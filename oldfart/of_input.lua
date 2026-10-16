OF = OF or {}
OF.input = OF.input or {}

local input = OF.input

input.REPEAT_DELAY = 17
input.REPEAT_INTERVAL = 5

input.lastDown = 0
input.down = 0
input.pressedMask = 0

input.releasedMask = 0

local lastPolledFrame = -1
local holdFrames = {}
local repeatDue = {}

local WATCHED = {
    A_BUTTON, B_BUTTON, Z_TRIG, START_BUTTON,
    U_JPAD, D_JPAD, L_JPAD, R_JPAD,
    L_TRIG, R_TRIG,

    U_CBUTTONS, D_CBUTTONS, L_CBUTTONS, R_CBUTTONS,
}

if Y_BUTTON ~= nil then table.insert(WATCHED, Y_BUTTON) end

local function frame_stamp()
    if get_global_timer ~= nil then return get_global_timer() end
    return nil
end

function input.blocked()
    if OF.util.optional("djui_is_chatbox_open", false) == true then return true end
    if OF.util.optional("djui_is_playerlist_open", false) == true then return true end
    return false
end

input.DEVICE_HOLD = 12

input.DEVICE_TRAVEL = 8

input.DEVICE_DEAD = 30

input.DEVICE_OFFSCREEN = -100

do

    local device = "none"
    local clock = 0
    local claimedAt = 0

    local anchorX, anchorY = nil, nil

    local function mouse_says(optional)

        local buttons = optional("djui_hud_get_mouse_buttons_down", 0) or 0
        local wheel = optional("djui_hud_get_mouse_scroll_y", 0) or 0
        local hard = buttons ~= 0 or wheel ~= 0

        local x = optional("djui_hud_get_mouse_x", nil)
        local y = optional("djui_hud_get_mouse_y", nil)
        if type(x) ~= "number" or type(y) ~= "number"
            or x < input.DEVICE_OFFSCREEN or y < input.DEVICE_OFFSCREEN then
            anchorX, anchorY = nil, nil
            return hard and "hard" or nil
        end

        if anchorX == nil then
            anchorX, anchorY = x, y
            return hard and "hard" or nil
        end

        local travelled =
            math.abs(x - anchorX) + math.abs(y - anchorY) >= input.DEVICE_TRAVEL
        if travelled then

            anchorX, anchorY = x, y
        end

        if hard then return "hard" end
        if travelled then return "soft" end
        return nil
    end

    local function pad_says(m)
        if input.pressedMask ~= 0 then return "hard" end
        local controller = m ~= nil and m.controller or nil
        if controller == nil then return nil end
        local x = controller.stickX or 0
        local y = controller.stickY or 0
        if math.abs(x) >= input.DEVICE_DEAD or math.abs(y) >= input.DEVICE_DEAD then

            return "soft"
        end
        return nil
    end

    local lastArbitratedFrame = -1

    function input.arbitrate(m, blocked)
        local stamp = frame_stamp()
        if stamp ~= nil and stamp == lastArbitratedFrame then return device end
        lastArbitratedFrame = stamp

        clock = clock + 1

        local optional = type(OF.util) == "table" and OF.util.optional or nil

        if optional == nil then return device end

        if blocked then
            anchorX, anchorY = nil, nil
            return device
        end

        local mouse = mouse_says(optional)
        local pad = pad_says(m)

        local want = nil
        if mouse == "hard" then want = "mouse"
        elseif pad == "hard" then want = "pad"
        elseif mouse == "soft" then want = "mouse"
        elseif pad == "soft" then want = "pad" end

        if want == nil then return device end

        if want == device then
            claimedAt = clock
            return device
        end
        if device ~= "none" and clock - claimedAt < input.DEVICE_HOLD then
            return device
        end

        device = want
        claimedAt = clock
        return device
    end

    function input.device()
        return device
    end

    function input.mouse_driving()
        return device == "mouse"
    end

    function input.pad_driving()
        return device == "pad"
    end

    function input.forget_device()
        device = "none"
        claimedAt = 0
        anchorX, anchorY = nil, nil
        return true
    end
end

input.KEY_FOR_BUTTON = { A = "L", B = ",", Z = "K", X = "I", Y = "M", L = "LShift", R = "RShift",
    START = "Space" }

function input.key_label(action)
    local hud = OF.hud
    local entry = hud ~= nil and hud.ACTIONS ~= nil and hud.ACTIONS[action] or nil
    local moves = hud ~= nil and type(hud.move_words) == "function"
    if entry == nil then
        entry = input.button_chip(tostring(action))
        if entry == nil then return tostring(action) end
    end
    if moves then
        local word = hud.move_words(entry)
        if word ~= nil then return word end
    end
    return entry.key or entry.pad or tostring(action)
end

function input.prompt_label(action, set)
    if set == nil then
        local hud = OF.hud
        if hud ~= nil and type(hud.glyph_set) == "function" then set = hud.glyph_set()
        else set = input.chip_set() end
    end
    if set == "kbm" then return input.key_label(action) end
    local hud = OF.hud
    local entry = hud ~= nil and hud.ACTIONS ~= nil and hud.ACTIONS[action] or nil
    if entry ~= nil then return entry.padText or entry.pad end
    return tostring(action)
