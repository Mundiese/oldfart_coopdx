OF = OF or {}

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function() return { E_MODEL_KOOPA_WITH_SHELL } end)
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
      blurb = "the one star is Bowser's sub in Dire, Dire Docks - every star door skipped" },
    { stars = 16,  name = "16 Star",  main = true,
      blurb = "the classic any% - the MIPS clip, and a BLJ up the endless stairs" },
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

speedrun.GRANTS = { speedo = 1 }

function speedrun.grants(key)
    local rung = speedrun.GRANTS[key]
    if rung == nil then return nil end
    local current = state()
    if current ~= speedrun.COUNTDOWN and current ~= speedrun.ACTIVE
        and current ~= speedrun.RESULTS then
        return nil
    end
    if speedrun.run_excluded(0) then return nil end
    if not speedrun.in_this_run() then return nil end
    return rung
end

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
    local tag = speedrun.opts_tag()
    if mode == speedrun.MODE_STARS then
        return "s" .. tostring(math.floor(tonumber(target) or 0)) .. tag
    end
    local key = tostring(levelNum)
    if actNum ~= nil then key = key .. "_" .. tostring(actNum) end
    return key .. tag
end
speedrun.slot = slot

local function pb_key(mode, levelNum, actNum, target)
    return slot(mode, levelNum, actNum, target)
end

speedrun.sessionBests = speedrun.sessionBests or {}

function speedrun.personal_best(levelNum, actNum, mode, target)
    local best = speedrun.sessionBests[pb_key(mode, levelNum, actNum, target)]
    if best == nil or best <= 0 then return nil end
    return best
end

function speedrun.current_best()
    local mode = speedrun.mode()
    local actNum = nil
    if mode == speedrun.MODE_STAR then actNum = gGlobalSyncTable.ofRunAct end
    return speedrun.personal_best(gGlobalSyncTable.ofRunLevel or 0, actNum,
        mode, speedrun.star_target())
end

function speedrun.current_slot()
    local mode = speedrun.mode()
    local actNum = nil
    if mode == speedrun.MODE_STAR then actNum = gGlobalSyncTable.ofRunAct end
    return slot(mode, gGlobalSyncTable.ofRunLevel or 0, actNum, speedrun.star_target())
end

local function save_personal_best(frames)
    local mode = speedrun.mode()
    local actNum = nil
    if mode == speedrun.MODE_STAR then actNum = gGlobalSyncTable.ofRunAct end
    frames = math.floor(tonumber(frames) or 0)
    if frames <= 0 then return end
    speedrun.sessionBests[pb_key(mode, gGlobalSyncTable.ofRunLevel or 0, actNum,
        speedrun.star_target())] = frames
end

local RECORD_NAME = 16

function speedrun.record_key(mode, levelNum, actNum, target)
    return slot(mode, levelNum, actNum, target)
end

speedrun.sessionRecords = speedrun.sessionRecords or {}

function speedrun.packed_record(key)
    local held = speedrun.sessionRecords[key]
    if held == nil or (held.time or 0) <= 0 then return "" end
    local name = held.name or ""
    if name == "" then name = "somebody" end
    return tostring(held.time) .. "|" .. name
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

    local held = speedrun.sessionRecords[key]
    local standing = held ~= nil and (held.time or 0) or 0
    if standing > 0 and entry.time >= standing then return nil end

    local name = OF.util.plain(entry.name or "")
    name = string.gsub(name, "|", "/")
    name = OF.util.short_name(name, RECORD_NAME)
    if name == "" then name = "somebody" end

    speedrun.sessionRecords[key] = { time = math.floor(entry.time),
        name = OF.util.storage_value(name) }
    OF.util.publish("ofRunRecord", speedrun.packed_record(key))
    return name, standing > 0 and standing or nil
end

speedrun.KIND_MODE = "mode"
speedrun.KIND_RUN = "run"
function speedrun.kind_now()
    local modes = OF.gamemodes
    if modes ~= nil and type(modes.state) == "function"
        and modes.state() ~= modes.OFF then
        return speedrun.KIND_MODE
    end
    if state() ~= speedrun.OFF then return speedrun.KIND_RUN end
    return speedrun.KIND_MODE
end

function speedrun.row_key(kind)
    if kind == speedrun.KIND_RUN then return "ofNoRun" end
    return "ofNoRace"
end

function speedrun.chose_out(localIndex, kind)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return false end
    if kind == nil then return s.ofNoRace == true or s.ofNoRun == true end
    return s[speedrun.row_key(kind)] == true
end

function speedrun.muted_out(localIndex)
    return OF.util.asks(OF.perms, "is_muted_rank")
        and OF.perms.is_muted_rank(localIndex) == true
end

function speedrun.is_excluded(localIndex, kind)
    if gPlayerSyncTable[localIndex] == nil then return false end
    return speedrun.chose_out(localIndex, kind or speedrun.kind_now())
        or speedrun.muted_out(localIndex)
end

function speedrun.run_excluded(localIndex)
    return speedrun.is_excluded(localIndex, speedrun.KIND_RUN)
end

speedrun.MUTED_WHY = "Muted players do not take part in rounds or runs."
speedrun.TOLD = {
    mode = { selfOut = "You are sitting game modes out", selfIn = "You are joining game modes again",
             otherOut = "A moderator excused you from game modes", otherIn = "You are back in the game modes" },
    run  = { selfOut = "You are sitting speedruns out", selfIn = "You are joining speedruns again",
             otherOut = "A moderator excused you from speedruns", otherIn = "You are back in the speedruns" },
    both = { selfOut = "You are sitting game modes and speedruns out", selfIn = "You are joining game modes and speedruns again",
             otherOut = "A moderator excused you from game modes and speedruns", otherIn = "You are back in the game modes and speedruns" },
}

function speedrun.keys_of(kind)
    if kind == speedrun.KIND_MODE or kind == speedrun.KIND_RUN then
        return { speedrun.row_key(kind) }
    end
    return { "ofNoRace", "ofNoRun" }
end

local function write_tick(key, value)
    if key == "ofNoRun" then
        OF.util.publish_row(0, "ofNoRun", value)
    else
        OF.util.publish_row(0, "ofNoRace", value)
    end
end

local function told(kind)
    return speedrun.TOLD[kind] or speedrun.TOLD.both
end

local function kind_code(kind)
    if kind == speedrun.KIND_MODE then return "m" end
    if kind == speedrun.KIND_RUN then return "r" end
    return nil
end
function speedrun.kind_of_code(code)
    if code == "m" then return speedrun.KIND_MODE end
    if code == "r" then return speedrun.KIND_RUN end
    return nil
end

function speedrun.set_excluded(localIndex, value, kind)

    if localIndex ~= 0 and not OF.perms.can("speedrun") then return false end

    if speedrun.muted_out(localIndex) then return false, speedrun.MUTED_WHY end

    if localIndex == 0 then
        for _, key in ipairs(speedrun.keys_of(kind)) do
            write_tick(key, value)
        end
        if value then
            OF.notify.show(told(kind).selfOut, "info")
        else
            OF.notify.show(told(kind).selfIn, "good")
        end
        return true
    end

    local globalIndex = network_global_index_from_local(localIndex)
    if not OF.util.is_host() then
        OF.util.send_to_host({
            ofp = speedrun.PACKET_ASK,
            who = globalIndex,
            out = value and 1 or 0,
            k = kind_code(kind),
        })
        return true
    end

    if not OF.util.send_to_player(localIndex, {
        ofp = speedrun.PACKET_SET, out = value and 1 or 0, k = kind_code(kind),
    }) then
        return false, "They are not here to tell."
    end
    if value then
        OF.notify.send_to(globalIndex, told(kind).otherOut, "info")
    else
        OF.notify.send_to(globalIndex, told(kind).otherIn, "info")
    end
    return true
end

local function racers()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if OF.util.can_play(entry.localIndex, speedrun.KIND_RUN) then
            table.insert(list, entry)
        end
    end
    return list
end

function speedrun.races_on(levelNum)
    if type(levelNum) ~= "number" then return false end
    for _, entry in ipairs(OF.LEVELS or {}) do
        if entry.level == levelNum and entry.custom ~= true then return true end
    end
    return false
end

speedrun.KEY_ONLY_LEVELS = { [LEVEL_BOWSER_1 or -1] = true, [LEVEL_BOWSER_2 or -2] = true,
                             [LEVEL_BOWSER_3 or -3] = true }
function speedrun.door_offers(levelNum, kind)
    if not speedrun.races_on(levelNum) then return false end
    if kind == "star" and speedrun.KEY_ONLY_LEVELS[levelNum] then return false end
    return true
end

local function begin(mode, levelNum, areaIndex, actNum, title, target, askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    if not speedrun.races_on(levelNum) then
        return false, "Races are run on the game's own levels."
    end

    if not OF.util.is_host() then
        return false, "Only the host can start a race."
    end

    local current = state()
    if current == speedrun.COUNTDOWN or current == speedrun.ACTIVE then
        return false, "A race is already going. Stop it first."
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

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("started a race: @", title))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("started a race: @", title))

    if OF.util.asks(OF.net, "pick_lead") then
        OF.net.set_round_lead(OF.net.pick_lead(askerLocal))
    end
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

local redStar = nil

local RED_LOOKS = 8
local redLookedAt, redLooks = nil, 0

local RED_STOCK_FRAMES = 300
local redStocking = 0

function speedrun.forget_red_coin_star()
    redStar = nil
    redStocking = 0
    redLookedAt, redLooks = nil, 0
end

function speedrun.is_red_coin_run()
    return redStar ~= nil
end

function speedrun.red_coin_star()
    return redStar
end

local function watch_red_star()
    local level = gGlobalSyncTable.ofRunLevel or 0
    local act = gGlobalSyncTable.ofRunAct or 0
    if redStar ~= nil then
        if redStar.level ~= level or redStar.act ~= act then
            speedrun.forget_red_coin_star()
        end
        return
    end

    local phase = state()
    if phase ~= speedrun.COUNTDOWN and phase ~= speedrun.ACTIVE then return end
    local mode = speedrun.mode()

    if mode ~= speedrun.MODE_STAR and mode ~= speedrun.MODE_LEVEL then return end

    if act < 1 or act > 6 then return end

    local me = gNetworkPlayers[0]
    if me == nil or me.currLevelNum ~= level then return end

    if me.currActNum ~= act and not (OF.util.asks(OF.roundact, "plays_as")
        and OF.roundact.plays_as(level, me.currActNum, act)) then
        return
    end

    local room = tostring(level) .. ":" .. tostring(me.currAreaIndex)
        .. ":" .. tostring(act)
    if redLookedAt ~= room then redLookedAt, redLooks = room, 0 end
    if redLooks >= RED_LOOKS then return end
    redLooks = redLooks + 1

    local object = OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvHiddenRedCoinStar)
    local depth = 0
    while object ~= nil and depth < 64 do
        depth = depth + 1

        if (OF.util.star_act_index(object) or -1) + 1 == act then
            redStar = {
                level = level, act = act, area = me.currAreaIndex,
                x = object.oPosX, y = object.oPosY, z = object.oPosZ,
                params = object.oBehParams or 0,
            }
            return
        end
        object = OF.util.optional("obj_get_next_with_same_behavior_id", nil,
            object)
    end
end

local function adopt_red_coins(star)
    local coin = OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvRedCoin)
    local taken = 0
    while coin ~= nil and taken < 64 do
        coin.parentObj = star
        taken = taken + 1
        coin = OF.util.optional("obj_get_next_with_same_behavior_id", nil, coin)
    end
    return taken
end

function speedrun.red_coin_tick()
    if redStocking <= 0 then return nil end
    if redStar == nil then return nil end

    local phase = state()
    if phase ~= speedrun.COUNTDOWN and phase ~= speedrun.ACTIVE then return nil end
    if not OF.util.can_play(0, speedrun.KIND_RUN) then return nil end

    local me = gNetworkPlayers[0]
    if me == nil or me.currLevelNum ~= redStar.level then return nil end

    if me.currAreaIndex ~= redStar.area then return nil end
    local mine = my_instance_act()

    if mine == nil or me.currActNum ~= mine then return nil end

    redStocking = redStocking - 1

    if OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvHiddenRedCoinStar) ~= nil then
        redStocking = 0
        return nil
    end

    local star = OF.util.optional("spawn_sync_object", nil,
        id_bhvHiddenRedCoinStar, E_MODEL_NONE,
        redStar.x, redStar.y, redStar.z,
        function(o)

            o.oBehParams = redStar.params
        end)
    if star == nil then

        if redStocking <= 0 then

            speedrun.refuse_copy(redStar.level)
            OF.net.warp_local(redStar.level, redStar.area, redStar.act, nil,
                OF.lang.t("Could not get you red coins of your own."))

            speedrun.note("The course stays shared - no red coins of your own",
                "warn")
            return false
        end
        return nil
    end

    redStocking = 0
    return adopt_red_coins(star)
end

local KOOPA_LOOKS = 8
local koopaLookedAt, koopaLooks = nil, 0

local koopaRacer = nil

local KOOPA_STOCK_FRAMES = 300
local koopaStocking = 0

local KOOPA_RACER_BP = KOOPA_BP_KOOPA_THE_QUICK_BASE or 2

function speedrun.forget_koopa_racer()
    koopaRacer = nil
    koopaStocking = 0
    koopaLookedAt, koopaLooks = nil, 0
end

function speedrun.is_koopa_run()
    return koopaRacer ~= nil
end

function speedrun.koopa_racer()
    return koopaRacer
end

local function racer_standing()
    local object = OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvKoopa)
    local depth = 0
    while object ~= nil and depth < 64 do
        depth = depth + 1
        local movement = object.oKoopaMovementType
        if type(movement) == "number" and movement >= KOOPA_RACER_BP then
            return object
        end
        object = OF.util.optional("obj_get_next_with_same_behavior_id", nil,
            object)
    end
    return nil
end

