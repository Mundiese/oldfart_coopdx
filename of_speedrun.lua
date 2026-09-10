OF = OF or {}
OF.speedrun = OF.speedrun or {}

local speedrun = OF.speedrun

speedrun.OFF       = 0
speedrun.COUNTDOWN = 1
speedrun.ACTIVE    = 2
speedrun.RESULTS   = 3

speedrun.PACKET_ASK = "raceask"
speedrun.MODE_LEVEL    = "level"
speedrun.MODE_STAR     = "star"
speedrun.MODE_STARS    = "stars"
speedrun.STAR_TARGETS = {
    { stars = 0,   name = "0 Star",   main = true,
      blurb = "no stars at all - straight to Bowser in the Sky" },
    { stars = 1,   name = "1 Star",   main = true,
      blurb = "one star, and then the endless stairs" },
    { stars = 16,  name = "16 Star",  main = true,
      blurb = "the category most runners learn first" },
    { stars = 70,  name = "70 Star",  main = true,
      blurb = "what the endless stairs ask for without a trick" },
    { stars = 120, name = "120 Star", main = true,
      blurb = "every star in the game, and then Bowser" },
    { stars = 31,  name = "31 Star",
      blurb = "what a full run asked for before the shortcut to sixteen" },
    { stars = 50,  name = "50 Star",
      blurb = "the long way through the castle, run for its own sake" },
}

local COUNTDOWN_SECONDS = 3
local RESULTS_SECONDS   = 20

local COUNTDOWN_FRAMES = COUNTDOWN_SECONDS * 30
local PB_PREFIX = "pb_"
speedrun.timer = 0

speedrun.startedAt = nil
speedrun.finished = false
speedrun.lastPbBeaten = false

speedrun.countSaid = false

speedrun.lastBest = nil

local function star_total()
    if not OF.util.asks(OF.save, "star_count") then return "?" end
    return OF.save.star_count()
end

speedrun.raceAt = nil

local sawTheLine = false

speedrun.LATE = {
    [speedrun.MODE_LEVEL] = { join = "watch",
        why = "The race is one level and one clock, started before they "
           .. "arrived. There is no shorter way in and no line to put them "
           .. "on." },
    [speedrun.MODE_STAR] = { join = "watch",
        why = "One named star, and the whole race is how long it took to "
           .. "reach it. Somebody who walks in beside it has the shortest "
           .. "route in the room to a star everybody else ran for." },
    [speedrun.MODE_STARS] = { join = "watch",
        why = "A category is a count and then Bowser, and the count is kept "
           .. "per runner from the countdown. An arrival starts on nought "
           .. "with less of the race left to reach the target in, which is "
           .. "not a race they can win and not one they can lose fairly." },
}

function speedrun.refuses_latecomers(mode)
    local row = speedrun.LATE[mode or speedrun.mode()]
    return row == nil or row.join ~= "play"
end

local lateSaid = false

local function race_frames()
    if speedrun.raceAt == nil then return nil end
    local seconds = clock_elapsed() - speedrun.raceAt
    if seconds < 0 then seconds = 0 end
    return math.floor(seconds * 30 + 0.5)
end

local function settle_race_origin(frames)
    if speedrun.raceAt == nil then return false end
    if type(frames) ~= "number" or frames < 0 then return false end

    local said = clock_elapsed() - frames / 30
    if said >= speedrun.raceAt then return false end
    speedrun.raceAt = said
    return true
end

speedrun.settle_race_origin = settle_race_origin

local passedBest = false
local passedRecord = false

local phaseAt = nil

local lastSaid = 0

local function mark_phase()
    phaseAt = clock_elapsed()
    lastSaid = 0
end

local function phase_seconds()
    if phaseAt == nil then return 0 end
    local seconds = clock_elapsed() - phaseAt
    if seconds < 0 then return 0 end
    return seconds
end

local function state()
    return gGlobalSyncTable.ofRunState or speedrun.OFF
end

function speedrun.is_running()
    return state() ~= speedrun.OFF
end

speedrun.state = state

function speedrun.mode()
    return gGlobalSyncTable.ofRunMode or speedrun.MODE_LEVEL
end

function speedrun.format_time(frames)
    if frames == nil or frames <= 0 then return "--:--.--" end
    local totalCentis = math.floor(frames * 100 / 30)
    local minutes = math.floor(totalCentis / 6000)
    local seconds = math.floor(totalCentis / 100) % 60
    local centis = totalCentis % 100
    return string.format("%.0f:%02.0f.%02.0f", minutes, seconds, centis)
end

function speedrun.gap_text(frames)
    frames = math.abs(math.floor(tonumber(frames) or 0))
    local totalCentis = math.floor(frames * 100 / 30)
    if totalCentis < 6000 then
        return string.format("%.0f.%02.0f", math.floor(totalCentis / 100),
            totalCentis % 100)
    end
    return speedrun.format_time(frames)
end

local function slot(mode, levelNum, actNum, target)
    if mode == speedrun.MODE_STARS then
        return "s" .. tostring(math.floor(tonumber(target) or 0))
    end
    local key = tostring(levelNum)
    if actNum ~= nil then key = key .. "_" .. tostring(actNum) end
    return key
end

local function pb_key(mode, levelNum, actNum, target)
    return PB_PREFIX .. slot(mode, levelNum, actNum, target)
end

function speedrun.personal_best(levelNum, actNum, mode, target)
    local best = mod_storage_load_integer(pb_key(mode, levelNum, actNum, target), 0)
    if best <= 0 then return nil end
    return best
end

function speedrun.current_best()
    local mode = speedrun.mode()
    local actNum = nil
    if mode == speedrun.MODE_STAR then actNum = gGlobalSyncTable.ofRunAct end
    return speedrun.personal_best(gGlobalSyncTable.ofRunLevel or 0, actNum,
        mode, speedrun.star_target())
end

local function save_personal_best(frames)
    local mode = speedrun.mode()
    local actNum = nil
    if mode == speedrun.MODE_STAR then actNum = gGlobalSyncTable.ofRunAct end
    OF.util.store_integer(pb_key(mode, gGlobalSyncTable.ofRunLevel or 0, actNum,
        speedrun.star_target()), frames)
end

local REC_PREFIX = "rc_"
local RECN_PREFIX = "rcn_"
local RECORD_NAME = 16

function speedrun.record_key(mode, levelNum, actNum, target)
    return REC_PREFIX .. slot(mode, levelNum, actNum, target)
end

