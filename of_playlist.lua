OF = OF or {}
OF.playlist = OF.playlist or {}

local playlist = OF.playlist

local ON_OFFER = 2

local RECENT_MAX = 30
local recent = {}

local nominated = nil

local offer = nil

local decided = nil

local armedFor = nil

local sawYes = 0
local sawNo = 0

function playlist.is_on()
    return gGlobalSyncTable.ofPlaylist == true
end

function playlist.offered()
    return offer
end

function playlist.nominated()
    return nominated
end

function playlist.decided()
    return decided
end

function playlist.holding()
    return offer ~= nil
end

function playlist.question()
    if offer == nil then return "What should the lobby play next?" end
    return "Play " .. offer.yesName .. " next?   (no = " .. offer.noName .. ")"
end

local function staleness(key)
    for place, played in ipairs(recent) do
        if played == key then return place end
    end
    return #recent + 1
end

playlist.staleness = staleness

local function draw(pool)
    local total = 0
    for _, mode in ipairs(pool) do total = total + staleness(mode.key) end
    if total <= 0 then return table.remove(pool, 1) end

    local point = math.random(total)
    for index, mode in ipairs(pool) do
        point = point - staleness(mode.key)
        if point <= 0 then return table.remove(pool, index) end
    end
    return table.remove(pool)
end

local function walking_away_from()
    if OF.gamemodes.is_running() then
        local key = gGlobalSyncTable.ofGmKey
        if key ~= nil and key ~= "" then return key end
    end
    return recent[1]
end

function playlist.candidates()
    local pool = {}
    local justPlayed = walking_away_from()
    for _, mode in ipairs(OF.gamemodes.LIST) do
        if OF.gamemodes.can_start_here(mode) and mode.key ~= justPlayed then
            table.insert(pool, mode)
        end
    end

    local picked = {}
    local seat = nil
    if nominated ~= nil then
        for index, mode in ipairs(pool) do
            if mode.key == nominated then
                seat = table.remove(pool, index)
                break
            end
        end
    end
    if seat ~= nil then table.insert(picked, seat) end

    while #picked < ON_OFFER and #pool > 0 do
        table.insert(picked, draw(pool))
    end

    if seat == nil then
        table.sort(picked, function(a, b)
            return staleness(a.key) > staleness(b.key)
        end)
    end
    return picked
end

local function spend(key)
    if key ~= nil and nominated == key then
        nominated = nil
        return true
    end
    return false
end

local function remember(key)
    if key == nil or key == "" then return false end
    if recent[1] == key then return false end
    table.insert(recent, 1, key)
    while #recent > RECENT_MAX do table.remove(recent) end
    return true
end

local function take(mode)
    if mode == nil then return false end
    if not OF.rounds.queue_one(mode.key) then return false end

    remember(mode.key)

    spend(mode.key)

    OF.notify.send_all("Next up: @", "good", 5, mode.name)
    return true
end

local function ours()
    local current = OF.vote.current()
    return current ~= nil and current.kind == "playlist"
end

local function drop(reason)
    if offer == nil and decided == nil then return false end
    offer = nil
    decided = nil
    sawYes, sawNo = 0, 0

    if ours() then
        local ok, why = OF.vote.cancel()
        if not ok then
            OF.chatlog.add_system("playlist vote left open: " .. tostring(why))
        end
    end

    if reason ~= nil and reason ~= "" then
        OF.notify.send_all("@", "warn", 5, reason)
    end
    return true
end

local function another_plan_owns_it()

    if OF.rounds.count() > 0 then return true end

    if OF.rounds.repeating or OF.rounds.is_lent() then return true end

    if OF.util.asks(OF.night, "is_on") and OF.night.is_on() then return true end

    return false
end

function playlist.round_ended(justPlayed)
    if not OF.util.is_host() then return false end

    remember(justPlayed)

    local won = decided
    decided = nil

    if not playlist.is_on() then return false end
    if another_plan_owns_it() then return false end

    if won ~= nil then
        local mode = OF.gamemodes.BY_KEY[won]
        if mode ~= nil and OF.gamemodes.can_start_here(mode) then
            return take(mode)
        end
        OF.chatlog.add_system("the lobby's pick cannot start here: " .. tostring(won))
    end

    if offer ~= nil then return false end

    local pair = playlist.candidates()
    if #pair == 0 then return false end

    if #pair < ON_OFFER then return take(pair[1]) end

    offer = {
        yes = pair[1].key, yesName = pair[1].name,
        no = pair[2].key, noName = pair[2].name,
    }
    sawYes, sawNo = 0, 0

    local ok, why = OF.vote.start("playlist")
    if not ok then

        local first = pair[1]
        offer = nil
        OF.chatlog.add_system("no playlist vote: " .. tostring(why))
        return take(first)
    end

    spend(offer.yes)
    return true
end

function playlist.choose(yes)
    if not OF.util.is_host() then return false end
    if offer == nil then return false end

    local key = offer.yes

    if not yes and sawNo > sawYes then key = offer.no end

    offer = nil
    sawYes, sawNo = 0, 0

    if OF.gamemodes.state() ~= OF.gamemodes.OFF then
        decided = key
        return true
    end

    return take(OF.gamemodes.BY_KEY[key])
end

function playlist.nominate(key, fromLocal)
    if not OF.util.is_host() then return false, "Only the host can do that." end
    if not playlist.is_on() then
        return false, "The lobby is not picking what plays next."
    end

    local mode = OF.gamemodes.BY_KEY[key]
    if mode == nil then return false, "No such game mode." end

    local able, why = OF.gamemodes.can_start_here(mode)
    if not able then return false, why end

    if nominated == key then
        return false, "That one is already on the next ballot."
    end

    nominated = key

    local np = fromLocal ~= nil and gNetworkPlayers[fromLocal] or nil

    OF.notify.send_all("@ put @ on the next ballot", "info", 5,
        np ~= nil and OF.util.plain(np.name) or "Somebody", mode.name)
    return true
