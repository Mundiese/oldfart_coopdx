OF = OF or {}
OF.util = OF.util or {}

local util = OF.util

function util.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function util.byte(v)
    if type(v) ~= "number" then return 255 end
    if v < 0 then return 0 end
    if v > 255 then return 255 end
    return math.floor(v)
end

local HELP_LINE = 256

local function describe_budget(command)

    return HELP_LINE - (1 + #command + 1 + 2 + 1 + 2 + 1)
end

function util.describe(command, items, prose)
    if type(command) ~= "string" or command == "" then return false end
    if type(items) ~= "table" or #items == 0 then return false end
    if update_chat_command_description == nil then return false end

    local clean = {}
    for _, item in ipairs(items) do

        if type(item) == "string" and item ~= "" and not string.find(item, "%s") then
            table.insert(clean, item)
        end
    end
    if #clean == 0 then return false end
    table.sort(clean)

    local seen, unique = nil, {}
    for _, key in ipairs(clean) do
        if key ~= seen then table.insert(unique, key) end
        seen = key
    end
    clean = unique

    if prose ~= nil then
        if #prose > describe_budget(command) then return false end
        if string.find(prose, "[", 1, true) ~= nil
            or string.find(prose, "]", 1, true) ~= nil then
            return false
        end
    end

    local list = "[" .. table.concat(clean, "|") .. "]"
    update_chat_command_description(command,
        prose ~= nil and ("- " .. prose .. " " .. list) or list)
    return true
end

function util.alive(thing)
    if thing == nil then return false end
    if type(thing) ~= "userdata" then return true end
    local ok, dead = pcall(function() return ~thing end)
    if not ok then return true end
    return dead ~= true
end

function util.has_flag(value, flag)

    if value == nil or flag == nil or flag == 0 then return false end
    return math.floor(value / flag) % 2 == 1
end

function util.action_group(action)
    if action == nil then return nil end
    return math.floor(action / 0x40) % 8
end

function util.stopping(m)
    if m == nil or m.action == nil then return false end
    return m.action == ACT_TURNING_AROUND
        or m.action == ACT_BRAKING
        or m.action == ACT_DECELERATING
        or m.action == ACT_HOLD_DECELERATING
end

function util.speed_up(m, want)
    if m == nil then return false end
    want = tonumber(want)
    if want == nil then return false end
    local now = tonumber(m.forwardVel) or 0
    if want <= now then return false end
    if util.stopping(m) then return false end
    m.forwardVel = want
    return true
end

function util.hex_to_rgb(hex)
    local r, g, b = string.match(hex or "", "#(%x%x)(%x%x)(%x%x)")
    if r == nil then return 255, 255, 255 end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

function util.player_color(localIndex)
    return util.hex_to_rgb(network_get_player_text_color_string(localIndex))
end

function util.name_colour()
    return 255, 255, 255
end

function util.asks(from, name)
    return from ~= nil and from[name] ~= nil
end

function util.menu_has_screen()
    return util.asks(OF.panel, "is_open") and OF.panel.is_open() == true
end

function util.flag(value)
    if value == nil or value == false or value == 0 then return 0 end
    return 1
end

function util.is_host()
    return network_is_server()
end

function util.is_host_player(localIndex)
    return network_global_index_from_local(localIndex) == 0
end

function util.area_authority()
    local np = util.optional("get_network_player_smallest_global", nil)
    if np == nil then return nil end
    local at = np.localIndex
    if type(at) ~= "number" then return nil end
    if at < 0 or at >= MAX_PLAYERS then return nil end
    return at
end

function util.i_decide_here()
    return util.area_authority() == 0
end

local NO_COOPNET_ID = { ["-1"] = true, ["0"] = true, [""] = true }

function util.player_identities(localIndex)
    local coopnet = nil
    local id = get_coopnet_id(localIndex)
    if id ~= nil then
        id = tostring(id)
        if not NO_COOPNET_ID[id] then
            coopnet = "cn" .. id
        end
    end

    local named = nil
    local np = gNetworkPlayers[localIndex]
    if np ~= nil and np.name ~= nil and np.name ~= "" then
        named = "nm" .. string.lower(np.name)
    end
    return coopnet, named
end

function util.player_id(localIndex)
    local coopnet, named = util.player_identities(localIndex)
    return coopnet or named
end

function util.local_from_global(globalIndex)
    local li = network_local_index_from_global(globalIndex)
    if li == nil or li < 0 or li >= MAX_PLAYERS then return nil end
    if not gNetworkPlayers[li].connected then return nil end
    return li
end

local connectedCache = nil
local connectedFrame = nil

local function frame_now()
    if get_global_timer ~= nil then return get_global_timer() end
    return nil
end

util.seatForgetters = util.seatForgetters or {}

function util.on_forget_seat(name, drop)
    if type(name) ~= "string" or name == "" then return false end
    if type(drop) ~= "function" then return false end
    util.seatForgetters[name] = drop
    return true
end

function util.forget_seat(localIndex)
    if type(localIndex) ~= "number" then return 0 end
    local ran = 0
    for _, drop in pairs(util.seatForgetters) do
        pcall(drop, localIndex)
        ran = ran + 1
    end
    return ran
end

function util.forget_player_cache(m)
    connectedCache = nil
    connectedFrame = nil
    if m ~= nil and type(m.playerIndex) == "number" then
        util.forget_seat(m.playerIndex)
    end
end

local playerRow = {}

function util.connected_players()
    local now = frame_now()
    if connectedCache ~= nil and now ~= nil and now == connectedFrame then
        return connectedCache
    end

    local list = {}
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected then
            local row = playerRow[i]
            if row == nil then
                row = { localIndex = i }
                playerRow[i] = row
            end
            row.np = np
            table.insert(list, row)
        end
    end

    connectedCache = list
    connectedFrame = now
    return list
end

hook_event(HOOK_ON_PLAYER_CONNECTED, util.forget_player_cache)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, util.forget_player_cache)

function util.find_player_by_name(name)
    local needle = string.lower(util.plain(name or ""))
    if needle == "" then return nil end
    for _, entry in ipairs(util.connected_players()) do
        if string.lower(util.plain(entry.np.name)) == needle then
            return entry.localIndex
        end
    end
    for _, entry in ipairs(util.connected_players()) do
        if string.sub(string.lower(util.plain(entry.np.name)), 1, #needle) == needle then
            return entry.localIndex
        end
    end
    return nil
end

local askedDepth = 0
local askedFrame = nil

function util.answering(fn, ...)
    askedDepth = askedDepth + 1
    askedFrame = frame_now()
    local ok, first, second = pcall(fn, ...)
    askedDepth = askedDepth - 1
    if askedDepth <= 0 then
        askedDepth = 0
        askedFrame = nil
    end
    if not ok then error(first, 0) end
    return first, second
end

function util.asked_in_chat()
    if askedDepth <= 0 then return false end
    local now = frame_now()
    if now ~= nil and askedFrame ~= nil and now ~= askedFrame then
        askedDepth = 0
        askedFrame = nil
        return false
    end
    return true
end

util.RANK_REFUSAL = "Your rank cannot do that."
local function tier_suffix(feature)
    if not util.asks(OF.perms, "required") then return "" end
    return " (" .. OF.lang.t(OF.perms.tier_name(OF.perms.required(feature))) .. "+)"
end

local function rank_line(feature)
    if type(feature) ~= "string" or feature == "" then return nil end
    if not util.asks(OF.perms, "required") then return nil end
    if OF.perms.DEFAULTS == nil or OF.perms.DEFAULTS[feature] == nil then
        return nil
    end
    if OF.perms.can(feature) then return nil end

    local needs = OF.perms.required(feature)
    if needs >= OF.TIER.HOST then
        return OF.lang.t(
            "Host is whoever is running the lobby, not a rank to be given.")
    end

    return OF.lang.fill("You are @. The menu's Ask the host for @ row asks.",
        OF.lang.t(OF.perms.tier_name(OF.perms.my_tier())),
        OF.lang.t(OF.perms.tier_name(needs)))
end

local function say_rank_line(feature)
    local line = rank_line(feature)
    if line == nil then return false end
    djui_chat_message_create("  \\#808080\\" .. line)
    return true
end

local function say_where_the_ladder_is()
    if util.is_host() then return end
    djui_chat_message_create("  \\#808080\\" .. OF.lang.t(
        "A greyed row says the rank it wants, and offers to ask the host."))
end

function util.allowed(feature)
    if OF.perms.can(feature) then return true end
    local said = OF.lang.t(util.RANK_REFUSAL) .. tier_suffix(feature)

    if util.asked_in_chat() or not util.asks(OF.notify, "show") then
        util.chat("\\#ff6060\\" .. said)
        say_rank_line(feature)
    else
        OF.notify.show(said, "bad")
    end

    if util.asks(OF.trouble, "refused") then OF.trouble.refused(feature) end
    return false
end

function util.named_player(msg)
    local target = util.find_player_by_name(msg)
    if target ~= nil then return target end
    util.chat("\\#ff6060\\" .. OF.lang.fill("No player called '@'.", tostring(msg)))
    return nil
end

function util.can_play(localIndex)
    if OF.util.asks(OF.speedrun, "is_excluded") and OF.speedrun.is_excluded(localIndex) then return false end
    if OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(localIndex) then return false end
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex) then return false end

    if OF.util.asks(OF.idle, "left_out") and OF.idle.left_out(localIndex) then
        return false
    end
    return true
end

local INTANGIBLE_VANISH = MARIO_VANISH_CAP or 0x00000002
local INTANGIBLE_CAP    = MARIO_CAP_ON_HEAD or 0x00000010

local intangibleHolders = {}

local intangibleOwned = { vanish = false, cap = false }

local function bit_on(value, bit)
    if util.has_flag(value, bit) then return value end
    return value + bit
end

local function bit_off(value, bit)
    if not util.has_flag(value, bit) then return value end
    return value - bit
end

function util.intangible_held(name)
    return intangibleHolders[name] == true
end

function util.intangible_any()
    return next(intangibleHolders) ~= nil
end

function util.intangible(name, on)
    local m = gMarioStates[0]
    if m == nil or name == nil then return false end

    if on then
        if not util.intangible_any() then
            intangibleOwned.vanish = util.has_flag(m.flags, INTANGIBLE_VANISH)
            intangibleOwned.cap    = util.has_flag(m.flags, INTANGIBLE_CAP)
        end
        intangibleHolders[name] = true
        m.flags = bit_on(bit_on(m.flags, INTANGIBLE_VANISH), INTANGIBLE_CAP)
        return true
    end

    if intangibleHolders[name] == nil then return false end
    intangibleHolders[name] = nil

    if util.intangible_any() then return true end

    if not intangibleOwned.vanish then m.flags = bit_off(m.flags, INTANGIBLE_VANISH) end
    if not intangibleOwned.cap then m.flags = bit_off(m.flags, INTANGIBLE_CAP) end
    return true
end

function util.intangible_borrowed(flag)
    if not util.intangible_any() then return false end
    if flag == INTANGIBLE_VANISH then return intangibleOwned.vanish == false end
    if flag == INTANGIBLE_CAP then return intangibleOwned.cap == false end
    return false
end

function util.own_flags(value)
    value = tonumber(value) or 0
    if util.intangible_borrowed(INTANGIBLE_VANISH) then
        value = bit_off(value, INTANGIBLE_VANISH)
    end
    if util.intangible_borrowed(INTANGIBLE_CAP) then
        value = bit_off(value, INTANGIBLE_CAP)
    end
    return value
end

function util.course_of_level(levelNum)
    for _, entry in ipairs(OF.COURSES) do
        if entry.level == levelNum then return entry.num end
    end
    return 0
end

function util.chat(message)
    djui_chat_message_create(OF.PREFIX .. message)
end

function util.report(ok, reason, feature)
    if ok then return true end
    if reason ~= nil and reason ~= "" then
        local rank = type(reason) == "string"
            and string.find(reason, util.RANK_REFUSAL, 1, true) ~= nil
        local named = type(feature) == "string" and feature ~= ""
        if OF.util.asks(OF.lang, "get") then reason = OF.lang.get(reason) end

        if rank and named and rank_line(feature) ~= nil
            and string.find(reason, "+)", 1, true) == nil then
            reason = reason .. tier_suffix(feature)
        end

        if util.asked_in_chat() or not OF.util.asks(OF.notify, "show") then
            util.chat("\\#ff6060\\" .. reason)
            if rank and named then

                say_rank_line(feature)
            elseif rank then
                say_where_the_ladder_is()
            end
            if OF.util.asks(OF.sounds, "play") then
                OF.sounds.play(OF.sounds.DENIED)
            end
        else

            OF.notify.show(reason, "bad")
        end
    end
    return false
end

local STORAGE_ESCAPES = {
    ["%"] = "%25",
    ["["] = "%5b",
    ["]"] = "%5d",
    ["="] = "%3d",
}

local ESCAPE_PERCENT = "%%25"
local ESCAPE_OPEN    = "%%5b"
local ESCAPE_CLOSE   = "%%5d"
local ESCAPE_EQUALS  = "%%3d"
function util.storage_escape(text)
    if text == nil then return "" end

    text = string.gsub(text, "%%", ESCAPE_PERCENT)
    text = string.gsub(text, "%[", ESCAPE_OPEN)
    text = string.gsub(text, "%]", ESCAPE_CLOSE)
    text = string.gsub(text, "=", ESCAPE_EQUALS)
    return text