function speedrun.packed_record(key)
    local frames = mod_storage_load_integer(key, 0)
    if frames <= 0 then return "" end
    local name = mod_storage_load(RECN_PREFIX .. string.sub(key, #REC_PREFIX + 1), "")
    if name == "" then name = "somebody" end
    return tostring(frames) .. "|" .. name
end

function speedrun.published_record()
    local packed = gGlobalSyncTable.ofRunRecord
    if packed == nil or packed == "" then return nil end
    local frames, name = string.match(packed, "^(%d+)|(.*)$")
    if frames == nil then return nil end
    frames = tonumber(frames)
    if frames == nil or frames <= 0 then return nil end
    return { time = frames, name = OF.util.plain(name) }
end

local function keep_record(entry)
    if not OF.util.is_host() then return nil end
    if entry == nil or (entry.time or 0) <= 0 then return nil end

    local mode = speedrun.mode()
    local actNum = nil
    if mode == speedrun.MODE_STAR then actNum = gGlobalSyncTable.ofRunAct end
    local key = speedrun.record_key(mode, gGlobalSyncTable.ofRunLevel or 0,
        actNum, speedrun.star_target())

    local standing = mod_storage_load_integer(key, 0)
    if standing > 0 and entry.time >= standing then return nil end

    local name = OF.util.plain(entry.name or "")
    name = string.gsub(name, "|", "/")
    name = OF.util.short_name(name, RECORD_NAME)
    if name == "" then name = "somebody" end

    OF.util.store_integer(key, entry.time)
    OF.util.store(RECN_PREFIX .. string.sub(key, #REC_PREFIX + 1),
        OF.util.storage_value(name))
    OF.util.publish("ofRunRecord", speedrun.packed_record(key))
    return name, standing > 0 and standing or nil
end

function speedrun.is_excluded(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return false end
    return s.ofNoRace == true
end

function speedrun.set_excluded(localIndex, value)

    if localIndex ~= 0 and not OF.perms.can("speedrun") then return false end

    if localIndex == 0 then
        OF.util.publish_row(0, "ofNoRace", value)
        if value then

            OF.notify.show("You are sitting rounds out", "info")
        else
            OF.notify.show("You are joining in again", "good")
        end
        return true
    end

    local globalIndex = network_global_index_from_local(localIndex)
    if not OF.util.is_host() then
        OF.util.send_to_host({
            ofp = speedrun.PACKET_ASK,
            who = globalIndex,
            out = value and 1 or 0,
        })
        return true
    end

    if not OF.util.send_to_player(localIndex, {
        ofp = speedrun.PACKET_SET, out = value and 1 or 0,
    }) then
        return false, "They are not here to tell."
    end
    if value then
        OF.notify.send_to(globalIndex, "A moderator excused you from speedruns", "info")
    else
        OF.notify.send_to(globalIndex, "You are back in the speedruns", "info")
    end
    return true
end

local function racers()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if OF.util.can_play(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function begin(mode, levelNum, areaIndex, actNum, title, target, askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not OF.util.is_host() then
        return false, "Only the host can start a race."
    end

    local current = state()
    if current == speedrun.COUNTDOWN or current == speedrun.ACTIVE then
        return false, "A race is already going. Stop it first."
    end

    if OF.gamemodes ~= nil and (OF.gamemodes.is_running()
            or OF.gamemodes.state() == OF.gamemodes.RESULTS) then
        OF.gamemodes.stop(true)
    end

    OF.util.publish("ofRunMode", mode)
    OF.util.publish("ofRunLevel", levelNum)
    OF.util.publish("ofRunAct", actNum)

    OF.util.publish("ofRunStars", math.floor(tonumber(target) or 0))
    OF.util.publish("ofRunTitle", title)

    OF.util.publish("ofRunRecord", speedrun.packed_record(
        speedrun.record_key(mode, levelNum,
            (mode == speedrun.MODE_STAR) and actNum or nil, target)))

    OF.util.publish("ofRunElapsed", 0)
    OF.util.publish("ofRunState", speedrun.COUNTDOWN)
    mark_phase()

    if OF.util.asks(OF.lockdown, "arm_race") then OF.lockdown.arm_race() end

    OF.notify.send_all(title, "info", 5)

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("started a race: @", title))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("started a race: @", title))
    return true
end

function speedrun.is_key_stage(levelNum)
    return levelNum == LEVEL_BITDW or levelNum == LEVEL_BITFS
        or levelNum == LEVEL_BITS
end

function speedrun.is_arena(levelNum)
    return levelNum == LEVEL_BOWSER_1 or levelNum == LEVEL_BOWSER_2
        or levelNum == LEVEL_BOWSER_3
end

function speedrun.ends_here(levelNum)
    return levelNum == LEVEL_BITS or levelNum == LEVEL_BOWSER_3
end

local function my_instance_act()
    if not OF.util.asks(OF.course, "instance_act") then return nil end
    return OF.course.instance_act(network_global_index_from_local(0))
end

local COIN_STAR_ACT = 7

function speedrun.is_coin_run()
    if speedrun.mode() ~= speedrun.MODE_STAR then return false end
    if (gGlobalSyncTable.ofRunAct or 0) ~= COIN_STAR_ACT then return false end
    local course = OF.util.course_of_level(gGlobalSyncTable.ofRunLevel or 0)
    return type(course) == "number" and course >= 1 and course <= 15
end

local function alone_here()
    local me = gNetworkPlayers[0]
    if me == nil then return nil end
    if speedrun.is_arena(me.currLevelNum) then return me.currLevelNum end
    if speedrun.is_coin_run()
        and me.currLevelNum == (gGlobalSyncTable.ofRunLevel or 0) then
        return me.currLevelNum
    end
    return nil
end

speedrun.alone_here = alone_here

speedrun.my_instance_act = my_instance_act

local arenaAsked = nil

function speedrun.arena_is_shared()

    local phase = state()
    local coins = speedrun.is_coin_run()
    if phase ~= speedrun.ACTIVE
        and not (coins and phase == speedrun.COUNTDOWN) then
        return false
    end
    if not OF.util.can_play(0) then return false end

    local me = gNetworkPlayers[0]
    if me == nil or alone_here() == nil then return false end

    if not me.currAreaSyncValid then return false end

    local want = my_instance_act()
    if want == nil then return false end
    return me.currActNum ~= want
end

local function arena_frame()
    local me = gNetworkPlayers[0]
    if me == nil or alone_here() == nil then
        arenaAsked = nil
        return
    end
    if not speedrun.arena_is_shared() then return end
    if arenaAsked == me.currLevelNum then return end

    arenaAsked = me.currLevelNum

    local coins = speedrun.is_coin_run()
        and not speedrun.is_arena(me.currLevelNum)
    OF.net.warp_local(me.currLevelNum, 1, my_instance_act(), nil,
        coins and OF.lang.t("Could not get you a course of your own.")
            or OF.lang.t("Could not get you a Bowser of your own."))
    if coins then
        OF.notify.show("Your own course - a hundred coins nobody else can take",
            "info", 5)
    else
        OF.notify.show("Your own Bowser - the others are fighting theirs",
            "info", 5)
    end
end

function speedrun.level_title(levelEntry)
    if speedrun.is_key_stage(levelEntry.level) then
        return levelEntry.name .. " - whoever takes the key wins"
    end
    return levelEntry.name .. " - first star wins"
end

speedrun.LEVEL_ACTION = "runlevel"
speedrun.STAR_ACTION  = "runstar"
speedrun.STARS_ACTION = "runstars"
local take_the_castle

function speedrun.start_level(levelEntry, askerLocal)
    if not OF.util.is_host() and OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does(speedrun.LEVEL_ACTION, levelEntry.level,
            levelEntry.area, tostring(levelEntry.act or 1))
    end
    local ok, why = begin(speedrun.MODE_LEVEL, levelEntry.level, levelEntry.area,
        levelEntry.act, speedrun.level_title(levelEntry), nil, askerLocal)
    if not ok then return false, why end
    OF.net.warp_everyone(levelEntry.level, levelEntry.area, levelEntry.act)
    return true
end

function speedrun.start_star(courseNum, actNum, askerLocal)
    if not OF.util.is_host() and OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does(speedrun.STAR_ACTION, courseNum, actNum)
    end
    local levelNum = get_level_num_from_course_num(courseNum)
    local starName = get_star_name(courseNum, actNum) or ("star " .. actNum)
    local title = OF.util.course_name(courseNum) .. " - " .. starName

    local ok, why = begin(speedrun.MODE_STAR, levelNum, 1, actNum, title, nil,
        askerLocal)
    if not ok then return false, why end
    OF.net.warp_everyone(levelNum, 1, actNum)
    return true
end

function speedrun.start_stars(target, askerLocal)

    local wanted = tonumber(target)
    if wanted == nil then return false, "No such star count." end
    target = math.floor(wanted)

    if not OF.util.is_host() and OF.util.asks(OF.net, "host_does") then
        local known = false
        for _, item in ipairs(speedrun.STAR_TARGETS) do
            if item.stars == target then known = true end
        end
        if not known then return false, "No such star count." end
        return OF.net.host_does(speedrun.STARS_ACTION, target)
    end

    local entry = nil
    for _, item in ipairs(speedrun.STAR_TARGETS) do
        if item.stars == target then entry = item end
    end
    if entry == nil then return false, "No such star count." end

    local title = entry.name .. " - "
        .. ((target > 0)
            and OF.lang.fill("@ stars, then Bowser in the Sky", tostring(target))
            or OF.lang.t("no stars, then Bowser in the Sky"))

    local ok, why = begin(speedrun.MODE_STARS, LEVEL_CASTLE_GROUNDS, 1, 0,
        title, target, askerLocal)
    if not ok then return false, why end

    take_the_castle()
    OF.net.warp_everyone(LEVEL_CASTLE_GROUNDS, 1, 0)
    return true
end

function speedrun.star_target()
    return gGlobalSyncTable.ofRunStars or 0
end

function speedrun.ends_at_bowser()
    return speedrun.mode() == speedrun.MODE_STARS
end

speedrun.GOT_KEY = "ofRunGot"
function speedrun.stars_got(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    local value = row ~= nil and row[speedrun.GOT_KEY] or nil
    if type(value) ~= "number" or value < 0 then return 0 end
    return math.floor(value)
end

local counted = {}

function speedrun.forget_counted()
    counted = {}
end

local function star_name_of(obj)
    local index = OF.util.star_act_index(obj)
    if index == nil then return nil end
    local here = gNetworkPlayers[0]
    local levelNum = here ~= nil and here.currLevelNum or 0
    return tostring(levelNum) .. ":" .. tostring(index)
end

local function took_a_star(obj)
    if speedrun.mode() ~= speedrun.MODE_STARS then return end
    local name = star_name_of(obj)

    if name == nil then return end
    if counted[name] then return end
    counted[name] = true
    OF.util.publish_row(0, "ofRunGot", speedrun.stars_got(0) + 1)
end

function speedrun.count_met()
    local target = speedrun.star_target()
    if target <= 0 then return true end
    return speedrun.stars_got(0) >= target
end

speedrun.PACKET_STOP = "runoff"
local hold_contact

function speedrun.stop(quiet, askerLocal)

    if not OF.perms.can("end_round") then return false end
    if state() == speedrun.OFF then return false end

    if not OF.util.is_host() then
        if not OF.util.send_to_host({ ofp = speedrun.PACKET_STOP }) then
            return false
        end
        return true
    end

    OF.util.publish("ofRunState", speedrun.OFF)

    hold_contact(speedrun.OFF)
    if OF.util.asks(OF.lockdown, "lift_race") then OF.lockdown.lift_race() end
    if quiet then return true end

    OF.notify.send_all("Speedrun cancelled", "warn")

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, OF.lang.t("cancelled the race"))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.t("cancelled the race"))
    return true
end

local on_the_line

local firstTime = {}

function speedrun.forget_times()
    firstTime = {}
end

function speedrun.posted_time(localIndex)
    if not on_the_line(localIndex) then return 0 end
    local key = network_global_index_from_local(localIndex)
    local kept = firstTime[key]
    if kept ~= nil then return kept end
    local row = gPlayerSyncTable[localIndex]
    local time = (row ~= nil and row.ofRunTime) or 0
    if type(time) ~= "number" or time <= 0 then return 0 end
    firstTime[key] = time
    return time
end

local function keep_first_times()
    local current = state()
    if current ~= speedrun.ACTIVE and current ~= speedrun.RESULTS then return end
    for _, entry in ipairs(OF.util.connected_players()) do
        speedrun.posted_time(entry.localIndex)
    end
end

function speedrun.results()
    local list = {}

    for _, entry in ipairs(OF.util.connected_players()) do

        local time = speedrun.posted_time(entry.localIndex)
        if time > 0 then
            table.insert(list, { localIndex = entry.localIndex,
                name = entry.np.name, time = time })
        end
    end
    table.sort(list, function(a, b) return a.time < b.time end)
    return list
end

function speedrun.fastest_clock(board)
    local best = nil
    for _, entry in ipairs(board) do
        if best == nil or entry.time < best.time then best = entry end
    end
    return best
end

local startLine = nil

function on_the_line(localIndex)
    if startLine == nil then return true end
    return startLine[network_global_index_from_local(localIndex)] == true
end

speedrun.on_the_line = on_the_line

function speedrun.in_this_run()
    return sawTheLine
end

local function take_the_line()
    startLine = {}
    for _, entry in ipairs(racers()) do
        startLine[network_global_index_from_local(entry.localIndex)] = true
    end
end

local function everyone_finished()
    local waited = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if on_the_line(entry.localIndex) then

            if speedrun.posted_time(entry.localIndex) > 0 then
                waited = waited + 1
            elseif OF.util.can_play(entry.localIndex) then
                return false
            end
        end
    end

    return waited > 0
end

local function host_update()
    if not OF.util.is_host() then return end
    local current = state()
    if current == speedrun.OFF then return end

    if current == speedrun.COUNTDOWN then
        if phase_seconds() >= COUNTDOWN_SECONDS then
            OF.util.publish("ofRunState", speedrun.ACTIVE)
            mark_phase()
        end
    elseif current == speedrun.ACTIVE then

        if speedrun.raceAt ~= nil then
            local frames = math.floor((clock_elapsed() - speedrun.raceAt) * 30)
            if frames - lastSaid >= 30 then
                lastSaid = frames
                OF.util.publish("ofRunElapsed", frames)
            end
        end

        if everyone_finished() then
            OF.util.publish("ofRunState", speedrun.RESULTS)
            mark_phase()
        end
    elseif current == speedrun.RESULTS then
        if phase_seconds() >= RESULTS_SECONDS then
            OF.util.publish("ofRunState", speedrun.OFF)
            mark_phase()

            hold_contact(speedrun.OFF)
            if OF.util.asks(OF.lockdown, "lift_race") then
                OF.lockdown.lift_race()
            end
        end
    end
end

local function on_state_changed(tag, oldVal, newVal)

    if oldVal == newVal then return end

    arenaAsked = nil

    speedrun.forget_owed_room()

    if newVal == speedrun.OFF or newVal == speedrun.COUNTDOWN then
        startLine = nil
        speedrun.forget_times()
    end

    if newVal == speedrun.OFF then sawTheLine = false end

    if newVal == speedrun.COUNTDOWN then
        speedrun.timer = 0

        speedrun.startedAt = nil

        speedrun.raceAt = nil

        sawTheLine = true
        lateSaid = false
        speedrun.finished = false
        speedrun.lastPbBeaten = false
        speedrun.countSaid = false
        passedBest, passedRecord = false, false

        OF.util.publish_row(0, "ofRunTime", 0)

        OF.util.publish_row(0, "ofRunGot", 0)

        speedrun.forget_counted()
    elseif newVal == speedrun.ACTIVE then
        speedrun.timer = 0
        speedrun.startedAt = nil

        if sawTheLine then
            speedrun.raceAt = clock_elapsed()
        else
            speedrun.raceAt = nil
        end
        speedrun.finished = false
        lateSaid = false

        speedrun.countSaid = false
        passedBest, passedRecord = false, false

        if sawTheLine then take_the_line() end
        if not speedrun.is_excluded(0) then
            play_character_sound(gMarioStates[0], CHAR_SOUND_HERE_WE_GO)
        end
    elseif newVal == speedrun.RESULTS then
        local board = speedrun.results()
        if #board > 0 and board[1].localIndex == 0 then OF.celebrate.win() end
        if #board > 0 and OF.util.is_host() then
            OF.stats.record_race_win(board[1].localIndex)
            for _, entry in ipairs(board) do
                OF.stats.add(entry.localIndex, "stars", 1)
            end
            OF.stats.publish()

            local quickest = speedrun.fastest_clock(board)
            local holder, was = keep_record(quickest)
            if holder ~= nil and quickest ~= nil then
                if was ~= nil then
                    OF.notify.send_all("@ takes the lobby record - @ off it",
                        "good", 7, holder,
                        speedrun.gap_text(was - quickest.time))
                else
                    OF.notify.send_all("@ sets the first lobby record: @",
                        "good", 7, holder,
                        speedrun.format_time(quickest.time))
                end
            end
        end

    end
end

speedrun.PACKET_SET = "runset"
local function on_race_set(data)
    if data == nil or data.ofp ~= speedrun.PACKET_SET then return end
    if not OF.util.from_host(data) then return end

    local value = data.out == 1
    OF.util.publish_row(0, "ofNoRace", value)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_race_set)

local function on_race_ask(data)
    if data == nil or data.ofp ~= speedrun.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    if OF.perms.tier(asker) < OF.perms.required("speedrun") then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    local target = OF.util.local_from_global(data.who)

    local may, whyNot = OF.util.may_act_on(asker, target)
    if not may then
        OF.util.tell_asker(askerGlobal, whyNot)
        return
    end

    speedrun.set_excluded(target, data.out == 1)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_race_ask)

local function on_race_stop(data)
    if data == nil or data.ofp ~= speedrun.PACKET_STOP then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end

    if OF.perms.tier(asker) < OF.perms.required("end_round") then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    speedrun.stop(false, asker)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_race_stop)

