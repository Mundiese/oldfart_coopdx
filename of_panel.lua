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
    if OF.util.asks(OF.theme, "highlight") then
        local r, g, b = OF.theme.highlight()
        if r ~= nil then return r, g, b end
    end
    local value = gold()
    return value.r, value.g, value.b
end

panel.highlight_rgb = highlight

panel.open = false
panel.page = "main"
panel.selected = -1
panel.levelMode = "everyone"
panel.pickMode = "everyone"
panel.aim = "self"
panel.dressGroup = nil

panel.modeKey = nil
panel.group = "Castle"
panel.hatGroup = nil
panel.starCourse = nil
panel.permPreset = nil

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
    return true
end

local OPACITY_KEY = "panel_opacity"
local OPACITY_DEFAULT = 75

panel.opacity = mod_storage_load_integer(OPACITY_KEY, OPACITY_DEFAULT)

panel.OPACITY_LIMITS = { min = 50, max = 100, step = 5 }

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

    local width = OF.util.clamp(screenWidth * (panel.place.w / 100),
        math.min(380, screenWidth), screenWidth - 16)
    local height = OF.util.clamp(screenHeight * (panel.place.h / 100),
        math.min(240, screenHeight), screenHeight - 16)

    local freeX = math.max(0, screenWidth - width)
    local freeY = math.max(0, screenHeight - height)

    return freeX * (panel.place.x / 100), freeY * (panel.place.y / 100),
        width, height
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

local function rest_row(built)
    if built ~= nil then built.rest = true end
    return built
end
panel.rest_row = rest_row

local function with_slider(built, value, steps, onChange)
    if built == nil then return nil end
    built.slider = { value = value, steps = steps }

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
    local at, from = 1, 0
    for n = 1, index do
        local box = string.match(text, "^%[[xX%s%-]%]%s", at)
        if box == nil then return nil end
        local wide = OF.util.width(box, scale)
        if n == index then return from, from + wide end
        from = from + wide
        at = at + #box
    end
    return nil
end

function panel.alt_zone(row, left)
    if type(row) ~= "table" or row.altAction == nil or row.altPad then
        return nil
    end
    local index = row.altBox or 1
    local from, to = panel.box_span(row.text, index)
    if from == nil then
        if panel.has_box(row) then return nil end
        from, to = 0, OF.util.width(panel.tick(true, ""), ROW_SCALE)
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
    if changed and built.action ~= nil then
        local g = gold()
        built.r, built.g, built.b = g.r, g.g, g.b
    end
    return with_right(built, level)
end

local function label_row(text, r, g, b)
    return { text = text, r = r or 150, g = g or 150, b = b or 150 }
end

local function loud_row(text)
    return label_row(text, gold().r, gold().g, gold().b)
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

local function host_row(feature, text, r, g, b, action)
    if OF.perms.can(feature) and not OF.util.is_host() then
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
        built.actionLabel = "for everyone"
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
        built.actionLabel = "for everyone"
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
    for _ = 1, #ring do
        index = index + 1
        if index > #ring then return nil end
        if ring[index] ~= lobbyLevel then return ring[index] end
    end
    return nil
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
    if not OF.util.asks(OF.lockdown, "held_by_round") then return false end
    if OF.lockdown.held_by_round() then return true end
    if not OF.util.asks(OF.lockdown, "held_by_race") then return false end
    return OF.lockdown.held_by_race()
end

function panel.tab_is_open(key)
    if not panel.round_tab_only() then return true end
    return key == panel.ROUND_TAB
end

local function go(page)

    if known_page(page) and not panel.tab_is_open(panel.tab_of(page)) then
        return
    end
    panel.remember()
    panel.page = page
    mark_tab_page(page)

    panel.mark_arrival()

    if not panel.open and known_page(page) then panel.lastPage = page end

    panel.foldAsk = page
    local was = panel.memory[page]
    panel.scroll = was ~= nil and was.scroll or 0
    panel.cursor = was ~= nil and was.cursor or 1
    panel.confirm = nil

    if panel.landed ~= nil and panel.landed.page ~= page then
        panel.landed = nil
    end

    panel.sliderDrag = nil

    panel.putBackSaid = nil

    if panel.forget_active ~= nil then panel.forget_active() end

    if panel.rebuild ~= nil then panel.rebuild() end

    if was ~= nil and was.key ~= nil and panel.keep_cursor_on ~= nil then
        panel.keep_cursor_on(was.key)
    end

    if was == nil and panel.rest_cursor ~= nil then panel.rest_cursor() end
end

panel.go = go

function panel.with_confirm(built, key)
    if built == nil or built.action == nil then return built end

    local action = built.action
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
    return confirm_row(key, text, r, g, b, action)
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
    if mode == "selected" then return panel.selection_list() end
    if mode == "everyone" then return everyone() end
    if mode == "others" then return others() end
    if mode == "player" then return { panel.selected } end
    return { network_global_index_from_local(0) }
end

