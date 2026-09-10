OF = OF or {}
OF.sign = OF.sign or {}

local sign = OF.sign

local SIGN_KEY = "ofSign"
local FIELD = "|"
local MAX_TEXT = 40

local ROWS = 3

local DEFAULT_X = 50
local DEFAULT_Y = 12

local PAD = 10
local TITLE_SCALE = 0.95
local LINE_SCALE = 0.75

local SIZE_MIN = 50
local SIZE_MAX = 250
local DEFAULT_SIZE = 100

local draft = {
    on = false,
    title = "",
    rows = { "", "", "", "" },
    x = DEFAULT_X,
    y = DEFAULT_Y,
    size = DEFAULT_SIZE,
}

local function clamp_size(value)
    value = math.floor(tonumber(value) or DEFAULT_SIZE)
    if value < SIZE_MIN then return SIZE_MIN end
    if value > SIZE_MAX then return SIZE_MAX end
    return value
end
sign.SIZE_MIN = SIZE_MIN
sign.SIZE_MAX = SIZE_MAX
sign.DEFAULT_SIZE = DEFAULT_SIZE

local SIGN_PREFIX = "sign_"
local function remember()
    OF.util.store_bool(SIGN_PREFIX .. "on", draft.on)
    OF.util.store(SIGN_PREFIX .. "title", draft.title)
    for i = 1, ROWS do
        OF.util.store(SIGN_PREFIX .. "row" .. i, draft.rows[i])
    end
    OF.util.store_integer(SIGN_PREFIX .. "x", draft.x)
    OF.util.store_integer(SIGN_PREFIX .. "y", draft.y)
    OF.util.store_integer(SIGN_PREFIX .. "size", draft.size)
end

draft.on = mod_storage_load_bool(SIGN_PREFIX .. "on", false)
draft.title = mod_storage_load(SIGN_PREFIX .. "title", "")
for i = 1, ROWS do
    draft.rows[i] = mod_storage_load(SIGN_PREFIX .. "row" .. i, "")
end
draft.x = mod_storage_load_integer(SIGN_PREFIX .. "x", DEFAULT_X)
draft.y = mod_storage_load_integer(SIGN_PREFIX .. "y", DEFAULT_Y)

draft.size = clamp_size(mod_storage_load_integer(SIGN_PREFIX .. "size",
    DEFAULT_SIZE))

local function clean(text)
    text = tostring(text or "")
    text = string.gsub(text, "%" .. FIELD, "/")
    if OF.util ~= nil and type(OF.util.plain) == "function" then
        text = OF.util.plain(text)
    end
    if #text > MAX_TEXT then text = string.sub(text, 1, MAX_TEXT) end
    return text
end