hook_on_sync_table_change(gGlobalSyncTable, "ofRunState", 0,
    function(tag, oldVal, newVal)
        if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofRunState") then
            return
        end
        on_state_changed(tag, oldVal, newVal)
    end)

hook_on_sync_table_change(gGlobalSyncTable, "ofRunElapsed", 0,
    function(tag, oldVal, newVal)
        if OF.util.asks(OF.guard, "repair")
            and OF.guard.repair("ofRunElapsed") then
            return
        end
        if newVal == oldVal then return end
        settle_race_origin(newVal)
    end)

local finish

local owed_frame

local function tick_timer()
    local from = speedrun.raceAt
    if state() ~= speedrun.ACTIVE then
        if speedrun.startedAt == nil then speedrun.startedAt = clock_elapsed() end
        from = speedrun.startedAt
    end

    if from == nil then
        speedrun.timer = 0
        return
    end
    local seconds = clock_elapsed() - from
    if seconds < 0 then seconds = 0 end
    speedrun.timer = math.floor(seconds * 30 + 0.5)
end

local function mark_pace()
    if speedrun.finished then return end
    if not OF.util.can_play(0) then return end

    if not passedBest then
        local best = speedrun.current_best()
        if best ~= nil and speedrun.timer > best then
            passedBest = true
            OF.notify.show("Your best just went by", "warn", 4)
        end
    end

    if not passedRecord then
        local record = speedrun.published_record()
        if record ~= nil and speedrun.timer > record.time then
            passedRecord = true
            OF.notify.show("The lobby record just went by", "warn", 4)
        end
    end
