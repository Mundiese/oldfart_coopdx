OF = OF or {}
OF.tournament = OF.tournament or {}

local tournament = OF.tournament

tournament.KEY = "ofTourney"
tournament.BOARD_KEY = "ofTourBoard"
tournament.FORMATS = { "points", "stays", "ladder", "stocks", "matchpoint", "show" }
tournament.FORMAT_NAMES = {
    points = "points per place",
    stays = "winner stays",
    ladder = "arena ladder",
    stocks = "stock up",
    matchpoint = "match point",
    show = "elimination show",
}

tournament.FORMAT_HELP = {
    points = "every place pays; the last round pays double",
    stays = "win a round to take the seat; three in a row takes the title",
    ladder = "pairs down the table; the better placed of each moves up",
    stocks = "the first half earns lives, the second half costs them",
    matchpoint = "reach the target, then win a round to take it",
    show = "the bottom of the field is cut each round; one is left",
}
tournament.ROUNDS = { 5, 8, 10, 3 }
tournament.POOLS = { "all", "lined", "kinds" }
tournament.POOL_NAMES = { all = "every mode", lined = "the ones lined up",
    kinds = "kinds in turn" }
tournament.FINALES = { "any", "decider" }
tournament.FINALE_NAMES = { any = "any mode", decider = "a decider" }

tournament.DECIDERS = { "laststanding", "sumo", "hexagone", "deflect" }

tournament.STREAK = 3

tournament.MIN_PLAYERS = 2

tournament.RETRY_SECONDS = 5

tournament.SHOW_IN = 99

function tournament.match_target(curveKey, rounds)
    local win = OF.util.asks(OF.standings, "points_for")
        and OF.standings.points_for(1, curveKey) or 8
    return win * math.ceil((tonumber(rounds) or 5) / 2)
end

local VALUE_DIGITS = 2
local VALUE_MAX = 1295
local NAME_MAX = 12
local NAME_MIN = 6
local FIELD = "\31"
local setFormat, setRounds, setPool, setCurve = "points", 5, "all", "measured"
local setFinale = "any"
local running = false
local roundNo = 0
local roundsOf = 0
local format = "points"
local curve = "measured"
local pool = "all"
local lined = nil
local linedAt = 0
local rows = {}
local ladder = {}
local holder = nil
local streak = 0
local crowning = false
local lastKey = nil
local stalledSince = nil
local finale = "any"
local matchWinner = nil

local notOurs = false

local celebratedStamp = nil

local HEAD_PATTERN = "^([^" .. FIELD .. "]*)" .. FIELD .. "?(.*)$"
local STATE_PATTERN =
    "^(%S) (%a+) (%d+) (%d+) (%a+) (%a+) (%d+) (%a+)$"
local function fields()
    local out = { state = "-", fmt = "points", round = 0, of = 5,
        curve = "measured", pool = "all", stamp = 0, extra = "",
        finale = "any" }
    local text = gGlobalSyncTable[tournament.KEY]
    if type(text) ~= "string" then return out end
    local head, extra = string.match(text, HEAD_PATTERN)
    if head == nil then return out end
    local state, fmt, round, of, crv, pl, stamp, fin =
        string.match(head, STATE_PATTERN)
    if state == nil then return out end
    out.state = state
    if tournament.FORMAT_NAMES[fmt] ~= nil then out.fmt = fmt end
    out.round = tonumber(round) or 0
    out.of = tonumber(of) or 5
    out.curve = crv
    if tournament.POOL_NAMES[pl] ~= nil then out.pool = pl end
    out.stamp = tonumber(stamp) or 0
    out.extra = extra or ""
    if tournament.FINALE_NAMES[fin] ~= nil then out.finale = fin end
    return out
end

function tournament.state()
    return fields()
end

local function state_letter()
    local text = gGlobalSyncTable[tournament.KEY]
    if type(text) ~= "string" then return "-" end
    local head = string.match(text, HEAD_PATTERN)
    if head == nil then return "-" end
    return string.match(head, STATE_PATTERN) or "-"
end

function tournament.crowning()
    return crowning
end

local function publish_state(state, extra)

    if not OF.util.is_host() then return false end
    local now = fields()
    local stamp = now.stamp
    if state == "c" then stamp = (stamp % 9999) + 1 end

    local live = running or state == "c"
    local head = string.format("%s %s %.0f %.0f %s %s %.0f %s",
        state, live and format or setFormat, live and roundNo or 0,
        live and roundsOf or setRounds, live and curve or setCurve,
        live and pool or setPool, stamp, live and finale or setFinale)
    OF.util.publish(tournament.KEY, head .. FIELD .. (extra or ""))
