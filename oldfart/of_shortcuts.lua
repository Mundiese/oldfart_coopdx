OF = OF or {}
OF.shortcuts = OF.shortcuts or {}

local sc = OF.shortcuts

sc.PINNED_KEY = "menu_pinned"
sc.RECENT_KEY = "menu_recent"
sc.MOST_PINNED = 8
sc.MOST_RECENT = 5

sc.PAGE = "players"
local SEP_ENTRY, SEP_FIELD = "\30", "\31"
local function decode(text)
    local out = {}
    for entry in string.gmatch(tostring(text or ""), "[^" .. SEP_ENTRY .. "]+") do
        local page, id, name = string.match(entry, "^([^\31]*)\31([^\31]*)\31(.*)$")
        if page ~= nil and page ~= "" and id ~= nil and id ~= "" then
            out[#out + 1] = { page = page, id = id, name = name ~= "" and name or id }
        end
    end
    return out
end

local function encode(list)
    local parts = {}
    for _, e in ipairs(list) do
        parts[#parts + 1] = table.concat({ e.page, e.id, e.name or "" }, SEP_FIELD)
    end
    return table.concat(parts, SEP_ENTRY)
end

local function load(key)
    if mod_storage_load == nil then return {} end
    return decode(mod_storage_load(key))
end

sc.pins = load(sc.PINNED_KEY)
sc.recent = load(sc.RECENT_KEY)

local function save(key, list)
    if OF.util ~= nil and type(OF.util.store) == "function" then
        if #list == 0 then
            if type(OF.util.clear) == "function" then OF.util.clear(key) end
        else
            OF.util.store(key, encode(list))
        end
    end
end

function sc.name_of(row)
    local text = OF.util.plain(tostring(row ~= nil and row.text or ""))
    text = text:gsub("^%s+", "")
    text = text:gsub("^Click again to confirm: ", "")
    for _ = 1, 3 do text = text:gsub("^%[[ xX%-]%]%s*", "") end
    text = text:gsub("^[%+%-]%s%s", "")
    text = text:gsub("%.%.%.$", "")
    return text
end

function sc.can_hold(page, row)
    if row == nil or row.shortcut or row.heading or row.notAShortcut then return false end
    if row.action == nil and row.altAction == nil then return false end

    if row.altPad then return false end
    local panel = OF.panel
    local id = panel ~= nil and type(panel.row_identity) == "function" and panel.row_identity(row) or nil
    if id == nil or string.sub(id, 1, 5) == "fold\31" then return false end
    local name = sc.name_of(row)
    if name == "" or name == "< Back" or string.find(name, "^<%s") then return false end
    return true, id, name
end

local function index_of(list, page, id)
    for i, e in ipairs(list) do
        if e.page == page and e.id == id then return i end
    end
    return nil
end

local function tell(text)
    if OF.notify ~= nil and type(OF.notify.show) == "function" then OF.notify.show(text, "info", 2) end
end

function sc.toggle_pin(page, row)
    if row ~= nil and row.shortcut and row.pinPage ~= nil then
        page, row = row.pinPage, { key = row.pinId, text = row.pinName, action = true }
    end
    local ok, id, name = sc.can_hold(page, row)
    if not ok then return nil end
    local at = index_of(sc.pins, page, id)
    local said
    if at ~= nil then
        table.remove(sc.pins, at)
        said = "unpin"
        tell(OF.lang.fill("Unpinned @", name))
    else
        if #sc.pins >= sc.MOST_PINNED then table.remove(sc.pins) end
        table.insert(sc.pins, 1, { page = page, id = id, name = name })
        said = "pin"
        tell(OF.lang.fill("Pinned @ to the top of Players", name))
    end
    save(sc.PINNED_KEY, sc.pins)
    if OF.panel ~= nil and type(OF.panel.mark_dirty) == "function" then OF.panel.mark_dirty() end
    if OF.hud ~= nil and type(OF.hud.sound) == "function" then OF.hud.sound("toggle") end
    return said
end

function sc.used(page, row)
    local ok, id, name = sc.can_hold(page, row)
    if not ok then return false end
    local at = index_of(sc.recent, page, id)
    if at == 1 then return true end
    if at ~= nil then table.remove(sc.recent, at) end
    table.insert(sc.recent, 1, { page = page, id = id, name = name })
    while #sc.recent > sc.MOST_RECENT do table.remove(sc.recent) end
    save(sc.RECENT_KEY, sc.recent)
    return true
end

function sc.go_to(entry)
    local panel = OF.panel
    if panel == nil or type(panel.go) ~= "function" then return false end
    panel.go(entry.page)
    if type(panel.rebuild) == "function" then panel.rebuild() end
    if type(panel.keep_cursor_on) == "function" then panel.keep_cursor_on(entry.id) end
    return true
end

function sc.path_of(page)
    local panel = OF.panel
    if panel == nil or type(panel.trail) ~= "function" then return "" end
    return table.concat(panel.trail(page) or {}, " > ")
end

local function shortcut_row(panel, entry)
    local built = panel.with_help(panel.with_right(
        panel.row(entry.name, 255, 255, 255, function() sc.go_to(entry) end),
        sc.path_of(entry.page)),
        OF.lang.t("takes you straight there, and Y unpins it"))
    built.shortcut = true
    built.key = "shortcut\31" .. entry.page .. "\31" .. entry.id
    built.pinPage, built.pinId, built.pinName = entry.page, entry.id, entry.name
    return built
end

function sc.rows(panel)
    local rows = {}
    local pinnedHeading = OF.lang.t("Pinned")
    local recentHeading = OF.lang.t("Recent")
    table.insert(rows, panel.with_help(panel.header_row(pinnedHeading),
        OF.lang.t("your favourite rows, one press away - only you see them")))
    if #sc.pins == 0 then
        local how = OF.input ~= nil and type(OF.input.device_says) == "function"
            and OF.input.device_says(OF.lang.t("Y (M on a keyboard)"), OF.lang.t("a middle click"))
            or OF.lang.t("Y")
        table.insert(rows, panel.label_row("   " .. OF.lang.fill("Press @ on any row to pin it here", how)))
    else
        for _, entry in ipairs(sc.pins) do table.insert(rows, shortcut_row(panel, entry)) end
    end
    if #sc.recent > 0 then
        table.insert(rows, panel.with_help(panel.header_row(recentHeading),
            OF.lang.t("the last rows you used, newest first")))
        for _, entry in ipairs(sc.recent) do table.insert(rows, shortcut_row(panel, entry)) end
    end
    return rows
end

function sc.forget()
    sc.pins, sc.recent = {}, {}
    return true
end
