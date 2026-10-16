OF = OF or {}
OF.filter = OF.filter or {}

local filter = OF.filter

filter.RULE_NAME = "Hold back filtered words"
filter.RULE_HELP = "a word on the list is held back from the lobby's chat"
local STORE_KEY = "chatfilter"
local MAX_WORDS = 40

local NEW_FOR_SECONDS = 60
local BURST = 5
local WINDOW_SECONDS = 10

local noticeCooldown = 0

local MODE_MARK = "~"
local function entries()
    local packed = gGlobalSyncTable.ofFilter
    if packed == nil or packed == "" then return {} end
    local list = {}
    for part in string.gmatch(packed, "[^,]+") do table.insert(list, part) end
    return list
end

function filter.words()
    local list = {}
    for _, part in ipairs(entries()) do
        if string.sub(part, 1, 1) ~= MODE_MARK then table.insert(list, part) end
    end
    return list
end

function filter.count()
    return #filter.words()
end

function filter.mode()
    local on = OF.trouble ~= nil and OF.trouble.ON or "on"
    for _, part in ipairs(entries()) do
        if string.sub(part, 1, 1) == MODE_MARK then
            local mode = string.sub(part, 2)
            if OF.util.asks(OF.trouble, "is_mode") and OF.trouble.is_mode(mode) then
                return mode
            end
        end
    end
    return on
end

local function packed_text(list, mode)
    local parts = {}
    if mode ~= nil and OF.util.asks(OF.trouble, "is_mode")
        and OF.trouble.is_mode(mode) and mode ~= OF.trouble.ON then
        table.insert(parts, MODE_MARK .. mode)
    end
    for _, word in ipairs(list) do table.insert(parts, word) end
    return table.concat(parts, ",")
end

local function mark_room()
    if not OF.util.asks(OF.trouble, "is_mode") then return 0 end
    if type(OF.trouble.MODES) ~= "table" then return 0 end
    local widest = 0
    for _, mode in ipairs(OF.trouble.MODES) do
        if #mode > widest then widest = #mode end
    end
    if widest == 0 then return 0 end

    return #MODE_MARK + widest + 1
end

local function publish(list, mode)
    local packed = packed_text(list, mode)
    OF.util.publish("ofFilter", packed)
    OF.util.store(STORE_KEY, packed)
end

local function normalise(word)
    return string.gsub(string.lower(word or ""), "[^%w]", "")
end

function filter.has(word)
    local wanted = normalise(word)
    for _, entry in ipairs(filter.words()) do
        if entry == wanted then return true end
    end
    return false
end

function filter.add(word)
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    local clean = normalise(word)
    if clean == "" then return false, "Give it a word." end
    if filter.has(clean) then return false, "That one is already on the list." end

    local list = filter.words()
    if #list >= MAX_WORDS then
        return false, "The list is full at " .. MAX_WORDS .. " words."
    end

    table.insert(list, clean)
    if #packed_text(list, nil) + mark_room() > OF.util.publish_limit() then
        return false, "The list is as long as it can be sent."
    end

    publish(list, filter.mode())
    return true
end

function filter.remove(word)
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    local clean = normalise(word)
    local list = filter.words()
    for index, entry in ipairs(list) do
        if entry == clean then
            table.remove(list, index)
            publish(list, filter.mode())
            return true
        end
    end
    return false, "That word is not on the list."
end

function filter.clear()
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    publish({}, filter.mode())
    return true
end

local function say_what_it_cannot_see()
    OF.notify.show("Chat the game itself ate is not counted here", "warn", 8)
    if OF.util.asks(OF.actionlog, "auto") then
        OF.actionlog.auto(OF.lang.t(
            "the chat filter is only watching - the game's own gag is not counted"))
    end
end