end

local function local_update()
    local current = state()

    arena_frame()
    owed_frame()

    keep_first_times()

    if current == speedrun.COUNTDOWN then
        tick_timer()
    elseif current == speedrun.ACTIVE and not speedrun.finished then
        tick_timer()
        mark_pace()

        if speedrun.mode() == speedrun.MODE_STARS
            and speedrun.star_target() > 0 and not speedrun.countSaid
            and speedrun.count_met() then
            speedrun.countSaid = true
            OF.notify.show("@ stars - now Bowser in the Sky", "good", 6,
                tostring(speedrun.star_target()))
        end
    end
end

function finish(reason)
    if speedrun.finished then return end
    if speedrun.is_excluded(0) then return end

    if not sawTheLine and speedrun.refuses_latecomers() then return end

    speedrun.finished = true

    if speedrun.timer > 0 then
        OF.util.publish_row(0, "ofRunTime", speedrun.timer)
    end

    speedrun.lastBest = speedrun.current_best()

    if speedrun.timer > 0
        and (speedrun.lastBest == nil or speedrun.timer < speedrun.lastBest) then
        save_personal_best(speedrun.timer)
        speedrun.lastPbBeaten = true
    end

    if reason ~= nil then OF.notify.show(reason, "good", 6) end
    if speedrun.lastPbBeaten then

        if speedrun.lastBest ~= nil then
            OF.notify.show("New best by @", "good", 6,
                speedrun.gap_text(speedrun.lastBest - speedrun.timer))
        else
            OF.notify.show("New personal best: @", "good", 6,
                speedrun.format_time(speedrun.timer))
        end

    elseif speedrun.lastBest ~= nil then
        OF.notify.show("Finished @ off your best", "info", 6,
            speedrun.gap_text(speedrun.timer - speedrun.lastBest))
    else
        OF.notify.show("Finished in @", "good", 6,
            speedrun.format_time(speedrun.timer))
    end

    local record = speedrun.published_record()
    if record ~= nil and speedrun.timer < record.time then
        OF.notify.show("Under the lobby record by @", "good", 7,
            speedrun.gap_text(record.time - speedrun.timer))
    end
end

local function same_room(np, here)
    return np ~= nil and here ~= nil
        and np.currLevelNum == here.currLevelNum
        and np.currAreaIndex == here.currAreaIndex
        and np.currActNum == here.currActNum
end

local function others_unfinished()
    local waiting = 0
    local here = gNetworkPlayers[0]
    if here == nil then return 0 end
    for _, entry in ipairs(racers()) do
        local i = entry.localIndex
        if i ~= 0
            and (gPlayerSyncTable[i].ofRunTime or 0) <= 0
            and same_room(entry.np, here) then
            waiting = waiting + 1
        end
    end
    return waiting
end

local BOSS_STARS = {
    [LEVEL_BOB] = { [0] = true },
    [LEVEL_WF]  = { [0] = true },
    [LEVEL_BBH] = { [0] = true, [1] = true, [4] = true },
    [LEVEL_LLL] = { [0] = true, [1] = true },
    [LEVEL_SL]  = { [1] = true },
    [LEVEL_SSL] = { [3] = true },
    [LEVEL_THI] = { [5] = true },
}

local function boss_drop(obj)
    local here = gNetworkPlayers[0]
    if obj == nil or here == nil then return false end
    local stars = BOSS_STARS[here.currLevelNum]
    if stars == nil then return false end
    local index = OF.util.star_act_index(obj)
    if index == nil then return false end
    return stars[index] == true
end

function speedrun.is_boss_star(levelNum, index)
    local stars = BOSS_STARS[levelNum]
    if stars == nil or index == nil then return false end
    return stars[index] == true
