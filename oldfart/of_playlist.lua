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

playlist.ALWAYS_KEY = "ofAlwaysOn"
playlist.PICKS = { "vote", "turn", "random", "kinds" }
playlist.PICK_NAMES = {
    vote = "the lobby votes",
    turn = "in turn",
    random = "at random",

    kinds = "kinds in turn",
}
playlist.POOLS = { "all", "lined" }
playlist.POOL_NAMES = {
    all = "every mode",
    lined = "the ones lined up",
}

playlist.FLOORS = { 2, 3, 4, 6, 8 }

playlist.RETRY_SECONDS = 5

local alwaysSet = nil

local alwaysTurnAt = 0

local function always_fields()
    local out = { on = false, pick = "vote", pool = "all", floor = 2,
        waiting = false }
    local text = gGlobalSyncTable[playlist.ALWAYS_KEY]
    if type(text) == "string" then
        local on, pick, pool, floor, waiting =
            string.match(text, "^(%d) (%a+) (%a+) (%d+) (%d)$")
        if on ~= nil then
            out.on = on == "1"
            if playlist.PICK_NAMES[pick] ~= nil then out.pick = pick end
            if playlist.POOL_NAMES[pool] ~= nil then out.pool = pool end
            out.waiting = waiting == "1"
            local n = tonumber(floor)
            for _, stop in ipairs(playlist.FLOORS) do
                if stop == n then out.floor = stop end
            end
        end
    end
    return out
end

local function publish_always(t)
    OF.util.publish(playlist.ALWAYS_KEY, string.format("%s %s %s %.0f %s",
        t.on and "1" or "0", t.pick, t.pool, t.floor,
        t.waiting and "1" or "0"))
end

function playlist.always()
    return always_fields()
end

function playlist.always_on()
    return always_fields().on
end

function playlist.feeding()
    return playlist.is_on() or always_fields().on
end

local function pick_now()
    local t = always_fields()
    if t.on then return t.pick end
    return "vote"
end

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

function playlist.in_pool(key)
    local t = always_fields()
    if not t.on or t.pool ~= "lined" then return true end
    if alwaysSet == nil then return true end
    for _, entry in ipairs(alwaysSet) do
        if entry.mode == key then return true end
    end
    return false
end

function playlist.playable()
    local pool = {}
    local justPlayed = walking_away_from()
    local again = nil
    for _, mode in ipairs(OF.gamemodes.LIST) do
        if playlist.in_pool(mode.key) and OF.gamemodes.can_start_here(mode) then
            if mode.key ~= justPlayed then
                table.insert(pool, mode)
            else
                again = mode
            end
        end
    end

    if #pool == 0 and again ~= nil and always_fields().on then
        table.insert(pool, again)
    end
    return pool
end

function playlist.candidates()
    local pool = playlist.playable()

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

local function entry_for(mode)
    local entry = { mode = mode.key }
    local t = always_fields()
    if not t.on then return entry end

    if t.pool == "lined" and alwaysSet ~= nil then
        for _, lined in ipairs(alwaysSet) do
            if lined.mode == mode.key then
                entry.arena, entry.place, entry.mods =
                    lined.arena, lined.place, lined.mods
                break
            end
        end
    end
    return playlist.with_map(entry)
end

function playlist.with_map(entry)
    if entry.arena ~= nil or entry.place ~= nil then return entry end
    if OF.util.asks(OF.mapvote, "wanted") and OF.mapvote.wanted(entry.mode) then
        return entry
    end
    if OF.util.asks(OF.gamemodes, "next_place") then
        entry.arena = OF.gamemodes.next_place(entry.mode)
    end
    if entry.arena == nil and OF.util.asks(OF.gamemodes, "next_level") then
        local level = OF.gamemodes.next_level(entry.mode)
        if level ~= nil then
            entry.place = { level = level.level, area = level.area or 1,
                act = level.act or 1, name = level.name or "somewhere" }
        end
    end
    return entry
end

playlist.entry_for = entry_for

