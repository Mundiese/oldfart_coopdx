OF = OF or {}
OF.theme = OF.theme or {}

local theme = OF.theme

local SETTING_KEY = "theme_own"
local RAINBOW_KEY = "theme_rainbow"
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

    {
        key = "game", name = "Game",
        about = "whatever theme you set in the game's own options",
        accent = { r = 235, g = 235, b = 235 },
        frame  = { r = 235, g = 235, b = 235, a = 215 },
        panel  = { r = 11, g = 11, b = 11, a = 238 },
        title  = { r = 40, g = 40, b = 40 },
    },
}

local GAME_FLOOR = 90
local GAME_LIFT = 235
local PANEL_SHADE = 0.05
local TITLE_SHADE = 0.14
local TITLE_BASE = 8

local GAME_FIELDS = {
    { "threePanels",   "rectColor"          },
    { "threePanels",   "borderColor"        },
    { "interactables", "defaultRectColor"   },
    { "interactables", "defaultBorderColor" },
    { "interactables", "textColor"          },
}

local function channel_of(colour, name)
    local value = colour ~= nil and colour[name] or nil
    if type(value) ~= "number" then return nil end
    return OF.util.clamp(math.floor(value), 0, 255)
end

local function colour_copy(colour)
    local r = channel_of(colour, "r")
    local g = channel_of(colour, "g")
    local b = channel_of(colour, "b")
    if r == nil or g == nil or b == nil then return nil end
    return { r = r, g = g, b = b }
end

local function brightest(colour)
    return math.max(colour.r, colour.g, colour.b)
end

local function lifted(colour)
    local top = brightest(colour)
    if top >= GAME_LIFT or top <= 0 then return colour end
    local by = GAME_LIFT / top
    return {
        r = OF.util.clamp(math.floor(colour.r * by), 0, 255),
        g = OF.util.clamp(math.floor(colour.g * by), 0, 255),
        b = OF.util.clamp(math.floor(colour.b * by), 0, 255),
    }
end

local function shaded(colour, mult, base)
    base = base or 0
    return {
        r = OF.util.clamp(math.floor(colour.r * mult) + base, 0, 255),
        g = OF.util.clamp(math.floor(colour.g * mult) + base, 0, 255),
        b = OF.util.clamp(math.floor(colour.b * mult) + base, 0, 255),
    }
end

local gameFrame = nil

function theme.game_look()
    local entry = nil
    for _, preset in ipairs(theme.PRESETS) do
        if preset.key == "game" then entry = preset end
    end
    if entry == nil then return nil end

    local stamp = get_global_timer ~= nil and get_global_timer() or nil
    if stamp ~= nil and stamp == gameFrame then return entry end
    gameFrame = stamp

    if djui_menu_get_theme == nil then return entry end
    if OF.util == nil or type(OF.util.clamp) ~= "function" then return entry end
    local look = djui_menu_get_theme()
    if look == nil then return entry end

    local accent = nil
    for _, field in ipairs(GAME_FIELDS) do
        local group = look[field[1]]
        local colour = group ~= nil and colour_copy(group[field[2]]) or nil
        if colour ~= nil and brightest(colour) >= GAME_FLOOR then
            accent = lifted(colour)
            break
        end
    end
    if accent == nil then return entry end

    entry.accent = accent
    entry.frame = { r = accent.r, g = accent.g, b = accent.b, a = 215 }
    local body = shaded(accent, PANEL_SHADE)
    entry.panel = { r = body.r, g = body.g, b = body.b, a = 238 }
    entry.title = shaded(accent, TITLE_SHADE, TITLE_BASE)
    return entry
end

theme.DEFAULT = "night"
local previewKey = nil

function theme.preset(key)

    if key == "game" then
        local live = theme.game_look()
        if live ~= nil then return live end
    end
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
    OF.notify.show(OF.settings.themeRainbow
        and "The highlighted row now drifts through colours."
        or "The highlighted row is back to the theme's colour.", "info", 3)
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
    OF.notify.show("Your theme: @", "info", 3, theme.preset(key).name)
    return true
end

OF.settings = OF.settings or {}
OF.settings.themeOwn = mod_storage_load(SETTING_KEY, theme.DEFAULT)

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

function theme.round_hides()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
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
    if OF.perms.tier(asker) < OF.perms.required("vision") then
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
        OF.notify.send_all("The light show is off.", "info", 4)
        credit_it()
        return true
    end

    if #theme.SHOWS <= 2 then
        OF.notify.send_all("The light show is on.", "info", 4)
        credit_it()
        return true
    end
    OF.notify.send_all("Light show: @", "info", 4, entry.name)
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
function theme.shape_entry(key)
    for _, entry in ipairs(theme.SHAPES) do
        if entry.key == key then return entry end
    end
    return theme.SHAPES[1]
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
        OF.notify.send_all("Everybody is back to normal.", "info", 4)
        credit_it()
        return true
    end
    OF.notify.send_all("Everybody is drawn: @", "info", 4, entry.name)
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
    if OF.perms.tier(asker) < OF.perms.required("vision") then
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
        if theme.round_hides() then return theme.SHOW_DEFAULT end
        local mine = theme.show_mine()
        local room = theme.show_key()
        if mine == true then

            if room ~= theme.SHOW_DEFAULT then return room end
            return first_lit_show()
        end

        if mine == false then return theme.SHOW_DEFAULT end
        return room
    end
    if theme.round_hides() then return theme.SHAPE_DEFAULT end
    return theme.shape_mine(localIndex) or theme.shape_key()