end

local function took_a_coin(obj)
    if speedrun.mode() ~= speedrun.MODE_STARS then return end
    if state() ~= speedrun.ACTIVE then return end

    OF.reserve.coin_again(obj, others_unfinished())
end

local function on_interact(m, obj, interactType, interacted)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType == INTERACT_COIN then
        took_a_coin(obj)
        return
    end
    if interactType ~= INTERACT_STAR_OR_KEY then return end
    if interacted ~= true then return end
    if state() ~= speedrun.ACTIVE then return end

    local mode = speedrun.mode()

    OF.reserve.again(obj, others_unfinished(), nil, boss_drop(obj))

    if not sawTheLine and speedrun.refuses_latecomers() then
        if not lateSaid then
            lateSaid = true
            OF.notify.show("This run started before you arrived - it is not yours to finish",
                "warn", 5)
        end
        return
    end

    took_a_star(obj)

    if speedrun.ends_at_bowser() then
        if not speedrun.ends_here(gNetworkPlayers[0].currLevelNum) then return end
        if not speedrun.count_met() then
            OF.notify.show("@ - not enough stars for this category yet", "warn", 5,
                OF.lang.fill("@ of @", tostring(star_total()),
                    tostring(speedrun.star_target())))
            return
        end
        finish("Bowser is down!")
        return
    end

    if mode == speedrun.MODE_STAR then

        local wanted = (gGlobalSyncTable.ofRunAct or 1) - 1
        local got = OF.util.star_act_index(obj)

        if gNetworkPlayers[0].currLevelNum ~= (gGlobalSyncTable.ofRunLevel or 0) then
            return
        end

        if got ~= nil and got ~= wanted then
            local name = get_star_name(
                OF.util.course_of_level(gNetworkPlayers[0].currLevelNum), got + 1)

            OF.notify.show("Wrong star@ - the race is still on.", "warn", 4,
                (name ~= nil and name ~= "") and (" (" .. name .. ")") or "")
            return
        end

        finish()
        return
    end

    finish()
end

local function on_level_init(type, levelNum)
    if state() ~= speedrun.ACTIVE then return end
    if not speedrun.ends_at_bowser() then return end

    if not speedrun.count_met() then return end
    if levelNum == LEVEL_ENDING then finish("You beat the game!") end
end

local CONTACT_HOLDER = "race"
function hold_contact(current)

    if not OF.util.is_host() then return end

    local running = current == speedrun.COUNTDOWN or current == speedrun.ACTIVE
    if running then
        if OF.util.asks(OF.rules, "lend") then
            OF.rules.lend("interactions", CONTACT_HOLDER,
                PLAYER_INTERACTIONS_NONE)
        end
    elseif OF.util.asks(OF.rules, "give_back") then
        OF.rules.give_back("interactions", CONTACT_HOLDER)
    end
end

local raceSweepWas = nil

local function hold_sweep(current)

    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.arena, "arm") then return end

    local running = current == speedrun.COUNTDOWN or current == speedrun.ACTIVE
    if running then

        if raceSweepWas == nil then
            local armed = OF.arena.armed_set()
            local keys = {}
            for _, option in ipairs(OF.arena.OPTIONS) do
                if armed[option.key] == true then table.insert(keys, option.key) end
            end
            raceSweepWas = {
                clear = gGlobalSyncTable.ofArenaClear == true,
                keys = keys,
                place = gGlobalSyncTable.ofArenaPlace or "",
            }
        end

        if gGlobalSyncTable.ofArenaClear == true then OF.arena.close() end
    elseif raceSweepWas ~= nil then
        local was = raceSweepWas

        raceSweepWas = nil

        if was.clear then OF.arena.arm(true, was.keys, was.place) end
    end
end

local raceCapsWere = nil

function speedrun.caps_unlocked()
    if raceCapsWere == nil then return false end
    return true
end

local function wants_caps(current)
    if current ~= speedrun.COUNTDOWN and current ~= speedrun.ACTIVE then
        return false
    end
    return speedrun.mode() ~= speedrun.MODE_STARS
end

local function write_caps(list, value)
    local wasUndo = OF.save.before
    local ok = OF.save.set_flags(list, value)
    OF.save.before = wasUndo
    return ok
end

local function hold_caps(current)

    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.save, "set_flags") then return end

    if wants_caps(current) then
        if raceCapsWere ~= nil then return end
        local were = {}
        local wanted = {}
        for _, flag in ipairs(OF.save.CAP_FLAGS) do
            were[flag] = OF.save.has_flag(flag)
            if not were[flag] then table.insert(wanted, flag) end
        end
        raceCapsWere = were

        if #wanted > 0 then write_caps(wanted, true) end
    elseif raceCapsWere ~= nil then
        local were = raceCapsWere
        raceCapsWere = nil
        local off = {}
        for _, flag in ipairs(OF.save.CAP_FLAGS) do
            if not were[flag] then table.insert(off, flag) end
        end

        if #off > 0 then write_caps(off, false) end
    end
end

local castleWas = nil

local CASTLE_KEY = "ofRunCastle"
local strandedAsked = false

function speedrun.from_the_beginning()
    return speedrun.mode() == speedrun.MODE_STARS
end

function speedrun.castle_held()
    return castleWas
end

function take_the_castle()

    if not OF.util.is_host() then return false end
    if not OF.util.asks(OF.save, "world_take") then return false end

    if castleWas ~= nil then return false end

    local shot = OF.save.world_take()
    if shot == nil then return false end
    castleWas = shot

    if OF.util.asks(OF.save, "world_pack") then
        local packed = OF.save.world_pack(shot)
        if packed ~= nil then OF.util.store(CASTLE_KEY, packed) end
    end

    OF.notify.show("The castle is locked for this run - it goes back at the end",
        "info", 6)
    return true
end

local function hold_castle(current)
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.save, "world_give_back") then return end

    local running = (current == speedrun.COUNTDOWN or current == speedrun.ACTIVE)
        and speedrun.from_the_beginning()

    if running then return end

    if castleWas ~= nil then
        local shot = castleWas

        castleWas = nil
        local ok, why = OF.save.world_give_back(shot)
        if ok then
            OF.util.clear(CASTLE_KEY)
            OF.notify.show("The castle is back to how the lobby had it", "info", 6)
            return
        end

        OF.notify.show("The castle could not go back yet and is still held: @",
            "warn", 8, tostring(why))
        return
    end

    if strandedAsked then return end
    strandedAsked = true
    if not OF.util.asks(OF.save, "world_unpack") then return end
    local shot = OF.save.world_unpack(OF.util.stored(CASTLE_KEY, ""))
    if shot == nil then return end
    local ok, why = OF.save.world_give_back(shot)
    if ok then
        OF.util.clear(CASTLE_KEY)
        OF.notify.show("A run did not finish - the castle is back to how it was",
            "info", 8)
    else
        OF.notify.show("A run left the castle locked and it is still waiting: @",
            "warn", 8, tostring(why))
    end
end

function speedrun.retries_on_death()
    if state() ~= speedrun.ACTIVE then return false end
    if speedrun.finished then return false end
    return speedrun.mode() ~= speedrun.MODE_STARS
end

local OWED_FRAMES = 900

local OWED_SETTLED = 150
local owed = nil

local function death_destination()
    local me = gNetworkPlayers[0]
    if me == nil or me.currLevelNum == nil or me.currLevelNum == 0 then
        return nil
    end
    return { level = me.currLevelNum, area = 1, act = me.currActNum or 1,
        frames = OWED_FRAMES, settled = 0 }
