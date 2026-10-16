OF = OF or {}
OF.modmenu = OF.modmenu or {}
OF.settings = OF.settings or {}

OF.VERSION = OF.VERSION or "?"
local SETTING_PREFIX = "set_"
local function load_bool(key, default)
    return mod_storage_load_bool(SETTING_PREFIX .. key, default)
end

local function save_bool(key, value)
    OF.util.store_bool(SETTING_PREFIX .. key, value)
end

OF.settings.showBanner      = load_bool("showBanner", true)
OF.settings.announceJoins   = load_bool("announceJoins", true)

local BANNER_MIN, BANNER_MAX, BANNER_DEFAULT = 2, 15, 6
OF.modmenu.BANNER_MIN     = BANNER_MIN
OF.modmenu.BANNER_MAX     = BANNER_MAX
OF.modmenu.BANNER_DEFAULT = BANNER_DEFAULT

OF.settings.bannerSeconds   = mod_storage_load_integer(SETTING_PREFIX .. "bannerSeconds", BANNER_DEFAULT)
if OF.settings.bannerSeconds < BANNER_MIN then OF.settings.bannerSeconds = BANNER_DEFAULT end
OF.settings.screenMessage   = mod_storage_load(SETTING_PREFIX .. "screenMessage", "")

OF.settings.allowSaveEdits  = load_bool("allowSaveEdits", true)

OF.settings.teamColours     = load_bool("teamColours", true)

OF.settings.turboMask = mod_storage_load_integer(SETTING_PREFIX .. "turboMask", 0)
OF.settings.turboRate = mod_storage_load_integer(SETTING_PREFIX .. "turboRate", 4)
if OF.settings.turboRate < 2 then OF.settings.turboRate = 4 end

OF.settings.panelOpener        = mod_storage_load_integer(SETTING_PREFIX .. "panelOpener", 1)
OF.settings.forgeSense         = mod_storage_load_integer(SETTING_PREFIX .. "forgeSense", 3)
OF.settings.forgeCamera        = mod_storage_load_integer(SETTING_PREFIX .. "forgeCamera", 1)
OF.settings.forgeInvertPitch   = load_bool("forgeInvertPitch", false)
OF.settings.stopDeadWhileOpen  = load_bool("stopDeadWhileOpen", false)

OF.settings.markers         = load_bool("markers", true)

OF.settings.overheadTags    = load_bool("overheadTags", true)

OF.settings.markerLooks = {}
if type(OF.markers) == "table" and type(OF.markers.looks) == "function" then
    local ok, list = pcall(OF.markers.looks)
    if ok and type(list) == "table" then
        for _, look in ipairs(list) do
            OF.settings.markerLooks[look.key] =
                load_bool("marker_" .. look.key, look.default ~= false)
        end
    end
end

function OF.settings.set_marker_look(key, value)
    OF.settings.markerLooks[key] = value
    save_bool("marker_" .. key, value)
end

OF.settings.showCredits     = load_bool("showCredits", true)

OF.settings.fanfares        = load_bool("fanfares", true)

OF.settings.negativeEyes    = load_bool("negativeEyes", false)

OF.settings.steadyCamera    = load_bool("steadyCamera", false)

function OF.settings.set_markers(value)
    OF.settings.markers = value
    save_bool("markers", value)
end

function OF.settings.set_overhead_tags(value)
    OF.settings.overheadTags = value
    save_bool("overheadTags", value)
end

function OF.settings.set_fanfares(value)
    OF.settings.fanfares = value
    save_bool("fanfares", value)
end

function OF.settings.set_steady_camera(value)
    OF.settings.steadyCamera = value
    save_bool("steadyCamera", value)
end

function OF.settings.set_negative_eyes(value)
    OF.settings.negativeEyes = value
    save_bool("negativeEyes", value)
end

function OF.settings.set_team_colours(value)
    OF.settings.teamColours = value
    save_bool("teamColours", value)
end

OF.util = OF.util or {}
OF.util.missing = OF.util.missing or {}

OF.modmenu.element = OF.modmenu.element or {}

