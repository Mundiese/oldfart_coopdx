OF = OF or {}
OF.rounds = OF.rounds or {}

local rounds = OF.rounds

local GAP_SECONDS = 3

rounds.BREATHERS = { 0, 3, 10, 30, 60 }

function rounds.breather_name(seconds)
    if seconds == nil then seconds = rounds.gap end
    if seconds <= 0 then return "straight on" end
    if seconds >= 60 then return "a minute" end
    return OF.lang.fill("@ seconds", tostring(seconds))
end

rounds.queue = rounds.queue or {}
rounds.repeating = false
rounds.gap = GAP_SECONDS

rounds.SURPRISE = "*"
local SAVED_KEY = "queue_plan"
local SAVED_LOOP = "queue_loop"
local SAVED_GAP = "queue_gap"
local EVENING_PREFIX = "queue_evening"
rounds.EVENINGS = 5

rounds.NAME_MAX = 19

local function evening_key(slot)
    return EVENING_PREFIX .. tostring(slot)
end
local FIELD = ";"
local ROW = "|"
local function pack(queue)
    local parts = {}
    for _, entry in ipairs(queue) do
        table.insert(parts, entry.mode .. FIELD .. (entry.arena or "")
            .. FIELD .. (entry.mods or ""))
    end
    return OF.util.pack_rows(parts, ROW, OF.util.STORE_MAX)
end

local function unpack_plan(text)
    local queue = {}
    if text == nil or text == "" then return queue end
    for row in string.gmatch(text, "[^" .. ROW .. "]+") do

        local mode, arena, mods = string.match(row,
            "^([^" .. FIELD .. "]*)" .. FIELD
            .. "([^" .. FIELD .. "]*)" .. FIELD .. "(.*)$")
        if mode == nil then
            mode, arena = string.match(row,
                "^([^" .. FIELD .. "]*)" .. FIELD .. "(.*)$")
        end

        if mode ~= nil
            and (mode == rounds.SURPRISE or OF.gamemodes.BY_KEY[mode] ~= nil) then
            table.insert(queue, {
                mode = mode,
                arena = (arena ~= nil and arena ~= "") and arena or nil,
                mods = (mods ~= nil and mods ~= "") and mods or nil,
            })
        end
    end
    return queue
end

function rounds.save()
    if not OF.util.is_host() then return false end
    local packed, kept = pack(rounds.queue)
    local ok = OF.util.store(SAVED_KEY, packed)
    OF.util.store_bool(SAVED_LOOP, rounds.repeating)
    OF.util.store(SAVED_GAP, tostring(rounds.gap))

    if ok and kept < #rounds.queue then
        OF.notify.show("Only the first @ round(s) will be remembered next time.",
            "warn", 7, tostring(kept))
    end
    return ok
end

function rounds.load()
    rounds.queue = unpack_plan(mod_storage_load(SAVED_KEY, ""))
    rounds.repeating = mod_storage_load_bool(SAVED_LOOP, false)

    rounds.set_breather(tonumber(mod_storage_load(SAVED_GAP, "")) or GAP_SECONDS,
        true)
    rounds.publish()
    return #rounds.queue
end

function rounds.set_breather(seconds, quiet)
    if not quiet and not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not quiet and not OF.util.is_host() then
        return OF.net.host_does("queuegap", seconds)
    end
    seconds = tonumber(seconds) or GAP_SECONDS
    local best, gap = GAP_SECONDS, nil
    for _, step in ipairs(rounds.BREATHERS) do
        local away = math.abs(step - seconds)
        if gap == nil or away < gap then best, gap = step, away end
    end
    rounds.gap = best
    if not quiet then rounds.save() end
    return true
end

