OF = OF or {}
OF.mute = OF.mute or {}

local mute = OF.mute

mute.PACKET_ASK = "muteask"
local MUTE_PREFIX = "mute_"
local noticeCooldown = 0

function mute.quiet_steps()
    return {
        OF.TIER.NORMAL,
        OF.TIER.CREW,
        OF.TIER.MOD,
    }
end

function mute.quiet_tier()
    return OF.perms.required("chat")
end

function mute.quiet_on()
    return mute.quiet_tier() > OF.TIER.NORMAL
end

function mute.may_talk(localIndex)
    if localIndex == nil then return true end
    return OF.perms.tier(localIndex) >= OF.perms.required("chat")
end

function mute.quiet_name(tier)
    if tier == nil then tier = mute.quiet_tier() end
    if tier <= OF.TIER.NORMAL then return "off" end
    return OF.perms.tier_name(tier)
end

function mute.quiet_step(tier)
    tier = tier or mute.quiet_tier()
    local steps = mute.quiet_steps()
    for i, value in ipairs(steps) do
        if value == tier then return steps[(i % #steps) + 1] end
    end

    return OF.TIER.NORMAL
end

local function apply_quiet(tier, askerLocal)
    local was = mute.quiet_tier()

    local ok, why = OF.perms.set_required("chat", tier)
    if not ok then return false, why or "The lobby's ladder would not take it." end
    if tier == was then return true end

    local asked = OF.util.asked_in_chat()
    if tier <= OF.TIER.NORMAL then
        if asked then
            OF.util.chat(OF.lang.t("Chat is open to everybody again."))
        end
        OF.notify.send_all("Chat is open again", "good", 5)

        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal, OF.lang.t("quiet mode off"))
        end
        OF.chatlog.add_system("quiet mode off", OF.util.presser(askerLocal))
    else

        if asked then

            OF.util.chat(OF.lang.fill(
                "Quiet mode: only @ and above can talk.",
                OF.perms.tier_name(tier)), "warn")
        end
        OF.notify.send_all("Quiet mode - only @ and above can talk", "warn", 6,
            OF.perms.tier_name(tier))

        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal,
                OF.lang.fill("quiet mode: @", OF.perms.tier_name(tier)))
        end
        OF.chatlog.add_system("quiet mode on (" .. OF.perms.tier_name(tier) .. ")",
            OF.util.presser(askerLocal))
    end
    return true
end

function mute.set_quiet(tier, askerLocal)
    tier = tonumber(tier)
    if tier == nil then return false, "That is not a rank." end

    local known = false
    for _, value in ipairs(mute.quiet_steps()) do
        if value == tier then known = true end
    end
    if not known then
        return false, "Quiet mode goes off, crew or mod."
    end

    if not OF.perms.can("mute") then return false, "Your rank cannot do that.", "mute" end
    if not OF.util.is_host() then
        return OF.net.host_does("quiet", tier)
    end
    return apply_quiet(tier, askerLocal)
end

local registered = false

function mute.ready()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action("quiet", "mute", function(fromLocal, tier)

        if not OF.util.is_host() then return false, "Only the host." end

        local wanted = tonumber(tier)
        for _, value in ipairs(mute.quiet_steps()) do

            if value == wanted then return apply_quiet(wanted, fromLocal) end
        end
        return false, "Quiet mode goes off, crew or mod."
    end)
end