local function clamp_percent(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

function sign.pack(state)
    local parts = { state.on and "1" or "0", clean(state.title) }
    for i = 1, ROWS do table.insert(parts, clean(state.rows[i])) end
    table.insert(parts, tostring(clamp_percent(state.x)))
    table.insert(parts, tostring(clamp_percent(state.y)))

    table.insert(parts, tostring(clamp_size(state.size)))
    return table.concat(parts, FIELD)
end

function sign.parse(packed)
    local state = { on = false, title = "", rows = {}, x = DEFAULT_X, y = DEFAULT_Y,
        size = DEFAULT_SIZE }
    for i = 1, ROWS do state.rows[i] = "" end
    if type(packed) ~= "string" or packed == "" then return state end

    local parts = {}
    for piece in string.gmatch(packed .. FIELD, "([^%" .. FIELD .. "]*)%" .. FIELD) do
        table.insert(parts, piece)
    end

    state.on = parts[1] == "1"
    state.title = clean(parts[2] or "")
    for i = 1, ROWS do state.rows[i] = clean(parts[2 + i] or "") end
    state.x = clamp_percent(parts[3 + ROWS] or DEFAULT_X)
    state.y = clamp_percent(parts[4 + ROWS] or DEFAULT_Y)
    state.size = clamp_size(parts[5 + ROWS] or DEFAULT_SIZE)
    return state
end

function sign.showing()
    local table_ = gGlobalSyncTable
    if table_ == nil then return sign.parse(nil) end
    return sign.parse(table_[SIGN_KEY])
end

function sign.on()
    return sign.showing().on
end

function sign.lines()
    local state = sign.showing()
    local out = {}
    for i = 1, ROWS do
        if state.rows[i] ~= "" then table.insert(out, state.rows[i]) end
    end
    return out
end

function sign.has_content()
    local state = sign.showing()
    if state.title ~= "" then return true end
    for i = 1, ROWS do
        if state.rows[i] ~= "" then return true end
    end
    return false
end

function sign.publish()
    if not OF.util.is_host() then return false, "Only the host puts up a sign." end
    OF.util.publish(SIGN_KEY, sign.pack(draft))
    return true
end

function sign.apply(change)
    local allowed, why = OF.util.allowed("message")
    if not allowed then
        return false, why or "Somebody of a higher rank puts the sign up."
    end
    if change ~= nil then change(draft) end
    draft.x = clamp_percent(draft.x)
    draft.y = clamp_percent(draft.y)
    remember()
    return sign.publish()
end

function sign.set_showing(value)
    return sign.apply(function(state) state.on = value and true or false end)
end

function sign.set_title(text)
    return sign.apply(function(state) state.title = clean(text) end)
end

function sign.set_row(index, text)
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > ROWS then
        return false, "The sign has three lines, numbered one to three."
    end
    return sign.apply(function(state) state.rows[index] = clean(text) end)
end

function sign.set_spot(x, y)
    return sign.apply(function(state)
        if x ~= nil then state.x = clamp_percent(x) end
        if y ~= nil then state.y = clamp_percent(y) end
    end)
end

function sign.set_size(value)
    return sign.apply(function(state)
        state.size = clamp_size(value)
    end)
end

function sign.size()
    if not sign.on() or not sign.has_content() then return nil end
    local width, height, lines = sign.measure()
    return width, height, #lines
end

local function text_width(lines)
    local widest = 0
    for _, line in ipairs(lines) do
        local w = OF.util.text_size(line.text, line.scale)
        if w > widest then widest = w end
    end
    return widest
end

local function fitted_factor(want, widest, height)
    if widest <= 0 or height <= 0 then return want end
    local screenW = djui_hud_get_screen_width()
    local screenH = djui_hud_get_screen_height()
    if type(screenW) ~= "number" or type(screenH) ~= "number" then return want end
    if screenW <= 0 or screenH <= 0 then return want end

    local roomW = (screenW - 8) / widest
    local roomH = (screenH - 8) / height
    local room = roomW
    if roomH < room then room = roomH end
    if room >= 1 then return want end
    return want * room
end

function sign.measure()
    local state = sign.showing()
    local factor = clamp_size(state.size) / 100

    local widest, height, lines = sign.lay_out(state, factor)
    local fitted = fitted_factor(factor, widest, height)
    if fitted < factor then
        widest, height, lines = sign.lay_out(state, fitted)
    end

    return widest, height, lines, state
end

function sign.lay_out(state, factor)
    local pad = PAD * factor
    local titleGap = 4 * factor
    local lineGap = 2 * factor
    local widest, height = 0, pad
    local lines = {}

    if state.title ~= "" then
        local scale = TITLE_SCALE * factor
        local w, h = OF.util.text_size(state.title, scale)
        if w > widest then widest = w end
        table.insert(lines, { text = state.title, scale = scale,
            height = h, gap = titleGap, title = true })
        height = height + h + titleGap
    end

    for i = 1, ROWS do
        if state.rows[i] ~= "" then
            local scale = LINE_SCALE * factor
            local w, h = OF.util.text_size(state.rows[i], scale)
            if w > widest then widest = w end
            table.insert(lines, { text = state.rows[i], scale = scale,
                height = h, gap = lineGap })
            height = height + h + lineGap
        end
    end

    return widest + pad * 2, height + pad - lineGap, lines, pad
end

local function render()
    if not sign.on() or not sign.has_content() then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    local width, height, lines, state = sign.measure()

    local screenW = djui_hud_get_screen_width()
    local screenH = djui_hud_get_screen_height()
    local x = (screenW - width) * (state.x / 100)
    local y = (screenH - height) * (state.y / 100)
    if x < 4 then x = 4 end
    if y < 4 then y = 4 end
    if x + width > screenW - 4 then x = screenW - width - 4 end
    if y + height > screenH - 4 then y = screenH - height - 4 end

    local gold = OF.util.gold()
    local edge = gold
    if OF.util.asks(OF.theme, "highlight") then
        local r, g, b = OF.theme.highlight()
        if r ~= nil then edge = { r = r, g = g, b = b } end
    end
    OF.util.plate(x, y, width, height, { edge = edge })

    local pad = (width - text_width(lines)) / 2

    local at = y + pad
    for _, line in ipairs(lines) do
        if line.title then
            OF.util.text(line.text, x + pad, at, line.scale,
                gold.r, gold.g, gold.b, 255)
        else
            OF.util.text(line.text, x + pad, at, line.scale, 220, 220, 220, 255)
        end
        at = at + line.height + (line.gap or 0)
    end
end

hook_event(HOOK_ON_HUD_RENDER, render)

local function publish_stored_sign(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not OF.util.is_host() then return end
    if not draft.on then return end
    sign.publish()
end

hook_event(HOOK_ON_PLAYER_CONNECTED, publish_stored_sign)

OF.util = OF.util or {}
OF.util.missing = OF.util.missing or {}

local HOST_ONLY = " (host only)"
local widgetIndexes = {}

local function write_rank()
    if not OF.util.asks(OF.perms, "can") then return true end
    return OF.perms.can("message") and true or false
end

local function write_suffix()
    if not OF.util.asks(OF.perms, "required")
        or not OF.util.asks(OF.perms, "tier_name") then
        return " (a higher rank)"
    end
    local name = OF.perms.tier_name(OF.perms.required("message"))
    if type(name) ~= "string" or name == "" then return " (a higher rank)" end
    return " (" .. name .. "+)"
end

local function register_widget(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then
        OF.util.missing[name] = true
        return nil
    end
    local ok, index = pcall(fn, ...)
    if ok and type(index) == "number" then return index end
    return nil
end

local function named_widget(write, name, ...)
    local index = register_widget(name, ...)
    if index ~= nil then
        table.insert(widgetIndexes,
            { index = index, name = (select(1, ...)), write = write })
    end
end

local function widget(name, ...)
    named_widget(false, name, ...)
end

local function write_widget(name, ...)
    named_widget(true, name, ...)
end

local function open_widget(name, ...)
    register_widget(name, ...)
end

local namedAsHost = nil
local namedAsWrite = nil

function sign.name_the_widgets()
    local host = OF.util.is_host()
    local written = write_rank() and "" or write_suffix()
    if namedAsHost == host and namedAsWrite == written then return false end
    local rename = _G["update_mod_menu_element_name"]
    if type(rename) ~= "function" then return false end
    namedAsHost, namedAsWrite = host, written
    for _, entry in ipairs(widgetIndexes) do
        local suffix = entry.write and written or (host and "" or HOST_ONLY)

        if #entry.name + #suffix < 64 then
            pcall(rename, entry.index, entry.name .. suffix)
        end
    end
    return true
end

local WRITE_LINES = 3

local WRITE_MAX = 24

local WRITE_DRAWS = "abcdefghijklmnopqrstuvwxyz"
    .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ',.-&!?~"
local WRITE_PREFIX = "signsay_"
local written = { on = false, lines = {} }

local function written_clean(text)
    text = tostring(text or "")
    if OF.util ~= nil and type(OF.util.plain) == "function" then
        text = OF.util.plain(text)
    end
    local out = {}
    for index = 1, #text do
        local ch = string.sub(text, index, index)
        if string.find(WRITE_DRAWS, ch, 1, true) ~= nil then
            table.insert(out, ch)
        end
    end
    return (string.match(table.concat(out), "^%s*(.-)%s*$"))
end

local function written_cut(text)
    return string.sub(written_clean(text), 1, WRITE_MAX)
end

for i = 1, WRITE_LINES do
    written.lines[i] = written_cut(mod_storage_load(WRITE_PREFIX .. i, ""))
end
written.on = mod_storage_load_bool(WRITE_PREFIX .. "on", false)

local function remember_written()
    OF.util.store_bool(WRITE_PREFIX .. "on", written.on)
    for i = 1, WRITE_LINES do
        OF.util.store(WRITE_PREFIX .. i, written.lines[i] or "")
    end
end

sign.WRITE_LINES = WRITE_LINES
sign.WRITE_MAX = WRITE_MAX

function sign.written_lines()
    local out = {}
    for i = 1, WRITE_LINES do
        local line = written.lines[i]
        if line ~= nil and line ~= "" then table.insert(out, line) end
    end
    return out
end

function sign.written_says()
    local lines = sign.written_lines()
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

function sign.written_row()
    return table.concat(sign.written_lines(), " / ")
end

function sign.written_on()
    return written.on == true
end

local function may_write()
    local allowed, why = OF.util.allowed("message")
    if not allowed then
        return false, why or "Somebody of a higher rank writes the boards."
    end
    return true
end

function sign.set_written_line(index, text)
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > WRITE_LINES then
        return false, "A signpost has three lines, numbered one to three."
    end
    local allowed, why = may_write()
    if not allowed then return false, why end
    local line = written_clean(text)

    if #line > WRITE_MAX then
        return false, "A signpost line is " .. WRITE_MAX .. " characters at most."
    end
    written.lines[index] = line
    remember_written()
    return true
end

function sign.set_written(on)
    local allowed, why = may_write()
    if not allowed then return false, why end
    written.on = on and true or false
    remember_written()
    return true
end

function sign.clear_written()
    local allowed, why = may_write()
    if not allowed then return false, why end
    for i = 1, WRITE_LINES do written.lines[i] = "" end
    remember_written()
    return true
end

for i = 1, WRITE_LINES do
    write_widget("hook_mod_menu_inputbox", "Signpost line " .. i,
        written.lines[i], WRITE_MAX, function(index, value)
            OF.util.report(sign.set_written_line(i, value))
        end)
end

write_widget("hook_mod_menu_checkbox", "Signposts say what you wrote",
    written.on, function(index, value)
        OF.util.report(sign.set_written(value))
    end)

write_widget("hook_mod_menu_button", "Clear what you wrote",
    function() OF.util.report(sign.clear_written()) end)

open_widget("hook_mod_menu_button", "Leave a signpost where I stand",
    function() OF.util.report(sign.ask_for_post()) end)

open_widget("hook_mod_menu_button", "Take my nearest signpost down",
    function() OF.util.report(sign.ask_to_take_post()) end)

widget("hook_mod_menu_button", "Clear this level's signposts", function()
    local np = gNetworkPlayers[0]
    if np == nil or not np.connected then
        OF.util.report(false, "You are not standing anywhere yet.")
        return
    end
    OF.util.report(sign.clear_posts(np.currLevelNum, np.currAreaIndex))
end)

widget("hook_mod_menu_checkbox", "Show the sign", draft.on,
    function(index, value)
        draft.on = value
        remember()
        OF.util.report(sign.apply(nil))
    end)

widget("hook_mod_menu_inputbox", "Sign title", draft.title, MAX_TEXT,
    function(index, value)
        OF.util.report(sign.set_title(value))
    end)

for i = 1, ROWS do
    widget("hook_mod_menu_inputbox", "Line " .. i, draft.rows[i], MAX_TEXT,
        function(index, value)
            OF.util.report(sign.set_row(i, value))
        end)
end

widget("hook_mod_menu_slider", "Sign across", draft.x, 0, 100,
    function(index, value)
        OF.util.report(sign.set_spot(value, nil))
    end)

widget("hook_mod_menu_slider", "Sign down", draft.y, 0, 100,
    function(index, value)
        OF.util.report(sign.set_spot(nil, value))
    end)

widget("hook_mod_menu_slider", "Sign size", draft.size, SIZE_MIN, SIZE_MAX,
    function(index, value)
        OF.util.report(sign.set_size(value))
    end)

hook_event(HOOK_UPDATE, sign.name_the_widgets)

local POST_KEYS = { "ofSignPosts", "ofSignPosts2" }
local POST_ON_KEY = "ofSignPostsOn"
local POST_CHUNK = 192

local SAID_KEYS = { "ofSignSaid", "ofSignSaid2" }

local SAID_CHUNK = 192

local SAID_FIELD = "|"
local SAID_END = ";"
sign.SAID_KEYS = SAID_KEYS
sign.SAID_CHUNK = SAID_CHUNK

sign.POST_SHAPES = {
    { say = "Try ~",              takes = "act" },
    { say = "~ ahead",            takes = "spot prize" },
    { say = "~ above",            takes = "spot prize" },
    { say = "~ below",            takes = "spot prize" },
    { say = "~ behind you",       takes = "spot prize" },
    { say = "Careful, ~",         takes = "spot mood" },
    { say = "Nothing here but ~", takes = "spot prize mood" },
    { say = "This way to ~",      takes = "spot prize" },
    { say = "Wrong way for ~",    takes = "prize" },
    { say = "Needs ~",            takes = "act mood" },
    { say = "Time for ~",         takes = "act mood" },
    { say = "Thanks for ~",       takes = "mood" },
}

sign.POST_THINGS = {
    { say = "a long jump",    kind = "act" },
    { say = "a wall kick",    kind = "act" },
    { say = "a ground pound", kind = "act" },
    { say = "a backflip",     kind = "act" },
    { say = "a dive",         kind = "act" },
    { say = "a triple jump",  kind = "act" },
    { say = "a run-up",       kind = "act" },
    { say = "a swim",         kind = "act" },
    { say = "a climb",        kind = "act" },
    { say = "a slide",        kind = "act" },

    { say = "a pit",          kind = "spot" },
    { say = "deep water",     kind = "spot" },
    { say = "the ledge",      kind = "spot" },
    { say = "the corner",     kind = "spot" },
    { say = "the wall",       kind = "spot" },
    { say = "quicksand",      kind = "spot" },
    { say = "lava",           kind = "spot" },
    { say = "the wind",       kind = "spot" },
    { say = "ice",            kind = "spot" },
    { say = "a shortcut",     kind = "spot" },
    { say = "the way back",   kind = "spot" },
    { say = "the long way",   kind = "spot" },
    { say = "a dead end",     kind = "spot" },
    { say = "the ceiling",    kind = "spot" },

    { say = "a star",         kind = "prize" },
    { say = "a red coin",     kind = "prize" },
    { say = "a cap",          kind = "prize" },
    { say = "a key",          kind = "prize" },
    { say = "a secret",       kind = "prize" },
    { say = "the coins",      kind = "prize" },
    { say = "a switch",       kind = "prize" },
    { say = "the door",       kind = "prize" },
    { say = "the top",        kind = "prize" },
    { say = "the exit",       kind = "prize" },

    { say = "trouble",        kind = "mood" },
    { say = "help",           kind = "mood" },
    { say = "company",        kind = "mood" },
    { say = "patience",       kind = "mood" },
    { say = "a laugh",        kind = "mood" },
    { say = "a mistake",      kind = "mood" },
    { say = "luck",           kind = "mood" },
    { say = "practice",       kind = "mood" },
}

local POST_STRIDE = #sign.POST_THINGS + 1

local SAID_BASE = (#sign.POST_SHAPES + 1) * POST_STRIDE

sign.SAID_BASE = SAID_BASE

local function said_pack(text)
    return (string.gsub(tostring(text or ""), "\n", SAID_FIELD)) .. SAID_END
end

local function said_text(piece)
    local lines = {}
    for line in string.gmatch(tostring(piece or "") .. SAID_FIELD,
        "([^%" .. SAID_FIELD .. "]*)%" .. SAID_FIELD) do
        line = written_cut(line)
        if line ~= "" then table.insert(lines, line) end

        if #lines >= WRITE_LINES then break end
    end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

function sign.said()
    local out = {}
    local text = OF.util.joined(SAID_KEYS)
    if type(text) ~= "string" or text == "" then return out end
    for piece in string.gmatch(text,
        "([^%" .. SAID_END .. "]*)%" .. SAID_END) do

        table.insert(out, said_text(piece) or false)
    end
    return out
end

local function shape_takes(shape, kind)
    if shape == nil or kind == nil then return false end
    return string.find(" " .. shape.takes .. " ", " " .. kind .. " ", 1, true) ~= nil
end

function sign.post_choices(shapeIndex)
    local out = {}
    local shape = sign.POST_SHAPES[shapeIndex]
    if shape == nil then return out end
    for index, thing in ipairs(sign.POST_THINGS) do
        if shape_takes(shape, thing.kind) then table.insert(out, index) end
    end
    return out
end

function sign.post_phrase_count()
    local total = 0
    for index = 1, #sign.POST_SHAPES do
        total = total + #sign.post_choices(index)
    end
    return total
end

function sign.post_id(shapeIndex, thingIndex)
    shapeIndex = math.floor(tonumber(shapeIndex) or 0)
    thingIndex = math.floor(tonumber(thingIndex) or 0)
    if sign.POST_SHAPES[shapeIndex] == nil then return 0 end
    if sign.POST_THINGS[thingIndex] == nil then return 0 end
    if not shape_takes(sign.POST_SHAPES[shapeIndex],
        sign.POST_THINGS[thingIndex].kind) then return 0 end
    return shapeIndex * POST_STRIDE + thingIndex
end

function sign.post_parts(id)
    id = math.floor(tonumber(id) or 0)
    if id <= 0 then return nil, nil end
    local shapeIndex = math.floor(id / POST_STRIDE)
    local thingIndex = id % POST_STRIDE
    local shape = sign.POST_SHAPES[shapeIndex]
    local thing = sign.POST_THINGS[thingIndex]
    if shape == nil or thing == nil then return nil, nil end
    if not shape_takes(shape, thing.kind) then return nil, nil end
    return shapeIndex, thingIndex
end

function sign.post_says(id, said)
    id = math.floor(tonumber(id) or 0)
    if id > SAID_BASE then
        local list = said or sign.said()
        local text = list[id - SAID_BASE]
        if type(text) ~= "string" or text == "" then return nil end
        return text
    end
    local shapeIndex, thingIndex = sign.post_parts(id)
    if shapeIndex == nil then return nil end
    return (string.gsub(sign.POST_SHAPES[shapeIndex].say, "~",
        sign.POST_THINGS[thingIndex].say))
end

local POST_STEP = 4
local POST_FIELDS = {
    { key = "level", width = 2 },
    { key = "area",  width = 1 },
    { key = "x",     width = 3, step = POST_STEP, bias = true },
    { key = "y",     width = 3, step = POST_STEP, bias = true },
    { key = "z",     width = 3, step = POST_STEP, bias = true },

    { key = "yaw",   width = 1 },
    { key = "say",   width = 2 },
    { key = "who",   width = 1 },
}

local POST_DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local POST_ENTRY = 0
for _, field in ipairs(POST_FIELDS) do
    POST_ENTRY = POST_ENTRY + field.width
end

local POST_MOST = #POST_KEYS * math.floor(POST_CHUNK / POST_ENTRY)

local POST_REACH = 400

sign.POST_MOST = POST_MOST
sign.POST_ENTRY = POST_ENTRY
sign.POST_KEYS = POST_KEYS
sign.POST_CHUNK = POST_CHUNK

local function post_span(width)

    return math.floor(36 ^ width + 0.5)
end

local function post_digits(value, width)
    local span = post_span(width)
    value = math.floor(tonumber(value) or 0)

    if value < 0 then value = 0 end
    if value > span - 1 then value = span - 1 end
    local out = ""
    for _ = 1, width do
        local digit = value % 36
        out = string.sub(POST_DIGITS, digit + 1, digit + 1) .. out
        value = math.floor(value / 36)
    end
    return out
end

local function post_number(text)
    if type(text) ~= "string" or text == "" then return nil end
    local value = 0
    for index = 1, #text do
        local at = string.find(POST_DIGITS, string.sub(text, index, index), 1, true)
        if at == nil then return nil end
        value = value * 36 + (at - 1)
    end
    return value
end

function sign.post_pack(post)
    local out = {}
    for _, field in ipairs(POST_FIELDS) do
        local value = tonumber(post[field.key]) or 0
        if field.step ~= nil then value = math.floor(value / field.step + 0.5) end
        if field.bias then value = value + math.floor(post_span(field.width) / 2) end
        table.insert(out, post_digits(value, field.width))
    end
    return table.concat(out)
end

function sign.post_unpack(text, said)
    if type(text) ~= "string" or #text ~= POST_ENTRY then return nil end
    local post, at = {}, 1
    for _, field in ipairs(POST_FIELDS) do
        local value = post_number(string.sub(text, at, at + field.width - 1))
        if value == nil then return nil end
        if field.bias then value = value - math.floor(post_span(field.width) / 2) end
        if field.step ~= nil then value = value * field.step end
        post[field.key] = value
        at = at + field.width
    end
    local says = sign.post_says(post.say, said)
    if says == nil then return nil end

    if post.say > SAID_BASE then post.wrote = says end
    return post
end

function sign.posts_on()
    if gGlobalSyncTable == nil then return true end
    local value = gGlobalSyncTable[POST_ON_KEY]
    if value == nil then return true end
    return value ~= false
end

function sign.set_posts_on(value)
    if not OF.util.is_host() then
        return false, "Only the host switches signposts off."
    end
    OF.util.publish(POST_ON_KEY, value and true or false)
    return true
end

function sign.posts()
    local text = OF.util.joined(POST_KEYS)
    local said = sign.said()
    local list = {}
    if type(text) ~= "string" then return list end
    local at = 1
    while at + POST_ENTRY - 1 <= #text do
        local post = sign.post_unpack(string.sub(text, at, at + POST_ENTRY - 1),
            said)

        if post ~= nil then table.insert(list, post) end
        at = at + POST_ENTRY
    end
    return list
end

function sign.posts_in(level, area)
    local out = {}
    if level == nil then return out end
    for _, post in ipairs(sign.posts()) do
        if post.level == level and post.area == area then
            table.insert(out, post)
            if #out >= POST_MOST then break end
        end
    end
    return out
end

local function post_here(localIndex)
    local np = gNetworkPlayers[localIndex]
    local m = gMarioStates[localIndex]
    if np == nil or not np.connected or m == nil or m.pos == nil then return nil end
    return np.currLevelNum, np.currAreaIndex, m
end

local function publish_posts(list)
    if not OF.util.is_host() then
        return false, "Only the host writes the lobby's signposts."
    end

    local said, parts = {}, {}
    for _, post in ipairs(list) do
        if type(post.wrote) == "string" and post.wrote ~= "" then
            local at = nil
            for index, entry in ipairs(said) do
                if entry == post.wrote then at = index end
            end
            if at == nil then
                table.insert(said, post.wrote)
                at = #said
            end
            post.say = SAID_BASE + at
        end
    end
    for _, entry in ipairs(said) do
        table.insert(parts, said_pack(entry))
    end

    local saidChunks = OF.util.chunk_parts(parts, SAID_CHUNK)
    if saidChunks == nil or #saidChunks > #SAID_KEYS then
        return false, "Too many written signposts to send."
    end

    parts = {}
    for _, post in ipairs(list) do
        table.insert(parts, sign.post_pack(post))
    end
    local chunks = OF.util.chunk_parts(parts, POST_CHUNK)

    if chunks == nil or #chunks > #POST_KEYS then
        return false, "Too many signposts to send."
    end
    local ok = true
    for index, key in ipairs(POST_KEYS) do

        if not OF.util.publish(key, chunks[index] or "") then ok = false end
    end

    for index, key in ipairs(SAID_KEYS) do
        if not OF.util.publish(key, saidChunks[index] or "") then ok = false end
    end
    return ok
end

function sign.leave_post(localIndex, id, text)
    if not OF.util.is_host() then
        return false, "Only the host writes the lobby's signposts."
    end
    if not sign.posts_on() then
        return false, "This lobby has signposts switched off."
    end
    if text ~= nil then
        if text == "" then return false, "Nothing is written on it yet." end

        local word = OF.util.asks(OF.filter, "blocks")
            and OF.filter.blocks(text) or nil
        if word ~= nil then
            return false, "The lobby filter will not have that word on a board."
        end
    elseif sign.post_says(id) == nil then
        return false, "That is not something a signpost can say."
    end

    local level, area, m = post_here(localIndex)
    if level == nil then return false, "That player is not anywhere yet." end
    local np = gNetworkPlayers[localIndex]

    local list = sign.posts()

    while #list >= POST_MOST do table.remove(list, 1) end

    table.insert(list, {
        level = level, area = area,
        x = m.pos.x, y = m.pos.y, z = m.pos.z,

        yaw = math.floor(((m.faceAngle.y + 0x8000) % 0x10000) / 0x10000 * 36) % 36,
        say = math.floor(tonumber(id) or 0),

        wrote = text,
        who = (np ~= nil and np.globalIndex) or 0,
    })
    return publish_posts(list)
end

function sign.take_post(localIndex)
    if not OF.util.is_host() then
        return false, "Only the host writes the lobby's signposts."
    end
    local level, area, m = post_here(localIndex)
    if level == nil then return false, "That player is not anywhere yet." end
    local np = gNetworkPlayers[localIndex]
    local who = (np ~= nil and np.globalIndex) or 0

    local list = sign.posts()
    local best, bestAway = nil, nil
    for index, post in ipairs(list) do
        if post.level == level and post.area == area and post.who == who then
            local dx, dz = post.x - m.pos.x, post.z - m.pos.z
            local away = math.sqrt(dx * dx + dz * dz)
            if away <= POST_REACH and (bestAway == nil or away < bestAway) then
                best, bestAway = index, away
            end
        end
    end
    if best == nil then return false, "None of your signposts is within reach." end
    table.remove(list, best)
    return publish_posts(list)
end

function sign.clear_posts(level, area)
    if not OF.util.is_host() then
        return false, "Only the host writes the lobby's signposts."
    end
    if level == nil then return publish_posts({}) end
    local kept = {}
    for _, post in ipairs(sign.posts()) do
        if post.level ~= level or post.area ~= area then
            table.insert(kept, post)
        end
    end
    return publish_posts(kept)
end

local myPosts = {}
local postsBuiltFor = nil
local postDialogs = {}
local postTick = 0

local POST_WATCH = 10

local function post_dialog(slot, text)
    if postDialogs[slot] == nil then
        local id = OF.util.optional("smlua_text_utils_allocate_dialog", nil)

        if type(id) ~= "number" or id < 0 then return nil end
        postDialogs[slot] = id
    end

    OF.util.optional("smlua_text_utils_dialog_replace", nil,
        postDialogs[slot], 1, 3, 30, 200, text)
    return postDialogs[slot]
end

local function drop_posts()
    for index, object in pairs(myPosts) do
        if OF.util.alive(object) then
            OF.util.optional("obj_mark_for_deletion", nil, object)
        end
        myPosts[index] = nil
    end
end

local function post_swept_away()
    local arena = OF.arena
    if not OF.util.asks(arena, "armed_set") then return false end
    if type(arena.OPTIONS) ~= "table" then return false end
    local armed = arena.armed_set()
    if type(armed) ~= "table" then return false end
    for _, option in ipairs(arena.OPTIONS) do
        if armed[option.key] then
            for _, behaviourId in ipairs(arena[option.list] or {}) do
                if behaviourId == id_bhvMessagePanel then return true end
            end
        end
    end
    return false
end

local function posts_wanted()
    if not sign.posts_on() then return nil end
    if post_swept_away() then return nil end
    local np = gNetworkPlayers[0]
    if np == nil or not np.connected then return nil end
    local out = tostring(np.currLevelNum) .. " " .. tostring(np.currAreaIndex)
    for _, key in ipairs(POST_KEYS) do
        local piece = gGlobalSyncTable[key]
        out = out .. " " .. (type(piece) == "string" and piece or "")
    end

    for _, key in ipairs(SAID_KEYS) do
        local piece = gGlobalSyncTable[key]
        out = out .. " " .. (type(piece) == "string" and piece or "")
    end
    return out
end

local function raise_posts()
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    local here = sign.posts_in(np.currLevelNum, np.currAreaIndex)
    local all = true

    for slot, post in ipairs(here) do
        local text = sign.post_says(post.say)
        if text ~= nil then
            local dialog = post_dialog(slot, text)

            local setup = function(o)
                o.oFaceAngleYaw = math.floor(post.yaw * 0x10000 / 36)
                o.oFaceAnglePitch = 0
                o.oFaceAngleRoll = 0
                o.oMoveAngleYaw = o.oFaceAngleYaw

                if dialog ~= nil then o.oBehParams2ndByte = dialog end
            end

            local object = OF.util.optional("spawn_non_sync_object", nil,
                id_bhvMessagePanel, E_MODEL_WOODEN_SIGNPOST,
                post.x, post.y, post.z, setup)
            if object == nil then
                all = false
            else
                table.insert(myPosts, object)
            end
        end
    end
    return all
end

function sign.post_frame()
    postTick = postTick + 1
    if postTick < POST_WATCH then return false end
    postTick = 0

    local want = posts_wanted()
    if want == postsBuiltFor then return false end

    drop_posts()
    if want == nil then
        postsBuiltFor = nil
        return true
    end

    if raise_posts() then postsBuiltFor = want else postsBuiltFor = nil end
    return true
end

hook_event(HOOK_UPDATE, sign.post_frame)

local postDraft = { shape = 1, thing = nil }

function sign.post_draft()
    local choices = sign.post_choices(postDraft.shape)
    if #choices == 0 then
        postDraft.shape = 1
        choices = sign.post_choices(postDraft.shape)
    end
    local at = nil
    for index, thing in ipairs(choices) do
        if thing == postDraft.thing then at = index end
    end
    if at == nil then
        at = 1
        postDraft.thing = choices[1]
    end
    return postDraft.shape, postDraft.thing, at, choices
end

local function step_within(at, count, step)
    if count <= 0 then return 1 end
    return ((at - 1 + step) % count) + 1
end

function sign.step_post_shape(step)
    postDraft.shape = step_within(postDraft.shape, #sign.POST_SHAPES, step or 1)

    postDraft.thing = nil
    sign.post_draft()
    return true
end

function sign.step_post_thing(step)
    local _, _, at, choices = sign.post_draft()
    postDraft.thing = choices[step_within(at, #choices, step or 1)]
    return true
end

function sign.post_draft_says()
    local shapeIndex, thingIndex = sign.post_draft()
    return sign.post_says(sign.post_id(shapeIndex, thingIndex))
end

function sign.ask_for_post()

    if sign.written_on() then
        local text = sign.written_says()
        if text == nil then return false, "Nothing is written on it yet." end
        if OF.util.is_host() then return sign.leave_post(0, 0, text) end
        if not OF.util.asks(OF.net, "host_does") then
            return false, "Only the host leaves a signpost in their own words."
        end
        return OF.net.host_does("signsay", nil, nil,
            (string.gsub(text, "\n", SAID_FIELD)))
    end
    local shapeIndex, thingIndex = sign.post_draft()
    local id = sign.post_id(shapeIndex, thingIndex)
    if id == 0 then return false, "That is not something a signpost can say." end
    if not OF.util.asks(OF.net, "host_does") then
        return sign.leave_post(0, id)
    end
    return OF.net.host_does("signpost", id)
end

function sign.ask_to_take_post()
    if not OF.util.asks(OF.net, "host_does") then return sign.take_post(0) end
    return OF.net.host_does("signdown")
end

function sign.build_posts_page(panel)
    local rows = {}
    local np = gNetworkPlayers[0]
    local level = np ~= nil and np.currLevelNum or nil
    local area = np ~= nil and np.currAreaIndex or nil
    local here = level ~= nil and sign.posts_in(level, area) or {}
    local on = sign.posts_on()

    table.insert(rows, panel.with_help(panel.level_right(
        panel.host_row("settings", panel.tick(on,
            OF.lang.t("Signposts players leave")), 255, 220, 120,
            function() OF.util.report(sign.set_posts_on(not on)) end),
        on, OF.lang.fill("@ up", tostring(#sign.posts()))),
        OF.lang.t("off takes every board down and lets nobody leave another")))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("What yours would say")),
        OF.lang.t("picked from a fixed list here, or typed in the Mod Menu")))

    local writing = sign.written_on()
    table.insert(rows, panel.with_help(panel.gated_row("message",
        panel.tick(writing, OF.lang.t("Say the words you wrote")),
        255, 220, 120,
        function() OF.util.report(sign.set_written(not writing)) end),
        OF.lang.t("the three lines are typed in the Mod Menu, on page two")))

    local shapeIndex, thingIndex, at, choices = sign.post_draft()
    local shape = sign.POST_SHAPES[shapeIndex]
    local thing = sign.POST_THINGS[thingIndex]

    table.insert(rows, panel.with_help(panel.with_slider(panel.with_right(
        panel.row(OF.lang.t("The shape"), 255, 220, 120,
            function() sign.step_post_shape(1) end),
        shape ~= nil and shape.say or ""),
        shapeIndex - 1, #sign.POST_SHAPES - 1,
        function(wanted) sign.step_post_shape(wanted + 1 - shapeIndex) end),
        OF.lang.t("the sentence, with a gap in it for the thing below")))

    table.insert(rows, panel.with_help(panel.with_slider(panel.with_right(
        panel.row(OF.lang.t("The thing"), 255, 220, 120,
            function() sign.step_post_thing(1) end),
        thing ~= nil and thing.say or ""),
        at - 1, math.max(#choices - 1, 0),
        function(wanted) sign.step_post_thing(wanted + 1 - at) end),
        OF.lang.t("only the ones that fit the shape above are offered")))

    local says = writing and sign.written_row() or (sign.post_draft_says() or "")
    table.insert(rows, panel.with_help(panel.with_walk(
        panel.label_row(says ~= "" and ("\"" .. says .. "\"")
            or OF.lang.t("Nothing is written on it yet"), 200, 200, 200)),
        OF.lang.t("what somebody walking up to it will read in the text box")))

    table.insert(rows, panel.with_help(panel.gated_row("chat",
        OF.lang.t("Leave it where you stand"), 140, 255, 160,
        function() OF.util.report(sign.ask_for_post()) end),
        OF.lang.t("a wooden board is planted at your feet for everybody")))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("The ones already up")),
        OF.lang.t("a board outlives whoever left it, and the lobby forgets the oldest")))

    table.insert(rows, panel.with_help(panel.with_walk(panel.with_right(
        panel.label_row(OF.lang.t("In this level")), tostring(#here))),
        OF.lang.t("how many are standing where you are, and nothing keeps "
            .. "them apart any more")))

    table.insert(rows, panel.with_help(panel.gated_row("chat",
        OF.lang.t("Take down your nearest one"), 255, 200, 120,
        function() OF.util.report(sign.ask_to_take_post()) end),
        OF.lang.t("only a board you left yourself, and only within a few steps")))

    table.insert(rows, panel.with_help(panel.host_row("settings",
        OF.lang.t("Clear this level's signposts"), 255, 140, 90,
        function() OF.util.report(sign.clear_posts(level, area)) end),
        OF.lang.t("every board where you are standing, whoever left it")))

    table.insert(rows, panel.with_help(panel.gated_confirm_row("settings",
        "clearposts", OF.lang.t("Clear every signpost in the lobby"),
        255, 140, 90,
        function() OF.util.report(sign.clear_posts(nil, nil)) end),
        OF.lang.t("the whole castle at once, which nothing puts back")))

    table.insert(rows, panel.back_row())
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_action") then

        OF.net.register_action("signpost", "chat", function(asker, x)
            return sign.leave_post(asker, tonumber(x))
        end)
        OF.net.register_action("signdown", "chat", function(asker)
            return sign.take_post(asker)
        end)

        OF.net.register_action("signsay", "message", function(asker, _, _, z)
            if not OF.util.is_host() then return false, "Only the host." end
            local text = said_text(z)
            if text == nil then return false, "Nothing is written on it yet." end
            return sign.leave_post(asker, 0, text)
        end)
    end

    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.signposts ~= nil then return end
    panel.PAGES.signposts = {
        title = "Signposts", tab = "room", up = "forge",
        build = function() return sign.build_posts_page(panel) end,
    }
end)

function sign.summary()
    local state = sign.showing()
    if not state.on or not sign.has_content() then return "no sign" end
    local count = #sign.lines()
    if state.title ~= "" then
        return state.title .. " (" .. count .. " line(s))"
    end
    return count .. " line(s)"
end
