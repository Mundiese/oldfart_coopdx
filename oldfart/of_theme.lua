OF = OF or {}
OF.theme = OF.theme or {}

local theme = OF.theme

local SETTING_KEY = "theme_own"
local RAINBOW_KEY = "theme_rainbow"
local MIX_KEEP_KEY = "theme_mix"
theme.PRESETS = {
    {
        key = "gold", name = "Gold",
        about = "the mod's own yellow on near-black",
        accent = { r = 255, g = 255, b = 0 },
        frame  = { r = 255, g = 255, b = 0, a = 220 },
        panel  = { r = 10, g = 10, b = 14, a = 238 },
        title  = { r = 28, g = 28, b = 38 },
    },
    {
        key = "ice", name = "Ice",
        about = "pale blue on a deep blue night",
        accent = { r = 130, g = 220, b = 255 },
        frame  = { r = 130, g = 220, b = 255, a = 210 },
        panel  = { r = 8, g = 14, b = 22, a = 238 },
        title  = { r = 22, g = 32, b = 44 },
    },
    {
        key = "toxic", name = "Toxic",
        about = "bright green on very dark green",
        accent = { r = 150, g = 255, b = 90 },
        frame  = { r = 150, g = 255, b = 90, a = 210 },
        panel  = { r = 8, g = 16, b = 8, a = 238 },
        title  = { r = 20, g = 34, b = 20 },
    },
    {
        key = "ember", name = "Ember",
        about = "orange on a burnt, almost black brown",
        accent = { r = 255, g = 130, b = 60 },
        frame  = { r = 255, g = 130, b = 60, a = 215 },
        panel  = { r = 18, g = 9, b = 6, a = 238 },
        title  = { r = 40, g = 22, b = 16 },
    },
    {
        key = "rose", name = "Rose",
        about = "pink on a dark plum",
        accent = { r = 255, g = 140, b = 200 },
        frame  = { r = 255, g = 140, b = 200, a = 210 },
        panel  = { r = 18, g = 8, b = 16, a = 238 },
        title  = { r = 40, g = 20, b = 34 },
    },
    {
        key = "mono", name = "Mono",
        about = "white on black, and no colour at all",
        accent = { r = 235, g = 235, b = 235 },
        frame  = { r = 200, g = 200, b = 200, a = 200 },
        panel  = { r = 12, g = 12, b = 12, a = 240 },
        title  = { r = 30, g = 30, b = 30 },
    },

    {
        key = "cap", name = "Cap",
        about = "the wing cap's red and its blue shadow",
        accent = { r = 245, g = 60, b = 55 },
        frame  = { r = 245, g = 60, b = 55, a = 215 },
        panel  = { r = 20, g = 7, b = 8, a = 238 },
        title  = { r = 46, g = 18, b = 18 },
    },
    {
        key = "boo", name = "Boo",
        about = "the haunted house - grey-white on grey",
        accent = { r = 195, g = 165, b = 255 },
        frame  = { r = 195, g = 165, b = 255, a = 205 },
        panel  = { r = 14, g = 10, b = 24, a = 238 },
        title  = { r = 34, g = 26, b = 52 },
    },
    {
        key = "bay", name = "Bay",
        about = "Jolly Roger's green water under a grim sky",
        accent = { r = 90, g = 215, b = 200 },
        frame  = { r = 90, g = 215, b = 200, a = 205 },
        panel  = { r = 6, g = 18, b = 20, a = 238 },
        title  = { r = 18, g = 38, b = 40 },
    },
    {
        key = "sand", name = "Sand",
        about = "the desert, warm and pale",
        accent = { r = 240, g = 200, b = 120 },
        frame  = { r = 240, g = 200, b = 120, a = 205 },
        panel  = { r = 20, g = 15, b = 8, a = 238 },
        title  = { r = 46, g = 36, b = 20 },
    },

    {
        key = "vanish", name = "Vanish",
        about = "the level shows through the menu",
        accent = { r = 190, g = 255, b = 245 },
        frame  = { r = 190, g = 255, b = 245, a = 150 },
        panel  = { r = 6, g = 10, b = 16, a = 150 },
        title  = { r = 20, g = 28, b = 40 },
    },

    {
        key = "night", name = "Night",
        about = "the darkest of them, and nothing shows through",
        accent = { r = 105, g = 130, b = 255 },
        frame  = { r = 60, g = 74, b = 150, a = 255 },
        panel  = { r = 4, g = 5, b = 11, a = 255 },
        title  = { r = 14, g = 17, b = 30 },
    },
}

theme.DEFAULT = "rose"
theme.RETURNING = "night"
local previewKey = nil

local MIX_TITLE_LIFT = 2.5

local MIX = {
    step = 5,
    groundMin = 3,
    groundMax = 12,
    frameAlpha = 215,
    panelAlpha = 238,
}

function theme.mix_cannot()
    local out = {}
    for _, entry in ipairs(theme.PRESETS) do
        local accent, frame = entry.accent, entry.frame
        if accent.r ~= frame.r or accent.g ~= frame.g or accent.b ~= frame.b then
            table.insert(out, entry.key)
        end
    end
    return out
end