end

local LOBBY_NEED = "vision"
local MINE_NEED = "costume_self"
function theme.build_page(panel)
    local rows = {}
    local activeKey = theme.active_key()

    local whose = "  (yours, and nobody else's)"
    if previewKey ~= nil then
        whose = "  (a preview - it ends when you close this menu)"
    end

    table.insert(rows, panel.label_row("Showing: "
        .. theme.preset(activeKey).name .. whose))

    theme.game_look()

    for _, preset in ipairs(theme.PRESETS) do
        local key = preset.key
        local mine = OF.settings.themeOwn == key
        table.insert(rows, panel.with_help(
            panel.row(panel.tick(mine, OF.lang.t(preset.name)),
                preset.accent.r, preset.accent.g, preset.accent.b, function()
                    theme.set_own(key)
                end),
            preset.about ~= nil and OF.lang.t(preset.about) or nil))
    end

    table.insert(rows, panel.header_row("The menu itself"))

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

    table.insert(rows, panel.with_help(
        panel.row("   The menu's size and place...",
            255, 255, 255, function() panel.go("place") end),
        OF.lang.t("how wide, how tall and where on the screen this window sits")))

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

    table.insert(rows, panel.header_row("The shape everybody is drawn as"))

    table.insert(rows, panel.label_row(
        "A look only - it changes nobody's reach and nobody's hitbox."))

    for _, entry in ipairs(theme.SHAPES) do
        local key = entry.key
        local room = theme.shape_room_on(key)
        local mine = theme.mine_state(0, "shape", key)
        local marked = panel.mine_marked(mine)
        local built = panel.two_box({
            lobbyOn = room,

            mineBox = panel.mine_shown(mine, room),
            name = OF.lang.t(entry.name),
            lobbyNeed = LOBBY_NEED,
            mineNeed = MINE_NEED,
            r = 255, g = 255, b = 255,
            onLobby = function()

                if theme.shape_room_on(key) then
                    OF.util.report(theme.ask_shape(theme.SHAPE_DEFAULT, 0))
                    return
                end
                OF.util.report(theme.ask_shape(key, 0))
            end,
            onMine = function()
                local next = panel.next_mine(
                    theme.mine_state(0, "shape", key),
                    theme.shape_room_on(key))

                if next == true then
                    OF.util.report(theme.set_shape_mine(key))
                elseif next == false then
                    OF.util.report(theme.set_shape_mine(theme.SHAPE_DEFAULT))
                else
                    OF.util.report(theme.set_shape_mine(nil))
                end
                panel.mark_dirty()
            end,
        })
        table.insert(rows, panel.with_help(
            panel.level_right(built, marked,
                marked and OF.lang.t("(yours)") or nil),
            entry.blurb))
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

    table.insert(rows, panel.label_row(
        "Yours only. Nothing here reaches anybody else, and no rank is asked."))

    table.insert(rows, panel.with_help(
        panel.row(panel.tick(OF.markers.on(),
            OF.lang.t("Markers over players in a round")), 255, 255, 255,
            function() OF.markers.set(not OF.markers.on()) end),
        OF.lang.t("an arrow through the walls to whoever a round wants you to find")))
    table.insert(rows, panel.with_help(
        panel.row(panel.tick(OF.teams.colours_on(),
            OF.lang.t("Colour the other players by side or role")),
            255, 255, 255,
            function() OF.teams.set_colours(not OF.teams.colours_on()) end),
        OF.lang.t("their own costume colour is put back when the round ends")))

    if OF.util.asks(OF.tags, "build_row") then
        table.insert(rows, OF.tags.build_row(panel))
    end

    if OF.util.asks(OF.markers, "build_rows") then
        for _, r in ipairs(OF.markers.build_rows(panel)) do
            table.insert(rows, r)
        end
    end

    if OF.util.asks(OF.zombies, "build_screen_row") then
        table.insert(rows, OF.zombies.build_screen_row(panel))
    end

    table.insert(rows, panel.with_help(panel.header_row("Notices"),
        "what the menu tells you out loud: the sound a round ends on, and "
        .. "whose hand was on a setting"))

    if OF.util.asks(OF.music, "fanfares_on") then

        table.insert(rows, panel.with_help(
            panel.row(panel.tick(OF.music.fanfares_on(),
                OF.lang.t("Fanfare when a round starts or is won")),
                255, 255, 255,
                function() OF.music.set_fanfares(not OF.music.fanfares_on()) end),
            OF.lang.t("a short jingle over your speakers - the lobby's track carries on")))
    end

    if OF.util.asks(OF.notify, "credits_on") then
        table.insert(rows, panel.with_help(
            panel.row(panel.tick(OF.notify.credits_on(),
                OF.lang.t("Say who changed a setting")), 255, 255, 255,
                function() OF.notify.set_credits(not OF.notify.credits_on()) end),
            OF.lang.t("puts a name on the notice above the menu when a setting moves")))
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
