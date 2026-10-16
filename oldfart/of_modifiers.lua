OF = OF or {}
OF.modifiers = OF.modifiers or {}

local modifiers = OF.modifiers

modifiers.PACKET = "mods"
local NO_FOV      = 0
local NO_SKYBOX   = -1
local NO_ENVFX    = ENVFX_MODE_NO_OVERRIDE or -1

do

    local A_FADE = 30

    local lanes, held, shown, rungs = {}, {}, {}, {}

    local skyDim = 255

    local painted = nil

    local weather = { 0, 255, 255, 255 }

    local dressing = false

    function modifiers.field_taken(key)
        if dressing then return end
        held[key] = true
    end

    function modifiers.field_is_taken(key)
        return held[key] == true
    end

    function modifiers.fade_open(key, from, frames)
        if from == nil then return false end
        lanes[key] = {
            now = { from[1] or 0, from[2] or 0, from[3] or 0, from[4] or 0 },
            left = math.max(1, math.floor(frames or A_FADE)),
        }
        return true
    end

    function modifiers.fade_frames(key)
        local lane = lanes[key]
        if lane == nil then return 0 end
        return lane.left
    end

    function modifiers.fade_running(key)
        return modifiers.fade_frames(key) > 0
    end

    function modifiers.fade_pull(key, target)
        local lane = lanes[key]
        if lane == nil then return target end
        local now = lane.now
        for i = 1, 4 do
            local aim = target[i] or 0
            now[i] = now[i] + (aim - now[i]) / lane.left
        end
        lane.left = lane.left - 1
        if lane.left <= 0 then lanes[key] = nil end
        return now
    end

    function modifiers.fade_shown(key)
        return shown[key]
    end

    function modifiers.fade_forget(key)
        shown[key] = nil
    end

    function modifiers.forget_fades()
        lanes, held, shown, rungs = {}, {}, {}, {}
        skyDim, painted, weather = 255, nil, { 0, 255, 255, 255 }
    end

    function modifiers.paint_the_sky(amount, r, g, b)
        amount = OF.util.clamp(amount or 0, 0, 1)
        local t1, t2, t3 = r or 255, g or 255, b or 255

        local tint, bright = modifiers.sky_layers()
        local o1, o2, o3 = OF.venues.sky_mix(amount, t1, t2, t3, skyDim, tint, bright)
        weather[1], weather[2], weather[3], weather[4] = amount, t1, t2, t3
        if painted ~= nil and painted[1] == o1 and painted[2] == o2
            and painted[3] == o3 then
            return
        end
        painted = { o1, o2, o3 }
        OF.util.optional("set_skybox_color", nil, 0, o1)
        OF.util.optional("set_skybox_color", nil, 1, o2)
        OF.util.optional("set_skybox_color", nil, 2, o3)
    end

    function modifiers.sky_layers()
        local tint = nil
        if modifiers.level("skycolour") > 0 then
            tint = modifiers.setting("skycolour", "tint", nil)
        elseif OF.util.asks(OF.venues, "sky_tint") then
            tint = OF.venues.sky_tint()
        end
        local bright = 1
        if modifiers.level("skybright") > 0 then
            bright = modifiers.setting("skybright", "bright", 1)
        end
        return tint, bright
    end

    function modifiers.sky_dim()
        return skyDim
    end

    local function repaint()
        modifiers.paint_the_sky(weather[1], weather[2], weather[3], weather[4])
    end
    modifiers.repaint_sky = repaint

    function modifiers.clear_sky_dim()
        skyDim, shown["night"] = 255, nil
        repaint()
    end

    local function on_a_rung(key, rung)
        if rung ~= nil and rungs[key] ~= nil and rungs[key] ~= rung then
            modifiers.fade_open(key, shown[key])
        end
        rungs[key] = rung
    end

    local function dress(key, on, target, write)
        if held[key] then

            held[key] = nil
            shown[key] = nil
            return
        end
        if not on then

            lanes[key] = nil
            shown[key] = nil
            return
        end
        local moving = modifiers.fade_running(key)
        local got = modifiers.fade_pull(key, target)
        local was = shown[key]
        local moved = moving or was == nil
        if not moved then
            for i = 1, 4 do
                if was[i] ~= (got[i] or 0) then
                    moved = true
                    break
                end
            end
        end

        if was == nil then
            shown[key] = { got[1] or 0, got[2] or 0, got[3] or 0, got[4] or 0 }
        else
            was[1], was[2], was[3], was[4] =
                got[1] or 0, got[2] or 0, got[3] or 0, got[4] or 0
        end
        if moved then write(got) end
    end

    local function write_sun(got) modifiers.wear_sun({ got[1], got[2], got[3] }) end
    local function write_dark(got) modifiers.set_lighting(got[1], got[2], got[3]) end
    local function write_tint(got) modifiers.wear_tint(true, got) end
    local function write_night(got) skyDim = OF.util.clamp(got[1], 0, 255) end
    local function write_fog(got)
        modifiers.set_fog(got[1], { got[2], got[3], got[4] })
    end

    function modifiers.dress_the_world()
        dressing = true

        local turning = modifiers.setting("sun", "hours", nil) == true
            or modifiers.setting("sun", "shoulder", nil) == true
        local dir = modifiers.sun_wanted()
        local sunOn = dir ~= nil and not turning
        dress("sun", sunOn,
            sunOn and { dir[1] or 0, dir[2] or 0, dir[3] or 0, 0 } or nil,
            write_sun)

        on_a_rung("dark", modifiers.dark_rung())
        local dark = modifiers.dark_wanted()

        dress("dark", dark ~= nil, dark, write_dark)

        local paint = modifiers.tint_wanted()
        dress("tint", paint ~= nil, paint, write_tint)

        local wantsSky = modifiers.level("night") > 0
        dress("night", wantsSky,
            wantsSky and { modifiers.setting("night", "dim", 255), 0, 0, 0 }
                or nil,
            write_night)
        if not wantsSky and not modifiers.fade_running("night") then
            skyDim = 255
        end

        local air = modifiers.fog_wanted()
        dress("fog", air ~= nil, air, write_fog)

        repaint()

        dressing = false
    end
end

local FOG_LEVELS = {
    [LEVEL_BOB] = true, [LEVEL_HMC] = true, [LEVEL_JRB] = true,
    [LEVEL_LLL] = true, [LEVEL_SSL] = true, [LEVEL_TTM] = true,
    [LEVEL_TTC] = true, [LEVEL_PSS] = true, [LEVEL_COTMC] = true,
    [LEVEL_CASTLE] = true, [LEVEL_BOWSER_1] = true, [LEVEL_BOWSER_2] = true,
}

local function fog_multiplier()
    return modifiers.setting("fog", "fogx", 118) / 100
end

local FOG_GREY = { r = 150, g = 152, b = 160 }
local FULL     = 255

local function fog_tint()

    if modifiers.setting("fog", "fromSky", false) == true then
        local sky = modifiers.air_of_the_sky()
        if sky ~= nil then

            local dim = (modifiers.sky_dim ~= nil and modifiers.sky_dim() or 255) / 255
            return math.floor(sky[1] * dim + 0.5), math.floor(sky[2] * dim + 0.5),
                math.floor(sky[3] * dim + 0.5)
        end
    end
    local hue = modifiers.setting("fog", "hue", nil)
    if hue == nil then return FOG_GREY.r, FOG_GREY.g, FOG_GREY.b end
    return hue[1], hue[2], hue[3]
end

function modifiers.fog_is_real(levelNum)
    return FOG_LEVELS[levelNum] == true
end

local FOG_THICKEST = 1.40

do
    modifiers.FOG_PLANES = { near = 5, far = 32767, levelNear = 100, levelFar = 32767 }

    local function fog_x(d)
        local P = modifiers.FOG_PLANES
        local n, f = P.near, P.far
        local z = d * (n + f) / (f - n) - 2 * n * f / (f - n)
        z = (z - P.levelNear) * (P.levelFar - n) / (P.levelFar - P.levelNear) + (2 * n - P.levelNear)
        return z / d
    end

    modifiers.fog_x_at = fog_x

    local function fog_horizon()
        local P = modifiers.FOG_PLANES
        return (P.near + P.far) / (P.far - P.near) * (P.levelFar - P.near) / (P.levelFar - P.levelNear)
    end

    local function s16_round(v)
        v = math.floor(v + 0.5)
        if v > 32767 then return 32767 elseif v < -32768 then return -32768 end
        return v
    end

    function modifiers.haze_words(start, finish, intensity)
        intensity = intensity or 1.0
        local x0 = fog_x(start)
        local x1 = finish == nil and fog_horizon() or fog_x(finish)
        local span = math.max(x1 - x0, 1e-6)
        local mul = 255 / (span * intensity)
        return s16_round(mul), s16_round(-x0 * mul * intensity)
    end
end

modifiers.PAINT_FAR, modifiers.PAINT_NEAR, modifiers.PAINT_WHOLE = 9000, 600, 4

modifiers.FOG_SPAN_DEFAULT = 8192
modifiers.FOG_SPAN_LEAST = 4000
modifiers.FOG_WHOLE_LEAST = 3500
modifiers.FOG_START_LEAST = 900
modifiers.FOG_SPANS = {
    { level = "LEVEL_BBH", area = 1, span = 6758 },
    { level = "LEVEL_BOWSER_1", area = 1, span = 7168 },
    { level = "LEVEL_BOWSER_2", area = 1, span = 6546 },
    { level = "LEVEL_CASTLE_COURTYARD", area = 1, span = 3839 },
    { level = "LEVEL_CASTLE", area = 1, span = 7431 },
    { level = "LEVEL_CASTLE", area = 2, span = 7642 },
    { level = "LEVEL_COTMC", area = 1, span = 7505 },
    { level = "LEVEL_DDD", area = 2, span = 7167 },
    { level = "LEVEL_JRB", area = 2, span = 3699 },
    { level = "LEVEL_LLL", area = 2, span = 2943 },
    { level = "LEVEL_SA", area = 1, span = 3072 },
    { level = "LEVEL_SL", area = 2, span = 3482 },
    { level = "LEVEL_SSL", area = 2, span = 6758 },
    { level = "LEVEL_SSL", area = 3, span = 3954 },
    { level = "LEVEL_THI", area = 3, span = 2458 },
    { level = "LEVEL_TTC", area = 1, span = 3301 },
    { level = "LEVEL_VCUTM", area = 1, span = 6681 },
    { level = "LEVEL_WDW", area = 1, span = 4608 },
    { level = "LEVEL_WDW", area = 2, span = 4569 },
}

function modifiers.fog_span(level, area, scale)
    local np = gNetworkPlayers[0]
    if level == nil then level = np ~= nil and np.currLevelNum or nil end
    if area == nil then area = np ~= nil and np.currAreaIndex or nil end
    local span = modifiers.FOG_SPAN_DEFAULT
    for _, row in ipairs(modifiers.FOG_SPANS) do
        if _G[row.level] ~= nil and _G[row.level] == level and row.area == area then
            span = row.span
        end
    end
    if scale == nil then
        scale = 1.0
        local size = OF.util.asks(OF.warp, "loaded_size") and OF.warp.loaded_size() or nil
        if size ~= nil then
            scale = math.max(math.abs(tonumber(size.x) or 1), math.abs(tonumber(size.z) or 1))
        end
    end
    return math.max(span * math.max(scale, 0.01), modifiers.FOG_SPAN_LEAST)
end

function modifiers.fog_reach(amount, span)
    amount = OF.util.clamp(amount or 0, 0, 1)
    local haze = modifiers.setting("fog", "haze", nil)
    if type(haze) == "number" and haze > 0 then
        local full = (modifiers.setting("fog", "fogx", 118) / 100 - 1.0) / (FOG_THICKEST - 1.0)
        local share = OF.util.clamp(amount / math.max(full, 0.01), 0.05, 1)
        return haze / share, nil
    end
    span = span or modifiers.fog_span()
    local start = math.max(span * (0.85 - 0.75 * amount), modifiers.FOG_START_LEAST)
    local finish = math.max(span * (4.0 - 3.0 * amount), modifiers.FOG_WHOLE_LEAST)
    return start, finish
end

function modifiers.fog_at(d, start, finish)
    local mul, off = modifiers.haze_words(start, finish, 1.0)
    local x = modifiers.fog_x_at(d)
    return OF.util.clamp((x * mul + off) / 255, 0, 1)
end

modifiers.FOG_SKY_SHARE = 0.55

function modifiers.fog_planes_here()
    if cast_graph_node == nil then return nil end
    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    local area = me ~= nil and me.area or nil
    local root = area ~= nil and area.root or nil
    local top = root ~= nil and root.node or nil
    if top == nil then return nil end
    if modifiers.fogPlanesAt == top and modifiers.fogPlanes ~= nil then
        return modifiers.fogPlanes[1], modifiers.fogPlanes[2]
    end
    local PERSPECTIVE = GRAPH_NODE_TYPE_PERSPECTIVE or 0x103
    local found = nil
    local budget = 400
    local function walk(first)
        if first == nil or found ~= nil or budget <= 0 then return end
        local node = first
        repeat
            budget = budget - 1
            if node.type == PERSPECTIVE then
                local ok, shaped = pcall(cast_graph_node, node)
                if ok and shaped ~= nil then found = shaped return end
            end
            walk(node.children)
            node = node.next
        until node == nil or node == first or found ~= nil or budget <= 0
    end
    walk(top.children)
    if found == nil then return nil end
    local near, far = tonumber(found.near), tonumber(found.far)
    if near == nil or far == nil or near <= 0 or far <= near then return nil end
    modifiers.fogPlanesAt, modifiers.fogPlanes = top, { near, far }
    return near, far
end

modifiers.fogColourWanted = nil
modifiers.lightingNow = nil

function modifiers.world_dark()
    local V = OF.venues
    if OF.util.asks(V, "dark_baked") then
        local bake = V.dark_baked()
        if type(bake) == "table" then return { bake[1], bake[2], bake[3] } end

        local layout = V.built ~= nil and V.LAYOUTS ~= nil and V.LAYOUTS[V.built] or nil
        if layout ~= nil and OF.util.asks(V, "lightfog_v2") and V.lightfog_v2(layout) then
            return nil
        end
    end
    local now = modifiers.lightingNow
    if modifiers.owns_lighting() and now ~= nil then return { now[1], now[2], now[3] } end
    return nil
end

function modifiers.fog_colour_wanted(r, g, b)
    if r == nil then
        modifiers.fogColourWanted = nil
        return nil
    end
    modifiers.fogColourWanted = { r, g or r, b or r }
    return modifiers.write_fog_colour()
end

function modifiers.write_fog_colour()
    local want = modifiers.fogColourWanted
    if want == nil then return nil end
    local r, g, b = modifiers.fog_in_the_dark(want[1], want[2], want[3], modifiers.world_dark())
    OF.util.optional("set_fog_color", nil, 0, r)
    OF.util.optional("set_fog_color", nil, 1, g)
    OF.util.optional("set_fog_color", nil, 2, b)
    return { r, g, b }
end

function modifiers.set_fog(amount, tint)

    modifiers.field_taken("fog")
    amount = OF.util.clamp(amount or 0, 0, 1)

    local np = gNetworkPlayers[0]
    local here = np ~= nil and np.currLevelNum or nil
    local real = modifiers.fog_is_real(here)

    if modifiers.fog_paint ~= nil and modifiers.fog_can_paint() then
        if amount > 0 then
            local near, far = modifiers.fog_planes_here()
            local P = modifiers.FOG_PLANES
            if near ~= nil then
                P.levelNear, P.levelFar = near, far
            end

            local start, finish = modifiers.fog_reach(amount)
            modifiers.fog_words(modifiers.haze_words(start, finish,
                1.0 + (FOG_THICKEST - 1.0) * amount))
            modifiers.fog_paint(true)
            real = true
        else
            modifiers.fog_paint(false)
        end
    end

    if not real then
        OF.util.optional("set_fog_intensity", nil, 1.0)
        modifiers.fog_colour_wanted(nil)
        for index = 0, 2 do
            OF.util.optional("set_fog_color", nil, index, FULL)
        end

        modifiers.paint_the_sky(0, FULL, FULL, FULL)
        return
    end

    local tintR, tintG, tintB = fog_tint()
    if tint ~= nil then
        tintR, tintG, tintB = tint[1] or tintR, tint[2] or tintG, tint[3] or tintB
    end

    modifiers.fog_colour_wanted(tintR, tintG, tintB)

    OF.util.optional("set_fog_intensity", nil, 1.0 + (FOG_THICKEST - 1.0) * amount)

    modifiers.paint_the_sky(amount * modifiers.FOG_SKY_SHARE, tintR, tintG, tintB)

end

do

    local STILL_SLACK = 2

    local STILL_FULL = 12

    function modifiers.still_seconds()
        local m = gMarioStates[0]
        if m == nil or m.pos == nil then return 0 end
        local now = OF.util.optional("get_global_timer", 0) or 0
        local was = modifiers.stillAt
        if was == nil
            or math.abs(m.pos.x - was.x) > STILL_SLACK
            or math.abs(m.pos.y - was.y) > STILL_SLACK
            or math.abs(m.pos.z - was.z) > STILL_SLACK then
            modifiers.stillAt = { x = m.pos.x, y = m.pos.y, z = m.pos.z, at = now }
            return 0
        end

        if now < was.at then
            modifiers.stillAt = { x = m.pos.x, y = m.pos.y, z = m.pos.z, at = now }
            return 0
        end
        return (now - was.at) / 30
    end

    function modifiers.forget_stillness()
        modifiers.stillAt = nil
    end

    function modifiers.fog_wanted()
        if modifiers.level("fog") <= 0 then return nil end
        local amount
        if modifiers.setting("fog", "still", false) == true then

            amount = OF.util.clamp(modifiers.still_seconds() / STILL_FULL, 0, 1)
        else
            amount = (fog_multiplier() - 1.0) / (FOG_THICKEST - 1.0)
        end
        local r, g, b = fog_tint()
        return { OF.util.clamp(amount, 0, 1), r, g, b }
    end
end

function modifiers.fog_step(name)
    local entry = modifiers.BY_KEY["fog"]
    for _, step in ipairs(entry ~= nil and entry.levels or {}) do
        if step.name == name and step.fogx ~= nil then
            return OF.util.clamp((step.fogx / 100 - 1.0) / (FOG_THICKEST - 1.0),
                0, 1)
        end
    end

    return 1
end

local ownsLighting = false
local saidLightingTaken = false

function modifiers.set_lighting(r, g, b)

    modifiers.field_taken("dark")
    r = math.floor(OF.util.clamp(r or 127, 0, 255))
    g = math.floor(OF.util.clamp(g or r, 0, 255))
    b = math.floor(OF.util.clamp(b or r, 0, 255))

    if not ownsLighting then
        if OF.util.optional("le_is_enabled", false)
            and modifiers.lantern_count() == 0 then
            if not saidLightingTaken then
                saidLightingTaken = true
                OF.notify.show("Another mod owns the lighting - darkness is off",
                    "warn", 5)
            end
            return false
        end
        ownsLighting = true
    end

    OF.util.optional("le_set_ambient_color", nil, r, g, b)
    modifiers.lightingNow = { r, g, b }
    modifiers.write_fog_colour()
    return true
end

function modifiers.set_dark(grey)
    grey = OF.util.clamp(grey or 127, 0, 255)
    return modifiers.set_lighting(grey, grey, grey)
end

do

    local A_RUNG = 30

    local function closing_ladder()
        local out = {}
        local entry = modifiers.BY_KEY["dark"]
        for _, step in ipairs(entry ~= nil and entry.levels or {}) do
            if step.grey ~= nil then out[#out + 1] = step.grey end
        end
        return out
    end

    function modifiers.dark_rung()
        if modifiers.setting("dark", "closes", false) ~= true then return nil end
        local rungs = #closing_ladder()
        if rungs == 0 then return nil end

        local elapsed = 0
        if OF.util.asks(OF.gamemodes, "state")
            and OF.gamemodes.state() ~= OF.gamemodes.OFF
            and OF.util.asks(OF.gamemodes, "elapsed") then
            elapsed = OF.gamemodes.elapsed() or 0
        end
        return math.min(rungs, 1 + math.floor(elapsed / A_RUNG))
    end

    local function dark_of_the_row()
        local rung = modifiers.dark_rung()
        if rung ~= nil then
            local grey = closing_ladder()[rung] or 127
            return { grey, grey, grey, 0 }
        end

        if modifiers.setting("dark", "fromSky", false) == true then
            return modifiers.dark_of_the_sky()
        end

        local rgb = modifiers.setting("dark", "light", nil)
        if rgb ~= nil then return { rgb[1], rgb[2], rgb[3], 0 } end
        local grey = modifiers.setting("dark", "grey", 100)
        return { grey, grey, grey, 0 }
    end

    function modifiers.dark_wanted()
        if modifiers.level("dark") <= 0 then return nil end
        return modifiers.dark_over_bake(dark_of_the_row())
    end
end

function modifiers.dark_over_bake(want)
    if want == nil or not OF.util.asks(OF.venues, "dark_baked") then return want end
    local bake = OF.venues.dark_baked()
    if type(bake) ~= "table" then return want end
    local A = tonumber(OF.venues.DARK_AMBIENT) or 208
    local out = { 0, 0, 0, want[4] or 0 }
    for i = 1, 3 do
        local c = A * (tonumber(want[i]) or 127) / math.max(1, tonumber(bake[i]) or 70)
        out[i] = math.floor(OF.util.clamp(c, 0, 255) + 0.5)
    end
    return out
end

function modifiers.clear_dark()
    if not ownsLighting then return false end
    ownsLighting = false
    saidLightingTaken = false

    OF.util.optional("le_set_ambient_color", nil, 127, 127, 127)
    modifiers.lightingNow = nil
    modifiers.write_fog_colour()

    if modifiers.lantern_count() == 0 then
        OF.util.optional("le_set_enabled", nil, false)
    end
    return true
end

function modifiers.owns_lighting()
    return ownsLighting
end

function modifiers.clear_fog()

    if modifiers.fog_paint ~= nil then modifiers.fog_paint(false) end

    modifiers.fog_colour_wanted(nil)
    for index = 0, 2 do
        OF.util.optional("set_fog_color", nil, index, FULL)
    end
    modifiers.paint_the_sky(0, FULL, FULL, FULL)
    OF.util.optional("set_fog_intensity", nil, 1.0)
end

function modifiers.fog_painter()
    local P = {}
    local G_MOVEWORD_OP, G_SETOTHERMODE_L_OP = 0xDB, 0xE2
    local G_GEOMETRYMODE_OP, G_SETFOGCOLOR_OP = 0xD9, 0xF8
    local G_MW_FOG_INDEX = 0x08
    local G_FOG_BIT = 0x00010000

    P.CYCLE1_MASK = 0xCCC00000
    P.FOG_SHADE_A = 0xC8000000

    P.mul, P.off = 3200, -2944
    P.positions = {}
    P.BUDGET = 4096
    P.EVERY = 15

    local DL_NODES = {
        [0x015] = true, [0x016] = true, [0x017] = true, [0x019] = true,
        [0x01A] = true, [0x01B] = true, [0x01C] = true, [0x01D] = true,
        [0x030] = true,
    }
    P.held = {}
    P.painted = {}

    P.ownOnly = false

    local SYNCS = { [0xE7] = "gsDPPipeSync()", [0xE6] = "gsDPLoadSync()", [0xE8] = "gsDPTileSync()" }
    local VTX_OPS = { [0x01] = true, [0x11] = true }
    local DRAW_OPS = { [0x05] = true, [0x06] = true, [0x07] = true, [0x12] = true }
    local STATE_WORDS = {
        "gsSPGeometryMode(%i, %i)", "gsSPFogFactor(%i, %i)", "gsDPSetFogColor(%i, %i, %i, %i)" }

    local function spend_sync(cmd, op, which)
        if which == 1 then
            gfx_set_command(cmd, STATE_WORDS[1], 0, G_FOG_BIT)
        elseif which == 2 then
            gfx_set_command(cmd, STATE_WORDS[2], P.mul, P.off)
            P.positions[#P.positions + 1] = cmd
        else
            gfx_set_command(cmd, STATE_WORDS[3], 255, 255, 255, 255)
        end
        P.held[#P.held + 1] = { cmd, "sync", SYNCS[op] }
    end

    local function fogable(cmd)
        local w0, w1 = cmd.w0 or 0, cmd.w1 or 0
        local len = (w0 & 0xFF) + 1
        local sft = 32 - len - ((w0 >> 8) & 0xFF)

        if sft > 18 or sft + len < 32 then return nil end
        local data = w1 & 0xFFFFFFFF
        if (data & P.CYCLE1_MASK) == P.FOG_SHADE_A then return nil end
        return sft, len, data
    end

    local function fog_render_mode(cmd)
        local sft, len, data = fogable(cmd)
        if sft == nil then return end
        local now = (data & ~P.CYCLE1_MASK) | P.FOG_SHADE_A
        gfx_set_command(cmd, "gsSPSetOtherMode(%i, %i, %i, %i)",
            G_SETOTHERMODE_L_OP, sft, len, now)
        P.held[#P.held + 1] = { cmd, "mode", data, sft, len }
    end

    function P.plan_list(cmds)
        local firstMode, firstVtx = nil, nil
        local modes = {}
        local have = {}
        for i, one in ipairs(cmds) do
            local op, cmd = one[2], one[1]
            if op == G_SETOTHERMODE_L_OP and fogable(cmd) ~= nil then
                modes[#modes + 1] = cmd
                firstMode = firstMode or i
            elseif VTX_OPS[op] then
                firstVtx = firstVtx or i
            elseif op == G_GEOMETRYMODE_OP and ((cmd.w1 or 0) & G_FOG_BIT) ~= 0 then
                have[1] = have[1] or i
            elseif op == G_MOVEWORD_OP and (((cmd.w0 or 0) >> 16) & 0xFF) == G_MW_FOG_INDEX then
                have[2] = have[2] or i
            elseif op == G_SETFOGCOLOR_OP then
                have[3] = have[3] or i
            end
        end
        if firstMode == nil then return nil, modes, false end
        local callable = firstVtx == nil or firstVtx > firstMode
        local firstDraw = #cmds + 1
        for i = firstMode + 1, #cmds do
            if DRAW_OPS[cmds[i][2]] then firstDraw = i break end
        end
        local limit = { firstVtx or firstDraw, firstVtx or firstDraw, firstDraw }
        if limit[1] > firstDraw then limit[1], limit[2] = firstDraw, firstDraw end
        local spend, at = {}, 1
        for which = 1, 3 do
            if have[which] == nil or have[which] >= limit[which] then
                while at < limit[which] and SYNCS[cmds[at][2]] == nil do at = at + 1 end
                if at >= limit[which] then return nil, modes, callable end
                spend[#spend + 1] = { at, which }
                at = at + 1
            end
        end
        return spend, modes, callable
    end

    P.NAME = "of_fogmode_"
    P.made, P.live = {}, {}
    local function mode_list(data)
        local dl = P.made[data]
        if dl ~= nil then

            if not P.live[data] then
                local factor = gfx_get_command(dl, 1)
                gfx_set_command(factor, STATE_WORDS[2], P.mul, P.off)
                P.positions[#P.positions + 1] = factor
                P.live[data] = true
            end
            return dl
        end
        if gfx_create == nil or gfx_get_command == nil then return nil end
        local name = P.NAME .. string.format("%08x", data)
        if gfx_get_from_name ~= nil then dl = gfx_get_from_name(name) end
        if dl == nil then dl = gfx_create(name, 5) end
        if dl == nil then return nil end
        gfx_set_command(gfx_get_command(dl, 0), STATE_WORDS[1], 0, G_FOG_BIT)
        local factor = gfx_get_command(dl, 1)
        gfx_set_command(factor, STATE_WORDS[2], P.mul, P.off)
        P.positions[#P.positions + 1] = factor
        P.live[data] = true
        gfx_set_command(gfx_get_command(dl, 2), STATE_WORDS[3], 255, 255, 255, 255)
        gfx_set_command(gfx_get_command(dl, 3), "gsSPSetOtherMode(%i, %i, %i, %i)",
            G_SETOTHERMODE_L_OP, 3, 29, (data & ~P.CYCLE1_MASK) | P.FOG_SHADE_A)
        gfx_set_command(gfx_get_command(dl, 4), "gsSPEndDisplayList()")
        P.made[data] = dl
        return dl
    end

    local function call_render_mode(cmd)
        local sft, len, data = fogable(cmd)
        if sft == nil or sft ~= 3 or len ~= 29 then return false end
        local dl = mode_list(data)
        if dl == nil then return false end
        gfx_set_command(cmd, "gsSPDisplayList(%g)", dl)
        P.held[#P.held + 1] = { cmd, "mode", data, sft, len }
        return true
    end

    local function own_word(cmd)
        local w0, w1 = cmd.w0 or 0, cmd.w1 or 0
        if ((w0 >> 16) & 0xFF) ~= G_MW_FOG_INDEX then return end
        local mul = (w1 >> 16) & 0xFFFF
        local off = w1 & 0xFFFF
        if mul >= 0x8000 then mul = mul - 0x10000 end
        if off >= 0x8000 then off = off - 0x10000 end
        if mul == P.mul and off == P.off then return end
        gfx_set_command(cmd, "gsSPFogFactor(%i, %i)", P.mul, P.off)
        P.positions[#P.positions + 1] = cmd
        P.held[#P.held + 1] = { cmd, "word", mul, off }
    end

    function P.paint_list(gfx)
        if gfx == nil then return end
        if P.ownOnly then
            gfx_parse(gfx, function(cmd, op)
                if op == G_MOVEWORD_OP then own_word(cmd) end
            end)
            return
        end
        local cmds = {}
        gfx_parse(gfx, function(cmd, op) cmds[#cmds + 1] = { cmd, op } end)
        local spend, modes, callable = P.plan_list(cmds)
        if spend ~= nil then
            for _, one in ipairs(spend) do
                local at = cmds[one[1]]
                spend_sync(at[1], at[2], one[2])
            end
            for _, cmd in ipairs(modes) do fog_render_mode(cmd) end
        elseif callable then

            for _, cmd in ipairs(modes) do
                if not call_render_mode(cmd) then break end
            end
        end
    end

    P.LISTS_PER_FRAME = 48
    P.queue, P.queued = {}, 0

    function P.drain(most)
        local done = 0
        while P.queued > 0 and done < most do
            local gfx = P.queue[P.queued]
            P.queue[P.queued] = nil
            P.queued = P.queued - 1
            P.paint_list(gfx)
            done = done + 1
        end
        return done
    end

    function P.walk(first, budget)
        if first == nil or budget <= 0 then return budget end
        local node = first
        repeat
            budget = budget - 1
            if budget <= 0 then return 0 end
            local kind = node.type
            if kind ~= nil and DL_NODES[kind] and cast_graph_node ~= nil then
                local shaped = cast_graph_node(node)
                if shaped ~= nil and shaped.displayList ~= nil then
                    P.queued = P.queued + 1
                    P.queue[P.queued] = shaped.displayList
                end
            end
            budget = P.walk(node.children, budget)
            node = node.next
        until node == nil or node == first or budget <= 0
        return budget
    end

    function P.paint_models(budget)
        if obj_get_first == nil or obj_get_next == nil then return budget end
        local seen, seenCount = {}, 0
        for list = 0, 12 do
            local object = obj_get_first(list)
            while object ~= nil and budget > 0 do
                local gfxNode = object.header ~= nil and object.header.gfx or nil
                local shared = gfxNode ~= nil and gfxNode.sharedChild or nil
                if shared ~= nil then
                    local already = false
                    for index = 1, seenCount do
                        if seen[index] == shared then already = true break end
                    end
                    if not already then
                        seenCount = seenCount + 1
                        seen[seenCount] = shared
                        budget = P.walk(shared, budget)
                    end
                end
                object = obj_get_next(object)
            end
        end
        return budget
    end

    function P.can()
        return gfx_parse ~= nil and gfx_set_command ~= nil and cast_graph_node ~= nil
    end

    function P.area(budget)
        local me = gMarioStates ~= nil and gMarioStates[0] or nil
        local area = me ~= nil and me.area or nil
        local root = area ~= nil and area.root or nil
        local top = root ~= nil and root.node or nil
        if top ~= nil and not P.painted[top] then
            P.painted[top] = true
            budget = P.walk(top.children, budget)
        end
        return budget
    end

    function P.restore()
        for index = #P.held, 1, -1 do
            local one = P.held[index]
            pcall(function()
                if one[2] == "sync" then
                    gfx_set_command(one[1], one[3] or "gsDPPipeSync()")
                elseif one[2] == "word" then
                    gfx_set_command(one[1], "gsSPFogFactor(%i, %i)", one[3], one[4])
                else
                    gfx_set_command(one[1], "gsSPSetOtherMode(%i, %i, %i, %i)",
                        G_SETOTHERMODE_L_OP, one[4], one[5], one[3])
                end
            end)
        end
        P.held, P.painted, P.positions, P.live = {}, {}, {}, {}
        P.queue, P.queued = {}, 0
    end

    function P.words(mul, off)
        mul, off = math.floor(mul), math.floor(off)
        if mul == P.mul and off == P.off then return false end
        P.mul, P.off = mul, off
        for _, cmd in ipairs(P.positions) do
            pcall(gfx_set_command, cmd, "gsSPFogFactor(%i, %i)", mul, off)
        end
        return true
    end
    return P
end

function modifiers.fog_in_the_dark(r, g, b, dark)
    r, g, b = r or 255, g or 255, b or 255
    if type(dark) ~= "table" then return r, g, b end
    local function one(c, d)
        d = math.max(0, math.min(255, tonumber(d) or 255))
        return math.floor(c * d / 255 + 0.5)
    end
    return one(r, dark[1]), one(g, dark[2] or dark[1]), one(b, dark[3] or dark[1])
end

do
    local P = modifiers.fog_painter()
    local wanted = false
    local tick = 0

    local PAINT_BUDGET, PAINT_EVERY, LISTS_PER_FRAME = P.BUDGET, P.EVERY, P.LISTS_PER_FRAME

    function modifiers.fog_can_paint()
        return P.can()
    end

    function modifiers.fog_paint(on, modelsOnly)

        if OF.util.asks(OF.stretch, "fog") then OF.stretch.fog(on == true) end
        if not on then
            wanted = false

            if OF.util.asks(OF.venues, "fog_heads") then OF.venues.fog_heads(false) end
            P.restore()
            return 0
        end
        wanted = true
        if not modifiers.fog_can_paint() then return #P.held end
        local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
        P.ownOnly = np ~= nil and modifiers.fog_is_real(np.currLevelNum)
        local budget = PAINT_BUDGET

        local heads = OF.util.asks(OF.venues, "fog_heads_here") and OF.venues.fog_heads_here()
        if heads and not modelsOnly then
            OF.venues.fog_heads(true, P.mul, P.off)
        end
        if not modelsOnly and not heads then budget = P.area(budget) end
        P.drain(LISTS_PER_FRAME)

        if not P.ownOnly then P.paint_models(budget) end
        return #P.held
    end

    function modifiers.fog_queued()
        return P.queued
    end

    function modifiers.fog_painted()
        return #P.held
    end

    function modifiers.fog_words(mul, off)
        if mul == nil or off == nil then return P.mul, P.off end
        if not P.words(mul, off) then return P.mul, P.off end
        mul, off = P.mul, P.off
        if wanted and OF.util.asks(OF.venues, "fog_heads_here") and OF.venues.fog_heads_here() then
            OF.venues.fog_heads(true, mul, off)
        end
        if OF.util.asks(OF.stretch, "fog_refresh") then OF.stretch.fog_refresh() end
        return P.mul, P.off
    end

    function modifiers.fog_paint_wanted()
        return wanted
    end

    hook_event(HOOK_UPDATE, function()
        if not wanted then return end
        tick = tick + 1
        modifiers.fog_paint(true, tick % PAINT_EVERY ~= 0)
    end)

    hook_event(HOOK_ON_LEVEL_INIT, function()
        if #P.held == 0 and not wanted then return end
        local still = wanted
        modifiers.fog_paint(false)
        wanted = still
    end)
    hook_event(HOOK_ON_EXIT, function() modifiers.fog_paint(false) end)
end

local HIGH_WATER = 1200
local DEEP_WATER = 3000
local DROWNED_WATER = 6000

local LOW_WATER = 1500
local GONE_WATER = 9000

local MAX_REGIONS = 20

local borrowed = {}

local function water_place()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    if type(np.currLevelNum) ~= "number" then return nil end
    if type(np.currAreaIndex) ~= "number" then return nil end
    return np.currLevelNum, np.currAreaIndex
end

local function borrowed_at(level, area)
    local rooms = borrowed[level]
    if rooms == nil then return nil end
    return rooms[area]
end

local function region_is_there(index)
    local here = get_water_level(index)
    if type(here) ~= "number" then return false end
    if gLevelValues ~= nil and here == gLevelValues.floorLowerLimit then
        return false
    end
    return true
end

local function water_is_ours()
    if not region_is_there(0) then return false end

    local m = gMarioStates[0]
    if m ~= nil and find_poison_gas_level ~= nil and gLevelValues ~= nil then

        modifiers.gasHushed = true
        local ok, gas = pcall(find_poison_gas_level, m.pos.x, m.pos.z)
        modifiers.gasHushed = false
        if ok and gas ~= nil and gas > gLevelValues.floorLowerLimit then
            return false
        end
    end

    return true
end

local function raise_water(by)
    if not water_is_ours() then return end
    local level, area = water_place()
    if level == nil then return end

    local record = borrowed_at(level, area)
    if record == nil then

        record = {}
        local found = false
        for index = 0, MAX_REGIONS - 1 do
            if region_is_there(index) then
                record[index] = get_water_level(index)
                found = true
            end
        end

        if not found then return end
        local rooms = borrowed[level]
        if rooms == nil then
            rooms = {}
            borrowed[level] = rooms
        end
        rooms[area] = record
    end

    local bottom = nil
    if gLevelValues ~= nil and type(gLevelValues.floorLowerLimit) == "number" then
        bottom = gLevelValues.floorLowerLimit
    end

    for index, base in pairs(record) do

        local wanted = base + by
        if bottom ~= nil and wanted <= bottom then wanted = bottom + 1 end

        set_water_level(index, wanted, false)
    end
end

local function restore_water()
    local level, area = water_place()
    if level == nil then return end
    local record = borrowed_at(level, area)
    if record == nil then return end
    for index, base in pairs(record) do
        set_water_level(index, base, false)
    end
    borrowed[level][area] = nil
    if next(borrowed[level]) == nil then borrowed[level] = nil end
end

do
local FOLLOW_OVER = 150

local FOLLOW_STEP = 8

local chaseAt = nil

function modifiers.forget_the_chase()
    chaseAt = nil
end

function modifiers.chase_the_lowest()
    if modifiers.setting("water", "follows", false) ~= true then
        chaseAt = nil
        return
    end

    local base = modifiers.water_baseline()
    if base == nil then return end

    local lowest = nil
    for _, entry in ipairs(OF.util.connected_players()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil
            and OF.util.optional("is_player_active", 0, m) ~= 0
            and (lowest == nil or m.pos.y < lowest) then
            lowest = m.pos.y
        end
    end
    if lowest == nil then return end

    local want = lowest + FOLLOW_OVER
    if chaseAt == nil then chaseAt = base end
    if want > chaseAt + FOLLOW_STEP then
        chaseAt = chaseAt + FOLLOW_STEP
    elseif want < chaseAt - FOLLOW_STEP then
        chaseAt = chaseAt - FOLLOW_STEP
    else
        chaseAt = want
    end

    raise_water(chaseAt - base)
end

local TIDE_PERIOD = 40
local TIDE_RISE = 700

local tideIsOurs = false

function modifiers.chase_the_tide()
    if not OF.util.asks(OF.ground, "tide_height") then return end
    if modifiers.setting("water", "tide", false) ~= true then
        if tideIsOurs and OF.util.is_host() then OF.ground.tide_disarm() end
        tideIsOurs = false
        return
    end
    if OF.util.is_host() and not OF.ground.tide_armed() then
        OF.ground.tide_arm(TIDE_PERIOD)
        tideIsOurs = true
    end
    if modifiers.water_baseline() == nil then return end
    local off = OF.ground.tide_height(0, TIDE_RISE)
    if off ~= nil then raise_water(off) end
end
end

hook_event(HOOK_UPDATE, function() modifiers.chase_the_lowest() end)
hook_event(HOOK_UPDATE, function() modifiers.chase_the_tide() end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    modifiers.forget_the_chase()
    restore_water()
end)

hook_event(HOOK_ON_EXIT, function() restore_water() end)

modifiers.water_baselines = function(level, area)
    if level == nil then level, area = water_place() end
    if level == nil then return nil end
    local record = borrowed_at(level, area)
    if record == nil then return nil end
    local copy = {}
    for index, base in pairs(record) do copy[index] = base end
    return copy
end

modifiers.water_baseline = function(level, area, region)
    if level == nil then level, area = water_place() end
    if level == nil then return nil end
    local record = borrowed_at(level, area)
    if record == nil then return nil end
    return record[region or 0]
end

function modifiers.water_note()
    if modifiers.level("water") <= 0 then return nil end

    if modifiers.setting("water", "tide", false) == true
        and OF.util.asks(OF.ground, "tide_progress") then
        local at = OF.ground.tide_progress()
        if at ~= nil then
            return OF.lang.fill("Tide: @ of the way round",
                string.format("%.0f%%", at * 100))
        end
        return OF.lang.t("Tide: waiting for the host's mark")
    end
    if water_is_ours() then return nil end

    return OF.lang.t("No water in this level to move.")
end

local function round_owns(subject)
    if type(subject) ~= "string" or subject == "" then return false end
    if not OF.util.asks(OF.gamemodes, "is_running") then return false end
    if not OF.util.asks(OF.gamemodes, "current") then return false end

    if not (OF.gamemodes.is_running()
        or (OF.util.asks(OF.gamemodes, "is_waiting") and OF.gamemodes.is_waiting())) then
        return false
    end
    local mode = OF.gamemodes.current()
    if mode == nil then return false end
    return mode["uses" .. subject:sub(1, 1):upper() .. subject:sub(2)] == true
end

modifiers.round_owns = round_owns

local function water_is_the_rounds()
    return round_owns("water")
end

modifiers.water_is_the_rounds = water_is_the_rounds

function modifiers.dry_note()
    if modifiers.level("dry") <= 0 then return nil end
    if water_is_the_rounds() then
        return OF.lang.t("The round owns the water - this is standing down.")
    end
    if water_is_ours() then return nil end
    return OF.lang.t("No water in this level to walk through.")
end

local TRUE_SWIM = 2

function modifiers.swim_note()
    local level = modifiers.level("swim")
    if level <= 0 then return nil end
    if level >= TRUE_SWIM then
        return OF.lang.t("No water needed, and no way out until this is off.")
    end
    if water_is_ours() then return nil end
    return OF.lang.t("No water in this level to swim out of - try the next stop.")
end

function modifiers.true_swim_on()
    return modifiers.level("swim") >= TRUE_SWIM
end

hook_event(HOOK_ALLOW_FORCE_WATER_ACTION, function(m, isInWaterAction)
    if m == nil or m.playerIndex ~= 0 then return end

    if isInWaterAction then

        if modifiers.level("swim") <= 0 then return end

        if modifiers.true_swim_on() then return false end

        local probe = m.pos.y + 1.5
        probe = (probe >= 0) and math.floor(probe) or math.ceil(probe)

        if OF.util.has_flag(m.input, INPUT_A_PRESSED)
            and m.pos.y <= m.waterLevel - 80
            and probe >= m.waterLevel - 80
            and m.faceAngle.x >= 0
            and m.controller.stickY < -60 then
            return
        end

        if m.waterLevel - 80 <= m.floorHeight then return end

        return false
    end

    if modifiers.level("dry") <= 0 then return end
    if water_is_the_rounds() then return end

    local wade = modifiers.setting("dry", "wade", nil)
    if wade ~= nil and type(m.floorHeight) == "number"
        and type(m.waterLevel) == "number"
        and m.waterLevel - m.floorHeight > wade then
        return
    end

    return false
end)

local trueSwimHealth = nil
local trueSwimHurt = nil

local function group_of(action)
    if type(action) ~= "number" or ACT_GROUP_MASK == nil then return nil end
    return action & ACT_GROUP_MASK
end

modifiers.action_group = group_of

function modifiers.drop_the_swim()
    local m = gMarioStates[0]
    if m == nil or set_mario_action == nil then return false end
    if group_of(m.action or 0) ~= ACT_GROUP_SUBMERGED then return false end

    if m.waterLevel ~= nil and m.pos ~= nil
        and m.pos.y <= m.waterLevel - 80 then return false end
    set_mario_action(m, ACT_FREEFALL, 0)
    return true
end

local function true_swim_before(m)
    if m == nil or m.playerIndex ~= 0 then return end
    trueSwimHealth = nil
    trueSwimHurt = nil
    if not modifiers.true_swim_on() then return end
    if set_mario_action == nil then return end

    trueSwimHealth = m.health
    trueSwimHurt = m.hurtCounter or 0

    if not OF.util.can_play(0) then return end
    local group = group_of(m.action or 0)
    if group == nil then return end
    if group == ACT_GROUP_CUTSCENE then return end
    if group == ACT_GROUP_SUBMERGED then return end
    if m.action == ACT_BUBBLED then return end

    set_mario_action(m, ACT_WATER_IDLE, 0)
end

local function true_swim_after(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not modifiers.true_swim_on() then return end
    if trueSwimHealth == nil then return end
    if trueSwimHurt ~= 0 then return end

    if OF.util.has_flag(m.input or 0, INPUT_IN_POISON_GAS) then return end
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then return end
    if m.health >= trueSwimHealth then return end
    m.health = trueSwimHealth
end

modifiers.true_swim_before = true_swim_before
modifiers.true_swim_after = true_swim_after

hook_event(HOOK_BEFORE_MARIO_UPDATE, true_swim_before, OF.LOCAL_MARIO)
hook_event(HOOK_MARIO_UPDATE, true_swim_after, OF.LOCAL_MARIO)

function modifiers.gates_note()
    if modifiers.level("gates") <= 0 then return nil end
    return OF.lang.t("Only the courtyard Boo changes now.")
end

modifiers.LIST = {

    {

        key = "lowgrav", id = "lg", name = "Everybody's gravity",
        blurb = "lighter than the moon, or heavier than lead",

        levels = {
            { name = "light", fall = 0.72 },
            { name = "floaty", fall = 0.55 },
            { name = "the moon", fall = 0.33 },

            { name = "a little heavy", fall = 1.30 },
            { name = "like lead", fall = 1.80 },

            { name = "a dropped anvil", fall = 2.60 },

            { name = "deep space", fall = 0.17 },
        },
    },

    {
        key = "upsidedown", id = "ud", name = "Upside down",
        blurb = "everybody falls towards the ceiling",
        levels = {
            { name = "the camera turns with it" },
            { name = "the camera stays put", horizon = "flat" },
        },

    },

    {
        key = "giant", id = "gi", name = "Everybody is giant",
        blurb = "everybody is enormous",
        excludes = { "tiny" },
        levels = {
            { name = "big", scale = 1.8 },
            { name = "huge", scale = 2.6 },
            { name = "absurd", scale = 3.6 },

            { name = "a kaiju", scale = 5.0 },
        },
        world = function() OF.cheats.apply_scale() end,
        restore = function() OF.cheats.apply_scale() end,
    },
    {
        key = "tiny", id = "ty", name = "Everybody is tiny",
        blurb = "everybody is a thimble",
        excludes = { "giant" },
        levels = {
            { name = "small", scale = 0.45 },
            { name = "tiny", scale = 0.28 },
            { name = "a crumb", scale = 0.15 },

            { name = "a grain of sand", scale = 0.08 },
        },
        world = function() OF.cheats.apply_scale() end,
        restore = function() OF.cheats.apply_scale() end,
    },

    {
        key = "night", id = "sk", name = "The sky",
        blurb = "somebody else's weather, everywhere",
        levels = {
            { name = "haunted", sky = BACKGROUND_HAUNTED },
            { name = "on fire", sky = BACKGROUND_FLAMING_SKY },
            { name = "underwater", sky = BACKGROUND_UNDERWATER_CITY },
            { name = "above the clouds", sky = BACKGROUND_ABOVE_CLOUDS },
            { name = "desert", sky = BACKGROUND_DESERT },
            { name = "green", sky = BACKGROUND_GREEN_SKY },
            { name = "purple", sky = BACKGROUND_PURPLE_SKY },

            { name = "at sea", sky = BACKGROUND_OCEAN_SKY },
            { name = "below the clouds", sky = BACKGROUND_BELOW_CLOUDS },
            { name = "snowy peaks", sky = BACKGROUND_SNOW_MOUNTAINS },

            { retired = "a total eclipse" },

            { retired = "no sky at all", lands = 0,
              becomes = { skybright = 5 } },
        },

        fades = true,
        world = function()
            set_override_skybox(modifiers.setting("night", "sky", BACKGROUND_HAUNTED))
        end,
        restore = function()

            set_override_skybox(modifiers.placeSky or NO_SKYBOX)
            modifiers.clear_sky_dim()
        end,
    },

    {
        key = "skycolour", id = "ky", name = "Sky colour",
        blurb = "the sky's own colour, over any sky",
        levels = {
            { name = "night blue", tint = { 60, 74, 125 } },
            { name = "dusk", tint = { 235, 140, 125 } },
            { name = "dawn rose", tint = { 250, 175, 185 } },
            { name = "blood red", tint = { 220, 55, 45 } },
            { name = "toxic green", tint = { 120, 225, 80 } },
            { name = "gold", tint = { 255, 205, 110 } },
            { name = "ice", tint = { 175, 225, 255 } },
        },
        world = function() modifiers.repaint_sky() end,
        restore = function() modifiers.repaint_sky() end,
    },
    {
        key = "skybright", id = "kh", name = "Sky brightness",
        blurb = "how much light the sky lets through",
        note = function() return modifiers.sky_note() end,
        levels = {
            { name = "brighter", bright = 1.3 },
            { name = "dim", bright = 0.7 },
            { name = "dark", bright = 0.45 },
            { name = "very dark", bright = 0.22 },
            { name = "pitch black", bright = 0 },
        },
        world = function() modifiers.repaint_sky() end,
        restore = function() modifiers.repaint_sky() end,
    },

    {
        key = "sun", id = "su", name = "The hour",
        blurb = "where the light comes from, so the shading turns with it",
        levels = {
            { name = "early, from the east", dir = { 0.9, 0.35, 0.1 } },
            { name = "overhead", dir = { 0, 1, 0 } },
            { name = "late, from the west", dir = { -0.9, 0.35, -0.1 } },

            { name = "from underneath", dir = { 0, -1, 0 } },

            { name = "the day going by", hours = true },

            { name = "from the north", dir = { 0.1, 0.4, 0.9 } },
            { name = "low and behind", dir = { 0, 0.15, -1.0 } },

            { name = "from the south", dir = { -0.1, 0.4, -0.9 } },
            { name = "flat on from the east", dir = { 1.0, 0.05, 0 } },
            { name = "flat on from the west", dir = { -1.0, 0.05, 0 } },

            { name = "the sun goes round in a minute", hours = true,
              turn = 60 * 30 },

            { retired = "it follows whoever is winning" },

            { retired = "it goes out, a stop on every death", lands = 0 },

            { name = "over your shoulder", shoulder = true },

            { name = "the sky decides it", fromSky = true },
        },

        fades = true,
        note = function() return modifiers.sun_note() end,
        restore = function()
            modifiers.wear_sun(nil)
            modifiers.rewear_place_light("sun")
        end,
    },

    {
        key = "dark", id = "dk", name = "Darkness",
        blurb = "the light goes out of the world itself",

        levels = {
            { name = "dusk",  grey = 100 },
            { name = "night", grey = 70 },
            { name = "pitch", grey = 45 },
            { name = "a red night",  light = { 110, 45, 45 } },
            { name = "a green murk", light = { 50, 100, 60 } },
            { name = "a cold blue",  light = { 50, 70, 115 } },
            { name = "sodium dusk",  light = { 120, 85, 40 } },

            { name = "a purple hour", light = { 95, 55, 120 } },
            { name = "hospital light", light = { 105, 125, 105 } },
            { name = "under water", light = { 45, 85, 105 } },

            { name = "it closes in", closes = true },

            { name = "the sky decides it", fromSky = true },

        },

        fades = true,
        note = function() return modifiers.dark_note() end,
        restore = function()
            modifiers.clear_dark()
            modifiers.rewear_place_light("dark")
        end,
    },

    {
        key = "starhome", id = "sx", name = "Where a star you earned lands",
        blurb = "a boss or red-coin star appears over its earner",
        levels = {

            { name = "over whoever earned it", over = 250 },

            { name = "over them, and close enough to take", over = 90 },
        },
        restore = function() return true end,
    },
    {
        key = "fog", id = "fg", name = "Fog",
        blurb = "the air thickens and the distance goes grey",
        levels = {

            { name = "hazy",     fogx = 105 },
            { name = "thick",    fogx = 118 },
            { name = "pea soup", fogx = 140 },

            { name = "a red haze",      fogx = 118, hue = { 175, 85, 80 } },
            { name = "sulphur",         fogx = 125, hue = { 185, 175, 90 } },
            { name = "a blue distance", fogx = 112, hue = { 105, 130, 180 } },

            { name = "a green murk",   fogx = 122, hue = { 105, 160, 110 } },
            { name = "smoke",          fogx = 132, hue = { 90, 88, 92 } },
            { name = "a pink evening", fogx = 108, hue = { 200, 150, 175 } },

            { name = "it thickens behind you", still = true },

            { name = "the sky decides it", fogx = 118, fromSky = true },

            { name = "the sky's haze", fogx = 106, fromSky = true, haze = 8000 },
        },
        fades = true,
        note = function() return modifiers.fog_note() end,
        restore = function() modifiers.clear_fog() end,
    },
    {
        key = "cloud", id = "cl", name = "Cloud flower",
        blurb = "fall far enough and a platform catches you, then regrows",

        levels = {
            { name = "one save, slow to return",  saves = 1, regen = 60 },
            { name = "two saves",                 saves = 2, regen = 50 },
            { name = "three saves",               saves = 3, regen = 40 },
            { name = "four saves",                saves = 4, regen = 30 },
            { name = "five saves, quick to return", saves = 5, regen = 20 },

            { name = "a pocketful",               saves = 6, regen = 15 },
            { name = "a dozen, and quick",        saves = 12, regen = 10 },
        },

        note = function() return modifiers.cloud_note() end,

        world = function() end,
        restore = function() modifiers.clear_clouds() end,
    },
    {
        key = "demon", id = "gd", name = "The Green Demon",
        blurb = "a 1-UP comes after you, and it does not stop",
        note = function() return modifiers.demon_note() end,
        levels = {

            { retired = "patient", lands = 2 },
            { name = "Brisk", speed = 1 },
            { retired = "relentless", lands = 2 },

            { name = "Run!", speed = 2 },

            { name = "On your heels", speed = 3 },
        },

        world = function() end,
        restore = function() modifiers.clear_demon() end,
    },

    {
        key = "clones", id = "kc", name = "Cosmic Clones",
        blurb = "dark copies of you run your path - a touch hurts",
        note = function()
            return OF.util.asks(OF.clones, "note") and OF.clones.note() or nil
        end,
        world = function() end,
        restore = function()
            if OF.util.asks(OF.clones, "clear") then OF.clones.clear() end
        end,
    },

    {
        key = "spray", id = "pt", name = "Spray paint",
        blurb = "spray your mark in your own colour where you aim",
        note = function()
            return OF.util.asks(OF.spray, "note") and OF.spray.note() or nil
        end,
        world = function() end,
        restore = function() end,
    },
    {
        key = "fisheye", id = "fe", name = "Fisheye",
        blurb = "a wider, sillier world",
        levels = {

            { name = "wide", fov = 90 },
            { name = "wider", fov = 115 },
            { name = "absurd", fov = 140 },

            { name = "a long lens", fov = 30 },
            { name = "through a keyhole", fov = 17 },

            { name = "everything at once", fov = 165 },
            { name = "a telescope", fov = 10 },

            { name = "it breathes", fov = 58, swell = 125, period = 150 },

            { name = "it widens when you run", fov = 45, wide = 115 },

            { name = "and it never stops widening", fov = 45, wide = 115,
              top = 165 },
        },
        world = function(level)
            modifiers.rest_fov()
        end,
        restore = function()
            modifiers.forget_fisheye()
            modifiers.rest_fov()
        end,
    },

    {
        key = "snow", id = "we", name = "Weather",
        blurb = "whatever is falling, wherever you are",
        levels = {
            { name = "snow", envfx = ENVFX_SNOW_NORMAL },
            { name = "a blizzard", envfx = ENVFX_SNOW_BLIZZARD },
            { name = "flower petals on the ground", envfx = ENVFX_FLOWERS,
              needs = "ground" },
            { name = "bubbles, deep under water", envfx = ENVFX_SNOW_WATER,
              needs = "water" },
            { name = "lava bubbles, over lava", envfx = ENVFX_LAVA_BUBBLES,
              needs = "lava" },

            { name = "rain", rain = "rain" },
            { name = "a thunderstorm", rain = "storm" },

            { name = "a rain of Bob-ombs", bombs = true, drop = "bombs" },

            { name = "a rain of coins", drop = "coins" },
            { name = "a rain of 1-Ups", drop = "lives" },

            { retired = "falling stars", lands = 0 },
            { retired = "hail", lands = 0 },

            { retired = "a wind that turns every minute",
              lands = 0 },

            { retired = "ash", lands = 0 },

            { retired = "rain you can shelter from",
              lands = 0 },
        },
        note = function() return modifiers.weather_note() end,
        world = function()
            local rain = modifiers.setting("snow", "rain", nil)

            local drop = modifiers.setting("snow", "drop", nil)
            set_override_envfx((rain ~= nil or drop ~= nil) and NO_ENVFX
                or modifiers.setting("snow", "envfx", ENVFX_SNOW_NORMAL))

            if OF.util.asks(OF.celebrate, "set_weather") then
                OF.celebrate.set_weather(rain)
            end
        end,
        restore = function()
            set_override_envfx(NO_ENVFX)
            if OF.util.asks(OF.celebrate, "set_weather") then
                OF.celebrate.set_weather(nil)
            end

            if modifiers.rain_held_here() then
                modifiers.hide_bombs(modifiers.bombs_standing(), true)
                return
            end
            modifiers.clear_bombs()

            modifiers.clear_drops()
        end,
    },

    {
        key = "quick", id = "qk", name = "How fast everybody moves",
        blurb = "the whole lobby, quicker or wading through treacle",

        note = function() return modifiers.quick_note() end,
        levels = {
            { name = "brisk", speed = 1.35 },
            { name = "fast", speed = 1.8 },
            { name = "silly", speed = 2.6 },

            { name = "wading", speed = 0.72 },
            { name = "through treacle", speed = 0.45 },

            { name = "ludicrous", speed = 3.6 },

            { name = "faster the fuller your pockets", pocket = 1 },
            { name = "faster the emptier your pockets", pocket = -1 },
        },
    },

    {
        key = "momentum", id = "mm", name = "Endless momentum",
        blurb = "the speed you build stays with you and keeps building",
        note = function() return modifiers.momentum_note() end,
        levels = {
            { name = "nothing bleeds off" },
            { name = "and it builds as you run", gain = 0.35 },
            { name = "and it builds quickly", gain = 0.9 },

            { name = "and it runs away with you", gain = 2.0 },
        },
        apply = function(m) modifiers.hold_momentum(m) end,
        restore = function() modifiers.forget_momentum() end,
    },

    {
        key = "tech", id = "tc", name = "Roll out of a hit",
        blurb = "press Z as a hit lands to roll out, instead of riding it out",
        levels = {

            { name = "one or two frames", frames = 2 },

            { name = "a third of a second", frames = 10 },

            { name = "generous", frames = 20 },
        },
        apply = function(m) modifiers.tech_out(m) end,
        restore = function() modifiers.forget_the_hit() end,
    },

    {
        key = "ridekb", id = "kp", name = "Ride the hit",
        blurb = "run the way a hit threw you: two seconds of free speed",
        apply = function(m) modifiers.ride_the_hit(m) end,
        restore = function() modifiers.forget_the_hit() end,
    },

    {
        key = "coinhit", id = "oh", name = "Coins on hit",
        blurb = "a hit knocks your coins loose for anybody to grab",
        note = function() return modifiers.coin_hit_note() end,
        levels = {

            { name = "a hit spills your coins" },
            { name = "coins take the hit", shield = true },
            { name = "coins are your life", shield = true, life = true },
        },
        world = function() end,
        restore = function() modifiers.forget_coin_hit() end,
    },

    {
        key = "cards", id = "ca", name = "Cards from stars",
        blurb = "a card turns per star - a hand of three pays lives",
        levels = {
            { name = "lives, as SMB3 paid them" },
        },
        restore = function()
            if OF.util.asks(OF.cards, "forget") then OF.cards.forget() end
        end,
    },

    {
        key = "softland", id = "sl", name = "Soft landings",
        blurb = "the fall costs nothing, a little, or gives the height back",
        levels = {

            { name = "no fall damage at all" },

            { name = "a little", cap = 1600 },

            { name = "you bounce", bounce = 52 },

            { name = "you bounce higher each time", bounce = 40, more = 9 },
        },
        apply = function(m) modifiers.hold_the_landing(m) end,
        restore = function() modifiers.forget_the_landing() end,
    },

    {
        key = "learn", id = "ln", name = "Earn your moveset",
        blurb = "start with almost nothing; take it back a star at a time",
        note = function() return modifiers.learn_note() end,
        levels = {
            { name = "from scratch" },
            { name = "keep the double jump" },
        },

    },

    {
        key = "face", id = "fc", name = "Everybody's face",
        blurb = "what the whole lobby's eyes and hands are doing",
        note = function() return modifiers.face_note() end,
        levels = {

            { name = "asleep", eyes = MARIO_EYES_CLOSED,
              hands = MARIO_HAND_FISTS },
            { name = "sleepwalking", eyes = MARIO_EYES_CLOSED,
              hands = MARIO_HAND_OPEN },
            { name = "half awake", eyes = MARIO_EYES_HALF_CLOSED,
              hands = MARIO_HAND_OPEN },

            { name = "not at all well", eyes = MARIO_EYES_DEAD,
              hands = MARIO_HAND_OPEN },

            { name = "looking somewhere else", eyes = MARIO_EYES_LOOK_LEFT,
              hands = MARIO_HAND_OPEN },
            { name = "watching the sky", eyes = MARIO_EYES_LOOK_UP,
              hands = MARIO_HAND_OPEN },

            { name = "very pleased with themselves", eyes = MARIO_EYES_OPEN,
              hands = MARIO_HAND_PEACE_SIGN },
            { name = "holding an invisible cap", eyes = MARIO_EYES_OPEN,
              hands = MARIO_HAND_HOLDING_CAP },

            { name = "whatever last happened to you", mood = true },

            { name = "somebody else's", dealt = true },
        },
    },

    {
        key = "posture", id = "ps", name = "Everybody's posture",
        blurb = "the whole lobby stands wrong, waist to neck",
        levels = {

            { name = "heads on backwards", head = { 0, 0, 0x7FFF } },
            { name = "leaning back", torso = { 0, -0x1200, 0 } },
            { name = "hunched forward", torso = { 0, 0x1600, 0 }, head = { 0, -0x0800, 0 } },
            { name = "listing to one side", torso = { 0x1800, 0, 0 } },
            { name = "looking over one shoulder", head = { 0, 0, 0x3800 } },

            { name = "wrong in every joint", torso = { 0x2000, 0x1800, 0x2000 },
              head = { -0x1800, 0x1000, 0x4000 } },

            { name = "frozen mid-animation", frame = 0 },

        },
        restore = function() modifiers.clear_posture() end,
    },

    {
        key = "trail", id = "tl", name = "Everybody leaves a trail",
        blurb = "something comes off the whole lobby as it moves",
        levels = {
            { name = "sparkles", particle = PARTICLE_SPARKLES },
            { name = "fire", particle = PARTICLE_FIRE },
            { name = "snow", particle = PARTICLE_SNOW },
            { name = "leaves", particle = PARTICLE_LEAF },
            { name = "dust", particle = PARTICLE_DUST },
            { name = "bubbles", particle = PARTICLE_BUBBLE },
            { name = "stars", particle = PARTICLE_VERTICAL_STAR },
            { name = "dirt", particle = PARTICLE_DIRT },

            { name = "breath, as if it were freezing", particle = PARTICLE_BREATH },

            { name = "everything at once",
              particle = PARTICLE_SPARKLES | PARTICLE_FIRE | PARTICLE_SNOW
                  | PARTICLE_LEAF | PARTICLE_DUST | PARTICLE_VERTICAL_STAR },

            { name = "only whoever is winning", lead = true },

            { name = "only whoever is behind you", chase = true },

            { name = "coins", coins = true },

            { name = "your team's colour", team = true },
        },

        restore = function() return modifiers.clear_coin_trail() end,
    },

    {
        key = "horizon", id = "hz", name = "The horizon",
        blurb = "the world does not sit level any more",
        levels = {
            { name = "a slight lean", tilt = 0x0700 },
            { name = "properly crooked", tilt = 0x1A00 },

            { name = "slowly turning", drift = 900 },
            { name = "upside down", tilt = 0x8000 },

            { name = "leaning the other way", tilt = -0x1A00 },

            { name = "on its side", tilt = 0x4000 },

            { name = "turning, and quickly", drift = 450 },

            { name = "a lean you can feel", tilt = 0x0E00 },
            { name = "turning, slowly, for ever", drift = 2200 },

            { name = "it leans towards whoever is nearest", lean = 0x1E00 },

            { name = "it rights itself when you stop", moving = 0x2200 },

            { name = "it flips on every jump", press = 0x4000 },
        },
    },

    {
        key = "mirror", id = "mi", name = "Mirror",
        blurb = "the whole world, left for right",
        levels = {
            { name = "the world, and your stick with it", stick = true },

            { name = "the world only", stick = false },

            { name = "everybody but whoever is winning", stick = true,
              spare = "leader" },

            { name = "it flips every twenty seconds", stick = true, every = 600 },
        },
        world = function() modifiers.wear_mirror(true) end,
        restore = function() modifiers.wear_mirror(false) end,
        note = function() return modifiers.mirror_note() end,
    },

    {
        key = "budget", id = "bg", name = "Your A presses",
        blurb = "every jump is counted, and there may be a budget",

        excludes = { "buttons" },
        note = function() return modifiers.press_note() end,
        levels = {
            { name = "counted only" },
            { name = "ten a level",  budget = 10 },
            { name = "three a level", budget = 3 },
            { name = "one a level",  budget = 1 },

            { name = "fifty a level", budget = 50 },
            { name = "twenty-five a level", budget = 25 },

            { name = "three a level, and coins buy them back",
              budget = 3, coin = 1 },

            { name = "one a minute", budget = 1, every = 1800 },
        },
        world = function() end,
        restore = function() modifiers.forget_presses() end,
    },
    {
        key = "buttons", id = "bt", name = "The buttons",
        blurb = "a button taken away, or one you can never let go of",
        excludes = { "budget" },
        levels = {
            { name = "no jumping (A)", mask = A_BUTTON },
            { name = "no hands (B)", mask = B_BUTTON },
            { name = "no crouching (Z)", mask = Z_TRIG },
            { name = "walk only", walk = true },
            { name = "all three at once", mask = A_BUTTON | B_BUTTON | Z_TRIG },

            { name = "no jumping and no hands", mask = A_BUTTON | B_BUTTON },
            { name = "no hands and no crouching", mask = B_BUTTON | Z_TRIG },
            { name = "no jumping and no crouching", mask = A_BUTTON | Z_TRIG },

            { name = "a slow walk and nothing else", walk = true,
              mask = A_BUTTON | B_BUTTON | Z_TRIG },

            { name = "crouching for ever (Z)", hold = Z_TRIG },
            { name = "fists up for ever (B)", hold = B_BUTTON },

            { name = "one button each, and not the same one", deal = "own" },
            { name = "whoever is nearest's button", deal = "near" },
            { name = "the buttons rotate every twenty seconds", rotate = 600 },

            { retired = "a button for every death", lands = 0 },
            { name = "never the same button twice in a row", norepeat = true },

            { name = "it presses buttons by itself", phantom = true },
            { name = "one A press in three does nothing", flaky = A_BUTTON },
        },
        restore = function() modifiers.forget_buttons() end,
    },
    {
        key = "controls", id = "ct", name = "The controls",
        blurb = "the stick, turned on its way to Mario",
        levels = {
            { name = "mirrored", turn = "mirror" },
            { name = "backwards", turn = "flip" },
            { name = "sideways", turn = "quarter" },
            { name = "drunk", turn = "drunk" },

            { name = "sideways, the other way", turn = "backquarter" },

            { name = "askew", turn = "askew" },

            { name = "eight directions only", turn = "eight" },
            { name = "no backing up", turn = "noback" },

            { name = "relative to the level, not the camera", turn = "level" },
            { name = "relative to whoever is nearest", turn = "near" },
            { name = "it turns a little more each second", turn = "creep" },

            { name = "a rudder", turn = "rudder" },
            { name = "only on the beat", turn = "beat" },
        },
    },

    {
        key = "view", id = "vw", name = "Where the camera sits",
        blurb = "where the camera stands while you play",
        levels = {
            { name = "over the shoulder", view = { 350, 550, 120, 190 } },
            { name = "far away", view = { 1600, 2400, 500, 800 } },
            { name = "from above", view = { 700, 900, 1300, 1700 } },
            { name = "down at your heels", view = { 900, 1400, 60, 90 } },

            { name = "through your own eyes", eyes = true },

            { name = "right behind you", view = { 200, 320, 90, 140 } },
            { name = "a long way up", view = { 500, 700, 2200, 2800 } },
            { name = "down at ankle height", view = { 700, 1000, 20, 60 } },

            { name = "a satellite", view = { 3200, 4000, 2600, 3400 } },
            { name = "practically inside you", view = { 120, 180, 100, 150 } },

            { name = "left where you put it", pin = "still" },
            { name = "left where you put it, and watching you", pin = "watch" },
            { name = "the television camera", pin = "crowd" },

            { name = "a periscope", eyes = true, lift = 320 },
            { name = "an ant's eye view", eyes = true, lift = -100 },
        },
        world = function(level)
            modifiers.wear_eyes(modifiers.setting("view", "eyes", false) == true)
            modifiers.lift_eyes(modifiers.setting("view", "lift", nil))
            modifiers.wear_view(modifiers.setting("view", "view", nil))
        end,
        restore = function()
            modifiers.lift_eyes(nil)
            modifiers.wear_eyes(false)
            modifiers.wear_view(nil)

            modifiers.forget_pin()
        end,
    },

    {
        key = "voice", id = "vo", name = "The voice",
        blurb = "what everybody in the lobby sounds like",
        levels = {
            { name = "silent", voice = { silent = true } },
            { name = "a Goomba", voice = {
                jump = SOUND_OBJ_GOOMBA_ALERT,
                hurt = SOUND_OBJ_GOOMBA_ALERT,
                quiet = SOUND_OBJ_GOOMBA_WALK,
                other = SOUND_OBJ_GOOMBA_WALK,
            } },
            { name = "Bowser", voice = {
                jump = SOUND_OBJ_BOWSER_LAUGH,
                hurt = SOUND_OBJ_BOWSER_DEFEATED,
                quiet = SOUND_OBJ_BOWSER_INHALING,
                other = SOUND_OBJ_BOWSER_WALK,
            } },
            { name = "a monkey", voice = {
                jump = SOUND_OBJ_UKIKI_CHATTER_SHORT,
                hurt = SOUND_OBJ_UKIKI_CHATTER_LONG,
                quiet = SOUND_OBJ_UKIKI_CHATTER_IDLE,
                other = SOUND_OBJ_UKIKI_STEP_DEFAULT,
            } },
            { name = "a Boo", voice = {
                jump = SOUND_OBJ_BOO_LAUGH_SHORT,
                hurt = SOUND_OBJ_BOO_LAUGH_LONG,
                quiet = SOUND_OBJ_BOO_LAUGH_LONG,
                other = SOUND_OBJ_BOO_BOUNCE_TOP,
            } },
            { name = "a Wiggler", voice = {
                jump = SOUND_OBJ_WIGGLER_JUMP,
                hurt = SOUND_OBJ_WIGGLER_ATTACKED,
                quiet = SOUND_OBJ_WIGGLER_TALK,
                other = SOUND_OBJ_WIGGLER_LOW_PITCH,
            } },
            { name = "a cartoon", voice = {
                jump = SOUND_GENERAL_BOING1,
                hurt = SOUND_GENERAL_BOING2,
                quiet = SOUND_GENERAL_BOING2_LOWPRIO,
                other = SOUND_GENERAL_BOING1,
            } },
            { name = "money", voice = {
                jump = SOUND_GENERAL_COIN,
                hurt = SOUND_GENERAL_COIN,
                quiet = SOUND_GENERAL_COIN,
                other = SOUND_GENERAL_COIN,
            } },

            { name = "a Koopa", voice = {
                jump = SOUND_OBJ_KOOPA_TALK,
                hurt = SOUND_OBJ_KOOPA_DAMAGE,
                quiet = SOUND_OBJ_KOOPA_TALK,
                other = SOUND_OBJ_KOOPA_DAMAGE,
            } },
            { name = "a penguin", voice = {
                jump = SOUND_OBJ_BIG_PENGUIN_YELL,
                hurt = SOUND_OBJ_BIG_PENGUIN_YELL,
                quiet = SOUND_OBJ_BIG_PENGUIN_WALK,
                other = SOUND_OBJ_BIG_PENGUIN_WALK,
            } },
            { name = "a bully", voice = {
                jump = SOUND_OBJ_BULLY_METAL,
                hurt = SOUND_OBJ_BULLY_EXPLODE,
                quiet = SOUND_OBJ_BULLY_METAL,
                other = SOUND_OBJ_BULLY_METAL,
            } },
            { name = "a piranha plant", voice = {
                jump = SOUND_OBJ2_PIRANHA_PLANT_BITE,
                hurt = SOUND_OBJ_SNUFIT_SHOOT,
                quiet = SOUND_OBJ2_PIRANHA_PLANT_BITE,
                other = SOUND_OBJ2_PIRANHA_PLANT_BITE,
            } },

            { name = "a Bob-omb", voice = {

                jump = SOUND_AIR_BOBOMB_LIT_FUSE,
                hurt = SOUND_OBJ_BOBOMB_BUDDY_TALK,
                quiet = SOUND_OBJ_BOBOMB_WALK,
                other = SOUND_OBJ_BOBOMB_WALK,
                dying = SOUND_GENERAL2_BOBOMB_EXPLOSION,
            } },
            { name = "the Big Bob-omb", voice = {
                jump = SOUND_OBJ_KING_BOBOMB_TALK,
                hurt = SOUND_OBJ2_KING_BOBOMB_DAMAGE,
                quiet = SOUND_OBJ_KING_BOBOMB_TALK,
                other = SOUND_OBJ_KING_BOBOMB_TALK,
                dying = SOUND_GENERAL2_BOBOMB_EXPLOSION,
            } },
            { name = "a Thwomp", voice = {
                jump = SOUND_OBJ_THWOMP,
                hurt = SOUND_OBJ_THWOMP,
                quiet = SOUND_OBJ_POUNDING_LOUD,
                other = SOUND_OBJ_POUNDING_LOUD,
                dying = SOUND_OBJ_THWOMP,
            } },
            { name = "a Chuckya", voice = {
                jump = SOUND_OBJ_HEAVEHO_TOSSED,
                hurt = SOUND_OBJ_CHUCKYA_DEATH,
                quiet = SOUND_OBJ_HEAVEHO_TOSSED,
                other = SOUND_OBJ_HEAVEHO_TOSSED,
                dying = SOUND_OBJ_CHUCKYA_DEATH,
            } },

            { name = "a Chain Chomp", voice = {
                jump = SOUND_GENERAL_CHAIN_CHOMP1,
                hurt = SOUND_GENERAL_CHAIN_CHOMP2,
                quiet = SOUND_GENERAL_CHAIN_CHOMP1,
                other = SOUND_GENERAL_CHAIN_CHOMP1,
                dying = SOUND_GENERAL_WALL_EXPLOSION,
            } },

            { name = "Peach", voice = {
                jump = SOUND_PEACH_MARIO,
                hurt = SOUND_PEACH_MARIO2,
                quiet = SOUND_PEACH_DEAR_MARIO,
                other = SOUND_PEACH_THANK_YOU_MARIO,
                dying = SOUND_PEACH_POWER_OF_THE_STARS,
            } },

            { name = "silent unless you are hurt", voice = {
                jump = 0,
                quiet = 0,
                other = 0,
                dying = 0,
            } },
        },
    },
    {
        key = "floor", id = "fl", name = "The floor",
        blurb = "every surface, as slippery as the lobby decides",
        levels = {
            { name = "slippery", class = SURFACE_CLASS_SLIPPERY },
            { name = "ice", class = SURFACE_CLASS_VERY_SLIPPERY },
            { name = "grippy", class = SURFACE_CLASS_NOT_SLIPPERY },

            { name = "ordinary everywhere", class = SURFACE_CLASS_DEFAULT },

            { name = "it alternates by area", alternate = true },

            { name = "ice where somebody has walked", trodden = true },
        },
        note = function() return modifiers.floor_note() end,

        world = function(level)
            if OF.util.asks(OF.ground, "trail") then
                OF.ground.trail(
                    modifiers.setting("floor", "trodden", false) == true)
            end
        end,
        restore = function()
            if OF.util.asks(OF.ground, "trail") then OF.ground.trail(false) end
        end,
    },

    {
        key = "lava", id = "lv", name = "The floor is lava",
        blurb = "the low ground burns - climb, or outrun it",
        levels = {

            { name = "the low ground" },
            { name = "all but the high ground" },
            { name = "the whole course" },

            { name = "a spreading fire" },

            { name = "only where nobody is standing" },
            { name = "only where somebody has stood" },
            { name = "it pulls back while somebody is down" },

            { retired = "where somebody died", lands = 0 },
        },

        note = function() return modifiers.lava_note() end,
        world = function(level)

            if level > 4 then
                if OF.util.asks(OF.ground, "remember") then
                    OF.ground.remember(level)
                end
            elseif level > 3 then
                if OF.util.asks(OF.ground, "creep") then OF.ground.creep() end
            elseif OF.util.asks(OF.ground, "paint") then
                OF.ground.paint(level)
            end
        end,
        restore = function()
            if OF.util.asks(OF.ground, "restore") then OF.ground.restore() end
        end,
    },

    {
        key = "water", id = "wt", name = "The water rises",
        blurb = "the level's own water, somewhere it should not be",

        excludes = { "dry" },
        levels = {
            { name = "high", by = HIGH_WATER },
            { name = "deep", by = DEEP_WATER },
            { name = "drowned", by = DROWNED_WATER },

            { name = "lowered", by = -LOW_WATER },
            { name = "drained", by = -GONE_WATER },

            { name = "it follows the lowest player", follows = true },

            { name = "it rises and falls on a tide", tide = true },
        },
        note = function() return modifiers.water_note() end,
        world = function(level)

            if modifiers.setting("water", "follows", false) == true
                or modifiers.setting("water", "tide", false) == true then

                raise_water(0)
                return
            end
            raise_water(modifiers.setting("water", "by", HIGH_WATER))
        end,
        restore = function()
            modifiers.forget_the_chase()

            modifiers.chase_the_tide()
            restore_water()
        end,
    },

    {
        key = "dry", id = "dl", name = "The water is gone",
        blurb = "every water box is a pit - or only the shallow end of one",
        levels = {

            { name = "everywhere" },

            { name = "the shallow end only", wade = 400 },
        },

        excludes = { "swim", "water" },
        note = function() return modifiers.dry_note() end,
    },

    {
        key = "swim", id = "sw", name = "Swim anywhere",
        blurb = "the surface does not hold you down; swim into the sky",
        levels = {
            { name = "past the surface" },
            { name = "in the air, in any level" },
        },
        excludes = { "dry" },
        note = function() return modifiers.swim_note() end,

        world = function() end,
        restore = function() modifiers.drop_the_swim() end,
    },

    {
        key = "invertwater", id = "iw", name = "You breathe water, not air",
        blurb = "the air empties your meter and the water fills it back up",
        note = function() return modifiers.invert_water_note() end,
        levels = {

            { name = "as slow as drowning", drain = 1 },
            { name = "twice as quick", drain = 2 },

            { name = "as quick as the gas", drain = 4 },
        },
        apply = function(m) modifiers.hold_invert_water(m) end,
    },

    {
        key = "whirl", id = "wh", name = "The water pulls",
        blurb = "an undertow drags swimmers in, or blasts them apart",
        levels = {
            { name = "a tug", pull = 12 },
            { name = "a current", pull = 26 },

            { name = "a drain", pull = 75 },
            { name = "it pushes instead", pull = -26 },
            { name = "a fountain", pull = -75 },
        },
        note = function() return modifiers.whirl_note() end,

        world = function() end,
        restore = function() modifiers.clear_whirlpool() end,
    },

    {
        key = "carousel", id = "ro", name = "The level turns",
        blurb = "the ground swings the whole level around its own middle",
        levels = {
            { name = "a slow turn", spin = 24 },
            { name = "a carousel", spin = 64 },

            { name = "a fairground ride", spin = 144 },
            { name = "the other way", spin = -64 },

            { name = "faster the more people are alive", spin = 24,
              perHead = true },

            { name = "only while nobody is moving", spin = 120,
              stillOnly = true },
        },
        note = function() return modifiers.carousel_note() end,

        world = function() end,
        restore = function() modifiers.clear_carousel() end,
    },

    {
        key = "music", id = "ms", name = "The music",
        blurb = "the level's track: wrong speed, key, or paced to feet",
        levels = {
            { name = "slow", tempo = 60 },
            { name = "quick", tempo = 145 },
            { name = "twice over", tempo = 200 },

            { name = "an octave down", trans = -12 },
            { name = "an octave up", trans = 12 },
            { name = "out of key", trans = 5 },

            { name = "a funeral march", tempo = 38 },
            { name = "three times over", tempo = 300 },
            { name = "two octaves down", trans = -24 },
            { name = "a fifth up", trans = 7 },

            { name = "fast and wrong", tempo = 165, trans = -7 },

            { name = "slow and low", tempo = 50, trans = -12 },

            { name = "synched to your speed", low = 70, high = 130 },

            { name = "inverted to your speed", low = 130, high = 70 },
        },
        world = function() modifiers.wear_music(true) end,
        apply = function(m) modifiers.hold_music(m) end,
        restore = function() modifiers.wear_music(false) end,
    },

    {
        key = "flat", id = "fw", name = "Flat light",
        blurb = "every face lit the same - the map loses its shading",
        world = function() modifiers.wear_flat(true) end,

        restore = function()
            if not modifiers.studio_holds("flat") then modifiers.wear_flat(false) end
        end,
    },

    {
        key = "tint", id = "tn", name = "The world's colour",
        blurb = "the course is repainted; everybody standing on it is not",
        levels = {
            { name = "sepia", tint = { 255, 205, 150 } },
            { name = "rust", tint = { 255, 130, 90 } },
            { name = "verdigris", tint = { 120, 220, 180 } },
            { name = "ice", tint = { 150, 195, 255 } },
            { name = "a bruise", tint = { 175, 130, 235 } },
            { name = "gold", tint = { 255, 215, 70 } },

            { name = "ash", tint = { 145, 145, 145 } },
            { name = "bleached", tint = { 250, 250, 250 } },

            { name = "a shadow of itself", tint = { 60, 60, 70 } },

            { name = "your team's colour", team = true },

            { name = "it drains as the clock runs", drains = true },

            { name = "red when somebody is near", alarm = true },

            { name = "the sky decides it", fromSky = true },
        },
        fades = true,
        restore = function() modifiers.wear_tint(false) end,
    },

    {
        key = "quake", id = "ea", name = "The camera shakes",
        blurb = "the ground keeps moving, or somebody is holding it still",
        levels = {
            { name = "a tremor", mag = 0x30 },
            { name = "an earthquake", mag = 0xA0 },
            { name = "the whole world", mag = 0x180 },
            { name = "a steady hand", hand = HAND_CAM_SHAKE_LOW },
            { name = "handheld", hand = HAND_CAM_SHAKE_STAR_DANCE },
            { name = "somebody who has had a coffee", hand = HAND_CAM_SHAKE_HIGH },

            { name = "an earthquake, filmed badly", mag = 0xA0,
              hand = HAND_CAM_SHAKE_HIGH },

            { name = "a rolling sea", sea = 0x300 },
        },
        apply = function() modifiers.hold_quake() end,
        restore = function() modifiers.calm_the_sea() end,
    },

    {
        key = "anim", id = "am", name = "Everybody's animation",
        blurb = "everybody's limbs running faster or slower than they are",
        levels = {
            { name = "in slow motion", rate = 35 },
            { name = "wound up", rate = 220 },
            { name = "a cartoon", rate = 420 },

            { name = "a flip-book", rate = 8 },
            { name = "a blur", rate = 900 },
        },
    },

    {
        key = "shadow", id = "sd", name = "Shadows",
        blurb = "nobody casts one - or casts one that is somewhere else",
        levels = {

            { name = "nobody casts one", gone = true },

            { name = "a second behind you", behind = 30 },
            { name = "somebody else's", swap = true },
        },
        world = function()
            modifiers.wear_shadows(modifiers.setting("shadow", "gone", false)
                ~= true and not modifiers.studio_holds("shadows"))
        end,

        restore = function()
            modifiers.wear_shadows(not modifiers.studio_holds("shadows"))
            modifiers.forget_the_shadows()
        end,
    },

    {
        key = "camlag", id = "cg", name = "The camera drags",
        blurb = "how quickly the camera catches up with you",
        levels = {
            { name = "on a long rope", pos = 0.02, foc = 0.05 },
            { name = "loose", pos = 0.08, foc = 0.2 },
            { name = "welded on", pos = 1.0, foc = 1.0 },

            { name = "half a second behind", pos = 0.008, foc = 0.02 },
            { name = "a step behind", pos = 0.25, foc = 0.45 },
        },
        apply = function() modifiers.hold_camlag() end,
    },

    {
        key = "shading", id = "sg", name = "The light and the shadow",
        blurb = "the lit side and the shaded side, coloured apart",
        levels = {
            { name = "hard shadows", dir = { 255, 255, 255 }, amb = { 25, 25, 30 } },
            { name = "a warm sun", dir = { 255, 205, 130 }, amb = { 70, 80, 130 } },
            { name = "moonlight", dir = { 150, 175, 255 }, amb = { 40, 45, 70 } },
            { name = "sickly", dir = { 150, 255, 120 }, amb = { 110, 70, 110 } },

            { name = "a sunset", dir = { 255, 150, 90 }, amb = { 100, 60, 90 } },
            { name = "a fluorescent office", dir = { 235, 245, 255 },
              amb = { 160, 170, 175 } },
            { name = "firelight", dir = { 255, 170, 80 }, amb = { 60, 30, 25 } },
        },
        world = function() modifiers.wear_shading(true) end,
        restore = function() modifiers.wear_shading(false) end,
    },

    {
        key = "quiet", id = "qt", name = "The level goes quiet",
        blurb = "the world's own sounds, off - the music plays on",
        levels = {
            { name = "the objects" },
            { name = "the whole world" },
            { name = "everything but the music" },
        },
        world = function() modifiers.wear_quiet(true) end,
        restore = function() modifiers.wear_quiet(false) end,
    },

    {
        key = "steps", id = "sp", name = "The ground underfoot",
        blurb = "what every footstep sounds like, wherever it lands",
        levels = {
            { name = "grass", terrain = SOUND_TERRAIN_GRASS },
            { name = "stone", terrain = SOUND_TERRAIN_STONE },
            { name = "water", terrain = SOUND_TERRAIN_WATER },
            { name = "the squeaky floor", terrain = SOUND_TERRAIN_SPOOKY },
            { name = "snow", terrain = SOUND_TERRAIN_SNOW },
            { name = "ice", terrain = SOUND_TERRAIN_ICE },
            { name = "sand", terrain = SOUND_TERRAIN_SAND },

            { name = "bare hard ground", terrain = SOUND_TERRAIN_DEFAULT },
        },

    },

    {
        key = "lantern", id = "la", name = "Everybody carries a light",
        blurb = "a lamp on every player, and the world dims to meet it",
        levels = {

            { name = "a candle", light = { 255, 214, 150 }, radius = 900, glow = 1.0 },
            { name = "a lantern", light = { 255, 226, 180 }, radius = 1700, glow = 1.4 },
            { name = "a floodlight", light = { 255, 255, 255 }, radius = 3200, glow = 2.0 },

            { name = "a red flare", light = { 255, 80, 60 }, radius = 1500, glow = 1.7 },
            { name = "a cold blue torch", light = { 110, 170, 255 }, radius = 1500, glow = 1.6 },
            { name = "a green lamp", light = { 110, 255, 140 }, radius = 1500, glow = 1.6 },

            { name = "barely a match", light = { 255, 190, 120 },
              radius = 420, glow = 0.8 },

            { name = "a guttering flame", light = { 255, 186, 104 },
              radius = 1500, glow = 1.5, beat = "gutter" },
            { name = "a slow pulse", light = { 255, 226, 180 },
              radius = 1700, glow = 1.4, beat = "breathe" },
            { name = "an alarm", light = { 255, 60, 60 },
              radius = 1600, glow = 1.8, beat = "alarm" },

            { name = "a glow with no direction", light = { 200, 220, 255 },
              radius = 1500, glow = 1.5, spread = true },
        },
        note = function() return modifiers.lantern_note() end,

        world = function() end,
        restore = function() modifiers.clear_lanterns() end,
    },

    {
        key = "delay", id = "dy", name = "The controls arrive late",
        blurb = "what you press now happens in a moment",
        levels = {

            { name = "a hair late", frames = 3 },
            { name = "late", frames = 6 },
            { name = "a bad connection", frames = 10 },
            { name = "half a second", frames = 15 },

            { name = "a whole second", frames = 30 },

            { name = "it drifts, and a death puts it back", drift = true },
        },
        note = function() return modifiers.delay_note() end,
        world = function() end,
        restore = function() modifiers.forget_delay() end,
    },

    {
        key = "buffer", id = "pr", name = "An early press still counts",
        blurb = "ask for a jump early and the game still hears it",
        levels = {

            { name = "a hair early", frames = 2 },
            { name = "early", frames = 4 },

            { name = "a beat early", frames = 6 },
        },
        world = function() end,
        restore = function() modifiers.forget_early() end,
    },

    {
        key = "cluster", id = "cu", name = "Ground pounds explode",
        blurb = "a pound sends rings of explosions across the floor",
        levels = {
            { name = "one ring", rings = 1, reach = 320 },
            { name = "three rings", rings = 3, reach = 340 },

            { name = "six rings, and they reach", rings = 6, reach = 360 },

            { name = "and it throws you through a stunt",
              rings = 6, reach = 360, stunt = 10 },
        },
        world = function() end,
        restore = function() modifiers.clear_cluster() end,
    },

    {
        key = "wave", id = "wv", name = "Ground pounds send a shockwave",
        blurb = "a pound sends Bowser's wave out; it never hits you",
        levels = {

            { name = "one wave", waves = 1 },
            { name = "two waves", waves = 2 },

            { name = "four waves", waves = 4 },
        },
        world = function() end,
        restore = function()
            modifiers.clear_waves()
            modifiers.clear_spared()
        end,
    },

    {
        key = "shove", id = "gq", name = "Ground pounds shake the floor",
        blurb = "a pound shakes the screen and bounces anyone near",

        levels = {
            { name = "a tremor", reach = 320, shove = 12, shake = SHAKE_POS_SMALL or 1 },
            { name = "a real shake", reach = 1020, shove = 30, shake = SHAKE_POS_MEDIUM or 2 },
            { name = "an earthquake", reach = 2160, shove = 60, shake = SHAKE_POS_LARGE or 3 },
        },
        world = function() end,
        restore = function() modifiers.clear_shove() end,
    },

    {
        key = "blinders", id = "bd", name = "What you see of the screen",
        blurb = "the screen is boarded up, all but a piece in the middle",
        levels = {
            { name = "a letterbox", across = 1.0, down = 0.42 },
            { name = "a narrow slit", across = 1.0, down = 0.18 },
            { name = "a tall window", across = 0.30, down = 1.0 },
            { name = "a keyhole", across = 0.42, down = 0.42 },

            { name = "barely a gap", across = 0.22, down = 0.22 },

            { name = "a slit that follows your stick",
              across = 0.30, down = 0.30, follows = 0.34 },

            { name = "it opens when you stand still",
              across = 0.22, down = 0.22, opens = 0.86 },

            { name = "a block that bounces round it", bounce = 0.34 },
            { name = "all of it, five seconds in forty", every = 1200, dark = 150 },
        },

        restore = function() modifiers.forget_blinders() end,
    },

    {
        key = "camaggr", id = "cq", name = "How hard the camera chases",
        blurb = "how quickly the shot gets behind you again",
        levels = {
            { name = "it never catches up", aggr = 0 },
            { name = "lazy", aggr = 15 },
            { name = "keen", aggr = 60 },
            { name = "it is already there", aggr = 100 },
        },
        world = function() modifiers.wear_camaggr(true) end,
        restore = function() modifiers.wear_camaggr(false) end,
    },

    {
        key = "campan", id = "cn", name = "How far the camera leads",
        blurb = "how far the shot leads your aim, not trailing behind",
        levels = {
            { name = "down your back", pan = 0 },
            { name = "a glance ahead", pan = 30 },
            { name = "well ahead", pan = 70 },
            { name = "all the way ahead", pan = 100 },
        },
        world = function() modifiers.wear_campan(true) end,
        restore = function() modifiers.wear_campan(false) end,
    },

    {
        key = "camdrag", id = "cd", name = "How the camera stops",
        blurb = "whether the shot coasts past you or stops dead",
        levels = {
            { name = "it coasts", decel = 0 },
            { name = "it eases", decel = 40 },
            { name = "it stops dead", decel = 100 },
        },
        world = function() modifiers.wear_camdrag(true) end,
        restore = function() modifiers.wear_camdrag(false) end,
    },

    {
        key = "camstick", id = "ck", name = "How fast the camera turns",
        blurb = "everybody's camera stick, on the same setting",
        levels = {
            { name = "a crawl", sens = 5 },
            { name = "slow", sens = 20 },
            { name = "quick", sens = 70 },
            { name = "a flick sends it round", sens = 100 },
        },
        world = function() modifiers.wear_camstick(true) end,
        restore = function() modifiers.wear_camstick(false) end,
    },

    {
        key = "camwall", id = "cw", name = "The camera goes through walls",
        blurb = "the shot stops being shoved out of the level's geometry",
        world = function() modifiers.wear_camwall(true) end,
        restore = function() modifiers.wear_camwall(false) end,
    },

    {
        key = "camcentre", id = "cr", name = "The camera never re-centres",
        blurb = "the shot keeps whatever angle you left it at",
        world = function() modifiers.wear_camcentre(true) end,
        restore = function() modifiers.wear_camcentre(false) end,
    },

    {
        key = "near", id = "np", name = "How close you can see",
        blurb = "anything close to the camera stops being drawn",
        levels = {
            { name = "the wall in front of you goes", near = 120 },
            { name = "and the ground with it", near = 300 },
            { name = "and most of you", near = 600 },
            { name = "there is barely a world left", near = 1200 },

            { name = "it follows your speed", near = 0, reach = 700 },

            { retired = "it closes when you are hurt", lands = 0 },
        },
        world = function() modifiers.wear_near(true) end,
        restore = function() modifiers.wear_near(false) end,
    },

    {
        key = "camlock", id = "cz", name = "The level's own cameras",
        blurb = "the course's own camera scripting, refused",
        levels = {
            { name = "no fixed shots" },
            { name = "no set pieces either" },
            { name = "nothing at all" },
        },
    },

    {
        key = "camangle", id = "cj", name = "Nobody may switch camera style",
        blurb = "locks the R-trigger camera swap to the lobby's style",

        levels = {
            { name = "neither way" },
            { name = "Lakitu's camera only", allow = CAM_ANGLE_LAKITU or 2 },
            { name = "Mario's camera only", allow = CAM_ANGLE_MARIO or 1 },
        },
    },

    {
        key = "nocoins", id = "nc", name = "Coins cannot be picked up",
        blurb = "every coin stays where it is, whatever it came out of",

    },

    {
        key = "nostomp", id = "ns", name = "Nothing may be stomped",
        blurb = "landing on an enemy does nothing at all",
    },

    {
        key = "nocarry", id = "ng", name = "Nothing may be picked up",
        blurb = "nothing carried anywhere, or only from a standstill",

        levels = {
            { name = "not at all" },
            { name = "not unless you stand still", still = true },
        },
    },

    {
        key = "nosigns", id = "ni", name = "Signs and characters say nothing",
        blurb = "nobody stops you to talk and no sign reads",
    },

    {
        key = "nobreak", id = "nk", name = "Nothing breaks",
        blurb = "boxes and blocks stay up however hard you hit them",
    },

    {
        key = "nopoles", id = "nz", name = "Poles cannot be held",
        blurb = "trees and poles are scenery, not a way up",
    },

    {
        key = "nocaps", id = "nq", name = "Caps cannot be picked up",
        blurb = "a cap on the ground is scenery; all three, or just one",

        levels = {
            { name = "every cap" },
            { name = "the Wing Cap", cap = "wing" },
            { name = "the Metal Cap", cap = "metal" },
            { name = "the Vanish Cap", cap = "vanish" },
        },
    },

    {
        key = "caminvert", id = "ci", name = "The camera is inverted",
        blurb = "the camera axes, flipped for the whole lobby",
        levels = {
            { name = "left is right", invx = true },
            { name = "up is down", invy = false },
            { name = "both at once", invx = true, invy = false },
        },
        world = function() modifiers.wear_caminvert(true) end,
        restore = function() modifiers.wear_caminvert(false) end,
    },

    {
        key = "camdrive", id = "cf", name = "What moves the camera",
        blurb = "the stick, D-pad or mouse instead of the C buttons",
        levels = {
            { name = "the right stick", analog = true, dpad = false, mouse = false },
            { name = "the D-pad as well", analog = true, dpad = true, mouse = false },
            { name = "the D-pad alone", analog = false, dpad = true, mouse = false },
            { name = "the mouse, on a PC", analog = true, dpad = false, mouse = true },
        },
        world = function() modifiers.wear_camdrive(true) end,
        restore = function() modifiers.wear_camdrive(false) end,
    },

    {
        key = "breathe", id = "bh", name = "The view never sits still",
        blurb = "the view will not quite sit still",
        levels = {
            { name = "a slow swell", amp = 0x100, speed = 0x200 },
            { name = "seasick", amp = 0x300, speed = 0x400 },
            { name = "a heartbeat", amp = 0x180, speed = 0x900 },
            { name = "something is very wrong", amp = 0x600, speed = 0xC00 },
        },
        apply = function() modifiers.hold_breathe() end,
    },

    {
        key = "pitch", id = "ph", name = "Everything sounds wrong",
        blurb = "every sound in the game, played at the wrong speed",
        levels = {
            { name = "the world is huge", freq = 0.55 },
            { name = "a little slow", freq = 0.8 },
            { name = "a little fast", freq = 1.3 },
            { name = "the world is tiny", freq = 1.9 },

            { name = "underwater", freq = 0.33 },
            { name = "wasps", freq = 2.6 },

            { name = "it follows your height", low = 0.7, high = 1.6 },

            { name = "every sound is another one", shuffle = true },
        },

        apply = function(m) modifiers.hold_pitch(m) end,
    },

    {
        key = "bank", id = "bk", name = "One set of instruments",

        blurb = "every track on one soundfont - recordings keep theirs",
        levels = {

            { name = "the outdoor courses", bank = 34 },
            { name = "inside the castle", bank = 14 },
            { name = "the water courses", bank = 19 },
            { name = "the fire courses", bank = 15 },
            { name = "the snow courses", bank = 11 },
            { name = "the slides", bank = 13 },
            { name = "Bowser's Road", bank = 25 },
            { name = "the boss fights", bank = 27 },

            { name = "Big Boo's Haunt", bank = 16 },
            { name = "the title screen", bank = 17 },
            { name = "Bowser's battle", bank = 18 },
            { name = "the Piranha Plant's lullaby", bank = 20 },
            { name = "the caves", bank = 21 },
            { name = "the star select", bank = 22 },
            { name = "the wing cap", bank = 23 },
            { name = "the metal cap", bank = 24 },
            { name = "the race fanfare", bank = 26 },
            { name = "the endless stairs", bank = 28 },
            { name = "Bowser's organ", bank = 29 },
            { name = "Peach's letter", bank = 30 },
            { name = "a new record", bank = 31 },
            { name = "Toad", bank = 32 },
            { name = "the merry-go-round", bank = 33 },
            { name = "the ending", bank = 35 },
            { name = "the file select", bank = 36 },
            { name = "the credits", bank = 37 },
        },
        world = function() modifiers.wear_bank(true) end,
        restore = function() modifiers.wear_bank(false) end,
    },

    {
        key = "gate", id = "gt", name = "The shape of the stick's gate",
        blurb = "how far the stick reaches; off is a circle, no corners",
        levels = {

            { name = "an octagon", gate = "octagon" },

            { name = "a square", gate = "square" },

            { name = "a triangle", gate = "triangle" },

            { name = "a cross", gate = "cross" },
        },
    },

    {
        key = "deadzone", id = "dz", name = "The stick's dead zone",
        blurb = "how far the stick moves before anything happens",
        levels = {

            { name = "none at all", dead = 0, raw = true },
            { name = "a nudge is ignored", dead = 6 },
            { name = "a quarter of the stick", dead = 16 },
            { name = "a third of the stick", dead = 21 },
            { name = "half the stick", dead = 32 },
        },
    },

    {
        key = "saturate", id = "st", name = "Where the stick counts as full",
        blurb = "how far the stick must go before it asks for everything",
        levels = {
            { name = "three quarters out", full = 48 },
            { name = "halfway out", full = 32 },
            { name = "a third of the way", full = 21 },
            { name = "a nudge is a sprint", full = 12 },
        },
    },

    {
        key = "fastest", id = "sm", name = "Shared momentum",
        blurb = "nobody moves slower than the fastest player around",
        apply = function(m) modifiers.hold_shared_speed(m) end,
    },

    {
        key = "lobbylight", id = "lt", name = "How everybody is lit",
        blurb = "every player's light colour, and their shaded side",
        excludes = { "ownlight" },
        levels = {

            { name = "warm light, blue shadows",
              light = { 255, 225, 115 }, shade = { 19, 58, 212 } },
            { name = "cold light, black shadows",
              light = { 180, 210, 255 }, shade = { 35, 45, 80 } },
            { name = "candlelight",
              light = { 255, 170, 80 }, shade = { 70, 35, 25 } },

            { name = "hard noon",
              light = { 255, 255, 255 }, shade = { 40, 40, 45 } },

            { name = "no shaded side at all",
              light = { 255, 255, 255 }, shade = { 255, 255, 255 } },
            { name = "sickly",
              light = { 160, 255, 120 }, shade = { 60, 90, 50 } },
            { name = "under water",
              light = { 120, 190, 220 }, shade = { 20, 45, 70 } },
        },
        restore = function() return modifiers.clear_body_light() end,
    },

    {
        key = "ownlight", id = "ow", name = "Everybody in their own light",
        blurb = "every player lit a different way, and nothing on the wire",
        excludes = { "lobbylight" },
        levels = {
            { name = "one each, by seat", seats = true },

            { name = "one each, by side", team = true },

            { name = "warm for you, cold for everybody else", mine = true },
        },
        restore = function() return modifiers.clear_body_light() end,
    },

    {
        key = "texshuffle", id = "ts", name = "Texture shuffle",
        blurb = "any texture in the game, swapped for another at random",
        levels = { { name = "on" } },
        excludes = { "texswap" },
    },

    {
        key = "texswap", id = "tw", name = "Texture swap",
        blurb = "walls and floors in the mod's own textures, kind for kind",
        levels = { { name = "on" } },
        excludes = { "texshuffle" },
    },

    {
        key = "paintswap", id = "pw", name = "Painting swap",
        blurb = "every painting in the mod's own picture of its own course",
        levels = { { name = "on" } },
    },

    {
        key = "jelly", id = "jp", name = "The paintings wobble",
        blurb = "walk past a painting and it never settles again",
        levels = {
            { name = "like jelly", mag = 3, rate = 1 },
            { name = "like a waterbed", mag = 6, rate = 0.5 },
        },
        world = function(level) modifiers.wobble_paintings(level) end,
        restore = function() modifiers.wobble_paintings(nil) end,
    },
}

function modifiers.wear_bank(on)
    if OF.util.binding("set_sound_bank_override") == nil then return false end
    local bank = nil
    if on then
        bank = modifiers.setting("bank", "bank", nil)
        if type(bank) ~= "number" then return false end
    end

    if not OF.util.asks(OF.music, "wear_bank") then return false end
    OF.music.wear_bank(bank)

    if not on and OF.util.asks(OF.music, "restore_banks") then
        OF.music.restore_banks()

        if OF.util.asks(OF.music, "free_the_voice") then
            OF.music.free_the_voice()
        end
    end
    if OF.util.asks(OF.music, "play_again") then OF.music.play_again() end
    return true
end

do

local STEP_REACH = 160

local CARVE_MOST = 512

local MOMENTUM_STICK = 8

local MOMENTUM_STOPPED = 1

local momentumHeld = 0

function modifiers.forget_momentum()
    momentumHeld = 0
    return true
end

function modifiers.momentum_held()
    return momentumHeld
end

function modifiers.momentum_note()
    if modifiers.level("momentum") <= 0 then return nil end
    return OF.lang.t("No top of any kind - brake to be rid of what you built.")
end

local WALK_CLAMP_FACTOR = 48 / 32

function modifiers.quick_note()
    if modifiers.setting("quick", "speed", 1) <= WALK_CLAMP_FACTOR then
        return nil
    end
    return OF.lang.t("Past this a plain run is capped - it tells in the air.")
end

local POCKET_FULL = 30

local POCKET_SLOW = 0.72
local POCKET_FAST = 1.8

function modifiers.quick_speed(m)
    if modifiers.level("quick") <= 0 then return nil end
    local flat = modifiers.setting("quick", "speed", nil)
    if flat ~= nil then return flat end

    local pocket = modifiers.setting("quick", "pocket", 0)
    if pocket == 0 then return nil end

    local coins = tonumber(m ~= nil and m.numCoins or nil) or 0
    if coins < 0 then coins = 0 end
    if coins > POCKET_FULL then coins = POCKET_FULL end
    local share = coins / POCKET_FULL

    if pocket < 0 then share = 1 - share end
    return POCKET_SLOW + (POCKET_FAST - POCKET_SLOW) * share
end

function modifiers.hold_momentum(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("momentum") <= 0 then return false end

    if not OF.util.can_play(0) then
        momentumHeld = 0
        return false
    end

    local now = tonumber(m.forwardVel) or 0
    if OF.util.stopping(m) or now < 0 then
        momentumHeld = 0
        return false
    end

    local still = type(ACT_FLAG_STATIONARY) == "number"
        and OF.util.has_flag(m.action or 0, ACT_FLAG_STATIONARY)
    local grounded = type(ACT_FLAG_AIR) ~= "number" or not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
    if still or (grounded and now < MOMENTUM_STOPPED) then
        momentumHeld = 0
        return false
    end

    if (tonumber(m.intendedMag) or 0) <= MOMENTUM_STICK then
        momentumHeld = math.max(0, now)
        return false
    end

    if now > momentumHeld then momentumHeld = now end

    local gain = modifiers.setting("momentum", "gain", 0)
    if gain > 0 then
        momentumHeld = momentumHeld + gain
    end

    return OF.util.speed_up(m, momentumHeld, true)
end

local hitFrames = 0

local hitHeading = 0
local hitSpeed = 0

local hitBackward = false

local hitRide = 0

local RIDE_FRAMES = 60

local RIDE_ARC = 0x2000

local function fold_angle(value)
    return ((value + 0x8000) % 0x10000) - 0x8000
end

local function in_a_hit(m)
    if m == nil or m.action == nil then return false end
    if not OF.util.asks(OF.cheats, "is_knockback") then return false end
    return OF.cheats.is_knockback(m.action) == true
end

local function watch_the_hit(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if modifiers.level("tech") <= 0 and modifiers.level("ridekb") <= 0 then
        hitFrames = 0
        hitRide = 0
        return
    end

    if hitRide > 0 then hitRide = hitRide - 1 end

    if not in_a_hit(m) then
        hitFrames = 0
        return
    end

    if hitFrames == 0 then
        local speed = tonumber(m.forwardVel) or 0
        local face = 0
        if m.faceAngle ~= nil then face = tonumber(m.faceAngle.y) or 0 end

        hitBackward = speed < 0
        if hitBackward then face = face + 0x8000 end
        hitHeading = fold_angle(face)
        hitSpeed = math.abs(speed)
        hitRide = RIDE_FRAMES
    end
    hitFrames = hitFrames + 1
end

hook_event(HOOK_MARIO_UPDATE, watch_the_hit, OF.LOCAL_MARIO)

function modifiers.hit_frames()
    return hitFrames
end

function modifiers.hit_speed()
    return hitSpeed
end

function modifiers.hit_ride_left()
    return hitRide
end

function modifiers.tech_out(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local window = modifiers.setting("tech", "frames", 0)
    if window <= 0 then return false end
    if not OF.util.can_play(0) then return false end
    if not in_a_hit(m) then return false end
    if hitFrames > window then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then return false end
    if not OF.util.has_flag(m.input or 0, INPUT_Z_PRESSED) then return false end

    local roll = ACT_FORWARD_ROLLOUT
    if hitBackward then roll = ACT_BACKWARD_ROLLOUT end
    if roll == nil then return false end
    set_mario_action(m, roll, 0)

    hitFrames = 0
    hitRide = 0
    return true
end

function modifiers.ride_the_hit(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("ridekb") <= 0 then return false end
    if not OF.util.can_play(0) then return false end
    if hitRide <= 0 or hitSpeed <= 0 then return false end

    if in_a_hit(m) then return false end

    local face = 0
    if m.faceAngle ~= nil then face = tonumber(m.faceAngle.y) or 0 end
    local off = fold_angle(face - hitHeading)
    if off < 0 then off = -off end
    if off > RIDE_ARC then return false end

    return OF.util.speed_up(m, hitSpeed, true)
end

function modifiers.forget_the_hit()
    hitFrames = 0
    hitRide = 0
    hitSpeed = 0
    hitHeading = 0
    hitBackward = false
    return true
end

local carving = false

local function one_part(m, stepType, stepArg)
    if stepType == STEP_TYPE_GROUND then return perform_ground_step(m) end
    return perform_air_step(m, stepArg)
end

function modifiers.carve_step(m, stepType, stepArg)
    if carving then return nil end
    if m == nil or m.playerIndex ~= 0 then return nil end
    if stepType ~= STEP_TYPE_GROUND and stepType ~= STEP_TYPE_AIR then return nil end
    if modifiers.level("momentum") <= 0 then return nil end
    if not OF.util.can_play(0) then return nil end
    if m.action == ACT_FLYING then return nil end
    if OF.util.asks(OF.underside, "held") and OF.underside.held(m) then
        return nil
    end

    if OF.util.asks(OF.cheats, "owns_step") and OF.cheats.owns_step(m) then
        return nil
    end

    local vel = m.vel
    if vel == nil then return nil end
    local vx = tonumber(vel.x) or 0
    local vz = tonumber(vel.z) or 0

    if stepType == STEP_TYPE_GROUND then
        local before = tonumber(m.forwardVel) or 0
        if before > 0 and OF.util.speed_up(m, momentumHeld, true) then
            local ratio = ((tonumber(m.forwardVel) or before) / before)
            vx, vz = vx * ratio, vz * ratio
            vel.x, vel.z = vx, vz
            m.slideVelX = (tonumber(m.slideVelX) or 0) * ratio
            m.slideVelZ = (tonumber(m.slideVelZ) or 0) * ratio
        end
    end

    local flat = math.sqrt(vx * vx + vz * vz)

    if not (flat > STEP_REACH) then return nil end

    local parts
    if flat > STEP_REACH * CARVE_MOST then
        parts = CARVE_MOST
    else
        parts = math.ceil(flat / STEP_REACH)
    end
    local slice = 1 / parts

    local restY = tonumber(vel.y) or 0
    local peak = tonumber(m.peakHeight)

    local answer = nil
    local stopped = false
    local carried = 0
    carving = true
    while carried < parts - 1 do
        vel.x, vel.z = vx * slice, vz * slice
        if stepType == STEP_TYPE_AIR then vel.y = 0 end
        local said = one_part(m, stepType, stepArg)
        carried = carried + 1

        if stepType == STEP_TYPE_GROUND then
            if said == GROUND_STEP_LEFT_GROUND
                or said == GROUND_STEP_HIT_WALL_STOP_QSTEPS then
                answer = said
                stopped = true
                break
            end
        else
            if said ~= AIR_STEP_NONE then answer = said end
            if said == AIR_STEP_LANDED or said == AIR_STEP_GRABBED_LEDGE
                or said == AIR_STEP_GRABBED_CEILING
                or said == AIR_STEP_HIT_LAVA_WALL then
                stopped = true
                break
            end
        end
    end

    vel.x, vel.z = vx * slice, vz * slice
    if stepType == STEP_TYPE_AIR then
        vel.y = restY
        if peak ~= nil then m.peakHeight = peak end
    end

    if answer == nil then

        carving = false
        return nil
    end
    if not stopped then

        local said = one_part(m, stepType, stepArg)
        if said ~= AIR_STEP_NONE then answer = said end
    end
    carving = false
    return answer
end

hook_event(HOOK_BEFORE_PHYS_STEP, modifiers.carve_step)

end

do

    local wasUp = false
    local fellFrom = nil
    local streak = 0

    local BOUNCE_FROM = 300

    local BOUNCE_MOST = 94

    function modifiers.softland_clears_the_fall()
        if modifiers.level("softland") <= 0 then return false end
        return modifiers.setting("softland", "cap", nil) == nil
    end

    function modifiers.covers_cheat(key)
        if key ~= "softland" then return true end
        return modifiers.softland_clears_the_fall()
    end

    function modifiers.forget_the_landing()
        wasUp = false
        fellFrom = nil
        streak = 0
    end

    function modifiers.hold_the_landing(m)
        if m == nil or m.playerIndex ~= 0 then return end
        if type(m.action) ~= "number" or m.pos == nil then return end

        local up = ACT_FLAG_AIR ~= nil and (m.action & ACT_FLAG_AIR) ~= 0

        local cap = modifiers.setting("softland", "cap", nil)
        if cap ~= nil then

            if type(m.peakHeight) == "number" and m.peakHeight - m.pos.y > cap then
                m.peakHeight = m.pos.y + cap
            end
            wasUp, fellFrom, streak = up, nil, 0
            return
        end

        local bounce = modifiers.setting("softland", "bounce", nil)
        if bounce == nil then
            wasUp, fellFrom, streak = up, nil, 0
            return
        end

        if up then

            if not wasUp or fellFrom == nil or m.pos.y > fellFrom then
                fellFrom = m.pos.y
            end
            wasUp = true
            return
        end

        if wasUp and fellFrom ~= nil and m.vel ~= nil
            and fellFrom - m.pos.y >= BOUNCE_FROM then
            local more = modifiers.setting("softland", "more", nil)
            local want = bounce
            if more ~= nil then
                want = bounce + streak * more
                if want > BOUNCE_MOST then want = BOUNCE_MOST end
                streak = streak + 1
            else
                streak = 0
            end

            if set_mario_action ~= nil then
                set_mario_action(m, ACT_JUMP, 0)
            end
            m.vel.y = want

            m.peakHeight = m.pos.y
        else
            streak = 0
        end
        wasUp = false
        fellFrom = nil
    end
end

do

local BREATH_BACK = 0x1A

local ONE_WEDGE = 0x100

local FULL_METER = 0x880

function modifiers.invert_water_note()
    if modifiers.level("invertwater") <= 0 then return nil end
    if water_is_the_rounds() then
        return OF.lang.t("The round owns the water - this is standing down.")
    end
    if water_is_ours() then return nil end
    return OF.lang.t("No water here to breathe - only air, and it drowns.")
end

function modifiers.hold_invert_water(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("invertwater") <= 0 then return false end
    if water_is_the_rounds() then return false end
    if not OF.util.can_play(0) then return false end

    local health = tonumber(m.health) or 0
    if health < ONE_WEDGE then return false end
    if (tonumber(m.hurtCounter) or 0) ~= 0 then return false end
    if (tonumber(m.healCounter) or 0) ~= 0 then return false end
    if OF.util.has_flag(m.input or 0, INPUT_IN_POISON_GAS) then return false end
    if OF.util.has_flag(m.flags or 0, MARIO_METAL_CAP) then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_INTANGIBLE) then return false end
    if group_of(m.action or 0) == ACT_GROUP_CUTSCENE then return false end

    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then

        if health >= FULL_METER then return false end
        m.health = math.min(FULL_METER, health + BREATH_BACK)
        return true
    end

    local drain = modifiers.setting("invertwater", "drain", 1)
    local left = health - drain
    if left < ONE_WEDGE then left = ONE_WEDGE - 1 end
    m.health = left
    return true
end

end

function modifiers.tally_coin(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return false end
    if interactType ~= INTERACT_COIN then return false end
    local perCoin = modifiers.setting("budget", "coin", nil)
    if perCoin == nil or o == nil then return false end
    modifiers.refund_press(OF.util.coin_worth(o) * perCoin)
    return true
end

do

    local DIALS = {
        aggression  = { "camera_config_get_aggression",     "camera_config_set_aggression" },
        pan         = { "camera_config_get_pan_level",      "camera_config_set_pan_level" },
        decel       = { "camera_config_get_deceleration",   "camera_config_set_deceleration" },
        sensitivity = { "camera_config_get_x_sensitivity",  "camera_config_set_x_sensitivity" },
        sensitivityY= { "camera_config_get_y_sensitivity",  "camera_config_set_y_sensitivity" },
        centering   = { "camera_config_get_centering",      "camera_config_enable_centering" },
        collision   = { "camera_config_is_collision_enabled", "camera_config_enable_collisions" },

        invertX     = { "camera_config_is_x_inverted",      "camera_config_invert_x" },
        invertY     = { "camera_config_is_y_inverted",      "camera_config_invert_y" },
        analog      = { "camera_config_is_analog_cam_enabled", "camera_config_enable_analog_cam" },
        dpad        = { "camera_config_is_dpad_enabled",    "camera_config_enable_dpad" },
        mouse       = { "camera_config_is_mouse_look_enabled", "camera_config_enable_mouse_look" },
    }

    modifiers.camHeld = modifiers.camHeld or setmetatable({}, {
        __index = function(_, dial)
            return OF.util.setting_was("cam." .. tostring(dial))
        end,
    })

    local DIAL_HOLDER = "modifiers"
    function modifiers.lend_camera(dial, value)
        local pair = DIALS[dial]
        if pair == nil then return false end
        return OF.util.lend_setting("cam." .. dial, DIAL_HOLDER,
            pair[1], pair[2], value)
    end

    function modifiers.return_camera(dial)
        local pair = DIALS[dial]
        if pair == nil then return false end
        if OF.util.setting_was("cam." .. dial) == nil then return true end
        if OF.util.binding(pair[2]) == nil then return false end
        return OF.util.return_setting("cam." .. dial, DIAL_HOLDER)
    end

    function modifiers.wear_camaggr(on)
        if not on then return modifiers.return_camera("aggression") end
        local want = modifiers.setting("camaggr", "aggr", nil)
        if want == nil then return false end
        return modifiers.lend_camera("aggression", want)
    end

    function modifiers.wear_campan(on)
        if not on then return modifiers.return_camera("pan") end
        local want = modifiers.setting("campan", "pan", nil)
        if want == nil then return false end
        return modifiers.lend_camera("pan", want)
    end

    function modifiers.wear_camdrag(on)
        if not on then return modifiers.return_camera("decel") end
        local want = modifiers.setting("camdrag", "decel", nil)
        if want == nil then return false end
        return modifiers.lend_camera("decel", want)
    end

    function modifiers.wear_camstick(on)
        if not on then
            local a = modifiers.return_camera("sensitivity")
            local b = modifiers.return_camera("sensitivityY")
            return a and b
        end
        local want = modifiers.setting("camstick", "sens", nil)
        if want == nil then return false end
        local a = modifiers.lend_camera("sensitivity", want)
        local b = modifiers.lend_camera("sensitivityY", want)
        return a and b
    end

    function modifiers.wear_camwall(on)
        if not on then return modifiers.return_camera("collision") end

        return modifiers.lend_camera("collision", false)
    end

    function modifiers.wear_camcentre(on)
        if not on then return modifiers.return_camera("centering") end
        return modifiers.lend_camera("centering", false)
    end
end

do

    local NO_NEAR = 0

    local NEAR_PER_TICK = 0.15

    local NEAR_RUN_VEL = 32.0

    local nearShare = 0.0

    function modifiers.forget_near()
        nearShare = 0.0
    end

    function modifiers.near_share()
        return nearShare
    end

    function modifiers.near_plane()
        local want = modifiers.setting("near", "near", nil)
        if want == nil then return nil end
        local reach = modifiers.setting("near", "reach", nil)
        if reach == nil then return want end
        return want + (reach - want) * nearShare
    end

    function modifiers.near_frame()
        local reach = modifiers.setting("near", "reach", nil)
        if reach == nil then
            modifiers.forget_near()
            return
        end

        local m = gMarioStates ~= nil and gMarioStates[0] or nil
        local want = 0
        if m ~= nil then
            local vel = type(m.forwardVel) == "number"
                and math.abs(m.forwardVel) or 0
            want = OF.util.clamp(vel / NEAR_RUN_VEL, 0, 1)
        end
        nearShare = nearShare + (want - nearShare) * NEAR_PER_TICK

        if OF.util.binding("set_override_near") == nil then return end
        OF.util.optional("set_override_near", nil,
            modifiers.near_plane() or NO_NEAR)
    end

    function modifiers.wear_near(on)
        if OF.util.binding("set_override_near") == nil then return false end
        if not on then
            modifiers.forget_near()
            OF.util.optional("set_override_near", nil, NO_NEAR)
            return true
        end
        modifiers.forget_near()
        local want = modifiers.near_plane()
        if want == nil then return false end
        OF.util.optional("set_override_near", nil, want)
        return true
    end

    hook_event(HOOK_UPDATE, function() modifiers.near_frame() end)
end

do

    local FIXED_ONLY = {
        [CAMERA_MODE_FIXED or -1] = true,
        [CAMERA_MODE_PARALLEL_TRACKING or -2] = true,
        [CAMERA_MODE_8_DIRECTIONS or -3] = true,
    }
    local AND_THE_SET_PIECES = {
        [CAMERA_MODE_WATER_SURFACE or -4] = true,
        [CAMERA_MODE_INSIDE_CANNON or -5] = true,
        [CAMERA_MODE_BOSS_FIGHT or -6] = true,
        [CAMERA_MODE_SLIDE_HOOT or -7] = true,
        [CAMERA_MODE_SPIRAL_STAIRS or -8] = true,
    }

    function modifiers.camera_mode_refused(mode)
        local step = modifiers.level("camlock")
        if step <= 0 then return false end
        if step >= 3 then return true end
        if FIXED_ONLY[mode] then return true end
        if step >= 2 and AND_THE_SET_PIECES[mode] then return true end
        return false
    end

    hook_event(HOOK_ON_SET_CAMERA_MODE, function(c, mode, frames)
        if modifiers.camera_mode_refused(mode) then return false end
    end)

    function modifiers.camera_angle_refused(angle)
        if modifiers.level("camangle") <= 0 then return false end
        local allow = modifiers.setting("camangle", "allow", nil)

        if allow == nil then return true end
        return angle ~= allow
    end

    hook_event(HOOK_ON_CHANGE_CAMERA_ANGLE, function(angle)
        if modifiers.camera_angle_refused(angle) then return false end
    end)

end

do

    local REFUSED = {
        nocoins = INTERACT_COIN,
        nostomp = (INTERACT_BOUNCE_TOP or 0) | (INTERACT_BOUNCE_TOP2 or 0),
        nocarry = INTERACT_GRABBABLE,
        nosigns = INTERACT_TEXT,
        nobreak = INTERACT_BREAKABLE,
        nopoles = INTERACT_POLE,
        nocaps = INTERACT_CAP,
    }

    local STILL_SPEED = 1.0

    local function standing_still(m)
        if m == nil or type(m.forwardVel) ~= "number" then return false end
        if type(m.action) == "number" and ACT_FLAG_AIR ~= nil
            and (m.action & ACT_FLAG_AIR) ~= 0 then return false end
        return m.forwardVel > -STILL_SPEED and m.forwardVel < STILL_SPEED
    end

    local CAP_ID = {
        wing   = id_bhvWingCap,
        metal  = id_bhvMetalCap,
        vanish = id_bhvVanishCap,
    }

    local function is_that_cap(o, which)
        local want = CAP_ID[which]
        if want == nil or o == nil or obj_has_behavior_id == nil then
            return false
        end
        return OF.util.optional("obj_has_behavior_id", 0, o, want) ~= 0
    end

    local CONDITION = {

        nocarry = function(m)
            if modifiers.setting("nocarry", "still", nil) ~= true then
                return true
            end
            return not standing_still(m)
        end,
        nocaps = function(_, o)
            local which = modifiers.setting("nocaps", "cap", nil)
            if which == nil then return true end
            return is_that_cap(o, which)
        end,
    }

    function modifiers.interaction_refused(interactType, m, o)
        if type(interactType) ~= "number" then return false end
        for key, mask in pairs(REFUSED) do
            if mask ~= nil and mask ~= 0
                and (interactType & mask) ~= 0
                and modifiers.level(key) > 0 then
                local extra = CONDITION[key]
                if extra == nil or extra(m, o) then return true end
            end
        end
        return false
    end

    hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)

        if m == nil or m.playerIndex ~= 0 then return end

        if modifiers.interaction_refused(interactType, m, o) then return false end
    end)
end

do
    modifiers.camHeld = modifiers.camHeld or {}

    function modifiers.wear_caminvert(on)
        if not on then
            local a = modifiers.return_camera("invertX")
            local b = modifiers.return_camera("invertY")
            return a and b
        end
        local x = modifiers.setting("caminvert", "invx", nil)
        local y = modifiers.setting("caminvert", "invy", nil)
        local ok = true

        if x ~= nil then ok = modifiers.lend_camera("invertX", x) and ok end
        if y ~= nil then ok = modifiers.lend_camera("invertY", y) and ok end
        return ok
    end

    function modifiers.wear_camdrive(on)
        if not on then
            local a = modifiers.return_camera("analog")
            local b = modifiers.return_camera("dpad")
            local c = modifiers.return_camera("mouse")
            return a and b and c
        end
        local analog = modifiers.setting("camdrive", "analog", nil)
        local dpad = modifiers.setting("camdrive", "dpad", nil)
        local mouse = modifiers.setting("camdrive", "mouse", nil)
        local ok = true
        if analog ~= nil then ok = modifiers.lend_camera("analog", analog) and ok end
        if dpad ~= nil then ok = modifiers.lend_camera("dpad", dpad) and ok end
        if mouse ~= nil then ok = modifiers.lend_camera("mouse", mouse) and ok end
        return ok
    end
end

do
    function modifiers.hold_breathe()
        if OF.util.binding("set_fov_shake") == nil then return false end
        if modifiers.level("breathe") <= 0 then return false end

        if not OF.util.can_play(0) then return false end
        local amp = modifiers.setting("breathe", "amp", nil)
        local speed = modifiers.setting("breathe", "speed", nil)
        if amp == nil then return false end

        OF.util.optional("set_fov_shake", nil, amp, 30, speed)
        return true
    end
end

do
    local bandCount, bandLow, bandHigh = nil, nil, nil

    hook_event(HOOK_ON_CLEAR_AREAS, function()
        bandCount, bandLow, bandHigh = nil, nil, nil
    end)

    local function height_fraction(m)
        if m == nil or m.pos == nil then return nil end
        if not OF.util.asks(OF.ground, "counted")
            or not OF.util.asks(OF.ground, "lowest")
            or not OF.util.asks(OF.ground, "highest") then
            return nil
        end
        local counted = OF.ground.counted()
        if counted ~= bandCount then
            bandCount = counted
            bandLow, bandHigh = OF.ground.lowest(), OF.ground.highest()
        end
        if type(bandLow) ~= "number" or type(bandHigh) ~= "number" then
            return nil
        end
        local span = bandHigh - bandLow

        if span < 1 then return nil end
        local here = tonumber(m.pos.y)
        if here == nil then return nil end

        local fraction = (here - bandLow) / span
        if fraction < 0 then return 0 end
        if fraction > 1 then return 1 end
        return fraction
    end
    modifiers.height_fraction = height_fraction

    modifiers.pitchSwing = modifiers.pitchSwing or nil

    function modifiers.hold_pitch(m)
        local low = modifiers.setting("pitch", "low", nil)
        local high = modifiers.setting("pitch", "high", nil)
        if low == nil or high == nil then
            modifiers.pitchSwing = nil
            return false
        end
        local fraction = height_fraction(m)
        if fraction == nil then
            modifiers.pitchSwing = nil
            return false
        end
        modifiers.pitchSwing = low + (high - low) * fraction
        return true
    end

    local replaying = false

    function modifiers.pitch_for(soundBits, pos)
        if replaying then return nil end
        if type(soundBits) ~= "number" then return nil end
        local scale = modifiers.setting("pitch", "freq", nil)

        if scale == nil and modifiers.setting("pitch", "low", nil) ~= nil then
            scale = modifiers.pitchSwing
        end
        if scale == nil then return nil end
        if OF.util.binding("play_sound_with_freq_scale") == nil then return nil end

        replaying = true
        OF.util.optional("play_sound_with_freq_scale", nil, soundBits, pos, scale)
        replaying = false

        return NO_SOUND or 0
    end
end

modifiers.ROW_RANK = "speedrun"
modifiers.GROUPS = {

    { home = "body", name = "How everybody moves",
      help = "what the lobby's body does - weight, speed, landings and grip",

      keys = { "upsidedown", "quick", "tech", "ridekb", "coinhit",
               "softland", "floor" } },

    { home = "body", name = "The speed you carry",
      help = "whose speed it is and whether the ground may ask any of it back",
      keys = { "momentum", "fastest" } },

    { home = "harsh", name = "A level that fights back",
      help = "a floor that burns, water that rises over you, and air you cannot breathe",
      keys = { "lava", "water", "invertwater" } },

    { home = "visuals", name = "The sky and the hour",
      help = "which sky, its colour and brightness, the hour and the dark",
      keys = { "night", "skycolour", "skybright", "sun", "dark" } },

    { home = "visuals", name = "Weather and light",
      help = "the air, what is falling out of it, and a light of your own",
      keys = { "fog", "snow", "lantern" } },

    { home = "visuals", name = "The light and the shadow", tail = "lightshow",
      help = "the paint on the level, the lighting model and the shadows under everybody",
      keys = { "tint", "flat", "shading", "shadow", "texshuffle", "texswap", "paintswap", "jelly" } },

    { home = "shapes", name = "How a body carries itself",
      help = "what everybody's face is doing, how they stand and what comes off them",

      keys = { "face", "posture", "trail", "anim",
               "lobbylight", "ownlight" } },

    { home = "controls", name = "What you may press",
      help = "which moves and which buttons exist at all, and how late a press may arrive",
      keys = { "learn", "budget", "buttons", "controls", "delay", "buffer" } },

    { home = "controls", name = "The stick itself",
      help = "the plastic under your thumb: its shape, its dead zone and its rim",
      keys = { "gate", "deadzone", "saturate" } },

    { home = "controls", name = "What a ground pound does",
      help = "what a landing sets off under your feet, and how it has to be dodged",
      keys = { "cluster", "wave", "shove" } },

    { home = "camera", name = "The camera",
      help = "where the game's own camera stands, how wide it sees and how it follows",
      keys = { "fisheye", "view", "camlag", "quake", "breathe" } },

    { home = "camera", name = "The camera you are given",
      help = "what may take the shot away from a player, and how hard it chases",
      keys = { "camaggr", "campan", "camdrag", "camwall", "camcentre",
               "camlock", "camangle" } },

    { home = "camera", name = "How the camera is driven",
      help = "the hand on the camera: how fast it turns and which way round it is",
      keys = { "camstick", "caminvert", "camdrive" } },

    { home = "camera", name = "The frame it is drawn in",
      help = "which way up the picture is, how much of it you get and how far it reaches",
      keys = { "horizon", "mirror", "blinders", "near" } },

    { home = "music", name = "What the lobby sounds like",
      help = "the music, the voices and the noise underfoot",
      keys = { "voice", "music", "quiet", "steps", "pitch", "bank" } },

    { home = "rules", name = "The level itself",
      help = "what the course is made of - its water, its ground and a flower to stand on",
      keys = { "dry", "swim", "whirl", "carousel", "cloud" } },
    { home = "rules", name = "What may be touched",
      help = "what the lobby allows a player to pick up, break, stomp or hold",
      keys = { "nocoins", "nostomp", "nocarry", "nosigns", "nobreak",
               "nopoles", "nocaps" } },

    { home = "rules", name = "What a star does",
      help = "where an earned star comes to rest, and what it pays",
      keys = { "starhome", "cards" } },
}

modifiers.HOMELESS = {
    demon = "its own page, Green Demon, beside Chaos and the Randomizer",
    clones = "its own page, Cosmic Clones, beside the Green Demon's",
    spray = "its own page, Spray paint, beside the Cosmic Clones'",
    lowgrav = "drawn as the cheat of the same name (his third playtest list §18)",
    giant = "drawn as the cheat of the same name (his third playtest list §18)",
    tiny = "drawn as the cheat of the same name (his third playtest list §18)",
}

modifiers.UNGROUPED = "Everything else"
function modifiers.grouped(home)
    local where = {}
    for index, group in ipairs(modifiers.GROUPS) do
        for _, key in ipairs(group.keys) do where[key] = index end
    end

    local buckets = {}
    for index = 1, #modifiers.GROUPS do buckets[index] = {} end
    local rest = {}

    for _, entry in ipairs(modifiers.LIST) do
        local index = where[entry.key]
        if index == nil then
            if modifiers.HOMELESS[entry.key] == nil then
                table.insert(rest, entry)
            end
        else
            table.insert(buckets[index], entry)
        end
    end

    local out = {}
    for index, group in ipairs(modifiers.GROUPS) do
        if #buckets[index] > 0 and (home == nil or group.home == home) then
            table.insert(out, { name = group.name, tail = group.tail,
                says = group.says, help = group.help,
                entries = buckets[index] })
        end
    end
    if home == nil and #rest > 0 then
        table.insert(out, { name = modifiers.UNGROUPED,
            help = "modifiers no heading has claimed yet",
            entries = rest })
    end
    return out
end

function modifiers.homes()
    local seen, out = {}, {}
    for _, group in ipairs(modifiers.GROUPS) do
        if group.home ~= nil and not seen[group.home] then
            seen[group.home] = true
            table.insert(out, group.home)
        end
    end
    return out
end

modifiers.BY_KEY = {}

modifiers.BY_ID = {}

modifiers.RETIRED = {

    made = "What everybody is made of",
    mo = "What everybody is made of",

    lines = "Who says what",
    lw = "Who says what",

    coinhealth = "A hit costs coins, not health",
    ch = "A hit costs coins, not health",

    spared = "Your own shockwave spares you",
    sr = "Your own shockwave spares you",

    headhop = "Hop off a head",
    hh = "Hop off a head",
    squish = "A stomp squashes a friend",
    fq = "A stomp squashes a friend",
    bubbleup = "Bubble up when you like",
    bu = "Bubble up when you like",
    bubblecost = "A bubble costs your power-up",
    bp = "A bubble costs your power-up",
    kinstone = "Kinstones",
    kn = "Kinstones",

    owncloud = "A cloud of your own",
    oc = "A cloud of your own",
}

for _, entry in ipairs(modifiers.LIST) do
    modifiers.BY_KEY[entry.key] = entry
    if entry.id ~= nil then modifiers.BY_ID[entry.id] = entry end
end

local wireStamp, textAt, textNow, setAt, setNow = 0, nil, nil, nil, nil

function modifiers.active()
    if setNow == nil or setAt ~= wireStamp then
        setAt = wireStamp
        setNow = modifiers.parse(modifiers.text())
    end
    return setNow
end

function modifiers.becomes(entry, level)
    local levels = entry ~= nil and entry.levels or nil
    local step = type(level) == "number" and levels ~= nil and levels[level] or nil
    if step == nil or step.retired == nil or type(step.becomes) ~= "table" then return nil end
    return step.becomes
end

local function level_of(piece)
    local key, level = string.match(piece, "^([^=]+)=(%d+)$")
    if key == nil then key, level = piece, 1 end

    if modifiers.RETIRED[key] ~= nil then return false end
    local entry = modifiers.BY_KEY[key] or modifiers.BY_ID[key]
    if entry == nil then return nil end
    return entry, modifiers.stored_step(entry, math.max(1, math.min(
        modifiers.step_count(entry), math.floor(tonumber(level) or 1))))
end

local function run_of(piece)
    local found = nil
    local at = 1
    while at <= #piece do
        local id, digits, after = string.match(piece, "^(%a%a)(%d*)()", at)
        found = found or {}

        if id ~= nil and modifiers.RETIRED[id] ~= nil then
            at = after
        else
            if id == nil or modifiers.BY_ID[id] == nil then return nil end
            local entry = modifiers.BY_ID[id]
            local raw = math.max(1, math.min(modifiers.step_count(entry),
                math.floor(tonumber(digits) or 1)))
            found[entry.key] = modifiers.stored_step(entry, raw)
            for k, v in pairs(modifiers.becomes(entry, raw) or {}) do found[k] = v end
            at = after
        end
    end
    return found
end

function modifiers.parse(packed)
    local set = {}
    if packed == nil or packed == "" then return set end

    for piece in string.gmatch(packed, "[^,]+") do

        local entry, level = level_of(piece)
        if entry == false then

        elseif entry ~= nil then

            if level > 0 then set[entry.key] = level end

            local key, raw = string.match(piece, "^([^=]+)=(%d+)$")
            raw = math.floor(tonumber(raw) or 1)
            for k, v in pairs(modifiers.becomes(entry, raw) or {}) do
                if v > 0 then set[k] = v end
            end
        else
            local run = run_of(piece)
            if run ~= nil then
                for key, at in pairs(run) do
                    if at > 0 then set[key] = at end
                end
            end
        end
    end
    return set
end

function modifiers.step_count(entry)
    if entry == nil then return 1 end
    if entry.levels == nil then return 1 end
    return #entry.levels
end

function modifiers.stored_step(entry, level)
    local levels = entry ~= nil and entry.levels or nil
    local step = type(level) == "number" and levels ~= nil and levels[level] or nil
    if step ~= nil and step.retired ~= nil and step.lands == 0 then return 0 end

    if step ~= nil and step.retired ~= nil and type(step.lands) == "number"
        and step.lands > 0 then
        return modifiers.live_step(entry, step.lands)
    end
    return modifiers.live_step(entry, level)
end

function modifiers.live_step(entry, level)
    if type(level) ~= "number" or level <= 0 then return level end
    local levels = entry ~= nil and entry.levels or nil
    if levels == nil then return level end
    local n = #levels
    local at = level
    for _ = 1, n do
        local step = levels[at]
        if step ~= nil and step.name ~= nil and step.retired == nil then
            return at
        end
        at = at + 1

        if at > n then return 0 end
    end
    return level
end

local function room_step(key)
    if not OF.util.asks(OF.rules, "step") then return 0 end
    return OF.rules.step(key)
end

local function room_setting(key, field, fallback)
    if not OF.util.asks(OF.rules, "step_setting") then return fallback end
    return OF.rules.step_setting(key, field, fallback)
end

modifiers.room_step = room_step
modifiers.room_setting = room_setting

modifiers.LOBBY_ONLY = {

    lowgrav = "set as a cheat - your own box is on the Cheats page",
    giant = "set as a cheat - your own box is on the Cheats page",
    tiny = "set as a cheat - your own box is on the Cheats page",

    water = "the level has one water line - the whole lobby shares it",
    dry = "the level has one water line - the whole lobby shares it",
    swim = "the level has one water line - the whole lobby shares it",

    whirl = "one pull, in the middle of the level, on everybody in it",

    cluster = "your pounds still reach everybody else - this one is the lobby's",

    wave = "one wave, on every screen at once - the engine draws it for the lobby",

    lava = "one floor, and it burns for the whole lobby or for nobody",
    demon = "one demon, coming after whoever in the lobby it can reach",

}

function modifiers.can_be_mine(key)
    if modifiers.BY_KEY[key] == nil then return false end
    return modifiers.LOBBY_ONLY[key] == nil
end

function modifiers.lobby_only_why(key)
    return modifiers.LOBBY_ONLY[key]
end

modifiers.mine = modifiers.mine or {}
modifiers.mineLevel = modifiers.mineLevel or {}

function modifiers.mine_level(key)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return 1 end
    return OF.util.clamp(math.floor(modifiers.mineLevel[key] or 1), 1,
        modifiers.step_count(entry))
end

function modifiers.mine_state(key)
    if not modifiers.can_be_mine(key) then return nil end
    local held = modifiers.mine[key]
    if held == nil then return nil end
    local roomLevel = modifiers.active()[key]
    if held == false then

        if roomLevel == nil or roomLevel <= 0 then return nil end
        return false
    end

    local entry = modifiers.BY_KEY ~= nil and modifiers.BY_KEY[key] or nil
    local steps = entry ~= nil and modifiers.step_count(entry) or 1
    if steps <= 1 and roomLevel ~= nil and roomLevel == modifiers.mine_level(key) then
        return nil
    end
    return true
end

function modifiers.mine_any()
    for key in pairs(modifiers.mine) do
        if modifiers.mine_state(key) ~= nil then return true end
    end
    return false
end

modifiers.ROUND_KEY = "ofRoundMods"
do

    local roundAt, roundSet = nil, nil

    function modifiers.round_text()
        local text = gGlobalSyncTable[modifiers.ROUND_KEY]
        if type(text) ~= "string" then return "" end
        return text
    end

    function modifiers.round_set()
        local text = modifiers.round_text()
        if roundSet == nil or roundAt ~= text then
            roundAt = text
            roundSet = modifiers.parse(text)
        end
        return roundSet
    end
end

function modifiers.round_level(key)
    return modifiers.round_set()[key] or 0
end

function modifiers.round_holds()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
end

function modifiers.select_holds()
    if not OF.util.asks(OF.venues, "mood_held") then return false end
    return OF.venues.mood_held() == true
end

modifiers.visualsKeys = nil
function modifiers.on_visuals(key)
    if modifiers.visualsKeys == nil then
        modifiers.visualsKeys = {}
        for _, group in ipairs(modifiers.GROUPS or {}) do
            if group.home == "visuals" then
                for _, k in ipairs(group.keys or {}) do modifiers.visualsKeys[k] = true end
            end
        end
    end
    return modifiers.visualsKeys[key] == true
end

modifiers.RUN_DRAWN = { night = true, sun = true, bank = true }

function modifiers.in_force(key, ignoreRound)
    local entry = modifiers.BY_KEY[key]

    if entry == nil then return room_step(key), false end

    local drawn = nil
    if modifiers.RUN_DRAWN[key] and OF.rando ~= nil
        and type(OF.rando.layer_level) == "function" then
        drawn = OF.rando.layer_level(key)
    end

    local placed = modifiers.placeVisuals ~= nil and modifiers.placeVisuals[key] or nil

    if placed ~= nil and not modifiers.maps_bring_weather() then placed = nil end
    if modifiers.mine[key] == nil and modifiers.active()[key] == nil
        and modifiers.round_set()[key] == nil and drawn == nil and placed == nil then
        return 0, false
    end

    if not ignoreRound and modifiers.on_visuals(key) and modifiers.select_holds() then
        return 0, false
    end

    if not ignoreRound and modifiers.round_holds() then
        return modifiers.round_level(key), false
    end

    local state = modifiers.mine_state(key)
    if state == true then return modifiers.mine_level(key), true end

    if state == false then return 0, true end

    local level = modifiers.active()[key]
    if level ~= nil then
        local excludes = entry.excludes
        if excludes ~= nil then
            for _, other in ipairs(excludes) do
                if modifiers.mine_state(other) == true then return 0, false end
            end
        end
        return level, false
    end

    if drawn ~= nil then return drawn, false end

    if placed ~= nil then return placed, false end
    return 0, false
end

function modifiers.level_is_yours(key)
    local _, mine = modifiers.in_force(key)
    return mine
end

function modifiers.suspended(key)
    if not modifiers.round_holds() then return false end
    return (modifiers.in_force(key, true)) > 0 and (modifiers.in_force(key)) == 0
end

function modifiers.settle_mine(key)
    if modifiers.mine_state(key) == nil then
        modifiers.mine[key] = nil
        modifiers.mineLevel[key] = nil
    end
end

function modifiers.set_mine(key, state)
    if modifiers.BY_KEY[key] == nil then return false, "No such modifier." end
    if not modifiers.can_be_mine(key) then
        return false, OF.lang.t(modifiers.LOBBY_ONLY[key])
    end
    if state == nil then
        modifiers.mine[key] = nil
        modifiers.mineLevel[key] = nil
    else
        modifiers.mine[key] = state == true
        if state == true and modifiers.mineLevel[key] == nil then
            modifiers.mineLevel[key] = 1
        end
        modifiers.settle_mine(key)
    end
    modifiers.mine_changed()
    return true
end

function modifiers.set_mine_level(key, level)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return false, "No such modifier." end
    if not modifiers.can_be_mine(key) then
        return false, OF.lang.t(modifiers.LOBBY_ONLY[key])
    end
    if type(level) ~= "number" then return false, "That is not a setting." end
    level = math.floor(level)
    if level <= 0 then return modifiers.set_mine(key, false) end
    if level > modifiers.step_count(entry) then
        return false, "That modifier does not go that far."
    end
    local live = modifiers.live_step(entry, level)
    if live <= 0 then return modifiers.set_mine(key, false) end
    modifiers.mine[key] = true
    modifiers.mineLevel[key] = live

    modifiers.settle_mine(key)
    modifiers.mine_changed()
    return true
end

function modifiers.clear_mine()
    modifiers.mine = {}
    modifiers.mineLevel = {}
    modifiers.mine_changed()
    return true
end

function modifiers.level(key)
    return (modifiers.in_force(key))
end

function modifiers.is_on(key)
    return modifiers.level(key) > 0
end

function modifiers.setting(key, field, fallback)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return room_setting(key, field, fallback) end
    local level = modifiers.level(key)
    if level <= 0 then return fallback end
    local levels = entry.levels
    if not levels then return fallback end
    local step = levels[level]
    if step == nil then return fallback end
    local value = step[field]
    if value == nil then return fallback end
    return value
end

function modifiers.room_level(key)
    if modifiers.round_holds() then return modifiers.round_level(key) end
    local level = modifiers.active()[key]
    if level == nil and modifiers.placeVisuals ~= nil and modifiers.maps_bring_weather() then
        level = modifiers.placeVisuals[key]
    end
    if type(level) ~= "number" or level <= 0 then return 0 end
    return level
end

modifiers.SEAT_ROWS = {

    upsidedown = { row = "ofUpside", seat = function(level)
        if level > 0 and OF.util.asks(OF.warp, "fall_is_owned")
            and OF.warp.fall_is_owned() then return 0 end
        return level
    end, publish = function(level)
        OF.util.publish_row(0, "ofUpside", level)
    end },
}

function modifiers.seat_level(key, localIndex)
    if localIndex == nil or localIndex == 0 then return (modifiers.in_force(key)) end
    local wire = modifiers.SEAT_ROWS[key]
    if wire == nil then return (modifiers.in_force(key)) end
    local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[localIndex] or nil
    local value = row ~= nil and tonumber(row[wire.row]) or nil
    if value == nil or value <= 0 then return 0 end
    return math.floor(value)
end

modifiers.seatSent = modifiers.seatSent or {}
function modifiers.publish_seats()
    for key, wire in pairs(modifiers.SEAT_ROWS) do
        local level = (modifiers.in_force(key))
        if wire.seat ~= nil then level = wire.seat(level) end
        if modifiers.seatSent[key] ~= level then
            modifiers.seatSent[key] = level
            wire.publish(level)
        end
    end
end

hook_event(HOOK_UPDATE, function() modifiers.publish_seats() end)

function modifiers.upside_here()
    return (modifiers.in_force("upsidedown")) > 0
end

function modifiers.upside_of(localIndex)
    return modifiers.seat_level("upsidedown", localIndex) > 0
end

function modifiers.upside_horizon()
    if not modifiers.upside_here() then return nil end
    return modifiers.setting("upsidedown", "horizon", nil)
end

local BUBBLE_DEPTH = 1400

function modifiers.bubbles_would_show()
    local m = gMarioStates[0]
    if m == nil or find_water_level == nil then return true end
    local ok, level = pcall(find_water_level, m.pos.x, m.pos.z)
    if not ok or type(level) ~= "number" then return true end
    return (level - m.pos.y) > BUBBLE_DEPTH
end

local LAVA_COURSES = "Lethal Lava Land and the Fire Sea"
function modifiers.fog_note()
    local np = gNetworkPlayers[0]
    local here = np ~= nil and np.currLevelNum or nil
    if here == nil then return nil end
    if modifiers.fog_is_real(here) then return nil end

    if modifiers.fog_can_paint ~= nil and modifiers.fog_can_paint() then return nil end

    return OF.lang.t("No fog here - only twelve levels have any.")
end

local function count_hooked(roster, total)
    for _, entry in ipairs(roster) do
        if entry.bhv ~= nil then
            local ok, found = pcall(count_objects_with_behavior,
                get_behavior_from_id(entry.bhv))
            if ok and type(found) == "number" then
                total = total + found
            end
        end
    end
    return total
end

function modifiers.fight_count()
    if OF.spawner == nil or OF.spawner.FIGHTS == nil then return nil end
    if OF.spawner.CLOCKWORK == nil then return nil end
    if count_objects_with_behavior == nil or get_behavior_from_id == nil then
        return nil
    end
    return count_hooked(OF.spawner.CLOCKWORK, count_hooked(OF.spawner.FIGHTS, 0))
end

function modifiers.fight_note()

    if modifiers.level("fightback") <= 0 then return nil end

    local found = modifiers.fight_count()
    if found == nil then
        return OF.lang.t("Acts on crushers and turntables already here.")
    end
    if found <= 0 then
        return OF.lang.t("Nothing here to turn up - most courses have some.")
    end
    return OF.lang.fill("@ of them here, turned up.", found)
end

function modifiers.clock_note()
    if modifiers.level("fightback") > 0 then
        return OF.lang.t("The level fights back is driving this too.")
    end
    if modifiers.clock_overdrive() > 1 then
        return OF.lang.t("Past the game's own top - the mod drives it.")
    end
    return OF.lang.t("Acts on clock parts - place some, or visit the clock.")
end

function modifiers.clock_overdrive()
    local factor = modifiers.setting("clock", "overdrive", 1)
    if type(factor) ~= "number" or factor < 1 then return 1 end
    return factor
end

function modifiers.dark_note()
    if modifiers.level("dark") <= 0 then return nil end
    if modifiers.setting("dark", "closes", false) == true then
        return OF.lang.t("One step darker every thirty seconds a round runs.")
    end
    return OF.lang.t("The sky is not lit by this - the picture reaches it.")
end

function modifiers.sky_note()

    if modifiers.level("skybright") <= 0 then return nil end
    if modifiers.setting("skybright", "bright", 1) < 1 then
        return OF.lang.t("The ground keeps its own light - only the sky goes.")
    end
    return nil
end

function modifiers.sun_note()
    if modifiers.level("sun") <= 0 then return nil end
    return OF.lang.t("Metal keeps the level's own light.")
end

function modifiers.lava_note()
    if not OF.util.asks(OF.ground, "remembering") then return nil end
    local step = OF.ground.remembering()
    if step == nil then return nil end
    if step == 5 then
        return OF.lang.t("Only the ground under somebody is safe.")
    end
    if step == 7 then
        return OF.lang.t("It drops to the low ground while somebody is down.")
    end

    local walked = OF.ground.trodden_count()
    if type(walked) ~= "number" or walked <= 0 then
        return OF.lang.t("Nobody has walked anywhere yet.")
    end
    local share = OF.ground.share(6)
    if type(share) ~= "number" then
        return OF.lang.fill("@ patches of ground have burned.", walked)
    end
    return OF.lang.fill("@ percent of this course has burned.",
        math.floor(share * 100 + 0.5))
end

function modifiers.floor_note()
    if modifiers.level("floor") <= 0 then return nil end
    if modifiers.setting("floor", "class", nil) ~= SURFACE_CLASS_DEFAULT then
        return nil
    end
    return OF.lang.t("Only bites where the level is icy or a slide.")
end

function modifiers.weather_note()

    if modifiers.setting("snow", "bombs", false) then
        return modifiers.bomb_note()
    end

    if modifiers.setting("snow", "rain", nil) ~= nil then
        if OF.util.asks(OF.celebrate, "spectacle")
            and not OF.celebrate.spectacle() then
            return OF.lang.t("Your own presentation setting is hiding this.")
        end
        return nil
    end

    local needs = modifiers.setting("snow", "needs", nil)
    if needs == nil then return nil end

    if needs == "ground" then
        return OF.lang.t("These settle on the ground rather than falling.")
    end
    if needs == "lava" then

        if modifiers.level("lava") > 0 then return nil end
        return OF.lang.fill("Only over lava - @", LAVA_COURSES)
    end
    if needs == "water" and not modifiers.bubbles_would_show() then
        return OF.lang.t("Nothing until you are deep under water.")
    end
    return nil
end

function modifiers.any()
    return modifiers.text() ~= ""
end

function modifiers.count_on()
    local n = 0
    for _ in pairs(modifiers.active()) do n = n + 1 end
    return n
end

function modifiers.count_on_home(home)
    local n = 0
    for _, group in ipairs(modifiers.grouped(home)) do
        for _, entry in ipairs(group.entries) do
            if modifiers.level(entry.key) > 0 then n = n + 1 end
        end
    end
    return n
end

function modifiers.names(packed)
    local set = packed ~= nil and modifiers.parse(packed) or modifiers.active()
    local list = {}
    for _, entry in ipairs(modifiers.LIST) do
        if set[entry.key] then table.insert(list, entry.name) end
    end
    return list
end

local SHADER_DEFAULTS = {
    [SHADER_FLAG_HUE] = 0.0,
    [SHADER_FLAG_SATURATION] = 1.0,
    [SHADER_FLAG_BRIGHTNESS] = 1.0,
    [SHADER_FLAG_CONTRAST] = 1.0,
    [SHADER_FLAG_EXPOSURE] = 1.0,
    [SHADER_FLAG_DITHERING] = 0.0,

    [SHADER_FLAG_POSTERIZATION] = 8.0,
    [SHADER_FLAG_SCANLINES] = 1.0,
}

modifiers.shaderHeld = modifiers.shaderHeld or {}

modifiers.viewHeld = modifiers.viewHeld or nil

local EIGHTH_TURN = math.pi / 4

local function turned(x, y, how, frame, angle)
    if how == "mirror" then return -x, y end
    if how == "flip" then return -x, -y end
    if how == "quarter" then return -y, x end

    if how == "backquarter" then return y, -x end

    if how == "askew" then
        local c, s = math.cos(EIGHTH_TURN), math.sin(EIGHTH_TURN)
        return x * c - y * s, x * s + y * c
    end

    if how == "eight" then
        local mag = math.sqrt(x * x + y * y)
        if mag < 1 then return x, y end
        local step = math.pi / 4
        local angle = math.floor(math.atan(y, x) / step + 0.5) * step
        return math.cos(angle) * mag, math.sin(angle) * mag
    end

    if how == "noback" then
        if y < 0 then return x, 0 end
        return x, y
    end
    if how == "drunk" then

        local wander = math.sin(frame / 47.0) * 2.2
        local c, s = math.cos(wander), math.sin(wander)
        return x * c - y * s, x * s + y * c
    end

    if how == "level" or how == "creep" then
        local c, s = math.cos(angle or 0), math.sin(angle or 0)
        return x * c - y * s, x * s + y * c
    end
    return x, y
end

modifiers.turned = turned

local controlFrame = 0

local stickCarry = { creep = 0, beat = nil, beatAt = 0 }

function modifiers.camera_yaw()
    if gLakituState == nil then return 0 end
    return gLakituState.yaw or 0
end

function modifiers.aim_the_stick(wanted, camYaw, mag)
    local turn = (wanted - camYaw - 0x8000) * (math.pi / 32768)
    mag = OF.util.clamp(mag or 0, 0, 64)
    return -math.sin(turn) * mag, math.cos(turn) * mag, mag
end

function modifiers.creep_angle(frames)
    return (math.max(frames or 0, 0) / 30) * (math.pi / 12)
end

function modifiers.beat_frames(tempo)
    local bpm = (tempo or 0) / 48
    if bpm < 20 or bpm > 400 then bpm = 120 end
    return math.max(math.floor(900 / bpm + 0.5), 1)
end

local function turn_the_stick(m)
    if m == nil or m.playerIndex ~= 0 then return end
    controlFrame = controlFrame + 1

    local how = modifiers.setting("controls", "turn", nil)
    if how == nil then
        stickCarry.creep, stickCarry.beat = 0, nil
        return
    end
    if OF.util.menu_has_screen() then return end

    local c = m.controller
    if c == nil then return end

    local x, y = c.stickX or 0, c.stickY or 0
    local mag = c.stickMag or 0

    if how == "rudder" then

        local facing = (m.faceAngle ~= nil and m.faceAngle.y or 0)
        local heading = facing + math.floor(x * 12)
        local drive = math.abs(y)
        if y < 0 then heading = heading + 0x8000 end
        if drive < 8 then drive = 0 end
        c.stickX, c.stickY, c.stickMag =
            modifiers.aim_the_stick(heading, modifiers.camera_yaw(), drive)
        return
    end

    if how == "near" then
        local _, who = modifiers.nearest_other()
        local other = who ~= nil and gMarioStates[who] or nil
        if other == nil or other.faceAngle == nil then return end
        c.stickX, c.stickY, c.stickMag =
            modifiers.aim_the_stick(other.faceAngle.y or 0,
                modifiers.camera_yaw(), mag)
        return
    end

    if how == "beat" then
        local every = modifiers.beat_frames(
            OF.util.optional("sequence_player_get_tempo", 0, SEQ_PLAYER_LEVEL))
        if stickCarry.beat == nil or controlFrame - stickCarry.beatAt >= every then
            stickCarry.beat = { x = x, y = y, mag = mag }
            stickCarry.beatAt = controlFrame
        end
        c.stickX, c.stickY, c.stickMag =
            stickCarry.beat.x, stickCarry.beat.y, stickCarry.beat.mag
        return
    end

    local angle = nil
    if how == "creep" then
        if mag <= 0 then
            stickCarry.creep = 0
        else
            stickCarry.creep = stickCarry.creep + 1
        end
        angle = modifiers.creep_angle(stickCarry.creep)
    elseif how == "level" then
        angle = -modifiers.camera_yaw() * (math.pi / 32768)
    end

    x, y = turned(x, y, how, controlFrame, angle)
    c.stickX, c.stickY = x, y
end

modifiers.STICK_FULL = 64

function modifiers.gate_polygon(sides, offset, angle, full)
    full = full or modifiers.STICK_FULL
    local step = (2 * math.pi) / sides
    local half = step / 2

    local away = (angle - offset) % step
    if away > half then away = away - step end
    return full * math.cos(half) / math.cos(half - math.abs(away))
end

modifiers.CROSS_ARM = 0.28

function modifiers.gate_cross(angle, full)
    full = full or modifiers.STICK_FULL
    local c = math.abs(math.cos(angle))
    local s = math.abs(math.sin(angle))
    local wide = full * modifiers.CROSS_ARM
    local flat = math.min(s > 0 and (wide / s) or full, c > 0 and (full / c) or full)
    local upright = math.min(c > 0 and (wide / c) or full, s > 0 and (full / s) or full)
    return math.min(full, math.max(flat, upright))
end

function modifiers.gate_radius(shape, angle, full)
    full = full or modifiers.STICK_FULL
    if shape == "octagon" then

        return modifiers.gate_polygon(8, 0, angle, full)
    elseif shape == "square" then

        return modifiers.gate_polygon(4, math.pi / 4, angle, full)
    elseif shape == "triangle" then

        return modifiers.gate_polygon(3, math.pi / 2, angle, full)
    elseif shape == "cross" then
        return modifiers.gate_cross(angle, full)
    end
    return full
end

function modifiers.stick_window(mag, dead, full)
    local top = modifiers.STICK_FULL
    mag = OF.util.clamp(tonumber(mag) or 0, 0, top)
    dead = OF.util.clamp(tonumber(dead) or 0, 0, top - 1)
    full = OF.util.clamp(tonumber(full) or top, dead + 1, top)
    if mag <= dead then return 0 end
    return OF.util.clamp((mag - dead) / (full - dead) * top, 0, top)
end

local function reshape_the_stick(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local shape = modifiers.setting("gate", "gate", nil)
    local dead = modifiers.setting("deadzone", "dead", nil)
    local full = modifiers.setting("saturate", "full", nil)
    if shape == nil and dead == nil and full == nil then return end
    if OF.util.menu_has_screen() then return end

    local c = m.controller
    if c == nil then return end

    local x, y = tonumber(c.stickX) or 0, tonumber(c.stickY) or 0

    if modifiers.setting("deadzone", "raw", false) then
        x, y = tonumber(c.rawStickX) or 0, tonumber(c.rawStickY) or 0
    end

    local mag = math.sqrt(x * x + y * y)
    if mag <= 0 then
        c.stickX, c.stickY, c.stickMag = 0, 0, 0
        return
    end
    if mag > modifiers.STICK_FULL then
        local down = modifiers.STICK_FULL / mag
        x, y, mag = x * down, y * down, modifiers.STICK_FULL
    end

    local want = mag
    if dead ~= nil or full ~= nil then
        want = modifiers.stick_window(mag, dead or 0, full or modifiers.STICK_FULL)
    end

    if shape ~= nil then
        local limit = modifiers.gate_radius(shape, math.atan(y, x))
        if want > limit then want = limit end
    end

    if want <= 0 then
        c.stickX, c.stickY, c.stickMag = 0, 0, 0
        return
    end
    local scale = want / mag
    c.stickX, c.stickY, c.stickMag = x * scale, y * scale, want
end

modifiers.reshape_the_stick = reshape_the_stick

function modifiers.fastest_ground_speed()
    local best = 0
    local moving = OF.util.action_group(ACT_GROUP_MOVING)
    for index = 0, (MAX_PLAYERS or 16) - 1 do
        local np = gNetworkPlayers[index]
        local other = gMarioStates[index]
        if np ~= nil and np.connected and other ~= nil
            and OF.util.can_play(index)
            and OF.util.action_group(other.action) == moving
            and not OF.util.stopping(other)
            and not (OF.util.asks(OF.cheats, "is_knockback")
                     and OF.cheats.is_knockback(other.action)) then
            local speed = tonumber(other.forwardVel) or 0
            if speed > best then best = speed end
        end
    end
    return best
end

function modifiers.hold_shared_speed(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("fastest") <= 0 then return false end
    if not OF.util.can_play(0) then return false end
    if OF.util.action_group(m.action) ~= OF.util.action_group(ACT_GROUP_MOVING) then
        return false
    end
    local best = modifiers.fastest_ground_speed()
    if best <= 0 then return false end
    return OF.util.speed_up(m, best, true)
end

local climbFrom = nil

function modifiers.forget_climb()
    climbFrom = nil
    return true
end

function modifiers.climb_origin()
    return climbFrom
end

local function climb_stand_down()
    return modifiers.round_holds()
end

function modifiers.climb_note()

    if not OF.util.asks(OF.rules, "shown_value") then return nil end
    local shown = OF.rules.shown_value("climb")
    if type(shown) ~= "number" or shown <= 0 then return nil end

    if OF.util.asks(OF.rules, "value") and OF.rules.value("stairs") == 999 then
        return OF.lang.t("The castle's own stairs are on How the game plays.")
    end
    return OF.lang.t("Any climb on foot, anywhere - not only stairs.")
end

local function on_own_feet(m)
    if m == nil or m.pos == nil or m.floor == nil then return false end
    if m.action == nil then return false end
    return OF.util.has_flag(m.action, ACT_FLAG_STATIONARY)
        or OF.util.has_flag(m.action, ACT_FLAG_MOVING)
end

local function climb_update(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local climb = modifiers.setting("climb", "climb", nil)
    if climb == nil or climb_stand_down() then
        climbFrom = nil
        return
    end

    local np = gNetworkPlayers[0]
    if np == nil then return end

    if not on_own_feet(m) then return end

    if climbFrom == nil
        or climbFrom.level ~= np.currLevelNum
        or climbFrom.area ~= np.currAreaIndex then
        climbFrom = { level = np.currLevelNum, area = np.currAreaIndex,
                      x = m.pos.x, y = m.pos.y, z = m.pos.z,

                      facing = m.faceAngle.y }
        return
    end

    if m.pos.y <= climbFrom.y then
        climbFrom.x, climbFrom.y, climbFrom.z = m.pos.x, m.pos.y, m.pos.z
        climbFrom.facing = m.faceAngle.y
        return
    end

    if m.pos.y - climbFrom.y < climb then return end

    m.pos.x, m.pos.y, m.pos.z = climbFrom.x, climbFrom.y, climbFrom.z
    m.faceAngle.y = climbFrom.facing

    if m.marioObj ~= nil then
        vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
        m.marioObj.oPosX, m.marioObj.oPosY, m.marioObj.oPosZ =
            m.pos.x, m.pos.y, m.pos.z

        OF.util.skip_interpolation(m.marioObj)
    end
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
end

hook_event(HOOK_MARIO_UPDATE, climb_update, OF.LOCAL_MARIO)

local LEVEL_CONSTANTS = {}
for name, value in pairs(_G) do
    if type(name) == "string" and type(value) == "number"
        and string.sub(name, 1, 6) == "LEVEL_" then

        if LEVEL_CONSTANTS[value] == nil then LEVEL_CONSTANTS[value] = name end
    end
end

do

local RUN_VEL = 32.0

local WIDEN_PER_TICK = 0.2

local WIDEN_TOP_SHARE = 1.75

local fisheyeBreathFrom = nil
local fisheyeWiden = 0.0
local lensHeld = false

function modifiers.rest_fov()
    if set_override_fov == nil then return end
    local fov = modifiers.fisheye_fov()
    set_override_fov(fov or NO_FOV)
    modifiers.eyes_fov(fov)
end

modifiers.eyesFovHeld = nil

function modifiers.eyes_fov(fov)
    local cam = gFirstPersonCamera
    if cam == nil then return false end
    if fov == nil then
        if modifiers.eyesFovHeld == nil then return true end
        cam.fov = modifiers.eyesFovHeld
        modifiers.eyesFovHeld = nil
        return true
    end
    if modifiers.eyesFovHeld == nil then modifiers.eyesFovHeld = cam.fov end
    cam.fov = fov
    return true
end

modifiers.eyeLiftHeld = nil

function modifiers.lift_eyes(lift)
    local cam = gFirstPersonCamera
    if cam == nil or cam.offset == nil then return false end
    if lift == nil then
        if modifiers.eyeLiftHeld == nil then return true end
        cam.offset.y = modifiers.eyeLiftHeld
        modifiers.eyeLiftHeld = nil
        return true
    end
    if modifiers.eyeLiftHeld == nil then modifiers.eyeLiftHeld = cam.offset.y or 0 end
    cam.offset.y = lift
    return true
end

function modifiers.forget_fisheye()
    fisheyeBreathFrom = nil
    fisheyeWiden = 0.0
end

function modifiers.fisheye_fov()
    local fov = modifiers.setting("fisheye", "fov", nil)
    if fov == nil then return nil end

    local swell = modifiers.setting("fisheye", "swell", nil)
    local period = modifiers.setting("fisheye", "period", nil)
    if swell ~= nil and period ~= nil and period > 0 then

        local phase = 0
        if fisheyeBreathFrom ~= nil then
            local now = OF.util.optional("get_global_timer", 0) or 0
            phase = (now - fisheyeBreathFrom) % period
        end
        local share = (1.0 - math.cos(2.0 * math.pi * phase / period)) / 2.0
        return fov + (swell - fov) * share
    end

    local wide = modifiers.setting("fisheye", "wide", nil)
    if wide ~= nil then
        local want = fov + (wide - fov) * fisheyeWiden

        local top = modifiers.setting("fisheye", "top", nil)
        if top ~= nil and want > top then return top end
        return want
    end

    return fov
end

function modifiers.fisheye_frame()
    local swell = modifiers.setting("fisheye", "swell", nil)
    local wide = modifiers.setting("fisheye", "wide", nil)
    if swell == nil and wide == nil then
        modifiers.forget_fisheye()
        return
    end

    if wide ~= nil then
        local m = gMarioStates ~= nil and gMarioStates[0] or nil
        local vel = (m ~= nil and type(m.forwardVel) == "number")
            and math.abs(m.forwardVel) or 0

        local top = modifiers.setting("fisheye", "top", nil)
        local most = (top ~= nil) and WIDEN_TOP_SHARE or 1
        local want = OF.util.clamp(vel / RUN_VEL, 0, most)
        fisheyeWiden = fisheyeWiden + (want - fisheyeWiden) * WIDEN_PER_TICK
    else

        if fisheyeBreathFrom == nil then
            fisheyeBreathFrom = OF.util.optional("get_global_timer", 0) or 0
        end
    end

    if lensHeld then return end
    if set_override_fov == nil then return end
    set_override_fov(modifiers.fisheye_fov() or NO_FOV)
end

local LENS_FOV = 18

function modifiers.lens_fov(on)
    if set_override_fov == nil then return false end
    if not on then
        lensHeld = false
        modifiers.rest_fov()
        return true
    end
    lensHeld = true
    set_override_fov(LENS_FOV)
    return true
end

function modifiers.lens_is_held()
    return lensHeld
end

hook_event(HOOK_UPDATE, function() modifiers.fisheye_frame() end)
end

local pressedLevel = nil
local pressWasDown = true

modifiers.pressClock = modifiers.pressClock or 0

function modifiers.presses(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row.ofPresses or 0
    if type(value) ~= "number" or value < 0 then return 0 end
    return math.floor(value)
end

function modifiers.press_budget()
    return modifiers.setting("budget", "budget", nil)
end

function modifiers.press_refill()
    return modifiers.setting("budget", "every", nil)
end

function modifiers.refund_press(by)
    local spent = modifiers.presses(0)
    if spent <= 0 then return false end
    local left = math.max(spent - math.max(math.floor(by or 1), 1), 0)
    OF.util.publish_row(0, "ofPresses", left > 0 and left or nil)
    return true
end

function modifiers.forget_presses()
    pressedLevel = nil
    modifiers.pressClock = 0

    pressWasDown = true
    if modifiers.presses(0) ~= 0 then
        OF.util.publish_row(0, "ofPresses", nil)
    end
end

function modifiers.press_note()
    if modifiers.level("budget") <= 0 then return nil end
    local budget = modifiers.press_budget()
    if budget == nil then
        return OF.lang.fill("@ so far this level", tostring(modifiers.presses(0)))
    end

    if modifiers.press_refill() ~= nil then
        return OF.lang.fill("@ of @, and one comes back on the clock",
            tostring(modifiers.presses(0)), tostring(budget))
    end
    if modifiers.setting("budget", "coin", nil) ~= nil then
        return OF.lang.fill("@ of @, and a coin buys one back",
            tostring(modifiers.presses(0)), tostring(budget))
    end
    return OF.lang.fill("@ of @ this level", tostring(modifiers.presses(0)),
        tostring(budget))
end

function modifiers.count_the_press(c)
    if modifiers.level("budget") <= 0 then return end

    local every = modifiers.press_refill()
    if every == nil then
        modifiers.pressClock = 0
    else
        modifiers.pressClock = modifiers.pressClock + 1
        if modifiers.pressClock >= every then
            modifiers.pressClock = 0
            modifiers.refund_press(1)
        end
    end

    if c == nil then return end

    local np = gNetworkPlayers[0]
    local here = np ~= nil and np.currLevelNum or nil
    local down = OF.util.has_flag(c.buttonDown or 0, A_BUTTON)

    if pressedLevel ~= here then
        modifiers.forget_presses()
        pressedLevel = here

        pressWasDown = down
        return
    end

    local newPress = down and not pressWasDown
    pressWasDown = down
    if not newPress then return end

    local spent = modifiers.presses(0)
    local budget = modifiers.press_budget()
    if budget ~= nil and spent >= budget then

        c.buttonDown = (c.buttonDown or 0) & 0xFFFF & ~A_BUTTON
        c.buttonPressed = (c.buttonPressed or 0) & 0xFFFF & ~A_BUTTON
        pressWasDown = false
        return
    end
    OF.util.publish_row(0, "ofPresses", spent + 1)
end

modifiers.BUTTON_DEAL = { A_BUTTON, B_BUTTON, Z_TRIG }

modifiers.BUTTON_ALL = A_BUTTON | B_BUTTON | Z_TRIG

local buttonCarry = {
    deaths = 0, level = nil, refused = 0, last = nil,
    wasAction = nil, wasHealth = nil, frame = 0, gone = 0,

    ghostAt = 0, ghostBit = 0, ghostLeft = 0, swallowed = false, dice = 12345,
}

function modifiers.dealt_button(index)
    local deal = modifiers.BUTTON_DEAL
    return deal[(math.floor(index or 0) % #deal) + 1]
end

function modifiers.dealt_mask(index)
    return modifiers.BUTTON_ALL & ~modifiers.dealt_button(index)
end

function modifiers.rotated_mask(frame, every)
    every = math.max(math.floor(every or 1), 1)
    return modifiers.dealt_mask(math.floor((frame or 0) / every))
end

function modifiers.no_repeat(pressed, last)
    local allowed = 0
    for _, bit in ipairs(modifiers.BUTTON_DEAL) do
        if (pressed & bit) ~= 0 and bit ~= last then
            allowed = allowed | bit
            last = bit
        end
    end
    return allowed, last
end

function modifiers.a_death(action, health, wasAction, wasHealth)
    if action == ACT_BUBBLED and wasAction ~= ACT_BUBBLED then return true end
    return (health or 0x880) < 0x100 and (wasHealth or 0x880) >= 0x100
end

function modifiers.deaths_here()
    return buttonCarry.deaths
end

function modifiers.button_die(sides)
    buttonCarry.dice = (1103515245 * buttonCarry.dice + 12345) % 2147483648
    return (math.floor(buttonCarry.dice / 65536) % sides) + 1
end

function modifiers.phantom_press(frame)
    if buttonCarry.ghostLeft > 0 then
        buttonCarry.ghostLeft = buttonCarry.ghostLeft - 1
        return buttonCarry.ghostBit, false
    end
    if buttonCarry.ghostAt == 0 then
        buttonCarry.ghostAt = frame + 90 + modifiers.button_die(150)
    end
    if frame < buttonCarry.ghostAt then return 0, false end
    buttonCarry.ghostBit = modifiers.BUTTON_DEAL[modifiers.button_die(#modifiers.BUTTON_DEAL)]
    buttonCarry.ghostLeft = 2
    buttonCarry.ghostAt = frame + 120 + modifiers.button_die(120)
    return buttonCarry.ghostBit, true
end

function modifiers.flaky_press(bit, down, pressed)
    if (down & bit) == 0 then buttonCarry.swallowed = false end
    if (pressed & bit) ~= 0 and modifiers.button_die(3) == 1 then
        buttonCarry.swallowed = true
    end
    return buttonCarry.swallowed
end

function modifiers.forget_buttons()
    buttonCarry.ghostAt, buttonCarry.ghostBit, buttonCarry.ghostLeft = 0, 0, 0
    buttonCarry.swallowed = false
    buttonCarry.deaths, buttonCarry.level = 0, nil
    buttonCarry.refused, buttonCarry.last, buttonCarry.frame = 0, nil, 0
    buttonCarry.wasAction, buttonCarry.wasHealth = nil, nil

    buttonCarry.gone = 0
    return true
end

function modifiers.watch_for_death(m)
    buttonCarry.frame = buttonCarry.frame + 1
    local np = gNetworkPlayers[0]
    local here = np ~= nil and np.currLevelNum or nil
    if buttonCarry.level ~= here then
        buttonCarry.deaths, buttonCarry.level = 0, here
        buttonCarry.wasAction, buttonCarry.wasHealth = m.action, m.health
        return
    end
    if modifiers.a_death(m.action, m.health,
        buttonCarry.wasAction, buttonCarry.wasHealth) then
        buttonCarry.deaths = buttonCarry.deaths + 1
    end
    buttonCarry.wasAction, buttonCarry.wasHealth = m.action, m.health
end

local function mask_the_buttons(m)
    if m == nil or m.playerIndex ~= 0 then return end

    modifiers.watch_for_death(m)

    buttonCarry.gone = 0

    if OF.util.menu_has_screen() then return end

    local c = m.controller
    if c == nil then return end

    modifiers.count_the_press(c)

    local hold = modifiers.setting("buttons", "hold", nil)
    if hold ~= nil then
        c.buttonDown = (c.buttonDown or 0) & 0xFFFF | hold
    end

    local mask = modifiers.setting("buttons", "mask", nil)
    if mask ~= nil then

        c.buttonDown = (c.buttonDown or 0) & 0xFFFF & ~mask
        c.buttonPressed = (c.buttonPressed or 0) & 0xFFFF & ~mask
        buttonCarry.gone = buttonCarry.gone | mask
    end

    local dealt = nil
    local deal = modifiers.setting("buttons", "deal", nil)
    if deal == "own" then
        local np = gNetworkPlayers[0]
        dealt = modifiers.dealt_mask(np ~= nil and np.globalIndex or 0)
    elseif deal == "near" then

        local _, who = modifiers.nearest_other()
        local other = who ~= nil and gNetworkPlayers[who] or nil
        if other ~= nil then
            dealt = modifiers.dealt_mask(other.globalIndex or 0)
        end
    end

    local rotate = modifiers.setting("buttons", "rotate", nil)
    if rotate ~= nil then
        dealt = modifiers.rotated_mask(buttonCarry.frame, rotate)
    end

    if dealt ~= nil and dealt ~= 0 then
        c.buttonDown = (c.buttonDown or 0) & 0xFFFF & ~dealt
        c.buttonPressed = (c.buttonPressed or 0) & 0xFFFF & ~dealt
        buttonCarry.gone = buttonCarry.gone | dealt
    end

    if modifiers.setting("buttons", "norepeat", false) == true then
        local down = (c.buttonDown or 0) & 0xFFFF
        buttonCarry.refused = buttonCarry.refused & down
        local pressed = (c.buttonPressed or 0) & modifiers.BUTTON_ALL & ~buttonCarry.refused
        local allowed
        allowed, buttonCarry.last = modifiers.no_repeat(pressed, buttonCarry.last)
        buttonCarry.refused = buttonCarry.refused | (pressed & ~allowed)
        if buttonCarry.refused ~= 0 then
            c.buttonDown = down & ~buttonCarry.refused
            c.buttonPressed = (c.buttonPressed or 0) & 0xFFFF & ~buttonCarry.refused

            buttonCarry.gone = buttonCarry.gone | buttonCarry.refused
        end
    end

    if modifiers.setting("buttons", "phantom", false) == true then
        local bit, fresh = modifiers.phantom_press(buttonCarry.frame)
        if bit ~= 0 then
            c.buttonDown = ((c.buttonDown or 0) & 0xFFFF) | bit
            if fresh then
                c.buttonPressed = ((c.buttonPressed or 0) & 0xFFFF) | bit
            end
        end
    end
    local flaky = modifiers.setting("buttons", "flaky", nil)
    if flaky ~= nil then
        local down = (c.buttonDown or 0) & 0xFFFF
        if modifiers.flaky_press(flaky, down, (c.buttonPressed or 0) & 0xFFFF) then
            c.buttonDown = down & ~flaky
            c.buttonPressed = (c.buttonPressed or 0) & 0xFFFF & ~flaky
            buttonCarry.gone = buttonCarry.gone | flaky
        end
    end

    if modifiers.setting("buttons", "walk", false) == true then
        local mag = c.stickMag or 0
        if mag > 24 then c.stickMag = 24 end
    end
end

modifiers.mask_the_buttons = mask_the_buttons

do

local BUTTON_NAMES = {
    { flag = A_BUTTON, name = "A" },
    { flag = B_BUTTON, name = "B" },
    { flag = Z_TRIG,   name = "Z" },
}

function modifiers.buttons_gone_text()
    local gone = buttonCarry.gone or 0
    if gone == 0 then return nil end
    local names = {}
    for _, button in ipairs(BUTTON_NAMES) do
        if (gone & button.flag) ~= 0 then names[#names + 1] = button.name end
    end
    if #names == 0 then return nil end
    if #names == 1 then return names[1] end
    local last = table.remove(names)
    return table.concat(names, ", ") .. " and " .. last
end

function modifiers.taken_away()
    local lines = {}

    if OF.util.asks(OF.rules, "moves_ban_step")
        and OF.util.asks(OF.rules, "option_name")
        and OF.util.asks(OF.rules, "find") then
        local step = OF.rules.moves_ban_step()
        if type(step) == "number" and step > 0 then
            local name = OF.rules.option_name(OF.rules.find("moveban"), step)
            if type(name) == "string" and name ~= "" then
                lines[#lines + 1] = OF.lang.fill("The lobby: @", name)
            end
        end
    end

    local learn = modifiers.BY_KEY.learn
    if learn ~= nil and modifiers.level("learn") > 0 then
        local said = modifiers.learn_note()
        if type(said) == "string" and said ~= "" then
            lines[#lines + 1] = OF.lang.fill("@: @", OF.lang.t(learn.name), said)
        end
    end

    local gone = modifiers.buttons_gone_text()
    if gone ~= nil then
        lines[#lines + 1] = OF.lang.fill("Taken off the pad: @", gone)
    end
    if modifiers.setting("buttons", "walk", false) == true then
        lines[#lines + 1] = OF.lang.t("And running with it.")
    end

    local budget = modifiers.BY_KEY.budget
    if budget ~= nil and modifiers.level("budget") > 0 then
        local said = modifiers.press_note()
        if type(said) == "string" and said ~= "" then
            lines[#lines + 1] = OF.lang.fill("@: @", OF.lang.t(budget.name), said)
        end
    end

    return lines
end

modifiers.pauseLines = 0

local TAKEN_TITLE = "What has been taken away"
local TAKEN_SCALE = 0.9
local TAKEN_UNDER = 0.68

local function render_taken()
    modifiers.pauseLines = 0

    if OF.util.menu_has_screen() then return end

    local paused
    if OF.util.asks(OF.gamemodes, "paused") then
        paused = OF.gamemodes.paused() == true
    else
        paused = OF.util.optional("is_game_paused", false) == true
    end
    if not paused then return end

    local lines = modifiers.taken_away()
    if #lines == 0 then return end

    local under = {}
    for index, text in ipairs(lines) do
        under[index] = { text = text, scale = TAKEN_UNDER }
    end

    OF.util.banner_low(OF.lang.t(TAKEN_TITLE), TAKEN_SCALE,
        255, 225, 160, 255, { under = under })
    modifiers.pauseLines = #lines
end

modifiers.render_taken = render_taken

hook_event(HOOK_ON_HUD_RENDER, render_taken)

end

local function fold_s16(value)
    value = math.floor(value) & 0xFFFF
    if value >= 0x8000 then value = value - 0x10000 end
    return value
end

modifiers.LEAN_FAR = 2000
modifiers.LEAN_CLOSE = 400

modifiers.WALK_FULL = 32

modifiers.horizonPresses = modifiers.horizonPresses or 0
modifiers.horizonHeldA = modifiers.horizonHeldA or false

function modifiers.forget_horizon_presses()
    modifiers.horizonPresses = 0
    modifiers.horizonHeldA = false
end

function modifiers.lean_towards()
    local away, who = modifiers.nearest_other()
    if away == nil or who == nil then return nil end
    local me, them = gMarioStates[0], gMarioStates[who]
    if me == nil or them == nil or me.faceAngle == nil then return nil end

    local dx = them.pos.x - me.pos.x
    local dz = them.pos.z - me.pos.z
    if dx == 0 and dz == 0 then return 0 end

    local bearing = math.atan(dx, dz)
    local facing = (me.faceAngle.y or 0) * math.pi / 0x8000
    local sideways = math.sin(bearing - facing)

    local near = OF.util.clamp(
        (modifiers.LEAN_FAR - away)
            / (modifiers.LEAN_FAR - modifiers.LEAN_CLOSE), 0, 1)
    return sideways * near
end

local function tilt_the_horizon()
    if gLakituState == nil then return end

    local tilt = modifiers.setting("horizon", "tilt", nil)
    local drift = modifiers.setting("horizon", "drift", nil)
    local lean = modifiers.setting("horizon", "lean", nil)
    local moving = modifiers.setting("horizon", "moving", nil)
    local press = modifiers.setting("horizon", "press", nil)

    local me = gMarioStates[0]
    local downA = me ~= nil and me.controller ~= nil
        and (me.controller.buttonDown & A_BUTTON) ~= 0
    if downA and not modifiers.horizonHeldA then
        modifiers.horizonPresses = (modifiers.horizonPresses + 1) % 4
    end
    modifiers.horizonHeldA = downA and true or false

    if tilt == nil and drift == nil and lean == nil and moving == nil
        and press == nil then
        return
    end

    local amount = tilt or 0
    if lean ~= nil then

        amount = amount + lean * (modifiers.lean_towards() or 0)
    end
    if moving ~= nil then

        local speed = 0
        if me ~= nil and me.vel ~= nil then
            speed = math.sqrt(me.vel.x * me.vel.x + me.vel.z * me.vel.z)
        end
        amount = amount
            + moving * OF.util.clamp(speed / modifiers.WALK_FULL, 0, 1)
    end
    if press ~= nil then
        amount = amount + press * modifiers.horizonPresses
    end
    if drift ~= nil then

        local now = OF.util.optional("get_global_timer", 0) or 0
        amount = amount + (now % drift) * 0x10000 / drift
    end

    gLakituState.roll = fold_s16((gLakituState.roll or 0) + amount)

end

modifiers.tilt_the_horizon = tilt_the_horizon

local WALL_KICK_WINDOW = 5

local function kicks_held()
    return OF.util.asks(OF.cheats, "is_on") and OF.cheats.is_on("kicks") == true
end

local function hold_the_wall_kick(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if not kicks_held() then return false end
    if (m.wallKickTimer or 0) < WALL_KICK_WINDOW then
        m.wallKickTimer = WALL_KICK_WINDOW
    end
    return true
end

modifiers.hold_the_wall_kick = hold_the_wall_kick

hook_event(HOOK_MARIO_UPDATE, hold_the_wall_kick, OF.LOCAL_MARIO)

do

local MAX_DELAY_FRAMES = 30

local DELAY_RING = MAX_DELAY_FRAMES + 1

local delayRing = {}
local delayAt = 0

local driftFor = 0
local driftDeaths = nil

local function empty_ring()
    for index = 1, DELAY_RING do delayRing[index] = nil end
    delayAt = 0
end

function modifiers.forget_delay()
    empty_ring()
    driftFor, driftDeaths = 0, nil
    return true
end

function modifiers.delay_held()
    local held = 0
    for index = 1, DELAY_RING do
        if delayRing[index] ~= nil then held = held + 1 end
    end
    return held
end

function modifiers.drift_frames(frames)
    local grown = 3 + math.floor(math.max(frames or 0, 0) / 300)
    return math.floor(OF.util.clamp(grown, 1, MAX_DELAY_FRAMES))
end

function modifiers.delay_frames()
    local frames = modifiers.setting("delay", "frames", nil)
    if frames ~= nil then return frames end
    if modifiers.setting("delay", "drift", false) ~= true then return nil end
    return modifiers.drift_frames(driftFor)
end

local function drift_the_pad()
    if modifiers.setting("delay", "drift", false) ~= true then
        driftFor, driftDeaths = 0, nil
        return
    end
    local deaths = modifiers.deaths_here()
    if driftDeaths ~= deaths then
        driftDeaths, driftFor = deaths, 0
    else
        driftFor = driftFor + 1
    end
end

function modifiers.delay_note()
    local frames = modifiers.delay_frames()
    if frames == nil then return nil end

    return OF.lang.fill("@ frames, about @ of a second",
        tostring(frames), tostring(math.floor(frames / 30 * 100 + 0.5) / 100))
end

local function delay_the_pad(m)
    if m == nil or m.playerIndex ~= 0 then return end

    drift_the_pad()

    local frames = modifiers.delay_frames()
    if frames == nil then

        if delayAt ~= 0 then modifiers.forget_delay() end
        return
    end

    if OF.util.menu_has_screen() then
        if delayAt ~= 0 then empty_ring() end
        return
    end

    local c = m.controller
    if c == nil then return end

    frames = math.floor(OF.util.clamp(frames, 1, MAX_DELAY_FRAMES))

    delayAt = (delayAt % DELAY_RING) + 1
    delayRing[delayAt] = {
        stickX = c.stickX or 0,
        stickY = c.stickY or 0,
        stickMag = c.stickMag or 0,
        buttonDown = (c.buttonDown or 0) & 0xFFFF,
        buttonPressed = (c.buttonPressed or 0) & 0xFFFF,
    }

    local from = ((delayAt - 1 - frames) % DELAY_RING) + 1
    local was = delayRing[from]

    if was == nil then
        c.stickX, c.stickY, c.stickMag = 0, 0, 0
        c.buttonDown, c.buttonPressed = 0, 0
        return
    end

    c.stickX, c.stickY, c.stickMag = was.stickX, was.stickY, was.stickMag
    c.buttonDown, c.buttonPressed = was.buttonDown, was.buttonPressed
end

modifiers.delay_the_pad = delay_the_pad

hook_event(HOOK_BEFORE_MARIO_UPDATE, delay_the_pad, OF.LOCAL_MARIO)

hook_event(HOOK_ON_LEVEL_INIT, function() modifiers.forget_delay() end)
end

do

local MAX_EARLY_FRAMES = 10

local groundedAt = nil

function modifiers.forget_early()
    groundedAt = nil
    return true
end

function modifiers.early_press(since, frames, now, wasGrounded)
    if type(since) ~= "number" then return nil end
    if type(frames) ~= "number" or type(now) ~= "number" then return nil end
    if type(wasGrounded) ~= "number" then return nil end
    if since < 1 or since > frames then return nil end
    local made = now - 1 - since
    if made <= wasGrounded then return nil end
    return made
end

local function on_the_ground(m)
    local group = group_of(m.action or 0)
    if group == nil then return false end
    return group == group_of(ACT_GROUP_STATIONARY)
        or group == group_of(ACT_GROUP_MOVING)
end

local function remember_the_press(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local frames = modifiers.setting("buffer", "frames", nil)
    if frames == nil then

        if groundedAt ~= nil then modifiers.forget_early() end
        return
    end

    if OF.util.menu_has_screen() or not OF.util.can_play(0) then
        modifiers.forget_early()
        return
    end

    local c = m.controller
    if c == nil then
        modifiers.forget_early()
        return
    end

    frames = math.floor(OF.util.clamp(frames, 1, MAX_EARLY_FRAMES))
    local now = OF.util.optional("get_global_timer", 0) or 0

    local wasGrounded = groundedAt
    local grounded = on_the_ground(m)
    if grounded then groundedAt = now end
    if not grounded or wasGrounded == nil then return end

    local pressed = (c.buttonPressed or 0) & 0xFFFF

    local madeA = modifiers.early_press(m.framesSinceA, frames, now, wasGrounded)
    if madeA ~= nil then pressed = pressed | A_BUTTON end

    local madeB = modifiers.early_press(m.framesSinceB, frames, now, wasGrounded)
    if madeB ~= nil then pressed = pressed | B_BUTTON end

    c.buttonPressed = pressed
end

modifiers.remember_the_press = remember_the_press

hook_event(HOOK_BEFORE_MARIO_UPDATE, remember_the_press, OF.LOCAL_MARIO)

hook_event(HOOK_ON_LEVEL_INIT, function() modifiers.forget_early() end)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, mask_the_buttons, OF.LOCAL_MARIO)

hook_event(HOOK_BEFORE_MARIO_UPDATE, reshape_the_stick, OF.LOCAL_MARIO)
hook_event(HOOK_BEFORE_MARIO_UPDATE, turn_the_stick, OF.LOCAL_MARIO)
hook_event(HOOK_ON_PLAY_MODE_UPDATE, tilt_the_horizon)

local MIRROR_CAMERA = GRAPH_NODE_TYPE_CAMERA or 0x114

local MIRROR_BUDGET = 96

local MIRROR_PATIENCE = 4

local MIRROR_MARK = 0x4D

local mirrorNode = nil

local mirrorUnseen = 0

local function mirror_find(first, budget)
    if first == nil or budget <= 0 then return nil, budget end
    local node = first
    repeat
        budget = budget - 1
        if budget < 0 then return nil, 0 end
        if node.type == MIRROR_CAMERA then return node, budget end
        local found
        found, budget = mirror_find(node.children, budget)
        if found ~= nil then return found, budget end
        node = node.next
    until node == nil or node == first or budget <= 0
    return nil, budget
end

local function mirror_camera_here()
    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    if me == nil then return nil end
    local area = me.area
    if area == nil then return nil end
    local root = area.root
    if root == nil then return nil end
    local top = root.node
    if top == nil then return nil end
    return (mirror_find(top.children, MIRROR_BUDGET))
end

modifiers.mirror_camera_here = mirror_camera_here

modifiers.camera_node = mirror_camera_here

local function mirror_mark()
    local node = mirror_camera_here()
    if node == nil then return false end

    local was = node.hookProcess or 0
    if was == 0 then
        node.hookProcess = MIRROR_MARK
        mirrorNode = node
    elseif was ~= MIRROR_MARK then

        mirrorNode = nil
    end
    return true
end

local function mirror_unmark()
    mirrorUnseen = 0
    if mirrorNode == nil then return end
    local node = mirror_camera_here()
    if node ~= nil and node == mirrorNode
        and (node.hookProcess or 0) == MIRROR_MARK then
        node.hookProcess = 0
    end
    mirrorNode = nil
end

local function mirror_the_camera(node, matStackIndex)
    if node == nil or node.type ~= MIRROR_CAMERA then return end
    mirrorUnseen = 0

    if not modifiers.mirror_live() then return end
    if gMatStack == nil or matStackIndex == nil then return end

    local view = gMatStack[matStackIndex]
    if view ~= nil then
        view.m00 = -(view.m00 or 0)
        view.m10 = -(view.m10 or 0)
        view.m20 = -(view.m20 or 0)
        view.m30 = -(view.m30 or 0)
    end

    if gMatStackPrev == nil then return end
    local prev = gMatStackPrev[matStackIndex]
    if prev ~= nil then
        prev.m00 = -(prev.m00 or 0)
        prev.m10 = -(prev.m10 or 0)
        prev.m20 = -(prev.m20 or 0)
        prev.m30 = -(prev.m30 or 0)
    end
end

modifiers.mirror_the_camera = mirror_the_camera

do

local mirrorFlipFrom = nil
local mirrorFlipped = true

local mirrorSpared = false

function modifiers.forget_mirror_flip()
    mirrorFlipFrom = nil
    mirrorFlipped = true
    mirrorSpared = false
end

function modifiers.mirror_live()
    if not modifiers.is_on("mirror") then return false end

    if modifiers.setting("mirror", "spare", nil) == "leader" then
        return not mirrorSpared
    end

    local every = modifiers.setting("mirror", "every", nil)
    if every ~= nil then
        return mirrorFlipped
    end

    return true
end

local function ask_the_board()
    if gNetworkPlayers == nil or gNetworkPlayers[0] == nil then return false end
    if not OF.util.asks(OF.gamemodes, "podium") then return false end
    local ok, board = pcall(OF.gamemodes.podium)
    if not ok or type(board) ~= "table" or board[1] == nil then return false end
    return board[1].localIndex == 0
end

local SPARE_SETTLE = 60
local spareHold = 0

local function mirror_flip_frame()
    if not modifiers.is_on("mirror") then
        mirrorFlipFrom = nil
        return
    end

    local every = modifiers.setting("mirror", "every", nil)
    if every ~= nil and every > 0 then
        local now = OF.util.optional("get_global_timer", 0) or 0
        if mirrorFlipFrom == nil then mirrorFlipFrom = now end

        local turns = math.floor((now - mirrorFlipFrom + 1) / every)
        mirrorFlipped = (turns % 2) == 0
    else
        mirrorFlipFrom = nil
    end

    if modifiers.setting("mirror", "spare", nil) == "leader" then
        if spareHold > 0 then
            spareHold = spareHold - 1
        else
            local now = ask_the_board()
            if now ~= mirrorSpared then
                mirrorSpared = now
                spareHold = SPARE_SETTLE
            end
        end
    else
        mirrorSpared = false
        spareHold = 0
    end

    modifiers.mirror_cull_live(modifiers.mirror_live())
end

hook_event(HOOK_UPDATE, mirror_flip_frame)
end

function modifiers.mirroring()
    return modifiers.mirror_live()
end

function modifiers.mirror_screen_x(x, width)
    if x == nil or not modifiers.mirroring() then return x end
    if width == nil then
        width = OF.util.optional("djui_hud_get_screen_width", nil)
    end
    if type(width) ~= "number" or width <= 0 then return x end
    return width - x
end

local G_GEOMETRYMODE_OP = 0xD9
local CULL_INVERT       = 0x00000100
local GEOMETRY_WORD     = 0x00FFFFFF

local SYNC_OPS = { [0xE6] = true, [0xE7] = true, [0xE8] = true }

local DL_NODE_TYPES = {
    [0x015] = true, [0x016] = true, [0x017] = true, [0x019] = true,
    [0x01A] = true, [0x01B] = true, [0x01C] = true, [0x01D] = true,
    [0x030] = true,
}

local CULL_BUDGET = 4096

local cullInverted = false

local cullEverOn = false

local cullChanged = 0

local cullNode = nil

local CULL_EVERY = 15
local cullTick = 0

local cullSettling = false

local function cull_is_spent(cmd)
    return ((~(cmd.w0 or 0)) & GEOMETRY_WORD) == 0
        and ((cmd.w1 or 0) & GEOMETRY_WORD) == CULL_INVERT
end

local function cull_rewrite(cmd, op, wanted)
    if op ~= G_GEOMETRYMODE_OP then return false end

    if not wanted and cull_is_spent(cmd) then return false end
    if gfx_set_command == nil then return true end

    local w0 = cmd.w0 or 0
    local set = (cmd.w1 or 0) & GEOMETRY_WORD

    local clear = (~w0) & GEOMETRY_WORD

    if ((set & CULL_INVERT) ~= 0) == (wanted and true or false)
        and (clear & CULL_INVERT) == 0 then
        return true
    end

    clear = clear & ~CULL_INVERT
    if wanted then
        set = set | CULL_INVERT
    else
        set = set & ~CULL_INVERT
    end

    cullChanged = cullChanged + 1
    gfx_set_command(cmd, "gsSPGeometryMode(%i, %i)", clear, set)
    return true
end

local function cull_spend_sync(cmd, op, wanted)
    if wanted then
        if not SYNC_OPS[op] then return false end
        if gfx_set_command == nil then return true end
        cullChanged = cullChanged + 1
        gfx_set_command(cmd, "gsSPGeometryMode(%i, %i)", 0, CULL_INVERT)
        return true
    end

    if op ~= G_GEOMETRYMODE_OP then return false end
    if not cull_is_spent(cmd) then return false end
    if gfx_set_command == nil then return true end
    cullChanged = cullChanged + 1
    gfx_set_command(cmd, "gsDPPipeSync()")
    return true
end

local function cull_patch_list(gfx, wanted)
    if gfx == nil or gfx_parse == nil then return end

    local touched = 0
    gfx_parse(gfx, function(cmd, op)
        if cull_rewrite(cmd, op, wanted) then touched = touched + 1 end
    end)
    if touched > 0 then return end

    gfx_parse(gfx, function(cmd, op)
        return cull_spend_sync(cmd, op, wanted)
    end)
end

local function cull_walk(first, wanted, budget)
    if first == nil or budget <= 0 then return budget end
    local node = first
    repeat
        budget = budget - 1
        if budget <= 0 then return 0 end
        local kind = node.type
        if kind ~= nil and DL_NODE_TYPES[kind] and cast_graph_node ~= nil then
            local shaped = cast_graph_node(node)
            if shaped ~= nil then cull_patch_list(shaped.displayList, wanted) end
        end
        budget = cull_walk(node.children, wanted, budget)
        node = node.next
    until node == nil or node == first or budget <= 0
    return budget
end

local function cull_level(wanted, budget)
    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    local area = me ~= nil and me.area or nil
    local root = area ~= nil and area.root or nil
    local top = root ~= nil and root.node or nil
    if top == nil then return budget end
    return cull_walk(top.children, wanted, budget)
end

local function cull_models(wanted, budget)
    if obj_get_first == nil or obj_get_next == nil then return budget end
    local seen, seenCount = {}, 0
    for list = 0, 12 do
        local object = obj_get_first(list)
        while object ~= nil and budget > 0 do
            local gfxNode = object.header ~= nil and object.header.gfx or nil
            local shared = gfxNode ~= nil and gfxNode.sharedChild or nil
            if shared ~= nil then
                local already = false
                for index = 1, seenCount do
                    if seen[index] == shared then
                        already = true
                        break
                    end
                end
                if not already then
                    seenCount = seenCount + 1
                    seen[seenCount] = shared
                    budget = cull_walk(shared, wanted, budget)
                end
            end
            object = obj_get_next(object)
        end
    end
    return budget
end

local function cull_all(wanted, modelsOnly)
    cullChanged = 0
    if gfx_parse == nil or gfx_set_command == nil then return 0 end

    local budget = CULL_BUDGET
    if not modelsOnly then budget = cull_level(wanted, budget) end
    cull_models(wanted, budget)
    return cullChanged
end

function modifiers.mirror_cull(wanted)
    cullInverted = wanted and true or false
    if cullInverted then
        cullEverOn = true
        cullSettling = false
    else

        cullSettling = cullEverOn
    end
    cullTick = 0
    cullNode = mirror_camera_here()
    return cull_all(cullInverted)
end

function modifiers.mirror_cull_on()
    return cullInverted and true or false
end

function modifiers.mirror_cull_live(live)
    live = live and true or false
    if live == cullInverted then return false end
    modifiers.mirror_cull(live)
    return true
end

function modifiers.mirror_cull_again()
    if not cullInverted and not cullEverOn then return 0 end
    if not cullInverted then cullSettling = true end
    cullTick = 0
    cullNode = mirror_camera_here()
    return cull_all(cullInverted)
end

function modifiers.wear_mirror(on)
    if not on then

        modifiers.mirror_signs(false)
        mirror_unmark()
        modifiers.mirror_cull(false)
        modifiers.forget_mirror_flip()
        return true
    end
    mirrorUnseen = 0
    modifiers.forget_mirror_flip()
    local marked = mirror_mark()

    modifiers.mirror_cull(modifiers.mirror_live())
    return marked
end

local function mirror_watch()
    if not modifiers.is_on("mirror") then return end
    mirrorUnseen = mirrorUnseen + 1
    if mirrorUnseen <= MIRROR_PATIENCE then return end
    mirrorUnseen = 0
    mirror_mark()

    modifiers.mirror_cull_again()
end

modifiers.mirror_watch = mirror_watch

local function cull_watch()
    if not cullInverted and not cullEverOn then return false end

    cullTick = cullTick + 1
    if cullTick < CULL_EVERY then return false end
    cullTick = 0

    local node = mirror_camera_here()
    local moved = node ~= cullNode
    cullNode = node

    if not cullInverted and not cullSettling and not moved then return false end

    local changed = cull_all(cullInverted, not moved)
    if cullInverted then
        cullSettling = false
    elseif moved or changed > 0 then

        cullSettling = true
    else

        cullSettling = false
    end
    return true
end

modifiers.cull_watch = cull_watch

local function mirror_the_stick(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if modifiers.setting("mirror", "stick", false) ~= true then return end

    if not modifiers.mirror_live() then return end
    if OF.util.menu_has_screen() then return end

    local c = m.controller
    if c == nil then return end
    c.stickX = -(c.stickX or 0)

    c.buttonDown = modifiers.swap_c_sides(c.buttonDown)
    c.buttonPressed = modifiers.swap_c_sides(c.buttonPressed)
end

modifiers.mirror_the_stick = mirror_the_stick

function modifiers.swap_c_sides(word)
    if word == nil or L_CBUTTONS == nil or R_CBUTTONS == nil then return word end
    local left = OF.util.has_flag(word, L_CBUTTONS)
    local right = OF.util.has_flag(word, R_CBUTTONS)
    if left == right then return word end
    if left then return word - L_CBUTTONS + R_CBUTTONS end
    return word - R_CBUTTONS + L_CBUTTONS
end

do
modifiers.MIRROR_SIGNS = { "DIALOG_001", "DIALOG_088", "DIALOG_089", "DIALOG_122",
    "DIALOG_123", "DIALOG_127", "DIALOG_138", "DIALOG_140" }
local mirroredSigns = {}
local signsLive = false

function modifiers.swap_left_right(text)
    if type(text) ~= "string" then return text end
    local swap = {
        left = "right", right = "left", Left = "Right", Right = "Left",
        LEFT = "RIGHT", RIGHT = "LEFT",
    }
    return (text:gsub("%f[%a](%a+)%f[%A]", function(word)
        return swap[word] or word
    end))
end

function modifiers.mirror_signs(on)
    if OF.util.binding("smlua_text_utils_dialog_get") == nil then return false end
    if on then
        for _, name in ipairs(modifiers.MIRROR_SIGNS) do
            local id = _G[name]
            if id ~= nil and not mirroredSigns[id] then
                local entry = OF.util.optional("smlua_text_utils_dialog_get", nil, id)
                if entry ~= nil and not entry.replaced and type(entry.text) == "string" then
                    OF.util.optional("smlua_text_utils_dialog_replace", nil, id,
                        entry.unused or 1, entry.linesPerBox, entry.leftOffset,
                        entry.width, modifiers.swap_left_right(entry.text))
                    mirroredSigns[id] = true
                end
            end
        end
    else
        for id in pairs(mirroredSigns) do
            OF.util.optional("smlua_text_utils_dialog_restore", nil, id)
        end
        mirroredSigns = {}
    end
    signsLive = on and true or false
    return true
end

function modifiers.mirror_signs_watch()
    local live = modifiers.mirror_live() == true
    if live == signsLive then return false end
    return modifiers.mirror_signs(live)
end
end

function modifiers.mirror_note()
    if not modifiers.is_on("mirror") then return nil end

    return OF.lang.t("The sky does not flip. Writing reads backwards.")
end

hook_event(HOOK_ON_GEO_PROCESS, mirror_the_camera)
hook_event(HOOK_BEFORE_MARIO_UPDATE, mirror_the_stick, OF.LOCAL_MARIO)
hook_event(HOOK_UPDATE, mirror_watch)
hook_event(HOOK_UPDATE, cull_watch)
hook_event(HOOK_UPDATE, function() modifiers.mirror_signs_watch() end)

hook_event(HOOK_ON_LEVEL_INIT, function() modifiers.mirror_cull_again() end)

hook_event(HOOK_ON_OBJECT_LOAD, function()
    if cullEverOn and not cullInverted then cullSettling = true end
end)

local function char_sound_set(names)
    local set = {}
    for _, name in ipairs(names) do
        local value = _G[name]
        if type(value) == "number" then set[value] = true end
    end
    return set
end

local VOICE_JUMP = char_sound_set({
    "CHAR_SOUND_YAH_WAH_HOO", "CHAR_SOUND_HOOHOO", "CHAR_SOUND_YAHOO",
    "CHAR_SOUND_WAH2", "CHAR_SOUND_HERE_WE_GO", "CHAR_SOUND_YAHOO_WAHA_YIPPEE",
    "CHAR_SOUND_TWIRL_BOUNCE", "CHAR_SOUND_LETS_A_GO",
})

local VOICE_HURT = char_sound_set({
    "CHAR_SOUND_UH", "CHAR_SOUND_WHOA", "CHAR_SOUND_EEUH", "CHAR_SOUND_ATTACKED",
    "CHAR_SOUND_OOOF", "CHAR_SOUND_OOOF2", "CHAR_SOUND_WAAAOOOW",
    "CHAR_SOUND_UH2", "CHAR_SOUND_UH2_2", "CHAR_SOUND_ON_FIRE",
    "CHAR_SOUND_DOH",
})

local VOICE_DYING = char_sound_set({
    "CHAR_SOUND_DYING", "CHAR_SOUND_DROWNING", "CHAR_SOUND_GAME_OVER",
})

local VOICE_QUIET = char_sound_set({
    "CHAR_SOUND_HRMM", "CHAR_SOUND_YAWNING", "CHAR_SOUND_SNORING1",
    "CHAR_SOUND_SNORING2", "CHAR_SOUND_SNORING3", "CHAR_SOUND_PANTING_COLD",
    "CHAR_SOUND_PANTING", "CHAR_SOUND_COUGHING1", "CHAR_SOUND_COUGHING2",
    "CHAR_SOUND_COUGHING3", "CHAR_SOUND_IMA_TIRED",
})

modifiers.VOICE_JUMP, modifiers.VOICE_HURT, modifiers.VOICE_QUIET =
    VOICE_JUMP, VOICE_HURT, VOICE_QUIET
modifiers.VOICE_DYING = VOICE_DYING

function modifiers.voice_for(characterSound)
    if type(characterSound) ~= "number" then return nil end
    local voice = modifiers.setting("voice", "voice", nil)
    if voice == nil then return nil end
    if voice.silent then return 0 end

    local pick
    if VOICE_JUMP[characterSound] then pick = voice.jump

    elseif VOICE_DYING[characterSound] then pick = voice.dying or voice.hurt
    elseif VOICE_HURT[characterSound] then pick = voice.hurt
    elseif VOICE_QUIET[characterSound] then pick = voice.quiet
    else pick = voice.other end

    if type(pick) ~= "number" then return nil end
    return pick
end

local function speak(m, characterSound)
    local sound = modifiers.voice_for(characterSound)
    if sound == nil then return nil end
    if sound == 0 then return 0 end

    local obj = m ~= nil and m.marioObj or nil
    local pos = obj ~= nil and obj.header ~= nil and obj.header.gfx ~= nil
        and obj.header.gfx.cameraToObject or nil
    local play = OF.util.binding("play_sound")
    if pos == nil or play == nil then return nil end
    play(sound, pos)
    return 0
end

modifiers.speak = speak

hook_event(HOOK_CHARACTER_SOUND, speak)

function modifiers.wear_sun(dir)
    if OF.util.binding("set_lighting_dir") == nil then return false end

    if OF.util.asks(OF.stretch, "relight") then
        OF.stretch.relight(modifiers.level("sun") > 0 and dir or nil)
    end

    if dir == nil then

        if modifiers.sunHeld == nil then return true end
        for i = 0, 2 do
            OF.util.optional("set_lighting_dir", nil, i, modifiers.sunHeld[i + 1])
        end
        modifiers.sunHeld = nil
        return true
    end

    if modifiers.sunHeld == nil then
        modifiers.sunHeld = {}
        for i = 0, 2 do
            modifiers.sunHeld[i + 1] = OF.util.optional("get_lighting_dir", 0, i) or 0
        end
    end
    for i = 0, 2 do
        OF.util.optional("set_lighting_dir", nil, i, dir[i + 1] or 0)
    end
    return true
end

do

    local LEADER_EVERY = 30

    local leaderStamp = nil
    local leaderDir = nil

    function modifiers.forget_sun_leader()
        leaderStamp = nil
        leaderDir = nil
    end

    local function leader_dir()
        local now = OF.util.optional("get_global_timer", 0) or 0
        if leaderStamp ~= nil and now >= leaderStamp
            and now - leaderStamp < LEADER_EVERY then
            return leaderDir
        end
        leaderStamp = now
        leaderDir = { 0, 1, 0 }

        if not OF.util.asks(OF.gamemodes, "podium") then return leaderDir end
        local ok, board = pcall(OF.gamemodes.podium)
        if not ok or type(board) ~= "table" or board[1] == nil then
            return leaderDir
        end
        local top = board[1].localIndex
        local me = gMarioStates ~= nil and gMarioStates[0] or nil
        local them = gMarioStates ~= nil and gMarioStates[top] or nil
        if top == 0 or me == nil or them == nil
            or me.pos == nil or them.pos == nil then
            return leaderDir
        end
        local dx = them.pos.x - me.pos.x
        local dz = them.pos.z - me.pos.z
        local away = math.sqrt(dx * dx + dz * dz)

        if away < 1 then return leaderDir end
        leaderDir = { dx / away, 0.4, dz / away }
        return leaderDir
    end

    modifiers.leader_dir = leader_dir

    function modifiers.sun_wanted()
        if modifiers.level("sun") <= 0 then return nil end

        local dir = modifiers.setting("sun", "dir", nil)
        if dir ~= nil then return dir end

        if modifiers.setting("sun", "leader", false) == true then
            return leader_dir()
        end

        if modifiers.setting("sun", "fromSky", false) == true then
            return modifiers.sun_of_the_sky()
        end

        return nil
    end
end

local SUN_TURN = 90 * 30

local function turn_the_sun()
    local hours = modifiers.setting("sun", "hours", nil)
    if hours ~= true then return end
    if OF.util.binding("set_lighting_dir") == nil then return end

    local now = OF.util.optional("get_global_timer", 0) or 0

    local turn = modifiers.setting("sun", "turn", SUN_TURN)
    if turn <= 0 then turn = SUN_TURN end
    local angle = (now % turn) / turn * math.pi * 2

    modifiers.wear_sun({ math.sin(angle), math.cos(angle) * 0.8, 0 })
end

modifiers.turn_the_sun = turn_the_sun

hook_event(HOOK_UPDATE, turn_the_sun)

do
local SHOULDER_LIFT = 0.45
local SHOULDER_REACH = 0.8

local function aim_over_the_shoulder()
    if modifiers.setting("sun", "shoulder", nil) ~= true then return end
    if OF.util.binding("set_lighting_dir") == nil then return end
    local eye = gLakituState
    if eye == nil or eye.pos == nil or eye.focus == nil then return end

    local dx = eye.pos.x - eye.focus.x
    local dz = eye.pos.z - eye.focus.z
    local away = math.sqrt(dx * dx + dz * dz)

    if away < 1 then
        modifiers.wear_sun({ 0, 1, 0 })
        return
    end
    modifiers.wear_sun({
        dx / away * SHOULDER_REACH,
        SHOULDER_LIFT,
        dz / away * SHOULDER_REACH,
    })
end

modifiers.aim_over_the_shoulder = aim_over_the_shoulder

hook_event(HOOK_UPDATE, aim_over_the_shoulder)
end

do

local CLOUD_FALL = 260
local CLOUD_LIFE = 6 * 30
local CLOUD_DROP = 40

local CLOUD_REACH = 500

local CLOUD_LAND = 1150
local CLOUD_GRACE = 3

local CLOUD_HOLD = 45

local clouds = {}
local cloudsLeft = 0
local cloudLevel = nil
local safeY = nil

local airFrames = 0
local catchHold = 0
local regrowFrames = 0

function modifiers.clouds_left()
    return cloudsLeft
end

function modifiers.cloud_max()
    local level = modifiers.level("cloud")
    if level <= 0 then return 0 end
    return modifiers.setting("cloud", "saves", level)
end

function modifiers.cloud_regen_seconds()
    return modifiers.setting("cloud", "regen", 40)
end

function modifiers.cloud_landing()
    return CLOUD_LAND
end

function modifiers.cloud_note()
    local most = modifiers.cloud_max()
    if most <= 0 then return nil end
    if cloudsLeft >= most then
        return OF.lang.fill("@ of @ ready", tostring(cloudsLeft), tostring(most))
    end
    local left = math.max(0,
        math.ceil((modifiers.cloud_regen_seconds() * 30 - regrowFrames) / 30))

    return OF.lang.fill("@ ready, another in @s",
        OF.lang.fill("@ of @", tostring(cloudsLeft), tostring(most)),
        tostring(left))
end

function modifiers.cloud_drop_total()
    return CLOUD_FALL + CLOUD_DROP
end

function modifiers.cloud_reach()
    return CLOUD_REACH
end

function modifiers.clear_clouds()
    for _, entry in ipairs(clouds) do
        if entry.object ~= nil then
            OF.util.optional("obj_mark_for_deletion", nil, entry.object)
        end
    end
    clouds = {}
    cloudsLeft = 0
    cloudLevel = nil
    safeY = nil
    airFrames = 0
    catchHold = 0
    regrowFrames = 0
end

local function cloud_budget()
    return modifiers.cloud_max()
end

local function regrow_frames()
    return math.max(1, math.floor(modifiers.cloud_regen_seconds() * 30))
end

local function about_to_land(m)
    local floor = m.floor
    if floor == nil then return false end
    local kind = floor.type
    if kind == SURFACE_DEATH_PLANE or kind == SURFACE_VERTICAL_WIND
        or kind == SURFACE_BURNING then
        return false
    end
    local height = m.floorHeight
    if type(height) ~= "number" then return false end
    return (m.pos.y - height) <= CLOUD_LAND
end

local function cloud_update()
    local budget = cloud_budget()
    if budget <= 0 then return end

    if OF.util.asks(OF.roundscope, "shares_room_with_round")
        and OF.roundscope.shares_room_with_round() then return end

    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or m.pos == nil or np == nil then return end

    if cloudLevel ~= np.currLevelNum then
        modifiers.clear_clouds()
        cloudLevel = np.currLevelNum
        cloudsLeft = budget
    end

    if cloudsLeft > budget then cloudsLeft = budget end

    if cloudsLeft < budget then
        regrowFrames = regrowFrames + 1
        if regrowFrames >= regrow_frames() then
            regrowFrames = 0
            cloudsLeft = cloudsLeft + 1

            OF.notify.show("A cloud grew back - @ ready", "info", 2,
                tostring(cloudsLeft))
        end
    else
        regrowFrames = 0
    end

    if catchHold > 0 then catchHold = catchHold - 1 end

    for index = #clouds, 1, -1 do
        local entry = clouds[index]
        entry.frames = entry.frames - 1
        if entry.frames <= 0 then
            if entry.object ~= nil then
                OF.util.optional("obj_mark_for_deletion", nil, entry.object)
            end
            table.remove(clouds, index)
        end
    end

    if not OF.util.can_play(0) then return end

    if math.abs(m.pos.y - (m.floorHeight or m.pos.y)) < 30 then
        safeY = m.pos.y
        airFrames = 0
        return
    end
    if safeY == nil then return end

    if (m.vel ~= nil and m.vel.y or 0) >= 0 then
        airFrames = 0
        return
    end
    airFrames = airFrames + 1
    if m.pos.y > safeY - CLOUD_FALL then return end
    if airFrames < CLOUD_GRACE then return end

    if about_to_land(m) then return end

    if catchHold > 0 then return end
    if cloudsLeft <= 0 then return end

    if spawn_sync_object == nil or id_bhvStaticCheckeredPlatform == nil then
        return
    end
    local made = spawn_sync_object(id_bhvStaticCheckeredPlatform,
        E_MODEL_CHECKERBOARD_PLATFORM,
        m.pos.x, m.pos.y - CLOUD_DROP, m.pos.z, nil)

    if made == nil then return end

    table.insert(clouds, { object = made, frames = CLOUD_LIFE })
    cloudsLeft = cloudsLeft - 1
    catchHold = CLOUD_HOLD

    regrowFrames = 0

    safeY = m.pos.y - CLOUD_DROP
    airFrames = 0
    OF.notify.show("A cloud catches you - @ left", "good", 4,
        tostring(cloudsLeft))
end

modifiers.cloud_update = cloud_update

hook_event(HOOK_UPDATE, cloud_update)

end

do
local DEMON_SPEEDS = { 11, 23, 29 }
local DEMON_REACH = 90
local DEMON_START = 700
local DEMON_WOKE = 120

local DEMON_TRAIL_COST = 30

local DEMON_TRAIL_BUDGET = 150

local DEMON_TRAIL_CEILING = 600
local trailAllowed = true
local trailStride = 1

local demons = {}
local demonWokeAt = {}
local demonLevel = {}
local demonArea = {}
local demonHome = {}

function modifiers.demon_home(localIndex)
    return demonHome[localIndex or 0]
end

function modifiers.is_demon_object(demon)
    if demon == nil then return false end

    local ok, flags = pcall(function() return demon.activeFlags end)
    if not ok or type(flags) ~= "number" or flags == 0 then return false end
    if OF.util.optional("obj_has_behavior_id", 1, demon, id_bhvStaticObject) ~= 1 then
        return false
    end
    if OF.util.optional("obj_has_model_extended", 1, demon, E_MODEL_1UP) ~= 1 then
        return false
    end
    return true
end

local function demon_is_ours(localIndex)
    return modifiers.is_demon_object(demons[localIndex or 0])
end

modifiers.DEMON_SPEEDS = DEMON_SPEEDS
modifiers.DEMON_REACH = DEMON_REACH
modifiers.DEMON_START = DEMON_START

function modifiers.spawn_demon_object(x, y, z)
    if spawn_non_sync_object == nil or id_bhvStaticObject == nil then
        return nil
    end
    local made = spawn_non_sync_object(id_bhvStaticObject, E_MODEL_1UP,
        x, y, z, nil)
    if made == nil then return nil end

    OF.util.optional("obj_set_billboard", nil, made)
    return made
end

function modifiers.demon_sparkle(demon)
    if demon == nil then return end
    OF.util.optional("spawn_non_sync_object", nil, id_bhvSparkleSpawn,
        E_MODEL_NONE, demon.oPosX, demon.oPosY, demon.oPosZ, nil)
end

modifiers.demon_is_ours = demon_is_ours

function modifiers.demon_allowed(levelNum)
    if levelNum == nil then return false end
    return (OF.util.course_of_level(levelNum) or 0) > 0
end

modifiers.DEMON_OPTS_KEY = "ofDemonOpts"
modifiers.DEMON_OPTS_ACTION = "demonopt"
modifiers.DEMON_OPTS = {
    { key = "where", name = "Where it hunts",
      help = "which levels a demon may follow you into",
      steps = { "the fifteen courses", "every level but the castle", "everywhere" } },
    { key = "catch", name = "When it catches you",
      help = "what a catch costs the player it reached",
      steps = { "you die", "three wedges of health", "back to the level's entry" } },
    { key = "wake", name = "When it starts",
      help = "whether it waits for your first steps in a level",
      steps = { "on your first steps", "at once" } },
    { key = "start", name = "Where it appears",
      help = "how far behind you it turns up",
      steps = { "well behind you", "close behind you", "far away" } },
    { key = "after", name = "After a catch",
      help = "whether a player it caught is chased again in the same level",
      steps = { "another one comes", "none until the next level" } },
    { key = "trail", name = "Its sparkle trail",
      help = "the running 1-UP's sparkles behind every demon",
      steps = { "shown", "hidden" } },
}
local DEMON_STARTS = { DEMON_START, 350, 1400 }

function modifiers.demon_opt(key)
    local text = gGlobalSyncTable[modifiers.DEMON_OPTS_KEY]
    if type(text) ~= "string" then text = "" end
    for index, row in ipairs(modifiers.DEMON_OPTS) do
        if row.key == key then
            local step = tonumber(string.sub(text, index, index)) or 1
            if step < 1 or step > #row.steps then step = 1 end
            return step
        end
    end
    return 1
end

function modifiers.reset_options()
    if not OF.util.is_host() then return false end
    local was = gGlobalSyncTable[modifiers.DEMON_OPTS_KEY]
    if was == nil or was == "" then return false end
    OF.util.publish(modifiers.DEMON_OPTS_KEY, nil)
    return true
end

function modifiers.set_demon_opt(key, step, askerLocal)
    if askerLocal == nil and not OF.perms.can(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(modifiers.DEMON_OPTS_ACTION, tonumber(step), nil,
                tostring(key))
        end
        return false, "No host to ask yet - try again in a second."
    end
    local digits, found = {}, false
    for index, row in ipairs(modifiers.DEMON_OPTS) do
        local now = modifiers.demon_opt(row.key)
        if row.key == key then
            now = math.floor(tonumber(step) or 1)
            if now < 1 or now > #row.steps then now = 1 end
            found = true
        end
        digits[index] = tostring(now)
    end
    if not found then return false, "No such setting." end
    OF.util.publish(modifiers.DEMON_OPTS_KEY, table.concat(digits))
    return true
end

function modifiers.reset_demon_opts(askerLocal)
    if askerLocal == nil and not OF.perms.can(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(modifiers.DEMON_OPTS_ACTION, 0, nil, "reset")
        end
        return false, "No host to ask yet - try again in a second."
    end
    OF.util.publish(modifiers.DEMON_OPTS_KEY, nil)
    return true
end

function modifiers.demon_hunts_in(levelNum)
    if levelNum == nil or levelNum <= 0 then return false end
    local where = modifiers.demon_opt("where")
    if where == 3 then return true end
    if where == 2 then
        return levelNum ~= LEVEL_CASTLE and levelNum ~= LEVEL_CASTLE_GROUNDS
            and levelNum ~= LEVEL_CASTLE_COURTYARD
    end
    return modifiers.demon_allowed(levelNum)
end

function modifiers.demon_start_distance()
    return DEMON_STARTS[modifiers.demon_opt("start")] or DEMON_START
end

local demonDone = {}

function modifiers.demon_catch(m)
    if m == nil then return end
    local catch = modifiers.demon_opt("catch")
    if catch == 2 then

        m.hurtCounter = math.max(m.hurtCounter or 0, 12)
    elseif catch == 3 then
        if OF.util.asks(OF.net, "reload_here") then OF.net.reload_here() end
    else
        m.hurtCounter = 31
    end
end

local STRANGERS_WORTH_SAYING = 8

function modifiers.demon_note()
    local speed = modifiers.setting("demon", "speed", nil)
    if speed == nil then return nil end
    local np = gNetworkPlayers[0]
    if np == nil or not modifiers.demon_hunts_in(np.currLevelNum) then
        return OF.lang.t("It does not hunt here - see Where it hunts.")
    end
    local step = DEMON_SPEEDS[speed] or DEMON_SPEEDS[1]

    local refused, strangers = modifiers.demon_faults()
    if (refused or 0) > 0 or (strangers or 0) > STRANGERS_WORTH_SAYING then
        return OF.lang.fill("@ per frame - @", step,
            tostring(refused or 0) .. " refused, "
                .. tostring(strangers or 0) .. " re-made.")
    end

    if #OF.util.connected_players() > 1 then
        return OF.lang.fill("@ per frame - @ chases running here.",
            step, modifiers.demon_count())
    end
    return OF.lang.fill("@ per frame - a run is 32.", step)
end

function modifiers.demon_awake(localIndex)
    local index = localIndex or 0
    return demons[index] ~= nil and demonWokeAt[index] ~= nil
end

function modifiers.demon_count()
    local n = 0
    for _ in pairs(demons) do n = n + 1 end
    return n
end

modifiers.demonRefused = 0
modifiers.demonStrangers = 0

function modifiers.demon_faults()
    return modifiers.demonRefused, modifiers.demonStrangers
end

function modifiers.clear_demon(localIndex)

    if localIndex == nil then
        for index in pairs(demons) do modifiers.clear_demon(index) end
        demonWokeAt = {}
        demonLevel = {}
        demonArea = {}
        demonHome = {}
        return
    end

    if demons[localIndex] ~= nil then
        if demon_is_ours(localIndex) then
            OF.util.optional("obj_mark_for_deletion", nil, demons[localIndex])
        end
        demons[localIndex] = nil
    end
    demonWokeAt[localIndex] = nil
    demonLevel[localIndex] = nil
    demonArea[localIndex] = nil

    demonHome[localIndex] = nil
end

local function chase_one(localIndex, speed)
    local m = gMarioStates[localIndex]
    local np = gNetworkPlayers[localIndex]
    if m == nil or m.pos == nil or np == nil then return end
    if not np.connected then
        modifiers.clear_demon(localIndex)
        return
    end

    if localIndex ~= 0 and np.currPositionValid == false then
        modifiers.clear_demon(localIndex)
        return
    end

    if demonLevel[localIndex] ~= np.currLevelNum
        or demonArea[localIndex] ~= np.currAreaIndex then
        modifiers.clear_demon(localIndex)
        demonLevel[localIndex] = np.currLevelNum
        demonArea[localIndex] = np.currAreaIndex
    end

    if not modifiers.demon_hunts_in(np.currLevelNum) then
        modifiers.clear_demon(localIndex)
        return
    end

    if demonDone[localIndex] ~= nil then
        if demonDone[localIndex] == np.currLevelNum
            and modifiers.demon_opt("after") == 2 then
            return
        end
        demonDone[localIndex] = nil
    end

    if not OF.util.can_play(localIndex) then return end

    if demons[localIndex] ~= nil and not demon_is_ours(localIndex) then
        demons[localIndex] = nil
        demonWokeAt[localIndex] = nil
        demonHome[localIndex] = nil
        modifiers.demonStrangers = modifiers.demonStrangers + 1
    end

    if demons[localIndex] == nil then
        if spawn_non_sync_object == nil or id_bhvStaticObject == nil then
            return
        end

        local away = modifiers.demon_start_distance()
        local made = modifiers.spawn_demon_object(
            m.pos.x - sins(m.faceAngle.y) * away,
            m.pos.y + 60,
            m.pos.z - coss(m.faceAngle.y) * away)

        if made == nil then
            modifiers.demonRefused = modifiers.demonRefused + 1
            return
        end
        demons[localIndex] = made

        if localIndex == 0 then
            OF.util.optional("play_sound", nil, SOUND_GENERAL2_1UP_APPEAR,
                gGlobalSoundSource)
        end
        demonWokeAt[localIndex] = nil

        if modifiers.demon_opt("wake") == 2 then
            demonWokeAt[localIndex] = OF.util.optional("get_global_timer", 0) or 0
        end
        demonHome[localIndex] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
        return
    end

    local demon = demons[localIndex]

    if demonWokeAt[localIndex] == nil then
        local home = demonHome[localIndex]
        if home == nil then
            demonHome[localIndex] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
            return
        end
        local dx, dz = m.pos.x - home.x, m.pos.z - home.z
        if dx * dx + dz * dz < DEMON_WOKE * DEMON_WOKE then return end
        demonWokeAt[localIndex] = OF.util.optional("get_global_timer", 0) or 0

        if localIndex == 0 then
            OF.notify.show("It has noticed you", "bad", 4)
        end
    end

    local dx = m.pos.x - demon.oPosX
    local dy = m.pos.y + 60 - demon.oPosY
    local dz = m.pos.z - demon.oPosZ
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    if distance < DEMON_REACH then

        if localIndex == 0 then

            modifiers.demon_catch(m)
        end
        modifiers.clear_demon(localIndex)
        demonDone[localIndex] = np.currLevelNum
        return
    end

    if distance > 0.001 then
        local step = DEMON_SPEEDS[speed] or DEMON_SPEEDS[1]
        demon.oPosX = demon.oPosX + dx / distance * step
        demon.oPosY = demon.oPosY + dy / distance * step
        demon.oPosZ = demon.oPosZ + dz / distance * step

        local mine = (localIndex or 0) == 0
        if trailAllowed and modifiers.demon_opt("trail") == 1 and (mine or trailStride <= 1
            or ((OF.util.optional("get_global_timer", 0) or 0) + localIndex)
                % trailStride == 0) then
            modifiers.demon_sparkle(demon)
        end
    end

    local ground = OF.util.optional("find_floor_height", nil,
        demon.oPosX, demon.oPosY + 200, demon.oPosZ)
    if ground ~= nil and ground > -10000 and demon.oPosY < ground + 40 then
        demon.oPosY = ground + 40
    end
end

local function chase_update()

    local speed = modifiers.setting("demon", "speed", nil)
    if speed == nil then return end

    local running = modifiers.demon_count()
    local others = math.max(0, running - 1)
    if others == 0 then
        trailStride = 1
    else
        local each = (DEMON_TRAIL_BUDGET - DEMON_TRAIL_COST) / others
        trailStride = math.max(1, math.ceil(DEMON_TRAIL_COST / math.max(1, each)))
    end

    local held = OF.util.optional("count_unimportant_objects", false)
    trailAllowed = not (type(held) == "number" and held > DEMON_TRAIL_CEILING)

    chase_one(0, speed)
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 then chase_one(entry.localIndex, speed) end
    end
end

modifiers.chase_update = chase_update

hook_event(HOOK_UPDATE, chase_update)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    modifiers.clear_demon(m.playerIndex)
end)
end

function modifiers.wear_eyes(on)
    if OF.util.binding("set_first_person_enabled") == nil then return false end

    if not on then

        if modifiers.eyesHeld == nil then return true end
        OF.util.optional("set_first_person_enabled", nil, modifiers.eyesHeld)
        modifiers.eyesHeld = nil
        return true
    end

    if modifiers.eyesHeld == nil then

        modifiers.eyesHeld = gFirstPersonCamera ~= nil
            and gFirstPersonCamera.enabled == true or false
    end
    OF.util.optional("set_first_person_enabled", nil, true)
    return true
end

function modifiers.wear_view(view)
    local get = {
        "camera_romhack_get_zoomed_in_dist", "camera_romhack_get_zoomed_out_dist",
        "camera_romhack_get_zoomed_in_height", "camera_romhack_get_zoomed_out_height",
    }
    local set = {
        "camera_romhack_set_zoomed_in_dist", "camera_romhack_set_zoomed_out_dist",
        "camera_romhack_set_zoomed_in_height", "camera_romhack_set_zoomed_out_height",
    }
    if OF.util.binding(set[1]) == nil then return false end

    if view == nil then

        if modifiers.viewHeld == nil then return true end
        for i = 1, 4 do
            OF.util.optional(set[i], nil, modifiers.viewHeld[i])
        end
        OF.util.optional("camera_set_romhack_override", nil, modifiers.viewHeld[5])
        OF.util.optional("camera_romhack_allow_only_mods", nil, 0)

        OF.util.return_free_cam("viewModifier")
        OF.util.reset_camera_overrides()

        modifiers.viewHeld = nil
        return true
    end

    if modifiers.viewHeld == nil then
        local was = {}
        for i = 1, 4 do was[i] = OF.util.optional(get[i], nil) end
        was[5] = OF.util.optional("camera_get_romhack_override", nil)

        modifiers.viewHeld = was
    end

    OF.util.lend_free_cam("viewModifier")

    OF.util.optional("camera_romhack_allow_only_mods", nil, 1)

    OF.util.optional("camera_set_romhack_override", nil, RCO_ALL_INCLUDING_VANILLA)
    for i = 1, 4 do
        OF.util.optional(set[i], nil, view[i])
    end
    return true
end

modifiers.VISION_KEY = "ofVision"
modifiers.LOOKS = {
    { name = "black and white",
      blurb = "every colour drained out - the world in grey",
      look = {
        { SHADER_FLAG_SATURATION, 0.0 },
    } },
    { name = "an old photograph",
      blurb = "faded and warm, like a print left in a drawer",
      look = {
        { SHADER_FLAG_SATURATION, 0.25 },
        { SHADER_FLAG_HUE, 0.08 },
        { SHADER_FLAG_CONTRAST, 0.85 },
    } },
    { name = "a comic book",
      blurb = "loud colour in a few flat shades, hard-edged",
      look = {
        { SHADER_FLAG_POSTERIZATION, 3.0 },
        { SHADER_FLAG_CONTRAST, 1.35 },
        { SHADER_FLAG_SATURATION, 1.4 },
    } },
    { name = "a CRT in 1996",
      blurb = "banded and stippled, under lines across the glass",
      look = {
        { SHADER_FLAG_SCANLINES, 6.0 },
        { SHADER_FLAG_POSTERIZATION, 6.0 },
        { SHADER_FLAG_DITHERING, 1.0 },
    } },
    { name = "night vision",
      blurb = "green and hard, as through a scope",
      look = {
        { SHADER_FLAG_SATURATION, 0.0 },
        { SHADER_FLAG_HUE, 0.33 },
        { SHADER_FLAG_CONTRAST, 1.6 },
        { SHADER_FLAG_BRIGHTNESS, 1.3 },
    } },
    { name = "a fever dream",
      blurb = "colour spun round the wheel, past real",
      look = {
        { SHADER_FLAG_HUE, 0.5 },
        { SHADER_FLAG_SATURATION, 2.2 },
        { SHADER_FLAG_CONTRAST, 1.2 },
    } },

    { name = "a photo negative",
      blurb = "every channel reflected through mid grey",
      look = {
        { SHADER_FLAG_CONTRAST, -1.0 },
    } },
    { name = "sun-bleached",
      blurb = "bright and washed out, with the contrast gone",
      look = {
        { SHADER_FLAG_BRIGHTNESS, 1.6 },
        { SHADER_FLAG_SATURATION, 0.5 },
        { SHADER_FLAG_CONTRAST, 0.75 },
    } },

    { name = "newsprint",
      blurb = "halftone dots instead of shading, as cheap print",
      look = {
        { SHADER_FLAG_SATURATION, 0.0 },
        { SHADER_FLAG_BRIGHTNESS, 1.15 },
        { SHADER_FLAG_CONTRAST, 1.6 },
        { SHADER_FLAG_DITHERING, 1.0 },
    } },

    { name = "thermal",
      blurb = "the level read as heat, in banded false colour",
      look = {
        { SHADER_FLAG_HUE, 0.62 },
        { SHADER_FLAG_SATURATION, 3.0 },
        { SHADER_FLAG_BRIGHTNESS, 1.25 },
        { SHADER_FLAG_POSTERIZATION, 4.0 },
    } },

    { name = "bleach bypass",
      blurb = "silvery and harsh, with the blacks stretched flat",
      look = {
        { SHADER_FLAG_SATURATION, 0.3 },
        { SHADER_FLAG_CONTRAST, 1.9 },
        { SHADER_FLAG_EXPOSURE, 1.3 },
    } },

    { name = "moonless",
      blurb = "night that takes the sky with it, shading left in",
      look = {
        { SHADER_FLAG_BRIGHTNESS, 0.4 },
        { SHADER_FLAG_SATURATION, 0.45 },
        { SHADER_FLAG_CONTRAST, 1.25 },
    } },

    { name = "blown out",
      blurb = "overexposed - the highlights gone to white",
      look = {
        { SHADER_FLAG_BRIGHTNESS, 1.6 },
        { SHADER_FLAG_CONTRAST, 1.25 },
        { SHADER_FLAG_SATURATION, 0.7 },
    } },
    { name = "a cheap VHS",
      blurb = "soft, dull and lined, like a worn-out tape",
      look = {
        { SHADER_FLAG_SCANLINES, 3.0 },
        { SHADER_FLAG_SATURATION, 0.75 },
        { SHADER_FLAG_CONTRAST, 0.85 },
        { SHADER_FLAG_BRIGHTNESS, 1.1 },
    } },

    { name = "eight colours",
      blurb = "each channel down to two shades, and colour up",
      look = {
        { SHADER_FLAG_POSTERIZATION, 2.0 },
        { SHADER_FLAG_SATURATION, 1.5 },
    } },
    { name = "a blueprint",
      blurb = "cold blue ink on a hard, pale drawing ground",
      look = {
        { SHADER_FLAG_SATURATION, 0.0 },
        { SHADER_FLAG_HUE, 0.6 },
        { SHADER_FLAG_CONTRAST, 1.4 },
        { SHADER_FLAG_BRIGHTNESS, 0.85 },
    } },
}

modifiers.VISION_DIALS = {
    { flag = SHADER_FLAG_HUE, name = "Hue",
      blurb = "every colour walked round the wheel",
      from = 0, to = 1, step = 0.05, rest = 0.0 },
    { flag = SHADER_FLAG_SATURATION, name = "Saturation",
      blurb = "how much colour the world keeps",
      from = 0, to = 3, step = 0.1, rest = 1.0 },
    { flag = SHADER_FLAG_BRIGHTNESS, name = "Brightness",
      blurb = "lifts the picture before the contrast",
      from = 0, to = 3, step = 0.1, rest = 1.0 },

    { flag = SHADER_FLAG_CONTRAST, name = "Contrast",
      blurb = "pushes light and dark apart - under zero it swaps them",
      from = -1, to = 3, step = 0.05, rest = 1.0 },

    { flag = SHADER_FLAG_EXPOSURE, name = "Exposure",
      blurb = "lifts the picture after the contrast",
      from = 0, to = 3, step = 0.1, rest = 1.0 },
    { flag = SHADER_FLAG_POSTERIZATION, name = "Posterization",
      blurb = "how many shades a colour is cut to",
      from = 1, to = 16, step = 1, rest = 8.0 },
    { flag = SHADER_FLAG_SCANLINES, name = "Scanlines",
      blurb = "dark lines drawn across the picture",
      from = 0, to = 10, step = 0.5, rest = 1.0 },
}

modifiers.VISION_DITHER = SHADER_FLAG_DITHERING

local VISION_SEP = ","
local function vision_defaults()
    local dials = {}
    for index, dial in ipairs(modifiers.VISION_DIALS) do
        dials[index] = dial.rest
    end
    return dials, false
end

function modifiers.vision_pack(dials, dither)
    local parts = {}
    for index in ipairs(modifiers.VISION_DIALS) do
        parts[index] = string.format("%.2f", dials[index] or 0)
    end
    table.insert(parts, dither and "1" or "0")
    return table.concat(parts, VISION_SEP)
end

function modifiers.vision_parse(text)
    local dials, dither = vision_defaults()
    if type(text) ~= "string" or text == "" then return dials, dither end

    local index = 0
    for field in string.gmatch(text, "[^" .. VISION_SEP .. "]+") do
        index = index + 1
        if index <= #modifiers.VISION_DIALS then
            local value = tonumber(field)
            if value ~= nil then
                local dial = modifiers.VISION_DIALS[index]
                dials[index] = OF.util.clamp(value, dial.from, dial.to)
            end
        elseif index == #modifiers.VISION_DIALS + 1 then
            dither = (field == "1")
        end
    end
    return dials, dither
end

function modifiers.vision()
    return modifiers.vision_parse(gGlobalSyncTable[modifiers.VISION_KEY])
end

local MINE_KEY = "visionMine"
local MINE_ON_KEY = "visionMineOn"
local mineAt = nil
local mineDither = nil

local function same_dial(one, two)
    if one == nil or two == nil then return false end
    return math.abs(one - two) < 0.001
end

local function mine_unpack(text)
    local at, dither = {}, nil
    if type(text) ~= "string" or text == "" then return at, dither end
    local index = 0
    for field in string.gmatch(text .. VISION_SEP,
                               "([^" .. VISION_SEP .. "]*)" .. VISION_SEP) do
        index = index + 1
        if index <= #modifiers.VISION_DIALS then
            local value = tonumber(field)
            if value ~= nil then
                local dial = modifiers.VISION_DIALS[index]
                at[index] = OF.util.clamp(value, dial.from, dial.to)
            end
        elseif index == #modifiers.VISION_DIALS + 1 then
            if field == "1" then dither = true
            elseif field == "0" then dither = false end
        end
    end
    return at, dither
end

local function mine_packed()
    local parts = {}
    for index in ipairs(modifiers.VISION_DIALS) do
        local value = mineAt[index]
        parts[index] = value == nil and "" or string.format("%.2f", value)
    end
    parts[#modifiers.VISION_DIALS + 1] =
        (mineDither == true and "1") or (mineDither == false and "0") or ""
    return table.concat(parts, VISION_SEP)
end

local function mine_written()
    if mineDither ~= nil then return true end
    for index in ipairs(modifiers.VISION_DIALS) do
        if mineAt[index] ~= nil then return true end
    end
    return false
end

local function mine_load()
    if mineAt ~= nil then return end
    local packed = mod_storage_load(MINE_KEY, "") or ""
    local was = mod_storage_load(MINE_ON_KEY, "") or ""
    if was ~= "" then
        mineAt, mineDither = {}, nil
        if was == "true" then
            local dials, dither = modifiers.vision_parse(packed)
            for index in ipairs(modifiers.VISION_DIALS) do
                mineAt[index] = dials[index]
            end
            mineDither = dither
        end
        OF.util.store(MINE_KEY, mine_written() and mine_packed() or "")

        OF.util.store(MINE_ON_KEY, "")
        return
    end

    mineAt, mineDither = mine_unpack(packed)
end

local function mine_store()
    if not OF.util.store(MINE_KEY, mine_written() and mine_packed() or "") then
        return false, "That did not fit in the save file."
    end
    modifiers.mine_changed()
    return true
end

function modifiers.vision_mine_state(what)
    mine_load()
    if what == "dither" then
        if mineDither == nil then return nil end
        local _, room = modifiers.vision()
        if mineDither == room then return nil end
        return mineDither
    end
    local dial = modifiers.VISION_DIALS[what]
    if dial == nil then return nil end
    local value = mineAt[what]
    if value == nil then return nil end
    local room = modifiers.vision()[what]
    if same_dial(value, room) then return nil end
    if same_dial(value, dial.rest) then return false end
    return true
end

function modifiers.vision_mine_value(index)
    mine_load()
    if modifiers.vision_mine_state(index) == nil then return nil end
    return mineAt[index]
end

function modifiers.vision_mine_any()
    if modifiers.vision_mine_state("dither") ~= nil then return true end
    for index in ipairs(modifiers.VISION_DIALS) do
        if modifiers.vision_mine_state(index) ~= nil then return true end
    end
    return false
end

function modifiers.vision_in_force(ignoreRound)
    if not ignoreRound and (modifiers.round_holds() or modifiers.select_holds()) then
        return vision_defaults()
    end
    mine_load()
    local dials, dither = modifiers.vision()

    local place = modifiers.placeVision
    if place ~= nil and modifiers.look_from(dials, dither) == nil
        and modifiers.maps_bring_weather() then
        for index in ipairs(modifiers.VISION_DIALS) do dials[index] = place.dials[index] end
        dither = place.dither
    end
    for index in ipairs(modifiers.VISION_DIALS) do
        if mineAt[index] ~= nil then dials[index] = mineAt[index] end
    end
    if mineDither ~= nil then dither = mineDither end
    return dials, dither
end

local function keep_mine(dials, dither)
    mine_load()
    for index in ipairs(modifiers.VISION_DIALS) do
        mineAt[index] = dials[index]
        if modifiers.vision_mine_state(index) == nil then mineAt[index] = nil end
    end
    mineDither = dither and true or false
    if modifiers.vision_mine_state("dither") == nil then mineDither = nil end
    return mine_store()
end

function modifiers.look_from(dials, dither)
    local look = {}
    for index, dial in ipairs(modifiers.VISION_DIALS) do
        local value = dials[index]
        if value ~= nil and math.abs(value - dial.rest) > 0.001 then
            table.insert(look, { dial.flag, value })
        end
    end

    if dither then table.insert(look, { modifiers.VISION_DITHER, 1.0 }) end
    if #look == 0 then return nil end
    return look
end

function modifiers.vision_look()
    return modifiers.look_from(modifiers.vision())
end

function modifiers.look()
    return modifiers.look_from(modifiers.vision_in_force())
end

function modifiers.set_dial(index, value)
    local dial = modifiers.VISION_DIALS[index]
    if dial == nil then return false, "No such dial." end
    if not OF.perms.can("vision") then return false, "Your rank cannot do that." end

    local dials, dither = modifiers.vision()
    dials[index] = OF.util.clamp(tonumber(value) or dial.rest, dial.from, dial.to)
    return modifiers.publish_vision(dials, dither)
end

function modifiers.set_dial_mine(index, value)
    local dial = modifiers.VISION_DIALS[index]
    if dial == nil then return false, "No such dial." end
    mine_load()
    if value == nil then
        mineAt[index] = nil
    else
        mineAt[index] = OF.util.clamp(tonumber(value) or dial.rest,
            dial.from, dial.to)

        if modifiers.vision_mine_state(index) == nil then mineAt[index] = nil end
    end
    return mine_store()
end

function modifiers.set_dither(on)
    if not OF.perms.can("vision") then return false, "Your rank cannot do that." end
    local dials = modifiers.vision()
    return modifiers.publish_vision(dials, on and true or false)
end

function modifiers.set_dither_mine(state)
    mine_load()
    if state ~= true and state ~= false then state = nil end
    mineDither = state
    if modifiers.vision_mine_state("dither") == nil then mineDither = nil end
    return mine_store()
end

function modifiers.vision_snapshot()
    local packed = gGlobalSyncTable[modifiers.VISION_KEY]
    if type(packed) ~= "string" then return "" end
    return packed
end

function modifiers.borrow_vision(packed)
    if not OF.util.is_host() then return false end
    if type(packed) ~= "string" then packed = "" end

    local rest = modifiers.vision_pack(vision_defaults())
    if packed ~= "" then
        local dials, dither = modifiers.vision_parse(packed)
        packed = modifiers.vision_pack(dials, dither)
    else
        packed = rest
    end
    local now = modifiers.vision_snapshot()
    if now == packed then return false end

    if now == "" and packed == rest then return false end
    OF.util.publish(modifiers.VISION_KEY, packed)
    return true
end

function modifiers.vision_is_on()
    local rest = modifiers.vision_pack(vision_defaults())
    local now = modifiers.vision_snapshot()
    return now ~= "" and now ~= rest
end

function modifiers.clear_vision()
    if not OF.perms.can("vision") then return false, "Your rank cannot do that." end
    local dials, dither = vision_defaults()
    return modifiers.publish_vision(dials, dither)
end

function modifiers.clear_vision_mine()
    local dials, dither = vision_defaults()
    return keep_mine(dials, dither)
end

function modifiers.forget_vision_mine()
    mine_load()
    mineAt, mineDither = {}, nil
    return mine_store()
end

local function preset_dials(name)
    local look = modifiers.look_named(name)
    if look == nil then return nil end

    local dials, dither = vision_defaults()
    for _, pair in ipairs(look) do
        local flag, value = pair[1], pair[2]
        if flag == modifiers.VISION_DITHER then
            dither = true
        else
            for index, dial in ipairs(modifiers.VISION_DIALS) do
                if dial.flag == flag then
                    dials[index] = OF.util.clamp(value, dial.from, dial.to)
                end
            end
        end
    end
    return dials, dither
end

function modifiers.load_preset(name)
    if not OF.perms.can("vision") then return false, "Your rank cannot do that." end
    local dials, dither = preset_dials(name)
    if dials == nil then return false, "No such preset." end
    return modifiers.publish_vision(dials, dither)
end

function modifiers.load_preset_mine(name)
    local dials, dither = preset_dials(name)
    if dials == nil then return false, "No such preset." end
    return keep_mine(dials, dither)
end

function modifiers.set_vision_here(asker, packed)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("vision", asker) then
        return false, "Your rank cannot do that."
    end

    local dials, dither = modifiers.vision_parse(packed)
    OF.util.publish(modifiers.VISION_KEY, modifiers.vision_pack(dials, dither))
    return true
end

function modifiers.publish_vision(dials, dither)
    local packed = modifiers.vision_pack(dials, dither)
    if OF.util.is_host() then
        OF.util.publish(modifiers.VISION_KEY, packed)

        return true
    end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("vision", packed)
    end
    return false, "No host to ask yet - try again in a second."
end

hook_on_sync_table_change(gGlobalSyncTable, "ofVision", 0,
    function()
        if OF.util.asks(OF.guard, "repair")
            and OF.guard.repair(modifiers.VISION_KEY) then
            return
        end
        modifiers.wear_look(modifiers.look())
    end)

local lookOver = nil

function modifiers.look_over(look)
    lookOver = look
    return modifiers.wear_look(modifiers.look())
end

function modifiers.look_overridden()
    return lookOver ~= nil
end

function modifiers.look_named(name)
    for _, entry in ipairs(modifiers.LOOKS) do
        if entry.name == name then return entry.look end
    end
    return nil
end

function modifiers.wear_look(look)
    if set_shader_flag_enabled == nil or set_shader_flag_value == nil then
        return false
    end

    if lookOver ~= nil then look = lookOver end

    for flag in pairs(modifiers.shaderHeld) do
        set_shader_flag_value(flag, SHADER_DEFAULTS[flag] or 0.0)
        set_shader_flag_enabled(flag, false)
    end
    modifiers.shaderHeld = {}

    if look == nil then return true end
    for _, pair in ipairs(look) do
        local flag, value = pair[1], pair[2]
        if flag ~= nil then
            set_shader_flag_value(flag, value)
            set_shader_flag_enabled(flag, true)
            modifiers.shaderHeld[flag] = true
        end
    end
    return true
end

local MUSIC_PLAYER = SEQ_PLAYER_LEVEL

modifiers.musicHeld = modifiers.musicHeld or nil

local function fold_u16(value)
    return math.floor(value) & 0xFFFF
end

local function speed_fraction(m)
    local speed = math.abs(tonumber(m ~= nil and m.forwardVel or 0) or 0)
    if speed <= 0 then return 0 end
    if speed >= 48.0 then return 1 end
    return speed / 48.0
end
modifiers.speed_fraction = speed_fraction

function modifiers.hold_music(m)
    local held = modifiers.musicHeld
    if held == nil or MUSIC_PLAYER == nil then return false end

    local tempo = modifiers.setting("music", "tempo", nil)
    local trans = modifiers.setting("music", "trans", nil)

    local low = modifiers.setting("music", "low", nil)
    local high = modifiers.setting("music", "high", nil)
    if low ~= nil and high ~= nil then
        tempo = low + (high - low) * speed_fraction(m)
    end

    if tempo ~= nil then
        local now = OF.util.optional("sequence_player_get_tempo", nil, MUSIC_PLAYER)
        if type(now) ~= "number" then return false end

        if held.wroteTempo == nil or now ~= held.wroteTempo then held.tempo = now end
        held.wroteTempo = math.floor(held.tempo * tempo / 100)

        if held.wroteTempo < 1 then held.wroteTempo = 1 end
        OF.util.optional("sequence_player_set_tempo", nil, MUSIC_PLAYER,
            held.wroteTempo)
    end

    if trans ~= nil then
        local now = OF.util.optional("sequence_player_get_transposition", nil,
            MUSIC_PLAYER)
        if type(now) ~= "number" then return false end
        if held.wroteTrans == nil or now ~= held.wroteTrans then
            held.trans = now
        end
        held.wroteTrans = fold_u16(held.trans + trans)
        OF.util.optional("sequence_player_set_transposition", nil, MUSIC_PLAYER,
            held.wroteTrans)
    end

    return true
end

function modifiers.wear_music(on)
    if MUSIC_PLAYER == nil then return false end
    if OF.util.binding("sequence_player_set_tempo") == nil then return false end

    if not on then
        local held = modifiers.musicHeld
        if held == nil then return true end

        if held.wroteTempo ~= nil then
            OF.util.optional("sequence_player_set_tempo", nil, MUSIC_PLAYER,
                held.tempo)
        end
        if held.wroteTrans ~= nil then
            OF.util.optional("sequence_player_set_transposition", nil,
                MUSIC_PLAYER, held.trans)
        end
        modifiers.musicHeld = nil
        return true
    end

    if modifiers.musicHeld == nil then modifiers.musicHeld = {} end
    return modifiers.hold_music()
end

modifiers.hudHeld = modifiers.hudHeld or nil

local function hud_wanted_gone()
    if modifiers.hudHeld then return true end

    if modifiers.studio_holds("hud") then return true end
    if OF.util.asks(OF.camera, "holds_hud") and OF.camera.holds_hud() then
        return true
    end

    if OF.util.asks(OF.pause, "holds_hud") and OF.pause.holds_hud() then
        return true
    end
    return false
end

function modifiers.settle_hud()
    if OF.util.binding("hud_hide") == nil then return false end
    if hud_wanted_gone() then
        OF.util.optional("hud_hide", nil)
    else
        OF.util.optional("hud_show", nil)
    end
    return true
end

function modifiers.wear_hud(on)
    if OF.util.binding("hud_hide") == nil then return false end

    modifiers.hudHeld = on and true or nil
    return modifiers.settle_hud()
end

hook_event(HOOK_ON_LEVEL_INIT, function() modifiers.settle_hud() end)

modifiers.flatHeld = modifiers.flatHeld or nil

do
    local DL_NODES = {
        [0x015] = true, [0x016] = true, [0x017] = true, [0x019] = true,
        [0x01A] = true, [0x01B] = true, [0x01C] = true, [0x01D] = true,
        [0x030] = true,
    }
    local OP_GEOMETRY, OP_VTX, OP_VTX_EXT = 0xD9, 0x01, 0x11
    local LIGHTING = 0x00020000
    local BUDGET = 4096
    local undo = {}
    local areasDone = {}

    local modelsDone = {}

    local function flatten_buffer(cmd)
        if gfx_get_vertex_buffer == nil or gfx_get_vertex_count == nil then return 0 end
        local first = gfx_get_vertex_buffer(cmd)
        local count = tonumber(gfx_get_vertex_count(cmd)) or 0
        if first == nil or count <= 0 then return 0 end
        local verts, v = {}, first
        for i = 1, count do
            if v == nil then break end
            verts[#verts + 1] = v
            if i < count then
                v = vtx_get_next_vertex ~= nil and vtx_get_next_vertex(v) or nil
            end
        end
        local best, bestSum = nil, -1
        for _, one in ipairs(verts) do
            local sum = (one.r or 0) + (one.g or 0) + (one.b or 0)
            if sum > bestSum then best, bestSum = one, sum end
        end
        if best == nil then return 0 end
        local r, g, b = best.r, best.g, best.b
        local wrote = 0
        for _, one in ipairs(verts) do
            if one.r ~= r or one.g ~= g or one.b ~= b then
                undo[#undo + 1] = { one, one.r, one.g, one.b }
                one.r, one.g, one.b = r, g, b
                wrote = wrote + 1
            end
        end
        return wrote
    end

    local function flatten_list(gfx)
        if gfx == nil or gfx_parse == nil then return 0 end
        local lit, wrote = true, 0
        gfx_parse(gfx, function(cmd, op)
            if op == OP_GEOMETRY then
                local keep = (cmd.w0 or 0) & 0xFFFFFF
                lit = (lit and (keep & LIGHTING) ~= 0) or ((cmd.w1 or 0) & LIGHTING) ~= 0
            elseif (op == OP_VTX or op == OP_VTX_EXT) and not lit then
                wrote = wrote + flatten_buffer(cmd)
            end
        end)
        return wrote
    end

    local function walk(first, budget, wrote)
        if first == nil or budget <= 0 then return budget, wrote end
        local node = first
        repeat
            budget = budget - 1
            if budget <= 0 then return 0, wrote end
            local kind = node.type
            if kind ~= nil and DL_NODES[kind] and cast_graph_node ~= nil then
                local shaped = cast_graph_node(node)
                if shaped ~= nil then wrote = wrote + flatten_list(shaped.displayList) end
            end
            budget, wrote = walk(node.children, budget, wrote)
            node = node.next
        until node == nil or node == first or budget <= 0
        return budget, wrote
    end

    function modifiers.flatten_map(on)
        if not on then
            local put = 0
            for index = #undo, 1, -1 do
                local one = undo[index]
                pcall(function() one[1].r, one[1].g, one[1].b = one[2], one[3], one[4] end)
                put = put + 1
            end
            undo, areasDone, modelsDone = {}, {}, {}
            return put
        end
        local me = gMarioStates ~= nil and gMarioStates[0] or nil
        local area = me ~= nil and me.area or nil
        local root = area ~= nil and area.root or nil
        local top = root ~= nil and root.node or nil

        if top == nil then return 0 end
        local wrote = 0
        if not areasDone[top] then
            areasDone[top] = true
            local _
            _, wrote = walk(top.children, BUDGET, 0)
            wrote = wrote + modifiers.flatten_pieces()
        end
        return wrote
    end

    function modifiers.flatten_pieces()
        if obj_get_first == nil or obj_get_next == nil or OBJ_LIST_SURFACE == nil then
            return 0
        end
        local wrote, seen = 0, 0
        local o = obj_get_first(OBJ_LIST_SURFACE)
        while o ~= nil and seen < BUDGET do
            seen = seen + 1
            local gfx = o.header ~= nil and o.header.gfx or nil
            local root = gfx ~= nil and gfx.sharedChild or nil
            if root ~= nil and not modelsDone[root] then
                modelsDone[root] = true
                local _, more = walk(root, BUDGET, 0)
                wrote = wrote + more
            end
            o = obj_get_next(o)
        end
        return wrote
    end

    function modifiers.flat_map_held()
        return #undo
    end

    local PIECES_EVERY = 30
    local frames = 0
    hook_event(HOOK_UPDATE, function()
        if modifiers.flatHeld == nil then return end
        modifiers.flatten_map(true)
        frames = frames + 1
        if frames >= PIECES_EVERY then
            frames = 0
            modifiers.flatten_pieces()
        end
    end)
    hook_event(HOOK_ON_EXIT, function() modifiers.flatten_map(false) end)

    hook_event(HOOK_ON_LEVEL_INIT, function() areasDone = {} end)
end

function modifiers.wear_flat(on)
    if OF.util.binding("set_shading_fullbright_enabled") == nil then return false end

    if not on then
        modifiers.flatten_map(false)
        if modifiers.flatHeld == nil then return true end
        OF.util.optional("set_shading_fullbright_enabled", nil, modifiers.flatHeld)
        modifiers.flatHeld = nil
        return true
    end
    modifiers.flatten_map(true)

    if modifiers.flatHeld == nil then
        modifiers.flatHeld =
            OF.util.optional("get_shading_fullbright_enabled", false) == true
    end
    OF.util.optional("set_shading_fullbright_enabled", nil, true)
    return true
end

modifiers.studioWants = modifiers.studioWants or nil

modifiers.placeSky = modifiers.placeSky or nil

function modifiers.wear_place_sky(background)
    if type(background) ~= "number" then background = nil end
    local was = modifiers.placeSky
    modifiers.placeSky = background
    if modifiers.level("night") > 0 then return false end
    if background == was then return false end
    set_override_skybox(background or NO_SKYBOX)
    return true
end

modifiers.placeLight = modifiers.placeLight or nil

local function place_dark_stop(n)
    local entry = modifiers.BY_KEY ~= nil and modifiers.BY_KEY["dark"] or nil
    if entry == nil or type(n) ~= "number" then return nil end
    local stop = entry.levels[math.floor(n)]
    if stop == nil or (stop.grey == nil and stop.light == nil) then return nil end
    return stop
end

local function wear_place_dark(stop)
    if stop.light ~= nil then
        return modifiers.set_lighting(stop.light[1], stop.light[2], stop.light[3])
    end
    return modifiers.set_dark(stop.grey)
end

function modifiers.wear_place_light(light)
    if type(light) ~= "table" then light = nil end
    local was = modifiers.placeLight
    modifiers.placeLight = light
    if modifiers.level("sun") <= 0 then
        local dir = light ~= nil and light.dir or nil
        if type(dir) ~= "table" then dir = nil end
        modifiers.wear_sun(dir)
    end
    if modifiers.level("dark") <= 0 then
        local stop = light ~= nil and place_dark_stop(light.dark) or nil
        if stop ~= nil then
            wear_place_dark(stop)
        elseif was ~= nil and place_dark_stop(was.dark) ~= nil then
            modifiers.clear_dark()
        end
    end
    return true
end

modifiers.PLACE_SUN_REACH = 2.0
modifiers.PLACE_SUN_BASE = { 0, 110 / 127, 63 / 127 }
modifiers.placeSunHeld = false

function modifiers.place_sun_dir()
    local light = modifiers.placeLight
    if light == nil or type(light.sun) ~= "table" or type(light.dir) == "table" then return nil end
    if modifiers.level("sun") > 0 or modifiers.select_holds() then return nil end
    local eye = gLakituState
    local from = eye ~= nil and (eye.curPos or eye.pos) or nil
    local at = eye ~= nil and (eye.curFocus or eye.focus) or nil
    if from == nil or at == nil then return nil end
    local fx, fy, fz = at.x - from.x, at.y - from.y, at.z - from.z
    local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
    if fl < 1 then return nil end
    fx, fy, fz = fx / fl, fy / fl, fz / fl

    local rx, rz = -fz, fx
    local rl = math.sqrt(rx * rx + rz * rz)
    if rl < 0.001 then return nil end
    rx, rz = rx / rl, rz / rl
    local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy
    local s = light.sun
    local sl = math.sqrt(s[1] * s[1] + s[2] * s[2] + s[3] * s[3])
    if sl == 0 then return nil end
    local sx, sy, sz = s[1] / sl, s[2] / sl, s[3] / sl
    local k, base = modifiers.PLACE_SUN_REACH, modifiers.PLACE_SUN_BASE
    return { k * (sx * rx + sz * rz) - base[1],
             k * (sx * ux + sy * uy + sz * uz) - base[2],
             k * -(sx * fx + sy * fy + sz * fz) - base[3] }
end

function modifiers.aim_place_sun()
    local dir = modifiers.place_sun_dir()
    if dir ~= nil then
        modifiers.placeSunHeld = true
        return modifiers.wear_sun(dir)
    end
    if not modifiers.placeSunHeld then return false end
    modifiers.placeSunHeld = false

    if modifiers.level("sun") > 0 then return false end
    local light = modifiers.placeLight
    return modifiers.wear_sun(light ~= nil and type(light.dir) == "table" and light.dir or nil)
end

hook_event(HOOK_UPDATE, function() modifiers.aim_place_sun() end)

function modifiers.rewear_place_light(field)
    local light = modifiers.placeLight
    if light == nil then return false end
    if field == "sun" and type(light.dir) == "table" then
        return modifiers.wear_sun(light.dir)
    end
    if field == "dark" then
        local stop = place_dark_stop(light.dark)
        if stop ~= nil then return wear_place_dark(stop) end
    end
    return false
end

modifiers.placeVisuals = modifiers.placeVisuals or nil

function modifiers.wear_place_visuals(list)
    if type(list) ~= "table" then list = nil end
    local wants = nil
    for _, pair in ipairs(list or {}) do
        local key, name = pair[1], pair[2]
        local entry = type(key) == "string" and modifiers.BY_KEY ~= nil
            and modifiers.BY_KEY[key] or nil
        local index = nil
        for i, stop in ipairs(entry ~= nil and entry.levels or {}) do
            if index == nil and stop.name == name then index = i end
        end
        if index ~= nil then
            wants = wants or {}
            wants[key] = index
        end
    end
    local moved = not modifiers.same_place(modifiers.placeVisuals, wants)
    modifiers.placeVisuals = wants

    if moved then modifiers.mine_changed() end
    return wants ~= nil
end

function modifiers.same_place(one, two)
    if one == nil or two == nil then return one == two end
    for key, value in pairs(one) do
        if two[key] ~= value then return false end
    end
    for key, value in pairs(two) do
        if one[key] ~= value then return false end
    end
    return true
end

function modifiers.maps_bring_weather()
    if not OF.util.asks(OF.rules, "step") then return true end
    return OF.rules.step("mapweather") == 0
end

modifiers.placeVision = modifiers.placeVision or nil

function modifiers.wear_place_vision(want)
    local dials, dither, any = nil, nil, false
    if type(want) == "table" then
        if type(want.look) == "string" then
            dials, dither = preset_dials(want.look)
            any = dials ~= nil
        end
        if dials == nil then dials, dither = vision_defaults() end
        for name, value in pairs(type(want.dials) == "table" and want.dials or {}) do
            for index, dial in ipairs(modifiers.VISION_DIALS) do
                if type(name) == "string" and string.lower(name) == string.lower(dial.name)
                    and type(value) == "number" then
                    dials[index] = OF.util.clamp(value, dial.from, dial.to)
                    any = true
                end
            end
        end
    end
    local was = modifiers.placeVision
    modifiers.placeVision = any and { dials = dials, dither = dither == true } or nil
    local now = modifiers.placeVision
    if was ~= nil or now ~= nil then modifiers.mine_changed() end
    return now ~= nil
end

function modifiers.studio_holds(field)
    local wants = modifiers.studioWants
    if wants == nil then return false end
    if field == "tint" then return wants.tint ~= nil end
    return wants[field] == true
end

function modifiers.studio_channel(index)
    local wants = modifiers.studioWants
    if wants == nil or wants.tint == nil then return 255 end
    local value = tonumber(wants.tint[index + 1]) or 255
    return math.floor(OF.util.clamp(value, 0, 255))
end

function modifiers.wear_studio(wants)
    if wants ~= nil and type(wants) ~= "table" then wants = nil end
    modifiers.studioWants = wants

    modifiers.settle_hud()

    local rowGone = modifiers.level("shadow") > 0
        and modifiers.setting("shadow", "gone", false) == true
    modifiers.wear_shadows(not (rowGone or modifiers.studio_holds("shadows")))

    if modifiers.studio_holds("flat") or modifiers.level("flat") > 0 then
        modifiers.wear_flat(true)
    else
        modifiers.wear_flat(false)
    end

    if modifiers.level("tint") > 0 then
        modifiers.fade_forget("tint")
    else
        modifiers.wear_tint(false)
    end
    return true
end

local SHAKE_DECAY = 0x3
local SHAKE_SPEED = 0x8000

function modifiers.hold_quake()
    local mag = modifiers.setting("quake", "mag", nil)
    local hand = modifiers.setting("quake", "hand", nil)
    local sea = modifiers.setting("quake", "sea", nil)
    if sea ~= nil then return modifiers.roll_the_sea(sea) end
    if mag == nil and hand == nil then return false end

    if hand ~= nil then
        OF.util.optional("set_handheld_shake", nil, hand)
    end

    if mag == nil then return true end
    if OF.util.binding("set_camera_pitch_shake") == nil then return false end

    local half = math.floor(mag / 2)
    OF.util.optional("set_camera_pitch_shake", nil, mag, SHAKE_DECAY, SHAKE_SPEED)
    OF.util.optional("set_camera_yaw_shake", nil, half, SHAKE_DECAY, SHAKE_SPEED)
    OF.util.optional("set_camera_roll_shake", nil, half, SHAKE_DECAY, SHAKE_SPEED)
    return true
end

do

modifiers.jellyHeld = nil

local JELLY_FIELDS = { "passiveRippleMag", "passiveRippleDecay", "passiveRippleRate",
    "passiveDispersionFactor", "rippleDecay" }

function modifiers.wobble_paintings(level)
    local paintings = gPaintingValues
    if paintings == nil then return false end
    if level == nil then
        if modifiers.jellyHeld == nil then return true end
        for name, was in pairs(modifiers.jellyHeld) do
            local painting = paintings[name]
            if painting ~= nil then
                for _, field in ipairs(JELLY_FIELDS) do
                    if was[field] ~= nil then painting[field] = was[field] end
                end
            end
        end
        modifiers.jellyHeld = nil
        return true
    end
    local mag = modifiers.setting("jelly", "mag", nil)
    local rate = modifiers.setting("jelly", "rate", nil)
    if mag == nil or rate == nil then return false end
    if modifiers.jellyHeld == nil then
        modifiers.jellyHeld = {}
        for name, painting in pairs(paintings) do
            if type(painting) == "table" or type(painting) == "userdata" then
                local was = {}
                for _, field in ipairs(JELLY_FIELDS) do was[field] = painting[field] end
                modifiers.jellyHeld[name] = was
            end
        end
    end
    for name, was in pairs(modifiers.jellyHeld) do
        local painting = paintings[name]
        if painting ~= nil then
            local base = was.passiveRippleMag or 10
            if base < 10 then base = 10 end
            painting.passiveRippleMag = base * mag
            painting.passiveRippleDecay = 1.0
            painting.rippleDecay = 1.0
            painting.passiveRippleRate = (was.passiveRippleRate or 0.24) * rate
            painting.passiveDispersionFactor = was.passiveDispersionFactor or 40
        end
    end
    return true
end
end

modifiers.seaHeld = false

function modifiers.roll_the_sea(mag)
    if OF.util.binding("set_camera_pitch_shake") == nil then return false end
    modifiers.seaHeld = true
    OF.util.optional("set_camera_pitch_shake", nil, mag, 0, 0x180)
    OF.util.optional("set_camera_roll_shake", nil, math.floor(mag * 1.5), 0, 0x100)
    return true
end

function modifiers.calm_the_sea()
    if not modifiers.seaHeld then return false end
    modifiers.seaHeld = false
    local shake = gLakituState ~= nil and gLakituState.shakeMagnitude or nil
    if shake == nil then return false end
    shake.x, shake.y, shake.z = 0, 0, 0
    return true
end

local ANIM_NORMAL = 0x10000

function modifiers.wear_animation(m)
    local rate = modifiers.setting("anim", "rate", nil)
    if rate == nil or m == nil then return false end

    local obj = m.marioObj
    if obj == nil or obj.header == nil then return false end
    local gfx = obj.header.gfx
    if gfx == nil or gfx.animInfo == nil then return false end

    gfx.animInfo.animAccel = math.max(1, math.floor(ANIM_NORMAL * rate / 100))
    return true
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    modifiers.wear_animation(m)
end)

function modifiers.face_note()
    if modifiers.setting("face", "hands", nil) ~= MARIO_HAND_FISTS then
        return nil
    end
    return OF.lang.t("The hands open in water and under a wing cap.")
end

do

    local MOOD_FRAMES = 90

    local ASLEEP_AFTER = 30

    local STILL_SLACK = 2

    local moodUntil = {}
    local moodEyes = {}
    local moodHands = {}
    local moodHurt = {}
    local moodStood = {}

    function modifiers.forget_faces()
        moodUntil = {}
        moodEyes = {}
        moodHands = {}
        moodHurt = {}
        moodStood = {}
    end

    local function asleep(index, m, now)
        local was = moodStood[index]
        if was == nil
            or math.abs(m.pos.x - was.x) > STILL_SLACK
            or math.abs(m.pos.y - was.y) > STILL_SLACK
            or math.abs(m.pos.z - was.z) > STILL_SLACK
            or now < was.at then
            moodStood[index] = { x = m.pos.x, y = m.pos.y, z = m.pos.z, at = now }
            return false
        end
        return (now - was.at) / 30 >= ASLEEP_AFTER
    end

    local function star_dancing(action)
        if action == nil then return false end
        return action == ACT_STAR_DANCE_EXIT
            or action == ACT_STAR_DANCE_NO_EXIT
            or action == ACT_STAR_DANCE_WATER
    end

    local function mood_of(m)
        local index = m.playerIndex
        local now = OF.util.optional("get_global_timer", 0) or 0

        local hurt = tonumber(m.hurtCounter) or 0
        local before = moodHurt[index]
        moodHurt[index] = hurt
        if before ~= nil and hurt > before then
            moodUntil[index] = now + MOOD_FRAMES
            moodEyes[index] = MARIO_EYES_DEAD
            moodHands[index] = MARIO_HAND_OPEN
        elseif star_dancing(m.action) then
            moodUntil[index] = now + MOOD_FRAMES
            moodEyes[index] = MARIO_EYES_OPEN
            moodHands[index] = MARIO_HAND_PEACE_SIGN
        end

        local until_ = moodUntil[index]
        if until_ ~= nil and now < until_ and now >= until_ - MOOD_FRAMES then
            return moodEyes[index], moodHands[index]
        end

        if m.pos ~= nil and asleep(index, m, now) then
            return MARIO_EYES_CLOSED, MARIO_HAND_OPEN
        end

        return MARIO_EYES_OPEN, MARIO_HAND_OPEN
    end

    local function fixed_faces()
        local out = {}
        local entry = modifiers.BY_KEY["face"]
        for _, step in ipairs(entry ~= nil and entry.levels or {}) do
            if step.eyes ~= nil then out[#out + 1] = step end
        end
        return out
    end

    modifiers.fixed_faces = fixed_faces

    local function dealt_face(index)
        local faces = fixed_faces()
        if #faces == 0 then return nil end
        local np = gNetworkPlayers ~= nil and gNetworkPlayers[index] or nil
        local seat = np ~= nil and np.globalIndex or index
        local level = np ~= nil and np.currLevelNum or 0
        if type(seat) ~= "number" then seat = index end
        if type(level) ~= "number" then level = 0 end
        local step = faces[1 + (seat * 7 + level * 13) % #faces]
        return step.eyes, step.hands
    end

    modifiers.dealt_face = dealt_face

    function modifiers.face_for(m)
        if m == nil then return nil end
        if modifiers.level("face") <= 0 then return nil end

        local eyes = modifiers.setting("face", "eyes", nil)
        if eyes ~= nil then
            return eyes, modifiers.setting("face", "hands", nil)
        end

        if modifiers.setting("face", "mood", false) == true then
            return mood_of(m)
        end
        if modifiers.setting("face", "dealt", false) == true then
            return dealt_face(m.playerIndex)
        end
        return nil
    end
end

do

    local boardStamp = nil
    local boardLeader = nil
    local boardChaser = nil

    local function board_answers()
        local stamp = OF.util.optional("get_global_timer", nil)
        if stamp ~= nil and stamp == boardStamp then return end
        boardStamp = stamp
        boardLeader, boardChaser = nil, nil
        if not OF.util.asks(OF.gamemodes, "podium") then return end
        local ok, board = pcall(OF.gamemodes.podium)
        if not ok or type(board) ~= "table" or board[1] == nil then return end
        boardLeader = board[1].localIndex
        for place, entry in ipairs(board) do
            if entry.localIndex == 0 then
                local behind = board[place + 1]
                if behind ~= nil then boardChaser = behind.localIndex end
                break
            end
        end
    end

    function modifiers.forget_trail_board()
        boardStamp = nil
        boardLeader, boardChaser = nil, nil
    end

    local LEAD_TRAIL = PARTICLE_SPARKLES
    local CHASE_TRAIL = PARTICLE_FIRE

    local TEAM_TRAIL = { red = PARTICLE_FIRE, blue = PARTICLE_BUBBLE }

    function modifiers.trail_bits(m)
        if m == nil then return nil end
        if modifiers.level("trail") <= 0 then return nil end

        local particle = modifiers.setting("trail", "particle", nil)
        if particle ~= nil then return particle end

        local index = m.playerIndex

        if modifiers.setting("trail", "lead", false) == true then
            board_answers()
            if boardLeader ~= nil and index == boardLeader then
                return LEAD_TRAIL
            end
            return nil
        end

        if modifiers.setting("trail", "chase", false) == true then
            board_answers()
            if boardChaser ~= nil and index == boardChaser then
                return CHASE_TRAIL
            end
            return nil
        end

        if modifiers.setting("trail", "team", false) == true then
            if not OF.util.asks(OF.teams, "of") then return nil end
            return TEAM_TRAIL[OF.teams.of(index)]
        end

        return nil
    end
end

do

    local COIN_TRAIL_EVERY = 12

    local COIN_TRAIL_LIVE = 24

    local COIN_TRAIL_LIFT = 60

    local COIN_TRAIL_MOVING = 8

    local coinTrail = {}
    local coinTrailWait = 0

    function modifiers.coin_trail_count()
        return OF.util.coin_live(coinTrail)
    end

    function modifiers.clear_coin_trail()
        OF.util.coin_sweep(coinTrail)
        OF.util.coin_live(coinTrail)
        coinTrailWait = 0
        return true
    end

    function modifiers.coin_trail_update()
        if modifiers.setting("trail", "coins", false) ~= true then
            if #coinTrail > 0 then modifiers.clear_coin_trail() end
            return false
        end

        if coinTrailWait > 0 then
            coinTrailWait = coinTrailWait - 1
            return false
        end

        local m = gMarioStates ~= nil and gMarioStates[0] or nil
        if m == nil or m.pos == nil or m.marioObj == nil then return false end
        if math.abs(m.forwardVel or 0) < COIN_TRAIL_MOVING then return false end
        if OF.util.coin_live(coinTrail) >= COIN_TRAIL_LIVE then return false end

        coinTrailWait = COIN_TRAIL_EVERY

        return OF.util.coin_put(coinTrail, m.pos.x, m.pos.y + COIN_TRAIL_LIFT,
            m.pos.z, OF.util.COIN_KINDS[1])
    end

    hook_event(HOOK_UPDATE, modifiers.coin_trail_update)
end

local function set_joint(angle, three)
    if angle == nil then return end
    angle.x = three ~= nil and (three[1] or 0) or 0
    angle.y = three ~= nil and (three[2] or 0) or 0
    angle.z = three ~= nil and (three[3] or 0) or 0
end

function modifiers.wear_body(m)
    if m == nil then return false end
    local did = false

    local body = m.marioBodyState

    local eyes, hands = modifiers.face_for(m)
    if eyes ~= nil and body ~= nil then
        body.eyeState = eyes
        if hands ~= nil then body.handState = hands end
        did = true
    end

    local yielding = m.playerIndex == 0 and OF.util.limping == true

    local postureOn = modifiers.BY_KEY.posture == nil
        or modifiers.level("posture") > 0
    local torso, head = nil, nil
    if postureOn then
        torso = modifiers.setting("posture", "torso", nil)
        head = modifiers.setting("posture", "head", nil)
    end
    if (torso ~= nil or head ~= nil) and body ~= nil and not yielding then
        body.allowPartRotation = true
        set_joint(body.torsoAngle, torso)
        set_joint(body.headAngle, head)
        did = true
    end

    local frame = nil
    if postureOn then frame = modifiers.setting("posture", "frame", nil) end
    if frame ~= nil then
        OF.util.optional("set_anim_to_frame", nil, m, frame)
        did = true
    end

    local particle = modifiers.trail_bits(m)
    if particle ~= nil and m.particleFlags ~= nil then
        m.particleFlags = m.particleFlags | particle
        did = true
    end

    local light = modifiers.light_for(m)
    if light ~= nil and body ~= nil then
        body.lightR, body.lightG, body.lightB = light[1], light[2], light[3]
        body.shadeR, body.shadeG, body.shadeB = light[4], light[5], light[6]
        did = true
    end

    return did
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    modifiers.wear_body(m)
end)

function modifiers.clear_posture()
    for index = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[index]
        local body = m ~= nil and m.marioBodyState or nil

        if index == 0 and OF.util.limping == true then body = nil end
        if body ~= nil then
            body.allowPartRotation = false
            set_joint(body.torsoAngle, nil)
            set_joint(body.headAngle, nil)
        end
    end
    return true
end

do

    local NEUTRAL_SHADE = 127
    local NEUTRAL_LIGHT = 255

    local SEAT_LIGHTS = {
        { 255, 225, 115,   19,  58, 212 },
        { 120, 200, 255,   90,  45,  20 },
        { 255, 150, 150,   40,  70,  90 },
        { 150, 255, 170,   80,  40,  90 },
        { 230, 160, 255,   60,  90,  35 },
        { 255, 200,  90,   30,  60, 120 },
        { 140, 240, 240,   90,  50,  30 },
        { 255, 130, 200,   35,  95,  55 },
        { 200, 255, 120,   55,  35, 110 },
        { 120, 160, 255,  110,  80,  25 },
        { 255, 180, 130,   25,  70, 110 },
        { 170, 255, 235,   85,  40,  60 },
        { 235, 235, 160,   45,  45, 100 },
        { 255, 110, 110,   30,  90, 100 },
        { 130, 255, 200,   95,  50,  45 },
        { 190, 190, 255,   70,  70,  30 },
    }

    local SIDE_LIGHTS = {
        red  = { 255, 150, 110,   40,  55, 110 },
        blue = { 130, 185, 255,  105,  70,  35 },
    }

    local MINE_WARM   = { 255, 220, 140,   70,  55,  95 }
    local MINE_OTHERS = { 140, 170, 210,   55,  60,  80 }

    function modifiers.light_for(m)
        if m == nil then return nil end

        local lobby = modifiers.setting("lobbylight", "light", nil)
        if lobby ~= nil then
            local shade = modifiers.setting("lobbylight", "shade", nil)
            if shade == nil then return nil end
            return { lobby[1], lobby[2], lobby[3], shade[1], shade[2], shade[3] }
        end

        if modifiers.level("ownlight") <= 0 then return nil end
        local index = m.playerIndex or 0

        if modifiers.setting("ownlight", "seats", false) == true then

            return SEAT_LIGHTS[(index % #SEAT_LIGHTS) + 1]
        end

        if modifiers.setting("ownlight", "team", false) == true then
            if not OF.util.asks(OF.teams, "of") then return nil end

            return SIDE_LIGHTS[OF.teams.of(index)]
        end

        if modifiers.setting("ownlight", "mine", false) == true then

            if index == 0 then return MINE_WARM end
            return MINE_OTHERS
        end

        return nil
    end

    function modifiers.clear_body_light()
        for index = 0, MAX_PLAYERS - 1 do
            local m = gMarioStates[index]
            local body = m ~= nil and m.marioBodyState or nil
            if body ~= nil then
                body.shadeR, body.shadeG, body.shadeB =
                    NEUTRAL_SHADE, NEUTRAL_SHADE, NEUTRAL_SHADE
                body.lightR, body.lightG, body.lightB =
                    NEUTRAL_LIGHT, NEUTRAL_LIGHT, NEUTRAL_LIGHT
            end
        end
        return true
    end

    function modifiers.neutral_body_light()
        return NEUTRAL_LIGHT, NEUTRAL_SHADE
    end
end

local NO_TINT = 255

function modifiers.wear_tint(on, paint)
    if OF.util.binding("set_vertex_color") == nil then return false end

    local tint = nil
    if on then tint = paint or modifiers.setting("tint", "tint", nil) end

    for index = 0, 2 do
        local value = NO_TINT
        if tint ~= nil and tint[index + 1] ~= nil then
            value = math.floor(OF.util.clamp(tint[index + 1], 0, 255))
        end

        value = math.floor(value * modifiers.studio_channel(index) / 255)
        OF.util.optional("set_vertex_color", nil, index, value)
    end
    return true
end

do

    local DRAINED = 130

    local DRAIN_OVER = 300

    local ALARM_FAR = 1500
    local ALARM_CLOSE = 300
    local ALARM_RED = { 255, 95, 85 }

    function modifiers.nearest_other()
        local np = gNetworkPlayers[0]
        local me = gMarioStates[0]
        if np == nil or me == nil or me.pos == nil then return nil end
        local best, who = nil, nil
        for index = 1, MAX_PLAYERS - 1 do
            local other = gNetworkPlayers[index]
            local body = gMarioStates[index]
            if other ~= nil and body ~= nil and body.pos ~= nil
                and other.connected
                and other.currLevelNum == np.currLevelNum
                and other.currAreaIndex == np.currAreaIndex then
                local dx = body.pos.x - me.pos.x
                local dy = body.pos.y - me.pos.y
                local dz = body.pos.z - me.pos.z
                local away = math.sqrt(dx * dx + dy * dy + dz * dz)
                if best == nil or away < best then best, who = away, index end
            end
        end
        return best, who
    end

    local function through_the_round()
        if not OF.util.asks(OF.gamemodes, "state")
            or OF.gamemodes.state() == OF.gamemodes.OFF then
            return 0
        end
        local left = OF.util.asks(OF.gamemodes, "time_left")
            and OF.gamemodes.time_left() or nil
        local limit = gGlobalSyncTable.ofGmLimit or 0
        if left ~= nil and limit > 0 then
            return OF.util.clamp(1 - left / limit, 0, 1)
        end
        local elapsed = OF.util.asks(OF.gamemodes, "elapsed")
            and OF.gamemodes.elapsed() or 0
        return OF.util.clamp(elapsed / DRAIN_OVER, 0, 1)
    end

    modifiers.through_the_round = through_the_round

    local SKY_TINT = {
        [0] = { 200, 225, 255 },
        [1] = { 255, 175, 120 },
        [2] = { 150, 210, 215 },
        [3] = { 195, 205, 225 },
        [4] = { 205, 225, 255 },
        [5] = { 255, 225, 170 },
        [6] = { 150, 165, 150 },

        [7] = { 180, 230, 175 },
        [8] = { 235, 240, 255 },
        [9] = { 185, 160, 225 },
    }

    function modifiers.tint_of_the_sky()
        if OF.util.binding("get_skybox") == nil then
            return { NO_TINT, NO_TINT, NO_TINT, 0 }
        end
        local sky = OF.util.optional("get_skybox", nil)
        local paint = type(sky) == "number" and SKY_TINT[sky] or nil

        if paint == nil then return { NO_TINT, NO_TINT, NO_TINT, 0 } end
        return { paint[1], paint[2], paint[3], 0 }
    end

    function modifiers.tint_wanted()
        if modifiers.level("tint") <= 0 then return nil end

        local paint = modifiers.setting("tint", "tint", nil)
        if paint ~= nil then return { paint[1], paint[2], paint[3], 0 } end

        if modifiers.setting("tint", "team", false) == true then

            local r, g, b = NO_TINT, NO_TINT, NO_TINT
            if OF.util.asks(OF.teams, "color_of") then
                r, g, b = OF.teams.color_of(0)
            end
            return { r, g, b, 0 }
        end

        if modifiers.setting("tint", "drains", false) == true then
            local through = through_the_round()
            local value = NO_TINT - (NO_TINT - DRAINED) * through
            return { value, value, value, 0 }
        end

        if modifiers.setting("tint", "fromSky", false) == true then
            return modifiers.tint_of_the_sky()
        end

        if modifiers.setting("tint", "alarm", false) == true then
            local away = modifiers.nearest_other()
            if away == nil then return { NO_TINT, NO_TINT, NO_TINT, 0 } end
            local close = OF.util.clamp(
                (ALARM_FAR - away) / (ALARM_FAR - ALARM_CLOSE), 0, 1)
            return {
                NO_TINT - (NO_TINT - ALARM_RED[1]) * close,
                NO_TINT - (NO_TINT - ALARM_RED[2]) * close,
                NO_TINT - (NO_TINT - ALARM_RED[3]) * close,
                0,
            }
        end

        return { NO_TINT, NO_TINT, NO_TINT, 0 }
    end
end

do

    local SKY_DIR = {
        [0] = { 0.7, 0.6, 0.2 },

        [1] = { 0, -0.8, 0.25 },
        [2] = { 0.1, 1.0, 0 },
        [3] = { -0.3, 0.9, 0.2 },
        [4] = { 0.8, 0.25, -0.4 },
        [5] = { 0, 1.0, 0 },
        [6] = { -0.2, 0.2, -1.0 },
        [7] = { 0.2, 0.35, 0.9 },
        [8] = { -0.8, 0.55, 0 },
        [9] = { -0.9, 0.2, -0.3 },
    }

    local SKY_AMBIENT = {
        [0] = { 85, 100, 120 },
        [1] = { 120, 60, 45 },
        [2] = { 55, 95, 100 },
        [3] = { 95, 98, 105 },
        [4] = { 95, 105, 125 },
        [5] = { 120, 100, 65 },
        [6] = { 60, 75, 60 },
        [7] = { 70, 105, 70 },
        [8] = { 110, 115, 125 },
        [9] = { 85, 60, 115 },
    }

    local SKY_AIR = {
        [0] = { 140, 165, 195 },
        [1] = { 159, 40, 2 },
        [2] = { 41, 37, 129 },
        [3] = { 59, 94, 235 },
        [4] = { 185, 194, 230 },
        [5] = { 190, 170, 120 },
        [6] = { 19, 19, 82 },
        [7] = { 0, 52, 37 },
        [8] = { 135, 182, 235 },
        [9] = { 96, 27, 74 },
    }

    local function sky_says(table_of_skies)
        if OF.util.binding("get_skybox") == nil then return nil end
        local sky = OF.util.optional("get_skybox", nil)
        if type(sky) ~= "number" then return nil end
        return table_of_skies[sky]
    end

    function modifiers.sun_of_the_sky()
        local dir = sky_says(SKY_DIR)
        if dir == nil then return { 0, 0, 0 } end
        return { dir[1], dir[2], dir[3] }
    end

    function modifiers.dark_of_the_sky()
        local light = sky_says(SKY_AMBIENT)
        if light == nil then return { 127, 127, 127, 0 } end
        return { light[1], light[2], light[3], 0 }
    end

    function modifiers.air_of_the_sky()
        return sky_says(SKY_AIR)
    end
end

local function mercy_refuses(hazardType)
    if hazardType == HAZARD_TYPE_LAVA_FLOOR
        or hazardType == HAZARD_TYPE_LAVA_WALL then
        return modifiers.setting("mercy", "lava", false) == true
    end
    if hazardType == HAZARD_TYPE_QUICKSAND then
        return modifiers.setting("mercy", "sand", false) == true
    end

    return false
end

hook_event(HOOK_ALLOW_HAZARD_SURFACE, function(m, hazardType)
    if m == nil or m.playerIndex ~= 0 then return end

    if mercy_refuses(hazardType) then return false end
end)

function modifiers.mercy_note()
    if modifiers.level("mercy") <= 0 then return nil end
    if modifiers.setting("mercy", "lava", false) ~= true then return nil end
    if modifiers.level("lava") <= 0 then return nil end
    return OF.lang.t("The floor is lava is on - it will not burn either.")
end

function modifiers.wear_shadows(on)
    if not OF.util.asks(OF.rules, "set_shadows") then return false end
    return OF.rules.set_shadows(on) == true
end

do

    local trail = {}
    local moved = false

    local function node_of(index)
        local m = gMarioStates ~= nil and gMarioStates[index] or nil
        if m == nil or m.marioObj == nil then return nil end
        local header = m.marioObj.header
        if header == nil or header.gfx == nil then return nil end
        if header.gfx.shadowPos == nil then return nil end
        return header.gfx
    end

    local function seats()
        local list = {}
        for _, entry in ipairs(OF.util.connected_players()) do
            local m = gMarioStates[entry.localIndex]
            if m ~= nil and m.pos ~= nil
                and OF.util.optional("is_player_active", 0, m) ~= 0
                and node_of(entry.localIndex) ~= nil then
                table.insert(list, entry.localIndex)
            end
        end
        return list
    end

    function modifiers.forget_the_shadows()
        for index = 0, (MAX_PLAYERS or 16) - 1 do
            local gfx = node_of(index)
            if gfx ~= nil then gfx.disableAutomaticShadowPos = false end
            trail[index] = nil
        end
        moved = false
    end

    function modifiers.shadow_is_moved()
        return moved
    end

    function modifiers.move_the_shadows()
        local behind = modifiers.setting("shadow", "behind", nil)
        local swap = modifiers.setting("shadow", "swap", nil)
        if behind == nil and swap ~= true then
            if moved then modifiers.forget_the_shadows() end
            return
        end

        local here = seats()
        if #here == 0 then return end
        moved = true

        for _, index in ipairs(here) do
            local gfx = node_of(index)
            local kept = trail[index]
            if kept == nil then kept = {} trail[index] = kept end
            table.insert(kept, { x = gfx.pos.x, y = gfx.pos.y, z = gfx.pos.z })
            while #kept > (behind or 1) + 1 do table.remove(kept, 1) end
        end

        for at, index in ipairs(here) do
            local gfx = node_of(index)
            local from = nil
            if swap == true then

                local other = here[(at % #here) + 1]
                local theirs = node_of(other)
                if theirs ~= nil then
                    from = { x = theirs.pos.x, y = theirs.pos.y,
                             z = theirs.pos.z }
                end
            else
                from = trail[index][1]
            end
            if from ~= nil then
                gfx.disableAutomaticShadowPos = true
                gfx.shadowPos.x = from.x
                gfx.shadowPos.y = from.y
                gfx.shadowPos.z = from.z
            end
        end
    end
end

hook_event(HOOK_UPDATE, function() modifiers.move_the_shadows() end)

function modifiers.hold_camlag()
    local pos = modifiers.setting("camlag", "pos", nil)
    local foc = modifiers.setting("camlag", "foc", nil)
    if pos == nil or gLakituState == nil then return false end

    gLakituState.posHSpeed = pos
    gLakituState.posVSpeed = pos
    gLakituState.focHSpeed = foc
    gLakituState.focVSpeed = foc
    return true
end

do

    local LOOK_AHEAD = 1000

    local SUBJECT_LIFT = 125

    local SNAP = 400

    local ENGINE_POS_H, ENGINE_POS_V = 0.3, 0.3
    local ENGINE_FOC_H, ENGINE_FOC_V = 0.8, 0.3

    local PITCH_LIMIT = 0x3600

    local SETTLE = 10

    local pin = nil
    local pinFor = nil

    local pinRoom = nil

    local startAt = nil
    local settle = 0
    local driving = false

    local function fold(value)
        value = math.floor(value or 0) % 0x10000
        if value >= 0x8000 then value = value - 0x10000 end
        return value
    end

    local function along(x, y, z, dist, pitch, yaw)
        return x + dist * coss(pitch) * sins(yaw),
               y + dist * sins(pitch),
               z + dist * coss(pitch) * coss(yaw)
    end

    local function put(vec, x, y, z)
        if vec == nil then return end
        vec.x, vec.y, vec.z = x, y, z
    end

    local function room_now()
        local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
        if np == nil then return nil end
        return tostring(np.currLevelNum) .. ":" .. tostring(np.currAreaIndex)
    end

    local function look_here()
        local s = gLakituState
        if s == nil or s.pos == nil then return nil end
        local view = s.oldYaw
        if type(view) ~= "number" then view = (s.yaw or 0) + 0x8000 end
        return {
            x = s.pos.x, y = s.pos.y, z = s.pos.z,
            yaw = fold(view),
            pitch = OF.util.clamp(fold(s.oldPitch or 0), -PITCH_LIMIT, PITCH_LIMIT),
        }
    end

    local function crowd_middle()
        local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
        if np == nil then return nil end
        local sx, sy, sz, count = 0, 0, 0, 0
        for _, entry in ipairs(OF.util.connected_players()) do
            local other = entry.np
            if other ~= nil and other.currLevelNum == np.currLevelNum
                and other.currAreaIndex == np.currAreaIndex then
                local m = gMarioStates ~= nil and gMarioStates[entry.localIndex] or nil
                if m ~= nil and m.pos ~= nil
                    and OF.util.optional("is_player_active", 0, m) ~= 0 then
                    sx, sy, sz = sx + m.pos.x, sy + m.pos.y, sz + m.pos.z
                    count = count + 1
                end
            end
        end
        if count == 0 then return nil end
        return sx / count, sy / count, sz / count, count
    end

    modifiers.pin_crowd_middle = crowd_middle

    local function place_for(stop)
        if stop == "crowd" then return startAt or pin end
        return pin
    end

    local function focus_for(stop, place)
        if stop == "watch" then
            local m = gMarioStates ~= nil and gMarioStates[0] or nil
            if m ~= nil and m.pos ~= nil then
                return m.pos.x, m.pos.y + SUBJECT_LIFT, m.pos.z
            end
        elseif stop == "crowd" then
            local x, y, z = crowd_middle()
            if x ~= nil then return x, y + SUBJECT_LIFT, z end
        end
        return along(place.x, place.y, place.z, LOOK_AHEAD, place.pitch, place.yaw)
    end

    modifiers.pin_focus_for = focus_for

    local function drive(place, fx, fy, fz)
        local s = gLakituState
        local px, py, pz = place.x, place.y, place.z

        local dx, dy, dz = px - s.pos.x, py - s.pos.y, pz - s.pos.z
        local jumped = (dx * dx + dy * dy + dz * dz) > SNAP * SNAP

        put(s.pos, px, py, pz)
        put(s.curPos, px, py, pz)
        put(s.goalPos, px, py, pz)
        put(s.focus, fx, fy, fz)
        put(s.curFocus, fx, fy, fz)
        put(s.goalFocus, fx, fy, fz)

        s.posHSpeed, s.posVSpeed = 0, 0
        s.focHSpeed, s.focVSpeed = 0, 0

        local ax, az = fx - px, fz - pz
        if (ax * ax + az * az) >= 1 then
            s.yaw = fold(atan2s(az, ax) + 0x8000)
        end

        driving = true
        if jumped then OF.util.optional("skip_camera_interpolation", nil) end
    end

    local function let_go()
        if not driving then return false end
        driving = false
        if gLakituState == nil then return false end
        if not modifiers.hold_camlag() then
            gLakituState.posHSpeed = ENGINE_POS_H
            gLakituState.posVSpeed = ENGINE_POS_V
            gLakituState.focHSpeed = ENGINE_FOC_H
            gLakituState.focVSpeed = ENGINE_FOC_V
        end
        OF.util.optional("skip_camera_interpolation", nil)
        return true
    end

    function modifiers.forget_pin()
        let_go()
        pin, pinFor, pinRoom, startAt, settle = nil, nil, nil, nil, 0
        return true
    end

    function modifiers.pin_place()
        return pin
    end

    function modifiers.pin_start()
        return startAt
    end

    function modifiers.pin_driving()
        return driving
    end

    function modifiers.camera_is_held()
        return driving == true
    end

    function modifiers.pin_frame()
        local s = gLakituState
        if s == nil or s.pos == nil then return end

        local room = room_now()
        if room ~= pinRoom then

            let_go()
            pin, pinFor, startAt, settle = nil, nil, nil, 0
            pinRoom = room
        end
        if startAt == nil and room ~= nil then
            settle = settle + 1
            if settle >= SETTLE then startAt = look_here() end
        end

        local stop = modifiers.setting("view", "pin", nil)
        if stop == nil then

            if pin ~= nil or driving then
                let_go()
                pin, pinFor = nil, nil
            end
            return
        end

        if OF.util.hands_on() ~= nil then
            let_go()
            return
        end

        if pin == nil or pinFor ~= stop then
            pin = look_here()
            pinFor = stop
        end

        local place = place_for(stop)
        if place == nil then return end
        local fx, fy, fz = focus_for(stop, place)
        drive(place, fx, fy, fz)
    end
end

hook_event(HOOK_UPDATE, function() modifiers.pin_frame() end)

local LIGHT_FULL = 255

modifiers.shadingHeld = modifiers.shadingHeld or false

function modifiers.wear_shading(on)
    if OF.util.binding("set_lighting_color") == nil then return false end

    if not on then
        if not modifiers.shadingHeld then return true end
        modifiers.shadingHeld = false
        for index = 0, 2 do
            OF.util.optional("set_lighting_color", nil, index, LIGHT_FULL)
            OF.util.optional("set_lighting_color_ambient", nil, index, LIGHT_FULL)
        end
        return true
    end

    local dir = modifiers.setting("shading", "dir", nil)
    local amb = modifiers.setting("shading", "amb", nil)
    if dir == nil or amb == nil then return false end

    modifiers.shadingHeld = true
    for index = 0, 2 do

        OF.util.optional("set_lighting_color", nil, index, dir[index + 1])
        OF.util.optional("set_lighting_color_ambient", nil, index, amb[index + 1])
    end
    return true
end

modifiers.showHeld = modifiers.showHeld or false

function modifiers.wear_lightshow(world, light, shadow)
    if OF.util.binding("set_vertex_color") == nil then return false end

    if world == nil and light == nil and shadow == nil then
        if not modifiers.showHeld then return true end
        modifiers.showHeld = false
        for index = 0, 2 do

            OF.util.optional("set_vertex_color", nil, index,
                modifiers.studio_channel(index))
            OF.util.optional("set_lighting_color", nil, index, LIGHT_FULL)
            OF.util.optional("set_lighting_color_ambient", nil, index, LIGHT_FULL)
        end
        return true
    end

    modifiers.showHeld = true

    local function part(colour, which)
        return math.floor(OF.util.clamp(colour[which] or 255, 0, 255))
    end

    local function world_part(which, index)
        return math.floor(part(world, which) * modifiers.studio_channel(index) / 255)
    end

    if world ~= nil then
        OF.util.optional("set_vertex_color", nil, 0, world_part("r", 0))
        OF.util.optional("set_vertex_color", nil, 1, world_part("g", 1))
        OF.util.optional("set_vertex_color", nil, 2, world_part("b", 2))
    end

    if light ~= nil then
        OF.util.optional("set_lighting_color", nil, 0, part(light, "r"))
        OF.util.optional("set_lighting_color", nil, 1, part(light, "g"))
        OF.util.optional("set_lighting_color", nil, 2, part(light, "b"))
    end
    if shadow ~= nil then
        OF.util.optional("set_lighting_color_ambient", nil, 0, part(shadow, "r"))
        OF.util.optional("set_lighting_color_ambient", nil, 1, part(shadow, "g"))
        OF.util.optional("set_lighting_color_ambient", nil, 2, part(shadow, "b"))
    end
    return true
end

local function quiet_mask(level)
    local function bit(name)
        local value = _G[name]
        if type(value) ~= "number" then return 0 end
        return 1 << value
    end

    local objects = bit("SOUND_BANK_OBJ") | bit("SOUND_BANK_OBJ2")
    if level <= 1 then return objects end

    local world = objects | bit("SOUND_BANK_ENV") | bit("SOUND_BANK_GENERAL")
        | bit("SOUND_BANK_GENERAL2") | bit("SOUND_BANK_AIR")
    if level <= 2 then return world end

    return world | bit("SOUND_BANK_ACTION") | bit("SOUND_BANK_MOVING")
        | bit("SOUND_BANK_MARIO_VOICE") | bit("SOUND_BANK_LUIGI_VOICE")
        | bit("SOUND_BANK_WARIO_VOICE") | bit("SOUND_BANK_TOAD_VOICE")
end

modifiers.quietHeld = modifiers.quietHeld or nil

function modifiers.wear_quiet(on)
    if OF.util.binding("sound_banks_disable") == nil then return false end

    if not on then
        if modifiers.quietHeld == nil then return true end

        OF.util.optional("sound_banks_enable", nil, 0, modifiers.quietHeld)
        modifiers.quietHeld = nil
        return true
    end

    local level = modifiers.level("quiet")
    if level <= 0 then return false end
    modifiers.quietHeld = quiet_mask(level)
    OF.util.optional("sound_banks_disable", nil, 0, modifiers.quietHeld)
    return true
end

function modifiers.step_name(key, packed)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return nil end
    if modifiers.step_count(entry) <= 1 then return nil end

    local level
    if packed ~= nil then
        level = modifiers.parse(packed)[key] or 0
    else
        level = modifiers.level(key)
    end
    if level <= 0 then return nil end

    local step = (entry.levels or {})[level]
    return step ~= nil and step.name or nil
end

function modifiers.label(packed)
    local list = modifiers.names(packed)
    if #list == 0 then return OF.lang.t("none") end
    local said = {}
    for _, name in ipairs(list) do
        local entry = nil
        for _, candidate in ipairs(modifiers.LIST) do
            if candidate.name == name then entry = candidate break end
        end
        local step = entry ~= nil and modifiers.step_name(entry.key, packed) or nil
        if step ~= nil then
            table.insert(said, OF.lang.fill("@: @", OF.lang.t(name), OF.lang.t(step)))
        else
            table.insert(said, OF.lang.t(name))
        end
    end
    return table.concat(said, ", ")
end

local function pack_parts(set)
    local list = {}
    for _, entry in ipairs(modifiers.LIST) do
        local level = set[entry.key]
        if level ~= nil and level > 0 then
            local id = entry.id or entry.key

            if level <= 1 then
                table.insert(list, id)
            else
                table.insert(list, id .. math.floor(level))
            end
        end
    end

    return list
end

function modifiers.pack(set)
    return table.concat(pack_parts(set))
end

local WIRE_CHUNK = 160

local WIRE_KEYS = { "ofMods", "ofMods2", "ofMods3", "ofMods4" }

modifiers.WIRE_CHUNK = WIRE_CHUNK
modifiers.WIRE_KEYS = WIRE_KEYS

local function publish_parts(parts)
    local chunks = OF.util.chunk_parts(parts, WIRE_CHUNK)
    if chunks == nil or #chunks > #WIRE_KEYS then
        OF.util.chat("Too many modifiers to send at once ("
            .. tostring(#parts) .. " of them).", "warn")
        return false
    end
    local ok = true
    for index, wireKey in ipairs(WIRE_KEYS) do
        if not OF.util.publish(wireKey, chunks[index] or "") then ok = false end
    end
    return ok
end

local function publish(set)
    if OF.util.asks(OF.cheats, "forget_room_scale") then
        OF.cheats.forget_room_scale()
    end
    return publish_parts(pack_parts(set))
end

function modifiers.publish_text(text)
    if not OF.util.is_host() then return false end
    return publish(modifiers.parse(text))
end

function modifiers.publish_round(text)
    if not OF.util.is_host() then return false end
    local packed = modifiers.pack(modifiers.parse(text or ""))
    if #packed > WIRE_CHUNK then
        OF.util.chat("The round's modifier set is too long to send.", "warn")
        return false
    end
    return OF.util.publish(modifiers.ROUND_KEY, packed)
end

function modifiers.set_round_level(key, level)
    if not OF.util.is_host() then return false end
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return false end
    local set = modifiers.parse(modifiers.round_text())
    level = math.floor(tonumber(level) or 0)
    if level > 0 then
        set[key] = math.min(level, modifiers.step_count(entry))
    else
        set[key] = nil
    end
    return modifiers.publish_round(modifiers.pack(set))
end

local LEARNABLE = {
    ACT_LONG_JUMP, ACT_BACKFLIP, ACT_SIDE_FLIP,
    ACT_DIVE, ACT_GROUND_POUND, ACT_TRIPLE_JUMP, ACT_DOUBLE_JUMP,
}

local BECOMES = {
    [ACT_LONG_JUMP] = ACT_JUMP, [ACT_BACKFLIP] = ACT_JUMP,
    [ACT_SIDE_FLIP] = ACT_JUMP, [ACT_DOUBLE_JUMP] = ACT_JUMP,
    [ACT_TRIPLE_JUMP] = ACT_JUMP, [ACT_DIVE] = ACT_JUMP,
    [ACT_GROUND_POUND] = ACT_FREEFALL,
}

local MOVE_NAMES = {
    [ACT_LONG_JUMP] = "The long jump",
    [ACT_BACKFLIP] = "The backflip",
    [ACT_SIDE_FLIP] = "The side flip",
    [ACT_DIVE] = "The dive",
    [ACT_GROUND_POUND] = "The ground pound",
    [ACT_TRIPLE_JUMP] = "The triple jump",
    [ACT_DOUBLE_JUMP] = "The double jump",
}

function modifiers.move_name(action)
    return MOVE_NAMES[action]
end

modifiers.LEARN_KEY = "ofLearn"
modifiers.mineLearn = modifiers.mineLearn or nil

function modifiers.room_learning()
    local packed = gGlobalSyncTable[modifiers.LEARN_KEY]
    if type(packed) ~= "string" or packed == "" then return nil end
    local seed, count = string.match(packed, "^(%d+),(%d+)$")
    if seed == nil then return nil end
    return tonumber(seed), tonumber(count)
end

function modifiers.learn_source()
    local level, yours = modifiers.in_force("learn")
    if level <= 0 then return nil end
    if yours then return "mine" end
    return "room"
end

local function learning(source)
    source = source or modifiers.learn_source()
    if source == "mine" then
        local own = modifiers.mineLearn
        if own == nil then return nil end
        return own.seed, own.count
    end
    return modifiers.room_learning()
end

function modifiers.learned(source)
    local _, count = learning(source)
    return count or 0
end

function modifiers.learnable_count()
    return #LEARNABLE
end

function modifiers.learn_order(seed)
    local order = {}
    for index, action in ipairs(LEARNABLE) do order[index] = action end
    local state = math.floor(seed or 1) % 2147483648
    for i = #order, 2, -1 do
        state = (1664525 * state + 1013904223) % 4294967296
        local j = math.floor(state / 65536) % i + 1
        order[i], order[j] = order[j], order[i]
    end
    return order
end

function modifiers.begin_learning()
    if not OF.util.is_host() then return false end
    if modifiers.room_learning() ~= nil then return true end
    local now = OF.util.optional("get_global_timer", 1) or 1
    OF.util.publish(modifiers.LEARN_KEY,
        tostring(math.floor(now) % 2147483647 + 1) .. ",0")
    return true
end

function modifiers.clear_learning()
    if not OF.util.is_host() then return false end
    OF.util.publish(modifiers.LEARN_KEY, nil)
    return true
end

function modifiers.learn_one()
    if not OF.util.is_host() then return nil end
    local seed, count = modifiers.room_learning()
    if seed == nil then return nil end
    if count >= #LEARNABLE then return nil end

    OF.util.publish(modifiers.LEARN_KEY, tostring(seed) .. "," .. (count + 1))
    local order = modifiers.learn_order(seed)
    return order[count + 1]
end

function modifiers.learn_one_mine()
    local own = modifiers.mineLearn
    if own == nil or own.count >= #LEARNABLE then return nil end
    own.count = own.count + 1
    return modifiers.learn_order(own.seed)[own.count]
end

function modifiers.keep_learning()
    if OF.util.is_host() then
        local room = modifiers.room_level("learn") > 0
        if room and modifiers.room_learning() == nil then modifiers.begin_learning()
        elseif not room and modifiers.room_learning() ~= nil and not modifiers.round_holds() then
            modifiers.clear_learning()
        end
    end
    local source = modifiers.learn_source()
    if source == "mine" then
        if modifiers.mineLearn == nil then
            local now = OF.util.optional("get_global_timer", 1) or 1
            modifiers.mineLearn = { seed = math.floor(now) % 2147483647 + 1, count = 0 }
        end
    else
        modifiers.mineLearn = nil
    end
    return source
end

function modifiers.learn_note()
    local level = modifiers.level("learn")
    if level <= 0 then return nil end
    local _, count = learning()
    if count == nil then return nil end
    return OF.lang.fill("@ of @ moves back", tostring(count),
        tostring(#LEARNABLE))
end

function modifiers.moves_taken()
    local learnLevel = modifiers.level("learn")
    if learnLevel > 0 then
        local seed, count = learning()
        if seed == nil then return nil end
        local order = modifiers.learn_order(seed)
        local taken = {}
        for index = count + 1, #order do
            local action = order[index]

            if not (learnLevel >= 2 and action == ACT_DOUBLE_JUMP) then
                taken[action] = BECOMES[action] or ACT_JUMP
            end
        end
        return taken
    end

    return nil
end

function modifiers.substitute_move(m, action)
    if m == nil or m.playerIndex ~= 0 then return nil end
    local taken = modifiers.moves_taken()
    if taken == nil then return nil end
    return taken[action]
end

hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action)
    return modifiers.substitute_move(m, action)
end)

modifiers.borrowing = false

function modifiers.borrow(fn)
    local was = modifiers.borrowing
    modifiers.borrowing = true
    local ok, err = pcall(fn)
    modifiers.borrowing = was
    if not ok then error(err, 0) end
end

function modifiers.set_text(packed)
    if not OF.util.is_host() then return false end

    if not modifiers.borrowing and OF.util.asks(OF.chaos, "release_all") then
        OF.chaos.release_all()
    end
    local set = modifiers.parse(packed)
    publish(set)

    if not modifiers.borrowing and OF.util.asks(OF.chaos, "rebase") then
        OF.chaos.rebase(set)
    end
    return true
end

function modifiers.text()
    if textNow == nil or textAt ~= wireStamp then
        textAt = wireStamp
        textNow = OF.util.joined(WIRE_KEYS)
    end
    return textNow
end

function modifiers.toggle(key)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return false, "No such modifier." end
    if not OF.perms.can(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end

    local next = modifiers.level(key) + 1
    if next > modifiers.step_count(entry) then next = 0 end
    return modifiers.set_level(key, next)
end

function modifiers.set_level_here(asker, key, level)
    if not OF.util.is_host() then return false, "Only the host sets these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required(modifiers.ROW_RANK, asker) then
        return false, "Your rank cannot do that."
    end
    return modifiers.apply_level(key, level, asker)
end

function modifiers.set_level(key, level)
    local entry = modifiers.BY_KEY[key]

    if entry == nil and OF.util.asks(OF.rules, "find")
        and OF.rules.find(key) ~= nil then
        return OF.rules.set(key, level)
    end
    if entry == nil then return false, "No such modifier." end
    if not OF.perms.can(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end

    if OF.util.is_host() then return modifiers.apply_level(key, level, 0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("modset", key, level)
    end
    return false, "No host to ask yet - try again in a second."
end

function modifiers.apply_level(key, level, askerLocal)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return false, "No such modifier." end

    level = math.floor(tonumber(level) or 0)
    if level < 0 then level = 0 end
    if level > modifiers.step_count(entry) then
        return false, "That modifier does not go that far."
    end

    if OF.util.asks(OF.chaos, "release") then OF.chaos.release(key) end

    local set = modifiers.parse(modifiers.text())
    if level > 0 then level = modifiers.live_step(entry, level) end
    if level <= 0 then
        set[key] = nil
    else
        set[key] = level

        for _, other in ipairs(entry.excludes or {}) do set[other] = nil end
    end

    publish(set)

    if modifiers.round_holds() and level > 0 then

        if askerLocal ~= nil and OF.util.asks(OF.notify, "send_to") then
            OF.notify.send_to(network_global_index_from_local(askerLocal),
                "A round has the modifiers - this takes effect when it ends.",
                "quiet", 4)
        end
    end

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal, modifiers.change_line(key, level))
    end
    return true
end

function modifiers.clear_here(asker)
    if not OF.util.is_host() then return false, "Only the host clears these." end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required(modifiers.ROW_RANK, asker) then
        return false, "Your rank cannot do that."
    end
    return modifiers.clear_now(asker)
end

function modifiers.clear()
    if not OF.perms.can(modifiers.ROW_RANK) then
        return false, "Your rank cannot do that."
    end
    if not modifiers.any() then return false, "Nothing is on." end
    if OF.util.is_host() then return modifiers.clear_now(0) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("modclear")
    end
    return false, "No host to ask yet - try again in a second."
end

function modifiers.clear_now(askerLocal)
    if not modifiers.any() then return false, "Nothing is on." end
    publish({})
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
        OF.notify.credit(askerLocal, OF.lang.t("everything off"))
    end
    return true
end

local applied = {}

local function sync_world()
    for _, entry in ipairs(modifiers.LIST) do
        local wanted = (modifiers.in_force(entry.key))
        local have = applied[entry.key] or 0

        if entry.fades == true and have ~= 0 and wanted ~= 0 and have ~= wanted then
            modifiers.fade_open(entry.key, modifiers.fade_shown(entry.key))
        end

        if have ~= 0 and have ~= wanted then
            if entry.restore ~= nil then entry.restore() end
            applied[entry.key] = nil
            have = 0
        end
        if wanted ~= 0 and have == 0 then
            if entry.world ~= nil then entry.world(wanted) end
            applied[entry.key] = wanted
        end
    end

    modifiers.dress_the_world()

    if modifiers.keep_learning ~= nil then modifiers.keep_learning() end

    modifiers.wear_look(modifiers.look())
end

modifiers.sync_world = sync_world

hook_event(HOOK_ON_LEVEL_INIT, function()
    modifiers.forget_fades()
    modifiers.forget_stillness()
end)

hook_event(HOOK_UPDATE, function() modifiers.dress_the_world() end)

function modifiers.resync()

    for _, entry in ipairs(modifiers.LIST) do
        if (modifiers.in_force(entry.key)) ~= 0 then applied[entry.key] = nil end
    end
    sync_world()
    return true
end

function modifiers.mine_changed()
    if OF.util.asks(OF.cheats, "forget_room_scale") then
        OF.cheats.forget_room_scale()
    end
    if modifiers.sync_world ~= nil then modifiers.sync_world() end
end

modifiers.roundWas = nil

modifiers.mapsWas = nil

function modifiers.watch_the_round()
    local now = modifiers.round_holds() == true
    local maps = nil
    if modifiers.placeVisuals ~= nil or modifiers.placeVision ~= nil then
        maps = modifiers.maps_bring_weather()
    end

    local select = modifiers.select_holds()
    if now == modifiers.roundWas and maps == modifiers.mapsWas
        and select == modifiers.selectWas then return false end
    modifiers.mapsWas = maps
    modifiers.roundWas = now
    modifiers.selectWas = select
    modifiers.mine_changed()
    return true
end

hook_event(HOOK_UPDATE, function() modifiers.watch_the_round() end)

for _, wireKey in ipairs(WIRE_KEYS) do
    hook_on_sync_table_change(gGlobalSyncTable, wireKey, wireKey, function(tag, prevValue)

        wireStamp = wireStamp + 1
        if OF.util.asks(OF.guard, "repair") and OF.guard.repair(wireKey) then
            return
        end
        sync_world()

        local credited = OF.util.asks(OF.notify, "credits_on")
            and OF.notify.credits_on()
        local putBack = OF.util.asks(OF.guard, "putting_back")
            and OF.guard.putting_back()

        local chaosOn = OF.util.asks(OF.chaos, "on") and OF.chaos.on()
        if OF.util.asks(OF.notify, "show") and not credited and not putBack
            and not chaosOn then
            local line = modifiers.changed_line(
                OF.util.joined(WIRE_KEYS, wireKey, prevValue), modifiers.text())
            if line ~= nil then
                OF.notify.show("Modifiers: @", "quiet", 3, line)
            end
        end
    end)
end

hook_on_sync_table_change(gGlobalSyncTable, modifiers.ROUND_KEY,
    modifiers.ROUND_KEY, function()
        if OF.util.asks(OF.guard, "repair")
            and OF.guard.repair(modifiers.ROUND_KEY) then
            return
        end

        sync_world()
    end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end
    if data.ofp ~= modifiers.PACKET then return end
    if not OF.util.from_host(data) then return end
    if data.what == "clearmine" then

        local had = modifiers.mine_any()
        modifiers.clear_mine()
        if had then
            OF.notify.show("The host cleared your own modifier settings",
                "info", 4)
        end
    end

    if data.what == "clearvision" then

        local had = modifiers.vision_mine_any()
        modifiers.forget_vision_mine()
        if had then
            OF.notify.show("The host cleared the picture you built", "info", 4)
        end
    end
end)

function modifiers.forget_applied_on_load()
    local undone = 0
    for _, entry in ipairs(modifiers.LIST) do
        if (applied[entry.key] or 0) ~= 0
                and (modifiers.in_force(entry.key)) == 0
                and entry.restore ~= nil then
            local ok = pcall(entry.restore)
            if ok then undone = undone + 1 end
        end
    end
    for key in pairs(applied) do applied[key] = nil end
    return undone
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    modifiers.forget_applied_on_load()
    sync_world()

end)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    for _, entry in ipairs(modifiers.LIST) do
        if entry.apply ~= nil and modifiers.level(entry.key) > 0 then entry.apply(m) end
    end
end, OF.LOCAL_MARIO)

hook_event(HOOK_MARIO_OVERRIDE_FLOOR_CLASS, function(m, floorClass)
    if m == nil or m.playerIndex ~= 0 then return end

    if modifiers.setting("floor", "alternate", false) == true then
        return modifiers.floor_here()
    end

    if modifiers.setting("floor", "trodden", false) == true then
        return modifiers.floor_trodden(m)
    end

    local class = modifiers.setting("floor", "class", nil)
    if class ~= nil then return class end
    return nil
end)

function modifiers.floor_trodden(m)
    if m == nil or m.floor == nil then return nil end
    if not OF.util.asks(OF.ground, "is_trodden") then return nil end
    if OF.ground.is_trodden(m.floor) then return SURFACE_CLASS_VERY_SLIPPERY end
    return nil
end

function modifiers.floor_here()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil or type(np.currAreaIndex) ~= "number" then return nil end
    if np.currAreaIndex % 2 == 1 then
        return SURFACE_CLASS_VERY_SLIPPERY
    end
    return SURFACE_CLASS_NOT_SLIPPERY
end

do

local TERRAIN_COUNT = 8
local terrainBack = nil

local function terrain_lookup()
    if terrainBack ~= nil then return terrainBack end

    local bases = {
        "SOUND_ACTION_TERRAIN_JUMP",
        "SOUND_ACTION_TERRAIN_LANDING",
        "SOUND_ACTION_TERRAIN_STEP",
        "SOUND_ACTION_TERRAIN_BODY_HIT_GROUND",
        "SOUND_ACTION_TERRAIN_STEP_TIPTOE",
        "SOUND_ACTION_TERRAIN_STUCK_IN_GROUND",
        "SOUND_ACTION_TERRAIN_HEAVY_LANDING",
        "SOUND_MOVING_TERRAIN_SLIDE",
        "SOUND_MOVING_TERRAIN_RIDING_SHELL",
    }

    local map = {}
    for _, name in ipairs(bases) do
        local base = _G[name]
        if type(base) == "number" then
            for terrain = 0, TERRAIN_COUNT - 1 do
                map[base + (terrain << 16)] = base
            end
        end
    end
    terrainBack = map
    return map
end

function modifiers.footstep_for(soundBits)
    if type(soundBits) ~= "number" then return nil end
    local wanted = modifiers.setting("steps", "terrain", nil)
    if wanted == nil then return nil end

    local base = terrain_lookup()[soundBits]
    if base == nil then return nil end

    local swapped = base + (wanted << 16)
    if swapped == soundBits then return nil end
    return swapped
end

local SHUFFLED_SOUNDS = {}
do
    local seen = {}

    local candidates = table.pack(
        SOUND_GENERAL_COIN, SOUND_GENERAL_RED_COIN, SOUND_GENERAL_BOING1,
        SOUND_GENERAL_EXPLOSION6, SOUND_OBJ_GOOMBA_ALERT, SOUND_GENERAL_OPEN_WOOD_DOOR,
        SOUND_GENERAL_CLOSE_WOOD_DOOR, SOUND_ACTION_HIT, SOUND_ACTION_SPIN,
        SOUND_ACTION_TWIRL, SOUND_ACTION_THROW, SOUND_ACTION_BONK, SOUND_OBJ_STOMPED,
        SOUND_GENERAL_BREAK_BOX, SOUND_MENU_CAMERA_BUZZ, SOUND_GENERAL_COLLECT_1UP,
        SOUND_OBJ_BOBOMB_WALK, SOUND_OBJ_KOOPA_TALK, SOUND_GENERAL_CANNON_UP,
        SOUND_GENERAL_PAINTING_EJECT, SOUND_MENU_STAR_SOUND)
    for index = 1, candidates.n do
        local bits = candidates[index]
        if type(bits) == "number" and not seen[bits] then
            seen[bits] = true
            SHUFFLED_SOUNDS[#SHUFFLED_SOUNDS + 1] = bits
        end
    end
end
modifiers.SHUFFLED_SOUNDS = SHUFFLED_SOUNDS

function modifiers.shuffled_sound(soundBits)
    if type(soundBits) ~= "number" then return nil end
    if modifiers.setting("pitch", "shuffle", false) ~= true then return nil end
    local count = #SHUFFLED_SOUNDS
    if count < 2 then return nil end
    local at = nil
    for index, bits in ipairs(SHUFFLED_SOUNDS) do
        if bits == soundBits then at = index break end
    end
    if at == nil then return nil end
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local level = np ~= nil and tonumber(np.currLevelNum) or 0
    local turn = (level * 7) % (count - 1) + 1
    return SHUFFLED_SOUNDS[(at - 1 + turn) % count + 1]
end

hook_event(HOOK_ON_PLAY_SOUND, function(soundBits, pos)

    if OF.util.asks(OF.roundscope, "mutes_sound") then
        local muted = OF.roundscope.mutes_sound(pos)
        if muted ~= nil then return muted end
    end
    local swapped = modifiers.footstep_for(soundBits)
    local dealt = modifiers.shuffled_sound(swapped or soundBits)
    if dealt ~= nil then swapped = dealt end
    local pitched = modifiers.pitch_for(swapped or soundBits, pos)
    if pitched ~= nil then return pitched end
    return swapped
end)
end

do

local MAX_LANTERNS = 16

local lanterns = {}
local saidLanternTaken = false

local LANTERN_HEIGHT = 90

function modifiers.star_home_lift()
    return modifiers.setting("starhome", "over", nil)
end

function modifiers.lantern_count()
    local count = 0
    for _ in pairs(lanterns) do count = count + 1 end
    return count
end

function modifiers.clear_lanterns()
    local had = next(lanterns) ~= nil
    for localIndex, id in pairs(lanterns) do
        OF.util.optional("le_remove_light", nil, id)
        lanterns[localIndex] = nil
    end
    saidLanternTaken = false

    if had and not modifiers.owns_lighting() then
        OF.util.optional("le_set_enabled", nil, false)
    end
    return true
end

function modifiers.lantern_note()
    if modifiers.level("lantern") <= 0 then return nil end
    if modifiers.level("dark") > 0 then return nil end

    return OF.lang.t("Darkness under it - a lamp wants a dark room.")
end

local function lantern_pos(localIndex)
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return nil end

    if OF.util.optional("is_player_active", 0, m) == 0 then return nil end

    local scale = 1.0
    if OF.util.asks(OF.cheats, "wanted_scale_for") then
        local worn = OF.cheats.wanted_scale_for(localIndex)
        if type(worn) == "number" and worn > 0 then scale = worn end
    end
    return m.pos.x, m.pos.y + LANTERN_HEIGHT * scale, m.pos.z
end

local function lantern_beat(kind, localIndex, rgb, radius, glow)
    if kind == nil then return nil end
    local frame = OF.util.optional("get_global_timer", 0) or 0

    if kind == "gutter" then

        local tick = math.floor(frame / 3) + localIndex * 977
        local n = (tick * 1103515245 + 12345) % 2147483648
        local amount = (n % 1000) / 1000
        return rgb[1], rgb[2], rgb[3], radius, glow * (0.45 + 0.55 * amount)
    end

    if kind == "breathe" then

        local phase = ((frame + localIndex * 11) % 90) / 90
        local swing = math.sin(phase * 2 * math.pi)
        return rgb[1], rgb[2], rgb[3],
            radius * (0.78 + 0.22 * swing), glow * (0.70 + 0.30 * swing)
    end

    if kind == "alarm" then

        local other = (math.floor(frame / 12) + localIndex) % 2 == 1
        if other then
            return 255 - rgb[1], 255 - rgb[2], 255 - rgb[3], radius, glow
        end
        return rgb[1], rgb[2], rgb[3], radius, glow
    end

    return nil
end

local function lantern_byte(value)
    local n = math.floor((value or 0) + 0.5)
    if n < 0 then return 0 end
    if n > 255 then return 255 end
    return n
end

local function lantern_update()
    local step = modifiers.level("lantern")

    if step <= 0 then

        if next(lanterns) ~= nil then modifiers.clear_lanterns() end
        return
    end

    if next(lanterns) == nil and not modifiers.owns_lighting()
        and OF.util.optional("le_is_enabled", false) then
        if not saidLanternTaken then
            saidLanternTaken = true
            OF.notify.show("Another mod owns the lighting - the lanterns are off",
                "warn", 5)
        end
        return
    end

    local rgb = modifiers.setting("lantern", "light", nil)
    if rgb == nil then return end
    local radius = modifiers.setting("lantern", "radius", 1200)
    local glow = modifiers.setting("lantern", "glow", 1.2)
    local beat = modifiers.setting("lantern", "beat", nil)
    local spread = modifiers.setting("lantern", "spread", false)

    local here = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local localIndex = entry.localIndex
        if modifiers.lantern_count() < MAX_LANTERNS or lanterns[localIndex] ~= nil then
            local x, y, z = lantern_pos(localIndex)
            if x ~= nil then
                here[localIndex] = true
                local id = lanterns[localIndex]

                if id == nil or not OF.util.optional("le_light_exists", false, id) then
                    id = OF.util.optional("le_add_light", nil,
                        x, y, z, rgb[1], rgb[2], rgb[3], radius, glow)
                    lanterns[localIndex] = id

                    if spread and id ~= nil then
                        OF.util.optional("le_set_light_use_surface_normals",
                            nil, id, false)
                    end
                else
                    OF.util.optional("le_set_light_pos", nil, id, x, y, z)

                    local r, g, b, wide, bright =
                        lantern_beat(beat, localIndex, rgb, radius, glow)
                    if r ~= nil then
                        OF.util.optional("le_set_light_color", nil, id,
                            lantern_byte(r), lantern_byte(g), lantern_byte(b))

                        OF.util.optional("le_set_light_radius", nil, id, wide)
                        OF.util.optional("le_set_light_intensity", nil, id, bright)
                    end
                end
            end
        end
    end

    for localIndex, id in pairs(lanterns) do
        if not here[localIndex] then
            OF.util.optional("le_remove_light", nil, id)
            lanterns[localIndex] = nil
        end
    end
end

modifiers.lantern_update = lantern_update

hook_event(HOOK_UPDATE, lantern_update)
end

do

local GAS_EVERYWHERE = 30000

function modifiers.gas_level()
    if modifiers.level("gas") <= 0 then return nil end

    if modifiers.setting("gas", "everywhere", false) == true then
        return GAS_EVERYWHERE
    end

    local share = modifiers.setting("gas", "share", nil)
    if share == nil then return nil end
    if not (OF.util.asks(OF.ground, "lowest") and OF.util.asks(OF.ground, "highest")) then
        return nil
    end

    local low = OF.ground.lowest()
    local high = OF.ground.highest()
    if low == nil or high == nil or high <= low then return nil end
    return low + (high - low) * share
end

function modifiers.gas_reaches()
    local ours = modifiers.gas_level()
    if ours == nil then return false end
    if find_poison_gas_level == nil then return true end

    local m = gMarioStates[0]
    local x, z = 0, 0
    if m ~= nil and m.pos ~= nil then x, z = m.pos.x, m.pos.z end

    local ok, answer = pcall(find_poison_gas_level, x, z)

    if not ok or type(answer) ~= "number" then return true end
    return answer >= ours
end

function modifiers.gas_note()
    if modifiers.level("gas") <= 0 then return nil end
    if modifiers.gas_level() == nil then
        return OF.lang.t("This level's floors are not measured yet.")
    end
    if not modifiers.gas_reaches() then
        return OF.lang.t("This course will not take gas - nothing happens.")
    end
    if modifiers.setting("gas", "everywhere", false) == true then
        return OF.lang.t("Everywhere - eighteen seconds from full.")
    end
    return nil
end

function modifiers.clear_gas()
    return true
end

hook_event(HOOK_ON_FIND_POISON_GAS_LEVEL, function(x, z, current)

    if modifiers.gasHushed then return nil end

    local ours = modifiers.gas_level()
    if ours == nil then return nil end
    if type(current) == "number" and current > ours then return nil end
    return ours
end)
end

do

local MAX_CLUSTER_PENDING = 6

local CLUSTER_AROUND = 8

local CLUSTER_GAP = 5

local clusters = {}

local poundWas = {}

local stuntDue = nil

function modifiers.cluster_pending()
    return #clusters
end

function modifiers.stunt_pending()
    return stuntDue ~= nil
end

function modifiers.clear_cluster()
    for index = #clusters, 1, -1 do clusters[index] = nil end
    for key in pairs(poundWas) do poundWas[key] = nil end
    stuntDue = nil
    return true
end

local function cluster_now()
    return OF.util.optional("get_global_timer", 0) or 0
end

function modifiers.begin_cluster(x, y, z)
    local rings = modifiers.setting("cluster", "rings", nil)
    if rings == nil then return false end
    if x == nil or y == nil or z == nil then return false end

    while #clusters >= MAX_CLUSTER_PENDING do table.remove(clusters, 1) end

    table.insert(clusters, {
        x = x, y = y, z = z,
        rings = rings,
        reach = modifiers.setting("cluster", "reach", 340),
        ring = 0,
        at = cluster_now(),
    })
    return true
end

local function cluster_ring(spot, ring)
    local radius = spot.reach * ring
    for index = 0, CLUSTER_AROUND - 1 do
        local angle = index * 2 * math.pi / CLUSTER_AROUND
        OF.util.optional("spawn_non_sync_object", nil,
            id_bhvExplosion, E_MODEL_EXPLOSION,
            spot.x + math.sin(angle) * radius,
            spot.y + 30,
            spot.z + math.cos(angle) * radius,
            nil)
    end
end

local function cluster_update()
    if #clusters == 0 then return end

    if modifiers.level("cluster") <= 0 then
        modifiers.clear_cluster()
        return
    end

    local now = cluster_now()
    for index = #clusters, 1, -1 do
        local spot = clusters[index]
        if now - spot.at >= spot.ring * CLUSTER_GAP then
            spot.ring = spot.ring + 1
            cluster_ring(spot, spot.ring)
            if spot.ring >= spot.rings then table.remove(clusters, index) end
        end
    end
end

modifiers.cluster_update = cluster_update

local function stunt_update()
    if stuntDue == nil then return false end

    if modifiers.level("cluster") <= 0 then
        stuntDue = nil
        return false
    end
    if cluster_now() < stuntDue then return false end
    stuntDue = nil

    local m = gMarioStates[0]
    if m == nil then return false end
    local jump, triple = _G["ACT_JUMP"], _G["ACT_TRIPLE_JUMP"]
    if jump == nil or triple == nil then return false end
    if m.action ~= jump then return false end

    local write = OF.util.binding("set_mario_action")
    if write == nil then return false end
    write(m, triple, 0)
    return true
end

modifiers.stunt_update = stunt_update

function modifiers.watch_the_pound(m)
    if m == nil then return false end
    local rings = modifiers.level("cluster") > 0
    local waves = modifiers.level("wave") > 0
    local shake = modifiers.level("shove") > 0
    if not rings and not waves and not shake then return false end

    local landing = _G["ACT_GROUND_POUND_LAND"]
    if landing == nil then return false end

    local index = m.playerIndex or 0
    local was = poundWas[index]
    poundWas[index] = m.action

    if m.action ~= landing or was == landing then return false end
    if m.pos == nil then return false end

    local made = rings and modifiers.begin_cluster(m.pos.x, m.pos.y, m.pos.z)
        or false

    if waves and m.playerIndex == 0 then

        local floor = tonumber(m.floorHeight)
        if floor == nil then floor = m.pos.y end
        if modifiers.begin_wave(m.pos.x, floor, m.pos.z) then made = true end
    end

    if shake and modifiers.shake_the_floor(m.pos.x, m.pos.y, m.pos.z) > 0 then
        made = true
    end
    if shake and modifiers.feel_the_tremor(m) then made = true end

    if rings and m.playerIndex == 0 and m.heldObj == nil then
        local gap = modifiers.setting("cluster", "stunt", nil)
        local jump = _G["ACT_JUMP"]
        local write = OF.util.binding("set_mario_action")
        if gap ~= nil and jump ~= nil and write ~= nil then
            write(m, jump, 0)
            stuntDue = cluster_now() + gap
            made = true
        end
    end
    return made
end

hook_event(HOOK_MARIO_UPDATE, function(m) modifiers.watch_the_pound(m) end)
hook_event(HOOK_UPDATE, function()
    cluster_update()
    stunt_update()
end)
end

do

local MAX_WAVE_PENDING = 4

local WAVE_GAP = 24

local pending = {}

local sent = {}

function modifiers.wave_pending()
    return #pending
end

function modifiers.waves_live()
    local kept = 0
    for index = 1, #sent do
        local wave = sent[index]
        sent[index] = nil
        if OF.util.alive(wave) and wave.activeFlags ~= 0 then
            kept = kept + 1
            sent[kept] = wave
        end
    end
    return kept
end

function modifiers.clear_waves()
    for index = #pending, 1, -1 do pending[index] = nil end
    for index = #sent, 1, -1 do
        local wave = sent[index]
        if OF.util.alive(wave) then wave.activeFlags = 0 end
        sent[index] = nil
    end
    return true
end

local function wave_now()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function send_wave(x, y, z)

    if OF.util.asks(OF.roundscope, "shares_room_with_round")
        and OF.roundscope.shares_room_with_round() then return nil end
    local wave = OF.slots.spawn_sync(
        id_bhvBowserShockWave, E_MODEL_BOWSER_WAVE, x, y, z, nil)

    if wave == nil then return false end
    table.insert(sent, wave)
    return true
end

function modifiers.begin_wave(x, y, z)
    local waves = modifiers.setting("wave", "waves", nil)
    if waves == nil then return false end
    if x == nil or y == nil or z == nil then return false end

    while #pending >= MAX_WAVE_PENDING do table.remove(pending, 1) end

    table.insert(pending, {
        x = x, y = y, z = z,
        waves = waves,
        sent = 0,
        at = wave_now(),
    })
    return true
end

local function wave_update()

    if #sent > 0 then modifiers.waves_live() end
    if #pending == 0 then return end

    if modifiers.level("wave") <= 0 then
        modifiers.clear_waves()
        return
    end

    local now = wave_now()
    for index = #pending, 1, -1 do
        local pound = pending[index]
        if now - pound.at >= pound.sent * WAVE_GAP then
            pound.sent = pound.sent + 1
            send_wave(pound.x, pound.y, pound.z)
            if pound.sent >= pound.waves then table.remove(pending, index) end
        end
    end
end

modifiers.wave_update = wave_update

local WAVE_LIFE = 70
local WAVE_INNER_FROM, WAVE_INNER_TO = 1.9, 2.4
local WAVE_OUTER_FROM, WAVE_OUTER_TO = 4.0, 4.8

local function wave_is_on_you(wave)
    if not OF.util.alive(wave) then return false end

    if wave.activeFlags == 0 then return false end
    local timer = tonumber(wave.oTimer)
    local size = tonumber(wave.oBowserShockWaveUnkF4)
    local away = tonumber(wave.oDistanceToMario)
    if timer == nil or size == nil or away == nil then return false end
    if timer >= WAVE_LIFE then return false end
    if (size * WAVE_INNER_FROM < away and away < size * WAVE_INNER_TO)
        or (size * WAVE_OUTER_FROM < away and away < size * WAVE_OUTER_TO) then
        return true
    end
    return false
end

local function wave_is_ours(wave)
    for index = 1, #sent do
        if sent[index] == wave then return true end
    end
    return false
end

local spareNext = false

function modifiers.wave_spares_you()
    return spareNext
end

function modifiers.clear_spared()
    spareNext = false
    return true
end

local function judge_the_waves()
    spareNext = false

    if #sent == 0 then return false end

    local m = gMarioStates[0]
    if m == nil then return false end

    if OF.util.optional("mario_is_in_air_action", 0, m) ~= 0 then return false end

    local mine, theirs = false, false
    local wave = OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvBowserShockWave)
    while wave ~= nil do
        local following = OF.util.optional("obj_get_next_with_same_behavior_id",
            nil, wave)
        if wave_is_on_you(wave) then
            if wave_is_ours(wave) then mine = true else theirs = true end
        end
        wave = following
    end

    spareNext = mine and not theirs
    return spareNext
end

modifiers.judge_the_waves = judge_the_waves

function modifiers.take_the_shock_back(m)
    if not spareNext then return false end
    if m == nil or (m.playerIndex or 0) ~= 0 then return false end

    local obj = m.marioObj
    if obj == nil then return false end
    local bit = _G["INT_STATUS_HIT_BY_SHOCKWAVE"]
    if bit == nil then return false end

    local status = tonumber(obj.oInteractStatus)
    if status == nil or not OF.util.has_flag(status, bit) then return false end
    obj.oInteractStatus = status - bit
    return true
end

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function() return { E_MODEL_BOWSER_WAVE } end)

hook_event(HOOK_UPDATE, function()
    wave_update()
    judge_the_waves()
end)
hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m) modifiers.take_the_shock_back(m) end)
end

do

local LOOSE = {
    "id_bhvPushableMetalBox",
    "id_bhvBreakableBox",
    "id_bhvBreakableBoxSmall",
    "id_bhvJrbFloatingBox",
    "id_bhvExclamationBox",
    "id_bhvFreeBowlingBall",
}

local MOST_MOVED = 24

local shifted = 0

function modifiers.shove_shifted()
    return shifted
end

function modifiers.clear_shove()
    shifted = 0
    return true
end

local function may_shift(object)
    local syncId = tonumber(object.oSyncID) or 0
    if OF.util.optional("sync_object_is_initialized", false, syncId) ~= true then
        return true
    end
    if modifiers.room_level("shove") <= 0 then return false end
    return OF.util.optional("sync_object_is_owned_locally", false, syncId) == true
end

modifiers.TREMOR_HEIGHT = 300
function modifiers.feel_the_tremor(pounder)
    local reach = modifiers.setting("shove", "reach", nil)
    local shake = modifiers.setting("shove", "shake", nil)
    if reach == nil or pounder == nil or pounder.pos == nil then return false end
    local me = gMarioStates[0]
    if me == nil or me.pos == nil then return false end
    local dx, dz = me.pos.x - pounder.pos.x, me.pos.z - pounder.pos.z
    local flat = math.sqrt(dx * dx + dz * dz)
    local high = math.abs(me.pos.y - pounder.pos.y)
    local felt = false
    if shake ~= nil and flat <= reach * 1.5 and high <= modifiers.TREMOR_HEIGHT * 2 then
        OF.util.optional("set_camera_shake_from_point", nil, shake,
            pounder.pos.x, pounder.pos.y, pounder.pos.z)
        felt = true
    end
    if (pounder.playerIndex or 0) ~= 0 and flat <= reach
        and high <= modifiers.TREMOR_HEIGHT then
        local group = OF.util.action_group(me.action)
        local standing = group == OF.util.action_group(ACT_GROUP_STATIONARY)
            or group == OF.util.action_group(ACT_GROUP_MOVING)
        local hop = _G["ACT_SHOCKWAVE_BOUNCE"]
        local write = OF.util.binding("set_mario_action")
        if standing and hop ~= nil and me.action ~= hop and write ~= nil then
            write(me, hop, 0)
            felt = true
        end
    end
    return felt
end

function modifiers.shake_the_floor(x, y, z)
    local reach = modifiers.setting("shove", "reach", nil)
    local shove = modifiers.setting("shove", "shove", nil)
    if reach == nil or shove == nil then return 0 end
    if x == nil or z == nil then return 0 end
    if reach <= 0 then return 0 end

    local moved = 0
    for _, name in ipairs(LOOSE) do
        local behaviourId = _G[name]
        if behaviourId ~= nil then
            local object = OF.util.optional("obj_get_first_with_behavior_id",
                nil, behaviourId)
            while object ~= nil and moved < MOST_MOVED do
                local following = OF.util.optional(
                    "obj_get_next_with_same_behavior_id", nil, object)
                if OF.util.alive(object) and object.activeFlags ~= 0 then
                    local dx = (tonumber(object.oPosX) or 0) - x
                    local dz = (tonumber(object.oPosZ) or 0) - z
                    local away = math.sqrt(dx * dx + dz * dz)

                    if away > 0 and away < reach and may_shift(object) then
                        local share = shove * (1 - away / reach)
                        object.oPosX = object.oPosX + dx / away * share
                        object.oPosZ = object.oPosZ + dz / away * share
                        moved = moved + 1
                    end
                end
                object = following
            end
        end
    end

    shifted = shifted + moved
    return moved
end
end

do
local function room_middle()
    local sumX, sumY, sumZ, count = 0, 0, 0, 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil
            and OF.util.optional("is_player_active", 0, m) ~= 0 then
            sumX = sumX + m.pos.x
            sumY = sumY + m.pos.y
            sumZ = sumZ + m.pos.z
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return sumX / count, sumY / count, sumZ / count, count
end

function modifiers.somebody_is_moving()
    for _, entry in ipairs(OF.util.connected_players()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and type(m.forwardVel) == "number"
            and OF.util.optional("is_player_active", 0, m) ~= 0
            and (m.forwardVel > 1.0 or m.forwardVel < -1.0) then
            return true
        end
    end
    return false
end

local function room_area()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    if type(np.currAreaIndex) ~= "number" then return nil end
    return np.currAreaIndex
end

do

local WHIRL_SLOT = 0

local LAST_AREA = 15

local wroteAt = nil

local function whirl_area()
    local area = room_area()
    if area == nil then return nil end
    if area < 0 or area > LAST_AREA then return nil end
    return area
end

function modifiers.clear_whirlpool()
    if wroteAt == nil then return false end
    if wroteAt == whirl_area() then
        OF.util.optional("set_whirlpools", nil, 0, 0, 0, 0, wroteAt, WHIRL_SLOT)
    end
    wroteAt = nil
    return true
end

function modifiers.whirl_note()
    if modifiers.level("whirl") <= 0 then return nil end
    if modifiers.true_swim_on() then return nil end
    return OF.lang.t("Only somebody swimming feels this.")
end

function modifiers.whirlpool_area()
    return wroteAt
end

local function whirl_update()
    local strength = modifiers.setting("whirl", "pull", nil)
    if strength == nil then

        if wroteAt ~= nil then modifiers.clear_whirlpool() end
        return
    end

    local area = whirl_area()
    if area == nil then return end
    local x, y, z = room_middle()
    if x == nil then return end

    OF.util.optional("set_whirlpools", nil, x, y, z, strength, area, WHIRL_SLOT)
    wroteAt = area
end

modifiers.whirl_update = whirl_update

hook_event(HOOK_UPDATE, whirl_update)
end

do

local anchor = nil

local riders = {}

local function anchor_alive()
    return anchor ~= nil and anchor.activeFlags ~= 0
end

function modifiers.clear_carousel()
    for localIndex in pairs(riders) do
        local m = gMarioStates[localIndex]
        if m ~= nil and m.marioObj ~= nil then m.marioObj.platform = nil end
        riders[localIndex] = nil
    end
    if anchor_alive() then
        OF.util.optional("obj_mark_for_deletion", nil, anchor)
    end
    anchor = nil
    return true
end

function modifiers.carousel_note()
    if modifiers.level("carousel") <= 0 then return nil end
    local _, _, _, count = room_middle()
    if count ~= nil and count > 1 then return nil end
    return OF.lang.t("Alone in this area there is nothing to swing around but you.")
end

function modifiers.carousel_riders()
    local count = 0
    for _ in pairs(riders) do count = count + 1 end
    return count
end

function modifiers.carousel_anchor()
    if not anchor_alive() then return nil end
    return anchor
end

local function carousel_rate(count)
    local rate = modifiers.setting("carousel", "spin", nil)
    if rate == nil then return nil end

    if modifiers.setting("carousel", "perHead", false) == true then
        rate = rate * (count or 1)

        if rate > 144 then rate = 144 end
    end

    if modifiers.setting("carousel", "stillOnly", false) == true
        and modifiers.somebody_is_moving() then

        return 0
    end

    return rate
end

local function carousel_update()
    local rate = modifiers.setting("carousel", "spin", nil)
    if rate == nil then

        if anchor ~= nil or next(riders) ~= nil then modifiers.clear_carousel() end
        return
    end

    local x, y, z, count = room_middle()
    if x == nil then return end
    rate = carousel_rate(count)
    if rate == nil then return end

    if not anchor_alive() then

        for localIndex in pairs(riders) do
            local rider = gMarioStates[localIndex]
            if rider ~= nil and rider.marioObj ~= nil then
                rider.marioObj.platform = nil
            end
            riders[localIndex] = nil
        end
        anchor = OF.util.optional("spawn_non_sync_object", nil,
            id_bhvStaticObject, E_MODEL_NONE, x, y, z, nil)
        if not anchor_alive() then
            anchor = nil
            return
        end
    end

    anchor.oPosX, anchor.oPosY, anchor.oPosZ = x, y, z

    anchor.oVelX, anchor.oVelZ = 0, 0
    anchor.oAngleVelYaw = rate
    anchor.oAngleVelPitch, anchor.oAngleVelRoll = 0, 0

    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return end
    if OF.util.optional("is_player_active", 0, m) == 0 then return end

    if m.marioObj.platform ~= nil then return end

    m.marioObj.platform = anchor
    riders[0] = true
end

modifiers.carousel_update = carousel_update

hook_event(HOOK_UPDATE, carousel_update)
end
end

do

local BOMB_MARK = 0x4F460100

local BOMB_FALL = 1500

local BOMB_HEADROOM = 300

local BOMB_LEAST = 400

local BOMB_HIGHEST = 1600

local BOMB_REACH = 3200
local BOMB_RUNS = 3900

local BOMB_MOST = 36

local BOMB_EVERY = 2
local BOMB_AT_ONCE = 1

local BOMB_LIFE = 450

modifiers.bombRefused = 0

local bombWait = 0

function modifiers.bomb_marked(o)
    if o == nil then return false end
    local marked, mark = pcall(function() return o.oBehParams end)
    return marked == true and mark == BOMB_MARK
end

local function bomb_is_ours(o)
    if o == nil then return false end

    local ok, flags = pcall(function() return o.activeFlags end)
    if not ok or type(flags) ~= "number" or flags == 0 then return false end
    if OF.util.optional("obj_has_behavior_id", 1, o, id_bhvBobomb) ~= 1 then
        return false
    end
    if OF.util.optional("obj_has_model_extended", 1, o, E_MODEL_BLACK_BOBOMB) ~= 1 then
        return false
    end
    return modifiers.bomb_marked(o)
end

modifiers.bomb_is_ours = bomb_is_ours

local function bombs_standing()
    local found = {}
    if id_bhvBobomb == nil then return found end
    local o = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvBobomb)
    local guard = 0
    while o ~= nil and guard < 512 do
        guard = guard + 1
        if bomb_is_ours(o) then table.insert(found, o) end
        o = OF.util.optional("obj_get_next_with_same_behavior_id", nil, o)
    end
    return found
end

modifiers.bombs_standing = bombs_standing

function modifiers.bomb_count()
    return #bombs_standing()
end

function modifiers.clear_bombs()
    local gone = 0
    for _, o in ipairs(bombs_standing()) do
        OF.util.optional("obj_mark_for_deletion", nil, o)
        gone = gone + 1
    end
    bombWait = 0
    return gone
end

function modifiers.bomb_mine_to_drop()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return false end
    if type(np.globalIndex) ~= "number" then return false end
    local at = OF.util.area_authority()
    if at ~= nil then return at == 0 end
    for _, entry in ipairs(OF.util.connected_players()) do
        local other = entry.np
        if other ~= nil and other ~= np and modifiers.same_room(other, np)
            and other.currAreaSyncValid ~= false
            and type(other.globalIndex) == "number"
            and other.globalIndex < np.globalIndex then
            return false
        end
    end
    return true
end

function modifiers.same_room(a, b)
    return a.currLevelNum == b.currLevelNum and a.currAreaIndex == b.currAreaIndex
        and (a.currActNum or 0) == (b.currActNum or 0)
end

local function bomb_targets()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return {} end
    local out = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local other = entry.np
        if other ~= nil and modifiers.same_room(other, np) then
            local m = gMarioStates ~= nil and gMarioStates[entry.localIndex] or nil
            if m ~= nil and m.marioObj ~= nil and m.pos ~= nil
                and OF.util.optional("is_player_active", 0, m) ~= 0 then
                table.insert(out, { index = entry.localIndex,
                                    global = other.globalIndex or 0, m = m })
            end
        end
    end

    table.sort(out, function(a, b) return a.global < b.global end)
    return out
end

modifiers.bomb_targets = bomb_targets

function modifiers.bomb_drop(x, ground, z)
    if type(ground) ~= "number" then return nil end

    local bottom = -11000
    if gLevelValues ~= nil and type(gLevelValues.floorLowerLimit) == "number" then
        bottom = gLevelValues.floorLowerLimit
    end
    if ground <= bottom then return nil end

    local fall = BOMB_FALL
    if OF.util.asks(OF.warp, "land_height") then
        local carried = OF.warp.land_height(BOMB_FALL)
        if type(carried) == "number" then fall = carried end
    end

    if fall > BOMB_HIGHEST then fall = BOMB_HIGHEST end

    local roof = OF.util.optional("find_ceil_height", nil, x, ground + 20, z)
    if type(roof) == "number" then
        local room = roof - ground - BOMB_HEADROOM
        if room < fall then fall = room end
    end

    if fall < BOMB_LEAST then return nil end
    return fall
end

local function bomb_init(o)
    if o == nil then return end
    if not modifiers.bomb_marked(o) then return end

    local ground = o.oPosY
    local fall = modifiers.bomb_drop(o.oPosX, ground, o.oPosZ)
    if fall == nil then

        OF.util.optional("obj_mark_for_deletion", nil, o)
        return
    end

    o.oPosY = ground + fall

    o.oAction = BOBOMB_ACT_LAUNCHED
    o.oVelY = 0
    o.oForwardVel = 0
end

function modifiers.rain_spot(who, reach, tries)
    if who == nil or #who == 0 then return nil end
    local minX, maxX, minZ, maxZ = nil, nil, nil, nil
    for _, entry in ipairs(who) do
        local p = entry.m ~= nil and entry.m.pos or nil
        if p ~= nil then
            minX = math.min(minX or p.x, p.x - reach)
            maxX = math.max(maxX or p.x, p.x + reach)
            minZ = math.min(minZ or p.z, p.z - reach)
            maxZ = math.max(maxZ or p.z, p.z + reach)
        end
    end
    if minX == nil then return nil end
    for _ = 1, tries or 8 do
        local x = minX + (maxX - minX) * OF.util.random_int(0, 10000) / 10000
        local z = minZ + (maxZ - minZ) * OF.util.random_int(0, 10000) / 10000
        local best, bestD = nil, nil
        for _, entry in ipairs(who) do
            local p = entry.m ~= nil and entry.m.pos or nil
            if p ~= nil then
                local d = (x - p.x) * (x - p.x) + (z - p.z) * (z - p.z)
                if d <= reach * reach and (bestD == nil or d < bestD) then
                    best, bestD = entry.m, d
                end
            end
        end
        if best ~= nil then return x, z, best end
    end
    return nil
end

function modifiers.rain_floor(x, z, m)
    local y = m.pos.y
    local ground = OF.util.optional("find_floor_height", nil, x, y + 100, z)
    local bottom = -11000
    if gLevelValues ~= nil and type(gLevelValues.floorLowerLimit) == "number" then
        bottom = gLevelValues.floorLowerLimit
    end
    if type(ground) ~= "number" or ground <= bottom then
        ground = OF.util.optional("find_floor_height", nil, x, y + 1500, z)
    end
    if type(ground) ~= "number" or ground <= bottom then return nil end
    return ground
end

local function drop_on(who, own)

    if OF.util.asks(OF.roundscope, "shares_room_with_round")
        and OF.roundscope.shares_room_with_round() then return false end

    local x, z, m = modifiers.rain_spot(who, BOMB_REACH)
    if x == nil then return false end
    local ground = modifiers.rain_floor(x, z, m)
    if ground == nil then return false end

    local sea = OF.util.optional("find_water_level", nil, x, z)
    if type(sea) == "number" and sea > ground then return false end

    local fall = modifiers.bomb_drop(x, ground, z)
    if fall == nil then return false end

    for _, y in ipairs({ ground, ground + fall }) do
        local dx, dy, dz = x - m.pos.x, y - m.pos.y, z - m.pos.z
        if dx * dx + dy * dy + dz * dz > BOMB_RUNS * BOMB_RUNS then return false end
    end

    local made = OF.util.optional(own and "spawn_non_sync_object" or "spawn_sync_object", nil,
        id_bhvBobomb, E_MODEL_BLACK_BOBOMB, x, ground + fall, z,
        function(o)
            o.oBehParams = BOMB_MARK
            o.oAction = BOBOMB_ACT_LAUNCHED
            o.oVelY = 0
            o.oForwardVel = 0
        end)
    if made == nil then

        modifiers.bombRefused = modifiers.bombRefused + 1
        return false
    end
    return true
end

local function age_the_bombs()
    local taken = 0
    for _, o in ipairs(bombs_standing()) do
        local held = o.oHeldState
        local age = o.oTimer
        if (held == nil or held == 0) and type(age) == "number"
            and age > BOMB_LIFE then
            OF.util.optional("obj_mark_for_deletion", nil, o)
            taken = taken + 1
        end
    end
    return taken
end

modifiers.age_the_bombs = age_the_bombs

function modifiers.rain_held_here()
    if modifiers.select_holds() then return true end
    return modifiers.mine_state("snow") == false
end

function modifiers.room_setting(key, field, fallback)
    local entry = modifiers.BY_KEY[key]
    if entry == nil or entry.levels == nil then return fallback end
    local level = modifiers.room_level(key)
    local step = level > 0 and entry.levels[level] or nil
    if step == nil or step[field] == nil then return fallback end
    return step[field]
end

local bombsHidden = false
local function hide_bombs(list, hide)
    local invisible = GRAPH_RENDER_INVISIBLE or 16
    for _, o in ipairs(list) do
        local node = o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.node or nil
        if node ~= nil then
            local flags = tonumber(node.flags) or 0
            local now = (flags & invisible) ~= 0
            if hide and not now then node.flags = flags | invisible
            elseif not hide and now then node.flags = flags & ~invisible end
        end
    end
    bombsHidden = hide
end
modifiers.hide_bombs = hide_bombs

local function bomb_update()

    local seen = modifiers.setting("snow", "bombs", false)
    local roomRain = modifiers.room_setting("snow", "bombs", false) == true
    local held = not seen and modifiers.rain_held_here()
    if not seen and not (held and roomRain) then

        local standing = bombs_standing()
        if #standing > 0 then modifiers.clear_bombs() end
        return false
    end

    if held then hide_bombs(bombs_standing(), true)
    elseif bombsHidden then hide_bombs(bombs_standing(), false) end

    age_the_bombs()

    if bombWait > 0 then
        bombWait = bombWait - 1
        return false
    end

    local me = gMarioStates ~= nil and gMarioStates[0] or nil
    if me == nil or me.marioObj == nil then return false end

    local own = not roomRain
    local who
    if own then

        who = {}
        for _, target in ipairs(bomb_targets()) do
            if target.index == 0 then table.insert(who, target) end
        end
    else

        if not modifiers.bomb_mine_to_drop() then return false end
        who = bomb_targets()

        if held then
            for i = #who, 1, -1 do
                if who[i].index == 0 then table.remove(who, i) end
            end
        end
    end
    if #who == 0 then return false end

    bombWait = BOMB_EVERY

    local room = BOMB_MOST - modifiers.bomb_count()
    if room <= 0 then return false end

    local made = 0
    for _ = 1, math.min(BOMB_AT_ONCE, room) do

        if drop_on(who, own) then made = made + 1 end
    end
    return made > 0
end

modifiers.bomb_update = bomb_update
modifiers.bomb_init = bomb_init

function modifiers.bomb_note()
    local refused = modifiers.bombRefused or 0
    if refused > 0 then
        return OF.lang.fill("@ falling - @ the engine would not let us spawn.",
            modifiers.bomb_count(), refused)
    end
    return OF.lang.fill("@ Bob-omb(s) falling, the same ones for everybody.",
        modifiers.bomb_count())
end

hook_event(HOOK_UPDATE, bomb_update)

if id_bhvBobomb ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvBobomb, OBJ_LIST_DESTRUCTIVE, false, bomb_init, nil)
end
end

do

    local DROP_EVERY = 6
    local DROP_AT_ONCE = 3

    local COIN_MOST = 80
    local LIFE_MOST = 8

    local COIN_STAY = 180

    local DROP_REACH = 3500

    local DROP_FALL = 900

    local dropPouch = {}
    local dropWait = 0

    local function drop_point(who)
        local x, z, m = modifiers.rain_spot(who, DROP_REACH)
        if x == nil then return nil end
        local ground = modifiers.rain_floor(x, z, m)
        if ground == nil then return nil end
        local sea = OF.util.optional("find_water_level", nil, x, z)
        if type(sea) == "number" and sea > ground then return nil end

        local fall = DROP_FALL
        if OF.util.asks(OF.warp, "land_height") then
            local carried = OF.warp.land_height(DROP_FALL)
            if type(carried) == "number" then fall = carried end
        end

        local roof = OF.util.optional("find_ceil_height", nil, x, ground + 20, z)
        if type(roof) == "number" then
            local room = roof - ground - 300
            if room < fall then fall = room end
        end
        if fall < 200 then return nil end
        return x, ground + fall, z
    end

    function modifiers.drop_coin_count()
        return OF.util.coin_live(dropPouch)
    end

    function modifiers.drop_pouch()
        return dropPouch
    end

    function modifiers.drop_life_count()
        local live = 0
        if id_bhv1upWalking == nil then return 0 end
        local o = OF.util.optional("obj_get_first_with_behavior_id", nil,
            id_bhv1upWalking)
        local guard = 0
        while o ~= nil and guard < 512 do
            guard = guard + 1
            local ok, flags = pcall(function() return o.activeFlags end)
            if ok and type(flags) == "number" and flags ~= 0 then
                live = live + 1
            end
            o = OF.util.optional("obj_get_next_with_same_behavior_id", nil, o)
        end
        return live
    end

    function modifiers.clear_drops()
        OF.util.coin_sweep(dropPouch)
        OF.util.coin_live(dropPouch)
        dropWait = 0
        return true
    end

    local minePouch = {}

    function modifiers.drop_mine_count()
        return OF.util.coin_live(minePouch)
    end

    local function sweep_mine()
        for _, o in ipairs(minePouch) do
            if OF.util.alive(o) and o.activeFlags ~= 0 then
                OF.util.optional("obj_mark_for_deletion", nil, o)
            end
        end
        OF.util.coin_live(minePouch)
    end

    local function drop_mine(what, x, y, z)
        if OF.util.asks(OF.roundscope, "shares_room_with_round")
            and OF.roundscope.shares_room_with_round() then return false end
        local made
        if what == "coins" then
            if id_bhvSingleCoinGetsSpawned == nil then return false end
            made = OF.util.optional("spawn_non_sync_object", nil,
                id_bhvSingleCoinGetsSpawned, E_MODEL_YELLOW_COIN, x, y, z, nil)
        else
            if id_bhv1upWalking == nil then return false end
            made = OF.util.optional("spawn_non_sync_object", nil,
                id_bhv1upWalking, E_MODEL_1UP, x, y, z,
                function(o)
                    o.oAction = 1
                    o.oVelY = 0
                    o.oForwardVel = 0
                    o.oIntangibleTimer = 0
                end)
        end
        if made == nil then return false end
        table.insert(minePouch, made)
        return true
    end

    local function drop_life(x, y, z)
        if id_bhv1upWalking == nil then return false end

        if OF.util.asks(OF.roundscope, "shares_room_with_round")
            and OF.roundscope.shares_room_with_round() then return false end
        local made = OF.util.optional("spawn_sync_object", nil,
            id_bhv1upWalking, E_MODEL_1UP, x, y, z,
            function(o)
                o.oAction = 1
                o.oVelY = 0
                o.oForwardVel = 0

                o.oIntangibleTimer = 0
            end)
        return made ~= nil
    end

    function modifiers.drop_update()
        local what = modifiers.setting("snow", "drop", nil)

        if what ~= "coins" and what ~= "lives" then what = nil end

        local roomWhat = modifiers.room_setting("snow", "drop", nil)
        if roomWhat ~= "coins" and roomWhat ~= "lives" then roomWhat = nil end
        local own = what ~= nil and roomWhat == nil
        if not own and #minePouch > 0 then sweep_mine() end
        if own then
            if dropWait > 0 then
                dropWait = dropWait - 1
                return false
            end
            local me = gMarioStates ~= nil and gMarioStates[0] or nil
            if me == nil or me.marioObj == nil then return false end
            local who = {}
            for _, target in ipairs(modifiers.bomb_targets()) do
                if target.index == 0 then table.insert(who, target) end
            end
            if #who == 0 then return false end
            dropWait = DROP_EVERY
            for _, o in ipairs(minePouch) do
                if OF.util.alive(o) and o.activeFlags ~= 0
                    and type(o.oTimer) == "number" and o.oTimer > COIN_STAY then
                    OF.util.optional("obj_mark_for_deletion", nil, o)
                end
            end
            local most = what == "coins" and COIN_MOST or LIFE_MOST
            local room = most - OF.util.coin_live(minePouch)
            local fell = 0
            for _ = 1, math.min(DROP_AT_ONCE, math.max(room, 0)) do
                local x, y, z = drop_point(who)
                if x ~= nil and drop_mine(what, x, y, z) then fell = fell + 1 end
            end
            return fell > 0
        end
        local heldHere = what == nil and roomWhat ~= nil
        what = roomWhat or what
        if what == nil then

            if #dropPouch > 0 and not modifiers.rain_held_here() then modifiers.clear_drops() end
            return false
        end

        if dropWait > 0 then
            dropWait = dropWait - 1
            return false
        end

        local me = gMarioStates ~= nil and gMarioStates[0] or nil
        if me == nil or me.marioObj == nil then return false end
        if not modifiers.bomb_mine_to_drop() then return false end

        local who = modifiers.bomb_targets()

        if heldHere then
            for i = #who, 1, -1 do
                if who[i].index == 0 then table.remove(who, i) end
            end
        end
        if #who == 0 then return false end

        dropWait = DROP_EVERY

        local room
        if what == "coins" then

            for _, coin in ipairs(dropPouch) do
                if OF.util.alive(coin) and coin.activeFlags ~= 0
                    and type(coin.oTimer) == "number" and coin.oTimer > COIN_STAY then
                    OF.util.optional("obj_mark_for_deletion", nil, coin)
                end
            end
            room = COIN_MOST - OF.util.coin_live(dropPouch)
        else
            room = LIFE_MOST - modifiers.drop_life_count()
        end
        if room <= 0 then return false end

        local fell = 0
        for _ = 1, math.min(DROP_AT_ONCE, room) do

            do
                local x, y, z = drop_point(who)
                if x ~= nil then
                    local put
                    if what == "coins" then

                        put = OF.util.coin_put(dropPouch, x, y, z,
                            OF.util.COIN_KINDS[1])
                    else
                        put = drop_life(x, y, z)
                    end
                    if put then fell = fell + 1 end
                end
            end
        end
        return fell > 0
    end

    hook_event(HOOK_UPDATE, modifiers.drop_update)
end

do

local BLIND = { r = 8, g = 8, b = 10 }

local function blinder_stick()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil then return 0, 0, 0 end
    local c = m.controller
    if c == nil then return 0, 0, 0 end
    local x, y, mag = c.stickX, c.stickY, c.stickMag
    if type(x) ~= "number" or type(y) ~= "number" then return 0, 0, 0 end
    if type(mag) ~= "number" then mag = math.sqrt(x * x + y * y) end
    return OF.util.clamp(x / 64.0, -1, 1), OF.util.clamp(-y / 64.0, -1, 1),
        OF.util.clamp(mag / 64.0, 0, 1)
end

local OPEN_PER_TICK = 1.0 / 15.0

local BLINDER_REST = 8.0 / 64.0

local blinderOpen = 0.0

local blinderBox = { x = 0.1, y = 0.2, dx = 0.0045, dy = 0.0065 }
local blinderTick = 0

function modifiers.forget_blinders()
    blinderOpen = 0.0
    blinderBox.x, blinderBox.y, blinderBox.dx, blinderBox.dy = 0.1, 0.2, 0.0045, 0.0065
    blinderTick = 0
end

function modifiers.blinder_block(width, height)
    local share = modifiers.setting("blinders", "bounce", nil)
    if share == nil or width == nil or height == nil then return nil end
    local w = math.floor(width * share + 0.5)
    local h = math.floor(height * share + 0.5)
    return math.floor((width - w) * blinderBox.x), math.floor((height - h) * blinderBox.y), w, h
end

function modifiers.blinder_dark()
    local every = modifiers.setting("blinders", "every", nil)
    local dark = modifiers.setting("blinders", "dark", nil)
    if every == nil or dark == nil then return false end
    return (blinderTick % every) >= every - dark
end

function modifiers.blinder_open()
    return blinderOpen
end

function modifiers.blinders_frame()

    if modifiers.setting("blinders", "bounce", nil) ~= nil then
        blinderBox.x = blinderBox.x + blinderBox.dx
        blinderBox.y = blinderBox.y + blinderBox.dy
        if blinderBox.x <= 0 or blinderBox.x >= 1 then
            blinderBox.dx = -blinderBox.dx
            blinderBox.x = OF.util.clamp(blinderBox.x, 0, 1)
        end
        if blinderBox.y <= 0 or blinderBox.y >= 1 then
            blinderBox.dy = -blinderBox.dy
            blinderBox.y = OF.util.clamp(blinderBox.y, 0, 1)
        end
    end
    if modifiers.setting("blinders", "every", nil) ~= nil then
        blinderTick = blinderTick + 1
    else
        blinderTick = 0
    end
    local opens = modifiers.setting("blinders", "opens", nil)
    if opens == nil then
        blinderOpen = 0.0
        return
    end
    local _, _, mag = blinder_stick()
    local want = (mag <= BLINDER_REST) and 1.0 or 0.0
    if blinderOpen < want then
        blinderOpen = math.min(want, blinderOpen + OPEN_PER_TICK)
    elseif blinderOpen > want then
        blinderOpen = math.max(want, blinderOpen - OPEN_PER_TICK)
    end
end

function modifiers.blinder_gap(width, height)
    local across = modifiers.setting("blinders", "across", nil)
    local down = modifiers.setting("blinders", "down", nil)
    if across == nil or down == nil then return nil end
    if width == nil or height == nil or width <= 0 or height <= 0 then return nil end

    local opens = modifiers.setting("blinders", "opens", nil)
    if opens ~= nil then
        across = across + (OF.util.clamp(opens, 0, 1) - across) * blinderOpen
        down = down + (OF.util.clamp(opens, 0, 1) - down) * blinderOpen
    end

    local gapW = math.floor(width * OF.util.clamp(across, 0, 1) + 0.5)
    local gapH = math.floor(height * OF.util.clamp(down, 0, 1) + 0.5)
    local x = math.floor((width - gapW) / 2)
    local y = math.floor((height - gapH) / 2)

    local follows = modifiers.setting("blinders", "follows", nil)
    if follows ~= nil then
        local sx, sy = blinder_stick()
        local reachX = math.floor((width - gapW) / 2 * OF.util.clamp(follows, 0, 1))
        local reachY = math.floor((height - gapH) / 2 * OF.util.clamp(follows, 0, 1))
        x = OF.util.clamp(x + math.floor(sx * reachX + 0.5), 0, width - gapW)
        y = OF.util.clamp(y + math.floor(sy * reachY + 0.5), 0, height - gapH)
    end

    return x, y, gapW, gapH
end

local function render_blinders()

    if OF.util.menu_has_screen() then return end

    local width = djui_hud_get_screen_width()
    local height = djui_hud_get_screen_height()

    local bx, by, bw, bh = modifiers.blinder_block(width, height)
    if bx ~= nil then
        djui_hud_set_resolution(RESOLUTION_DJUI)
        OF.util.rect(bx, by, bw, bh, BLIND.r, BLIND.g, BLIND.b, 255)
        return
    end
    if modifiers.blinder_dark() then
        djui_hud_set_resolution(RESOLUTION_DJUI)
        OF.util.rect(0, 0, width, height, BLIND.r, BLIND.g, BLIND.b, 255)
        return
    end

    local x, y, gapW, gapH = modifiers.blinder_gap(width, height)
    if x == nil then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)

    if y > 0 then
        OF.util.rect(0, 0, width, y, BLIND.r, BLIND.g, BLIND.b, 255)
    end
    if y + gapH < height then
        OF.util.rect(0, y + gapH, width, height - (y + gapH),
            BLIND.r, BLIND.g, BLIND.b, 255)
    end
    if x > 0 then
        OF.util.rect(0, y, x, gapH, BLIND.r, BLIND.g, BLIND.b, 255)
    end
    if x + gapW < width then
        OF.util.rect(x + gapW, y, width - (x + gapW), gapH,
            BLIND.r, BLIND.g, BLIND.b, 255)
    end
end

modifiers.render_blinders = render_blinders

hook_event(HOOK_ON_HUD_RENDER, render_blinders)

hook_event(HOOK_UPDATE, function() modifiers.blinders_frame() end)
end

do

local MOST_HURT = 255

local stingDice = 24680

local stungFrom = {}

function modifiers.forget_stings()
    for key in pairs(stungFrom) do stungFrom[key] = nil end
    return true
end

function modifiers.sting_worth(added)
    if added == nil or added <= 0 then return added end

    local wedges = modifiers.setting("sting", "wedges", nil)
    if wedges ~= nil then return math.floor(OF.util.clamp(wedges * 4, 0, MOST_HURT)) end

    if modifiers.setting("sting", "lottery", false) == true then
        stingDice = (1103515245 * stingDice + 12345) % 2147483648
        local drawn = (math.floor(stingDice / 65536) % 8) + 1
        return math.floor(OF.util.clamp(drawn * 4, 0, MOST_HURT))
    end

    local factor = modifiers.setting("sting", "factor", nil)
    if factor == nil then return added end

    return math.floor(OF.util.clamp(added * factor + 0.5, 1, MOST_HURT))
end

local function sting_remember(m)
    if m == nil or m.playerIndex ~= 0 then return end
    stungFrom[m.playerIndex] = m.hurtCounter or 0
end

function modifiers.sting_the_hit(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modifiers.level("sting") <= 0 then return false end

    local from = stungFrom[m.playerIndex]
    if from == nil then return false end

    local now = m.hurtCounter or 0
    local added = now - from
    if added <= 0 then return false end

    local worth = modifiers.sting_worth(added)
    if worth == added then return false end

    m.hurtCounter = math.floor(OF.util.clamp(from + worth, 0, MOST_HURT))

    stungFrom[m.playerIndex] = m.hurtCounter
    return true
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, sting_remember, OF.LOCAL_MARIO)

hook_event(HOOK_ON_INTERACT, function(m, o, interactType)
    modifiers.sting_the_hit(m)
    modifiers.tally_coin(m, o, interactType)

    modifiers.coin_hit_tally(m, o, interactType)
end)
end

local PRESS_HUD_Y = 78

function modifiers.press_hud()
    if modifiers.level("budget") <= 0 then return nil end
    local spent = modifiers.presses(0)
    local budget = modifiers.press_budget()

    if budget == nil then
        return tostring(spent), nil, 255, 255, 255
    end

    local left = budget - spent
    local r, g, b = 255, 255, 255
    if left <= 0 then
        r, g, b = 255, 110, 110
    elseif left <= 2 then
        r, g, b = 255, 200, 90
    end
    return tostring(spent), OF.lang.fill("of @", tostring(budget)), r, g, b
end

local function render_presses()
    local count, ofWhat, r, g, b = modifiers.press_hud()
    if count == nil then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)

    djui_hud_set_font(FONT_HUD)
    local scale = 1.15
    local width = djui_hud_measure_text(count) * scale
    local x = (djui_hud_get_screen_width() - width) / 2
    local y = djui_hud_get_screen_height() - PRESS_HUD_Y

    djui_hud_set_color(0, 0, 0, 160)
    djui_hud_print_text(count, x + 2, y + 2, scale)
    djui_hud_set_color(r, g, b, 255)
    djui_hud_print_text(count, x, y, scale)

    djui_hud_set_font(FONT_NORMAL)

    if ofWhat ~= nil then
        OF.util.text(ofWhat, x + width + 6, y + 6, 0.5, r, g, b, 200)
    end
end

modifiers.COIN_HIT_FROM = 310
modifiers.COIN_HIT_KICK = 20
modifiers.COIN_HIT_BLINK = 60
modifiers.COIN_HIT_STANDING = 32
modifiers.COIN_HIT_RING = 40
modifiers.COIN_HIT_LINE = 100

do
    local COIN_HIT_KEY_NAME = "coinhit"
    local coinHitHeld = nil
    local coinHitWasHurt, coinHitWasHealth = nil, nil

    local coinHitImmune = 0
    local coinHitPouch = {}
    local coinHitLevel = nil

    local coinHitSpilled = 0
    local coinHitSeen = {}

    function modifiers.coin_hit_pieces(players)
        return OF.util.clamp(math.floor(96 / math.max(players or 1, 1)), 6, 16)
    end

    function modifiers.coin_hit_split(lose, pieces)
        local out = {}
        lose = math.floor(lose or 0)
        pieces = math.min(math.floor(pieces or 0), lose)
        if pieces <= 0 then return out end
        local each = math.floor(lose / pieces)
        local over = lose - each * pieces
        local most = OF.util.COIN_WORTH_MAX or 50
        for k = 1, pieces do
            local worth = each + (k <= over and 1 or 0)
            if worth > most then worth = most end
            out[k] = worth
        end
        return out
    end

    function modifiers.coin_hit_floor(purse, lose)
        purse = math.floor(purse or 0)
        lose = math.floor(lose or 0)
        local line = modifiers.COIN_HIT_LINE
        if gLevelValues ~= nil and type(gLevelValues.coinsRequiredForCoinStar) == "number" then
            line = gLevelValues.coinsRequiredForCoinStar
        end
        if purse >= line then return math.max(0, math.min(lose, purse - line)) end
        return math.max(0, math.min(lose, purse))
    end

    function modifiers.coin_hit_held() return coinHitHeld end
    function modifiers.coin_hit_live() return OF.util.coin_live(coinHitPouch) end

    local function coin_model(worth)
        if worth >= 5 then return E_MODEL_BLUE_COIN end
        if worth >= 2 then return E_MODEL_RED_COIN end
        return E_MODEL_YELLOW_COIN
    end

    local function players_here()
        local me = gNetworkPlayers[0]
        local n = 0
        for _, entry in ipairs(OF.util.connected_players()) do
            local np = gNetworkPlayers[entry.localIndex]
            if np ~= nil and me ~= nil and np.currLevelNum == me.currLevelNum then
                n = n + 1
            end
        end
        return math.max(n, 1)
    end

    function modifiers.coin_hit_spill(m, lose)
        if m == nil or m.pos == nil or lose <= 0 then return 0 end
        local room = modifiers.COIN_HIT_STANDING - OF.util.coin_live(coinHitPouch)
        local pieces = math.min(modifiers.coin_hit_pieces(players_here()), math.max(room, 0))
        local worths = modifiers.coin_hit_split(lose, pieces)
        local put = 0
        local claim = OF.util.claim_worth
        for k, worth in ipairs(worths) do
            local angle = (k / #worths) * 6.28318
            local kind = { model = coin_model(worth), worth = worth }
            local coin = OF.slots.spawn_sync(id_bhvSingleCoinGetsSpawned, kind.model,
                m.pos.x + math.cos(angle) * modifiers.COIN_HIT_RING,
                m.pos.y + 60,
                m.pos.z + math.sin(angle) * modifiers.COIN_HIT_RING,
                function(o)
                    if claim ~= nil then claim(o, kind) end
                    o.oCoinUnk110 = modifiers.COIN_HIT_KICK
                    o.oTimer = modifiers.COIN_HIT_FROM
                end)
            if coin ~= nil then
                table.insert(coinHitPouch, coin)
                put = put + 1
            end
        end
        if put > 0 and SOUND_GENERAL_COIN_SPURT_2 ~= nil and m.marioObj ~= nil then
            OF.util.optional("play_sound", nil, SOUND_GENERAL_COIN_SPURT_2,
                m.marioObj.header.gfx.cameraToObject)
        end
        return put
    end

    local coinHitPaidAt = nil

    local function coins_took_it(m)
        m.hurtCounter = 0
        coinHitWasHurt = 0
        if coinHitWasHealth ~= nil and (m.health or 0) < coinHitWasHealth then
            m.health = coinHitWasHealth
        end
    end

    function modifiers.coin_hit_take(m, hurt)
        if coinHitHeld == nil then return 0 end
        local now = OF.util.optional("get_global_timer", 0) or 0
        if coinHitImmune > 0 then

            if hurt and coinHitPaidAt == now
                and modifiers.setting("coinhit", "shield", false) == true then
                coins_took_it(m)
            end
            return 0
        end
        local coins = math.floor(coinHitHeld)
        if coins <= 0 then

            if hurt and modifiers.setting("coinhit", "life", false) == true then
                m.hurtCounter = 31
                coinHitWasHurt = 31
                return 0
            end
            return 0
        end
        coinHitHeld = 0
        coinHitPaidAt = now
        coinHitImmune = modifiers.COIN_HIT_BLINK
        m.invincTimer = math.max(m.invincTimer or 0, modifiers.COIN_HIT_BLINK)
        modifiers.coin_hit_spill(m, coins)

        local purse = modifiers.coin_hit_floor(m.numCoins, coins)
        if purse > 0 then
            m.numCoins = m.numCoins - purse
            coinHitSpilled = coinHitSpilled + purse
            OF.util.publish_row(0, "ofCoinSpill", coinHitSpilled)
        end
        if hurt and modifiers.setting("coinhit", "shield", false) == true then
            coins_took_it(m)
        end
        return coins
    end

    function modifiers.coin_hit_purse(m)
        local me = gNetworkPlayers[0]
        for i = 1, (MAX_PLAYERS or 16) - 1 do
            local np = gNetworkPlayers[i]
            local row = gPlayerSyncTable[i]
            if np ~= nil and np.connected and row ~= nil then
                local total = math.floor(tonumber(row.ofCoinSpill) or 0)
                local key = np.globalIndex
                local seen = coinHitSeen[key]
                if seen == nil or total < seen then
                    coinHitSeen[key] = total
                elseif total > seen then
                    coinHitSeen[key] = total
                    if me ~= nil and np.currLevelNum == me.currLevelNum then
                        m.numCoins = m.numCoins
                            - modifiers.coin_hit_floor(m.numCoins, total - seen)
                    end
                end
            elseif np ~= nil and not np.connected then
                coinHitSeen[np.globalIndex] = nil
            end
        end
    end

    function modifiers.forget_coin_hit()
        coinHitHeld = nil
        coinHitWasHurt, coinHitWasHealth = nil, nil
        coinHitImmune = 0
        OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, "coinhit", false)
        return true
    end

    function modifiers.watch_coin_hit(m)
        if m == nil or m.playerIndex ~= 0 then return end
        modifiers.coin_hit_purse(m)
        if modifiers.level(COIN_HIT_KEY_NAME) <= 0 then
            if coinHitHeld ~= nil then modifiers.forget_coin_hit() end
            return
        end
        local np = gNetworkPlayers[0]
        local here = np ~= nil and (tostring(np.currLevelNum) .. ":"
            .. tostring(np.currActNum)) or ""
        if coinHitHeld == nil or here ~= coinHitLevel then
            coinHitHeld = 0
            coinHitLevel = here
        end
        if coinHitImmune > 0 then coinHitImmune = coinHitImmune - 1 end
        local hurt = tonumber(m.hurtCounter) or 0
        local wasHurt = coinHitWasHurt
        coinHitWasHurt = hurt
        if wasHurt ~= nil and hurt > wasHurt then modifiers.coin_hit_take(m, true) end
        coinHitWasHealth = tonumber(m.health) or 0
    end

    function modifiers.coin_hit_tally(m, o, interactType)
        if m == nil or m.playerIndex ~= 0 or o == nil then return false end
        if interactType ~= INTERACT_COIN or coinHitHeld == nil then return false end
        coinHitHeld = coinHitHeld + OF.util.coin_worth(o)
        return true
    end

    function modifiers.coin_hit_knocked(attacker, victim)
        if victim == nil or victim.playerIndex ~= 0 or coinHitHeld == nil then return false end
        return modifiers.coin_hit_take(victim, false) > 0
    end

    function modifiers.coin_hit_hud()
        if coinHitHeld == nil then return nil end
        if coinHitHeld <= 0 and modifiers.setting("coinhit", "life", false) == true then
            return tostring(coinHitHeld), 255, 110, 110
        end
        return tostring(coinHitHeld), 255, 235, 130
    end

    function modifiers.coin_hit_note()
        if modifiers.level(COIN_HIT_KEY_NAME) <= 0 then return nil end
        return OF.lang.t("Your own count, from nothing in every level.")
    end

    function modifiers.render_coin_hit()
        local count, r, g, b = modifiers.coin_hit_hud()
        OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, "coinhit", count ~= nil)
        if count == nil or OF.util.menu_has_screen() then return end
        local beside = 0
        if OF.util.asks(OF.speedrun, "tally_width") then
            beside = beside + OF.speedrun.tally_width()
        end
        if OF.util.asks(OF.split, "tally_width") then
            beside = beside + OF.split.tally_width()
        end
        djui_hud_set_resolution(RESOLUTION_DJUI)
        local icon = gTextures ~= nil and gTextures.coin or nil
        OF.util.corner_counter(icon, count, r, g, b, beside, 1.0)
    end
end

hook_event(HOOK_MARIO_UPDATE, function(m) modifiers.watch_coin_hit(m) end)
hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim)
    modifiers.coin_hit_knocked(attacker, victim)
end)

hook_event(HOOK_ON_HUD_RENDER, function()
    render_presses()
    modifiers.render_coin_hit()
end)

local VISION_SLOT = "vis_"
modifiers.VISION_SLOTS = 16

local NAME_SEP = "|"
local function slot_read(slot)
    local stored = mod_storage_load(VISION_SLOT .. slot, "")
    if stored == nil or stored == "" then return nil end
    local at = string.find(stored, NAME_SEP, 1, true)
    if at == nil then return nil end
    local name = string.sub(stored, 1, at - 1)
    local packed = string.sub(stored, at + 1)
    if name == "" or packed == "" then return nil end
    return { slot = slot, name = name, packed = packed }
end

function modifiers.saved_visions()
    local list = {}
    for slot = 1, modifiers.VISION_SLOTS do
        local kept = slot_read(slot)
        if kept ~= nil then table.insert(list, kept) end
    end
    return list
end

function modifiers.forget_vision(slot)
    mod_storage_remove(VISION_SLOT .. slot)
    return true
end

function modifiers.keep_vision(name)
    name = string.gsub(tostring(name or ""), "%" .. NAME_SEP, "/")
    name = string.match(name, "^%s*(.-)%s*$")
    if name == "" then

        name = OF.lang.fill("Vision @", #modifiers.saved_visions() + 1)
    end

    local free = nil
    for slot = 1, modifiers.VISION_SLOTS do
        local kept = slot_read(slot)
        if kept ~= nil and kept.name == name then
            free = slot
            break
        end
        if kept == nil and free == nil then free = slot end
    end
    if free == nil then
        return false, "All " .. modifiers.VISION_SLOTS .. " vision slots are full."
    end

    local dials, dither = modifiers.vision_in_force(true)

    local ok = OF.util.store(VISION_SLOT .. free,
        name .. NAME_SEP .. modifiers.vision_pack(dials, dither))
    if not ok then return false, "That did not fit in the save file." end
    return true, name
end

function modifiers.wear_saved(name)
    local needle = string.lower(tostring(name or ""))
    for _, kept in ipairs(modifiers.saved_visions()) do
        if string.lower(kept.name) == needle then
            local dials, dither = modifiers.vision_parse(kept.packed)
            if OF.perms.can("vision") then
                return modifiers.publish_vision(dials, dither)
            end
            return keep_mine(dials, dither)
        end
    end
    return false, "No vision of that name is saved."
end

local VISION_LOBBY_NEED = "vision"
local VISION_MINE_NEED = "costume_self"
local function first_notch(dial)
    local up = dial.rest + dial.step
    if up <= dial.to + 0.0001 then return up end
    return dial.rest - dial.step
end

function modifiers.build_visuals_page(panel)
    local rows = {}

    local roomDials, roomStipple = modifiers.vision()

    local livedDials, livedStipple = modifiers.vision_in_force()

    local seen = modifiers.look_from(modifiers.vision_in_force(true))
    local roomLook = modifiers.vision_look()
    if seen == nil then
        table.insert(rows, panel.label_row(
            OF.lang.t("Nothing turned - you see it as the game drew it.")))
    elseif modifiers.vision_mine_any() then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "@ dial(s) away from rest on your screen, and the lobby has @.",
            #seen, roomLook == nil and 0 or #roomLook)))
    else
        table.insert(rows, panel.label_row(OF.lang.fill(
            "@ dial(s) away from rest, and everybody sees them.", #seen)))
    end

    if modifiers.round_holds() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has the picture - every dial comes back after it.")))
    end

    table.insert(rows, panel.with_help(panel.two_box({
        boxes = false,
        name = OF.lang.t("Reset this page"),
        lobbyNeed = VISION_LOBBY_NEED,
        mineNeed = VISION_MINE_NEED,
        r = 255, g = 200, b = 120,
        onLobby = function() OF.util.report(modifiers.clear_vision()) end,
        onMine = function()
            OF.util.report(modifiers.clear_vision_mine())
            panel.mark_dirty()
        end,
    }), OF.lang.t("A puts the lobby's dials back, Z puts your screen back")))

    if #modifiers.grouped("visuals") > 0 then
        table.insert(rows, panel.label_row(OF.lang.t(
            "What the lobby wears this session - the right-hand box keeps you "
                .. "out of it, and the host or a round takes them off.")))
    end

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("The dials")),
        "the picture itself, turned one property at a time"))
    for index, dial in ipairs(modifiers.VISION_DIALS) do
        local steps = math.floor((dial.to - dial.from) / dial.step + 0.5)
        local roomValue = roomDials[index] or dial.rest
        local roomTurned = math.abs(roomValue - dial.rest) > 0.001
        local mineSays = modifiers.vision_mine_state(index)
        local mineValue = modifiers.vision_mine_value(index)

        local lived = livedDials[index] or dial.rest
        local livedOn = math.abs(lived - dial.rest) > 0.001

        local r, g, b = 255, 255, 255
        if livedOn then
            r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
        end

        local built = panel.with_help(panel.two_box({
            lobbyOn = roomTurned,

            mineBox = panel.mine_shown(mineSays, roomTurned),
            name = OF.lang.t(dial.name),
            lobbyNeed = VISION_LOBBY_NEED,
            mineNeed = VISION_MINE_NEED,
            r = r, g = g, b = b,

            onLobby = function()
                OF.util.report(modifiers.set_dial(index,
                    roomTurned and dial.rest or first_notch(dial)))
            end,

            onMine = function()
                local want = panel.next_mine(mineSays, roomTurned)
                local value = nil
                if want == false then value = dial.rest
                elseif want == true then value = first_notch(dial) end
                OF.util.report(modifiers.set_dial_mine(index, value))
                panel.mark_dirty()
            end,
        }), OF.lang.t(dial.blurb))

        local roomSaid = roomTurned and string.format("%.2f", roomValue) or nil
        local mineSaid = nil
        if mineSays == false then mineSaid = OF.lang.t("normal")
        elseif mineSays ~= nil and mineValue ~= nil then
            mineSaid = string.format("%.2f", mineValue)
        end
        local column, youPart = panel.two_box_column(roomSaid, mineSaid, mineSays ~= nil)
        built = panel.level_right(built, livedOn or column ~= nil, column)
        built.rightMine = youPart

        local function notch(value)
            return math.floor((value - dial.from) / dial.step + 0.5)
        end
        local mineAt = nil
        if mineSays == false then mineAt = notch(dial.rest)
        elseif mineSays ~= nil and mineValue ~= nil then mineAt = notch(mineValue) end
        built = panel.two_slider(built, {
            steps = steps, room = notch(roomValue), mine = mineAt,
            mayRoom = panel.may(VISION_LOBBY_NEED), mayMine = panel.may(VISION_MINE_NEED),
            setRoom = function(wanted)
                OF.util.report(modifiers.set_dial(index, dial.from + wanted * dial.step))
            end,
            setMine = function(wanted)
                OF.util.report(modifiers.set_dial_mine(index, dial.from + wanted * dial.step))
            end,
            clearMine = function()
                OF.util.report(modifiers.set_dial_mine(index, nil))
                panel.mark_dirty()
            end,
        })

        table.insert(rows, built)
    end

    local stippleMine = modifiers.vision_mine_state("dither")
    local stippleR, stippleG, stippleB = 255, 255, 255
    if livedStipple then
        stippleR, stippleG, stippleB =
            OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
    end
    table.insert(rows, panel.with_help(panel.two_box({
        lobbyOn = roomStipple,
        mineBox = panel.mine_shown(stippleMine, roomStipple),
        name = OF.lang.t("Dithering"),
        lobbyNeed = VISION_LOBBY_NEED,
        mineNeed = VISION_MINE_NEED,
        r = stippleR, g = stippleG, b = stippleB,
        onLobby = function()
            OF.util.report(modifiers.set_dither(not roomStipple))
        end,
        onMine = function()
            OF.util.report(modifiers.set_dither_mine(
                panel.next_mine(stippleMine, roomStipple)))
            panel.mark_dirty()
        end,
    }), OF.lang.t("stipples the picture instead of shading it")))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("Start from one of these")),
        "a whole look in one press, and the dials above are still yours "
        .. "afterwards"))
    for _, step in ipairs(modifiers.LOOKS) do
        local name = step.name

        table.insert(rows, panel.with_help(
            panel.two_box({
                boxes = false,
                name = OF.lang.t(name),
                lobbyNeed = VISION_LOBBY_NEED,
                mineNeed = VISION_MINE_NEED,
                r = 200, g = 230, b = 255,
                onLobby = function()
                    OF.util.report(modifiers.load_preset(name))
                end,
                onMine = function()
                    OF.util.report(modifiers.load_preset_mine(name))
                    panel.mark_dirty()
                end,
            }),
            OF.lang.t(step.blurb)))
    end

    local kept = modifiers.saved_visions()
    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.fill("Kept by you (@)", #kept)),
        "looks you have saved on this machine, and nobody else has them"))

    table.insert(rows, panel.with_help(panel.gated_row(VISION_MINE_NEED,
        OF.lang.t("+ Keep this one"), 120, 255, 120, function()
            local ok, what = modifiers.keep_vision(nil)
            if ok then

                OF.notify.show("Kept @", "good", 4, tostring(what))
            else
                OF.util.report(ok, what)
            end
        end),

        OF.lang.t("keeps the picture on your screen, on this machine only")))

    for _, entry in ipairs(kept) do
        local slot, name = entry.slot, entry.name

        local built = panel.gated_row(VISION_MINE_NEED, name,
            200, 230, 255, function()
                OF.util.report(modifiers.wear_saved(name))
            end)
        if built ~= nil and built.action ~= nil then
            built.altAction = function()

                if OF.util.report(modifiers.forget_vision(slot)) then
                    OF.notify.show("Forgot @", "info", 4, name)
                end
            end
        end
        table.insert(rows, panel.with_help(built,
            panel.may(VISION_LOBBY_NEED)
                and OF.lang.t("press to wear it on the lobby's dials, the left "
                    .. "strip to forget it")
                or OF.lang.t("press to wear it on your screen, the left strip "
                    .. "to forget it")))
    end

    for _, r in ipairs(modifiers.build_rows(panel, "visuals")) do
        table.insert(rows, r)
    end

    table.insert(rows, panel.back_row("fun"))

    return rows
end

function modifiers.change_line(key, level)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return nil end
    local name = OF.lang.t(entry.name)
    level = math.floor(tonumber(level) or 0)
    if level <= 0 then return OF.lang.fill("@ off", name) end
    local step = modifiers.step_name(key, modifiers.pack({ [key] = level }))
    if step == nil then return OF.lang.fill("@ on", name) end
    return OF.lang.fill("@: @", name, OF.lang.t(step))
end

function modifiers.changed_line(before, after)
    local was, now = modifiers.parse(before), modifiers.parse(after)
    local moved, only = 0, nil
    local keys = {}
    for key in pairs(was) do keys[key] = true end
    for key in pairs(now) do keys[key] = true end
    for key in pairs(keys) do
        if (was[key] or 0) ~= (now[key] or 0) then
            moved = moved + 1
            only = key
        end
    end
    if moved == 0 then return nil end
    if moved == 1 then return modifiers.change_line(only, now[only] or 0) end
    return OF.lang.fill("@ modifiers changed", tostring(moved))
end

function modifiers.stop_name_at(key, level)
    local entry = modifiers.BY_KEY[key]
    if entry == nil then return nil end
    if type(level) ~= "number" or level <= 0 then return nil end
    local step = (entry.levels or {})[level]
    return step ~= nil and step.name or nil
end

function modifiers.slider_holes(entry)
    local holes = nil
    for index, step in ipairs(entry ~= nil and entry.levels or {}) do
        if step.retired ~= nil or step.name == nil then
            holes = holes or {}
            holes[index] = true
        end
    end
    return holes
end

function modifiers.two_box_row(panel, entry)
    local key = entry.key
    local steps = modifiers.step_count(entry)
    local holes = modifiers.slider_holes(entry)
    local roomLevel = modifiers.active()[key] or 0
    local room = roomLevel > 0
    local level, yours = modifiers.in_force(key)
    local on = level > 0

    local r, g, b = 255, 255, 255
    if on then
        r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
    end

    local title = OF.lang.t(entry.name)

    local function step_after(from)
        if steps <= 1 then return from > 0 and 0 or 1 end
        local next = from + 1
        if next > steps then next = 0 end
        return next
    end

    if not modifiers.can_be_mine(key) then
        local built = panel.with_help(
            panel.gated_row(modifiers.ROW_RANK, panel.tick(room, title),
                r, g, b, function() modifiers.toggle(key) end),
            OF.lang.t(modifiers.LOBBY_ONLY[key]))
        local stop = room and modifiers.stop_name_at(key, roomLevel) or nil
        if stop ~= nil then stop = OF.util.say_buttons(OF.lang.t(stop), true) end
        built = panel.level_right(built, room, stop)
        if steps > 1 then
            built = panel.with_slider(built, roomLevel, steps, function(wanted)
                OF.util.report(modifiers.set_level(key, wanted))
            end, holes)
        end
        built.catalogue = "modifier"
        return built
    end

    local mine = modifiers.mine_state(key)

    local help = OF.util.say_buttons(entry.blurb ~= nil and OF.lang.t(entry.blurb) or nil, true)
    if modifiers.suspended(key) then
        help = OF.lang.t("put away until the round ends - your setting is kept")
    end

    local built = panel.with_help(panel.two_box({
        lobbyOn = room,

        mineBox = panel.mine_shown(mine, room),
        name = title,
        lobbyNeed = modifiers.ROW_RANK,
        mineNeed = "modifier_self",
        r = r, g = g, b = b,
        onLobby = function()
            OF.util.report(modifiers.set_level(key, step_after(roomLevel)))
        end,

        onMine = function()
            local want = panel.next_mine_level(mine,
                modifiers.mine_level(key), steps, roomLevel)
            if want == nil then
                OF.util.report(modifiers.set_mine(key, nil))
                return
            end
            OF.util.report(modifiers.set_mine_level(key, want))
        end,
    }), help)

    local stop = nil
    if steps > 1 and on then
        stop = modifiers.stop_name_at(key, level)
        if stop ~= nil then stop = OF.util.say_buttons(OF.lang.t(stop), true) end
    end
    local column = panel.two_box_level(stop, yours)
    if mine == false then

        column = panel.two_box_level(OF.lang.t("off"), true)
    end

    local youPart = nil
    if steps > 1 then
        local roomStop = room and modifiers.stop_name_at(key, roomLevel) or nil
        if roomStop ~= nil then roomStop = OF.util.say_buttons(OF.lang.t(roomStop), true) end
        local mineStop = nil
        if mine == false then mineStop = OF.lang.t("off")
        elseif mine == true then
            mineStop = modifiers.stop_name_at(key, modifiers.mine_level(key))
            if mineStop ~= nil then mineStop = OF.util.say_buttons(OF.lang.t(mineStop), true) end
        end
        column, youPart = panel.two_box_column(roomStop, mineStop, mine ~= nil)
    end
    built = panel.level_right(built, on or column ~= nil, column)
    built.rightMine = youPart

    if steps > 1 then

        local mineAt = nil
        if mine == false then mineAt = 0
        elseif mine == true then mineAt = modifiers.mine_level(key) end
        local function name_at(stopAt)
            if stopAt == nil then return OF.lang.t("follow lobby") end
            if stopAt <= 0 then return OF.lang.t("off") end
            local said = modifiers.stop_name_at(key, stopAt)
            return said ~= nil and OF.util.say_buttons(OF.lang.t(said), true) or tostring(stopAt)
        end
        built = panel.two_slider(built, {
            steps = steps, room = roomLevel, mine = mineAt, holes = holes,
            mayRoom = panel.may(modifiers.ROW_RANK), mayMine = panel.may("modifier_self"),
            setRoom = function(wanted) OF.util.report(modifiers.set_level(key, wanted)) end,

            setMine = function(wanted) OF.util.report(modifiers.set_mine_level(key, wanted)) end,
            clearMine = function() OF.util.report(modifiers.set_mine(key, nil)) end,
            roomNext = name_at(step_after(roomLevel)),
            mineNext = name_at(panel.next_mine_level(mine,
                modifiers.mine_level(key), steps, roomLevel)),
        })
    end

    built.catalogue = "modifier"
    return built
end

function modifiers.demon_row(panel)
    local entry = modifiers.BY_KEY["demon"]
    if entry == nil then return nil end
    return modifiers.two_box_row(panel, entry)
end

function modifiers.build_demon_page(panel)
    local rows = {}
    table.insert(rows, panel.label_row(OF.lang.t(
        "A 1-UP comes after everybody in the lobby, and it does not stop.")))
    local switch = modifiers.demon_row(panel)
    if switch ~= nil then table.insert(rows, switch) end
    table.insert(rows, panel.with_help(panel.gated_confirm_row(modifiers.ROW_RANK,
        "demonreset", OF.lang.t("Reset this page"), 200, 200, 200,
        function() OF.util.report(modifiers.reset_demon_opts()) end),
        OF.lang.t("every row of how it hunts, back to its first stop")))
    if modifiers.round_holds() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has these - the settings come back after it.")))
    end
    table.insert(rows, panel.with_help(panel.header_row(OF.lang.t("How it hunts")),
        OF.lang.t("where it goes, what a catch costs and how it arrives")))
    for _, row in ipairs(modifiers.DEMON_OPTS) do
        local key = row.key
        local step = modifiers.demon_opt(key)
        local built = panel.gated_row(modifiers.ROW_RANK, OF.lang.t(row.name),
            255, 255, 255, function()
                OF.util.report(modifiers.set_demon_opt(key, step % #row.steps + 1))
            end)
        built = panel.with_right(built, OF.lang.t(row.steps[step]))
        if panel.may(modifiers.ROW_RANK) then
            built = panel.with_slider(built, step - 1, #row.steps - 1, function(wanted)
                OF.util.report(modifiers.set_demon_opt(key, wanted + 1))
            end)
        else
            built = panel.with_slider(built, step - 1, #row.steps - 1, nil)
        end
        table.insert(rows, panel.with_help(built, OF.lang.t(row.help)))
    end
    table.insert(rows, panel.back_row())
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_action") then
        OF.net.register_action(modifiers.DEMON_OPTS_ACTION, modifiers.ROW_RANK,
            function(fromLocal, x, _, z)
                if not OF.util.is_host() then return false, "Only the host." end
                if tostring(z) == "reset" then return modifiers.reset_demon_opts(fromLocal) end
                return modifiers.set_demon_opt(tostring(z), tonumber(x), fromLocal)
            end)
    end
    local panel = OF.panel
    if panel ~= nil and type(panel.PAGES) == "table" and panel.PAGES.demon == nil then
        panel.PAGES.demon = {
            title = "Green Demon", tab = "room", up = "chance",
            build = function() return modifiers.build_demon_page(panel) end,
        }
    end
end)

function modifiers.build_rows(panel, home)
    local rows = {}

    local groups = modifiers.grouped(home)
    if #groups == 0 then return rows end

    if modifiers.round_holds() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has these - the settings come back after it.")))
    end

    for _, group in ipairs(groups) do

        table.insert(rows, panel.with_help(
            panel.header_row(OF.lang.t(group.name)),
            group.help ~= nil and OF.lang.t(group.help) or nil))

        if group.says ~= nil then
            table.insert(rows, panel.label_row(OF.lang.t(group.says)))
        end

        if not OF.perms.can(modifiers.ROW_RANK) then
            table.insert(rows, panel.label_row(OF.lang.fill(
                "Modifiers ask @ wherever they are drawn.",
                OF.lang.t(OF.perms.tier_name(
                    OF.perms.required(modifiers.ROW_RANK))))))
        end

        for _, entry in ipairs(group.entries) do

            table.insert(rows, modifiers.two_box_row(panel, entry))

            local note = entry.note ~= nil and entry.note() or nil
            if type(note) == "string" and note ~= "" then
                table.insert(rows, panel.label_row("   " .. note))
            end
        end

        if group.tail == "lightshow" and OF.util.asks(OF.theme, "show_rows") then
            for _, row in ipairs(OF.theme.show_rows(panel)) do
                table.insert(rows, row)
            end
        end
    end

    return rows
end