local AIM_NAMES = {
    self = OF.lang.t("just me"),
    player = OF.lang.t("that player"),
    selected = OF.lang.t("the ticked"),
    others = OF.lang.t("everyone but me"),
    everyone = OF.lang.t("everyone"),
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

local function player_display(entry)
    local tier = OF.ranks.get(entry.localIndex)
    local tag = OF.perms.tier_label(tier)
    local text = entry.np.name
    if tag ~= "" then text = "[" .. tag .. "] " .. text end

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

    return text .. flags
end

local function player_where(entry)
    return where_of(entry.np.currLevelNum, entry.np.currAreaIndex)
end

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

    if OF.spectate.can_stop() then
        table.insert(rows, with_help(row(OF.spectate.is_active()
            and OF.lang.t("Stop spectating") or OF.lang.t("Stop spectating (give me my body back)"),
            255, 140, 90, function()
                OF.spectate.stop()
                panel.close()
            end), OF.lang.t("puts you back in your own body, wherever it was left")))
    end

    table.insert(rows, header_row(OF.lang.t("The whole lobby")))
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Gather everyone to me"), 255, 255, 255, function()

        local moved, why = OF.net.summon_everyone_to(me)
        OF.net.report_move(moved > 0, why,
            OF.lang.fill("Summoned @ player(s).", moved))
    end), OF.lang.t("pulls the whole lobby to where you are standing")))
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Gather everyone to a player..."), 255, 255, 255, function()
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

    table.insert(rows, header_row(OF.lang.t("Saved places")))
    table.insert(rows, with_help(gated_row("waypoint_use", OF.lang.fill("Waypoints (@)", #OF.waypoints.list()),
        255, 255, 255, function() go("waypoints") end),
        OF.lang.t("spots you have saved, to send yourself or anybody else to")))

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
        row(OF.lang.t("What the lobby changes..."), 255, 255, 255,
            function() go("roomrules") end),
        ((OF.util.asks(OF.harsh, "any_on") and OF.harsh.any_on())
            or (OF.util.asks(OF.enemies, "anything_on") and OF.enemies.anything_on()))
            and OF.lang.t("on") or ""),
        "how the game plays, what a mistake costs, and what is left standing in the level"))

    table.insert(rows, with_help(
        row(OF.lang.t("Chance and chaos..."), 255, 220, 120,
            function() go("chance") end),
        "the randomizer, the clock that deals the lobby a new hand, and the 1-UP that hunts you"))

    table.insert(rows, with_help(with_right(
        row(OF.lang.t("Look and sound..."), 255, 255, 255,
            function() go("looksound") end),
        OF.music.track_name(OF.music.lobby_track())),
        OF.lang.t("the music, the weather and the light, and what shape everybody is drawn as")))

    table.insert(rows, header_row(OF.lang.t("The level and the save file")))

    if OF.util.asks(OF.warp, "build_page") then

        table.insert(rows, with_help(with_right(
            gated_row("vision", OF.lang.t("The size of the landscape..."),
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
        gated_row("powerup_self", OF.lang.t("Cheats..."), 255, 255, 255,

            function() go("cheats") end),

        OF.lang.fill("@ on", OF.util.asks(OF.cheats, "page_count")
            and OF.cheats.page_count() or 0)),
        OF.lang.t("one player's switches, and the six the whole lobby wears")))

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

local function build_roomrules()
    local rows = {}

    table.insert(rows, with_help(gated_row("rules", OF.lang.t("How the game plays..."), 255, 255, 255,
        function() go("rules") end),
        OF.lang.t("the game's own settings - stars, coins, caps, doors and the courses")))

    if OF.util.asks(OF.moves, "build_page") then
        table.insert(rows, with_help(gated_row("speedrun",
            OF.lang.t("Controls editor - the pad and the camera..."),
            255, 255, 255, function() go("moves") end),
            OF.lang.t("what anybody may press, where the camera stands, and which way up it all is")))
    end

    if OF.util.asks(OF.harsh, "build_page") then
        table.insert(rows, with_help(with_right(
            row(OF.lang.t("What a mistake costs - make it worse on purpose..."),
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

    table.insert(rows, with_help(gated_row("save_edit", OF.lang.t("Randomizer..."),
        255, 220, 120, function() go("rando") end),
        OF.lang.t("a hand of modifiers and a shuffled castle, dealt from a shape you choose once")))

    if OF.util.asks(OF.chaos, "build_page") then
        local running = OF.util.asks(OF.chaos, "on") and OF.chaos.on()
        table.insert(rows, with_right(with_help(gated_row("speedrun",
            running and OF.lang.t("Chaos: on...") or OF.lang.t("Chaos..."),
            255, running and 200 or 255, running and 120 or 255,
            function() go("chaos") end),
            OF.lang.t("the lobby deals itself something new on a clock, and never says what")),
            running and OF.util.asks(OF.chaos, "label") and OF.chaos.label() or ""))
    end

    if OF.util.asks(OF.modifiers, "demon_row") then
        local demon = OF.modifiers.demon_row(panel)
        if demon ~= nil then table.insert(rows, demon) end
    end

    table.insert(rows, back_row())
    return rows
end

local function build_looksound()
    local rows = {}

    table.insert(rows, with_help(with_right(gated_row("music",
        OF.lang.t("Music..."),
        255, 255, 255, function() go("music") end),
        OF.music.track_name(OF.music.lobby_track())),
        OF.lang.t("what the whole lobby hears, and the playlist it is dealt from")))

    table.insert(rows, with_help(gated_row("vision",
        OF.lang.t("Visuals - how the lobby looks..."), 255, 255, 255,
        function() go("vision") end),
        OF.lang.t("the weather, the light, the shadows, and the looks this lobby is wearing")))

    if OF.util.asks(OF.theme, "shape") then
        table.insert(rows, with_help(with_right(gated_row("vision",
            OF.lang.t("How players look..."),
            255, 255, 255, function() go("shapes") end),
            OF.lang.t(OF.theme.shape().name)),
            "the shape everybody is drawn as, and the name over their head"))
    end

    table.insert(rows, back_row())
    return rows
end

local function build_control()
    local rows = {}

    table.insert(rows, header_row(OF.lang.t("Who may do what")))

    table.insert(rows, with_help(gated_row("settings", OF.lang.t("Moderation..."),
        255, 255, 255, function() go("order") end),
        OF.lang.t("ranks and permissions, mutes, bans, warnings, notes and the chat filter")))

    if OF.util.asks(OF.perms, "build_shields_page") then
        table.insert(rows, with_help(gated_row("ranks",
            OF.lang.t("Who is protected..."),
            255, 255, 255, function() go("permshield") end),
            OF.lang.t("who a moderator may not act on, whatever rank they hold")))
    end

    local held = OF.util.asks(OF.lockdown, "held_by_host") and OF.lockdown.held_by_host()
    table.insert(rows, with_help(host_row("jail",
        held and OF.lang.t("Let the lobby go again")
             or OF.lang.t("Hold the whole lobby"),
        held and 120 or 255, held and 255 or 200, held and 140 or 90, function()

            OF.util.report(OF.lockdown.toggle_hold(0))
        end), "modifiers off, cheats off, nobody but you can do anything"))

    if OF.util.asks(OF.vote, "build_page") then
        local running = OF.util.asks(OF.vote, "is_open") and OF.vote.is_open()
        local voteRow = row(OF.lang.t("Vote - ask the lobby a question..."),
            255, 255, 255, function() go("vote") end)
        if running and OF.util.asks(OF.vote, "count_text") then
            voteRow = with_right(voteRow, OF.vote.count_text())
        end
        table.insert(rows, with_help(voteRow, running
            and OF.lang.t("a question is open - answer it, or read who has not")
            or OF.lang.t("end the round early, or ask the lobby about somebody")))
    end

    table.insert(rows, header_row(OF.lang.t("What happened, and what is running")))

    table.insert(rows, with_help(with_right(
        host_row("jail", OF.lang.t("Who did what..."), 255, 220, 120,
            function() go("actionlog") end),
        tostring(OF.util.asks(OF.actionlog, "count") and OF.actionlog.count() or 0)),
        "every action anybody took in this mod menu, with the name and the time"))

    table.insert(rows, with_right(
        with_help(row(OF.lang.t("Chat log..."), 255, 255, 255,
            function() go("chatlog") end),
            OF.lang.t("what the lobby has said, kept on this machine for this session")),
        tostring(#((OF.chatlog ~= nil and OF.chatlog.entries) or {}))))

    local clashing = OF.util.asks(OF.roommods, "clashes")
        and #OF.roommods.clashes() or 0
    table.insert(rows, with_help(with_right(
        row(OF.lang.t("What else is loaded here..."), 255, 255, 255,
            function() go("roommods") end),
        clashing > 0 and tostring(clashing) or ""),
        OF.lang.t("every mod running in this lobby, and which two of them were built to be run apart")))

    if OF.util.asks(OF.trouble, "rules_changed") then
        local watched = OF.trouble.rules_changed()
        table.insert(rows, with_help(with_right(host_row("settings",
            OF.lang.t("What the mod does on its own..."), 255, 255, 255,
            function() go("autorules") end),
            watched > 0 and tostring(watched) or ""),
            OF.lang.t("everything that acts without being pressed, and one press to watch instead")))
    end

    table.insert(rows, with_help(gated_confirm_row("settings", "freshroom",
        OF.lang.t("Put the lobby back, keep personal things"), 255, 200, 120,
        function()
            OF.util.report(OF.fresh.run(true))
        end), "the round, the modifiers and every sentence - but not what somebody put on themselves"))

    table.insert(rows, with_help(gated_confirm_row("settings", "freshstart",
        OF.lang.t("Start the lobby fresh"), 255, 200, 120, function()
            OF.util.report(OF.fresh.run())
        end), "the round, the modifiers, the cheats and every sentence, all put back"))

    return rows
end

local function build_order()
    local rows = {}

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

    table.insert(rows, header_row(OF.lang.t("The ladder, and who is on it")))

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
    table.insert(rows, with_help(host_row("settings",
        OF.lang.t("Permission presets..."),
        255, 255, 255, function() go("permpresets") end),
        OF.lang.t("a whole ladder in one press, with what it moves shown first")))

    table.insert(rows, with_help(gated_row("ranks",
        OF.lang.fill("Remembered ranks (@)", OF.ranks.remembered_count()),
        255, 255, 255, function() go("remembered") end),
        OF.lang.t("who keeps a rank when they are not in the lobby")))
    table.insert(rows, with_help(gated_row("ban",
        OF.lang.fill("Ban list (@)", OF.jail.ban_count()),
        255, 255, 255, function() go("bans") end),
        OF.lang.t("who the lobby will not let back in, and one press to forgive")))

    table.insert(rows, with_help(with_right(gated_row("mute",
        OF.lang.fill("Warnings on record (@)", OF.jail.warn_total()),
        255, 255, 255, function() go("warnings") end),
        OF.jail.escalates() and OF.lang.t("escalates") or OF.lang.t("record only")),
        OF.lang.t("a word before a punishment, and the lobby remembers it")))
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
            end),
            OF.lang.t(OF.trouble.mode_name(OF.trouble.mode(def.key)))),
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

    table.insert(rows, header_row(OF.lang.t("On your screen")))

    table.insert(rows, with_help(row(OF.lang.t("Theme..."), 255, 255, 255,
        function() go("theme") end),
        OF.lang.t("the colours this menu is drawn in, on your screen only")))

    if OF.util.asks(OF.theme, "build_screen_page") then
        table.insert(rows, with_help(
            row(OF.lang.t("Marks over players, and the notices..."),
                255, 255, 255, function() go("screen") end),
            OF.lang.t("what the marks over people show, the fanfare, and how a win looks to you")))
    end

    table.insert(rows, with_help(row(OF.lang.t("When somebody arrives..."), 255, 255, 255,
        function() go("arrivals") end),
        OF.lang.t("the banner and the chat line you see when a player joins or goes")))

    if OF.util.asks(OF.scoreboard, "toggle") then
        table.insert(rows, with_help(
            row(panel.tick(OF.scoreboard.is_on(),
                OF.lang.t("This round, on the player list key")),
                255, 255, 255, function() OF.scoreboard.toggle() end),
            OF.lang.t("hold the key that opens the player list to see where everybody stands")))
    end

    table.insert(rows, header_row(OF.lang.t("This menu and your pad")))

    table.insert(rows, with_help(row(OF.lang.t("The menu's size and place..."),
        255, 255, 255, function() go("place") end),
        OF.lang.t("how wide and tall this menu is drawn, and where it sits")))
    table.insert(rows, with_help(row(OF.lang.t("Your shortcuts - what you press most..."),
        255, 255, 255, function() go("quick") end),
        OF.lang.t("the rows you press most, gathered onto one page")))

    table.insert(rows, with_help(row(OF.lang.t("Your controls - the pad and this menu..."),
        255, 255, 255, function() go("controls") end),
        OF.lang.t("which button opens this menu, and what the pad does while it is open")))

    table.insert(rows, with_help(
        row(OF.lang.t("Commands - what you can type..."), 255, 255, 255,
            function() go("commands") end),
        OF.lang.t("every word this mod adds to the chat box, grouped")))

    return rows
end

local function build_arrivals()
    local rows = {}

    table.insert(rows, label_row(OF.lang.t(
        "Yours only. Nobody else is affected and nothing is sent.")))

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
    local secondsRow = row(OF.lang.t("Banner seconds") .. "  -  " .. tostring(seconds),
        255, 220, 120, function()
            local wanted = seconds + 1
            if wanted > high then wanted = low end
            OF.settings.set_banner_seconds(wanted)
        end)
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

    table.insert(rows, label_row(OF.lang.t("Drag the title bar to move it, or dial it here.")))

    local DIALS = {
        { which = "x", name = OF.lang.t("Across"),
          help = OF.lang.t("how far across the screen the menu sits") },
        { which = "y", name = OF.lang.t("Down"),
          help = OF.lang.t("how far down the screen the menu sits") },
        { which = "w", name = OF.lang.t("Width"),
          help = OF.lang.t("how wide the menu is drawn, and so how much of a"
              .. " row's sentence fits on one line") },
        { which = "h", name = "Height",
          help = OF.lang.t("how tall the menu is drawn, and so how many rows fit") },
    }
    for _, dial in ipairs(DIALS) do
        local which = dial.which
        local built = row(OF.lang.t(dial.name) .. "   "
            .. panel.place[which] .. "%", 255, 255, 255, function() end)
        table.insert(rows, with_help(with_slider(built, panel.place_step(which),
            panel.place_steps(which), function(wanted)
                OF.util.report(panel.set_place_step(which, wanted))
            end), dial.help))
    end

    table.insert(rows, label_row(OF.lang.t(
        "A narrower menu cuts the line under the cursor, and the half it cuts "
        .. "is the half that carries the warning.")))

    table.insert(rows, with_help(row(OF.lang.t("Back to the middle"),
        255, 200, 120, function()
        panel.reset_place()
    end), OF.lang.t("puts all four dials back where the menu shipped")))

    table.insert(rows, back_row())
    return rows
end

local function build_players()
    local rows = {}
    local selected = panel.selection_count()

    local ticks = "A"
    local mousing = false
    if OF.util.asks(OF.input, "device_says") then
        ticks = OF.input.device_says("A", "A click")
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

    table.insert(rows, with_help(with_right(
        row(OF.lang.t("Costumes - be something else..."), 255, 255, 255,
            function()

                go("costumes")
            end),
        OF.costumes.name_worn(0) or OF.lang.t("your own face")),
        "your own Mario, reshaped - and only yours"))

    if OF.util.asks(OF.hats, "build_page") then
        table.insert(rows, with_help(with_right(
            row(OF.lang.t("Hats - wear something on your head..."),
                255, 255, 255, function() go("hats") end),
            OF.util.asks(OF.hats, "name_worn")
                and (OF.hats.name_worn(0) or OF.lang.t("nothing")) or ""),
            OF.lang.t("something on your own head, and only yours")))
    end

    if OF.util.asks(OF.emotes, "build_page") then
        table.insert(rows, with_help(with_right(
            row(OF.lang.t("Emotes - say something without typing..."),
                255, 255, 255, function() go("emotes") end),
            OF.util.asks(OF.emotes, "count")
                and OF.lang.fill("@ on the wheel", OF.emotes.count()) or ""),
            OF.lang.t("a wheel on a shoulder button: wave, point, sit, cheer")))
    end

    table.insert(rows, header_row(OF.lang.t("Who is here")))

    for _, entry in ipairs(OF.util.connected_players()) do
        local tier = OF.ranks.get(entry.localIndex)
        local r, g, b = OF.ranks.color(tier)
        local globalIndex = network_global_index_from_local(entry.localIndex)

        local ticked = panel.selection[globalIndex] == true

        local playerRow = with_help(with_right(
            row(panel.tick(ticked, player_display(entry)), r, g, b,
                function() panel.selection_toggle(globalIndex) end),
            player_where(entry)),
            OF.lang.t("A ticks this name, Z opens it; the door below acts on everybody ticked"))
        playerRow.ticks = true

        playerRow.altAction = function()
            panel.selected = globalIndex
            go("player")
        end
        playerRow.altPad = true
        playerRow.altLabel = "open"
        table.insert(rows, playerRow)
    end

    table.insert(rows, header_row(OF.lang.t("What you can do")))

    local connected = OF.util.connected_players()
    local allSelected = selected >= #connected and #connected > 0

    table.insert(rows, with_help(row(
        allSelected and OF.lang.t("Unselect everyone") or OF.lang.t("Select everyone"),
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

    table.insert(rows, with_help(row(OF.lang.t("Select everyone but me"),
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
    table.insert(rows, with_help(row(doorText,
        selected > 0 and 120 or 255, 255, selected > 0 and 120 or 255,
        function()
            local ticked = panel.selection_list()
            if #ticked == 0 then
                OF.util.report(false, OF.lang.t(
                    "Nobody is ticked - tick a player on the list above, then press this."))
                return
            end

            local carryOn, why = panel.aim_check("selected")
            if why ~= nil then OF.util.report(false, why) end
            if not carryOn then return end
            go("multi")
        end),
        OF.lang.t("move them, give them something, do something to them, or moderate them")))

    local oneText = OF.lang.t("Everything about one ticked player...")
    local oneR, oneG, oneB = 255, 255, 255
    if selected == 1 then
        local only = OF.util.local_from_global(panel.selection_list()[1])
        local np = only ~= nil and gNetworkPlayers[only] or nil
        if np ~= nil then
            oneText = OF.lang.fill("Everything about @...", np.name)
            oneR, oneG, oneB = 255, 220, 120
        end
    end
    table.insert(rows, with_help(row(oneText, oneR, oneG, oneB, function()
            local ticked = panel.selection_list()

            if #ticked == 0 then
                OF.util.report(false, OF.lang.t(
                    "Nobody is ticked - tick one player on the list."))
                return
            end
            if #ticked > 1 then
                OF.util.report(false, OF.lang.fill(
                    "@ names are ticked - this opens one. Untick the rest.",
                    #ticked))
                return
            end
            if OF.util.local_from_global(ticked[1]) == nil then
                OF.util.report(false, OF.lang.t("That player has left."))
                return
            end

            panel.selected = ticked[1]
            go("player")
        end),
        OF.lang.t("their record, their rank, a sentence - the things that are about one person")))

    local incidentEntry, isIncident = OF.recent.target()
    if incidentEntry ~= nil and isIncident then

        table.insert(rows, with_help(with_right(gated_row("mute",
            OF.lang.fill("Mute @", incidentEntry.name),
            255, 200, 120, function() OF.util.report(OF.recent.mute_last()) end),
            incidentEntry.what),
            OF.lang.t("stops the lobby reading what they type in chat")))
    end

    if OF.util.asks(OF.together, "build_page") then
        table.insert(rows, with_help(row(
            OF.lang.t("Players together - stand on, carry, rope..."),
            255, 255, 255, function() go("together") end),
            OF.lang.t("stand on each other, throw each other about, or tie the whole lobby together")))
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
    table.insert(rows, label_row(np.name .. "  -  " .. OF.perms.tier_name(tier)
        .. "  -  " .. where_of(np.currLevelNum, np.currAreaIndex)
        .. OF.lang.fill("  -  ping @", tostring(np.ping)),
        nameR, nameG, nameB))

    table.insert(rows, label_row(identity_of(li), 170, 190, 215))

    for _, r in ipairs(OF.idle.build_rows(panel, li)) do table.insert(rows, r) end

    table.insert(rows, header_row(OF.lang.t("Move")))
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
    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.fill("Teleport everyone to @", np.name),
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

    table.insert(rows, header_row(OF.lang.t("Do")))
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

        table.insert(rows, with_help(panel.with_key(gated_row("ranks",
            OF.lang.fill("Promote to @ @",
            OF.lang.t(OF.perms.tier_name(OF.perms.step_tier(tier, 1))),
            OF.lang.t(length.name)),
            255, 215, 0, function()

                OF.util.report(OF.ranks.promote(li, length.minutes))
            end), "rankpromote"),
            OF.lang.t("moves them one rung up the ladder, for the length above")))
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

        local racing = OF.lang.t("Exclude from speedruns")
        if OF.speedrun.is_excluded(li) then racing = OF.lang.t("Include in speedruns") end
        table.insert(rows, with_help(gated_row("speedrun", racing, 255, 255, 255, function()
            OF.util.report(OF.speedrun.set_excluded(li, not OF.speedrun.is_excluded(li)))
        end), OF.lang.t("whether a round or a timed run counts them in at all")))

        if OF.jail.is_jailed(li) then
            table.insert(rows, with_help(gated_row("jail", OF.lang.fill("Release @ and send home", np.name),
                120, 255, 120, function()
                    OF.util.report(OF.jail.release(li, true))
                    go("players")
                end), OF.lang.t("ends the sentence they are serving and puts them back")))
        else

            local worst = OF.jail.max_sentence()
            table.insert(rows, with_help(with_right(gated_confirm_row("jail",
                "jail_" .. tostring(worst.key), OF.lang.fill("Jail @", np.name),
                255, 140, 90, function()
                    local why = nil
                    if panel.modReason ~= "none" then
                        why = OF.jail.reason_text(panel.modReason)
                    end
                    OF.util.report(OF.jail.punish(li, worst.key, why))
                    go("players")
                end), OF.lang.t(worst.short)),
                OF.lang.t("holds them until somebody lifts it, with the reason above")))
        end

        local carrying = OF.mute.is_muted(li) or OF.jail.is_jailed(li)
            or (OF.util.asks(OF.speedrun, "is_excluded")
                and OF.speedrun.is_excluded(li))
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
        table.insert(rows, with_help(row(OF.lang.t("How to actually disconnect them..."),
            200, 200, 200, function()
            go("kickhelp")
        end), OF.lang.t("what to type, because no mod may press the game's own kick")))
    end

    table.insert(rows, back_row())
    return rows
end

local function build_record()
    local li = OF.util.local_from_global(panel.selected)
    if li == nil then
        return { label_row(OF.lang.t("That player has left.")), back_row() }
    end

    local np = gNetworkPlayers[li]
    local rows = {}
    local tier = OF.ranks.get(li)

    table.insert(rows, label_row(np.name .. "  -  " .. OF.perms.tier_name(tier),
        OF.ranks.color(tier)))

    table.insert(rows, header_row(OF.lang.t("Right now")))
    local holding = {}
    if OF.mute.is_muted(li) then table.insert(holding, "muted") end
    local serving = OF.jail.sentence_of(li)
    if serving ~= nil then table.insert(holding, serving.short) end
    if OF.util.asks(OF.speedrun, "is_excluded") and OF.speedrun.is_excluded(li) then
        table.insert(holding, "sitting races out")
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

    table.insert(rows, with_help(panel.with_key(gated_confirm_row("ban", "ban",
        OF.lang.fill("Ban @ @", np.name, OF.lang.t(length.name)),
        255, 90, 90, function()
            OF.util.report(OF.jail.ban(li, length.minutes, panel.modReason))
            go("players")
        end), "banconfirm"),
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
                OF.util.accent() .. "/kick" .. " " .. OF.util.plain(np.name)))
            OF.util.chat(OF.lang.fill("Then: @", OF.util.accent() .. "/confirm"))
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
    if #list == 0 then

        return {
            label_row(OF.lang.t("Nobody is ticked.")),
            label_row(OF.lang.t("Tick a name on the list and come back.")),
            back_row(),
        }
    end

    local rows = {}
    local me = network_global_index_from_local(0)

    table.insert(rows, panel.aim_fixed(panel.aim_label("selected")))
    local _, _, width = panel.geometry()
    local room = math.max(80, width - SIDE_PADDING * 2)
    local drawn = panel.wrap(selection_names(), ROW_SCALE, room, 6)
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

    if #list == 1 then
        local only = OF.util.local_from_global(list[1])
        if only ~= nil and gNetworkPlayers[only] ~= nil then
            table.insert(rows, with_help(row(
                OF.lang.fill("Everything about @...",
                    gNetworkPlayers[only].name), 255, 220, 120, function()
                    panel.selected = list[1]
                    go("player")
                end),
                OF.lang.t("their record, their rank, a sentence - the things that are about one person")))
        end
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
            OF.net.report_move(sent > 0,
                sent > 0 and nil or "Nobody could be moved.",
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
    table.insert(rows, with_help(gated_row("ranks",
        (promoteTo ~= nil and promoteTo ~= false)
            and OF.lang.fill("Promote them all to @ @",
                OF.lang.t(OF.perms.tier_name(promoteTo)), OF.lang.t(length.name))
            or OF.lang.fill("Promote them all one rung each @",
                OF.lang.t(length.name)),
        255, 215, 0, function()
            local done, refused, why = to_each(list, function(li)
                return OF.ranks.promote(li, length.minutes)
            end)
            report_each(done, refused, why, "Promoted @ player(s).")
        end), (promoteTo ~= nil and promoteTo ~= false)
            and OF.lang.t("they are all on one rung, so they all land on one")
            or OF.lang.t("they are on different rungs, so each moves one up")))
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
    table.insert(rows, with_help(gated_row("speedrun", OF.lang.t("Exclude them from speedruns"), 255, 255, 255, function()
        local done, refused, why = to_each(list, function(li)
            return OF.speedrun.set_excluded(li, true)
        end)
        report_each(done, refused, why, "@ player(s) are sitting rounds out.")
    end), OF.lang.t("a round or a timed run stops counting them in")))
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
                or (OF.util.asks(OF.speedrun, "is_excluded")
                    and OF.speedrun.is_excluded(li))) then
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

local function build_groups()

    local rows = {}
    local aimed = panel.level_aim(panel.levelMode)
    if aimed ~= nil then table.insert(rows, aimed) end
    table.insert(rows, label_row(OF.lang.t("Where to?")))
    for _, group in ipairs(OF.util.level_groups()) do

        if not (group == OF.WAYPOINT_GROUP
            and (panel.levelMode == "run" or panel.levelMode == "round")) then
        local count = #OF.util.levels_in_group(group)
        table.insert(rows, with_help(row(OF.lang.fill("@ (@)", group, count),
            255, 255, 255, function()
            panel.group = group
            go("levels")
        end), OF.lang.t("the levels in this group, to pick one from")))
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
            OF.lang.fill("Sent everyone to @", OF.util.accent() .. entry.name))
        return
    end
    local sent = 0
    for _, globalIndex in ipairs(targets_for(mode)) do
        if OF.net.send_to_position(globalIndex, entry.point) then sent = sent + 1 end
    end

    OF.net.report_move(sent > 0, sent > 0 and nil or "Nobody could be moved.",
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
        return OF.lang.t("starts a timed run of this level, on your clock")
    end
    if mode == "round" then
        return OF.lang.t("the next round is played here; nobody moves yet")
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

        local ticked, refused = false, false
        if mode == "round" then

            refused = entry.point ~= nil
                or (OF.util.asks(OF.gamemodes, "accepts_level")
                    and not OF.gamemodes.accepts_level(panel.modeKey, entry))
            local held = OF.gamemodes ~= nil and OF.gamemodes.levelChoice or nil
            ticked = held ~= nil and held.level == entry.level
                and (held.area or 1) == (entry.area or 1)
        end

        if not refused then
        table.insert(rows, with_help(row(
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
                    OF.lang.fill("Loading @ for everyone.", entry.name))
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
        end), level_help(mode)))
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
    if mode == "round" then return nil end
    if mode == "selected" or mode == "everyone" then
        return panel.aim_fixed(panel.aim_label(mode))
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

    if dials == "none" then return end

    local timed = 0
    for _, entry in ipairs(list) do
        if entry.timed then timed = timed + 1 end
    end

    local lengthRow = gated_row("powerup_tune",
        OF.lang.t("How long") .. "  -  " .. OF.lang.t(OF.powerups.length_name()),
        255, 255, 255, function()
            OF.powerups.set_length(OF.powerups.howLong % #OF.powerups.LENGTHS + 1)
        end)
    table.insert(rows, with_help(with_slider(lengthRow,
        OF.powerups.howLong - 1, #OF.powerups.LENGTHS - 1, function(wanted)
            OF.powerups.set_length(wanted + 1)
        end), OF.lang.fill(lengthHelp, timed)))

    local amountRow = gated_row("powerup_tune",
        OF.lang.t("How many") .. "  -  "
            .. OF.powerups.AMOUNTS[OF.powerups.amount],
        255, 255, 255, function()
            OF.powerups.set_amount(OF.powerups.amount % #OF.powerups.AMOUNTS + 1)
        end)
    table.insert(rows, with_help(with_slider(amountRow,
        OF.powerups.amount - 1, #OF.powerups.AMOUNTS - 1, function(wanted)
            OF.powerups.set_amount(wanted + 1)
        end), OF.lang.t("how many coins, and how many lives at once")))

    if pool then

        table.insert(rows, with_help(with_right(panel.with_key(
            gated_row("powerup_tune", OF.lang.t("Surprise draws from"),
            255, 255, 255, function()
                OF.powerups.set_pool(OF.powerups.pool % #OF.powerups.POOLS + 1)
            end), "givepool"), OF.lang.t(OF.powerups.pool_name())),
            OF.lang.t("what the Surprise row is allowed to roll")))
    end
end

local function give_catalogue_rows(rows, list, need, verb, twoBox)
    local group, sub = nil, nil

    local aimedAt = (not twoBox) and targets_for(panel.aimed_at()) or nil
    for _, entry in ipairs(list) do
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

            if not twoBox then
                text = panel.tick(OF.powerups.staying(entry.key), text)
            end
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

            if not (twoBox and target == "self") then
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

                    OF.notify.show(at > 0 and "@ is on for everyone."
                        or "@ is off for everyone.", "info", 4,
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
        if rungs > 1 then

            local said = OF.powerups.step_name(entry.key) or ""
            if twoBox and boxed then
                local state = OF.powerups.mine_state(entry.key)
                if state == false then

                    said = panel.two_box_level(OF.lang.t("off"), true) or said
                elseif inForce > 0 then
                    said = panel.two_box_level(OF.lang.t(
                        OF.powerups.step_name_at(entry.key, inForce) or said),
                        mineIsMine) or said
                end
            end
            built = with_right(built, said)
            built = with_slider(built, (OF.powerups.step(entry.key) or 1) - 1,
                rungs - 1, function(wanted)
                    OF.util.report(OF.powerups.set_step(entry.key, wanted + 1))
                end)

        elseif twoBox and boxed
                and OF.powerups.mine_state(entry.key) == false then
            built = with_right(built,
                panel.two_box_level(OF.lang.t("off"), true) or "")

        elseif entry.counted then
            built = with_right(built, tostring(OF.powerups.AMOUNTS[OF.powerups.amount]))
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
        table.insert(rows, built)
    end
end

local function build_powerups()
    local rows = {}

    table.insert(rows, label_row(OF.lang.t(
        "A hands this to everyone, Z hands it to you.")))

    table.insert(rows, label_row(OF.lang.t(OF.powerups.ONE_AT_A_TIME)))
    give_dial_rows(rows, OF.powerups.LIST, true,

        "star power and the two doses - @ rows", "dials", false)

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

local function build_cheats()
    local rows = {}
    for _, r in ipairs(OF.cheats.build_rows(panel)) do
        if r.heading == true and r.sub == true then

            table.insert(rows, with_help(header_row(r.text), r.help))
        else
            table.insert(rows, r)
        end
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

    table.insert(rows, with_help(gated_row("teleport_other", OF.lang.t("Send everyone there"), 255, 255, 255, function()
        local ok, why = OF.net.send_everyone_to_position(point)
        OF.net.report_move(ok, why,
            OF.lang.fill("Sent everyone to @", OF.util.accent() .. point.name))
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
                OF.notify.show("Cheats off", "info", 3)
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
        table.insert(rows, { text = e.time .. "  " .. e.name .. ": " .. e.message,
                             r = e.r, g = e.g, b = e.b })
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

    local rows = { panel.with_walk(with_help(label_row(OF.lang.t(
        "Minimum rank per feature. A raises it, Z lowers it.")),
        OF.lang.t("the rank is on the right, and what the row covers is down here"))) }

    table.insert(rows, panel.with_walk(with_help(label_row(OF.lang.t(
        "\"host only\" is the host\'s own machine, so those rows cannot be moved.")),
        OF.lang.t("four of them are written into the host\'s own record and cannot leave it"))))

    local reading = {}
    for _, group in ipairs(OF.perms.grouped_order()) do
        reading[#reading + 1] = group
        for _, feature in ipairs(group.features) do
            reading[#reading + 1] = feature
        end
    end

    for _, entry in ipairs(reading) do

        if type(entry) == "table" then
            table.insert(rows, with_help(header_row(OF.lang.t(entry.name)),
                OF.lang.t(entry.help)))
            goto continue
        end

        local feature = entry
        local required = OF.perms.required(feature)
        local info = OF.perms.tier_info(required)

        if OF.perms.FIXED[feature] then

            table.insert(rows, panel.with_walk(with_help(with_right(
                label_row(OF.lang.t(OF.perms.LABELS[feature] or feature)),
                OF.lang.fill("@, always",
                    OF.lang.t(OF.perms.tier_name(required)))),
                OF.perms.COVERS[feature])))
            goto continue
        end

        if OF.perms.needs_host(feature) then

            table.insert(rows, panel.with_walk(with_help(with_right(
                label_row(OF.lang.t(OF.perms.LABELS[feature] or feature)),
                OF.lang.fill("@ only",
                    OF.lang.t(OF.perms.tier_name(required)))),
                OF.perms.COVERS[feature])))
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
        table.insert(rows, with_help(with_right(built,
            OF.lang.t(OF.perms.tier_name(required))),
            OF.perms.COVERS[feature]))
        ::continue::
    end

    table.insert(rows, with_help(gated_confirm_row("permissions", "resetperms",
        OF.lang.t("Put every rank back where it ships"), 255, 140, 90,
        function()
            OF.util.report(OF.perms.reset())
        end),
        OF.lang.t("every row on this page at once, and nothing else this lobby has set")))
    table.insert(rows, back_row())
    return rows
end

local function build_controls(panel)
    local rows = { label_row(OF.lang.t(
        "Yours only. Nobody else is affected and nothing is sent.")) }

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

    table.insert(rows, label_row(OF.lang.t(
        "Hold Z and press L or R to jump to the next section of a long page.")))

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

    record      = { title = "Their record",          tab = "players", build = build_record, up = "player" },
    ban_confirm = { title = "Ban",                   tab = "players", build = build_ban_confirm, up = "player" },
    kickhelp    = { title = "Disconnecting a player", tab = "players", build = build_kickhelp, up = "player" },
    vote        = { title = "Vote",                  tab = "control", up = "control",
                    build = function() return OF.vote.build_page(panel) end },

    travel      = { title = "Travel",                tab = "travel", build = build_travel },
    groups      = { title = "Destinations",          tab = "travel", build = build_groups, up = "travel" },

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

    racers      = { title = "Who is taking part",    tab = "race", up = "speedrun",
                    build = function() return OF.speedrun.build_racers_page(panel) end },
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

    room        = { title = "Fun",                  tab = "room", build = build_room },

    vision      = { title = "Visuals",               tab = "room", up = "looksound",
                    build = function() return OF.modifiers.build_visuals_page(panel) end },

    roomrules   = { title = "What the lobby changes", tab = "room", up = "room",
                    build = build_roomrules },
    chance      = { title = "Chance and chaos",     tab = "room", up = "room",
                    build = build_chance },
    looksound   = { title = "Look and sound",       tab = "room", up = "room",
                    build = build_looksound },

    costumes    = { title = "Costumes",              tab = "players", up = "players",
                    fold = false,
                    build = function() return OF.costumes.build_page(panel) end },

    costumeset  = { title = "Pick a costume",        tab = "players", up = "costumes",
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
                    build = function() return OF.emotes.build_page(panel) end },

    forge       = { title = "Forge",                 tab = "room", up = "room",
                    build = function() return OF.forge.build_page(panel) end },

    forgepick   = { title = "Things to place",       tab = "room", up = "forge",
                    build = function() return OF.forge.build_pick_page(panel) end },

    bingo       = { title = "Bingo",                 tab = "race", up = "speedrun", fold = false,
                    build = function() return OF.bingo.build_page(panel) end },
    rules       = { title = "How the game plays",     tab = "room", up = "roomrules",
                    build = function() return OF.rules.build_page(panel) end },

    theme       = { title = "Theme",                  tab = "me", up = "client",
                    build = function() return OF.theme.build_page(panel) end },

    shapes      = { title = "How players look",      tab = "room", up = "looksound",
                    build = function() return OF.theme.build_figure_page(panel) end },
    music       = { title = "Music",                 tab = "room", up = "looksound",
                    build = function() return OF.music.build_page(panel) end },

    together    = { title = "Players together",      tab = "players", up = "players",
                    build = function() return OF.together.build_page(panel) end },

    practice    = { title = "Practice room",         tab = "race", up = "speedrun",
                    build = function() return OF.together.build_practice(panel) end },
    notes       = { title = "Notes",                 tab = "control", up = "order",
                    build = function() return OF.notes.build_page(panel) end },
    filter      = { title = "Chat filter",           tab = "control", up = "order",
                    build = function() return OF.filter.build_page(panel) end },
    order       = { title = "Moderation",            tab = "control", up = "control",
                    build = build_order },

    autorules   = { title = "What the mod does on its own", tab = "control", up = "control",
                    build = build_autorules },

    roommods    = { title = "What else is loaded",   tab = "control", up = "control",
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
                    build = build_cheats },

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

    sweep       = { title = "Clear the level out", tab = "room", up = "roomrules",
                    build = function() return OF.arena.build_sweep_page(panel) end },

    control     = { title = "Control",               tab = "control", build = build_control },

    perms       = { title = "Ranks and permissions", tab = "control", build = build_perms, up = "order" },

    permladder  = { title = "What each rank can do",  tab = "control", up = "order",
                    build = function() return OF.perms.build_ladder_page(panel) end },

    permwho     = { title = "Promote or demote",      tab = "control", up = "order",
                    build = function() return OF.ranks.build_who_page(panel) end },
    permrungs   = { title = "The rungs of the ladder", tab = "control", up = "order",
                    build = function() return OF.perms.build_rungs_page(panel) end },
    permshield  = { title = "Who is protected",       tab = "control", up = "control",
                    build = function() return OF.perms.build_shields_page(panel) end },

    permpresets = { title = "Permission presets",     tab = "control", up = "order",
                    selections = {
                        held = function()
                            if panel.permPreset == nil then return "" end
                            return panel.permPreset
                        end,
                        pick = function(value)
                            if value == "" then
                                panel.permPreset = nil
                                return true
                            end
                            panel.permPreset = value
                            return true
                        end,
                        list = function()
                            local out = { "" }
                            for _, entry in ipairs(OF.util.asks(OF.perms, "PRESETS")
                                and OF.perms.PRESETS or {}) do
                                table.insert(out, entry.key)
                            end
                            return out
                        end,

                        name = function(value)
                            if value == "" then
                                return OF.lang.t("none ticked")
                            end
                            local entry = OF.util.asks(OF.perms, "preset")
                                and OF.perms.preset(value) or nil
                            return entry ~= nil and OF.lang.t(entry.name) or nil
                        end,
                    },
                    build = function() return OF.perms.build_presets_page(panel) end },

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
    actionlog   = { title = "Who did what",          tab = "control", up = "control",
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
                           "kickhelp", "tie" }) do
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
    local found = {}
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
                    end
                end
            end
        end
    end
    panel.page, panel.rows = wasPage, wasRows

    panel.searchWord = tostring(word or "")
    panel.searchRows = found
    return found
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

function panel.crumbs_shown(crumbs, room)
    if type(crumbs) ~= "table" or #crumbs <= 1 then return 1 end

    local function width_from(from)
        local text = "  /  "
        if from > 1 then text = text .. "...  /  " end
        for index = from, #crumbs do
            if index > from then text = text .. "  /  " end
            text = text .. tostring(crumbs[index])
        end
        return OF.util.width(text, CRUMB_SCALE)
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
    go(panel.page_for_tab(tab.key))
end

function panel.next_tab(direction)
    panel.show_tab(panel.tab + direction)
    OF.sounds.play(OF.sounds.TAB)
end

panel.PAGES = PAGES

panel.targets_for = targets_for
panel.row = row
panel.with_right = with_right
panel.with_help = with_help
panel.with_slider = with_slider
panel.label_row = label_row
panel.header_row = header_row
panel.sub_header_row = sub_header_row
panel.gated_row = gated_row
panel.host_row = host_row
panel.confirm_row = confirm_row
panel.gated_confirm_row = gated_confirm_row
panel.back_row = back_row
panel.go = go

panel.ROW_SCALE = ROW_SCALE

local function track_share(width)
    return math.floor(width * 0.22)
end

function panel.level_band(rows, width)
    local widest, any = 0, false
    for _, r in ipairs(rows or {}) do
        if r.slider ~= nil and r.slider.steps ~= nil and r.slider.steps > 0 then
            if r.levelSlot or (r.right ~= nil and r.right ~= "") then
                any = true
            end

            local w = OF.util.width(tostring(r.text or ""), ROW_SCALE)
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

local REFRESH_FRAMES = 10
local sinceRefresh = 0

local lastMouseX, lastMouseY = nil, nil

local lastScroll = 0

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
    return PAGES[page]
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

    local def = PAGES[page]
    if def ~= nil and def.fold == false then return end

    if def ~= nil and def.arriveFolded == false then return end

    if not panel.should_fold(rows, panel.visibleRows) then return end

    panel.foldSeen[page] = true

    local under = {}
    local at = nil
    for _, r in ipairs(rows) do
        if r.heading then
            at = r
            under[r] = 0
        elseif at ~= nil and r.outside ~= true then
            under[at] = under[at] + 1
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
            OF.util.chat("\\#ff6060\\" .. told)
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
        if plain and OF.util.width(text, ROW_SCALE) > room then

            for _, line in ipairs(panel.wrap(text, ROW_SCALE, room, 3)) do

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
    maybe_fold(panel.page, panel.rows)
    local built = panel.rows
    panel.rows = apply_folding(panel.page, panel.rows)
    explain_the_grey(panel.rows, built)
    panel.rows = wrap_wide_labels(panel.rows)

    if OF.util.asks(OF.find, "tab_root_row") then
        local ok, hint = pcall(OF.find.tab_root_row, panel)
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

local function log_row(page, row, steady, mine)
    if not OF.util.asks(OF.actionlog, "report") then return false end
    if row == nil or row.heading then return false end

    local said = row.confirming or row.text or panel.row_identity(row)
    if said == nil then return false end

    if row.mine == true then mine = true end

    local where = PAGES[page] ~= nil and PAGES[page].title or page
    return OF.actionlog.report(OF.lang.t(tostring(where)) .. ": "
        .. OF.util.plain(tostring(said)), steady,
        mine == true and OF.actionlog.KIND_MINE or nil)
end

function panel.run(action, mine)
    if action == nil then return end

    local was = panel.rows ~= nil and panel.rows[panel.cursor] or nil

    local wasConfirm = panel.confirm

    local wasKey = panel.row_identity(was)
    local wasPage = panel.page

    local wasOpen = panel.open

    local wasSet = panel.change_snapshot()

    action()

    if OF.util.asks(OF.quick, "remember")
        and panel.page == wasPage and wasOpen then
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
    if panel.page == wasPage and wasKey ~= nil and not armed then
        log_row(wasPage, was, false, mine)
    end

    if panel.page == wasPage and panel.page == "active"
        and panel.forget_active ~= nil then
        panel.forget_active(true)
    end

    if not panel.open then return end
    panel.rebuild()

    panel.note_change(wasSet)

    panel.keep_cursor_on(wasKey)
end

function panel.nudge(step)
    local current = panel.rows and panel.rows[panel.cursor]
    if current == nil or current.slider == nil then return false end
    if current.slider.onChange == nil then return false end

    local wanted = OF.util.clamp(current.slider.value + step,
        0, current.slider.steps)
    if wanted == current.slider.value then return false end

    local wasSet = panel.change_snapshot()
    local wasKey = panel.row_identity(current)
    local wasPage = panel.page
    OF.sounds.play(OF.sounds.MOVE)
    current.slider.onChange(wanted)
    if panel.open then
        panel.rebuild()

        panel.keep_cursor_on(wasKey)
    end
    panel.note_change(wasSet)

    local now = panel.open and panel.rows and panel.rows[panel.cursor] or current

    log_row(wasPage, now, true, now ~= nil and now.mine == true)
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
        if row.slider ~= nil and row.slider.onChange ~= nil then
            table.insert(list, { key = says("<>", "Drag"), label = "set" })
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
                label = row.altLabel or "tick" })
        end
        if row.action ~= nil then

            local what = "pick"
            if row.heading then what = "open"
            elseif panel.row_ticks(row) then what = "tick" end

            if row.actionLabel ~= nil then what = row.actionLabel end

            table.insert(list, {
                key = says("A", twoBoxed and "Click left [x]" or "Click"),
                label = what })
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
        local sections = #panel.section_starts(rows)
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

function panel.back()
    local def = PAGES[panel.page]
    if def ~= nil and def.up ~= nil then
        go(def.up)
        return
    end
    panel.close()
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
        OF.util.chat("\\#ff6060\\" .. why)
        OF.sounds.play(OF.sounds.DENIED)
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
            OF.util.chat("\\#ff6060\\" .. why)
            OF.sounds.play(OF.sounds.DENIED)
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
    OF.sounds.play(OF.sounds.OPEN)
end

function panel.close()
    if panel.open then OF.sounds.play(OF.sounds.CLOSE) end
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

local TAB_WINDOW = 2

local function render_tabs(x, y, width, m, mouseX, mouseY, clicked, wheel)
    local look = OF.theme.active()
    dim_rect(x, y, width, m.tabHeight,
        math.floor(look.title.r * 0.7), math.floor(look.title.g * 0.7),
        math.floor(look.title.b * 0.7), 255)

    local first = math.max(1, panel.tab - TAB_WINDOW)
    local last = math.min(#panel.TABS, panel.tab + TAB_WINDOW)

    local total = 0
    for i = first, last do
        total = total + OF.util.width(OF.lang.t(panel.TABS[i].name), TAB_SCALE) + TAB_GAP
    end
    total = total - TAB_GAP

    local cursorX = x + (width - total) * 0.5
    local textY = y + (m.tabHeight - m.tabText) * 0.5

    for i = first, last do
        local tab = panel.TABS[i]
        local tabName = OF.lang.t(tab.name)
        local tabWidth = OF.util.width(tabName, TAB_SCALE)
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

        if not panel.tab_is_open(tab.key) then
            r, g, b, a = 95, 95, 95, 120
        end

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

        OF.util.text(tabName, cursorX, textY, TAB_SCALE, r, g, b, a)

        if distance == 0 then
            local hr, hg, hb = highlight()
            dim_rect(cursorX - 4, y + m.tabHeight - 3, tabWidth + 8, 3,
                hr, hg, hb, 255)
        end

        if hovered and clicked and distance ~= 0 then

            panel.show_tab(i)
            OF.sounds.play(OF.sounds.TAB)
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
        OF.util.text(glyph, glyphX, textY, TAB_SCALE, lit, lit, lit,
            hovered and 255 or 200)
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

local SELECT_BANDS = 5
local SELECT_REACH = 0.55

local function draw_selection(x, width, top, height)
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

    local rowBand = panel.level_band(rows, width)

    local maxScroll = math.max(0, #rows - visibleRows)
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
        OF.sounds.play(OF.sounds.MOVE)
    end

    clamp_cursor_into_view(visibleRows, panel.scroll ~= lastScroll)
    panel.scroll = math.floor(OF.util.clamp(panel.scroll, 0, maxScroll))
    lastScroll = panel.scroll

    local buttons = djui_hud_get_mouse_buttons_pressed()
    local clicked = OF.util.has_flag(buttons, L_MOUSE_BUTTON)
        or OF.input.mouse_pressed(L_MOUSE_BUTTON)
    local rightClicked = OF.util.has_flag(buttons, R_MOUSE_BUTTON)
        or OF.input.mouse_pressed(R_MOUSE_BUTTON)

    local held = OF.util.has_flag(
        OF.util.optional("djui_hud_get_mouse_buttons_down", 0), L_MOUSE_BUTTON)
    if not held then
        panel.drag = nil
    elseif panel.drag == nil and clicked
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

    local titleY = y + TITLE_PADDING

    local brand = OF.BRAND
    if type(brand) ~= "table" or brand.r == nil then
        brand = { r = 255, g = 255, b = 0 }
    end
    local titleSegments = {
        { text = "old",           r = brand.r, g = brand.g, b = brand.b },
        { text = "fart",          r = 255, g = 255, b = 255 },
    }
    OF.util.draw_segments(titleSegments, x + SIDE_PADDING, titleY, TITLE_SCALE, 255)

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

    local nameWidth = OF.util.segments_width(titleSegments, TITLE_SCALE)
    local crumbX = x + SIDE_PADDING + nameWidth
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
    table.insert(segments, { text = "  /  ", r = 110, g = 110, b = 110 })
    if first > 1 then
        table.insert(segments, { text = "...  /  ", r = 110, g = 110, b = 110 })
    end
    local leaf = nil
    for index = first, #crumbs do
        local last = index == #crumbs

        local shade = last and 215 or 150
        table.insert(segments,
            { text = tostring(crumbs[index]), r = shade, g = shade, b = shade })
        if last then
            leaf = #segments
        else
            table.insert(segments, { text = "  /  ", r = 110, g = 110, b = 110 })
        end
    end

    local overflow = OF.util.segments_width(segments, CRUMB_SCALE) - crumbRoom
    if overflow > 0 and leaf ~= nil then
        local cut = segments[leaf]
        cut.text = OF.util.fit(cut.text, CRUMB_SCALE,
            OF.util.width(cut.text, CRUMB_SCALE) - overflow)
    end
    for _, seg in ipairs(tail) do table.insert(segments, seg) end
    OF.util.draw_segments(segments, crumbX, crumbY, CRUMB_SCALE, 255)

    if render_tabs(x, y + m.titleHeight, width, m, mouseX, mouseY, clicked,
        tabWheel) then
        return
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
            if r.slider ~= nil and r.slider.steps > 0 and r.slider.onChange ~= nil then

                trackX, trackWidth = panel.slider_columns(x, width,
                    rowBand, maxScroll > 0)
            end

            local inTrack = hovered and trackX ~= nil and not inAltZone
                and mouseX >= trackX - 6 and mouseX <= trackX + trackWidth + 6

            if hovered and mouseMoved then panel.cursor = index end

            if selectable and index == panel.cursor then
                local litY, litHeight = glide_to(rowY, m.rowHeight, panel.page)
                draw_selection(x, width, litY, litHeight)

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
            end

            if inTrack and clicked and panel.drag == nil then
                panel.sliderDrag = { index = index, x = trackX, w = trackWidth }
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
                    if wanted ~= r.slider.value then
                        OF.sounds.play(OF.sounds.MOVE)
                        panel.run(function() r.slider.onChange(wanted) end)
                        return
                    end
                end
            end

            if hovered and clicked and not inTrack then

                local doing = inAltZone and r.altAction or r.action

                local sound = OF.sounds.MOVE
                if doing ~= nil then
                    sound = (panel.row_ticks(r) and not inAltZone)
                        and OF.sounds.TICK or OF.sounds.PICK
                end
                OF.sounds.play(sound)
                panel.cursor = index

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
                    OF.sounds.play(OF.sounds.DENIED)
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

            local level = ""
            if r.right ~= nil and r.right ~= "" then
                level = panel.level_shown(r.right, width, hasTrack, rowBand)
            end
            local levelX
            if level ~= "" then

                levelX = (hasTrack and levelEdge or (x + width - SIDE_PADDING))
                    - OF.util.width(level, ROW_SCALE)
            end

            local textRoom
            if hasTrack then
                textRoom = drawTrackX - SIDE_PADDING - (x + SIDE_PADDING)
            elseif levelX ~= nil then
                textRoom = levelX - SIDE_PADDING - (x + SIDE_PADDING)
            else
                textRoom = panel.text_room(nil, width, hasTrack)
            end
            OF.util.text(OF.util.fit(r.text, ROW_SCALE, textRoom),
                x + SIDE_PADDING, rowY + (m.rowHeight - m.rowText) * 0.5,
                ROW_SCALE, r.r, r.g, r.b, ink)

            if hasTrack then
                local trackY = rowY + m.rowHeight * 0.5 - 1
                local lit = selectable and index == panel.cursor

                dim_rect(drawTrackX, trackY, drawTrackWidth, 2,
                    255, 255, 255, lit and 70 or 40)

                local filled = math.floor(
                    drawTrackWidth * (r.slider.value / r.slider.steps))
                if filled > 0 then
                    dim_rect(drawTrackX, trackY, filled, 2,
                        r.r, r.g, r.b, lit and 255 or 150)
                end

                local handleX = drawTrackX + filled - 3
                dim_rect(handleX, rowY + m.rowHeight * 0.5 - 5, 6, 10,
                    r.r, r.g, r.b, lit and 255 or 170)
            end

            if levelX ~= nil then
                OF.util.text(level, levelX,
                    rowY + (m.rowHeight - m.rowText) * 0.5,
                    ROW_SCALE, r.r, r.g, r.b, ink)
            end
        end
    end

    local listBottom = listTop + visibleRows * m.rowHeight
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
        dim_rect(barX, thumbY, 2, thumbHeight,
            gold().r, gold().g, gold().b, bright)
    end

    local footerTop = y + height - m.footerHeight

    dim_rect(x, footerTop - 1, width, 1, 0, 0, 0, 70)
    dim_rect(x, footerTop, width, 1, 255, 255, 255, 30)

    local hints = panel.hints(rows and rows[panel.cursor])
    local contextual = 0
    for _, hint in ipairs(hints) do
        if not hint.nav then
            contextual = contextual + 1
        end
    end

    local PLATE_PADDING = 4
    local GAP = 9
    local room = width - SIDE_PADDING * 2
    local function legend_width(list)
        local total = 0
        for index, hint in ipairs(list) do
            total = total + OF.util.width(hint.key, FOOTER_SCALE) + PLATE_PADDING * 2
                + 4 + OF.util.width(OF.lang.t(hint.label), FOOTER_SCALE)
            if index < #list then total = total + GAP end
        end
        return total
    end
    while #hints > 1 and legend_width(hints) > room do
        table.remove(hints)
    end

    local hintX = x + SIDE_PADDING
    local hintY = footerTop + FOOTER_PADDING

    local under = rows and rows[panel.cursor]
    local help = under ~= nil and under.help or nil
    if help ~= nil and help ~= "" then
        local spare = room - legend_width(hints) - GAP * 2
        if spare > 60 then
            local shown = OF.util.fit(OF.lang.t(help), FOOTER_SCALE, spare)
            OF.util.text(shown,
                x + width - SIDE_PADDING - OF.util.width(shown, FOOTER_SCALE),
                hintY, FOOTER_SCALE, 165, 165, 175, 255)
        end
    end
    for index, hint in ipairs(hints) do
        local lit = index <= contextual
        local keyWidth = OF.util.width(hint.key, FOOTER_SCALE)
        local plateWidth = keyWidth + PLATE_PADDING * 2

        dim_rect(hintX, hintY - 1, plateWidth, m.footerText + 2,
            look.frame.r, look.frame.g, look.frame.b, lit and 220 or 120)
        dim_rect(hintX, hintY - 1, plateWidth, 1, 255, 255, 255, lit and 60 or 25)

        dim_rect(hintX, hintY + m.footerText, plateWidth, 1,
            0, 0, 0, lit and 80 or 45)
        OF.util.text(hint.key, hintX + PLATE_PADDING, hintY, FOOTER_SCALE,
            lit and gold().r or 190, lit and gold().g or 190,
            lit and gold().b or 190, 255)

        hintX = hintX + plateWidth + 4
        local label = OF.lang.t(hint.label)
        OF.util.text(label, hintX, hintY, FOOTER_SCALE,
            lit and 220 or 140, lit and 220 or 140, lit and 220 or 140, 255)
        hintX = hintX + OF.util.width(label, FOOTER_SCALE) + GAP
    end

    OF.util.rect(mouseX + 1, mouseY + 1, 9, 2, 0, 0, 0, 150)
    OF.util.rect(mouseX + 1, mouseY + 1, 2, 9, 0, 0, 0, 150)
    OF.util.rect(mouseX, mouseY, 9, 2, gold().r, gold().g, gold().b, 255)
    OF.util.rect(mouseX, mouseY, 2, 9, gold().r, gold().g, gold().b, 255)

    if rightClicked then
        OF.sounds.play(OF.sounds.BACK)
        panel.back()
    end
end

local function on_update()
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

local zChorded = false

local zRow = nil

local function handle_controller(m)
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
    local function padPressed(button)
        if mousing then return false end
        return input.pressed(button)
    end
    local function padRepeated(button)
        if mousing then return false end
        return input.repeated(button)
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
    if step == 0 and not mousing then step = stickStep end
    if step ~= 0 then
        panel.move_cursor(step)
        OF.sounds.play(OF.sounds.MOVE)
    end

    local zHeld = not mousing and input.held(Z_TRIG)
    local jump = 0
    if padPressed(R_TRIG) then
        if zHeld then jump = 1 else panel.next_tab(1) end
    end
    if padPressed(L_TRIG) then
        if zHeld then jump = -1 else panel.next_tab(-1) end
    end
    if jump ~= 0 then

        zChorded = true
        if panel.jump_section(jump) then OF.sounds.play(OF.sounds.MOVE) end
    end

    local slide = 0
    if padRepeated(R_JPAD) then slide = 1 end
    if padRepeated(L_JPAD) then slide = -1 end
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

    if not mousing and input.released(Z_TRIG) then

        local doing = current ~= nil and current.altAction or nil
        if not zChorded and doing ~= nil and zRow == panel.cursor then

            local ticked = not current.altPad and panel.has_box(current)
            OF.sounds.play(ticked and OF.sounds.TICK or OF.sounds.PICK)

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
        OF.sounds.play(sound)
        panel.run(current.action)
    elseif padPressed(B_BUTTON) then
        OF.sounds.play(OF.sounds.BACK)
        panel.back()
    elseif padPressed(START_BUTTON) then
        panel.close()
    end

    OF.input.claim(m, OF.input.PANEL_BUTTONS, OF.input.panel_stop())
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
        OF.util.chat("\\#ff6060\\" .. OF.lang.t("The mod menu's controls hit an error:")
            .. " " .. controllerFailure)
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

    local ok, err = pcall(render_panel)
    if ok then return end

    local drewPlain = false
    local plainOk = pcall(function() drewPlain = render_plainly() end)
    if plainOk and drewPlain then
        if not saidOnce.toldDraw then
            saidOnce.toldDraw = true

            local told = pcall(function()
                renderFailure = panel.short_reason(err)
                OF.util.chat("\\#ff6060\\" .. OF.lang.fill("oldfart's Lobby v@ - @",
                    tostring(OF.VERSION), OF.lang.t("The mod menu could not draw:"))
                    .. " " .. renderFailure)
                djui_chat_message_create("  \\#808080\\" .. tostring(err))
                djui_chat_message_create("  \\#808080\\"
                    .. OF.lang.t("Type /ofdiag for the full picture, and say what it shows."))
                OF.notify.show("The menu is in plain mode - the reason is in chat", "bad", 6)
            end)
            if not told then

                pcall(djui_chat_message_create,
                    "\\#ff6060\\" .. "oldfart" .. "'s Lobby v" .. tostring(OF.VERSION)
                    .. " - the menu is in plain mode: " .. tostring(err))
                pcall(djui_chat_message_create,
                    "\\#808080\\  Type /ofdiag and say what it shows.")
            end
        end
        return
    end

    renderFailure = panel.short_reason(err)
    if not saidOnce.toldDraw then
        saidOnce.toldDraw = true

        OF.util.chat("\\#ff6060\\" .. OF.lang.fill("oldfart's Lobby v@ - @",
            tostring(OF.VERSION), OF.lang.t("The mod menu could not draw:"))
            .. " " .. renderFailure)
        djui_chat_message_create("  \\#808080\\" .. tostring(err))
        djui_chat_message_create("  \\#808080\\"
            .. OF.lang.t("Type /ofdiag for the full picture, and say what it shows."))
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
            OF.util.chat("\\#ff6060\\" .. OF.lang.t(
                "Try: /menu reset, or /menu across 30."))
            return true
        end

        local percent = tonumber(rest)
        if percent == nil then
            OF.util.chat("\\#ff6060\\" .. OF.lang.t(
                "Give it a percentage, as in /menu across 30."))
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

hook_chat_command("bring", "- teleport a player to you", function(msg)
    if not OF.util.allowed("teleport_other") then return true end
    local target = OF.util.named_player(msg)
    if target == nil then return true end
    local np = gNetworkPlayers[target]

    local ok, why = OF.net.summon_player(target,
        network_global_index_from_local(0))
    OF.net.report_move(ok, why,
        OF.lang.fill("Summoned @.", OF.util.plain(np and np.name or "them")))
    return true
end)

hook_chat_command("bringall", "- teleport everyone to you", function()
    if not OF.util.allowed("teleport_other") then return true end
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 then
            table.insert(list, entry.np.globalIndex)
        end
    end
    if #list == 0 then
        OF.util.chat(OF.lang.t("There is nobody else here."))
        return true
    end
    OF.util.chat(OF.lang.fill("Summoned @ player(s).",
        tostring(OF.net.summon_many(list, network_global_index_from_local(0)))))
    return true
end)

hook_chat_command("go", "<place> - send the lobby somewhere, or 'me <place>' for just you",
    function(msg)
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
            OF.util.chat("\\#ff6060\\"
                .. OF.lang.fill("Nowhere called '@'.", wanted))
            return true
        end

        if entry.point ~= nil then
            if alone then
                OF.net.teleport_to_position(entry.point)
            else
                local ok, why = OF.net.send_everyone_to_position(entry.point)
                OF.net.report_move(ok, why,
                    OF.lang.fill("Sent everyone to @",
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
            OF.util.chat(OF.lang.fill("Loading @ for everyone.",
                OF.util.accent() .. entry.name .. "\\#dcdcdc\\"))
        end
        return true
    end)

hook_chat_command("tp", "- teleport yourself to a player", function(msg)
    if not OF.util.allowed("teleport_self") then return true end
    local target = OF.util.named_player(msg)
    if target == nil then return true end
    OF.net.teleport_to(network_global_index_from_local(target))
    return true
end)