end

input.BUTTON_TOKENS = { A = true, B = true, Z = true, L = true, R = true, X = true, Y = true,
    START = true }
function input.button_chip(button)
    if input.BUTTON_TOKENS[button] ~= true then return nil end
    return { pad = button, key = input.KEY_FOR_BUTTON[button] }
end

function input.button_said(button, set)
    local hud = OF.hud
    local word = hud ~= nil and type(hud.BUTTON_MOVE) == "table" and hud.BUTTON_MOVE[button] or nil
    if word ~= nil then
        if OF.lang ~= nil and type(OF.lang.t) == "function" then word = OF.lang.t(word) end

        if set == "none" then word = button .. " " .. word end
    elseif set == "none" then
        return nil
    else
        word = input.button_word(button, "kbm")
    end
    return "[" .. word .. "]"
end

input.KEY_FOR_C = { ["C-UP"] = "Up", ["C-DOWN"] = "Down", ["C-LEFT"] = "Left",
    ["C-RIGHT"] = "Right" }
function input.button_word(name, set)
    if type(name) ~= "string" or name == "" then return name end
    if set == nil then
        local hud = OF.hud
        if hud ~= nil and type(hud.glyph_set) == "function" then set = hud.glyph_set()
        else set = input.device() == "mouse" and "kbm" or "pad" end
    end
    if set ~= "kbm" then return name end
    local hud = OF.hud
    local move = hud ~= nil and type(hud.BUTTON_MOVE) == "table" and hud.BUTTON_MOVE[name] or nil
    if move ~= nil then
        if OF.lang ~= nil and type(OF.lang.t) == "function" then move = OF.lang.t(move) end
        return move
    end

    return input.KEY_FOR_BUTTON[name] or input.KEY_FOR_C[name] or name
end

input.BUTTON_VERBS = { "Press", "press", "Hold", "hold", "Tap", "tap", "with", "With",
    "Use", "use", "then", "holding", "Holding", "pressing", "Release", "release" }

function input.button_text(text, set)
    if type(text) ~= "string" or text == "" then return text end
    if set == nil then
        local hud = OF.hud
        if hud ~= nil and type(hud.glyph_set) == "function" then set = hud.glyph_set()
        else set = input.device() == "mouse" and "kbm" or "pad" end
    end
    if set ~= "kbm" and set ~= "none" then return text end
    local T = input.BUTTON_TOKENS
    local function said(b) return input.button_said(b, set) end
    text = string.gsub(text, "%f[%w](%u+)( ?%+ ?)(%u+)%f[^%w]", function(a, joint, b)
        if T[a] and T[b] and (said(a) ~= nil or said(b) ~= nil) then
            return (said(a) or a) .. "+" .. (said(b) or b)
        end
        return nil
    end)

    text = string.gsub(text, "%]( ?%+ ?)(%u+)%f[^%w]", function(joint, b)
        local word = T[b] and said(b) or nil
        if word ~= nil then return "]+" .. word end
        return nil
    end)
    for _, verb in ipairs(input.BUTTON_VERBS) do
        text = string.gsub(text, "%f[%a](" .. verb .. " )(%u+)%f[^%w]", function(head, b)
            local word = T[b] and said(b) or nil
            if word ~= nil then return head .. word end
            return nil
        end)
    end

    text = string.gsub(text, "%]( or )(%u+)%f[^%w]", function(joint, b)
        local word = T[b] and said(b) or nil
        if word ~= nil then return "]" .. joint .. word end
        return nil
    end)

    text = string.gsub(text, "%((%u+)%)", function(b)
        return T[b] and said(b) or nil
    end)
    text = string.gsub(text, "%f[^\n%z](%u+)( %- )", function(b, dash)
        local word = T[b] and said(b) or nil
        if word ~= nil then return word .. dash end
        return nil
    end)
    return text
end

function input.device_says(padText, mouseText)
    if padText == nil then return mouseText end
    if mouseText == nil then return padText end
    if input.device() == "pad" then return padText end
    if input.device() == "mouse" then return mouseText end
    if padText == mouseText then return padText end
    return padText .. "   " .. mouseText
end

input.MOUSE_BUTTONS = {}
for _, name in ipairs({ "L_MOUSE_BUTTON", "M_MOUSE_BUTTON", "R_MOUSE_BUTTON" }) do
    local value = _G[name]
    if type(value) == "number" then table.insert(input.MOUSE_BUTTONS, value) end
end

input.mouseDown = 0
input.mousePressedMask = 0

local lastMouseDown = 0
local mouseSeen = false

function input.poll_mouse(blocked)
    local down = 0
    if not blocked then
        down = OF.util.optional("djui_hud_get_mouse_buttons_down", 0)
        if type(down) ~= "number" then down = 0 end
    end

    if not mouseSeen then
        mouseSeen = true
        lastMouseDown = down
    end

    input.mousePressedMask = 0
    for _, button in ipairs(input.MOUSE_BUTTONS) do
        if OF.util.has_flag(down, button)
            and not OF.util.has_flag(lastMouseDown, button) then
            input.mousePressedMask = input.mousePressedMask + button
        end
    end

    input.mouseDown = down
    lastMouseDown = down
    return input.mousePressedMask
