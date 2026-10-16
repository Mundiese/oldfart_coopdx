OF = OF or {}

if OF.sounds == nil then OF.sounds = {} end
OF.uisfx = OF.uisfx or {}

local uisfx = OF.uisfx

uisfx.NAMES = { "move", "slider_step", "select", "back", "toggle_on", "toggle_off", "tab",
    "open", "close", "arm", "confirm", "error", "wheel_open", "wheel_tick" }
uisfx.KNOWN = {}
for _, name in ipairs(uisfx.NAMES) do uisfx.KNOWN[name] = true end

function uisfx.path(name)
    return "sound/of_ui_" .. name .. ".ogg"
end

uisfx.CLASSIC = {
    move = "MOVE", slider_step = "MOVE", select = "PICK", back = "BACK",
    toggle_on = "TICK", toggle_off = "TICK", tab = "TAB", open = "OPEN",
    close = "CLOSE", arm = "PICK", confirm = "PICK", error = "DENIED",
    wheel_open = "OPEN", wheel_tick = "MOVE",
}

uisfx.MODE_KEY = "ui_sounds"
uisfx.VOLUME_KEY = "ui_sounds_volume"
uisfx.MODES = { "new", "classic", "off" }
uisfx.MODE_WORDS = { new = "The new ones", classic = "The game's old ones", off = "Off" }
uisfx.DEFAULT_MODE = "new"
uisfx.DEFAULT_VOLUME = 100
uisfx.VOLUME_STEP = 10

uisfx.mode = uisfx.DEFAULT_MODE
uisfx.volume = uisfx.DEFAULT_VOLUME

uisfx.handles = {}

uisfx.last = nil

do
    local function known_mode(word)
        for _, m in ipairs(uisfx.MODES) do if m == word then return true end end
        return false
    end
    if mod_storage_load ~= nil then
        local stored = mod_storage_load(uisfx.MODE_KEY)
        if stored ~= nil and known_mode(stored) then uisfx.mode = stored end
        local loud = tonumber(mod_storage_load(uisfx.VOLUME_KEY) or "")
        if loud ~= nil then uisfx.volume = math.max(0, math.min(100, math.floor(loud))) end
    end
    uisfx.known_mode = known_mode
end

local function store(key, value)
    if OF.util ~= nil and type(OF.util.store) == "function" then OF.util.store(key, value) end
end

function uisfx.set_mode(word)
    if not uisfx.known_mode(word) then return uisfx.mode end
    uisfx.mode = word
    store(uisfx.MODE_KEY, word)
    return word
end

function uisfx.set_volume(percent)
    local wanted = math.floor((tonumber(percent) or uisfx.volume) / uisfx.VOLUME_STEP + 0.5) * uisfx.VOLUME_STEP
    uisfx.volume = math.max(0, math.min(100, wanted))
    store(uisfx.VOLUME_KEY, tostring(uisfx.volume))
    return uisfx.volume
end

local function handle_of(name)
    local held = uisfx.handles[name]
    if held ~= nil then return held or nil end
    if type(audio_sample_load) ~= "function" then return nil end
    local fine, handle = pcall(audio_sample_load, uisfx.path(name))
    if not fine or handle == nil then
        uisfx.handles[name] = false
        return nil
    end

    uisfx.handles[name] = handle
    return handle
end

local function at_the_camera()
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local area = m ~= nil and m.area or nil
    local camera = area ~= nil and area.camera or nil
    if camera ~= nil and camera.pos ~= nil then
        return { x = camera.pos.x, y = camera.pos.y, z = camera.pos.z }
    end
    if gLakituState ~= nil and gLakituState.pos ~= nil then
        return { x = gLakituState.pos.x, y = gLakituState.pos.y, z = gLakituState.pos.z }
    end
    if m ~= nil and m.pos ~= nil then return { x = m.pos.x, y = m.pos.y, z = m.pos.z } end
    return { x = 0, y = 0, z = 0 }
