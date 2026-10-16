OF = OF or {}
OF.panel = OF.panel or {}

local panel = OF.panel

local FALLBACK_GOLD = { r = 255, g = 255, b = 0 }

local function gold()
    local value = OF.GOLD
    if type(value) ~= "table" or value.r == nil then return FALLBACK_GOLD end
    return value
end

panel.gold = gold

local function highlight()
    local r, g, b = nil, nil, nil
    if OF.util.asks(OF.theme, "highlight") then r, g, b = OF.theme.highlight() end
    if r == nil then
        local value = gold()
        r, g, b = value.r, value.g, value.b
    end

    if panel.skin_on ~= nil and panel.skin_on() and OF.util.asks(OF.hud, "accent_lift") then
        local lifted = OF.hud.accent_lift({ r, g, b })
        return lifted[1], lifted[2], lifted[3]
    end
    return r, g, b
end

panel.highlight_rgb = highlight

function panel.skin_on()
    return OF.util.asks(OF.panelskin, "on") and OF.panelskin.on() == true
end

panel.RESET_ROW = "Reset this page"
panel.RESET_OWN_ROW = "Reset this page, your own boxes only"
panel.open = false
panel.page = "main"
panel.selected = -1
panel.levelMode = "everyone"
panel.runKind = nil
panel.pickMode = "everyone"
panel.aim = "self"
panel.dressGroup = nil

panel.modeKey = nil
panel.group = "Castle"
panel.hatGroup = nil
panel.starCourse = nil

panel.waypoint = 1

panel.modReason = "none"
panel.banLength = "forever"
panel.rankLength = "forever"
panel.scroll = 0
panel.confirm = nil

local CONFIRM_FRAMES = 150
panel.cursor = 1

panel.landed = nil

panel.memory = {}
panel.lastPage = nil

panel.tabPage = {}

local PLACE_KEY = "panel_"
local PLACE_DEFAULT = { x = 50, y = 50, w = 70, h = 85 }

panel.place = {
    x = mod_storage_load_integer(PLACE_KEY .. "x", PLACE_DEFAULT.x),
    y = mod_storage_load_integer(PLACE_KEY .. "y", PLACE_DEFAULT.y),
    w = mod_storage_load_integer(PLACE_KEY .. "w", PLACE_DEFAULT.w),
    h = mod_storage_load_integer(PLACE_KEY .. "h", PLACE_DEFAULT.h),
}

panel.PLACE_LIMITS = {
    x = { min = 0,  max = 100, step = 5 },
    y = { min = 0,  max = 100, step = 5 },
    w = { min = 45, max = 100, step = 5 },
    h = { min = 45, max = 100, step = 5 },
}

for which, limit in pairs(panel.PLACE_LIMITS) do
    local stored = math.floor(tonumber(panel.place[which]) or PLACE_DEFAULT[which])
    panel.place[which] = math.max(limit.min, math.min(limit.max, stored))
end

function panel.place_steps(which)
    local limit = panel.PLACE_LIMITS[which]
    if limit == nil then return 0 end
    return math.floor((limit.max - limit.min) / limit.step)
end

function panel.place_step(which)
    local limit = panel.PLACE_LIMITS[which]
    if limit == nil then return 0 end
    return math.floor((panel.place[which] - limit.min) / limit.step + 0.5)
end

function panel.set_place(which, percent)
    local limit = panel.PLACE_LIMITS[which]
    if limit == nil then return false, "The menu has no such measurement." end
    local wanted = OF.util.clamp(math.floor(tonumber(percent) or 0),
        limit.min, limit.max)
    panel.place[which] = wanted
    OF.util.store_integer(PLACE_KEY .. which, wanted)
    return true
end

function panel.set_place_step(which, step)
    local limit = panel.PLACE_LIMITS[which]
    if limit == nil then return false, "The menu has no such measurement." end
    return panel.set_place(which, limit.min + step * limit.step)
end

function panel.reset_place()
    for which, value in pairs(PLACE_DEFAULT) do
        OF.util.report(panel.set_place(which, value))
    end
    if OF.util.asks(OF.panelskin, "set_size_step") then
        local skin = OF.panelskin
        for i, v in ipairs(skin.SIZES) do
            if v == skin.SIZE_DEFAULT then OF.util.report(skin.set_size_step(i - 1)) end
        end
    end
    return true
end

function panel.set_size_step(step)
    local skin = OF.panelskin
    if not OF.util.asks(skin, "set_size_step") then return false, "No such size." end
    local ok, why = skin.set_size_step(step)
    if not ok then return ok, why end
    local share = skin.size()
    if share == 0 then
        panel.set_place("w", 100)
        panel.set_place("h", 100)
    else
        panel.set_place("w", PLACE_DEFAULT.w * share / 100 + 0.5)
        panel.set_place("h", PLACE_DEFAULT.h * share / 100 + 0.5)
    end
    return true
end

panel.PLACE_PRESETS = {
    { name = "In the middle", x = 50, y = 50 },
    { name = "Top left", x = 0, y = 0 },
    { name = "At the top", x = 50, y = 0 },
    { name = "Top right", x = 100, y = 0 },
    { name = "On the left", x = 0, y = 50 },
    { name = "On the right", x = 100, y = 50 },
    { name = "Bottom left", x = 0, y = 100 },
    { name = "At the bottom", x = 50, y = 100 },
    { name = "Bottom right", x = 100, y = 100 },
}
function panel.place_preset()
    for i, p in ipairs(panel.PLACE_PRESETS) do
        if panel.place.x == p.x and panel.place.y == p.y then return i, p end
    end
    return nil, nil
end
function panel.set_place_preset(index)
    local p = panel.PLACE_PRESETS[math.floor(tonumber(index) or 0)]
    if p == nil then return false, "No such place." end
    panel.set_place("x", p.x)
    panel.set_place("y", p.y)
    return true
end

local OPACITY_KEY = "panel_opacity"
local OPACITY_DEFAULT = 75

panel.opacity = mod_storage_load_integer(OPACITY_KEY, OPACITY_DEFAULT)

panel.OPACITY_LIMITS = { min = 70, max = 100, step = 5 }
function panel.settle_opacity(stored)
    stored = math.floor(tonumber(stored) or OPACITY_DEFAULT)
    return math.max(panel.OPACITY_LIMITS.min,
        math.min(panel.OPACITY_LIMITS.max, stored))
end
panel.opacity = panel.settle_opacity(panel.opacity)

function panel.opacity_steps()
    return math.floor((panel.OPACITY_LIMITS.max - panel.OPACITY_LIMITS.min)
        / panel.OPACITY_LIMITS.step)
end

function panel.opacity_step()
    return math.floor((panel.opacity - panel.OPACITY_LIMITS.min)
        / panel.OPACITY_LIMITS.step + 0.5)
end

function panel.set_opacity(percent)
    local wanted = OF.util.clamp(math.floor(tonumber(percent) or 0),
        panel.OPACITY_LIMITS.min, panel.OPACITY_LIMITS.max)
    panel.opacity = wanted
    OF.util.store_integer(OPACITY_KEY, wanted)
    return true
end

function panel.set_opacity_step(step)
    return panel.set_opacity(panel.OPACITY_LIMITS.min
        + step * panel.OPACITY_LIMITS.step)
end

function panel.fade()
    return panel.opacity / 100
end

function panel.geometry()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local wShare, hShare = panel.place.w, panel.place.h
    if panel.skin_on() then wShare, hShare = PLACE_DEFAULT.w, PLACE_DEFAULT.h end
    local width = OF.util.clamp(screenWidth * (wShare / 100),
        math.min(380, screenWidth), screenWidth - 16)
    local height = OF.util.clamp(screenHeight * (hShare / 100),
        math.min(240, screenHeight), screenHeight - 16)

    local freeX = math.max(0, screenWidth - width)
    local freeY = math.max(0, screenHeight - height)

    return freeX * (panel.place.x / 100), freeY * (panel.place.y / 100),
        width, height
end

panel.RESIZE_OUT = 8
panel.RESIZE_IN = 3

function panel.resize_edge(mouseX, mouseY, x, y, width, height)
    if type(mouseX) ~= "number" or type(mouseY) ~= "number" then return nil end
    local out, inside = panel.RESIZE_OUT, panel.RESIZE_IN
    if mouseY < y or mouseY > y + height + out then return nil end
    if mouseX < x - out or mouseX > x + width + out then return nil end
    local edge = {
        left = mouseX >= x - out and mouseX <= x + inside,
        right = mouseX >= x + width - inside and mouseX <= x + width + out,
        bottom = mouseY >= y + height - inside and mouseY <= y + height + out,
    }
    if not (edge.left or edge.right or edge.bottom) then return nil end
    return edge
end

function panel.resize_step(hold, mouseX, mouseY)
    if hold == nil then return false end
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    if screenWidth <= 0 or screenHeight <= 0 then return false end
    local dx, dy = mouseX - hold.mx, mouseY - hold.my
    local left, top = hold.x, hold.y
    local width, height = hold.width, hold.height
    if hold.edge.right then width = hold.width + dx end
    if hold.edge.left then width = hold.width - dx end
    if hold.edge.bottom then height = hold.height + dy end
    if hold.edge.left or hold.edge.right then
        OF.util.report(panel.set_place("w", width / screenWidth * 100 + 0.5))
    end
    if hold.edge.bottom then
        OF.util.report(panel.set_place("h", height / screenHeight * 100 + 0.5))
    end

    local _, _, newWidth, newHeight = panel.geometry()
    if hold.edge.left then left = hold.x + hold.width - newWidth end
    local freeX = math.max(0, screenWidth - newWidth)
    local freeY = math.max(0, screenHeight - newHeight)
    if freeX > 0 then OF.util.report(panel.set_place("x", left / freeX * 100 + 0.5)) end
    if freeY > 0 then OF.util.report(panel.set_place("y", top / freeY * 100 + 0.5)) end
    return true
end
panel.rows = nil
panel.visibleRows = 1
panel.title = "oldfart's Lobby"
local ROW_SCALE = 1.0
local TITLE_SCALE = 1.25

local CRUMB_SCALE = 0.85
local FOOTER_SCALE = 0.7

local ROW_GAP = 9
local TITLE_PADDING = 8
local FOOTER_PADDING = 5
local LIST_PADDING = 6
local SIDE_PADDING = 12

local SCROLLBAR_STRIP = 18
local VERSION_GAP = 10
local LOGO_GAP = 6

panel.TABS = {
    { key = "players", name = "Players",  page = "players" },
    { key = "travel",  name = "Travel",   page = "travel" },
    { key = "race",    name = "Modes",    page = "speedrun" },
    { key = "room",    name = "Fun",      page = "room" },
    { key = "control", name = "Control",  page = "control" },
    { key = "me",      name = "Menu Settings", page = "client" },
}
panel.tab = 1

local function row(text, r, g, b, action)
    return { text = text, r = r, g = g, b = b, action = action }
end

local function with_right(built, right)
    if built ~= nil then
        built.right = right
        built.levelSlot = true
    end
    return built
end

local function with_help(built, help)
    if built ~= nil then built.help = help end
    return built
end

function panel.with_walk(built)
    if built ~= nil then built.walk = true end
    return built
end

function panel.log_line(stamp, who, sentence, r, g, b, action)
    local parts = {}
    for _, part in ipairs({ stamp, who, sentence }) do
        if part ~= nil and tostring(part) ~= "" then parts[#parts + 1] = tostring(part) end
    end
    local built = row(table.concat(parts, "  "), r or 220, g or 220, b or 220, action)
    built.logLine = true
    if action == nil then built.walk = true end
    return built
end

local function rest_row(built)
    if built ~= nil then built.rest = true end
    return built
end
panel.rest_row = rest_row

local function with_slider(built, value, steps, onChange, holes)
    if built == nil then return nil end

    built.slider = { value = value, steps = steps, holes = holes }

    if built.action ~= nil then built.slider.onChange = onChange end
    return built
end

function panel.tick(on, text)
    return (on and "[X] " or "[ ] ") .. tostring(text or "")
end

function panel.tick_some(text)
    return "[-] " .. tostring(text or "")
end

do

local BOX = "^%[[xX%s%-]%]%s"
function panel.row_ticks(r)
    if type(r) ~= "table" then return false end
    if r.ticks == true then return true end
    if r.action == nil then return false end
    if type(r.text) ~= "string" then return false end
    return OF.util.plain(r.text):match(BOX) ~= nil
end

function panel.has_box(r)
    if type(r) ~= "table" or type(r.text) ~= "string" then return false end
    return OF.util.plain(r.text):match(BOX) ~= nil
end

function panel.box_span(text, index, scale)
    if type(text) ~= "string" then return nil end
    index = math.floor(tonumber(index) or 0)
    if index < 1 then return nil end
    scale = scale or ROW_SCALE

    local slot = panel.skin_on() and panel.boxSlot or nil
    local at, from = 1, 0
    for n = 1, index do
        local box = string.match(text, "^%[[xX%s%-]%]%s", at)
        if box == nil then return nil end
        local wide = slot or OF.util.width(box, scale)
        if n == index then return from, from + wide end
        from = from + wide
        at = at + #box
    end
    return nil
end

function panel.alt_zone(row, left, scale)
    if type(row) ~= "table" or row.altAction == nil or row.altPad then
        return nil
    end
    local index = row.altBox or 1
    local from, to = panel.box_span(row.text, index, scale)
    if from == nil then
        if panel.has_box(row) then return nil end
        from, to = 0, OF.util.width(panel.tick(true, ""), scale or ROW_SCALE)
    end
    return left + from, left + to
end

end

function panel.level_right(built, on, level)
    if built == nil then return nil end
    if level == nil or level == "" then return built end
    if on then return with_right(built, level) end
    built.levelSlot = true
    return built
end

function panel.picker_row(built, level, changed)
    if built == nil then return nil end
    built.picker = true
    if changed and built.action ~= nil then built.moved = true end
    return with_right(built, level)
end

local function label_row(text, r, g, b)
    return { text = text, r = r or 150, g = g or 150, b = b or 150 }
end

local function loud_row(text)
    local built = label_row(text, gold().r, gold().g, gold().b)

    built.loud = true
    return built
end

local function header_row(text)
    return { text = text, r = gold().r, g = gold().g, b = gold().b,
             heading = true }
end

local function sub_header_row(text)
    local gold = OF.util.gold()
    return { text = text, r = gold.r, g = gold.g, b = gold.b,
             heading = true, sub = true }
end

local function gated_row(feature, text, r, g, b, action)
    if OF.perms.can(feature) then
        if OF.perms.needs_host(feature) and not OF.util.is_host() then

            local blocked = label_row(text .. "   " .. OF.lang.t("(host only)"))
            blocked.hostOnly = true
            return blocked
        end

        local built = row(text, r, g, b, action)
        built.feature = feature
        return built
    end

    local needs = OF.perms.required(feature)
    local denied
    if OF.perms.needs_host(feature) then
        denied = label_row(text .. "   " .. OF.lang.t("(host only)"))
        denied.hostOnly = true
    else
        denied = label_row(text .. "   ("
            .. OF.lang.t(OF.perms.tier_name(needs)) .. "+)")
    end
    denied.needs = needs
    return denied
end

function panel.door_for_either(lobbyNeed, mineNeed, text, r, g, b, action)
    local built
    if panel.may(lobbyNeed) then
        built = gated_row(lobbyNeed, text, r, g, b, action)
    else
        built = gated_row(mineNeed, text, r, g, b, action)
    end
    if built ~= nil and built.action ~= nil then built.feature = mineNeed end
    return built
end

local function host_row(feature, text, r, g, b, action, ask)
    if OF.perms.can(feature) and not OF.util.is_host() then
        if ask ~= nil and OF.perms.is_cohost(0) then
            return gated_row(feature, text, r, g, b, ask)
        end
        local blocked = label_row(text .. "   " .. OF.lang.t("(host only)"))
        blocked.hostOnly = true
        return blocked
    end
    return gated_row(feature, text, r, g, b, action)
end

function panel.two_box(spec)
    local text
    if spec.boxes == false then
        text = spec.name or ""
    else
        local left = spec.lobbySome and panel.tick_some("")
            or panel.tick(spec.lobbyOn, "")

        local right
        if spec.mineBox == false then
            right = panel.tick_some(spec.name or "")
        else
            right = panel.tick(spec.mineBox == true, spec.name or "")
        end
        text = left .. right
    end
    local mayLobby = panel.may(spec.lobbyNeed)
    local mayMine = panel.may(spec.mineNeed)

    local zone = (spec.boxes == false) and 1 or 2

    if mayLobby and mayMine then
        local built = row(text, spec.r, spec.g, spec.b, spec.onLobby)

        built.feature = spec.lobbyNeed
        built.altAction = spec.onMine
        built.altBox = zone
        built.actionLabel = "for everybody"
        built.altLabel = "for me"
        built.altMine = true
        return built
    end

    if mayMine then

        local built = panel.with_walk(row(text, spec.r, spec.g, spec.b, nil))
        built.altAction = spec.onMine
        built.altBox = zone
        built.altLabel = "for me"
        built.altMine = true
        return built
    end

    if mayLobby then
        local built = row(text, spec.r, spec.g, spec.b, spec.onLobby)
        built.feature = spec.lobbyNeed
        built.actionLabel = "for everybody"
        return built
    end

    return gated_row(spec.mineNeed, text, spec.r, spec.g, spec.b, nil)
end

function panel.may(feature)
    if feature == nil then return false end
    if not OF.perms.can(feature) then return false end
    if OF.perms.needs_host(feature) and not OF.util.is_host() then
        return false
    end
    return true
end

function panel.two_box_level(stop, mine)
    if stop == nil or stop == "" then return nil end
    if not mine then return stop end
    return OF.lang.fill("@ (yours)", stop)
end

function panel.mine_ink()
    local C = OF.hud ~= nil and OF.hud.C or nil
    local info = C ~= nil and C.info or { 140, 210, 255 }
    local good = C ~= nil and C.good or { 110, 236, 140 }
    local ar, ag, ab = 255, 210, 80
    if OF.theme ~= nil and type(OF.theme.highlight) == "function" then
        ar, ag, ab = OF.theme.highlight()
    end
    local d = math.abs((ar or 0) - info[1]) + math.abs((ag or 0) - info[2])
        + math.abs((ab or 0) - info[3])
    if d < 160 then return good[1], good[2], good[3] end
    return info[1], info[2], info[3]
end

function panel.two_box_column(roomStop, mineStop, mineSet)
    if roomStop == "" then roomStop = nil end
    if mineStop == "" then mineStop = nil end
    if not mineSet then return roomStop, nil end
    if mineStop == nil then return roomStop, nil end
    if roomStop == nil or roomStop == mineStop then
        return OF.lang.fill("@ (yours)", mineStop), nil
    end
    local you = OF.lang.fill("you: @", mineStop)
    return roomStop .. "  " .. you, you
end

function panel.two_slider(built, spec)
    if built == nil then return nil end
    local steps = math.max(1, math.floor(tonumber(spec.steps) or 1))
    built.slider = {
        value = OF.util.clamp(math.floor(tonumber(spec.room) or 0), 0, steps),
        steps = steps,
        holes = spec.holes,
        onChange = spec.mayRoom and spec.setRoom or nil,
        mine = {
            value = spec.mine ~= nil
                and OF.util.clamp(math.floor(tonumber(spec.mine) or 0), 0, steps) or nil,
            onChange = spec.mayMine and spec.setMine or nil,
        },
    }
    if spec.mine ~= nil and spec.mayMine and spec.clearMine ~= nil then
        built.clearMine = spec.clearMine
    end

    if spec.mayRoom and spec.roomNext ~= nil and built.action ~= nil then
        built.actionLabel = OF.lang.fill("everybody -> @", spec.roomNext)
        built.actionShort = "everybody"
    end
    if spec.mayMine and spec.mineNext ~= nil and built.altAction ~= nil then
        built.altLabel = OF.lang.fill("me -> @", spec.mineNext)
        built.altShort = "me"
    end
    return built
end

function panel.dial_target(slider, zHeld)
    if slider == nil then return nil end
    local mine = slider.mine
    local mineDial = mine ~= nil and mine.onChange ~= nil
        and (zHeld == true or slider.onChange == nil)
    if mineDial then
        local from = mine.value
        if from == nil then from = slider.value end
        return from, mine.onChange, true
    end
    if slider.onChange == nil then return nil end
    return slider.value, slider.onChange, false
end

panel.HOLD_Z_FRAMES = 15

panel.MINE_STOPS = { true, false }

function panel.all_for_me(rows)
    if type(rows) ~= "table" then return rows end
    for _, r in ipairs(rows) do
        if type(r) == "table" then r.mine = true end
    end
    return rows
end

function panel.mine_shown(state, lobbyOn)
    if state ~= nil then return state end
    if lobbyOn then return true end
    return nil
end

function panel.mine_marked(state)
    return state ~= nil
end

function panel.next_mine(state, lobbyOn)
    local at = state
    for _ = 1, #panel.MINE_STOPS + 1 do

        if at == nil then
            at = panel.MINE_STOPS[1]
        else
            local found = nil
            for index, value in ipairs(panel.MINE_STOPS) do
                if value == at then found = panel.MINE_STOPS[index + 1] end
            end
            at = found
        end
        local settled = at
        if settled == (lobbyOn and true or false) then settled = nil end
        if settled ~= state then return settled end
    end
    return nil
end

function panel.next_mine_level(state, level, stops, lobbyLevel)
    stops = math.floor(tonumber(stops) or 1)
    if stops < 1 then stops = 1 end
    lobbyLevel = math.floor(tonumber(lobbyLevel) or 0)

    local at = nil
    if state == false then
        at = 0
    elseif state == true then
        at = math.floor(tonumber(level) or 1)
        if at < 1 then at = 1 end
        if at > stops then at = stops end
    end

    local ring = {}
    for stop = 1, stops do ring[stop] = stop end
    ring[stops + 1] = 0

    local index = 0
    if at ~= nil then
        for i = 1, #ring do
            if ring[i] == at then index = i end
        end
    end

    if stops <= 1 then
        for _ = 1, #ring do
            index = index + 1
            if index > #ring then return nil end
            if ring[index] ~= lobbyLevel then return ring[index] end
        end
        return nil
    end
    index = index + 1
    if index > #ring then return nil end
    return ring[index]
end

panel.rowsPage = nil

local function known_page(page)
    return page ~= nil and panel.PAGES ~= nil and panel.PAGES[page] ~= nil
end

local function mark_tab_page(page)
    if not known_page(page) then return end
    local def = panel.PAGES[page]
    if def ~= nil and def.transient == true then return end
    panel.tabPage[panel.tab_of(page)] = page
end

function panel.cursor_identity()
    if panel.rowsPage ~= panel.page then return nil end
    if panel.row_identity == nil or type(panel.rows) ~= "table" then
        return nil
    end
    return panel.row_identity(panel.rows[panel.cursor])
end

function panel.remember()
    if panel.page == nil then return end
    mark_tab_page(panel.page)
    if panel.scroll == 0 and panel.cursor <= 1 then
        panel.memory[panel.page] = nil
        return
    end
    panel.memory[panel.page] = { scroll = panel.scroll, cursor = panel.cursor,
        key = panel.cursor_identity() }
end

function panel.page_for_tab(key)
    local remembered = panel.tabPage[key]

    if known_page(remembered) and panel.tab_of(remembered) == key then
        return remembered
    end
    for _, tab in ipairs(panel.TABS) do
        if tab.key == key then return tab.page end
    end
    return panel.TABS[1].page
end

panel.ROUND_TAB = "race"
function panel.round_tab_only()
    local held = false
    if OF.util.asks(OF.lockdown, "held_by_round") and OF.lockdown.held_by_round() then
        held = true
    elseif OF.util.asks(OF.lockdown, "held_by_race") and OF.lockdown.held_by_race() then
        held = true
    end
    if not held then return false end
    if not OF.util.asks(OF.roundscope, "inside") then return true end

    if OF.util.asks(OF.lockdown, "round_or_run") and not OF.lockdown.round_or_run() then
        return true
    end
    return OF.roundscope.inside(0) == true
end

function panel.tab_is_open(key)
    if not panel.round_tab_only() then return true end
    return key == panel.ROUND_TAB
end

panel.travelFrom = nil
panel.TRAVEL_PAGES = { groups = true, levels = true }

panel.history = {}
panel.HISTORY_DEEPEST = 32

function panel.history_spot()
    local folds, prefix = {}, tostring(panel.page) .. "\31"
    for key, shut in pairs(panel.folded or {}) do
        if string.sub(key, 1, #prefix) == prefix then folds[key] = shut end
    end

    local page = panel.page == "main" and "players" or panel.page
    return { page = page, scroll = panel.scroll, cursor = panel.cursor,
        key = panel.cursor_identity(), folds = folds }
end

function panel.history_take(page)
    local h = panel.history
    for i = #h, 1, -1 do
        if h[i].page == page then
            local spot = h[i]
            for j = #h, i, -1 do h[j] = nil end
            return spot
        end
    end

    local def = panel.PAGES ~= nil and panel.PAGES[panel.page] or nil
    if panel.pressing and def ~= nil and def.up == page and #h > 0 then return table.remove(h) end
    return nil
end

function panel.history_push()
    local h = panel.history
    h[#h + 1] = panel.history_spot()
    while #h > panel.HISTORY_DEEPEST do table.remove(h, 1) end
end

function panel.history_clear()
    panel.history = {}
end

local function go(page, how)

    local spot = nil
    if how ~= "tab" and panel.open and panel.page ~= nil and page ~= panel.page then
        spot = panel.history_take(page)
        if spot ~= nil then
            page = spot.page
        elseif how ~= "back" and known_page(panel.page) then

            panel.history_push()
        end
    end
    if panel.travelFrom ~= nil and not panel.TRAVEL_PAGES[page] then panel.travelFrom = nil end

    if known_page(page) and not panel.tab_is_open(panel.tab_of(page)) then
        return
    end
    panel.remember()
    panel.page = page
    mark_tab_page(page)

    panel.mark_arrival()

    if not panel.open and known_page(page) then panel.lastPage = page end

    panel.foldAsk = page

    if spot ~= nil then
        local prefix = tostring(page) .. "\31"
        for key in pairs(panel.folded) do
            if string.sub(key, 1, #prefix) == prefix then panel.folded[key] = nil end
        end
        for key, shut in pairs(spot.folds or {}) do panel.folded[key] = shut end
        panel.foldSeen[page] = true
        panel.foldAsk = false
    end
    local was = spot or panel.memory[page]
    panel.scroll = was ~= nil and was.scroll or 0
    panel.cursor = was ~= nil and was.cursor or 1
    panel.confirm = nil

    if panel.landed ~= nil and panel.landed.page ~= page then
        panel.landed = nil
    end

    panel.sliderDrag = nil

    panel.putBackSaid = nil

    if panel.forget_active ~= nil then panel.forget_active() end

    if page == "search" and panel.refresh_search ~= nil then panel.refresh_search() end

    if panel.rebuild ~= nil then panel.rebuild() end

    if was ~= nil and was.key ~= nil and panel.keep_cursor_on ~= nil then
        panel.keep_cursor_on(was.key)
    end

    if was == nil and panel.rest_cursor ~= nil then panel.rest_cursor() end
end

panel.go = go

panel.backPage = nil

function panel.remember_before_round()
    local page = panel.page
    if not known_page(page) then return end
    if page == "speedrun" or panel.tab_of(page) == panel.ROUND_TAB then return end
    panel.remember()
    panel.backPage = page
end

function panel.restore_after_round()
    local page = panel.backPage
    panel.backPage = nil
    if not known_page(page) then return end
    if not panel.tab_is_open(panel.tab_of(page)) then return end

    panel.history_clear()
    go(page, "back")
end

function panel.with_confirm(built, key)
    if built == nil or built.action == nil then return built end

    local action = built.action

    built.danger = true
    if panel.confirm ~= nil and panel.confirm.key == key then
        built.confirming = built.text
        built.text = OF.lang.fill("Click again to confirm: @", built.text)
        built.r, built.g, built.b = 255, 220, 120
        built.action = function()
            panel.confirm = nil
            action()
        end
        return built
    end
    built.action = function() panel.confirm = { key = key, timer = 0 } end
    return built
end

local function confirm_row(key, text, r, g, b, action)
    return panel.with_confirm(row(text, r, g, b, action), key)
end

local function gated_confirm_row(feature, key, text, r, g, b, action)
    local built = gated_row(feature, text, r, g, b, action)
    if built.action == nil then return built end

    local confirmed = confirm_row(key, text, r, g, b, action)
    confirmed.feature = built.feature
    return confirmed
end

local function back_row()
    local built = with_help(row(OF.lang.t("< Back"), 180, 180, 180,
        function() panel.back() end),
        OF.lang.t("up to the page this one opened from"))
    built.outside = true
    built.exit = true
    return built
end

panel.selection = panel.selection or {}

function panel.enrol_forgetting()

    if panel.forgetting then return true end
    if not OF.util.asks(OF.util, "on_forget_seat") then return false end
    panel.forgetting = OF.util.on_forget_seat("the panel's ticked set", function(localIndex)

        local globalIndex = network_global_index_from_local(localIndex)
        if globalIndex == nil then return end
        if panel.selection[globalIndex] ~= nil then
            panel.selection[globalIndex] = nil
            panel.dirty = true
        end

        if panel.selected == globalIndex then
            panel.selected = -1
            panel.dirty = true
        end
    end)
    return panel.forgetting
end

function panel.selection_list()
    local list = {}
    for globalIndex, on in pairs(panel.selection) do
        if on and OF.util.local_from_global(globalIndex) ~= nil then
            table.insert(list, globalIndex)
        end
    end
    table.sort(list)
    return list
end

function panel.selection_count()
    return #panel.selection_list()
end

function panel.selection_toggle(globalIndex)

    panel.enrol_forgetting()
    if panel.selection[globalIndex] then
        panel.selection[globalIndex] = nil
    else
        panel.selection[globalIndex] = true
    end
    panel.dirty = true
end

function panel.selection_clear()
    panel.selection = {}
    panel.dirty = true
end

local function selection_names()
    local names = {}
    for _, globalIndex in ipairs(panel.selection_list()) do
        local li = OF.util.local_from_global(globalIndex)
        if li ~= nil then table.insert(names, gNetworkPlayers[li].name) end
    end
    return table.concat(names, ", ")
end

function panel.selection_out_of_reach()
    local names = {}
    local me = network_global_index_from_local(0)
    for _, globalIndex in ipairs(panel.selection_list()) do
        if globalIndex ~= me then
            local li = OF.util.local_from_global(globalIndex)
            local may = OF.util.may_act_on(0, li)
            if not may then
                local np = li ~= nil and gNetworkPlayers[li] or nil
                table.insert(names, np ~= nil and np.name or "?")
            end
        end
    end
    return names
end

function panel.selection_only_other(localIndex)
    if localIndex == nil then return nil end
    local list = panel.selection_list()
    if #list ~= 1 then return nil end
    local mine = network_global_index_from_local(localIndex)
    if list[1] == mine then return nil end
    return list[1]
end

local function everyone()
    local all = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        table.insert(all, network_global_index_from_local(entry.localIndex))
    end
    return all
end

local function others()
    local list = {}
    local me = network_global_index_from_local(0)
    for _, entry in ipairs(OF.util.connected_players()) do
        local globalIndex = network_global_index_from_local(entry.localIndex)
        if globalIndex ~= me then table.insert(list, globalIndex) end
    end
    return list
end

local function targets_for(mode)
    local list
    if mode == "selected" then list = panel.selection_list()
    elseif mode == "everyone" then list = everyone()
    elseif mode == "others" then list = others()
    elseif mode == "player" then list = { panel.selected }
    else return { network_global_index_from_local(0) } end

    if OF.util.asks(OF.roundscope, "out_of_reach") then
        list = OF.roundscope.out_of_reach(list)
    end
    return list
end

local AIM_NAMES = {
    self = OF.lang.t("just me"),
    player = OF.lang.t("that player"),
    selected = OF.lang.t("the ticked"),
    others = OF.lang.t("everybody but me"),
    everyone = OF.lang.t("everybody"),
}

function panel.aim_name(mode)
    return AIM_NAMES[mode] or AIM_NAMES.self
end

function panel.aim_label(mode)
    local name = panel.aim_name(mode)
    if mode == "player" then
        local li = OF.util.local_from_global(panel.selected)
        if li ~= nil and gNetworkPlayers[li] ~= nil then
            return OF.util.plain(gNetworkPlayers[li].name)
        end
        return name
    end
    if mode ~= "selected" then return name end
    local picked = panel.selection_count()
    if picked == 0 then return name .. OF.lang.t(" (none yet)") end
    return name .. OF.lang.fill(" (@)", picked)
end

function panel.aim_refusal(mode)
    if mode == nil then mode = panel.aimed_at() end
    if mode == "player" then
        if OF.util.local_from_global(panel.selected) ~= nil then return nil end
        return OF.lang.t("That player has left. Press Aimed at to pick somebody else.")
    end
    if mode ~= "selected" then return nil end
    if panel.selection_count() > 0 then return nil end
    return OF.lang.t("Nothing is ticked. Tick names on the Players list first.")
end

function panel.aim_check(mode)
    if mode == nil then mode = panel.aimed_at() end

    if mode == "player" then
        local refusal = panel.aim_refusal(mode)
        if refusal ~= nil then return false, refusal end
        return true, nil
    end
    if mode ~= "selected" then return true, nil end
    local refusal = panel.aim_refusal(mode)
    if refusal ~= nil then return false, refusal end
    local out = panel.selection_out_of_reach()
    if #out == 0 then return true, nil end
    return #out < panel.selection_count(),
        OF.lang.fill("Not @ - your rank cannot act on them.",
            table.concat(out, ", "))
end

local AIM_STOPS = { "self", "player", "selected", "others", "everyone" }

panel.AIM_STOPS = AIM_STOPS

function panel.aimed_at()
    local aim = panel.aim or "self"
    if AIM_NAMES[aim] == nil then return "self" end
    return aim
end

function panel.aim_at(mode)
    if AIM_NAMES[mode] == nil then mode = "self" end
    panel.aim = mode
    return true
end

function panel.open_aimed(page, mode)
    panel.aim_at(mode)
    go(page)
end

local function anybody_behind(mode)
    for _, globalIndex in ipairs(targets_for(mode)) do
        if OF.util.local_from_global(globalIndex) ~= nil then return true end
    end
    return false
end

function panel.next_aim()
    local at, here = 1, panel.aimed_at()
    for index, mode in ipairs(AIM_STOPS) do
        if mode == here then at = index end
    end
    for step = 1, #AIM_STOPS do
        local mode = AIM_STOPS[(at + step - 1) % #AIM_STOPS + 1]
        if mode == "self" or mode == "everyone" or mode == "selected" then
            return mode
        end
        if anybody_behind(mode) then return mode end
    end
    return "self"
end

local function where_of(levelNum, areaIndex)
    if OF.util.asks(OF.util, "level_name") then
        local ok, name = pcall(OF.util.level_name, levelNum, areaIndex)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return OF.lang.fill("level @", tostring(levelNum or "?"))
end

panel.where_of = where_of

function panel.rank_chip_width()
    local H = OF.hud
    local widest = 0
    for _, tier in ipairs(OF.TIER_ORDER or {}) do
        local label = OF.perms.tier_label(tier)
        if label ~= nil and label ~= "" and H ~= nil and type(H.measure) == "function" then
            widest = math.max(widest, H.measure(label, "caption") or 0)
        end
    end
    local margin = (H ~= nil and H.S ~= nil and H.S.s3) or 12
    return math.floor(widest + margin + 0.5)
end

function panel.draw_named(text, nameRaw, x, y, inkR, inkG, inkB, ink)
    local plainName = OF.util.plain(nameRaw or "")
    if plainName == "" then return false end
    local at, to = string.find(text, plainName, 1, true)
    if at == nil then return false end
    local runs = OF.util.asks(OF.hud, "name_runs") and OF.hud.name_runs(nameRaw, "ink")
        or OF.util.colour_runs(nameRaw, { r = inkR, g = inkG, b = inkB })
    local before, after = string.sub(text, 1, at - 1), string.sub(text, to + 1)
    if before ~= "" then
        OF.util.text(before, x, y, ROW_SCALE, inkR, inkG, inkB, ink)
        x = x + OF.util.width(before, ROW_SCALE)
    end
    for _, run in ipairs(runs) do
        OF.util.text(run.text, x, y, ROW_SCALE, run.r or inkR, run.g or inkG, run.b or inkB, ink)
        x = x + OF.util.width(run.text, ROW_SCALE)
    end
    if after ~= "" then OF.util.text(after, x, y, ROW_SCALE, inkR, inkG, inkB, ink) end
    return true
end

local function player_display(entry)
    local tier = OF.ranks.get(entry.localIndex)
    local tag = OF.perms.tier_label(tier)

    local text = OF.util.plain(entry.np.name or "")

    local who = OF.charselect ~= nil and OF.charselect.suffix or nil
    if who ~= nil then text = text .. (who(entry.localIndex) or "") end

    local flags = ""
    if OF.mute.is_muted(entry.localIndex) then flags = flags .. " (muted)" end
    if OF.jail.is_jailed(entry.localIndex) then
        local sentence = OF.jail.sentence_of(entry.localIndex)
        flags = flags .. " (" .. (sentence and sentence.short or "jailed") .. ")"
    end

    if OF.speedrun.is_excluded(entry.localIndex) then flags = flags .. " (sitting out)" end
    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(entry.localIndex) then
        flags = flags .. " (watching)"
    end
    if OF.idle.is_idle(entry.localIndex) then flags = flags .. " (away)" end

    if OF.util.asks(OF.charselect, "in_menu")
        and OF.charselect.in_menu(entry.localIndex) then
        flags = flags .. " (in the menu)"
    end

    if OF.util.asks(OF.costumes, "model_for")
        and OF.costumes.model_for(entry.localIndex) ~= nil then
        local worn = OF.costumes.name_worn(entry.localIndex)
        if worn ~= nil then flags = flags .. " (" .. worn .. ")" end
    end

    if OF.util.is_host() and OF.notes.has(entry.localIndex) then flags = flags .. " *" end

    return text .. flags, tag
end

local function player_where(entry)

    if OF.util.asks(OF.roundscope, "secret_from_me")
        and OF.roundscope.secret_from_me(entry.localIndex) then
        return OF.lang.t("in a hide round")
    end
    return where_of(entry.np.currLevelNum, entry.np.currAreaIndex)
end

panel.player_where = player_where

local function build_travel()
    local rows = {}
    local me = network_global_index_from_local(0)

    table.insert(rows, header_row(OF.lang.t("Where to next")))
    table.insert(rows, with_help(gated_row("teleport_self", OF.lang.t("Go somewhere..."), 255, 255, 255, function()
        panel.levelMode = "self"
        go("groups")
    end), OF.lang.t("moves you alone; the lobby stays where it is")))
    table.insert(rows, with_help(gated_row("warp_lobby", OF.lang.t("Take everybody somewhere..."), 255, 255, 255, function()
        panel.levelMode = "everyone"
        go("groups")
    end), OF.lang.t("takes the whole lobby to a level you pick next")))

    table.insert(rows, with_help(gated_row("warp_lobby",
        OF.lang.t("Arenas - a swept level for a fight..."), 255, 255, 255,
        function() go("arena") end),
        OF.lang.t("the same lobby warp with the level's own cast taken out")))

    table.insert(rows, with_help(gated_row("waypoint_use", OF.lang.fill("Waypoints and doorways (@)", #OF.waypoints.list()),
        255, 255, 255, function() go("waypoints") end),
        OF.lang.t("spots you have saved to send anybody to, and the doorway gun's two openings")))

    if OF.spectate.can_stop() then
        table.insert(rows, with_help(row(OF.spectate.is_active()
            and OF.lang.t("Stop spectating") or OF.lang.t("Stop spectating (give me my body back)"),
            255, 140, 90, function()
                OF.spectate.stop()
                panel.close()
            end), OF.lang.t("puts you back in your own body, wherever it was left")))
    end

    table.insert(rows, header_row(OF.lang.t("The whole lobby")))
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Gather everybody to me"), 255, 255, 255, function()

        local moved, why = OF.net.summon_everyone_to(me)
        OF.net.report_move(moved > 0, why,
            OF.lang.fill("Summoned @ player(s).", moved))
    end), OF.lang.t("pulls the whole lobby to where you are standing")))
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Gather everybody to a player..."), 255, 255, 255, function()
        panel.pickMode = "everyone"
        go("pick")
    end), OF.lang.t("pulls the whole lobby to somebody you pick next")))
    table.insert(rows, with_help(gated_row("warp_lobby", OF.lang.t("Reload this map"), 255, 255, 255, function()
        OF.util.report(OF.net.reload_level())
    end), OF.lang.t("starts this level again for everybody, from its opening")))
    if OF.net.can_undo() then
        table.insert(rows, with_help(gated_row("warp_lobby", OF.lang.t("Undo the last warp"), 255, 255, 255, function()
            OF.net.report_move(OF.net.undo_warp())
            panel.close()
        end), OF.lang.t("sends the lobby back to the level it was in before the last one")))
    end

    local picked = panel.selection_count()
    if picked > 0 then
        table.insert(rows, header_row(OF.lang.fill("The @ selected", picked)))
        table.insert(rows, with_help(gated_row("teleport_other",
            OF.lang.t("Send them somewhere..."), 120, 255, 120, function()
                panel.levelMode = "selected"
                go("groups")
            end), OF.lang.t("moves the ticked names to a level you pick next")))
        table.insert(rows, with_help(gated_row("teleport_other",
            OF.lang.t("Gather them to me"), 120, 255, 120, function()

                local carryOn, refusal = panel.aim_check("selected")
                if refusal ~= nil then OF.util.report(false, refusal) end
                if not carryOn then return end
                local moved, why =
                    OF.net.summon_many(panel.selection_list(), me)
                OF.net.report_move(moved > 0, why,
                    OF.lang.fill("Summoned @ player(s).", moved))
            end), OF.lang.t("pulls the ticked names to where you are standing")))

    end

    return rows
end

local function build_room()
    local rows = {}

    table.insert(rows, with_help(row(OF.lang.t("What is on right now..."),
        255, 220, 120, function() go("active") end),
        OF.lang.t("every modifier and cheat that is on, in one list you can press")))

    table.insert(rows, header_row(OF.lang.t("What the lobby is like")))

    table.insert(rows, with_help(with_right(
        row(OF.lang.t("Lobby rules..."), 255, 255, 255,
            function() go("roomrules") end),
        ((OF.util.asks(OF.harsh, "any_on") and OF.harsh.any_on())
            or (OF.util.asks(OF.enemies, "anything_on") and OF.enemies.anything_on()))
            and OF.lang.t("on") or ""),
        "how the game plays, how everybody moves, what a mistake costs, and the level itself"))

    table.insert(rows, with_help(
        row(OF.lang.t("Twists..."), 255, 220, 120,
            function() go("chance") end),
        "a shuffled world, a dealt hand, and things that hunt you"))

    table.insert(rows, with_help(with_right(panel.door_for_either("music", "costume_self",
        OF.lang.t("Music..."),
        255, 255, 255, function() go("music") end),
        OF.music.track_name(OF.music.lobby_track())),
        OF.lang.t("what the whole lobby hears, and the playlist it is dealt from")))

    table.insert(rows, with_help(panel.door_for_either("vision", "costume_self",
        OF.lang.t("Visuals - how the lobby looks..."), 255, 255, 255,
        function() go("vision") end),
        OF.lang.t("the weather, the light, the shadows, and the looks this lobby is wearing")))

    if OF.util.asks(OF.theme, "shape") then
        table.insert(rows, with_help(with_right(panel.door_for_either("vision",
            "costume_self", OF.lang.t("How players look..."),
            255, 255, 255, function() go("shapes") end),
            OF.lang.t(OF.theme.shape().name)),
            "what you wear, the shape everybody is drawn as, and the name over their head"))
    end

    table.insert(rows, header_row(OF.lang.t("The level and the save file")))

    if OF.util.asks(OF.warp, "build_page") then

        table.insert(rows, with_help(with_right(

            gated_row("vision", OF.lang.t("Level scale - stretch the level..."),
                255, 255, 255, function() go("warp") end),
            OF.util.asks(OF.warp, "is_on") and OF.warp.is_on()
                and OF.lang.t("resized") or ""),
            "the level's own things made wider, taller or deeper - a picture only, and a map reload takes it"))
    end
    table.insert(rows, with_help(gated_row("spawn_object",
        OF.forge.open and OF.lang.t("Forge: on...") or OF.lang.t("Forge - place things by hand..."),
        255, 255, 255, function() go("forge") end),
        OF.lang.t("build in the level: blocks, enemies and props put where you stand")))

    table.insert(rows, with_help(gated_row("save_edit",
        OF.lang.t("Save file editor - stars, keys, caps and doors..."), 255, 255, 255,
        function() go("save") end),
        "the lobby's own progress file - the game keeps no backup of it"))

    table.insert(rows, header_row(OF.lang.t("One player at a time")))

    table.insert(rows, with_help(with_right(
        gated_row("cheats_self", OF.lang.t("Cheats..."), 255, 255, 255,

            function() go("cheats") end),

        OF.lang.fill("@ on", OF.util.asks(OF.cheats, "page_count")
            and OF.cheats.page_count("cheats") or 0)),
        OF.lang.t("your own switches, with a box for the whole lobby's")))

    table.insert(rows, with_help(with_right(
        gated_row("cheats_self", OF.lang.t("Read-outs..."), 255, 255, 255,
            function() go("readouts") end),
        OF.lang.fill("@ on", OF.util.asks(OF.cheats, "page_count")
            and OF.cheats.page_count("readouts") or 0)),
        OF.lang.t("speed, time, where you are, and what the machine is doing underneath")))

    table.insert(rows, with_help(gated_row("powerup_self", OF.lang.t("Powerups..."),
        255, 255, 255, function() go("powerups") end),
        OF.lang.t("caps, coins, a star - the page asks who they go to")))

    if OF.util.asks(OF.camera, "build_page") then
        table.insert(rows, with_help(
            row(OF.util.asks(OF.camera, "active") and OF.camera.active()
                    and OF.lang.t("Photo mode: on...")
                    or OF.lang.t("Photo mode - fly the camera..."),
                255, 255, 255, function() go("camera") end),
            OF.lang.t("your camera off your Mario, the HUD away, and a move it can fly")))
    end

    return rows
end

function panel.build_lens()
    local rows = {}
    table.insert(rows, label_row(OF.lang.t(
        "Where the camera stands and how it moves. A ticks the lobby's box, Z yours.")))
    for _, r in ipairs(OF.util.asks(OF.modifiers, "build_rows")
            and OF.modifiers.build_rows(panel, "camera") or {}) do
        table.insert(rows, r)
    end
    table.insert(rows, back_row())
    return rows
end

local function build_roomrules()
    local rows = {}

    table.insert(rows, with_help(gated_row("rules", OF.lang.t("How the game plays..."), 255, 255, 255,
        function() go("rules") end),
        OF.lang.t("the game's own settings - stars, coins, caps, doors and the courses")))

    if OF.util.asks(OF.moves, "build_page") then
        table.insert(rows, with_help(row(
            OF.lang.t("Controls editor..."),
            255, 255, 255, function() go("moves") end),
            OF.lang.t("your own rapid fire, what anybody may press, the stick, and what a ground pound does")))
    end

    if OF.util.asks(OF.modifiers, "build_rows") then
        table.insert(rows, with_help(panel.door_for_either("speedrun", "modifier_self",
            OF.lang.t("The camera..."),
            255, 255, 255, function() go("lens") end),
            OF.lang.t("where the camera stands, how it follows, and which way up the picture is")))
    end

    if OF.util.asks(OF.modifiers, "build_rows") then
        local moving = OF.util.asks(OF.modifiers, "count_on_home")
            and OF.modifiers.count_on_home("body") or 0
        table.insert(rows, with_help(with_right(
            row(OF.lang.t("How everybody moves..."), 255, 255, 255,
                function() go("body") end),
            moving > 0 and OF.lang.fill("@ on", moving) or ""),
            OF.lang.t("upside down, how fast, how you land, the floor, and the speed you carry")))
    end

    if OF.util.asks(OF.harsh, "build_page") then
        table.insert(rows, with_help(with_right(

            row(OF.lang.t("Hard mode - what a mistake costs..."),
                255, 255, 255, function() go("harsh") end),
            OF.util.asks(OF.harsh, "any_on") and OF.harsh.any_on()
                and OF.lang.t("on") or ""),
            "coins that kill, a meter that drains while you stand about, a level that restarts on the first scratch - everybody plays under it"))
    end

    if OF.util.asks(OF.enemies, "build_page") then
        table.insert(rows, with_help(with_right(
            gated_row("speedrun", OF.lang.t("The course's own enemies..."),
                255, 255, 255, function() go("enemies") end),
            OF.util.asks(OF.enemies, "anything_on") and OF.enemies.anything_on()
                and OF.lang.t("retuned") or ""),
            "how they dress, how hard they hit, and how much of the level's own cast is left"))
    end

    if panel.PAGES ~= nil and panel.PAGES.sweep ~= nil then
        table.insert(rows, with_help(gated_row("warp_lobby",
            OF.lang.t("Clear the level out..."), 255, 255, 255,
            function() go("sweep") end),
            OF.lang.t("bosses, hazards, spawners, pickups - whole kinds of thing, swept out of the level")))
    end

    table.insert(rows, back_row())
    return rows
end

local function build_chance()
    local rows = {}

    table.insert(rows, with_help(gated_row("chaos", OF.lang.t("Randomizer..."),
        255, 220, 120, function() go("rando") end),
        OF.lang.t("a shuffled castle and a world drawn level by level, from rows you choose once")))

    if OF.util.asks(OF.chaos, "build_page") then
        local running = OF.util.asks(OF.chaos, "on") and OF.chaos.on()
        table.insert(rows, with_right(with_help(gated_row("chaos",
            running and OF.lang.t("Chaos: on...") or OF.lang.t("Chaos..."),
            255, running and 200 or 255, running and 120 or 255,
            function() go("chaos") end),
            OF.lang.t("the lobby deals itself something new on a clock, and never says what")),
            running and OF.util.asks(OF.chaos, "label") and OF.chaos.label() or ""))
    end

    if OF.util.asks(OF.modifiers, "build_demon_page") and panel.PAGES ~= nil
        and panel.PAGES.demon ~= nil then
        local level = OF.modifiers.active()["demon"] or 0
        local entry = OF.modifiers.BY_KEY["demon"]
        local stop = ""
        if level > 0 and entry ~= nil and entry.levels ~= nil
            and entry.levels[level] ~= nil then
            stop = OF.lang.t(entry.levels[level].name)
        end
        table.insert(rows, with_right(with_help(gated_row(OF.modifiers.ROW_RANK,
            level > 0 and OF.lang.t("Green Demon: on...") or OF.lang.t("Green Demon..."),
            255, level > 0 and 200 or 255, level > 0 and 120 or 255,
            function() go("demon") end),
            OF.lang.t("a 1-UP that comes after everybody, and how it hunts")),
            stop))
    end

    if OF.util.asks(OF.clones, "build_page") and panel.PAGES ~= nil
        and panel.PAGES.clones ~= nil and OF.modifiers ~= nil then
        local on = (OF.modifiers.active()["clones"] or 0) > 0
        table.insert(rows, with_right(with_help(gated_row(OF.modifiers.ROW_RANK,
            on and OF.lang.t("Cosmic Clones: on...") or OF.lang.t("Cosmic Clones..."),
            255, on and 200 or 255, on and 120 or 255,
            function() go("clones") end),
            OF.lang.t("dark copies of you, and how they follow")),
            on and OF.util.asks(OF.clones, "count_name") and OF.clones.count_name() or ""))
    end

    table.insert(rows, back_row())
    return rows
end

local function build_shapes_page()
    local figure = OF.theme.build_figure_page(panel)
    local rows, placed = {}, false
    local function wear_rows()
        table.insert(rows, with_help(header_row(OF.lang.t("What you wear")),
            OF.lang.t("your costume, your hat, the pet at your heels and your spray paint - no rank is asked")))
        table.insert(rows, with_help(with_right(
            row(OF.lang.t("Costumes - be something else..."), 255, 255, 255,
                function() go("costumes") end),
            OF.util.asks(OF.costumes, "name_worn")
                and (OF.costumes.name_worn(0) or OF.lang.t("your own face")) or ""),
            OF.lang.t("what the lobby can be, and what you are")))
        if OF.util.asks(OF.hats, "build_page") then
            table.insert(rows, with_help(with_right(
                row(OF.lang.t("Hats - wear something on your head..."),
                    255, 255, 255, function() go("hats") end),
                OF.util.asks(OF.hats, "name_worn")
                    and (OF.hats.name_worn(0) or OF.lang.t("nothing")) or ""),
                OF.lang.t("what the lobby can wear, and what you have on")))
        end
        if OF.util.asks(OF.pets, "build_page") then
            table.insert(rows, with_help(with_right(
                row(OF.lang.t("Pets - a friend at your heels..."),
                    255, 255, 255, function() go("pets") end),
                OF.util.asks(OF.pets, "name_of")
                    and (OF.pets.name_of(0) or OF.lang.t("nobody")) or ""),
                OF.lang.t("a creature that walks where you walk")))
        end

        if OF.util.asks(OF.spray, "build_page") and panel.PAGES ~= nil
            and panel.PAGES.spray ~= nil and OF.modifiers ~= nil then
            local on = (OF.modifiers.active()["spray"] or 0) > 0
            table.insert(rows, with_help(with_right(row(
                on and OF.lang.t("Spray paint: on...") or OF.lang.t("Spray paint..."),
                255, on and 200 or 255, on and 120 or 255,
                function() go("spray") end),
                OF.util.asks(OF.spray, "note") and OF.spray.note() or ""),
                OF.lang.t("your mark in your colour where you aim, and your pattern")))
        end
    end
    for _, r in ipairs(figure) do
        if not placed and r.heading == true then
            wear_rows()
            placed = true
        end
        table.insert(rows, r)
    end
    if not placed then
        local exit = table.remove(rows)
        wear_rows()
        table.insert(rows, exit)
    end
    return rows
end

local function build_control()
    local rows = {}

    table.insert(rows, header_row(OF.lang.t("Ranks and moderation")))

    table.insert(rows, with_help(gated_row("settings", OF.lang.t("Moderation..."),
        255, 255, 255, function() go("order") end),
        OF.lang.t("ranks and permissions, mutes, bans, warnings, notes and the chat filter")))

    table.insert(rows, header_row(OF.lang.t("Logs and what is running")))

    table.insert(rows, with_help(with_right(
        host_row("jail", OF.lang.t("Action log..."), 255, 220, 120,
            function() go("actionlog") end,

            function()
                go("actionlog")
                OF.util.report(OF.actionlog.ask_copy())
            end),
        tostring(OF.util.asks(OF.actionlog, "shown_count") and OF.actionlog.shown_count() or 0)),
        "every action anybody took in this mod menu, with the name and the time"))

    table.insert(rows, with_right(
        with_help(row(OF.lang.t("Chat log..."), 255, 255, 255,
            function() go("chatlog") end),
            OF.lang.t("what the lobby has said, kept on this machine for this session")),
        tostring(#((OF.chatlog ~= nil and OF.chatlog.entries) or {}))))

    local clashing = OF.util.asks(OF.roommods, "clashes")
        and #OF.roommods.clashes() or 0
    table.insert(rows, with_help(with_right(
        row(OF.lang.t("Other mods in this lobby..."), 255, 255, 255,
            function() go("roommods") end),
        clashing > 0 and tostring(clashing) or ""),
        OF.lang.t("every mod running in this lobby, and which two of them were built to be run apart")))

    if OF.util.asks(OF.trouble, "rules_changed") then
        local watched = OF.trouble.rules_changed()
        table.insert(rows, with_help(with_right(host_row("settings",
            OF.lang.t("Automatic actions..."), 255, 255, 255,
            function() go("autorules") end,

            function()
                go("autorules")
                OF.util.report(OF.net.cohost_does(OF.trouble.SEND_ACTION))
            end),
            watched > 0 and tostring(watched) or ""),
            OF.lang.t("everything that acts without being pressed, and one press to watch instead")))
    end

    table.insert(rows, header_row(OF.lang.t("In an emergency")))

    local held = OF.util.asks(OF.lockdown, "held_by_host") and OF.lockdown.held_by_host()
    local brakeText = held and OF.lang.t("Let the lobby go again")
        or OF.lang.t("Freeze the lobby - only you can act")
    local brake
    if OF.util.is_host() then
        brake = host_row("jail", brakeText,
            held and 120 or 255, held and 255 or 200, held and 140 or 90, function()

                OF.util.report(OF.lockdown.toggle_hold(0))
            end)
    elseif OF.perms.is_cohost(0) then

        brake = row(brakeText,
            held and 120 or 255, held and 255 or 200, held and 140 or 90,
            panel.ask_host(panel.BRAKE_ACTION, held and "off" or "on"))
    else

        brake = label_row(brakeText .. "   " .. OF.lang.t("(host only)"))
        brake.hostOnly = true
    end
    table.insert(rows, with_help(brake, "modifiers off, cheats off, nobody but you can do anything"))

    table.insert(rows, with_help(gated_confirm_row("settings", "freshroom",
        OF.lang.t("Reset the lobby, keep what players chose"), 255, 200, 120,
        function()
            OF.util.report(OF.fresh.run(true))
        end), "the round, the modifiers and every sentence - but not what somebody put on themselves"))

    table.insert(rows, with_help(gated_confirm_row("settings", "freshstart",
        OF.lang.t("Reset everything"), 255, 200, 120, function()
            OF.util.report(OF.fresh.run())
        end), "the round, the modifiers, the cheats and every sentence, all put back"))

    return rows
end

local function build_order()
    local rows = {}

    table.insert(rows, header_row(OF.lang.t("Keeping order")))

    local reportCount = OF.util.asks(OF.recent, "report_count")
        and OF.recent.report_count() or 0
    table.insert(rows, with_help(with_right(
        gated_row("mute", OF.lang.t("Reports..."),
            255, reportCount > 0 and 200 or 255, reportCount > 0 and 120 or 255,
            function() go("reports") end),
        reportCount > 0 and tostring(reportCount) or ""),
        OF.lang.t("who the lobby has asked you to look at, and what is still on people")))

    local quietOn = OF.mute.quiet_on()

    local quietG = quietOn and 176 or 255
    local quietB = quietOn and 96 or 255
    table.insert(rows, with_help(with_right(host_row("mute",
        quietOn and OF.lang.t("Quiet mode is ON") or OF.lang.t("Quiet mode"),
        255, quietG, quietB,
        function()

            OF.util.report(OF.mute.set_quiet(OF.mute.quiet_step(), 0))
        end),
        OF.mute.quiet_name()),
        OF.lang.t("only that rank and above may talk - press to step it")))

    table.insert(rows, with_help(gated_row("mute",
        OF.lang.fill("Muted players (@)", OF.mute.count()),
        255, 255, 255, function() go("mutes") end),
        OF.lang.t("who cannot talk, why, and one press to give it back")))

    table.insert(rows, with_help(with_right(gated_row("mute",
        OF.lang.fill("Warnings on record (@)", OF.jail.warn_total()),
        255, 255, 255, function() go("warnings") end),
        OF.jail.escalates() and OF.lang.t("escalates") or OF.lang.t("record only")),
        OF.lang.t("a word before a punishment, and the lobby remembers it")))

    table.insert(rows, with_help(panel.with_tone(gated_row("ban",
        OF.lang.fill("Ban list (@)", OF.jail.ban_count()),
        255, 255, 255, function() go("bans") end), false),
        OF.lang.t("who the lobby will not let back in, and one press to forgive")))
    table.insert(rows, with_help(gated_row("ban",
        OF.lang.fill("Notes on players (@)", OF.notes.count()),
        255, 255, 255, function() go("notes") end),
        OF.lang.t("what you wrote down about somebody, for the next session")))
    table.insert(rows, with_help(gated_row("settings",
        OF.lang.fill("Chat filter (@ words)", OF.filter.count()),
        255, 255, 255, function() go("filter") end),
        OF.lang.t("words this lobby will not carry, and what happens to a line holding one")))

    table.insert(rows, with_help(gated_confirm_row("jail", "amnesty",
        OF.lang.t("Lift every mute and sentence"), 120, 255, 140, function()

            OF.util.report(OF.jail.amnesty(0))
        end), "everybody in the lobby, race exclusions too - the ban list stays"))

    table.insert(rows, header_row(OF.lang.t("Ranks")))

    table.insert(rows, with_help(host_row("settings",
        OF.lang.t("Ranks and permissions..."),
        255, 255, 255, function() go("perms") end),
        OF.lang.t("which rank each feature wants, one row per feature")))

    table.insert(rows, with_help(host_row("settings",
        OF.lang.t("What each rank can do..."),
        255, 255, 255, function() go("permladder") end),
        OF.lang.t("the same ladder read from the other end, rung by rung")))

    table.insert(rows, with_help(gated_row("ranks",
        OF.lang.t("Promote or demote somebody..."),
        255, 255, 255, function() go("permwho") end),
        OF.lang.t("everybody in the lobby, what they hold, and one press to move it")))
    table.insert(rows, with_help(host_row("settings",
        OF.lang.t("The rungs of the ladder..."),
        255, 255, 255, function() go("permrungs") end),
        OF.lang.t("how many ranks this lobby has, and what each one is called")))

    table.insert(rows, with_help(host_row("ranks",
        OF.lang.fill("Remembered ranks (@)", OF.ranks.remembered_count()),
        255, 255, 255, function() go("remembered") end),
        OF.lang.t("who keeps a rank when they are not in the lobby")))

    if OF.util.asks(OF.perms, "build_shields_page") then
        table.insert(rows, with_help(gated_row("ranks",
            OF.lang.t("Who is protected..."),
            255, 255, 255, function() go("permshield") end),
            OF.lang.t("who a moderator may not act on, whatever rank they hold")))
    end

    table.insert(rows, back_row())
    return rows
end

local function build_autorules()
    local rows = {}

    local list = OF.util.asks(OF.trouble, "rule_list") and OF.trouble.rule_list()
        or {}

    for _, def in ipairs(list) do

        table.insert(rows, with_help(with_right(host_row("settings",
            OF.lang.t(def.name), 255, 255, 255, function()
                OF.trouble.set_mode(def.key,
                    OF.trouble.next_mode(OF.trouble.mode(def.key)))
            end, panel.ask_host(OF.trouble.CYCLE_ACTION, def.key)),
            OF.lang.t(OF.trouble.mode_name(OF.trouble.shown_mode(def.key)))),
            OF.lang.t(def.help)))
    end

    if #rows == 0 then
        table.insert(rows, label_row(OF.lang.t(
            "No automatic rules are registered in this build.")))
    end

    table.insert(rows, back_row())
    return rows
end

local function build_me()
    local rows = {}

    table.insert(rows, panel.with_key(with_help(with_right(
        panel.with_tone(row(OF.lang.t("Find anything..."), 255, 220, 120, function()
            if OF.util.asks(OF.find, "open") and OF.find.open() then return end
            go("find")
        end), "key"), "/search"),
        OF.lang.t("every row in the menu, by name - type the word on the right in chat, and what you want")),
        "findanything"))

    table.insert(rows, header_row(OF.lang.t("Look")))

    table.insert(rows, with_help(row(OF.lang.t("Theme..."), 255, 255, 255,
        function() go("theme") end),
        OF.lang.t("the colours this menu is drawn in and how it sounds, on your screen only")))

    table.insert(rows, with_help(row(OF.lang.t("The menu's size and place..."),
        255, 255, 255, function() go("place") end),
        OF.lang.t("how wide and tall this menu is drawn, and where it sits")))

    table.insert(rows, header_row(OF.lang.t("On your screen")))

    if OF.util.asks(OF.theme, "build_screen_page") then
        table.insert(rows, with_help(
            row(OF.lang.t("Marks over players, and the notices..."),
                255, 255, 255, function() go("screen") end),
            OF.lang.t("the marks over players, the round board, the fanfare, and how a win looks")))
    end

    table.insert(rows, with_help(row(OF.lang.t("When somebody arrives..."), 255, 255, 255,
        function() go("arrivals") end),
        OF.lang.t("the banner and the chat line you see when a player joins or goes")))

    table.insert(rows, header_row(OF.lang.t("Controls and shortcuts")))

    table.insert(rows, with_help(row(OF.lang.t("Your controls - the pad and this menu..."),
        255, 255, 255, function() go("controls") end),
        OF.lang.t("which button opens this menu, and what the pad does while it is open")))

    table.insert(rows, with_help(row(OF.lang.t("Your shortcuts - what you press most..."),
        255, 255, 255, function() go("quick") end),
        OF.lang.t("the rows you press most, gathered onto one page")))

    table.insert(rows, with_help(
        row(OF.lang.t("Commands - what you can type..."), 255, 255, 255,
            function() go("commands") end),
        OF.lang.t("every word this mod adds to the chat box, grouped")))

    return rows
end

local function build_arrivals()
    local rows = {}

    if not OF.util.asks(OF.settings, "set_show_banner") then
        table.insert(rows, label_row(OF.lang.t("Settings are not loaded.")))
        table.insert(rows, back_row())
        return rows
    end

    table.insert(rows, with_help(
        row(panel.tick(OF.settings.showBanner,
            OF.lang.t("Welcome banner")), 255, 255, 255, function()
                OF.settings.set_show_banner(not OF.settings.showBanner)
            end),
        "the big hello across the middle of the screen, yours and everybody else's"))

    local low = (OF.modmenu ~= nil and OF.modmenu.BANNER_MIN) or 2
    local high = (OF.modmenu ~= nil and OF.modmenu.BANNER_MAX) or 15
    local seconds = OF.util.clamp(OF.settings.bannerSeconds or low, low, high)

    local secondsRow = row(OF.lang.t("Banner seconds"),
        255, 220, 120, function()
            local wanted = seconds + 1
            if wanted > high then wanted = low end
            OF.settings.set_banner_seconds(wanted)
        end)
    secondsRow = with_right(secondsRow, tostring(seconds))
    table.insert(rows, with_help(with_slider(secondsRow, seconds - low, high - low,
        function(wanted) OF.settings.set_banner_seconds(low + wanted) end),
        "how long it stays before it fades"))

    table.insert(rows, with_help(
        row(panel.tick(OF.settings.announceJoins,
            OF.lang.t("Announce joins and leaves")), 255, 255, 255, function()
                OF.settings.set_announce_joins(not OF.settings.announceJoins)
            end),
        "the green and the red line in chat when somebody comes or goes"))

    table.insert(rows, with_help(row(OF.lang.t("Preview the welcome banner"),
        255, 255, 255, function()
        OF.welcome.greet(0, OF.lang.t("Preview"))
        panel.close()
    end), OF.lang.t("shows you the banner once, so the seconds dial means something")))

    table.insert(rows, back_row())
    return rows
end

local function build_place()
    local rows = {}

    table.insert(rows, with_help(row(OF.lang.t(panel.RESET_ROW),
        255, 200, 120, function()
        panel.reset_place()
    end), OF.lang.t("puts every dial on this page back where the menu shipped")))

    table.insert(rows, label_row(OF.lang.t("Drag the title bar to move it, or dial it here.")))

    local DIALS = {
        { which = "x", name = OF.lang.t("Across"),
          help = OF.lang.t("how far across the screen the menu sits") },
        { which = "y", name = OF.lang.t("Down"),
          help = OF.lang.t("how far down the screen the menu sits") },
    }
    for _, dial in ipairs(DIALS) do
        local which = dial.which
        local built = with_right(row(OF.lang.t(dial.name), 255, 255, 255,
            function() end), panel.place[which] .. "%")
        table.insert(rows, with_help(with_slider(built, panel.place_step(which),
            panel.place_steps(which), function(wanted)
                OF.util.report(panel.set_place_step(which, wanted))
            end), dial.help))
    end

    do
        local at, preset = panel.place_preset()
        local built = with_right(row(OF.lang.t("Where it sits"), 255, 255, 255, function()
            OF.util.report(panel.set_place_preset(((at or 0) % #panel.PLACE_PRESETS) + 1))
        end), preset ~= nil and OF.lang.t(preset.name) or OF.lang.t("Your own spot"))
        table.insert(rows, with_help(with_slider(built, (at or 1) - 1, #panel.PLACE_PRESETS - 1,
            function(wanted)
                OF.util.report(panel.set_place_preset(wanted + 1))
            end), OF.lang.t("the middle, a corner or an edge - Across and Down move it from there")))
    end

    if OF.util.asks(OF.panelskin, "size_step") then
        local skin = OF.panelskin
        local built = with_right(row(OF.lang.t("Size"), 255, 255, 255, function()
            OF.util.report(panel.set_size_step((skin.size_step() + 1) % #skin.SIZES))
        end), skin.size_word())
        table.insert(rows, with_help(with_slider(built, skin.size_step(), #skin.SIZES - 1,
            function(wanted)
                OF.util.report(panel.set_size_step(wanted))
            end), OF.lang.t("three quarters up to the whole screen - a smaller menu fits less of a"
                .. " row's sentence on one line")))
    end

    table.insert(rows, label_row(OF.lang.t(
        "A smaller menu cuts the line under the cursor, and the half it cuts "
        .. "is the half that carries the warning.")))

    table.insert(rows, back_row())
    return rows
end

local function build_players()
    local rows = {}
    local selected = panel.selection_count()

    local ticks = "A"
    local mousing = false
    local device = OF.util.asks(OF.input, "device") and OF.input.device() or "pad"
    if device == "mouse" then
        ticks = "A click"
    elseif device ~= "pad" then
        ticks = "A (or a click)"
    end
    if OF.util.asks(OF.input, "mouse_driving") then
        mousing = OF.input.mouse_driving()
    end
    local how = mousing and OF.lang.fill("@ ticks a name", ticks)
        or OF.lang.fill("@ ticks a name, @ opens one", ticks, "Z")
    local doing = OF.util.asks(OF.presence, "lobby_line")
        and OF.presence.lobby_line() or nil
    if doing ~= nil and doing ~= "" then
        table.insert(rows, label_row(doing .. "\\#808080\\  -  " .. how))
    else
        table.insert(rows, label_row(how))
    end

    if OF.util.asks(OF.emotes, "build_page") then
        table.insert(rows, with_help(with_right(
            row(OF.lang.t("Emotes - say something without typing..."),
                255, 255, 255, function() go("emotes") end),
            OF.util.asks(OF.emotes, "count")
                and OF.lang.fill("@ on the wheel", OF.emotes.count()) or ""),
            OF.lang.t("a wheel on a shoulder button: wave, point, sit, cheer")))
    end

    if OF.util.asks(OF.shortcuts, "rows") then
        for _, r in ipairs(OF.shortcuts.rows(panel)) do table.insert(rows, r) end
    end

    table.insert(rows, header_row(OF.lang.t("Who is here")))

    for _, entry in ipairs(OF.util.connected_players()) do
        local tier = OF.ranks.get(entry.localIndex)
        local r, g, b = OF.ranks.color(tier)
        local globalIndex = network_global_index_from_local(entry.localIndex)

        local ticked = panel.selection[globalIndex] == true

        local shown, rankTag = player_display(entry)
        local playerRow = with_help(with_right(
            row(panel.tick(ticked, shown), r, g, b,
                function() panel.selection_toggle(globalIndex) end),
            player_where(entry)),
            OF.lang.t("A ticks this name, Z opens it; the door below acts on everybody ticked"))

        playerRow.rankTag = rankTag or ""
        playerRow.nameRaw = entry.np.name
        playerRow.ticks = true
        playerRow.localIndex = entry.localIndex
        playerRow.rankColour = { r, g, b }

        playerRow.selection = true

        playerRow.swatch = true

        playerRow.altAction = function()
            panel.selected = globalIndex
            go("player")
        end
        playerRow.altPad = true
        playerRow.altLabel = "open"
        table.insert(rows, playerRow)
    end

    if OF.spectate.is_active() then
        table.insert(rows, header_row(OF.lang.t("The shot you are watching")))

        local picking = OF.spectate.auto == true
        table.insert(rows, with_help(row(picking
            and OF.lang.t("The camera picks for itself: on")
            or OF.lang.t("The camera picks for itself: off"),
            255, 255, 255, function()
                if OF.util.report(OF.spectate.set_auto(not picking)) then
                    panel.rebuild()
                end
            end), OF.lang.t("the shot moves to whoever is worth watching, on its own")))

        local jobs = OF.util.asks(OF.gamemodes, "roles_dealt")
            and OF.gamemodes.roles_dealt() or {}
        if #jobs > 0 then
            local following = OF.spectate.role

            local at = 0
            for index, job in ipairs(jobs) do
                if job == following then at = index end
            end
            local nextJob = jobs[at + 1]
            table.insert(rows, with_help(row(following ~= nil
                and OF.lang.fill("Follow the job: @", following)
                or OF.lang.t("Follow the job: nobody"),
                255, 255, 255, function()
                    if OF.util.report(OF.spectate.watch_role(nextJob)) then
                        panel.rebuild()
                    end
                end),
                OF.lang.t("the shot follows whoever holds the job, and moves when it moves")))
        end
    end

    table.insert(rows, header_row(OF.lang.t("What you can do")))

    local connected = OF.util.connected_players()
    local allSelected = selected >= #connected and #connected > 0

    table.insert(rows, with_help(row(
        allSelected and OF.lang.t("Unselect everybody") or OF.lang.t("Select everybody"),
        255, 255, 255, function()
            if allSelected then
                panel.selection_clear()
                return
            end
            for _, entry in ipairs(connected) do
                panel.selection[network_global_index_from_local(entry.localIndex)] = true
            end
            panel.dirty = true
        end), allSelected
            and OF.lang.t("takes every tick off the list at once")
            or OF.lang.t("ticks every name on the list at once")))

    table.insert(rows, with_help(row(OF.lang.t("Select everybody but me"),
        255, 255, 255, function()
        panel.selection_clear()
        local me = network_global_index_from_local(0)
        for _, entry in ipairs(connected) do
            local globalIndex = network_global_index_from_local(entry.localIndex)
            if globalIndex ~= me then panel.selection[globalIndex] = true end
        end
        panel.dirty = true
    end), OF.lang.t("ticks the whole lobby and leaves your own name alone")))

    local doorText = OF.lang.t("Actions for the ticked players...")
    if selected > 0 then
        doorText = OF.lang.fill("Actions for the @ ticked...", selected)
    end

    table.insert(rows, with_help(panel.with_tone(row(doorText,
        selected > 0 and 120 or 255, 255, selected > 0 and 120 or 255,
        function()
            local ticked = panel.selection_list()

            if #ticked == 0 then
                go("multi")
                return
            end

            local carryOn, why = panel.aim_check("selected")
            if why ~= nil then OF.util.report(false, why) end
            if not carryOn then return end
            go("multi")
        end), selected > 0 and "key" or false),
        OF.lang.t("move them, give them something, do something to them, or moderate them")))

    if OF.util.asks(OF.swap, "build_room_rows") then
        for _, r in ipairs(OF.swap.build_room_rows(panel)) do
            table.insert(rows, r)
        end
    end

    local incidentEntry, isIncident = OF.recent.target()
    if incidentEntry ~= nil and isIncident then

        table.insert(rows, with_help(with_right(gated_row("mute",
            OF.lang.fill("Mute @", incidentEntry.name),
            255, 200, 120, function() OF.util.report(OF.recent.mute_last()) end),
            incidentEntry.what),
            OF.lang.t("stops the lobby reading what they type in chat")))

        table.insert(rows, with_help(gated_confirm_row("jail",
            "clearlast" .. tostring(incidentEntry.id),
            OF.lang.fill("Wrong person - take it all back off @",
                incidentEntry.name),
            120, 255, 140, function()
                OF.util.report(OF.recent.clear_last())
            end),
            OF.lang.t("the ban, the sentence, the mute and sitting out races - and it still lands after they have left")))
    end

    if OF.util.asks(OF.together, "build_page") then
        table.insert(rows, with_help(row(
            OF.lang.t("Players together - stand on, carry, rope..."),
            255, 255, 255, function() go("together") end),
            OF.lang.t("stand on each other, throw each other about, or tie the whole lobby together")))
    end

    if OF.util.asks(OF.lobbytalk, "build_page") then
        table.insert(rows, with_help(panel.with_pulse(with_right(row(
            OF.lang.t("Talk to the lobby - polls, ready check, clock..."),
            255, 255, 255, function() go("lobbytalk") end),
            OF.lobbytalk.summary()), panel.live("vote", "poll", "ready", "countdown")),
            OF.lang.t("polls, rock the vote, a ready check, a clock, and team chat")))
    end

    return rows
end

local function identity_of(localIndex)
    local id = OF.util.player_id(localIndex)
    if id == nil then return OF.lang.t("no id at all") end
    local coopnet = string.match(id, "^cn(.+)$")
    if coopnet ~= nil then
        return OF.lang.fill("CoopNet @", coopnet)
    end
    return OF.lang.t("no CoopNet id - filed by name")
end

panel.identity_of = identity_of

local function build_player()
    local li = OF.util.local_from_global(panel.selected)
    if li == nil then
        return { label_row(OF.lang.t("That player has left.")), back_row() }
    end

    local rows = {}
    local np = gNetworkPlayers[li]
    local me = network_global_index_from_local(0)
    local isSelf = panel.selected == me
    local tier = OF.ranks.get(li)

    local nameR, nameG, nameB = OF.ranks.color(tier)
    local nameRow = label_row(np.name .. "  -  " .. OF.perms.tier_name(tier)
        .. "  -  " .. player_where({ localIndex = li, np = np })
        .. OF.lang.fill("  -  ping @", tostring(np.ping)),
        nameR, nameG, nameB)
    nameRow.swatch = true
    table.insert(rows, nameRow)

    table.insert(rows, label_row(identity_of(li), 170, 190, 215))

    for _, r in ipairs(OF.idle.build_rows(panel, li)) do table.insert(rows, r) end

    table.insert(rows, header_row(OF.lang.t("Move and do")))
    if not isSelf then
        table.insert(rows, with_help(gated_row("teleport_other", OF.lang.fill("Teleport @ to me", np.name),
            255, 255, 255, function()
                local ok, why = OF.net.summon_player(panel.selected, me)
                if not OF.net.report_move(ok, why,
                        OF.lang.fill("Summoned @.", OF.util.plain(np.name))) then
                    return
                end

                local mine = gNetworkPlayers[0]
                OF.notify.send_to(panel.selected, "@ pulled you over", "info",
                    nil, OF.util.plain(mine ~= nil and mine.name or "Somebody"))
            end), OF.lang.t("pulls them to where you are standing, and tells them who did")))
    end
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.fill("Send @ to the moon", np.name), 255, 200, 120, function()
            OF.util.report(OF.net.moon_player(panel.selected))
        end), OF.lang.t("straight up, tumbling, and they land unharmed")))
    table.insert(rows, with_help(gated_row("teleport_self", OF.lang.fill("Teleport me to @", np.name),
        255, 255, 255, function()
            OF.net.teleport_to(panel.selected)
            panel.close()
        end), OF.lang.t("moves you to them; nobody else is touched")))
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.fill("Teleport everybody to @", np.name),
        255, 255, 255, function()
            local moved, why = OF.net.summon_everyone_to(panel.selected)
            OF.net.report_move(moved > 0, why,
                OF.lang.fill("Sent @ player(s) to @.", moved, np.name))
            panel.close()
        end), OF.lang.t("pulls the whole lobby to them, wherever they are")))
    if panel.selection_count() > 0 then
        table.insert(rows, with_help(gated_row("teleport_other", OF.lang.fill("Teleport the @ selected to @", panel.selection_count(), np.name),
            255, 255, 255, function()
                local moved, why =
                    OF.net.summon_many(panel.selection_list(), panel.selected)
                OF.net.report_move(moved > 0, why,
                    OF.lang.fill("Sent @ player(s) to @.", moved, np.name))
                panel.close()
            end), OF.lang.t("pulls everybody ticked on the list to them")))
    end

    table.insert(rows, with_help(gated_row("teleport_other",
        OF.lang.fill("Send @ to another player...", np.name), 255, 255, 255,
        function()
            panel.pickMode = "one"
            go("pick")
        end), OF.lang.t("pulls them to somebody you pick next")))

    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.fill("Send @ somewhere...", np.name),
        255, 255, 255, function()
            panel.levelMode = "player"
            go("groups")
        end), OF.lang.t("moves this one player to a level you pick next")))

    for _, r in ipairs(OF.swap.build_rows(panel, li)) do table.insert(rows, r) end

    if OF.util.asks(OF.together, "build_rows") then
        for _, r in ipairs(OF.together.build_rows(panel, li)) do
            table.insert(rows, r)
        end
    end
    if not isSelf then
        table.insert(rows, with_help(gated_row("spectate", OF.lang.fill("Spectate @", np.name), 255, 255, 255, function()
            OF.spectate.start(panel.selected)
            panel.close()
        end), OF.lang.t("watch through their eyes until you stop, on Travel")))
    end

    local message = OF.settings.screenMessage or ""
    if message ~= "" then
        table.insert(rows, with_help(gated_row("message", OF.lang.fill('Show @: "@"', np.name, message),
            255, 215, 0, function()
                OF.net.announce_to({ panel.selected }, message)

                OF.notify.show("Message shown to @.", "info", 4,
                    OF.util.plain(np.name))
            end), OF.lang.t("puts the banner you typed on their screen and nobody else's")))
    end

    table.insert(rows, with_help(gated_row("powerup_other",
        OF.lang.fill("Do something to @...", np.name), 255, 200, 120,
        function()
            panel.open_aimed("doto", "player")
        end), OF.lang.t("zap, flatten, suck under - done once, to them")))

    if not isSelf then
        table.insert(rows, header_row(OF.lang.t("Rank")))

        local length = OF.ranks.length(panel.rankLength)
        local standing = ""
        if OF.util.is_host() then
            local at = OF.ranks.expires_at(OF.util.player_id(li))
            if at > 0 then
                standing = OF.lang.fill("theirs ends in @",
                    OF.jail.until_text(at))
            end
        end
        table.insert(rows, with_help(with_right(gated_row("ranks",
            OF.lang.t("A promotion lasts"), 255, 220, 120, function()
                panel.rankLength = OF.ranks.next_length(panel.rankLength)
            end),
            standing ~= "" and standing or OF.lang.t(length.name)),
            OF.lang.t("how long the rank the row below hands out is kept for")))

        local upTier = OF.perms.step_tier(tier, 1)
        if OF.ranks.may_offer(upTier) then
            local promoteText = OF.lang.fill("Promote to @ @",
                OF.lang.t(OF.perms.tier_name(upTier)), OF.lang.t(length.name))
            local function promote()

                OF.util.report(OF.ranks.promote(li, length.minutes))
            end
            local promoteRow = OF.ranks.asks_twice(upTier)
                and gated_confirm_row("ranks", "rankcohost" .. tostring(li),
                    promoteText, 255, 215, 0, promote)
                or gated_row("ranks", promoteText, 255, 215, 0, promote)
            table.insert(rows, with_help(panel.with_key(promoteRow, "rankpromote"),
                OF.ranks.asks_twice(upTier)
                    and OF.lang.t("makes them the host's second - press again to confirm")
                    or OF.lang.t("moves them one rung up the ladder, for the length above")))
        end
        table.insert(rows, with_help(gated_row("ranks", OF.lang.fill("Demote to @",
            OF.lang.t(OF.perms.tier_name(OF.perms.step_tier(tier, -1)))),
            200, 200, 200, function()
                OF.util.report(OF.ranks.demote(li))
            end), OF.lang.t("moves them one rung down the ladder, straight away")))

        table.insert(rows, header_row(OF.lang.t("Moderate")))

        local warned = OF.util.is_host()
            and OF.jail.warn_count(OF.util.player_id(li)) or 0
        table.insert(rows, with_help(with_right(gated_row("mute",
            OF.lang.fill("What @ has done...", np.name), 255, 255, 255,
            function() go("record") end),
            warned > 0 and OF.lang.fill("@ warning(s)", warned) or ""),
            OF.lang.t("their whole record in one place, before you decide anything")))

        table.insert(rows, with_help(with_right(gated_row("jail",
            OF.lang.t("Reason for this"), 255, 220, 120, function()
                panel.modReason = OF.jail.next_reason(panel.modReason)
            end),
            OF.jail.reason_text(panel.modReason)),
            OF.lang.t("rides along with the warning, the sentence and the ban")))

        table.insert(rows, with_help(with_right(gated_row("mute",
            OF.lang.fill("Warn @", np.name), 255, 220, 120, function()
                OF.util.report(OF.jail.warn(li, panel.modReason))
            end),
            OF.util.is_host()
                and (OF.jail.warn_next_step(OF.util.player_id(li))
                    or OF.jail.reason_text(panel.modReason))
                or OF.jail.reason_text(panel.modReason)),
            OF.lang.t("a word on their screen, kept on their record")))
        if warned > 0 then
            table.insert(rows, with_help(gated_row("mute",
                OF.lang.fill("Forgive @ - wipe their warnings", np.name),
                160, 255, 160, function()
                    OF.util.report(OF.jail.forgive(li))
                end), OF.lang.t("wipes the warnings off their record, back to none")))
        end

        local muteText = OF.lang.fill("Mute @", np.name)
        if OF.mute.is_muted(li) then muteText = OF.lang.fill("Unmute @", np.name) end
        table.insert(rows, with_help(gated_row("mute", muteText, 255, 180, 90, function()
            OF.mute.toggle(li)
        end), OF.lang.t("stops the lobby reading what they type in chat")))

        for _, kind in ipairs({ OF.speedrun.KIND_MODE, OF.speedrun.KIND_RUN }) do
            local words = kind == OF.speedrun.KIND_RUN and OF.speedrun.JOIN_RUNS
                or OF.speedrun.JOIN_MODES
            local help = kind == OF.speedrun.KIND_RUN and OF.speedrun.JOIN_RUNS_HELP
                or OF.speedrun.JOIN_MODES_HELP
            if OF.speedrun.muted_out(li) then

                table.insert(rows, with_help(label_row(panel.tick(false, OF.lang.t(words))
                    .. "   " .. OF.lang.t("(Muted)")),
                    OF.lang.t("muted players take no part until they are raised")))
            else
                local out = OF.speedrun.chose_out(li, kind)
                table.insert(rows, with_help(gated_row("speedrun",
                    panel.tick(not out, OF.lang.t(words)), 255, 255, 255, function()
                        OF.util.report(OF.speedrun.set_excluded(li, not out, kind))
                    end), OF.lang.t(help)))
            end
        end

        if OF.jail.is_jailed(li) then
            table.insert(rows, with_help(panel.acts(gated_row("jail", OF.lang.fill("Release @ and send home", np.name),
                120, 255, 120, function()
                    OF.util.report(OF.jail.release(li, true))
                    go("players")
                end)), OF.lang.t("ends the sentence they are serving and puts them back")))
        else

            local worst = OF.jail.max_sentence()
            table.insert(rows, with_help(panel.acts(with_right(gated_confirm_row("jail",
                "jail_" .. tostring(worst.key), OF.lang.fill("Jail @", np.name),
                255, 140, 90, function()
                    local why = nil
                    if panel.modReason ~= "none" then
                        why = OF.jail.reason_text(panel.modReason)
                    end
                    OF.util.report(OF.jail.punish(li, worst.key, why))
                    go("players")
                end), OF.lang.t(worst.short))),
                OF.lang.t("holds them until somebody lifts it, with the reason above")))
        end

        local carrying = OF.mute.is_muted(li) or OF.jail.is_jailed(li)
            or (OF.util.asks(OF.speedrun, "chose_out")
                and OF.speedrun.chose_out(li))
        if carrying then
            table.insert(rows, with_help(confirm_row("clearplayer",
                OF.lang.fill("Wrong person - take everything off @", np.name),
                120, 255, 140, function()
                    OF.util.report(OF.jail.clear_player(li))
                end), OF.lang.t("undoes every mute, sentence and exclusion this person is carrying")))
        end

        table.insert(rows, with_help(gated_row("vote", OF.lang.fill("Ask the lobby to jail @", np.name),
            255, 200, 120, function()
                OF.util.report(OF.vote.start("jail", panel.selected))
                go("vote")
            end), OF.lang.t("puts it to the lobby instead of deciding it yourself")))

        table.insert(rows, OF.notes.note_row(panel, li))

        table.insert(rows, with_help(gated_row("ban", OF.lang.fill("Ban @ (lobby list)...", np.name), 255, 90, 90,
            function() go("ban_confirm") end),
            OF.lang.t("keeps them out of this lobby; the length is set on the next page")))
        for _, r in ipairs(panel.game_command_rows(li)) do table.insert(rows, r) end
        table.insert(rows, with_help(row(OF.lang.t("How to actually disconnect them..."),
            200, 200, 200, function()
            go("kickhelp")
        end), OF.lang.t("what to type, because no mod may press the game's own kick")))
    end

    table.insert(rows, back_row())
    return rows
end

function panel.game_command_rows(li)
    local np = li ~= nil and gNetworkPlayers[li] or nil
    if np == nil then return {} end
    local name = OF.util.plain(tostring(np.name or ""))
    local function print_command(command, what)
        local canKick = OF.util.is_host()
            or (network_is_moderator ~= nil and network_is_moderator() == true)
        if not canKick then
            OF.util.report(false, "The game's own kick and ban need the host or a Coop DX moderator.")
            return
        end
        OF.util.chat(OF.lang.fill("@: @", OF.lang.t(what),
            command .. " " .. name))
        OF.util.chat(OF.lang.fill("Then: @", "/confirm"))
        panel.close()
    end

    return {
        panel.past_ceiling(panel.with_tone(with_help(row(OF.lang.fill("Kick @ - into chat", name), 255, 90, 90,
            function() print_command("/kick", "Kick") end),
            OF.lang.t("the game's own /kick with their name in it, ready to send")), "danger"),
            "kick-ban-into-chat"),
        panel.past_ceiling(panel.with_tone(with_help(row(OF.lang.fill("Ban @ from the game - into chat", name), 255, 90, 90,
            function() print_command("/ban", "Ban") end),
            OF.lang.t("the game's own /ban with their name in it, ready to send")), "danger"),
            "kick-ban-into-chat"),
    }
end

local function build_record()
    local li = OF.util.local_from_global(panel.selected)
    if li == nil then
        return { label_row(OF.lang.t("That player has left.")), back_row() }
    end

    local np = gNetworkPlayers[li]
    local rows = {}
    local tier = OF.ranks.get(li)

    local nameRow = label_row(np.name .. "  -  " .. OF.perms.tier_name(tier),
        OF.ranks.color(tier))
    nameRow.swatch = true
    table.insert(rows, nameRow)

    table.insert(rows, header_row(OF.lang.t("Right now")))
    local holding = {}
    if OF.mute.is_muted(li) then table.insert(holding, "muted") end
    local serving = OF.jail.sentence_of(li)
    if serving ~= nil then table.insert(holding, serving.short) end
    if OF.util.asks(OF.speedrun, "chose_out") then
        if OF.speedrun.chose_out(li, OF.speedrun.KIND_MODE) then
            table.insert(holding, "sitting game modes out")
        end
        if OF.speedrun.chose_out(li, OF.speedrun.KIND_RUN) then
            table.insert(holding, "sitting speedruns out")
        end
    end
    if #holding == 0 then
        table.insert(rows, label_row(OF.lang.t("Nothing is being held against them.")))
    else
        table.insert(rows, label_row(table.concat(holding, ", ")))
    end

    if not OF.util.is_host() then
        table.insert(rows, label_row(""))
        table.insert(rows, label_row(OF.lang.t(
            "The rest of a record is the host's - ask them.")))
        table.insert(rows, back_row())
        return rows
    end

    local id = OF.util.player_id(li)

    table.insert(rows, header_row(OF.lang.t("On record")))
    local record = OF.jail.warn_record(id)
    if record == nil then
        table.insert(rows, label_row(OF.lang.t("Never warned.")))
    else
        table.insert(rows, with_right(
            label_row(OF.lang.fill("Warned @ time(s)", record.count)),
            OF.jail.reason_text(record.reason)))
        table.insert(rows, with_help(gated_row("mute",
            OF.lang.t("Forgive - wipe the record"), 160, 255, 160, function()
                OF.util.report(OF.jail.forgive(li))
            end), OF.lang.t("takes the warnings off this person, back to none")))
    end

    local ban = OF.jail.ban_entry(id)
    if ban ~= nil then
        table.insert(rows, with_right(
            label_row(OF.lang.fill("Banned: @", OF.jail.reason_text(ban.reason))),
            OF.jail.until_text(ban.expires)))
    end

    if OF.util.asks(OF.notes, "get") then
        local note = OF.notes.get(id)
        if note ~= nil and note ~= "" then
            table.insert(rows, label_row(OF.lang.fill("Note: @", note),
                255, 220, 120))
        end
    end

    if OF.util.asks(OF.actionlog, "touching") then
        table.insert(rows, header_row(OF.lang.t("This session")))
        local seen = 0
        for _, entry in ipairs(OF.actionlog.touching(np.name) or {}) do
            if seen < 6 then
                table.insert(rows, with_right(label_row(entry.what or ""),
                    entry.time or ""))
                seen = seen + 1
            end
        end
        if seen == 0 then
            table.insert(rows, label_row(OF.lang.t("Nothing this session.")))
        else
            table.insert(rows, with_help(gated_row("jail", OF.lang.t("The whole log..."),
                255, 255, 255, function() go("actionlog") end),
                OF.lang.t("everything the lobby has done this session, not only this person")))
        end
    end

    table.insert(rows, back_row())
    return rows
end

local function build_ban_confirm()
    local li = OF.util.local_from_global(panel.selected)
    if li == nil then
        return { label_row(OF.lang.t("That player has left.")), back_row() }
    end
    local np = gNetworkPlayers[li]
    local length = OF.jail.ban_length(panel.banLength)

    local rows = {
        panel.aim_fixed(np.name),
        label_row(OF.lang.t("A ban puts them in the void and keeps")),
        label_row(OF.lang.t("them there every time they reconnect.")),
        label_row(""),
    }

    table.insert(rows, with_help(with_right(gated_row("ban", OF.lang.t("How long"),
        255, 220, 120, function()
            panel.banLength = OF.jail.next_ban_length(panel.banLength)
        end),
        OF.lang.t(length.name)),
        OF.lang.t("how long they stay out before the lobby lets them back")))
    table.insert(rows, with_help(with_right(gated_row("ban", OF.lang.t("Reason"),
        255, 220, 120, function()
            panel.modReason = OF.jail.next_reason(panel.modReason)
        end),
        OF.jail.reason_text(panel.modReason)),
        OF.lang.t("what they are told when they try to come back")))
    table.insert(rows, label_row(""))

    table.insert(rows, with_help(panel.acts(panel.with_key(gated_confirm_row("ban", "ban",
        OF.lang.fill("Ban @ @", np.name, OF.lang.t(length.name)),
        255, 90, 90, function()
            OF.util.report(OF.jail.ban(li, length.minutes, panel.modReason))
            go("players")
        end), "banconfirm")),
        OF.lang.t("press again to confirm; the two dials above decide what it is")))
    table.insert(rows, back_row())
    return rows
end

local function build_kickhelp()
    local li = OF.util.local_from_global(panel.selected)
    local name = "them"
    if li ~= nil then name = gNetworkPlayers[li].name end

    local canKick = OF.util.is_host()
        or (network_is_moderator ~= nil and network_is_moderator() == true)

    return {

        panel.aim_fixed(name),
        label_row(OF.lang.t("Disconnecting somebody is the game's own button,")),
        label_row(OF.lang.t("and no mod is allowed to press it. So this one cannot.")),
        label_row(""),

        label_row(canKick and OF.lang.t("You can use it. In chat, type:")
            or OF.lang.t("It needs the host or a Coop DX moderator,")),
        label_row(canKick and "" or OF.lang.t("which you are not.")),
        loud_row(OF.lang.fill("   @", "/kick" .. " " .. name)),
        loud_row(OF.lang.t("   /confirm")),
        label_row(""),
        label_row(canKick and OF.lang.t("For a permanent one use /permban instead.")
            or OF.lang.t("The host hands that out with /moderator,")),
        label_row(canKick and OF.lang.t("This mod's ban keeps them out without kicking.")
            or OF.lang.t("which is not this mod's MOD rank.")),

        rest_row(with_help(row(OF.lang.t("Print those lines into chat"), 255, 255, 255, function()
            if li == nil then return end
            local np = gNetworkPlayers[li]
            OF.util.chat(OF.lang.fill("Copy this: @",
                "/kick" .. " " .. OF.util.plain(np.name)))
            OF.util.chat(OF.lang.fill("Then: @", "/confirm"))
            panel.close()
        end), OF.lang.t("puts the two lines in chat so you can copy them"))),
        back_row(),
    }
end

local build_multi
do

local function to_each(list, act)
    local done, refused, why = 0, {}, nil
    for _, globalIndex in ipairs(list) do
        local li = OF.util.local_from_global(globalIndex)
        if li == nil then

            table.insert(refused, "?")
            if why == nil then why = OF.lang.t("They have left the lobby.") end
        else
            local ok, reason = act(li, globalIndex)
            if ok == false then
                local np = gNetworkPlayers[li]
                table.insert(refused,
                    np ~= nil and OF.util.plain(np.name) or "?")
                if why == nil then why = reason end
            else
                done = done + 1
            end
        end
    end
    return done, refused, why
end

local function report_each(done, refused, why, sentence)
    if done == 0 then
        OF.util.report(false, why or OF.lang.t("Nobody could be reached."))
        return false
    end
    OF.notify.show(sentence, "info", 4, done)

    if #refused > 0 then
        if why ~= nil and why ~= "" then
            OF.notify.show("Not @ - @", "bad", 5,
                table.concat(refused, ", "), why)
        else
            OF.notify.show("Not @.", "bad", 5, table.concat(refused, ", "))
        end
    end
    return true
end

function build_multi()
    local list = panel.selection_list()

    local dice = OF.util.asks(OF.lobbytalk, "dice_rows") and OF.lobbytalk.dice_rows(panel) or {}
    if #list == 0 then

        local empty = {}
        for _, r in ipairs(dice) do table.insert(empty, r) end
        table.insert(empty, label_row(OF.lang.t("Nobody is ticked.")))
        table.insert(empty, label_row(OF.lang.t("Tick a name on the list and come back.")))
        table.insert(empty, back_row())
        return empty
    end

    local rows = {}
    local me = network_global_index_from_local(0)

    table.insert(rows, panel.aim_fixed(panel.aim_label("selected")))
    local _, _, width = panel.geometry()
    local room = math.max(80, width - SIDE_PADDING * 2)
    local drawn = panel.wrap(selection_names(), panel.ROW_SCALE, room, 6)
    for _, line in ipairs(drawn) do
        table.insert(rows, label_row(line, 255, 255, 255))
    end

    local written = table.concat(drawn, " ")
    local unnamed = 0
    for _, globalIndex in ipairs(list) do
        local li = OF.util.local_from_global(globalIndex)
        local np = li ~= nil and gNetworkPlayers[li] or nil
        if np == nil or written:find(np.name, 1, true) == nil then
            unnamed = unnamed + 1
        end
    end
    if unnamed > 0 then
        table.insert(rows, label_row(OF.lang.fill("and @ more", unnamed),
            255, 255, 255))
    end

    table.insert(rows, with_help(row(OF.lang.t("Clear selection"), 180, 180, 180, function()
        panel.selection_clear()
        go("players")
    end), OF.lang.t("unticks everybody and goes back to the list")))

    if #dice > 0 then
        table.insert(rows, header_row(OF.lang.t("Dice")))
        for _, r in ipairs(dice) do table.insert(rows, r) end
    end

    table.insert(rows, header_row(OF.lang.t("Move")))
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Teleport them to me"), 255, 255, 255, function()
        local moved, why = OF.net.summon_many(list, me)
        OF.net.report_move(moved > 0, why,
            OF.lang.fill("Summoned @ player(s).", moved))
        panel.close()
    end), OF.lang.t("pulls them to where you are standing")))
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Teleport them to another player..."),
        255, 255, 255, function()
            panel.pickMode = "selected"
            go("pick")
        end), OF.lang.t("pulls them to somebody you pick next")))
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Send them somewhere..."), 255, 255, 255, function()
        panel.levelMode = "selected"
        go("groups")
    end), OF.lang.t("moves them to a level you pick next")))

    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Send them to the moon"),
        255, 200, 120, function()
            local sent = OF.net.moon_many(list)

            local moved = sent > 0
            local why = nil
            if not moved then why = "Nobody could be moved." end
            OF.net.report_move(moved, why,
                OF.lang.fill("Launched @ player(s).", sent))
        end), OF.lang.t("straight up, tumbling, and they land unharmed")))

    table.insert(rows, header_row(OF.lang.t("Give")))

    local message = OF.settings.screenMessage or ""
    if message ~= "" then
        table.insert(rows, with_help(gated_row("message", OF.lang.fill('Show them: "@"', message),
            255, 215, 0, function()

                OF.notify.show("Message shown to @ player(s).", "info", 4,
                    OF.net.announce_to(list, message))
                panel.close()
            end), OF.lang.t("puts the banner you typed on each of their screens")))
    end

    table.insert(rows, header_row(OF.lang.t("Do")))
    table.insert(rows, with_help(gated_row("powerup_other",
        OF.lang.t("Do something to them..."), 255, 200, 120, function()
            panel.open_aimed("doto", "selected")
        end), OF.lang.t("zap, flatten, suck under - done once, to them")))

    table.insert(rows, header_row(OF.lang.t("Rank")))
    local length = OF.ranks.length(panel.rankLength)
    table.insert(rows, with_help(with_right(gated_row("ranks",
        OF.lang.t("A promotion lasts"), 255, 220, 120, function()
            panel.rankLength = OF.ranks.next_length(panel.rankLength)
        end), OF.lang.t(length.name)),
        OF.lang.t("how long the rank the row below hands out is kept for")))

    local promoteTo, demoteTo = nil, nil
    for _, globalIndex in ipairs(list) do
        local li = OF.util.local_from_global(globalIndex)
        local now = li ~= nil and OF.ranks.get(li) or nil
        if now == nil then
            promoteTo, demoteTo = false, false
        else
            local up, down = OF.perms.step_tier(now, 1), OF.perms.step_tier(now, -1)
            if promoteTo == nil then promoteTo = up
            elseif promoteTo ~= up then promoteTo = false end
            if demoteTo == nil then demoteTo = down
            elseif demoteTo ~= down then demoteTo = false end
        end
    end

    local oneRung = promoteTo ~= nil and promoteTo ~= false
    if not oneRung or OF.ranks.may_offer(promoteTo) then
        local allText = oneRung
            and OF.lang.fill("Promote them all to @ @",
                OF.lang.t(OF.perms.tier_name(promoteTo)), OF.lang.t(length.name))
            or OF.lang.fill("Promote them all one rung each @",
                OF.lang.t(length.name))
        local function promote_all()
            local done, refused, why = to_each(list, function(li)
                return OF.ranks.promote(li, length.minutes)
            end)
            report_each(done, refused, why, "Promoted @ player(s).")
        end
        local allRow = (oneRung and OF.ranks.asks_twice(promoteTo))
            and gated_confirm_row("ranks", "rankcohostall", allText, 255, 215, 0, promote_all)
            or gated_row("ranks", allText, 255, 215, 0, promote_all)
        table.insert(rows, with_help(allRow, oneRung
            and OF.lang.t("they are all on one rung, so they all land on one")
            or OF.lang.t("they are on different rungs, so each moves one up")))
    end
    table.insert(rows, with_help(gated_row("ranks",
        (demoteTo ~= nil and demoteTo ~= false)
            and OF.lang.fill("Demote them all to @",
                OF.lang.t(OF.perms.tier_name(demoteTo)))
            or OF.lang.t("Demote them all one rung each"),
        200, 200, 200, function()
            local done, refused, why = to_each(list, function(li)
                return OF.ranks.demote(li)
            end)
            report_each(done, refused, why, "Demoted @ player(s).")
        end), (demoteTo ~= nil and demoteTo ~= false)
            and OF.lang.t("they are all on one rung, so they all land on one")
            or OF.lang.t("they are on different rungs, so each moves one down")))

    table.insert(rows, header_row(OF.lang.t("Moderate")))

    table.insert(rows, with_help(with_right(gated_row("mute", OF.lang.t("Warn them"),
        255, 220, 120, function()
            local done, refused, why = to_each(list, function(li)
                return OF.jail.warn(li, panel.modReason)
            end)
            report_each(done, refused, why, "Warned @ player(s).")
        end), OF.jail.reason_text(panel.modReason)),
        OF.lang.t("a word on each of their screens, kept on each record")))

    local warned = 0
    if OF.util.is_host() then
        for _, globalIndex in ipairs(list) do
            local li = OF.util.local_from_global(globalIndex)
            if li ~= nil then
                warned = warned + OF.jail.warn_count(OF.util.player_id(li))
            end
        end
    end
    if warned > 0 then
        table.insert(rows, with_help(with_right(gated_row("mute",
            OF.lang.t("Forgive them - wipe their warnings"), 160, 255, 160,
            function()
                local done, refused, why = to_each(list, function(li)
                    return OF.jail.forgive(li)
                end)
                report_each(done, refused, why, "Forgave @ player(s).")
            end), OF.lang.fill("@ warning(s)", warned)),
            OF.lang.t("wipes every warning off each of them, back to none")))
    end

    table.insert(rows, with_help(gated_row("mute", OF.lang.t("Mute them"), 255, 180, 90, function()
        local done, refused, why = to_each(list, function(li)
            return OF.mute.set(li, true)
        end)
        report_each(done, refused, why, "Muted @ player(s).")
    end), OF.lang.t("stops the lobby reading what any of them type in chat")))
    table.insert(rows, with_help(gated_row("mute", OF.lang.t("Unmute them"), 255, 255, 255, function()
        local done, refused, why = to_each(list, function(li)
            return OF.mute.set(li, false)
        end)
        report_each(done, refused, why, "Unmuted @ player(s).")
    end), OF.lang.t("lets the lobby read them again")))
    table.insert(rows, with_help(gated_row("speedrun", OF.lang.t("Sit modes and runs out for all of them"), 255, 255, 255, function()
        local done, refused, why = to_each(list, function(li)
            return OF.speedrun.set_excluded(li, true)
        end)
        report_each(done, refused, why, "@ player(s) are sitting modes and runs out.")
    end), OF.lang.t("game modes and speedruns both stop counting them in")))
    table.insert(rows, with_help(gated_row("jail", OF.lang.t("Release them all"), 120, 255, 120, function()
        local done, refused, why = to_each(list, function(li)
            return OF.jail.release(li, true)
        end)
        report_each(done, refused, why, "Released @ player(s).")
        go("players")
    end), OF.lang.t("ends whatever sentence each of them is serving")))

    table.insert(rows, with_help(with_right(gated_confirm_row("jail", "multijail",
        OF.lang.t("Jail them all"), 255, 140, 90, function()
        local worst = OF.jail.max_sentence()
        local why = nil
        if panel.modReason ~= "none" then
            why = OF.jail.reason_text(panel.modReason)
        end
        local done, refused, whyNot = to_each(list, function(li)
            return OF.jail.punish(li, worst.key, why)
        end)
        report_each(done, refused, whyNot, "Jailed @ player(s).")
        go("players")
    end), OF.lang.t(OF.jail.max_sentence().short)),
        OF.lang.t("press again to confirm; they are held until released")))

    local carrying = false
    for _, globalIndex in ipairs(list) do
        local li = OF.util.local_from_global(globalIndex)
        if li ~= nil and (OF.mute.is_muted(li) or OF.jail.is_jailed(li)
                or (OF.util.asks(OF.speedrun, "chose_out")
                    and OF.speedrun.chose_out(li))) then
            carrying = true
        end
    end
    if carrying then
        table.insert(rows, with_help(confirm_row("clearticked",
            OF.lang.t("Wrong people - take everything off them"),
            120, 255, 140, function()
                local done, refused, why = to_each(list, function(li)
                    return OF.jail.clear_player(li)
                end)
                report_each(done, refused, why, "Cleared @ player(s).")
            end), OF.lang.t("undoes every mute, sentence and exclusion the ticked are carrying")))
    end

    if #list == 1 and list[1] ~= me then
        local only = OF.util.local_from_global(list[1])
        local np = only ~= nil and gNetworkPlayers[only] or nil
        if np ~= nil then
            table.insert(rows, header_row(OF.lang.fill("Only @", np.name)))

            table.insert(rows, with_help(gated_row("teleport_self",
                OF.lang.fill("Teleport me to @", np.name), 255, 255, 255,
                function()
                    OF.net.teleport_to(list[1])
                    panel.close()
                end), OF.lang.t("moves you to them; nobody else is touched")))
            table.insert(rows, with_help(gated_row("spectate",
                OF.lang.fill("Spectate @", np.name), 255, 255, 255,
                function()
                    OF.spectate.start(list[1])
                    panel.close()
                end), OF.lang.t("watch through their eyes until you stop, on Travel")))

            local warnings = OF.util.is_host()
                and OF.jail.warn_count(OF.util.player_id(only)) or 0
            table.insert(rows, with_help(with_right(gated_row("mute",
                OF.lang.fill("What @ has done...", np.name), 255, 255, 255,
                function()
                    panel.selected = list[1]
                    go("record")
                end),
                warnings > 0 and OF.lang.fill("@ warning(s)", warnings) or ""),
                OF.lang.t("their whole record in one place, before you decide anything")))
            table.insert(rows, with_help(row(
                OF.lang.t("How to actually disconnect them..."),
                200, 200, 200, function()
                    panel.selected = list[1]
                    go("kickhelp")
                end),
                OF.lang.t("what to type, because no mod may press the game's own kick")))
        end
    end

    table.insert(rows, back_row())
    return rows
end

end

local function build_pick()

    local rows = {
        panel.aim_fixed(panel.aim_label(
            panel.pickMode == "selected" and "selected"
                or panel.pickMode == "one" and "player" or "everyone")),
        label_row(OF.lang.t("Pick the player they should be sent to:")),
    }

    for _, entry in ipairs(OF.util.connected_players()) do
        local globalIndex = network_global_index_from_local(entry.localIndex)
        local r, g, b = OF.util.name_colour()

        table.insert(rows, with_help(gated_row("teleport_other", entry.np.name, r, g, b,
            function()
                local moved, why
                if panel.pickMode == "selected" then
                    moved, why = OF.net.summon_many(panel.selection_list(), globalIndex)
                elseif panel.pickMode == "one" then

                    moved, why = OF.net.summon_many({ panel.selected }, globalIndex)
                else
                    moved, why = OF.net.summon_everyone_to(globalIndex)
                end
                if moved == 0 then
                    OF.util.report(false, why)
                    return
                end
                OF.net.report_move(true, nil,
                    OF.lang.fill("Sent @ player(s) to @.", moved,
                        OF.util.plain(entry.np.name)))
                panel.close()
            end), OF.lang.t("pulls them to wherever this player is standing")))
    end

    table.insert(rows, back_row())
    return rows
end

local outside = {}

function outside.help(mode)
    if mode == "self" then
        return OF.lang.t("the staff roll, for you alone; START skips it")
    end
    return OF.lang.t("each machine runs its own staff roll; START skips it")
end

function outside.credits(mode)
    if mode == "self" then
        if OF.util.report(OF.net.credits_local()) then panel.close() end
        return
    end
    local sent = OF.net.credits_many(targets_for(mode))
    local why = nil
    if sent == 0 then why = "Nobody could be moved." end
    OF.net.report_move(sent > 0, why,
        OF.lang.fill("Sent @ player(s) to the end credits.", sent))
    if sent > 0 then panel.close() end
end

local function build_groups()

    local rows = {}
    local aimed = panel.level_aim(panel.levelMode)
    if aimed ~= nil then table.insert(rows, aimed) end
    table.insert(rows, label_row(OF.lang.t("Where to?")))
    for _, group in ipairs(OF.util.level_groups()) do

        local first = OF.util.levels_in_group(group)[1]
        local madeLevels = first ~= nil and first.custom == true
        if not (group == OF.WAYPOINT_GROUP
            and (panel.levelMode == "run" or panel.levelMode == "round"
                or panel.levelMode == "pipe"))
            and not (madeLevels and panel.levelMode == "run") then
        local count = 0
        for _, entry in ipairs(OF.util.levels_in_group(group)) do

            if panel.levelMode ~= "run" or not OF.util.asks(OF.speedrun, "door_offers")
                or OF.speedrun.door_offers(entry.level, panel.runKind) then
                count = count + 1
            end
        end
        table.insert(rows, with_help(row(OF.lang.fill("@ (@)", group, count),
            255, 255, 255, function()
            panel.group = group
            go("levels")
        end), OF.lang.t("the levels in this group, to pick one from")))
        end
    end

    local mode = panel.levelMode

    if mode == "pipe" and OF.util.asks(OF.forge, "pipe_group_rows") then
        OF.forge.pipe_group_rows(panel, rows)
    end
    if mode == "self" or mode == "everyone" or mode == "selected" or mode == "player" then
        table.insert(rows, label_row(OF.lang.t("Outside the levels")))

        local function credits() outside.credits(mode) end
        local credits_row
        if mode == "self" then
            credits_row = gated_row("teleport_self", OF.lang.t("The end credits"),
                255, 255, 255, credits)
        elseif mode == "everyone" then
            credits_row = gated_row("warp_lobby", OF.lang.t("The end credits"),
                255, 255, 255, credits)
        else
            credits_row = gated_row("teleport_other", OF.lang.t("The end credits"),
                255, 255, 255, credits)
        end
        table.insert(rows, with_help(credits_row, outside.help(mode)))
        if mode == "self" then
            table.insert(rows, with_help(gated_row("teleport_self",
                OF.lang.t("The title screen"), 255, 255, 255, function()
                    if OF.util.report(OF.net.title_local()) then panel.close() end
                end), OF.lang.t("only ever you; START there brings you back to the castle")))
        end
    end
    table.insert(rows, back_row())
    return rows
end

local function go_to_waypoint(entry, mode)
    if mode == "self" then
        OF.net.teleport_to_position(entry.point)
        return
    end
    if mode == "everyone" then
        local ok, why = OF.net.send_everyone_to_position(entry.point)
        OF.net.report_move(ok, why,
            OF.lang.fill("Sent everybody to @", OF.util.accent() .. entry.name))
        return
    end
    local sent = 0
    for _, globalIndex in ipairs(targets_for(mode)) do
        if OF.net.send_to_position(globalIndex, entry.point) then sent = sent + 1 end
    end

    local moved = sent > 0
    local why = nil
    if not moved then why = "Nobody could be moved." end
    OF.net.report_move(moved, why,
        OF.lang.fill("Sent @ player(s) to @.", sent, entry.name))
end

local function level_help(mode)
    if mode == "everyone" then
        return OF.lang.t("loads this level for the whole lobby")
    end
    if mode == "selected" then
        return OF.lang.t("sends the ticked names to this level")
    end
    if mode == "player" then
        return OF.lang.t("sends that one player to this level")
    end

    if mode == "run" then
        return OF.lang.t("starts the race here - everybody in the lobby is warped in")
    end
    if mode == "round" then
        return OF.lang.t("the next round is played here; nobody moves yet")
    end
    if mode == "pipe" then
        return OF.lang.t("the Forge pipe leads here; nobody moves yet")
    end
    return OF.lang.t("takes you there alone; the lobby stays where it is")
end

local function build_levels()
    local rows = {}
    local mode = panel.levelMode

    local aimed = panel.level_aim(mode)
    if aimed ~= nil then table.insert(rows, aimed) end
    if panel.group ~= nil and panel.group ~= "" then
        table.insert(rows, label_row(OF.lang.t(panel.group)))
    end

    for _, entry in ipairs(OF.util.levels_in_group(panel.group)) do
        local suffix = ""
        if mode == "run" then
            local best = OF.speedrun.personal_best(entry.level)
            if best ~= nil then suffix = "   (best " .. OF.speedrun.format_time(best) .. ")" end
        end

        if mode ~= "run" and mode ~= "round" and OF.util.asks(OF.venues, "travel_suffix") then
            suffix = suffix .. OF.venues.travel_suffix(entry.level, entry.area)
        end

        local ticked, refused = false, false
        if mode == "run" and OF.util.asks(OF.speedrun, "door_offers") then
            refused = not OF.speedrun.door_offers(entry.level, panel.runKind)
        end
        if mode == "round" then

            refused = entry.point ~= nil
                or (OF.util.asks(OF.gamemodes, "accepts_level")
                    and not OF.gamemodes.accepts_level(panel.modeKey, entry))
            local held = OF.gamemodes ~= nil and OF.gamemodes.levelChoice or nil
            ticked = held ~= nil and held.level == entry.level
                and (held.area or 1) == (entry.area or 1)
        end

        local hazards = entry.point == nil
            and OF.util.level_hazard_line(entry.level, entry.area) or nil

        if not refused then
        table.insert(rows, with_help(with_right(row(
            mode == "round" and panel.tick(ticked, entry.name .. suffix)
                or (entry.name .. suffix), 255, 255, 255, function()

            local carryOn, why = panel.aim_check(mode)
            if why ~= nil then OF.util.report(false, why) end
            if not carryOn then return end
            if entry.point ~= nil then
                go_to_waypoint(entry, mode)
                panel.close()
                return
            end

            if mode == "pipe" then
                if OF.util.asks(OF.forge, "pipe_choose")
                    and OF.util.report(OF.forge.pipe_choose(entry)) then
                    panel.levelMode = "everyone"
                    panel.go(OF.forge.pipe_back())
                end
                return
            end
            if mode == "run" then

                OF.speedrun.start_level(entry, 0)
                panel.close()
                return
            end

            if mode == "round" then

                if ticked then
                    if OF.util.asks(OF.gamemodes, "set_level") then
                        OF.gamemodes.set_level(nil)
                        OF.notify.show("The next round has no level picked.",
                            "info", 4)
                    end
                elseif OF.util.asks(OF.gamemodes, "set_level")
                    and OF.gamemodes.set_level(entry) then

                    OF.notify.show("The next round is on @.", "info", 4,
                        entry.name)
                end
                panel.levelMode = "everyone"
                panel.go(OF.util.asks(OF.gamemodes, "place_door")
                    and OF.gamemodes.place_door() or "speedrun")
                return
            end

            local act = OF.util.destination_act(entry)

            if mode == "everyone" then
                if not OF.util.report(OF.net.warp_everyone(entry.level, entry.area,
                        act)) then
                    return
                end

                OF.net.report_move(true, nil,
                    OF.lang.fill("Loading @ for everybody.", entry.name))
                panel.close()
                return
            end
            if mode == "self" then
                OF.net.warp_local(entry.level, entry.area, act)
                panel.close()
                return
            end

            local sent, refusal = 0, nil
            for _, globalIndex in ipairs(targets_for(mode)) do
                local ok, why = OF.net.warp_player(globalIndex, entry.level,
                    entry.area, act)
                if ok then sent = sent + 1 elseif refusal == nil then refusal = why end
            end
            if sent > 0 then
                OF.net.report_move(true, nil,
                    OF.lang.fill("Sent @ player(s) to @.", sent, entry.name))
                panel.close()
            else
                OF.util.report(false, refusal or OF.lang.t("Nobody could be sent."))
            end
        end), hazards or ""), level_help(mode)))
        end
    end

    table.insert(rows, back_row())
    return rows
end

local function aim_row(need, key)
    return with_help(with_right(panel.with_key(gated_row(need,
        OF.lang.t("Aimed at"),
        255, 255, 255, function()
            panel.aim_at(panel.next_aim())
        end), key), panel.aim_label(panel.aimed_at())),

        OF.lang.t("who every press on this page goes to; it is kept when you leave"))
end

panel.aim_row = aim_row

function panel.aim_fixed(who)
    return with_right(label_row(OF.lang.t("Aimed at")), tostring(who or ""))
end

function panel.level_aim(mode)
    if mode == "round" or mode == "pipe" then return nil end
    if mode == "selected" or mode == "everyone" then
        return panel.aim_fixed(panel.aim_label(mode))
    end

    if mode == "run" then
        return panel.aim_fixed(panel.aim_name("everyone"))
    end
    if mode == "player" then

        local li = OF.util.local_from_global(panel.selected)
        if li ~= nil and gNetworkPlayers[li] ~= nil then
            return panel.aim_fixed(gNetworkPlayers[li].name)
        end
        return panel.aim_fixed(panel.aim_name("player"))
    end

    return panel.aim_fixed(panel.aim_name("self"))
end

local function give_dial_rows(rows, list, pool, lengthHelp, dials, aimed)

    if aimed then
        table.insert(rows, aim_row("powerup_self", "givetarget"))
    end

end

function panel.deed_track(key, rungs)
    local P = OF.powerups
    if P.staying(key) then
        return rungs, rungs, OF.lang.t("until it is switched off")
    end
    if rungs > 1 then
        return (P.step(key) or 1) - 1, rungs, OF.lang.t(P.step_name(key) or "")
    end
    return 0, rungs, OF.lang.t("the usual time")
end

function panel.deed_track_set(key, rungs, wanted)
    local P = OF.powerups
    wanted = math.floor(tonumber(wanted) or 0)
    if wanted >= rungs then return P.set_stays(key, true) end
    P.set_stays(key, false)
    if rungs > 1 then return P.set_step(key, wanted + 1) end
    return true
end

local function give_catalogue_rows(rows, list, need, verb, twoBox)
    local group, sub = nil, nil

    local aimedAt = (not twoBox) and targets_for(panel.aimed_at()) or nil
    for _, entry in ipairs(list) do

      if OF.powerups.on_menu(entry) then
        if entry.group ~= group then
            group = entry.group
            sub = nil
            table.insert(rows, header_row(OF.lang.t(group or "Powerups")))
        end
        if entry.sub ~= sub then
            sub = entry.sub
            if sub ~= nil then
                table.insert(rows, sub_header_row(OF.lang.t(sub)))
            end
        end

        local r, g, b = 255, 255, 255
        if entry.kind == "bad" then r, g, b = 255, 120, 120 end
        if entry.kind == "warn" then r, g, b = 255, 200, 120 end

        local text = OF.lang.t(entry.name)

        local boxed, lobbyOn, lobbySome = false, false, false
        local mineBox, mineIsMine, inForce = nil, false, 0
        if OF.powerups.is_toggle(entry) then
            if twoBox then

                boxed = true
                lobbyOn = OF.powerups.room_on(entry.key)
                local state = OF.powerups.mine_state(entry.key)

                mineBox = panel.mine_shown(state, lobbyOn)
                mineIsMine = panel.mine_marked(state)

                inForce = OF.powerups.in_force(entry.key)
                if inForce > 0 then
                    r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
                end
            else

                local on, off = 0, 0
                for _, who in ipairs(aimedAt or {}) do
                    if OF.powerups.toggled_on(who, entry) then on = on + 1
                    else off = off + 1 end
                end
                if on > 0 then
                    r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
                end
                if on > 0 and off > 0 then text = panel.tick_some(text)
                else text = panel.tick(on > 0 and off == 0, text) end
            end
        elseif OF.powerups.can_stay(entry) then

        end
        local function hand_out(target)

            local carryOn, why = panel.aim_check(target)
            if why ~= nil then OF.util.report(false, why) end
            if not carryOn then return end
            local given, why, gave =
                OF.powerups.give_many(targets_for(target), entry.key)
            if given == 0 then
                OF.util.report(false, why or OF.lang.t("Nobody could be given that."))
                return
            end

            local landed = gave or entry

            if twoBox and target ~= "self" then
                if OF.powerups.is_toggle(landed)
                        or OF.powerups.staying(landed.key) then
                    OF.notify.show("Switched @ for @ player(s).", "info", 4,
                        OF.lang.t(landed.name), given)
                else
                    OF.notify.show(verb, "info", 4, OF.lang.t(landed.name), given)
                end
            end
            panel.close()
        end

        local built
        if twoBox then

            local stops = OF.powerups.step_count(entry)
            local function step_after(from)
                if stops <= 1 then return from > 0 and 0 or 1 end
                local at = from + 1
                if at > stops then at = 0 end
                return at
            end
            built = panel.two_box({
                boxes = boxed,
                lobbyOn = lobbyOn,
                lobbySome = lobbySome,

                mineBox = mineBox,
                name = text,
                lobbyNeed = "powerup_other",
                mineNeed = "powerup_self",
                r = r, g = g, b = b,

                onLobby = function()
                    if not boxed then hand_out("everyone") return end
                    local at = step_after(OF.powerups.room_stop(entry.key) or 0)
                    local ok, why = OF.powerups.set_room_stop(entry.key, at)
                    if not OF.util.report(ok, why) then return end

                    OF.notify.show(at > 0 and "@ is on for everybody."
                        or "@ is off for everybody.", "info", 4,
                        OF.lang.t(entry.name))
                end,

                onMine = function()
                    if not boxed then hand_out("self") return end
                    OF.util.report(OF.powerups.set_mine(entry.key,
                        panel.next_mine(OF.powerups.mine_state(entry.key),
                            lobbyOn)))
                end,
            })
        else
            built = gated_row(need, text, r, g, b, function()
                hand_out(panel.aimed_at())
            end)
        end

        built = with_help(built, OF.powerups.row_note(entry))

        local rungs = OF.powerups.step_count(entry)
        if not twoBox and OF.powerups.can_stay(entry) then

            local at, last, said = panel.deed_track(entry.key, rungs)
            built = with_right(built, said)
            built = with_slider(built, at, last, function(wanted)
                OF.util.report(panel.deed_track_set(entry.key, rungs, wanted))
            end)
        elseif rungs > 1 then

            local said = OF.powerups.step_name(entry.key) or ""
            if twoBox and boxed then
                local state = OF.powerups.mine_state(entry.key)
                if state == false then

                    said = panel.two_box_level(OF.lang.t("off"), true) or said
                elseif inForce > 0 then
                    said = panel.two_box_level(OF.lang.t(
                        OF.powerups.step_name_at(entry.key, inForce) or said),
                        mineIsMine) or said
                elseif OF.util.asks(OF.powerups, "slider_at") then

                    local at = OF.powerups.slider_at(entry.key, panel.may("powerup_other"))
                    said = at > 0 and OF.lang.t(OF.powerups.step_name_at(entry.key, at)
                        or said) or OF.lang.t("off")
                end
            end
            built = with_right(built, said)
            if twoBox and boxed and OF.util.asks(OF.powerups, "slider_at") then

                local at, dialsRoom = OF.powerups.slider_at(entry.key,
                    panel.may("powerup_other"))
                built = with_slider(built, at, rungs, function(wanted)
                    OF.util.report(OF.powerups.slider_set(entry.key, wanted, dialsRoom))
                end)
            else
                built = with_slider(built, (OF.powerups.step(entry.key) or 1) - 1,
                    rungs - 1, function(wanted)
                        OF.util.report(OF.powerups.set_step(entry.key, wanted + 1))
                    end)
            end

        elseif twoBox and boxed
                and OF.powerups.mine_state(entry.key) == false then
            built = with_right(built,
                panel.two_box_level(OF.lang.t("off"), true) or "")

        elseif entry.counted then

            local at = OF.powerups.amount_of(entry.key)
            built = with_right(built, tostring(OF.powerups.AMOUNTS[at]))

            if OF.perms.can("powerup_tune") then
                built = with_slider(built, at - 1, #OF.powerups.AMOUNTS - 1, function(wanted)
                    OF.util.report(OF.powerups.set_row_amount(entry.key, wanted + 1))
                end)
            end
        elseif OF.powerups.can_stay(entry) then

            if twoBox then
                built = with_right(built, OF.powerups.staying(entry.key)
                    and OF.lang.t("until it is switched off")
                    or OF.lang.t("the usual time"))
            end
            built = with_slider(built,
                OF.powerups.staying(entry.key) and 1 or 0, 1,
                function(wanted)
                    OF.util.report(OF.powerups.set_stays(entry.key, wanted == 1))
                end)
        elseif entry.timed and list ~= OF.powerups.ACTIONS
                and OF.powerups.howLong ~= 3 then

            built = with_right(built, "x" .. tostring(OF.powerups.LENGTHS[OF.powerups.howLong]))
        end

        if not twoBox and built ~= nil then built.dialQuiet = true end

        table.insert(rows, built)
      end
    end
end

local function build_powerups()
    local rows = {}

    table.insert(rows, label_row(OF.lang.t(
        "A hands this to everybody, Z hands it to you.")))

    table.insert(rows, label_row(OF.lang.t(OF.powerups.ONE_AT_A_TIME)))

    give_catalogue_rows(rows, OF.powerups.LIST, nil, "Gave @ to @ player(s).",
        true)

    OF.powerups.say_group_help(rows)

    table.insert(rows, back_row())
    return rows
end

local function build_doto()
    local target = panel.aimed_at()
    local rows = {}
    give_dial_rows(rows, OF.powerups.ACTIONS, false, nil, "none", true)

    local need = "powerup_other"
    if target == "self" then need = "powerup_self" end
    give_catalogue_rows(rows, OF.powerups.ACTIONS, need, "Did @ to @ player(s).")

    OF.powerups.say_group_help(rows)

    table.insert(rows, back_row())
    return rows
end

local cheat_pages = {}

function cheat_pages.rows(part)
    local rows = {}
    for _, r in ipairs(OF.cheats.build_rows(panel, part)) do
        if r.heading == true and r.sub == true then

            table.insert(rows, with_help(header_row(r.text), r.help))
        else
            table.insert(rows, r)
        end
    end
    table.insert(rows, back_row())
    return rows
end

function cheat_pages.cheats()
    return cheat_pages.rows("cheats")
end

function cheat_pages.readouts()
    local rows = cheat_pages.rows("readouts")

    if OF.util.asks(OF.rules, "rows_for") then
        local back = table.remove(rows)
        for _, r in ipairs(OF.rules.rows_for(panel, "readouts")) do
            table.insert(rows, r)
        end
        table.insert(rows, back)
    end
    return rows
end

function cheat_pages.body()
    local rows = {}
    table.insert(rows, panel.label_row(OF.lang.t(
        "A ticks the lobby's box, Z yours - and yours wins.")))
    for _, r in ipairs(OF.util.asks(OF.modifiers, "build_rows")
            and OF.modifiers.build_rows(panel, "body") or {}) do
        table.insert(rows, r)
    end
    table.insert(rows, back_row())
    return rows
end

local function build_waypoints()
    local rows = {}

    table.insert(rows, with_help(gated_row("waypoint_save", OF.lang.t("+ Save my position here"), 120, 255, 120, function()
        local point = OF.waypoints.save_here(nil)

        if point ~= nil then
            OF.notify.show("Saved waypoint @", "info", 4, point.name)
        end
    end), OF.lang.t("remembers exactly where you are standing, to come back to")))

    if #OF.waypoints.list() > 0 then

        table.insert(rows, with_help(host_row("teleport_other",
            OF.lang.t("Share all of these with the lobby"), 255, 215, 0, function()

                OF.util.report(OF.waypoints.share_all(0))
            end, function()

                OF.util.report(OF.waypoints.share_all(0))
            end), OF.lang.t("hands your saved spots to everybody in the lobby")))
    end

    for _, point in ipairs(OF.waypoints.list()) do
        local slot = point.slot

        table.insert(rows, with_help(with_right(row(point.name,
            255, 255, 255, function()
                panel.waypoint = slot
                go("waypoint")
            end), OF.util.level_name(point.level, point.area)),
            OF.lang.t("what is saved here, and who can be sent to it")))
    end

    if OF.util.asks(OF.doorways, "build_rows") then
        for _, r in ipairs(OF.doorways.build_rows(panel)) do
            table.insert(rows, r)
        end
    end

    table.insert(rows, back_row())
    return rows
end

local function build_waypoint()
    local point = nil
    for _, candidate in ipairs(OF.waypoints.list()) do
        if candidate.slot == panel.waypoint then point = candidate end
    end
    if point == nil then
        return { label_row(OF.lang.t("That waypoint is gone.")), back_row() }
    end

    local rows = {
        label_row(point.name .. "  -  " .. OF.util.level_name(point.level, point.area)),

        label_row(OF.waypoints.numbers(point), 170, 190, 215),
        with_help(gated_row("waypoint_use", OF.lang.t("Go there"), 255, 255, 255, function()
            OF.net.teleport_to_position(point)
            panel.close()
        end), OF.lang.t("takes you there alone; the lobby stays where it is")),
    }

    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Send everybody there"), 255, 255, 255, function()
        local ok, why = OF.net.send_everyone_to_position(point)
        OF.net.report_move(ok, why,
            OF.lang.fill("Sent everybody to @", OF.util.accent() .. point.name))
        panel.close()
    end), OF.lang.t("puts the whole lobby on this exact spot")))

    local selected = panel.selection_count()
    if selected > 0 then
        table.insert(rows, with_help(gated_row("teleport_other", OF.lang.fill("Send the @ selected there", selected),
            255, 255, 255, function()

                local ok, why
                for _, globalIndex in ipairs(panel.selection_list()) do
                    local sent, reason = OF.net.send_to_position(globalIndex, point)
                    if ok == nil then ok, why = sent, reason end
                end
                OF.net.report_move(ok, why,
                    OF.lang.fill("Sent @ player(s) to @.", selected, point.name))
                panel.close()
            end), OF.lang.t("puts the ticked names on this exact spot")))
    end

    table.insert(rows, with_help(confirm_row("delwp" .. point.slot,
        OF.lang.t("Delete this waypoint"), 255, 140, 90, function()
        OF.waypoints.delete(point.slot)
        go("waypoints")
    end), OF.lang.t("forgets this spot; the level itself is untouched")))
    table.insert(rows, back_row())
    return rows
end

local CHANGES_KEPT = 16

local PUT_BACK_TRIES = 8

panel.changes = panel.changes or {}

local function frame_now()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function stable_key(built)
    if built == nil then return nil end
    if built.key ~= nil and built.key ~= "" then return tostring(built.key) end
    local text = OF.util.plain(tostring(built.text or ""))

    local cut
    repeat
        text, cut = string.gsub(text, "^%[[xX%s%-]%]%s*", "")
    until cut == 0
    local name = string.match(text, "^(.-): ")
    if name ~= nil and name ~= "" then text = name end
    if text == "" then return nil end
    return text
end
panel.stable_key = stable_key

function panel.box_word(box, side)
    if box == "x" or box == "X" then return OF.lang.t("on") end
    if box == "-" then
        if side == "mine" then return OF.lang.t("off") end
        return OF.lang.t("some")
    end
    return OF.lang.t("off")
end

local function row_value(built)
    if built == nil then return nil end
    if built.slider ~= nil and built.slider.value ~= nil then
        return tostring(built.slider.value)
    end
    local right = built.right
    if right ~= nil and right ~= "" then
        return OF.util.plain(tostring(right))
    end
    local text = OF.util.plain(tostring(built.text or ""))

    local lobbyBox, mineBox = string.match(text, "^%[([xX%s%-])%]%s*%[([xX%s%-])%]")
    if lobbyBox ~= nil then
        return OF.lang.fill("@ / @", panel.box_word(lobbyBox, "lobby"),
            panel.box_word(mineBox, "mine"))
    end
    local tick = string.match(text, "^%[([xX%s%-])%]")
    if tick == "x" or tick == "X" then return OF.lang.t("on") end
    if tick == " " then return OF.lang.t("off") end
    if tick == "-" then return OF.lang.t("some") end
    local value = string.match(text, "^.-: (.*)$")
    if value ~= nil and value ~= "" then return value end
    return text
end
panel.row_value = row_value

local function row_name(built)
    return OF.util.row_key((built ~= nil and built.text) or "")
end

local function differing_part(before, after)
    before, after = tostring(before or ""), tostring(after or "")
    if before == "" or after == "" then return before, after end

    local shortest = math.min(#before, #after)
    local head = 0
    while head < shortest
        and string.sub(before, head + 1, head + 1)
            == string.sub(after, head + 1, head + 1) do
        head = head + 1
    end

    local tail = 0
    while tail < shortest - head
        and string.sub(before, #before - tail, #before - tail)
            == string.sub(after, #after - tail, #after - tail) do
        tail = tail + 1
    end

    local a = string.sub(before, head + 1, #before - tail)
    local b = string.sub(after, head + 1, #after - tail)
    a = string.match(a, "^%s*(.-)%s*$")
    b = string.match(b, "^%s*(.-)%s*$")
    if a == "" or b == "" then return before, after end
    return a, b
end
panel.differing_part = differing_part

function panel.change_snapshot()
    if panel.page == "changed" then return nil end
    if panel.confirm ~= nil then return nil end

    local built = panel.rows ~= nil and panel.rows[panel.cursor] or nil
    if built == nil then return nil end
    if built.heading == true or built.exit == true then return nil end

    local key = stable_key(built)
    if key == nil then return nil end
    return {
        page = panel.page,
        key = key,
        feature = built.feature,
        value = row_value(built),
        slider = built.slider ~= nil and built.slider.value or nil,
    }
end

function panel.drop_change(page, key)
    for index, held in ipairs(panel.changes) do
        if held.page == page and held.key == key then
            table.remove(panel.changes, index)
            return true
        end
    end
    return false
end

function panel.note_change(before)
    if before == nil then return false end

    if panel.page ~= before.page then return false end

    if panel.confirm ~= nil then return false end

    local now = nil
    for _, built in ipairs(panel.rows or {}) do
        if stable_key(built) == before.key then
            now = built
            break
        end
    end
    if now == nil then return false end

    local after = row_value(now)
    if after == nil or after == before.value then return false end

    local entry = nil
    for index, held in ipairs(panel.changes) do
        if held.page == before.page and held.key == before.key then
            entry = table.remove(panel.changes, index)
            break
        end
    end
    if entry == nil then
        entry = {
            page = before.page,
            key = before.key,
            first = before.value,
            firstSlider = before.slider,
        }
    end

    entry.feature = before.feature
    entry.name = row_name(now)
    entry.value = after
    entry.at = frame_now()

    if entry.value == entry.first then return false end

    table.insert(panel.changes, 1, entry)
    while #panel.changes > CHANGES_KEPT do
        table.remove(panel.changes)
    end
    return true
end

function panel.forget_changes()
    panel.changes = {}
    panel.putBackSaid = nil
end

local function how_long_ago(frame)
    if frame == nil then return "" end
    local seconds = math.floor((frame_now() - frame) / 30)
    if seconds < 0 then return "" end
    if seconds < 60 then return OF.lang.t("just now") end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return OF.lang.fill("@ min ago", minutes) end
    return OF.lang.fill("@ h ago", math.floor(minutes / 60))
end
panel.how_long_ago = how_long_ago

panel.searchWord = nil
panel.searchRows = nil

local function build_search()
    local rows = {}
    if panel.searchWord == nil or panel.searchWord == "" then
        table.insert(rows, label_row(OF.lang.t("Search from chat, then press the row that says to show these.")))
        table.insert(rows, back_row())
        return rows
    end

    table.insert(rows, label_row(OF.lang.fill("Matching '@'", panel.searchWord)))
    for _, r in ipairs(panel.searchRows or {}) do

        table.insert(rows, r)
    end
    if #(panel.searchRows or {}) == 0 then
        table.insert(rows, label_row(OF.lang.t("Nothing matches.")))
    end
    table.insert(rows, back_row())
    return rows
end

local function build_active()
    local rows = {}

    local tier = OF.util.asks(OF.perms, "my_tier") and OF.perms.my_tier() or 0
    if panel.activeFor ~= tier then panel.activeRows = nil end
    if panel.activeRows == nil and panel.refresh_active ~= nil then
        panel.refresh_active()
    end
    local found = panel.activeRows or {}
    local total = panel.activeCount or #found

    if total == 0 and #found == 0 then

        table.insert(rows, label_row(OF.lang.t(
            "No modifier and no cheat is switched on.")))
        table.insert(rows, label_row(OF.lang.t(
            "Every modifier and cheat you switch on is listed here, and can be switched off here. "
            .. "The lobby's own settings have their own pages.")))
        table.insert(rows, back_row())
        return rows
    end

    table.insert(rows, label_row(
        OF.lang.fill("@ switched on. Press one to change it.", tostring(total))))

    table.insert(rows, with_help(gated_row("speedrun",
        OF.lang.t("Turn every modifier and cheat off"), 255, 140, 90,
        function()

            local any = false
            if OF.modifiers.any() then
                any = true
                OF.util.report(OF.modifiers.clear())
            end
            if OF.util.asks(OF.cheats, "any_on") and OF.cheats.any_on() then
                any = true
                OF.cheats.clear_local()
            end
            if not any then OF.util.report(false, OF.lang.t("Nothing is on.")) end
        end),
        OF.lang.t("everything the lobby is wearing and every cheat you have on, off")))
    for _, r in ipairs(found) do
        table.insert(rows, r)
    end
    if total > #found then
        table.insert(rows, label_row(OF.lang.fill(
            "@ more, on the pages they live on.", tostring(total - #found))))
    end
    table.insert(rows, back_row())
    return rows
end

local function build_chatlog()
    local rows = {}

    local entries = OF.chatlog.entries

    for i = 1, #entries do
        local e = entries[i]

        local line = panel.log_line(e.time, OF.chatlog.who_of(e), e.message, e.r, e.g, e.b)

        line.nameRaw = e.nameRaw
        table.insert(rows, with_help(line,
            OF.lang.t("one line of this lobby's chat, the oldest at the top")))
    end

    if #entries == 0 then
        table.insert(rows, label_row(OF.lang.t("Nothing logged yet.")))
    end
    table.insert(rows, with_help(confirm_row("clearlog", OF.lang.t("Clear log"), 255, 140, 90, function()
        OF.chatlog.clear()
        panel.scroll = 0
    end), OF.lang.t("empties this list on your machine; nobody else is affected")))

    table.insert(rows, back_row())
    return rows
end

local function build_bans()
    local rows = {}

    if not OF.util.is_host() then
        table.insert(rows, label_row(OF.lang.t("The ban list is the host's - ask them.")))
        table.insert(rows, back_row())
        return rows
    end

    for _, entry in ipairs(OF.jail.ban_list()) do

        table.insert(rows, with_help(with_right(
            gated_confirm_row("ban", "unban_" .. entry.id,
                OF.lang.fill("Unban @ (releases and sends home)", entry.name)
                    .. "  " .. (OF.jail.is_name_ban(entry.id)
                        and OF.lang.t("(on the name)")
                        or OF.lang.t("(on their account)")),
                255, 255, 255, function()
                    if OF.util.report(OF.jail.unban(entry.id)) then

                        OF.notify.show("Unbanned @.", "info", 4, entry.name)
                    end
                end),
            OF.jail.until_text(entry.expires)),
            OF.jail.reason_text(entry.reason)))
    end
    if #rows == 0 then
        table.insert(rows, label_row(OF.lang.t("No bans.")))
    end

    table.insert(rows, back_row())
    return rows
end

local function build_warnings()
    local rows = {}

    if not OF.util.is_host() then
        table.insert(rows, label_row(OF.lang.t("The warning list is the host's - ask them.")))
        table.insert(rows, back_row())
        return rows
    end

    local escalates = OF.jail.escalates()
    table.insert(rows, with_help(with_right(gated_row("mute",
        OF.lang.t("Warnings turn into a punishment by themselves"),
        255, 220, 120, function()
            OF.util.report(OF.jail.set_escalates(not OF.jail.escalates()))
        end),
        escalates and OF.lang.t("yes") or OF.lang.t("no")),

        OF.jail.warn_ladder_text()))

    if escalates then
        table.insert(rows, label_row(OF.lang.t(
            "A first warning is only a word. The player is told each time.")))

        table.insert(rows, OF.jail.warn_rung_row(panel, "mute"))
        table.insert(rows, OF.jail.warn_rung_row(panel, "jail"))
    else
        table.insert(rows, label_row(OF.lang.t(
            "Nothing happens on its own - the count is a memory only.")))
    end

    table.insert(rows, OF.jail.warn_window_row(panel))

    local list = OF.jail.warn_list()
    if #list == 0 then
        table.insert(rows, label_row(OF.lang.t("Nobody has a warning on record.")))
        table.insert(rows, back_row())
        return rows
    end

    table.insert(rows, header_row(OF.lang.t("On record")))
    for _, entry in ipairs(list) do

        table.insert(rows, with_help(with_right(
            label_row(OF.util.plain(entry.name), 255, 255, 255),
            OF.lang.fill("@ warning(s)", entry.count)),
            OF.jail.reason_text(entry.reason)))
    end

    table.insert(rows, with_help(confirm_row("forgiveall",
        OF.lang.t("Forgive everybody - wipe every record"), 160, 255, 160,
        function() OF.util.report(OF.jail.forgive_all()) end),
        OF.lang.t("empties the whole warning book; press again to confirm")))
    table.insert(rows, back_row())
    return rows
end

local function build_mutes()
    local rows = {}
    local host = OF.util.is_host()
    local list = OF.mute.list()

    if OF.mute.quiet_on() then
        table.insert(rows, with_help(label_row(OF.lang.fill(
            "Quiet mode is on as well - only @ and above can talk at all.",
            OF.perms.tier_name(OF.mute.quiet_tier())), 255, 176, 96),
            OF.lang.t("the switch for that is on Moderation, one page back")))
    end

    table.insert(rows, OF.mute.length_row(panel))

    if not host then
        table.insert(rows, label_row(OF.lang.t(
            "Muted in this lobby. The host holds the rest - who else, and what for.")))
    end

    if #list == 0 then
        table.insert(rows, label_row(host and OF.lang.t("Nobody is muted.")
            or OF.lang.t("Nobody in this lobby is muted.")))
        table.insert(rows, back_row())
        return rows
    end

    for _, entry in ipairs(list) do
        local text = OF.lang.fill("Unmute @", OF.util.plain(entry.name or "?"))

        if entry.here == nil then
            text = text .. "   " .. OF.lang.t("(not in the lobby)")
        end

        local right = OF.mute.left_text(entry)

        local help
        if entry.reason == nil then
            help = OF.lang.t("the host holds the reason and the time for this one")
        else
            help = OF.mute.reason_text(entry.reason)
                .. " - " .. OF.mute.source_text(entry.source)
            local since = OF.mute.since_text(entry.at)
            if since ~= nil then
                help = help .. ", " .. OF.lang.fill("@ ago", since)
            end
        end

        table.insert(rows, with_help(with_right(
            gated_row("mute", text, 255, 255, 255, function()
                OF.util.report(OF.mute.lift(entry.id, entry.here))
            end), right), help))
    end

    table.insert(rows, with_help(gated_confirm_row("mute", "unmuteall",
        OF.lang.t("Unmute everybody"), 160, 255, 160, function()
            OF.util.report(OF.mute.lift_all())
        end), OF.lang.t("the mutes only - sentences and bans stay")))

    table.insert(rows, back_row())
    return rows
end

local function build_remembered()
    local rows = {}
    if not OF.util.is_host() then
        table.insert(rows, label_row(OF.lang.t(
            "The host holds the list of remembered ranks.")))
        table.insert(rows, back_row())
        return rows
    end

    local list = OF.ranks.remembered()
    if #list == 0 then
        table.insert(rows, label_row(OF.lang.t(
            "Nobody holds a rank in this lobby's file.")))
        table.insert(rows, back_row())
        return rows
    end

    table.insert(rows, label_row(OF.lang.t(
        "Ranks the lobby keeps, whether or not they are here.")))
    for _, entry in ipairs(list) do
        local ends = OF.lang.t("for good")
        if entry.expires > 0 and OF.util.asks(OF.jail, "until_text") then
            ends = OF.jail.until_text(entry.expires)
        end
        local r, g, b = OF.perms.tier_color(entry.tier)

        table.insert(rows, with_help(with_right(gated_confirm_row("ranks",
            "forgetrank" .. entry.id,
            OF.util.plain(OF.ranks.remembered_label(entry)), r, g, b,
            function()
                OF.util.report(OF.ranks.forget_stored(entry.id))
            end), OF.perms.tier_name(entry.tier)),
            OF.lang.fill("held @ - press twice to take it back", ends)))
    end

    table.insert(rows, back_row())
    return rows
end

local function build_perms()

    local rows = {}
    table.insert(rows, with_help(gated_confirm_row("permissions", "resetperms",
        OF.lang.t(panel.RESET_ROW), 255, 140, 90,
        function()
            OF.util.report(OF.perms.reset())
        end),
        OF.lang.t("every row on this page at once, and nothing else this lobby has set")))

    table.insert(rows, panel.with_walk(with_help(label_row(OF.lang.t(
        "Minimum rank per feature. A raises it, Z lowers it.")),
        OF.lang.t("the rank is on the right, in its own colour, and what the row covers is down here"))))

    local reading = {}
    for _, group in ipairs(OF.perms.grouped_order()) do
        reading[#reading + 1] = group
        for _, feature in ipairs(group.features) do
            if group.subs ~= nil and group.subs[feature] ~= nil then
                reading[#reading + 1] = { sub = true, name = group.subs[feature] }
            end
            reading[#reading + 1] = feature
        end
    end

    local function perm_row(feature, required, built)
        if built == nil then return built end
        built.key = "perm:" .. feature
        local r, g, b = OF.perms.tier_color(required)
        built.rightInk = { r, g, b }
        return built
    end

    for _, entry in ipairs(reading) do

        if type(entry) == "table" and entry.sub then
            table.insert(rows, sub_header_row(OF.lang.t(entry.name)))
            goto continue
        end
        if type(entry) == "table" then
            table.insert(rows, with_help(header_row(OF.lang.t(entry.name)),
                OF.lang.t(entry.help)))
            goto continue
        end

        local feature = entry
        local required = OF.perms.required(feature)
        local info = OF.perms.tier_info(required)

        if OF.perms.FIXED[feature] then

            table.insert(rows, perm_row(feature, required, panel.with_walk(with_help(with_right(
                label_row(OF.lang.t(OF.perms.LABELS[feature] or feature)),
                OF.lang.fill("@, always",
                    OF.lang.t(OF.perms.tier_name(required)))),
                OF.perms.COVERS[feature]))))
            goto continue
        end

        if OF.perms.needs_host(feature) then

            table.insert(rows, perm_row(feature, required, panel.with_walk(with_help(with_right(
                label_row(OF.lang.t(OF.perms.LABELS[feature] or feature)),
                OF.lang.fill("@ only",
                    OF.lang.t(OF.perms.tier_name(required)))),
                OF.perms.COVERS[feature]))))
            goto continue
        end

        local built = gated_row("permissions",
            OF.lang.t(OF.perms.LABELS[feature] or feature),
            info.r, info.g, info.b, function()

                local nextTier = OF.perms.step_tier(required, 1)
                if nextTier == required then
                    nextTier = OF.perms.nearest_in_use(OF.TIER.NORMAL, 1)
                end
                OF.util.report(OF.perms.set_required(feature, nextTier))
            end)

        if built.action ~= nil then
            built.altAction = function()
                local down = OF.perms.step_tier(required, -1)
                if down == required then
                    OF.util.report(false, OF.lang.t(
                        "That is the lowest rung this lobby has."))
                    return
                end
                OF.util.report(OF.perms.set_required(feature, down))
            end
            built.altPad = true
            built.altLabel = "lower"
        end
        table.insert(rows, perm_row(feature, required, with_help(with_right(built,
            OF.lang.t(OF.perms.tier_name(required))),
            OF.perms.COVERS[feature])))
        ::continue::
    end

    table.insert(rows, back_row())
    return rows
end

local function build_controls(panel)

    local rows = {}

    if not OF.util.asks(OF.input, "step_opener") then
        table.insert(rows, label_row(OF.lang.t("Input is not loaded.")))
        table.insert(rows, back_row())
        return rows
    end

    table.insert(rows, with_help(with_right(
        row(OF.lang.t("Opens the mod menu"), 255, 255, 255,
            function() OF.input.step_opener() end),
        OF.lang.t(OF.input.opener_name())),

        OF.lang.t("which pad button opens this menu for you")))

    table.insert(rows, label_row(OF.util.say_buttons(OF.lang.t(
        "Hold Z and press L or R to jump to the next section of a long page."), true)))

    local dead = OF.input.panel_stop() == "dead"
    table.insert(rows, with_help(
        row(panel.tick(dead,
                OF.lang.t("Stop me dead, rather than letting me slide on")),
            dead and 140 or 200, dead and 255 or 200, dead and 160 or 200,
            function() OF.input.toggle_panel_stop_dead() end),
        "you are frozen while this menu is open either way"))

    table.insert(rows, back_row())
    return rows
end

local PAGES = {

    players     = { title = "Players",               tab = "players",
                    build = build_players, arriveFolded = false },
    quick       = { title = "Your shortcuts",        tab = "me", up = "client",
                    build = function() return OF.quick.build_page(panel) end },

    search      = { title = "Search results",        tab = "me", up = "find",
                    build = build_search },
    player      = { title = "Player",                tab = "players", build = build_player, up = "players" },

    multi       = { title = "Player actions",        tab = "players", build = build_multi, up = "players" },

    doto        = { title = "Do something to them", tab = "players", build = build_doto, up = "player" },
    pick        = { title = "Send to which player?", tab = "players", build = build_pick, up = "players" },

    tie         = { title = "Tie them to which player?", tab = "players", up = "player",
                    build = function() return OF.together.build_tie_page(panel) end },

    bond        = { title = "Share their health bar with?", tab = "players", up = "player",
                    build = function() return OF.together.build_bond_page(panel) end },

    record      = { title = "Their record",          tab = "players", build = build_record, up = "player" },
    ban_confirm = { title = "Ban",                   tab = "players", build = build_ban_confirm, up = "player" },
    kickhelp    = { title = "Disconnecting a player", tab = "players", build = build_kickhelp, up = "player" },

    vote        = { title = "Vote",                  tab = "players", up = "lobbytalk",
                    build = function() return OF.vote.build_page(panel) end },

    travel      = { title = "Travel",                tab = "travel", build = build_travel },

    groups      = { title = "Destinations",          tab = "travel", build = build_groups, up = "travel",
                    titleNow = function()
                        if panel.levelMode == "run" then return "Where to race" end
                        return nil
                    end },

    levels      = { title = "Levels",                tab = "travel", up = "groups",
                    selections = {
                        held = function() return panel.group end,
                        pick = function(value) panel.group = value end,
                        list = function()
                            local out = OF.util.level_groups()
                            if type(out) ~= "table" or #out == 0 then
                                return { panel.group }
                            end
                            return out
                        end,

                    },
                    build = build_levels },
    waypoints   = { title = "Waypoints",             tab = "travel", build = build_waypoints, up = "travel" },

    waypoint    = { title = "Waypoint",              tab = "travel", up = "waypoints",
                    selections = {
                        held = function() return panel.waypoint end,
                        pick = function(value) panel.waypoint = value end,
                        list = function()
                            local out = {}
                            for _, point in ipairs(
                                OF.util.asks(OF.waypoints, "list")
                                and OF.waypoints.list() or {}) do
                                table.insert(out, point.slot)
                            end
                            if #out == 0 then return { panel.waypoint } end
                            return out
                        end,

                        name = function(value)
                            for _, point in ipairs(
                                OF.util.asks(OF.waypoints, "list")
                                and OF.waypoints.list() or {}) do
                                if point.slot == value then return point.name end
                            end
                            return nil
                        end,
                    },
                    build = build_waypoint },
    arena       = { title = "Arenas",                tab = "travel", up = "travel",
                    build = function() return OF.arena.build_page(panel) end },

    speedrun    = { title = "Modes",                 tab = "race",
                    build = function() return OF.speedrun.build_page(panel) end },

    whoplays    = { title = "Who is taking part",    tab = "race", up = "speedrun",
                    build = function() return OF.whoplays.build_page(panel) end },
    starcount   = { title = "Star count races",      tab = "race", up = "speedrun",
                    build = function() return OF.speedrun.build_starcount_page(panel) end },

    stars       = { title = "Pick a star",           tab = "race", up = "speedrun",
                    selections = {
                        held = function()
                            if panel.starCourse == nil then return "" end
                            return panel.starCourse
                        end,
                        pick = function(value)
                            if value == "" then
                                panel.starCourse = nil
                                return true
                            end
                            panel.starCourse = tonumber(value)
                            return panel.starCourse ~= nil
                        end,
                        list = function()
                            local out = { "" }
                            for _, course in ipairs(OF.COURSES or {}) do
                                table.insert(out, course.num)
                            end
                            return out
                        end,

                        name = function(value)
                            if value == "" then
                                return OF.lang.t("no course yet")
                            end
                            return OF.util.course_name(tonumber(value))
                        end,
                    },
                    build = function() return OF.speedrun.build_star_page(panel) end },

    gamemodes   = { title = "Game modes",            tab = "race", up = "speedrun",
                    build = function() return OF.gamemodes.build_page(panel) end },

    queue       = { title = "Round queue",           tab = "race", up = "gamemodes",
                    build = function() return OF.rounds.build_page(panel) end },

    gamemode    = { title = "Game mode",             tab = "race", up = "gamemodes",
                    titleNow = function()
                        local list = OF.gamemodes ~= nil
                            and OF.gamemodes.BY_KEY or nil
                        local mode = (list ~= nil and panel.modeKey ~= nil)
                            and list[panel.modeKey] or nil
                        return mode ~= nil and mode.name or nil
                    end,

                    shutOnArrival = { "How it plays" },
                    selections = {
                        held = function() return panel.modeKey end,
                        pick = function(value) panel.modeKey = value end,
                        list = function()
                            local out = {}
                            for _, mode in ipairs(OF.gamemodes ~= nil
                                and OF.gamemodes.LIST or {}) do
                                table.insert(out, mode.key)
                            end
                            return out
                        end,
                        name = function(value)
                            for _, mode in ipairs(OF.gamemodes ~= nil
                                and OF.gamemodes.LIST or {}) do
                                if mode.key == value then
                                    return OF.lang.t(mode.name)
                                end
                            end
                            return nil
                        end,
                    },
                    build = function() return OF.gamemodes.build_mode_page(panel) end },

    playin      = { title = "Where it is played",    tab = "race", up = "gamemodes",
                    fold = false,
                    selections = {
                        held = function() return panel.modeKey end,
                        pick = function(value) panel.modeKey = value end,
                        list = function()
                            local out = {}
                            for _, mode in ipairs(OF.gamemodes ~= nil
                                and OF.gamemodes.LIST or {}) do
                                table.insert(out, mode.key)
                            end
                            return out
                        end,

                        name = function(value)
                            for _, mode in ipairs(OF.gamemodes ~= nil
                                and OF.gamemodes.LIST or {}) do
                                if mode.key == value then
                                    return OF.lang.t(mode.name)
                                end
                            end
                            return nil
                        end,
                    },
                    build = function() return OF.gamemodes.build_where_page(panel) end },

    room        = { title = "Fun",                  tab = "room", build = build_room,
                    arriveFolded = false },

    vision      = { title = "Visuals",               tab = "room", up = "room",
                    build = function() return OF.modifiers.build_visuals_page(panel) end },

    roomrules   = { title = "Lobby rules",          tab = "room", up = "room",
                    build = build_roomrules },

    lens        = { title = "The camera",           tab = "room", up = "roomrules",
                    build = function() return panel.build_lens() end },
    chance      = { title = "Twists",               tab = "room", up = "room",
                    build = build_chance },

    costumes    = { title = "Costumes",              tab = "room", up = "shapes",
                    fold = false,
                    build = function() return OF.costumes.build_page(panel) end },

    costumeset  = { title = "Pick a costume",        tab = "room", up = "costumes",
                    selections = {
                        held = function() return panel.dressGroup end,
                        pick = function(value) panel.dressGroup = value end,
                        list = function()
                            local out = {}
                            for _, group in ipairs(OF.costumes ~= nil
                                and OF.costumes.GROUPS or {}) do
                                table.insert(out, group.key)
                            end
                            return out
                        end,

                        name = function(value)
                            local group = OF.util.asks(OF.costumes, "group_of")
                                and OF.costumes.group_of(value) or nil
                            return group ~= nil and OF.lang.t(group.name) or nil
                        end,
                    },
                    build = function() return OF.costumes.build_group_page(panel) end },

    emotes      = { title = "Emotes",                tab = "players", up = "players",
                    build = function() return OF.emotes.build_page(panel) end,
                    findAlso = function()
                        local names = {}
                        if OF.util.asks(OF.emotes, "catalogue") then
                            for _, entry in ipairs(OF.emotes.catalogue()) do
                                names[#names + 1] = entry.name
                            end
                        end
                        return names
                    end },

    forge       = { title = "Forge",                 tab = "room", up = "room",
                    build = function() return OF.forge.build_page(panel) end },

    forgeclearing = { title = "Clearing",            tab = "room", up = "forge",
                    shutOnArrival = { "One player's pieces" },
                    build = function() return OF.forge.clear_page(panel) end },

    forgelevel  = { title = "Level",                 tab = "room", up = "forge",
                    build = function() return OF.forge.level_page(panel) end },
    forgerules  = { title = "Who builds",            tab = "room", up = "forge",
                    build = function() return OF.forge.rules_page(panel) end },
    forgemore   = { title = "More",                  tab = "room", up = "forge",
                    shutOnArrival = OF.forge ~= nil and OF.forge.MORE_SHUT or nil,
                    build = function() return OF.forge.more_page(panel) end },
    forgekept   = { title = "Builds in every level", tab = "room", up = "forge",
                    shutOnArrival = {},
                    build = function() return OF.forge.kept_page(panel) end },

    forgetracks = { title = "Tracks in every level", tab = "room", up = "forge",
                    shutOnArrival = {},
                    build = function() return OF.forge.tracks_page(panel) end },

    forgepick   = { title = "Things to place",       tab = "room", up = "forge",
                    selections = {
                        held = function()
                            return OF.forge ~= nil and OF.forge.pick_blocks == true
                                and "blocks" or "things"
                        end,
                        pick = function(value)
                            if OF.forge ~= nil then OF.forge.pick_blocks = value == "blocks" end
                        end,
                        list = function() return { "things", "blocks" } end,
                        name = function(value)
                            return value == "blocks" and OF.lang.t("Blocks")
                                or OF.lang.t("Things to place")
                        end,
                    },
                    build = function() return OF.forge.build_pick_page(panel) end },

    bingo       = { title = "Bingo",                 tab = "race", up = "speedrun", fold = false,
                    build = function() return OF.bingo.build_page(panel) end },
    rules       = { title = "How the game plays",     tab = "room", up = "roomrules",
                    build = function() return OF.rules.build_page(panel) end },

    theme       = { title = "Theme",                  tab = "me", up = "client",
                    build = function() return OF.theme.build_page(panel) end },

    shapes      = { title = "How players look",      tab = "room", up = "room",
                    build = build_shapes_page },
    music       = { title = "Music",                 tab = "room", up = "room",
                    build = function() return OF.music.build_page(panel) end },

    together    = { title = "Players together",      tab = "players", up = "players",
                    build = function() return OF.together.build_page(panel) end },

    practice    = { title = "Practice room",         tab = "race", up = "training",
                    build = function() return OF.together.build_practice(panel) end },

    tas         = { title = "TAS tools",             tab = "race", up = "training",
                    build = function() return OF.tas.build_page(panel) end },

    training    = { title = "Practice and TAS", tab = "race", up = "speedrun",
                    build = function() return OF.speedrun.build_training_page(panel) end },
    notes       = { title = "Notes",                 tab = "control", up = "order",
                    build = function() return OF.notes.build_page(panel) end },
    filter      = { title = "Chat filter",           tab = "control", up = "order",
                    build = function() return OF.filter.build_page(panel) end },

    order       = { title = "Moderation",            tab = "control", up = "control",
                    build = build_order, arriveFolded = false },

    autorules   = { title = "Automatic actions", tab = "control", up = "control",
                    build = build_autorules },

    roommods    = { title = "Other mods in this lobby", tab = "control", up = "control",
                    fold = false,
                    build = function() return OF.roommods.build_page(panel) end },

    reports     = { title = "Reports",               tab = "control", up = "order",
                    build = function() return OF.recent.build_reports_page(panel) end },

    client      = { title = "Menu Settings",         tab = "me",
                    build = build_me },

    camera      = { title = "Photo mode",            tab = "room", up = "room",
                    build = function() return OF.camera.build_page(panel) end },
    arrivals    = { title = "When somebody arrives", tab = "me", up = "client",
                    build = build_arrivals },

    cheats      = { title = "Cheats",                tab = "room", up = "room",
                    build = function() return cheat_pages.cheats() end },

    readouts    = { title = "Read-outs",             tab = "room", up = "room",
                    build = function() return cheat_pages.readouts() end },
    body        = { title = "How everybody moves",   tab = "room", up = "roomrules",
                    build = function() return cheat_pages.body() end },

    commands    = { title = "Commands",              tab = "me", up = "client",
                    build = function() return OF.guide.build_page(panel) end },
    controls    = { title = "Your controls",         tab = "me", up = "client",
                    build = function() return build_controls(panel) end },

    place       = { title = "The menu's size and place", tab = "me", up = "client",
                    build = build_place },
    powerups    = { title = "Powerups",              tab = "room", build = build_powerups, up = "room" },

    save        = { title = "Save file editor",      tab = "room", up = "room",

                    titleNow = function()
                        if not OF.util.asks(OF.ledger, "page_title") then return nil end
                        return OF.ledger.page_title()
                    end,
                    build = function() return OF.save.build_page(panel) end },

    rando       = { title = "Randomizer",          tab = "room", up = "chance",
                    build = function() return OF.rando.build_page(panel) end },

    savestar    = { title = "One course's stars",  tab = "room", up = "save",
                    selections = {
                        held = function()
                            return OF.util.asks(OF.save, "star_course")
                                and OF.save.star_course() or nil
                        end,
                        pick = function(value)
                            if OF.util.asks(OF.save, "pick_star_course") then
                                OF.save.pick_star_course(value)
                            end
                        end,
                        list = function()
                            local out = {}
                            for _, entry in ipairs(OF.ledger ~= nil
                                and OF.ledger.COURSES or {}) do
                                if (entry.stars or 0) > 0 then
                                    table.insert(out, entry.num)
                                end
                            end
                            table.insert(out, -1)
                            return out
                        end,

                        name = function(value)
                            if value == -1 then
                                return OF.lang.t("The castle itself")
                            end
                            return OF.util.course_name(value)
                        end,
                    },
                    build = function() return OF.save.build_star_page(panel) end },

    savebonus   = { title = "One world's bonus stars", tab = "room", up = "save",
                    selections = {
                        held = function()
                            return OF.util.asks(OF.save, "bonus_world")
                                and OF.save.bonus_world() or nil
                        end,
                        pick = function(value)
                            if OF.util.asks(OF.save, "pick_bonus_world") then
                                OF.save.pick_bonus_world(value)
                            end
                        end,
                        list = function()
                            local out = {}
                            if OF.util.asks(OF.save, "bonus_worlds") then
                                for _, world in ipairs(OF.save.bonus_worlds()) do
                                    table.insert(out, world.key)
                                end
                            end
                            return out
                        end,
                        name = function(value)
                            if OF.util.asks(OF.save, "bonus_worlds") then
                                for _, world in ipairs(OF.save.bonus_worlds()) do
                                    if world.key == value then
                                        return OF.lang.fill("@. @", world.number, world.name)
                                    end
                                end
                            end
                            return tostring(value)
                        end,
                    },
                    build = function() return OF.save.build_bonus_page(panel) end },

    savebulk    = { title = "All stars",            tab = "room", up = "save",
                    build = function() return OF.save.build_bulk_page(panel) end },

    sweep       = { title = "Clear the level out", tab = "room", up = "roomrules",
                    build = function() return OF.arena.build_sweep_page(panel) end },

    control     = { title = "Control",               tab = "control", build = build_control },

    perms       = { title = "Ranks and permissions", tab = "control", build = build_perms, up = "order",
                    shutOnArrival = { "Yourself", "Others", "The lobby", "Rounds",
                                      "Building", "Moderation", "Host only" } },

    permladder  = { title = "What each rank can do",  tab = "control", up = "order",
                    build = function() return OF.perms.build_ladder_page(panel) end },

    permwho     = { title = "Promote or demote",      tab = "control", up = "order",
                    build = function() return OF.ranks.build_who_page(panel) end },
    permrungs   = { title = "The rungs of the ladder", tab = "control", up = "order",
                    build = function() return OF.perms.build_rungs_page(panel) end },
    permshield  = { title = "Who is protected",       tab = "control", up = "order",
                    build = function() return OF.perms.build_shields_page(panel) end },

    remembered  = { title = "Remembered ranks",      tab = "control", build = build_remembered, up = "order" },
    bans        = { title = "Ban list",              tab = "control", build = build_bans, up = "order" },

    warnings    = { title = "Warnings",              tab = "control", build = build_warnings, up = "order" },

    mutes       = { title = "Muted players",         tab = "control", build = build_mutes, up = "order" },

    active      = { title = "What is on",            tab = "room", up = "room",
                    fold = false, transient = true, build = build_active },

    find        = { title = "Find anything",         tab = "me", up = "client",
                    fold = false, transient = true,
                    build = function() return OF.find.build_page(panel) end },

    chatlog     = { title = "Chat log",              tab = "control", up = "control",
                    build = build_chatlog },
    actionlog   = { title = "Action log",            tab = "control", up = "control",
                    build = function() return OF.actionlog.build_page(panel) end },
}

do
    local aboutOnePlayer = {
        held = function() return panel.selected end,
        pick = function(value) panel.selected = value end,
        list = function()
            local out = {}
            for index = 0, MAX_PLAYERS - 1 do
                local np = gNetworkPlayers[index]
                if np ~= nil and np.connected then
                    table.insert(out, network_global_index_from_local(index))
                end
            end
            return out
        end,

        name = function(value)
            local li = OF.util.local_from_global(value)
            local np = li ~= nil and gNetworkPlayers[li] or nil
            if np == nil then return nil end
            local drawn = OF.util.plain(tostring(np.name or ""))
            if drawn == "" then return nil end
            return drawn
        end,
    }

    for _, key in ipairs({ "player", "record", "ban_confirm",
                           "kickhelp", "tie", "bond" }) do
        PAGES[key].selections = aboutOnePlayer
    end
end

do

    local aboutOneHatGroup = {
        held = function() return panel.hatGroup end,
        pick = function(value) panel.hatGroup = value end,
        list = function()
            local out = {}
            for _, group in ipairs(OF.hats ~= nil and OF.hats.GROUPS or {}) do
                table.insert(out, group.key)
            end
            return out
        end,

        name = function(value)
            local group = OF.util.asks(OF.hats, "group_of")
                and OF.hats.group_of(value) or nil
            return group ~= nil and OF.lang.t(group.name) or nil
        end,
    }

    local function dress_dials()
        if PAGES.hatset ~= nil and PAGES.hatset.selections == nil then
            PAGES.hatset.selections = aboutOneHatGroup
        end
    end
    dress_dials()
    hook_event(HOOK_ON_MODS_LOADED, dress_dials)
end

function panel.search(word)
    local needle = string.lower(tostring(word or ""))
    local found, hits, seen = {}, {}, {}
    if needle == "" then return found end

    local wasPage, wasRows = panel.page, panel.rows
    for key, def in pairs(PAGES) do

        if key ~= "main" and key ~= "search" and key ~= "find"
            and key ~= "active" then
            local ok, rows = pcall(def.build)
            if ok and type(rows) == "table" then
                for _, r in ipairs(rows) do
                    local text = tostring(r.text or "")

                    if string.find(string.lower(text), needle, 1, true)
                        and r.heading ~= true and r.exit ~= true then

                        local where = table.concat(panel.trail(key), " / ")
                        r.right = (r.right ~= nil and r.right ~= "")
                            and (r.right .. "  -  " .. where) or where
                        table.insert(found, r)

                        local id = stable_key(r) or text
                        seen[key .. "\31" .. id] = (seen[key .. "\31" .. id] or 0) + 1
                        table.insert(hits, { page = key, id = id, where = where,
                                             nth = seen[key .. "\31" .. id] })
                    end
                end
            end
        end
    end
    panel.page, panel.rows = wasPage, wasRows

    panel.searchWord = tostring(word or "")
    panel.searchRows = found
    panel.searchHits = hits
    return found
end

function panel.refresh_search()
    local hits = panel.searchHits
    if type(hits) ~= "table" or #hits == 0 then return false end
    local wasPage, wasRows = panel.page, panel.rows
    local wasCursor, wasScroll, wasTab = panel.cursor, panel.scroll, panel.tab
    local wasAim = panel.aim
    local built = {}
    local fresh = {}
    for index, hit in ipairs(hits) do
        if built[hit.page] == nil then
            built[hit.page] = false
            local def = PAGES[hit.page]
            if def ~= nil and def.build ~= nil then
                local ok, rows = pcall(def.build)
                if ok and type(rows) == "table" then built[hit.page] = rows end
            end
        end

        local row, met = nil, 0
        for _, r in ipairs(built[hit.page] or {}) do
            if r.heading ~= true and r.exit ~= true
                and (stable_key(r) or tostring(r.text or "")) == hit.id then
                met = met + 1
                if met == (hit.nth or 1) then
                    row = r
                    break
                end
            end
        end
        if row ~= nil then
            row.right = (row.right ~= nil and row.right ~= "")
                and (row.right .. "  -  " .. hit.where) or hit.where
            fresh[index] = row
        else
            fresh[index] = (panel.searchRows or {})[index]
        end
    end
    panel.page, panel.rows = wasPage, wasRows
    panel.cursor, panel.scroll, panel.tab = wasCursor, wasScroll, wasTab
    if panel.aim ~= wasAim and panel.aim_at ~= nil then panel.aim_at(wasAim) end
    panel.searchRows = fresh
    return true
end

function panel.relive_gathered()
    if panel.page == "active" and panel.forget_active ~= nil then
        panel.forget_active(true)
    elseif panel.page == "search" then
        panel.refresh_search()
    end
end

panel.ACTIVE_SHOWN = 24

local NOT_FILTERED = {
    active = true, search = true, find = true, quick = true,
}

function panel.forget_active(remember)
    if remember then
        local held = panel.activeHeld or {}
        for _, r in ipairs(panel.activeRows or {}) do
            if r.filterKey ~= nil then held[r.filterKey] = true end
        end
        panel.activeHeld = held
    else
        panel.activeHeld = nil
    end
    panel.activeRows = nil
    panel.activeCount = nil
    panel.activeFor = nil
    return true
end

function panel.refresh_active()
    local held = panel.activeHeld or {}
    local found, kept = {}, 0

    local wasPage, wasRows = panel.page, panel.rows
    local wasCursor, wasScroll, wasTab = panel.cursor, panel.scroll, panel.tab

    local wasAim = panel.aim
    panel.aim_at("self")

    for _, tab in ipairs(panel.TABS) do
        local keys = {}
        for key, def in pairs(PAGES) do
            if def.tab == tab.key and def.build ~= nil
                and key ~= "main" and not NOT_FILTERED[key] then
                table.insert(keys, key)
            end
        end
        table.sort(keys)

        local column = OF.lang.t(tab.name)

        for _, key in ipairs(keys) do

            local ok, rows = pcall(PAGES[key].build)
            if ok and type(rows) == "table" then
                local where = table.concat(panel.trail(key), " / ")
                for _, r in ipairs(rows) do

                    if r.catalogue ~= nil then
                        local text = OF.util.plain(tostring(r.text or ""))

                        local tick = string.match(text, "^%[([xX%s%-])%]")

                        local second = string.match(text,
                            "^%[[xX%s%-]%]%s*%[([xX%s%-])%]")
                        if second ~= nil and tick == " " then tick = second end
                        local mine = key .. "\31"
                            .. tostring(stable_key(r) or text)
                        if tick ~= nil and (tick ~= " " or held[mine]) then
                            r.filterKey = mine

                            r.right = (r.right ~= nil and r.right ~= "")
                                and (r.right .. "  -  " .. column) or column
                            r.help = where

                            if r.action == nil then r.walk = true end

                            if tick ~= " " then kept = kept + 1 end
                            if #found < panel.ACTIVE_SHOWN then
                                table.insert(found, r)
                            end
                        end
                    end
                end
            end
        end
    end

    panel.page, panel.rows = wasPage, wasRows
    panel.cursor, panel.scroll, panel.tab = wasCursor, wasScroll, wasTab
    panel.aim_at(wasAim)
    panel.activeRows = found
    panel.activeCount = kept

    panel.activeFor = OF.util.asks(OF.perms, "my_tier") and OF.perms.my_tier() or 0
    return found
end

PAGES.main = PAGES.players

function panel.tab_of(page)
    local def = PAGES[page]
    if def == nil then return "players" end
    return def.tab or "players"
end

local TRAIL_DEEPEST = 8

function panel.page_title(def)
    if def == nil then return nil end
    local title = def.title
    if type(def.titleNow) == "function" then
        local ok, said = pcall(def.titleNow)
        if ok and type(said) == "string" and said ~= "" then title = said end
    end
    return title
end

function panel.trail(page)
    local names, seen = {}, {}
    local key = page
    for _ = 1, TRAIL_DEEPEST do
        if key == nil or seen[key] then break end
        local def = PAGES[key]
        if def == nil then break end
        seen[key] = true
        table.insert(names, 1, OF.lang.t(panel.page_title(def)))
        key = def.up
    end
    return names
end

function panel.trail_keys(page)
    local keys, seen = {}, {}
    local key = page
    for _ = 1, TRAIL_DEEPEST do
        if key == nil or seen[key] then break end
        local def = PAGES[key]
        if def == nil then break end
        seen[key] = true
        table.insert(keys, 1, key)
        key = def.up
    end
    return keys
end

panel.crumbHits = nil

function panel.crumb_at(mouseX, mouseY)
    local hits = panel.crumbHits
    if hits == nil or type(mouseX) ~= "number" or type(mouseY) ~= "number" then
        return nil
    end
    if mouseY < hits.top or mouseY > hits.bottom then return nil end
    for _, hit in ipairs(hits.list) do
        if mouseX >= hit.left and mouseX <= hit.right and hit.key ~= panel.page then
            return hit.key
        end
    end
    return nil
end

function panel.trail_hits(segments, x, scale)
    local list = {}
    for _, seg in ipairs(segments) do
        local w
        if seg.chevron then
            w = panel.chevron_width(scale)
        else
            w = OF.util.drawn_width(seg.text, scale)
            if seg.key ~= nil then
                list[#list + 1] = { left = x, right = x + w, key = seg.key }
            end
        end
        x = x + w
    end
    return list
end

function panel.crumbs_shown(crumbs, room)
    if type(crumbs) ~= "table" or #crumbs <= 1 then return 1 end

    local function width_from(from)
        local total = panel.chevron_width(CRUMB_SCALE)
        if from > 1 then
            total = total + OF.util.width("...", CRUMB_SCALE)
                + panel.chevron_width(CRUMB_SCALE)
        end
        for index = from, #crumbs do
            if index > from then total = total + panel.chevron_width(CRUMB_SCALE) end
            total = total + OF.util.width(tostring(crumbs[index]), CRUMB_SCALE)
        end
        return total
    end

    local first = 1
    while first < #crumbs and width_from(first) > (room or 0) do
        first = first + 1
    end
    return first
end

local function rows_of_page(page)
    local def = PAGES[page]
    if def == nil or def.build == nil then return nil end
    local wasPage, wasRows = panel.page, panel.rows
    local ok, rows = pcall(def.build)
    panel.page, panel.rows = wasPage, wasRows
    if not ok or type(rows) ~= "table" then return nil end
    return rows
end

local function row_on_page(page, key)
    local rows = rows_of_page(page)
    if rows == nil then return nil end
    for _, built in ipairs(rows) do
        if panel.stable_key(built) == key then return built end
    end
    return nil
end

local refreshing = false

function panel.refresh_changes()
    if refreshing then return panel.changes end
    refreshing = true

    local seen, kept = {}, {}
    for _, entry in ipairs(panel.changes) do

        if entry.page ~= "changed" then
            if seen[entry.page] == nil then
                seen[entry.page] = rows_of_page(entry.page) or false
            end
            local rows = seen[entry.page]
            if rows then
                for _, built in ipairs(rows) do
                    if panel.stable_key(built) == entry.key then
                        entry.value = panel.row_value(built)
                        entry.name = entry.name or panel.stable_key(built)
                        break
                    end
                end
            end
            if entry.value ~= entry.first then table.insert(kept, entry) end
        end
    end
    panel.changes = kept
    refreshing = false
    return panel.changes
end

function panel.put_back(entry)
    if entry == nil then return false, OF.lang.t("There is nothing to put back.") end

    local named = OF.util.plain(tostring(entry.name or entry.key))
    if PAGES[entry.page] == nil then
        return false, OF.lang.fill("The page '@' is not there any more.", entry.page)
    end

    for attempt = 0, PUT_BACK_TRIES do
        local target = row_on_page(entry.page, entry.key)
        if target == nil then
            return false, OF.lang.fill("'@' is not on that page any more.", named)
        end

        if panel.row_value(target) == entry.first then
            panel.drop_change(entry.page, entry.key)
            if panel.open then panel.rebuild() end
            return true, OF.lang.fill("'@' is back where it was.", named)
        end

        if target.action == nil then

            return false, OF.lang.fill("You cannot press that now: @",
                OF.util.plain(tostring(target.text or named)))
        end
        if attempt == PUT_BACK_TRIES then break end

        local ok
        if target.slider ~= nil and target.slider.onChange ~= nil
            and entry.firstSlider ~= nil then
            ok = pcall(target.slider.onChange, entry.firstSlider)
        else
            ok = pcall(target.action)
        end
        if not ok then
            return false, OF.lang.fill("'@' threw while being put back.", named)
        end
    end

    return false, OF.lang.fill(
        "'@' has more settings than this can walk back. Set it by hand.", named)
end

function panel.sync_tab()
    local key = panel.tab_of(panel.page)
    for i, tab in ipairs(panel.TABS) do
        if tab.key == key then
            panel.tab = i
            return
        end
    end
end

function panel.show_tab(index)
    if #panel.TABS == 0 then return end
    if index < 1 then index = #panel.TABS end
    if index > #panel.TABS then index = 1 end
    local tab = panel.TABS[index]
    if tab == nil then return end

    if not panel.tab_is_open(tab.key) then return end
    panel.tab = index

    panel.history_clear()
    go(panel.page_for_tab(tab.key), "tab")
end

function panel.tab_home(index)
    local tab = panel.TABS[index]
    if tab == nil or not panel.tab_is_open(tab.key) then return end
    panel.tab = index
    panel.tabPage[tab.key] = nil

    if panel.memory ~= nil then panel.memory[tab.page] = nil end
    panel.history_clear()
    go(tab.page, "tab")
end

function panel.next_tab(direction)
    panel.show_tab(panel.tab + direction)
    OF.sounds.ui("tab", OF.sounds.TAB)
end

panel.PAGES = PAGES

panel.targets_for = targets_for
panel.row = row
panel.with_right = with_right
panel.with_help = with_help
panel.with_slider = with_slider

panel.SWATCH_GAP = 8

function panel.with_right_picture(r, texture, shape, flip)
    if r ~= nil then
        r.rightPicture = { texture = texture, shape = shape, flip = flip == true }
    end
    return r
end

function panel.draw_right_picture(r, rightEdge, rowY, rowHeight, side, alpha)
    local pic = r ~= nil and r.rightPicture or nil
    if pic == nil or djui_hud_render_texture == nil then return 0 end
    local info = panel.texture_info(pic.texture)
    local x = rightEdge - panel.SWATCH_GAP - side
    local y = rowY + (rowHeight - side) * 0.5
    if pic.shape ~= nil and OF.util.asks(OF.forge, "draw_shape_picture") then
        OF.forge.draw_shape_picture(pic.shape, x, y, side, info, alpha, pic.flip)
    elseif info ~= nil then
        djui_hud_set_color(255, 255, 255, alpha)
        djui_hud_render_texture(info, x, y, side / info.width, side / info.height)
    else
        return 0
    end
    return side + panel.SWATCH_GAP
end

panel.gridCol = 1
panel.GRID_CELL = 132
panel.GRID_GAP = 6

function panel.grid_columns(width)
    if width == nil then
        local _, _, w = panel.geometry()
        width = w
    end
    local room = (tonumber(width) or 400) - 2 * SIDE_PADDING - SCROLLBAR_STRIP
    return math.max(2, math.floor((room + panel.GRID_GAP) / (panel.GRID_CELL + panel.GRID_GAP)))
end

function panel.grid_col(r)
    local cells = r ~= nil and r.grid ~= nil and r.grid.cells or nil
    if cells == nil or #cells == 0 then return nil end
    return OF.util.clamp(math.floor(panel.gridCol or 1), 1, #cells)
end

function panel.grid_help(r)
    local col = panel.grid_col(r)
    local cell = col ~= nil and r.grid.cells[col] or nil
    if cell == nil then return r ~= nil and r.help or nil end
    if cell.help ~= nil and cell.help ~= "" then
        return OF.lang.fill("@ - @", cell.name or "", cell.help)
    end
    return cell.name
end

function panel.grid_select(r, col)
    if r == nil or r.grid == nil then return false end
    local was = panel.grid_col(r)
    panel.gridCol = OF.util.clamp(math.floor(col), 1, #r.grid.cells)
    r.help = panel.grid_help(r)
    return was ~= panel.gridCol
end

function panel.grid_row(cells, per, help, feature)
    cells = cells or {}
    local names = {}
    for _, cell in ipairs(cells) do names[#names + 1] = cell.name or "" end
    local built
    built = row(table.concat(names, ", "), 255, 255, 255, function()
        local col = panel.grid_col(built)
        local cell = col ~= nil and cells[col] or nil
        if cell ~= nil and cell.action ~= nil then return cell.action() end
        return nil
    end)

    if feature ~= nil and not panel.may(feature) then
        built.needs = OF.perms.required(feature)
        if OF.perms.needs_host(feature) then built.hostOnly = true end
        built.action = nil
    end
    built.grid = { cells = cells, per = math.max(1, math.floor(per or #cells)) }
    built.help = help
    return built
end

function panel.grid_walk(step)
    local rows = panel.rows or {}
    local current = rows[panel.cursor]
    if current == nil or current.grid == nil then return false end
    local col = (panel.grid_col(current) or 1) + step
    if col >= 1 and col <= #current.grid.cells then
        panel.grid_select(current, col)
        OF.sounds.ui("move", OF.sounds.MOVE)
        return true
    end
    local to = panel.cursor + (step > 0 and 1 or -1)
    local next = rows[to]
    if next == nil or next.grid == nil or #next.grid.cells == 0 then return false end
    panel.cursor = to
    panel.grid_select(next, step > 0 and 1 or #next.grid.cells)
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function panel.grid_layout(r, x, width, reserved)
    local per = (r.grid and r.grid.per) or 1
    local room = width - 2 * SIDE_PADDING - (reserved or 0)
    local cellW = (room - panel.GRID_GAP * (per - 1)) / per
    return x + SIDE_PADDING, math.max(8, cellW)
end

function panel.grid_cell_at(r, x, width, reserved, mouseX)
    if r == nil or r.grid == nil then return nil end
    local left, cellW = panel.grid_layout(r, x, width, reserved)
    local along = mouseX - left
    if along < 0 then return nil end
    local col = math.floor(along / (cellW + panel.GRID_GAP)) + 1
    if col > #r.grid.cells then return nil end
    return col
end

function panel.draw_grid(r, x, rowY, width, rowHeight, rowText, ink, lit, reserved)
    if r == nil or r.grid == nil then return end
    local left, cellW = panel.grid_layout(r, x, width, reserved)
    local col = panel.grid_col(r)
    local side = math.max(8, math.min(rowText, rowHeight - 4))
    local scale = ROW_SCALE * 0.82
    local textH = OF.util.line_height(scale)
    local hr, hg, hb = highlight()
    if lit then r.help = panel.grid_help(r) end
    for index, cell in ipairs(r.grid.cells) do
        local cx = left + (index - 1) * (cellW + panel.GRID_GAP)
        if lit and index == col then
            panel.grid_rect(cx - 2, rowY + 1, cellW + 4, rowHeight - 2, hr, hg, hb, 120)
            panel.grid_rect(cx - 2, rowY + rowHeight - 3, cellW + 4, 2, hr, hg, hb, 255)
        else
            panel.grid_rect(cx, rowY + 2, cellW, rowHeight - 4, 255, 255, 255, 14)
        end
        local px = cx + 3
        local py = rowY + (rowHeight - side) * 0.5
        local info = panel.texture_info(cell.texture)
        local drew = false

        if cell.shape ~= nil and panel.skin_on() and OF.util.asks(OF.forge, "draw_shape_picture") then
            OF.forge.draw_shape_picture(cell.shape, px, py, side, info, ink, cell.flip == true)
            drew = true
        elseif info ~= nil and djui_hud_render_texture ~= nil then
            djui_hud_set_color(255, 255, 255, ink)
            djui_hud_render_texture(info, px, py, side / info.width, side / info.height)
            drew = true
        end
        local nameX = px + (drew and (side + panel.SWATCH_GAP) or 0)
        local room = cx + cellW - 3 - nameX
        local ir, ig, ib = 255, 255, 255
        if cell.here then
            local g = gold()
            ir, ig, ib = g.r, g.g, g.b
        end
        if room > 6 then
            OF.util.text(panel.fit_to(cell.name or "", scale, room), nameX,
                rowY + (rowHeight - textH) * 0.5, scale, ir, ig, ib, ink)
        end
    end
end

panel.textureCache = {}

panel.TEXTURE_MISS_RETRY = 90

function panel.texture_info(name)
    if type(name) ~= "string" or name == "" then return nil end
    local held = panel.textureCache[name]
    local now = get_global_timer ~= nil and get_global_timer() or 0
    if held == nil or (type(held) == "number" and now - held >= panel.TEXTURE_MISS_RETRY) then
        held = now
        if get_texture_info ~= nil then
            local ok, info = pcall(get_texture_info, name)
            if ok and info ~= nil and (tonumber(info.width) or 0) > 0
                and (tonumber(info.height) or 0) > 0 then
                held = info
            end
        end
        panel.textureCache[name] = held
    end
    if type(held) == "table" then return held end
    return nil
end

function panel.swatch_width(r, side)
    if r == nil or r.texture == nil or djui_hud_render_texture == nil
        or panel.texture_info(r.texture) == nil then
        return 0
    end
    side = side or OF.util.line_height(1.0)
    return side + panel.SWATCH_GAP
end
panel.label_row = label_row
panel.header_row = header_row
panel.sub_header_row = sub_header_row
panel.gated_row = gated_row
panel.host_row = host_row

panel.BRAKE_ACTION = "brake"
hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_cohost_action") then
        OF.net.register_cohost_action(panel.BRAKE_ACTION, "panel", function(asker, x)
            return OF.lockdown.hold(x == "on", asker)
        end)
    end
end)

panel.DICE_ACTION = "dicepool"
panel.STAR_FEED_ACTION = "starfeed"
hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.asks(OF.net, "register_cohost_action") then return end
    OF.net.register_cohost_action(panel.DICE_ACTION, "settings", function()
        local talk = OF.lobbytalk
        talk.dicePool = (tonumber(talk.dicePool) or 1) % 3 + 1
        return true, nil, talk.dicePool
    end, function(value) OF.lobbytalk.dicePool = tonumber(value) or 1 end)
    OF.net.register_cohost_action(panel.STAR_FEED_ACTION, "settings", function()
        local talk = OF.lobbytalk
        talk.starFeedOn = not talk.starFeedOn
        return true, nil, talk.starFeedOn and "on" or "off"
    end, function(value) OF.lobbytalk.starFeedOn = value == "on" end)
end)

function panel.ask_host(name, x, y, z)
    return function()
        return OF.util.report(OF.net.cohost_does(name, x, y, z))
    end
end
panel.confirm_row = confirm_row
panel.gated_confirm_row = gated_confirm_row
panel.back_row = back_row
panel.go = go

panel.ROW_SCALE = ROW_SCALE

panel.ROW_GAP = ROW_GAP

panel.FOOTER_SCALE = FOOTER_SCALE

panel.CRUMB_SCALE = CRUMB_SCALE

local function track_share(width)
    return math.floor(width * 0.22)
end

function panel.level_band(rows, width)
    local widest, any = 0, false
    for _, r in ipairs(rows or {}) do
        if r.slider ~= nil and r.slider.steps ~= nil and r.slider.steps > 0 then

            local name = panel.slider_face(r)
            any = true

            local w = OF.util.width(tostring(name or ""), ROW_SCALE)
            if w > widest then widest = w end
        end
    end
    if not any then return 0 end

    local span = width - SIDE_PADDING * 4 - track_share(width)
    local third = math.floor(span / 3)
    local spare = math.floor(span - widest)

    if spare < third and spare >= math.floor(span / 8) then return spare end
    return math.max(1, third)
end

function panel.slider_columns(x, width, band, hasBar)
    band = band or 0
    local levelEdge = x + width - SIDE_PADDING
    local trackWidth = track_share(width)
    local clear = math.max((band > 0) and (band + SIDE_PADDING) or 0,
        hasBar and SCROLLBAR_STRIP or 0)
    return levelEdge - clear - trackWidth, trackWidth, levelEdge, band
end

function panel.level_shown(right, width, hasTrack, band)
    if right == nil or right == "" then return "" end
    right = tostring(right)
    if not hasTrack then return right end
    if width == nil then
        local _, _, w = panel.geometry()
        width = w
    end

    return OF.util.fit(right, ROW_SCALE,
        band or panel.level_band(panel.rows, width))
end

function panel.text_room(right, width, hasTrack)
    if width == nil then
        local _, _, w = panel.geometry()
        width = w
    end
    if hasTrack then

        local trackX = panel.slider_columns(0, width,
            panel.level_band(panel.rows, width), true)
        return trackX - SIDE_PADDING * 2
    end
    local room = width - SIDE_PADDING * 2
    local level = panel.level_shown(right, width, hasTrack)
    if level ~= "" then
        room = room - OF.util.width(level, ROW_SCALE) - SIDE_PADDING
    end
    return room
end

panel.ROW_WHITE = { r = 255, g = 255, b = 255 }
panel.ROW_NOTE = { r = 200, g = 200, b = 200 }
panel.ROW_DANGER = { r = 255, g = 120, b = 90 }

panel.ROW_LASTING = { r = 255, g = 205, b = 70 }
panel.ROW_GIVE = { r = 130, g = 232, b = 150 }
panel.ROW_GO = panel.ROW_GIVE
panel.ROW_RANK = panel.ROW_LASTING

panel.ROW_KEY = { r = 110, g = 190, b = 255 }
panel.TONE_INK = {
    danger = panel.ROW_DANGER,
    lasting = panel.ROW_LASTING,
    give = panel.ROW_GIVE,
    go = panel.ROW_GO,
    rank = panel.ROW_RANK,

    key = panel.ROW_KEY,
}

panel.TONE_WORDS = {
    danger = {
        "^stop the run", "^stop the speedrun", "^stop the round", "^end the run", "^end the round",
        "^end this round", "^kick ", "^ban ", "^wipe ", "^reset ",

        "^clear the ", "^clear log", "^clear every ", "^clear this ",
        "^remove ", "^delete ", "^forget ", "^cut every ", "^empty every ",
        "^empty this ", "^lift every ", "^take all ", "^lock every ",
        "^mute ", "^jail ", "^send .+ to the moon",
        "^freeze the lobby", "^put every ", "^put everybody back",
        "^put the .+ back",
    },

    rank = { "^promote ", "^demote ", "^give .+ the rank ", "^give rank ",
        "^set .*rank to " },
    lasting = { " for good", " forever" },

    go = { "^start the ", "^start a vote", "^deal a card", "^deal a new card",
        "^run the track", "^run this track", "^ask who is ready" },
    give = { "^give ", "^unlock ", "^unban ", "^unmute ", "^unjail " },
}
panel.TONE_ORDER = { "danger", "rank", "lasting", "go", "give" }

function panel.with_tone(built, tone)
    if type(built) == "table" then built.tone = tone end
    return built
end

function panel.past_ceiling(built, name)
    if type(built) == "table" then built.pastCeiling = name end
    return built
end

function panel.acts(built)
    if type(built) == "table" then built.acts = true end
    return built
end

function panel.reset_text(text)
    text = string.lower(OF.util.plain(tostring(text or ""))):gsub("^%s+", "")
    for _, pattern in ipairs(panel.TONE_WORDS.danger) do
        if string.find(text, pattern) ~= nil then return true end
    end
    return false
end

function panel.tone_of(r)
    if type(r) ~= "table" or r.action == nil or r.heading then return nil end
    if r.tone == false then return nil end
    if panel.TONE_INK[r.tone] ~= nil then return r.tone end
    if r.danger or r.confirming ~= nil then return "danger" end

    if r.slider ~= nil or r.swatch or r.loud then
        return nil
    end
    local text = OF.util.plain(tostring(r.confirming or r.text or ""))
    text = string.lower(text):gsub("^%s+", "")
    if string.sub(text, 1, 1) == "[" or string.sub(text, 1, 1) == "+"
        or string.sub(text, -3) == "..." or string.find(text, "...", 1, true) then
        return nil
    end
    if r.altAction ~= nil then
        return panel.reset_text(text) and "danger" or nil
    end
    for _, tone in ipairs(panel.TONE_ORDER) do
        for _, pattern in ipairs(panel.TONE_WORDS[tone]) do
            if string.find(text, pattern) ~= nil then return tone end
        end
    end
    return nil
end

function panel.ink_gap(a, b)
    return math.abs(a.r - b.r) + math.abs(a.g - b.g) + math.abs(a.b - b.b)
end

function panel.hue_chroma(c)
    local hi = math.max(c.r, c.g, c.b)
    local lo = math.min(c.r, c.g, c.b)
    local chroma = hi - lo
    if chroma == 0 then return 0, 0 end
    local h
    if hi == c.r then h = ((c.g - c.b) / chroma) % 6
    elseif hi == c.g then h = (c.b - c.r) / chroma + 2
    else h = (c.r - c.g) / chroma + 4 end
    return h * 60, chroma
end

panel.KEY_CHROMA = 80
panel.KEY_HUE = 40

function panel.key_ink(look)
    if look == nil and OF.util.asks(OF.theme, "active") then
        look = OF.theme.active()
    end
    local accent = look ~= nil and look.accent or nil
    if type(accent) ~= "table" or accent.r == nil then return panel.ROW_KEY end
    local hue, chroma = panel.hue_chroma(accent)
    if chroma < panel.KEY_CHROMA then return panel.ROW_KEY end
    for _, tone in ipairs({ panel.ROW_DANGER, panel.ROW_LASTING, panel.ROW_GIVE }) do
        local other = panel.hue_chroma(tone)
        local apart = math.abs(hue - other) % 360
        if math.min(apart, 360 - apart) < panel.KEY_HUE then return panel.ROW_KEY end
    end
    if look.panel ~= nil and OF.util.asks(OF.theme, "contrast")
        and OF.theme.contrast(accent, look.panel) < (OF.theme.READABLE or 4.5) then
        return panel.ROW_KEY
    end
    return accent
end

panel.PULSE_FRAMES = 90
panel.PULSE_LIFT = 0.35
function panel.pulse_ink(r, g, b, frame)
    local phase = ((tonumber(frame) or 0) % panel.PULSE_FRAMES) / panel.PULSE_FRAMES
    local lift = panel.PULSE_LIFT * (0.5 - 0.5 * math.cos(phase * 2 * math.pi))
    return math.floor(r + (255 - r) * lift + 0.5),
        math.floor(g + (255 - g) * lift + 0.5),
        math.floor(b + (255 - b) * lift + 0.5)
end

do
local function asks_true(owner, name, ...)
    if not OF.util.asks(owner, name) then return false end
    local ok, value = pcall(owner[name], ...)
    return ok and value == true
end
panel.LIVE = {

    round = function() return asks_true(OF.gamemodes, "is_running") end,

    nonstop = function() return asks_true(OF.gamemodes, "nonstop") end,
    queue = function() return asks_true(OF.rounds, "is_running") end,

    rotation = function() return asks_true(OF.playlist, "is_on") end,
    tournament = function()
        if not OF.util.asks(OF.tournament, "state") then return false end
        local ok, t = pcall(OF.tournament.state)
        return ok and type(t) == "table" and t.state == "r"
    end,

    session = function() return asks_true(OF.night, "is_on") end,
    race = function() return asks_true(OF.speedrun, "is_running") end,
    vote = function() return asks_true(OF.vote, "is_open") end,
    countdown = function()
        if not OF.util.asks(OF.lobbytalk, "countdown") then return false end
        local ok, c = pcall(OF.lobbytalk.countdown)
        return ok and c ~= nil
    end,
    poll = function()
        if not OF.util.asks(OF.lobbytalk, "poll") then return false end
        local ok, p = pcall(OF.lobbytalk.poll)
        return ok and type(p) == "table" and (tonumber(p.left) or 0) > 0
    end,
    ready = function()
        if not OF.util.asks(OF.lobbytalk, "ready") then return false end
        local ok, r = pcall(OF.lobbytalk.ready)
        return ok and type(r) == "table" and (tonumber(r.left) or 0) > 0
    end,
    bingo = function() return asks_true(OF.bingo, "running") end,
}
end

function panel.live(...)
    for _, name in ipairs({ ... }) do
        local ask = panel.LIVE[name]
        if ask ~= nil and ask() == true then return true end
    end
    return false
end

function panel.is_setting_row(r)
    if type(r) ~= "table" then return false end
    if r.slider ~= nil or r.altAction ~= nil then return true end
    local text = OF.util.plain(tostring(r.text or "")):gsub("^%s+", "")
    if string.sub(text, 1, 1) == "[" then return true end
    if r.action ~= nil and r.right ~= nil and r.right ~= ""
        and not string.find(text, "...", 1, true) then
        return true
    end
    return false
end

function panel.with_pulse(built, on)
    if type(built) ~= "table" or on ~= true then return built end
    if panel.is_setting_row(built) then return built end
    built.pulse = true
    if built.action ~= nil and built.tone == nil and panel.tone_of(built) == nil then
        built.tone = "key"
        built.pulseKey = true
    end
    return built
end

function panel.one_pulse(rows)
    local seen = false
    for _, r in ipairs(rows or {}) do
        if type(r) == "table" and r.pulse then
            if seen then
                r.pulse = nil
                if r.pulseKey then r.tone, r.pulseKey = nil, nil end
            end
            seen = true
        end
    end
    return rows
end

function panel.tone_ink(tone, look)
    if tone == "key" then return panel.key_ink(look) end
    return panel.TONE_INK[tone]
end

function panel.ink_of(r)
    if type(r) ~= "table" then return 255, 255, 255 end
    if r.heading or r.swatch or r.loud then
        return r.r or 255, r.g or 255, r.b or 255
    end
    local c
    local tone = panel.tone_of(r)
    if tone ~= nil then
        c = panel.tone_ink(tone)
    elseif r.action ~= nil then
        c = panel.ROW_WHITE
    else
        local cr, cg, cb = r.r or 150, r.g or 150, r.b or 150
        if cr == cg and cg == cb then return cr, cg, cb end
        c = panel.ROW_NOTE
    end
    return c.r, c.g, c.b
end

function panel.slider_face(r)
    local text = type(r) == "table" and r.text or nil
    if type(text) ~= "string" then return text, r ~= nil and r.right or nil end
    if r.slider == nil then return text, r.right end
    local name, level = text:match("^(.-%S)%s%s%-%s%s(%S.*)$")
    if name == nil then name, level = text:match("^(.-[^%s:]):%s+(%S.*)$") end
    if name == nil then return text, r.right end

    local right = r.right
    if right ~= nil and right ~= "" and tostring(right) ~= level then
        level = level .. "  " .. tostring(right)
    end
    return name, level
end

local REFRESH_FRAMES = 10
local sinceRefresh = 0

local lastMouseX, lastMouseY = nil, nil

local lastScroll = 0

local lastScrollPage = nil

local lastDeniedFrame = -1

local glideY = nil
local glideHeight = nil
local glidePage = nil

local GLIDE = 0.32

local function glide_to(targetY, targetHeight, page)
    if glideY == nil or glidePage ~= page then
        glideY, glideHeight, glidePage = targetY, targetHeight, page
        return glideY, glideHeight
    end

    if math.abs(targetY - glideY) < 0.7 then
        glideY = targetY
    else
        glideY = glideY + (targetY - glideY) * GLIDE
    end
    if math.abs(targetHeight - (glideHeight or targetHeight)) < 0.7 then
        glideHeight = targetHeight
    else
        glideHeight = (glideHeight or targetHeight)
            + (targetHeight - (glideHeight or targetHeight)) * GLIDE
    end
    return glideY, glideHeight
end

panel.glide_position = function() return glideY end
panel.forget_glide = function() glideY, glideHeight, glidePage = nil, nil, nil end

local ARRIVE_FRAMES = 8

local ARRIVE_LEAD = 3
local ARRIVE_RAMP = 5
local arrival = ARRIVE_FRAMES

function panel.mark_arrival()
    arrival = 0
end

local function arrived(slot, count)
    if arrival >= ARRIVE_FRAMES then return 1 end
    local at = arrival - ((slot - 1) / math.max(1, count)) * ARRIVE_LEAD
    if at <= 0 then return 0 end

    local t = math.min(1, at / ARRIVE_RAMP)
    return 1 - (1 - t) * (1 - t)
end

local FOCUS_INK = 220

panel.arriving = function() return arrival < ARRIVE_FRAMES end
panel.settle_arrival = function() arrival = ARRIVE_FRAMES end

function panel.mark_dirty()
    panel.dirty = true
end

panel.folded = {}

local function fold_key(page, heading, parent)
    return tostring(page) .. "\31" .. tostring(parent or "")
        .. "\31" .. tostring(heading)
end

panel.foldSeen = {}

panel.foldAsk = true

local FOLD_MARGIN = 4
panel.FOLD_MARGIN = FOLD_MARGIN

function panel.should_fold(rows, fits)
    local headings, leading, seenHeading = 0, 0, false
    for _, r in ipairs(rows) do
        if r.heading and not r.sub then

            headings = headings + 1
            seenHeading = true
        elseif r.heading then
            seenHeading = true
        elseif not seenHeading then
            leading = leading + 1
        end
    end

    if headings < 2 then return false end

    if #rows <= fits + FOLD_MARGIN then return false end

    return (leading + headings) * 2 <= #rows
end

local function def_of(page)
    return PAGES[page] or PAGES.players
end

local function maybe_fold(page, rows)

    if not panel.foldAsk then return end

    if panel.foldAsk ~= true and panel.foldAsk ~= page then return end

    if panel.visibleRows < 2 then return end
    panel.foldAsk = false

    if panel.foldSeen[page] then return end

    if def_of(page) ~= nil and def_of(page).shutOnArrival ~= nil then
        for _, name in ipairs(def_of(page).shutOnArrival) do
            panel.folded[fold_key(page, name, nil)] = true
        end
        panel.foldSeen[page] = true
        return
    end

    local def = def_of(page)
    if def ~= nil and def.fold == false then return end

    if def ~= nil and def.arriveFolded == false then return end

    if not panel.should_fold(rows, panel.visibleRows) then return end

    panel.foldSeen[page] = true

    local under = {}
    local at, top = nil, nil
    for _, r in ipairs(rows) do
        if r.heading then
            at = r
            under[r] = 0
            if not r.sub then top = r end
        elseif at ~= nil and r.outside ~= true then
            under[at] = under[at] + 1
            if top ~= nil and top ~= at then under[top] = under[top] + 1 end
        end
    end

    local parent = nil
    for _, r in ipairs(rows) do
        if r.heading and not r.sub then parent = r.text end
        if r.heading and (under[r] or 0) >= 3 then
            panel.folded[fold_key(page, r.text, r.sub and parent or nil)] = true
        end
    end
end

local function fold_row(page, r, key, shut, indent)
    local marker = shut and "+  " or "-  "
    return {
        text = indent .. marker .. r.text, r = r.r, g = r.g, b = r.b,
        heading = true, sub = r.sub,

        right = r.right, help = r.help,
        key = "fold\31" .. tostring(key),
        action = function()

            panel.foldSeen[page] = true
            panel.folded[key] = not shut
            if panel.open then panel.rebuild() end
        end,
    }
end

function panel.heading_of(r)
    if type(r) ~= "table" or r.heading ~= true then return nil end
    local key = r.key
    if type(key) ~= "string" or string.sub(key, 1, 5) ~= "fold\31" then
        return nil
    end
    local head = string.match(key, "^.*\31(.-)$")
    if head == nil or head == "" then return nil end
    return head
end

local function apply_folding(page, rows)
    local def = PAGES[page]
    if def ~= nil and def.fold == false then return rows end

    local out = {}
    local parent, parentShut, subShut = nil, false, false

    for _, r in ipairs(rows) do
        if r.heading and not r.sub then
            parent = r.text
            local key = fold_key(page, r.text, nil)
            parentShut = panel.folded[key] == true

            subShut = false
            table.insert(out, fold_row(page, r, key, parentShut, ""))

        elseif r.heading then
            local key = fold_key(page, r.text, parent)
            subShut = panel.folded[key] == true
            if not parentShut then
                table.insert(out, fold_row(page, r, key, subShut, "   "))
            end

        elseif r.outside == true then

            table.insert(out, r)

        elseif not parentShut and not subShut then
            table.insert(out, r)
        end
    end
    return out
end

panel.buildFailure = nil
local toldAboutPage = {}

local function build_page_safely(pageDef)
    local ok, rows = pcall(pageDef.build)
    if ok and type(rows) == "table" then
        panel.buildFailure = nil
        return rows
    end

    local reason = panel.short_reason(rows)
    panel.buildFailure = { page = panel.page, reason = reason }
    if toldAboutPage[panel.page] ~= reason then
        toldAboutPage[panel.page] = reason

        local told = OF.lang.t("That page could not be built:") .. " " .. reason
        if OF.util.asked_in_chat() then
            OF.util.chat(told, "warn")
        else
            OF.notify.show(told, "bad")
        end
    end
    local built = {
        panel.label_row(OF.lang.t("This page could not be built.")),
    }
    for _, line in ipairs(panel.wrap(reason, 0.75, 380, 3)) do
        table.insert(built, panel.label_row(line))
    end
    table.insert(built, panel.label_row(OF.lang.t("Say that line in the lobby.")))

    if panel.page == "players" then
        table.insert(built, panel.with_help(
            panel.row(OF.lang.t("Try the Travel tab"), 255, 255, 255,
                function() panel.go("travel") end),
            OF.lang.t("another tab, because the page that broke is the one you are on")))
    else
        table.insert(built, panel.with_help(
            panel.row(OF.lang.t("Back to the players"), 255, 255, 255,
                function() panel.go("players") end),
            OF.lang.t("the page this menu opens on, which is still working")))
    end
    return built
end

local function explain_the_grey(rows, before)
    before = before or rows
    local lowest, open = nil, 0
    for _, r in ipairs(before) do

        if r.action ~= nil and r.exit ~= true and r.heading ~= true then
            open = open + 1
        end
        if r.needs ~= nil and (lowest == nil or r.needs < lowest) then
            lowest = r.needs
        end

        if r.hostOnly == true
            and (lowest == nil or OF.TIER.HOST < lowest) then
            lowest = OF.TIER.HOST
        end
    end
    if lowest == nil then return end

    local at = #rows + 1
    while at > 1 and rows[at - 1].exit == true do at = at - 1 end
    local function put(built)
        table.insert(rows, at, built)
        at = at + 1
    end

    if lowest >= OF.TIER.HOST then
        if open == 0 then
            put(label_row(OF.lang.t(
                "Only the host can use this page, and host is not a rank "
                    .. "anybody can be given.")))
        else
            put(label_row(OF.lang.t(
                "The grey rows here are the host's own, and host is not a rank "
                    .. "anybody can be given.")))
        end
        return
    end

    local tier = OF.lang.t(OF.perms.tier_name(lowest))
    local opens = OF.perms.tier_opens(lowest)

    if opens ~= nil then
        put(label_row(OF.lang.fill("The grey rows need @: @", tier, opens)))
    else
        put(label_row(OF.lang.fill("The grey rows need @.", tier)))
    end

    if OF.net.asked_recently() then

        put(label_row(OF.lang.t("Asked. The host has been told.")))
    else
        put(row(OF.lang.fill("Ask the host for @", tier),
            255, 200, 120, function()
                OF.util.report(OF.net.ask_for_rank(tier))
            end))
    end
end

local function wrap_wide_labels(rows)

    if panel.page == "chatlog" then return rows end

    local _, _, width = panel.geometry()
    local room = width - SIDE_PADDING * 2
    if room <= 0 then return rows end

    local out = {}
    for _, r in ipairs(rows) do
        local plain = r.action == nil and r.altAction == nil
            and r.slider == nil and (r.right == nil or r.right == "")
        local text = tostring(r.text or "")

        if plain and OF.util.width(text, panel.ROW_SCALE) > room then

            for _, line in ipairs(panel.wrap(text, panel.ROW_SCALE, room, 3)) do

                local copy = { text = line }
                for key, value in pairs(r) do
                    if key ~= "text" then copy[key] = value end
                end
                table.insert(out, copy)
            end
        else
            table.insert(out, r)
        end
    end
    return out
end

function panel.rebuild()
    local pageDef = PAGES[panel.page] or PAGES.players

    local following = panel.cursor_identity()
    panel.rows = build_page_safely(pageDef)

    if OF.util.asks(OF.mapgrid, "offer") then pcall(OF.mapgrid.offer, panel, panel.rows) end
    panel.one_pulse(panel.rows)
    maybe_fold(panel.page, panel.rows)
    local built = panel.rows
    panel.rows = apply_folding(panel.page, panel.rows)
    explain_the_grey(panel.rows, built)
    panel.rows = wrap_wide_labels(panel.rows)

    if OF.util.asks(OF.find, "tab_root_row") then
        local drawn = false
        for _, r in ipairs(panel.rows) do
            if r.key == "findanything" then drawn = true break end
        end
        local ok, hint = false, nil
        if not drawn then ok, hint = pcall(OF.find.tab_root_row, panel) end
        if ok and hint ~= nil then table.insert(panel.rows, hint) end
    end

    OF.util.scroll_list(panel, panel.rows, 1)

    if panel.landed ~= nil and panel.landed.page == panel.page
        and OF.util.asks(OF.find, "row_at") then
        local ok, at = pcall(OF.find.row_at, panel.rows,
            panel.landed.key, panel.landed.heading)
        local sent = (ok and type(at) == "number") and panel.rows[at] or nil
        if sent ~= nil and not panel.is_stop(sent) then sent.walk = true end
    end

    panel.title = OF.lang.t(panel.page_title(pageDef))

    panel.crumbs = panel.trail(panel.page)

    local picked = panel.selection_count()
    if picked > 0 then
        panel.title = panel.title .. "   -   "
            .. OF.lang.fill("@ selected", picked)
    end
    panel.dirty = false
    sinceRefresh = 0
    panel.sync_tab()

    if panel.cursor > #panel.rows then panel.cursor = #panel.rows end
    if panel.cursor < 1 or not panel.is_stop(panel.rows[panel.cursor]) then
        panel.cursor = 0
        for i, r in ipairs(panel.rows) do
            if panel.is_stop(r) then
                panel.cursor = i
                break
            end
        end
    end

    if following ~= nil then panel.keep_cursor_on(following) end

    panel.rowsPage = panel.page
    return panel.rows
end

local function with_key(built, key)
    if built ~= nil then built.key = key end
    return built
end
panel.with_key = with_key

function panel.row_identity(row)
    if row == nil then return nil end
    if row.key ~= nil and row.key ~= "" then return row.key end
    local text = row.text
    if text == nil or text == "" then return nil end
    local name = OF.util.row_key(text)
    if name == nil or name == "" then return nil end
    return name
end

function panel.keep_cursor_on(wasKey)
    if wasKey == nil or panel.rows == nil then return false end
    local now = panel.rows[panel.cursor]
    if now ~= nil and panel.row_identity(now) == wasKey then return true end
    for index, r in ipairs(panel.rows) do
        if panel.row_identity(r) == wasKey and panel.is_stop(r) then
            panel.cursor = index
            return true
        end
    end
    return false
end

local function log_row(page, row, steady, mine, deferFeed)
    if not OF.util.asks(OF.actionlog, "report") then return false end
    if row == nil or row.heading then return false end

    local said = row.confirming or row.text or panel.row_identity(row)
    if said == nil then return false end

    if row.mine == true then mine = true end

    local where = PAGES[page] ~= nil and PAGES[page].title or page

    if not panel.line_personal(row, mine)
        and panel.skin_on() and OF.util.asks(OF.panelskin, "feed_push") then
        local text = OF.lang.t(tostring(where)) .. ": " .. OF.util.plain(tostring(said))
        if deferFeed then
            panel.feedPending = text
        else
            OF.panelskin.feed_push(text)
        end
    end
    return OF.actionlog.report(OF.lang.t(tostring(where)) .. ": "
        .. OF.util.plain(tostring(said)), steady,
        mine == true and OF.actionlog.KIND_MINE or nil)
end

panel.LINE_PAGES = {
    player = true, doto = true, multi = true, ban_confirm = true, tie = true,
    save = true, control = true, order = true, perms = true, permrungs = true,
    permshield = true, permwho = true, remembered = true,
    bans = true, mutes = true, warnings = true,
}

panel.LINE_TARGETED = { player = true, doto = true, ban_confirm = true,
    tie = true }

panel.LINE_EXEMPT = {

    actionlog = "a filter on the log, not a setting",
}

function panel.line_box(r)
    if type(r) ~= "table" or r.slider ~= nil then return nil end
    local text = OF.util.plain(tostring(r.text or ""))
    if string.match(text, "^%s*%[.%]%s*%[.%]") ~= nil then return nil end
    return string.match(text, "^%s*%[(.)%]")
end

function panel.line_words(page, was, now)
    local r = was

    local deed = type(was) == "table" and was.dialQuiet == true
    if now ~= nil and not deed
        and (panel.is_toggle(was) or (type(was) == "table" and was.altAction ~= nil)) then
        r = now
    end
    if type(r) ~= "table" then return nil end
    local flip = false
    local wasBox = panel.line_box(was)
    if wasBox ~= nil and wasBox ~= "-" and panel.is_toggle(was)
        and (now == nil or panel.line_box(now) == wasBox) then
        flip = true
    end
    local text
    if r.slider ~= nil then
        local name, level = panel.slider_face(r)
        text = OF.util.plain(tostring(name or r.text or ""))
        if level ~= nil and level ~= "" then
            text = text .. ": " .. OF.util.plain(tostring(level))
        end
    else
        text = OF.util.plain(tostring(r.confirming or r.text or ""))
    end
    local box = string.match(text, "^%s*%[(.)%]")
    for _ = 1, 2 do text = string.gsub(text, "^%s*%[.%]%s*", "", 1) end
    if deed then box = nil end
    if box ~= nil then
        if flip then box = box == " " and "X" or " " end
        local state = box == " " and "off" or (box == "-" and "some" or "on")
        if r.right ~= nil and r.right ~= "" and box ~= " " then
            state = OF.util.plain(tostring(r.right))
        end
        text = text .. ": " .. OF.lang.t(state)
    elseif r.slider == nil and type(r.right) == "string" and r.right ~= "" then
        text = text .. ": " .. OF.util.plain(r.right)
    end
    local me = OF.util.presser(0) or ""
    if me ~= "" then
        text = string.gsub(text, "%f[%w]my%f[%W]", me .. "'s")
        text = string.gsub(text, "%f[%w]me%f[%W]", me)
    end

    if panel.LINE_TARGETED[page] then
        local _, count = panel.line_target(page)
        if count > 1 then
            text = text .. " - " .. OF.lang.fill(OF.lang.t("@ players"), count)
        end
    end
    text = string.gsub(text, "^%s+", "")
    if text == "" then return nil end
    return text
end

function panel.line_target(page)
    local mine = network_global_index_from_local(0)
    local list
    if page == "doto" then
        list = targets_for(panel.aimed_at())
    elseif (panel.selected or -1) >= 0 then
        list = { panel.selected }
    else
        return nil, 0, false
    end
    local others, one, me = 0, nil, false
    for _, globalIndex in ipairs(list) do
        if globalIndex == mine then
            me = true
        elseif OF.util.local_from_global(globalIndex) ~= nil then
            others = others + 1
            one = globalIndex
        end
    end
    if others ~= 1 then one = nil end
    return one, others, me and others == 0
end

function panel.line_personal(was, mine)
    if mine == true or was.mine == true then return true end
    local feature = was.feature
    if feature == nil then return true end
    return string.match(tostring(feature), "_self$") ~= nil
end

function panel.line_earned(page, was)
    if type(was) ~= "table" or was.heading == true or was.exit == true then
        return false
    end
    if panel.LINE_EXEMPT[page] ~= nil then return false end

    if was.selection == true then return false end

    if panel.line_personal(was) then return false end
    if panel.is_toggle(was) then return true end
    return panel.LINE_PAGES[page] == true and was.feature ~= nil
end

function panel.action_line(page, was, now, mine)
    if not panel.line_earned(page, was) then return false end
    if not OF.util.asks(OF.notify, "line_ask") then return false end

    local target, _, selfOnly = nil, 0, false
    if panel.LINE_TARGETED[page] then
        target, _, selfOnly = panel.line_target(page)
        if selfOnly then return false end
    end

    if now ~= nil and panel.is_toggle(was) and OF.util.is_host()
        and was.dialQuiet ~= true
        and panel.row_value(now) == panel.row_value(was)
        and panel.row_identity(now) == panel.row_identity(was) then
        return false
    end
    local words = panel.line_words(page, was, now)
    if words == nil then return false end
    if panel.line_personal(was, mine) then return false end
    return OF.notify.line_ask(was.feature, words, panel.tone_of(was), target)
end

function panel.flush_feed(was, now)
    local text = panel.feedPending
    panel.feedPending = nil
    if text == nil then return false end
    if now ~= nil and type(was) == "table" and panel.row_ticks(was)
        and OF.util.is_host()
        and panel.row_identity(now) == panel.row_identity(was)
        and row_value(now) == row_value(was) then
        return false
    end
    if not OF.util.asks(OF.panelskin, "feed_push") then return false end
    OF.panelskin.feed_push(text)
    return true
end

function panel.run(action, mine)
    if action == nil then return end

    local was = panel.rows ~= nil and panel.rows[panel.cursor] or nil

    local wasConfirm = panel.confirm

    local wasKey = panel.row_identity(was)
    local wasPage = panel.page

    local wasOpen = panel.open

    local wasSet = panel.change_snapshot()

    local personal = type(was) == "table" and (mine == true or was.mine == true
        or (was.feature ~= nil and string.match(tostring(was.feature), "_self$") ~= nil))
    local hush = (panel.is_toggle(was) or personal) and OF.util.asks(OF.notify, "hush")
    if hush then OF.notify.hush(true) end

    local fine, err

    local wasPressing = panel.pressing
    panel.pressing = true
    if OF.util.asks(OF.notify, "acting") then
        fine, err = pcall(OF.notify.acting, 0, action)
    else
        fine, err = pcall(action)
    end
    panel.pressing = wasPressing
    if hush then OF.notify.hush(false) end
    if not fine then error(err, 0) end

    if OF.util.asks(OF.quick, "remember")
        and panel.page == wasPage and wasOpen and not (was ~= nil and was.notAShortcut) then
        local quickKey = wasKey
        if OF.util.asks(OF.quick, "identity") then
            quickKey = OF.quick.identity(was)
        end
        local heldSel = nil
        local sweep = OF.util.asks(OF.find, "selections_of")
            and OF.find.selections_of(PAGES[wasPage]) or nil
        if sweep ~= nil then
            local fine, got = pcall(sweep.held)
            if fine then heldSel = got end
        end
        OF.quick.remember(wasPage, quickKey, heldSel)
    end

    local armed = panel.confirm ~= nil and panel.confirm ~= wasConfirm
    panel.feedPending = nil
    if panel.page == wasPage and wasKey ~= nil and not armed then
        log_row(wasPage, was, false, mine, true)
    end

    local lineDue = wasKey ~= nil and not armed
        and (panel.page == wasPage or (type(was) == "table" and was.acts == true)
            or panel.is_toggle(was))

    if type(was) == "table" and was.dialQuiet == true and action ~= was.action then
        lineDue = false
    end

    if panel.page == wasPage then panel.relive_gathered() end

    if not panel.open then
        panel.flush_feed(was, nil)
        if lineDue then panel.action_line(wasPage, was, nil, mine) end
        return
    end
    panel.rebuild()

    panel.note_change(wasSet)

    panel.keep_cursor_on(wasKey)
    panel.flush_feed(was, panel.page == wasPage and panel.rows
        and panel.rows[panel.cursor] or nil)

    if lineDue then
        panel.action_line(wasPage, was, panel.page == wasPage and panel.rows
            and panel.rows[panel.cursor] or nil, mine)
    end
end

panel.STICK_DEAD = 30
panel.stickSlideDue = 0
panel.stickSlideNeutral = true

function panel.stick_slide(m)

    local x, y = 0, 0
    if OF.util.asks(OF.input, "menu_stick") then
        x, y = OF.input.menu_stick(m)
    else
        local controller = m ~= nil and m.controller or nil
        x = controller ~= nil and (controller.stickX or 0) or 0
        y = controller ~= nil and (controller.stickY or 0) or 0
    end
    if math.abs(x) < panel.STICK_DEAD or math.abs(x) <= math.abs(y) then
        panel.stickSlideNeutral = true
        panel.stickSlideDue = 0
        return 0, false
    end
    local step = x > 0 and 1 or -1
    if panel.stickSlideNeutral then
        panel.stickSlideNeutral = false
        panel.stickSlideDue = OF.input.REPEAT_DELAY or 10
        return step, true
    end
    panel.stickSlideDue = panel.stickSlideDue - 1
    if panel.stickSlideDue > 0 then return 0, true end
    panel.stickSlideDue = OF.input.REPEAT_INTERVAL or 3
    return step, true
end

function panel.is_toggle(r)
    if type(r) ~= "table" then return false end
    if r.slider ~= nil or r.picker == true then return true end
    return panel.row_ticks(r)
end

function panel.nudge(step)
    local current = panel.rows and panel.rows[panel.cursor]
    if current ~= nil and current.grid ~= nil then return panel.grid_walk(step) end
    if current == nil or current.slider == nil then return false end

    local from, change = panel.dial_target(current.slider, panel.zHeldNow)
    if change == nil then return false end

    local holes = current.slider.holes
    local wanted = from
    for _ = 0, current.slider.steps do
        wanted = OF.util.clamp(wanted + step, 0, current.slider.steps)
        if type(holes) ~= "table" or not holes[wanted] then break end
    end
    if type(holes) == "table" and holes[wanted] then return false end
    if wanted == from then return false end

    local wasSet = panel.change_snapshot()
    local wasKey = panel.row_identity(current)
    local wasPage = panel.page
    OF.sounds.ui("slider_step", OF.sounds.MOVE)
    local hush = OF.util.asks(OF.notify, "hush")
    if hush then OF.notify.hush(true) end
    local fine, err = pcall(change, wanted)
    if hush then OF.notify.hush(false) end
    if not fine then error(err, 0) end

    panel.relive_gathered()
    if panel.open then
        panel.rebuild()

        panel.keep_cursor_on(wasKey)
    end
    panel.note_change(wasSet)

    local now = panel.open and panel.rows and panel.rows[panel.cursor] or current

    log_row(wasPage, now, true, now ~= nil and now.mine == true)

    if current.dialQuiet ~= true then
        panel.action_line(wasPage, current, now, now ~= nil and now.mine == true)
    end
    return true
end

local function says(padKey, mouseKey)
    if not OF.util.asks(OF.input, "device_says") then return padKey end
    return OF.input.device_says(padKey, mouseKey)
end

local function two_boxed(row)
    return type(row) == "table" and row.altBox == 2
        and panel.box_span(row.text, 2) ~= nil
end

function panel.hints(row)
    local list = {}

    if row ~= nil then
        local twoBoxed = two_boxed(row)
        if row.slider ~= nil and row.slider.mine ~= nil then

            if row.slider.onChange ~= nil then
                table.insert(list, { key = says("<>", "Drag"), label = "everybody's level" })
            end
            if row.slider.mine.onChange ~= nil then
                table.insert(list, { key = says(row.slider.onChange ~= nil and "Z+<>" or "<>", "Drag"),
                    label = "my level" })
            end
            if row.clearMine ~= nil then
                table.insert(list, { key = says("hold Z", "Right-click right [x]"),
                    label = "follow lobby" })
            end
        elseif row.slider ~= nil and row.slider.onChange ~= nil then
            table.insert(list, { key = says("<>", "Drag"), label = "set" })
        elseif row.grid ~= nil then

            table.insert(list, { key = says("<>", "Point"), label = "walk the cells" })
        end
        if row.altAction ~= nil and row.altPad then

            if not (OF.util.asks(OF.input, "mouse_driving")
                and OF.input.mouse_driving()) then
                table.insert(list,
                    { key = "Z", label = row.altLabel or "open" })
            end
        elseif row.altAction ~= nil then

            local zone = "Click the strip"
            if twoBoxed then zone = "Click right [x]"
            elseif panel.has_box(row) then zone = "Click [x]" end
            table.insert(list, { key = says("Z", zone),
                label = row.altLabel or "tick", short = row.altShort })
        end
        if row.action ~= nil then

            local what = "pick"
            if row.heading then what = "open"
            elseif panel.row_ticks(row) then what = "tick" end

            if row.actionLabel ~= nil then what = row.actionLabel end

            table.insert(list, {
                key = says("A", twoBoxed and "Click left [x]" or "Click"),
                label = what, short = row.actionLabel ~= nil and row.actionShort or nil })
        end
    end

    table.insert(list, { key = says("^v", "Wheel"), label = "move", nav = true })

    local here = PAGES[panel.page]
    table.insert(list, { key = says("B", "Right-click"),
        label = (here ~= nil and here.up ~= nil) and "back" or "close",
        nav = true })

    table.insert(list, { key = says("L/R", "Click"), label = "tabs", nav = true })

    local rows = panel.rows or {}
    if #rows > (panel.visibleRows or 0) then
        local sections = panel.section_count(rows)
        if sections > 2 then
            table.insert(list, { key = says("Z+L/R", "Wheel on the bar"),
                label = "to sections", nav = true })
        elseif sections == 2 then
            table.insert(list, { key = says("Z+L/R", "Wheel on the bar"),
                label = "to the ends", nav = true })
        end
    end
    return list
end

local function is_stop(r)
    if r == nil then return false end
    if r.action ~= nil then return true end
    return r.walk == true
end

panel.is_stop = is_stop

function panel.rest_cursor()
    if type(panel.rows) ~= "table" then return false end
    for index, r in ipairs(panel.rows) do
        if type(r) == "table" and r.rest == true and is_stop(r) then
            panel.cursor = index
            return true
        end
    end
    return false
end

function panel.move_cursor(step)
    if panel.rows == nil or #panel.rows == 0 then return end
    local index = panel.cursor
    for _ = 1, #panel.rows do
        index = index + step
        if index < 1 then index = #panel.rows end
        if index > #panel.rows then index = 1 end
        if is_stop(panel.rows[index]) then
            panel.cursor = index
            return
        end
    end
end

function panel.section_starts(rows)
    local starts = {}
    if type(rows) ~= "table" or #rows == 0 then return starts end

    local function add(index)
        if starts[#starts] ~= index then starts[#starts + 1] = index end
    end
    add(1)
    for index, r in ipairs(rows) do
        if type(r) == "table" and r.heading == true then add(index) end
    end
    add(#rows)
    return starts
end

function panel.section_count(rows)
    if type(rows) ~= "table" or #rows == 0 then return 0 end

    local count, last = 1, 1
    for index, r in ipairs(rows) do
        if type(r) == "table" and r.heading == true and last ~= index then
            count = count + 1
            last = index
        end
    end
    if last ~= #rows then count = count + 1 end
    return count
end

local function section_landing(rows, at)
    for index = at, #rows do
        if is_stop(rows[index]) then return index end
    end
    return nil
end

function panel.section_target(step)
    local rows = panel.rows
    if type(rows) ~= "table" or #rows == 0 then return nil end
    local starts = panel.section_starts(rows)
    if #starts == 0 then return nil end
    local cursor = panel.cursor or 0

    if step > 0 then
        for _, at in ipairs(starts) do
            if at > cursor then
                local to = section_landing(rows, at)
                if to ~= nil then return at, to end
            end
        end
        for _, at in ipairs(starts) do
            local to = section_landing(rows, at)
            if to ~= nil then return at, to end
        end
        return nil
    end

    for i = #starts, 1, -1 do
        local at = starts[i]
        local to = section_landing(rows, at)
        if to ~= nil and to < cursor then return at, to end
    end
    for i = #starts, 1, -1 do
        local at = starts[i]
        local to = section_landing(rows, at)
        if to ~= nil then return at, to end
    end
    return nil
end

function panel.jump_section(step)
    local rows = panel.rows
    if type(rows) ~= "table" or #rows == 0 then return false end
    local at, to = panel.section_target(step)
    if to == nil or to == panel.cursor then return false end

    panel.cursor = to

    local visible = panel.visibleRows
    if type(visible) ~= "number" or visible < 2 then visible = 2 end
    local top = at - 1
    if top > 0 and type(panel.pinned_rows) == "function"
        and panel.pinned_rows(rows, top) > 0 then
        top = top - 1
    end
    if to > top + visible then top = to - visible end
    panel.scroll = math.floor(
        OF.util.clamp(top, 0, math.max(0, #rows - visible)))
    return true
end

function panel.travel_from_here(page)
    panel.travelFrom = page or panel.page
    return panel.travelFrom
end

function panel.travel_return(fallback)
    local to = panel.travelFrom or fallback
    panel.travelFrom = nil
    return to
end

function panel.back()

    if panel.page == "groups" and panel.travelFrom ~= nil then
        local to = panel.travel_return()
        if panel.levelMode == "pipe" then
            if OF.util.asks(OF.forge, "pipe_pick_cancel") then OF.forge.pipe_pick_cancel() end
            panel.levelMode = "everyone"
        end
        go(to)
        return
    end
    local h = panel.history
    if #h > 0 then
        go(h[#h].page)
        return
    end
    local def = PAGES[panel.page]
    if def ~= nil and def.up ~= nil then
        go(def.up, "back")
        return
    end
    panel.close()
end

function panel.back_to(page)
    for i = #panel.history, 1, -1 do
        if panel.history[i].page == page then
            go(page)
            return
        end
    end
    panel.history_clear()
    go(page, "back")
end

function panel.is_open()
    return panel.open == true
end

function panel.toggle()
    if panel.open then panel.close() else panel.show() end
end

panel.refusedAt = nil

function panel.say_no_menu(asked)
    local tier = OF.util.asks(OF.perms, "my_tier") and OF.perms.my_tier() or nil
    if not asked and panel.refusedAt ~= nil and panel.refusedAt == tier then
        return false
    end
    panel.refusedAt = tier

    local why = OF.lang.t("Your rank cannot open the mod menu.")
    if OF.util.asks(OF.perms, "required") and OF.util.asks(OF.perms, "tier_name") then
        local needs = OF.perms.required("panel")
        if needs < OF.TIER.HOST then
            why = OF.lang.fill("The mod menu opens at @ - ask the host for it.",
                OF.lang.t(OF.perms.tier_name(needs)))
        end
    end

    if asked then
        OF.util.chat(why, "warn")
        OF.sounds.ui("error", OF.sounds.DENIED)
    else
        OF.notify.show(why, "bad")
    end
    return true
end

function panel.show()

    local asked = OF.util.asked_in_chat()
    if OF.jail ~= nil and OF.jail.active then
        local why = OF.lang.fill("@ - the mod menu is closed until it ends.",
            OF.lang.t(OF.jail.reason ~= "" and OF.jail.reason or "You are jailed"))
        if asked then
            OF.util.chat(why, "warn")
            OF.sounds.ui("error", OF.sounds.DENIED)
        else
            OF.notify.show(why, "bad")
        end
        return
    end
    if not OF.perms.can("panel") then
        panel.say_no_menu(asked)
        return
    end
    panel.open = true

    panel.history_clear()

    panel.page = panel.lastPage or panel.page_for_tab(panel.TABS[panel.tab].key)
    if PAGES[panel.page] == nil then
        panel.page = panel.page_for_tab(panel.TABS[panel.tab].key)
    end

    if panel.lastPage == nil and #panel.TABS > 0
        and OF.util.asks(OF.util, "connected_players")
        and #OF.util.connected_players() <= 1 then
        for index, tab in ipairs(panel.TABS) do
            if tab.key == "race" then
                panel.tab = index
                panel.page = panel.page_for_tab(tab.key)
                break
            end
        end
    end
    mark_tab_page(panel.page)
    local was = panel.memory[panel.page]
    panel.scroll = was ~= nil and was.scroll or 0
    panel.cursor = was ~= nil and was.cursor or 1
    panel.confirm = nil

    panel.foldAsk = panel.page
    panel.mark_arrival()
    panel.rebuild()

    if was ~= nil and was.key ~= nil then panel.keep_cursor_on(was.key) end

    if OF.util.asks(OF.input, "hold_mouse") then
        OF.input.hold_mouse("panel", true)
    end
    OF.sounds.ui("open", OF.sounds.OPEN)
end

function panel.close()
    if panel.open then OF.sounds.ui("close", OF.sounds.CLOSE) end
    panel.travelFrom = nil
    panel.remember()

    local closingDef = panel.PAGES[panel.page]
    if closingDef ~= nil and closingDef.transient == true then
        panel.lastPage = panel.page_for_tab(panel.tab_of(panel.page))
    else
        panel.lastPage = panel.page
    end
    panel.open = false
    panel.confirm = nil

    panel.landed = nil

    panel.drag = nil
    panel.resizing = nil
    panel.sliderDrag = nil
    panel.scrollDrag = nil

    if panel.forget_active ~= nil then panel.forget_active() end

    if OF.util.asks(OF.input, "hold_mouse") then
        OF.input.hold_mouse("panel", false)
    end
end

local lastBadgeX, lastBadgeY = nil, nil

local TAB_SCALE = 0.9
local TAB_PADDING = 7
local TAB_GAP = 18

local function rows_in_view(m, height)
    local listHeight = height - m.titleHeight - m.tabHeight - m.footerHeight
        - LIST_PADDING * 2
    return math.max(1, math.floor(listHeight / m.rowHeight))
end

local function metrics()
    local rowText = OF.util.line_height(ROW_SCALE)
    local titleText = OF.util.line_height(TITLE_SCALE)
    local footerText = OF.util.line_height(FOOTER_SCALE)
    local tabText = OF.util.line_height(TAB_SCALE)
    return {
        rowText = rowText,
        rowHeight = rowText + ROW_GAP,
        titleHeight = titleText + TITLE_PADDING * 2,
        footerHeight = footerText + FOOTER_PADDING * 2,
        tabHeight = tabText + TAB_PADDING * 2,
        titleText = titleText,
        footerText = footerText,
        tabText = tabText,
    }
end

function panel.rows_that_fit()
    local _, _, _, height = panel.geometry()
    return rows_in_view(metrics(), height)
end

local fadeNow = 1

local function dim_rect(x, y, w, h, r, g, b, a)
    OF.util.rect(x, y, w, h, r, g, b, a * fadeNow)
end

panel.grid_rect = dim_rect

function panel.fade_now()
    return fadeNow
end

do
    local FIT_LIMIT = 2048
    local byFont, held = {}, 0
    local heldMeasure, heldWidth, heldFit = nil, nil, nil

    function panel.fit_to(message, scale, room)
        local getFont = djui_hud_get_font
        if getFont == nil or type(message) ~= "string"
            or type(scale) ~= "number" or scale ~= scale
            or type(room) ~= "number" or room ~= room then
            return OF.util.fit(message, scale, room)
        end
        local util = OF.util
        local measure, width, fit = djui_hud_measure_text, util.width, util.fit
        if measure ~= heldMeasure or width ~= heldWidth or fit ~= heldFit
            or held > FIT_LIMIT then
            byFont, held = {}, 0
            heldMeasure, heldWidth, heldFit = measure, width, fit
        end
        local font = getFont()
        if font == nil or font ~= font then return fit(message, scale, room) end
        local fonts = byFont[font]
        if fonts == nil then
            fonts = { whole = {} }
            byFont[font] = fonts
        end

        local shelves = fonts
        if math.type(scale) == "integer" then shelves = fonts.whole end
        local rooms = shelves[scale]
        if rooms == nil then
            rooms = {}
            shelves[scale] = rooms
        end
        local kept = rooms[room]
        if kept == nil then
            kept = {}
            rooms[room] = kept
        end
        local answer = kept[message]
        if answer == nil then
            answer = fit(message, scale, room)
            kept[message] = answer
            held = held + 1
        end
        return answer
    end
end

panel.MARQUEE_SPEED = 1
panel.MARQUEE_PAUSE = 45
do
    local heldText, heldScale, chars, edges = nil, nil, nil, nil

    local function split(text, scale)
        if text == heldText and scale == heldScale then return chars, edges end
        chars, edges = {}, { [0] = 0 }
        for ch in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
            chars[#chars + 1] = ch
            edges[#chars] = edges[#chars - 1] + OF.util.width(ch, scale)
        end
        heldText, heldScale = text, scale
        return chars, edges
    end

    function panel.marquee_offset(travel, frame)
        if travel <= 0 then return 0 end
        local pause, speed = panel.MARQUEE_PAUSE, panel.MARQUEE_SPEED
        local moving = travel / speed
        local phase = (frame or 0) % (pause + moving + pause)
        return math.max(0, math.min(travel, (phase - pause) * speed))
    end

    function panel.marquee(text, scale, room, frame)
        if type(text) ~= "string" or type(scale) ~= "number" or type(room) ~= "number" then
            return text, 0
        end
        if OF.util.width(text, scale) <= room then return text, 0 end

        if string.find(text, string.char(92, 35), 1, true) ~= nil then
            return panel.fit_to(text, scale, room), 0
        end
        local list, edge = split(text, scale)
        local offset = panel.marquee_offset(edge[#list] - room, frame)
        local first, last = nil, 0
        for i = 1, #list do
            if first == nil and edge[i - 1] >= offset - 0.001 then first = i end
            if edge[i] <= offset + room + 0.001 then last = i end
        end
        if first == nil or last < first then return "", 0 end
        return table.concat(list, "", first, last), edge[first - 1] - offset
    end
end

do
    local started = {}
    function panel.marquee_frame(place, text)
        local now = get_global_timer()
        local held = started[place]
        if held == nil or held.text ~= text then
            held = { text = text, at = now }
            started[place] = held
        end
        return now - held.at
    end
end

function panel.legend_width(list, platePadding, gap)
    local total = 0
    for index, hint in ipairs(list) do
        total = total + OF.util.width(hint.key, FOOTER_SCALE) + platePadding * 2
            + 4 + OF.util.width(OF.lang.t(hint.label), FOOTER_SCALE)
        if index < #list then total = total + gap end
    end
    return total
end

do
local FOOTER_GAP, FOOTER_PLATE_PADDING, FOOTER_HELP_ROOM = 9, 4, 280
panel.FOOTER_GAP = FOOTER_GAP
panel.FOOTER_SIDE_PADDING = SIDE_PADDING
function panel.footer_hints(row, room, chips)
    local hints = panel.hints(row)
    local contextual = 0
    for _, hint in ipairs(hints) do
        if not hint.nav then contextual = contextual + 1 end
    end
    local function legend_width()
        if chips then return OF.panelskin.legend_width(hints, FOOTER_SCALE, FOOTER_GAP) end
        return panel.legend_width(hints, FOOTER_PLATE_PADDING, FOOTER_GAP)
    end
    local help = row ~= nil and row.help or nil
    local wantsRoom = help ~= nil and help ~= ""
    while #hints > 1 and (legend_width() > room
        or (wantsRoom and #hints > contextual
            and legend_width() > room - FOOTER_HELP_ROOM)) do
        table.remove(hints)
    end

    if wantsRoom and legend_width() > room - FOOTER_HELP_ROOM then
        for _, hint in ipairs(hints) do
            if hint.short ~= nil then hint.label = hint.short end
        end
    end
    return hints, contextual, legend_width
end
end

do
    local heldTitle, heldR, heldG, heldB = nil, nil, nil, nil

    function panel.title_segments(r, g, b)

        if heldTitle == nil or r ~= heldR or g ~= heldG or b ~= heldB
            or math.type(r) ~= math.type(heldR) or math.type(g) ~= math.type(heldG)
            or math.type(b) ~= math.type(heldB) then
            heldTitle = {
                { text = "old",           r = r, g = g, b = b },
                { text = "fart",          r = 255, g = 255, b = 255 },
            }
            heldR, heldG, heldB = r, g, b
        end
        return heldTitle
    end

    panel.logoInfo = nil
    function panel.logo_info()
        if panel.logoInfo == nil then
            panel.logoInfo = false
            if get_texture_info ~= nil then
                local ok, info = pcall(get_texture_info, "oflogo")
                if ok and type(info) == "table" and (info.width or 0) > 0
                    and (info.height or 0) > 0 then
                    panel.logoInfo = info
                end
            end
        end
        return panel.logoInfo or nil
    end
end

do
    local CHEVRON_SIZE_RATIO = 0.42
    local CHEVRON_SIDE_PAD_RATIO = 0.45

    local CHEVRON_DROP_RATIO = 0.09

    function panel.chevron_size(scale)
        return OF.util.line_height(scale) * CHEVRON_SIZE_RATIO
    end

    function panel.chevron_width(scale)
        local size = panel.chevron_size(scale)
        return size + size * CHEVRON_SIDE_PAD_RATIO * 2
    end

    function panel.trail_width(segments, scale)
        local w = 0
        for _, seg in ipairs(segments) do
            if seg.chevron then
                w = w + panel.chevron_width(scale)
            else
                w = w + OF.util.drawn_width(seg.text, scale)
            end
        end
        return w
    end

    function panel.draw_trail(segments, x, y, scale, alpha)
        local lineHeight = OF.util.line_height(scale)
        for _, seg in ipairs(segments) do
            if seg.chevron then
                local size = panel.chevron_size(scale)
                local pad = size * CHEVRON_SIDE_PAD_RATIO
                OF.hud.arrow_glyph("right", x + pad + size * 0.5,
                    y + (lineHeight - size) * 0.5 + lineHeight * CHEVRON_DROP_RATIO + size * 0.5, size,
                    { seg.r, seg.g, seg.b }, alpha, "chevron")
                x = x + panel.chevron_width(scale)
            else
                OF.util.text(seg.text, x, y, scale, seg.r, seg.g, seg.b, alpha)
                x = x + OF.util.drawn_width(seg.text, scale)
            end
        end
    end
end

local TAB_WINDOW = 2

local function render_tabs(x, y, width, m, mouseX, mouseY, clicked, wheel)
    local look = OF.theme.active()
    dim_rect(x, y, width, m.tabHeight,
        math.floor(look.title.r * 0.7), math.floor(look.title.g * 0.7),
        math.floor(look.title.b * 0.7), 255)

    local first = math.max(1, panel.tab - TAB_WINDOW)
    local last = math.min(#panel.TABS, panel.tab + TAB_WINDOW)

    local iconRoom = 0
    if panel.skin_on() then iconRoom = OF.panelskin.TAB_ICON + 6 end
    local total = 0
    for i = first, last do
        total = total + OF.util.width(OF.lang.t(panel.TABS[i].name), TAB_SCALE) + iconRoom + TAB_GAP
    end
    total = total - TAB_GAP

    local cursorX = x + (width - total) * 0.5
    local textY = y + (m.tabHeight - m.tabText) * 0.5
    local roundOnly = nil

    for i = first, last do
        local tab = panel.TABS[i]
        local tabName = OF.lang.t(tab.name)
        local tabWidth = OF.util.width(tabName, TAB_SCALE) + iconRoom
        local distance = math.abs(i - panel.tab)

        local r, g, b, a = 150, 150, 150, 150
        if distance == 0 then
            r, g, b, a = 255, 255, 255, 255
        elseif distance == 1 then
            r, g, b, a = 190, 190, 190, 200
        end

        local hovered = mouseY >= y and mouseY <= y + m.tabHeight
            and mouseX >= cursorX - TAB_GAP * 0.5
            and mouseX <= cursorX + tabWidth + TAB_GAP * 0.5
        if hovered and distance ~= 0 then r, g, b, a = 230, 230, 230, 255 end

        if roundOnly == nil then roundOnly = panel.round_tab_only() end
        if roundOnly and tab.key ~= panel.ROUND_TAB then
            r, g, b, a = 95, 95, 95, 120
        end

        local skinned = distance == 0 and panel.skin_on()
        if distance == 0 then
            local plateX = cursorX - TAB_GAP * 0.5
            local plateWidth = tabWidth + TAB_GAP
            dim_rect(plateX, y + 2, plateWidth, m.tabHeight - 2,
                look.title.r, look.title.g, look.title.b, 255)
            dim_rect(plateX, y + 2, plateWidth, 1, 255, 255, 255, 45)
            dim_rect(plateX, y + 2, 1, m.tabHeight - 2, 255, 255, 255, 20)
            dim_rect(plateX + plateWidth - 1, y + 2, 1, m.tabHeight - 2,
                0, 0, 0, 45)
        end

        if iconRoom > 0 then

            local ic = { r, g, b }
            if distance == 0 then
                local hr, hg, hb = highlight()
                ic = { hr, hg, hb }
            end
            OF.panelskin.tab_icon(tab.key, cursorX, y + (m.tabHeight - OF.panelskin.TAB_ICON) * 0.5,
                OF.panelskin.TAB_ICON, ic, a * fadeNow)
        end
        OF.util.text(tabName, cursorX + iconRoom, textY, TAB_SCALE, r, g, b, a)

        if distance == 0 then
            local hr, hg, hb = highlight()
            dim_rect(cursorX - 4, y + m.tabHeight - 3, tabWidth + 8, 3,
                hr, hg, hb, 255)
            if skinned then
                OF.panelskin.tab_underline(cursorX - 4, tabWidth + 8, y + m.tabHeight - 3, hr, hg, hb)
            end
        end

        if hovered and clicked and distance ~= 0 then

            panel.show_tab(i)
            OF.sounds.ui("tab", OF.sounds.TAB)
            return true
        end

        if hovered and clicked and distance == 0 then
            panel.tab_home(i)
            OF.sounds.ui("tab", OF.sounds.TAB)
            return true
        end

        cursorX = cursorX + tabWidth + TAB_GAP
    end

    local function arrow(glyph, glyphX, direction, shown)
        if not shown then return false end
        local w = OF.util.width(glyph, TAB_SCALE)
        local hovered = mouseY >= y and mouseY <= y + m.tabHeight
            and mouseX >= glyphX - TAB_GAP * 0.5
            and mouseX <= glyphX + w + TAB_GAP * 0.5
        local lit = hovered and 230 or 120
        local glyphH = OF.util.line_height(TAB_SCALE)
        OF.hud.arrow_glyph(direction < 0 and "left" or "right", glyphX + w * 0.5, textY + glyphH * 0.5,
            math.max(8, math.floor(glyphH * 0.6)), { lit, lit, lit }, hovered and 255 or 200, "chevron")
        if hovered and clicked then
            panel.next_tab(direction)
            return true
        end
        return false
    end

    if arrow("<", x + SIDE_PADDING, -1, first > 1) then return true end
    if arrow(">", x + width - OF.util.width(">", TAB_SCALE) - SIDE_PADDING, 1,
        last < #panel.TABS) then
        return true
    end

    if wheel ~= 0 then
        panel.next_tab(wheel > 0 and -1 or 1)
        return true
    end

    return false
end

local function pinned_rows(rows, scroll)
    if scroll <= 0 then return 0 end
    for index = scroll, 1, -1 do
        local candidate = rows[index]
        if candidate ~= nil and candidate.heading then return 1 end
    end
    return 0
end

panel.pinned_rows = pinned_rows

local function clamp_cursor_into_view(visibleRows, viewMoved)
    if panel.cursor < 1 then return end

    local rows = panel.rows or {}
    local hidden = pinned_rows(rows, panel.scroll)
    local firstSeen = panel.scroll + 1 + hidden
    local lastSeen = panel.scroll + visibleRows

    if viewMoved then
        if panel.cursor < firstSeen then
            panel.cursor = firstSeen
        elseif panel.cursor > lastSeen then
            panel.cursor = lastSeen
        else
            return
        end

        local wanted = panel.cursor
        for step = 0, #rows do
            local at = wanted + step
            if panel.is_stop(rows[at])
                and at >= firstSeen and at <= lastSeen then
                panel.cursor = at
                return
            end
            at = wanted - step
            if panel.is_stop(rows[at])
                and at >= firstSeen and at <= lastSeen then
                panel.cursor = at
                return
            end
        end
        return
    end

    if panel.cursor < firstSeen then

        panel.scroll = panel.cursor - 1 - hidden
        if panel.scroll < 0 then panel.scroll = 0 end
    elseif panel.cursor > lastSeen then
        panel.scroll = panel.cursor - visibleRows
    end
end

local function edge_shade(x, width, edgeY, direction, depth)
    for step = 1, 4 do
        local alpha = math.floor(depth * (5 - step) / 5)
        if alpha <= 0 then return end
        dim_rect(x + 2, edgeY + direction * (step - 1), width - 4, 1,
            0, 0, 0, alpha)
    end
end

local draw_selection
do
    local SELECT_BANDS = 5
    local SELECT_REACH = 0.55

function draw_selection(x, width, top, height)
    local inner = width - 4

    local hr, hg, hb = gold().r, gold().g, gold().b
    if OF.util.asks(OF.theme, "highlight") then
        hr, hg, hb = OF.theme.highlight()
    end

    dim_rect(x + 2, top, inner, height, 255, 255, 255, 18)

    local bandWidth = (inner * SELECT_REACH) / SELECT_BANDS
    for band = 1, SELECT_BANDS do
        local alpha = 34 - band * 6
        if alpha <= 0 then break end
        dim_rect(x + 2 + (band - 1) * bandWidth, top, bandWidth, height,
            hr, hg, hb, alpha)
    end

    dim_rect(x + 2, top, inner, 1, hr, hg, hb, 70)
    dim_rect(x + 2, top + height - 1, inner, 1, hr, hg, hb, 40)

    dim_rect(x + 2, top, 3, height, hr, hg, hb, 255)
end
end

local function render_panel()
    if not panel.open then return end
    if OF.jail.active then
        panel.close()
        return
    end

    if OF.util.asks(OF.perms, "can") and not OF.perms.can("panel") then
        panel.close()
        panel.say_no_menu(false)
        return
    end

    if panel.round_tab_only() and known_page(panel.page)
        and panel.tab_of(panel.page) ~= panel.ROUND_TAB then
        panel.page = panel.page_for_tab(panel.ROUND_TAB)
        panel.sync_tab()
        panel.rebuild()
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    djui_hud_set_mouse_locked(false)

    fadeNow = panel.fade()

    if arrival < ARRIVE_FRAMES then arrival = arrival + 1 end

    local m = metrics()
    local x, y, width, height = panel.geometry()

    local rows = panel.rows
    if rows == nil then rows = panel.rebuild() end

    local listTop = y + m.titleHeight + m.tabHeight + LIST_PADDING
    local visibleRows = rows_in_view(m, height)
    panel.visibleRows = visibleRows

    local lab = nil
    if panel.skin_on() and OF.util.asks(OF.panelskin, "layout") then
        lab = OF.panelskin.layout(width, SIDE_PADDING, SCROLLBAR_STRIP)
        m = OF.panelskin.metrics(m)
        x, y, width, height = lab.lx, lab.ly, lab.lw, lab.lh
        listTop = lab.ly
        visibleRows = OF.panelskin.rows_in(lab, m)
        panel.visibleRows = visibleRows
    end

    local rowBand = panel.level_band(rows, width)

    local maxScroll = math.max(0, #rows - visibleRows)

    local wentToEnd = panel.scrollToEnd == true
    if panel.scrollToEnd then
        panel.scroll = maxScroll
        panel.scrollToEnd = false
    end

    local mouseX = djui_hud_get_mouse_x()
    local mouseY = djui_hud_get_mouse_y()

    local mouseMoved = lastMouseX == nil
        or math.abs(mouseX - lastMouseX) >= 1 or math.abs(mouseY - lastMouseY) >= 1
    lastMouseX, lastMouseY = mouseX, mouseY

    local WHEEL_ROWS = 3
    local wheel = djui_hud_get_mouse_scroll_y()

    local tabTop = y + m.titleHeight
    local onTabs = mouseY >= tabTop and mouseY <= tabTop + m.tabHeight
        and mouseX >= x and mouseX <= x + width
    if lab then
        local bar = lab.tabBar
        onTabs = mouseY >= bar.y and mouseY <= bar.y + bar.h
            and mouseX >= bar.x and mouseX <= bar.x + bar.w
    end

    local tabWheel = onTabs and wheel or 0
    if tabWheel ~= 0 then wheel = 0 end

    local BAR_GRAB = 12
    local barX = x + width - 5
    local trackTop = listTop
    local trackHeight = visibleRows * m.rowHeight
    local overBar = mouseX >= barX - BAR_GRAB and mouseX <= barX + BAR_GRAB
        and mouseY >= trackTop and mouseY <= trackTop + trackHeight
    local barWheel = 0
    if maxScroll > 0 and not onTabs and overBar then
        barWheel = wheel
        if barWheel ~= 0 then wheel = 0 end
    end

    panel.scroll = panel.scroll - wheel * WHEEL_ROWS
    panel.scroll = math.floor(OF.util.clamp(panel.scroll, 0, maxScroll))

    if barWheel ~= 0 and panel.jump_section(barWheel > 0 and -1 or 1) then
        OF.sounds.ui("move", OF.sounds.MOVE)
    end

    local sameList = lastScrollPage == panel.page
    clamp_cursor_into_view(visibleRows,
        (sameList or wentToEnd) and panel.scroll ~= lastScroll)
    panel.scroll = math.floor(OF.util.clamp(panel.scroll, 0, maxScroll))
    lastScroll = panel.scroll
    lastScrollPage = panel.page

    local buttons = djui_hud_get_mouse_buttons_pressed()
    local clicked = OF.util.has_flag(buttons, L_MOUSE_BUTTON)
        or OF.input.mouse_pressed(L_MOUSE_BUTTON)
    local rightClicked = OF.util.has_flag(buttons, R_MOUSE_BUTTON)
        or OF.input.mouse_pressed(R_MOUSE_BUTTON)

    local middleClicked = M_MOUSE_BUTTON ~= nil and (OF.util.has_flag(buttons, M_MOUSE_BUTTON)
        or OF.input.mouse_pressed(M_MOUSE_BUTTON))

    local gridUp = OF.util.asks(OF.mapgrid, "is_open") and OF.mapgrid.is_open()
    local gridClick, gridRight = clicked, rightClicked
    if gridUp then clicked, rightClicked, middleClicked = false, false, false end

    local held = OF.util.has_flag(
        OF.util.optional("djui_hud_get_mouse_buttons_down", 0), L_MOUSE_BUTTON)

    if clicked and panel.drag == nil and panel.resizing == nil then
        local target = panel.crumb_at(mouseX, mouseY)
        if target ~= nil then
            OF.sounds.ui("back", OF.sounds.MOVE)
            panel.back_to(target)
            return
        end
    end

    if not held then
        panel.resizing = nil
    elseif panel.resizing == nil and panel.drag == nil and clicked and lab == nil then
        local edge = panel.resize_edge(mouseX, mouseY, x, y, width, height)
        if edge ~= nil then
            panel.resizing = { edge = edge, mx = mouseX, my = mouseY,
                x = x, y = y, width = width, height = height }
            clicked = false
        end
    end
    if panel.resizing ~= nil then
        panel.resize_step(panel.resizing, mouseX, mouseY)
        x, y, width, height = panel.geometry()
        listTop = y + m.titleHeight + m.tabHeight + LIST_PADDING
        visibleRows = rows_in_view(m, height)
        panel.visibleRows = visibleRows
        clicked = false
    end

    if not held then
        panel.drag = nil
    elseif panel.drag == nil and clicked and lab == nil
        and mouseY >= y and mouseY < y + m.titleHeight
        and mouseX >= x and mouseX <= x + width then
        panel.drag = { dx = mouseX - x, dy = mouseY - y }
    end

    if panel.drag ~= nil then
        local screenWidth = djui_hud_get_screen_width()
        local screenHeight = djui_hud_get_screen_height()
        local freeX = math.max(0, screenWidth - width)
        local freeY = math.max(0, screenHeight - height)

        if freeX > 0 then
            OF.util.report(panel.set_place("x", ((mouseX - panel.drag.dx) / freeX) * 100))
        end
        if freeY > 0 then
            OF.util.report(panel.set_place("y", ((mouseY - panel.drag.dy) / freeY) * 100))
        end
        x, y, width, height = panel.geometry()
        listTop = y + m.titleHeight + m.tabHeight + LIST_PADDING
    end

    local look = OF.theme.active()

    if lab then

        OF.panelskin.backdrop(true)
        if OF.panelskin.chrome(lab, { mouseX = mouseX, mouseY = mouseY, clicked = clicked,
            wheel = tabWheel, now = OF.util.optional("get_global_timer", 0) or 0 }) then
            return
        end
    else
        if panel.skin_on() then OF.panelskin.backdrop() end

        for step = 3, 1, -1 do
            local spread = step * 3
            dim_rect(x - 2 - spread, y - 2 - spread,
                width + 4 + spread * 2, height + 4 + spread * 2,
                0, 0, 0, 26 - step * 6)
        end

        dim_rect(x - 2, y - 2, width + 4, height + 4,
            look.frame.r, look.frame.g, look.frame.b, look.frame.a)
        dim_rect(x, y, width, height, look.panel.r, look.panel.g, look.panel.b, look.panel.a)

        local bands = 4
        for band = 1, bands do
            local lift = (bands - band + 1) * 5
            local bandHeight = math.ceil(m.titleHeight / bands)
            dim_rect(x, y + (band - 1) * bandHeight, width, bandHeight,
                math.min(255, look.title.r + lift),
                math.min(255, look.title.g + lift),
                math.min(255, look.title.b + lift), 255)
        end

        dim_rect(x, y, width, 1, 255, 255, 255, 30)
        dim_rect(x, y + height - 1, width, 1, 0, 0, 0, 60)

        dim_rect(x, y, 1, height, 255, 255, 255, 18)
        dim_rect(x + width - 1, y, 1, height, 0, 0, 0, 55)

        local innerTop = y + m.titleHeight
        local innerHeight = height - m.titleHeight - 1
        dim_rect(x + 1, innerTop, 1, innerHeight,
            look.frame.r, look.frame.g, look.frame.b, 22)
        dim_rect(x + width - 2, innerTop, 1, innerHeight,
            look.frame.r, look.frame.g, look.frame.b, 22)
        dim_rect(x + 1, y + height - 2, width - 2, 1,
            look.frame.r, look.frame.g, look.frame.b, 22)

        dim_rect(x, y + m.titleHeight - 1, width, 1, gold().r, gold().g, gold().b, 120)
        if panel.skin_on() then
            local hr, hg, hb = highlight()
            OF.panelskin.frame(x, y, width, height, m.titleHeight, hr, hg, hb)
        end

        local titleY = y + TITLE_PADDING

        local brand = OF.BRAND
        if type(brand) ~= "table" or brand.r == nil then
            brand = { r = 255, g = 255, b = 0 }
        end
        local titleSegments = panel.title_segments(brand.r, brand.g, brand.b)

        local nameX = x + SIDE_PADDING
        local logo = panel.logo_info()
        if logo then
            local side = m.titleText
            local restore = djui_hud_get_filter and djui_hud_get_filter() or nil
            if panel.skin_on() then OF.panelskin.logo_glow(nameX, titleY, side) end
            if djui_hud_set_filter and FILTER_LINEAR then djui_hud_set_filter(FILTER_LINEAR) end
            djui_hud_set_color(255, 255, 255, 255)
            djui_hud_render_texture(logo, nameX, titleY,
                side / logo.width, side / logo.height)
            if djui_hud_set_filter and restore ~= nil then djui_hud_set_filter(restore) end
            if panel.skin_on() then OF.panelskin.logo_shine(nameX, titleY, side) end
            nameX = nameX + side + LOGO_GAP
        end

        local nameFace = OF.util.hud_face(OF.util.segments_text(titleSegments))
        local nameWidth, nameGap
        if nameFace ~= nil then
            nameWidth = OF.util.in_font(nameFace, function()
                local unitHeight = OF.util.line_height(1)
                local scale = TITLE_SCALE
                if unitHeight ~= nil and unitHeight > 0 then
                    scale = m.titleText / unitHeight
                end

                local drawnHeight = OF.util.line_height(scale)
                OF.util.draw_segments(titleSegments, nameX,
                    titleY + (m.titleText - drawnHeight) * 0.5, scale, 255)
                return OF.util.segments_width(titleSegments, scale)
            end)

            nameGap = m.titleText * 0.5
        else
            OF.util.draw_segments(titleSegments, nameX, titleY, TITLE_SCALE, 255)
            nameWidth = OF.util.segments_width(titleSegments, TITLE_SCALE)
            nameGap = 0
        end

        local myTier = OF.perms.my_tier()
        local tag = OF.perms.tier_name(myTier)
        local tagR, tagG, tagB = 170, 170, 170
        if OF.util.asks(OF.perms, "tier_color") then
            tagR, tagG, tagB = OF.perms.tier_color(myTier)
        end
        local tagWidth = OF.util.width(tag, FOOTER_SCALE)
        local tagY = titleY + (m.titleText - m.footerText) * 0.5
        OF.util.text(tag, x + width - tagWidth - SIDE_PADDING, tagY,
            FOOTER_SCALE, tagR, tagG, tagB, 255)

        local build = "v" .. tostring(OF.VERSION)
        OF.util.text(build,
            x + width - tagWidth - SIDE_PADDING - VERSION_GAP
                - OF.util.width(build, FOOTER_SCALE),
            tagY, FOOTER_SCALE, 120, 120, 120, 255)

        local crumbX = nameX + nameWidth + nameGap
        local crumbY = titleY + (m.titleText - OF.util.line_height(CRUMB_SCALE)) * 0.5

        local crumbRoom = (x + width - tagWidth - SIDE_PADDING - VERSION_GAP
            - OF.util.width("v" .. tostring(OF.VERSION), FOOTER_SCALE)) - crumbX
            - SIDE_PADDING

        local crumbs = panel.crumbs
        if type(crumbs) ~= "table" or #crumbs == 0 then crumbs = panel.trail(panel.page) end
        if #crumbs == 0 then crumbs = { OF.lang.t(PAGES.players.title) } end

        local selected = panel.selection_count()
        local tail = {}
        if selected > 0 then
            table.insert(tail, { text = "   -   ", r = 110, g = 110, b = 110 })
            table.insert(tail,
                { text = OF.lang.fill("@ selected", selected), r = 255, g = 215, b = 120 })
            crumbRoom = crumbRoom - OF.util.segments_width(tail, CRUMB_SCALE)
        end

        local first = panel.crumbs_shown(crumbs, crumbRoom)
        local segments = {}
        table.insert(segments, { chevron = true, r = 110, g = 110, b = 110 })
        if first > 1 then
            table.insert(segments, { text = "...", r = 110, g = 110, b = 110 })
            table.insert(segments, { chevron = true, r = 110, g = 110, b = 110 })
        end
        local leaf = nil

        local crumbKeys = panel.trail_keys(panel.page)
        if #crumbKeys ~= #crumbs then crumbKeys = {} end
        local hoverKey = panel.crumb_at(mouseX, mouseY)
        for index = first, #crumbs do
            local last = index == #crumbs

            local shade = last and 215 or 150
            local key = (not last) and crumbKeys[index] or nil

            if key ~= nil and key == hoverKey then shade = 255 end
            table.insert(segments,
                { text = tostring(crumbs[index]), r = shade, g = shade, b = shade,
                  key = key })
            if last then
                leaf = #segments
            else
                table.insert(segments, { chevron = true, r = 110, g = 110, b = 110 })
            end
        end

        local overflow = panel.trail_width(segments, CRUMB_SCALE) - crumbRoom
        if overflow > 0 and leaf ~= nil then
            local cut = segments[leaf]
            cut.text = panel.fit_to(cut.text, CRUMB_SCALE,
                OF.util.width(cut.text, CRUMB_SCALE) - overflow)
        end
        for _, seg in ipairs(tail) do table.insert(segments, seg) end
        panel.draw_trail(segments, crumbX, crumbY, CRUMB_SCALE, 255)
        panel.crumbHits = { top = crumbY, bottom = crumbY + OF.util.line_height(CRUMB_SCALE),
            list = panel.trail_hits(segments, crumbX, CRUMB_SCALE) }

        if render_tabs(x, y + m.titleHeight, width, m, mouseX, mouseY, clicked,
            tabWheel) then
            return
        end
    end

    panel.listLeft, panel.drawScale = x + SIDE_PADDING, ROW_SCALE

    panel.drawFont = lab and FONT_ALIASED or FONT_NORMAL
    panel.boxSlot = nil
    if lab then
        djui_hud_set_font(FONT_ALIASED)

        lab.boxCell = OF.util.width(panel.tick(true, ""), ROW_SCALE)
        lab.boxes = 0

        panel.boxSlot = lab.boxCell
        for _, each in ipairs(rows) do
            lab.boxes = math.max(lab.boxes, #(OF.panelskin.split_boxes(each.text)))
        end
    end

    local stuck = nil
    if panel.scroll > 0 then
        for index = panel.scroll, 1, -1 do
            local candidate = rows[index]
            if candidate ~= nil and candidate.heading then
                stuck = candidate
                break
            end
        end
    end

    local firstRow = 1
    if stuck ~= nil then
        dim_rect(x + 2, listTop, width - 4, m.rowHeight,
            look.title.r, look.title.g, look.title.b, 235)
        local hr, hg, hb = highlight()
        dim_rect(x + 2, listTop + m.rowHeight - 1, width - 4, 1,
            hr, hg, hb, 90)
        OF.util.text(stuck.text, x + SIDE_PADDING,
            listTop + (m.rowHeight - m.rowText) * 0.5,
            ROW_SCALE, stuck.r, stuck.g, stuck.b,
            math.floor(FOCUS_INK * arrived(1, visibleRows)))
        firstRow = 2
    end

    for i = firstRow, visibleRows do
        local index = i + panel.scroll
        local r = rows[index]
        if r ~= nil then
            local rowY = listTop + (i - 1) * m.rowHeight
            local selectable = panel.is_stop(r)

            if r.heading == true then
                local lift = 14
                dim_rect(x + 2, rowY, width - 4, m.rowHeight,
                    math.min(255, look.panel.r + lift),
                    math.min(255, look.panel.g + lift),
                    math.min(255, look.panel.b + lift), 255)
            end

            local reserved = (maxScroll > 0) and SCROLLBAR_STRIP or 0
            local hovered = selectable
                and mouseX >= x and mouseX <= x + width - reserved
                and mouseY >= rowY and mouseY <= rowY + m.rowHeight

            local altFrom, altZone = panel.alt_zone(r, x + SIDE_PADDING)
            local inAltZone = hovered and altFrom ~= nil
                and mouseX < altZone and mouseX >= altFrom

            local trackX, trackWidth = nil, nil
            if r.slider ~= nil and r.slider.steps > 0 and (r.slider.onChange ~= nil
                or (r.slider.mine ~= nil and r.slider.mine.onChange ~= nil)) then

                trackX, trackWidth = panel.slider_columns(x, width,
                    rowBand, maxScroll > 0)
            end

            local inTrack = hovered and trackX ~= nil and not inAltZone
                and mouseX >= trackX - 6 and mouseX <= trackX + trackWidth + 6

            if hovered and mouseMoved then panel.cursor = index end

            if selectable and index == panel.cursor then
                local litY, litHeight = glide_to(rowY, m.rowHeight, panel.page)
                if panel.skin_on() then
                    local hr, hg, hb = highlight()
                    OF.panelskin.selection(x, width, litY, litHeight, hr, hg, hb)
                end
                draw_selection(x, width, litY, litHeight)
                if panel.skin_on() then
                    OF.panelskin.glint(tostring(panel.page) .. "\31" .. tostring(index), x, width,
                        litY, litHeight)
                end

                if panel.confirm ~= nil then
                    local left = 1 - OF.util.clamp(
                        panel.confirm.timer / CONFIRM_FRAMES, 0, 1)
                    if left > 0 then
                        dim_rect(x + 2, litY + litHeight - 2,
                            (width - 4) * left, 2,
                            gold().r, gold().g, gold().b, 210)
                    end
                end
            end

            if inAltZone then
                dim_rect(altFrom - 1, rowY, altZone - altFrom + 2, m.rowHeight,
                    255, 255, 255, 40)

                if rightClicked and r.clearMine ~= nil then
                    rightClicked = false
                    OF.sounds.ui_press(r, true, OF.sounds.TICK)
                    panel.run(r.clearMine, true)
                    return
                end
            end

            if inTrack and clicked and panel.drag == nil then
                panel.sliderDrag = { index = index, x = trackX, w = trackWidth }

                local mine = r.slider.mine
                if mine ~= nil and mine.onChange ~= nil then
                    local function at(v)
                        return trackX + trackWidth * ((v or 0) / math.max(1, r.slider.steps))
                    end
                    local mineAt = mine.value ~= nil and at(mine.value) or nil
                    if r.slider.onChange == nil or (mineAt ~= nil
                        and math.abs(mouseX - mineAt) < math.abs(mouseX - at(r.slider.value))) then
                        panel.sliderDrag.mine = true
                    end
                end
            end
            if panel.sliderDrag ~= nil and panel.sliderDrag.index == index then
                if not OF.util.has_flag(
                    OF.util.optional("djui_hud_get_mouse_buttons_down", 0),
                    L_MOUSE_BUTTON) then
                    panel.sliderDrag = nil
                else
                    panel.cursor = index
                    local along = OF.util.clamp(
                        (mouseX - panel.sliderDrag.x)
                            / math.max(1, panel.sliderDrag.w), 0, 1)
                    local wanted = math.floor(along * r.slider.steps + 0.5)
                    local change, now = r.slider.onChange, r.slider.value
                    if panel.sliderDrag.mine and r.slider.mine ~= nil then
                        change, now = r.slider.mine.onChange, r.slider.mine.value
                        if now == nil then now = r.slider.value end
                    end
                    if change ~= nil and wanted ~= now then
                        OF.sounds.ui("slider_step", OF.sounds.MOVE)
                        panel.run(function() change(wanted) end)
                        return
                    end
                end
            end

            if hovered and middleClicked and OF.util.asks(OF.shortcuts, "toggle_pin") then
                OF.shortcuts.toggle_pin(panel.page, r)
                return
            end

            if hovered and r.grid ~= nil and (mouseMoved or clicked) then
                local cell = panel.grid_cell_at(r, x, width, reserved, mouseX)
                if cell ~= nil then panel.grid_select(r, cell) end
            end
            if hovered and clicked and not inTrack then

                local doing = inAltZone and r.altAction or r.action

                local sound = OF.sounds.MOVE
                if doing ~= nil then
                    sound = (panel.row_ticks(r) and not inAltZone)
                        and OF.sounds.TICK or OF.sounds.PICK
                end
                OF.sounds.ui_press(r, inAltZone, sound)
                panel.cursor = index

            if OF.util.asks(OF.shortcuts, "used") then OF.shortcuts.used(panel.page, r) end
            if inAltZone then
                panel.run(r.altAction, r.altMine == true)
            else
                panel.run(r.action)
            end
                return
            end

            if clicked and not selectable and (r.needs ~= nil or r.hostOnly)
                and mouseX >= x and mouseX <= x + width - reserved
                and mouseY >= rowY and mouseY <= rowY + m.rowHeight then
                local frame = OF.util.optional("get_global_timer", 0) or 0
                if frame ~= lastDeniedFrame then
                    lastDeniedFrame = frame
                    OF.sounds.ui("error", OF.sounds.DENIED)
                end
            end

            local ink = math.floor(
                ((index == panel.cursor) and 255 or FOCUS_INK)
                * arrived(i, visibleRows))

            local hasTrack = r.slider ~= nil and r.slider.steps > 0
            local drawTrackWidth, drawTrackX, levelEdge
            if hasTrack then

                if trackX ~= nil then
                    drawTrackX, drawTrackWidth = trackX, trackWidth
                    levelEdge = x + width - SIDE_PADDING
                else
                    drawTrackX, drawTrackWidth, levelEdge =
                        panel.slider_columns(x, width, rowBand,
                            maxScroll > 0)
                end
            end

            local faceName, faceLevel = panel.slider_face(r)

            if r.grid ~= nil then faceName, faceLevel = "", nil end
            local inkR, inkG, inkB = panel.ink_of(r)
            local skinned = panel.skin_on()

            local pulseLater = false
            if r.pulse then
                if skinned then
                    pulseLater = true
                else
                    inkR, inkG, inkB = panel.pulse_ink(inkR, inkG, inkB, get_global_timer())
                end
            end
            local level = ""
            if faceLevel ~= nil and faceLevel ~= "" then
                level = panel.level_shown(faceLevel, width, hasTrack, rowBand)
            end
            local levelX
            if level ~= "" then

                local levelScale = (r.smallRight and panel.skin_on()) and ROW_SCALE * 0.72 or ROW_SCALE
                levelX = (hasTrack and levelEdge or (x + width - SIDE_PADDING))
                    - OF.util.width(level, levelScale)

                if lab ~= nil then
                    levelX = (hasTrack and levelEdge or (x + width - SIDE_PADDING))
                        - OF.hud.measure(level, r.smallRight and "caption" or "rowSmall")
                end
            end

            local textRoom
            if hasTrack then
                textRoom = drawTrackX - SIDE_PADDING - (x + SIDE_PADDING)
            elseif levelX ~= nil then
                textRoom = levelX - SIDE_PADDING - (x + SIDE_PADDING)
            else
                textRoom = panel.text_room(nil, width, hasTrack)
            end

            textRoom = textRoom - panel.draw_right_picture(r,
                levelX or (x + width - SIDE_PADDING), rowY, m.rowHeight, m.rowText, ink)

            local levelR, levelG, levelB = inkR, inkG, inkB

            if skinned and r.localIndex ~= nil then levelR, levelG, levelB = 205, 210, 222 end

            if type(r.rightInk) == "table" then
                levelR, levelG, levelB = r.rightInk[1] or levelR,
                    r.rightInk[2] or levelG, r.rightInk[3] or levelB
            end
            if skinned then
                local midY = rowY + m.rowHeight * 0.5
                local skin = OF.panelskin
                local lit = selectable and index == panel.cursor
                local hr, hg, hb = highlight()
                if pulseLater then
                    if levelX ~= nil then
                        levelR, levelG, levelB = skin.pulse_pair(inkR, inkG, inkB, lit, hr, hg, hb)
                    else
                        inkR, inkG, inkB = skin.pulse_pair(inkR, inkG, inkB, lit, hr, hg, hb)
                    end
                end
                local key = panel.row_identity(r)
                local boxes = type(faceName) == "string"
                    and (string.match(faceName, "^((%[[^%]]*%]%s*)+)") or "") or ""
                if level ~= "" and levelX ~= nil then
                    skin.value_flash(key, level .. "|" .. boxes, levelX, rowY,
                        OF.util.width(level, ROW_SCALE), m.rowHeight, hr, hg, hb)
                elseif boxes ~= "" then
                    skin.value_flash(key, boxes, x + SIDE_PADDING, rowY,
                        OF.util.width(boxes, ROW_SCALE), m.rowHeight, hr, hg, hb)
                end
                if r.localIndex ~= nil then
                    skin.status_dot((levelX or (x + width - SIDE_PADDING)) - 10, midY, r.localIndex)
                    if r.rankColour ~= nil and lab == nil then
                        skin.rank_badge(faceName, x + SIDE_PADDING, rowY, m.rowHeight, ROW_SCALE, r.rankColour)
                    end
                end
                if skin.sounding(r) then
                    skin.equaliser((levelX or (x + width - SIDE_PADDING)) - 6, midY, hr, hg, hb)
                end

                if lab ~= nil and levelX == nil and not hasTrack and r.action ~= nil
                    and type(faceName) == "string" and string.find(faceName, "%.%.%.$") then
                    faceName = string.sub(faceName, 1, -4)
                    OF.hud.arrow_glyph("right", x + width - SIDE_PADDING
                        - ((maxScroll > 0) and SCROLLBAR_STRIP or 0) - 6, midY, 10,
                        lit and { hr, hg, hb } or "mute", 255 * fadeNow, "chevron")
                    textRoom = textRoom - 20
                end
                if lab ~= nil and r.action == nil and not selectable and levelX == nil and not hasTrack
                    and (r.needs ~= nil or r.hostOnly) then
                    textRoom = textRoom - OF.panelskin.locked(x + width - SIDE_PADDING
                        - ((maxScroll > 0) and SCROLLBAR_STRIP or 0), midY)
                end
                if r.danger == true and r.action ~= nil and levelX == nil and not hasTrack then
                    local left = nil
                    if r.confirming ~= nil and panel.confirm ~= nil then
                        left = 1 - OF.util.clamp(panel.confirm.timer / CONFIRM_FRAMES, 0, 1)
                    end
                    OF.panelskin.two_tick(x + width - SIDE_PADDING
                        - ((maxScroll > 0) and SCROLLBAR_STRIP or 0), midY, left,
                        selectable and index == panel.cursor)
                    textRoom = textRoom - OF.panelskin.TAG_ROOM
                end
            end
            local nameX = x + SIDE_PADDING

            if r.rankTag ~= nil and OF.util.asks(OF.hud, "plate") then
                local chipW = panel.rank_chip_width()
                if r.rankTag ~= "" then
                    local H = OF.hud
                    local cy = rowY + m.rowHeight * 0.5
                    local tone = r.rankColour or { 255, 255, 255 }

                    if panel.skin_on() then
                        H.plate(nameX, cy - 9, chipW, 18, { alpha = fadeNow, lit = true })
                        H.rect(nameX + 2, cy + 7, chipW - 4, 2, tone, 255 * fadeNow)
                    else

                        dim_rect(nameX, cy - 9, chipW, 18, 40, 44, 56, 205)
                        dim_rect(nameX + 2, cy + 7, chipW - 4, 2,
                            tone[1] or 255, tone[2] or 255, tone[3] or 255, 255)
                    end
                    H.menu_text_mid(r.rankTag, nameX + chipW / 2, cy - 1, "caption", tone, ink, "center")
                end
                nameX = nameX + chipW + 6
                textRoom = textRoom - chipW - 6
            end

            if lab ~= nil and type(faceName) == "string" then
                local states, rest = OF.panelskin.split_boxes(faceName)
                if #states > 0 then
                    OF.panelskin.boxes(faceName, nameX, rowY, m.rowHeight, states,
                        not selectable and (r.needs ~= nil or r.hostOnly),
                        r.altBox == 2 and r.slider ~= nil and r.slider.mine ~= nil)
                end

                if lab.boxes > 0 and not r.heading then
                    faceName = rest
                    nameX = nameX + lab.boxes * lab.boxCell
                    textRoom = textRoom - lab.boxes * lab.boxCell
                end
                if r.localIndex ~= nil and r.rankColour ~= nil then
                    OF.panelskin.rank_badge(faceName, nameX, rowY, m.rowHeight, ROW_SCALE, r.rankColour)
                end
            end
            local swatchWidth = panel.swatch_width(r, m.rowText)
            if swatchWidth > 0 then
                local info = panel.texture_info(r.texture)

                if skinned and r.iconShape ~= nil
                    and OF.util.asks(OF.forge, "draw_shape_picture") then
                    OF.forge.draw_shape_picture(r.iconShape, nameX,
                        rowY + (m.rowHeight - m.rowText) * 0.5, m.rowText, info, ink, r.iconFlip == true)
                else
                djui_hud_set_color(255, 255, 255, ink)
                djui_hud_render_texture(info, nameX,
                    rowY + (m.rowHeight - m.rowText) * 0.5,
                    m.rowText / info.width, m.rowText / info.height)
                end
                nameX = nameX + swatchWidth
                textRoom = textRoom - swatchWidth
            end

            local shownName, nameShift = nil, 0
            if ((selectable and index == panel.cursor) or skinned) and type(faceName) == "string"
                and OF.util.width(faceName, ROW_SCALE) > textRoom then
                local boxes = string.match(faceName, "^((%[[^%]]*%]%s*)+)") or ""
                local boxWidth = OF.util.width(boxes, ROW_SCALE)
                local rest = string.sub(faceName, #boxes + 1)
                local moving, shift = panel.marquee(rest, ROW_SCALE, textRoom - boxWidth,
                    panel.marquee_frame((selectable and index == panel.cursor) and "row"
                        or ("row" .. tostring(index)), faceName))
                if boxes ~= "" then
                    OF.util.text(boxes, nameX, rowY + (m.rowHeight - m.rowText) * 0.5,
                        ROW_SCALE, inkR, inkG, inkB, ink)
                end
                shownName, nameShift = moving, boxWidth + shift
            else
                shownName = panel.fit_to(faceName, ROW_SCALE, textRoom)
            end
            if skinned and r.match ~= nil and shownName == faceName then
                local hr, hg, hb = highlight()
                OF.panelskin.mark_match(faceName, r.match, nameX, rowY, m.rowHeight, ROW_SCALE, hr, hg, hb)
            end

            if lab ~= nil and r.action == nil and r.altAction == nil and not r.heading and not hasTrack
                and not r.logLine
                and levelX == nil and r.needs == nil and not r.hostOnly and r.localIndex == nil then
                OF.panelskin.caption_row(faceName, x + SIDE_PADDING, rowY + m.rowHeight * 0.5,
                    x + width - SIDE_PADDING - (x + SIDE_PADDING), ink, index)
            elseif r.nameRaw ~= nil
                and panel.draw_named(shownName, r.nameRaw, nameX + nameShift,
                    rowY + (m.rowHeight - m.rowText) * 0.5, inkR, inkG, inkB, ink) then

            else
            OF.util.text(shownName,
                nameX + nameShift, rowY + (m.rowHeight - m.rowText) * 0.5,
                ROW_SCALE, inkR, inkG, inkB, ink)
            end

            if hasTrack then
                local trackY = rowY + m.rowHeight * 0.5 - 1
                local lit = selectable and index == panel.cursor

                dim_rect(drawTrackX, trackY, drawTrackWidth, 2,
                    255, 255, 255, lit and 70 or 40)

                local filled = math.floor(
                    drawTrackWidth * (r.slider.value / r.slider.steps))
                if filled > 0 then
                    dim_rect(drawTrackX, trackY, filled, 2,
                        inkR, inkG, inkB, lit and 255 or 150)
                end

                local handleX = drawTrackX + filled - 3

                local hr, hg, hb = inkR, inkG, inkB
                if r.slider.mine ~= nil and panel.skin_on()
                    and OF.util.asks(OF.panelskin, "accent_now") then
                    local acc = OF.panelskin.accent_now()
                    if type(acc) == "table" then hr, hg, hb = acc[1], acc[2], acc[3] end
                end
                dim_rect(handleX, rowY + m.rowHeight * 0.5 - 5, 6, 10,
                    hr, hg, hb, lit and 255 or 170)

                local mine = r.slider.mine
                if mine ~= nil and mine.value ~= nil then
                    local mr, mg, mb = panel.mine_ink()
                    local mx = drawTrackX + math.floor(drawTrackWidth
                        * (mine.value / r.slider.steps)) - 4
                    local my = rowY + m.rowHeight * 0.5 - 4
                    if mine.value == r.slider.value then my = my + 7 end
                    dim_rect(mx - 1, my - 1, 10, 10, 0, 0, 0, lit and 200 or 130)
                    dim_rect(mx, my, 8, 8, mr, mg, mb, lit and 255 or 190)
                end
            end

            local youPart = type(r.rightMine) == "string" and type(level) == "string"
                and string.sub(level, -#r.rightMine) == r.rightMine and r.rightMine or nil
            local youPrefix = youPart ~= nil and string.sub(level, 1, #level - #youPart) or nil
            if levelX ~= nil and lab ~= nil then
                OF.hud.menu_text_mid(level, levelX, rowY + m.rowHeight * 0.5,
                    r.smallRight and "caption" or "rowSmall",
                    r.smallRight and "mute" or { levelR, levelG, levelB }, ink, "left")
                if youPart ~= nil and not r.smallRight then
                    local yr, yg, yb = panel.mine_ink()
                    OF.hud.menu_text_mid(youPart,
                        levelX + (OF.hud.measure(youPrefix, "rowSmall") or 0),
                        rowY + m.rowHeight * 0.5, "rowSmall", { yr, yg, yb }, ink, "left")
                end
            elseif levelX ~= nil and skinned and r.smallRight then
                local small = ROW_SCALE * 0.72
                local smallH = OF.util.line_height(small)
                OF.util.text(level, levelX, rowY + (m.rowHeight - smallH) * 0.5, small, 165, 170, 185, ink)
            elseif levelX ~= nil then
                OF.util.text(level, levelX,
                    rowY + (m.rowHeight - m.rowText) * 0.5,
                    ROW_SCALE, levelR, levelG, levelB, ink)
                if youPart ~= nil then
                    local yr, yg, yb = panel.mine_ink()
                    OF.util.text(youPart, levelX + OF.util.width(youPrefix, ROW_SCALE),
                        rowY + (m.rowHeight - m.rowText) * 0.5, ROW_SCALE, yr, yg, yb, ink)
                end
            end
            if r.grid ~= nil then
                panel.draw_grid(r, x, rowY, width, m.rowHeight, m.rowText, ink,
                    selectable and index == panel.cursor, reserved)
            end
        end
    end

    local listBottom = listTop + visibleRows * m.rowHeight
    if panel.skin_on() then
        OF.panelskin.page_veil(panel.page, #(panel.trail_keys(panel.page) or {}), x, listTop, width,
            visibleRows * m.rowHeight)
    end
    edge_shade(x, width, listTop, 1, panel.scroll > 0 and 76 or 30)
    if panel.scroll < maxScroll then
        edge_shade(x, width, listBottom - 1, -1, 66)
    end

    if maxScroll > 0 then
        dim_rect(barX, trackTop, 2, trackHeight, 255, 255, 255, 28)

        local starts = panel.section_starts(rows)
        if #starts > 2 then
            for _, at in ipairs(starts) do
                local tickY = trackTop
                    + math.floor(trackHeight * ((at - 1) / #rows))
                dim_rect(barX - 2, tickY, 6, 1, 255, 255, 255, 80)
            end
        end

        local span = visibleRows / (#rows)
        local thumbHeight = math.max(18, math.floor(trackHeight * span))
        local room = trackHeight - thumbHeight
        local thumbY = trackTop + math.floor(room * (panel.scroll / maxScroll))

        if not held then
            panel.scrollDrag = nil
        elseif panel.scrollDrag == nil and clicked and overBar then
            local onThumb = mouseY >= thumbY and mouseY <= thumbY + thumbHeight
            panel.scrollDrag = { dy = onThumb and (mouseY - thumbY)
                                      or thumbHeight * 0.5 }
        end

        if panel.scrollDrag ~= nil and room > 0 then
            local wanted = (mouseY - panel.scrollDrag.dy - trackTop) / room
            panel.scroll = math.floor(
                OF.util.clamp(wanted * maxScroll + 0.5, 0, maxScroll))
            thumbY = trackTop + math.floor(room * (panel.scroll / maxScroll))
        end

        local bright = (panel.scrollDrag ~= nil or overBar) and 255 or 190
        if panel.skin_on() then
            local hr, hg, hb = highlight()
            OF.panelskin.thumb(barX, thumbY, thumbHeight, hr, hg, hb, bright)
        end
        dim_rect(barX, thumbY, 2, thumbHeight,
            gold().r, gold().g, gold().b, bright)
    end

    if lab then
        djui_hud_set_font(FONT_NORMAL)

        local under = rows and rows[panel.cursor] or nil
        local labHints = panel.hints(under)
        local lit = 0
        for _, hint in ipairs(labHints) do
            if not hint.nav then lit = lit + 1 end
        end
        OF.panelskin.footer(lab, labHints, lit, FOOTER_SCALE)

        local _, level = panel.slider_face(under or {})
        if under ~= nil and under.smallRight then level = nil end
        OF.panelskin.detail(lab, under, level, OF.util.optional("get_global_timer", 0) or 0)
    else
        local footerTop = y + height - m.footerHeight

        dim_rect(x, footerTop - 1, width, 1, 0, 0, 0, 70)
        dim_rect(x, footerTop, width, 1, 255, 255, 255, 30)

        local PLATE_PADDING = 4
        local GAP = panel.FOOTER_GAP
        local room = width - SIDE_PADDING * 2
        local chips = panel.skin_on()
        local under = rows and rows[panel.cursor]

        local help = under ~= nil and under.help ~= nil
            and OF.util.say_buttons(OF.lang.t(under.help), true) or nil
        local hints, contextual, legend_width = panel.footer_hints(under, room, chips)

        local hintX = x + SIDE_PADDING
        local hintY = footerTop + FOOTER_PADDING

        if help ~= nil and help ~= "" then
            local spare = room - legend_width() - GAP * 2
            if spare > 60 then

                local said = OF.lang.t(help)
                if OF.util.width(said, FOOTER_SCALE) > spare then
                    local shown, dx = panel.marquee(said, FOOTER_SCALE, spare,
                        panel.marquee_frame("footer", said))
                    OF.util.text(shown, x + width - SIDE_PADDING - spare + dx,
                        hintY, FOOTER_SCALE, 165, 165, 175, 255)
                else
                    OF.util.text(said,
                        x + width - SIDE_PADDING - OF.util.width(said, FOOTER_SCALE),
                        hintY, FOOTER_SCALE, 165, 165, 175, 255)
                end
            end
        end
        for index, hint in ipairs(hints) do
            local lit = index <= contextual
            local keyWidth = OF.util.width(hint.key, FOOTER_SCALE)
            local plateWidth = keyWidth + PLATE_PADDING * 2
            if chips then
                plateWidth = OF.panelskin.key(hint.key, hintX, hintY, m.footerText, FOOTER_SCALE)
            else
            dim_rect(hintX, hintY - 1, plateWidth, m.footerText + 2,
                look.frame.r, look.frame.g, look.frame.b, lit and 220 or 120)
            dim_rect(hintX, hintY - 1, plateWidth, 1, 255, 255, 255, lit and 60 or 25)

            dim_rect(hintX, hintY + m.footerText, plateWidth, 1,
                0, 0, 0, lit and 80 or 45)
            OF.util.text(hint.key, hintX + PLATE_PADDING, hintY, FOOTER_SCALE,
                lit and gold().r or 190, lit and gold().g or 190,
                lit and gold().b or 190, 255)
            end

            hintX = hintX + plateWidth + 4
            local label = OF.lang.t(hint.label)
            OF.util.text(label, hintX, hintY, FOOTER_SCALE,
                lit and 220 or 140, lit and 220 or 140, lit and 220 or 140, 255)
            hintX = hintX + OF.util.width(label, FOOTER_SCALE) + GAP
        end

    end

    local rim = lab == nil and (panel.resizing ~= nil and panel.resizing.edge
        or panel.resize_edge(mouseX, mouseY, x, y, width, height))
    if rim then
        local g = gold()
        if rim.left then OF.util.rect(x - 1, y, 2, height, g.r, g.g, g.b, 200) end
        if rim.right then OF.util.rect(x + width - 1, y, 2, height, g.r, g.g, g.b, 200) end
        if rim.bottom then OF.util.rect(x, y + height - 1, width, 2, g.r, g.g, g.b, 200) end
    end

    if gridUp then OF.mapgrid.render(mouseX, mouseY, gridClick, gridRight, mouseMoved) end

    OF.util.rect(mouseX + 1, mouseY + 1, 9, 2, 0, 0, 0, 150)
    OF.util.rect(mouseX + 1, mouseY + 1, 2, 9, 0, 0, 0, 150)
    OF.util.rect(mouseX, mouseY, 9, 2, gold().r, gold().g, gold().b, 255)
    OF.util.rect(mouseX, mouseY, 2, 9, gold().r, gold().g, gold().b, 255)

    if rightClicked then
        OF.sounds.ui("back", OF.sounds.BACK)
        panel.back()
    end
end

local function on_update()

    panel.enrol_forgetting()

    if panel.confirm ~= nil then
        panel.confirm.timer = panel.confirm.timer + 1
        if panel.confirm.timer > CONFIRM_FRAMES then
            panel.confirm = nil
            panel.mark_dirty()
        end
    end

    if not panel.open then return end

    sinceRefresh = sinceRefresh + 1
    if panel.dirty or panel.rows == nil or sinceRefresh >= REFRESH_FRAMES then
        panel.rebuild()
    end
end

panel.stickRows = 0
panel.STICK_SCROLL_SLOW = 0.15
panel.STICK_SCROLL_FAST = 0.85
function panel.stick_scroll(m)
    if m == nil or m.controller == nil then return 0 end
    local y = tonumber(m.controller.extStickY) or 0
    local dead = OF.input.DEVICE_DEAD
    local moved = 0
    if math.abs(y) <= dead or OF.input.mouse_busy() then
        panel.stickRows = 0
    else
        local push = OF.util.clamp((math.abs(y) - dead) / (80 - dead), 0, 1)
        local rate = panel.STICK_SCROLL_SLOW
            + (panel.STICK_SCROLL_FAST - panel.STICK_SCROLL_SLOW) * push * push

        panel.stickRows = panel.stickRows + (y > 0 and -rate or rate)
        local whole = panel.stickRows >= 0 and math.floor(panel.stickRows)
            or -math.floor(-panel.stickRows)
        if whole ~= 0 then
            panel.stickRows = panel.stickRows - whole
            local most = math.max(0, #(panel.rows or {}) - (panel.visibleRows or 0))
            local before = panel.scroll
            panel.scroll = math.floor(OF.util.clamp(panel.scroll + whole, 0, most))
            moved = panel.scroll - before
        end
    end
    OF.input.claim_camera(m)
    return moved
end

local handle_controller
do

    local zChorded = false

    local zRow = nil

local padMousing, padInput = false, nil

local function padPressed(button)
    if padMousing then return false end
    local input = padInput
    return input.pressed(button)
end

local function padRepeated(button)
    if padMousing then return false end
    local input = padInput
    return input.repeated(button)
end

function handle_controller(m)
    OF.input.poll(m)
    local input = OF.input

    if not panel.open then

        local opener = OF.input.opener()
        if input.pressed(opener) then
            panel.show()
            OF.input.take(m, opener)
        end
        return
    end

    local mousing = OF.input.mouse_busy()
    padMousing, padInput = mousing, input

    if OF.util.asks(OF.mapgrid, "input") and OF.mapgrid.input(m, input, padPressed, padRepeated) then
        OF.input.claim(m, OF.input.PANEL_BUTTONS, OF.input.panel_stop())
        OF.input.claim_camera(m)
        return
    end

    if padPressed(Z_TRIG) then
        zChorded = false
        zRow = panel.cursor
    end

    local step = 0
    if padRepeated(D_JPAD) then step = 1 end
    if padRepeated(U_JPAD) then step = -1 end

    local arrows = OF.input.arrows_are_keys(m)
    if arrows then
        if step == 0 and padRepeated(D_CBUTTONS) then
            step = 1
            OF.input.take(m, D_CBUTTONS)
        end
        if step == 0 and padRepeated(U_CBUTTONS) then
            step = -1
            OF.input.take(m, U_CBUTTONS)
        end
    end

    local stickStep = input.stick_step(m)

    local stickSlide, sideways = panel.stick_slide(m)
    if sideways then stickStep = 0 end
    if step == 0 and not mousing then step = stickStep end
    if step ~= 0 then
        panel.move_cursor(step)
        OF.sounds.ui("move", OF.sounds.MOVE)
    end

    panel.stick_scroll(m)

    local zHeld = not mousing and input.held(Z_TRIG)

    panel.zHeldNow = zHeld
    local jump = 0
    if padPressed(R_TRIG) then
        if zHeld then jump = 1 else panel.next_tab(1) end
    end
    if padPressed(L_TRIG) then
        if zHeld then jump = -1 else panel.next_tab(-1) end
    end
    if jump ~= 0 then

        zChorded = true
        if panel.jump_section(jump) then OF.sounds.ui("move", OF.sounds.MOVE) end
    end

    local slide = 0
    if padRepeated(R_JPAD) then slide = 1 end
    if padRepeated(L_JPAD) then slide = -1 end
    if slide == 0 and not mousing then slide = stickSlide end
    if arrows then
        if slide == 0 and padRepeated(R_CBUTTONS) then
            slide = 1
            OF.input.take(m, R_CBUTTONS)
        end
        if slide == 0 and padRepeated(L_CBUTTONS) then
            slide = -1
            OF.input.take(m, L_CBUTTONS)
        end
    end
    if slide ~= 0 then
        panel.nudge(slide)

        if zHeld then zChorded = true end
    end

    local current = panel.rows and panel.rows[panel.cursor]

    if zHeld and not zChorded and zRow == panel.cursor then
        panel.zHoldFrames = (panel.zHoldFrames or 0) + 1
        if panel.zHoldFrames == panel.HOLD_Z_FRAMES and current ~= nil
            and current.clearMine ~= nil then
            zChorded = true
            OF.sounds.ui_press(current, true, OF.sounds.TICK)
            panel.run(current.clearMine, true)
            current = panel.rows and panel.rows[panel.cursor]
        end
    else
        panel.zHoldFrames = 0
    end

    if not mousing and input.released(Z_TRIG) then

        local doing = current ~= nil and current.altAction or nil
        if not zChorded and doing ~= nil and zRow == panel.cursor then

            local ticked = not current.altPad and panel.has_box(current)
            OF.sounds.ui_press(current, true, ticked and OF.sounds.TICK or OF.sounds.PICK)

            if OF.util.asks(OF.shortcuts, "used") then OF.shortcuts.used(panel.page, current) end
            panel.run(doing, current.altMine == true)
            current = panel.rows and panel.rows[panel.cursor]
        end
        zChorded = false
        zRow = nil
    end

    if zHeld and (padPressed(A_BUTTON) or padPressed(B_BUTTON)
        or padPressed(START_BUTTON)) then
        zChorded = true
    end

    if padPressed(A_BUTTON) and current ~= nil then

        local sound = OF.sounds.MOVE
        if current.action ~= nil then

            sound = panel.row_ticks(current) and OF.sounds.TICK
                or OF.sounds.PICK
        end
        OF.sounds.ui_press(current, false, sound)
        if OF.util.asks(OF.shortcuts, "used") then OF.shortcuts.used(panel.page, current) end
        panel.run(current.action)
    elseif padPressed(B_BUTTON) then
        OF.sounds.ui("back", OF.sounds.BACK)
        panel.back()
    elseif padPressed(START_BUTTON) then
        panel.close()
    elseif Y_BUTTON ~= nil and padPressed(Y_BUTTON) and current ~= nil
        and OF.util.asks(OF.shortcuts, "toggle_pin") then

        OF.shortcuts.toggle_pin(panel.page, current)
    end

    OF.input.claim(m, OF.input.PANEL_BUTTONS, OF.input.panel_stop())
end
end

local controllerFailure = nil

local saidOnce = { toldPad = false, toldDraw = false }

local updateTick = 0
local marioTick = 0

local function drive_controls(m)
    if m == nil or m.playerIndex ~= 0 then return end

    local ok, err = pcall(handle_controller, m)
    if ok then return end

    controllerFailure = panel.short_reason(err)
    if not saidOnce.toldPad then
        saidOnce.toldPad = true
        OF.util.chat(OF.lang.t("The mod menu's controls hit an error:")
            .. " " .. controllerFailure, "warn")
        OF.notify.show("The mod menu's controls hit an error - it is in chat", "bad", 8)
    end
end

local function on_before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end

    marioTick = updateTick
    drive_controls(m)
end

function panel.controller_failure()
    return controllerFailure
end

local renderFailure = nil

function panel.short_reason(err)
    local text = tostring(err)

    local at = string.find(text, "[^/\\]+%.lua:%d+:")
    if at ~= nil then return string.sub(text, at) end

    local path, rest = string.match(text, '^%[string "(.-)"%](.*)$')
    if path == nil then return text end
    return (string.match(path, "([^/\\]+)$") or path) .. rest
end

function panel.wrap(text, scale, width, maxLines)
    local lines = {}
    local rest = text
    while rest ~= "" and #lines < maxLines do
        local fitted = OF.util.fit(rest, scale, width)

        local kept = fitted
        local cut = string.match(fitted, "^(.*)%.%.%.$")
        if cut ~= nil then kept = cut end
        if kept == "" then break end

        if #kept < #rest then
            local space = nil
            for at = #kept, math.floor(#kept * 0.5), -1 do
                if string.sub(kept, at, at) == " " then space = at break end
            end
            if space ~= nil then kept = string.sub(kept, 1, space) end
        end
        table.insert(lines, #lines + 1 < maxLines and kept or fitted)
        rest = string.sub(rest, #kept + 1)
    end
    if #lines == 0 then return { text } end
    return lines
end

function panel.break_for_test(drawing, controls)
    renderFailure = drawing
    controllerFailure = controls
end

function panel.render_failure()
    return renderFailure
end

function panel.forget_failure()
    renderFailure = nil
    controllerFailure = nil
    saidOnce.toldDraw = false
    saidOnce.toldPad = false
end

local function render_plainly()
    local rows = panel.rows
    if type(rows) ~= "table" then return false end

    local screenWidth = djui_hud_get_screen_width()
    local width = math.min(520, screenWidth - 40)
    local x = (screenWidth - width) * 0.5
    local y = 40
    local lineHeight = 16
    local shown = math.min(#rows, 18)

    djui_hud_set_color(0, 0, 0, 235)
    djui_hud_render_rect(x - 10, y - 10, width + 20, 46 + shown * lineHeight)

    djui_hud_set_color(255, 220, 80, 255)
    djui_hud_print_text("oldfart's Lobby v" .. tostring(OF.VERSION)
        .. " - plain mode (the styled menu could not draw)", x, y, 0.55)
    y = y + 20

    local first = 1
    local cursor = panel.cursor or 1
    if cursor > shown then first = cursor - shown + 1 end

    for offset = 0, shown - 1 do
        local index = first + offset
        local row = rows[index]
        if row == nil then break end
        local text = tostring(row.text or "")
        if row.right ~= nil and row.right ~= "" then
            text = text .. "   -   " .. tostring(row.right)
        end
        if index == cursor then
            djui_hud_set_color(255, 255, 255, 255)
            text = "> " .. text
        elseif row.action ~= nil then
            djui_hud_set_color(200, 200, 200, 255)
            text = "  " .. text
        else
            djui_hud_set_color(140, 140, 140, 255)
            text = "  " .. text
        end
        djui_hud_print_text(text, x, y + offset * lineHeight, 0.5)
    end

    djui_hud_set_color(150, 150, 150, 255)
    djui_hud_print_text("A press   B back   /ofdiag for why this happened",
        x, y + shown * lineHeight + 4, 0.5)
    return true
end

local render_badge
do
    local BADGE_SECONDS = 4
    local badgeSeenAt = nil
    local badgeAt = { x = 0, y = 0, w = 0, h = 0 }

    local function badge_wanted(mouseX, mouseY)
        if lastBadgeX == nil then
            lastBadgeX, lastBadgeY = mouseX, mouseY
            return false
        end
        local moved = math.abs(mouseX - lastBadgeX) >= 1
            or math.abs(mouseY - lastBadgeY) >= 1
        lastBadgeX, lastBadgeY = mouseX, mouseY
        local now = OF.util.optional("get_global_timer", 0)
        if moved then badgeSeenAt = now end
        if badgeSeenAt == nil then return false end
        return (now - badgeSeenAt) < BADGE_SECONDS * 30
    end

function render_badge()
        if panel.open then return end
        if OF.jail ~= nil and OF.jail.active then return end

        if type(OF.util) ~= "table" or OF.util.optional == nil then return end

        local mouseX = OF.util.optional("djui_hud_get_mouse_x", nil)
        local mouseY = OF.util.optional("djui_hud_get_mouse_y", nil)
        if mouseX == nil or mouseY == nil then return end
        if not badge_wanted(mouseX, mouseY) then return end

        local label = OF.lang.t("Menu")
        local textWidth, textHeight = OF.util.text_size(label, 0.9)
        local w, h = textWidth + 18, textHeight + 10
        local x = djui_hud_get_screen_width() - w - 12
        local y = 12
        badgeAt = { x = x, y = y, w = w, h = h }

        local over = mouseX >= x and mouseX <= x + w
            and mouseY >= y and mouseY <= y + h
        OF.util.plate(x, y, w, h)
        local gold = OF.util.gold()
        OF.util.text(label, x + 9, y + 5, 0.9,
            over and gold.r or 220, over and gold.g or 220,
            over and gold.b or 220, 255)

        local pressed = OF.util.has_flag(
            OF.util.optional("djui_hud_get_mouse_buttons_pressed", 0), L_MOUSE_BUTTON)
        if over and pressed then panel.show() end
    end

end

local function guarded_render()

    pcall(render_badge)

    if not panel.open then return end

    if panel.skin_on() and OF.util.asks(OF.panelskin, "layout") then
        ROW_SCALE, ROW_GAP = OF.panelskin.ROW_SCALE, OF.panelskin.ROW_GAP
    end
    local ok, err = pcall(render_panel)
    ROW_SCALE, ROW_GAP = panel.ROW_SCALE, panel.ROW_GAP
    if ok then return end

    local drewPlain = false
    local plainOk = pcall(function() drewPlain = render_plainly() end)
    if plainOk and drewPlain then
        if not saidOnce.toldDraw then
            saidOnce.toldDraw = true

            local told = pcall(function()
                renderFailure = panel.short_reason(err)
                OF.util.chat(OF.lang.fill("oldfart's Lobby v@ - @",
                    tostring(OF.VERSION), OF.lang.t("The mod menu could not draw:"))
                    .. " " .. renderFailure, "warn")
                OF.util.chat(tostring(err), nil, { more = true })
                OF.util.chat(
                    OF.lang.t("Type /ofdiag for the full picture, and say what it shows."), nil, { more = true })
                OF.notify.show("The menu is in plain mode - the reason is in chat", "bad", 6)
            end)
            if not told then

                pcall(djui_chat_message_create,
                    "oldfart" .. "'s Lobby v" .. tostring(OF.VERSION)
                    .. " - the menu is in plain mode: " .. tostring(err))
                pcall(djui_chat_message_create,
                    "  Type /ofdiag and say what it shows.")
            end
        end
        return
    end

    renderFailure = panel.short_reason(err)
    if not saidOnce.toldDraw then
        saidOnce.toldDraw = true

        OF.util.chat(OF.lang.fill("oldfart's Lobby v@ - @",
            tostring(OF.VERSION), OF.lang.t("The mod menu could not draw:"))
            .. " " .. renderFailure, "warn")
        OF.util.chat(tostring(err), nil, { more = true })
        OF.util.chat(
            OF.lang.t("Type /ofdiag for the full picture, and say what it shows."), nil, { more = true })
        OF.notify.show("The mod menu hit an error - it is in chat", "bad", 6)
    end

    local width = math.min(560, djui_hud_get_screen_width() - 40)
    local x = (djui_hud_get_screen_width() - width) * 0.5
    local y = djui_hud_get_screen_height() * 0.35
    local lines = panel.wrap(renderFailure, 0.7, width, 3)
    OF.util.rect(x - 8, y - 8, width + 16, 56 + #lines * 18, 0, 0, 0, 230)
    OF.util.text(OF.lang.t("oldfart's Lobby - the mod menu could not draw"), x, y, 0.9,
        255, 100, 100, 255)
    for i, line in ipairs(lines) do
        OF.util.text(line, x, y + 8 + i * 18, 0.7, 220, 220, 220, 255)
    end

    local missing = OF.missing_parts and OF.missing_parts() or {}
    local tail = "B or right-click closes this. Say this line in the lobby."
    if #missing > 0 then
        tail = "Did not load: " .. OF.util.fit(table.concat(missing, ", "), 0.7, width)
    end
    OF.util.text(tail, x, y + 22 + #lines * 18, 0.7, 170, 170, 170, 255)
end

local function catch_up_controls()
    updateTick = updateTick + 1
    if updateTick - marioTick < 2 then return end
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m == nil or m.controller == nil then return end

    drive_controls(m)
end

hook_event(HOOK_ON_HUD_RENDER, function()
    local ok, err = pcall(guarded_render)
    if OF.util ~= nil and type(OF.util.paint_above_menu) == "function" then
        pcall(OF.util.paint_above_menu)
    end
    if not ok then error(err, 0) end
end)
hook_event(HOOK_UPDATE, on_update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update)

hook_event(HOOK_UPDATE, catch_up_controls)

hook_chat_command("mm", "- open the oldfart mod menu", function()
    panel.toggle()
    return true
end)

hook_chat_command("modmenu", "- open the oldfart mod menu", function()
    panel.toggle()
    return true
end)

local PLACE_NAMES = {
    across = "x", x = "x", down = "y", y = "y",
    width = "w", w = "w", height = "h", h = "h",
}

hook_chat_command("menu",

    "[reset|across|down|width|height] [percent] - the menu's size and place",
    function(msg)
        msg = string.lower(msg or "")

        if msg == "" then
            OF.util.chat(OF.lang.fill("The menu sits at @", panel.place.x .. OF.lang.t("% across, ")
                .. panel.place.y .. "% down, " .. panel.place.w .. "% wide, "
                .. panel.place.h .. "% tall"))
            return true
        end

        if msg == "reset" then
            panel.reset_place()
            OF.util.chat(OF.lang.t("The menu is back in the middle."))
            return true
        end

        local word, rest = string.match(msg, "^(%S+)%s*(.*)$")
        local which = PLACE_NAMES[word or ""]
        if which == nil then
            OF.util.chat(OF.lang.t(
                "Try: /menu reset, or /menu across 30."), "warn")
            return true
        end

        local percent = tonumber(rest)
        if percent == nil then
            OF.util.chat(OF.lang.t(
                "Give it a percentage, as in /menu across 30."), "warn")
            return true
        end

        OF.util.report(panel.set_place(which, percent))
        OF.util.chat(OF.lang.fill("The menu sits at @", panel.place.x .. OF.lang.t("% across, ")
            .. panel.place.y .. "% down, " .. panel.place.w .. "% wide, "
            .. panel.place.h .. "% tall"))
        return true
    end)

hook_chat_command("say", "- announce a message to the whole lobby", function(msg)
    if not OF.util.allowed("message") then return true end
    if msg == nil or msg == "" then return false end
    OF.net.announce(msg)
    return true
end)

hook_chat_command("tell", "- - show one player a big on-screen message", function(msg)
    if not OF.util.allowed("message") then return true end
    if msg == nil or msg == "" then return false end

    local name, text = string.match(msg, "^(%S+)%s+(.+)$")
    if name == nil then
        OF.util.chat(OF.lang.t("Usage: /tell [name] [text]"))
        return true
    end

    local target = OF.util.named_player(name)
    if target == nil then return true end

    OF.net.announce_to({ network_global_index_from_local(target) }, text)
    OF.util.chat(OF.lang.fill("Message shown to @.", OF.util.plain(gNetworkPlayers[target].name)))
    return true
end)

local function travel_stands_down()
    if not (OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down()) then
        return false
    end
    OF.util.chat(OF.lang.t("a round or a run owns where everybody is standing"), "warn")
    return true
end

hook_chat_command("go", "<place> - send the lobby somewhere, or 'me <place>' for just you",
    function(msg)
        if travel_stands_down() then return true end
        msg = msg or ""
        local alone = false
        local wanted = string.match(msg, "^%s*me%s+(.+)$")
        if wanted ~= nil then
            alone = true
        else
            wanted = string.match(msg, "^%s*(.-)%s*$")
        end

        if wanted == nil or wanted == "" then
            OF.util.chat(OF.lang.t("Usage: /go [me] <place>, for example /go Rainbow"))
            return true
        end

        if not OF.util.allowed(alone and "teleport_self" or "warp_lobby") then
            return true
        end

        local entry = OF.util.find_destination(wanted)
        if entry == nil then
            OF.util.chat(OF.lang.fill("Nowhere called '@'.", wanted), "warn")
            return true
        end

        if entry.point ~= nil then
            if alone then
                OF.net.teleport_to_position(entry.point)
            else
                local ok, why = OF.net.send_everyone_to_position(entry.point)
                OF.net.report_move(ok, why,
                    OF.lang.fill("Sent everybody to @",
                        OF.util.accent() .. entry.name))
            end
            return true
        end

        local act = OF.util.destination_act(entry)

        if alone then
            OF.net.warp_local(entry.level, entry.area, act)
            return true
        end

        if OF.util.report(OF.net.warp_everyone(entry.level, entry.area, act)) then
            OF.util.chat(OF.lang.fill("Loading @ for everybody.", entry.name))
        end
        return true
    end)

do
panel.TP_OTHERS_TIER = OF.TIER ~= nil and OF.TIER.MOD or nil

function panel.tp_tokens(msg)
    local out, cur, depth = {}, "", 0
    for ch in string.gmatch(msg or "", ".") do
        if ch == "[" then depth = depth + 1 end
        if ch == "]" and depth > 0 then depth = depth - 1 end
        if depth == 0 and string.match(ch, "%s") then
            if cur ~= "" then table.insert(out, cur) end
            cur = ""
        else
            cur = cur .. ch
        end
    end
    if cur ~= "" then table.insert(out, cur) end
    return out
end

function panel.tp_coord(token)
    if token == nil then return nil end
    local lead = string.sub(token, 1, 1)
    if lead == "~" or lead == "^" then
        local rest = string.sub(token, 2)
        local n = rest == "" and 0 or tonumber(rest)
        if n == nil then return nil end
        return lead == "~" and "rel" or "local", n
    end
    local n = tonumber(token)
    if n == nil then return nil end
    return "abs", n
end

local tp = {}
tp.MIX = "Cannot mix world & local coordinates (everything must either use ^ or not)"
tp.ONE = "Only one entity is allowed, but the provided selector allows more than one"
tp.BAD = "Incorrect argument for command"
function panel.tp_location(a, b, c)
    local ka, va = panel.tp_coord(a)
    local kb, vb = panel.tp_coord(b)
    local kc, vc = panel.tp_coord(c)
    if ka == nil or kb == nil or kc == nil then return nil, tp.BAD end
    local locals = (ka == "local" and 1 or 0) + (kb == "local" and 1 or 0)
        + (kc == "local" and 1 or 0)
    if locals ~= 0 and locals ~= 3 then return nil, tp.MIX end
    local m = gMarioStates[0]
    if m == nil then return nil, tp.BAD end
    if locals == 3 then

        local yaw = (m.faceAngle.y or 0) * math.pi * 2 / 65536
        local fx, fz = math.sin(yaw), math.cos(yaw)
        local lx, lz = fz, -fx
        return { x = m.pos.x + lx * va + fx * vc, y = m.pos.y + vb,
                 z = m.pos.z + lz * va + fz * vc }
    end
    return { x = ka == "rel" and m.pos.x + va or va,
             y = kb == "rel" and m.pos.y + vb or vb,
             z = kc == "rel" and m.pos.z + vc or vc }
end

function tp.dist_to_me(li)
    local me, m = gNetworkPlayers[0], gMarioStates[li]
    local np = gNetworkPlayers[li]
    if me == nil or np == nil or m == nil or gMarioStates[0] == nil then return nil end
    if np.currLevelNum ~= me.currLevelNum or np.currAreaIndex ~= me.currAreaIndex then
        return nil
    end
    local o = gMarioStates[0].pos
    local dx, dy, dz = m.pos.x - o.x, m.pos.y - o.y, m.pos.z - o.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function panel.tp_entity(token)
    if token == nil or token == "" then return nil, tp.BAD end
    local letter, args = string.match(token, "^@([sprane])%[(.*)%]$")
    if letter == nil then letter = string.match(token, "^@([sprane])$") end
    if letter == nil and string.sub(token, 1, 1) == "@" then
        return nil, "Unknown selector type '" .. token .. "'"
    end
    if letter == nil then

        local li = OF.util.find_player_by_name(token)
        if li == nil then return { players = {}, single = true } end
        return { players = { li }, single = true }
    end
    args = args or ""
    if letter == "e" or letter == "n" then
        local spec, why = OF.net.parse_selector_args(args, false)
        if spec == nil then return nil, why end
        return { things = { sel = letter, args = args },
                 single = letter == "n" or spec.limit == 1 }
    end
    local spec, why = OF.net.parse_selector_args(args, true)
    if spec == nil then return nil, why end
    local entries = {}
    for index, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local ok = letter ~= "s" or li == 0
        local name = string.lower(OF.util.plain(entry.np.name or ""))
        if spec.name ~= nil and name ~= spec.name then ok = false end
        for _, not_name in ipairs(spec.notNames) do
            if name == not_name then ok = false end
        end
        for _, not_type in ipairs(spec.notTypes) do
            if not_type == "player" then ok = false end
        end
        local d = tp.dist_to_me(li)
        if (letter == "p" or spec.dmin ~= nil or spec.dmax ~= nil) and d == nil then
            ok = false
        end
        if spec.dmin ~= nil and d ~= nil and d < spec.dmin then ok = false end
        if spec.dmax ~= nil and d ~= nil and d > spec.dmax then ok = false end
        if ok then table.insert(entries, { li = li, d = d, order = index }) end
    end
    local defaultSort = (letter == "p" and "nearest") or (letter == "r" and "random")
        or "arbitrary"
    local defaultLimit = (letter == "p" or letter == "r") and 1 or nil
    OF.net.sort_and_limit(entries, spec, defaultSort, defaultLimit, math.random(1, 2147483646))
    local players = {}
    for _, e in ipairs(entries) do table.insert(players, e.li) end
    local single = letter == "s" or letter == "p" or letter == "r" or spec.limit == 1
    return { players = players, single = single }
end

function panel.tp_parse(msg)
    local t = panel.tp_tokens(msg)
    if #t == 0 then return nil, "Unknown or incomplete command" end
    local plan = {}
    local at = 1

    if panel.tp_coord(t[1]) ~= nil then
        if #t ~= 3 then return nil, tp.BAD end
        plan.targets = { players = { 0 }, single = true }
    elseif #t == 1 then
        plan.targets = { players = { 0 }, single = true }
    else
        local who, why = panel.tp_entity(t[1])
        if who == nil then return nil, why end
        plan.targets = who
        at = 2
    end
    if panel.tp_coord(t[at]) == nil then

        if #t ~= at then return nil, tp.BAD end
        local dest, why = panel.tp_entity(t[at])
        if dest == nil then return nil, why end
        if not dest.single then return nil, tp.ONE end
        plan.dest = dest
        return plan
    end
    local point, why = panel.tp_location(t[at], t[at + 1], t[at + 2])
    if point == nil then return nil, why end
    plan.point = point
    at = at + 3
    if t[at] == nil then return plan end
    if string.lower(t[at]) == "facing" then
        if t[at + 1] ~= nil and string.lower(t[at + 1]) == "entity" then
            local anchor = t[at + 3]
            if (anchor ~= nil and anchor ~= "eyes" and anchor ~= "feet") or t[at + 4] ~= nil then
                return nil, tp.BAD
            end
            local face, whyFace = panel.tp_entity(t[at + 2])
            if face == nil then return nil, whyFace end
            if not face.single then return nil, tp.ONE end
            plan.facingEntity = face
            return plan
        end
        if t[at + 4] ~= nil then return nil, tp.BAD end
        local spot, whySpot = panel.tp_location(t[at + 1], t[at + 2], t[at + 3])
        if spot == nil then return nil, whySpot end
        plan.facing = spot
        return plan
    end

    if t[at + 2] ~= nil then return nil, tp.BAD end
    local ky, vy = panel.tp_coord(t[at])
    local kp = t[at + 1] ~= nil and panel.tp_coord(t[at + 1]) or "rel"
    if ky == nil or kp == nil then return nil, tp.BAD end
    if ky == "local" or kp == "local" then return nil, "Local coordinates are not allowed here" end
    local turn = math.floor(-vy * 65536 / 360 + 0.5)
    if ky == "rel" then plan.yawRel = turn else plan.yaw = turn end
    return plan
end

function tp.norm(a)
    a = math.floor(a) % 0x10000
    if a >= 0x8000 then a = a - 0x10000 end
    return a
end

function tp.yaw_towards(from, to)
    local dx, dz = to.x - from.x, to.z - from.z
    if dx == 0 and dz == 0 then return nil end
    return tp.norm(math.atan(dx, dz) * 65536 / (math.pi * 2))
end

function tp.coords_text(p)
    return string.format("%.1f, %.1f, %.1f", p.x, p.y, p.z)
end

function tp.player_name(li)
    local np = gNetworkPlayers[li]
    if np == nil then return "?" end
    return OF.util.chat_name(np.name or "?")
end

function tp.entity_spot(ent)
    if ent.players ~= nil then
        local li = ent.players[1]
        if li == nil then return nil end
        if li ~= 0 and tp.dist_to_me(li) == nil then return nil, tp.player_name(li), li end
        local m = gMarioStates[li]
        return { x = m.pos.x, y = m.pos.y, z = m.pos.z }, tp.player_name(li), li
    end
    local me, m = gNetworkPlayers[0], gMarioStates[0]
    local picked = OF.net.select_things({ lvl = me.currLevelNum, area = me.currAreaIndex,
        ox = m.pos.x, oy = m.pos.y, oz = m.pos.z, sel = ent.things.sel,
        args = ent.things.args, seed = 1 })
    if picked[1] == nil then return nil end
    local o = picked[1].o
    return { x = o.oPosX, y = o.oPosY, z = o.oPosZ }, picked[1].kind or "entity"
end

function tp.said(text, a, b)
    OF.util.chat(OF.lang.fill(text, a, b))
end

function tp.refused(text)
    OF.util.chat(OF.lang.t(text), "warn")
end

function panel.teleport_command(msg)
    if travel_stands_down() then return true end
    local plan, why = panel.tp_parse(msg)
    if plan == nil then
        tp.refused(why)
        return true
    end
    local targets = plan.targets
    local others = targets.things ~= nil
    for _, li in ipairs(targets.players or {}) do
        if li ~= 0 then others = true end
    end
    if others then
        if not OF.util.allowed("teleport_other") then return true end
        local tier = panel.TP_OTHERS_TIER or (OF.TIER and OF.TIER.MOD)
        if tier ~= nil and OF.perms.tier(0) < tier then
            tp.refused("Moving other players or @e with /tp is for Mod and up.")
            return true
        end
    else
        if not OF.util.allowed("teleport_self") then return true end
    end
    if targets.players ~= nil and #targets.players == 0 then
        tp.refused("No player was found")
        return true
    end

    local me, m = gNetworkPlayers[0], gMarioStates[0]

    local destName, destLi = nil, nil
    local point = plan.point
    if plan.dest ~= nil then
        local spot, name, li = tp.entity_spot(plan.dest)
        if name == nil then
            tp.refused(plan.dest.players ~= nil and "No player was found" or "No entity was found")
            return true
        end
        destName, destLi = name, li
        point = spot
        if spot == nil and targets.things ~= nil then
            tp.refused("Enemies and items stay in their own level - that player is elsewhere.")
            return true
        end
    end
    if point ~= nil then
        point.level, point.area, point.act =
            me.currLevelNum, me.currAreaIndex, me.currActNum
    end
    local facingYaw = nil
    if point ~= nil and plan.facing ~= nil then facingYaw = tp.yaw_towards(point, plan.facing) end
    if point ~= nil and plan.facingEntity ~= nil then
        local spot = tp.entity_spot(plan.facingEntity)
        if spot == nil then
            tp.refused("No entity was found")
            return true
        end
        facingYaw = tp.yaw_towards(point, spot)
    end
    local whereText = destName or (point ~= nil and tp.coords_text(point)) or "?"
    if targets.things ~= nil then
        local job = { lvl = me.currLevelNum, area = me.currAreaIndex, act = me.currActNum,
            x = point.x, y = point.y, z = point.z, ox = m.pos.x, oy = m.pos.y, oz = m.pos.z,
            sel = targets.things.sel, args = targets.things.args,
            seed = math.random(1, 2147483646),
            yaw = facingYaw or plan.yaw, yr = plan.yawRel }
        local count = #OF.net.select_things(job)
        if count == 0 then
            tp.refused("No entity was found")
            return true
        end
        local ok, whyNot = OF.net.move_things(job)
        if not ok then
            OF.util.report(false, whyNot)
            return true
        end
        tp.said("Teleported @ entities to @", tostring(count), whereText)
        return true
    end

    local moved, refusal, only = 0, nil, nil
    for _, li in ipairs(targets.players) do
        local ok, whyNot = true, nil
        local angle = facingYaw or plan.yaw
        if angle == nil and plan.yawRel ~= nil then
            angle = tp.norm((gMarioStates[li].faceAngle.y or 0) + plan.yawRel)
        end
        if destLi ~= nil and point == nil then

            local tg = network_global_index_from_local(destLi)
            if li == 0 then
                OF.net.teleport_to(tg)
            elseif li ~= destLi then
                ok, whyNot = OF.net.summon_player(network_global_index_from_local(li), tg)
            end
        else
            local spot = { level = point.level, area = point.area, act = point.act,
                x = point.x, y = point.y, z = point.z, angle = angle }
            if li == 0 then
                OF.net.teleport_to_position(spot)
            else
                ok, whyNot = OF.net.send_to_position(network_global_index_from_local(li), spot)
                if ok == nil then ok = true end
            end
        end
        if ok then
            moved = moved + 1
            only = li
        elseif refusal == nil then
            refusal = whyNot
        end
    end
    if moved == 0 then
        OF.util.report(false, refusal)
    elseif moved == 1 then
        tp.said("Teleported @ to @", tp.player_name(only), whereText)
    else
        tp.said("Teleported @ entities to @", tostring(moved), whereText)
    end
    return true
end

hook_chat_command("teleport", "- teleport like Minecraft: who, then a player or x y z and a facing (@s @a @p @r @e @n)",
    function(msg) return panel.teleport_command(msg) end)
hook_chat_command("tp", "- teleport like Minecraft: who, then a player or x y z and a facing (@s @a @p @r @e @n)",
    function(msg) return panel.teleport_command(msg) end)
end
