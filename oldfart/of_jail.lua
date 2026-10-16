OF = OF or {}
OF.jail = OF.jail or {}

local jail = OF.jail

jail.PACKET = "jail"
jail.PACKET_ASK = "jailask"
local BAN_PREFIX = "ban_"
jail.SENTENCES = {

    {
        key = "timeout", name = "Frozen", short = "frozen",
        reason = "Frozen by the host",
        frozen = true, muted = false, moon = false, blind = false,
    },
    {
        key = "moon", name = "Moon jail", short = "on the moon",
        reason = "Sent to the moon",
        frozen = true, muted = false, moon = true, blind = false,
    },
    {
        key = "silence", name = "Silent freeze", short = "frozen and muted",
        reason = "Frozen and muted by the host",
        frozen = true, muted = true, moon = false, blind = false,
    },
    {
        key = "void", name = "The void", short = "in the void",
        reason = "Banished by the host",
        frozen = true, muted = true, moon = true, blind = true,
    },
}

function jail.sentence(key)
    for _, entry in ipairs(jail.SENTENCES) do
        if entry.key == key then return entry end
    end
    return jail.SENTENCES[1]
end

function jail.max_sentence()
    local best = jail.SENTENCES[1]
    local most = -1
    for _, entry in ipairs(jail.SENTENCES) do
        local parts = 0
        if entry.frozen then parts = parts + 1 end
        if entry.muted then parts = parts + 1 end
        if entry.moon then parts = parts + 1 end
        if entry.blind then parts = parts + 1 end
        if parts >= most then
            most = parts
            best = entry
        end
    end
    return best
end

jail.REASONS = {
    { key = "none",     text = "No reason given" },
    { key = "spam",     text = "Spamming the chat" },
    { key = "language", text = "Language" },
    { key = "harass",   text = "Going after another player" },
    { key = "grief",    text = "Griefing the lobby" },
    { key = "cheat",    text = "Cheating in a race" },
    { key = "asked",    text = "Would not stop when asked" },
}

function jail.reason_text(key)
    for _, entry in ipairs(jail.REASONS) do
        if entry.key == key then return entry.text end
    end
    return jail.REASONS[1].text
end

function jail.reason_key(key)
    for _, entry in ipairs(jail.REASONS) do
        if entry.key == key then return key end
    end
    return "none"
end

