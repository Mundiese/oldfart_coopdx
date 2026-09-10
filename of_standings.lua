OF = OF or {}
OF.standings = OF.standings or {}

local standings = OF.standings

standings.KEY = "ofStandings"
local FIELD = "\31"
local POINTS_DIGITS = 2

local POINTS_MAX = 1295

local OFF_ID = "-"
local NAME_MAX = 12
local NAME_MIN = 6

standings.CURVES = {
    { key = "steep", id = "s", name = "steep",
      points = { 10, 6, 4, 3, 2, 1 }, tail = 0 },
    { key = "measured", id = "m", name = "measured",
      points = { 8, 6, 5, 4, 3, 2 }, tail = 1 },
    { key = "flat", id = "f", name = "flat",
      points = { 4, 3, 2 }, tail = 1 },
}

standings.BY_KEY = {}
standings.BY_ID = {}
for _, curve in ipairs(standings.CURVES) do
    standings.BY_KEY[curve.key] = curve
    standings.BY_ID[curve.id] = curve
end

standings.DEFAULT_CURVE = "measured"
standings.FINALES = {

    { key = "off", id = "o", name = "off", times = 1 },

    { key = "double", id = "d", name = "double", times = 2 },

    { key = "treble", id = "t", name = "treble", times = 3 },
}

standings.BY_FINALE = {}
standings.BY_FINALE_ID = {}
for _, step in ipairs(standings.FINALES) do
    standings.BY_FINALE[step.key] = step
    standings.BY_FINALE_ID[step.id] = step
end

standings.DEFAULT_FINALE = "double"
local keeping = true

local curveKey = standings.DEFAULT_CURVE

local finaleKey = standings.DEFAULT_FINALE
local finaleComing = false

local record = {}
local order = {}

local function board_name(name)
    name = OF.util.plain(tostring(name or ""))
    name = string.gsub(name, FIELD, "")
    return OF.util.short_name(name, NAME_MAX)
end