end

function input.mouse_pressed(button)
    if button == nil then return false end
    return OF.util.has_flag(input.mousePressedMask, button)
end

function input.mouse_held(button)
    if button == nil then return false end
    return OF.util.has_flag(input.mouseDown, button)
end

function input.mouse_busy()
    return input.mouseDown ~= 0
end

function input.forget_mouse()
    input.mouseDown = 0
    input.mousePressedMask = 0
    lastMouseDown = 0
    mouseSeen = false
    return true
end

function input.arrows_are_keys(m)
    if m == nil or m.controller == nil then return false end
    local x = m.controller.extStickX or 0
    local y = m.controller.extStickY or 0
    return math.abs(x) < input.DEVICE_DEAD and math.abs(y) < input.DEVICE_DEAD
end

input.ARROW_BUTTONS = {
    up    = U_CBUTTONS,
    down  = D_CBUTTONS,
    left  = L_CBUTTONS,
    right = R_CBUTTONS,
}

function input.poll(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local stamp = frame_stamp()
    if stamp ~= nil and stamp == lastPolledFrame then return end
    lastPolledFrame = stamp

    local blocked = input.blocked()

    local down = m.controller.buttonDown or 0
    if blocked then down = 0 end
    input.down = down
    input.watch_drift(m.controller.stickX or 0, m.controller.stickY or 0)

    input.pressedMask = 0
    input.releasedMask = 0

    for _, button in ipairs(WATCHED) do
        local isDown = OF.util.has_flag(down, button)
        local wasDown = OF.util.has_flag(input.lastDown, button)

        if isDown and not wasDown then
            input.pressedMask = input.pressedMask + button
            holdFrames[button] = 0
            repeatDue[button] = input.REPEAT_DELAY
        elseif isDown then
            holdFrames[button] = (holdFrames[button] or 0) + 1
            repeatDue[button] = (repeatDue[button] or input.REPEAT_DELAY) - 1
        elseif wasDown then

            if not blocked then
                input.releasedMask = input.releasedMask + button
            end
            holdFrames[button] = nil
            repeatDue[button] = nil
        end
    end

    input.lastDown = down

    input.arbitrate(m, blocked)

    input.poll_mouse(blocked)
end

function input.pressed(button)
    return OF.util.has_flag(input.pressedMask, button)
end

function input.held(button)
    return OF.util.has_flag(input.down, button)
end

function input.released(button)
    return OF.util.has_flag(input.releasedMask, button)
end

function input.repeated(button)
    if input.pressed(button) then return true end
    if not input.held(button) then return false end
    if (repeatDue[button] or 1) > 0 then return false end
    repeatDue[button] = input.REPEAT_INTERVAL
    return true
end

input.DRIFT_FRAMES = 90
input.DRIFT_MOST = 50
input.DRIFT_TWITCH = 3
input.MENU_STICK_DEAD = 30
input.drift = { x = 0, y = 0 }
local driftWas, driftStill = nil, 0

function input.watch_drift(x, y)
    x, y = tonumber(x) or 0, tonumber(y) or 0
    if math.abs(x) < 8 and math.abs(y) < 8 then
        input.drift.x, input.drift.y = 0, 0
        driftWas, driftStill = { x = x, y = y }, 0
        return
    end
    if driftWas ~= nil and math.abs(x - driftWas.x) <= input.DRIFT_TWITCH
        and math.abs(y - driftWas.y) <= input.DRIFT_TWITCH then
        driftStill = driftStill + 1
    else
        driftStill = 0
        driftWas = { x = x, y = y }
    end
    if driftStill >= input.DRIFT_FRAMES and math.abs(x) <= input.DRIFT_MOST
        and math.abs(y) <= input.DRIFT_MOST then
        input.drift.x, input.drift.y = driftWas.x, driftWas.y
    end
end

function input.menu_stick(m)
    local c = m ~= nil and m.controller or nil
    local x = c ~= nil and (c.stickX or 0) or 0
    local y = c ~= nil and (c.stickY or 0) or 0
    return x - input.drift.x, y - input.drift.y
end

local stickDue = 0
local stickWasNeutral = true

function input.stick_step(m)
    local _, y = input.menu_stick(m)
    local neutral = math.abs(y) < input.MENU_STICK_DEAD

    if neutral then
        stickWasNeutral = true
        stickDue = 0
        return 0
    end

    local step = 0
    if y > 0 then step = -1 else step = 1 end

    if stickWasNeutral then
        stickWasNeutral = false
        stickDue = input.REPEAT_DELAY
        return step
    end

    stickDue = stickDue - 1
    if stickDue > 0 then return 0 end
    stickDue = input.REPEAT_INTERVAL
    return step
end

local function without(value, button)
    if not OF.util.has_flag(value, button) then return value end
    return value - button
end

function input.take(m, button)
    if m == nil or m.controller == nil or button == nil then return end
    m.controller.buttonDown = without(m.controller.buttonDown or 0, button)
    m.controller.buttonPressed = without(m.controller.buttonPressed or 0, button)
end

function input.freeze(m)
    if m == nil then return end

    input.poll(m)

    if OF.util.asks(OF.mapvote, "reads_pad") and OF.mapvote.reads_pad() then return end
    m.controller.stickX = 0
    m.controller.stickY = 0
    m.controller.stickMag = 0
    m.controller.buttonDown = 0
    m.controller.buttonPressed = 0
end

function input.hold(m)
    if m == nil then return end
    input.freeze(m)
    m.vel.x = 0
    m.vel.z = 0
    m.forwardVel = 0
end

input.CAMERA_BUTTONS = { U_CBUTTONS, D_CBUTTONS, L_CBUTTONS, R_CBUTTONS }

input.PANEL_BUTTONS = {
    A_BUTTON, B_BUTTON, Z_TRIG, START_BUTTON,
    U_JPAD, D_JPAD, L_JPAD, R_JPAD,
    L_TRIG, R_TRIG,
}

if Y_BUTTON ~= nil then table.insert(input.PANEL_BUTTONS, Y_BUTTON) end

input.WATCHED = WATCHED

function input.claim(m, buttons, stop)
    if m == nil or m.controller == nil then return false end

    for _, button in ipairs(buttons or {}) do
        input.take(m, button)
    end

    if not stop then return true end

    m.controller.stickX = 0
    m.controller.stickY = 0
    m.controller.stickMag = 0

    if stop == "dead" then
        m.vel.x = 0
        m.vel.z = 0
        m.forwardVel = 0
    end
    return true
end

function input.claim_camera(m)
    if m == nil or m.controller == nil then return false end
    m.controller.extStickX = 0
    m.controller.extStickY = 0
    for _, button in ipairs(input.CAMERA_BUTTONS) do
        input.take(m, button)
    end
    return true
end

input.MOVE_BUTTONS = { A_BUTTON, B_BUTTON, Z_TRIG }

function input.lock_movement(m)
    if m == nil or m.controller == nil then return false end
    for _, button in ipairs(input.MOVE_BUTTONS) do
        input.take(m, button)
    end
    m.controller.stickX = 0
    m.controller.stickY = 0
    m.controller.stickMag = 0
    if m.vel ~= nil then
        m.vel.x = 0
        m.vel.z = 0
    end
    m.forwardVel = 0
    return true
end

local mouseHeldBy = {}

function input.hold_mouse(holder, on)
    if holder == nil then return false end
    if on then
        if mouseHeldBy[holder] then return true end
        local look = OF.util.lend_mouse_look(holder)
        local hud = OF.util.lend_hud_mouse(holder)
        if not look and not hud then return false end
        mouseHeldBy[holder] = { look = look, hud = hud }
        return true
    end
    local held = mouseHeldBy[holder]
    if held == nil then return false end
    mouseHeldBy[holder] = nil
    if held.look then OF.util.return_mouse_look(holder) end
    if held.hud then OF.util.return_hud_mouse(holder) end
    return true
end

function input.holds_mouse(holder)
    return mouseHeldBy[holder] ~= nil
end

function input.forget_mouse_holds()
    mouseHeldBy = {}
    return true
end

local function setting(key, kind, fallback)
    local settings = OF.settings
    if type(settings) ~= "table" then return fallback end
    local value = settings[key]
    if type(value) ~= kind then return fallback end
    return value
end

local function remember(key, value)
    if type(OF.settings) == "table" then OF.settings[key] = value end
    if type(value) == "boolean" then
        if mod_storage_save_bool ~= nil then mod_storage_save_bool("set_" .. key, value) end
    else
        if mod_storage_save_integer ~= nil then mod_storage_save_integer("set_" .. key, value) end
    end
end

input.OPEN_BUTTONS = {
    { name = "D-pad down",  key = "End",       button = D_JPAD },
    { name = "D-pad up",    key = "Home",      button = U_JPAD },
    { name = "D-pad right", key = "Page Down", button = R_JPAD },
}

function input.opener()
    local index = setting("panelOpener", "number", 1)
    local entry = input.OPEN_BUTTONS[index] or input.OPEN_BUTTONS[1]
    return entry.button
end

function input.opener_name()
    local index = setting("panelOpener", "number", 1)
    local entry = input.OPEN_BUTTONS[index] or input.OPEN_BUTTONS[1]
    return entry.name
end

function input.opener_key()
    local index = setting("panelOpener", "number", 1)
    local entry = input.OPEN_BUTTONS[index] or input.OPEN_BUTTONS[1]
    return entry.key
end

function input.step_opener()
    local index = setting("panelOpener", "number", 1) + 1
    if index > #input.OPEN_BUTTONS then index = 1 end
    remember("panelOpener", index)
    return true
end

input.WHEEL_BUTTONS = input.OPEN_BUTTONS

function input.wheel_choices()
    local opener = input.opener()
    local free = {}
    for _, entry in ipairs(input.WHEEL_BUTTONS) do
        if entry.button ~= opener then free[#free + 1] = entry end
    end
    return free
end

local function wheel_entry()
    local free = input.wheel_choices()
    if #free == 0 then return nil end
    local index = setting("emoteWheel", "number", 1)
    if index < 1 or index > #free then index = 1 end
    return free[index]
end

function input.wheel_button()
    local entry = wheel_entry()
    if entry == nil then return nil end
    return entry.button
end

function input.wheel_button_name()
    local entry = wheel_entry()
    if entry == nil then return nil end
    return entry.name
end

function input.wheel_button_key()
    local entry = wheel_entry()
    if entry == nil then return nil end
    return entry.key
end

function input.step_wheel()
    local free = input.wheel_choices()
    if #free == 0 then return false end
    local index = setting("emoteWheel", "number", 1) + 1
    if index > #free then index = 1 end
    remember("emoteWheel", index)
    return true
end

local FORGE_SCALES = { 0.25, 0.5, 1.0, 1.5, 2.0 }
local FORGE_DEFAULT = 3

function input.forge_scale()
    local index = setting("forgeSense", "number", FORGE_DEFAULT)
    return FORGE_SCALES[index] or FORGE_SCALES[FORGE_DEFAULT]
end

function input.forge_scale_index()
    local index = setting("forgeSense", "number", FORGE_DEFAULT)
    if FORGE_SCALES[index] == nil then return FORGE_DEFAULT end
    return index
end

function input.forge_scale_count()
    return #FORGE_SCALES
end

function input.step_forge_scale()
    local index = input.forge_scale_index() + 1
    if index > #FORGE_SCALES then index = 1 end
    remember("forgeSense", index)
    return true
end

function input.forge_inverts_pitch()
    return setting("forgeInvertPitch", "boolean", false)
end

function input.toggle_forge_invert_pitch()
    remember("forgeInvertPitch", not input.forge_inverts_pitch())
    return true
end

function input.forge_pitch(value)
    if input.forge_inverts_pitch() then return -value end
    return value
end

input.FORGE_CAMERA = { "chord", "holding", "off" }

function input.forge_camera()
    local index = setting("forgeCamera", "number", 1)
    return input.FORGE_CAMERA[index] or input.FORGE_CAMERA[1]
end

function input.step_forge_camera()
    local index = setting("forgeCamera", "number", 1) + 1
    if index > #input.FORGE_CAMERA then index = 1 end
    remember("forgeCamera", index)
    return true
end

function input.panel_stop()
    if setting("stopDeadWhileOpen", "boolean", false) then return "dead" end
    return true
end

function input.toggle_panel_stop_dead()
    remember("stopDeadWhileOpen", not setting("stopDeadWhileOpen", "boolean", false))
    return true
end

local turboAge = {}

local function turbo_mask()
    local settings = OF.settings
    if type(settings) ~= "table" then return 0 end
    local mask = settings.turboMask
    if type(mask) ~= "number" then return 0 end
    local offered = 0
    for _, entry in ipairs(input.TURBO_BUTTONS or {}) do
        if OF.util.has_flag(mask, entry.button) then offered = offered + entry.button end
    end
    return offered
end

local TURBO_FASTEST = 1
local TURBO_SLOWEST = 8

local function turbo_rate()
    local settings = OF.settings
    local rate = type(settings) == "table" and settings.turboRate or nil
    if type(rate) ~= "number" or rate < TURBO_FASTEST then return 4 end
    return rate
end

function input.turbo(m)
    if m == nil or m.playerIndex ~= 0 or m.controller == nil then return 0 end
    local mask = turbo_mask()
    if mask == 0 then return 0 end

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return 0
    end

    if OF.util.optional("djui_is_chatbox_open", false) == true then return 0 end
    if OF.util.menu_has_screen() then return 0 end

    local rate = turbo_rate()
    local fired = 0
    for _, button in ipairs(WATCHED) do
        if OF.util.has_flag(mask, button) then
            if OF.util.has_flag(m.controller.buttonDown or 0, button) then
                local age = (turboAge[button] or 0) + 1
                if age >= rate then
                    age = 0

                    local pressed = m.controller.buttonPressed or 0
                    if not OF.util.has_flag(pressed, button) then
                        m.controller.buttonPressed = pressed + button
                    end
                    fired = fired + 1
                end
                turboAge[button] = age
            else
                turboAge[button] = nil
            end
        end
    end
    return fired
end

input.SPACE_JUMP_MODES = { shooter = true, oitc = true, rocketarena = true, shellbattle = true,
    bounty = true }
input.kbm = { seen = false, on = false, told = false }

input.KBM_SNAPS = 2
function input.kbm_step(m)
    local c = m ~= nil and m.controller or nil
    if c == nil then return input.kbm.seen end
    local ex, ey = c.extStickX or 0, c.extStickY or 0
    local rx, ry = c.rawStickX or 0, c.rawStickY or 0
    local function between(v) return math.abs(v) > input.DEVICE_DEAD and v ~= 127 and v ~= -128 end
    local function stop(v) return v == 127 or v == -128 end
    local wasRest = (input.kbm.lastRx or 0) == 0 and (input.kbm.lastRy or 0) == 0
    input.kbm.lastRx, input.kbm.lastRy = rx, ry
    if math.abs(ex) >= input.DEVICE_DEAD or math.abs(ey) >= input.DEVICE_DEAD
        or between(rx) or between(ry) then
        input.kbm.seen = false
        input.kbm.snaps = 0
    elseif type(input.device) == "function" and input.device() == "mouse" then
        input.kbm.seen = true
    elseif wasRest and (stop(rx) or stop(ry)) then
        input.kbm.snaps = (input.kbm.snaps or 0) + 1
        if input.kbm.snaps >= input.KBM_SNAPS then input.kbm.seen = true end
    end
    return input.kbm.seen
end

input.chipSet = "none"
function input.chip_set()
    local want = nil
    if input.kbm.seen then want = "kbm"
    else
        local device = input.device()
        if device == "pad" then want = "pad" elseif device == "mouse" then want = "kbm" end
    end
    if want ~= nil then input.chipSet = want end
    return input.chipSet
end

function input.space_jumps()
    local gm = OF.gamemodes
    if gm == nil or type(gm.is_running) ~= "function" or not gm.is_running() then return false end
    local mode = type(gm.current) == "function" and gm.current() or nil
    if mode == nil or input.SPACE_JUMP_MODES[mode.key] ~= true then return false end
    return input.kbm.seen == true
end

function input.shooter_keys(m)
    if m == nil or m.playerIndex ~= 0 or m.controller == nil then return false end
    input.poll(m)
    input.kbm_step(m)
    local on = input.space_jumps()
    if not on then
        input.kbm.on, input.kbm.told = false, false
        return false
    end
    input.kbm.on = true
    if input.blocked() or OF.util.menu_has_screen() then return false end
    if not input.kbm.told then
        input.kbm.told = true
        if OF.util.asks(OF.notify, "show") then OF.notify.show(OF.lang.t("Space jumps this round - middle mouse pauses"), "info", 4) end
    end
    local c = m.controller
    local down, pressed = c.buttonDown or 0, c.buttonPressed or 0
    if OF.util.has_flag(down, START_BUTTON) then
        down = down - START_BUTTON
        if not OF.util.has_flag(down, A_BUTTON) then down = down + A_BUTTON end
    end
    if OF.util.has_flag(pressed, START_BUTTON) then
        pressed = pressed - START_BUTTON
        if not OF.util.has_flag(pressed, A_BUTTON) then pressed = pressed + A_BUTTON end
    end
    if M_MOUSE_BUTTON ~= nil and input.mouse_pressed(M_MOUSE_BUTTON) then
        if not OF.util.has_flag(down, START_BUTTON) then down = down + START_BUTTON end
        if not OF.util.has_flag(pressed, START_BUTTON) then pressed = pressed + START_BUTTON end
    end
    c.buttonDown, c.buttonPressed = down, pressed
    return true
end

input.TURBO_BUTTONS = {
    { name = "A", button = A_BUTTON },
    { name = "B", button = B_BUTTON },
}

function input.turbo_on(button)
    return OF.util.has_flag(turbo_mask(), button)
end

function input.turbo_toggle(button)
    if type(OF.settings) ~= "table" or button == nil then return false end
    local mask = turbo_mask()
    if OF.util.has_flag(mask, button) then
        mask = mask - button
    else
        mask = mask + button
    end
    OF.settings.turboMask = mask
    if mod_storage_save_number ~= nil then mod_storage_save_number("set_turboMask", mask) end
    return true
end

function input.reset_mine()
    if type(OF.settings) ~= "table" or (turbo_mask() or 0) == 0 then return false end
    OF.settings.turboMask = 0
    if mod_storage_save_number ~= nil then mod_storage_save_number("set_turboMask", 0) end
    return true
end

function input.turbo_step_rate()
    if type(OF.settings) ~= "table" then return false end
    local rate = turbo_rate() - 1
    if rate < TURBO_FASTEST then rate = TURBO_SLOWEST end
    OF.settings.turboRate = rate
    if mod_storage_save_number ~= nil then mod_storage_save_number("set_turboRate", rate) end
    return true
end

function input.turbo_rate()
    return turbo_rate()
end

input.AIM_BUTTON = L_TRIG
input.AIM_TAKES = { B_BUTTON }

local aimClaimed = {}
local aimWasDown = 0
local aimTookAt = -1
local aimTook = 0

local AIM_B_ONLY = { [B_BUTTON] = true }
local AIM_NONE = {}
local AIM_ALL = {}
for _, button in ipairs(input.AIM_TAKES) do AIM_ALL[button] = true end

function input.aim_buttons()
    if OF.util.asks(OF.shooter, "weapon_of") then
        local ok, shape = pcall(OF.shooter.weapon_of, 0)
        if ok and shape ~= nil then return AIM_ALL end
    end
    if OF.util.asks(OF.murder, "sheriff_aims") then
        local ok, aims = pcall(OF.murder.sheriff_aims)
        if ok and aims then return AIM_B_ONLY end
    end
    return AIM_NONE
end

function input.aim_held(m, button)
    if m ~= nil and m.controller ~= nil
        and OF.util.has_flag(m.controller.buttonDown or 0, button) then
        return true
    end
    local now = frame_stamp()
    if now == nil or aimTookAt == nil then return false end
    local age = now - aimTookAt
    return age >= 0 and age <= 1 and OF.util.has_flag(aimTook, button)
end

function input.aim_layer(m)
    if m == nil or m.playerIndex ~= 0 or m.controller == nil then return 0 end
    local down = m.controller.buttonDown or 0
    local takes = input.aim_buttons()
    local aiming = next(takes) ~= nil
        and OF.util.has_flag(down, input.AIM_BUTTON)
    local took = 0
    for _, button in ipairs(input.AIM_TAKES) do
        if OF.util.has_flag(down, button) then
            local fresh = not OF.util.has_flag(aimWasDown, button)
            if fresh and aiming and takes[button] then aimClaimed[button] = true end
            if aimClaimed[button] then
                input.take(m, button)
                took = took + button
            end
        else
            aimClaimed[button] = nil
        end
    end
    aimWasDown = down
    aimTookAt = frame_stamp()
    aimTook = took
    return took
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    input.poll(m)
    input.turbo(m)
    input.aim_layer(m)
end)

OF.sounds = OF.sounds or {}

OF.sounds.MOVE   = SOUND_MENU_CHANGE_SELECT
OF.sounds.PICK   = SOUND_MENU_CLICK_FILE_SELECT
OF.sounds.BACK   = SOUND_MENU_CAMERA_ZOOM_OUT
OF.sounds.OPEN   = SOUND_MENU_PAUSE
OF.sounds.CLOSE  = SOUND_MENU_REVERSE_PAUSE
OF.sounds.TAB    = SOUND_MENU_CAMERA_ZOOM_IN
OF.sounds.DENIED = SOUND_MENU_CAMERA_BUZZ
OF.sounds.TICK   = SOUND_MENU_MESSAGE_APPEAR

OF.sounds.COUNT = SOUND_GENERAL_COIN
OF.sounds.GO    = SOUND_MENU_STAR_SOUND_LETS_A_GO

OF.sounds.WARN  = SOUND_GENERAL_ENEMY_ALERT1

OF.sounds.SHOT       = SOUND_GENERAL_RACE_GUN_SHOT
OF.sounds.CLOCK      = SOUND_GENERAL2_SWITCH_TICK_FAST
OF.sounds.CLOCK_LAST = SOUND_GENERAL2_SWITCH_TICK_SLOW
OF.sounds.FINISH     = SOUND_GENERAL_RACE_GUN_SHOT
OF.sounds.POOF       = SOUND_OBJ_DEFAULT_DEATH
OF.sounds.CAUGHT     = SOUND_MENU_CAMERA_BUZZ
OF.sounds.GOT_ONE    = SOUND_GENERAL2_RIGHT_ANSWER
OF.sounds.CHIME      = SOUND_MENU_COLLECT_SECRET

OF.sounds.BEST       = SOUND_GENERAL2_RIGHT_ANSWER
OF.sounds.RECORD     = SOUND_GENERAL2_STAR_APPEARS

local lastFrame, lastIds = -1, {}

function OF.sounds.fresh(sound)
    if OF.sounds.dedupe == false or get_global_timer == nil then return true end
    local now = get_global_timer()
    if now ~= lastFrame then
        lastFrame, lastIds = now, {}
    end
    if lastIds[sound] then return false end
    lastIds[sound] = true
    return true
end

function OF.sounds.play(sound)
    if sound == nil then return end
    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return end
    if not OF.sounds.fresh(sound) then return end
    play_sound(sound, m.marioObj.header.gfx.cameraToObject)
end

function OF.sounds.play_from(obj, sound)
    if sound == nil then return end
    local gfx = obj ~= nil and obj.header ~= nil and obj.header.gfx or nil
    if gfx == nil or gfx.cameraToObject == nil then
        OF.sounds.play(sound)
        return
    end
    if not OF.sounds.fresh(sound) then return end
    play_sound(sound, gfx.cameraToObject)
end

local LADDER_STEPS = 8

function OF.sounds.ladder(step)
    if type(step) ~= "number" then step = 1 end
    step = math.floor(OF.util.clamp(step, 1, LADDER_STEPS))
    OF.sounds.play(SOUND_MENU_COLLECT_RED_COIN + ((LADDER_STEPS - step) << 16))
end

local VOICE_LINES = {

    { key = "hello",    name = "Hello",              char = "CHAR_SOUND_HELLO" },
    { key = "okey",     name = "Okey-dokey",         char = "CHAR_SOUND_OKEY_DOKEY" },
    { key = "letsgo",   name = "Let's-a go",         char = "CHAR_SOUND_LETS_A_GO" },
    { key = "herewego", name = "Here we go",         char = "CHAR_SOUND_HERE_WE_GO" },
    { key = "yahoo",    name = "Yahoo",              char = "CHAR_SOUND_YAHOO" },
    { key = "yippee",   name = "Yippee",             char = "CHAR_SOUND_YAHOO_WAHA_YIPPEE" },
    { key = "laugh",    name = "Laugh",              char = "CHAR_SOUND_HAHA" },
    { key = "mamamia",  name = "Mamma mia",          char = "CHAR_SOUND_MAMA_MIA" },
    { key = "doh",      name = "Doh",                char = "CHAR_SOUND_DOH" },
    { key = "solong",   name = "So long-a Bowser",   char = "CHAR_SOUND_SO_LONGA_BOWSER" },
    { key = "tired",    name = "I'm-a tired",        char = "CHAR_SOUND_IMA_TIRED" },
    { key = "gameover", name = "Game over",          char = "CHAR_SOUND_GAME_OVER" },
    { key = "yawn",     name = "Yawn",               char = "CHAR_SOUND_YAWNING" },
    { key = "snore",    name = "Snore",              char = "CHAR_SOUND_SNORING3" },
    { key = "press",    name = "Press start to play", char = "CHAR_SOUND_PRESS_START_TO_PLAY" },
    { key = "punch",    name = "Punch",              char = "CHAR_SOUND_PUNCH_YAH" },
    { key = "pound",    name = "Ground pound",       char = "CHAR_SOUND_GROUND_POUND_WAH" },
    { key = "twirl",    name = "Twirl",              char = "CHAR_SOUND_TWIRL_BOUNCE" },

    { key = "itsame",   name = "It's-a me",          sound = "SOUND_MENU_COIN_ITS_A_ME_MARIO" },
    { key = "thankyou", name = "Thank you",          sound = "SOUND_MENU_THANK_YOU_PLAYING_MY_GAME" },
    { key = "peach",    name = "Peach thanks you",   sound = "SOUND_PEACH_THANK_YOU_MARIO" },
    { key = "dear",     name = "Dear Mario",         sound = "SOUND_PEACH_DEAR_MARIO" },
    { key = "stars",    name = "Power of the stars", sound = "SOUND_PEACH_POWER_OF_THE_STARS" },
    { key = "cake",     name = "Bake a cake",        sound = "SOUND_PEACH_BAKE_A_CAKE" },
    { key = "bowser",   name = "Bowser laughs",      sound = "SOUND_MENU_BOWSER_LAUGH" },
    { key = "roar",     name = "Bowser roars",       sound = "SOUND_OBJ2_BOWSER_ROAR" },
    { key = "boo",      name = "Boo laughs",         sound = "SOUND_OBJ_BOO_LAUGH_LONG" },
    { key = "koopa",    name = "Koopa talks",        sound = "SOUND_OBJ_KOOPA_TALK" },
    { key = "bobomb",   name = "Bob-omb talks",      sound = "SOUND_OBJ_BOBOMB_BUDDY_TALK" },
    { key = "king",     name = "King Bob-omb talks", sound = "SOUND_OBJ_KING_BOBOMB_TALK" },
    { key = "yoshi",    name = "Yoshi talks",        sound = "SOUND_GENERAL_YOSHI_TALK" },
    { key = "ukiki",    name = "Ukiki chatters",     sound = "SOUND_OBJ_UKIKI_CHATTER_LONG" },
    { key = "wiggler",  name = "Wiggler talks",      sound = "SOUND_OBJ_WIGGLER_TALK" },
    { key = "penguin",  name = "Penguin yells",      sound = "SOUND_OBJ_BIG_PENGUIN_YELL" },
    { key = "grunt",    name = "Boss grunts",        sound = "SOUND_OBJ2_BOSS_DIALOG_GRUNT" },
}

OF.sounds.VOICES = {}
OF.sounds.VOICE_ORDER = {}

for _, line in ipairs(VOICE_LINES) do
    local constant = line.char or line.sound
    local value = _G[constant]
    if type(value) == "number" and OF.sounds.VOICES[line.key] == nil then
        local entry = {
            key = line.key,
            name = line.name,
            constant = constant,
            char = line.char ~= nil and value or nil,
            sound = line.sound ~= nil and value or nil,
        }
        OF.sounds.VOICES[line.key] = entry
        table.insert(OF.sounds.VOICE_ORDER, entry)
    end
end

function OF.sounds.voice_count()
    return #OF.sounds.VOICE_ORDER
end

function OF.sounds.voice_name(key)
    local entry = OF.sounds.VOICES[key]
    if entry == nil then return OF.lang.t("Silent") end
    return OF.lang.t(entry.name)
end

OF.sounds.VOICE_GAP = 40
OF.sounds.lastVoiceAt = nil

function OF.sounds.say(key, m, force)
    local entry = OF.sounds.VOICES[key]
    if entry == nil then return false end

    local now = OF.util.optional("get_global_timer", 0) or 0
    if not force and OF.sounds.lastVoiceAt ~= nil
        and now - OF.sounds.lastVoiceAt < OF.sounds.VOICE_GAP

        and now >= OF.sounds.lastVoiceAt then
        return false
    end

    if m == nil then m = gMarioStates[0] end
    if m == nil or m.marioObj == nil then return false end

    OF.sounds.lastVoiceAt = now

    if entry.char ~= nil then
        local play = OF.util.binding("play_character_sound")
        if play == nil then return false end
        play(m, entry.char)
        return true
    end

    play_sound(entry.sound, m.marioObj.header.gfx.cameraToObject)
    return true
end

function OF.sounds.say_one_of(keys, m)
    if type(keys) ~= "table" or #keys == 0 then return false end

    local pool = keys
    if #keys > 1 and OF.sounds.lastVoiceKey ~= nil then
        pool = {}
        for _, key in ipairs(keys) do
            if key ~= OF.sounds.lastVoiceKey then table.insert(pool, key) end
        end
        if #pool == 0 then pool = keys end
    end

    local pick = pool[math.random(1, #pool)]
    OF.sounds.lastVoiceKey = pick
    return OF.sounds.say(pick, m)
end