local function watch_koopa_racer()
    local level = gGlobalSyncTable.ofRunLevel or 0
    local act = gGlobalSyncTable.ofRunAct or 0
    if koopaRacer ~= nil then
        if koopaRacer.level ~= level or koopaRacer.act ~= act then
            speedrun.forget_koopa_racer()
        end
        return
    end

    local phase = state()
    if phase ~= speedrun.COUNTDOWN and phase ~= speedrun.ACTIVE then return end
    local mode = speedrun.mode()

    if mode ~= speedrun.MODE_STAR and mode ~= speedrun.MODE_LEVEL then return end

    if act < 1 or act > 6 then return end

    local me = gNetworkPlayers[0]
    if me == nil or me.currLevelNum ~= level then return end

    if me.currActNum ~= act and not (OF.util.asks(OF.roundact, "plays_as")
        and OF.roundact.plays_as(level, me.currActNum, act)) then
        return
    end

    local room = tostring(level) .. ":" .. tostring(me.currAreaIndex)
        .. ":" .. tostring(act)
    if koopaLookedAt ~= room then koopaLookedAt, koopaLooks = room, 0 end
    if koopaLooks >= KOOPA_LOOKS then return end
    koopaLooks = koopaLooks + 1

    local racer = racer_standing()
    if racer == nil then return end

    local endpoint = OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvKoopaRaceEndpoint)
    if endpoint == nil then return end

    koopaRacer = {
        level = level, act = act, area = me.currAreaIndex,
        x = racer.oPosX, y = racer.oPosY, z = racer.oPosZ,
        params = racer.oBehParams or 0,
        params2 = racer.oBehParams2ndByte or 0,
        movement = racer.oKoopaMovementType or KOOPA_RACER_BP,
        flagX = endpoint.oPosX, flagY = endpoint.oPosY, flagZ = endpoint.oPosZ,
        flagParams = endpoint.oBehParams or 0,
        flagParams2 = endpoint.oBehParams2ndByte or 0,
    }
end

function speedrun.koopa_tick()
    if koopaStocking <= 0 then return nil end
    if koopaRacer == nil then return nil end

    local phase = state()
    if phase ~= speedrun.COUNTDOWN and phase ~= speedrun.ACTIVE then return nil end
    if not OF.util.can_play(0, speedrun.KIND_RUN) then return nil end

    local me = gNetworkPlayers[0]
    if me == nil or me.currLevelNum ~= koopaRacer.level then return nil end

    if me.currAreaIndex ~= koopaRacer.area then return nil end
    local mine = my_instance_act()

    if mine == nil or me.currActNum ~= mine then return nil end

    koopaStocking = koopaStocking - 1

    if racer_standing() ~= nil then
        koopaStocking = 0
        return nil
    end

    local endpointId = id_bhvKoopaRaceEndpoint
    if endpointId == nil then

        koopaStocking = 0
        return false
    end
    local flag = OF.util.optional("obj_get_first_with_behavior_id", nil,
        endpointId)
    if flag == nil then
        flag = OF.util.optional("spawn_sync_object", nil,
            endpointId, E_MODEL_NONE,
            koopaRacer.flagX, koopaRacer.flagY, koopaRacer.flagZ,
            function(o)

                o.oBehParams = koopaRacer.flagParams
                o.oBehParams2ndByte = koopaRacer.flagParams2
            end)
    end
    local racer = nil
    if flag ~= nil then
        racer = OF.slots.spawn_sync(
            id_bhvKoopa, E_MODEL_KOOPA_WITH_SHELL,
            koopaRacer.x, koopaRacer.y, koopaRacer.z,
            function(o)
                o.oBehParams = koopaRacer.params
                o.oBehParams2ndByte = koopaRacer.params2
                o.oKoopaMovementType = koopaRacer.movement
            end, true)
    end
    if racer == nil then

        if koopaStocking <= 0 then
            speedrun.refuse_copy(koopaRacer.level)
            OF.net.warp_local(koopaRacer.level, koopaRacer.area,
                koopaRacer.act, nil,
                OF.lang.t("Could not get you a Koopa of your own."))

            speedrun.note("The course stays shared - no Koopa of your own",
                "warn")
            return false
        end
        return nil
    end

    koopaStocking = 0
    return racer
end

speedrun.ACT_WRAP = 32

function speedrun.is_first_star_run()
    if speedrun.mode() ~= speedrun.MODE_LEVEL then return false end
    local level = gGlobalSyncTable.ofRunLevel or 0
    if speedrun.is_key_stage(level) then return false end
    local course = OF.util.course_of_level(level)
    return type(course) == "number" and course >= 1 and course <= 15
end

speedrun.ACT_WIRE_MAX = 255
speedrun.CREDITS_ACT = 99

speedrun.FIRST_PRIVATE_ACT = 7

