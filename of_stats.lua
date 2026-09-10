OF = OF or {}
OF.stats = OF.stats or {}

local stats = OF.stats

local PREFIX = "st_"
local BOARD_SIZE = 16

local EXTRA_SIZE = 16

local HERE_KEYS = { "ofBoardHere", "ofBoardHere2", "ofBoardHere3",
                    "ofBoardHere4" }
stats.HERE_KEYS = HERE_KEYS

local HERE_CHUNK = 190

local TOP_KEYS = { "ofBoard", "ofBoard2" }
local NIGHT_KEYS = { "ofBoardTonight", "ofBoardTonight2" }
stats.TOP_KEYS = TOP_KEYS
stats.NIGHT_KEYS = NIGHT_KEYS

local BOARD_CHUNK = 190

local PACK_NAME = 12
local PACK_NAME_MIN = 4

local AWARD_SIZE = 8
local MODE_BOARD = 12

stats.session = stats.session or {}

stats.night = stats.night or { rounds = 0, modes = {}, moments = {} }

local houseTold = {}
local houseWas = {}

function stats.forget_night_log()
    stats.night = { rounds = 0, modes = {}, moments = {} }

    houseTold = {}
    houseWas = {}
end

local function session_row(playerId)
    if stats.session[playerId] == nil then
        stats.session[playerId] = { wins = 0, rounds = 0, playerName = "?",
                                    modes = {}, run = 0,
                                    newTonight = stats.newcomers[playerId] == true,
                                    arrived = OF.util.optional("get_global_timer", 0) or 0 }
    end
    return stats.session[playerId]
end

local function session_mode(row, modeKey)
    if row.modes[modeKey] == nil then
        row.modes[modeKey] = { rounds = 0, wins = 0, best = 0 }
    end
    return row.modes[modeKey]
end

stats.FIELDS = {
    { key = "wins",    id = "w",  label = "Wins",             board = true, record = true },
    { key = "rounds",  id = "r",  label = "Rounds played",    board = true, record = true },

    { key = "points",  id = "pt", label = "Points scored",    record = true },
    { key = "best",    id = "bs", label = "Best round",       record = true, most = true },
    { key = "mvp",     id = "mv", label = "Rounds top-scored", record = true },
    { key = "podium",  id = "pd", label = "Podium finishes",  record = true },
    { key = "streak",  id = "sk", label = "Best win streak",  record = true, most = true },

    { key = "bestnight", id = "bn", label = "Best session", record = true, most = true },
    { key = "races",   id = "ra", label = "Races won",        record = true },
    { key = "stars",   id = "st", label = "Race stars taken", record = true },

    { key = "nights",  id = "ni", label = "Sessions here" },
    { key = "minutes", id = "mi", label = "Minutes played" },
    { key = "seen",    id = "se", label = "Last here", most = true, date = true },

    { key = "lastwin", id = "lw", label = "Last win", most = true, date = true },

    { key = "frozen",  id = "fz", label = "Times caught" },
}

stats.FIELD_OF = {}
for _, field in ipairs(stats.FIELDS) do stats.FIELD_OF[field.key] = field end