function mute.is_muted(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return false end
    return s.ofMuted == true
end

function mute.stored_mute(playerId)
    if playerId == nil then return false end
    return mod_storage_exists(OF.util.storage_key(MUTE_PREFIX, playerId))
end

local roundMuted = {}

function mute.round_holds(playerId)
    if playerId == nil then return false end
    return roundMuted[playerId] == true
end

function mute.round_count()
    local held = 0
    for _ in pairs(roundMuted) do held = held + 1 end
    return held
end

function mute.round_silence(localIndex)
    if not OF.util.is_host() then return false end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false end
    if OF.util.is_host_player(localIndex) then return false end

    local id = OF.util.player_id(localIndex)
    if id == nil then return false end
    if roundMuted[id] then return false end

    if mute.stored_mute(id) then return false end

    roundMuted[id] = true
    gPlayerSyncTable[localIndex].ofMuted = true
    return true
end

function mute.round_release()

    if not OF.util.is_host() then
        roundMuted = {}
        return 0
    end

    local given = 0
    for id in pairs(roundMuted) do
        local li = mute.here(id)
        roundMuted[id] = nil
        given = given + 1
        if li ~= nil and not mute.stored_mute(id) then
            gPlayerSyncTable[li].ofMuted = false
        end
    end
    roundMuted = {}
    return given
end

local MUTE_MARK = "2|"
mute.SOURCES = {
    { key = "hand",     text = "a moderator" },
    { key = "warnings", text = "the warning ladder" },
    { key = "sentence", text = "part of a sentence" },
}

function mute.source_text(key)
    for _, entry in ipairs(mute.SOURCES) do
        if entry.key == key then return entry.text end
    end
    return mute.SOURCES[1].text
end

function mute.source_key(key)
    for _, entry in ipairs(mute.SOURCES) do
        if entry.key == key then return key end
    end
    return "hand"
end

function mute.reason_text(key)
    if OF.util.asks(OF.jail, "reason_text") then return OF.jail.reason_text(key) end
    return "No reason given"
end

function mute.reason_key(key)
    if OF.util.asks(OF.jail, "reason_key") then return OF.jail.reason_key(key) end
    return "none"
end

local function now_seconds()
    if OF.util.asks(OF.jail, "now") then return OF.jail.now() end
    return 0
end

local function open_case(kind, name, detail)
    if not OF.util.asks(OF.trouble, "open_case") then return nil end
    return OF.trouble.open_case(kind, name, detail)
end

local function case_suffix(code)
    if not OF.util.asks(OF.trouble, "case_suffix") then return "" end
    return OF.trouble.case_suffix(code)
end

local function read_mute(value)
    value = tostring(value or "")

    local at, ends, why, how, name = string.match(value,
        "^2|(%-?%d+)|(%-?%d+)|([%w_]*)|([%w_]*)|(.*)$")
    if at ~= nil then
        return {
            at = tonumber(at) or 0,
            ends = tonumber(ends) or 0,
            reason = why ~= "" and why or "none",
            source = how ~= "" and how or "hand",
            name = name,
        }
    end

    at, why, how, name = string.match(value,
        "^1|(%-?%d+)|([%w_]*)|([%w_]*)|(.*)$")
    if at ~= nil then
        return {
            at = tonumber(at) or 0,
            ends = 0,
            reason = why ~= "" and why or "none",
            source = how ~= "" and how or "hand",
            name = name,
        }
    end

    return { at = 0, ends = 0, reason = "none", source = "hand", name = value }
end

function mute.tidy_entries()
    local list = {}
    if not OF.util.is_host() then return list end
    for key, value in pairs(mod_storage_load_all() or {}) do
        if string.sub(key, 1, #MUTE_PREFIX) == MUTE_PREFIX then
            local id = OF.util.storage_unescape(string.sub(key, #MUTE_PREFIX + 1))
            list[#list + 1] = { keys = { key }, at = read_mute(value).at or 0,
                                who = { id } }
        end
    end
    return list
end

local function write_mute(entry)
    return MUTE_MARK .. string.format("%.0f", entry.at or 0)
        .. "|" .. string.format("%.0f", entry.ends or 0)
        .. "|" .. mute.reason_key(entry.reason)
        .. "|" .. mute.source_key(entry.source)
        .. "|" .. tostring(entry.name or "?")
end

function mute.record(playerId)
    if playerId == nil or not OF.util.is_host() then return nil end
    local key = OF.util.storage_key(MUTE_PREFIX, playerId)
    if not mod_storage_exists(key) then return nil end
    local entry = read_mute(mod_storage_load(key, ""))
    entry.id = playerId
    return entry
end

function mute.since_text(at)
    at = tonumber(at) or 0
    if at <= 0 then return nil end
    local now = now_seconds()
    if now <= 0 then return nil end
    local since = now - at
    if since < 0 then return nil end
    if since < 3600 then
        if OF.util.asks(OF.jail, "left_text") then return OF.jail.left_text(since) end
        return string.format("%.0fs", since)
    end
    if since < 86400 then return string.format("%.0fh", math.floor(since / 3600)) end
    return string.format("%.0fd", math.floor(since / 86400))
end

local LENGTH_KEY = "mutelen"
mute.LENGTH_MAX = 60
mute.LENGTH_STEP = 5

mute.LENGTH_DEFAULT = 0

local lengthMinutes = mod_storage_load_integer(LENGTH_KEY, mute.LENGTH_DEFAULT)

function mute.length_minutes()
    return lengthMinutes
end

function mute.set_length_minutes(minutes)
    if not OF.util.is_host() then return false, "Only the host." end
    minutes = math.floor(tonumber(minutes) or 0)
    if minutes < 0 then minutes = 0 end
    if minutes > mute.LENGTH_MAX then minutes = mute.LENGTH_MAX end
    lengthMinutes = minutes
    OF.util.store_integer(LENGTH_KEY, minutes)
    return true
end

function mute.reset_options()
    if not OF.util.is_host() or lengthMinutes == mute.LENGTH_DEFAULT then return false end
    return mute.set_length_minutes(mute.LENGTH_DEFAULT) == true
end

function mute.length_text()
    if lengthMinutes <= 0 then return OF.lang.t("until it is lifted") end
    return OF.lang.fill("@ minute(s)", lengthMinutes)
end

function mute.length_note()
    if lengthMinutes <= 0 then
        return OF.lang.fill(
            "new mutes last until somebody lifts them - each stop on the dial is @ minutes",
            mute.LENGTH_STEP)
    end
    return OF.lang.fill("new mutes lift themselves after @ minutes - each stop on the dial is @ minutes",
        lengthMinutes, mute.LENGTH_STEP)
end

function mute.length_row(panel)
    local steps = mute.LENGTH_MAX / mute.LENGTH_STEP
    local built = panel.host_row("mute",
        OF.lang.t("How long a new mute lasts"), 255, 220, 120,
        function()
            local next_ = mute.length_minutes() + mute.LENGTH_STEP
            if next_ > mute.LENGTH_MAX then next_ = 0 end
            OF.util.report(mute.set_length_minutes(next_))
        end)
    built = panel.with_right(built, mute.length_text())
    built = panel.with_slider(built, lengthMinutes / mute.LENGTH_STEP, steps,
        function(wanted)
            OF.util.report(mute.set_length_minutes(wanted * mute.LENGTH_STEP))
        end)
    return panel.with_help(built, mute.length_note())
end

local function ends_at(minutes)
    minutes = tonumber(minutes) or 0
    if minutes <= 0 then return 0 end
    local now = now_seconds()
    if now <= 0 then return 0 end
    return now + math.floor(minutes * 60)
end

function mute.time_left(entry)
    if not OF.util.is_host() then return nil end
    if entry == nil then return nil end
    local ends = tonumber(entry.ends) or 0
    if ends <= 0 then return nil end
    local now = now_seconds()
    if now <= 0 then return nil end
    return math.max(0, ends - now)
end

function mute.left_text(entry)
    local left = mute.time_left(entry)
    if left ~= nil and OF.util.asks(OF.jail, "left_text") then
        return OF.lang.fill("@ left", OF.jail.left_text(left))
    end

    local here = entry ~= nil and entry.here or nil
    if here ~= nil and OF.util.asks(OF.jail, "time_left") then
        local sentence = OF.jail.sentence_of(here)
        local serving = OF.jail.time_left(here)
        if sentence ~= nil and sentence.muted and serving ~= nil then
            return OF.lang.fill("@ left", OF.jail.left_text(serving))
        end
    end

    return OF.lang.t("until it is lifted")
end

function mute.here(playerId)
    if playerId == nil then return nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        if OF.util.player_id(entry.localIndex) == playerId then
            return entry.localIndex
        end
    end
    return nil
end

function mute.list()
    local list = {}

    if not OF.util.is_host() then
        for _, entry in ipairs(OF.util.connected_players()) do
            if mute.is_muted(entry.localIndex) then

                table.insert(list, {
                    id = OF.util.player_id(entry.localIndex) or "?",
                    name = entry.np.name,
                    here = entry.localIndex,
                })
            end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return list
    end

    local all = mod_storage_load_all()
    if all == nil then return list end
    for key, value in pairs(all) do
        if string.sub(key, 1, #MUTE_PREFIX) == MUTE_PREFIX then
            local entry = read_mute(value)
            entry.id = OF.util.storage_unescape(string.sub(key, #MUTE_PREFIX + 1))

            entry.here = mute.here(entry.id)
            table.insert(list, entry)
        end
    end

    table.sort(list, function(a, b)
        if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
        return a.name < b.name
    end)
    return list
end

local countMemo = {}

function mute.count()
    if not OF.util.is_host() then return #mute.list() end
    return OF.util.stored_count(countMemo, mute.list)
end

function mute.lift(playerId, localIndex)
    if not OF.perms.can("mute") then return false, "Your rank cannot do that.", "mute" end

    local li = localIndex
    if li == nil then li = mute.here(playerId) end
    if li ~= nil then
        local np = gNetworkPlayers[li]
        if np ~= nil and np.connected then return mute.set(li, false) end
    end
    if playerId == nil then return false, "Nobody to unmute." end

    if not OF.util.is_host() then
        return false, "That one is the host's to lift - they are not in the lobby."
    end

    local entry = mute.record(playerId)
    if entry == nil then return false, "That mute has already gone." end
    mod_storage_remove(OF.util.storage_key(MUTE_PREFIX, playerId))

    OF.notify.show("Unmuted @", "info", 4, OF.util.plain(entry.name))
    OF.chatlog.add_system("unmuted " .. entry.name .. " (not in the lobby)")
    return true
end

function mute.lift_all()
    if not OF.perms.can("mute") then return false, "Your rank cannot do that.", "mute" end
    local list = mute.list()
    if #list == 0 then return false, "Nobody is muted." end

    local lifted = 0
    for _, entry in ipairs(list) do
        if mute.lift(entry.id, entry.here) then lifted = lifted + 1 end
    end
    if lifted == 0 then return false, "Nothing could be lifted from here." end
    OF.chatlog.add_system("unmuted everybody (" .. string.format("%.0f", lifted) .. ")")
    return true
end

local function expire_one(entry)
    if entry == nil or entry.id == nil then return false end
    mod_storage_remove(OF.util.storage_key(MUTE_PREFIX, entry.id))

    local li = entry.here
    if li ~= nil then
        local np = gNetworkPlayers[li]
        if np ~= nil and np.connected then
            gPlayerSyncTable[li].ofMuted = false
        end
    end

    local name = OF.util.plain(entry.name or "?")

    OF.notify.show("@ can talk again - the mute ran out on its own.",
        "quiet", 5, name)
    if li ~= nil and li ~= 0 then
        local who = gNetworkPlayers[li]
        if who ~= nil and who.connected then
            OF.notify.send_to(who.globalIndex,
                "Your mute ran out - you can talk again", "good", 5)
        end
    end
    OF.chatlog.add_system(OF.lang.fill("the mute on @ ran out", name),
        OF.util.asks(OF.actionlog, "auto") and OF.actionlog.BY_THE_ROOM or nil)
    return true
end

function mute.serve_time()
    if not OF.util.is_host() then return 0 end
    local now = now_seconds()
    if now <= 0 then return 0 end

    local lifted = 0
    for _, entry in ipairs(mute.list()) do
        if (entry.ends or 0) > 0 and now >= entry.ends then
            if expire_one(entry) then lifted = lifted + 1 end
        end
    end
    return lifted
end

function mute.set(localIndex, value, quiet, why, how, minutes, case)
    if not OF.perms.can("mute") then return false end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false end
    if OF.util.is_host_player(localIndex) then return false end

    if not OF.util.is_host() then
        OF.util.send_to_host({
            ofp = mute.PACKET_ASK,
            who = network_global_index_from_local(localIndex),
            on = value and 1 or 0,
        })
        return true
    end

    local actor = OF.notify.deed_take()
    local wasMuted = mute.is_muted(localIndex)

    local id = OF.util.player_id(localIndex)
    if id ~= nil then
        if value then

            local was = mute.record(id)

            local ends
            if minutes ~= nil then
                ends = ends_at(minutes)
            elseif was ~= nil and (was.ends or 0) > 0 then
                ends = was.ends
            else
                ends = ends_at(lengthMinutes)
            end
            if not OF.util.store(OF.util.storage_key(MUTE_PREFIX, id),
                    OF.util.storage_value(write_mute({
                        at = (was ~= nil and was.at > 0) and was.at or now_seconds(),
                        ends = ends,
                        reason = why or (was ~= nil and was.reason) or "none",
                        source = how or (was ~= nil and was.source) or "hand",
                        name = np ~= nil and np.name or "?",
                    }))) then
                return false, "The mute could not be saved, so nobody was muted."
            end

            if case == nil and was == nil then
                case = open_case("muted", np.name, mute.reason_text(why))
            end
        else
            mod_storage_remove(OF.util.storage_key(MUTE_PREFIX, id))
        end
    end
    gPlayerSyncTable[localIndex].ofMuted = value

    local mark = case_suffix(case)
    local asked = OF.util.asked_in_chat()
    if value then
        if asked then
            OF.util.chat("Muted " .. OF.util.chat_name(np.name) .. mark, "warn")
        else

            OF.notify.show("Muted @@", "crit", nil, OF.util.plain(np.name), mark)
        end
        OF.chatlog.add_system("muted " .. np.name .. mark)
    else
        if asked then
            OF.util.chat("Unmuted " .. OF.util.chat_name(np.name))
        else
            OF.notify.show("Unmuted @", "good", nil, OF.util.plain(np.name))
        end
        OF.chatlog.add_system("unmuted " .. np.name)
    end
    if wasMuted ~= (value == true) then
        OF.notify.deed_said(actor, value and "mute" or "unmute", localIndex)
    else
        OF.notify.deedBy = actor
    end
    return true
end

function mute.toggle(localIndex)
    return mute.set(localIndex, not mute.is_muted(localIndex))
end

function mute.forget_all_stored()
    local cleared = 0
    for _, entry in ipairs(mute.list()) do
        if entry.id ~= nil then
            mod_storage_remove(OF.util.storage_key(MUTE_PREFIX, entry.id))
            cleared = cleared + 1
        end
    end
    return cleared
end

function mute.check_on_join(localIndex)
    if not OF.util.is_host() then return end
    if OF.util.is_host_player(localIndex) then return end

    local id = OF.util.player_id(localIndex)
    local muted = mute.stored_mute(id) or mute.round_holds(id)
    gPlayerSyncTable[localIndex].ofMuted = muted
end

local function on_chat_message(m, message)
    if m == nil then return end

    if not mute.may_talk(m.playerIndex) then
        if m.playerIndex == 0 and noticeCooldown <= 0 then
            noticeCooldown = 90
            OF.notify.show("The lobby is quiet - @ and above can talk", "warn", 5,
                OF.perms.tier_name(OF.perms.required("chat")))
        end

        OF.chatlog.add_system("[quiet] " .. gNetworkPlayers[m.playerIndex].name
            .. ": " .. message)
        return false
    end

    if not mute.is_muted(m.playerIndex) then return end

    if m.playerIndex == 0 and noticeCooldown <= 0 then
        noticeCooldown = 90
        OF.notify.show("You are muted in this lobby", "bad", 4)
    end

    OF.chatlog.add_system("[muted] " .. gNetworkPlayers[m.playerIndex].name .. ": " .. message)
    return false
end

local function host_record(localIndex)
    local id = OF.util.player_id(localIndex)
    if id == nil then return nil end

    if roundMuted[id] then return true end
    return mute.stored_mute(id)
end

for i = 1, MAX_PLAYERS - 1 do
    hook_on_sync_table_change(gPlayerSyncTable[i], "ofMuted", i,
        function(tag, oldVal, newVal)
            if newVal == oldVal then return end
            if not OF.util.is_host() then return end

            local truth = host_record(i)
            if truth == nil then return end
            if newVal == truth then return end

            gPlayerSyncTable[i].ofMuted = truth
        end)
end

hook_on_sync_table_change(gPlayerSyncTable[0], "ofMuted", 0,
    function(tag, oldVal, newVal)
        if newVal == oldVal then return end

        if OF.util.asks(OF.guard, "repair_my_row")
            and OF.guard.repair_my_row("ofMuted") then
            return
        end

        if newVal == true then
            OF.notify.show("You have been muted by a moderator", "crit", 6)
        elseif oldVal == true then
            OF.notify.show("You can talk again", "good", 5)
        end
    end)

local function on_packet_receive(data)
    if data == nil or data.ofp ~= mute.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    if OF.perms.tier(asker) < OF.perms.required("mute", asker) then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    local target = OF.util.local_from_global(data.who)

    local may, whyNot = OF.util.may_act_on(asker, target)
    if not may then
        OF.util.tell_asker(askerGlobal, whyNot)
        return
    end

    local ok, why = OF.notify.acting(asker, mute.set, target, data.on == 1)
    if not ok then
        OF.notify.send_to(askerGlobal, "@", "bad", 5, tostring(why or "Refused."))
        return
    end

    local np = gNetworkPlayers[asker]
    OF.chatlog.add_system(OF.lang.fill("muted/unmuted @",
        gNetworkPlayers[target] ~= nil and gNetworkPlayers[target].name or "?"),
        np ~= nil and np.name or nil)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
hook_event(HOOK_ON_CHAT_MESSAGE, on_chat_message)
hook_event(HOOK_UPDATE, function()
    if noticeCooldown > 0 then noticeCooldown = noticeCooldown - 1 end
end)

local SWEEP_FRAMES = 150
local sweepFrames = 0
hook_event(HOOK_UPDATE, function()
    sweepFrames = sweepFrames + 1
    if sweepFrames % SWEEP_FRAMES ~= 0 then return end
    mute.serve_time()
end)

hook_event(HOOK_UPDATE, function() mute.ready() end)

function mute.chat_mute(msg)
        if not OF.util.allowed("mute") then return true end
        msg = msg or ""
        local name, tail = string.match(msg, "^(.-)%s+(%d+)$")
        local minutes = nil
        if name ~= nil and name ~= "" then
            minutes = tonumber(tail)
            msg = name
        end

        local target = OF.util.named_player(msg)
        if target == nil then return true end

        if minutes ~= nil and mute.is_muted(target) then
            OF.util.chat(OF.lang.t(
                "They are already muted. Type it without a number to lift it."), "warn")
            return true
        end

        if minutes ~= nil then
            local was = OF.notify.deedBy
            OF.notify.deedBy = 0
            OF.util.report(mute.set(target, true, nil, nil, nil, minutes))
            OF.notify.deedBy = was
            return true
        end

        local was = OF.notify.deedBy
        OF.notify.deedBy = 0
        mute.toggle(target)
        OF.notify.deedBy = was
        return true
end

hook_chat_command("mute", "- toggle chat mute for a player, optionally for N minutes",
    function(msg) return mute.chat_mute(msg) end)

hook_chat_command("unmute", "- let a muted player talk again", function(msg)
    if not OF.util.allowed("mute") then return true end
    local target = OF.util.named_player(msg)
    if target == nil then return true end
    if not mute.is_muted(target) then
        OF.util.chat(OF.lang.t("They are not muted."), "warn")
        return true
    end

    local was = OF.notify.deedBy
    OF.notify.deedBy = 0
    OF.util.report(mute.set(target, false))
    OF.notify.deedBy = was
    return true
end)

hook_chat_command("quiet", "- only vouched-for players may talk", function(msg)
    if not OF.util.allowed("mute") then return true end
    msg = string.lower(msg or "")

    if msg == "" then

        local wanted = OF.TIER.CREW
        if mute.quiet_on() then wanted = OF.TIER.NORMAL end

        OF.util.report(mute.set_quiet(wanted, 0))
        return true
    end

    if msg == "off" then
        OF.util.report(mute.set_quiet(OF.TIER.NORMAL, 0))
        return true
    end

    for _, tier in ipairs(mute.quiet_steps()) do
        if OF.perms.tier_info(tier).key == msg then
            OF.util.report(mute.set_quiet(tier, 0))
            return true
        end
    end

    OF.util.chat("Usage: /quiet [off|crew|mod]")
    OF.util.chat(OF.lang.fill("Right now: @",
        mute.quiet_name()))
    return true
end)