end

local function row_for(id, name)
    local row = rows[id]
    if row == nil then
        row = { called = name or id, points = 0, places = {}, wins = 0,
            best = 0, stocks = 0, last = nil, cut = nil }
        rows[id] = row
    end
    if name ~= nil and name ~= "" then row.called = name end
    return row
end

local function present()
    local list, byId = {}, {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local id = OF.util.player_id(entry.localIndex)
        if id ~= nil and byId[id] == nil then
            local np = gNetworkPlayers[entry.localIndex]
            local item = { id = id, localIndex = entry.localIndex,
                name = np ~= nil and OF.util.plain(np.name) or id }
            byId[id] = item
            list[#list + 1] = item
        end
    end
    return list, byId
end

local function countback(a, b)
    for place = 1, 16 do
        local x, y = a.places[place] or 0, b.places[place] or 0
        if x ~= y then return x > y end
    end
    return nil
end

local function ordered()
    local list = {}
    if format == "ladder" then
        for seat, id in ipairs(ladder) do
            local row = rows[id]
            if row ~= nil then
                list[#list + 1] = { id = id, called = row.called,
                    value = math.floor((seat + 1) / 2), row = row }
            end
        end
        return list
    end
    for id, row in pairs(rows) do
        local value = row.points
        if format == "stays" then value = row.best end
        if format == "stocks" then value = row.stocks end

        if format == "show" then value = row.cut or tournament.SHOW_IN end
        list[#list + 1] = { id = id, called = row.called, value = value, row = row }
    end
    table.sort(list, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        if format == "show" then
            local x, y = a.row.last or 99, b.row.last or 99
            if x ~= y then return x < y end
        end
        if format == "points" or format == "matchpoint" then
            local cb = countback(a.row, b.row)
            if cb ~= nil then return cb end
        elseif format == "stays" then
            if a.row.wins ~= b.row.wins then return a.row.wins > b.row.wins end
            if (a.id == holder) ~= (b.id == holder) then return a.id == holder end
        elseif format == "stocks" then
            local x, y = a.row.last or 99, b.row.last or 99
            if x ~= y then return x < y end
        end
        return a.id < b.id
    end)
    return list
end

local function level(a, b)
    if a.value ~= b.value then return false end
    if format == "points" or format == "matchpoint" then
        return countback(a.row, b.row) == nil
    end
    if format == "show" then return (a.row.last or 99) == (b.row.last or 99) end
    if format == "stays" then
        return a.row.wins == b.row.wins and a.id ~= holder and b.id ~= holder
    end
    if format == "stocks" then return (a.row.last or 99) == (b.row.last or 99) end
    return false
end

local function publish_board()
    local list = ordered()
    local body = OF.util.pack_to_fit(list, function(entry, width)
        local value = math.max(0, math.min(VALUE_MAX, math.floor(entry.value)))
        return OF.util.short_name(string.gsub(entry.called, FIELD, ""), width)
            .. OF.rules.to36(value, VALUE_DIGITS)
    end, NAME_MAX, NAME_MIN, FIELD)
    OF.util.publish(tournament.BOARD_KEY, body)
end

function tournament.board()
    local list = {}
    local text = gGlobalSyncTable[tournament.BOARD_KEY]
    if type(text) ~= "string" or text == "" then return list end
    local fmt = fields().fmt
    for piece in string.gmatch(text .. FIELD, "([^" .. FIELD .. "]*)" .. FIELD) do
        if #piece > VALUE_DIGITS then
            local name = string.sub(piece, 1, #piece - VALUE_DIGITS)
            local value = OF.rules.from36(string.sub(piece, -VALUE_DIGITS)) or 0
            local right = tostring(value)
            if fmt == "ladder" then
                right = OF.lang.fill("arena @", tostring(value))
            elseif fmt == "stays" then
                right = OF.lang.fill("best run @", tostring(value))
            elseif fmt == "stocks" then
                right = value == 0 and OF.lang.t("out")
                    or OF.lang.fill("@ stocks", tostring(value))
            elseif fmt == "show" then
                right = value >= tournament.SHOW_IN and OF.lang.t("still in")
                    or OF.lang.fill("cut in round @", tostring(value))
            elseif fmt == "matchpoint" then
                local t = fields()
                if value >= tournament.match_target(t.curve, t.of) then
                    right = OF.lang.fill("@ - match point", tostring(value))
                end
            end
            list[#list + 1] = { name = name, right = right, value = value }
        end
    end
    return list
end

local crownSeenAt = nil
local FINAL_TABLE_SECONDS = 15

function tournament.showing_board()
    local state = state_letter()
    if state == "r" then
        local s = OF.gamemodes.state()
        return s == OF.gamemodes.RESULTS or s == OF.gamemodes.OFF
    end
    if state == "c" and crownSeenAt ~= nil then
        return clock_elapsed() - crownSeenAt < FINAL_TABLE_SECONDS
    end
    return false
end

function tournament.title()
    local t = fields()
    if t.state == "c" then return OF.lang.t("Tournament - final table") end
    return OF.lang.fill("Tournament - round @ of @", tostring(t.round),
        tostring(t.of))
end

local function gives_places(mode)
    return mode ~= nil and mode.teams ~= "always"
end

tournament.LONG_SECONDS = 300
function tournament.kind_turn(modes, lastKey)
    if #modes == 0 then return modes end
    local stats = OF.stats
    if not OF.util.asks(stats, "family_of") or stats.FAMILY_ORDER == nil then
        return modes
    end
    local order = stats.FAMILY_ORDER
    local lastFamily = lastKey ~= nil and stats.family_of(lastKey) or nil
    local at = 0
    for index, family in ipairs(order) do
        if family == lastFamily then at = index end
    end
    local picked = modes
    for step = 1, #order do
        local family = order[(at + step - 1) % #order + 1]
        local list = {}
        for _, mode in ipairs(modes) do
            if stats.family_of(mode.key) == family then list[#list + 1] = mode end
        end
        if #list > 0 then picked = list; break end
    end
    local last = lastKey ~= nil and OF.gamemodes.BY_KEY[lastKey] or nil
    if last ~= nil and (last.defaultLimit or 0) >= tournament.LONG_SECONDS then
        local short = {}
        for _, mode in ipairs(picked) do
            if (mode.defaultLimit or 0) < tournament.LONG_SECONDS then
                short[#short + 1] = mode
            end
        end
        if #short > 0 then picked = short end
    end
    return picked
end

local function last_round_next()
    if not OF.util.is_host() then return false end
    return roundNo + 1 >= roundsOf
end

local function deciders()
    local list = {}
    for _, key in ipairs(tournament.DECIDERS) do
        local mode = OF.gamemodes.BY_KEY[key]
        if mode ~= nil and gives_places(mode) and OF.gamemodes.can_start_here(mode) then
            list[#list + 1] = mode
        end
    end
    return list
end

local function next_entry()

    if (finale == "decider" or format == "show") and last_round_next() then
        local list = deciders()
        if #list > 0 then
            local mode = list[math.random(#list)]
            lastKey = mode.key
            local entry = { mode = mode.key }
            if OF.util.asks(OF.playlist, "with_map") then OF.playlist.with_map(entry) end
            return entry
        end
    end
    if pool == "lined" and lined ~= nil and #lined > 0 then
        for offset = 1, #lined do
            local at = (linedAt + offset - 1) % #lined + 1
            local entry = lined[at]
            local mode = OF.gamemodes.BY_KEY[entry.mode]
            if mode ~= nil and OF.gamemodes.can_start_here(mode) then
                linedAt = at
                return { mode = entry.mode, arena = entry.arena,
                    place = entry.place, mods = entry.mods }
            end
        end
        return nil
    end
    local able, again = {}, nil
    for _, mode in ipairs(OF.gamemodes.LIST) do
        if gives_places(mode) and OF.gamemodes.can_start_here(mode) then
            if mode.key ~= lastKey then able[#able + 1] = mode else again = mode end
        end
    end
    if #able == 0 and again ~= nil then able[1] = again end
    if #able == 0 then return nil end
    if pool == "kinds" then able = tournament.kind_turn(able, lastKey) end
    local mode = able[math.random(#able)]
    lastKey = mode.key
    local entry = { mode = mode.key }
    if OF.util.asks(OF.playlist, "with_map") then OF.playlist.with_map(entry) end
    return entry
end

local function queue_next()
    if #OF.rounds.queue > 0 then return true end
    local entry = next_entry()
    if entry == nil then return false end
    return OF.rounds.queue_entry(entry) == true
end

local function score_points(board, times)
    for place, entry in ipairs(board) do
        local id = OF.util.player_id(entry.localIndex)
        if id ~= nil then
            local row = row_for(id, entry.name)
            row.points = math.min(VALUE_MAX,
                row.points + OF.standings.points_for(place, curve) * times)
            row.places[place] = (row.places[place] or 0) + 1
            if place == 1 then row.wins = row.wins + 1 end
        end
    end
end

local function score_stays(board)
    local first = board[1]
    local id = first ~= nil and OF.util.player_id(first.localIndex) or nil

    if id == nil then return end
    local row = row_for(id, first.name)
    row.wins = row.wins + 1
    if holder == id then
        streak = streak + 1
    else
        holder, streak = id, 1
    end
    if streak > row.best then row.best = streak end
end

local function reseat(here, byId)
    local kept = {}
    for _, id in ipairs(ladder) do
        if byId[id] ~= nil then kept[#kept + 1] = id end
    end
    local seated = {}
    for _, id in ipairs(kept) do seated[id] = true end
    for _, item in ipairs(here) do
        if not seated[item.id] then
            kept[#kept + 1] = item.id
            row_for(item.id, item.name)
        end
    end
    ladder = kept
end

local function score_ladder(board)
    local here, byId = present()
    reseat(here, byId)

    local placeOf = {}
    for place, entry in ipairs(board) do
        local id = OF.util.player_id(entry.localIndex)
        if id ~= nil and placeOf[id] == nil then placeOf[id] = place end
    end

    local n = #ladder
    local full = math.floor(n / 2)
    if full == 0 then return end
    local winners, losers = {}, {}
    for a = 1, full do
        local up, down = ladder[2 * a - 1], ladder[2 * a]
        local pu, pd = placeOf[up] or 99, placeOf[down] or 99
        if pd < pu then up, down = down, up end
        winners[a], losers[a] = up, down
        local row = rows[up]
        if row ~= nil and pd ~= pu then row.wins = row.wins + 1 end
    end
    local waiting = (n % 2 == 1) and ladder[n] or nil

    local arenas = {}
    for a = 1, full do arenas[a] = {} end

    table.insert(arenas[1], winners[1])
    for a = 2, full do table.insert(arenas[a - 1], winners[a]) end
    for a = 1, full - 1 do table.insert(arenas[a + 1], 1, losers[a]) end
    local nextWaiting = nil
    if waiting ~= nil then
        table.insert(arenas[full], waiting)
        nextWaiting = losers[full]
    else
        table.insert(arenas[full], losers[full])
    end

    local seated = {}
    for a = 1, full do
        for _, id in ipairs(arenas[a]) do seated[#seated + 1] = id end
    end
    if nextWaiting ~= nil then seated[#seated + 1] = nextWaiting end
    ladder = seated
end

local function gathering()
    if not OF.util.is_host() then return false end
    return roundNo <= math.ceil(roundsOf / 2)
end

local function score_stocks(board)
    local _, byId = present()

    if gathering() then
        for _, item in ipairs(present()) do
            if rows[item.id] == nil then row_for(item.id, item.name).stocks = 1 end
        end
    end
    local half = math.max(1, math.ceil(#board / 2))
    if gathering() then
        for place, entry in ipairs(board) do
            local id = OF.util.player_id(entry.localIndex)
            if id ~= nil and rows[id] ~= nil then
                local row = rows[id]
                local earn = place == 1 and 3 or place == 2 and 2
                    or place <= half and 1 or 0
                row.stocks = math.min(VALUE_MAX, row.stocks + earn)
                row.last = place
            end
        end
        return
    end

    local alive, placeOf = {}, {}
    for id, row in pairs(rows) do
        if row.stocks > 0 and byId[id] ~= nil then alive[#alive + 1] = id end
    end
    local rank = 0
    for _, entry in ipairs(board) do
        local id = OF.util.player_id(entry.localIndex)
        if id ~= nil and rows[id] ~= nil and rows[id].stocks > 0 and placeOf[id] == nil then
            rank = rank + 1
            placeOf[id] = rank
            rows[id].last = rank
        end
    end
    local top = math.max(1, math.floor(#alive / 2))
    for _, id in ipairs(alive) do
        local p = placeOf[id]
        if p == nil or p > top then rows[id].stocks = rows[id].stocks - 1 end
    end
end

local function score_matchpoint(board)
    local first = board[1]
    local id = first ~= nil and OF.util.player_id(first.localIndex) or nil
    if id ~= nil and rows[id] ~= nil
        and rows[id].points >= tournament.match_target(curve, roundsOf) then
        matchWinner = id
    end
    score_points(board, 1)
end

local function score_show(board)
    if not OF.util.is_host() then return end
    local _, byId = present()
    local order, seen = {}, {}
    for _, entry in ipairs(board) do
        local id = OF.util.player_id(entry.localIndex)
        if id ~= nil and rows[id] ~= nil and rows[id].cut == nil
            and byId[id] ~= nil and not seen[id] then
            seen[id] = true
            order[#order + 1] = id
        end
    end
    local missing = {}
    for id, row in pairs(rows) do
        if row.cut == nil and not seen[id] then missing[#missing + 1] = id end
    end
    table.sort(missing)
    local alive = #order + #missing
    local left = math.max(1, roundsOf - roundNo + 1)
    local cut = math.max(1, math.ceil((alive - 1) / left))
    if alive <= 1 then cut = 0 end
    for place, id in ipairs(order) do rows[id].last = place end
    for _, id in ipairs(missing) do
        if cut > 0 then rows[id].cut = roundNo; cut = cut - 1 end
    end
    for place = #order, 2, -1 do
        if cut <= 0 then break end
        rows[order[place]].cut = roundNo
        cut = cut - 1
    end
end

local function show_left()
    local n = 0
    for _, row in pairs(rows) do
        if row.cut == nil then n = n + 1 end
    end
    return n
end

local function alive_count()
    local _, byId = present()
    local n = 0
    for id, row in pairs(rows) do
        if row.stocks > 0 and byId[id] ~= nil then n = n + 1 end
    end
    return n
end

local function decided_early()
    if format == "stays" then return streak >= tournament.STREAK end
    if format == "stocks" and not gathering() then return alive_count() <= 1 end
    if format == "matchpoint" then return matchWinner ~= nil end
    if format == "show" then return show_left() <= 1 end
    return false
end

function tournament.record()
    if not OF.util.is_host() then return false end
    if not running or crowning or notOurs then return false end
    if not OF.util.asks(OF.gamemodes, "finishing_order") then return false end

    local board = OF.gamemodes.finishing_order()
    roundNo = roundNo + 1

    if format == "points" then
        score_points(board, roundNo >= roundsOf and 2 or 1)
    elseif format == "stays" then
        score_stays(board)
    elseif format == "ladder" then
        score_ladder(board)
    elseif format == "matchpoint" then
        score_matchpoint(board)
    elseif format == "show" then
        score_show(board)
    else
        score_stocks(board)
    end

    publish_board()
    if roundNo >= roundsOf or decided_early() then
        crowning = true
        publish_state("r", "")
        return true
    end
    publish_state("r", format == "stays" and holder ~= nil
        and rows[holder] ~= nil and OF.util.plain(rows[holder].called) or "")
    queue_next()
    return true
end

local function the_champions()
    local _, byId = present()
    if format == "matchpoint" and matchWinner ~= nil and byId[matchWinner] ~= nil then
        return { byId[matchWinner] }
    end
    local list = {}
    for _, entry in ipairs(ordered()) do
        if byId[entry.id] ~= nil then list[#list + 1] = entry end
    end
    if #list == 0 then return {} end
    local out = { list[1] }
    for at = 2, #list do
        if format ~= "ladder" and level(list[1], list[at]) then
            out[#out + 1] = list[at]
        else
            break
        end
    end
    for index, entry in ipairs(out) do out[index] = byId[entry.id] end
    return out
end

local function crown()
    crowning = false
    running = false
    local winners = the_champions()
    local indexes, names = {}, {}
    for _, item in ipairs(winners) do
        local np = gNetworkPlayers[item.localIndex]
        if np ~= nil then indexes[#indexes + 1] = tostring(np.globalIndex) end
        names[#names + 1] = item.name
    end
    publish_state("c", table.concat(indexes, " "))

    if OF.util.asks(OF.rounds, "hand_back") then OF.rounds.hand_back() end

    local clock = OF.util.asks(OF.playlist, "always_on") and OF.playlist.always_on()
    if not clock and OF.rounds.is_running() then
        local stopped, why = OF.rounds.stop(true)
        if not stopped then
            OF.chatlog.add_system("the queue stayed on after the tournament: "
                .. tostring(why))
        end
    end

    if #names == 0 then
        OF.notify.send_all("The tournament is over - nobody is left to crown", "warn", 8)
    else
        OF.chatlog.add_system("tournament won by " .. table.concat(names, " & "))
    end
    if OF.util.asks(OF.music, "fanfare") then OF.music.fanfare("finish") end
    return true
end

local function celebrate_crown()

    if celebratedStamp ~= nil and state_letter() ~= "c" then return end
    local t = fields()

    if celebratedStamp == nil then
        celebratedStamp = t.stamp
        return
    end
    if t.state ~= "c" then return end
    if celebratedStamp == t.stamp then return end
    celebratedStamp = t.stamp
    crownSeenAt = clock_elapsed()
    local mine = gNetworkPlayers[0] ~= nil and tostring(gNetworkPlayers[0].globalIndex)
    for piece in string.gmatch(t.extra, "%d+") do
        local localIndex = OF.util.local_from_global(tonumber(piece))
        if localIndex ~= nil and OF.util.asks(OF.celebrate, "star_over") then
            OF.celebrate.star_over(localIndex)
        end
        if piece == mine and OF.util.asks(OF.celebrate, "win") then
            OF.celebrate.win()
        end
    end
end

local function read_lined_up()
    local set = {}
    for _, entry in ipairs(OF.rounds.queue or {}) do
        local mode = OF.gamemodes.BY_KEY[entry.mode]
        if entry.mode ~= OF.rounds.SURPRISE and gives_places(mode) then
            set[#set + 1] = { mode = entry.mode, arena = entry.arena,
                place = entry.place, mods = entry.mods }
        end
    end
    return set
end

function tournament.start(askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then return OF.net.host_does("tourstart") end
    if running then return false, "A tournament is already running." end
    if OF.rounds.is_lent() then return false, "The queue is playing somebody else's plan." end
    local here = present()
    if #here < tournament.MIN_PLAYERS then
        return false, "A tournament needs at least two players."
    end

    lined = nil
    if setPool == "lined" then
        lined = read_lined_up()
        if #lined == 0 then
            return false, "Line some modes up first, or pick every mode."
        end
    end

    if OF.util.asks(OF.stats, "make_room_for_tournament") then
        OF.stats.make_room_for_tournament()
    end
    if OF.util.asks(OF.util, "tidy_before_tournament") then
        OF.util.tidy_before_tournament()
    end

    running, crowning = true, false
    finale = setFinale
    matchWinner = nil

    notOurs = OF.gamemodes.state() ~= OF.gamemodes.OFF
    roundNo, roundsOf = 0, setRounds
    format, curve, pool = setFormat, setCurve, setPool
    linedAt, lastKey, stalledSince = 0, nil, nil
    rows, ladder, holder, streak = {}, {}, nil, 0
    for _, item in ipairs(here) do
        local row = row_for(item.id, item.name)
        if format == "stocks" then row.stocks = 1 end
    end
    if format == "ladder" then

        local seats = {}
        for _, item in ipairs(here) do seats[#seats + 1] = item.id end
        for i = #seats, 2, -1 do
            local j = math.random(i)
            seats[i], seats[j] = seats[j], seats[i]
        end
        ladder = seats
    end

    OF.rounds.take_over({})
    if not queue_next() then
        OF.rounds.hand_back()
        running = false
        return false, "Nothing here can be played right now."
    end
    publish_board()
    publish_state("r", "")

    local ok, why = true, nil
    if not OF.rounds.is_running() then ok, why = OF.rounds.start() end
    if not ok then
        OF.rounds.hand_back()
        running = false
        publish_state("-", "")
        return false, why
    end

    OF.notify.send_all("A tournament begins: @", "good", 8,
        OF.lang.fill("@ rounds, @", tostring(roundsOf),
            OF.lang.t(tournament.FORMAT_NAMES[format])))
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, OF.lang.t("started a tournament"))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal), OF.lang.t("started a tournament"))
    return true
end

function tournament.stop(askerLocal)
    if not OF.perms.can("end_round") then
        return false, "Your rank cannot do that.", "end_round"
    end
    if not OF.util.is_host() then return OF.net.host_does("tourend") end
    if not running then return false, "No tournament is running." end
    tournament.put(false)
    OF.notify.send_all("The tournament was called off", "warn", 6)
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, OF.lang.t("called the tournament off"))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.t("called the tournament off"))
    return true
end

function tournament.put(on)
    if not OF.util.is_host() then return false end
    if on == true or not running then return false end
    running, crowning = false, false
    publish_state("-", "")
    OF.util.publish(tournament.BOARD_KEY, "")
    if OF.rounds.is_lent() then OF.rounds.hand_back() end
    local clock = OF.util.asks(OF.playlist, "always_on") and OF.playlist.always_on()
    if not clock and OF.rounds.is_running() then
        local stopped, why = OF.rounds.stop(true)
        if not stopped then
            OF.chatlog.add_system("the queue stayed on after the tournament: "
                .. tostring(why))
        end
    end
    return true
end

function tournament.set_option(which, value)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local list = which == "format" and tournament.FORMATS
        or which == "rounds" and tournament.ROUNDS
        or which == "pool" and tournament.POOLS
        or which == "finale" and tournament.FINALES or nil
    if which == "curve" then
        list = {}
        for _, c in ipairs(OF.standings.CURVES) do list[#list + 1] = c.key end
    end
    if list == nil then return false, "No such setting." end
    local at = nil
    for index, stop in ipairs(list) do
        if stop == value then at = index end
    end
    if at == nil then return false, "No such setting." end
    if not OF.util.is_host() then
        local code = which == "format" and 1 or which == "rounds" and 2
            or which == "curve" and 3 or which == "pool" and 4
            or 5
        return OF.net.host_does("tourset", code, at)
    end
    if running then return false, "Not while a tournament is running." end
    if which == "format" then setFormat = value
    elseif which == "rounds" then setRounds = value
    elseif which == "curve" then setCurve = value
    elseif which == "finale" then setFinale = value
    else setPool = value end

    publish_state("-", "")
    OF.util.publish(tournament.BOARD_KEY, "")
    return true
end

function tournament.cycle(which)
    local t = fields()
    local list = which == "format" and tournament.FORMATS
        or which == "rounds" and tournament.ROUNDS
        or which == "pool" and tournament.POOLS
        or which == "finale" and tournament.FINALES or {}
    local now = which == "format" and t.fmt or which == "rounds" and t.of
        or which == "pool" and t.pool or which == "finale" and t.finale
        or t.curve
    if which == "curve" then
        for _, c in ipairs(OF.standings.CURVES) do list[#list + 1] = c.key end
    end
    local at = 1
    for index, stop in ipairs(list) do
        if stop == now then at = index end
    end
    return tournament.set_option(which, list[at % #list + 1])
end

function tournament.rows(panel)
    local out = {}
    local t = tournament.state()
    out[#out + 1] = panel.with_help(panel.header_row(OF.lang.t("Tournament")),
        "several rounds, one table across them, and a champion at the end")
    if t.state == "r" then
        out[#out + 1] = panel.label_row(OF.lang.fill("Round @ of @",
            tostring(math.min(t.round + 1, t.of)), tostring(t.of)))
        out[#out + 1] = panel.gated_confirm_row("end_round", "endtourney",
            OF.lang.t("Call the tournament off"), 255, 140, 90,
            function() OF.util.report(tournament.stop(0)) end)
        return out
    end
    out[#out + 1] = panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Start the tournament"), 140, 255, 160,
        function()
            if OF.util.report(tournament.start(0)) then panel.close() end
        end),
        "the lobby plays the rounds one after another, the table between them")
    out[#out + 1] = panel.with_right(panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Format"), 255, 255, 255,
        function() OF.util.report(tournament.cycle("format")) end),
        tournament.FORMAT_HELP[t.fmt]),
        OF.lang.t(tournament.FORMAT_NAMES[t.fmt]))
    out[#out + 1] = panel.with_right(panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Rounds"), 255, 255, 255,
        function() OF.util.report(tournament.cycle("rounds")) end),
        "how many the tournament plays, unless it is decided sooner"),
        tostring(t.of))
    if t.fmt == "points" then
        out[#out + 1] = panel.with_right(panel.with_help(panel.gated_row("speedrun",
            OF.lang.t("Points"), 255, 255, 255,
            function() OF.util.report(tournament.cycle("curve")) end),
            "what each place is worth, from a win-heavy table to an even one"),
            OF.lang.t(OF.standings.curve_name(t.curve)))
    end
    out[#out + 1] = panel.with_right(panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Modes played"), 255, 255, 255,
        function() OF.util.report(tournament.cycle("pool")) end),
        "which modes the rounds are drawn from, and in what order"),
        OF.lang.t(tournament.POOL_NAMES[t.pool]))
    out[#out + 1] = panel.with_right(panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Last round"), 255, 255, 255,
        function() OF.util.report(tournament.cycle("finale")) end),
        "whether the last round is one that names a single winner"),
        OF.lang.t(tournament.FINALE_NAMES[t.finale]))
    return out
end

local function host_update()
    if not OF.util.is_host() then return end
    if not running then return end
    if OF.gamemodes.state() ~= OF.gamemodes.OFF then
        stalledSince = nil
        return
    end
    notOurs = false
    if crowning then
        crown()
        return
    end

    if #OF.rounds.queue == 0 then queue_next() end
    if OF.rounds.is_running() then
        stalledSince = nil
        return
    end
    local now = clock_elapsed()
    if stalledSince == nil then stalledSince = now end
    if now - stalledSince < tournament.RETRY_SECONDS then return end
    stalledSince = now
    if #OF.gamemodes.participants() < tournament.MIN_PLAYERS then return end
    if #OF.rounds.queue == 0 then return end
    local ok, why = OF.rounds.start()
    if not ok then OF.chatlog.add_system("tournament round not started: " .. tostring(why)) end
end

local registered = false

local function register()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action("tourstart", "speedrun", function(asker)
        return tournament.start(asker)
    end)
    OF.net.register_action("tourend", "end_round", function(asker)
        return tournament.stop(asker)
    end)
    OF.net.register_action("tourset", "speedrun", function(_, code, at)
        local which = code == 1 and "format" or code == 2 and "rounds"
            or code == 3 and "curve" or code == 4 and "pool"
            or code == 5 and "finale" or nil
        local list = code == 1 and tournament.FORMATS
            or code == 2 and tournament.ROUNDS or code == 4 and tournament.POOLS
            or code == 5 and tournament.FINALES
        if code == 3 then
            list = {}
            for _, c in ipairs(OF.standings.CURVES) do list[#list + 1] = c.key end
        end
        local value = list ~= nil and list[tonumber(at) or 0] or nil
        if value == nil then return false, "No such setting." end
        return tournament.set_option(which, value)
    end)
end

hook_event(HOOK_UPDATE, function()
    register()
    celebrate_crown()
    host_update()
end)

local BOARD_X = 0.03
local BOARD_Y = 0.24

function tournament.final_line()
    local t = fields()
    if t.state ~= "c" then return "" end
    local names = {}
    for piece in string.gmatch(t.extra or "", "%d+") do
        local li = OF.util.local_from_global(tonumber(piece))
        local np = li ~= nil and gNetworkPlayers[li] or nil
        if np ~= nil and np.name ~= nil and np.name ~= "" then
            names[#names + 1] = OF.util.shorten(OF.util.plain(np.name), 20)
        end
    end
    if #names == 0 then return "" end
    return OF.lang.fill("@ won.", table.concat(names, " & "))
end

local function render()
    if not OF.util.asks(OF.gamemodes, "state") then return end
    if not tournament.showing_board() then return end
    if OF.util.menu_has_screen() then return end
    local list = tournament.board()
    if #list == 0 then return end
    local drawn = {}
    for _, entry in ipairs(list) do
        drawn[#drawn + 1] = { name = entry.name, right = entry.right }
    end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local screenWidth = djui_hud_get_screen_width()
    local bx, by = screenWidth * BOARD_X, djui_hud_get_screen_height() * BOARD_Y
    local opts = { width = 180, column = 120 }
    OF.util.board(bx, by, tournament.title(), drawn, opts)

    local line = tournament.final_line()
    if line ~= "" then
        local left = 0
        local x, _, w = OF.util.board_box(bx, by, tournament.title(), drawn, opts)
        left = x + w + 16
        local room = screenWidth - 2 * left
        if room < screenWidth * 0.4 then room = screenWidth - left end
        OF.util.final_headline(line,
            djui_hud_get_screen_height() * (OF.gamemodes.RESULTS_HEADLINE_AT or 0.32),
            nil, left, room)
    end
end

hook_event(HOOK_ON_HUD_RENDER, render)

function tournament.ready()
    return true
end