function filter.set_mode(mode)
    if not OF.util.asks(OF.trouble, "is_mode") or not OF.trouble.is_mode(mode) then
        return false, "That is not one of the three settings."
    end
    if not OF.perms.can("settings") then
        return false, "Your rank cannot do that.", "settings"
    end
    if not OF.util.is_host() then
        return false, "Only the host can change what the filter does."
    end

    local was = filter.mode()
    publish(filter.words(), mode)
    if mode ~= was and mode == OF.trouble.OBSERVE then say_what_it_cannot_see() end
    return true
end

function filter.blocks(message)
    if message == nil or message == "" then return nil end
    local list = filter.words()
    if #list == 0 then return nil end

    for word in string.gmatch(string.lower(message), "[%w]+") do
        for _, entry in ipairs(list) do
            if word == entry then return entry end
        end
    end
    return nil
end

local firstSeen = {}
local recent = {}

local function now_frames()
    return (get_global_timer ~= nil) and get_global_timer() or 0
end

function filter.is_new(localIndex)
    local seen = firstSeen[localIndex]
    if seen == nil then return true end
    return (now_frames() - seen) < NEW_FOR_SECONDS * 30
end

function filter.too_fast(localIndex)
    if not filter.is_new(localIndex) then return false end

    local stamps = recent[localIndex] or {}
    local cutoff = now_frames() - WINDOW_SECONDS * 30

    local kept = {}
    for _, stamp in ipairs(stamps) do
        if stamp > cutoff then table.insert(kept, stamp) end
    end

    table.insert(kept, now_frames())
    recent[localIndex] = kept

    return #kept > BURST
end

local STRIKE_FORGET_SECONDS = 120
local TELL_EVERY = 3

local strikes = {}
local strikeAt = {}

local function count_strike(localIndex)
    local now = now_frames()
    local last = strikeAt[localIndex]
    if last == nil or (now - last) > STRIKE_FORGET_SECONDS * 30 then
        strikes[localIndex] = 0
    end
    strikeAt[localIndex] = now
    strikes[localIndex] = (strikes[localIndex] or 0) + 1
    return strikes[localIndex]
end

local function tell_on_repeat(localIndex, count)
    if not OF.util.is_host() then return false end
    if count < TELL_EVERY or (count % TELL_EVERY) ~= 0 then return false end

    local np = gNetworkPlayers[localIndex]
    OF.notify.show("@ has hit the filter @ times", "warn", 8,
        OF.util.plain(np ~= nil and np.name or "somebody"), count)
    return true
end

hook_event(HOOK_ON_PLAYER_CONNECTED, function(m)
    if m == nil then return end
    firstSeen[m.playerIndex] = now_frames()
    recent[m.playerIndex] = nil
end)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    firstSeen[m.playerIndex] = nil
    recent[m.playerIndex] = nil

    strikes[m.playerIndex] = nil
    strikeAt[m.playerIndex] = nil
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    for _, entry in ipairs(OF.util.connected_players()) do
        firstSeen[entry.localIndex] = -NEW_FOR_SECONDS * 30
    end

    if OF.util.asks(OF.trouble, "automatic") then
        OF.trouble.automatic({
            key = "filter",
            name = filter.RULE_NAME,

            help = filter.RULE_HELP,
            default = OF.trouble.ON,
            get = filter.mode,
            set = filter.set_mode,
        })
    end
end)