end

function playlist.set(on, askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then
        return OF.net.host_does("playlist", on and 1 or 0)
    end

    OF.util.publish("ofPlaylist", on == true)
    if not on then
        drop(nil)

        nominated = nil
    end

    OF.notify.send_all("The lobby picks what plays next: @", "info", 4,
        on and "yes" or "no")

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, on
            and OF.lang.t("let the lobby pick what plays next")
            or OF.lang.t("stopped the lobby picking what plays next"))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal), on
        and OF.lang.t("let the lobby pick what plays next")
        or OF.lang.t("stopped the lobby picking what plays next"))
    return true
end

function playlist.put(on)
    if not OF.util.is_host() then return false end
    on = on == true

    if not on then nominated = nil end
    if playlist.is_on() == on then return false end
    OF.util.publish("ofPlaylist", on)
    if not on then drop(nil) end
    return true
end

local heardQuestion = false

local function listen()

    if not OF.util.asks(OF.vote, "current") then return end

    local asking = ours()
    if asking and not heardQuestion and OF.util.asks(OF.music, "fanfare") then
        OF.music.fanfare("asked")
    end
    heardQuestion = asking
end

local function ask_ahead_seconds()
    return (OF.vote.SECONDS or 25) + 5
end

local function arm_early()

    if offer ~= nil or decided ~= nil then return end

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    local key = gGlobalSyncTable.ofGmKey
    if key == nil or key == "" then return end

    if armedFor == key then return end

    if not playlist.is_on() then return end

    if gGlobalSyncTable.ofQueueOn ~= true then return end
    if another_plan_owns_it() then return end

    local left = OF.gamemodes.time_left()
    if left == nil or left > ask_ahead_seconds() then return end

    armedFor = key

    local pair = playlist.candidates()

    if #pair < ON_OFFER then return end

    offer = {
        yes = pair[1].key, yesName = pair[1].name,
        no = pair[2].key, noName = pair[2].name,

        armedIn = key,
    }
    sawYes, sawNo = 0, 0

    local ok, why = OF.vote.start("playlist")
    if not ok then

        offer = nil
        OF.chatlog.add_system("no early playlist vote: " .. tostring(why))
        return
    end

    spend(offer.yes)
end

local function host_update()
    if not OF.util.is_host() then return end

    if OF.gamemodes.state() == OF.gamemodes.OFF then armedFor = nil end

    if offer == nil then

        if decided ~= nil and (gGlobalSyncTable.ofQueueOn ~= true
            or not playlist.is_on()) then
            drop("The playlist stood down - somebody took the lobby back.")
            return
        end
        arm_early()
        return
    end

    local foreign = OF.gamemodes.state() ~= OF.gamemodes.OFF
        and gGlobalSyncTable.ofGmKey ~= offer.armedIn
    if foreign
        or gGlobalSyncTable.ofQueueOn ~= true
        or not playlist.is_on() then

        drop("The playlist stood down - somebody took the lobby back.")
        return
    end

    if not ours() then
        sawYes, sawNo = 0, 0
        playlist.choose(false)
        return
    end

    sawYes, sawNo = OF.vote.tally()
end

local registeredNominate = false

local function register_nominate()
    if registeredNominate then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registeredNominate = true
    OF.net.register_action("nominate", "vote", function(fromLocal, _, _, key)

        if not OF.util.is_host() then return false, "Only the host." end
        return playlist.nominate(key, fromLocal)
    end)
end

hook_event(HOOK_UPDATE, function()
    register_nominate()
    listen()
    host_update()
end)

local function mode_wanted(text)
    text = OF.util.plain(tostring(text or ""))
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then return nil end

    if type(OF.gamemodes.LIST) ~= "table" then return nil end
    local lowered = string.lower(text)
    for _, mode in ipairs(OF.gamemodes.LIST) do
        if string.lower(mode.key or "") == lowered then return mode end
    end
    for _, mode in ipairs(OF.gamemodes.LIST) do
        if string.lower(mode.name or "") == lowered then return mode end
    end
    if OF.util.asks(OF.rounds, "mode_named") then
        return OF.rounds.mode_named(text)
    end
    return nil
end

hook_chat_command("nominate", "<mode> - put a mode on the lobby's next ballot",
function(msg)
    msg = msg or ""
    if msg == "" then
        if not playlist.is_on() then
            OF.util.chat(OF.lang.t("The lobby is not picking what plays next."))
            return true
        end

        if not OF.util.is_host() then
            OF.util.chat(OF.lang.t("Name a mode to put it on the next ballot. Try /nominate Sumo."))
            return true
        end
        local standing = nominated ~= nil and OF.gamemodes.BY_KEY[nominated] or nil
        if standing ~= nil then
            OF.util.chat(OF.lang.fill("@ is on the next ballot.",
                OF.lang.t(standing.name)))
        else
            OF.util.chat(OF.lang.t("Nothing is nominated. Try /nominate Sumo."))
        end
        return true
    end

    local mode = mode_wanted(msg)
    if mode == nil then

        OF.util.chat(OF.lang.t("No game mode by that name. Try its name off the mode list."))
        return true
    end

    OF.util.report(OF.net.host_does("nominate", nil, nil, mode.key))
    return true
end)

function playlist.ready()
    return true
end