end

function speedrun.owed_room()
    return owed
end

function speedrun.forget_owed_room()
    owed = nil
end

function owed_frame()
    if owed == nil then return end

    owed.frames = owed.frames - 1
    if owed.frames <= 0 then
        owed = nil
        return
    end

    local me = gNetworkPlayers[0]
    if me == nil then return end

    if not me.currAreaSyncValid then return end
    if me.currLevelNum == owed.level and me.currActNum == owed.act then

        owed.settled = owed.settled + 1
        if owed.settled >= OWED_SETTLED then owed = nil end
        return
    end

    local want = owed
    owed = nil

    local putBack = OF.net.warp_local(want.level, want.area, want.act, nil,
        "Could not put you back at the start of that level.")

    if putBack and OF.util.asks(OF.gamemodes, "give_full_health") then
        OF.gamemodes.give_full_health()
    end

    OF.notify.show("Back to the start - the attempt is yours to retake",
        "info", 5)
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not speedrun.retries_on_death() then return end

    if not OF.util.can_play(0) then return end

    owed = death_destination()
end)

local seatedByRun = false

local function best_seat()
    local counting = speedrun.mode() == speedrun.MODE_STARS
    local best, bestRank, bestNear = nil, nil, nil
    for _, globalIndex in ipairs(OF.spectate.watchable()) do
        local li = OF.util.local_from_global(globalIndex)
        if li ~= nil and li ~= 0 and on_the_line(li)
            and speedrun.posted_time(li) <= 0 and OF.util.can_play(li) then
            local rank = counting and speedrun.stars_got(li) or 0
            local near = math.huge
            if OF.util.asks(OF.gamemodes, "distance") then
                near = OF.gamemodes.distance(0, li) or math.huge
            end
            if best == nil or rank > bestRank
                or (rank == bestRank and near < bestNear)
                or (rank == bestRank and near == bestNear and li < best) then
                best, bestRank, bestNear = li, rank, near
            end
        end
    end
    if best == nil then return nil end
    return network_global_index_from_local(best)
end

function speedrun.can_watch()
    if state() ~= speedrun.ACTIVE then return false end
    if not speedrun.finished then return false end

    if not speedrun.in_this_run() then return false end

    return OF.util.asks(OF.spectate, "start")
        and OF.util.asks(OF.spectate, "watchable")
end

local function watching()
    return OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active()
end

local function watch_press()
    if OF.util.menu_has_screen() then return false end
    if not OF.input.pressed(L_JPAD) then return false end

    if watching() then

        if not seatedByRun then return false end
        OF.spectate.stop()
        seatedByRun = false
        return true
    end

    if not speedrun.can_watch() then return false end

    local seat = best_seat()
    if seat == nil then

        OF.util.report(false, "There is nobody still running to watch.")
        return true
    end
    seatedByRun = OF.spectate.start(seat) == true
    return true
end

local function hold_seat(current)
    if current == speedrun.ACTIVE or current == speedrun.RESULTS then

        if not watching() then seatedByRun = false end
        return
    end
    if not seatedByRun then return end
    seatedByRun = false
    if OF.util.asks(OF.spectate, "stop") then OF.spectate.stop() end
end

local function on_before_mario_update(m)
    if m.playerIndex ~= 0 then return end
    local current = state()

    hold_contact(current)

    hold_sweep(current)
    hold_caps(current)

    hold_castle(current)

    hold_seat(current)

    if current == speedrun.OFF then return end

    OF.input.poll(m)

    if not OF.panel.open and watch_press() then
        m.controller.buttonPressed = 0
        return
    end

    if not OF.panel.open and OF.perms.can("end_round") and OF.input.pressed(L_JPAD) then

        speedrun.stop(false, 0)
        m.controller.buttonPressed = 0
        return
    end

    if current == speedrun.COUNTDOWN and OF.util.can_play(0) then
        OF.input.hold(m)
    end
end