local function remember_element(key, index)
    if type(index) == "number" then OF.modmenu.element[key] = index end
end

local function push_element(binding, key, value)
    local index = OF.modmenu.element[key]
    if index == nil then return false end
    local fn = _G[binding]
    if type(fn) ~= "function" then
        OF.util.missing[binding] = true
        return false
    end
    return (pcall(fn, index, value))
end

function OF.settings.set_show_banner(value)
    value = value and true or false
    OF.settings.showBanner = value
    save_bool("showBanner", value)
    push_element("update_mod_menu_element_checkbox", "showBanner", value)
    return true
end

function OF.settings.set_announce_joins(value)
    value = value and true or false
    OF.settings.announceJoins = value
    save_bool("announceJoins", value)
    push_element("update_mod_menu_element_checkbox", "announceJoins", value)
    return true
end

function OF.settings.set_banner_seconds(value)
    local seconds = math.floor(tonumber(value) or BANNER_DEFAULT)
    if seconds < BANNER_MIN then seconds = BANNER_MIN end
    if seconds > BANNER_MAX then seconds = BANNER_MAX end
    OF.settings.bannerSeconds = seconds
    OF.util.store_integer(SETTING_PREFIX .. "bannerSeconds", seconds)
    push_element("update_mod_menu_element_slider", "bannerSeconds", seconds)
    return true
end

function OF.settings.reset_screen()
    local S = OF.settings
    local moved = false
    local function bool(key, default, setter)
        if S[key] ~= default then
            if setter ~= nil then setter(default) else
                S[key] = default
                save_bool(key, default)
            end
            moved = true
        end
    end
    bool("showBanner", true, S.set_show_banner)
    bool("announceJoins", true, S.set_announce_joins)
    if S.bannerSeconds ~= BANNER_DEFAULT then
        S.set_banner_seconds(BANNER_DEFAULT)
        moved = true
    end
    bool("markers", true, S.set_markers)
    bool("overheadTags", true, S.set_overhead_tags)
    bool("showCredits", true)
    bool("fanfares", true, S.set_fanfares)
    bool("negativeEyes", false, S.set_negative_eyes)
    bool("steadyCamera", false, S.set_steady_camera)
    bool("forgeInvertPitch", false)
    bool("stopDeadWhileOpen", false)
    if type(OF.markers) == "table" and type(OF.markers.looks) == "function" then
        for _, look in ipairs(OF.markers.looks()) do
            local default = look.default ~= false
            if S.markerLooks[look.key] ~= default then
                S.set_marker_look(look.key, default)
                moved = true
            end
        end
    end
    return moved
end

function OF.settings.set_allow_save_edits(value)
    OF.settings.allowSaveEdits = value
    save_bool("allowSaveEdits", value)
end

OF.util = OF.util or {}
OF.util.missing = OF.util.missing or {}

local function log_press(label, mine)
    if not OF.util.asks(OF.actionlog, "report") then return false end
    return OF.actionlog.report(OF.lang.t("Pause menu") .. ": "
        .. OF.util.plain(tostring(label)), false,
        mine == true and OF.actionlog.KIND_MINE or nil)
end