local function take(mode, lined)
    if mode == nil then return false end
    local entry = entry_for(mode)

    if type(lined) == "table" and (lined.arena ~= nil or lined.place ~= nil) then
        entry.arena, entry.place, entry.mods = lined.arena, lined.place, lined.mods
    end

    local queued
    if entry.arena == nil and entry.place == nil and entry.mods == nil then
        queued = OF.rounds.queue_one(mode.key)
    else
        queued = OF.rounds.queue_entry(entry)
    end
    if not queued then return false end

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

    if not playlist.feeding() then return false end
    if another_plan_owns_it() then return false end

    if won ~= nil then
        local mode = OF.gamemodes.BY_KEY[won]
        if mode ~= nil and OF.gamemodes.can_start_here(mode) then
            return take(mode)
        end
        OF.chatlog.add_system("the lobby's pick cannot start here: " .. tostring(won))
    end

    return playlist.supply()
end

local function next_in_turn()
    local list = {}
    local t = always_fields()
    if t.pool == "lined" and alwaysSet ~= nil then
        for _, entry in ipairs(alwaysSet) do
            local mode = OF.gamemodes.BY_KEY[entry.mode]
            if mode ~= nil then list[#list + 1] = { mode = mode, entry = entry } end
        end
    else
        for _, mode in ipairs(OF.gamemodes.LIST) do
            list[#list + 1] = { mode = mode }
        end
    end
    local n = #list
    if n == 0 then return nil end

    local justPlayed = walking_away_from()
    local again = nil
    for offset = 1, n do
        local at = (alwaysTurnAt + offset - 1) % n + 1
        local seat = list[at]
        if OF.gamemodes.can_start_here(seat.mode) then
            if seat.mode.key ~= justPlayed then
                alwaysTurnAt = at
                return seat.mode, seat.entry
            end
            if again == nil then again = at end
        end
    end
    if again == nil then return nil end
    alwaysTurnAt = again
    return list[again].mode, list[again].entry
end

function playlist.supply()
    if not OF.util.is_host() then return false end
    if not playlist.feeding() then return false end
    if another_plan_owns_it() then return false end

    if offer ~= nil then return false end

    local pick = pick_now()
    if pick == "turn" then
        local mode, lined = next_in_turn()
        if mode == nil then return false end
        return take(mode, lined)
    end

    local pair = playlist.candidates()
    if #pair == 0 then return false end

    if pick == "random" then
        local pool = playlist.playable()
        if #pool == 0 then return false end
        return take(pool[math.random(#pool)])
    end

    if pick == "kinds" then
        local pool = playlist.playable()
        if OF.util.asks(OF.tournament, "kind_turn") then
            pool = OF.tournament.kind_turn(pool, walking_away_from())
        end
        if #pool == 0 then return false end
        return take(pool[math.random(#pool)])
    end
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
    if not playlist.feeding() or pick_now() ~= "vote" then
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

        if not always_fields().on then drop(nil) end

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

    local clockWent = false
    if not on and always_fields().on then
        playlist.put_always(false)
        clockWent = true
    end
    if playlist.is_on() == on then return clockWent end
    OF.util.publish("ofPlaylist", on)
    if not on then drop(nil) end
    return true
end

function playlist.put_always(on)
    if not OF.util.is_host() then return false end
    local t = always_fields()
    if t.on == (on == true) then return false end
    if on == true then return playlist.set_always(true) end
    t.on, t.waiting = false, false
    publish_always(t)
    alwaysSet = nil
    if not playlist.is_on() then drop(nil) end
    if OF.util.asks(OF.rounds, "is_running") and OF.rounds.is_running() then
        local stopped, why = OF.rounds.stop(true)
        if not stopped then
            OF.chatlog.add_system("the queue stayed on after the clock: " .. tostring(why))
        end
    end
    return true
end

local function read_lined_up()
    local set = {}
    for _, entry in ipairs(OF.rounds.queue or {}) do
        if entry.mode ~= OF.rounds.SURPRISE
            and OF.gamemodes.BY_KEY[entry.mode] ~= nil then
            set[#set + 1] = { mode = entry.mode, arena = entry.arena,
                place = entry.place, mods = entry.mods }
        end
    end
    return set
end

function playlist.set_always(on, askerLocal)
    on = on == true
    local gate = on and "speedrun" or "end_round"
    if not OF.perms.can(gate) then
        return false, "Your rank cannot do that.", gate
    end
    if not OF.util.is_host() then
        return OF.net.host_does(on and "alwayson" or "alwaysoff")
    end

    local t = always_fields()
    if t.on == on then
        return false, on and "The lobby is already running around the clock."
            or "The lobby is not running around the clock."
    end

    if not on then
        playlist.put_always(false)
        OF.notify.send_all("The lobby stops running around the clock", "warn", 5)
        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal,
                OF.lang.t("stopped the lobby running around the clock"))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.t("stopped the lobby running around the clock"))
        return true
    end

    if t.pool == "lined" then
        local set = read_lined_up()
        if #set == 0 then
            return false, "Line some modes up first, or pick every mode."
        end
        alwaysSet = set
    else
        alwaysSet = nil
    end
    alwaysTurnAt = 0
    t.on, t.waiting = true, false
    publish_always(t)

    if OF.util.asks(OF.rounds, "run_always") then OF.rounds.run_always() end

    OF.notify.send_all("The lobby runs around the clock now: @", "good", 6,
        OF.lang.t(playlist.PICK_NAMES[t.pick]))
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.t("set the lobby running around the clock"))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.t("set the lobby running around the clock"))
    return true
end

function playlist.set_always_option(which, value)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local list = which == "pick" and playlist.PICKS
        or which == "pool" and playlist.POOLS
        or which == "floor" and playlist.FLOORS or nil
    if list == nil then return false, "No such setting." end
    local at = nil
    for index, stop in ipairs(list) do
        if stop == value then at = index end
    end
    if at == nil then return false, "No such setting." end
    if not OF.util.is_host() then
        local code = which == "pick" and 1 or which == "pool" and 2 or 3
        return OF.net.host_does("alwaysset", code, at)
    end

    local t = always_fields()
    if which == "pool" and value == "lined" and t.on then
        local set = read_lined_up()
        if #set == 0 then
            return false, "Line some modes up first, or pick every mode."
        end
        alwaysSet = set
        alwaysTurnAt = 0
    elseif which == "pool" then
        alwaysSet = nil
        alwaysTurnAt = 0
    end
    t[which] = value
    publish_always(t)
    return true
end

function playlist.cycle_always(which)
    local t = always_fields()
    local list = which == "pick" and playlist.PICKS
        or which == "pool" and playlist.POOLS or playlist.FLOORS
    local at = 1
    for index, stop in ipairs(list) do
        if stop == t[which] then at = index end
    end
    return playlist.set_always_option(which, list[at % #list + 1])
end

function playlist.set_always_waiting(waiting)
    if not OF.util.is_host() then return false end
    local t = always_fields()
    if not t.on or t.waiting == (waiting == true) then return false end
    t.waiting = waiting == true
    publish_always(t)
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

    if not playlist.feeding() or pick_now() ~= "vote" then return end

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
            or not playlist.feeding()) then
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
        or not playlist.feeding() then

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

    OF.net.register_action("alwayson", "speedrun", function(asker)
        return playlist.set_always(true, asker)
    end)
    OF.net.register_action("alwaysoff", "end_round", function(asker)
        return playlist.set_always(false, asker)
    end)
    OF.net.register_action("alwaysset", "speedrun", function(_, code, at)
        local which = code == 1 and "pick" or code == 2 and "pool" or "floor"
        local list = code == 1 and playlist.PICKS
            or code == 2 and playlist.POOLS or playlist.FLOORS
        local value = list[tonumber(at) or 0]
        if value == nil then return false, "No such setting." end
        return playlist.set_always_option(which, value)
    end)
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
        if not playlist.feeding() or pick_now() ~= "vote" then
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