local function render_countdown()
    local remaining = COUNTDOWN_FRAMES - speedrun.timer
    local text = tostring(math.max(1, math.ceil(remaining / 30)))
    local scale = 3.0
    local width = OF.util.width(text, scale)
    OF.util.text(text, (djui_hud_get_screen_width() - width) * 0.5,
        djui_hud_get_screen_height() * 0.35, scale, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
end

local function pace_segments()
    local best = speedrun.current_best()
    local record = speedrun.published_record()
    local live = (state() == speedrun.ACTIVE) and not speedrun.finished
    local parts = {}

    if best ~= nil then
        local r, g, b = 200, 200, 200
        if live and speedrun.timer > best then r, g, b = 255, 130, 130 end
        table.insert(parts, { text = OF.lang.t("best") .. " "
            .. speedrun.format_time(best), r = r, g = g, b = b })
    end

    if record ~= nil then
        local r, g, b = 255, 215, 0
        if live and speedrun.timer > record.time then r, g, b = 255, 130, 130 end
        table.insert(parts, { text = "   " .. OF.lang.t("record") .. " "
            .. speedrun.format_time(record.time) .. " ", r = r, g = g, b = b })

        table.insert(parts, { text = record.name, r = r, g = g, b = b, raw = true })
    end

    if speedrun.finished and best ~= nil then
        local gap = speedrun.timer - best
        if gap < 0 then
            table.insert(parts, { text = "   -" .. speedrun.gap_text(gap),
                r = 120, g = 255, b = 120 })
        elseif gap > 0 then
            table.insert(parts, { text = "   +" .. speedrun.gap_text(gap),
                r = 255, g = 130, b = 130 })
        end
    end

    if #parts == 0 then return nil end
    return parts
end

local function render_timer()
    local text = speedrun.format_time(speedrun.timer)
    local r, g, b = 255, 255, 255
    if speedrun.finished then r, g, b = 120, 255, 120 end
    if speedrun.is_excluded(0) then
        text = OF.lang.t("not racing")
        r, g, b = 170, 170, 170
    end

    local under = {}
    local title = gGlobalSyncTable.ofRunTitle
    if title ~= nil and title ~= "" then
        table.insert(under, { text = title, scale = 0.7 })
    end
    if not speedrun.is_excluded(0) then
        local parts = pace_segments()
        if parts ~= nil then
            table.insert(under, { segments = parts, scale = 0.7 })
        end
    end
    if #under == 0 then under = nil end

    OF.util.banner(text, 1.4, r, g, b, nil, { under = under })
end

local function still_running()
    local list = {}
    if state() ~= speedrun.ACTIVE then return list end
    for _, entry in ipairs(racers()) do
        if (gPlayerSyncTable[entry.localIndex].ofRunTime or 0) <= 0 then
            table.insert(list, { name = entry.np.name })
        end
    end
    return list
end

local BOARD_ROWS = 8

local function render_board(topY)
    local board = speedrun.results()
    local waiting = still_running()
    if #board == 0 and #waiting == 0 then return end

    local scale = 0.9
    local lineHeight = OF.util.line_height(scale) + 4
    local x = djui_hud_get_screen_width() * 0.03
    local y = topY

    local shownDone = math.min(#board, BOARD_ROWS)
    local shownLeft = math.min(#waiting, BOARD_ROWS - shownDone)

    local function shown_name(name)
        return OF.util.shorten(name, OF.util.BOARD_NAME_LETTERS + 3)
    end

    local timeColumn = OF.util.width("0. ", scale)
    for _, entry in ipairs(board) do
        local w = OF.util.width("0. " .. shown_name(entry.name) .. "  ", scale)
        if w > timeColumn then timeColumn = w end
    end

    for _, entry in ipairs(waiting) do
        local w = OF.util.width("0. " .. shown_name(entry.name) .. "  ", scale)
        if w > timeColumn then timeColumn = w end
    end

    local heads = 0
    if shownDone > 0 then heads = heads + 1 end
    if shownLeft > 0 then heads = heads + 1 end

    local plateWidth = timeColumn + OF.util.width("0:00.00", scale) + 16
    local plateHeight = lineHeight * (shownDone + shownLeft + heads) + 10
    OF.util.plate(x - 8, y - 5, plateWidth, plateHeight)

    if shownDone > 0 then

        local head = OF.lang.t("Finished")
        OF.util.text(head, x, y, scale, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
        y = y + lineHeight

        for place, entry in ipairs(board) do
            if place > shownDone then break end
            local r, g, b = OF.util.name_colour()

            local lead = place .. ". "
            OF.util.text(lead, x, y, scale, r, g, b, 255)
            OF.util.text_raw(shown_name(entry.name),
                x + OF.util.width(lead, scale), y, scale, r, g, b, 255)
            OF.util.text(speedrun.format_time(entry.time), x + timeColumn, y,
                scale, 255, 255, 255, 255)
            y = y + lineHeight
        end
    end

    if shownLeft > 0 then

        local head = OF.lang.t("Still running")
        local live = race_frames()
        if live ~= nil then head = head .. "   " .. speedrun.format_time(live) end
        OF.util.text(head, x, y, scale, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
        y = y + lineHeight

        local lead = OF.util.width("0. ", scale)
        for index, entry in ipairs(waiting) do
            if index > shownLeft then break end
            OF.util.text_raw(shown_name(entry.name), x + lead, y, scale,
                170, 170, 170, 255)
            y = y + lineHeight
        end
    end
end

local HUD_EDGE = 18
local HUD_PAD_X, HUD_PAD_Y = 8, 5

local function corner_plate(x, y, width, height)
    OF.util.plate(x - HUD_PAD_X, y - HUD_PAD_Y,
        width + HUD_PAD_X * 2, height + HUD_PAD_Y * 2)
end

local function render_cancel_hint()

    if seatedByRun and watching() then return end
    local seat = speedrun.can_watch()
    if not seat and not OF.perms.can("speedrun") then return end

    local text = seat and OF.lang.t("D-pad left: watch the runners")
        or OF.lang.t("D-pad left: cancel the run")
    local scale = 0.7
    local width, height = OF.util.text_size(text, scale)
    local x = djui_hud_get_screen_width() - width - HUD_EDGE
    local y = djui_hud_get_screen_height() - height - HUD_EDGE
    corner_plate(x, y, width, height)
    OF.util.text(text, x, y, scale, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
end

local TALLY_SCALE = 1.0

local TALLY_GAP_SHARE = 0.15

local starFallback = nil

local function star_glyph()
    local globals = _G["gTextures"]
    if globals ~= nil and globals.star ~= nil then return globals.star end

    if starFallback ~= nil then
        if starFallback == false then return nil end
        return starFallback
    end
    if get_texture_info == nil then starFallback = false; return nil end
    local ok, info = pcall(get_texture_info, "texture_hud_char_star")
    if not ok or info == nil then starFallback = false; return nil end
    starFallback = info
    return info
end

local TALLY_HOLD = "speedrun"
local function hold_vanilla_counter(hide)
    OF.util.hud_hide(HUD_DISPLAY_FLAG_STAR_COUNT, TALLY_HOLD, hide and true or false)
end

speedrun.hold_vanilla_counter = hold_vanilla_counter

local function render_tally()

    local target = speedrun.star_target()
    local text = tostring(speedrun.stars_got(0)) .. "/" .. tostring(target)

    local face = OF.util.hud_face(text)
    local at = OF.util.hud_scale(face, TALLY_SCALE)
    local width, height = OF.util.in_font(face, function()
        return OF.util.text_size(text, at)
    end)

    speedrun.tallyWidth = OF.util.corner_counter(star_glyph(), text,
        OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 0, TALLY_SCALE)
end

speedrun.tallyWidth = 0

function speedrun.tally_width()
    return speedrun.tallyWidth or 0
end

local function render()
    local current = state()

    if current == speedrun.OFF or speedrun.mode() ~= speedrun.MODE_STARS then
        hold_vanilla_counter(false)

        speedrun.tallyWidth = 0
    else
        hold_vanilla_counter(true)
    end
    if current == speedrun.OFF then return end

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    if speedrun.mode() == speedrun.MODE_STARS then
        render_tally()
    else
        speedrun.tallyWidth = 0
    end

    if current == speedrun.COUNTDOWN then
        render_countdown()
    elseif current == speedrun.ACTIVE then
        render_timer()
        render_board(djui_hud_get_screen_height() * 0.22)
    elseif current == speedrun.RESULTS then

        local screen = djui_hud_get_screen_width()
        local top = djui_hud_get_screen_height() * 0.06
        local bottom = OF.util.final_headline(OF.lang.t("Final times"), top)

        local record = speedrun.published_record()
        if record ~= nil then
            local small = 0.8
            local label = OF.lang.t("Lobby record") .. "  "
                .. speedrun.format_time(record.time) .. "  "
            local parts = {
                { text = label, r = OF.util.gold().r, g = OF.util.gold().g,
                  b = OF.util.gold().b },

                { text = record.name, r = 255, g = 255, b = 255, raw = true },
            }
            local width = OF.util.segments_width(parts, small)
            OF.util.draw_segments(parts, (screen - width) * 0.5,
                bottom + 14, small, 255)
        end

        render_board(djui_hud_get_screen_height() * 0.22)
    end

    render_cancel_hint()
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.net == nil or OF.net.register_action == nil then return end

    OF.net.register_action(speedrun.LEVEL_ACTION, "speedrun",
        function(asker, level, area, act)
            if not OF.util.is_host() then return false, "Only the host." end
            local levelNum = math.floor(tonumber(level) or 0)
            if levelNum <= 0 then return false, "No such level." end
            local areaIndex = math.floor(tonumber(area) or 1)
            if areaIndex < 1 then areaIndex = 1 end
            local actNum = math.floor(tonumber(act) or 1)
            if actNum < 1 then actNum = 1 end

            return speedrun.start_level({
                level = levelNum, area = areaIndex, act = actNum,
                name = OF.util.level_name(levelNum, areaIndex),
            }, asker)
        end)

    OF.net.register_action(speedrun.STAR_ACTION, "speedrun",
        function(asker, course, act)
            if not OF.util.is_host() then return false, "Only the host." end
            local courseNum = math.floor(tonumber(course) or 0)
            local actNum = math.floor(tonumber(act) or 0)
            if courseNum < 1 or actNum < 1 or actNum > 7 then
                return false, "No such star."
            end
            return speedrun.start_star(courseNum, actNum, asker)
        end)

    OF.net.register_action(speedrun.STARS_ACTION, "speedrun",
        function(asker, target)
            if not OF.util.is_host() then return false, "Only the host." end

            return speedrun.start_stars(target, asker)
        end)
end)

hook_event(HOOK_UPDATE, host_update)
hook_event(HOOK_UPDATE, local_update)
hook_event(HOOK_ON_INTERACT, on_interact)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update)
hook_event(HOOK_ON_HUD_RENDER, render)

function speedrun.build_starcount_page(panel)
    local rows = {}

    table.insert(rows, panel.label_row(
        OF.lang.t("Every save is wiped to zero. Collect the count, then beat Bowser.")))

    local groups = {
        { name = "The five categories", main = true,
          help = "the five counts anybody who runs this game already races" },
        { name = "Also run",           main = false,
          help = "the ones a lobby asks for that are not one of the five" },
    }
    for _, group in ipairs(groups) do
        table.insert(rows, panel.with_help(
            panel.header_row(OF.lang.t(group.name)), group.help))
        for _, entry in ipairs(speedrun.STAR_TARGETS) do
            if (entry.main == true) == group.main then
                local target = entry.stars

                local best = speedrun.personal_best(0, nil,
                    speedrun.MODE_STARS, target)
                table.insert(rows, panel.with_help(panel.with_right(
                    panel.gated_confirm_row("speedrun", "stars" .. tostring(target),
                        OF.lang.t(entry.name), 255, 215, 0, function()

                            OF.util.report(speedrun.start_stars(target, 0))
                            panel.close()
                        end),
                    best ~= nil and speedrun.format_time(best) or ""),
                    entry.blurb))
            end
        end
    end

    table.insert(rows, panel.back_row())
    return rows
end

local function taking_part()
    local playing, total = 0, 0
    for _, entry in ipairs(OF.util.connected_players()) do
        total = total + 1
        if not speedrun.is_excluded(entry.localIndex) then
            playing = playing + 1
        end
    end
    return playing, total
end

local function roster_door(panel)
    local playing, total = taking_part()
    return panel.with_help(panel.with_right(
        panel.row(OF.lang.t("Who is taking part..."),
            200, 220, 255, function() panel.go("racers") end),
        OF.lang.fill("@ of @", playing, total)),
        "somebody ticked out is left where they are when a race or a round starts")
end

function speedrun.build_page(panel)
    local rows = {}

    table.insert(rows, roster_door(panel))

    if state() ~= speedrun.OFF then
        local title = gGlobalSyncTable.ofRunTitle or "a run"
        table.insert(rows, panel.label_row(OF.lang.fill("Running: @", title)))

        table.insert(rows, panel.gated_row("end_round",
            OF.lang.t("Stop the run  (or press D-pad left)"), 255, 140, 90, function()

            speedrun.stop(false, 0)
            panel.close()
        end))
    end

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.fill("Game modes (@)...", #OF.gamemodes.LIST),
        255, 255, 255, function() panel.go("gamemodes") end),
        "everyone in the lobby is warped in"))

    if OF.util.asks(OF.bingo, "build_page") then
        table.insert(rows, panel.with_help(panel.row(
            OF.util.asks(OF.bingo, "running") and OF.bingo.running()
                and OF.lang.t("Bingo - the lobby's card...")
                or OF.lang.t("Bingo - deal the lobby a card..."),
            255, 255, 255, function() panel.go("bingo") end),
            "twenty-five things to do, dealt to the whole lobby at once"))
    end

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("Speedruns")),
        "everybody in the lobby is warped in"))

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Speedrun categories..."), 255, 215, 0, function()
            panel.go("starcount")
        end),
        "0, 1, 16, 70 and 120 Star, and the two that are run beside them"))
    table.insert(rows, panel.with_help(panel.gated_row("speedrun",

        OF.lang.t("Race a level - first star wins..."), 255, 255, 255, function()
            panel.levelMode = "run"
            panel.go("groups")
        end),
        "pick any level and the first star anybody takes in it ends the race"))

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Race Bowser - whoever takes the key wins..."),
        255, 200, 90, function()
            panel.levelMode = "run"
            panel.group = OF.BOWSER_GROUP
            panel.go("levels")
        end),

        "the three stages that end on a key, and everybody gets their own Bowser"))
    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Race one named star..."), 255, 255, 255, function()
            panel.starCourse = nil
            panel.go("stars")
        end),
        "a course and one of its seven stars, with everybody after the same one"))

    if OF.util.asks(OF.together, "build_practice") then
        table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
            OF.lang.t("Practice room - drill a trick..."), 255, 255, 255,
            function() panel.go("practice") end),
            "save where you are standing, and repeat the bit you keep losing"))
    end

    return rows