end

function util.storage_key(prefix, id)
    return prefix .. util.storage_escape(id)
end

function util.storage_unescape(text)
    if text == nil then return "" end
    text = string.gsub(text, "%%5b", "[")
    text = string.gsub(text, "%%5d", "]")
    text = string.gsub(text, "%%3d", "=")

    text = string.gsub(text, "%%25", "%%")
    return text
end

function util.storage_value(text)
    if text == nil then return "" end
    return (string.gsub(tostring(text), "%c", " "))
end

local storageComplaint = 0

local function report_refusal(key)
    if storageComplaint > 0 then return end
    storageComplaint = 300
    if not util.asks(OF.notify, "show") then

        util.chat("\\#ff6060\\Could not save '" .. tostring(key)
            .. "'. Stats and records, Forget old players makes room.")
        return
    end
    OF.notify.show("Could not save - Stats and records, Forget old players",
        "bad", 8)
end

local storageStamp = 0

function util.storage_stamp()
    return storageStamp
end

local function stamp_writes()
    local WRITERS = {
        "mod_storage_save", "mod_storage_save_bool",
        "mod_storage_save_number", "mod_storage_save_integer",
        "mod_storage_remove", "mod_storage_clear",
    }
    for _, name in ipairs(WRITERS) do
        local engine = _G[name]
        if type(engine) == "function" and not util.stampedWriters then
            _G[name] = function(...)
                storageStamp = storageStamp + 1
                return engine(...)
            end
        end
    end
    util.stampedWriters = true
end
stamp_writes()

function util.stored_count(memo, list, expiry_of)
    if type(memo) ~= "table" or type(list) ~= "function" then return 0 end
    local now = util.asks(OF.jail, "now") and OF.jail.now() or 0
    local ripe = memo.due ~= nil and memo.due > 0 and now > 0 and now >= memo.due
    if memo.stamp == storageStamp and not ripe then return memo.count or 0 end

    local entries = list()
    local due
    if type(expiry_of) == "function" then
        for _, entry in ipairs(entries) do
            local ends = expiry_of(entry)
            if type(ends) == "number" and ends > 0
                and (due == nil or ends < due) then due = ends end
        end
    end
    memo.stamp = storageStamp
    memo.due = due
    memo.count = #entries
    return memo.count
end

local NOTHING = {}
local snapshotStamp = -1
local snapshot = nil
local answered = {}

local engineAll = _G.mod_storage_load_all

local function section()
    if snapshot ~= nil and snapshotStamp == storageStamp then return snapshot end
    if type(engineAll) ~= "function" then return nil end
    local all = engineAll()
    if all == nil then return nil end
    snapshot = all
    snapshotStamp = storageStamp
    answered = {}
    util.storageCopies = (util.storageCopies or 0) + 1
    return snapshot
end

local function loaded(key)
    local all = section()
    if all == nil then return nil, false end
    local held = answered[key]
    if held ~= nil then
        if held == NOTHING then return nil, true end
        return held, true
    end
    local raw = all[key]

    if raw == nil or raw == "" then
        answered[key] = NOTHING
        return nil, true
    end

    local text = string.sub(raw, 1, 1023)
    answered[key] = text
    return text, true
end