local LOBBY_ID = "lobby"
local MODE_ID = "md"
local function is_identity(playerId)
    if playerId == nil or playerId == "" then return false end
    if playerId == LOBBY_ID then return false end
    if playerId == MODE_ID then return false end
    if string.sub(playerId, 1, #MODE_ID + 1) == MODE_ID .. "_" then return false end
    return true
end

local function storage_key(playerId, field)
    return PREFIX .. OF.util.storage_escape(playerId) .. "_" .. field
end

local ROW_PREFIX = "sp_"
local OLD_ROW_PREFIX = "sr_"
local OLD_LIFE_ROW_PREFIX = "srl_"
local OLD_LIFE_PREFIX = "stl_"
local ROW_SPLIT = "|"
local ROW_PAIR = ":"
local ROW_NAME = "~"
local ROW_ORDER = {}
local ROW_ID = {}
local ROW_FIELD = {}
for _, field in ipairs(stats.FIELDS) do
    ROW_ID[field.key] = field.id
    ROW_FIELD[field.id] = field.key
    table.insert(ROW_ORDER, field.key)
end
ROW_ID["medals"] = "me"
ROW_FIELD["me"] = "medals"
table.insert(ROW_ORDER, "medals")

local function row_key(playerId)
    return ROW_PREFIX .. OF.util.storage_escape(playerId)
end

local function unpack_row(text)
    local row = {}
    if text == nil or text == "" then return row end
    local head, name = text, nil

    if string.sub(text, 1, 1) == ROW_NAME then
        head, name = "", string.sub(text, 2)
    else
        local at = string.find(text, ROW_SPLIT .. ROW_NAME, 1, true)
        if at ~= nil then
            head, name = string.sub(text, 1, at - 1), string.sub(text, at + 2)
        end
    end

    for piece in string.gmatch(head, "[^|]+") do
        local short, value = string.match(piece, "^(%a+):(%-?%d+)$")
        local field = short ~= nil and ROW_FIELD[short] or nil
        if field ~= nil then row[field] = math.floor(tonumber(value) or 0) end
    end
    if name ~= nil and name ~= "" then row.name = name end
    return row
end

local function pack_row(row)
    local out = {}
    for _, field in ipairs(ROW_ORDER) do
        local value = tonumber(row[field])
        if value ~= nil and value == value and math.floor(value) ~= 0 then

            table.insert(out, ROW_ID[field] .. ROW_PAIR
                .. string.format("%.0f", math.floor(value)))
        end
    end
    local text = table.concat(out, ROW_SPLIT)
    if row.name ~= nil and row.name ~= "" then
        if text ~= "" then text = text .. ROW_SPLIT end
        text = text .. ROW_NAME .. row.name
    end
    return text
end

local rowsDone = false

local function old_row(playerId)
    local row = {}
    local escaped = OF.util.storage_escape(playerId)
    for _, field in ipairs(ROW_ORDER) do
        for _, prefix in ipairs({ PREFIX, OLD_LIFE_PREFIX }) do
            local value = OF.util.stored_integer(
                prefix .. escaped .. "_" .. field, 0) or 0
            if value ~= 0 then row[field] = value end
        end
    end
    for _, prefix in ipairs({ PREFIX, OLD_LIFE_PREFIX }) do
        local name = OF.util.stored(prefix .. escaped .. "_name", "")
        if name ~= nil and name ~= "" then row.name = name end
    end
    for _, prefix in ipairs({ OLD_ROW_PREFIX, OLD_LIFE_ROW_PREFIX }) do
        for field, value in pairs(unpack_row(OF.util.stored(prefix .. escaped, ""))) do
            row[field] = value
        end
    end
    return row
end

local function row_of(playerId)
    local key = row_key(playerId)
    local text = OF.util.stored(key, "")
    if text ~= nil and text ~= "" then return unpack_row(text), key end
    if rowsDone then return {}, key end
    return old_row(playerId), key
end

local function store_row_field(playerId, field, value, soon)

    if not is_identity(playerId) then
        if soon then
            return OF.util.store_soon_integer(
                storage_key(playerId, field), value)
        end
        return OF.util.store_integer(storage_key(playerId, field), value)
    end
    local row, key = row_of(playerId)
    row[field] = math.floor(tonumber(value) or 0)
    local text = pack_row(row)
    if soon then return OF.util.store_soon(key, text) end
    return OF.util.store(key, text)
end

local function store_row_name(playerId, name)
    if not is_identity(playerId) then
        return OF.util.store_soon(storage_key(playerId, "name"), name)
    end
    local row, key = row_of(playerId)
    if row.name == name then return true end
    row.name = name
    return OF.util.store_soon(key, pack_row(row))
end

function stats.get(playerId, field)
    if playerId == nil then return 0 end
    if not is_identity(playerId) then
        return OF.util.stored_integer(storage_key(playerId, field), 0)
    end
    local row = row_of(playerId)
    return math.floor(tonumber(row[field]) or 0)
end

function stats.name_of(playerId)
    if playerId == nil then return "?" end
    if not is_identity(playerId) then
        return OF.util.stored(storage_key(playerId, "name"), "?")
    end
    local row = row_of(playerId)
    if row.name == nil or row.name == "" then return "?" end
    return row.name
end

stats.HONOURS = {
    { key = "breaker", label = "Record breaker",
      note = "Took a mode's house record off somebody who held it" },
    { key = "giant", label = "Giant killer",
      note = "Ended somebody's run of five or more" },
    { key = "back", label = "The long way back",
      note = "Won again after three weeks of not winning" },
    { key = "allnight", label = "Every round of the session",
      note = "Played every round of a session of ten or more" },
}

stats.HONOUR_AT = {}
for index, one in ipairs(stats.HONOURS) do stats.HONOUR_AT[one.key] = index end

local CASE_SPAN = 244140625
stats.CASE_SPAN = CASE_SPAN

local function honour_bits(value)
    value = tonumber(value) or 0
    if value ~= value or value < 0 then value = 0 end
    return math.floor(math.floor(value) / CASE_SPAN)
end

function stats.held_honours(playerId)
    local bits = honour_bits(stats.get(playerId, "medals"))
    local held = {}
    for index = 1, #stats.HONOURS do
        held[index] = (bits % 2) == 1
        bits = math.floor(bits / 2)
    end
    return held
end

function stats.win_honour(localIndex, key)
    if not OF.util.is_host() then return false end
    local index = stats.HONOUR_AT[key]
    if index == nil then return false end
    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return false end

    local raw = tonumber(stats.get(playerId, "medals")) or 0
    if raw ~= raw or raw < 0 then raw = 0 end
    raw = math.floor(raw)

    local bits = honour_bits(raw)
    local step = 1
    for _ = 2, index do step = step * 2 end
    if math.floor(bits / step) % 2 == 1 then return false end

    local below = raw % CASE_SPAN
    if not store_row_field(playerId, "medals",
            below + (bits + step) * CASE_SPAN, false) then
        return false
    end
    stats.mark_standing()

    if not stats.long_game() then return true end

    local globalIndex = network_global_index_from_local(localIndex)
    if localIndex ~= 0 then
        if not OF.util.asks(OF.pass, "confirmed") then return true end
        if not OF.pass.confirmed(globalIndex) then return true end
    end

    OF.notify.send_to(globalIndex, "Title earned - @", "star", nil,
        stats.HONOURS[index].label)
    return true
end

function stats.titles_held(standing)
    local list = {}
    if standing == nil or standing.honours == nil then return list end
    for index, one in ipairs(stats.HONOURS) do
        if standing.honours[index] == true then table.insert(list, one) end
    end
    return list
end

function stats.long_game()
    if not OF.util.is_host() then return false end
    return stats.get(LOBBY_ID, "longgame") == 0
end

function stats.set_long_game(on)
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    if not OF.util.is_host() then
        return false, "Only the host keeps the record, so only the host can switch this."
    end
    if not OF.util.store_integer(storage_key(LOBBY_ID, "longgame"), on and 0 or 1) then
        return false, "That could not be saved."
    end
    stats.send_standings()
    return true
end

stats.WIN_SHARE_ROUNDS = 20

stats.WIN_SHARE_FLOOR = 5

stats.SHARE_MIN_PLAYERS = 3

stats.FAMILY_ORDER = { "chase", "survive", "collect", "hold", "other" }

stats.FAMILY_NAMES = {
    chase   = "Chases",
    survive = "Survival",
    collect = "Collecting",
    hold    = "Objectives",
    other   = "Other rounds",
}

stats.FAMILY_OF = {

    bounty = "chase",     hideseek = "chase",
    manhunt = "chase",  murder = "chase",
    hotpotato = "chase",

    flood = "survive",    hexagone = "survive",
    zombies = "survive",  laststanding = "survive",
    spots = "survive",    simon = "survive",
    line = "survive",     sumo = "survive",

    hexheat = "survive",

    logroll = "survive",

    coinrush = "collect", bank = "collect",   secretrun = "collect",
    bossrush = "collect",

    shellrace = "collect", meltdown = "collect",

    koth = "hold",        domination = "hold",
    ctf = "hold",         crown = "hold",
}

function stats.family_of(modeKey)
    if modeKey == nil then return nil end
    return stats.FAMILY_OF[modeKey] or "other"
end

function stats.family_name(family)
    return stats.FAMILY_NAMES[family] or "Other rounds"
end

stats.form = stats.form or {}

function stats.forget_form()
    stats.form = {}
end

local function note_share(playerId, family, won, players)
    if playerId == nil or family == nil then return end
    if stats.form[playerId] == nil then stats.form[playerId] = {} end
    local list = stats.form[playerId][family]
    if list == nil then
        list = {}
        stats.form[playerId][family] = list
    end
    table.insert(list, { won = won == true, players = players })

    while #list > stats.WIN_SHARE_ROUNDS do table.remove(list, 1) end
end

function stats.win_share(playerId, family)
    if not OF.util.is_host() then return nil end
    if playerId == nil then return nil end
    local byFamily = stats.form[playerId]
    if byFamily == nil then return nil end
    local list = byFamily[family]
    if list == nil or #list < stats.WIN_SHARE_FLOOR then return nil end

    local wins = 0
    local expected = 0
    for _, entry in ipairs(list) do
        if entry.won then wins = wins + 1 end
        expected = expected + 1 / math.max(2, entry.players or 2)
    end
    local share = wins / #list
    expected = expected / #list
    local tier = OF.util.clamp(
        math.floor((share - expected) * 6 + 0.5), -3, 3)
    return { share = share, rounds = #list, wins = wins,
             expected = expected, tier = tier }
end

function stats.share_sentence(entry)
    if entry == nil then return nil end
    return OF.lang.fill("You win @% of these, over @ round(s).",
        string.format("%.0f", math.floor(entry.share * 100 + 0.5)),
        string.format("%.0f", entry.rounds))
end

stats.PACKET = "stnd"
stats.standing = nil

local STANDING_SPLIT = ","
local STANDING_FIELD = ":"
function stats.standing_of(playerId)
    if not OF.util.is_host() then return nil end
    if playerId == nil then return nil end

    local shares = {}
    for _, family in ipairs(stats.FAMILY_ORDER) do
        local entry = stats.win_share(playerId, family)
        if entry ~= nil then
            entry.family = family
            table.insert(shares, entry)
        end
    end

    local row = stats.session[playerId]

    return { on = stats.long_game(), shares = shares,

             honours = stats.held_honours(playerId),
             run = (row ~= nil and row.run) or 0,
             duels = stats.head_to_head(),
             rivals = stats.rivals(playerId) }
end

local function my_record()
    if not OF.util.is_host() then return nil end
    return stats.standing_of(OF.util.player_id(0))
end

function stats.my_standing()
    return my_record() or stats.standing
end

local function pack_rivals(list)
    local rivals = {}
    for _, entry in ipairs(list or {}) do
        if #rivals >= stats.RIVAL_ROWS then break end
        local name = OF.util.plain(entry.name or "?")
        name = string.gsub(name, "[" .. STANDING_SPLIT .. STANDING_FIELD .. "]", "/")
        name = OF.util.short_name(name, PACK_NAME)
        table.insert(rivals, name .. STANDING_FIELD
            .. string.format("%.0f", math.floor(entry.mine or 0))
            .. STANDING_FIELD
            .. string.format("%.0f", math.floor(entry.theirs or 0)))
    end
    return rivals
end

function stats.send_standing(localIndex)
    if not OF.util.is_host() then return false end

    if localIndex == nil or localIndex <= 0 then return false end

    local duelsOn = stats.head_to_head()
    local rivals = duelsOn
        and pack_rivals(stats.rivals(OF.util.player_id(localIndex))) or {}
    local duelFields = {
        q = duelsOn and 1 or 0,
        d = (#rivals > 0) and table.concat(rivals, STANDING_SPLIT) or nil,
    }

    if not stats.long_game() then
        return OF.util.send_to_player(localIndex, {
            ofp = stats.PACKET, off = true,
            q = duelFields.q, d = duelFields.d,
        })
    end

    local standing = stats.standing_of(OF.util.player_id(localIndex))
    if standing == nil then return false end

    local shares = {}
    for _, entry in ipairs(standing.shares) do
        table.insert(shares, entry.family .. STANDING_FIELD
            .. string.format("%.0f", math.floor(entry.share * 100 + 0.5))
            .. STANDING_FIELD .. string.format("%.0f", entry.rounds))
    end

    local titles = {}
    for index = 1, #stats.HONOURS do
        table.insert(titles, (standing.honours or {})[index] and "1" or "0")
    end

    return OF.util.send_to_player(localIndex, {
        ofp = stats.PACKET,
        t = table.concat(titles, ""),
        s = (#shares > 0) and table.concat(shares, STANDING_SPLIT) or nil,
        r = math.floor(standing.run or 0),
        q = duelFields.q,
        d = duelFields.d,
    })
end

function stats.send_standings()
    if not OF.util.is_host() then return 0 end
    local sent = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex > 0 and stats.send_standing(entry.localIndex) then
            sent = sent + 1
        end
    end
    return sent
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" or data.ofp ~= stats.PACKET then return end
    if not OF.util.from_host(data) then return end

    local duels = math.floor(tonumber(data.q) or 0) == 1
    local rivals = {}
    for piece in string.gmatch(tostring(data.d or ""), "[^" .. STANDING_SPLIT .. "]+") do
        local name, mine, theirs = string.match(piece,
            "^(.-)" .. STANDING_FIELD .. "(%d+)" .. STANDING_FIELD .. "(%d+)$")

        if name ~= nil and name ~= "" then
            table.insert(rivals, { name = OF.util.plain(name),
                                   mine = tonumber(mine) or 0,
                                   theirs = tonumber(theirs) or 0 })
        end
    end

    if data.off == true then
        stats.standing = { on = false, honours = {},
                           shares = {}, run = 0, duels = duels, rivals = rivals }
        return
    end

    local shares = {}
    for piece in string.gmatch(tostring(data.s or ""), "[^" .. STANDING_SPLIT .. "]+") do
        local family, percent, rounds = string.match(piece,
            "^(%w+)" .. STANDING_FIELD .. "(%d+)" .. STANDING_FIELD .. "(%d+)$")
        if family ~= nil and stats.FAMILY_NAMES[family] ~= nil then
            table.insert(shares, { family = family,
                                   share = (tonumber(percent) or 0) / 100,
                                   rounds = tonumber(rounds) or 0 })
        end
    end

    local honours = {}
    for digit in string.gmatch(tostring(data.t or ""), "%d") do
        table.insert(honours, digit == "1")
    end

    stats.standing = { on = true,
                       honours = honours, shares = shares,
                       run = math.floor(tonumber(data.r) or 0),
                       duels = duels, rivals = rivals }
end)

local STANDING_EVERY = 30 * 2
local standingFrames = 0
local standingDirty = false

function stats.mark_standing()
    standingDirty = true
end

function stats.tick_standings()
    if not OF.util.is_host() then return false end
    standingFrames = standingFrames + 1
    if standingFrames < STANDING_EVERY then return false end
    standingFrames = 0
    if not standingDirty then return false end
    standingDirty = false
    stats.send_standings()
    return true
end

local function record_name(playerId, np)
    if np == nil or np.name == nil or np.name == "" then return end
    store_row_name(playerId,
        OF.util.storage_value(OF.util.plain(np.name)))
end

local function declared(field)
    return stats.FIELD_OF[field] ~= nil
end

function stats.add(localIndex, field, amount)
    if not OF.util.is_host() then return false end
    if not declared(field) then return false end

    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return false end

    local np = gNetworkPlayers[localIndex]
    record_name(playerId, np)

    local value = stats.get(playerId, field) + (amount or 1)
    store_row_field(playerId, field, value, true)

    local known = stats.FIELD_OF[field]
    if known == nil or not known.date then
        local row = session_row(playerId)
        row[field] = (row[field] or 0) + (amount or 1)
        if np ~= nil and np.name ~= nil and np.name ~= "" then
            row.playerName = OF.util.plain(np.name)
        end
    end

    stats.mark_standing()
    return true
end

function stats.raise(localIndex, field, value)
    if not OF.util.is_host() then return false end

    if not declared(field) then return false end
    value = tonumber(value)

    if value == nil or value ~= value then return false end

    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return false end

    record_name(playerId, gNetworkPlayers[localIndex])

    value = math.floor(value)

    local known = stats.FIELD_OF[field]
    if known == nil or not known.date then
        local row = session_row(playerId)
        if value > (row[field] or 0) then row[field] = value end
    end

    if value <= stats.get(playerId, field) then return false end
    store_row_field(playerId, field, value, true)
    stats.mark_standing()
    return true
end

function stats.everyone()
    local seen = {}
    local list = {}
    local all = OF.util.stored_all()
    if all == nil then return list end

    for key, _ in pairs(all) do

        local escaped = string.match(key, "^" .. ROW_PREFIX .. "(.+)$")
            or string.match(key, "^" .. OLD_LIFE_ROW_PREFIX .. "(.+)$")
            or string.match(key, "^" .. PREFIX .. "(.+)_name$")

        local playerId = escaped ~= nil
            and OF.util.storage_unescape(escaped) or nil
        if playerId ~= nil and not seen[playerId] then
            seen[playerId] = true
            local row = row_of(playerId)
            if row.name ~= nil and row.name ~= "" then
                local entry = { id = playerId, name = row.name }
                for _, field in ipairs(stats.FIELDS) do
                    entry[field.key] =
                        math.floor(tonumber(row[field.key]) or 0)
                end
                table.insert(list, entry)
            end
        end
    end
    return list
end

function stats.leaderboard()
    local list = stats.everyone()
    table.sort(list, function(a, b)
        if a.wins ~= b.wins then return a.wins > b.wins end
        if a.rounds ~= b.rounds then return a.rounds > b.rounds end
        return a.name < b.name
    end)
    return list
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

local MODE_PREFIX = PREFIX .. MODE_ID .. "_"
local function mode_storage_key(modeKey)
    return MODE_PREFIX .. OF.util.storage_escape(modeKey)
end

local modeOrder = nil
local modeIndex = nil

function stats.forget_mode_order()
    modeOrder = nil
    modeIndex = nil
end

local function mode_order()
    if modeOrder ~= nil then return modeOrder, modeIndex end
    modeOrder = {}
    modeIndex = {}
    if OF.gamemodes ~= nil and OF.gamemodes.LIST ~= nil then
        for _, mode in ipairs(OF.gamemodes.LIST) do
            if mode.key ~= nil then table.insert(modeOrder, mode.key) end
        end
    end
    table.sort(modeOrder)
    for index, key in ipairs(modeOrder) do modeIndex[key] = index end
    return modeOrder, modeIndex
end

stats.mode_order = mode_order

function stats.mode_record(modeKey)
    if modeKey == nil then return nil end
    local packed = mod_storage_load(mode_storage_key(modeKey), "")
    if packed == nil or packed == "" then return nil end
    local name, score = string.match(packed, "^(.-)|(%d+)$")
    if name == nil then return nil end
    return { key = modeKey, name = OF.util.plain(OF.util.storage_unescape(name)),
             score = tonumber(score) or 0 }
end

function stats.keep_mode_record(modeKey, np, score)
    if not OF.util.is_host() then return false end
    if modeKey == nil or np == nil then return false end
    score = tonumber(score)

    if score == nil or score ~= score or score <= 0 then return false end
    score = math.floor(score)

    local held = stats.mode_record(modeKey)
    if held ~= nil and score <= held.score then return false end

    local name = OF.util.storage_value(OF.util.plain(np.name or "?"))

    name = string.gsub(name, "|", "/")
    name = OF.util.short_name(name, PACK_NAME)
    if not OF.util.store(mode_storage_key(modeKey),
            name .. "|" .. string.format("%.0f", score)) then
        return false
    end
    return true, held
end

local function note_mode_played(modeKey)
    if modeKey == nil then return end
    local list = stats.night.modes
    for index, key in ipairs(list) do
        if key == modeKey then
            table.remove(list, index)
            break
        end
    end
    table.insert(list, 1, modeKey)

    while #list > #(mode_order()) + 1 do table.remove(list) end
end

function stats.mode_records()
    if not OF.util.is_host() then return {} end
    local order, _ = mode_order()
    local seen = {}
    local list = {}

    local function take(modeKey)
        if modeKey == nil or seen[modeKey] then return end
        local record = stats.mode_record(modeKey)
        if record == nil then return end
        seen[modeKey] = true
        table.insert(list, record)
    end

    for _, modeKey in ipairs(stats.night.modes) do take(modeKey) end
    for _, modeKey in ipairs(order) do take(modeKey) end
    return list
end

stats.AGO_IN_DAYS = 14

function stats.ago_text(day)
    day = math.floor(tonumber(day) or 0)
    if day <= 0 then return OF.lang.t("at some point") end

    local since = stats.days_between(day, stats.today_number())
    if since == nil or since < 0 then return stats.date_text(day) end
    if since == 0 then return OF.lang.t("today") end
    if since == 1 then return OF.lang.t("yesterday") end
    if since <= stats.AGO_IN_DAYS then
        return OF.lang.fill("@ days ago", tostring(since))
    end
    return stats.date_text(day)
end

function stats.best_line(modeKey)
    if modeKey == nil then return nil end
    if not OF.util.asks(OF.celebrate, "best_record") then return nil end
    local held = OF.celebrate.best_record(modeKey)
    if held == nil or (tonumber(held.score) or 0) <= 0 then return nil end

    local score = math.floor(tonumber(held.score) or 0)
    local ago = stats.ago_text(held.day)

    local said = OF.lang.fill("Set @.", ago)

    local last = tonumber(held.last)
    if last ~= nil then
        if math.floor(last) >= score then
            said = said .. " " .. OF.lang.t("Your last round here set it.")
        else
            said = said .. " " .. OF.lang.fill(
                "Your last round here scored @.", tostring(math.floor(last)))
        end
    end

    return { score = score, right = string.format("%.0f", score), help = said }
end

stats.duels = stats.duels or {}

function stats.forget_duels()
    stats.duels = {}
end

function stats.head_to_head()
    if not OF.util.is_host() then return false end
    return stats.get(LOBBY_ID, "duels") == 1
end

function stats.set_head_to_head(on)
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    if not OF.util.is_host() then
        return false, "Only the host keeps the record, so only the host can switch this."
    end
    if not OF.util.store_integer(storage_key(LOBBY_ID, "duels"), on and 1 or 0) then
        return false, "That could not be saved."
    end
    stats.send_standings()
    return true
end

local function note_duel(winnerId, loserId)
    if winnerId == nil or loserId == nil or winnerId == loserId then return end
    if stats.duels[winnerId] == nil then stats.duels[winnerId] = {} end
    stats.duels[winnerId][loserId] = (stats.duels[winnerId][loserId] or 0) + 1
end

stats.RIVAL_ROWS = 5

function stats.rivals(playerId)
    if not OF.util.is_host() then return {} end
    if playerId == nil then return {} end

    local against = {}
    for otherId, count in pairs(stats.duels[playerId] or {}) do
        against[otherId] = { mine = count, theirs = 0 }
    end
    for otherId, beaten in pairs(stats.duels) do
        local count = beaten[playerId]
        if count ~= nil and count > 0 then
            if against[otherId] == nil then against[otherId] = { mine = 0, theirs = 0 } end
            against[otherId].theirs = count
        end
    end

    local list = {}
    for otherId, entry in pairs(against) do
        local row = stats.session[otherId]
        table.insert(list, {
            name = (row ~= nil and row.playerName) or stats.name_of(otherId),
            mine = entry.mine, theirs = entry.theirs,
        })
    end

    table.sort(list, function(a, b)
        local gapA = a.theirs - a.mine
        local gapB = b.theirs - b.mine
        if gapA ~= gapB then return gapA > gapB end
        if (a.theirs + a.mine) ~= (b.theirs + b.mine) then
            return (a.theirs + a.mine) > (b.theirs + b.mine)
        end
        return a.name < b.name
    end)
    return list
end

function stats.nemesis(rivals)
    local first = (rivals or {})[1]
    if first == nil then return nil end
    if (first.theirs or 0) <= (first.mine or 0) then return nil end
    return first
end

stats.AWARDS = {
    { id = "st", label = "Star of the session", unit = "win(s)",
      of = function(row) return row.wins or 0 end },
    { id = "sk", label = "On a tear", unit = "in a row",
      of = function(row) return row.streak or 0 end, floor = 2 },
    { id = "pt", label = "Point machine", unit = "point(s)",
      of = function(row) return row.points or 0 end },
    { id = "bg", label = "One enormous round", unit = "in one round",
      of = function(row) return row.best or 0 end },
    { id = "mv", label = "Top of the scoreboard", unit = "round(s)",
      of = function(row) return row.mvp or 0 end },
    { id = "gr", label = "Never sat one out", unit = "round(s)",
      of = function(row) return row.rounds or 0 end },

    { id = "cg", label = "Most wanted", unit = "time(s) caught",
      of = function(row) return row.frozen or 0 end },
    { id = "pd", label = "Always in the mix", unit = "podium(s)",
      of = function(row) return row.podium or 0 end },

    { id = "im", label = "Most improved", unit = "points better",
      floor = 5,
      of = function(row, playerId)
          local tonightRounds = row.rounds or 0
          if tonightRounds < 3 then return 0 end
          local beforeRounds = stats.get(playerId, "rounds") - tonightRounds
          local beforeWins = stats.get(playerId, "wins") - (row.wins or 0)
          if beforeRounds < 5 then return 0 end
          local was = beforeWins / beforeRounds
          local now = (row.wins or 0) / tonightRounds
          if now <= was then return 0 end
          return math.floor((now - was) * 100 + 0.5)
      end },
    { id = "nw", label = "First session here", unit = nil,
      of = function(row) return row.newTonight and 1 or 0 end },
}

stats.AWARD_OF = {}
for _, award in ipairs(stats.AWARDS) do stats.AWARD_OF[award.id] = award end

function stats.awards()
    if not OF.util.is_host() then return {} end

    local taken = {}
    local list = {}
    for _, award in ipairs(stats.AWARDS) do
        local bestId = nil
        local bestName = nil
        local bestValue = 0
        for playerId, row in pairs(stats.session) do
            if not taken[playerId] then
                local value = award.of(row, playerId) or 0
                local name = row.playerName or "?"
                if value > 0 and (value > bestValue
                        or (value == bestValue and bestName ~= nil
                            and name < bestName)) then
                    bestId = playerId
                    bestName = name
                    bestValue = value
                end
            end
        end
        if bestId ~= nil and bestValue >= (award.floor or 1) then

            taken[bestId] = true
            table.insert(list, { award = award, name = bestName,
                                 value = bestValue })
        end
        if #list >= AWARD_SIZE then break end
    end
    return list
end

function stats.tonight_numbers()

    local numbers = { rounds = stats.night.rounds or 0, players = 0, points = 0,
                      modes = #stats.night.modes, streak = 0, newcomers = 0 }
    for _, row in pairs(stats.session) do
        numbers.players = numbers.players + 1
        numbers.points = numbers.points + (row.points or 0)
        if (row.streak or 0) > numbers.streak then numbers.streak = row.streak end
    end

    for _ in pairs(stats.newcomers) do
        numbers.newcomers = numbers.newcomers + 1
    end
    return numbers
end

stats.MOMENT_KEEP = 8

function stats.note_moment(weight, text, first, second)
    if not OF.util.is_host() then return false end
    if type(text) ~= "string" or text == "" then return false end
    if stats.night.moments == nil then stats.night.moments = {} end

    table.insert(stats.night.moments, {
        weight = tonumber(weight) or 0, text = text,
        first = first, second = second,

        at = stats.night.rounds or 0,
    })

    while #stats.night.moments > stats.MOMENT_KEEP do
        local lightest, at = nil, 1
        for index, one in ipairs(stats.night.moments) do
            if lightest == nil or one.weight < lightest then
                lightest, at = one.weight, index
            end
        end
        table.remove(stats.night.moments, at)
    end
    return true
end

function stats.best_moment()
    local best = nil
    for _, one in ipairs(stats.night.moments or {}) do
        if best == nil or one.weight > best.weight
            or (one.weight == best.weight and (one.at or 0) >= (best.at or 0)) then
            best = one
        end
    end
    return best
end

stats.HOUSE_NIGHTS = {

    { key = "bignight", floor = 5,
      say = "The busiest session this lobby has had - @ round(s)",
      of = function(numbers) return numbers.rounds or 0 end },
    { key = "bigcrowd", floor = 3,
      say = "The biggest turnout this lobby has had - @ of you",
      of = function(numbers) return numbers.players or 0 end },
    { key = "bigpoints", floor = 100,
      say = "The most this lobby has ever scored in a session - @ point(s)",
      of = function(numbers) return numbers.points or 0 end },
}

stats.HOUSE_OF = {}
for _, one in ipairs(stats.HOUSE_NIGHTS) do stats.HOUSE_OF[one.key] = one end

function stats.house_night(key)
    if stats.HOUSE_OF[key] == nil then return nil end
    local packed = mod_storage_load(storage_key(LOBBY_ID, key), "")
    if packed == nil or packed == "" then return nil end
    local value, day = string.match(packed, "^(%d+)|(%d+)$")
    if value == nil then return nil end
    return { key = key, value = tonumber(value) or 0, day = tonumber(day) or 0 }
end

function stats.raise_house_night(key, value)
    if not OF.util.is_host() then return false end
    local entry = stats.HOUSE_OF[key]
    if entry == nil then return false end

    value = tonumber(value)

    if value == nil or value ~= value then return false end
    value = math.floor(value)

    if value < (entry.floor or 1) then return false end

    local held = stats.house_night(key)
    if held ~= nil and value <= held.value then return false end

    if not OF.util.store(storage_key(LOBBY_ID, key),
            string.format("%.0f", value) .. "|"
                .. string.format("%.0f", stats.today_number())) then
        return false
    end
    return true, held
end

function stats.note_house_nights()
    if not OF.util.is_host() then return false end
    local numbers = stats.tonight_numbers()
    local told = false

    for _, entry in ipairs(stats.HOUSE_NIGHTS) do
        local value = entry.of(numbers) or 0
        if houseWas[entry.key] == nil then
            local before = stats.house_night(entry.key)

            houseWas[entry.key] = (before ~= nil and before.value) or 0
        end

        local took = stats.raise_house_night(entry.key, value)
        if took and not houseTold[entry.key]
            and houseWas[entry.key] > 0 and value > houseWas[entry.key] then
            houseTold[entry.key] = true
            told = true
            OF.notify.send_all(entry.say, "star", 8, value)

            stats.note_moment(6, entry.say, value)
        end
    end
    return told
end

local function clean(name, most)
    name = OF.util.plain(tostring(name))
    name = string.gsub(name, "[|;]", "/")
    most = most or PACK_NAME
    name = OF.util.short_name(name, most)
    return name
end

local PACK_MAX = 999999

local PACK_BOARD_MAX = 9999

local function clamped(value, most)
    value = tonumber(value) or 0
    if value ~= value then value = 0 end
    value = math.floor(value)
    if value < 0 then value = 0 end
    if value > most then value = most end
    return tostring(value)
end

local function packed_number(value)
    return clamped(value, PACK_MAX)
end

local function board_number(value)
    return clamped(value, PACK_BOARD_MAX)
end

local PACK_DATE_MAX = 99999999

local function date_number(value)
    return clamped(value, PACK_DATE_MAX)
end

local function pack_board(list, keys)
    local wanted = {}
    for index, entry in ipairs(list) do
        if index > BOARD_SIZE then break end
        table.insert(wanted, entry)
    end

    return (OF.util.pack_to_keys(wanted, function(entry, width)
        return clean(entry.name, width) .. "|"
            .. board_number(entry.wins) .. "|" .. board_number(entry.rounds)
    end, PACK_NAME, PACK_NAME_MIN, ";", keys, BOARD_CHUNK))
end

local function pack_records()
    local list = stats.everyone()
    local parts = {}

    for _, field in ipairs(stats.FIELDS) do
        if field.record then
            local best = nil
            for _, entry in ipairs(list) do
                local value = entry[field.key] or 0

                if value > 0 and (best == nil or value > best.value
                        or (value == best.value and entry.name < best.name)) then
                    best = { id = field.id, name = entry.name, value = value }
                end
            end
            if best ~= nil then table.insert(parts, best) end
        end
    end

    return (OF.util.pack_to_fit(parts, function(entry, width)
        return entry.id .. "|" .. clean(entry.name, width) .. "|"
            .. packed_number(entry.value)
    end, PACK_NAME, PACK_NAME_MIN, ";"))
end

local function pack_regulars()
    local list = stats.everyone()
    table.sort(list, function(a, b)
        if (a.nights or 0) ~= (b.nights or 0) then
            return (a.nights or 0) > (b.nights or 0)
        end
        if (a.minutes or 0) ~= (b.minutes or 0) then
            return (a.minutes or 0) > (b.minutes or 0)
        end
        return a.name < b.name
    end)

    local wanted = {}
    for _, entry in ipairs(list) do
        if #wanted >= EXTRA_SIZE then break end
        if (entry.nights or 0) > 0 then table.insert(wanted, entry) end
    end

    return (OF.util.pack_to_keys(wanted, function(entry, width)
        return clean(entry.name, width) .. "|"
            .. packed_number(entry.nights) .. "|"
            .. packed_number(entry.minutes) .. "|"
            .. date_number(entry.seen)
    end, PACK_NAME, PACK_NAME_MIN, ";", HERE_KEYS, HERE_CHUNK))
end

local AWARD_SUMMARY = "~"
local function pack_awards()
    local numbers = stats.tonight_numbers()

    local parts = { AWARD_SUMMARY .. "|" .. board_number(numbers.rounds)
        .. "|" .. board_number(numbers.players)
        .. "|" .. packed_number(numbers.points)
        .. "|" .. board_number(numbers.modes)
        .. "|" .. board_number(numbers.streak)
        .. "|" .. board_number(numbers.newcomers) }

    local awards = {}
    for _, entry in ipairs(stats.awards()) do
        if #awards >= AWARD_SIZE then break end
        table.insert(awards, entry)
    end

    local packed = OF.util.pack_to_fit(awards, function(entry, width)
        return entry.award.id .. "|" .. clean(entry.name, width) .. "|"
            .. board_number(entry.value)
    end, PACK_NAME, PACK_NAME_MIN, ";",
        OF.util.publish_limit() - #parts[1] - 1)

    if packed == "" then return parts[1] end
    return parts[1] .. ";" .. packed
end

local function pack_modes()
    local _, index = mode_order()
    local wanted = {}
    for _, record in ipairs(stats.mode_records()) do
        if #wanted >= MODE_BOARD then break end
        if index[record.key] ~= nil then
            table.insert(wanted, record)
        end
    end
    return (OF.util.pack_to_fit(wanted, function(entry, width)
        return string.format("%.0f", index[entry.key]) .. "|"
            .. clean(entry.name, width) .. "|" .. board_number(entry.score)
    end, PACK_NAME, PACK_NAME_MIN, ";"))
end

stats.BOARD_KEYS = { "ofBoard", "ofBoard2",
                     "ofBoardTonight", "ofBoardTonight2", "ofBoardBest",
                     "ofBoardHere", "ofBoardHere2", "ofBoardHere3",
                     "ofBoardHere4", "ofAwards", "ofModeBest" }

local SPREAD = {
    { keys = TOP_KEYS, of = function() return pack_board(stats.leaderboard(), TOP_KEYS) end },
    { keys = NIGHT_KEYS, of = function() return pack_board(stats.tonight(), NIGHT_KEYS) end },
    { keys = HERE_KEYS, of = function() return pack_regulars() end },
}

function stats.packed_boards()
    local packed = {
        ofBoardBest = pack_records(),

        ofAwards = pack_awards(),
        ofModeBest = pack_modes(),
    }

    for _, board in ipairs(SPREAD) do
        local chunks = board.of()
        for index, chunkKey in ipairs(board.keys) do
            packed[chunkKey] = chunks[index] or ""
        end
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

function stats.published_tonight()

    return stats.published_board(OF.util.joined(NIGHT_KEYS))
end

function stats.published_board(packed)
    if packed == nil then packed = OF.util.joined(TOP_KEYS) end
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

function stats.published_records()
    local packed = gGlobalSyncTable.ofBoardBest
    if packed == nil or packed == "" then return {} end

    local byId = {}
    for row in string.gmatch(packed, "[^;]+") do
        local id, name, value = string.match(row, "^(%w+)|(.-)|(%d+)$")
        if id ~= nil then
            byId[id] = { name = OF.util.plain(name), value = tonumber(value) }
        end
    end

    local list = {}
    for _, field in ipairs(stats.FIELDS) do
        local found = nil
        if field.record then found = byId[field.id] end
        if found ~= nil then
            table.insert(list, { key = field.key, label = field.label,
                                 name = found.name, value = found.value })
        end
    end
    return list
end

function stats.published_regulars()

    local packed = OF.util.joined(HERE_KEYS)
    if packed == nil or packed == "" then return {} end

    local list = {}
    for row in string.gmatch(packed, "[^;]+") do
        local name, nights, minutes, seen =
            string.match(row, "^(.-)|(%d+)|(%d+)|(%d+)$")
        if name ~= nil then
            table.insert(list, { name = OF.util.plain(name),
                                 nights = tonumber(nights),
                                 minutes = tonumber(minutes),
                                 seen = tonumber(seen) })
        end
    end
    return list
end

function stats.published_awards()
    local packed = gGlobalSyncTable.ofAwards
    local numbers = { rounds = 0, players = 0, points = 0, modes = 0,
                      streak = 0, newcomers = 0 }
    local list = {}
    if packed == nil or packed == "" then return list, numbers end

    for row in string.gmatch(packed, "[^;]+") do
        local rounds, players, points, modes, streak, newcomers =
            string.match(row, "^~|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
        if rounds ~= nil then
            numbers = { rounds = tonumber(rounds) or 0,
                        players = tonumber(players) or 0,
                        points = tonumber(points) or 0,
                        modes = tonumber(modes) or 0,
                        streak = tonumber(streak) or 0,
                        newcomers = tonumber(newcomers) or 0 }
        else
            local id, name, value = string.match(row, "^(%a%a)|(.-)|(%d+)$")

            if id ~= nil and stats.AWARD_OF[id] ~= nil then
                table.insert(list, { award = stats.AWARD_OF[id],
                                     name = OF.util.plain(name),
                                     value = tonumber(value) or 0 })
            end
        end
    end
    return list, numbers
end

function stats.published_modes()
    local packed = gGlobalSyncTable.ofModeBest
    local list = {}
    if packed == nil or packed == "" then return list end

    local order, _ = mode_order()
    for row in string.gmatch(packed, "[^;]+") do
        local index, name, score = string.match(row, "^(%d+)|(.-)|(%d+)$")
        if index ~= nil then
            local modeKey = order[tonumber(index)]

            local mode = nil
            if modeKey ~= nil and OF.gamemodes ~= nil
                and OF.gamemodes.BY_KEY ~= nil then
                mode = OF.gamemodes.BY_KEY[modeKey]
            end
            if mode ~= nil then
                table.insert(list, { key = modeKey, label = mode.name or modeKey,
                                     name = OF.util.plain(name),
                                     score = tonumber(score) or 0 })
            end
        end
    end
    return list
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

local function harvest_round()
    if not OF.util.asks(OF.gamemodes, "played") then return end

    local mode = OF.gamemodes.current()
    if mode ~= nil and mode.scoreIsTime then return end

    local list = {}
    for _, entry in ipairs(OF.gamemodes.played()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local score = tonumber(row ~= nil and row.ofScore or 0) or 0

        if score ~= score or score < 0 then score = 0 end
        table.insert(list, { localIndex = entry.localIndex, score = math.floor(score) })
    end
    if #list == 0 then return end

    table.sort(list, function(a, b) return a.score > b.score end)

    if list[1].score > 0 and (list[2] == nil or list[2].score < list[1].score) then
        stats.add(list[1].localIndex, "mvp", 1)
    end

    for place, entry in ipairs(list) do
        if entry.score > 0 then
            stats.add(entry.localIndex, "points", entry.score)
            stats.raise(entry.localIndex, "best", entry.score)
            if place <= 3 then stats.add(entry.localIndex, "podium", 1) end

            local playerId = OF.util.player_id(entry.localIndex)
            if playerId ~= nil and mode ~= nil and mode.key ~= nil then
                local seat = session_mode(session_row(playerId), mode.key)
                if entry.score > seat.best then seat.best = entry.score end
            end
        end
    end

    if mode ~= nil and mode.key ~= nil and list[1].score > 0 then
        local np = gNetworkPlayers[list[1].localIndex]
        local took, held = stats.keep_mode_record(mode.key, np, list[1].score)
        if took and np ~= nil then

            if held ~= nil then
                OF.notify.send_all("@ takes the @ record", "star", 6,
                    OF.util.plain(np.name), mode.name or mode.key)
                stats.note_moment(5, "@ takes the @ record",
                    OF.util.plain(np.name), mode.name or mode.key)

                stats.win_honour(list[1].localIndex, "breaker")
            end
        end
    end
end

stats.streaks = stats.streaks or {}

function stats.forget_streaks()
    stats.streaks = {}
end

stats.RUN_ENDED_AT = 3

stats.ALL_NIGHT_ROUNDS = 10

stats.GIANT_RUN = 5

local function note_streak(localIndex, won)
    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return 0 end
    if not won then
        stats.streaks[playerId] = 0

        session_row(playerId).run = 0
        return 0
    end
    local run = (stats.streaks[playerId] or 0) + 1
    stats.streaks[playerId] = run
    session_row(playerId).run = run
    stats.raise(localIndex, "streak", run)
    return run
end

function stats.share_family(list)
    if not OF.util.asks(OF.gamemodes, "current") then return nil end
    local mode = OF.gamemodes.current()
    if mode == nil or mode.key == nil then return nil end
    if #list < stats.SHARE_MIN_PLAYERS then return nil end
    if OF.util.asks(OF.gamemodes, "role") then
        for _, entry in ipairs(list) do
            if OF.gamemodes.role(entry.localIndex) == OF.gamemodes.WAITING then
                return nil
            end
        end
    end
    return stats.family_of(mode.key)
end

function stats.drought(playerId)
    if playerId == nil then return nil end
    local last = stats.get(playerId, "lastwin")
    if last <= 0 then return nil end
    local today = stats.today_number()
    if today <= 0 then return nil end
    local days = stats.days_between(last, today)
    if days == nil or days < 0 then return nil end
    return days, last
end

stats.DROUGHT_DAYS = 21
local DROUGHT_DAYS = stats.DROUGHT_DAYS

local function note_win_day(localIndex, playerId)
    local days = stats.drought(playerId)
    local today = stats.today_number()
    if today > 0 then stats.raise(localIndex, "lastwin", today) end
    if days ~= nil and days >= DROUGHT_DAYS then return days end
    return nil
end

function stats.record_round(winner)
    if not OF.util.is_host() then return end

    local teamKey, nameSet = nil, nil
    if type(winner) == "table" then
        teamKey = winner.team
        if winner.names ~= nil then
            nameSet = {}
            for _, name in ipairs(winner.names) do nameSet[name] = true end
        end
    end

    local list = OF.gamemodes.participants()
    local family = stats.share_family(list)

    local mode = nil
    if OF.util.asks(OF.gamemodes, "current") then mode = OF.gamemodes.current() end
    stats.night.rounds = (stats.night.rounds or 0) + 1
    if mode ~= nil and mode.key ~= nil then note_mode_played(mode.key) end

    local winners = {}
    local losers = {}

    local droughtDays = nil
    local droughtName = nil

    local endedRun = nil
    local endedName = nil

    local enderIndex = nil
    local winnerCount = 0

    local onARun = nil

    for _, entry in ipairs(list) do
        stats.add(entry.localIndex, "rounds", 1)

        local playerId = OF.util.player_id(entry.localIndex)

        local won = false
        if teamKey ~= nil then
            won = OF.util.asks(OF.teams, "of") and OF.teams.of(entry.localIndex) == teamKey
        elseif nameSet ~= nil then
            won = nameSet[entry.np.name] == true
        elseif type(winner) == "string" and winner ~= "" then
            won = entry.np.name == winner
        end
        if won then stats.add(entry.localIndex, "wins", 1) end

        local runBefore = (playerId ~= nil and stats.streaks[playerId]) or 0
        local runNow = note_streak(entry.localIndex, won) or 0

        if won and runNow == stats.GIANT_RUN and onARun == nil then
            local row = playerId ~= nil and stats.session[playerId] or nil
            onARun = (row ~= nil and row.playerName ~= "?" and row.playerName)
                or (entry.np ~= nil and entry.np.name ~= nil
                    and OF.util.plain(entry.np.name)) or nil
        end
        if not won and runBefore >= stats.RUN_ENDED_AT
            and runBefore > (endedRun or 0) then
            endedRun = runBefore
            endedName = (playerId ~= nil and stats.session[playerId] ~= nil
                and stats.session[playerId].playerName)
                or (entry.np ~= nil and entry.np.name ~= nil
                    and OF.util.plain(entry.np.name)) or nil
        end
        if family ~= nil then
            note_share(playerId, family, won, #list)
        end

        if playerId ~= nil then
            local row = session_row(playerId)
            if mode ~= nil and mode.key ~= nil then
                local seat = session_mode(row, mode.key)
                seat.rounds = seat.rounds + 1
                if won then seat.wins = seat.wins + 1 end
            end

            stats.raise(entry.localIndex, "bestnight", row.wins or 0)

            if (stats.night.rounds or 0) >= stats.ALL_NIGHT_ROUNDS
                and (row.rounds or 0) >= (stats.night.rounds or 0) then
                stats.win_honour(entry.localIndex, "allnight")
            end

            if won then
                table.insert(winners, playerId)
                winnerCount = winnerCount + 1
                enderIndex = entry.localIndex

                local gap = note_win_day(entry.localIndex, playerId)

                if gap ~= nil then stats.win_honour(entry.localIndex, "back") end
                if gap ~= nil and gap > (droughtDays or 0) then
                    droughtDays = gap
                    droughtName = row.playerName
                        or (entry.np ~= nil and entry.np.name ~= nil
                            and OF.util.plain(entry.np.name)) or nil
                end
            else
                table.insert(losers, playerId)
            end
        end
    end

    if stats.head_to_head() then
        for _, winnerId in ipairs(winners) do
            for _, loserId in ipairs(losers) do
                note_duel(winnerId, loserId)
            end
        end
    end

    if droughtDays ~= nil and droughtName ~= nil and droughtName ~= "" then
        OF.notify.send_all("@ wins one at last - @ day(s)", "good", 7,
            droughtName, droughtDays)
        stats.note_moment(5, "@ wins one at last - @ day(s)",
            droughtName, droughtDays)
    end

    if onARun ~= nil and onARun ~= "" then
        OF.notify.send_all("@ has won @ in a row", "star", 7,
            onARun, stats.GIANT_RUN)
        stats.note_moment(4, "@ has won @ in a row", onARun, stats.GIANT_RUN)
    end

    if endedRun ~= nil and endedName ~= nil and endedName ~= "" then
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
        if enderName ~= nil and enderName ~= "" then
            OF.notify.send_all("@ ends @", "star", 7, enderName,
                OF.lang.fill("@'s run of @", endedName, endedRun))
            stats.note_moment(endedRun >= stats.GIANT_RUN and 5 or 3,
                "@ ends @", enderName,
                OF.lang.fill("@'s run of @", endedName, endedRun))

            if endedRun >= stats.GIANT_RUN then
                stats.win_honour(enderIndex, "giant")
            end
        else

            OF.notify.send_all("@'s run of @ is over", "star", 7,
                endedName, endedRun)
            stats.note_moment(endedRun >= stats.GIANT_RUN and 4 or 3,
                "@'s run of @ is over", endedName, endedRun)
        end
    end

    harvest_round()

    stats.note_house_nights()
    stats.publish()

    stats.send_standings()
    standingDirty = false
end

function stats.record_race_win(localIndex)
    if not OF.util.is_host() then return end

    local playerId = OF.util.player_id(localIndex)
    local gap = playerId ~= nil and note_win_day(localIndex, playerId) or nil
    stats.add(localIndex, "races", 1)
    stats.add(localIndex, "wins", 1)

    local row = playerId ~= nil and stats.session[playerId] or nil
    if row ~= nil then
        stats.raise(localIndex, "bestnight", row.wins or 0)
    end

    if gap ~= nil then

        stats.win_honour(localIndex, "back")
        local np = gNetworkPlayers[localIndex]
        if np ~= nil and np.name ~= nil and np.name ~= "" then
            OF.notify.send_all("@ wins one at last - @ day(s)", "good", 7,
                OF.util.plain(np.name), gap)
            stats.note_moment(5, "@ wins one at last - @ day(s)",
                OF.util.plain(np.name), gap)
        end
    end
    stats.publish()
end

function stats.record(localIndex, field, amount)
    if stats.add(localIndex, field, amount) then stats.publish() end
end

stats.nightsSeen = stats.nightsSeen or {}

function stats.forget_night()
    stats.nightsSeen = {}
end

local function today_number()
    local now = OF.util.optional("get_date_and_time", nil)
    if now == nil or type(now.year) ~= "number" or type(now.month) ~= "number"
        or type(now.day) ~= "number" then
        return 0
    end
    return (math.floor(now.year) + 1900) * 10000
        + (math.floor(now.month) + 1) * 100 + math.floor(now.day)
end

stats.today_number = today_number

function stats.date_text(value)
    value = math.floor(tonumber(value) or 0)
    if value <= 0 then return "-" end

    return string.format("%04.0f-%02.0f-%02.0f",
        math.floor(value / 10000), math.floor(value / 100) % 100, value % 100)
end

function stats.mark_here(localIndex)
    if not OF.util.is_host() then return false end
    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return false end

    stats.raise(localIndex, "seen", today_number())
    if stats.nightsSeen[playerId] then return false end
    stats.nightsSeen[playerId] = true
    stats.add(localIndex, "nights", 1)

    stats.note_house_nights()
    return true
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

function stats.greet_returning(localIndex)
    if not OF.util.is_host() then return false end

    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return false end

    local nights = stats.get(playerId, "nights")
    if nights < 2 then

        return false
    end

    return false
end

stats.newcomers = stats.newcomers or {}

function stats.forget_newcomers()
    stats.newcomers = {}
end

function stats.note_newcomer(localIndex)
    if not OF.util.is_host() then return false end
    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return false end
    if stats.get(playerId, "nights") > 1 then return false end
    stats.newcomers[playerId] = true

    if stats.session[playerId] ~= nil then
        stats.session[playerId].newTonight = true
    end
    return true
end

local MINUTE_FRAMES = 30 * 60
local minuteFrames = 0

function stats.tick_minutes()
    if not OF.util.is_host() then return false end

    local here = OF.util.connected_players()
    if #here < 2 then
        minuteFrames = 0
        return false
    end

    minuteFrames = minuteFrames + 1
    if minuteFrames < MINUTE_FRAMES then return false end
    minuteFrames = 0

    for _, entry in ipairs(here) do
        stats.add(entry.localIndex, "minutes", 1)
    end
    stats.publish()
    return true
end

function stats.born_on()
    return stats.get(LOBBY_ID, "born")
end

function stats.mark_born()
    if not OF.util.is_host() then return false end
    if stats.born_on() > 0 then return false end
    local today = today_number()
    if today <= 0 then return false end
    return OF.util.store_soon_integer(storage_key(LOBBY_ID, "born"), today)
end

local function days_since_epoch(value)
    value = math.floor(tonumber(value) or 0)
    if value <= 0 then return nil end
    local year = math.floor(value / 10000)
    local month = math.floor(value / 100) % 100
    local day = value % 100
    if year < 1 or month < 1 or month > 12 or day < 1 or day > 31 then return nil end

    local before = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
    local years = year - 1
    local total = years * 365 + math.floor(years / 4)
        - math.floor(years / 100) + math.floor(years / 400)
    total = total + before[month] + (day - 1)
    if month > 2 and (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) then
        total = total + 1
    end
    return total
end

stats.days_since_epoch = days_since_epoch

function stats.days_between(from, to)
    local a = days_since_epoch(from)
    local b = days_since_epoch(to)
    if a == nil or b == nil then return nil end
    return b - a
end

stats.MAX_KEYS = 4096

local function census(wanted)
    local out = { used = 0, keys = {} }
    local all = OF.util.stored_all()
    if all == nil then return out end

    for key, _ in pairs(all) do
        out.used = out.used + 1
        local id = nil

        for _, prefix in ipairs({ ROW_PREFIX, OLD_LIFE_ROW_PREFIX,
                                  OLD_ROW_PREFIX }) do
            if id == nil and string.sub(key, 1, #prefix) == prefix then
                id = string.sub(key, #prefix + 1)
            end
        end
        local rest = nil

        if id ~= nil then
            rest = nil
        elseif string.sub(key, 1, #OLD_LIFE_PREFIX) == OLD_LIFE_PREFIX then
            rest = string.sub(key, #OLD_LIFE_PREFIX + 1)
        elseif string.sub(key, 1, #PREFIX) == PREFIX then
            rest = string.sub(key, #PREFIX + 1)
        end

        if rest ~= nil then id = string.match(rest, "^(.+)_[^_]+$") end
        if id ~= nil then
            id = OF.util.storage_unescape(id)
            if is_identity(id) and (wanted == nil or wanted[id]) then
                local mine = out.keys[id]
                if mine == nil then
                    mine = {}
                    out.keys[id] = mine
                end
                table.insert(mine, key)
            end
        end
    end
    return out
end

function stats.keys_used()
    local all = OF.util.stored_all()
    if all == nil then return 0 end
    local count = 0
    for _ in pairs(all) do count = count + 1 end
    return count
end

stats.PRUNE_STALE_DAYS = 30

function stats.is_stale(seen, today)
    today = math.floor(tonumber(today) or 0)
    if today <= 0 then today = today_number() end
    local ago = stats.days_between(seen, today)
    if ago == nil then return false end
    return ago >= stats.PRUNE_STALE_DAYS
end

function stats.forgettable()
    local here = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local id = OF.util.player_id(entry.localIndex)
        if id ~= nil then here[id] = true end
    end

    local today = today_number()

    local list = {}
    for _, entry in ipairs(stats.everyone()) do
        local titles = honour_bits(stats.get(entry.id, "medals"))
        if is_identity(entry.id) and not here[entry.id]
            and titles <= 0
            and (entry.seen or 0) > 0
            and stats.is_stale(entry.seen, today) then
            table.insert(list, entry)
        end
    end

    table.sort(list, function(a, b)
        if (a.seen or 0) ~= (b.seen or 0) then
            return (a.seen or 0) < (b.seen or 0)
        end
        return (a.rounds or 0) < (b.rounds or 0)
    end)
    return list
end

stats.PRUNE_BATCH_KEYS = 200

stats.PRUNE_BATCH_PLAYERS = 12

function stats.prune_plan(limitKeys, limitPlayers)
    limitKeys = math.floor(tonumber(limitKeys) or stats.PRUNE_BATCH_KEYS)
    limitPlayers = math.floor(tonumber(limitPlayers) or stats.PRUNE_BATCH_PLAYERS)
    if limitKeys < 1 then limitKeys = 1 end
    if limitPlayers < 0 then limitPlayers = 0 end

    local list = stats.forgettable()
    local wanted = {}
    for _, entry in ipairs(list) do wanted[entry.id] = true end
    local file = census(wanted)

    local plan = {
        players = {}, count = 0, keys = 0, writes = 0,
        droppable = #list, waiting = #list,
        used = file.used, cap = stats.MAX_KEYS, capped = false,
    }

    for _, entry in ipairs(list) do
        local mine = file.keys[entry.id] or {}

        if plan.count >= limitPlayers
            or (plan.count > 0 and plan.keys + #mine > limitKeys) then
            plan.capped = true
            break
        end
        table.insert(plan.players, {
            id = entry.id,
            name = entry.name,
            seen = entry.seen or 0,
            rounds = entry.rounds or 0,
            keys = mine,
        })
        plan.count = plan.count + 1
        plan.keys = plan.keys + #mine
    end

    plan.waiting = plan.droppable - plan.count

    plan.writes = plan.keys * 2
    return plan
end

function stats.prune(limitKeys, limitPlayers)

    if not OF.perms.can("settings") then return 0, 0, nil end
    if not OF.util.is_host() then return 0, 0, nil end

    local plan = stats.prune_plan(limitKeys, limitPlayers)
    local gone, freed = 0, 0
    for _, who in ipairs(plan.players) do
        for _, key in ipairs(who.keys) do

            if mod_storage_remove(key) then freed = freed + 1 end
        end

        stats.session[who.id] = nil
        gone = gone + 1
    end

    if gone > 0 then
        stats.publish()
        stats.send_standings()
    end
    return gone, freed, plan
end

function stats.prune_report(gone, freed, waiting)
    if (tonumber(gone) or 0) <= 0 then
        return OF.lang.t("Nobody was old enough to forget.")
    end
    local said = OF.lang.fill("Forgot @ player(s) and freed @ key(s).",
        gone, freed)
    if (tonumber(waiting) or 0) > 0 then
        return said .. " " .. OF.lang.fill(
            "@ more are still old enough - press it again to take the next batch.",
            waiting)
    end
    return said .. " " .. OF.lang.t("Nobody else is old enough to forget.")
end

function stats.forget_oldest(howMany)
    local gone = stats.prune(nil, howMany)
    return gone
end

stats.PRUNE_WARN_AT = 0.85

local warnedFilling = false

local countedAt = nil
local COUNT_EVERY = 30.0

function stats.warn_if_filling()
    if not OF.util.is_host() then return false end

    local now = OF.util.asks(OF, "seconds") and OF.seconds() or nil
    if now == nil and clock_elapsed_f64 ~= nil then now = clock_elapsed_f64() end

    if warnedFilling and countedAt ~= nil and now ~= nil
        and (now - countedAt) < COUNT_EVERY then
        return false
    end
    countedAt = now

    local used = stats.keys_used()
    local line = math.floor(stats.MAX_KEYS * stats.PRUNE_WARN_AT)
    if used < line then
        warnedFilling = false
        return false
    end
    if warnedFilling then return false end
    warnedFilling = true

    OF.notify.show("@ of @ keys used - Forget old players makes room",
        "warn", 8, used, stats.MAX_KEYS)
    return true
end

function stats.reset_all()
    if not OF.perms.can("settings") then return false end

    OF.util.flush_storage(true)
    local all = mod_storage_load_all()
    if all ~= nil then
        for key, _ in pairs(all) do

            for _, prefix in ipairs({ PREFIX, OLD_LIFE_PREFIX, ROW_PREFIX,
                                      OLD_ROW_PREFIX, OLD_LIFE_ROW_PREFIX }) do
                if string.sub(key, 1, #prefix) == prefix then
                    mod_storage_remove(key)
                    break
                end
            end
        end
    end
    stats.session = {}
    stats.forget_streaks()
    stats.forget_form()
    stats.forget_night()
    stats.forget_night_log()
    stats.forget_duels()
    stats.forget_newcomers()

    for _, boardKey in ipairs(stats.BOARD_KEYS) do
        OF.util.publish(boardKey, "")
    end

    OF.notify.show("Lobby stats cleared", "good", 5)
    return true
end

hook_event(HOOK_ON_PLAYER_CONNECTED, function(m)
    if m == nil or not OF.util.is_host() then return end

    if stats.mark_here(m.playerIndex) then
        stats.greet_returning(m.playerIndex)
        stats.note_newcomer(m.playerIndex)
    end

    stats.mark_born()

    stats.mark_here(0)
    stats.publish()

    stats.warn_if_filling()

    stats.mark_standing()
end)

local ROW_FORM_KEY = "of_rows"
local ROW_FORM = "2"
local function migrate_identity(playerId, oldKeys)
    local key = row_key(playerId)
    if OF.util.stored(key, "") == "" then
        local text = pack_row(old_row(playerId))
        if text ~= "" and not OF.util.store(key, text) then return false end
    end
    for _, key in ipairs(oldKeys) do mod_storage_remove(key) end
    return true
end

function stats.migrate_rows(force)
    if rowsDone and not force then return 0 end
    if not force and OF.util.stored(ROW_FORM_KEY, "") == ROW_FORM then
        rowsDone = true
        return 0
    end

    local all = OF.util.stored_all()
    if all == nil then return 0 end

    local lobbyKeys = {}
    local pending, order = {}, {}
    for key, _ in pairs(all) do
        local escaped = nil

        for _, prefix in ipairs({ OLD_LIFE_ROW_PREFIX, OLD_ROW_PREFIX }) do
            if escaped == nil and string.sub(key, 1, #prefix) == prefix then
                escaped = string.sub(key, #prefix + 1)
            end
        end
        local rest = nil
        if escaped ~= nil then
            rest = nil
        elseif string.sub(key, 1, #OLD_LIFE_PREFIX) == OLD_LIFE_PREFIX then
            rest = string.sub(key, #OLD_LIFE_PREFIX + 1)
        elseif string.sub(key, 1, #PREFIX) == PREFIX then
            rest = string.sub(key, #PREFIX + 1)
        end

        if rest ~= nil then escaped = string.match(rest, "^(.+)_[^_]+$") end
        local id = escaped ~= nil and OF.util.storage_unescape(escaped) or nil
        if id ~= nil and is_identity(id) then
            if pending[id] == nil then
                pending[id] = {}
                table.insert(order, id)
            end
            table.insert(pending[id], key)
        elseif string.sub(key, 1, #OLD_LIFE_PREFIX) == OLD_LIFE_PREFIX then
            table.insert(lobbyKeys, key)
        end
    end
    table.sort(lobbyKeys)

    table.sort(order)

    local moved, refused = 0, false
    for _, id in ipairs(order) do
        if migrate_identity(id, pending[id]) then moved = moved + 1
        else refused = true end
    end

    for _, key in ipairs(lobbyKeys) do
        local moving = PREFIX .. string.sub(key, #OLD_LIFE_PREFIX + 1)
        local value = OF.util.stored(key, "")
        if value == "" or OF.util.stored(moving, "") ~= ""
            or OF.util.store(moving, value) then
            mod_storage_remove(key)
        else
            refused = true
        end
    end

    if not refused then
        rowsDone = true
        OF.util.store(ROW_FORM_KEY, ROW_FORM)
    end
    return moved
end

hook_event(HOOK_ON_MODS_LOADED, function()

    stats.migrate_rows()

    stats.warn_if_filling()
end)

hook_event(HOOK_UPDATE, function()
    stats.tick_minutes()
    stats.tick_standings()
end)

stats.AWARDS_SPOKEN = 3

stats.NOTIFY_STACK = 4

function stats.show_awards()
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    if not OF.util.is_host() then
        return false, "Only the host keeps the record, so only the host can do this."
    end

    local awards = stats.awards()
    if #awards == 0 then
        return false, "Nothing has been played this session yet."
    end

    local numbers = stats.tonight_numbers()
    OF.notify.send_all("That is the session - @ round(s), @ of you", "star", 7,
        numbers.rounds, numbers.players)

    local moment = stats.best_moment()
    local spoken = stats.AWARDS_SPOKEN
    if moment ~= nil then
        OF.notify.send_all(moment.text, "star", 8, moment.first, moment.second)
        spoken = math.min(spoken, stats.NOTIFY_STACK - 2)
    end

    for index, entry in ipairs(awards) do
        if index > spoken then break end
        OF.notify.send_all("@ - @", "good", 7,
            OF.lang.t(entry.award.label), entry.name)
    end
    return true
end

local NAME = "\\#ffffff\\"
function stats.board_name(plainName)
    local wanted = OF.util.plain(tostring(plainName or ""))
    if wanted == "" then return wanted end
    for _, entry in ipairs(OF.util.connected_players()) do
        local live = entry.np ~= nil and entry.np.name or nil
        if live ~= nil and OF.util.plain(live) == wanted then return live end
    end
    return wanted
end

function stats.print_board(board, heading, empty)
    if #board == 0 then
        OF.util.chat(empty)
        return
    end
    OF.util.chat(heading)
    for place, entry in ipairs(board) do
        djui_chat_message_create("  " .. OF.util.accent() .. place .. ".\\#dcdcdc\\ "
            .. NAME .. stats.board_name(entry.name)
            .. "\\#dcdcdc\\ - " .. OF.lang.fill("@ win(s) in @ round(s)",
                entry.wins, entry.rounds))
    end
end