end

function speedrun.build_racers_page(panel)
    local rows = {}

    local anyExcluded = false
    for _, entry in ipairs(OF.util.connected_players()) do
        if speedrun.is_excluded(entry.localIndex) then anyExcluded = true end
    end
    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        anyExcluded and OF.lang.t("Everyone takes part")
            or OF.lang.t("Nobody takes part"),
        200, 220, 255, function()
            for _, entry in ipairs(OF.util.connected_players()) do
                OF.util.report(speedrun.set_excluded(entry.localIndex, not anyExcluded))
            end
        end),
        "a ticked player is dealt into every race and every round, and warped in with it"))

    for _, entry in ipairs(OF.util.connected_players()) do
        local excluded = speedrun.is_excluded(entry.localIndex)
        local name = panel.tick(not excluded, entry.np.name)
        local r, g, b = 255, 255, 255
        if excluded then
            r, g, b = 150, 150, 150
        end
        local li = entry.localIndex

        if li == 0 then
            table.insert(rows, panel.with_help(panel.row(name, r, g, b, function()
                OF.util.report(speedrun.set_excluded(li, not excluded))
            end), "your own place in every race and every round this lobby starts"))
        else
            table.insert(rows, panel.with_help(panel.gated_row("speedrun", name,
                r, g, b, function() speedrun.set_excluded(li, not excluded) end),
                "ticked and they are dealt in and warped with the round; clear it and they sit it out"))
        end
    end

    table.insert(rows, panel.back_row("speedrun"))
    return rows
end

function speedrun.build_star_page(panel)
    local rows = {}

    if panel.starCourse == nil then
        table.insert(rows, panel.label_row(OF.lang.t("Which course?")))

        for _, course in ipairs(OF.COURSES) do
            local num = course.num
            table.insert(rows, panel.with_help(
                panel.row(course.name .. "...", 255, 255, 255,
                    function() panel.starCourse = num end),
                "opens the seven stars of this course, with your best time on each"))
        end
        table.insert(rows, panel.back_row("speedrun"))
        return rows
    end

    local courseNum = panel.starCourse
    table.insert(rows, panel.label_row(
        OF.lang.fill("@ - pick a star:", OF.util.course_name(courseNum))))

    for act = 1, 7 do
        local name = get_star_name(courseNum, act)
        if name == nil or name == "" then name = OF.lang.fill("Star @", act) end
        local best = speedrun.personal_best(get_level_num_from_course_num(courseNum), act)
        local suffix = ""
        if best ~= nil then
            suffix = "   " .. OF.lang.fill("(best @)", speedrun.format_time(best))
        end

        local why = "starts the race on this star - the clock runs until "
            .. "somebody has it"
        if act == 7 then
            why = "a hundred coins, and a copy of the course each - nobody "
                .. "can take a coin you need"
        end
        table.insert(rows, panel.with_help(panel.gated_row("speedrun",
            act .. ". " .. name .. suffix, 255, 255, 255, function()

                OF.util.report(speedrun.start_star(courseNum, act, 0))
                panel.close()
            end), why))
    end

    table.insert(rows, panel.with_help(panel.row(OF.lang.t("< Other course"),
        180, 180, 180, function()
            panel.starCourse = nil
        end),
        "back to the fifteen courses without leaving the page"))
    table.insert(rows, panel.back_row("speedrun"))
    return rows
end