end

local function play_classic(name, classic)

    if classic == false then return false end
    local id = classic
    if id == nil then
        local word = uisfx.CLASSIC[name]
        id = word ~= nil and OF.sounds[word] or nil
    end
    if id == nil or type(OF.sounds.play) ~= "function" then return false end
    OF.sounds.play(id)
    uisfx.last = { name = name, classic = id }
    return true
end

function uisfx.play(name, classic)
    if not uisfx.KNOWN[name] then return false end
    if uisfx.mode == "off" then return false end
    if uisfx.mode == "classic" then return play_classic(name, classic) end
    if uisfx.volume <= 0 then return false end
    local handle = handle_of(name)
    if handle == nil or type(audio_sample_play) ~= "function" then
        return play_classic(name, classic)
    end

    if OF.util.asks(OF.sounds, "fresh") and not OF.sounds.fresh("ui:" .. name) then
        return false
    end
    audio_sample_play(handle, at_the_camera(), uisfx.volume / 100)
    uisfx.last = { name = name, volume = uisfx.volume / 100 }
    return true
end

OF.sounds.ui = uisfx.play

function uisfx.press_word(row, alt)
    if type(row) ~= "table" or row.action == nil and not alt then return "move" end
    if row.confirming ~= nil then return "confirm" end
    if row.danger then return "arm" end
    local panel = OF.panel
    local text = type(row.text) == "string" and row.text or ""
    if OF.util ~= nil and type(OF.util.plain) == "function" then text = OF.util.plain(text) end
    local first, second = string.match(text, "^%s*%[(.)%]%s*%[(.)%]")
    local box = first
    if alt then box = second end
    if box == nil and not alt then box = string.match(text, "^%s*%[(.)%]") end
    local ticks = box ~= nil
        or (panel ~= nil and type(panel.row_ticks) == "function" and panel.row_ticks(row) and not alt)
    if not ticks then

        if string.match(text, "^%s*<") then return "back" end
        return "select"
    end
    if box == "X" or box == "x" then return "toggle_off" end
    return "toggle_on"
end

function uisfx.press(row, alt, classic)
    return uisfx.play(uisfx.press_word(row, alt), classic)
end

OF.sounds.ui_press = uisfx.press

function uisfx.rows(panel)
    local rows = {}
    local index = 1
    for i, m in ipairs(uisfx.MODES) do if m == uisfx.mode then index = i end end
    local setRow = panel.row(OF.lang.t("Menu sounds"), 255, 255, 255, function()
        uisfx.set_mode(uisfx.MODES[index % #uisfx.MODES + 1])
    end)
    setRow = panel.with_right(setRow, OF.lang.t(uisfx.MODE_WORDS[uisfx.mode]))
    setRow = panel.with_slider(setRow, index - 1, #uisfx.MODES - 1, function(wanted)
        uisfx.set_mode(uisfx.MODES[wanted + 1])
    end)
    rows[#rows + 1] = panel.with_help(setRow,
        OF.lang.t("the clicks of menus and wheels - only on your machine; game sounds stay as they are"))
    local loudRow = panel.row(OF.lang.t("Menu sounds volume"), 255, 255, 255, function()
        local stepped = uisfx.volume - uisfx.VOLUME_STEP
        if stepped < 0 then stepped = 100 end
        uisfx.set_volume(stepped)
    end)
    loudRow = panel.with_right(loudRow, uisfx.volume .. "%")
    loudRow = panel.with_slider(loudRow, math.floor(uisfx.volume / uisfx.VOLUME_STEP + 0.5),
        100 / uisfx.VOLUME_STEP, function(wanted)
            uisfx.set_volume(wanted * uisfx.VOLUME_STEP)
        end)
    rows[#rows + 1] = panel.with_help(loudRow,
        OF.lang.t("the new menu sounds only - the game's own slider still applies"))
    return rows
end