function jail.next_reason(key)
    for i, entry in ipairs(jail.REASONS) do
        if entry.key == key then
            return jail.REASONS[(i % #jail.REASONS) + 1].key
        end
    end
    return jail.REASONS[1].key
end

function jail.now()
    local value = tonumber(OF.util.optional("get_time", 0))

    if value == nil or value ~= value then return 0 end
    return math.floor(value)
end

function jail.until_text(expires)
    expires = tonumber(expires) or 0
    if expires <= 0 then return "forever" end
    local now = jail.now()
    if now <= 0 then return "until the host lifts it" end
    local left = expires - now
    if left <= 0 then return "over" end
    if left < 3600 then return jail.left_text(left) end
    if left < 86400 then
        return string.format("%.0fh", math.ceil(left / 3600))
    end
    return string.format("%.0fd", math.ceil(left / 86400))
end

local frames = 0

function jail.left_text(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then return string.format("%.0fs", seconds) end
    return string.format("%.0fm %02.0fs", math.floor(seconds / 60), seconds % 60)
end

local MAX_MINUTES = 120

function jail.minutes_for(sentence, minutes)
    local wanted = tonumber(minutes)
    if wanted == nil then wanted = sentence.minutes or 0 end
    if wanted ~= wanted then return 0 end
    wanted = math.floor(wanted)
    if wanted < 0 then return 0 end
    if wanted > MAX_MINUTES then return MAX_MINUTES end
    return wanted
end

jail.active = false
jail.reason = ""
jail.sentenceKey = "timeout"
jail.frozen = false
jail.moon = false
jail.blind = false
jail.moonY = nil

jail.case = nil

jail.endsIn = nil

local function clear_local()
    jail.active = false
    jail.reason = ""
    jail.frozen = false
    jail.moon = false
    jail.blind = false
    jail.moonY = nil
    jail.case = nil
    jail.endsIn = nil

    if OF.util.asks(OF.util, "stand_up") then OF.util.stand_up() end
end

function jail.apply_local(sentenceKey, reason, minutes, case)
    local sentence = jail.sentence(sentenceKey)
    jail.active = true
    jail.sentenceKey = sentence.key
    jail.reason = reason or sentence.reason
    jail.frozen = sentence.frozen
    jail.moon = sentence.moon
    jail.blind = sentence.blind
    jail.moonY = nil

    jail.case = (case ~= nil and case ~= "") and tostring(case) or nil

    local mins = tonumber(minutes) or 0
    jail.endsIn = (mins > 0) and math.floor(mins * 60 * 30) or nil

    if sentence.moon then
        OF.powerups.moon(gMarioStates[0])
        jail.moonY = gMarioStates[0].pos.y
    end

    OF.notify.show(jail.reason, "crit", 8)
    OF.chatlog.add_system(OF.lang.fill("jailed: @", jail.reason))
    play_sound(SOUND_MENU_CAMERA_BUZZ, gMarioStates[0].marioObj.header.gfx.cameraToObject)
end

function jail.release_local()
    if not jail.active then return end
    clear_local()
    OF.notify.show("You are free to move again", "good", 5)
    OF.chatlog.add_system(OF.lang.t("released from jail"))
end

jail.sentenced = jail.sentenced or {}
jail.forged = jail.forged or 0

jail.ends = jail.ends or {}

jail.voidByBan = jail.voidByBan or {}

function jail.time_left(localIndex)
    if not OF.util.is_host() then return nil end
    local at = jail.ends[localIndex]
    if at == nil then return nil end
    return math.max(0, math.floor((at - frames) / 30))
end

function jail.repair_row(localIndex)
    if not OF.util.is_host() then return false end
    if localIndex == nil or localIndex <= 0 then return false end

    local row = gPlayerSyncTable[localIndex]
    if row == nil then return false end

    local wanted = jail.sentenced[localIndex]
    local now = row.ofJailed

    if wanted == nil and (now == nil or now == "") then return false end
    if now == wanted then return false end

    OF.util.publish_row(localIndex, "ofJailed", wanted or "")
    jail.forged = jail.forged + 1

    local np = gNetworkPlayers[localIndex]
    OF.guard.tell(
        OF.lang.fill("Somebody tried to jail @. Put back. /kick removes them.",
            OF.util.plain(np ~= nil and np.name or "somebody")),
        "Somebody is jailing people who were not sentenced", 8)
    return true
end

function jail.forget_sentence(localIndex)
    jail.sentenced[localIndex] = nil

    jail.ends[localIndex] = nil

    jail.voidByBan[localIndex] = nil
end

jail.HOST_IS_SAFE = "The host cannot be locked out of their own lobby."
function jail.protects(localIndex)
    if localIndex == nil then return false end
    return OF.util.is_host_player(localIndex)
end

function jail.protects_id(playerId)
    if playerId == nil or playerId == "" then return false end
    if not OF.util.is_host() then return false end
    return OF.util.player_id(0) == playerId
end

local function open_case(kind, name, detail)
    if not OF.util.asks(OF.trouble, "open_case") then return nil end
    return OF.trouble.open_case(kind, name, detail)
end

local function case_suffix(code)
    if not OF.util.asks(OF.trouble, "case_suffix") then return "" end
    return OF.trouble.case_suffix(code)
end

function jail.punish(localIndex, sentenceKey, reason, minutes, case)
    if not OF.perms.can("jail") then return false, "Your rank cannot do that.", "jail" end
    if jail.protects(localIndex) then return false, jail.HOST_IS_SAFE end
    if localIndex == 0 then return false, "You cannot jail yourself." end

    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false, "That player has left." end

    local sentence = jail.sentence(sentenceKey)
    local mins = jail.minutes_for(sentence, minutes)
    local globalIndex = network_global_index_from_local(localIndex)

    if not OF.util.is_host() then
        OF.util.send_to_host({
            ofp = jail.PACKET_ASK,
            who = globalIndex,
            sent = sentence.key,
            mins = mins,
        })
        return true
    end

    if case == nil then
        case = open_case(sentence.short, np.name, reason or sentence.reason)
    end

    local actor = OF.notify.deed_take()

    OF.util.send_to_player(localIndex, {
        ofp = jail.PACKET,
        act = "hold",
        sent = sentence.key,
        why = reason or sentence.reason,
        mins = mins,
        case = case,
    })

    if sentence.muted then
        OF.mute.set(localIndex, true, true, nil, "sentence", 0, case)
    end

    jail.sentenced[localIndex] = sentence.key
    jail.ends[localIndex] = (mins > 0) and (frames + mins * 60 * 30) or nil

    jail.remember_sentence(localIndex, sentence.key, mins)
    OF.util.publish_row(localIndex, "ofJailed", sentence.key)

    local said = OF.lang.fill("@ is now @.", OF.util.plain(np.name), sentence.short)
    if mins > 0 then
        said = said .. " " .. OF.lang.fill("It lifts itself in @ minute(s).", mins)
    end

    said = said .. case_suffix(case)

    if OF.util.asked_in_chat() then
        OF.util.chat(said, "warn")
    else
        OF.notify.show(said, "crit")
    end

    OF.chatlog.add_system(OF.lang.fill("jailed @", np.name)
        .. " (" .. sentence.key
        .. (mins > 0 and string.format(", %.0f min", mins) or "") .. ")"
        .. case_suffix(case))
    OF.notify.deed_said(actor, "jail", localIndex)
    return true
end

function jail.release(localIndex, sendHome)
    if not OF.perms.can("jail") then return false, "Your rank cannot do that.", "jail" end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return false, "That player has left." end

    if not OF.util.is_host() then
        OF.util.send_to_host({
            ofp = jail.PACKET_ASK,
            act = "free",
            who = network_global_index_from_local(localIndex),
            home = sendHome and 1 or 0,
        })
        return true
    end

    OF.util.send_to_player(localIndex, { ofp = jail.PACKET, act = "free" })
    local actor = OF.notify.deed_take()

    OF.mute.set(localIndex, false, true)
    jail.sentenced[localIndex] = nil

    jail.ends[localIndex] = nil
    jail.voidByBan[localIndex] = nil

    jail.forget_stored_sentence(localIndex)
    OF.util.publish_row(localIndex, "ofJailed", "")

    if sendHome then
        OF.net.warp_player(network_global_index_from_local(localIndex),
            LEVEL_CASTLE_GROUNDS, 1, 0)
    end

    local freed = OF.lang.fill("@ has been released.", OF.util.plain(np.name))
    if OF.util.asked_in_chat() then
        OF.util.chat(freed)
    else
        OF.notify.show(freed, "good")
    end
    OF.chatlog.add_system(OF.lang.fill("released @", np.name))
    OF.notify.deed_said(actor, "free", localIndex)
    return true
end

function jail.is_jailed(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil or s.ofJailed == nil then return false end
    return s.ofJailed ~= ""
end

function jail.sentence_of(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil or s.ofJailed == nil or s.ofJailed == "" then return nil end
    return jail.sentence(s.ofJailed)
end

function jail.say_who_is_serving()
    if not OF.perms.can("jail") then
        return false, "Your rank cannot do that.", "jail"
    end

    local said = false
    for _, entry in ipairs(OF.util.connected_players()) do
        local sentence = jail.sentence_of(entry.localIndex)
        if sentence ~= nil then
            if not said then
                OF.util.chat(OF.lang.t("Serving a sentence right now:"))
                said = true
            end
            local left = jail.time_left(entry.localIndex)
            local line = OF.util.plain(entry.np.name) .. " - " .. sentence.short
            if left ~= nil then
                line = line .. "  " .. jail.left_text(left) .. " left"
            end
            OF.util.chat(line, nil, { more = true })
        end
    end

    if not said then
        OF.util.chat(OF.lang.t("Nobody is serving anything."))
    elseif not OF.util.is_host() then

        OF.util.chat(OF.lang.t("How long is left is the host's to see."), nil, { more = true })
    end
    return true
end

local SENTENCE_PREFIX = "sent_"
local SENTENCE_MARK = "1|"
local BAN_MARK = "2|"
local function read_ban(value)
    value = tostring(value or "")
    local made, expires2, reason2, name2 = string.match(value,
        "^2|(%-?%d+)|(%-?%d+)|([%w_]*)|(.*)$")
    if made ~= nil then
        return {
            made = tonumber(made) or 0,
            expires = tonumber(expires2) or 0,
            reason = reason2 ~= "" and reason2 or "none",
            name = name2,
        }
    end
    local expires, reason, name = string.match(value, "^1|(%-?%d+)|([%w_]*)|(.*)$")
    if expires ~= nil then
        return {
            made = 0,
            expires = tonumber(expires) or 0,
            reason = reason ~= "" and reason or "none",
            name = name,
        }
    end
    return { made = 0, expires = 0, reason = "none", name = value }
end

local function write_ban(name, expires, reason)

    return BAN_MARK .. string.format("%.0f", math.max(0, jail.now()))
        .. "|" .. string.format("%.0f", math.floor(tonumber(expires) or 0))
        .. "|" .. jail.reason_key(reason) .. "|" .. OF.util.storage_value(name)
end

function jail.tidy_entries()
    local list = {}
    if not OF.util.is_host() then return list end
    for key, value in pairs(mod_storage_load_all() or {}) do
        if string.sub(key, 1, #BAN_PREFIX) == BAN_PREFIX then
            local id = OF.util.storage_unescape(string.sub(key, #BAN_PREFIX + 1))
            list[#list + 1] = { keys = { key }, at = read_ban(value).made or 0,
                                who = { id } }
        end
    end
    return list
end

local function live_ban(playerId)
    local key = OF.util.storage_key(BAN_PREFIX, playerId)
    if not mod_storage_exists(key) then return nil end

    local entry = read_ban(mod_storage_load(key, ""))
    entry.id = playerId
    entry.key = key
    if entry.expires <= 0 then return entry end

    local now = jail.now()

    if now <= 0 then return entry end
    if entry.expires > now then return entry end

    mod_storage_remove(key)
    return nil
end

function jail.is_banned(playerId)
    if playerId == nil then return false end
    return live_ban(playerId) ~= nil
end

function jail.ban_entry(playerId)
    if playerId == nil then return nil end
    return live_ban(playerId)
end

jail.BAN_LENGTHS = {
    { key = "hour",    name = "for an hour",  minutes = 60 },
    { key = "day",     name = "for a day",    minutes = 1440 },
    { key = "week",    name = "for a week",   minutes = 10080 },
    { key = "forever", name = "forever",      minutes = 0 },
}

function jail.ban_length(key)
    for _, entry in ipairs(jail.BAN_LENGTHS) do
        if entry.key == key then return entry end
    end
    return jail.BAN_LENGTHS[#jail.BAN_LENGTHS]
end

function jail.next_ban_length(key)
    for i, entry in ipairs(jail.BAN_LENGTHS) do
        if entry.key == key then
            return jail.BAN_LENGTHS[(i % #jail.BAN_LENGTHS) + 1].key
        end
    end
    return jail.BAN_LENGTHS[1].key
end

local MAX_BAN_MINUTES = 525600

function jail.expiry_for(minutes)
    local wanted = tonumber(minutes)
    if wanted == nil or wanted ~= wanted then return 0 end
    wanted = math.floor(wanted)
    if wanted <= 0 then return 0 end
    if wanted > MAX_BAN_MINUTES then wanted = MAX_BAN_MINUTES end
    local now = jail.now()

    if now <= 0 then return 0 end
    return now + wanted * 60
end

function jail.is_name_ban(playerId)
    return playerId ~= nil and string.sub(playerId, 1, 2) == "nm"
end

function jail.name_match(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil or np.name == nil or np.name == "" then return nil end
    local id = OF.util.player_id(localIndex)
    local wanted = string.lower(np.name)
    for _, entry in ipairs(jail.ban_list()) do
        if entry.id ~= id and string.lower(entry.name) == wanted then
            return entry
        end
    end
    return nil
end

function jail.ban_list()
    local list = {}
    local all = mod_storage_load_all()
    if all == nil then return list end
    for key, value in pairs(all) do
        if string.sub(key, 1, #BAN_PREFIX) == BAN_PREFIX then
            local id = OF.util.storage_unescape(string.sub(key, #BAN_PREFIX + 1))
            local entry = read_ban(value)
            entry.id = id

            if live_ban(id) ~= nil then table.insert(list, entry) end
        end
    end
    table.sort(list, function(a, b)

        local aForever = a.expires <= 0
        local bForever = b.expires <= 0
        if aForever ~= bForever then return bForever end
        if not aForever and a.expires ~= b.expires then
            return a.expires < b.expires
        end
        return a.name < b.name
    end)
    return list
end

local function say_the_ban(label, expires, alreadyGone)
    if alreadyGone then
        OF.notify.show("Banned @ - it lands on their return", "crit", 6, label)
        return
    end
    OF.notify.show("Banned @ @", "crit", 6, label, jail.until_text(expires))
end

local function write_sentence(expires, key, name)
    return SENTENCE_MARK .. string.format("%.0f", math.floor(tonumber(expires) or 0))
        .. "|" .. tostring(key or "timeout")
        .. "|" .. tostring(name or "?")
end

local function read_sentence(value)
    local expires, key, name = string.match(tostring(value or ""),
        "^1|(%-?%d+)|([%w_]*)|(.*)$")
    if expires == nil then return nil end
    return {
        expires = tonumber(expires) or 0,
        key = key ~= "" and key or "timeout",
        name = name,
    }
end

function jail.tidy_sentences()
    local list = {}
    if not OF.util.is_host() then return list end
    for key, value in pairs(mod_storage_load_all() or {}) do
        if string.sub(key, 1, #SENTENCE_PREFIX) == SENTENCE_PREFIX then
            local id = OF.util.storage_unescape(string.sub(key, #SENTENCE_PREFIX + 1))
            list[#list + 1] = { keys = { key }, at = 0, who = { id } }
        end
    end
    return list
end

function jail.stored_sentence(playerId)
    if playerId == nil or not OF.util.is_host() then return nil end
    local key = OF.util.storage_key(SENTENCE_PREFIX, playerId)
    if not mod_storage_exists(key) then return nil end

    local entry = read_sentence(mod_storage_load(key, ""))
    if entry == nil then

        mod_storage_remove(key)
        return nil
    end

    local now = jail.now()
    if entry.expires > 0 and now > 0 and entry.expires <= now then
        mod_storage_remove(key)
        return nil
    end
    entry.id = playerId
    return entry
end

function jail.stored_minutes(entry)
    if entry == nil then return 0 end
    if (tonumber(entry.expires) or 0) <= 0 then return 0 end
    local now = jail.now()
    if now <= 0 then return 0 end
    local left = entry.expires - now
    if left <= 0 then return 0 end

    return math.ceil(left / 60)
end

function jail.remember_sentence(localIndex, sentenceKey, minutes)
    if not OF.util.is_host() then return false end
    minutes = tonumber(minutes) or 0

    local id = OF.util.player_id(localIndex)
    if id == nil then return false end

    local expires = 0
    if minutes > 0 then
        local now = jail.now()
        if now > 0 then expires = now + math.floor(minutes * 60) end
    end

    local np = gNetworkPlayers[localIndex]
    return OF.util.store(OF.util.storage_key(SENTENCE_PREFIX, id),
        OF.util.storage_value(write_sentence(expires,
            sentenceKey, np ~= nil and np.name or "?")))
end

function jail.forget_stored_sentence(localIndex, playerId)
    if not OF.util.is_host() then return false end
    local id = playerId
    if id == nil and localIndex ~= nil then id = OF.util.player_id(localIndex) end
    if id == nil then return false end
    return mod_storage_remove(OF.util.storage_key(SENTENCE_PREFIX, id))
end

function jail.forget_all_stored_sentences()
    if not OF.util.is_host() then return 0 end
    local all = mod_storage_load_all()
    if all == nil then return 0 end

    local ids = {}
    for key in pairs(all) do
        if string.sub(key, 1, #SENTENCE_PREFIX) == SENTENCE_PREFIX then
            table.insert(ids, key)
        end
    end

    local cleared = 0
    for _, key in ipairs(ids) do
        if mod_storage_remove(key) then cleared = cleared + 1 end
    end
    return cleared
end

function jail.ban(localIndex, minutes, reasonKey)
    if not OF.perms.can("ban") then return false, "Your rank cannot do that.", "ban" end

    if not OF.util.is_host() then
        if localIndex == 0 then return false, "You cannot ban yourself." end
        local who = network_global_index_from_local(localIndex)
        if who == nil then return false, "They have left the lobby." end
        return OF.net.host_does("banask", who, tonumber(minutes) or 0,
            tostring(reasonKey or "none"))
    end
    if jail.protects(localIndex) then return false, jail.HOST_IS_SAFE end
    if localIndex == 0 then return false, "You cannot ban yourself." end

    local id = OF.util.player_id(localIndex)
    local np = gNetworkPlayers[localIndex]
    if id == nil or np == nil then return false, "That player has no stable id." end

    local expires = jail.expiry_for(minutes)
    reasonKey = jail.reason_key(reasonKey)

    if not OF.util.store(OF.util.storage_key(BAN_PREFIX, id),
            write_ban(np.name, expires, reasonKey)) then
        return false, "The ban could not be saved, so nobody was banned."
    end

    local detail = jail.until_text(expires)
    if reasonKey ~= "none" then
        detail = detail .. ", " .. jail.reason_text(reasonKey)
    end
    local case = open_case("banned", np.name, detail)

    local actor = OF.notify.deed_take()

    local told = OF.lang.t("You are banned from this lobby")
    if reasonKey ~= "none" then
        told = told .. " - " .. jail.reason_text(reasonKey)
    end

    told = told .. case_suffix(case)
    if OF.util.report(jail.punish(localIndex, "void", told, nil, case)) then
        jail.voidByBan[localIndex] = true
    end
    say_the_ban(OF.util.plain(np.name), expires, false)
    jail.say_what_it_is_on(id)
    OF.chatlog.add_system(OF.lang.fill("banned @", np.name)
        .. " (" .. jail.until_text(expires) .. ", " .. reasonKey .. ")"
        .. case_suffix(case))
    OF.notify.deed_said(actor, "ban", localIndex)
    return true
end

function jail.say_what_it_is_on(playerId)
    if not jail.is_name_ban(playerId) then return false end

    OF.notify.show("That ban is on the name - a rename walks past it", "warn", 6)
    return true
end

function jail.ban_absent(playerId, name, minutes, reasonKey)
    if not OF.perms.can("ban") then return false, "Your rank cannot do that.", "ban" end

    if not OF.util.is_host() then
        if playerId == nil or playerId == "" then
            return false, "That player has no stable id."
        end
        return OF.net.host_does("banabsentask", tonumber(minutes) or 0, nil,
            tostring(reasonKey or "none") .. "|" .. tostring(playerId)
                .. "|" .. tostring(name or ""))
    end
    if playerId == nil or playerId == "" then
        return false, "That player has no stable id."
    end

    if jail.protects_id(playerId) then return false, jail.HOST_IS_SAFE end
    if jail.is_banned(playerId) then return false, "They are already banned." end

    local label = OF.util.storage_value(name)
    if label == "" then label = playerId end

    local expires = jail.expiry_for(minutes)
    reasonKey = jail.reason_key(reasonKey)

    if not OF.util.store(OF.util.storage_key(BAN_PREFIX, playerId),
            write_ban(label, expires, reasonKey)) then
        return false, "The ban could not be saved, so nobody was banned."
    end

    local detail = jail.until_text(expires)
    if reasonKey ~= "none" then
        detail = detail .. ", " .. jail.reason_text(reasonKey)
    end
    local case = open_case("banned", label, detail)

    say_the_ban(label, expires, true)
    jail.say_what_it_is_on(playerId)
    OF.chatlog.add_system(OF.lang.fill("banned @", label)
        .. " " .. OF.lang.t("(had already left)")
        .. " (" .. jail.until_text(expires) .. ", " .. reasonKey .. ")"
        .. case_suffix(case))
    return true
end

function jail.amnesty(askerLocal)
    if not OF.perms.can("jail") then
        return false, "Your rank cannot do that.", "jail"
    end
    if not OF.util.is_host() then
        return false, "Only the host can lift everything."
    end

    local lifted = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local had = false

        if jail.is_jailed(li) then

            if OF.util.report(jail.release(li, false)) then had = true end
        end
        if OF.util.asks(OF.mute, "is_muted") and OF.mute.is_muted(li) then
            OF.mute.set(li, false, true)
            had = true
        end

        if OF.util.asks(OF.speedrun, "chose_out")
            and OF.speedrun.chose_out(li) and not OF.speedrun.muted_out(li) then
            OF.speedrun.set_excluded(li, false)
            had = true
        end

        if had then lifted = lifted + 1 end
    end

    local filed = 0
    if OF.util.asks(OF.mute, "forget_all_stored") then
        filed = OF.mute.forget_all_stored()
    end

    filed = filed + jail.forget_all_stored_sentences()

    local who = OF.util.presser(askerLocal)
    if who ~= nil then
        OF.notify.send_all("@ lifted everything", "good", 5, who)
    else
        OF.notify.send_all("The host lifted everything", "good", 5)
    end
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.t("lifted every mute and sentence"))
    end
    OF.notify.show("Everything lifted: @ player(s) are clear", "good", 5, lifted)

    if filed > 0 then
        OF.notify.show("@ record(s) for people who are not here, cleared too",
            "good", 5, filed)
    end
    OF.chatlog.add_system(OF.lang.fill("lifted everything from @ player(s)",
        lifted), who)
    return true
end

function jail.clear_player(localIndex)
    if not OF.perms.can("jail") then return false, "Your rank cannot do that.", "jail" end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false, "That player has left." end

    local id = OF.util.player_id(localIndex)
    local lifted = {}

    if id ~= nil and jail.is_banned(id) then
        if OF.perms.can("ban") then
            if OF.util.report(jail.unban(id)) then
                table.insert(lifted, "the ban")
            end
        else

            OF.notify.show("The ban list is the host's - ask them to lift it",
                "bad", 5)
        end
    end

    if jail.is_jailed(localIndex) then
        if OF.util.report(jail.release(localIndex, true)) then
            table.insert(lifted, "the sentence")
        end
    end
    if OF.util.asks(OF.mute, "is_muted") and OF.mute.is_muted(localIndex) then
        if OF.util.report(OF.mute.set(localIndex, false)) then
            table.insert(lifted, "the mute")
        end
    end
    if OF.util.asks(OF.speedrun, "chose_out")
        and OF.speedrun.chose_out(localIndex) and not OF.speedrun.muted_out(localIndex) then
        OF.speedrun.set_excluded(localIndex, false)
        table.insert(lifted, "sitting out races")
    end

    if #lifted == 0 then
        return false, "There is nothing on them to take off."
    end

    OF.notify.show("Took @ off @", "good", 5,
        table.concat(lifted, ", "), OF.util.plain(np.name))
    OF.notify.send_to(network_global_index_from_local(localIndex),
        "That was a mistake - you are clear", "good", 6)
    OF.chatlog.add_system(OF.lang.fill("took everything off @", np.name))
    return true
end

function jail.unban(playerId)
    if not OF.perms.can("ban") then return false, "Your rank cannot do that.", "ban" end
    if not OF.util.is_host() then
        return OF.net.host_does("unbanask", nil, nil, tostring(playerId or ""))
    end
    mod_storage_remove(OF.util.storage_key(BAN_PREFIX, playerId))

    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local matches = OF.util.player_id(li) == playerId
        local strandedInVoid = jail.sentence_of(li) ~= nil
            and jail.sentence_of(li).key == "void"
            and not jail.is_banned(OF.util.player_id(li))

        if matches or strandedInVoid then
            OF.util.report(jail.release(li, true))
            OF.notify.send_to(network_global_index_from_local(li),
                "Your ban was lifted. Welcome back.", "good", 6)
        end
    end

    OF.chatlog.add_system(OF.lang.fill("unbanned @", tostring(playerId)))
    return true
end

local WARN_PREFIX = "warn_"
local WARN_MARK = "1|"
local ESCALATE_KEY = "warnauto"
local WINDOW_KEY = "warnwindow"
local MUTE_RUNG_KEY = "warnmuteat"
local JAIL_RUNG_KEY = "warnjailat"
jail.WARN_TO_MUTE = 2
jail.WARN_TO_JAIL = 3

jail.WARN_RUNG_MIN = 1
jail.WARN_RUNG_MAX = 5

jail.WARN_WINDOWS = {
    { key = "never", name = "never",          days = 0 },
    { key = "day",   name = "after a day",    days = 1 },
    { key = "week",  name = "after a week",   days = 7 },
    { key = "month", name = "after a month",  days = 30 },
}

local function read_warn(value)
    value = tostring(value or "")
    local count, at, reason, name = string.match(value,
        "^1|(%d+)|(%-?%d+)|([%w_]*)|(.*)$")
    if count ~= nil then
        return {
            count = tonumber(count) or 0,
            at = tonumber(at) or 0,
            reason = reason ~= "" and reason or "none",
            name = name,
        }
    end

    return { count = 1, at = 0, reason = "none", name = value }
end

function jail.tidy_warnings()
    local list = {}
    if not OF.util.is_host() then return list end
    for key, value in pairs(mod_storage_load_all() or {}) do
        if string.sub(key, 1, #WARN_PREFIX) == WARN_PREFIX then
            local id = OF.util.storage_unescape(string.sub(key, #WARN_PREFIX + 1))
            list[#list + 1] = { keys = { key }, at = read_warn(value).at or 0,
                                who = { id } }
        end
    end
    return list
end

function jail.warn_record(playerId)
    if playerId == nil or not OF.util.is_host() then return nil end
    local key = OF.util.storage_key(WARN_PREFIX, playerId)
    if not mod_storage_exists(key) then return nil end
    local entry = read_warn(mod_storage_load(key, ""))
    if entry == nil then return nil end
    entry.id = playerId
    return entry
end

function jail.warn_count(playerId)
    local entry = jail.warn_record(playerId)
    return entry ~= nil and entry.count or 0
end

function jail.warn_list()
    local list = {}
    if not OF.util.is_host() then return list end
    local all = mod_storage_load_all()
    if all == nil then return list end
    for key, value in pairs(all) do
        if string.sub(key, 1, #WARN_PREFIX) == WARN_PREFIX then
            local entry = read_warn(value)
            if entry ~= nil then
                entry.id = OF.util.storage_unescape(string.sub(key, #WARN_PREFIX + 1))
                table.insert(list, entry)
            end
        end
    end
    table.sort(list, function(a, b)
        if a.at ~= b.at then return a.at > b.at end
        return a.name < b.name
    end)
    return list
end

local warnCountMemo = {}

function jail.warn_total()
    return OF.util.stored_count(warnCountMemo, jail.warn_list)
end

local banCountMemo = {}

function jail.ban_count()
    return OF.util.stored_count(banCountMemo, jail.ban_list,
        function(entry) return entry.expires end)
end

function jail.escalates()
    return mod_storage_load_bool(ESCALATE_KEY, true)
end

function jail.set_escalates(on)
    if not OF.util.is_host() then
        return false, "The warning ladder is the host's."
    end
    if not OF.util.store_bool(ESCALATE_KEY, on == true) then
        return false, "That could not be saved."
    end
    OF.chatlog.add_system(on and "warnings escalate by themselves"
        or "warnings no longer escalate by themselves")
    return true
end

function jail.warn_window(key)
    if key == nil then key = mod_storage_load(WINDOW_KEY, jail.WARN_WINDOWS[1].key) end
    for _, entry in ipairs(jail.WARN_WINDOWS) do
        if entry.key == key then return entry end
    end
    return jail.WARN_WINDOWS[1]
end

function jail.next_warn_window(key)
    for i, entry in ipairs(jail.WARN_WINDOWS) do
        if entry.key == key then
            return jail.WARN_WINDOWS[(i % #jail.WARN_WINDOWS) + 1].key
        end
    end
    return jail.WARN_WINDOWS[1].key
end

function jail.set_warn_window(key)
    if not OF.util.is_host() then
        return false, "The warning ladder is the host's."
    end
    local wanted = jail.warn_window(key)
    if not OF.util.store(WINDOW_KEY, wanted.key) then
        return false, "That could not be saved."
    end
    OF.chatlog.add_system(OF.lang.fill("warnings stop counting @", wanted.name))
    return true
end

function jail.warn_rungs()
    local muteAt = mod_storage_load_integer(MUTE_RUNG_KEY, jail.WARN_TO_MUTE)
    local jailAt = mod_storage_load_integer(JAIL_RUNG_KEY, jail.WARN_TO_JAIL)
    muteAt = math.max(jail.WARN_RUNG_MIN, math.min(jail.WARN_RUNG_MAX, muteAt))
    jailAt = math.max(jail.WARN_RUNG_MIN, math.min(jail.WARN_RUNG_MAX, jailAt))
    if jailAt < muteAt then jailAt = muteAt end
    return muteAt, jailAt
end

function jail.reset_options()
    if not OF.util.is_host() then return false end
    local muteAt, jailAt = jail.warn_rungs()
    local moved = muteAt ~= jail.WARN_TO_MUTE or jailAt ~= jail.WARN_TO_JAIL
        or jail.warn_window().key ~= jail.WARN_WINDOWS[1].key or not jail.escalates()
    if not moved then return false end
    OF.util.store_integer(MUTE_RUNG_KEY, jail.WARN_TO_MUTE)
    OF.util.store_integer(JAIL_RUNG_KEY, jail.WARN_TO_JAIL)
    OF.util.store(WINDOW_KEY, jail.WARN_WINDOWS[1].key)
    OF.util.store_bool(ESCALATE_KEY, true)
    return true
end

function jail.set_warn_rung(which, value)
    if not OF.util.is_host() then
        return false, "The warning ladder is the host's."
    end
    value = math.floor(tonumber(value) or 0)
    if value ~= value then return false, "That is not a number." end
    if value < jail.WARN_RUNG_MIN then value = jail.WARN_RUNG_MIN end
    if value > jail.WARN_RUNG_MAX then value = jail.WARN_RUNG_MAX end
    local key = (which == "jail") and JAIL_RUNG_KEY or MUTE_RUNG_KEY
    if not OF.util.store_integer(key, value) then
        return false, "That could not be saved."
    end
    OF.chatlog.add_system(OF.lang.fill("warning @ is now @", value,
        (which == "jail") and "a freeze" or "a mute"))
    return true
end

function jail.warn_ladder_text()
    local muteAt, jailAt = jail.warn_rungs()
    return OF.lang.fill("warning @ is a mute, @ is a freeze that stays until lifted",
        string.format("%.0f", muteAt), string.format("%.0f", jailAt))
end

function jail.warn_live(entry)
    if entry == nil then return 0 end
    local count = tonumber(entry.count) or 0
    if count <= 0 then return 0 end

    local days = jail.warn_window().days
    if days <= 0 then return count end

    local at = tonumber(entry.at) or 0
    if at <= 0 then return count end
    local now = jail.now()
    if now <= 0 then return count end

    if now - at >= days * 86400 then return 0 end
    return count
end

function jail.warn_count_live(playerId)
    return jail.warn_live(jail.warn_record(playerId))
end

function jail.warn_next_step(playerId)
    if not jail.escalates() then return nil end
    local muteAt, jailAt = jail.warn_rungs()
    local next = jail.warn_count_live(playerId) + 1
    if next >= jailAt then return "a freeze" end
    if next >= muteAt then return "a mute" end
    return nil
end

function jail.warn_window_row(panel)
    local window = jail.warn_window()
    local built = panel.gated_row("mute",
        OF.lang.t("Warnings stop counting"), 255, 220, 120,
        function()
            OF.util.report(jail.set_warn_window(
                jail.next_warn_window(jail.warn_window().key)))
        end)
    built = panel.picker_row(built, window.name,
        window.key ~= jail.WARN_WINDOWS[1].key)
    return panel.with_help(built, OF.lang.t(
        "an old warning stays on the record but stops pushing anybody up a rung"))
end

function jail.warn_rung_row(panel, which)
    local muteAt, jailAt = jail.warn_rungs()
    local at = (which == "jail") and jailAt or muteAt
    local built = panel.gated_row("mute",
        (which == "jail") and OF.lang.t("A freeze lands on warning")
            or OF.lang.t("A mute lands on warning"),
        255, 220, 120,
        function()
            local wanted = at + 1
            if wanted > jail.WARN_RUNG_MAX then wanted = jail.WARN_RUNG_MIN end
            OF.util.report(jail.set_warn_rung(which, wanted))
        end)
    built = panel.with_right(built, string.format("%.0f", at))
    built = panel.with_slider(built, at, jail.WARN_RUNG_MAX, function(wanted)
        OF.util.report(jail.set_warn_rung(which, wanted))
    end)
    return panel.with_help(built, (which == "jail")
        and OF.lang.t("the freeze is never below the mute; dragging it under one moves both")
        or OF.lang.t("which warning turns into a mute, if the ladder is on at all"))
end

function jail.warn(localIndex, reasonKey)
    if not OF.perms.can("mute") then return false, "Your rank cannot do that.", "mute" end
    if jail.protects(localIndex) then return false, jail.HOST_IS_SAFE end
    if localIndex == 0 then return false, "You cannot warn yourself." end

    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false, "That player has left." end

    if not OF.util.is_host() then
        return OF.net.host_does("warn",
            network_global_index_from_local(localIndex), reasonKey)
    end

    local id = OF.util.player_id(localIndex)
    if id == nil then return false, "That player has no stable id." end
    reasonKey = jail.reason_key(reasonKey)

    local was = jail.warn_record(id)
    local count = jail.warn_live(was) + 1

    if not OF.util.store(OF.util.storage_key(WARN_PREFIX, id),
            WARN_MARK .. string.format("%.0f", count) .. "|"
                .. string.format("%.0f", jail.now()) .. "|" .. reasonKey
                .. "|" .. OF.util.storage_value(np.name)) then
        return false, "The warning could not be saved, so nobody was warned."
    end

    local actor = OF.notify.deed_take()

    local _, jailAt = jail.warn_rungs()
    local case = open_case("a warning", np.name, jail.reason_text(reasonKey))

    local globalIndex = network_global_index_from_local(localIndex)
    if reasonKey == "none" then
        OF.notify.send_to(globalIndex, "Warning @ of @ from a moderator", "crit", 6,
            string.format("%.0f", count), string.format("%.0f", jailAt))
    else
        OF.notify.send_to(globalIndex, "Warning: @", "crit", 6,
            jail.reason_text(reasonKey))
    end

    OF.notify.show("Warned @ (@)", "warn", 6,
        OF.util.plain(np.name),
        OF.lang.fill("@ of @", string.format("%.0f", count),
            string.format("%.0f", jailAt)))
    OF.chatlog.add_system(OF.lang.fill("warned @", np.name)
        .. " (" .. string.format("%.0f", count) .. ", " .. reasonKey .. ")"
        .. case_suffix(case))
    if OF.util.asks(OF.recent, "note") then
        OF.recent.note(localIndex, OF.lang.t("was warned"))
    end

    local muteAt = jail.warn_rungs()
    if jail.escalates() then
        if count >= jailAt then
            OF.util.report(jail.punish(localIndex, "timeout",
                OF.lang.fill("Warning @: @", string.format("%.0f", count),
                    jail.reason_text(reasonKey)), nil, case))
        elseif count >= muteAt then
            if OF.util.asks(OF.mute, "set") then

                OF.util.report(OF.mute.set(localIndex, true, false,
                    reasonKey, "warnings", nil, case))
            end
        end
    end
    OF.notify.deed_said(actor, "warn", localIndex)
    return true
end

function jail.forgive(localIndex)
    if not OF.perms.can("mute") then return false, "Your rank cannot do that.", "mute" end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return false, "That player has left." end

    if not OF.util.is_host() then
        return OF.net.host_does("forgive",
            network_global_index_from_local(localIndex))
    end

    local id = OF.util.player_id(localIndex)
    if id == nil then return false, "That player has no stable id." end
    if jail.warn_count(id) == 0 then
        return false, "There is nothing on their record."
    end

    mod_storage_remove(OF.util.storage_key(WARN_PREFIX, id))

    OF.notify.show("@ has a clean record again", "good", 5,
        OF.util.plain(np.name))
    OF.notify.send_to(network_global_index_from_local(localIndex),
        "Your warnings have been cleared", "good", 5)
    OF.chatlog.add_system(OF.lang.fill("cleared the warnings on @", np.name))
    return true
end

function jail.forgive_all()
    if not OF.util.is_host() then
        return false, "The warning list is the host's."
    end
    if not OF.perms.can("mute") then return false, "Your rank cannot do that.", "mute" end

    local cleared = 0
    for _, entry in ipairs(jail.warn_list()) do
        mod_storage_remove(OF.util.storage_key(WARN_PREFIX, entry.id))
        cleared = cleared + 1
    end

    OF.notify.show("@ record(s) wiped", "good", 5, cleared)
    OF.chatlog.add_system(OF.lang.fill("wiped @ warning record(s)", cleared))
    return true
end

jail.PACKET_APPEAL = "jailappeal"
local APPEAL_EVERY = 1800

local appealedAt = -99999

function jail.may_appeal()
    if OF.util.is_host() then return false end
    if jail.active then return true end
    if OF.util.asks(OF.mute, "is_muted") and OF.mute.is_muted(0) then return true end
    return false
end

function jail.appeal(code)
    if OF.util.is_host() then
        return false, "You are the host - there is nobody to ask."
    end
    if not jail.may_appeal() then
        return false, "Nothing is being held against you."
    end
    if frames - appealedAt < APPEAL_EVERY then
        return false, "Already asked - give them a moment."
    end

    local named = OF.util.plain(tostring(code or ""))
    named = string.match(named, "^%s*(.-)%s*$") or ""
    if named == "" then named = jail.case end

    local ok, why = OF.util.send_to_host({
        ofp = jail.PACKET_APPEAL,
        case = named,
    })
    if not ok then return false, why or "There is no host to ask." end
    appealedAt = frames
    return true, "The host has been told."
end

function jail.hear_appeal(data)
    if not OF.util.is_host() then return false end

    local asker = OF.util.asked_by(data)
    if asker == nil then return false end

    local np = gNetworkPlayers[asker]
    if np == nil or not np.connected then return false end
    local who = OF.util.plain(np.name)

    local about = ""
    OF.notify.show("@ says it was the wrong person@", "warn", 8, who, about)
    if OF.util.asks(OF.recent, "note") then
        OF.recent.note(asker, OF.lang.t("says it was the wrong person"))
    end
    OF.chatlog.add_system(OF.lang.fill("@ appealed", np.name) .. about)
    return true
end

local function serve_the_rest(localIndex)
    if not OF.util.is_host() then return false end
    local id = OF.util.player_id(localIndex)
    local entry = jail.stored_sentence(id)
    if entry == nil then return false end

    if jail.protects(localIndex) or jail.protects_id(id) then
        jail.forget_stored_sentence(nil, id)
        return false
    end

    local left = jail.stored_minutes(entry)

    local np = gNetworkPlayers[localIndex]
    if not OF.util.report(jail.punish(localIndex, entry.key, nil, left)) then
        return false
    end

    local heldFor = (left > 0) and jail.left_text(left * 60)
        or OF.lang.t("until the host lifts it")
    OF.notify.send_to(network_global_index_from_local(localIndex),
        "Your sentence was still standing. @.", "crit", 7, heldFor)

    OF.notify.show("@ came back still serving - @", "warn", 6,
        OF.util.plain(np ~= nil and np.name or "?"), heldFor)
    OF.chatlog.add_system(
        OF.lang.fill("@ rejoined still serving", np ~= nil and np.name or "?"),
        OF.util.asks(OF.actionlog, "auto") and OF.actionlog.BY_THE_ROOM or nil)
    return true
end

function jail.check_on_join(localIndex)
    if not OF.util.is_host() then return end
    local id = OF.util.player_id(localIndex)
    if not jail.is_banned(id) then

        serve_the_rest(localIndex)

        local match = jail.name_match(localIndex)
        if match ~= nil then
            local rejoined = gNetworkPlayers[localIndex]

            OF.notify.show("@ has the name of a banned player", "warn", 8,
                OF.util.plain(rejoined.name))

            OF.chatlog.add_system(OF.lang.fill("@ joined under a banned name",
                rejoined.name),
                OF.util.asks(OF.actionlog, "auto")
                    and OF.actionlog.BY_THE_ROOM or nil)
            if OF.util.asks(OF.recent, "note") then
                OF.recent.note(localIndex,
                    OF.lang.t("joined under a banned name"))
            end
        end
        return
    end

    if jail.protects(localIndex) or jail.protects_id(id) then
        mod_storage_remove(OF.util.storage_key(BAN_PREFIX, id))
        return
    end
    local np = gNetworkPlayers[localIndex]

    OF.notify.show("@ rejoined and was put back in the void", "crit", 8,
        OF.util.plain(np.name))

    local entry = jail.ban_entry(id)
    local told = OF.lang.t("You are banned from this lobby")
    if entry ~= nil then
        if entry.reason ~= "none" then
            told = told .. " - " .. jail.reason_text(entry.reason)
        end
        if entry.expires > 0 then
            told = told .. " (" .. jail.until_text(entry.expires) .. " left)"
        end
    end
    if OF.util.report(jail.punish(localIndex, "void", told)) then
        jail.voidByBan[localIndex] = true
    end
end

local function on_packet_receive(data)
    if data == nil then return end

    if data.ofp == jail.PACKET_APPEAL then
        jail.hear_appeal(data)
        return
    end

    if data.ofp == jail.PACKET_ASK then
        if not OF.util.is_host() then return end

        local asker, askerGlobal = OF.util.asked_by(data)
        if asker == nil then return end

        if OF.perms.tier(asker) < OF.perms.required("jail", asker) then
            OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
            return
        end

        local target = OF.util.local_from_global(data.who)

        local may, whyNot = OF.util.may_act_on(asker, target)
        if not may then
            OF.util.tell_asker(askerGlobal, whyNot)
            return
        end

        if data.act == "free" then
            local freed, reason = OF.notify.acting(asker, jail.release, target, data.home == 1)
            if not freed then
                OF.notify.send_to(askerGlobal, "@", "bad", 5, tostring(reason))
            end
            return
        end

        local ok, why = OF.notify.acting(asker, jail.punish, target, data.sent,
            OF.lang.fill("@ asked for it", gNetworkPlayers[asker].name), data.mins)
        if not ok then
            OF.notify.send_to(askerGlobal, "@", "bad", 5, tostring(why))
        end
        return
    end

    if data.ofp ~= jail.PACKET then return end
    if not OF.util.from_host(data) then return end

    if data.act == "hold" then
        jail.apply_local(data.sent, data.why, data.mins, data.case)
    elseif data.act == "free" then
        jail.release_local()
    end
end

hook_on_sync_table_change(gPlayerSyncTable[0], "ofJailed", 0, function(tag, oldVal, newVal)
    if OF.util.asks(OF.guard, "repair_my_row")
        and OF.guard.repair_my_row("ofJailed") then
        return
    end

    if OF.util.asks(OF.gamemodes, "forget_participants") then
        OF.gamemodes.forget_participants()
    end

    if newVal == nil or newVal == "" then jail.release_local() end
end)

local ORPHAN_FRAMES = 60
local orphaned = 0

local function sentence_on_my_row()
    local row = gPlayerSyncTable[0]
    if row == nil then return true end
    return row.ofJailed ~= nil and row.ofJailed ~= ""
end

local function serve_time()
    if not OF.util.is_host() then return end
    for localIndex, at in pairs(jail.ends) do
        if frames >= at then

            jail.ends[localIndex] = nil

            local np = gNetworkPlayers[localIndex]
            if np ~= nil and np.connected then
                local serving = jail.sentence(jail.sentenced[localIndex])
                if OF.util.report(jail.release(localIndex, serving.moon)) then

                    OF.notify.show("@ served their time", "quiet", 4,
                        OF.util.plain(np.name))

                    OF.chatlog.add_system(
                        OF.lang.fill("sentence ran out for @", np.name),
                        OF.util.asks(OF.actionlog, "auto")
                            and OF.actionlog.BY_THE_ROOM or nil)
                end
            end
        end
    end
end

local BAN_SWEEP_FRAMES = 30
local banSweep = 0

local function serve_bans()
    if not OF.util.is_host() then return end
    banSweep = banSweep + 1
    if banSweep < BAN_SWEEP_FRAMES then return end
    banSweep = 0

    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local serving = jail.sentence_of(li)
        if serving ~= nil and serving.key == "void"
            and jail.voidByBan[li] == true
            and not jail.is_banned(OF.util.player_id(li)) then
            if OF.util.report(jail.release(li, true)) then
                OF.notify.send_to(network_global_index_from_local(li),
                    "Your ban has run out. Welcome back.", "good", 6)

                OF.notify.show("@'s ban ran out", "quiet", 4,
                    OF.util.plain(entry.np.name))

                OF.chatlog.add_system(OF.lang.fill("ban ran out for @",
                    entry.np.name),
                    OF.util.asks(OF.actionlog, "auto")
                        and OF.actionlog.BY_THE_ROOM or nil)
            end
        end
    end
end

local registered = false

local function register_requests()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true

    OF.net.register_action("warn", "mute", function(fromLocal, who, reasonKey)
        if not OF.util.is_host() then return false, "Only the host." end
        local target = OF.util.local_from_global(tonumber(who))

        local may, whyNot = OF.util.may_act_on(fromLocal, target)
        if not may then return false, whyNot end

        return jail.warn(target, tostring(reasonKey or "none"))
    end)

    OF.net.register_action("forgive", "mute", function(fromLocal, who)
        if not OF.util.is_host() then return false, "Only the host." end
        local target = OF.util.local_from_global(tonumber(who))
        local may, whyNot = OF.util.may_act_on(fromLocal, target)
        if not may then return false, whyNot end
        return jail.forgive(target)
    end)

    OF.net.register_action("banask", "ban", function(fromLocal, who, minutes, reasonKey)
        if not OF.util.is_host() then return false, "Only the host." end
        local target = OF.util.local_from_global(tonumber(who))
        local may, whyNot = OF.util.may_act_on(fromLocal, target)
        if not may then return false, whyNot end
        return jail.ban(target, tonumber(minutes), tostring(reasonKey or "none"))
    end)
    OF.net.register_action("banabsentask", "ban", function(fromLocal, minutes, _, text)
        if not OF.util.is_host() then return false, "Only the host." end
        local reasonKey, playerId, name = string.match(tostring(text or ""),
            "^([^|]*)|([^|]*)|(.*)$")
        if playerId == nil or playerId == "" then return false, "That player has no stable id." end

        if jail.protects_id(playerId) then return false, jail.HOST_IS_SAFE end
        local theirs = OF.util.asks(OF.ranks, "stored") and OF.ranks.stored(playerId) or nil
        if theirs ~= nil and theirs >= OF.perms.tier(fromLocal) then
            return false, "They are your rank or above it."
        end
        return jail.ban_absent(playerId, name, tonumber(minutes), reasonKey)
    end)
    OF.net.register_action("unbanask", "ban", function(_, _, _, playerId)
        if not OF.util.is_host() then return false, "Only the host." end
        if playerId == nil or playerId == "" then return false, "Nobody by that id." end
        return jail.unban(playerId)
    end)
end

local function update()
    frames = frames + 1
    register_requests()
    serve_time()
    serve_bans()

    if jail.endsIn ~= nil and jail.endsIn > 0 then
        jail.endsIn = jail.endsIn - 1
    end

    if jail.active and not OF.util.is_host() and not sentence_on_my_row() then
        orphaned = orphaned + 1
        if orphaned >= ORPHAN_FRAMES then
            orphaned = 0
            jail.release_local()
            return
        end
    else
        orphaned = 0
    end

    if not jail.active then return end
    if not jail.moon then return end

    local m = gMarioStates[0]
    if m == nil then return end
    if jail.moonY == nil then jail.moonY = m.pos.y end

    m.pos.y = jail.moonY
    m.vel.y = 0
    m.forwardVel = 0
    vec3f_copy(m.marioObj.header.gfx.pos, m.pos)

    OF.util.limp(m)
end

local function on_before_mario_update(m)
    if not jail.active or not jail.frozen then return end
    if m.playerIndex ~= 0 then return end

    OF.input.freeze(m)
end

local function render()
    if not jail.active then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local cover = 190
    if jail.blind then cover = 245 end
    OF.util.rect(0, 0, screenWidth, screenHeight, 0, 0, 0, cover)

    local title = "Locked out of " .. OF.LOBBY_NAME .. "'s lobby"
    local titleScale = 1.3
    local titleWidth, titleHeight = OF.util.text_size(title, titleScale)
    local y = screenHeight * 0.36
    OF.util.text(title, (screenWidth - titleWidth) * 0.5, y, titleScale, 255, 90, 90, 255)

    y = y + titleHeight + 14
    if jail.reason ~= "" then
        local reasonScale = 1.0
        local reasonWidth, reasonHeight = OF.util.text_size(jail.reason, reasonScale)
        OF.util.text(jail.reason, (screenWidth - reasonWidth) * 0.5, y, reasonScale,
            255, 255, 255, 255)
        y = y + reasonHeight + 14
    end

    if jail.endsIn ~= nil then
        local counting = "Ends by itself in " .. jail.left_text(jail.endsIn / 30)
        local cr, cg, cb = 255, 176, 96
        if jail.endsIn <= 0 then

            counting = "Your time is up - any moment now"
            cr, cg, cb = 160, 255, 160
        elseif jail.endsIn <= 10 * 30 then
            counting = "Almost over - " .. jail.left_text(jail.endsIn / 30)
            cr, cg, cb = 160, 255, 160
        end
        local countScale = 1.0
        local countWidth, countHeight = OF.util.text_size(counting, countScale)
        OF.util.text(counting, (screenWidth - countWidth) * 0.5, y, countScale,
            cr, cg, cb, 255)
        y = y + countHeight + 14
    end

    local hint = "Only the host can lift this. Chat still works unless you are muted."
    local hintScale = 0.8
    local _, hintHeight = OF.util.text_size(hint, hintScale)
    OF.util.text(hint, (screenWidth - OF.util.width(hint, hintScale)) * 0.5, y,
        hintScale, 190, 190, 190, 255)

    local appeal = "Wrong person? Type /appeal in chat and the host is told."
    OF.util.text(appeal,

        (screenWidth - OF.util.width(appeal, hintScale)) * 0.5,
        y + hintHeight + 8, hintScale, 255, 176, 96, 255)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
hook_event(HOOK_UPDATE, update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update, OF.LOCAL_MARIO)
hook_event(HOOK_ON_HUD_RENDER, render)

function jail.chat_jail(msg)
    msg = msg or ""
    if msg == "" then
        OF.util.report(jail.say_who_is_serving())
        return true
    end

    local name, key, mins = string.match(msg, "^(%S+)%s*(%S*)%s*(%S*)$")
    if name == nil then
        OF.util.chat(OF.lang.t(
            "Usage: /jail [name] [timeout|moon|silence|void] [minutes]"))
        return true
    end

    if mins == "" and tonumber(key) ~= nil then
        mins = key
        key = ""
    end
    if key == "" then key = "timeout" end

    local target = OF.util.named_player(name)
    if target == nil then return true end

    local was = OF.notify.deedBy
    OF.notify.deedBy = 0
    local ok, reason = jail.punish(target, key, nil, mins ~= "" and mins or nil)
    OF.notify.deedBy = was
    if not ok then OF.util.chat(reason, "warn") end
    return true
end

hook_chat_command("jail",
    "- jail a player, for a while or until you say",
    function(msg) return jail.chat_jail(msg) end)

hook_chat_command("unjail", "- release a player and send them to Castle Grounds",
    function(msg)
        local target = OF.util.named_player(msg)
        if target == nil then return true end

        local was = OF.notify.deedBy
        OF.notify.deedBy = 0
        local ok, reason = jail.release(target, true)
        OF.notify.deedBy = was
        if not ok then OF.util.chat(reason, "warn") end
        return true
    end)

hook_chat_command("unban", "- lift a lobby ban by name", function(msg)
    if not OF.util.allowed("ban") then return true end
    if not OF.util.is_host() then
        OF.util.chat(OF.lang.t("The ban list is the host's - ask them."))
        return true
    end

    local wanted = string.lower(OF.util.plain(msg or ""))
    if wanted == "" then
        OF.util.chat(OF.lang.t("Say who to unban. The Players page has the list."))
        return true
    end

    local list = jail.ban_list()
    local found = nil
    for _, entry in ipairs(list) do
        if string.lower(OF.util.plain(entry.name)) == wanted then found = entry end
    end
    if found == nil then
        for _, entry in ipairs(list) do
            if found == nil and string.sub(string.lower(OF.util.plain(entry.name)),
                1, #wanted) == wanted then
                found = entry
            end
        end
    end

    if found == nil then
        OF.util.chat(OF.lang.fill("Nobody banned is called '@'.",
            tostring(msg)), "warn")
        return true
    end

    OF.util.report(jail.unban(found.id))
    return true
end)

function jail.chat_appeal(msg)
    if OF.util.report(jail.appeal(msg)) then
        OF.util.chat(OF.lang.t(
            "The host has been told. They will look."))
    end
    return true
end

hook_chat_command("appeal",
    "- tell the host they have the wrong person",

    function(msg) return jail.chat_appeal(msg) end)
hook_chat_command("notme",
    "- tell the host they have the wrong person",

    function(msg) return jail.chat_appeal(msg) end)