function speedrun.copy_families(base)
    local list = {}
    local k = 1
    while base + speedrun.ACT_WRAP * k <= speedrun.ACT_WIRE_MAX do

        if base + speedrun.ACT_WRAP * k ~= speedrun.CREDITS_ACT
            and k ~= (OF.roundact and OF.roundact.ROUND_FAMILY or 7) then
            list[#list + 1] = k
        end
        k = k + 1
    end
    return list
end

function speedrun.wrapped_act(base, globalIndex)
    base = math.floor(tonumber(base) or 1)
    if base < 1 or base >= speedrun.ACT_WRAP then base = 1 end
    local index = math.floor(tonumber(globalIndex) or 0)
    if index < 0 then index = 0 end
    local families = speedrun.copy_families(base)
    return base + speedrun.ACT_WRAP * families[(index % #families) + 1]
end

local function content_bound(level)
    if OF.util.asks(OF.roundact, "content_bound") then
        return OF.roundact.content_bound(level) == true
    end
    local course = OF.util.course_of_level(level)
    return type(course) == "number" and course >= 1 and course <= 15
end

local function is_hub(level)
    if OF.util.asks(OF.roundact, "is_hub") then return OF.roundact.is_hub(level) end
    return level == LEVEL_CASTLE or level == LEVEL_CASTLE_GROUNDS
        or level == LEVEL_CASTLE_COURTYARD
end

speedrun.SHARED_MISSIONS = {

    [LEVEL_WF or -1] = {
        [2] = "the tower and its cannon have no model a Lua spawn can draw",
        [3] = "the tower and its cannon have no model a Lua spawn can draw",
        [4] = "the tower and its cannon have no model a Lua spawn can draw",
        [5] = "the tower and its cannon have no model a Lua spawn can draw",
        [6] = "the tower and its cannon have no model a Lua spawn can draw",
    },

    [LEVEL_CCM or -1] = {
        [5] = "the snowman's body has no model a Lua spawn can draw",
    },
}

function speedrun.mission_shared(level, act)
    local byLevel = speedrun.SHARED_MISSIONS[level]
    if byLevel == nil then return nil end
    return byLevel[act]
end

local missionOf = {}

function speedrun.mission_act(level, act)
    local mode = speedrun.mode()
    if level == (gGlobalSyncTable.ofRunLevel or 0)
        and (mode == speedrun.MODE_STAR or mode == speedrun.MODE_LEVEL) then
        local raced = math.floor(tonumber(gGlobalSyncTable.ofRunAct) or 1)
        if raced < 1 then raced = 1 end
        return raced
    end
    local here = math.floor(tonumber(act) or 0)
    if here >= 1 and here <= 6 then return here end
    if here > speedrun.ACT_WRAP and here <= speedrun.ACT_WIRE_MAX then
        local wrapped = here % speedrun.ACT_WRAP
        if wrapped >= 1 and wrapped <= 6 then return wrapped end
    end
    return missionOf[level] or 1
end

function speedrun.note_mission()
    local me = gNetworkPlayers[0]
    if me == nil or not content_bound(me.currLevelNum) then return end
    local act = me.currActNum
    if type(act) == "number" and act >= 1 and act <= 6 then
        missionOf[me.currLevelNum] = act
    end
end

function speedrun.forget_missions()
    missionOf = {}
end

local refusedCopies = {}
function speedrun.refuse_copy(level)
    if level ~= nil then refusedCopies[level] = true end
end
function speedrun.forget_refused_copies()
    refusedCopies = {}
end

function speedrun.copy_act(level, act, globalIndex)
    if level == nil or level == 0 or is_hub(level) then return nil end
    if refusedCopies[level] then return nil end
    local phase = state()
    if phase ~= speedrun.COUNTDOWN and phase ~= speedrun.ACTIVE then return nil end
    local index = math.floor(tonumber(globalIndex) or 0)
    local instance = OF.util.asks(OF.course, "instance_act")
        and OF.course.instance_act(index) or nil

    if speedrun.is_arena(level) then return instance end
    if not content_bound(level) then return instance end

    local mission = speedrun.mission_act(level, act)
    if speedrun.mission_shared(level, mission) ~= nil then
        return speedrun.wrapped_act(mission, index)
    end
    return instance
end

local function races_here()
    if not OF.util.can_play(0, speedrun.KIND_RUN) then return false end
    if OF.util.asks(OF.roundact, "plays") then return OF.roundact.plays(0) == true end
    return true
end
speedrun.races_here = races_here

local function alone_here()
    local me = gNetworkPlayers[0]
    if me == nil then return nil end
    local phase = state()

    if phase == speedrun.COUNTDOWN
        and me.currLevelNum ~= (gGlobalSyncTable.ofRunLevel or 0) then
        return nil
    end
    if speedrun.copy_act(me.currLevelNum, me.currActNum,
        network_global_index_from_local(0)) == nil then
        return nil
    end
    return me.currLevelNum
end

speedrun.alone_here = alone_here

speedrun.my_instance_act = my_instance_act

local function owed_act()
    local me = gNetworkPlayers[0]
    if me == nil then return nil end
    return speedrun.copy_act(me.currLevelNum, me.currActNum,
        network_global_index_from_local(0))
end
speedrun.owed_act = owed_act

function speedrun.mission_rows(level, act, area)
    local out = {}
    local byLevel = OF.ACT_OBJECTS ~= nil and OF.ACT_OBJECTS[level] or nil
    if byLevel == nil then return out end
    for _, row in ipairs(byLevel) do
        local holds = false
        for _, a in ipairs(row.acts or {}) do
            if a == act then holds = true break end
        end
        if holds and row.area == (area or 1) and row.lacks == nil then
            local bhv = _G["id_" .. tostring(row.bhv)]
            local model = _G[tostring(row.model)]
            if bhv ~= nil and model ~= nil then
                out[#out + 1] = {
                    bhv = bhv, model = model, name = row.bhv,
                    x = row.x, y = row.y, z = row.z,
                    pitch = row.pitch, yaw = row.yaw, roll = row.roll,
                    params = row.params or 0, src = row.src,
                }
            end
        end
    end
    return out
end

local ROW_NEAR = 150

local function near(object, prefix, thing)
    return math.abs((object[prefix .. "X"] or 0) - thing.x) <= ROW_NEAR
        and math.abs((object[prefix .. "Y"] or 0) - thing.y) <= ROW_NEAR
        and math.abs((object[prefix .. "Z"] or 0) - thing.z) <= ROW_NEAR
end

function speedrun.row_standing(thing)
    local object = OF.util.optional("obj_get_first_with_behavior_id", nil, thing.bhv)
    local depth = 0
    while object ~= nil and depth < 64 do
        depth = depth + 1
        if (object.oBehParams or 0) == thing.params
            and (near(object, "oHome", thing) or near(object, "oPos", thing)) then
            return object
        end
        object = OF.util.optional("obj_get_next_with_same_behavior_id", nil, object)
    end
    return nil
end

local MISSION_STOCK_FRAMES = 300
local missionStocking, missionRoom = 0, nil

function speedrun.arm_mission_stock()
    missionStocking = MISSION_STOCK_FRAMES
end

function speedrun.mission_stock_tick()
    local me = gNetworkPlayers[0]
    if me == nil then return nil end
    local room = tostring(me.currLevelNum) .. ":" .. tostring(me.currAreaIndex)
        .. ":" .. tostring(me.currActNum)
    if room ~= missionRoom then
        missionRoom = room
        missionStocking = MISSION_STOCK_FRAMES
    end
    if missionStocking <= 0 then return nil end

    local phase = state()
    if phase ~= speedrun.COUNTDOWN and phase ~= speedrun.ACTIVE then return nil end
    if not races_here() then return nil end
    local level = me.currLevelNum
    if not content_bound(level) then missionStocking = 0 return nil end
    local mine = my_instance_act()
    if mine == nil or me.currActNum ~= mine then return nil end
    local mission = speedrun.mission_act(level, me.currActNum)
    if speedrun.mission_shared(level, mission) ~= nil then
        missionStocking = 0
        return nil
    end

    missionStocking = missionStocking - 1
    local owed = {}
    for _, thing in ipairs(speedrun.mission_rows(level, mission, me.currAreaIndex)) do
        if speedrun.row_standing(thing) == nil then owed[#owed + 1] = thing end
    end
    if #owed == 0 then
        missionStocking = 0
        return 0
    end

    local placed = {}
    local first = OF.util.asks(OF.roundact, "stock_one")
        and OF.roundact.stock_one(owed[1]) or nil
    if first == nil then

        if missionStocking <= 0 then
            speedrun.refuse_copy(level)
            OF.net.warp_local(level, me.currAreaIndex or 1, mission, nil,
                OF.lang.t("Could not get you a copy of this level of your own."))
            speedrun.note("The course stays shared - no copy of your own",
                "warn")
            return false
        end
        return nil
    end
    placed[1] = { thing = owed[1], object = first }
    for index = 2, #owed do
        placed[#placed + 1] = { thing = owed[index],
            object = OF.roundact.stock_one(owed[index]) }
    end

    for _, entry in ipairs(placed) do
        if entry.object ~= nil and entry.thing.name == "bhvHiddenRedCoinStar" then
            adopt_red_coins(entry.object)
        end
    end
    missionStocking = 0
    return #placed
end

function speedrun.whirlpool_frame()
    local me = gNetworkPlayers[0]
    if me == nil or OF.ACT_WHIRLPOOLS == nil then return false end
    local list = OF.ACT_WHIRLPOOLS[me.currLevelNum]
    if list == nil then return false end
    local act = me.currActNum
    if type(act) ~= "number" or act < speedrun.FIRST_PRIVATE_ACT
        or act == speedrun.CREDITS_ACT then
        return false
    end
    local phase = state()
    if phase ~= speedrun.COUNTDOWN and phase ~= speedrun.ACTIVE then return false end
    local mission = speedrun.mission_act(me.currLevelNum, act)
    local m = gMarioStates[0]
    local area = m ~= nil and m.area or nil
    if area == nil or area.whirlpools == nil then return false end
    local calmed = false
    for _, w in ipairs(list) do
        if w.area == me.currAreaIndex and mission < (w.fromAct or 2) then
            local pool = area.whirlpools[w.index]
            if pool ~= nil and pool.strength ~= 0 then
                pool.strength = 0
                calmed = true
            end
        end
    end
    return calmed
end

function speedrun.snowman_frame()
    local me = gNetworkPlayers[0]
    if me == nil or me.currLevelNum ~= LEVEL_CCM then return false end
    local act = me.currActNum
    if type(act) ~= "number" or act < speedrun.FIRST_PRIVATE_ACT
        or act == speedrun.CREDITS_ACT then
        return false
    end
    if OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvSnowmansBottom) == nil then
        return false
    end
    local whole = OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvBigSnowmanWhole)
    if whole == nil then return false end
    OF.util.optional("obj_mark_for_deletion", nil, whole)
    local head = OF.util.optional("obj_get_first_with_behavior_id", nil,
        id_bhvSnowmansHead)
    local placed = nil
    for _, row in ipairs((OF.ACT_OBJECTS or {})[LEVEL_CCM] or {}) do
        if row.bhv == "bhvSnowmansHead" then placed = row break end
    end
    if head ~= nil and placed ~= nil then
        head.oPosX, head.oPosY, head.oPosZ = placed.x, placed.y, placed.z
        head.oAction = 0
    end
    return true
end

local arenaAsked = nil

function speedrun.arena_is_shared()

    local phase = state()

    if phase ~= speedrun.ACTIVE and phase ~= speedrun.COUNTDOWN then
        return false
    end
    if not races_here() then return false end

    if speedrun.owed_room() ~= nil then return false end

    local me = gNetworkPlayers[0]
    if me == nil or alone_here() == nil then return false end

    if not me.currAreaSyncValid then return false end

    local want = owed_act()
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

    local asking = tostring(me.currLevelNum) .. ":" .. tostring(owed_act())
    if arenaAsked == asking then return end

    arenaAsked = asking

    local arena = speedrun.is_arena(me.currLevelNum)

    local inRace = me.currLevelNum == (gGlobalSyncTable.ofRunLevel or 0)
    local first = speedrun.is_first_star_run() and not arena and inRace
    local coins = speedrun.is_coin_run() and not arena and inRace
    local reds = speedrun.is_red_coin_run() and not arena and not coins and inRace
    local ktq = speedrun.is_koopa_run() and not arena and not coins
        and not reds and inRace
    local general = not arena and not first and not coins and not reds and not ktq
    local refusal = OF.lang.t("Could not get you a Bowser of your own.")
    if general then
        refusal = OF.lang.t("Could not get you a copy of this level of your own.")
    elseif first then
        refusal = OF.lang.t("Could not get you a course of your own.")
    elseif ktq then
        refusal = OF.lang.t("Could not get you a Koopa of your own.")
    elseif reds then
        refusal = OF.lang.t("Could not get you red coins of your own.")
    elseif coins then
        refusal = OF.lang.t("Could not get you a course of your own.")
    end

    local area = 1
    if reds then area = (speedrun.red_coin_star() or {}).area or 1 end

    if ktq then area = (speedrun.koopa_racer() or {}).area or 1 end

    if first then area = me.currAreaIndex or 1 end

    if general and OF.util.asks(OF.roundact, "move_to") then
        OF.roundact.move_to(owed_act())
    else
        OF.net.warp_local(me.currLevelNum, area, owed_act(), nil, refusal)
    end
    if general then
        speedrun.note("Your own copy of this level - the others have theirs",
            "info")
    elseif first then
        speedrun.note("Your own copy of the course - the others race theirs",
            "info")
    elseif ktq then
        speedrun.note("Your own Koopa the Quick, racing you and nobody else",
            "info")
    elseif reds then
        speedrun.note("Your own course - eight red coins nobody else can take",
            "info")
    elseif coins then
        speedrun.note("Your own course - a hundred coins nobody else can take",
            "info")
    else
        speedrun.note("Your own Bowser - the others are fighting theirs",
            "info")
    end
end

speedrun.SMALL_WORDS = { a = true, an = true, the = true, of = true, on = true,
    ["in"] = true, to = true, ["for"] = true, ["and"] = true, at = true, by = true,
    from = true, with = true, over = true, into = true }
function speedrun.star_title(name)
    if type(name) ~= "string" or name == "" then return nil end
    local index = 0
    local out = string.gsub(name, "%S+", function(word)
        index = index + 1
        local lower = string.lower(word)
        if index > 1 and speedrun.SMALL_WORDS[lower] then return lower end
        return (string.gsub(word, "%-(%u)", function(c) return "-" .. string.lower(c) end))
    end)
    return out
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
    OF.net.warp_everyone(levelEntry.level, levelEntry.area, levelEntry.act, nil, true)
    return true
end

function speedrun.start_star(courseNum, actNum, askerLocal)
    if not OF.util.is_host() and OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does(speedrun.STAR_ACTION, courseNum, actNum)
    end
    local levelNum = get_level_num_from_course_num(courseNum)
    local starName = speedrun.star_title(get_star_name(courseNum, actNum)) or ("star " .. actNum)
    local title = OF.util.course_name(courseNum) .. " - " .. starName

    local ok, why = begin(speedrun.MODE_STAR, levelNum, 1, actNum, title, nil,
        askerLocal)
    if not ok then return false, why end
    OF.net.warp_everyone(levelNum, 1, actNum, nil, true)
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

    local title = entry.name

    local ok, why = begin(speedrun.MODE_STARS, LEVEL_CASTLE_GROUNDS, 1, 0,
        title, target, askerLocal)
    if not ok then return false, why end

    take_the_castle()
    OF.net.warp_everyone(LEVEL_CASTLE_GROUNDS, 1, 0, nil, true)
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

    if obj == nil or OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvBowserKey) ~= 0 then
        return nil
    end
    local index = OF.util.star_act_index(obj)
    if index == nil then return nil end
    local here = gNetworkPlayers[0]
    local levelNum = here ~= nil and here.currLevelNum or 0
    return tostring(levelNum) .. ":" .. tostring(index)
end

local function took_a_star(obj)
    if not speedrun.counts_stars() then return end
    local name = star_name_of(obj)

    if name == nil then return end
    local here = gNetworkPlayers[0]
    local level = here ~= nil and here.currLevelNum or 0
    if counted[name] then return end
    counted[name] = true
    OF.util.publish_row(0, "ofRunGot", speedrun.stars_got(0) + 1)
    speedrun.take_split("star", level, speedrun.stars_got(0), nil, OF.util.star_act_index(obj))
end

function speedrun.counts_stars()
    return speedrun.mode() == speedrun.MODE_STARS
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

function speedrun.final_line()
    local board = speedrun.results()
    local first = board[1]
    if first == nil or first.name == nil or first.name == "" then
        return OF.lang.t("Nobody finished.")
    end
    local name = OF.util.shorten(OF.util.plain(first.name), 20)

    if speedrun.field_size() <= 1 then
        return OF.lang.fill("@ finished in @", name, speedrun.format_time(first.time))
    end
    return OF.lang.fill("@ wins in @", name, speedrun.format_time(first.time))
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

function speedrun.shows_run()
    if speedrun.watched_runner() ~= nil then return true end
    if OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(0) then
        return true
    end
    return speedrun.in_this_run() and not speedrun.run_excluded(0)
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
            elseif OF.util.can_play(entry.localIndex, speedrun.KIND_RUN) then
                return false
            end
        end
    end

    return waited > 0
end

do

    speedrun.COURSE_SHORT = {}
    local short = speedrun.COURSE_SHORT
    local function put(level, name)
        if type(level) == "number" then short[level] = name end
    end
    put(LEVEL_BOB, "BoB") put(LEVEL_WF, "WF") put(LEVEL_JRB, "JRB")
    put(LEVEL_CCM, "CCM") put(LEVEL_BBH, "BBH") put(LEVEL_HMC, "HMC")
    put(LEVEL_LLL, "LLL") put(LEVEL_SSL, "SSL") put(LEVEL_DDD, "DDD")
    put(LEVEL_SL, "SL") put(LEVEL_WDW, "WDW") put(LEVEL_TTM, "TTM")
    put(LEVEL_THI, "THI") put(LEVEL_TTC, "TTC") put(LEVEL_RR, "RR")
    put(LEVEL_BITDW, "BitDW") put(LEVEL_BITFS, "BitFS") put(LEVEL_BITS, "BitS")
    put(LEVEL_BOWSER_1, "BitDW") put(LEVEL_BOWSER_2, "BitFS")
    put(LEVEL_BOWSER_3, "BitS")
    put(LEVEL_PSS, "PSS") put(LEVEL_SA, "SA") put(LEVEL_WMOTR, "WMotR")
    put(LEVEL_TOTWC, "TotWC") put(LEVEL_COTMC, "CotMC") put(LEVEL_VCUTM, "VCutM")
    put(LEVEL_CASTLE, "Castle") put(LEVEL_CASTLE_GROUNDS, "Castle")
    put(LEVEL_CASTLE_COURTYARD, "Castle")

    speedrun.FIGHTS = {}
    local function fight(level, stage, key, keyName)
        if type(level) == "number" then
            speedrun.FIGHTS[level] = { stage = stage, key = key, keyName = keyName }
        end
    end
    fight(LEVEL_BOWSER_1, "BitDW", "k1", "Key 1")
    fight(LEVEL_BOWSER_2, "BitFS", "k2", "Key 2")
    fight(LEVEL_BOWSER_3, "BitS", nil, nil)
    speedrun.STAGE_KEY = { BitDW = "b1", BitFS = "b2", BitS = "b3" }
end

function speedrun.course_short(levelNum)
    return speedrun.COURSE_SHORT[levelNum]
end

function speedrun.is_castle_level(levelNum)
    return levelNum ~= nil and (levelNum == LEVEL_CASTLE or levelNum == LEVEL_CASTLE_GROUNDS
        or levelNum == LEVEL_CASTLE_COURTYARD)
end

function speedrun.is_exit_course(levelNum)
    if levelNum == nil or speedrun.COURSE_SHORT[levelNum] == nil then return false end
    if speedrun.is_castle_level(levelNum) then return false end
    return speedrun.FIGHTS[levelNum] == nil
end

speedrun.EXIT_SPLITS_FROM = 70
function speedrun.splits_by_exit(target)
    if speedrun.mode() ~= speedrun.MODE_STARS then return false end
    target = target or speedrun.star_target()
    return target >= speedrun.EXIT_SPLITS_FROM
end

function speedrun.split_wanted(kind, count, target, levelNum)
    if kind == "exit" then
        count = math.floor(tonumber(count) or 0)
        return count > 0 and speedrun.splits_by_exit(target)
    end
    if kind ~= "star" then return true end
    if speedrun.mode() ~= speedrun.MODE_STARS then return false end
    target = target or speedrun.star_target()
    count = math.floor(tonumber(count) or 0)
    if target <= 0 or count <= 0 then return false end
    if speedrun.splits_by_exit(target) then return speedrun.is_castle_level(levelNum) end
    return true
end

function speedrun.split_key(kind, levelNum, count)
    if kind == "star" or kind == "exit" then return "s" .. tostring(math.floor(tonumber(count) or 0)) end
    local fight = speedrun.FIGHTS[levelNum]
    if kind == "stage" then
        return fight ~= nil and speedrun.STAGE_KEY[fight.stage] or "b0"
    end
    if kind == "key" then return fight ~= nil and fight.key or "k0" end
    return "end"
end

function speedrun.castle_star_word(index)
    if index == nil then return speedrun.COURSE_SHORT[LEVEL_CASTLE] or "Castle" end
    if index == 3 or index == 4 then return "Mips" end
    if index >= 0 and index <= 2 then return "Toad" end
    return speedrun.COURSE_SHORT[LEVEL_CASTLE] or "Castle"
end

function speedrun.split_name(kind, levelNum, count, index)
    count = math.floor(tonumber(count) or 0)
    local stars = speedrun.mode() == speedrun.MODE_STARS
    if kind == "star" or kind == "exit" then
        local word = speedrun.COURSE_SHORT[levelNum] or "Star"
        if kind == "star" and speedrun.is_castle_level(levelNum) then
            word = speedrun.castle_star_word(index)
        end
        return word .. " (" .. tostring(count) .. ")"
    end
    local fight = speedrun.FIGHTS[levelNum]
    if kind == "stage" then
        return fight ~= nil and fight.stage or "Bowser stage"
    end
    if kind == "key" then
        local name = fight ~= nil and fight.keyName or "Key"
        if stars and speedrun.star_target() > 0 then
            name = name .. " (" .. tostring(count) .. ")"
        end
        return name
    end

    if stars or levelNum == LEVEL_BOWSER_3 or levelNum == LEVEL_BITS then
        return "Bowser 3"
    end
    if fight ~= nil and fight.keyName ~= nil then return fight.keyName end
    if levelNum == LEVEL_BITDW then return "Key 1" end
    if levelNum == LEVEL_BITFS then return "Key 2" end
    return speedrun.COURSE_SHORT[levelNum] or "Finish"
end

function speedrun.split_state(delta, prevDelta, seg, gold)
    if seg ~= nil and gold ~= nil and seg < gold then return "best" end
    if delta == nil then return "none" end
    if delta < 0 then
        if prevDelta ~= nil and delta > prevDelta then return "aheadLose" end
        return "aheadGain"
    end
    if prevDelta ~= nil and delta < prevDelta then return "behindGain" end
    return "behindLose"
end

function speedrun.segments(list)
    local out, prevKey, prevFrames = {}, "start", 0
    for _, split in ipairs(list or {}) do
        out[#out + 1] = { key = prevKey .. ">" .. split.key,
            frames = split.frames - prevFrames }
        prevKey, prevFrames = split.key, split.frames
    end
    return out
end

function speedrun.sum_of_best(route, golds)
    if route == nil or #route == 0 or golds == nil then return nil end
    local total = 0
    for _, seg in ipairs(speedrun.segments(route)) do
        local gold = golds[seg.key]
        if gold == nil then return nil end
        total = total + gold
    end
    return total
end

function speedrun.keep_golds(golds, list)
    local moved = 0
    for _, seg in ipairs(speedrun.segments(list)) do
        if golds[seg.key] == nil or seg.frames < golds[seg.key] then
            golds[seg.key] = seg.frames
            moved = moved + 1
        end
    end
    return moved
end

speedrun.sessionSplits = speedrun.sessionSplits or {}

function speedrun.split_book(slotKey)
    slotKey = slotKey or speedrun.current_slot()
    local book = speedrun.sessionSplits[slotKey]
    if book == nil then
        book = { golds = {} }
        speedrun.sessionSplits[slotKey] = book
    end
    return book
end

speedrun.mySplits = {}
speedrun.runRoute = nil
speedrun.routeTaken = false

speedrun.splitAt = nil

speedrun.seen = {}

function speedrun.forget_splits()
    speedrun.exitFrom = nil
    speedrun.mySplits = {}
    speedrun.runRoute = nil
    speedrun.routeTaken = false
    speedrun.splitAt = nil
    speedrun.seen = {}
end

function speedrun.saw_split(globalIndex, key, name, frames)
    if globalIndex == nil or key == nil or type(frames) ~= "number" then return false end
    local row = speedrun.seen[globalIndex]
    if row == nil then
        row = { splits = {}, count = 0 }
        speedrun.seen[globalIndex] = row
    end
    if row.splits[key] ~= nil then return false end
    row.splits[key] = frames
    row.count = (row.count or 0) + 1
    row.last = { key = key, name = name, frames = frames }
    return true
end

local function route_at(route, key)
    for _, split in ipairs(route or {}) do
        if split.key == key then return split.frames, split end
    end
    return nil
end
speedrun.route_at = route_at

function speedrun.take_split(kind, levelNum, count, frames, index)

    if not sawTheLine or speedrun.run_excluded(0) then return nil end
    if speedrun.finished and kind ~= "final" then return nil end
    if not speedrun.split_wanted(kind, count, nil, levelNum) then return nil end
    frames = math.floor(tonumber(frames) or speedrun.timer or 0)
    if frames <= 0 then return nil end
    local key = speedrun.split_key(kind, levelNum, count)
    for _, split in ipairs(speedrun.mySplits) do
        if split.key == key then return nil end
    end
    local book = speedrun.split_book()
    if not speedrun.routeTaken then
        speedrun.runRoute = book.best
        speedrun.routeTaken = true
    end
    local prev = speedrun.mySplits[#speedrun.mySplits]
    local prevKey = prev ~= nil and prev.key or "start"
    local seg = frames - (prev ~= nil and prev.frames or 0)
    local at = route_at(speedrun.runRoute, key)
    local delta = at ~= nil and (frames - at) or nil
    local prevDelta = nil
    for index = #speedrun.mySplits, 1, -1 do
        if speedrun.mySplits[index].delta ~= nil then
            prevDelta = speedrun.mySplits[index].delta
            break
        end
    end
    local segKey = prevKey .. ">" .. key
    local gold = book.golds[segKey]
    local split = {
        kind = kind, key = key, name = speedrun.split_name(kind, levelNum, count, index),
        frames = frames, seg = seg, segKey = segKey, delta = delta,
        state = speedrun.split_state(delta, prevDelta, seg, gold),
        at = OF.util.asks(OF.hud, "now") and OF.hud.now() or 0,
    }
    if gold == nil or seg < gold then book.golds[segKey] = seg end
    table.insert(speedrun.mySplits, split)
    speedrun.splitAt = split.at
    speedrun.saw_split(network_global_index_from_local(0), key, split.name, frames)

    if kind ~= "final" and OF.hud ~= nil then
        speedrun.run_sound(OF.hud.sound_of(split.state == "best" and "gold" or "split"))
    end
    return split
end

function speedrun.previous_segment()
    local last = speedrun.mySplits[#speedrun.mySplits]
    if last == nil then return nil end
    for _, seg in ipairs(speedrun.segments(speedrun.runRoute)) do
        if seg.key == last.segKey then
            local diff = last.seg - seg.frames
            local tone = last.state == "best" and "best"
                or (diff < 0 and "aheadGain" or "behindLose")
            return diff, tone
        end
    end
    return nil
end

function speedrun.keep_split_book(newBest)
    if not newBest or #speedrun.mySplits == 0 then return false end
    local route = {}
    for index, split in ipairs(speedrun.mySplits) do
        route[index] = { key = split.key, name = split.name, frames = split.frames }
    end
    local book = speedrun.split_book()
    book.best = route

    speedrun.keep_golds(book.golds, speedrun.mySplits)
    return true
end

function speedrun.split_rows(most)
    most = most or 5
    local rows = {}
    local done = speedrun.mySplits
    local route = speedrun.runRoute
    if not speedrun.routeTaken then route = speedrun.split_book().best end

    local nextIndex = 1
    if route ~= nil then
        for index = #done, 1, -1 do
            local found = nil
            for r, split in ipairs(route) do
                if split.key == done[index].key then found = r break end
            end
            if found ~= nil then nextIndex = found + 1 break end
        end
    end
    local upcoming = {}
    if route ~= nil and not speedrun.finished then
        for r = nextIndex, #route do
            local taken = false
            for _, split in ipairs(done) do
                if split.key == route[r].key then taken = true break end
            end
            if not taken then upcoming[#upcoming + 1] = route[r] end
        end
    end

    local wantUp = math.min(#upcoming, (#done > 0) and 1 or most)
    local wantDone = math.min(#done, most - wantUp)
    wantUp = math.min(#upcoming, most - wantDone)
    for index = #done - wantDone + 1, #done do
        local split = done[index]
        rows[#rows + 1] = { name = split.name, frames = split.frames, delta = split.delta,
            state = split.state, split = split }
    end
    for index = 1, wantUp do
        local split = upcoming[index]
        rows[#rows + 1] = { name = split.name, frames = split.frames, upcoming = true }
    end
    return rows
end

function speedrun.observe_runners()
    if state() ~= speedrun.ACTIVE then return end
    local clock = speedrun.raceClock or 0
    local stars = speedrun.counts_stars()
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        if li ~= 0 and on_the_line(li) then
            local g = network_global_index_from_local(li)
            local row = speedrun.seen[g]
            if row == nil then
                row = { splits = {}, count = 0 }
                speedrun.seen[g] = row
            end
            local np = entry.np
            local level = np ~= nil and np.currLevelNum or nil
            local posted = speedrun.posted_time(li)
            if clock > 0 then
                if stars then
                    local got = speedrun.stars_got(li)
                    row.got = row.got or 0
                    while row.got < got do
                        row.got = row.got + 1
                        if speedrun.split_wanted("star", row.got, nil, level) then
                            speedrun.saw_split(g, "s" .. row.got,
                                speedrun.split_name("star", level, row.got), clock)
                        end
                    end
                end
                if row.level ~= nil and level ~= row.level then

                    if stars and speedrun.is_exit_course(row.level) and speedrun.FIGHTS[level] == nil
                        and (row.got or 0) > (row.gotIn or 0)
                        and speedrun.split_wanted("exit", row.got) then
                        speedrun.saw_split(g, speedrun.split_key("exit", row.level, row.got),
                            speedrun.split_name("exit", row.level, row.got), clock)
                    end
                    row.gotIn = row.got or 0
                    local into = speedrun.FIGHTS[level]
                    if into ~= nil then
                        speedrun.saw_split(g, speedrun.split_key("stage", level),
                            speedrun.split_name("stage", level), clock)
                    end
                    local out = speedrun.FIGHTS[row.level]
                    if out ~= nil and out.key ~= nil and level == LEVEL_CASTLE then
                        speedrun.saw_split(g, out.key,
                            speedrun.split_name("key", row.level, row.got or 0), clock)
                    end
                end
            end
            if level ~= nil then row.level = level end
            if posted > 0 and row.splits["end"] == nil then
                speedrun.saw_split(g, "end", speedrun.split_name("final",
                    gGlobalSyncTable.ofRunLevel or level, row.got or 0), posted)
            end
        end
    end
end

local function split_count(row)
    return row.seen ~= nil and (row.seen.count or 0) or 0
end
local function race_ahead(a, b)
    local af, bf = a.posted > 0, b.posted > 0
    if af ~= bf then return af end
    if af then
        if a.posted ~= b.posted then return a.posted < b.posted end
        return a.localIndex < b.localIndex
    end
    if (a.got or 0) ~= (b.got or 0) then return (a.got or 0) > (b.got or 0) end
    local ac, bc = split_count(a), split_count(b)
    if ac ~= bc then return ac > bc end
    local at = a.seen ~= nil and a.seen.last ~= nil and a.seen.last.frames or math.huge
    local bt = b.seen ~= nil and b.seen.last ~= nil and b.seen.last.frames or math.huge
    if at ~= bt then return at < bt end
    return a.localIndex < b.localIndex
end

function speedrun.race_rows()
    local rows = {}
    local stars = speedrun.counts_stars()
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local dealt = startLine ~= nil and on_the_line(li)
            or (startLine == nil and OF.util.can_play(li, speedrun.KIND_RUN))
        if dealt then
            local g = network_global_index_from_local(li)
            rows[#rows + 1] = {
                localIndex = li, globalIndex = g, name = entry.np.name,
                posted = speedrun.posted_time(li),
                got = stars and speedrun.stars_got(li) or nil,
                seen = speedrun.seen[g], you = li == 0,
            }
        end
    end
    table.sort(rows, race_ahead)
    local leader = rows[1]
    for place, row in ipairs(rows) do
        row.place = place
        local last = row.seen ~= nil and row.seen.last or nil
        row.split = last ~= nil and last.name or nil
        if place > 1 and leader ~= nil then
            if row.posted > 0 and leader.posted > 0 then
                row.gap = row.posted - leader.posted
            elseif last ~= nil and leader.seen ~= nil and leader.seen.splits[last.key] ~= nil then
                row.gap = last.frames - leader.seen.splits[last.key]
            end
        end
    end
    return rows
end

function speedrun.field_size()
    local count = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if startLine ~= nil then
            if on_the_line(entry.localIndex) then count = count + 1 end
        elseif OF.util.can_play(entry.localIndex, speedrun.KIND_RUN) then
            count = count + 1
        end
    end
    return count
end

function speedrun.delta_text(frames)
    if frames == nil then return "-" end
    local sign = frames < 0 and "-" or "+"
    local tenths = math.floor(math.abs(frames) * 10 / 30)
    local seconds = math.floor(tenths / 10)
    if seconds < 60 then
        return string.format("%s%.0f.%.0f", sign, seconds, tenths % 10)
    end
    return string.format("%s%.0f:%02.0f.%.0f", sign, math.floor(seconds / 60),
        seconds % 60, tenths % 10)
end

speedrun.EMPTY_RACE_SECONDS = 60
speedrun.EMPTY_SAID = "Everybody left the race - it is over."
speedrun.emptyFrames = 0

function speedrun.racers_on_line()
    local n = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if on_the_line(entry.localIndex) then n = n + 1 end
    end
    return n
end

function speedrun.field_empty_step()
    if speedrun.racers_on_line() > 0 then
        speedrun.emptyFrames = 0
        return false
    end
    speedrun.emptyFrames = speedrun.emptyFrames + 1
    if speedrun.emptyFrames < speedrun.EMPTY_RACE_SECONDS * 30 then return false end
    speedrun.emptyFrames = 0
    OF.notify.send_all(speedrun.EMPTY_SAID, "info", 6)
    speedrun.stop(true)
    return true
end

local function host_update()
    if not OF.util.is_host() then return end
    local current = state()
    if current == speedrun.OFF then return end

    if current == speedrun.COUNTDOWN then

        local waited = phase_seconds()
        if waited >= COUNTDOWN_SECONDS and speedrun.field_ready(waited) then
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

        if speedrun.field_empty_step() then return end
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

    if newVal == speedrun.OFF and OF.util.asks(OF.net, "lead_settle") then
        OF.net.lead_settle()
    end

    if oldVal == newVal then return end

    arenaAsked = nil

    speedrun.forget_red_coin_star()

    speedrun.forget_koopa_racer()

    speedrun.forget_refused_copies()

    speedrun.forget_missions()

    speedrun.forget_owed_room()

    if newVal == speedrun.OFF or newVal == speedrun.COUNTDOWN then
        startLine = nil
        speedrun.forget_times()
    end

    if newVal == speedrun.OFF then
        sawTheLine = false
        speedrun.castleNote = false
    end

    local nowFrame = OF.util.asks(OF.hud, "now") and OF.hud.now() or 0
    if newVal == speedrun.COUNTDOWN then
        speedrun.forget_splits()
        speedrun.countAt, speedrun.goAt, speedrun.cardAt, speedrun.resultsAt = nowFrame, nil, nil, nil
        speedrun.timedAtCredits, speedrun.underRecord = false, nil
        speedrun.recordAtGun, speedrun.recordSaid = nil, false
    elseif newVal == speedrun.ACTIVE then
        speedrun.goAt = nowFrame
        speedrun.recordAtGun = speedrun.published_record()
        speedrun.recordSaid = false
    elseif newVal == speedrun.RESULTS then
        speedrun.resultsAt = nowFrame
    end

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
        if not speedrun.run_excluded(0) then
            play_character_sound(gMarioStates[0], CHAR_SOUND_HERE_WE_GO)
        end

        speedrun.hear_the_count(nil)
        speedrun.run_sound(OF.sounds.SHOT)
    elseif newVal == speedrun.RESULTS then
        local board = speedrun.results()
        if #board > 0 and board[1].localIndex == 0 then OF.celebrate.win() end
        if #board > 0 and OF.util.is_host() then
            OF.stats.record_race_win(board[1].localIndex)

            keep_record(speedrun.fastest_clock(board))
        end

    end
end

speedrun.PACKET_SET = "runset"
local function on_race_set(data)
    if data == nil or data.ofp ~= speedrun.PACKET_SET then return end
    if not OF.util.from_host(data) then return end

    if speedrun.muted_out(0) then return end
    local value = data.out == 1
    for _, key in ipairs(speedrun.keys_of(speedrun.kind_of_code(data.k))) do
        write_tick(key, value)
    end
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_race_set)

local function on_race_ask(data)
    if data == nil or data.ofp ~= speedrun.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    if OF.perms.tier(asker) < OF.perms.required("speedrun", asker) then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    local target = OF.util.local_from_global(data.who)

    local may, whyNot = OF.util.may_act_on(asker, target)
    if not may then
        OF.util.tell_asker(askerGlobal, whyNot)
        return
    end

    speedrun.set_excluded(target, data.out == 1, speedrun.kind_of_code(data.k))
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_race_ask)

local function on_race_stop(data)
    if data == nil or data.ofp ~= speedrun.PACKET_STOP then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end

    if OF.perms.tier(asker) < OF.perms.required("end_round", asker) then
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

    if state() == speedrun.ACTIVE then
        speedrun.raceClock = race_frames() or 0
        speedrun.timer = speedrun.raceClock
        return
    end
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
    if not OF.util.can_play(0, speedrun.KIND_RUN) then return end

    if not passedBest then
        local best = speedrun.current_best()
        if best ~= nil and speedrun.timer > best then

            passedBest = true
        end
    end

    if not passedRecord then
        local record = speedrun.published_record()
        if record ~= nil and speedrun.timer > record.time then
            passedRecord = true
        end
    end
end

do
    function speedrun.hears_run()
        local current = state()
        if current ~= speedrun.COUNTDOWN and current ~= speedrun.ACTIVE then
            return false
        end
        if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then
            return true
        end
        return OF.util.asks(OF.roundact, "watches") and OF.roundact.watches(0)
            or false
    end

    function speedrun.run_sound(sound)
        if sound == nil or not speedrun.hears_run() then return nil end
        OF.sounds.play(sound)
        return sound
    end

    local countHeard = nil
    function speedrun.hear_the_count(frames)
        if type(frames) ~= "number" then
            countHeard = nil
            return nil
        end
        local left = math.ceil(frames / 30)
        if left < 1 or left == countHeard then return nil end
        if not OF.util.asks(OF.gamemodes, "count_sound") then return nil end

        local played = speedrun.run_sound(OF.gamemodes.count_sound(left))
        if played ~= nil then countHeard = left end
        return played
    end
end

function speedrun.record_news()
    if state() ~= speedrun.RESULTS or speedrun.recordSaid then return false end
    local now = speedrun.published_record()
    if now == nil then return false end
    local was = speedrun.recordAtGun
    if was ~= nil and now.time >= was.time then return false end
    speedrun.recordSaid = true
    if was ~= nil then
        speedrun.note("@ takes the session record - @ off it", "good", now.name,
            speedrun.gap_text(was.time - now.time))
    else
        speedrun.note("@ sets the first session record: @", "good", now.name,
            speedrun.format_time(now.time))
    end
    return true
end

local function local_update()
    local current = state()

    watch_red_star()

    watch_koopa_racer()

    speedrun.note_mission()
    arena_frame()
    speedrun.red_coin_tick()
    speedrun.koopa_tick()

    speedrun.mission_stock_tick()
    speedrun.whirlpool_frame()
    speedrun.snowman_frame()
    owed_frame()

    keep_first_times()

    if current == speedrun.ACTIVE then
        speedrun.raceClock = race_frames() or 0
        speedrun.observe_runners()
    end
    speedrun.record_news()

    if current == speedrun.COUNTDOWN then
        tick_timer()
        speedrun.hear_the_count(COUNTDOWN_FRAMES - (speedrun.timer or 0))
    elseif current == speedrun.ACTIVE and not speedrun.finished then
        tick_timer()
        mark_pace()

        if speedrun.mode() == speedrun.MODE_STARS
            and speedrun.star_target() > 0 and not speedrun.countSaid
            and speedrun.count_met() then
            speedrun.countSaid = true
            speedrun.note("@ stars - now Bowser in the Sky", "good",
                tostring(speedrun.star_target()))

            speedrun.run_sound(OF.sounds.CHIME)
        end
    end
end

function finish(reason)
    if speedrun.finished then return end
    if speedrun.run_excluded(0) then return end

    if not sawTheLine and speedrun.refuses_latecomers() then return end

    speedrun.finished = true

    if speedrun.timer > 0 then
        OF.util.publish_row(0, "ofRunTime", speedrun.timer)
    end

    local here = gNetworkPlayers[0]
    speedrun.take_split("final", here ~= nil and here.currLevelNum or 0,
        speedrun.stars_got(0), speedrun.timer)

    speedrun.lastBest = speedrun.current_best()

    if speedrun.timer > 0
        and (speedrun.lastBest == nil or speedrun.timer < speedrun.lastBest) then
        save_personal_best(speedrun.timer)
        speedrun.lastPbBeaten = true
    end

    speedrun.keep_split_book(speedrun.lastPbBeaten)

    speedrun.finishReason = reason
    speedrun.cardAt = nil
    local record = speedrun.published_record()
    local underRecord = record ~= nil and speedrun.timer > 0
        and speedrun.timer < record.time
    speedrun.underRecord = underRecord and (record.time - speedrun.timer) or nil

    speedrun.run_sound(OF.sounds.FINISH)
    if underRecord then
        speedrun.run_sound(OF.sounds.RECORD)
    elseif speedrun.lastPbBeaten then
        speedrun.run_sound(OF.sounds.BEST)
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
            speedrun.note("This run started before you arrived - it is not yours to finish",
                "warn")
        end
        return
    end

    took_a_star(obj)

    if speedrun.mode() == speedrun.MODE_STARS and obj ~= nil
        and OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvBowserKey) ~= 0 then
        speedrun.take_split("key", gNetworkPlayers[0].currLevelNum, speedrun.stars_got(0))
    end

    if speedrun.ends_at_bowser() then
        if not speedrun.ends_here(gNetworkPlayers[0].currLevelNum) then return end
        if not speedrun.count_met() then
            speedrun.note("@ - not enough stars for this category yet", "warn",
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

            name = speedrun.star_title(name)
            speedrun.note("Wrong star@ - the race is still on.", "warn",
                (name ~= nil and name ~= "") and (" (" .. name .. ")") or "")
            return
        end

        finish()
        return
    end

    finish()
end

speedrun.exitFrom = nil
function speedrun.exit_tick(levelNum)
    local got = speedrun.stars_got(0)
    local from = speedrun.exitFrom
    if from ~= nil and from.level ~= levelNum and got > (from.got or 0)
        and speedrun.is_exit_course(from.level) and speedrun.FIGHTS[levelNum] == nil then
        speedrun.take_split("exit", from.level, got)
    end
    speedrun.exitFrom = { level = levelNum, got = got }
    return speedrun.exitFrom
end

local function on_level_init(type, levelNum)

    redStocking = RED_STOCK_FRAMES
    koopaStocking = KOOPA_STOCK_FRAMES
    speedrun.arm_mission_stock()
    if state() ~= speedrun.ACTIVE then return end
    speedrun.exit_tick(levelNum)

    if speedrun.FIGHTS[levelNum] ~= nil then
        speedrun.take_split("stage", levelNum, speedrun.stars_got(0))
    end
    if not speedrun.ends_at_bowser() then return end

    if not speedrun.count_met() then return end

    if levelNum == LEVEL_ENDING then
        if not speedrun.finished then speedrun.timedAtCredits = true end
        finish("You beat the game!")
    end
end

local CONTACT_HOLDER = "race"
speedrun.OPTS_KEY = "ofRunOpts"
speedrun.OPTS_ACTION = "runopts"
speedrun.OPTS_STORE = "run_opts2"
speedrun.OPTS = {
    { key = "text", name = "Text boxes", vanilla = 2,
      help = "the signs, the boss openings and the level-start windows",
      steps = { "skipped", "kept" },
      stepHelp = { "faster, and the time is kept apart from vanilla runs",
                   "as the game shows them, the way speedrun.com times a run" } },
    { key = "star", name = "After a star", vanilla = 1,
      help = "what a runner who takes a star does next",
      steps = { "leave the level", "Non-Stop" },
      stepHelp = { "the game's own answer, as speedrun.com runs it",
                   "the star leaves you in the level - kept apart from vanilla runs" } },

    { key = "doors", name = "Doors", vanilla = 2,
      help = "the lobby's own Doors row, for the runners while they race",
      steps = { "open as you run up", "as the game has them" },
      stepHelp = { "a star door you have not earned stays shut - kept apart from vanilla runs",
                   "every door opens the way the game opens it" } },
}

speedrun.OPT_PRESETS = {
    { key = "vanilla", name = "Vanilla",
      help = "the speedrun.com rules: text kept, leave the level, doors as the game has them",
      sets = { text = 2, star = 1, doors = 2 } },
    { key = "party", name = "Party",
      help = "text skipped and doors that open as you run up - quick, and timed apart",
      sets = { text = 1, star = 1, doors = 1 } },
}

function speedrun.opt(key)
    local text = gGlobalSyncTable[speedrun.OPTS_KEY]
    if type(text) ~= "string" then text = "" end
    for index, row in ipairs(speedrun.OPTS) do
        if row.key == key then
            local step = tonumber(string.sub(text, index, index)) or 1
            if step < 1 or step > #row.steps then step = 1 end
            return step
        end
    end
    return 1
end

function speedrun.keeps_text() return speedrun.opt("text") == 2 end
function speedrun.opens_doors() return speedrun.opt("doors") == 1 end
function speedrun.non_stop() return speedrun.opt("star") == 2 end

function speedrun.opts_digits()
    local digits = {}
    for index, row in ipairs(speedrun.OPTS) do
        digits[index] = tostring(speedrun.opt(row.key))
    end
    return table.concat(digits)
end

function speedrun.opts_vanilla()
    for _, row in ipairs(speedrun.OPTS) do
        if speedrun.opt(row.key) ~= row.vanilla then return false end
    end
    return true
end

function speedrun.opts_tag()
    if speedrun.opts_vanilla() then return "" end
    return "_o" .. speedrun.opts_digits()
end

function speedrun.opt_shown(row)
    local rule = row ~= nil and row.shownIf or nil
    if rule == nil then return true end
    if type(rule) == "function" then
        local ok, shown = pcall(rule, speedrun.opt)
        return not ok or shown ~= false
    end
    if type(rule) ~= "table" then return true end
    for key, want in pairs(rule) do
        local now = speedrun.opt(key)
        if type(want) == "table" then
            local any = false
            for _, value in ipairs(want) do
                if value == now then any = true end
            end
            if not any then return false end
        elseif now ~= want then
            return false
        end
    end
    return true
end

function speedrun.opt_preset_now()
    for _, preset in ipairs(speedrun.OPT_PRESETS) do
        local all = true
        for _, row in ipairs(speedrun.OPTS) do
            if speedrun.opt(row.key) ~= (preset.sets[row.key] or 1) then all = false end
        end
        if all then return preset end
    end
    return nil
end

speedrun.DOORS_RULE = "opendoors"
function speedrun.doors_stop()
    if speedrun.opens_doors() then return 2 end
    return 0
end

local function publish_opts(digits)
    if state() == speedrun.ACTIVE then
        return false, "The settings change between races - stop this one first."
    end
    OF.util.publish(speedrun.OPTS_KEY, digits)
    OF.util.store(speedrun.OPTS_STORE, digits)
    return true
end

function speedrun.set_opt(key, step, askerLocal)
    if not OF.perms.can("speedrun") and askerLocal == nil then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(speedrun.OPTS_ACTION, tonumber(step), nil, tostring(key))
        end
        return false, "No host to ask yet - try again in a second."
    end
    local digits = {}
    local found = false
    for index, row in ipairs(speedrun.OPTS) do
        local now = speedrun.opt(row.key)
        if row.key == key then
            now = math.floor(tonumber(step) or 1)
            if now < 1 or now > #row.steps then now = 1 end
            found = true
        end
        digits[index] = tostring(now)
    end
    if not found then return false, "No such setting." end
    return publish_opts(table.concat(digits))
end

function speedrun.apply_opt_preset(presetKey, askerLocal)
    if not OF.perms.can("speedrun") and askerLocal == nil then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local preset = nil
    for _, entry in ipairs(speedrun.OPT_PRESETS) do
        if entry.key == presetKey then preset = entry end
    end
    if preset == nil then return false, "No such way to play it." end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(speedrun.OPTS_ACTION, 0, nil, "preset:" .. preset.key)
        end
        return false, "No host to ask yet - try again in a second."
    end
    local digits = {}
    for index, row in ipairs(speedrun.OPTS) do
        digits[index] = tostring(preset.sets[row.key] or 1)
    end
    return publish_opts(table.concat(digits))
end

function speedrun.step_opt_preset(askerLocal)
    local now = speedrun.opt_preset_now()
    local nextIndex = 1
    for index, preset in ipairs(speedrun.OPT_PRESETS) do
        if preset == now then nextIndex = index % #speedrun.OPT_PRESETS + 1 end
    end
    return speedrun.apply_opt_preset(speedrun.OPT_PRESETS[nextIndex].key, askerLocal)
end

local optsPublished = false
local function publish_stored_opts()
    if optsPublished or not OF.util.is_host() then return end
    optsPublished = true
    if type(gGlobalSyncTable[speedrun.OPTS_KEY]) == "string" then return end
    local stored = OF.util.stored(speedrun.OPTS_STORE)
    if type(stored) == "string" and string.match(stored, "^%d+$") then
        OF.util.publish(speedrun.OPTS_KEY, stored)
    end
end

local STAR_HOLDER = "speedrun-star"
speedrun.STAR_RULE_OF_STEP = { 0, 2 }
local function hold_star(running)
    local step = speedrun.opt("star")
    if running then
        if OF.util.asks(OF.rules, "lend") then
            OF.rules.lend("star", STAR_HOLDER, speedrun.STAR_RULE_OF_STEP[step] or 0)
        end
    elseif OF.util.asks(OF.rules, "give_back") then
        OF.rules.give_back("star", STAR_HOLDER)
    end
end

local function hold_doors(running)
    if not running then return end
    if not OF.util.asks(OF.rules, "set_round") then return end
    local want = nil
    if not speedrun.opens_doors() then want = speedrun.doors_stop() end
    if OF.rules.round_value(speedrun.DOORS_RULE) ~= want then
        OF.rules.set_round(speedrun.DOORS_RULE, want)
    end
end
speedrun.hold_doors = hold_doors

function hold_contact(current)
    local running = current == speedrun.COUNTDOWN or current == speedrun.ACTIVE
    if OF.util.is_host() then
        publish_stored_opts()
        hold_star(running)
        hold_doors(running)
    end

    if not OF.util.is_host() then return end

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

    local shot, why = OF.save.world_take()
    if shot == nil then

        if why ~= nil and why ~= "" then
            OF.notify.show(why, "warn", 6)
        end
        return false
    end
    castleWas = shot

    if OF.util.asks(OF.save, "world_pack") then
        local packed = OF.save.world_pack(shot)
        if packed ~= nil then OF.util.store(CASTLE_KEY, packed) end
    end

    speedrun.castleNote = true
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

    local mode = speedrun.mode()
    return mode == speedrun.MODE_LEVEL or mode == speedrun.MODE_STAR
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

    speedrun.note("Back to the start - the attempt is yours to retake",
        "info")
end

function speedrun.back_to_start()
    if not speedrun.retries_on_death() then return false end
    if not OF.util.can_play(0, speedrun.KIND_RUN) then return false end
    local want = death_destination()
    if want == nil then return false end
    owed = nil
    local putBack = OF.net.warp_local(want.level, want.area, want.act, nil,
        "Could not put you back at the start of that level.")
    if putBack and OF.util.asks(OF.gamemodes, "give_full_health") then
        OF.gamemodes.give_full_health()
    end
    if putBack then
        speedrun.note("Back to the start - the attempt is yours to retake", "info")
    end
    return putBack == true
end

speedrun.RETRY_HOLD = L_TRIG or 0x0020
speedrun.RETRY_BUTTON = B_BUTTON or 0x4000
speedrun.RETRY_ACTION = { pad = "L+B", key = "LShift+," }

function speedrun.retry_press()
    if state() ~= speedrun.ACTIVE then return false end
    if OF.util.menu_has_screen() then return false end
    if not speedrun.retries_on_death() then return false end
    if not OF.util.asks(OF.input, "pressed") or not OF.input.held(speedrun.RETRY_HOLD)
        or not OF.input.pressed(speedrun.RETRY_BUTTON) then
        return false
    end
    if not speedrun.back_to_start() then return false end
    speedrun.retries = (speedrun.retries or 0) + 1
    return true
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not speedrun.retries_on_death() then return end

    if not OF.util.can_play(0, speedrun.KIND_RUN) then return end

    owed = death_destination()
end)

local seatedByRun = false

local function best_seat()
    local counting = speedrun.counts_stars()
    local best, bestRank, bestNear = nil, nil, nil
    for _, globalIndex in ipairs(OF.spectate.watchable()) do
        local li = OF.util.local_from_global(globalIndex)
        if li ~= nil and li ~= 0 and on_the_line(li)
            and speedrun.posted_time(li) <= 0 and OF.util.can_play(li, speedrun.KIND_RUN) then
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

    if not OF.panel.open and speedrun.retry_press() then
        m.controller.buttonPressed = 0
        return
    end

    if current == speedrun.COUNTDOWN and OF.util.can_play(0, speedrun.KIND_RUN) then
        OF.input.hold(m)
    end
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

speedrun.star_glyph = star_glyph

local TALLY_HOLD = "speedrun"
local function hold_vanilla_counter(hide)
    OF.util.hud_hide(HUD_DISPLAY_FLAG_STAR_COUNT, TALLY_HOLD, hide and true or false)
end

speedrun.hold_vanilla_counter = hold_vanilla_counter

local function render_tally()

    local target = speedrun.star_target()
    if target <= 0 then
        speedrun.tallyWidth = 0
        return
    end
    local text = tostring(speedrun.stars_got(0)) .. "/" .. tostring(target)

    local face = OF.util.title_face(text)
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

speedrun.LOOK = {
    TONE = {
        best = "best", aheadGain = "good", aheadLose = { "good", 0.45 },
        behindGain = { "bad", 0.40 }, behindLose = "bad", pb = "info",
        none = "ink2", upcoming = "mute",
    },

    CLOCK_ROWS = 5,

    PANEL_ROWS = 34,
    PANEL_W = 320, PAD = 12, ROW = 22, SPLIT_ROWS = 5, RACE_ROWS = 8,

    CARD_W = 440, CARD_Y = 0.60,

    ENTER = 8, EXIT = 5, POP = 8, FLASH = 6, GO = 24, CARD_HOLD = 150, BAR = 18,

    LOAD_WAIT = 8,
}

function speedrun.tone(name)
    local t = speedrun.LOOK.TONE[name]
    if t == nil then return name or "ink" end
    if type(t) == "table" then return OF.hud.lighten(t[1], t[2]) end
    return t
end

speedrun.hudLog = { times = {} }

local function log_time(text, role)
    local times = speedrun.hudLog.times
    times[#times + 1] = { text = text, role = role }
end

local function punch(age, peak)
    local H = OF.hud
    if age == nil or age < 0 or age >= speedrun.LOOK.POP then return 1 end
    if age < 2 then return 1 + (peak - 1) * age / 2 end
    if age < 4 then return peak end
    return peak - (peak - 1) * H.ease.out_cubic((age - 4) / 4)
end

function speedrun.clock_top()
    local _, sh = OF.hud.screen()
    return math.floor(speedrun.LOOK.CLOCK_ROWS * sh / 240 + 0.5)
end

function speedrun.panel_top()
    local H = OF.hud
    local _, sh = H.screen()
    return math.floor(speedrun.LOOK.PANEL_ROWS * sh / 240 + 0.5) + H.S.s2
end

function speedrun.watched_runner()
    if not watching() or startLine == nil then return nil end
    local target = OF.spectate.target
    local li = target ~= nil and OF.util.local_from_global(target) or nil
    if li == nil or li == 0 or not on_the_line(li) then return nil end
    return li
end

function speedrun.clock_reading()
    local li = speedrun.watched_runner()
    if li ~= nil then
        local posted = speedrun.posted_time(li)
        if posted > 0 then return speedrun.format_time(posted), "good", "good", posted, li end
        local clock = speedrun.raceClock or 0
        return speedrun.format_time(clock), "ink", nil, clock, li
    end
    if speedrun.run_excluded(0) then return OF.lang.t("not racing"), "out", nil, nil, nil end
    if not speedrun.in_this_run() then return speedrun.format_time(0), "mute", nil, 0, nil end
    local frames = speedrun.timer or 0
    if speedrun.finished then
        if speedrun.lastPbBeaten then
            return speedrun.format_time(frames), "pb", "pb", frames, 0
        end
        return speedrun.format_time(frames), "good", "good", frames, 0
    end

    local best = speedrun.current_best()
    if best ~= nil and frames > best then
        return speedrun.format_time(frames), "behindLose", nil, frames, 0
    end
    return speedrun.format_time(frames), "ink", nil, frames, 0
end

function speedrun.reserve_clock_row()
    local current = state()
    if current ~= speedrun.ACTIVE and current ~= speedrun.RESULTS then return false end

    if not speedrun.shows_run() then return false end
    local H = OF.hud
    if H == nil or not OF.util.asks(OF.util, "hud_claim") then return false end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    local bottom = speedrun.clock_top() + H.CHIP_H + H.S.s2
    local y = OF.util.hud_claim(0, 0)
    if bottom > y then OF.util.hud_push(bottom - y) end
    return true
end

local function draw_clock(now)
    local H = OF.hud
    local LOOK = speedrun.LOOK
    local text, tone, tint, frames, who = speedrun.clock_reading()
    local top = speedrun.clock_top()
    local st = { clockText = text, clockTone = speedrun.tone(tone), countUp = true, top = top }
    if tint ~= nil then st.clockTint = speedrun.tone(tint) end
    H.top_cluster(st, now)
    local L = H.cluster_layout(st)

    local last = speedrun.mySplits[#speedrun.mySplits]
    if who == 0 and last ~= nil and last.kind ~= "final" then
        local age = now - (last.at or now)
        if age >= 0 and age < LOOK.BAR then
            local k = 1 - H.ease.in_cubic(age / LOOK.BAR)
            local w = L.chipW * (0.3 + 0.7 * H.ease.out_back(math.min(1, age / 6)))
            H.rect(L.cx - w / 2, top + H.CHIP_H + 2, w, 2, speedrun.tone(last.state), 255 * k)
        end
    end
    speedrun.hudLog.clock = { x = L.chipX, y = top, w = L.chipW, h = H.CHIP_H,
        text = text, frames = frames, who = who }
    if frames ~= nil then log_time(text, "clock") end
end

function speedrun.run_name()
    local mode = speedrun.mode()
    if mode == speedrun.MODE_STARS then
        local target = speedrun.star_target()
        for _, entry in ipairs(speedrun.STAR_TARGETS) do
            if entry.stars == target then return OF.lang.t(entry.name) end
        end
        return OF.lang.fill("@ Star", tostring(target))
    end
    local level = gGlobalSyncTable.ofRunLevel or 0
    local title = gGlobalSyncTable.ofRunTitle
    if mode == speedrun.MODE_STAR then
        local course = OF.util.course_of_level(level)
        local name = course ~= nil and get_star_name(course, gGlobalSyncTable.ofRunAct or 1) or nil
        if type(name) == "string" and name ~= "" then return speedrun.star_title(name) end
    end
    if type(title) == "string" and title ~= "" then
        return (string.match(title, "^(.-) %- ") or title)
    end
    return OF.lang.t("Speedrun")
end

function speedrun.objective_line()
    local mode = speedrun.mode()
    if mode == speedrun.MODE_STARS then
        local target = speedrun.star_target()
        if target > 0 then
            return OF.lang.fill("Collect @ stars, then beat Bowser in the Sky", tostring(target))
        end
        return OF.lang.t("No stars at all - straight to Bowser in the Sky")
    end
    local level = gGlobalSyncTable.ofRunLevel or 0
    if mode == speedrun.MODE_STAR then
        local course = OF.util.course_of_level(level)
        return OF.lang.fill("Only this star counts - @",
            course ~= nil and OF.util.course_name(course) or OF.lang.t("this course"))
    end
    if speedrun.is_key_stage(level) then return OF.lang.t("Whoever takes the key wins") end
    return OF.lang.t("First star wins")
end

function speedrun.options_note(all)
    local parts = {}
    if all or not speedrun.keeps_text() then
        parts[#parts + 1] = speedrun.keeps_text() and OF.lang.t("Text boxes kept")
            or OF.lang.t("Text boxes skipped")
    end
    if all or speedrun.non_stop() then
        parts[#parts + 1] = speedrun.non_stop() and OF.lang.t("Non-Stop")
            or OF.lang.t("A star takes you out of the level")
    end
    if all or speedrun.opens_doors() then
        parts[#parts + 1] = speedrun.opens_doors() and OF.lang.t("Doors open as you run up")
            or OF.lang.t("Doors as the game has them")
    end
    return table.concat(parts, " - ")
end

function speedrun.loading_count()
    local loading, total = 0, 0
    for _, entry in ipairs(racers()) do
        total = total + 1
        local np = entry.np
        if np ~= nil and (np.currAreaSyncValid == false or np.currLevelSyncValid == false) then
            loading = loading + 1
        end
    end
    return loading, total
end

function speedrun.field_ready(waited)
    if (waited or 0) >= COUNTDOWN_SECONDS + speedrun.LOOK.LOAD_WAIT then return true end
    local loading = speedrun.loading_count()
    return loading == 0
end

function speedrun.intro_card(seconds, phase)
    local card = { round = OF.lang.t("SPEEDRUN"), name = speedrun.run_name(),
        objective = speedrun.objective_line(), rules = {}, tone = "gold" }
    local loading, total = speedrun.loading_count()
    if seconds == nil and loading > 0 then
        card.rules[#card.rules + 1] = OF.lang.fill("Waiting for @ of @ to finish loading",
            tostring(loading), tostring(total))
    end
    local note = speedrun.options_note(true)
    if note ~= "" then card.rules[#card.rules + 1] = note end

    if speedrun.castleNote then
        card.rules[#card.rules + 1] = OF.lang.t("The castle is locked for this run - it goes back at the end")
    end
    if type(seconds) == "number" and seconds >= 1 then
        phase = phase or 0
        card.count = { n = seconds, frac = math.max(0, math.min(1, phase / 30)) }
        card.left = math.max(0, math.min(1, (seconds - phase / 30) / COUNTDOWN_SECONDS))
    end
    card.hints = { { "pause", OF.lang.t("Controls & rules") } }

    local mode = speedrun.mode()
    if mode == speedrun.MODE_LEVEL or mode == speedrun.MODE_STAR then
        card.hints[#card.hints + 1] = { speedrun.RETRY_ACTION, OF.lang.t("Retry") }
    end
    return card
end

local function render_countdown(now)
    local remaining = COUNTDOWN_FRAMES - speedrun.timer
    local seconds = math.max(1, math.ceil(remaining / 30))
    if seconds ~= speedrun.countDigit then
        speedrun.countDigit, speedrun.countPhase = seconds, 0
    else
        speedrun.countPhase = speedrun.countPhase + 1
    end
    local held = remaining <= 0
    local card = speedrun.intro_card(not held and seconds or nil, speedrun.countPhase)
    local age = now - (speedrun.countAt or now)
    local H = OF.hud
    if H.intro_card(card, age) and OF.util.asks(OF.gamemodes, "countdown_controls") then
        OF.gamemodes.countdown_controls(nil, age)
    end
    speedrun.hudLog.card = { kind = "countdown", name = card.name, held = held }
end

local function render_go(now)
    if speedrun.goAt == nil then return end
    local H = OF.hud
    local age = now - speedrun.goAt
    if age < 0 or age > speedrun.LOOK.GO then return end
    if age < speedrun.LOOK.EXIT then
        local card = speedrun.intro_card(nil, 0)
        card.hints, card.rules = nil, {}
        H.intro_card(card, H.MOTION.base * (1 - age / speedrun.LOOK.EXIT))
    end
    H.go(age)
end

local function draw_splits(x, y, now)
    local H = OF.hud
    local LOOK = speedrun.LOOK
    local book = speedrun.split_book()
    local rows = speedrun.split_rows(LOOK.SPLIT_ROWS)
    local route = speedrun.routeTaken and speedrun.runRoute or book.best
    local sob = speedrun.sum_of_best(route, book.golds)
    local prevDiff, prevTone = speedrun.previous_segment()
    if #rows == 0 and sob == nil then return y end
    local w, pad, rowH = LOOK.PANEL_W, LOOK.PAD, LOOK.ROW
    local _, _, capH = H.cap("body", 1, "A")
    local rowsY = y + pad + capH + 8
    local footY = rowsY + #rows * rowH + 4
    local h = footY + 6 + rowH * 2 + pad / 2 - y
    H.plate(x, y, w, h, { strip = "gold" })
    local splitsWord = OF.lang.t("SPLITS")
    local wordW = H.ink_width(splitsWord, "body")
    H.text_base(splitsWord, x + w - pad, y + pad + capH, "body", "mute", 230, "right")
    local _, kb = H.cap("body", 1, "A")

    local head = speedrun.run_name()
    if speedrun.mode() ~= speedrun.MODE_STARS then
        head = speedrun.course_short(gGlobalSyncTable.ofRunLevel or 0) or head
    end
    H.name(string.upper(head), x + pad, y + pad + capH - kb, "body", "gold", 255,
        "left", w - pad * 2 - wordW - H.S.s3, { key = "sr-splits-head" })
    local timeX = x + w - pad
    local deltaX = timeX - 78
    local nameRoom = deltaX - 52 - (x + pad + 10)
    for index, row in ipairs(rows) do
        local top = rowsY + (index - 1) * rowH
        local mid = top + rowH / 2
        local age = row.split ~= nil and (now - (row.split.at or now)) or 99
        local k = H.ease.out_cubic(math.min(1, math.max(0, age) / H.MOTION.fast))
        local a = 255 * k
        local slide = (1 - k) * 10
        if row.state == "best" then

            if age < LOOK.FLASH then
                H.plate(x + 4, top, w - 8, rowH - 1, { lit = true, tint = "best",
                    alpha = 1 - age / LOOK.FLASH })
            end
            H.diamond(x + pad + 3, mid, 6, "best", a)
        end
        local nameTone = row.upcoming and "mute" or "ink"
        H.name_mid(row.name, x + pad + 10 + slide, mid, "row", nameTone, a, "left",
            nameRoom, { key = "sr-split" .. index })
        if row.delta ~= nil then
            local mult = (index == #rows or not rows[index + 1] or rows[index + 1].upcoming)
                and punch(age, 1.25) or 1
            H.digits_mid(speedrun.delta_text(row.delta), deltaX, mid, "row",
                speedrun.tone(row.state), a, "right", mult)
        end
        local text = speedrun.format_time(row.frames)
        H.digits_mid(text, timeX, mid, "row", row.upcoming and "mute" or "ink2", a, "right")
        log_time(text, row.upcoming and "route" or "split")
    end
    H.rect(x + pad, footY, w - pad * 2, 1, "edge", 40)
    local mid1 = footY + 6 + rowH / 2
    local mid2 = mid1 + rowH
    H.text_mid(OF.lang.t("Previous segment"), x + pad, mid1, "body", "mute", 230, "left")
    H.digits_mid(prevDiff ~= nil and speedrun.delta_text(prevDiff) or "-", timeX, mid1, "row",
        speedrun.tone(prevTone or "none"), 255, "right")
    H.text_mid(OF.lang.t("Sum of best"), x + pad, mid2, "body", "mute", 230, "left")
    local sobText = sob ~= nil and speedrun.format_time(sob) or "-"
    H.digits_mid(sobText, timeX, mid2, "row", "ink2", 255, "right")
    if sob ~= nil then log_time(sobText, "sob") end
    speedrun.hudLog.splits = { x = x, y = y, w = w, h = h, rows = #rows }
    return y + h
end

local function draw_race(x, y, now)
    local H = OF.hud
    local LOOK = speedrun.LOOK
    local rows = speedrun.race_rows()
    if #rows == 0 then return y end
    local most = LOOK.RACE_ROWS
    local shown = rows
    if #rows > most then

        shown = {}
        for index = 1, most do shown[index] = rows[index] end
        for index = most + 1, #rows do
            if rows[index].you then shown[most] = rows[index] end
        end
    end
    local stars = speedrun.counts_stars()
    local watched = speedrun.watched_runner()
    local w, pad, rowH = LOOK.PANEL_W, LOOK.PAD, LOOK.ROW
    local _, _, capH = H.cap("body", 1, "A")
    local rowsY = y + pad + capH + 8
    local h = rowsY + #shown * rowH + pad / 2 - y
    H.plate(x, y, w, h, { strip = "gold" })
    H.text_base(OF.lang.t("RACE"), x + pad, y + pad + capH, "body", "gold", 255)
    local finished = 0
    for _, row in ipairs(rows) do if row.posted > 0 then finished = finished + 1 end end
    H.text_base(OF.lang.fill("@ of @ home", tostring(finished), tostring(#rows)), x + w - pad,
        y + pad + capH, "body", "mute", 230, "right")
    local placeX = x + pad + 14
    local nameX = placeX + 8
    local gapX = x + w - pad
    local splitX = gapX - 70 - 64
    local starX = splitX - 10
    local nameRoom = (stars and (starX - 26) or (splitX - 8)) - nameX
    for index, row in ipairs(shown) do
        local top = rowsY + (index - 1) * rowH
        local mid = top + rowH / 2
        local strip = row.you and "gold" or (row.localIndex == watched and "info" or nil)
        if strip ~= nil then
            H.plate(x + 4, top, w - 8, rowH - 1, { lit = row.you, strip = strip, alpha = 0.8 })
        end
        local tone = row.posted > 0 and "ink" or "ink2"
        local placeTone = (row.posted > 0 and H.PODIUM[row.place]) or "mute"
        H.digits_mid(tostring(row.place), placeX, mid, "row", placeTone, 255, "right")
        H.name_mid(row.name or "", nameX, mid, "row", tone, 255, "left", nameRoom,
            { key = "sr-race" .. index })
        if stars then
            H.digits_mid(tostring(row.got or 0), starX - 12, mid, "row", "ink2", 255, "right")
            H.draw_glyph("star", starX - 4, mid, 9, "gold", 255)
        end
        if row.split ~= nil then
            H.name_mid(row.split, splitX, mid, "row", "mute", 230, "left", 64,
                { key = "sr-race-split" .. index })
        end
        local right = nil
        if row.place == 1 then
            if row.posted > 0 then right = speedrun.format_time(row.posted) end
        elseif row.gap ~= nil then
            right = speedrun.delta_text(row.gap)
        end
        if right ~= nil then
            H.digits_mid(right, gapX, mid, "row", "ink2", 255, "right")
            log_time(right, row.place == 1 and "posted" or "gap")
        end
    end
    speedrun.hudLog.race = { x = x, y = y, w = w, h = h, rows = #shown }
    return y + h
end

function speedrun.finish_card()
    if not speedrun.finished or not speedrun.in_this_run() then return nil end
    local frames = speedrun.timer or 0
    local card = { kicker = string.upper(speedrun.run_name()), time = speedrun.format_time(frames),
        timeTone = "ink", word = OF.lang.t("FINISH"), wordTone = "good", pb = speedrun.lastPbBeaten }
    local best = speedrun.lastBest
    if speedrun.lastPbBeaten and best ~= nil then
        card.timeTone, card.word, card.wordTone = "pb", OF.lang.t("NEW SESSION BEST"), "pb"
        card.delta, card.deltaTone = speedrun.delta_text(frames - best), "best"
    elseif speedrun.lastPbBeaten then
        card.timeTone = "pb"
        card.line = OF.lang.t("First time this session")
    elseif best ~= nil then
        card.delta, card.deltaTone = speedrun.delta_text(frames - best), "behindLose"
        card.line = OF.lang.t("on your session best")
    end
    if speedrun.underRecord ~= nil then
        card.record = OF.lang.fill("Under the session record by @", speedrun.gap_text(speedrun.underRecord))
    end
    if speedrun.field_size() >= 2 then
        local place = nil
        for index, row in ipairs(speedrun.results()) do
            if row.localIndex == 0 then place = index end
        end
        if place ~= nil then
            card.place = OF.lang.fill("@ of @", OF.hud.ordinal(place), tostring(speedrun.field_size()))
        end
    end
    local notes = {}
    local opts = speedrun.options_note(false)
    if opts ~= "" then notes[#notes + 1] = opts end
    if speedrun.timedAtCredits then notes[#notes + 1] = OF.lang.t("Timed at the credits") end
    card.note = table.concat(notes, " - ")
    return card
end

function speedrun.results_card()
    local card = { kicker = string.upper(speedrun.run_name()), word = OF.lang.t("RACE OVER"),
        wordTone = "gold" }
    card.line = speedrun.final_line()
    local record = speedrun.published_record()
    if record ~= nil then
        card.record = OF.lang.fill("Session record @ - @", speedrun.format_time(record.time), record.name)
    end
    return card
end

function speedrun.vanilla_card_up()
    local m = gMarioStates[0]
    return m ~= nil and ACT_EXIT_LAND_SAVE_DIALOG ~= nil and m.action == ACT_EXIT_LAND_SAVE_DIALOG
end

local function draw_card(card, k, rise, pop)
    local H = OF.hud
    local LOOK = speedrun.LOOK
    local sw, sh = H.screen()
    local w = LOOK.CARD_W
    local pad = H.CARD_PAD
    local _, _, capC = H.cap("body", 1, "A")
    local _, _, capT = H.cap("title", 1, "0")
    local _, _, capB = H.cap("body", 1, "A")
    local lines = 0
    if card.line ~= nil or card.delta ~= nil or card.word ~= nil then lines = lines + 1 end
    if card.record ~= nil then lines = lines + 1 end
    if card.note ~= nil and card.note ~= "" then lines = lines + 1 end
    local h = pad + capC + 14 + (card.time ~= nil and (capT + 14) or 0) + lines * (capB + 10) + pad - 6

    local widest = 0
    if card.note ~= nil and card.note ~= "" then widest = H.ink_width(card.note, "body") end
    if card.line ~= nil then widest = math.max(widest, H.ink_width(card.line, "body") + 80) end
    if card.record ~= nil then widest = math.max(widest, H.ink_width(card.record, "body")) end
    w = math.min(sw - H.MARGIN * 2, math.max(w, widest + pad * 2))
    local x = sw / 2 - w / 2
    local y = sh * LOOK.CARD_Y - h / 2 + rise
    local a = 255 * k
    local strip = card.pb and "pb" or "gold"
    H.plate(x, y, w, h, { alpha = k, lit = card.pb == true })
    H.rect(x + 2, y, w - 4, 3, speedrun.tone(strip), a)
    local base = y + pad + capC
    local placeW = 0
    if card.place ~= nil then
        placeW = H.ink_width(card.place, "body") + H.S.s3
        H.text_base(card.place, x + w - pad, base, "body", "ink2", a, "right")
    end
    local _, kb = H.cap("body", 1, "A")
    H.name(card.kicker or "", x + pad, base - kb, "body", "gold", a, "left", w - pad * 2 - placeW,
        { key = "sr-card-kicker" })
    base = base + 14
    if card.time ~= nil then
        local mid = base + capT / 2
        H.digits_mid(card.time, sw / 2, mid, "title", speedrun.tone(card.timeTone), a, "center", pop)
        log_time(card.time, "card")
        base = base + capT + 14
    end
    local function line(parts)
        local total = 0
        for _, part in ipairs(parts) do
            part.w = part.digits and H.digits_width(part.text, "body") or H.ink_width(part.text, "body")
            total = total + part.w
        end
        total = total + 10 * (#parts - 1)
        local lx = sw / 2 - total / 2
        for _, part in ipairs(parts) do

            if part.digits then
                H.digits_mid(part.text, lx, base + capB / 2, "body", part.tone, a, "left")
            else
                H.text_base(part.text, lx, base + capB, "body", part.tone, a)
            end
            lx = lx + part.w + 10
        end
        base = base + capB + 10
    end
    local first = {}
    if card.word ~= nil and card.time ~= nil then first[#first + 1] = { text = card.word, tone = speedrun.tone(card.wordTone) } end
    if card.delta ~= nil then
        first[#first + 1] = { text = card.delta, tone = speedrun.tone(card.deltaTone), digits = true }
    end
    if card.line ~= nil then first[#first + 1] = { text = card.line, tone = "ink2" } end
    if card.time == nil and card.word ~= nil then
        H.text_mid(card.word, sw / 2, base + capT / 2, "title", speedrun.tone(card.wordTone), a, "center")
        base = base + capT + 14
        first = {}
        if card.line ~= nil then first[1] = { text = card.line, tone = "ink" } end
    end
    if #first > 0 then line(first) end
    if card.record ~= nil then line({ { text = card.record, tone = "gold" } }) end
    if card.note ~= nil and card.note ~= "" then
        H.text_base(card.note, sw / 2 - H.ink_width(card.note, "body") / 2, base + capC,
            "body", "mute", a)
    end
    speedrun.hudLog.card = { kind = card.time ~= nil and "finish" or "results", x = x, y = y,
        w = w, h = h, word = card.word, line = card.line, place = card.place }
end

local function render_finish(now)
    local LOOK = speedrun.LOOK
    local H = OF.hud
    local card = speedrun.finish_card()
    if card == nil then return false end
    if speedrun.vanilla_card_up() then
        speedrun.cardAt = nil
        return true
    end
    if speedrun.cardAt == nil then speedrun.cardAt = now end
    local age = now - speedrun.cardAt
    local k = H.ease.out_cubic(math.min(1, age / LOOK.ENTER))
    local rise = (1 - k) * 12
    if state() == speedrun.ACTIVE then
        if age > LOOK.CARD_HOLD + LOOK.EXIT then return true end
        if age > LOOK.CARD_HOLD then
            k = 1 - H.ease.in_cubic((age - LOOK.CARD_HOLD) / LOOK.EXIT)
            rise = 0
        end
    end
    draw_card(card, k, rise, punch(age - 2, 1.18))
    return true
end

local function render_results(now)
    local H = OF.hud
    if speedrun.vanilla_card_up() then return end
    local age = now - (speedrun.resultsAt or now)
    local card = speedrun.finish_card()
    if card ~= nil then
        local word = (card.pb and speedrun.lastBest ~= nil) and "NEW BEST" or "FINISHED"
        H.result(card.pb and "draw" or "win", card.place, age, OF.lang.t(word))
        speedrun.hudLog.band = { word = word, sub = card.place }
        render_finish(now)
        return
    end
    local rc = speedrun.results_card()
    H.result("win", rc.line, age, OF.lang.t("RACE OVER"))
    speedrun.hudLog.band = { word = "RACE OVER", sub = rc.line }
    if rc.record ~= nil then
        local k = H.ease.out_cubic(math.min(1, math.max(0, age - H.MOTION.base) / speedrun.LOOK.ENTER))
        draw_card({ kicker = rc.kicker, line = rc.record }, k, (1 - k) * 12, 1)
    end
end

local function render_watch_hint()
    if seatedByRun and watching() then return end
    if not speedrun.can_watch() then return end
    local H = OF.hud
    local list = { { "watch", OF.lang.t("Watch the runners") } }
    local sw, sh = H.screen()
    local y = H.corner_hint_y()
    local width = H.hint_row_width(list)
    if sw - H.MARGIN - width < OF.util.camera_icon_left(sw, sh) then
        y = math.min(y, OF.util.camera_icon_top(sh) - H.HINT_SIZE - 4)
    end
    H.hints(list, { y = y })
    speedrun.hudLog.hint = { y = y, w = width }
end

speedrun.COIN_HOLD = "speedrun-coins"
function speedrun.render_coins()
    local m, np = gMarioStates[0], gNetworkPlayers[0]
    if m == nil or np == nil or (np.currCourseNum or 0) < 1 then return 0 end
    if OF.util.asks(OF.modifiers, "coin_hit_hud") and OF.modifiers.coin_hit_hud() ~= nil then
        return 0
    end
    local textures = _G["gTextures"]
    local icon = textures ~= nil and textures.coin or nil
    return OF.util.corner_counter(icon, tostring(m.numCoins or 0), 255, 255, 255,
        speedrun.tallyWidth or 0, 1.0) or 0
end

speedrun.NOTE_TONE = { good = "good", warn = "warn", bad = "bad", info = "ink" }
speedrun.NOTE_ICON = { good = "capture", warn = "bomb", bad = "kill", info = "score" }
function speedrun.note(message, kind, value, second)
    local H = OF.hud
    if state() ~= speedrun.OFF and H ~= nil and type(H.feed_push) == "function" then
        H.feed_push({ left = OF.lang.fill(message, value, second),
            leftColour = speedrun.NOTE_TONE[kind] or "ink",
            icon = speedrun.NOTE_ICON[kind] or "score", mine = true })
        if OF.util.asks(OF.notify, "buzz") then OF.notify.buzz(kind) end
        return "feed"
    end
    OF.notify.show(message, kind, nil, value, second)
    return "toast"
end

local function render_column(now)
    local H = OF.hud
    local x, y = H.MARGIN, speedrun.panel_top()
    local runner = speedrun.in_this_run() and not speedrun.run_excluded(0)
        and speedrun.watched_runner() == nil
    if runner then
        local under = draw_splits(x, y, now)
        if under > y then y = under + H.S.s2 end
    end
    if not runner or speedrun.field_size() >= 2 then draw_race(x, y, now) end
end

local function render()
    local current = state()
    local live = current ~= speedrun.OFF

    local running = live and speedrun.shows_run()

    hold_vanilla_counter(running)
    OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, speedrun.COIN_HOLD, running)
    if not running then
        speedrun.tallyWidth = 0

        if live and not OF.util.menu_has_screen() then
            djui_hud_set_resolution(RESOLUTION_DJUI)
            djui_hud_set_font(FONT_NORMAL)
            render_watch_hint()
        end
        return
    end
    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    local H = OF.hud
    local now = H.now()
    local log = speedrun.hudLog
    log.clock, log.card, log.splits, log.race, log.hint, log.band = nil, nil, nil, nil, nil, nil
    for index = #log.times, 1, -1 do log.times[index] = nil end

    speedrun.tallyWidth = 0
    if speedrun.counts_stars() then render_tally() end
    speedrun.tallyWidth = (speedrun.tallyWidth or 0) + speedrun.render_coins()

    if current == speedrun.COUNTDOWN then
        render_countdown(now)
    else
        draw_clock(now)
        render_column(now)
        local _, sh = H.screen()
        H.feed_draw(now, math.max(H.MARGIN, OF.util.counters_bottom(sh) + H.S.s2))
        if current == speedrun.ACTIVE then
            render_go(now)
            render_finish(now)
        elseif current == speedrun.RESULTS then
            render_results(now)
        end
    end
    render_watch_hint()
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.net == nil or OF.net.register_action == nil then return end

    OF.net.register_action(speedrun.OPTS_ACTION, "speedrun", function(fromLocal, x, _, z)
        if not OF.util.is_host() then return false, "Only the host." end
        local preset = string.match(tostring(z), "^preset:(%a+)$")
        if preset ~= nil then return speedrun.apply_opt_preset(preset, fromLocal) end
        return speedrun.set_opt(tostring(z), tonumber(x), fromLocal)
    end)
    local panel = OF.panel
    if panel ~= nil and type(panel.PAGES) == "table" and panel.PAGES.runopts == nil then
        panel.PAGES.runopts = {
            title = "Speedrun settings", tab = "race", up = "starcount",
            build = function() return speedrun.build_opts_page(panel) end,
        }
    end
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
hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update, OF.LOCAL_MARIO)
hook_event(HOOK_ON_HUD_RENDER, render)

if HOOK_ON_HUD_RENDER_BEHIND ~= nil then
    hook_event(HOOK_ON_HUD_RENDER_BEHIND, function() speedrun.reserve_clock_row() end)
end

function speedrun.build_starcount_page(panel)
    local rows = {}

    table.insert(rows, panel.label_row(
        OF.lang.t("Every save is wiped to zero. Collect the count, then beat Bowser.")))

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Speedrun settings..."), 255, 255, 255, function()
            panel.go("runopts")
        end),
        "text boxes, what a star does and the doors, for every race"))

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

    table.insert(rows, panel.label_row(OF.lang.t(speedrun.TRICK_NOTE)))

    if OF.util.asks(OF.forge, "tracks_rows") then OF.forge.tracks_rows(panel, rows) end

    table.insert(rows, panel.back_row())
    return rows
end

speedrun.TRICK_NOTE = "Trick bans (BLJ, MIPS clip, DDD skip) are on your honour - not enforced"
speedrun.JOIN_MODES = "Join game modes"
speedrun.JOIN_RUNS = "Join speedruns"
speedrun.JOIN_BOTH = "Join game modes / speedruns"
speedrun.JOIN_MODES_HELP = "ticked: rounds of a game mode deal you in - unticked: you play on your own meanwhile"
speedrun.JOIN_RUNS_HELP = "ticked: speedruns count you as a runner - unticked: a race leaves you where you are"
speedrun.JOIN_BOTH_HELP = "left box (A): game modes deal you in - right box (Z): speedruns count you as a runner"
function speedrun.take_part_rows(panel)
    local rows = {}

    if speedrun.muted_out(0) then
        table.insert(rows, panel.with_help(panel.label_row(
            panel.tick(false, "") .. panel.tick(false, OF.lang.t(speedrun.JOIN_BOTH))
            .. "   " .. OF.lang.t("(Muted)")),
            "muted players take no part until they are raised"))
        return rows
    end
    local inModes = not speedrun.chose_out(0, speedrun.KIND_MODE)
    local inRuns = not speedrun.chose_out(0, speedrun.KIND_RUN)
    local built = panel.row(panel.tick(inModes, "") .. panel.tick(inRuns, OF.lang.t(speedrun.JOIN_BOTH)),
        255, 255, 255, function()
            if OF.util.asks(OF.outseat, "toggle") then
                OF.util.report(OF.outseat.toggle())
            else
                OF.util.report(speedrun.set_excluded(0, inModes, speedrun.KIND_MODE))
            end
        end)
    built.altAction = function()
        OF.util.report(speedrun.set_excluded(0, inRuns, speedrun.KIND_RUN))
    end
    built.altBox = 2
    built.actionLabel = "game modes"
    built.altLabel = "speedruns"
    table.insert(rows, panel.with_help(built, speedrun.JOIN_BOTH_HELP))
    return rows
end

speedrun.OPT_NOTES = {
    { text = "These settings keep their own bests - not mixed with vanilla runs",
      shownIf = function(pick)
          for _, row in ipairs(speedrun.OPTS) do
              if pick(row.key) ~= row.vanilla then return true end
          end
          return false
      end },
    { text = "Only a race is changed - the lobby gets its own back." },
}

function speedrun.build_opts_page(panel)
    local rows = {}
    local now = speedrun.opt_preset_now()
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("speedrun", OF.lang.t("Play it as"), 255, 220, 120, function()
            OF.util.report(speedrun.step_opt_preset())
        end),
        now ~= nil and OF.lang.t(now.name) or OF.lang.t("custom")),
        OF.lang.t(now ~= nil and now.help or "Vanilla is one press: the speedrun.com rules")))

    for _, row in ipairs(speedrun.OPTS) do
        if speedrun.opt_shown(row) then
            local key = row.key
            local step = speedrun.opt(key)
            local built = panel.gated_row("speedrun", OF.lang.t(row.name), 255, 220, 120,
                function()
                    OF.util.report(speedrun.set_opt(key, step % #row.steps + 1))
                end)
            built = panel.with_right(built, OF.lang.t(row.steps[step]))
            local help = row.stepHelp ~= nil and row.stepHelp[step] or row.help
            table.insert(rows, panel.with_key(panel.with_help(built, OF.lang.t(help)),
                "speedrun:" .. key))
        end
    end
    for _, note in ipairs(speedrun.OPT_NOTES) do
        if speedrun.opt_shown(note) then
            table.insert(rows, panel.label_row(OF.lang.t(note.text)))
        end
    end
    table.insert(rows, panel.label_row(OF.lang.t(speedrun.TRICK_NOTE)))
    table.insert(rows, panel.back_row())
    return rows
end

function speedrun.build_page(panel)
    local rows = {}

    for _, tick in ipairs(speedrun.take_part_rows(panel)) do
        table.insert(rows, tick)
    end

    local join = OF.util.asks(OF.gamemodes, "lobby_join_row")
        and OF.gamemodes.lobby_join_row(panel) or nil
    if join ~= nil then table.insert(rows, join) end

    local who = OF.util.asks(OF.whoplays, "list_door") and OF.whoplays.list_door(panel)
    if who then table.insert(rows, who) end

    if state() ~= speedrun.OFF then
        local title = gGlobalSyncTable.ofRunTitle or "a run"
        local runningRow = panel.label_row(OF.lang.fill("Running: @", title))
        if OF.util.asks(panel, "with_pulse") then
            runningRow = panel.with_pulse(runningRow, true)
        end
        table.insert(rows, runningRow)

        table.insert(rows, panel.gated_row("end_round",
            OF.lang.t("Stop the speedrun"), 255, 140, 90, function()

            speedrun.stop(false, 0)
            panel.close()
        end))
    end

    if OF.util.asks(OF.gamemodes, "is_open") and OF.gamemodes.is_open() then
        table.insert(rows, panel.gated_row("end_round",
            OF.lang.t("Stop the round"), 255, 140, 90, function()
                if OF.util.report(OF.gamemodes.stop(false, 0)) then panel.close() end
            end))
    end

    local modesDoor = panel.with_tone(panel.gated_row("speedrun",
        OF.lang.fill("Game modes (@)...", #OF.gamemodes.LIST),
        255, 255, 255, function() panel.go("gamemodes") end), "key")
    if OF.util.asks(panel, "live") then
        modesDoor = panel.with_pulse(modesDoor, panel.live("round", "nonstop",
            "queue", "rotation", "tournament", "session"))
    end
    table.insert(rows, panel.with_help(modesDoor,
        "round games, sorted by what you do in them - open one for its settings and its start"))

    if OF.util.asks(OF.bingo, "build_page") then
        local bingoDoor = panel.row(
            OF.util.asks(OF.bingo, "running") and OF.bingo.running()
                and OF.lang.t("Bingo - the lobby's card...")
                or OF.lang.t("Bingo - deal the lobby a card..."),
            255, 255, 255, function() panel.go("bingo") end)

        if OF.util.asks(panel, "live") then
            bingoDoor = panel.with_pulse(bingoDoor, panel.live("bingo"))
        end
        table.insert(rows, panel.with_help(bingoDoor,
            "twenty-five things to do, dealt to the whole lobby at once"))
    end

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("Speedruns")),
        "races against the clock for the whole lobby, from a whole-game category to one star"))

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Speedrun categories..."), 255, 215, 0, function()
            panel.go("starcount")
        end),
        "0, 1, 16, 70 and 120 Star, the two run beside them, and every race's settings"))

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",

        OF.lang.t("Race a level - first star wins..."), 255, 255, 255, function()
            panel.levelMode = "run"
            panel.runKind = "star"
            panel.go("groups")
        end),
        "pick any level and the first star anybody takes in it ends the race"))

    table.insert(rows, panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("Race Bowser - whoever takes the key wins..."),
        255, 200, 90, function()
            panel.levelMode = "run"
            panel.runKind = "key"
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

    if OF.util.asks(OF.together, "build_practice") or OF.util.asks(OF.tas, "build_page") then
        table.insert(rows, panel.with_help(panel.row(
            OF.lang.t("Practice and TAS..."), 255, 255, 255,
            function() panel.go("training") end),
            "save states, and your own inputs replayed"))
    end

    return rows
end

function speedrun.build_training_page(panel)
    local rows = {}
    if OF.util.asks(OF.together, "build_practice") then
        table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
            OF.lang.t("Practice room - drill a trick..."), 255, 255, 255,
            function() panel.go("practice") end),
            "save where you are standing, and repeat the bit you keep losing"))
    end

    if OF.util.asks(OF.tas, "build_page") then
        table.insert(rows, panel.with_help(panel.row(
            OF.lang.t("TAS tools - record and replay inputs..."), 255, 255, 255,
            function() panel.go("tas") end),
            "your own inputs, frame by frame - for practice, never for a race"))
    end
    table.insert(rows, panel.back_row())
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

        name = speedrun.star_title(name) or name

        local why = "starts the race on this star - the clock runs until "
            .. "somebody has it"
        if act == 7 then
            why = "a hundred coins, and a copy of the course each - nobody "
                .. "can take a coin you need"
        end
        table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("speedrun",
            act .. ". " .. name, 255, 255, 255, function()

                OF.util.report(speedrun.start_star(courseNum, act, 0))
                panel.close()
            end), best ~= nil and speedrun.format_time(best) or ""), why))
    end

    table.insert(rows, panel.with_help(panel.row(OF.lang.t("< Other course"),
        180, 180, 180, function()
            panel.starCourse = nil
        end),
        "back to the fifteen courses without leaving the page"))
    table.insert(rows, panel.back_row("speedrun"))
    return rows
end