local function widget(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then
        OF.util.missing[name] = true
        return nil
    end

    local ok, index = pcall(fn, ...)
    if not ok then return nil end
    return index
end

widget("hook_mod_menu_inputbox", "Message", OF.settings.screenMessage, 60, function(index, value)
    OF.settings.screenMessage = value
    OF.util.store(SETTING_PREFIX .. "screenMessage", value)
end)

widget("hook_mod_menu_button", "Send message to everybody", function()
    if not OF.util.allowed("message") then return end

    local message = OF.settings.screenMessage or ""
    if message == "" then

        OF.notify.show("Type the text in the box above first.", "bad", 5)
        return
    end
    log_press("Send message to everybody")
    OF.net.announce(message)
end)

widget("hook_mod_menu_button", "Get me unstuck", function()
    if not OF.util.asks(OF.unstick, "free") then
        OF.notify.show("That part of the mod did not load.", "bad", 5)
        return
    end
    log_press("Get me unstuck", true)
    OF.util.report(OF.unstick.free())
end)

remember_element("showBanner", widget("hook_mod_menu_checkbox", "Welcome banner",
    OF.settings.showBanner, function(index, value)
        log_press("Welcome banner", true)
        OF.settings.set_show_banner(value)
    end))

remember_element("announceJoins", widget("hook_mod_menu_checkbox", "Announce joins and leaves",
    OF.settings.announceJoins, function(index, value)
        log_press("Announce joins and leaves", true)
        OF.settings.set_announce_joins(value)
    end))

remember_element("bannerSeconds", widget("hook_mod_menu_slider", "Banner seconds",
    OF.settings.bannerSeconds, BANNER_MIN, BANNER_MAX, function(index, value)
        log_press("Banner seconds", true)
        OF.settings.set_banner_seconds(value)
    end))

local FRESH_NAME = "Reset everything"
local FRESH_ARMED = "Press again to confirm: reset everything"
local FRESH_FRAMES = 150
local freshArmed = 0

remember_element("hostHold", widget("hook_mod_menu_checkbox", "Freeze the lobby",
    false, function(index, value)

        log_press("Freeze the lobby")

        if not OF.util.is_host() and OF.perms.is_cohost(0) then
            OF.util.report(OF.net.cohost_does(OF.panel.BRAKE_ACTION,
                value and "on" or "off"))
        else
            OF.util.report(OF.lockdown.hold(value, 0))
        end

        local held = OF.lockdown ~= nil and type(OF.lockdown.held_by_host) == "function"
            and OF.lockdown.held_by_host() and true or false
        push_element("update_mod_menu_element_checkbox", "hostHold", held)
    end))

remember_element("freshStart", widget("hook_mod_menu_button", FRESH_NAME,
    function()
        if freshArmed > 0 then
            freshArmed = 0
            push_element("update_mod_menu_element_name", "freshStart", FRESH_NAME)
            log_press(FRESH_NAME)
            OF.util.report(OF.fresh.run())
            return
        end
        freshArmed = FRESH_FRAMES
        push_element("update_mod_menu_element_name", "freshStart", FRESH_ARMED)
        OF.notify.show("Press it again to put the whole lobby back.", "warn", 5)
    end))

local RANK_ONLY = " (host only)"
local GATED = {
    { key = "hostHold",   name = "Freeze the lobby",         feature = "jail" },
    { key = "freshStart", name = FRESH_NAME,               feature = "settings" },
}

local namedAsAllowed = {}

local function may_press(feature)

    if not OF.util.is_host() then
        return feature == "jail" and OF.perms.is_cohost(0)
    end
    if OF.perms == nil or type(OF.perms.can) ~= "function" then return true end
    return OF.perms.can(feature) and true or false
end

local function name_the_rows()
    local wrote = false
    for _, entry in ipairs(GATED) do
        local allowed = may_press(entry.feature)

        local waiting = entry.key == "freshStart" and freshArmed > 0
        if namedAsAllowed[entry.key] ~= allowed and not waiting
            and #entry.name + #RANK_ONLY < 64 then
            namedAsAllowed[entry.key] = allowed
            push_element("update_mod_menu_element_name", entry.key,
                allowed and entry.name or (entry.name .. RANK_ONLY))
            wrote = true
        end
    end
    return wrote
end

OF.modmenu.name_the_rows = name_the_rows

local lastHold = nil
local function watch()
    name_the_rows()
    if freshArmed > 0 then
        freshArmed = freshArmed - 1
        if freshArmed == 0 then
            push_element("update_mod_menu_element_name", "freshStart", FRESH_NAME)
        end
    end

    local held = false
    if OF.lockdown ~= nil and type(OF.lockdown.held_by_host) == "function" then
        held = OF.lockdown.held_by_host() and true or false
    end
    if held ~= lastHold then
        lastHold = held
        push_element("update_mod_menu_element_checkbox", "hostHold", held)
    end
end

hook_event(HOOK_UPDATE, watch)