local function mix_channel(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return value
end

local function mix_snap(value)
    return mix_channel(math.floor(mix_channel(value) / MIX.step + 0.5) * MIX.step)
end

local function mix_ground(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if value < MIX.groundMin then return MIX.groundMin end
    if value > MIX.groundMax then return MIX.groundMax end
    return value
end

local MIX_MARK = "mix:"
local function mix_text(set)
    return MIX_MARK .. set.r .. "," .. set.g .. "," .. set.b .. ","
        .. set.ground .. "," .. set.frameA .. "," .. set.panelA
end

local function mix_read(text)
    if type(text) ~= "string" then return nil end

    local r, g, b, ground, frameA, panelA =
        string.match(text, "^mix:(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$")
    if r == nil then return nil end
    return {
        r = mix_snap(r), g = mix_snap(g), b = mix_snap(b),
        ground = mix_ground(ground),
        frameA = mix_channel(frameA), panelA = mix_channel(panelA),
    }
end

local mixText = nil
local mixEntry = nil

local READABLE = 4.5

local function linear(c)
    c = c / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(colour)
    return 0.2126 * linear(colour.r) + 0.7152 * linear(colour.g)
        + 0.0722 * linear(colour.b)
end

function theme.contrast(fore, back)
    local a, b = luminance(fore), luminance(back)
    if a < b then a, b = b, a end
    return (a + 0.05) / (b + 0.05)
end

theme.READABLE = READABLE

local function readable(accent, ground)
    for step = 0, 20 do
        local t = step / 20
        local lit = {
            r = mix_channel(accent.r + (255 - accent.r) * t),
            g = mix_channel(accent.g + (255 - accent.g) * t),
            b = mix_channel(accent.b + (255 - accent.b) * t),
        }
        if theme.contrast(lit, ground) >= READABLE then return lit end
    end
    return { r = 255, g = 255, b = 255 }
end

local function mix_entry(text)
    if text ~= nil and text == mixText then return mixEntry end
    local set = mix_read(text)
    if set == nil then return nil end
    local body = {
        r = mix_channel(set.r * set.ground / 100),
        g = mix_channel(set.g * set.ground / 100),
        b = mix_channel(set.b * set.ground / 100),
    }
    mixText = text
    mixEntry = {
        key = text,

        name = set.r .. ", " .. set.g .. ", " .. set.b,
        panel  = { r = body.r, g = body.g, b = body.b, a = set.panelA },
        title  = { r = mix_channel(body.r * MIX_TITLE_LIFT),
                   g = mix_channel(body.g * MIX_TITLE_LIFT),
                   b = mix_channel(body.b * MIX_TITLE_LIFT) },
    }

    local lit = readable({ r = set.r, g = set.g, b = set.b }, {
        r = mix_channel(mix_channel(set.r * MIX.groundMax / 100) * MIX_TITLE_LIFT),
        g = mix_channel(mix_channel(set.g * MIX.groundMax / 100) * MIX_TITLE_LIFT),
        b = mix_channel(mix_channel(set.b * MIX.groundMax / 100) * MIX_TITLE_LIFT),
    })
    mixEntry.accent = { r = lit.r, g = lit.g, b = lit.b }
    mixEntry.frame = { r = lit.r, g = lit.g, b = lit.b, a = set.frameA }
    return mixEntry
end

function theme.mix_showing()
    local key = theme.active_key()
    local set = mix_read(key)
    if set ~= nil then return set end

    local entry = theme.preset(key)

    local total, counted = 0, 0
    for _, channel in ipairs({ "r", "g", "b" }) do
        if entry.accent[channel] > 0 then
            total = total + entry.panel[channel] / entry.accent[channel]
            counted = counted + 1
        end
    end
    local ground = MIX.groundMin
    if counted > 0 then ground = math.floor(total / counted * 100 + 0.5) end

    return {
        r = mix_snap(entry.accent.r),
        g = mix_snap(entry.accent.g),
        b = mix_snap(entry.accent.b),
        ground = mix_ground(ground),
        frameA = mix_channel(entry.frame.a or MIX.frameAlpha),
        panelA = mix_channel(entry.panel.a or MIX.panelAlpha),
    }
end

function theme.mix_look(set)
    return mix_entry(mix_text({
        r = mix_snap(set.r), g = mix_snap(set.g), b = mix_snap(set.b),
        ground = mix_ground(set.ground),
        frameA = mix_channel(set.frameA or MIX.frameAlpha),
        panelA = mix_channel(set.panelA or MIX.panelAlpha),
    }))
end

theme.MIX_TITLE_LIFT = MIX_TITLE_LIFT
theme.MIX_STEP = MIX.step
theme.MIX_GROUND_MIN = MIX.groundMin
theme.MIX_GROUND_MAX = MIX.groundMax

function theme.set_mix(set)
    previewKey = nil
    local text = mix_text({
        r = mix_snap(set.r), g = mix_snap(set.g), b = mix_snap(set.b),
        ground = mix_ground(set.ground),
        frameA = mix_channel(set.frameA or MIX.frameAlpha),
        panelA = mix_channel(set.panelA or MIX.panelAlpha),
    })
    OF.settings.themeOwn = text
    OF.util.store(SETTING_KEY, text)

    OF.settings.themeMix = text
    OF.util.store(MIX_KEEP_KEY, text)
    theme.apply()
    return true
end

function theme.settled_own(stored)
    if mix_read(stored) ~= nil then return stored end
    if type(stored) == "string" then
        for _, entry in ipairs(theme.PRESETS) do
            if entry.key == stored then return stored end
        end
    end
    return theme.DEFAULT
end

function theme.settled_mix(stored)
    if mix_read(stored) ~= nil then return stored end
    return nil
end

function theme.kept_mix()
    return OF.settings.themeMix
end

function theme.preset(key)

    local mixed = mix_entry(key)
    if mixed ~= nil then return mixed end
    for _, entry in ipairs(theme.PRESETS) do
        if entry.key == key then return entry end
    end
    return theme.PRESETS[1]
end

function theme.active_key()

    if previewKey ~= nil then return previewKey end
    return OF.settings.themeOwn or theme.DEFAULT
end

local function stop_preview()
    previewKey = nil
    theme.apply()
end

function theme.preview(key)
    if key == nil then
        stop_preview()
        return true
    end
    if theme.preset(key).key ~= key then
        return false, "No theme called '" .. tostring(key) .. "'."
    end
    previewKey = key
    theme.apply()
    return true
end

function theme.active()
    return theme.preset(theme.active_key())
end

function theme.apply()
    local preset = theme.active()
    OF.GOLD.r = preset.accent.r
    OF.GOLD.g = preset.accent.g
    OF.GOLD.b = preset.accent.b
end

local RAINBOW_FRAMES = 600

local RAINBOW_DEPTH = 3

local RAINBOW_FLOOR = 25
local RAINBOW_TURN = math.pi * 2
local RAINBOW_THIRD = RAINBOW_TURN / 3

function theme.rainbow_on()
    return OF.settings.themeRainbow == true
end

function theme.set_rainbow(on)
    OF.settings.themeRainbow = on and true or false
    OF.util.store_bool(RAINBOW_KEY, OF.settings.themeRainbow)
    return true
end

local function whole(v)
    return math.floor(v + 0.5)
end

function theme.wheel(t, depth, floor)

    local a = (0.5 + 0.5 * math.sin(t)) ^ depth
    local b = (0.5 + 0.5 * math.sin(t + RAINBOW_THIRD)) ^ depth
    local c = (0.5 + 0.5 * math.sin(t + RAINBOW_THIRD * 2)) ^ depth
    local top = a
    if b > top then top = b end
    if c > top then top = c end
    if top <= 0 then top = 1 end
    local span = 255 - floor
    return whole(floor + span * (a / top)),
           whole(floor + span * (b / top)),
           whole(floor + span * (c / top))
end

theme.HUE_AT = {
    yellow  = 1 / 12,
    red     = 3 / 12,
    magenta = 5 / 12,
    blue    = 7 / 12,
    cyan    = 9 / 12,
    green   = 11 / 12,
}

function theme.highlight(frame)
    local accent = theme.active().accent
    if not theme.rainbow_on() then return accent.r, accent.g, accent.b end

    if frame == nil then
        frame = OF.util.optional("get_global_timer", 0) or 0
    end
    local t = (frame % RAINBOW_FRAMES) / RAINBOW_FRAMES * RAINBOW_TURN
    return theme.wheel(t, RAINBOW_DEPTH, RAINBOW_FLOOR)
end

theme.RAINBOW_FLOOR = RAINBOW_FLOOR
theme.RAINBOW_FRAMES = RAINBOW_FRAMES
theme.RAINBOW_DEPTH = RAINBOW_DEPTH

function theme.set_own(key)
    previewKey = nil
    OF.settings.themeOwn = key
    OF.util.store(SETTING_KEY, key)
    theme.apply()
    return true
end

OF.settings = OF.settings or {}

function theme.first_own(stored, others)
    if stored ~= nil and stored ~= "" then return theme.settled_own(stored), false end
    if others then return theme.RETURNING, true end
    return theme.DEFAULT, false
end

do
    local stored = mod_storage_load(SETTING_KEY)
    local others = false
    if stored == nil or stored == "" then
        local all = mod_storage_load_all ~= nil and mod_storage_load_all() or nil
        if type(all) == "table" then
            for key, value in pairs(all) do
                if key ~= SETTING_KEY and value ~= nil and value ~= "" then
                    others = true
                    break
                end
            end
        end
    end
    local own, pin = theme.first_own(stored, others)
    OF.settings.themeOwn = own

    if pin and mod_storage_save ~= nil then mod_storage_save(SETTING_KEY, own) end
end
OF.settings.themeMix = theme.settled_mix(mod_storage_load(MIX_KEEP_KEY, ""))

if OF.settings.themeMix == nil and mix_read(OF.settings.themeOwn) ~= nil then
    OF.settings.themeMix = OF.settings.themeOwn
end

OF.settings.themeRainbow = mod_storage_load_bool(RAINBOW_KEY, true)

hook_event(HOOK_ON_LEVEL_INIT, function() theme.apply() end)

hook_event(HOOK_UPDATE, function()
    if previewKey == nil then return end
    if OF.util.menu_has_screen() then return end
    stop_preview()
end)

theme.SHOW_FLOOR = 140

theme.SHOWS = {
    {
        key = "off", name = "Off",
        blurb = "the level keeps its own colours",
    },

    {
        key = "fever", name = "Fever",
        blurb = "two seconds a turn - the world, the light and the shadow, cycling",
        turn = 60, depth = 3, floor = 150, spread = 1 / 3,
        paints = { world = true, light = true, shadow = true },
    },
}

theme.SHOW_DEFAULT = "off"
local SHOW_KEY = "ofShow"
theme.SHOW_KEY = SHOW_KEY

function theme.round_hides(localIndex)
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down(localIndex) == true
end

local SHOWOFF_KEY = "theme_showoff"
OF.settings = OF.settings or {}
local storedShowMine = (mod_storage_load ~= nil)
    and mod_storage_load(SHOWOFF_KEY, "") or ""
OF.settings.themeShowMine = nil
if storedShowMine == "off" or storedShowMine == "false" then
    OF.settings.themeShowMine = false
elseif storedShowMine == "on" then
    OF.settings.themeShowMine = true
end

function theme.show_entry(key)
    for _, entry in ipairs(theme.SHOWS) do
        if entry.key == key then return entry end
    end
    return theme.SHOWS[1]
end

function theme.show_key()
    local key = gGlobalSyncTable[SHOW_KEY]
    if key == nil or key == "" then return theme.SHOW_DEFAULT end
    return key
end

function theme.show()
    return theme.show_entry(theme.show_key())
end

function theme.show_mine()
    local settings = OF.settings
    if type(settings) ~= "table" then return nil end
    local held = settings.themeShowMine
    if held ~= true and held ~= false then return nil end
    return held
end

function theme.ask_show(key, askerLocal)
    if not OF.perms.can("vision") then
        return false, "Your rank cannot set the lobby's light show."
    end
    if theme.show_entry(key).key ~= key then
        return false, "No such light show."
    end
    if OF.util.is_host() then return theme.set_show(key, askerLocal) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("show", key)
    end
    return false, "No host to ask yet - try again in a second."
end

function theme.show_for_room(asker, key)
    if not OF.util.is_host() then
        return false, "Only the host sets the lobby's light show."
    end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("vision", asker) then
        return false, "Your rank cannot do that."
    end

    return theme.set_show(tostring(key), asker)
end

function theme.set_show_mine(state)
    if state ~= true and state ~= false then state = nil end

    if state == (theme.show_key() ~= theme.SHOW_DEFAULT) then state = nil end
    OF.settings = OF.settings or {}
    OF.settings.themeShowMine = state
    OF.util.store(SHOWOFF_KEY,
        (state == true and "on") or (state == false and "off") or "")
    return true
end

local function show_turn(entry, frame, offset)
    local phase = ((frame / entry.turn) + (offset or 0)) % 1

    if entry.steps ~= nil and entry.steps > 0 then
        phase = math.floor(phase * entry.steps) / entry.steps
    end

    if entry.pong then
        local walked = phase * 2
        if walked > 1 then walked = 2 - walked end
        phase = walked
    end
    return ((entry.from or 0) + (entry.span or 1) * phase) * RAINBOW_TURN
end
theme.show_turn = show_turn

local showWorld = { r = 255, g = 255, b = 255 }
local showLight = { r = 255, g = 255, b = 255 }
local showShadow = { r = 255, g = 255, b = 255 }

local function fill(into, r, g, b)
    into.r, into.g, into.b = r, g, b
    return into
end

function theme.show_colours(frame)

    local entry = theme.show_entry(theme.in_force(0, "show"))
    if entry == nil or entry.turn == nil or entry.turn <= 0 then return nil end
    if frame == nil then
        frame = OF.util.optional("get_global_timer", 0) or 0
    end

    local depth = entry.depth or 2
    local floor = entry.floor or theme.SHOW_FLOOR
    local paints = entry.paints or {}

    local world, light, shadow = nil, nil, nil
    if paints.world or paints.light then
        local r, g, b = theme.wheel(show_turn(entry, frame, 0), depth, floor)
        if paints.world then world = fill(showWorld, r, g, b) end
        if paints.light then light = fill(showLight, r, g, b) end
    end
    if paints.shadow then
        local r, g, b = theme.wheel(
            show_turn(entry, frame, entry.spread or 0), depth, floor)
        shadow = fill(showShadow, r, g, b)
    end
    return world, light, shadow
end

function theme.show_blocked_by()
    if not OF.util.asks(OF.modifiers, "is_on") then return nil end
    if OF.modifiers.is_on("tint") then return "The world's colour" end
    if OF.modifiers.is_on("shading") then return "The light and the shadow" end
    return nil
end

local showHeld = false

function theme.show_held()
    return showHeld
end

function theme.drive_show(frame)
    local wants = OF.util.asks(OF.modifiers, "wear_lightshow")
    if not wants then return false end

    local world, light, shadow = nil, nil, nil
    if theme.show_blocked_by() == nil then
        world, light, shadow = theme.show_colours(frame)
    end

    if world == nil and light == nil and shadow == nil then

        if not showHeld then return false end
        showHeld = false
        OF.modifiers.wear_lightshow(nil, nil, nil)
        return true
    end

    showHeld = true
    OF.modifiers.wear_lightshow(world, light, shadow)
    return true
end

hook_event(HOOK_UPDATE, function()
    theme.drive_show()
end)

function theme.set_show(key, askerLocal)
    if not OF.perms.can("vision") then
        return false, "Your rank cannot set the lobby's light show."
    end
    if not OF.util.is_host() then
        return false, "Only the host sets the lobby's light show."
    end
    if theme.show_entry(key).key ~= key then
        return false, "No light show called '" .. tostring(key) .. "'."
    end
    OF.util.publish(SHOW_KEY, key)
    local entry = theme.show_entry(key)

    local function credit_it()
        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
            OF.notify.credit(askerLocal,
                OF.lang.fill("light show: @", OF.lang.t(entry.name)))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.fill("set the light show: @", OF.lang.t(entry.name)))
    end

    if key == theme.SHOW_DEFAULT then
        credit_it()
        return true
    end

    if #theme.SHOWS <= 2 then
        credit_it()
        return true
    end
    credit_it()
    return true
end

function theme.borrow_show(key)
    if not OF.util.is_host() then return false end
    if theme.show_entry(key).key ~= key then return false end
    if theme.show_key() == key then return false end
    OF.util.publish(SHOW_KEY, key)
    return true
end

function theme.next_show()
    local now = theme.show_key()
    for index, entry in ipairs(theme.SHOWS) do
        if entry.key == now then
            return theme.SHOWS[index % #theme.SHOWS + 1].key
        end
    end
    return theme.SHOWS[1].key
end

local SHAPE_KEY = "ofShape"
theme.SHAPE_KEY = SHAPE_KEY

local PAPER = 0.04

theme.SHAPES = {
    {
        key = "solid", name = "Solid",
        blurb = "the way the game draws everybody",
        x = 1, y = 1, z = 1,
    },
    {
        key = "front", name = "Paper, facing front",
        blurb = "whole from the front, an edge from the side",
        x = 1, y = 1, z = PAPER,
    },
    {
        key = "side", name = "Paper, side on",
        blurb = "whole from the side, an edge from the front",
        x = PAPER, y = 1, z = 1,
    },
    {
        key = "pancake", name = "Flattened",
        blurb = "stepped on, and stayed that way",
        x = 1.45, y = 0.3, z = 1.45,
    },
    {
        key = "tall", name = "Stretched tall",
        blurb = "a head and a half taller, and narrower for it",
        x = 0.65, y = 1.75, z = 0.65,
    },
    {
        key = "wide", name = "Wide",
        blurb = "twice the shoulders, none of the height",
        x = 1.7, y = 0.95, z = 1.7,
    },
    {
        key = "pin", name = "Pin thin",
        blurb = "a third of the width, and a little stretched",
        x = 0.35, y = 1.15, z = 0.35,
    },
}

theme.SHAPE_DEFAULT = "solid"
theme.MEASURE_STEPS = { PAPER, 0.3, 0.5, 0.65, 0.8, 1, 1.15, 1.3, 1.5, 1.75, 2 }
theme.MEASURE_REST = 6

theme.MEASURE_AXES = {
    { axis = "y", name = "Height", blurb = "how tall everybody is drawn, feet to head" },
    { axis = "x", name = "Width", blurb = "how wide, shoulder to shoulder" },
    { axis = "z", name = "Depth", blurb = "how deep, front to back - paper at the bottom" },
}

function theme.measure_word(index)
    local value = theme.MEASURE_STEPS[index]
    if value == nil then return "" end
    if value < 0.1 then return OF.lang.t("paper") end
    return tostring(math.floor(value * 100 + 0.5)) .. "%"
end

function theme.nearest_step(value)
    value = tonumber(value) or 1
    local best, gap = theme.MEASURE_REST, math.huge
    for index, step in ipairs(theme.MEASURE_STEPS) do
        local d = math.abs(step - value)
        if d < gap then best, gap = index, d end
    end
    return best
end

function theme.measured_key(x, y, z)
    local rest = theme.MEASURE_REST
    if x == rest and y == rest and z == rest then return theme.SHAPE_DEFAULT end
    return string.format("m%.0f.%.0f.%.0f", x, y, z)
end

local measuredCache = {}

local function measured_entry(key)
    if type(key) ~= "string" then return nil end
    local held = measuredCache[key]
    if held ~= nil then return held end
    local x, y, z = key:match("^m(%d+)%.(%d+)%.(%d+)$")
    if x == nil then return nil end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    local steps = theme.MEASURE_STEPS
    if steps[x] == nil or steps[y] == nil or steps[z] == nil then return nil end
    local entry = {
        key = key,
        name = "height " .. theme.measure_word(y) .. ", width "
            .. theme.measure_word(x) .. ", depth " .. theme.measure_word(z),
        blurb = "measured on the size sliders",
        x = steps[x], y = steps[y], z = steps[z],
        stops = { x = x, y = y, z = z },
    }
    measuredCache[key] = entry
    return entry
end

function theme.shape_entry(key)
    for _, entry in ipairs(theme.SHAPES) do
        if entry.key == key then return entry end
    end
    local measured = measured_entry(key)
    if measured ~= nil then return measured end
    return theme.SHAPES[1]
end

function theme.shape_stops(key)
    local entry = theme.shape_entry(key)
    if entry.stops ~= nil then
        return entry.stops.x, entry.stops.y, entry.stops.z
    end
    return theme.nearest_step(entry.x), theme.nearest_step(entry.y),
        theme.nearest_step(entry.z)
end

function theme.with_axis(key, axis, index)
    local x, y, z = theme.shape_stops(key)
    if axis == "x" then x = index elseif axis == "y" then y = index else z = index end
    return theme.measured_key(x, y, z)
end

function theme.shape_key()
    local key = gGlobalSyncTable[SHAPE_KEY]
    if key == nil or key == "" then return theme.SHAPE_DEFAULT end
    return key
end

function theme.shape()
    return theme.shape_entry(theme.shape_key())
end

function theme.shape_room_on(key)
    return key ~= nil and theme.shape_key() == key
end

local SHAPE_MINE_KEY = "ofMyShape"
theme.SHAPE_MINE_KEY = SHAPE_MINE_KEY

local SHAPE_MINE_STORE = "theme_shape_mine"
local storedShapeMine = (mod_storage_load ~= nil)
    and mod_storage_load(SHAPE_MINE_STORE, "") or ""
function theme.shape_mine(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return nil end
    local key = row[SHAPE_MINE_KEY]
    if key == nil or key == "" then return nil end
    if theme.shape_entry(key).key ~= key then return nil end
    if key == theme.shape_key() then return nil end
    return key
end

function theme.settled_shape(key)
    if key == nil or key == "" then return nil end
    if theme.shape_entry(key).key ~= key then return nil end
    if key == theme.shape_key() then return nil end
    return key
end

function theme.set_shape_mine(key)
    local settled = theme.settled_shape(key)
    OF.util.publish_row(0, SHAPE_MINE_KEY, settled or "")

    OF.util.store(SHAPE_MINE_STORE, settled or "")
    return true
end

function theme.forget_shape_mine()
    OF.util.publish_row(0, SHAPE_MINE_KEY, "")
    OF.util.store(SHAPE_MINE_STORE, "")
    return true
end

function theme.anyone_chose()
    if theme.show_mine() ~= nil then return true end
    for index = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[index]
        if np ~= nil and np.connected and theme.shape_mine(index) ~= nil then
            return true
        end
    end
    return false
end

theme.PACKET_CLEAR = "themeclear"
hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= theme.PACKET_CLEAR then return end

    if not OF.util.from_host(data) then return end

    theme.forget_shape_mine()
    theme.set_show_mine(nil)
end)

function theme.pin_round_screen()
    local moved = 0
    if OF.util.asks(OF.markers, "on") and not OF.markers.on() then
        OF.markers.set(true)
        moved = moved + 1
    end
    if OF.util.asks(OF.teams, "colours_on") and not OF.teams.colours_on() then
        OF.teams.set_colours(true)
        moved = moved + 1
    end
    if OF.util.asks(OF.scoreboard, "is_on") and not OF.scoreboard.is_on() then
        OF.scoreboard.set_on(true)
        moved = moved + 1
    end
    if OF.util.asks(OF.zombies, "negative_eyes") and OF.zombies.negative_eyes()
        and OF.util.asks(OF.settings, "set_negative_eyes") then
        OF.settings.set_negative_eyes(false)
        moved = moved + 1
    end
    return moved
end

hook_event(HOOK_ON_MODS_LOADED, function()
    theme.pin_round_screen()
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    if storedShapeMine == nil or storedShapeMine == "" then return end
    if theme.shape_entry(storedShapeMine).key ~= storedShapeMine then return end
    theme.set_shape_mine(storedShapeMine)
end)

function theme.drawn_shape(localIndex)
    local entry = theme.shape_entry(theme.in_force(localIndex or 0, "shape"))
    return entry.x or 1, entry.y or 1, entry.z or 1
end

function theme.set_shape(key, askerLocal)
    if not OF.perms.can("vision") then
        return false, "Your rank cannot set how the lobby is drawn."
    end
    if not OF.util.is_host() then
        return false, "Only the host sets how the lobby is drawn."
    end
    if theme.shape_entry(key).key ~= key then
        return false, "Nobody is drawn as '" .. tostring(key) .. "'."
    end
    OF.util.publish(SHAPE_KEY, key)

    local entry = theme.shape_entry(key)

    local function credit_it()
        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit") then
            OF.notify.credit(askerLocal,
                OF.lang.fill("everybody is drawn: @", OF.lang.t(entry.name)))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.fill("set how everybody is drawn: @",
                OF.lang.t(entry.name)))
    end
    if key == theme.SHAPE_DEFAULT then
        credit_it()
        return true
    end
    credit_it()
    return true
end

function theme.borrow_shape(key)
    if not OF.util.is_host() then return false end
    if theme.shape_entry(key).key ~= key then return false end
    if theme.shape_key() == key then return false end
    OF.util.publish(SHAPE_KEY, key)
    return true
end

function theme.ask_shape(key, askerLocal)
    if not OF.perms.can("vision") then
        return false, "Your rank cannot set how the lobby is drawn."
    end
    if theme.shape_entry(key).key ~= key then
        return false, "Nobody is drawn as '" .. tostring(key) .. "'."
    end
    if OF.util.is_host() then return theme.set_shape(key, askerLocal) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("shape", key)
    end
    return false, "No host to ask yet - try again in a second."
end

function theme.shape_for_room(asker, key)
    if not OF.util.is_host() then
        return false, "Only the host sets how the lobby is drawn."
    end
    if asker == nil then return false, "Who asked?" end
    if OF.perms.tier(asker) < OF.perms.required("vision", asker) then
        return false, "Your rank cannot do that."
    end

    return theme.set_shape(tostring(key), asker)
end

function theme.next_shape()
    local now = theme.shape_key()
    for index, entry in ipairs(theme.SHAPES) do
        if entry.key == now then
            return theme.SHAPES[index % #theme.SHAPES + 1].key
        end
    end
    return theme.SHAPES[1].key
end

local function first_lit_show()
    for _, entry in ipairs(theme.SHOWS) do
        if entry.key ~= theme.SHOW_DEFAULT then return entry.key end
    end
    return theme.SHOW_DEFAULT
end

function theme.mine_state(localIndex, what, key)
    if what == "show" then
        local held = theme.show_mine()
        if held == nil then return nil end

        if held == (theme.show_key() ~= theme.SHOW_DEFAULT) then return nil end
        return held
    end
    local choice = theme.shape_mine(localIndex)
    if choice == nil then return nil end
    if choice == key then return true end
    if theme.shape_room_on(key) then return false end
    return nil
end

function theme.in_force(localIndex, what)
    if what == "show" then

        local mine = theme.show_mine()
        local room = theme.show_key()
        if mine ~= true and (mine == false or room == theme.SHOW_DEFAULT) then
            return theme.SHOW_DEFAULT
        end
        if theme.round_hides() then return theme.SHOW_DEFAULT end

        if OF.util.asks(OF.modifiers, "select_holds") and OF.modifiers.select_holds() then
            return theme.SHOW_DEFAULT
        end
        if mine == true then

            if room ~= theme.SHOW_DEFAULT then return room end
            return first_lit_show()
        end

        if mine == false then return theme.SHOW_DEFAULT end
        return room
    end

    local shape = theme.shape_mine(localIndex) or theme.shape_key()
    if shape == theme.SHAPE_DEFAULT then return shape end
    if theme.round_hides(localIndex) then return theme.SHAPE_DEFAULT end
    return shape
end

local LOBBY_NEED = "vision"
local MINE_NEED = "costume_self"
function theme.build_page(panel)
    local rows = {}
    local activeKey = theme.active_key()

    local whose = ""
    if previewKey ~= nil then
        whose = "  (a preview - it ends when you close this menu)"
    end

    table.insert(rows, panel.label_row("Showing: "
        .. theme.preset(activeKey).name .. whose))

    for _, preset in ipairs(theme.PRESETS) do
        local key = preset.key
        local mine = OF.settings.themeOwn == key

        local swatch = panel.row(panel.tick(mine, OF.lang.t(preset.name)),
            preset.accent.r, preset.accent.g, preset.accent.b, function()
                theme.set_own(key)
            end)
        swatch.swatch = true
        table.insert(rows, panel.with_help(swatch,
            preset.about ~= nil and OF.lang.t(preset.about) or nil))
    end

    local kept = theme.kept_mix()
    if kept ~= nil then
        local own = theme.preset(kept)
        local mine = OF.settings.themeOwn == kept
        local swatch = panel.row(panel.tick(mine, OF.lang.t("Your own")),
            own.accent.r, own.accent.g, own.accent.b, function()
                theme.set_own(kept)
            end)
        swatch.swatch = true
        table.insert(rows, panel.with_help(panel.with_right(swatch,
            mine and own.name or ""),
            OF.lang.fill("your last mix below, @ - no preset throws it away",
                own.name)))
    end

    local set = theme.mix_showing()
    local look = theme.mix_look(set)

    local function channel_row(name, which)
        local built = panel.row("   " .. name .. ": " .. set[which],
            255, 255, 255, function()
                local now = theme.mix_showing()
                now[which] = now[which] + theme.MIX_STEP * 3
                if now[which] > 255 then now[which] = 0 end
                theme.set_mix(now)
            end)
        return panel.with_slider(built,
            math.floor(set[which] / theme.MIX_STEP),
            math.floor(255 / theme.MIX_STEP), function(wanted)
                local now = theme.mix_showing()
                now[which] = wanted * theme.MIX_STEP
                theme.set_mix(now)
            end)
    end

    table.insert(rows, panel.with_help(panel.header_row("Adjust this set"),
        "mix one of your own from the colour above - it stays on this machine"))
    table.insert(rows, panel.with_help(channel_row("Red", "r"),
        "how much red - the highlight, the cursor and the underlines carry it"))
    table.insert(rows, panel.with_help(channel_row("Green", "g"),
        "how much green - the border round the menu is the same colour"))
    table.insert(rows, panel.with_help(channel_row("Blue", "b"),
        "how much blue - the body and the title bar are shaded down from all three"))

    local ground = panel.row("   The ground under it: " .. look.panel.r
        .. ", " .. look.panel.g .. ", " .. look.panel.b, 255, 255, 255,
        function()
            local now = theme.mix_showing()
            now.ground = now.ground + 1
            if now.ground > theme.MIX_GROUND_MAX then
                now.ground = theme.MIX_GROUND_MIN
            end
            theme.set_mix(now)
        end)
    table.insert(rows, panel.with_help(
        panel.with_slider(ground, set.ground - theme.MIX_GROUND_MIN,
            theme.MIX_GROUND_MAX - theme.MIX_GROUND_MIN, function(wanted)
                local now = theme.mix_showing()
                now.ground = theme.MIX_GROUND_MIN + wanted
                theme.set_mix(now)
            end),
        "how dark the body is - the title bar is lifted from it, never toward white"))

    table.insert(rows, panel.header_row("The menu itself"))

    if OF.util.asks(OF.panelskin, "style") then
        local skin = OF.panelskin
        table.insert(rows, panel.with_help(
            panel.row(panel.tick(skin.style() == "premium",
                OF.lang.t("The new menu look")),
                255, 255, 255, function()
                    skin.set(skin.style() == "premium" and "classic" or "premium")
                end),
            OF.lang.t("the new design, with tab icons and a glowing logo - only you see it")))
    end

    if OF.util.asks(OF.uisfx, "rows") then
        for _, r in ipairs(OF.uisfx.rows(panel)) do table.insert(rows, r) end
    end

    table.insert(rows, panel.with_help(
        panel.row(panel.tick(theme.rainbow_on(),
            OF.lang.t("Drift the highlighted row through colours")),
            255, 255, 255, function()
                theme.set_rainbow(not theme.rainbow_on())
            end),
        OF.lang.t("the row under the cursor only, and only on your screen")))

    if OF.util.asks(OF.panel, "opacity_step") then
        local solid = panel.row("   How solid the menu is: "
            .. OF.panel.opacity .. "%", 255, 255, 255, function()
                local stepped = OF.panel.opacity - 25
                if stepped < OF.panel.OPACITY_LIMITS.min then stepped = 100 end
                OF.util.report(OF.panel.set_opacity(stepped))
            end)
        table.insert(rows, panel.with_help(
            panel.with_slider(solid, OF.panel.opacity_step(),
                OF.panel.opacity_steps(), function(wanted)
                    OF.util.report(OF.panel.set_opacity_step(wanted))
                end),
            "the plates, rules and shadows fade - the words stay solid"))
    end

    table.insert(rows, panel.back_row("client"))
    return rows
end

function theme.show_rows(panel)
    local rows = {}
    local on = theme.show_key() ~= theme.SHOW_DEFAULT
    local mine = theme.mine_state(0, "show")

    local r, g, b = 255, 255, 255
    if on then r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b end

    local built = panel.two_box({
        lobbyOn = on,

        mineBox = panel.mine_shown(mine, on),
        name = OF.lang.t("Light show"),
        lobbyNeed = LOBBY_NEED,
        mineNeed = MINE_NEED,
        r = r, g = g, b = b,
        onLobby = function()

            OF.util.report(theme.ask_show(theme.next_show(), 0))
        end,

        onMine = function()
            OF.util.report(theme.set_show_mine(
                panel.next_mine(theme.mine_state(0, "show"),
                    theme.show_key() ~= theme.SHOW_DEFAULT)))
            panel.mark_dirty()
        end,
    })
    table.insert(rows, panel.with_help(
        panel.level_right(built, panel.mine_marked(mine),
            panel.mine_marked(mine) and OF.lang.t("(yours)") or nil),
        OF.lang.t("A lights the lobby, Z lights your screen - and yours wins")))

    local blocked = theme.show_blocked_by()
    if blocked ~= nil then

        table.insert(rows, panel.label_row("   " .. OF.lang.fill(
            "Waiting for @ to let go.", OF.lang.t(blocked))))
    end

    return rows
end

function theme.build_figure_page(panel)
    local rows = {}

    if theme.round_hides() then
        table.insert(rows, panel.label_row(
            OF.lang.t("A round has these - the lobby's own come back after it.")))
    end

    table.insert(rows, panel.with_help(panel.header_row("Size and shape"),
        "how tall, wide and deep everybody is drawn, Giant and Tiny, and Invisible"))

    table.insert(rows, panel.label_row(
        "Height, width and depth are a look only - nobody's reach or hitbox."))

    local stepCount = #theme.MEASURE_STEPS
    for _, axis in ipairs(theme.MEASURE_AXES) do
        local which = axis.axis
        local function stop_of(key)
            local x, y, z = theme.shape_stops(key)
            if which == "x" then return x elseif which == "y" then return y end
            return z
        end
        local roomKey = theme.shape_key()
        local mineKey = theme.shape_mine(0)
        local roomAt = stop_of(roomKey)
        local mineAt = mineKey ~= nil and stop_of(mineKey) or nil
        local lobbyOn = roomAt ~= theme.MEASURE_REST

        local mine = nil
        if mineAt ~= nil then
            if mineAt ~= theme.MEASURE_REST then mine = true
            elseif lobbyOn then mine = false end
        end
        local function set_room(index)
            OF.util.report(theme.ask_shape(theme.with_axis(roomKey, which, index), 0))
        end
        local function set_mine(index)
            local from = theme.shape_mine(0) or theme.shape_key()
            OF.util.report(theme.set_shape_mine(theme.with_axis(from, which, index)))
            panel.mark_dirty()
        end
        local built = panel.two_box({
            lobbyOn = lobbyOn,
            mineBox = panel.mine_shown(mine, lobbyOn),
            name = OF.lang.t(axis.name),
            lobbyNeed = LOBBY_NEED,
            mineNeed = "powerup_self",
            r = 255, g = 255, b = 255,
            onLobby = function()
                local next = roomAt + 1
                if next > stepCount then next = 1 end
                set_room(next)
            end,
            onMine = function()

                local at = mineAt or roomAt
                if at >= stepCount then
                    OF.util.report(theme.set_shape_mine(nil))
                    panel.mark_dirty()
                    return
                end
                set_mine(at + 1)
            end,
        })
        local shownAt = mineAt or roomAt
        built = panel.level_right(built, true,
            panel.two_box_level(theme.measure_word(shownAt), mineAt ~= nil))
        local dialsRoom = (mineKey == nil) and panel.may(LOBBY_NEED)
        local need = dialsRoom and LOBBY_NEED or "powerup_self"
        if panel.may(need) then
            built = panel.with_slider(built, shownAt - 1, stepCount - 1,
                function(wanted)
                    if dialsRoom then set_room(wanted + 1) else set_mine(wanted + 1) end
                end)
        else
            built = panel.with_slider(built, shownAt - 1, stepCount - 1, nil)
        end
        table.insert(rows, panel.with_help(built, axis.blurb))
    end

    if OF.util.asks(OF.cheats, "page_rows") then
        for _, built in ipairs(OF.cheats.page_rows(panel, "shapes")) do
            table.insert(rows, built)
        end
    end

    if OF.util.asks(OF.rules, "look_rows") then
        table.insert(rows, panel.with_help(
            panel.header_row("The name over a head"),
            "whether there is one, what colour it is, and what it carries"))
        for _, built in ipairs(OF.rules.look_rows(panel)) do
            table.insert(rows, built)
        end
    end

    if OF.util.asks(OF.modifiers, "build_rows") then
        for _, built in ipairs(OF.modifiers.build_rows(panel, "shapes")) do
            table.insert(rows, built)
        end
    end

    table.insert(rows, panel.back_row())
    return rows
end

theme.apply()

function theme.build_screen_page(panel)
    local rows = {}

    table.insert(rows, panel.with_help(panel.header_row("The other players"),
        "what goes over the other players' heads, and what a mark there shows"))

    if OF.util.asks(OF.tags, "build_row") then
        table.insert(rows, OF.tags.build_row(panel))
    end

    if OF.util.asks(OF.camera, "set_steady") then
        table.insert(rows, panel.with_help(
            panel.row(panel.tick(OF.camera.steady_on(),
                OF.lang.t("Hold my camera steady")), 255, 255, 255,
                function()
                    OF.util.report(OF.camera.set_steady(not OF.camera.steady_on()))
                end),
            OF.lang.t("no screen shake on your screen; a round you play in keeps its own")))
    end

    if OF.util.asks(OF.markers, "build_rows") then
        for _, r in ipairs(OF.markers.build_rows(panel)) do
            table.insert(rows, r)
        end
    end

    table.insert(rows, panel.with_help(panel.header_row("Sound and notices"),
        "the jingle a round starts and ends on, and whose hand was on a setting"))

    if OF.util.asks(OF.music, "fanfares_on") then

        table.insert(rows, panel.with_help(
            panel.row(panel.tick(OF.music.fanfares_on(),
                OF.lang.t("Fanfare when a round starts or is won")),
                255, 255, 255,
                function() OF.music.set_fanfares(not OF.music.fanfares_on()) end),
            OF.lang.t("a short jingle over your speakers - the lobby's track carries on")))
    end

    if OF.util.asks(OF.notify, "lines_on") then
        table.insert(rows, panel.with_help(
            panel.row(panel.tick(OF.notify.lines_on(),
                OF.lang.t("Who did what, as a line in the corner")),
                255, 255, 255,
                function() OF.notify.set_lines_on(not OF.notify.lines_on()) end),
            OF.lang.t("the name of whoever changed the lobby or acted on a player, for a few seconds")))
    end

    if OF.util.asks(OF.celebrate, "presentation_rows") then
        for _, r in ipairs(OF.celebrate.presentation_rows(panel)) do
            table.insert(rows, r)
        end
    end

    table.insert(rows, panel.back_row())
    return rows
end

if OF.panel ~= nil and type(OF.panel.PAGES) == "table" then
    OF.panel.PAGES.screen = {
        title = "Marks and notices", tab = "me", up = "client",
        build = function() return theme.build_screen_page(OF.panel) end,
    }
end