local function on_chat_message(m, message)
    if m == nil then return end
    local localIndex = m.playerIndex

    if localIndex ~= 0 and OF.util.asks(OF.recent, "said") then
        OF.recent.said(localIndex)
    end

    local word = filter.blocks(message)
    if word ~= nil then

        local speaker = gNetworkPlayers[localIndex]
        local by = speaker ~= nil and OF.util.plain(speaker.name) or "somebody"
        local hold = true
        if OF.util.asks(OF.trouble, "would") then
            hold = OF.trouble.would("filter", "would have hidden a line from @ ('@')",
                by, OF.util.plain(word))
        end
        if hold then

            local named = OF.util.plain(word)

            if localIndex == 0 and noticeCooldown <= 0 then

                OF.notify.show("Nobody saw that - '@' is on the lobby filter",
                    "warn", 5, named)
                noticeCooldown = 90
            end

            if OF.util.is_host() and localIndex ~= 0 then
                OF.util.chat(OF.lang.fill("Filtered from @ ('@')",
                        OF.util.plain(gNetworkPlayers[localIndex].name), named)
                    .. ": " .. OF.util.plain(message), "warn")
            end

            if localIndex ~= 0 then
                OF.recent.note(localIndex, "said a filtered word ('" .. named .. "')")
                tell_on_repeat(localIndex, count_strike(localIndex))
            end
            return false
        end
    end

    if filter.too_fast(localIndex) then
        if localIndex == 0 and noticeCooldown <= 0 then
            OF.notify.show("Slow down - you have only just arrived", "warn", 4)
            noticeCooldown = 90
        end
        if localIndex ~= 0 then
            OF.recent.note(localIndex, "flooded the chat just after arriving")
        end
        return false
    end
end

hook_event(HOOK_ON_CHAT_MESSAGE, on_chat_message)

hook_event(HOOK_UPDATE, function()
    if noticeCooldown > 0 then noticeCooldown = noticeCooldown - 1 end
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.is_host() then return end
    local stored = mod_storage_load(STORE_KEY, "")
    if stored ~= nil and stored ~= "" then OF.util.publish("ofFilter", stored) end
end)

local function said(panel, text, help, r, g, b)
    local built = panel.label_row(text, r, g, b)
    built.walk = true
    return panel.with_help(built, help)
end

function filter.build_page(panel)
    local rows = {}
    local list = filter.words()

    table.insert(rows, said(panel, #list == 0 and "No words on the list."
            or (#list .. " word(s). Click one to take it off."),
        "the lobby's chat is checked against every one of them"))
    table.insert(rows, said(panel, "Add one with /filter add [word].",
        "a word on the list is held back from the lobby's chat"))

    local mode = filter.mode()
    if OF.util.asks(OF.trouble, "mode_name") then
        local how = panel.host_row("settings", filter.RULE_NAME,
            200, 220, 255, function()
                OF.util.report(OF.trouble.set_mode("filter",
                    OF.trouble.next_mode(filter.mode())))
            end, panel.ask_host(OF.trouble.CYCLE_ACTION, "filter"))
        panel.with_right(how, OF.trouble.mode_name(OF.trouble.shown_mode("filter")))
        panel.with_help(how, filter.RULE_HELP)
        table.insert(rows, how)
    end

    if OF.trouble ~= nil and mode == OF.trouble.OBSERVE then
        table.insert(rows, said(panel,
            "Nothing is being held back - the list is only being watched.",
            "chat the game's own word list ate never reaches this mod, so the count can only be low",
            255, 220, 140))
    end

    for _, word in ipairs(list) do
        local entry = word
        table.insert(rows, panel.gated_row("settings", "   " .. word, 255, 180, 180,
            function() OF.util.report(filter.remove(entry)) end))
    end

    if #list > 0 then
        table.insert(rows, panel.confirm_row("filterclear", "Take them all off",
            255, 140, 90, function() OF.util.report(filter.clear()) end))
    end

    table.insert(rows, panel.back_row("control"))
    return rows
end

hook_chat_command("filter",
    "add <word> - hold a word back from the lobby's chat",
    function(msg)
        local said = OF.util.plain(msg or "")
        local word = string.match(said, "^[Aa][Dd][Dd]%s+(.+)$")
        if word == nil then
            return true, OF.lang.t(
                "Say 'add' and a word. Control, Chat filter takes them off again.")
        end
        if OF.util.report(OF.filter.add(word)) then
            OF.util.chat(OF.lang.fill("'@' is held back from the lobby's chat now.",
                string.lower(word)))
        end
        return true
    end)
