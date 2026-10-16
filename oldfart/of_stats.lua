OF = OF or {}
OF.stats = OF.stats or {}

local stats = OF.stats

local BOARD_SIZE = 16

local NIGHT_KEYS = { "ofBoardTonight", "ofBoardTonight2" }
stats.NIGHT_KEYS = NIGHT_KEYS

stats.BOARD_KEYS = { "ofBoardTonight", "ofBoardTonight2" }

local BOARD_CHUNK = 190

local PACK_NAME = 12
local PACK_NAME_MIN = 4

local PACK_BOARD_MAX = 9999

stats.session = stats.session or {}

stats.SESSION_CAP = 64
stats.SESSION_TRIM_AT = 0.90
stats.SESSION_TRIM_TO = 0.75
stats.SESSION_TOURNEY_AT = 0.85

local function session_now()
    if get_global_timer ~= nil then return get_global_timer() or 0 end
    return 0
end

function stats.session_rows()
    local n = 0
    for _ in pairs(stats.session) do n = n + 1 end
    return n
end

local function in_room()
    local here = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local coopnet, named = OF.util.player_identities(entry.localIndex)
        if coopnet ~= nil then here[coopnet] = true end
        if named ~= nil then here[named] = true end
    end
    return here
end

function stats.trim_session(target, keepId)
    target = math.max(0, math.floor(tonumber(target) or 0))
    local count = stats.session_rows()
    if count <= target then return 0 end
    local here = in_room()
    local gone = {}
    for playerId, row in pairs(stats.session) do
        if not here[playerId] and playerId ~= keepId then
            gone[#gone + 1] = { id = playerId, seen = row.seen or 0 }
        end
    end

    table.sort(gone, function(a, b)
        if a.seen ~= b.seen then return a.seen < b.seen end
        return a.id < b.id
    end)
    local dropped = 0
    for _, entry in ipairs(gone) do
        if count <= target then break end
        stats.session[entry.id] = nil
        if stats.streaks ~= nil then stats.streaks[entry.id] = nil end
        count = count - 1
        dropped = dropped + 1
    end
    return dropped
end

local function trim_floor()
    return math.floor(stats.SESSION_CAP * stats.SESSION_TRIM_TO)
end

function stats.keep_session_in_bounds(keepId)
    if stats.session_rows() < math.ceil(stats.SESSION_CAP * stats.SESSION_TRIM_AT) then
        return 0
    end
    return stats.trim_session(trim_floor(), keepId)
end

function stats.make_room_for_tournament()
    if stats.session_rows() < math.ceil(stats.SESSION_CAP * stats.SESSION_TOURNEY_AT) then
        return 0
    end
    return stats.trim_session(trim_floor())
end

local function session_row(playerId)
    local row = stats.session[playerId]
    if row == nil then

        if not stats.seenEnrolled and OF.util.asks(OF.util, "on_forget_seat") then
            stats.seenEnrolled = OF.util.on_forget_seat("stats.session_seen",
                stats.stamp_leaving)
        end
        row = { wins = 0, rounds = 0, playerName = "?", modes = {} }
        stats.session[playerId] = row

        stats.keep_session_in_bounds(playerId)
    end
    row.seen = session_now()
    return row
end

local function stamp_leaving(localIndex)
    local coopnet, named = OF.util.player_identities(localIndex)
    local now = session_now()
    for _, playerId in ipairs({ coopnet or false, named or false }) do
        if playerId and stats.session[playerId] ~= nil then
            stats.session[playerId].seen = now
        end
    end
end
stats.stamp_leaving = stamp_leaving

local function session_mode(row, modeKey)
    if row.modes[modeKey] == nil then
        row.modes[modeKey] = { rounds = 0, wins = 0, best = 0 }
    end
    return row.modes[modeKey]
end

local function note_name(row, np)
    if np ~= nil and np.name ~= nil and np.name ~= "" then
        row.playerName = OF.util.plain(np.name)
    end
end

stats.FAMILY_ORDER = { "chase", "survive", "collect", "hold", "other" }

stats.FAMILY_NAMES = {
    chase   = "Chases",
    survive = "Survival",
    collect = "Collecting",
    hold    = "Objectives",
    other   = "Other rounds",
}

stats.FAMILY_OF = {

    oneflag = "hold",

    shooter = "chase",
    bounty = "chase",     hideseek = "chase",
    manhunt = "chase",  murder = "chase",
    hotpotato = "chase",

    flood = "survive",    hexagone = "survive",

    copsandrobbers = "chase",
    rocketarena = "chase",

    wanted = "chase",

    rabbitchase = "collect",

    bombsort = "collect",

    flyguy = "collect",

    firesweep = "collect",

    snd = "hold",

    lakitu = "chase",

    onoffclimb = "collect",

    megarampage = "chase",

    shellbattle = "chase",
    assassins = "chase",
    zombies = "survive",  laststanding = "survive",
    spots = "survive",    simon = "survive",

    frenzy = "survive",
    line = "survive",     sumo = "survive",

    hexheat = "survive",

    glassbridge = "survive",

    logroll = "survive",

    coinrush = "collect", bank = "collect",

    silverfive = "collect",
    bossrush = "collect",

    shellrace = "collect",

    downhill = "collect",

    smash = "survive",

    bumperballs = "survive", chompfever = "survive",

    deflect = "survive",
    lavaleave = "survive",   bombsaway = "survive",
    hotrope   = "survive",
    booksquirm = "survive",
    blizzard = "survive",
    bombxing = "survive",
    blastgrid = "survive",

    blast = "other",

    prophunt = "chase",

    koth = "hold",        domination = "hold",
    ctf = "hold",         crown = "hold",

    football = "hold",

    volleyball = "hold",

    greendemon = "survive",

    oitc = "chase",

    hideballoon = "collect",

    sardines = "chase",

    turf = "hold",
}

function stats.family_of(modeKey)
    if modeKey == nil then return nil end
    return stats.FAMILY_OF[modeKey] or "other"
end

function stats.tonight()
    local list = {}
    for playerId, row in pairs(stats.session) do
        if (row.rounds or 0) > 0 or (row.wins or 0) > 0 then
            table.insert(list, { id = playerId, name = row.playerName,
                                 wins = row.wins, rounds = row.rounds })
        end
    end
    table.sort(list, function(a, b)
        if a.wins ~= b.wins then return a.wins > b.wins end
        if a.rounds ~= b.rounds then return a.rounds > b.rounds end
        return a.name < b.name
    end)
    return list
end

function stats.mode_board(modeKey)
    if modeKey == nil then return nil end
    if not OF.util.is_host() then return nil end

    local list = {}
    for playerId, row in pairs(stats.session) do
        local seat = row.modes ~= nil and row.modes[modeKey] or nil
        if seat ~= nil and ((seat.rounds or 0) > 0 or (seat.wins or 0) > 0) then
            table.insert(list, { id = playerId, name = row.playerName,
                                 wins = seat.wins or 0,
                                 rounds = seat.rounds or 0,
                                 best = seat.best or 0 })
        end
    end
    table.sort(list, function(a, b)
        if a.wins ~= b.wins then return a.wins > b.wins end
        if a.rounds ~= b.rounds then return a.rounds > b.rounds end
        if a.best ~= b.best then return a.best > b.best end
        return a.name < b.name
    end)
    return list
end

stats.MODE_BOARD_ROWS = 8

stats.streaks = stats.streaks or {}

stats.RUN_ENDED_AT = 3

stats.GIANT_RUN = 5

local function note_streak(localIndex, won)
    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return 0 end
    if not won then
        stats.streaks[playerId] = 0
        return 0
    end
    local run = (stats.streaks[playerId] or 0) + 1
    stats.streaks[playerId] = run
    return run
end

local function harvest_round()
    if not OF.util.asks(OF.gamemodes, "played") then return end
    local mode = OF.gamemodes.current()
    if mode == nil or mode.key == nil or mode.scoreIsTime then return end
    for _, entry in ipairs(OF.gamemodes.played()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local score = tonumber(row ~= nil and row.ofScore or 0) or 0

        if score == score and score > 0 then
            local playerId = OF.util.player_id(entry.localIndex)
            if playerId ~= nil then
                local seat = session_mode(session_row(playerId), mode.key)
                if math.floor(score) > seat.best then seat.best = math.floor(score) end
            end
        end
    end
end

function stats.record_round(winner)
    if not OF.util.is_host() then return end

    if OF.util.asks(OF.gamemodes, "is_waiting") and OF.gamemodes.is_waiting() then return nil end

    local teamKey, nameSet = nil, nil
    if type(winner) == "table" then
        teamKey = winner.team
        if winner.names ~= nil then
            nameSet = {}
            for _, name in ipairs(winner.names) do nameSet[name] = true end
        end
    end

    local mode = nil
    if OF.util.asks(OF.gamemodes, "current") then mode = OF.gamemodes.current() end

    local endedRun, endedName = nil, nil
    local enderIndex, winnerCount = nil, 0
    local onARun = nil

    for _, entry in ipairs(OF.gamemodes.participants()) do
        local won = false
        if teamKey ~= nil then
            won = OF.util.asks(OF.teams, "of") and OF.teams.of(entry.localIndex) == teamKey
        elseif nameSet ~= nil then
            won = nameSet[entry.np.name] == true
        elseif type(winner) == "string" and winner ~= "" then
            won = entry.np.name == winner
        end

        local playerId = OF.util.player_id(entry.localIndex)
        if playerId ~= nil then
            local row = session_row(playerId)
            note_name(row, entry.np)
            row.rounds = row.rounds + 1
            if won then row.wins = row.wins + 1 end
            if mode ~= nil and mode.key ~= nil then
                local seat = session_mode(row, mode.key)
                seat.rounds = seat.rounds + 1
                if won then seat.wins = seat.wins + 1 end
            end
            if won then
                winnerCount = winnerCount + 1
                enderIndex = entry.localIndex
            end

            local runBefore = stats.streaks[playerId] or 0
            local runNow = note_streak(entry.localIndex, won) or 0
            if won and runNow == stats.GIANT_RUN and onARun == nil then
                onARun = row.playerName
            end
            if not won and runBefore >= stats.RUN_ENDED_AT
                and runBefore > (endedRun or 0) then
                endedRun, endedName = runBefore, row.playerName
            end
        end
    end

    if onARun ~= nil and onARun ~= "" and onARun ~= "?" then
        OF.notify.send_all("@ has won @ in a row", "star", 7,
            onARun, stats.GIANT_RUN)
    end

    if endedRun ~= nil and endedName ~= nil and endedName ~= "" and endedName ~= "?" then
        local enderName = nil
        if winnerCount == 1 and enderIndex ~= nil then
            local enderId = OF.util.player_id(enderIndex)
            local row = enderId ~= nil and stats.session[enderId] or nil
            enderName = (row ~= nil and row.playerName) or nil
            local np = gNetworkPlayers[enderIndex]
            if (enderName == nil or enderName == "?") and np ~= nil
                and np.name ~= nil and np.name ~= "" then
                enderName = OF.util.plain(np.name)
            end
        end
        if enderName ~= nil and enderName ~= "" and enderName ~= "?" then
            OF.notify.send_all("@ ends @", "star", 7, enderName,
                OF.lang.fill("@'s run of @", endedName, endedRun))
        else

            OF.notify.send_all("@'s run of @ is over", "star", 7,
                endedName, endedRun)
        end
    end

    harvest_round()
    stats.publish()
end

function stats.record_race_win(localIndex)
    if not OF.util.is_host() then return end
    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return end
    local row = session_row(playerId)
    note_name(row, gNetworkPlayers[localIndex])
    row.wins = row.wins + 1
    stats.publish()
end

local function clean(name, most)
    name = OF.util.plain(tostring(name))
    name = string.gsub(name, "[|;]", "/")
    return OF.util.short_name(name, most or PACK_NAME)
end

local function board_number(value)
    value = tonumber(value) or 0
    if value ~= value then value = 0 end
    value = math.floor(value)
    if value < 0 then value = 0 end
    if value > PACK_BOARD_MAX then value = PACK_BOARD_MAX end
    return tostring(value)
end

local function pack_board(list)
    local wanted = {}
    for index, entry in ipairs(list) do
        if index > BOARD_SIZE then break end
        table.insert(wanted, entry)
    end
    return (OF.util.pack_to_keys(wanted, function(entry, width)
        return clean(entry.name, width) .. "|"
            .. board_number(entry.wins) .. "|" .. board_number(entry.rounds)
    end, PACK_NAME, PACK_NAME_MIN, ";", NIGHT_KEYS, BOARD_CHUNK))
end

function stats.packed_boards()
    local packed = {}
    local chunks = pack_board(stats.tonight())
    for index, chunkKey in ipairs(NIGHT_KEYS) do
        packed[chunkKey] = chunks[index] or ""
    end
    return packed
end

function stats.publish()
    if not OF.util.is_host() then return end
    local packed = stats.packed_boards()
    for _, boardKey in ipairs(stats.BOARD_KEYS) do
        OF.util.publish(boardKey, packed[boardKey])
    end
end

function stats.published_board(packed)
    if packed == nil then packed = OF.util.joined(NIGHT_KEYS) end
    if packed == nil or packed == "" then return {} end
    local list = {}
    for row in string.gmatch(packed, "[^;]+") do
        local name, wins, rounds = string.match(row, "^(.-)|(%d+)|(%d+)$")
        if name ~= nil then
            table.insert(list, { name = OF.util.plain(name),
                                 wins = tonumber(wins), rounds = tonumber(rounds) })
        end
    end
    return list
end

function stats.published_tonight()
    return stats.published_board(OF.util.joined(NIGHT_KEYS))
end

stats.FORM_ROUNDS = 5

function stats.form_board()
    local list = {}
    for _, entry in ipairs(stats.published_board()) do
        local rounds = entry.rounds or 0
        if rounds >= stats.FORM_ROUNDS then
            table.insert(list, { name = entry.name, wins = entry.wins or 0,
                                 rounds = rounds,
                                 rate = (entry.wins or 0) / rounds })
        end
    end
    table.sort(list, function(a, b)
        if a.rate ~= b.rate then return a.rate > b.rate end
        if a.rounds ~= b.rounds then return a.rounds > b.rounds end
        return a.name < b.name
    end)
    return list
end

function stats.ordinal(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then value = 0 end
    local suffix = "th"
    if value % 100 < 11 or value % 100 > 13 then
        local unit = value % 10
        if unit == 1 then suffix = "st"
        elseif unit == 2 then suffix = "nd"
        elseif unit == 3 then suffix = "rd" end
    end
    return string.format("%.0f", value) .. suffix
end

stats.LEFTOVER_PREFIXES = { "st_", "sp_", "sr_", "srl_", "stl_",
                            "pb_", "rc_", "rcn_", "ofbest_" }
stats.LEFTOVER_KEYS = { "of_rows", "ofKingId", "ofKingName", "cb_best",
                        "welcome_visits", "run_opts",

                        "gh_on", "gh_which", "gh_share" }

stats.LEFTOVERS_PER_FRAME = 1

local leftoverKey = {}
for _, key in ipairs(stats.LEFTOVER_KEYS) do leftoverKey[key] = true end

function stats.is_leftover(key)
    if type(key) ~= "string" then return false end
    if leftoverKey[key] then return true end
    for _, prefix in ipairs(stats.LEFTOVER_PREFIXES) do
        if string.sub(key, 1, #prefix) == prefix then return true end
    end
    return false
end

function stats.tidy_entries()
    local list = {}
    for key in pairs(mod_storage_load_all() or {}) do
        if stats.is_leftover(key) then list[#list + 1] = { keys = { key }, at = 0 } end
    end
    return list
end

stats.leftovers = nil
stats.leftoverAt = 1

function stats.find_leftovers()
    local list = {}
    local all = OF.util.stored_all()
    for key in pairs(all or {}) do
        if stats.is_leftover(key) then list[#list + 1] = key end
    end
    table.sort(list)
    stats.leftovers, stats.leftoverAt = list, 1
    return #list
end

local function sweep(most)
    local list = stats.leftovers
    if list == nil then return 0 end
    local removed = 0
    while removed < most and stats.leftoverAt <= #list do
        local key = list[stats.leftoverAt]
        stats.leftoverAt = stats.leftoverAt + 1
        if mod_storage_remove(key) then removed = removed + 1 end
    end
    if stats.leftoverAt > #list then stats.leftovers = nil end
    return removed
end

function stats.sweep_leftovers()
    return sweep(stats.LEFTOVERS_PER_FRAME)
end

function stats.make_room_now(limit)
    limit = math.floor(tonumber(limit) or 16)
    if limit < 1 then limit = 1 end
    if stats.leftovers == nil and not stats.leftoversRead then
        stats.leftoversRead = true
        stats.find_leftovers()
    end
    return sweep(limit)
end

local REFUSAL_EVERY = 150
stats.refusalCheckedAt = nil

function stats.on_refused_write()
    local frame = get_global_timer ~= nil and get_global_timer() or nil
    if frame ~= nil and stats.refusalCheckedAt ~= nil
        and (frame - stats.refusalCheckedAt) < REFUSAL_EVERY then
        return false
    end
    stats.refusalCheckedAt = frame
    return stats.make_room_now(16) > 0
end

hook_event(HOOK_ON_MODS_LOADED, function()
    stats.leftoversRead = true
    stats.find_leftovers()
end)

hook_event(HOOK_UPDATE, function()
    if stats.leftovers == nil then return end
    if OF.util.asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running() then return end
    stats.sweep_leftovers()
end)

function stats.ready()
    return true
end