local function clamp_points(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then return 0 end
    if value > POINTS_MAX then return POINTS_MAX end
    return value
end

local function by_points(a, b)
    if a.points ~= b.points then return a.points > b.points end
    return a.name < b.name
end

local HELD_FALLBACK = 120

local function held_seconds()
    local held = nil
    if OF.gamemodes ~= nil then held = tonumber(OF.gamemodes.SEAT_SECONDS) end
    if held == nil or held <= 0 then return HELD_FALLBACK end
    return held
end

local function on_the_board()
    local here = {}
    local now = clock_elapsed()
    for _, entry in ipairs(OF.util.connected_players()) do
        local id = OF.util.player_id(entry.localIndex)
        if id ~= nil then
            here[id] = true
            local row = record[id]
            if row ~= nil then row.seen = now end
        end
    end

    local window = held_seconds()
    for id, row in pairs(record) do
        local seen = row.seen
        if here[id] == nil and seen ~= nil and now - seen < window then
            here[id] = true
        end
    end
    return here
end

function standings.curve_of(key)
    return standings.BY_KEY[key or ""] or standings.BY_KEY[standings.DEFAULT_CURVE]
end

function standings.points_for(place, key)
    place = math.floor(tonumber(place) or 0)
    if place < 1 then return 0 end

    local curve = standings.curve_of(key or standings.curve_key())
    return curve.points[place] or curve.tail
end

local function head_now()
    if not keeping then return OFF_ID end
    local step = standings.BY_FINALE[finaleKey]
        or standings.BY_FINALE[standings.DEFAULT_FINALE]
    local id = step.id
    if finaleComing and step.times > 1 then id = string.upper(id) end
    return standings.curve_of(curveKey).id .. id
end

local function packed_now()
    if not keeping then return OFF_ID end

    local list = {}

    local here = on_the_board()
    for _, id in ipairs(order) do
        local row = record[id]
        if row ~= nil and here[id] then
            list[#list + 1] = { name = board_name(row.called),
                                points = row.points }
        end
    end
    table.sort(list, by_points)

    local body = OF.util.pack_to_fit(list, function(entry, width)
        return OF.util.short_name(entry.name, width)
            .. OF.rules.to36(entry.points, POINTS_DIGITS)
    end, NAME_MAX, NAME_MIN, FIELD)

    local head = head_now()
    if body == "" then return head end
    return head .. FIELD .. body
end

local function wire()
    return gGlobalSyncTable[standings.KEY] or ""
end

function standings.is_on()
    if OF.util.is_host() then return keeping == true end
    return string.sub(wire(), 1, 1) ~= OFF_ID
end

function standings.curve_key()
    if OF.util.is_host() then return curveKey end
    local head = string.sub(wire(), 1, 1)
    local curve = standings.BY_ID[head]
    return curve ~= nil and curve.key or standings.DEFAULT_CURVE
end

function standings.curve_name(key)
    return standings.curve_of(key or standings.curve_key()).name
end

function standings.finale_of(key)
    return standings.BY_FINALE[key or ""]
        or standings.BY_FINALE[standings.DEFAULT_FINALE]
end

function standings.finale_key()
    if OF.util.is_host() then return finaleKey end
    local step = standings.BY_FINALE_ID[string.lower(string.sub(wire(), 2, 2))]
    return step ~= nil and step.key or standings.DEFAULT_FINALE
end

function standings.finale_name(key)
    return standings.finale_of(key or standings.finale_key()).name
end

function standings.finale_times(key)
    return standings.finale_of(key or standings.finale_key()).times
end

function standings.finale_coming()
    if not standings.is_on() then return false end
    if standings.finale_times() <= 1 then return false end
    if OF.util.is_host() then return finaleComing == true end
    local char = string.sub(wire(), 2, 2)
    return char ~= "" and char == string.upper(char)
        and char ~= string.lower(char)
end

function standings.board()
    local list = {}

    if OF.util.is_host() then
        if not keeping then return list end
        local here = on_the_board()
        for _, id in ipairs(order) do
            local row = record[id]
            if row ~= nil and here[id] then
                list[#list + 1] = { name = board_name(row.called),
                                    points = row.points, rounds = row.rounds }
            end
        end
        table.sort(list, by_points)
        return list
    end

    local packed = wire()
    if packed == "" then return list end

    local first = true
    for piece in string.gmatch(packed .. FIELD, "([^" .. FIELD .. "]*)" .. FIELD) do
        if first then

            first = false
        elseif #piece > POINTS_DIGITS then

            local name = OF.util.plain(string.sub(piece, 1, #piece - POINTS_DIGITS))
            local points = OF.rules.from36(string.sub(piece, -POINTS_DIGITS))
            if points ~= nil then
                list[#list + 1] = { name = name, points = points }
            end
        end
    end

    table.sort(list, by_points)
    return list
end

function standings.leader()
    local list = standings.board()
    if #list == 0 then return nil end
    if #list > 1 and list[2].points == list[1].points then return nil end
    return list[1]
end

function standings.total()
    local sum = 0
    for _, row in ipairs(standings.board()) do sum = sum + (row.points or 0) end
    return sum
end

function standings.count()
    return #standings.board()
end

local function publish()
    if not OF.util.is_host() then return false end
    OF.util.publish(standings.KEY, packed_now())
    return true
end

function standings.give(playerId, name, points)
    if not OF.util.is_host() then return 0 end
    if type(playerId) ~= "string" or playerId == "" then return 0 end

    local row = record[playerId]
    if row == nil then
        row = { called = name or playerId, points = 0, rounds = 0 }
        record[playerId] = row
        order[#order + 1] = playerId
    end

    if name ~= nil and name ~= "" then row.called = name end
    row.points = clamp_points(row.points + (tonumber(points) or 0))
    row.rounds = row.rounds + 1

    row.seen = clock_elapsed()
    return row.points
end

function standings.record()
    if not OF.util.is_host() then return 0 end
    if not keeping then return 0 end
    if not OF.util.asks(OF.gamemodes, "finishing_order") then return 0 end

    local board = OF.gamemodes.finishing_order()
    if #board == 0 then return 0 end

    local times = 1
    if OF.util.asks(OF.rounds, "in_finale") and OF.rounds.in_finale() then
        times = standings.finale_times()
    end

    local paid = 0
    for place, entry in ipairs(board) do
        local playerId = OF.util.player_id(entry.localIndex)
        if playerId ~= nil then
            standings.give(playerId, entry.name,
                standings.points_for(place) * times)
            paid = paid + 1
        end
    end

    if paid > 0 then publish() end
    return paid
end

function standings.set_on(want)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then return false, "Only the host can do that." end
    want = want == true
    if want == keeping then return false end
    keeping = want
    publish()
    return true
end

function standings.set_curve(key)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then return false, "Only the host can do that." end
    if standings.BY_KEY[key] == nil then return false, "No such points curve." end
    if key == curveKey then return false end
    curveKey = key

    publish()
    return true
end

function standings.cycle_curve()
    local at = 1

    local now = standings.curve_key()
    for index, curve in ipairs(standings.CURVES) do
        if curve.key == now then at = index break end
    end
    return standings.set_curve(standings.CURVES[at % #standings.CURVES + 1].key)
end

function standings.set_finale(key)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then return false, "Only the host can do that." end
    if standings.BY_FINALE[key] == nil then return false, "No such finale." end
    if key == finaleKey then return false end
    finaleKey = key

    publish()
    return true
end

function standings.cycle_finale()
    local at = 1
    local now = standings.finale_key()
    for index, step in ipairs(standings.FINALES) do
        if step.key == now then at = index break end
    end
    return standings.set_finale(standings.FINALES[at % #standings.FINALES + 1].key)
end

function standings.arm_finale(want)
    if not OF.util.is_host() then return false end
    want = want == true
    if want == finaleComing then return false end
    finaleComing = want
    publish()
    return true
end

function standings.clear()
    if not OF.util.is_host() then return false end
    local had = #order > 0
    record, order = {}, {}
    publish()
    return had
end

function standings.clear_here()
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then return false, "Only the host can do that." end
    if not standings.clear() then return false, "The standings are empty." end
    return true
end

function standings.snapshot()
    if not OF.util.is_host() then return nil end

    local snap = { keeping = keeping, curve = curveKey, finale = finaleKey,
                   order = {}, rows = {} }
    for index, id in ipairs(order) do
        snap.order[index] = id
        local row = record[id]
        snap.rows[id] = { called = row.called, points = row.points,
                          rounds = row.rounds }
    end
    return snap
end

function standings.restore(value)
    if not OF.util.is_host() then return false end
    if type(value) ~= "table" then return false end

    local had = #order > 0
    record, order = {}, {}
    for index, id in ipairs(value.order or {}) do
        local row = (value.rows or {})[id]
        if row ~= nil then
            order[index] = id
            record[id] = { called = row.called,
                           points = clamp_points(row.points),
                           rounds = math.floor(tonumber(row.rounds) or 0) }
        end
    end

    local want = value.keeping
    if want ~= nil then keeping = want == true end
    if value.curve ~= nil and standings.BY_KEY[value.curve] ~= nil then
        curveKey = value.curve
    end

    if value.finale ~= nil and standings.BY_FINALE[value.finale] ~= nil then
        finaleKey = value.finale
    end
    finaleComing = false
    publish()
    return had or #order > 0
end

local BOARD_X = 0.03
local BOARD_Y = 0.24

local function in_breather()
    if gGlobalSyncTable.ofQueueOn ~= true then return false end
    return OF.gamemodes.state() == OF.gamemodes.OFF
end

local function render()

    if not OF.util.asks(OF.gamemodes, "state") then return end
    if OF.gamemodes.state() ~= OF.gamemodes.RESULTS and not in_breather() then
        return
    end
    if not standings.is_on() then return end

    if OF.util.menu_has_screen() then return end

    local list = standings.board()

    if #list < 2 then return end

    local rows = {}
    for _, entry in ipairs(list) do
        rows[#rows + 1] = { name = entry.name, right = tostring(entry.points) }
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    OF.util.board(djui_hud_get_screen_width() * BOARD_X,
        djui_hud_get_screen_height() * BOARD_Y,
        OF.lang.t("Standings"), rows, { width = 180, column = 120 })
end

hook_event(HOOK_ON_HUD_RENDER, render)

function standings.ready()
    return true
end