local function wrap_readers()
    if util.cachedReaders then return end
    util.cachedReaders = true

    local engineLoad = _G.mod_storage_load
    local engineInteger = _G.mod_storage_load_integer
    local engineNumber = _G.mod_storage_load_number
    local engineBool = _G.mod_storage_load_bool
    local engineExists = _G.mod_storage_exists
    local engineLoadAll = _G.mod_storage_load_all

    if type(engineLoad) == "function" then
        _G.mod_storage_load = function(key, ...)
            local given = select("#", ...)
            local fallback = ...
            if type(key) ~= "string" or given > 1
                or (given == 1 and type(fallback) ~= "string") then
                return engineLoad(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineLoad(key, ...) end
            if text ~= nil then return text end
            return fallback
        end
    end

    if type(engineInteger) == "function" then
        _G.mod_storage_load_integer = function(key, ...)
            local given = select("#", ...)
            local fallback = ...
            if type(key) ~= "string" or given > 1
                or (given == 1 and type(fallback) ~= "number"
                    and type(fallback) ~= "boolean") then
                return engineInteger(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineInteger(key, ...) end
            if text == nil then return fallback end

            local number = tonumber(text)
            if number == nil then return engineInteger(key, ...) end
            return math.floor(number)
        end
    end

    if type(engineNumber) == "function" then
        _G.mod_storage_load_number = function(key, ...)
            local given = select("#", ...)
            local fallback = ...
            if type(key) ~= "string" or given > 1
                or (given == 1 and type(fallback) ~= "number"
                    and type(fallback) ~= "boolean") then
                return engineNumber(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineNumber(key, ...) end
            if text == nil then return fallback end
            local number = tonumber(text)
            if number == nil then return engineNumber(key, ...) end
            return number
        end
    end

    if type(engineBool) == "function" then
        _G.mod_storage_load_bool = function(key, ...)
            local given = select("#", ...)
            local fallback = ...
            if type(key) ~= "string" or given > 1
                or (given == 1 and type(fallback) ~= "boolean") then
                return engineBool(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineBool(key, ...) end
            if text == nil then return fallback end
            return text == "true"
        end
    end

    if type(engineLoadAll) == "function" then
        _G.mod_storage_load_all = function(...)
            if select("#", ...) ~= 0 then return engineLoadAll(...) end
            local all = section()
            if all == nil then return engineLoadAll() end

            local out = {}
            for key, text in pairs(all) do out[key] = text end
            util.storageCopies = (util.storageCopies or 0) + 1
            return out
        end
    end

    if type(engineExists) == "function" then
        _G.mod_storage_exists = function(key, ...)
            if type(key) ~= "string" or select("#", ...) ~= 0 then
                return engineExists(key, ...)
            end
            local text, served = loaded(key)
            if not served then return engineExists(key) end
            return text ~= nil
        end
    end
end
wrap_readers()

util.storageCopies = util.storageCopies or 0

function util.storage_copies()
    return util.storageCopies or 0
end

hook_event(HOOK_UPDATE, function()
    if storageComplaint > 0 then storageComplaint = storageComplaint - 1 end

    util.flush_storage(false)

    util.tick_frame()

    util.sweep_stale_rows()
end)

hook_event(HOOK_ON_LEVEL_INIT, function() util.flush_storage(true) end)
hook_event(HOOK_ON_EXIT, function() util.flush_storage(true) end)

local function already_stored(key, text)
    if mod_storage_load == nil then return false end

    return util.stored(key) == text
end

util.storeWrites = util.storeWrites or 0

local function storing()
    util.storeWrites = util.storeWrites + 1
end

function util.store(key, value)
    local text = util.storage_value(value)
    if text == "" then return util.clear(key) end
    if already_stored(key, text) then return true end

    util.drop_pending(key)
    storing()
    local ok = mod_storage_save(key, text)
    if not ok then report_refusal(key) end
    return ok
end

local waiting = { byKey = {}, order = {}, count = 0 }

function util.storage_pending()
    return waiting.count
end

function util.forget_pending()
    local dropped = waiting.count
    waiting.byKey, waiting.order, waiting.count = {}, {}, 0
    return dropped
end

function util.drop_pending(key)
    if waiting.byKey[key] == nil then return false end
    waiting.byKey[key] = nil
    waiting.count = waiting.count - 1
    return true
end

function util.stored(key, default)
    local marked = waiting.byKey[key]
    if marked ~= nil then return marked end
    if default == nil then return mod_storage_load(key) end
    return mod_storage_load(key, default)
end

function util.stored_integer(key, default)
    local marked = waiting.byKey[key]
    if marked ~= nil then return math.floor(tonumber(marked) or 0) end
    return mod_storage_load_integer(key, default or 0)
end

function util.stored_all()
    local all = mod_storage_load_all()
    if all == nil then return nil end
    local out = {}
    for key, text in pairs(all) do out[key] = text end
    for key, text in pairs(waiting.byKey) do out[key] = text end
    return out
end

function util.store_soon(key, value)
    local text = util.storage_value(value)

    if text == "" then return util.clear(key) end

    if util.stored(key) == text then return true end
    if waiting.byKey[key] == nil then
        waiting.count = waiting.count + 1
        table.insert(waiting.order, key)
    end
    waiting.byKey[key] = text
    return true
end

function util.store_soon_integer(key, value)
    return util.store_soon(key, tostring(math.floor(tonumber(value) or 0)))
end

function util.flush_storage(everything)
    local wrote = 0
    while #waiting.order > 0 do
        local key = table.remove(waiting.order, 1)
        local text = waiting.byKey[key]

        if text ~= nil then
            waiting.byKey[key] = nil
            waiting.count = waiting.count - 1
            storing()
            if not mod_storage_save(key, text) then report_refusal(key) end
            wrote = wrote + 1
            if not everything then return wrote end
        end
    end
    return wrote
end

local PUBLISH_MAX = 256

function util.publish_to(syncTable, key, value)
    if syncTable == nil then return false end

    if value ~= value then return false end

    if type(value) == "string" then
        if value == "" then
            if OF.wireWatch then
                local was = syncTable[key]
                syncTable[key] = nil
                OF.note_sync(key, was ~= nil)
                return true
            end
            syncTable[key] = nil
            return true
        end
        if #value > PUBLISH_MAX then
            util.chat("\\#ff6060\\Too much to send in '" .. tostring(key)
                .. "' (" .. #value .. " characters, " .. PUBLISH_MAX .. " is the limit).")
            return false
        end
    end

    if OF.wireWatch then
        local was = syncTable[key]
        syncTable[key] = value
        OF.note_sync(key, was ~= value)
        return true
    end

    syncTable[key] = value
    return true
end

function util.publish(key, value)
    local guard = OF.guard
    local watched = guard ~= nil and guard.remember ~= nil

    local was
    if watched then
        was = guard.truth[key]
        if value == "" then
            guard.remember(key, nil)
        else
            guard.remember(key, value)
        end
    end

    local ok = util.publish_to(gGlobalSyncTable, key, value)

    if watched then

        if not ok then guard.remember(key, was) end
        if ok then guard.begin(key) end
    end
    return ok
end

function util.chunk_parts(parts, width)
    local chunks, current = {}, ""
    for _, piece in ipairs(parts) do
        if #piece > width then return nil end
        if #current + #piece > width then
            table.insert(chunks, current)
            current = ""
        end
        current = current .. piece
    end
    if current ~= "" then table.insert(chunks, current) end
    return chunks
end

function util.joined(keys, swap, to)
    local first, parts, found = nil, nil, 0
    for index = 1, #keys do
        local key = keys[index]
        local piece = gGlobalSyncTable[key]
        if key == swap then piece = to end
        if type(piece) ~= "string" or piece == "" then break end
        found = found + 1
        if found == 1 then
            first = piece
        else
            if parts == nil then parts = { first } end
            parts[found] = piece
        end
    end
    if found == 0 then return "" end
    if found == 1 then return first end
    return table.concat(parts)
end

function util.pack_to_keys(list, row, widest, narrowest, separator, keys, width)
    separator = separator or ";"
    widest = widest or 12
    narrowest = math.min(narrowest or 6, widest)
    local at = widest
    while true do
        local parts = {}
        for _, entry in ipairs(list) do
            table.insert(parts, row(entry, at) .. separator)
        end

        local chunks = util.chunk_parts(parts, width)
        if chunks ~= nil and #chunks <= #keys then
            return chunks, #parts, at
        end

        if at > narrowest then
            at = at - 1
        else

            while #parts > 0 do
                table.remove(parts)
                chunks = util.chunk_parts(parts, width)
                if chunks ~= nil and #chunks <= #keys then
                    return chunks, #parts, at
                end
            end
            return {}, 0, at
        end
    end
end

local PACKET_TEXT_MAX = 256

function util.packet_safe(data)
    if type(data) ~= "table" then return data end
    for key, value in pairs(data) do
        if type(value) == "string" then
            if value == "" or #value > PACKET_TEXT_MAX then data[key] = nil end
        end
    end
    return data
end

function util.send_all(data)
    if OF.wireWatch then OF.note_packet(data ~= nil and data.ofp or nil) end
    network_send(true, util.packet_safe(data))
    return true
end

function util.send_raw(localIndex, data)
    if localIndex == nil then return false end
    if localIndex <= 0 or localIndex >= MAX_PLAYERS then return false end
    data.from = network_global_index_from_local(0)
    if OF.wireWatch then OF.note_packet(data.ofp) end
    network_send_to(localIndex, true, util.packet_safe(data))
    return true
end

function util.tell_all(data)
    if not util.is_host() then return false end
    local sent = 0
    for _, entry in ipairs(util.connected_players()) do
        if entry.localIndex > 0 then
            local copy = {}
            for key, value in pairs(data) do copy[key] = value end
            if util.send_to_player(entry.localIndex, copy) then sent = sent + 1 end
        end
    end
    return true, sent
end

function util.from_host(data)
    if type(data) ~= "table" then return false end
    if util.is_host() then return false end
    if not util.asks(OF.pass, "is_mine") then return false end
    return OF.pass.is_mine(data.pk)
end

function util.from_host_effect(data)
    if type(data) ~= "table" then return false end
    if util.is_host() then return false end

    if util.from_host(data) then return true end

    return data.from == 0
end

function util.may_act_on(asker, target)
    if target == nil then
        return false, "They have left the lobby."
    end

    if util.is_host_player(target) then
        return false, "The host is not somebody you can do that to."
    end

    if OF.perms.shield(target) >= OF.perms.tier(asker) then
        if OF.util.asks(OF.perms, "is_shielded") and OF.perms.is_shielded(target) then
            return false, "The host has put them out of a moderator's reach."
        end
        return false, "They are your rank or above it."
    end
    return true
end

function util.tell_asker(askerGlobal, why)
    if askerGlobal == nil or why == nil then return false end
    if not OF.util.asks(OF.notify, "send_to") then return false end
    OF.notify.send_to(askerGlobal, "@", "bad", 5, tostring(why))
    return true
end

function util.asked_by(data)
    if type(data) ~= "table" then return nil end
    if not util.is_host() then return nil end
    if not util.asks(OF.pass, "owner") then return nil end
    local globalIndex = OF.pass.owner(data.pk)
    if globalIndex == nil then return nil end
    local localIndex = util.local_from_global(globalIndex)
    if localIndex == nil then return nil end

    if util.asks(OF.actionlog, "behalf") then
        local np = gNetworkPlayers[localIndex]
        if np ~= nil then OF.actionlog.behalf(np.name) end
    end

    return localIndex, globalIndex
end

function util.send_to_host(data)
    if util.is_host() then return false end
    local li = util.local_from_global(0)

    if li == nil or li <= 0 then return false end

    data.from = network_global_index_from_local(0)

    if util.asks(OF.pass, "mine") then data.pk = OF.pass.mine() end
    if OF.wireWatch then OF.note_packet(data.ofp) end
    network_send_to(li, true, util.packet_safe(data))
    return true
end

function util.send_anonymous(data)

    if util.is_host() then return false end
    local li = util.local_from_global(0)
    if li == nil or li <= 0 then return false end

    if OF.wireWatch then OF.note_packet(data ~= nil and data.ofp or nil) end
    network_send_to(li, true, util.packet_safe(data))
    return true
end

function util.send_to_player(localIndex, data)
    if localIndex == nil then return false end
    if localIndex <= 0 or localIndex >= MAX_PLAYERS then return false end

    data.from = network_global_index_from_local(0)

    if util.is_host() and util.asks(OF.pass, "of") then
        local globalIndex = network_global_index_from_local(localIndex)
        data.pk = OF.pass.of(globalIndex)

        if data.pk == nil then
            OF.pass.hold(globalIndex, data)
            return false, "They are still arriving - it will reach them."
        end
    end
    if OF.wireWatch then OF.note_packet(data.ofp) end
    network_send_to(localIndex, true, util.packet_safe(data))
    return true
end

function util.publish_row(localIndex, key, value)

    if localIndex == 0 and OF.util.asks(OF.guard, "remember_mine") then
        OF.guard.remember_mine(key, value)
    end
    return util.publish_to(gPlayerSyncTable[localIndex], key, value)
end

function util.publish_limit()
    return PUBLISH_MAX
end

util.STORE_MAX = 1023

function util.pack_rows(rows, separator, limit)
    separator = separator or ";"
    limit = limit or PUBLISH_MAX
    local packed = ""
    local used = 0
    for _, row in ipairs(rows) do
        local candidate = (used == 0) and row or (packed .. separator .. row)
        if #candidate > limit then break end
        packed = candidate
        used = used + 1
    end
    return packed, used
end

function util.pack_to_fit(list, row, widest, narrowest, separator, limit)
    widest = widest or 12
    narrowest = math.min(narrowest or 6, widest)
    local width = widest
    while true do
        local parts = {}
        for _, entry in ipairs(list) do
            table.insert(parts, row(entry, width))
        end
        local packed, used = util.pack_rows(parts, separator, limit)
        if used >= #list or width <= narrowest then
            return packed, used, width
        end
        width = width - 1
    end
end

function util.clear(key)

    util.drop_pending(key)
    storing()
    if mod_storage_remove(key) then return true end
    if not mod_storage_exists(key) then return true end
    report_refusal(key)
    return false
end

function util.store_integer(key, value)
    if already_stored(key, tostring(math.floor(value or 0))) then return true end

    util.drop_pending(key)
    storing()
    local ok = mod_storage_save_integer(key, value)
    if not ok then report_refusal(key) end
    return ok
end

function util.store_bool(key, value)
    if already_stored(key, value and "true" or "false") then return true end

    util.drop_pending(key)
    storing()
    local ok = mod_storage_save_bool(key, value)
    if not ok then report_refusal(key) end
    return ok
end

function util.migrate_storage_keys()
    if mod_storage_load_all == nil then return 0 end
    local all = mod_storage_load_all()
    if all == nil then return 0 end

    local renames = {}
    for key, value in pairs(all) do
        if string.find(key, "%%") ~= nil then
            local prefix, id = string.match(key, "^(%w+_)(.*)$")
            if prefix ~= nil then

                local settled = util.storage_escape(util.storage_unescape(id)) == id
                local fresh = prefix .. util.storage_escape(id)
                if not settled and fresh ~= key and all[fresh] == nil then
                    renames[key] = { key = fresh, value = value }
                end
            end
        end
    end

    local count = 0
    for old, entry in pairs(renames) do
        mod_storage_save(entry.key, tostring(entry.value))
        mod_storage_remove(old)
        count = count + 1
    end
    return count
end

util.migrate_storage_keys()

util.PLAYER_ROW_DEFAULTS = {
    ofTier = nil,
    ofMuted = false,
    ofJailed = "",
    ofNoRace = false,
    ofSpectating = false,
    ofRole = "",
    ofScore = 0,
    ofGmTime = 0,
    ofHpGrab = 0,
    ofSplits = "",
    ofRunTime = 0,
    ofRunGot = 0,
    ofCheats = "",
    ofTeam = "",
    ofVoted = "",
    ofIdle = false,
    ofHsFresh = false,

    ofHsFrozen = false,

    ofMhDied = 0,
    ofForgeSize = "",

    ofCostume = "",

    ofMyShape = "",

    ofCrownGave = 0,

    ofCrownDied = 0,

    ofBingoMarks = 0,

    ofEmote = 0,

    ofHold = "",

    ofPerch = "",

    ofScale = 1.0,

    ofUnseen = false,

    ofStill = false,

    ofFacing = false,

    ofPresses = 0,

    ofForgeReach = "",
    ofForgeMoved = "",
    ofDoorMine = "",
    ofHat = "",

    ofPossess = "",

    ofWorn = "",

    ofSpotsClaim = 0,

    ofRollAim = 0,

    ofBankHeld = 0,

    ofBountyAt = "",

    ofBountyTo = -1,
    ofBountySeq = 0,

    ofCrownTo = "",

    ofRope = "",
    ofBond = "",

    ofTicks = "",
}

function util.clear_player_row(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return end

    util.forget_host_records(localIndex)

    for key, value in pairs(util.PLAYER_ROW_DEFAULTS) do
        util.publish_row(localIndex, key, value)
    end

    row.ofTier = nil
end

function util.forget_host_records(localIndex)
    if OF.util.asks(OF.ranks, "forget") then
        OF.ranks.forget(localIndex)
    end
    if OF.util.asks(OF.jail, "forget_sentence") then
        OF.jail.forget_sentence(localIndex)
    end
end

local function row_holds_somebody(localIndex)
    local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[localIndex] or nil
    if row == nil then return false end

    if row.ofTier ~= nil then return true end
    for key, value in pairs(util.PLAYER_ROW_DEFAULTS) do
        local have = row[key]
        if have ~= nil and have ~= value then return true end
    end
    return false
end

util.sweptRows = util.sweptRows or false

function util.sweep_stale_rows()
    if util.sweptRows then return 0 end

    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me == nil or me.connected ~= true then return 0 end

    util.sweptRows = true
    if not util.is_host() then return 0 end

    local swept = 0
    for i = 1, (MAX_PLAYERS or 1) - 1 do
        local np = gNetworkPlayers[i]
        if (np == nil or np.connected ~= true) and row_holds_somebody(i) then
            util.clear_player_row(i)
            swept = swept + 1
        end
    end
    return swept
end

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    if not util.is_host() then return end
    if m.playerIndex == 0 then return end

    if OF.wireWatch then OF.wire_mark("a player left") end
    util.clear_player_row(m.playerIndex)
end)

local TICK_KEY = "ofTicks"
local TICK_FPS = 30

local TICK_NAME_MAX = 8
local TICK_SECONDS_MAX = 5999
local TICK_MOST = 6

util.TICK_WIDEST = TICK_MOST * (TICK_NAME_MAX + 1 + #tostring(TICK_SECONDS_MAX))
    + (TICK_MOST - 1)

local tickFrames = {}

local tickSeen = {}

local tickRaw = {}

local tickSaid = {}
local tickPublished = nil

local function tick_seconds(frames)
    return math.ceil(frames / TICK_FPS)
end

local function tick_name_ok(name)
    if type(name) ~= "string" then return false end
    if #name < 1 or #name > TICK_NAME_MAX then return false end
    return string.match(name, "^%w+$") ~= nil
end

local function tick_pack(byName, said)
    local names = {}
    for name in pairs(byName) do table.insert(names, name) end
    table.sort(names)
    local parts = {}
    for _, name in ipairs(names) do
        local seconds = tick_seconds(byName[name])
        said[name] = seconds
        table.insert(parts, name .. ":" .. seconds)
    end
    return table.concat(parts, ";")
end

local function tick_parse(text)
    local out = {}
    if type(text) ~= "string" or text == "" then return out end
    local kept = 0
    for piece in string.gmatch(text, "[^;]+") do
        local name, seconds = string.match(piece, "^(%w+):(%d+)$")
        local value = tonumber(seconds)
        if kept < TICK_MOST and name ~= nil and value ~= nil
            and tick_name_ok(name) and value <= TICK_SECONDS_MAX then
            out[name] = value
            kept = kept + 1
        end
    end
    return out
end

local function tick_publish()
    local mine = tickFrames[0]
    local said = {}
    local packed = (mine ~= nil) and tick_pack(mine, said) or ""
    tickSaid = said

    tickPublished = (packed ~= "") and packed or nil
    util.publish_row(0, TICK_KEY, packed)
end

function util.tick_row(name, seconds)
    if not tick_name_ok(name) then return false end

    local mine = tickFrames[0]
    if mine == nil then
        mine = {}
        tickFrames[0] = mine
    end

    if seconds == nil then
        if mine[name] == nil then return true end
        mine[name] = nil
        tick_publish()
        return true
    end

    if type(seconds) ~= "number" then return false end

    if seconds ~= seconds then return false end
    if seconds < 0 or seconds > TICK_SECONDS_MAX then return false end

    if mine[name] == nil then
        local live = 0
        for _ in pairs(mine) do live = live + 1 end
        if live >= TICK_MOST then return false end
    end

    mine[name] = math.floor(seconds * TICK_FPS)
    tick_publish()
    return true
end

function util.row_ticks(localIndex, name)
    local held = tickFrames[localIndex]
    if held == nil then return nil end
    return held[name]
end

function util.tick_frame()
    for localIndex = 0, MAX_PLAYERS - 1 do
        local row = gPlayerSyncTable[localIndex]

        if localIndex ~= 0 and row ~= nil then
            local raw = row[TICK_KEY]
            if raw ~= tickRaw[localIndex] then
                tickRaw[localIndex] = raw
                local said = tick_parse(raw)
                local seen = tickSeen[localIndex] or {}
                local held = tickFrames[localIndex] or {}
                for name, seconds in pairs(said) do
                    if seen[name] ~= seconds then
                        seen[name] = seconds
                        held[name] = seconds * TICK_FPS
                    end
                end

                for name in pairs(held) do
                    if said[name] == nil then
                        held[name] = nil
                        seen[name] = nil
                    end
                end
                tickSeen[localIndex] = seen
                tickFrames[localIndex] = held
            end
        end

        local held = tickFrames[localIndex]
        if held ~= nil then
            for name, frames in pairs(held) do
                if frames > 0 then held[name] = frames - 1 end
            end
        end
    end

    local mine = tickFrames[0]
    if mine == nil or tickPublished == nil then return end
    for name, frames in pairs(mine) do
        if tickSaid[name] ~= tick_seconds(frames) then
            tick_publish()
            return
        end
    end
end

util.missing = util.missing or {}

local FALLBACK_GOLD = { r = 255, g = 255, b = 0 }

function util.gold()
    local value = OF.GOLD
    if type(value) ~= "table" or value.r == nil then return FALLBACK_GOLD end
    return value
end

local function channel(value)
    value = tonumber(value)
    if value == nil then return 255 end
    value = math.floor(value + 0.5)
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return value
end

local ACCENT_FORMAT = "\\#%02x%02x%02x\\"
function util.colour_escape(r, g, b)
    return string.format(ACCENT_FORMAT, channel(r), channel(g), channel(b))
end

function util.accent()
    local gold = util.gold()
    return util.colour_escape(gold.r, gold.g, gold.b)
end

function util.binding(name)
    local fn = _G[name]
    if type(fn) == "function" then return fn end
    util.missing[name] = true
    return nil
end

function util.optional(name, fallback, ...)
    local fn = util.binding(name)
    if fn == nil then return fallback end
    local ok, result = pcall(fn, ...)
    if not ok then return fallback end
    return result
end

local LCG_A, LCG_C, LCG_M = 1103515245, 12345, 2147483648
local ownState = 1

function util.seed_own(value)
    local n = math.floor(math.abs(tonumber(value) or 1)) % LCG_M
    ownState = n > 0 and n or 1
    return true
end

function util.random()
    ownState = (LCG_A * ownState + LCG_C) % LCG_M
    return math.floor(ownState / 65536) / 32768
end

function util.random_int(low, high)
    if high == nil then low, high = 1, low end
    low, high = math.floor(low or 1), math.floor(high or 1)
    if high < low then low, high = high, low end
    return low + math.floor(util.random() * (high - low + 1)) % (high - low + 1)
end

util.WEIGHT_MOST = 8

local function bounded_weight(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    value = math.floor(value)
    if value < 1 then return 1 end
    if value > util.WEIGHT_MOST then return util.WEIGHT_MOST end
    return value
end

function util.draw_weight(entry, lag)
    if type(entry) ~= "table" then return 1 end
    local weight = bounded_weight(entry.weight, 1)
    local lift = bounded_weight(entry.lift, weight)
    lag = tonumber(lag) or 0
    if lag <= 0 or lift == weight then return weight end
    if lag > 1 then lag = 1 end
    local delta = (lift - weight) * lag
    delta = delta >= 0 and math.floor(delta) or math.ceil(delta)
    return bounded_weight(weight + delta, weight)
end

function util.pick_weighted(choices, lag, roll)
    if type(choices) ~= "table" or #choices == 0 then return nil end
    if type(roll) ~= "function" then return nil end

    local bag = {}
    for _, entry in ipairs(choices) do
        for _ = 1, util.draw_weight(entry, lag) do
            table.insert(bag, entry)
        end
    end

    local at = roll(#bag)
    if type(at) ~= "number" then return nil end
    at = math.floor(at)
    if at < 1 or at > #bag then return nil end
    return bag[at]
end

local seeded = false

function util.seed_random()
    if seeded then return false end
    seeded = true
    local fine = util.optional("clock_elapsed_f64", nil)
    if type(fine) ~= "number" then

        fine = (util.optional("get_global_timer", 0) or 0) / 30
    end
    local mixed = (util.optional("get_time", 0) or 0)
        + math.floor((fine % 1) * 1000000000)
        + network_global_index_from_local(0)

    ownState = math.floor(math.abs(mixed) % LCG_M)
    if ownState <= 0 then ownState = 1 end
    return true
end

function util.missing_bindings()
    local list = {}
    for name in pairs(util.missing) do table.insert(list, name) end
    table.sort(list)
    return list
end

local interpResolved = false
local printInterp = nil

local rectInterp = nil

local function resolve_interp()
    if interpResolved then return end
    interpResolved = true
    local p = _G["djui_hud_print_text_interpolated"]
    if type(p) == "function" then printInterp = p end
    local r = _G["djui_hud_render_rect_interpolated"]
    if type(r) == "function" then rectInterp = r end
end

function util.forget_interp()
    interpResolved = false
    printInterp = nil
    rectInterp = nil
end

function util.interpolates()
    resolve_interp()
    return printInterp ~= nil
end

function util.box_interpolates()
    resolve_interp()
    return rectInterp ~= nil
end

function util.in_font(font, draw)
    if type(draw) ~= "function" then return end

    if font == nil or djui_hud_set_font == nil then return draw() end

    local previous = FONT_NORMAL
    if djui_hud_get_font ~= nil then previous = djui_hud_get_font() end

    djui_hud_set_font(font)
    local ok, first, second, third, fourth = pcall(draw)
    djui_hud_set_font(previous)
    if not ok then error(first, 0) end
    return first, second, third, fourth
end

function util.hud_face(text)
    local face = _G["FONT_MENU"]
    if face == nil then return nil end
    if type(text) ~= "string" then return face end

    if string.find(text, "[^\032-\126\t\n]") ~= nil then return nil end
    return face
end

local TITLE_OVER_NORMAL = 32 / 64

function util.hud_scale(face, scale)
    if face == nil then return scale end
    return scale * TITLE_OVER_NORMAL
end

local function print_moving(message, prevX, prevY, prevScale, x, y, scale)
    resolve_interp()
    if prevX == nil or printInterp == nil then
        djui_hud_print_text(message, x, y, scale)
        return
    end

    printInterp(message, prevX, prevY, prevScale, prevScale, x, y, scale, scale)
end

function util.rect(x, y, w, h, r, g, b, a, from)
    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    if from == nil or from.x == nil then
        djui_hud_render_rect(x, y, w, h)
        return
    end
    resolve_interp()
    if rectInterp == nil then
        djui_hud_render_rect(x, y, w, h)
        return
    end
    rectInterp(from.x, from.y, from.width or w, from.height or h, x, y, w, h)
end

function util.meter(x, y, width, height, share, first, second)
    share = util.clamp(share or 0.5, 0, 1)
    local left = math.floor(width * share + 0.5)

    first = first or { r = 255, g = 255, b = 255 }
    second = second or { r = 90, g = 90, b = 90 }

    if left > 0 then
        util.rect(x, y, left, height, first.r, first.g, first.b, 235)
    end
    if left < width then
        util.rect(x + left, y, width - left, height,
            second.r, second.g, second.b, 235)
    end
end

util.CHECKS_MOST = 24
local CHECK_SIZE = 7
local CHECK_GAP = 4

function util.checks(x, y, done, total, colour)
    total = math.floor(util.clamp(total or 0, 0, util.CHECKS_MOST))
    if total <= 0 then return 0 end
    done = math.floor(util.clamp(done or 0, 0, total))

    colour = colour or util.gold()
    local step = CHECK_SIZE + CHECK_GAP
    for index = 1, total do
        local at = x + (index - 1) * step
        if index <= done then
            util.rect(at, y, CHECK_SIZE, CHECK_SIZE,
                colour.r, colour.g, colour.b, 235)
        else

            util.rect(at, y, CHECK_SIZE, CHECK_SIZE, 255, 255, 255, 40)
        end
    end
    return total * step - CHECK_GAP
end

function util.share_of(a, b)
    a = math.max(0, a or 0)
    b = math.max(0, b or 0)
    if a + b <= 0 then return 0.5 end
    return a / (a + b)
end

function util.plate(x, y, width, height, opts)
    opts = opts or {}
    local alpha = opts.alpha or 255
    if alpha <= 0 then return end
    local function faded(value) return math.floor(value * (alpha / 255)) end

    local look = OF.util.asks(OF.theme, "active")
        and OF.theme.active() or nil
    local body = look ~= nil and look.panel or { r = 10, g = 10, b = 14 }

    for step = 2, 1, -1 do
        local spread = step * 2
        util.rect(x - spread, y - spread,
            width + spread * 2, height + spread * 2, 0, 0, 0, faded(22 - step * 6))
    end

    util.rect(x, y, width, height, body.r, body.g, body.b, faded(238))
    util.rect(x, y, width, 1, 255, 255, 255, faded(30))
    util.rect(x, y + height - 1, width, 1, 0, 0, 0, faded(60))

    if opts.edge ~= nil then
        util.rect(x, y, 4, height, opts.edge.r, opts.edge.g, opts.edge.b, alpha)
    end
    if opts.accent ~= nil then
        util.rect(x, y + height, width, 2,
            opts.accent.r, opts.accent.g, opts.accent.b, alpha)
    end
end

local ESCAPE = "\\" .. "#%x*" .. "\\"
function util.list_of(names)
    if names == nil or #names == 0 then return "" end
    if #names == 1 then return names[1] end
    local head = {}
    for i = 1, #names - 1 do table.insert(head, names[i]) end
    return table.concat(head, ", ") .. " and " .. names[#names]
end

function util.plain(text)
    if type(text) ~= "string" then return text end
    return (string.gsub(text, ESCAPE, ""))
end

function util.presser(askerLocal)
    if askerLocal == nil then return nil end
    local np = gNetworkPlayers[askerLocal]
    if np == nil or np.name == nil or np.name == "" then return nil end
    return util.plain(np.name)
end

function util.row_key(text)
    text = util.plain(tostring(text or ""))

    local cut
    repeat
        text, cut = string.gsub(text, "^%[[xX%s%-]%]%s*", "")
    until cut == 0
    local head = string.match(text, "^(.-): ")
    if head ~= nil and head ~= "" then return head end
    return text
end

function util.cut_coloured(text, budget)
    if type(text) ~= "string" then return "" end
    budget = math.floor(tonumber(budget) or 0)
    if budget < 0 then budget = 0 end

    local pieces, at, seen = {}, 1, 0
    while at <= #text do
        local openAt, closeAt = string.find(text, ESCAPE, at)
        if openAt == at then
            pieces[#pieces + 1] = string.sub(text, openAt, closeAt)
            at = closeAt + 1
        else
            if seen >= budget then break end
            local runEnd = (openAt ~= nil) and (openAt - 1) or #text
            local room = budget - seen
            if runEnd - at + 1 > room then runEnd = at + room - 1 end
            pieces[#pieces + 1] = string.sub(text, at, runEnd)
            seen = seen + (runEnd - at + 1)
            at = runEnd + 1
        end
    end
    return table.concat(pieces)
end

function util.text(message, x, y, scale, r, g, b, a, from)

    message = util.plain(message)
    a = util.byte(a)

    local prevX, prevY, prevScale
    if from ~= nil then
        prevX, prevY, prevScale = from.x, from.y, from.scale or scale
    end

    djui_hud_set_color(0, 0, 0, math.floor(a * 0.65))
    print_moving(message,
        prevX ~= nil and prevX + 2 * prevScale or nil,
        prevY ~= nil and prevY + 2 * prevScale or nil, prevScale,
        x + 2 * scale, y + 2 * scale, scale)
    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), a)
    print_moving(message, prevX, prevY, prevScale, x, y, scale)
end

function util.text_raw(message, x, y, scale, r, g, b, a)
    if type(message) ~= "string" then message = tostring(message) end
    a = util.byte(a)
    local tinted = util.colour_escape(r, g, b) .. message
    djui_hud_set_color(0, 0, 0, math.floor(a * 0.65))
    djui_hud_print_text(tinted, x + 2 * scale, y + 2 * scale, scale)
    djui_hud_set_color(255, 255, 255, a)
    djui_hud_print_text(tinted, x, y, scale)
end

function util.text_named(prefix, name, suffix, x, y, scale, r, g, b, a)
    local head = util.plain(prefix ~= nil and prefix or "")
    local tail = util.plain(suffix ~= nil and suffix or "")
    local own = name ~= nil and tostring(name) or ""
    local line = head .. own
    if tail ~= "" then

        if own:find(ESCAPE) ~= nil then
            line = line .. util.colour_escape(r, g, b)
        end
        line = line .. tail
    end
    if line == "" then return 0 end

    util.text_raw(line, x, y, scale, r, g, b, a)
    return util.drawn_width(line, scale)
end

function util.named_width(prefix, name, suffix, scale)
    return util.drawn_width(prefix or "", scale)
        + util.drawn_width(name or "", scale)
        + util.drawn_width(suffix or "", scale)
end

local RING_FAR = 20000

local function world_screen(world, out)
    if djui_hud_world_pos_to_screen_pos == nil then return false end

    local point = world

    if not djui_hud_world_pos_to_screen_pos(point, out) then return false end
    if math.abs(out.x) > RING_FAR or math.abs(out.y) > RING_FAR then
        return false
    end

    if util.asks(OF.modifiers, "mirror_screen_x") then
        out.x = OF.modifiers.mirror_screen_x(out.x)
    end
    return true
end

util.world_screen = world_screen

local screenAt = { x = 0, y = 0, z = 0 }
local worldAt = { x = 0, y = 0, z = 0 }

local function project_point(x, y, z)
    worldAt.x, worldAt.y, worldAt.z = x, y, z
    if not world_screen(worldAt, screenAt) then return nil end
    return screenAt.x, screenAt.y
end

local function view_axis()
    local eye = gLakituState
    if eye == nil or eye.pos == nil or eye.focus == nil then return nil end
    if util.optional("is_game_paused", false) == true then return nil end
    local ex, ey, ez = eye.pos.x, eye.pos.y, eye.pos.z
    local fx, fy, fz = eye.focus.x, eye.focus.y, eye.focus.z

    if type(ex) ~= "number" or type(ey) ~= "number" or type(ez) ~= "number"
        or type(fx) ~= "number" or type(fy) ~= "number"
        or type(fz) ~= "number" then
        return nil
    end
    fx, fy, fz = fx - ex, fy - ey, fz - ez
    local length = math.sqrt(fx * fx + fy * fy + fz * fz)

    if not (length > 0.0001) then return nil end
    return ex, ey, ez, fx / length, fy / length, fz / length
end

local function view_depth(x, y, z)
    local ex, ey, ez, fx, fy, fz = view_axis()
    if ex == nil then return nil end
    return (x - ex) * fx + (y - ey) * fy + (z - ez) * fz
end

util.view_depth = view_depth

local function walk_to_plane(goodX, goodZ, badX, badZ, y)
    local nearX, nearZ = goodX, goodZ
    local farX, farZ = badX, badZ
    local edgeX, edgeY = nil, nil
    for _ = 1, 6 do
        local midX = (nearX + farX) * 0.5
        local midZ = (nearZ + farZ) * 0.5
        local px, py = project_point(midX, y, midZ)
        if px == nil then
            farX, farZ = midX, midZ
        else
            nearX, nearZ = midX, midZ
            edgeX, edgeY = px, py
        end
    end
    return edgeX, edgeY
end

local ringX, ringZ, atX, atY = {}, {}, {}, {}

local function stroke_closed(count, y, width)
    local drawn = 0
    for index = 1, count do
        local step = index + 1
        if atX[index] ~= nil and atX[step] ~= nil then
            djui_hud_render_line(atX[index], atY[index], atX[step], atY[step],
                width)
            drawn = drawn + 1
        elseif atX[index] ~= nil then
            local edgeX, edgeY = walk_to_plane(ringX[index], ringZ[index],
                ringX[step], ringZ[step], y)
            if edgeX ~= nil then
                djui_hud_render_line(atX[index], atY[index], edgeX, edgeY, width)
                drawn = drawn + 1
            end
        elseif atX[step] ~= nil then
            local edgeX, edgeY = walk_to_plane(ringX[step], ringZ[step],
                ringX[index], ringZ[index], y)
            if edgeX ~= nil then
                djui_hud_render_line(edgeX, edgeY, atX[step], atY[step], width)
                drawn = drawn + 1
            end
        end
    end
    return drawn
end

function util.world_ring(at, radius, segments, size, r, g, b, a)
    if at == nil or type(radius) ~= "number" or radius <= 0 then return 0 end
    if djui_hud_render_line == nil or djui_hud_world_pos_to_screen_pos == nil then
        return 0
    end
    segments = math.max(8, math.floor(segments or 32))
    local width = size or 3

    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    local centreDepth = view_depth(at.x, at.y, at.z)
    if centreDepth ~= nil and centreDepth + radius <= 0 then
        djui_hud_set_rotation(0, 0, 0)
        return 0
    end

    for index = 1, segments + 1 do
        local angle = ((index - 1) / segments) * 2 * math.pi
        ringX[index] = at.x + math.cos(angle) * radius
        ringZ[index] = at.z + math.sin(angle) * radius
        atX[index], atY[index] = project_point(ringX[index], at.y, ringZ[index])
    end

    local drawn = stroke_closed(segments, at.y, width)

    djui_hud_set_rotation(0, 0, 0)
    return drawn
end

function util.world_outline(at, corners, size, r, g, b, a)
    if at == nil or type(corners) ~= "table" then return 0 end
    local count = #corners
    if count < 3 then return 0 end
    if djui_hud_render_line == nil or djui_hud_world_pos_to_screen_pos == nil then
        return 0
    end
    local width = size or 3

    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))

    local reach = 0
    for index = 1, count do
        local corner = corners[index]
        local away = corner.x * corner.x + corner.z * corner.z
        if away > reach then reach = away end
    end
    reach = math.sqrt(reach)

    local centreDepth = view_depth(at.x, at.y, at.z)
    if centreDepth ~= nil and centreDepth + reach <= 0 then
        djui_hud_set_rotation(0, 0, 0)
        return 0
    end

    for index = 1, count do
        local corner = corners[index]
        ringX[index] = at.x + corner.x
        ringZ[index] = at.z + corner.z
        atX[index], atY[index] = project_point(ringX[index], at.y, ringZ[index])
    end

    ringX[count + 1], ringZ[count + 1] = ringX[1], ringZ[1]
    atX[count + 1], atY[count + 1] = atX[1], atY[1]

    local drawn = stroke_closed(count, at.y, width)
    djui_hud_set_rotation(0, 0, 0)
    return drawn
end

function util.world_arrow(at, height, size, r, g, b, a)
    if at == nil then return false end
    if djui_hud_render_line == nil or djui_hud_world_pos_to_screen_pos == nil then
        return false
    end

    height = height or 220

    local ex, ey, ez, fx, fy, fz = view_axis()
    if ex ~= nil then
        local tipDepth = (at.x - ex) * fx + (at.y - ey) * fy + (at.z - ez) * fz

        if tipDepth <= 0 and tipDepth + height * fy <= 0 then return false end
    end

    local tipX, tipY = project_point(at.x, at.y, at.z)
    local tailX, tailY = project_point(at.x, at.y + height, at.z)
    if tipX == nil or tailX == nil then return false end

    local dx, dy = tipX - tailX, tipY - tailY
    local length = math.sqrt(dx * dx + dy * dy)

    if length < 1 then return false end

    local width = size or 4
    djui_hud_set_color(util.byte(r), util.byte(g), util.byte(b), util.byte(a))
    djui_hud_render_line(tailX, tailY, tipX, tipY, width)

    local barb = length * 0.35
    local ux, uy = dx / length, dy / length
    for _, turn in ipairs({ 0.6, -0.6 }) do
        local cosT, sinT = math.cos(turn), math.sin(turn)

        local bx = -ux * cosT + uy * sinT
        local by = -uy * cosT - ux * sinT
        djui_hud_render_line(tipX, tipY, tipX + bx * barb, tipY + by * barb,
            width)
    end

    djui_hud_set_rotation(0, 0, 0)
    return true
end

function util.width(message, scale)
    return djui_hud_measure_text(message) * scale
end

function util.drawn_width(message, scale)
    return util.width(util.plain(message), scale)
end

function util.shorten(text, most)
    if type(text) ~= "string" then return "" end
    most = most or 14
    if most < 4 then most = 4 end
    if #util.plain(text) <= most then return text end

    local budget = most - 3
    local kept, seen, index = {}, 0, 1
    while index <= #text and seen < budget do
        local from, to = string.find(text, ESCAPE, index)
        if from == index then

            table.insert(kept, string.sub(text, from, to))
            index = to + 1
        else
            table.insert(kept, string.sub(text, index, index))
            seen = seen + 1
            index = index + 1
        end
    end
    return table.concat(kept) .. "..."
end

function util.short_name(name, most)
    return util.shorten(util.plain(tostring(name or "")), most)
end

function util.fit(message, scale, room)
    if type(message) ~= "string" or room == nil or room <= 0 then return message end
    if util.width(message, scale) <= room then return message end

    local ellipsis = "..."
    local budget = room - util.width(ellipsis, scale)
    if budget <= 0 then return ellipsis end

    local kept = ""
    for index = 1, #message do
        local candidate = string.sub(message, 1, index)
        if util.width(candidate, scale) > budget then break end
        kept = candidate
    end

    kept = string.gsub(kept, "%s+$", "")
    return kept .. ellipsis
end

util.HUD_EDGE = 18
util.HUD_PAD_X, util.HUD_PAD_Y = 8, 5

util.HUD_GLYPH_GAP = 0.15

function util.corner_counter(glyph, text, r, g, b, fromRight, scale)
    if text == nil or text == "" then return 0 end
    scale = scale or 1.0

    local face = util.hud_face(text)
    local at = util.hud_scale(face, scale)
    local width, height = util.in_font(face, function()
        return util.text_size(text, at)
    end)

    local box, gap = height, math.floor(height * util.HUD_GLYPH_GAP)
    if glyph == nil then box, gap = 0, 0 end

    local total = box + gap + width

    local x = djui_hud_get_screen_width() - total - util.HUD_EDGE
        - (fromRight or 0)
    local y = util.HUD_EDGE

    util.plate(x - util.HUD_PAD_X, y - util.HUD_PAD_Y,
        total + util.HUD_PAD_X * 2, height + util.HUD_PAD_Y * 2)

    if glyph ~= nil then

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_render_texture(glyph, x, y,
            box / (glyph.width or box), box / (glyph.height or box))
    end

    util.in_font(face, function()
        util.text(text, x + box + gap, y, at, r, g, b, 255)
    end)

    return total + util.HUD_PAD_X * 3
end

function util.text_size(message, scale)
    local w, h = djui_hud_measure_text(message)
    return w * scale, h * scale
end

function util.fit_name(name, scale, room)
    local plain = util.plain(type(name) == "string" and name or tostring(name or ""))
    if room == nil or room <= 0 then return plain end
    if util.text_size(plain, scale) <= room then return plain end

    local ellipsis = "..."
    local budget = room - util.text_size(ellipsis, scale)

    local kept = ""
    for index = 1, #plain do
        local candidate = string.sub(plain, 1, index)
        if util.text_size(candidate, scale) > budget then break end
        kept = candidate
    end

    if kept == "" then kept = string.sub(plain, 1, 1) end

    kept = string.gsub(kept, "%s+$", "")
    return kept .. ellipsis
end

function util.line_height(scale)
    local _, h = djui_hud_measure_text("Ag")
    return h * scale
end

util.ROW_FIT_MARGIN = 24

function util.rows_that_fit(top, lineHeight, margin)
    if lineHeight == nil or lineHeight <= 0 then return 1 end
    local bottom = djui_hud_get_screen_height() - (margin or util.ROW_FIT_MARGIN)
    return math.max(1, math.floor((bottom - top) / lineHeight))
end

function util.scroll_list(panel, rows, first, last)
    if panel == nil or type(rows) ~= "table" then return false end
    if first == nil then first = 1 end
    if type(first) ~= "number" then return false end
    if last == nil then last = #rows end
    if last > #rows then last = #rows end
    if first < 1 then first = 1 end
    if last < first then return false end

    local fits = nil
    if util.asks(panel, "rows_that_fit") then fits = panel.rows_that_fit() end
    if type(fits) ~= "number" then fits = panel.visibleRows end
    if type(fits) ~= "number" or fits < 1 then fits = 1 end

    local function is_stop(r)
        if type(r) ~= "table" then return true end
        return r.action ~= nil or r.walk == true
    end

    local marked = false

    local runStart = nil
    for index = first, last + 1 do
        if index > last or is_stop(rows[index]) then
            if runStart ~= nil and index - runStart > fits then
                for at = runStart, index - 1 do
                    local r = rows[at]

                    if type(r) == "table" and r.heading ~= true
                        and r.slider == nil then
                        r.walk = true
                        marked = true
                    end
                end
            end
            runStart = nil
        elseif runStart == nil then
            runStart = index
        end
    end
    return marked
end

local STACK_TOP = 0.045
local STACK_GAP = 6

local STACK_BOTTOM = 0.045

util.hudStack = nil
util.hudStackLow = nil
local stackFrame = nil

local function frame_stamp()
    if get_global_timer ~= nil then return get_global_timer() end
    return nil
end

function util.hud_reset()
    local height = djui_hud_get_screen_height()
    util.hudStack = height * STACK_TOP

    util.hudStackLow = height - height * STACK_BOTTOM
    stackFrame = frame_stamp()

    util.hudClaims = {}
    util.hudClaimsLow = {}
end

function util.hud_push(height)
    if util.hudStack == nil then util.hud_reset() end
    util.hudStack = util.hudStack + height
end

function util.hud_claim(height, padding)
    padding = padding or 6
    local stamp = frame_stamp()
    if util.hudStack == nil or stamp == nil or stamp ~= stackFrame then
        util.hud_reset()
    end
    local y = util.hudStack + padding
    util.hudStack = y + height + padding + STACK_GAP
    table.insert(util.hudClaims, { y = y - padding, height = height + padding * 2 })
    return y
end

function util.hud_claim_low(height, padding)
    padding = padding or 6
    local stamp = frame_stamp()
    if util.hudStackLow == nil or stamp == nil or stamp ~= stackFrame then
        util.hud_reset()
    end
    local y = util.hudStackLow - padding - height
    util.hudStackLow = y - padding - STACK_GAP
    table.insert(util.hudClaimsLow, { y = y - padding, height = height + padding * 2 })
    return y
end

util.hudHeldBy = {}
util.hudBitWas = {}

function util.hud_hidden(flag)
    local holders = util.hudHeldBy[flag]
    if holders == nil then return false end
    return next(holders) ~= nil
end

function util.hud_holders(flag)
    local n = 0
    for _ in pairs(util.hudHeldBy[flag] or {}) do n = n + 1 end
    return n
end

function util.hud_hide(flag, who, wanted)
    if type(flag) ~= "number" or who == nil then return false end

    local holders = util.hudHeldBy[flag]
    if holders == nil then
        holders = {}
        util.hudHeldBy[flag] = holders
    end
    local hadAny = next(holders) ~= nil
    if wanted then holders[who] = true else holders[who] = nil end
    local anyNow = next(holders) ~= nil

    local flags = util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) ~= "number" then return anyNow end
    local lit = util.has_flag(flags, flag)

    if anyNow and not hadAny then util.hudBitWas[flag] = lit end

    if anyNow then
        if lit then
            util.optional("hud_set_value", nil, HUD_DISPLAY_FLAGS, flags - flag)
        end
        return true
    end

    if hadAny then
        local was = util.hudBitWas[flag]
        util.hudBitWas[flag] = nil
        if was == true and not lit then
            util.optional("hud_set_value", nil, HUD_DISPLAY_FLAGS, flags + flag)
        end
    end
    return false
end

function util.hud_room_flags()
    local flags = util.optional("hud_get_value", nil, HUD_DISPLAY_FLAGS)
    if type(flags) ~= "number" then return nil end
    for flag, was in pairs(util.hudBitWas) do
        local lit = util.has_flag(flags, flag)
        if was == true and not lit then
            flags = flags + flag
        elseif was == false and lit then
            flags = flags - flag
        end
    end
    return flags
end

util.aboveMenu = {}
local aboveFrame = nil

function util.above_menu(paint)
    if type(paint) ~= "function" then return false end

    local stamp = frame_stamp()
    if stamp == nil or stamp ~= aboveFrame then
        util.aboveMenu = {}
        aboveFrame = stamp
    end
    table.insert(util.aboveMenu, paint)
    return true
end

function util.paint_above_menu()
    local queued = util.aboveMenu
    util.aboveMenu = {}
    aboveFrame = nil
    for _, paint in ipairs(queued) do

        pcall(djui_hud_set_resolution, RESOLUTION_DJUI)
        pcall(djui_hud_set_font, FONT_NORMAL)

        pcall(paint)
    end
    return #queued
end

local BANNER_PAD = 5
local UNDER_GAP = 6

local LIMP_PITCH = 0x0180
local LIMP_ROLL  = 0x00E0
local LIMP_LEAN  = 0x0110

local TORSO_SWING = 0x0E00
local HEAD_SWING  = 0x0700

util.limpTick = util.limpTick or 0

local function set_joint(joint, roll, pitch, yaw)
    if joint == nil then return end
    joint.x = roll
    joint.y = pitch
    joint.z = yaw
end

function util.limp(m, tick)
    m = m or gMarioStates[0]
    if m == nil or m.marioObj == nil then return false end

    util.limpTick = tick or (util.limpTick + 1)
    local t = util.limpTick

    local gfx = m.marioObj.header.gfx
    if gfx ~= nil and gfx.angle ~= nil then
        gfx.angle.x = math.floor(t * LIMP_PITCH) % 0x10000
        gfx.angle.z = math.floor(t * LIMP_ROLL) % 0x10000
    end

    local body = m.marioBodyState
    if body == nil then return false end

    body.allowPartRotation = true

    local swing = math.sin(t * LIMP_LEAN / 0x8000 * math.pi)
    set_joint(body.torsoAngle,
        math.floor(TORSO_SWING * swing),
        math.floor(TORSO_SWING * 0.6 * math.cos(t * 0.07)), 0)
    set_joint(body.headAngle,
        math.floor(HEAD_SWING * -swing),
        math.floor(HEAD_SWING * 0.5 * math.sin(t * 0.05)), 0)
    return true
end

function util.stand_up(m)
    m = m or gMarioStates[0]
    util.limpTick = 0
    if m == nil or m.marioObj == nil then return false end

    local gfx = m.marioObj.header.gfx
    if gfx ~= nil and gfx.angle ~= nil then
        gfx.angle.x = 0
        gfx.angle.z = 0
    end

    local body = m.marioBodyState
    if body == nil then return false end
    set_joint(body.torsoAngle, 0, 0, 0)
    set_joint(body.headAngle, 0, 0, 0)
    body.allowPartRotation = false
    return true
end

util.limping = util.limping or false

function util.limp_until_landed()
    util.limping = true
    util.limpTick = 0
end

function util.limp_update(m)
    if not util.limping then return false end
    m = m or gMarioStates[0]
    if m == nil then return false end

    if util.action_group(m.action) == util.action_group(ACT_GROUP_AIRBORNE) then
        util.limp(m)
        return true
    end

    util.limping = false
    util.stand_up(m)
    return false
end

function util.skip_interpolation(obj)
    if obj == nil then return false end
    local fn = util.binding("obj_skip_interpolation")
    if fn == nil then return false end

    local ok = pcall(fn, obj)
    return ok
end

function util.place_player(localIndex, x, y, z)
    local m = gMarioStates ~= nil and gMarioStates[localIndex] or nil
    if m == nil or m.pos == nil then return false end
    if type(x) ~= "number" or type(y) ~= "number"
        or type(z) ~= "number" then return false end
    local obj = m.marioObj
    if obj == nil then return false end

    local moved = m.pos.x ~= x or m.pos.y ~= y or m.pos.z ~= z

    m.pos.x, m.pos.y, m.pos.z = x, y, z
    if type(obj.oPosX) == "number" then
        obj.oPosX, obj.oPosY, obj.oPosZ = x, y, z
    end
    local header = obj.header
    local gfx = header ~= nil and header.gfx or nil
    local at = gfx ~= nil and gfx.pos or nil
    if at ~= nil and type(at.x) == "number" then
        at.x, at.y, at.z = x, y, z
    end

    if moved then util.skip_interpolation(obj) end
    return true
end

local function banner_measure(line)
    line.face = util.hud_face(line.segments ~= nil
        and util.segments_text(line.segments) or line.text)
    line.at = util.hud_scale(line.face, line.want)
    line.w, line.h = util.in_font(line.face, function()
        if line.segments ~= nil then
            return util.segments_width(line.segments, line.at),
                util.line_height(line.at)
        end
        return util.text_size(line.text, line.at)
    end)
end

local function banner_draw(line, x, y, alpha)
    util.in_font(line.face, function()
        if line.segments ~= nil then
            util.draw_segments(line.segments, x, y, line.at, alpha)
        else
            util.text(line.text, x, y, line.at, line.r, line.g, line.b, alpha)
        end
    end)
end

local BANNER_EDGE = 24

local function banner_fit(lines, screen)
    local widest = 0
    for _, line in ipairs(lines) do
        if line.w > widest then widest = line.w end
    end
    local room = screen - BANNER_EDGE * 2 - BANNER_PAD * 4
    if widest <= room or room <= 0 or widest <= 0 then return end

    local fit = room / widest
    for _, line in ipairs(lines) do
        line.at = line.at * fit
        line.w = line.w * fit
        line.h = line.h * fit
    end
end

local function banner_at(claim, text, scale, r, g, b, alpha, opts)
    opts = opts or {}
    local screen = djui_hud_get_screen_width()
    alpha = alpha or 255

    local unders = opts.under
    if unders ~= nil and unders.text == nil and unders.segments == nil then

    elseif unders ~= nil then
        unders = { unders }
    end

    local lines = { { text = text, want = scale, segments = opts.segments,
                      r = r, g = g, b = b } }
    if unders ~= nil then
        for _, line in ipairs(unders) do
            line.want = line.scale or 0.7
            line.r = line.r or 220
            line.g = line.g or 220
            line.b = line.b or 220
            lines[#lines + 1] = line
        end
    end

    for _, line in ipairs(lines) do banner_measure(line) end
    banner_fit(lines, screen)

    local widest, total = 0, 0
    for index, line in ipairs(lines) do
        if line.w > widest then widest = line.w end
        total = total + line.h
        if index > 1 then total = total + UNDER_GAP end
    end

    local top = lines[1]
    local x = (screen - top.w) * 0.5
    local y = claim(total, BANNER_PAD)

    opts.alpha = opts.alpha or alpha
    util.plate((screen - widest) * 0.5 - BANNER_PAD * 2, y - BANNER_PAD,
        widest + BANNER_PAD * 4, total + BANNER_PAD * 2, opts)

    local lineY = y
    for index, line in ipairs(lines) do
        if index > 1 then lineY = lineY + UNDER_GAP end
        banner_draw(line, (screen - line.w) * 0.5, lineY, alpha)
        lineY = lineY + line.h
    end
    return y, x, top.w, top.h
end

function util.banner(text, scale, r, g, b, alpha, opts)
    return banner_at(util.hud_claim, text, scale, r, g, b, alpha, opts)
end

function util.banner_low(text, scale, r, g, b, alpha, opts)
    return banner_at(util.hud_claim_low, text, scale, r, g, b, alpha, opts)
end

function util.world_label(screenX, screenY, text, scale, r, g, b, alpha)
    if type(text) ~= "string" or text == "" then return false end
    alpha = alpha or 255

    local face = util.hud_face(text)
    local at = util.hud_scale(face, scale)

    util.in_font(face, function()
        local width, height = util.text_size(text, at)
        util.plate(screenX - width * 0.5 - BANNER_PAD * 2,
            screenY - height * 0.5 - BANNER_PAD,
            width + BANNER_PAD * 4, height + BANNER_PAD * 2, { alpha = alpha })
        util.text(text, screenX - width * 0.5, screenY - height * 0.5,
            at, r, g, b, alpha)
    end)
    return true
end

local METER_LIFT = 6
local METER_HEIGHT = 4

function util.banner_meter(top, x, width, share, first, second, lift)
    if type(top) ~= "number" or type(x) ~= "number" then return false end
    if type(width) ~= "number" or width <= 0 then return false end
    util.meter(x, top - METER_LIFT - (lift or 0), width, METER_HEIGHT,
        share, first, second)
    return true
end

local CHECKS_LIFT = 11

function util.banner_checks(top, x, done, total, colour, lift)
    if type(top) ~= "number" or type(x) ~= "number" then return false end
    return util.checks(x, top - CHECKS_LIFT - (lift or 0),
        done, total, colour) > 0
end

function util.segments_width(segments, scale)
    local w = 0
    for _, seg in ipairs(segments) do
        w = w + util.drawn_width(seg.text, scale)
    end
    return w
end

function util.segments_text(segments)
    local pieces = {}
    for _, seg in ipairs(segments) do
        pieces[#pieces + 1] = tostring(seg.text or "")
    end
    return table.concat(pieces)
end

local COLOUR_RUN = "\\" .. "#(%x%x%x%x%x%x)" .. "\\"
function util.colour_runs(text, fallback)
    local runs = {}
    if type(text) ~= "string" then return runs end
    local white = fallback or { r = 255, g = 255, b = 255 }
    local r, g, b = white.r, white.g, white.b

    local at = 1
    while at <= #text do

        local from, to, hex = string.find(text, COLOUR_RUN, at)
        if from == nil then break end
        if from > at then
            table.insert(runs, { text = string.sub(text, at, from - 1),
                                 r = r, g = g, b = b })
        end
        r = tonumber(string.sub(hex, 1, 2), 16)
        g = tonumber(string.sub(hex, 3, 4), 16)
        b = tonumber(string.sub(hex, 5, 6), 16)
        at = to + 1
    end

    if at <= #text then
        table.insert(runs, { text = string.sub(text, at), r = r, g = g, b = b })
    end
    return runs
end

function util.runs_width(runs, scale)
    local total = 0
    for _, run in ipairs(runs) do
        total = total + util.drawn_width(run.text, scale)
    end
    return total
end

function util.draw_segments(segments, x, y, scale, alpha)
    for _, seg in ipairs(segments) do
        if seg.raw then
            util.text_raw(seg.text, x, y, scale, seg.r, seg.g, seg.b, alpha)
        else
            util.text(seg.text, x, y, scale, seg.r, seg.g, seg.b, alpha)
        end
        x = x + util.drawn_width(seg.text, scale)
    end
end

util.BOARD_NAME_LETTERS = 10

function util.board(x, y, title, rows, opts)
    opts = opts or {}
    local scale = opts.scale or 0.85
    local width = opts.width or 190
    local column = opts.column or (width - 60)
    local lineHeight = util.line_height(scale) + 4
    local max = opts.max or util.rows_that_fit(y + lineHeight, lineHeight)
    local shown = math.min(#rows, max)

    util.plate(x - 8, y - 5, width, lineHeight * (shown + 1) + 10)
    util.text(title, x, y, scale, util.gold().r, util.gold().g, util.gold().b, 255)
    y = y + lineHeight

    for place, entry in ipairs(rows) do
        if place > max then break end

        local r, g, b = util.name_colour()

        local at = x
        if entry.place ~= nil then
            local mark = tostring(entry.place) .. ".  "
            util.text(mark, at, y, scale, r, g, b, 255)
            at = at + util.drawn_width(mark, scale)
        end
        util.text_raw(util.shorten(entry.name, util.BOARD_NAME_LETTERS + 3),
            at, y, scale, r, g, b, 255)
        if entry.right ~= nil then
            util.text(entry.right, x + column, y, scale, 255, 255, 255, 255)
        end
        y = y + lineHeight
    end
    return y
end

local HEADLINE_PAD_X, HEADLINE_PAD_Y = 18, 10

function util.final_headline(text, y, scale)
    if type(text) ~= "string" or text == "" then return y end
    scale = scale or 1.8
    local width, height = util.text_size(text, scale)
    local x = (djui_hud_get_screen_width() - width) * 0.5
    util.plate(x - HEADLINE_PAD_X, y - HEADLINE_PAD_Y,
        width + HEADLINE_PAD_X * 2, height + HEADLINE_PAD_Y * 2,
        { accent = OF.GOLD })
    util.text(text, x, y, scale,
        util.gold().r, util.gold().g, util.gold().b, 255)
    return y + height
end

OF.LEVELS = {

    { name = "Castle Grounds",            group = "Castle", level = LEVEL_CASTLE_GROUNDS,   area = 1, act = 0 },
    { name = "Castle Lobby",              group = "Castle", level = LEVEL_CASTLE,           area = 1, act = 0 },
    { name = "Castle Upstairs",           group = "Castle", level = LEVEL_CASTLE,           area = 2, act = 0 },
    { name = "Castle Basement",           group = "Castle", level = LEVEL_CASTLE,           area = 3, act = 0 },
    { name = "Castle Courtyard",          group = "Castle", level = LEVEL_CASTLE_COURTYARD, area = 1, act = 0 },

    { name = "Bob-omb Battlefield",       group = "Courses", level = LEVEL_BOB, area = 1, act = 1 },
    { name = "Whomp's Fortress",          group = "Courses", level = LEVEL_WF,  area = 1, act = 1 },
    { name = "Jolly Roger Bay",           group = "Courses", level = LEVEL_JRB, area = 1, act = 1 },
    { name = "Jolly Roger Bay - Inside the Ship", group = "Courses", level = LEVEL_JRB, area = 2, act = 1 },
    { name = "Cool, Cool Mountain",       group = "Courses", level = LEVEL_CCM, area = 1, act = 1 },
    { name = "Cool, Cool Mountain - Slide", group = "Courses", level = LEVEL_CCM, area = 2, act = 1 },
    { name = "Big Boo's Haunt",           group = "Courses", level = LEVEL_BBH, area = 1, act = 1 },
    { name = "Hazy Maze Cave",            group = "Courses", level = LEVEL_HMC, area = 1, act = 1 },
    { name = "Lethal Lava Land",          group = "Courses", level = LEVEL_LLL, area = 1, act = 1 },
    { name = "Lethal Lava Land - Volcano", group = "Courses", level = LEVEL_LLL, area = 2, act = 1 },
    { name = "Shifting Sand Land",        group = "Courses", level = LEVEL_SSL, area = 1, act = 1 },
    { name = "Shifting Sand Land - Pyramid", group = "Courses", level = LEVEL_SSL, area = 2, act = 1 },
    { name = "Dire, Dire Docks",          group = "Courses", level = LEVEL_DDD, area = 1, act = 1 },
    { name = "Snowman's Land",            group = "Courses", level = LEVEL_SL,  area = 1, act = 1 },
    { name = "Snowman's Land - Igloo",    group = "Courses", level = LEVEL_SL,  area = 2, act = 1 },
    { name = "Wet-Dry World",             group = "Courses", level = LEVEL_WDW, area = 1, act = 1 },
    { name = "Tall, Tall Mountain",       group = "Courses", level = LEVEL_TTM, area = 1, act = 1 },
    { name = "Tall, Tall Mountain - Slide", group = "Courses", level = LEVEL_TTM, area = 2, act = 1 },
    { name = "Tiny-Huge Island (huge)",   group = "Courses", level = LEVEL_THI, area = 1, act = 1 },
    { name = "Tiny-Huge Island (tiny)",   group = "Courses", level = LEVEL_THI, area = 2, act = 1 },
    { name = "Tiny-Huge Island - Wiggler's Cave", group = "Courses", level = LEVEL_THI, area = 3, act = 1 },
    { name = "Tick Tock Clock",           group = "Courses", level = LEVEL_TTC, area = 1, act = 1 },
    { name = "Rainbow Ride",              group = "Courses", level = LEVEL_RR,  area = 1, act = 1 },

    { name = "Bowser in the Dark World",  group = "Bowser", level = LEVEL_BITDW,   area = 1, act = 0 },
    { name = "Bowser in the Fire Sea",    group = "Bowser", level = LEVEL_BITFS,   area = 1, act = 0 },
    { name = "Bowser in the Sky",         group = "Bowser", level = LEVEL_BITS,    area = 1, act = 0 },
    { name = "Bowser 1 Arena",            group = "Bowser", level = LEVEL_BOWSER_1, area = 1, act = 0 },
    { name = "Bowser 2 Arena",            group = "Bowser", level = LEVEL_BOWSER_2, area = 1, act = 0 },
    { name = "Bowser 3 Arena",            group = "Bowser", level = LEVEL_BOWSER_3, area = 1, act = 0 },

    { name = "Princess's Secret Slide",   group = "Secret", secret = true, level = LEVEL_PSS,   area = 1, act = 0 },
    { name = "Cavern of the Metal Cap",   group = "Secret", secret = true, level = LEVEL_COTMC, area = 1, act = 0 },
    { name = "Tower of the Wing Cap",     group = "Secret", secret = true, level = LEVEL_TOTWC, area = 1, act = 0 },
    { name = "Vanish Cap under the Moat", group = "Secret", secret = true, level = LEVEL_VCUTM, area = 1, act = 0 },
    { name = "Wing Mario over the Rainbow", group = "Secret", secret = true, level = LEVEL_WMOTR, area = 1, act = 0 },
    { name = "The Secret Aquarium",       group = "Secret", secret = true, level = LEVEL_SA,    area = 1, act = 0 },

}

OF.LEVEL_GROUPS = { "Castle", "Courses", "Bowser", "Secret" }

OF.WAYPOINT_GROUP = "Waypoints"
OF.BOWSER_GROUP = "Bowser"
function util.waypoint_destinations()
    if OF.waypoints == nil or OF.waypoints.list == nil then return {} end
    local list = {}
    for _, point in ipairs(OF.waypoints.list()) do
        table.insert(list, {
            name = point.name,
            group = OF.WAYPOINT_GROUP,
            level = point.level, area = point.area, act = point.act,
            point = point,
        })
    end
    return list
end

function util.levels_in_group(group)

    if group == "Mod levels" then return util.custom_levels() end
    if group == OF.WAYPOINT_GROUP then return util.waypoint_destinations() end

    local list = {}
    for _, entry in ipairs(OF.LEVELS) do
        if entry.group == group then table.insert(list, entry) end
    end
    return list
end

function util.level_groups()
    local groups = {}
    for _, group in ipairs(OF.LEVEL_GROUPS) do

        if #util.levels_in_group(group) > 0 then table.insert(groups, group) end
    end
    if #util.custom_levels() > 0 then table.insert(groups, "Mod levels") end

    if #util.waypoint_destinations() > 0 then
        table.insert(groups, OF.WAYPOINT_GROUP)
    end
    return groups
end

OF.COURSES = {
    { num = COURSE_BOB, name = "Bob-omb Battlefield",  level = LEVEL_BOB },
    { num = COURSE_WF,  name = "Whomp's Fortress",     level = LEVEL_WF },
    { num = COURSE_JRB, name = "Jolly Roger Bay",      level = LEVEL_JRB },
    { num = COURSE_CCM, name = "Cool, Cool Mountain",  level = LEVEL_CCM },
    { num = COURSE_BBH, name = "Big Boo's Haunt",      level = LEVEL_BBH },
    { num = COURSE_HMC, name = "Hazy Maze Cave",       level = LEVEL_HMC },
    { num = COURSE_LLL, name = "Lethal Lava Land",     level = LEVEL_LLL },
    { num = COURSE_SSL, name = "Shifting Sand Land",   level = LEVEL_SSL },
    { num = COURSE_DDD, name = "Dire, Dire Docks",     level = LEVEL_DDD },
    { num = COURSE_SL,  name = "Snowman's Land",       level = LEVEL_SL },
    { num = COURSE_WDW, name = "Wet-Dry World",        level = LEVEL_WDW },
    { num = COURSE_TTM, name = "Tall, Tall Mountain",  level = LEVEL_TTM },
    { num = COURSE_THI, name = "Tiny-Huge Island",     level = LEVEL_THI },
    { num = COURSE_TTC, name = "Tick Tock Clock",      level = LEVEL_TTC },
    { num = COURSE_RR,  name = "Rainbow Ride",         level = LEVEL_RR },
}

util.PAINTING_WIDTH = 64
util.PAINTING_HALF = 32

util.PAINTINGS = {
    [COURSE_BOB] = { bottom = "inside_castle_seg7_texture_0700B800",
                     top    = "inside_castle_seg7_texture_0700A800" },
    [COURSE_CCM] = { bottom = "inside_castle_seg7_texture_0700D800",
                     top    = "inside_castle_seg7_texture_0700C800" },
    [COURSE_WF]  = { bottom = "inside_castle_seg7_texture_0700F800",
                     top    = "inside_castle_seg7_texture_0700E800" },
    [COURSE_JRB] = { bottom = "inside_castle_seg7_texture_07011800",
                     top    = "inside_castle_seg7_texture_07010800" },
    [COURSE_LLL] = { bottom = "inside_castle_seg7_texture_07012800",
                     top    = "inside_castle_seg7_texture_07013800" },
    [COURSE_SSL] = { bottom = "inside_castle_seg7_texture_07015800",
                     top    = "inside_castle_seg7_texture_07014800" },
    [COURSE_WDW] = { bottom = "inside_castle_seg7_texture_07018800",
                     top    = "inside_castle_seg7_texture_07017800" },
    [COURSE_THI] = { bottom = "inside_castle_seg7_texture_0701A800",
                     top    = "inside_castle_seg7_texture_07019800" },
    [COURSE_TTM] = { bottom = "inside_castle_seg7_texture_0701C800",
                     top    = "inside_castle_seg7_texture_0701B800" },
    [COURSE_TTC] = { bottom = "inside_castle_seg7_texture_0701E800",
                     top    = "inside_castle_seg7_texture_0701D800" },
    [COURSE_SL]  = { bottom = "inside_castle_seg7_texture_07020800",
                     top    = "inside_castle_seg7_texture_0701F800" },
}

local paintingCache = {}

local function painting_texture(name)
    local held = paintingCache[name]
    if held ~= nil then
        if held == false then return nil end
        return held
    end
    if get_texture_info == nil then
        paintingCache[name] = false
        return nil
    end
    local ok, info = pcall(get_texture_info, name)
    if not ok or info == nil then
        paintingCache[name] = false
        return nil
    end
    paintingCache[name] = info
    return info
end

function util.has_painting(course)
    return util.PAINTINGS[course] ~= nil
end

function util.painting(course, x, y, scale, alpha)
    local pair = util.PAINTINGS[course]
    if pair == nil then return false end
    if djui_hud_render_texture == nil then return false end

    local top = painting_texture(pair.top)
    local bottom = painting_texture(pair.bottom)
    if top == nil or bottom == nil then return false end

    scale = scale or 1
    djui_hud_set_color(255, 255, 255, util.byte(alpha == nil and 255 or alpha))
    djui_hud_render_texture(top, x, y, scale, scale)
    djui_hud_render_texture(bottom, x, y + util.PAINTING_HALF * scale,
        scale, scale)
    return true
end

function util.every_destination()
    local list = {}
    for _, entry in ipairs(OF.LEVELS) do table.insert(list, entry) end
    for _, entry in ipairs(util.custom_levels()) do table.insert(list, entry) end
    for _, entry in ipairs(util.waypoint_destinations()) do
        table.insert(list, entry)
    end
    return list
end

function util.find_destination(text)
    local needle = string.lower(text or "")
    if needle == "" then return nil end

    local all = util.every_destination()
    for _, entry in ipairs(all) do
        if string.lower(entry.name) == needle then return entry end
    end
    for _, entry in ipairs(all) do
        if string.sub(string.lower(entry.name), 1, #needle) == needle then
            return entry
        end
    end
    for _, entry in ipairs(all) do
        if string.find(string.lower(entry.name), needle, 1, true) ~= nil then
            return entry
        end
    end
    return nil
end

function util.destination_act(entry)
    if type(entry) ~= "table" then return 0 end
    local fallback = math.floor(tonumber(entry.act) or 0)
    local level = entry.level
    if level == nil then return fallback end
    local area = entry.area

    local inArea, inLevel = nil, nil
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected and np.currLevelSyncValid
            and np.currLevelNum == level then
            local act = math.floor(tonumber(np.currActNum) or 0)
            if act ~= 99 then
                if np.currAreaSyncValid and np.currAreaIndex == area then
                    if inArea == nil then inArea = act end
                elseif inLevel == nil then
                    inLevel = act
                end
            end
        end
    end

    if inArea ~= nil then return inArea end
    if inLevel ~= nil then return inLevel end
    return fallback
end

util.SECRET_STAGE = "Secret stage"
function util.level_name(levelNum, areaIndex)
    if areaIndex ~= nil then
        for _, entry in ipairs(OF.LEVELS) do
            if entry.level == levelNum and entry.area == areaIndex then
                return entry.name
            end
        end
    end
    for _, entry in ipairs(OF.LEVELS) do
        if entry.level == levelNum then
            return entry.name
        end
    end

    if type(levelNum) ~= "number" then return "Unknown" end
    local ok, info = pcall(smlua_level_util_get_info, levelNum)
    if ok and info ~= nil then
        if info.fullName ~= nil and info.fullName ~= "" then return info.fullName end
        if info.shortName ~= nil and info.shortName ~= "" then return info.shortName end
    end
    return "Unknown"
end

function util.concealed_level_name(levelNum, areaIndex)
    if util.level_is_secret(levelNum, areaIndex) then return util.SECRET_STAGE end
    return util.level_name(levelNum, areaIndex)
end

function util.level_is_secret(levelNum, areaIndex)
    if type(levelNum) ~= "number" then return false end
    if areaIndex ~= nil then
        for _, entry in ipairs(OF.LEVELS) do
            if entry.level == levelNum and entry.area == areaIndex then
                return entry.secret == true
            end
        end
    end
    for _, entry in ipairs(OF.LEVELS) do
        if entry.level == levelNum then return entry.secret == true end
    end
    return false
end

function util.secret_order()
    for index, entry in ipairs(OF.LEVELS) do
        if entry.secret == true then return index end
    end
    return #OF.LEVELS + 1
end

function util.level_order(levelNum, areaIndex)
    if areaIndex ~= nil then
        for index, entry in ipairs(OF.LEVELS) do
            if entry.level == levelNum and entry.area == areaIndex then return index end
        end
    end
    for index, entry in ipairs(OF.LEVELS) do
        if entry.level == levelNum then return index end
    end
    return #OF.LEVELS + 1
end

local CUSTOM_LEVEL_NUM_START = 50
local CUSTOM_LEVEL_PROBE_END = 250

function util.custom_levels()
    local found = {}
    local list = {}

    local function take(info)
        while info ~= nil do
            local levelNum = info.levelNum
            if levelNum ~= nil and not found[levelNum] then
                found[levelNum] = true
                local name = info.fullName
                if name == nil or name == "" then name = info.shortName end
                if name ~= nil and name ~= "" then
                    table.insert(list, {
                        name = name,
                        group = "Mod levels",
                        level = levelNum,
                        area = 1,
                        act = 1,
                        custom = true,
                    })
                end
            end
            info = info.next
        end
    end

    for levelNum = CUSTOM_LEVEL_NUM_START, CUSTOM_LEVEL_PROBE_END do
        if not found[levelNum] then
            local ok, info = pcall(smlua_level_util_get_info, levelNum)
            if ok and info ~= nil then take(info) end
        end
    end

    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function util.course_name(courseNum)
    for _, entry in ipairs(OF.COURSES) do
        if entry.num == courseNum then return entry.name end
    end
    return "Course " .. tostring(courseNum)
end

function util.star_act_index(obj)
    if obj == nil or obj.oBehParams == nil then return nil end
    local raw = math.floor(obj.oBehParams / 16777216)

    if gLevelValues ~= nil and OF.util.flag(gLevelValues.useGlobalStarIds) == 1 then
        return (raw % 256) % 7
    end
    return raw % 32
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    util.limp_update(m)
end)

do

    local ledger = {}

    function util.lend_setting(name, holder, getter, setter, value)
        if name == nil or holder == nil then return false end
        if util.binding(setter) == nil then return false end
        local slot = ledger[name]
        if slot == nil then
            local was = util.optional(getter, nil)
            if was == nil then return false end
            slot = { was = was, holders = {}, count = 0, get = getter,
                set = setter, wants = {}, order = {} }
            ledger[name] = slot
        end
        if not slot.holders[holder] then
            slot.holders[holder] = true
            slot.count = slot.count + 1
            table.insert(slot.order, holder)
        end

        slot.wants[holder] = value
        slot.value = value
        util.optional(setter, nil, value)
        return true
    end

    function util.return_setting(name, holder)
        local slot = ledger[name]
        if slot == nil or holder == nil then return false end
        if not slot.holders[holder] then return false end
        slot.holders[holder] = nil
        slot.count = slot.count - 1
        slot.wants[holder] = nil
        for at = #slot.order, 1, -1 do
            if slot.order[at] == holder then table.remove(slot.order, at) end
        end
        if slot.count > 0 then

            local newest = slot.order[#slot.order]
            if newest ~= nil then
                slot.value = slot.wants[newest]
                util.optional(slot.set, nil, slot.value)
            end
            return true
        end
        ledger[name] = nil
        util.optional(slot.set, nil, slot.was)
        return true
    end

    function util.setting_was(name)
        local slot = ledger[name]
        if slot == nil then return nil end
        return slot.was
    end

    function util.setting_count(name)
        local slot = ledger[name]
        if slot == nil then return 0 end
        return slot.count
    end

    function util.setting_holders(name)
        local slot = ledger[name]
        local list = {}
        if slot == nil then return list end
        for holder in pairs(slot.holders) do table.insert(list, holder) end
        table.sort(list)
        return list
    end

    local NEWCAM = CAMERA_MODE_NEWCAM or 0x12

    local function settle_camera_mode()
        if gLakituState == nil or type(gLakituState.mode) ~= "number" then return false end

        if gLakituState.mode == NEWCAM then return false end
        local m = gMarioStates ~= nil and gMarioStates[0] or nil
        local camera = m ~= nil and m.area ~= nil and m.area.camera or nil
        if camera == nil or type(camera.mode) ~= "number" then return false end

        if camera.mode ~= NEWCAM then return false end
        camera.mode = gLakituState.mode
        return true
    end

    util.settle_camera_mode = settle_camera_mode

    function util.lend_free_cam(holder)
        local lent = util.lend_setting("freeCam", holder,
            "camera_config_is_free_cam_enabled",
            "camera_config_enable_free_cam", false)
        settle_camera_mode()
        return lent
    end

    function util.return_free_cam(holder)
        local given = util.return_setting("freeCam", holder)
        settle_camera_mode()
        return given
    end

    function util.lend_mouse_look(holder)
        local lent = util.lend_setting("cam.mouse", holder,
            "camera_config_is_mouse_look_enabled",
            "camera_config_enable_mouse_look", false)

        settle_camera_mode()
        return lent
    end

    function util.return_mouse_look(holder)
        local given = util.return_setting("cam.mouse", holder)
        settle_camera_mode()
        return given
    end

    function util.lend_hud_mouse(holder)
        return util.lend_setting("hudMouseLock", holder,
            "djui_hud_is_mouse_locked", "djui_hud_set_mouse_locked", false)
    end

    function util.return_hud_mouse(holder)
        return util.return_setting("hudMouseLock", holder)
    end

    function util.reset_camera_overrides()
        if util.binding("camera_reset_overrides") == nil then return false end
        util.optional("camera_reset_overrides", nil)
        for _, slot in pairs(ledger) do
            if slot.count > 0 and slot.value ~= nil then
                util.optional(slot.set, nil, slot.value)
            end
        end

        settle_camera_mode()
        return true
    end

    function util.forget_settings()
        ledger = {}
    end
end

do

    local MODES = {

        { key = "spectate", name = "spectating",
          at = function() return OF.spectate end, yields = false },
        { key = "photo", name = "photo mode",
          at = function() return OF.camera end, yields = true },
        { key = "forge", name = "the forge",
          at = function() return OF.forge end, yields = true },
        { key = "gun", name = "the doorway gun",
          at = function() return OF.doorways end, yields = true },
        { key = "noclip", name = "noclip",
          at = function() return OF.cheats end, yields = true },
    }

    local function ask(row, what)
        local owner = row.at()
        if not util.asks(owner, what) then return nil end
        if type(owner[what]) ~= "function" then return nil end
        return owner[what]()
    end

    local function row_live(row)
        return ask(row, "mode_live") == true
    end

    local function row_for(key)
        for _, row in ipairs(MODES) do
            if row.key == key then return row end
        end
        return nil
    end

    local stack = {}

    local busy = false

    local function say(text)
        if not util.asks(OF.notify, "show") then return end
        OF.notify.show(text, "info", 4)
    end

    local function settle()
        if busy then return false end
        busy = true
        local handed = nil
        while #stack > 0 do
            local entry = stack[#stack]

            if row_live(entry.by) then break end
            table.remove(stack)
            if ask(entry.row, "mode_resume") == true then
                handed = entry.row.name
                break
            end

        end
        busy = false
        if handed ~= nil then say(OF.lang.fill("@ is back", handed)) end
        return handed ~= nil
    end

    function util.hands_on()
        for _, row in ipairs(MODES) do
            if row_live(row) then return row.key, row.name end
        end
        return nil
    end

    function util.enter_mode(key)
        local row = row_for(key)
        if row == nil then return true end
        if busy then return true end

        for _, other in ipairs(MODES) do
            if other.key ~= key and not other.yields and row_live(other) then

                return false, OF.lang.fill("Stop @ first.", other.name)
            end
        end

        busy = true

        for i = #stack, 1, -1 do
            if stack[i].row.key == key then table.remove(stack, i) end
        end

        local took = nil
        for _, other in ipairs(MODES) do
            if other.key ~= key and row_live(other) then
                if ask(other, "mode_suspend") == true then
                    table.insert(stack, { row = other, by = row })
                    took = other.name
                end
            end
        end
        busy = false

        if took ~= nil then
            say(OF.lang.fill("@ is off until you are done", took))
        end
        return true
    end

    function util.leave_mode(key)
        local row = row_for(key)
        if row == nil then return false end
        return settle()
    end

    function util.mode_notice(key)
        local row = row_for(key)
        if row == nil then return nil end
        if row_live(row) then return nil end
        for _, other in ipairs(MODES) do
            if other.key ~= key and row_live(other) then
                if other.yields then
                    return OF.lang.fill(
                        "@ is on - this puts it away and gives it back after",
                        other.name)
                end
                return OF.lang.fill("@ is on - stop that first", other.name)
            end
        end
        return nil
    end

    function util.forget_modes()
        stack = {}
        busy = false
    end

    function util.suspended_modes()
        local list = {}
        for _, entry in ipairs(stack) do table.insert(list, entry.row.key) end
        return list
    end

    hook_event(HOOK_UPDATE, function()
        settle()
    end)
end

util.FLY_PACES = { 6, 20, 50, 110 }
util.FLY_PACE_NAMES = { "crawl", "walk", "sweep", "rush" }
util.FLY_SPRINT = 3
util.FLY_LIFT = 34

util.flyPace = 2

function util.fly_pace_name()
    return util.FLY_PACE_NAMES[util.flyPace] or util.FLY_PACE_NAMES[2]
end

function util.step_fly_pace(delta)
    local count = #util.FLY_PACES
    util.flyPace = ((util.flyPace - 1 + (delta or 1)) % count) + 1
    return true
end

function util.fly_speed(down)
    local base = util.FLY_PACES[util.flyPace] or util.FLY_PACES[2]
    if util.has_flag(down, A_BUTTON) then base = base * util.FLY_SPRINT end
    return base
end

function util.fly_lift(down)
    if util.has_flag(down, Z_TRIG) then return 0 end
    local lift = util.FLY_LIFT
    if util.has_flag(down, A_BUTTON) then lift = lift * util.FLY_SPRINT end
    if util.has_flag(down, R_TRIG) then return lift end
    if util.has_flag(down, L_TRIG) then return -lift end
    return 0
end

function util.fly_mag(stickX, stickY)
    local raw = math.sqrt((stickX or 0) * (stickX or 0) + (stickY or 0) * (stickY or 0))
    return math.min(raw, 64) / 64, math.max(raw, 1)
end

util.COIN_KINDS = {
    { model = E_MODEL_YELLOW_COIN, worth = 1, weight = 82 },
    { model = E_MODEL_RED_COIN,    worth = 2, weight = 14 },
    { model = E_MODEL_BLUE_COIN,   worth = 5, weight = 4 },
}

local KIND_WEIGHT_TOTAL = 0
for _, kind in ipairs(util.COIN_KINDS) do
    KIND_WEIGHT_TOTAL = KIND_WEIGHT_TOTAL + kind.weight
end

util.COIN_EVERY = 45
util.COIN_BURST = 5
util.COIN_SPREAD = 900
util.COIN_HEIGHT = 700
util.COIN_LIVE_MAX = 40

util.COIN_WORTH_MAX = 50

function util.coin_worth(obj)
    if obj == nil then return 1 end
    local value = obj.oDamageOrCoinValue
    if type(value) ~= "number" or value < 1 then return 1 end
    return math.floor(util.clamp(value, 1, util.COIN_WORTH_MAX))
end

function util.coin_kind()
    local roll = math.random(KIND_WEIGHT_TOTAL)
    for _, kind in ipairs(util.COIN_KINDS) do
        if roll <= kind.weight then return kind end
        roll = roll - kind.weight
    end
    return util.COIN_KINDS[1]
end

local function claim_worth(coin, kind)
    if coin == nil then return end
    coin.oInteractType = INTERACT_COIN
    coin.oDamageOrCoinValue = kind.worth
    coin.oHealth = 0
    coin.oNumLootCoins = 0
    local flags = coin.oFlags or 0
    if not util.has_flag(flags, OBJ_FLAG_30) then
        coin.oFlags = flags + OBJ_FLAG_30
    end
end

util.COIN_POUCH_MAX = 120

function util.coin_put(pouch, x, y, z, kind)
    if pouch == nil then return false end
    if #pouch >= util.COIN_POUCH_MAX then util.coin_live(pouch) end
    kind = kind or util.COIN_KINDS[1]
    local coin = util.optional("spawn_sync_object", nil,
        id_bhvSingleCoinGetsSpawned, kind.model, x, y, z,
        function(o) claim_worth(o, kind) end)
    if coin == nil then return false end
    table.insert(pouch, coin)
    return true
end

function util.coin_live(pouch)
    if pouch == nil then return 0 end
    local kept = 0
    for index = 1, #pouch do
        local coin = pouch[index]
        pouch[index] = nil
        if util.alive(coin) and coin.activeFlags ~= 0 then
            kept = kept + 1
            pouch[kept] = coin
        end
    end
    return kept
end

function util.coin_sweep(pouch)
    if pouch == nil then return end
    for _, coin in ipairs(pouch) do
        if util.alive(coin) then coin.activeFlags = 0 end
    end
end

function util.coin_rain(pouch, playing, options)
    if pouch == nil or playing == nil or #playing == 0 then return 0 end
    options = options or {}

    local room = (options.max or util.COIN_LIVE_MAX) - util.coin_live(pouch)
    if room <= 0 then return 0 end

    local spread = options.spread or util.COIN_SPREAD
    local height = options.height or util.COIN_HEIGHT
    local yellowOnly = options.plain == true

    local fell = 0
    for _ = 1, math.min(options.coins or util.COIN_BURST, room) do
        local entry = playing[math.random(#playing)]
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil then
            local kind = util.COIN_KINDS[1]
            if not yellowOnly then kind = util.coin_kind() end
            if util.coin_put(pouch,
                m.pos.x + math.random(-spread, spread),
                m.pos.y + height,
                m.pos.z + math.random(-spread, spread), kind) then
                fell = fell + 1
            end
        end
    end
    return fell
end