function rounds.next_breather()
    for index, step in ipairs(rounds.BREATHERS) do
        if step == rounds.gap then
            return rounds.BREATHERS[index % #rounds.BREATHERS + 1]
        end
    end
    return rounds.BREATHERS[1]
end

local gapLeft = 0
local gapSeen = nil

local waiting = false
local lastState = nil

local playedSoFar = 0

local lastMode = nil

local pausedSaid = false

local function always_running()
    return OF.util.asks(OF.playlist, "always_on")
        and OF.playlist.always_on() == true
end

local function mods_for(entry)
    if entry ~= nil and entry.mods ~= nil and entry.mods ~= "" then
        return entry.mods
    end
    return ""
end

function rounds.is_running()
    return gGlobalSyncTable.ofQueueOn == true
end

function rounds.count()
    if OF.util.is_host() then return #rounds.queue end
    return gGlobalSyncTable.ofQueueLeft or 0
end

function rounds.looping()
    if OF.util.is_host() then return rounds.repeating == true end
    return gGlobalSyncTable.ofQueueLoop == true
end

function rounds.reset_options()
    if not OF.util.is_host() then return false end
    local moved = rounds.repeating == true or rounds.gap ~= GAP_SECONDS
    if rounds.gap ~= GAP_SECONDS then rounds.set_breather(GAP_SECONDS, true) end
    if rounds.repeating == true then
        rounds.repeating = false
        rounds.publish()
        rounds.save()
    end
    return moved
end

function rounds.set_repeating(on)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then
        return OF.net.host_does("queueloop", on and 1 or 0)
    end
    rounds.repeating = (on == true)
    rounds.publish()
    rounds.save()
    return true
end

local function coming_line()
    local after = rounds.count() - 1
    if after > 0 then
        return OF.lang.fill("@ more after this", tostring(after))
    end
    if after == 0 then return OF.lang.t("last one lined up") end
    return nil
end

function rounds.describe(entry)
    if entry == nil then return "" end

    if entry.mode == rounds.SURPRISE then return "Surprise me" end
    local mode = OF.gamemodes.BY_KEY[entry.mode]
    local text = mode ~= nil and mode.name or entry.mode
    if entry.arena ~= nil and entry.arena ~= "" then
        local name = OF.arena.name_of(entry.arena)
        if name ~= nil then text = text .. " in " .. name end
    elseif entry.place ~= nil and entry.place.name ~= nil then

        text = text .. " on " .. entry.place.name
    end
    return text
end

function rounds.localize(text)
    if text == nil or text == "" then return "" end

    local onMode, onPlace = string.match(text, "^(.-) on (.*)$")
    local inMode, inArena = string.match(text, "^(.-) in (.*)$")
    if onMode ~= nil then return OF.lang.fill("@ on @", onMode, onPlace) end
    if inMode == nil then return OF.lang.get(text) end
    return OF.lang.fill("@ in @", inMode, inArena)
end

function rounds.describe_full(entry)

    local line = rounds.localize(rounds.describe(entry))
    if entry == nil or entry.mods == nil or entry.mods == "" then return line end
    if not OF.util.asks(OF.modifiers, "label") then return line end
    return OF.lang.fill("@ with @", line, OF.modifiers.label(entry.mods))
end

function rounds.add(modeKey, arenaKey, modsText)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if modeKey ~= rounds.SURPRISE and OF.gamemodes.BY_KEY[modeKey] == nil then
        return false, "No such game mode."
    end

    if not OF.util.is_host() then
        return OF.net.host_does("queueadd", modeKey, arenaKey)
    end

    table.insert(rounds.queue, {
        mode = modeKey, arena = arenaKey,
        mods = (modsText ~= nil and modsText ~= "") and modsText or nil,
    })
    rounds.publish()
    rounds.save()
    return true
end

function rounds.remove(index)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then return false, "The host holds the list." end
    if rounds.queue[index] == nil then return false, "No such round." end
    table.remove(rounds.queue, index)
    rounds.publish()
    rounds.save()
    return true
end

function rounds.move(from, to)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then return false, "The host holds the list." end
    from = math.floor(tonumber(from) or 0)
    to = math.floor(tonumber(to) or 0)
    local entry = rounds.queue[from]
    if entry == nil then return false, "No such round." end
    to = OF.util.clamp(to, 1, #rounds.queue)
    if to == from then return true end

    table.remove(rounds.queue, from)
    table.insert(rounds.queue, to, entry)
    rounds.publish()
    rounds.save()
    return true
end

function rounds.duplicate(index)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then return false, "The host holds the list." end
    index = math.floor(tonumber(index) or 0)
    local entry = rounds.queue[index]
    if entry == nil then return false, "No such round." end
    table.insert(rounds.queue, index + 1, {
        mode = entry.mode, arena = entry.arena, place = entry.place,
        mods = entry.mods,
    })
    rounds.publish()
    rounds.save()
    return true
end

function rounds.mend(pick)
    if not OF.util.is_host() then return 0, 0 end

    if rounds.is_lent() then return 0, 0 end

    local swapped, dropped = 0, 0
    for index = #rounds.queue, 1, -1 do
        local entry = rounds.queue[index]
        if entry.mode ~= rounds.SURPRISE then
            local mode = OF.gamemodes.BY_KEY[entry.mode]
            if mode == nil or not OF.gamemodes.can_start_here(mode) then
                local instead = nil
                if pick ~= nil then instead = pick(index, entry) end
                if instead ~= nil and OF.gamemodes.BY_KEY[instead] ~= nil then
                    entry.mode = instead
                    swapped = swapped + 1
                else
                    table.remove(rounds.queue, index)
                    dropped = dropped + 1
                end
            end
        end
    end

    if swapped + dropped > 0 then rounds.publish() rounds.save() end
    return swapped, dropped
end

function rounds.clear()
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then return OF.net.host_does("queueclear") end
    rounds.queue = {}
    rounds.publish()
    rounds.save()
    return true
end

function rounds.fill_with_everything(arenaKey, modsText)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then
        return OF.net.host_does("queuefill", arenaKey)
    end

    rounds.queue = {}
    for _, mode in ipairs(OF.gamemodes.LIST) do

        if OF.gamemodes.can_start_here(mode) then
            table.insert(rounds.queue, {
                mode = mode.key, arena = arenaKey,
                mods = (modsText ~= nil and modsText ~= "") and modsText or nil,
            })
        end
    end
    rounds.publish()
    rounds.save()
    return true
end

local function finale_at(left)

    if not OF.util.is_host() then return false end
    if gGlobalSyncTable.ofQueueOn ~= true then return false end
    if rounds.repeating then return false end

    if rounds.is_lent() then return false end

    if OF.util.asks(OF.playlist, "feeding") and OF.playlist.feeding() then
        return false
    end
    if OF.util.asks(OF.night, "is_on") and OF.night.is_on() then return false end
    if #rounds.queue ~= left then return false end
    return playedSoFar + #rounds.queue >= 2
end

function rounds.finale_next()
    return finale_at(1)
end

function rounds.in_finale()
    return finale_at(0)
end

function rounds.publish()
    OF.util.publish("ofQueueLeft", #rounds.queue)
    OF.util.publish("ofQueueNext", rounds.describe(rounds.queue[1]))

    OF.util.publish("ofQueueLoop", rounds.repeating == true)
    if OF.util.asks(OF.standings, "arm_finale") then
        OF.standings.arm_finale(rounds.finale_next())
    end
end

local function unpack_evening(text)
    if type(text) ~= "string" or text == "" then return nil end
    local name, plan = string.match(text,
        "^([^" .. ROW .. "]*)" .. ROW .. "(.*)$")
    if name == nil or name == "" then return nil end
    return name, unpack_plan(plan)
end

local function pack_evening(name, queue)
    local packed, kept = pack(queue)
    return name .. ROW .. packed, kept
end

function rounds.evenings()
    local found = {}
    for slot = 1, rounds.EVENINGS do
        local name, queue = unpack_evening(mod_storage_load(evening_key(slot), ""))
        if name ~= nil then
            table.insert(found, { slot = slot, name = name, queue = queue })
        end
    end
    return found
end

function rounds.free_evening()
    local used = {}
    for _, entry in ipairs(rounds.evenings()) do used[entry.slot] = true end
    for slot = 1, rounds.EVENINGS do
        if not used[slot] then return slot end
    end
    return nil
end

function rounds.suggested_name()
    local slot = rounds.free_evening() or rounds.EVENINGS
    return string.sub(OF.lang.fill("@ rounds @", tostring(#rounds.queue),
        tostring(slot)), 1, rounds.NAME_MAX)
end

function rounds.keep(name, slot, list)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then return false, "The host holds the list." end
    if list == nil then list = rounds.queue end
    if #list == 0 then return false, "Line some rounds up first." end

    name = OF.util.plain(tostring(name or ""))

    name = string.gsub(name, "[%" .. ROW .. "%" .. FIELD .. "]", "")
    name = string.sub(name, 1, rounds.NAME_MAX)
    if name == "" then return false, "Give the session a name." end

    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > rounds.EVENINGS then
        slot = rounds.free_evening()
        if slot == nil then
            return false, "All the session slots are full - clear one first."
        end
    end

    local packed, kept = pack_evening(name, list)
    if not OF.util.store(evening_key(slot), packed) then
        return false, "That could not be saved."
    end

    if kept < #list then
        OF.notify.show("Only the first @ round(s) fitted.", "warn", 6,
            tostring(kept))
    end
    OF.notify.show("Kept as a session: @", "good", 5, name)
    return true
end

function rounds.play(slot)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then return false, "The host holds the list." end
    if rounds.is_running() then return false, "Stop the queue first." end
    if rounds.is_lent() then return false, "Stop the queue first." end

    slot = math.floor(tonumber(slot) or 0)
    for _, entry in ipairs(rounds.evenings()) do
        if entry.slot == slot then
            rounds.queue = entry.queue
            rounds.publish()
            rounds.save()
            OF.notify.show("@ - @ round(s) lined up.", "good", 5,
                entry.name, tostring(#rounds.queue))
            return true
        end
    end
    return false, "No such session."
end

function rounds.forget_evening(slot)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > rounds.EVENINGS then return false, "No such session." end
    OF.util.clear(evening_key(slot))
    return true
end

local lentQueue = nil
local lentRepeat = nil

function rounds.take_over(list)
    if lentQueue == nil then
        lentQueue = rounds.queue
        lentRepeat = rounds.repeating
    end
    rounds.queue = list or {}
    rounds.repeating = false
    rounds.publish()
    return true
end

function rounds.hand_back()
    if lentQueue == nil then return false end
    rounds.queue = lentQueue
    rounds.repeating = lentRepeat
    lentQueue, lentRepeat = nil, nil
    rounds.publish()
    return true
end

function rounds.is_lent()
    return lentQueue ~= nil
end

function rounds.queue_one(modeKey)
    return rounds.queue_entry({ mode = modeKey })
end

function rounds.queue_entry(entry)
    if not OF.util.is_host() then return false end
    if type(entry) ~= "table" then return false end
    if entry.mode ~= rounds.SURPRISE
        and OF.gamemodes.BY_KEY[entry.mode] == nil then
        return false
    end
    table.insert(rounds.queue, {
        mode = entry.mode, arena = entry.arena, place = entry.place,
        mods = entry.mods,
    })
    rounds.publish()
    return true
end

local function surprise_mode()
    local able = {}
    for _, mode in ipairs(OF.gamemodes.LIST) do
        if OF.gamemodes.can_start_here(mode) and mode.key ~= lastMode then
            table.insert(able, mode.key)
        end
    end
    if #able == 0 then
        for _, mode in ipairs(OF.gamemodes.LIST) do
            if OF.gamemodes.can_start_here(mode) then
                table.insert(able, mode.key)
            end
        end
    end
    if #able == 0 then return nil end
    return able[math.random(#able)]
end

rounds.surprise_mode = surprise_mode

local function start_next()
    if #rounds.queue == 0 then return false, "The queue is empty." end

    local firstWhy = nil
    local said = false

    for _ = 1, #rounds.queue do
        local entry = table.remove(rounds.queue, 1)

        local modeKey = entry.mode
        if modeKey == rounds.SURPRISE then
            modeKey = surprise_mode()
            if modeKey == nil then

                table.insert(rounds.queue, 1, entry)
                return false, "Nothing here can be played right now."
            end
        end

        playedSoFar = playedSoFar + 1
        local ok, reason = OF.gamemodes.start(modeKey,
            { arena = entry.arena, place = entry.place, mods = mods_for(entry) })
        if not ok then playedSoFar = playedSoFar - 1 end

        if ok then

            if entry.mode == rounds.SURPRISE then
                local mode = OF.gamemodes.BY_KEY[modeKey]
                OF.notify.send_all("Surprise: @", "good", 5,
                    mode ~= nil and mode.name or modeKey)
            end

            lastMode = modeKey
            if rounds.repeating then table.insert(rounds.queue, entry) end
            rounds.publish()
            return true
        end

        if firstWhy == nil then firstWhy = reason end

        if rounds.is_lent() or #rounds.queue == 0 then
            table.insert(rounds.queue, 1, entry)
            return false, firstWhy
        end

        table.insert(rounds.queue, entry)

        if not said then
            said = true

            OF.notify.send_all("@ cannot start yet - later in the session instead.",
                "warn", 6, rounds.localize(rounds.describe(entry)))
        end
        rounds.publish()
    end

    return false, firstWhy or "The queue is empty."
end

function rounds.start(askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then return OF.net.host_does("queuestart") end

    if #rounds.queue == 0 then

        if always_running() then return rounds.run_always() end
        return false, "Line some rounds up first."
    end

    OF.util.publish("ofQueueOn", true)

    local starter = askerLocal ~= nil and gNetworkPlayers[askerLocal] or nil
    OF.gamemodes.seriesLead = starter ~= nil and starter.globalIndex or nil
    gapLeft, gapSeen, waiting = 0, nil, false

    playedSoFar = 0
    lastState = OF.gamemodes.state()

    if OF.gamemodes.state() == OF.gamemodes.OFF then
        local ok, reason = start_next()
        if not ok then
            OF.util.publish("ofQueueOn", false)
            return false, reason
        end
    end

    rounds.publish()

    OF.notify.send_all("The lobby is running itself now - @ to go", "good", 5,
        tostring(#rounds.queue))

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("started the queue: @ to go",
                tostring(#rounds.queue)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("started the round queue: @ to go",
            tostring(#rounds.queue)))
    return true
end

function rounds.run_always()
    if not OF.util.is_host() then return false end
    if gGlobalSyncTable.ofQueueOn ~= true then
        OF.util.publish("ofQueueOn", true)
        playedSoFar = 0
    end
    pausedSaid = false
    lastState = OF.gamemodes.state()
    if lastState == OF.gamemodes.OFF then
        waiting = true
        gapLeft, gapSeen = 0, clock_elapsed()
    end
    rounds.publish()
    return true
end

function rounds.stop(quiet, askerLocal)

    if not quiet and not OF.perms.can("end_round") then
        return false, "Your rank cannot do that.", "end_round"
    end
    if gGlobalSyncTable.ofQueueOn ~= true then return false, "Nothing is queued up." end

    if not quiet and not OF.util.is_host() then
        return OF.net.host_does("queuestop")
    end

    OF.util.publish("ofQueueOn", false)
    gapLeft, gapSeen, waiting = 0, nil, false
    pausedSaid = false

    if OF.util.asks(OF.playlist, "put_always") then OF.playlist.put_always(false) end

    playedSoFar = 0
    rounds.publish()
    if not quiet then
        OF.notify.send_all("Round queue stopped", "warn", 4)

        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal,
                OF.lang.t("stopped the queue"))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.t("stopped the round queue"))
    end
    return true
end

function rounds.race_holds()
    local run = OF.speedrun
    return run ~= nil and type(run.state) == "function"
        and run.state() ~= run.OFF
end

local function host_update()
    if not OF.util.is_host() then
        lastState = OF.gamemodes.state()
        return
    end

    local state = OF.gamemodes.state()
    local was = lastState
    lastState = state

    if gGlobalSyncTable.ofQueueOn ~= true then return end
    if was == nil then return end

    if was ~= state and state == OF.gamemodes.OFF then
        if was == OF.gamemodes.RESULTS then

            waiting = true
            gapLeft, gapSeen = rounds.gap, clock_elapsed()

            if OF.util.asks(OF.playlist, "round_ended") then
                OF.playlist.round_ended(lastMode)
            end

            if OF.util.asks(OF.standings, "finale_coming")
                and OF.standings.finale_coming() then
                OF.notify.send_all("Last one - the finale pays @.", "good", 6,
                    OF.standings.finale_name())
            end
        elseif always_running() then

            waiting = true
            gapLeft, gapSeen = rounds.gap, clock_elapsed()
            if OF.util.asks(OF.playlist, "round_ended") then
                OF.playlist.round_ended(lastMode)
            end
        else
            rounds.stop(true)

            OF.notify.send_all(
                "Round queue stood down - somebody stopped the round.",
                "warn", 6)
            return
        end
    end

    if not waiting then return end

    if state ~= OF.gamemodes.OFF then
        gapLeft, waiting = 0, false
        return
    end

    if OF.util.asks(OF.playlist, "holding") and OF.playlist.holding() then
        gapSeen = clock_elapsed()
        return
    end

    if rounds.race_holds() then
        gapSeen = clock_elapsed()
        return
    end

    local now = clock_elapsed()
    local since = now - (gapSeen or now)
    gapSeen = now
    if since > 0 then gapLeft = gapLeft - since end
    if gapLeft > 0 then return end
    gapLeft, waiting = 0, false

    if always_running() then
        rounds.always_step()
        return
    end

    if #rounds.queue == 0 and OF.util.asks(OF.tournament, "crowning")
        and OF.tournament.crowning() then
        OF.util.publish("ofQueueOn", false)
        rounds.publish()
        return
    end

    if #rounds.queue == 0 then
        OF.util.publish("ofQueueOn", false)
        rounds.publish()

        OF.notify.send_all("That was the last one. Well played.", "good", 6)

        if OF.util.asks(OF.standings, "leader") then
            local ahead = OF.standings.leader()
            if ahead ~= nil then
                OF.notify.send_all("@ takes the evening on @", "good", 8,
                    ahead.name, tostring(ahead.points))
            end
        end

        if OF.util.asks(OF.music, "fanfare") then OF.music.fanfare("finish") end
        OF.celebrate.win()
        return
    end

    local ok, reason = start_next()
    if not ok then
        OF.util.publish("ofQueueOn", false)
        rounds.publish()
        OF.notify.send_all("Queue stopped: @", "warn", 6, reason or "cannot start")
    end
end

hook_event(HOOK_UPDATE, host_update)

local function pause(template, value)
    waiting = true
    gapLeft, gapSeen = OF.playlist.RETRY_SECONDS or 5, clock_elapsed()
    OF.playlist.set_always_waiting(true)
    if not pausedSaid then
        pausedSaid = true
        OF.notify.send_all(template, "info", 6, value)
    end
    return false
end

function rounds.always_step()
    if not OF.util.is_host() then return false end
    if not always_running() then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.OFF then return false end

    if OF.util.asks(OF.tournament, "crowning") and OF.tournament.crowning() then
        waiting = true
        gapLeft, gapSeen = 0, clock_elapsed()
        return true
    end

    local floor = OF.playlist.always().floor
    local here = #OF.gamemodes.participants()
    if here < floor then
        return pause("Waiting for @ players to carry on", tostring(floor))
    end

    if #rounds.queue == 0 then
        OF.playlist.supply()

        if OF.playlist.holding() then
            waiting = true
            gapLeft, gapSeen = 0, clock_elapsed()
            return true
        end
        if #rounds.queue == 0 then
            return pause("Waiting - @", "nothing here can be played right now")
        end
    end

    local ok, reason = start_next()
    if not ok then
        return pause("Waiting - @", reason or "nothing here can be played right now")
    end
    pausedSaid = false
    OF.playlist.set_always_waiting(false)
    return true
end

function rounds.build_page(panel)
    local rows = {}

    if rounds.is_running() then
        table.insert(rows, panel.label_row(
            OF.lang.fill("@ round(s) to go", rounds.count())))

        table.insert(rows, panel.with_help(panel.gated_row("end_round",
            OF.lang.t("Stop the queue"), 255, 140, 90,

            function() OF.util.report(rounds.stop(false, 0)) end),
            "the round being played finishes; nothing behind it is started"))
    else

        table.insert(rows, panel.label_row(
            OF.lang.t("Line rounds up and the lobby runs itself.")))

        table.insert(rows, panel.with_help(panel.gated_row("speedrun",
            OF.lang.fill("Start the queue (@ lined up)", rounds.count()),
            140, 255, 160,
            function()

                if OF.util.report(rounds.start(0)) then panel.close() end
            end),
            "plays the list from the top, one round after another"))
    end

    if OF.util.asks(OF.playlist, "always") then
        local clockOn = OF.playlist.always_on()
        table.insert(rows, panel.with_key(panel.with_help(panel.gated_row(
            clockOn and "end_round" or "speedrun",
            panel.tick(clockOn, OF.lang.t("Run the lobby around the clock")),
            140, 255, 160,
            function()
                OF.util.report(OF.playlist.set_always(not clockOn, 0))
            end),
            "rounds keep coming with nobody at the menu, and wait when too few are here"),
            "rounds:clock"))
    end

    table.insert(rows, panel.with_key(panel.with_help(panel.gated_row("speedrun",

        panel.tick(rounds.looping(), OF.lang.t("Loop the queue")),
        255, 255, 255,
        function()
            OF.util.report(rounds.set_repeating(not rounds.looping()))
        end),
        "the queue starts again from the top instead of ending"),
        "rounds:loop"))

    do
        local at = 1
        for index, step in ipairs(rounds.BREATHERS) do
            if step == rounds.gap then at = index end
        end
        table.insert(rows, panel.with_slider(panel.with_help(
            panel.gated_row("speedrun",
                OF.lang.fill("Breather between rounds: @",
                    OF.lang.t(rounds.breather_name())),
                255, 255, 255,
                function()
                    OF.util.report(rounds.set_breather(rounds.next_breather()))
                end),
            "long enough to read the board, or straight on to the next one"),
            at - 1, #rounds.BREATHERS - 1, function(wanted)
                OF.util.report(rounds.set_breather(
                    rounds.BREATHERS[wanted + 1]))
            end))
    end

    if OF.util.asks(OF.playlist, "is_on") then
        table.insert(rows, panel.with_key(panel.with_help(panel.gated_row("speedrun",
            panel.tick(OF.playlist.is_on(),
                OF.lang.t("The lobby picks when this runs out")),
            255, 255, 255,
            function()

                OF.util.report(OF.playlist.set(not OF.playlist.is_on(), 0))
            end),
            "an empty queue asks the lobby what to play instead of stopping"),
            "rounds:playlist"))
    end

    if OF.util.asks(OF.modifiers, "label") then
        table.insert(rows, panel.label_row(
            OF.lang.t("Rounds are played plainly - the lobby is wearing:")
            .. " " .. OF.modifiers.label()))
    end

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("+ every mode there is"),
        200, 255, 200, function()

            OF.util.report(rounds.fill_with_everything(OF.gamemodes.arenaChoice))
        end),
        "one round of every mode the lobby can play, in the order they are listed"))

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("+ Surprise me"), 255, 220, 120, function()
            OF.util.report(rounds.add(rounds.SURPRISE,
                OF.gamemodes.arenaChoice))
        end),
        "decided the moment it starts, and never the round you just played"))

    if not OF.util.is_host() and rounds.count() > 0 then
        table.insert(rows, panel.label_row(
            OF.lang.t("The host holds the list. Next:") .. " "
            .. rounds.localize(gGlobalSyncTable.ofQueueNext or "?")))

        local coming = coming_line()
        if coming ~= nil then
            table.insert(rows, panel.label_row(coming))
        end
    end

    local catalogueAt = #rows + 1

    if OF.util.asks(OF.playlist, "always") then
        local clock = OF.playlist.always()
        table.insert(rows, panel.with_help(
            panel.header_row(OF.lang.t("Around the clock")),
            "which modes, how the next one is picked, and how many it waits for"))
        if clock.on and clock.waiting then
            table.insert(rows, panel.label_row(OF.lang.fill(
                "Waiting for players - @ of @",
                tostring(#OF.gamemodes.participants()), tostring(clock.floor))))
        end

        table.insert(rows, panel.with_right(panel.with_help(panel.gated_row(
            "speedrun", OF.lang.t("Which modes"), 255, 255, 255,
            function() OF.util.report(OF.playlist.cycle_always("pool")) end),
            "the whole catalogue, or only the list that was queued when it was switched on"),
            OF.lang.t(OF.playlist.POOL_NAMES[clock.pool])))
        table.insert(rows, panel.with_right(panel.with_help(panel.gated_row(
            "speedrun", OF.lang.t("The next one"), 255, 255, 255,
            function() OF.util.report(OF.playlist.cycle_always("pick")) end),
            "a vote between two, the next one along, a draw, or a draw by kind"),
            OF.lang.t(OF.playlist.PICK_NAMES[clock.pick])))
        table.insert(rows, panel.with_right(panel.with_help(panel.gated_row(
            "speedrun", OF.lang.t("Waits for"), 255, 255, 255,
            function() OF.util.report(OF.playlist.cycle_always("floor")) end),
            "below this many the lobby pauses, and carries on when they are back"),
            OF.lang.fill("@ players", tostring(clock.floor))))
    end

    if OF.util.asks(OF.tournament, "rows") then
        for _, r in ipairs(OF.tournament.rows(panel)) do table.insert(rows, r) end
    end

    for _, group in ipairs(OF.gamemodes.grouped()) do

        table.insert(rows, panel.with_help(
            panel.header_row(OF.lang.t(group.name)), group.help))
        for _, mode in ipairs(group.modes) do
            local key = mode.key
            table.insert(rows, panel.with_help(panel.gated_row("speedrun",
                "+ " .. OF.lang.t(mode.name),
                255, 255, 255, function()
                    OF.util.report(rounds.add(key, OF.gamemodes.arenaChoice))
                end), mode.blurb))
        end
    end

    local planAt = #rows + 1
    if #rounds.queue > 0 then

        table.insert(rows, panel.header_row(
            OF.lang.t("Lined up  (press to drop, slide to reorder)")))
        for index, entry in ipairs(rounds.queue) do
            local at = index
            table.insert(rows, panel.with_slider(panel.gated_row("speedrun",
                index .. ".  " .. rounds.describe_full(entry), 220, 220, 220,

                function() OF.util.report(rounds.remove(at)) end),
                index - 1, #rounds.queue - 1, function(wanted)
                    OF.util.report(rounds.move(at, wanted + 1))
                end))
        end

        table.insert(rows, panel.with_help(panel.gated_row("speedrun",
            OF.lang.t("Play the last one twice"), 200, 220, 255, function()
                OF.util.report(rounds.duplicate(#rounds.queue))
            end),
            "the same mode, arena and modifiers, straight after itself"))
    end

    if rounds.count() > 0 then
        table.insert(rows, panel.gated_confirm_row("speedrun", "clearqueue",
            OF.lang.t("Clear the queue"),
            255, 140, 90, function() OF.util.report(rounds.clear()) end))
    end

    if OF.util.is_host() then
        local evenings = {}
        local kept = rounds.evenings()

        for _, evening in ipairs(kept) do
            local slot = evening.slot
            table.insert(evenings, panel.with_right(panel.with_help(
                panel.gated_row("speedrun",
                    OF.lang.fill("Line up \"@\"", evening.name),
                    255, 255, 255,
                    function() OF.util.report(rounds.play(slot)) end),
                "replaces whatever is lined up now with that whole plan"),
                OF.lang.fill("@ round(s)", tostring(#evening.queue))))
        end

        if #rounds.queue > 0 and rounds.free_evening() ~= nil then
            table.insert(evenings, panel.with_help(panel.gated_row("speedrun",
                OF.lang.t("Keep this session"), 120, 255, 140, function()
                    OF.util.report(rounds.keep(rounds.suggested_name()))
                end),
                "the whole plan under a name, to line up again another time"))
        elseif #kept >= rounds.EVENINGS then
            table.insert(evenings, panel.label_row(OF.lang.fill(
                "All @ session slots are full.", tostring(rounds.EVENINGS))))
        end

        for _, evening in ipairs(kept) do
            local slot = evening.slot
            table.insert(evenings, panel.gated_row("speedrun",
                OF.lang.fill("Forget \"@\"", evening.name), 255, 140, 90,
                function() OF.util.report(rounds.forget_evening(slot)) end))
        end

        if #evenings > 0 then
            table.insert(rows, panel.header_row(OF.lang.t("Sessions you kept")))
            for _, r in ipairs(evenings) do table.insert(rows, r) end
        end
    end

    if planAt > catalogueAt then
        local moved = {}
        for at = planAt, #rows do moved[#moved + 1] = rows[at] end
        for at = #rows, planAt, -1 do rows[at] = nil end
        for at = #moved, 1, -1 do table.insert(rows, catalogueAt, moved[at]) end
    end

    table.insert(rows, panel.back_row("speedrun"))
    return rows
end

local function mode_named(line)

    if type(OF.gamemodes.LIST) ~= "table" then return nil end
    local found = nil
    for _, mode in ipairs(OF.gamemodes.LIST) do
        local name = mode.name or ""
        if name ~= "" and string.sub(line, 1, #name) == name
            and (found == nil or #name > #(found.name or "")) then
            found = mode
        end
    end
    return found
end

rounds.mode_named = mode_named

local function render()
    if gGlobalSyncTable.ofQueueOn ~= true then return end
    if OF.gamemodes.state() ~= OF.gamemodes.OFF then return end

    if OF.util.asks(OF.playlist, "always") then
        local clock = OF.playlist.always()
        if clock.on and clock.waiting then
            if OF.util.menu_has_screen() then return end
            djui_hud_set_resolution(RESOLUTION_DJUI)
            djui_hud_set_font(FONT_NORMAL)
            local here = #OF.gamemodes.participants()
            local text = here < clock.floor
                and OF.lang.fill("Waiting for players - @ of @",
                    tostring(here), tostring(clock.floor))
                or OF.lang.t("Waiting - no mode here can be played right now")
            OF.util.banner(text, 1.0, OF.util.gold().r, OF.util.gold().g,
                OF.util.gold().b, 255, { under = {
                    { text = OF.lang.t("The lobby runs around the clock and carries on by itself."),
                      scale = 0.7 } } })
            return
        end
    end

    local next = gGlobalSyncTable.ofQueueNext
    if next == nil or next == "" then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local text = OF.lang.t("Next up:") .. "  " .. rounds.localize(next)

    local under = {}

    local mode = mode_named(next)
    if mode ~= nil and mode.blurb ~= nil and mode.blurb ~= "" then
        under[#under + 1] = { text = OF.lang.t(mode.blurb), scale = 0.8 }
    end

    if OF.util.asks(OF.standings, "finale_coming")
        and OF.standings.finale_coming() then
        under[#under + 1] = {
            text = OF.lang.fill("The finale - it pays @",
                OF.lang.t(OF.standings.finale_name())),
            scale = 0.8,
            r = OF.util.gold().r, g = OF.util.gold().g, b = OF.util.gold().b,
        }
    end

    local coming = coming_line()
    if coming ~= nil then under[#under + 1] = { text = coming, scale = 0.7 } end

    if #under == 0 then under = nil end
    OF.util.banner(text, 1.0, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b,
        255, { under = under })
end

hook_event(HOOK_ON_HUD_RENDER, render)

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.is_host() then return end
    local restored = rounds.load()
    if restored > 0 then

        OF.notify.show("Round queue restored: @ lined up from last time.",
            "info", 6, tostring(restored))
    end
end)
