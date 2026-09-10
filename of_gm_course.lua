OF = OF or {}

local ROLE_RUNNING = "running"
OF.course = OF.course or {}

local course = OF.course

course.BOSSES = {

    { name = "King Bob-omb",   level = LEVEL_BOB, area = 1, act = 1, star = 0,
      instanced = true },
    { name = "King Whomp",     level = LEVEL_WF,  area = 1, act = 1, star = 0,
      instanced = true },

    { name = "Big Boo (the balcony)", level = LEVEL_BBH, area = 1, act = 1,
      star = 4, instanced = true },

    { name = "The Big Bully",  level = LEVEL_LLL, area = 1, act = 1, star = 0,
      instanced = true },
    { name = "Chill Bully",    level = LEVEL_SL,  area = 1, act = 2, star = 1,
      instanced = true },
    { name = "Eyerok",         level = LEVEL_SSL, area = 1, act = 4, star = 3,
      instanced = true },
    { name = "Wiggler",        level = LEVEL_THI, area = 1, act = 6, star = 5,
      instanced = true },

    { name = "Bowser",          level = LEVEL_BOWSER_1, area = 1, act = 1,
      instanced = true },
    { name = "Bowser again",    level = LEVEL_BOWSER_2, area = 1, act = 1,
      instanced = true },
    { name = "Bowser, finally", level = LEVEL_BOWSER_3, area = 1, act = 1,
      instanced = true },
}

local function running_course()
    local mode = OF.gamemodes.current()
    if mode == nil or mode.stages == nil then return nil end
    if not OF.gamemodes.is_running() then return nil end
    return mode
end

course.FLOOR_KEY = "ofCourseFloor"
course.STALL_SECONDS = 120

function course.stall_seconds(mode)
    if mode == nil then mode = OF.gamemodes.current() end
    local want = mode ~= nil and mode.stallSeconds or nil
    if type(want) ~= "number" or want <= 0 then return course.STALL_SECONDS end
    return math.floor(want)
end

function course.floor()
    return gGlobalSyncTable[course.FLOOR_KEY] or 0
end

local function cleared_by(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local done = (row ~= nil and row.ofScore) or 0
    if course.floor() > done then done = course.floor() end
    return done
end

local function my_stage_number()
    return cleared_by(0) + 1
end

local cameFrom = nil

local function remember_here()
    local np = gNetworkPlayers[0]
    if np == nil then return end
    cameFrom = { level = np.currLevelNum, area = np.currAreaIndex, act = np.currActNum }
end

local function go_home()
    local spot = cameFrom
    cameFrom = nil
    if spot == nil then return end

    local np = gNetworkPlayers[0]
    if np ~= nil and np.currLevelNum == spot.level
        and np.currAreaIndex == spot.area then
        return
    end

    OF.net.warp_local(spot.level, spot.area, spot.act)
end

course.ORDER_KEY = "ofCourseOrder"
course.wantShuffle = course.wantShuffle or false

function course.order()
    local packed = gGlobalSyncTable[course.ORDER_KEY]
    if packed == nil or packed == "" then return nil end
    local list = {}
    for piece in string.gmatch(tostring(packed), "[^,]+") do
        local index = math.floor(tonumber(piece) or 0)
        if index <= 0 then return nil end
        table.insert(list, index)
    end
    return #list > 0 and list or nil
end

local function coprime(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a == 1
end

function course.stride(count)
    if type(count) ~= "number" or count < 3 then return 1 end
    for step = math.floor(count / 2), count - 1 do
        if coprime(step, count) then return step end
    end
    return 1
end

function course.lane_for(globalIndex, count)
    if type(count) ~= "number" or count <= 1 then return 0 end
    local index = math.floor(tonumber(globalIndex) or 0)
    if index < 0 then index = 0 end
    return (index * course.stride(count)) % count
end

function course.lane_of(mode, localIndex)
    if mode == nil or mode.stages == nil then return 0 end
    if not mode.lanes then return 0 end
    return course.lane_for(network_global_index_from_local(localIndex or 0),
        #mode.stages)
end

course.INSTANCE_ACT = 7

function course.instance_act(globalIndex)
    local index = math.floor(tonumber(globalIndex) or 0)
    if index < 0 then index = 0 end
    return course.INSTANCE_ACT + index
end

function course.act_for(stage, globalIndex)
    if stage == nil then return nil end
    if not stage.instanced then return stage.act end
    return course.instance_act(globalIndex)
end

function course.index_at(mode, number, lane)
    if mode == nil or mode.stages == nil or number == nil then return nil end
    local count = #mode.stages
    if count == 0 or number < 1 or number > count then return nil end

    local position = number
    if lane ~= nil and lane > 0 then
        position = ((number - 1 + lane) % count) + 1
    end

    local order = course.order()
    return order ~= nil and order[position] or position
end

function course.stage_at(mode, number, lane)
    local at = course.index_at(mode, number, lane)
    if at == nil then return nil end
    return mode.stages[at]
end

function course.shuffled(count)

    OF.util.seed_random()
    local list = {}
    for i = 1, count do list[i] = i end
    for i = count, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

function course.publish_order(mode)
    if mode == nil or mode.stages == nil then return false end
    if not course.wantShuffle then
        OF.util.publish(course.ORDER_KEY, "")
        return true
    end
    local parts = {}
    for _, index in ipairs(course.shuffled(#mode.stages)) do
        table.insert(parts, tostring(index))
    end
    return OF.util.publish(course.ORDER_KEY, table.concat(parts, ","))
end

local function go_to(mode, number)
    local stage = course.stage_at(mode, number, course.lane_of(mode, 0))
    if stage == nil then return end
    local act = course.act_for(stage, network_global_index_from_local(0))

    if OF.util.asks(OF.gamemodes, "hold_here")
        and OF.util.asks(OF.gamemodes, "is_running")
        and OF.gamemodes.is_running() then
        OF.gamemodes.hold_here(stage.level, stage.area, act, stage.also)
    end

    OF.net.warp_local(stage.level, stage.area, act, stage.also)
end

course.ARENA = {

    [LEVEL_BOB] = {
        { bhv = id_bhvKingBobomb, model = E_MODEL_KING_BOBOMB,
          x = 1636, y = 4242, z = -5567, yaw = -147, params = 0x00000000 },
    },

    [LEVEL_WF] = {
        { bhv = id_bhvWhompKingBoss, model = E_MODEL_WHOMP,
          x = 0, y = 3584, z = 0, yaw = 0, params = 0x00000000 },
    },

    [LEVEL_BBH] = {
        { bhv = id_bhvBalconyBigBoo, model = E_MODEL_BOO,
          x = 1030, y = 1922, z = 2546, yaw = -90, params = 0x04000000 },
    },
}

function course.arena_for(stage)
    if stage == nil or not stage.instanced then return nil end
    return course.ARENA[stage.level]
end

local STOCK_FRAMES = 300
local stocking = 0

local function game_angle(degrees)
    local raw = (tonumber(degrees) or 0) * 0x8000
    if raw < 0 then return -math.floor(-raw / 180) end
    return math.floor(raw / 180)
end

local function stock_one(thing)
    local turn = game_angle(thing.yaw)
    return OF.util.optional("spawn_sync_object", nil,
        thing.bhv, thing.model, thing.x, thing.y, thing.z,
        function(o)

            o.oBehParams = thing.params or 0
            o.oMoveAngleYaw = turn
            o.oFaceAngleYaw = turn
        end)
end

function course.stock_tick()
    if stocking <= 0 then return false end
    stocking = stocking - 1

    local mode = running_course()
    if mode == nil then stocking = 0 return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if OF.gamemodes.role(0) ~= ROLE_RUNNING then stocking = 0 return false end

    local stage = course.stage_at(mode, my_stage_number(),
        course.lane_of(mode, 0))
    local want = course.arena_for(stage)
    if want == nil or #want == 0 then stocking = 0 return false end

    local np = gNetworkPlayers[0]
    if np == nil or np.currLevelNum ~= stage.level
        or np.currAreaIndex ~= stage.area then
        return false
    end

    if OF.util.optional("obj_get_first_with_behavior_id", nil,
        want[1].bhv) ~= nil then
        stocking = 0
        return false
    end

    if stock_one(want[1]) == nil then return false end
    for index = 2, #want do stock_one(want[index]) end

    stocking = 0
    return true
end

hook_event(HOOK_ON_LEVEL_INIT, function() stocking = STOCK_FRAMES end)
hook_event(HOOK_UPDATE, function() course.stock_tick() end)

local SPLIT_SEP = ","
function course.splits_of(localIndex)
    local packed = gPlayerSyncTable[localIndex].ofSplits
    local list = {}
    if packed == nil or packed == "" then return list end
    for piece in string.gmatch(tostring(packed), "[^" .. SPLIT_SEP .. "]+") do
        table.insert(list, math.floor(tonumber(piece) or 0))
    end
    return list
end

function course.total_of(localIndex)
    local total = 0
    for _, split in ipairs(course.splits_of(localIndex)) do
        total = total + split
    end
    return total
end

local function record_split(index)
    local already = course.total_of(0)

    local split = math.floor(OF.gamemodes.since_start()) - already
    if split < 0 then split = 0 end

    local list = course.splits_of(0)

    while #list < index - 1 do table.insert(list, 0) end
    list[index] = split

    local parts = {}
    for _, value in ipairs(list) do table.insert(parts, tostring(value)) end

    OF.util.publish_row(0, "ofSplits", (OF.util.pack_rows(parts, SPLIT_SEP)))
end

local BEST_PREFIX = "ofbest"
local function best_key(modeKey, stageName)
    return OF.util.storage_key(BEST_PREFIX .. "_" .. tostring(modeKey) .. "_",
        string.lower(tostring(stageName)))
end

function course.best_for(modeKey, stageName)
    local stored = mod_storage_load(best_key(modeKey, stageName), "")
    local value = tonumber(stored)
    if value == nil or value <= 0 then return nil end
    return math.floor(value)
end

function course.keep_best(modeKey, stageName, split)
    if split == nil or split <= 0 then return false end
    local had = course.best_for(modeKey, stageName)
    if had ~= nil and had <= split then return false end
    OF.util.store_integer(best_key(modeKey, stageName), math.floor(split))
    return true
end

function course.keep_bests()
    local mode = OF.gamemodes.current()
    if mode == nil or mode.stages == nil then return {} end
    local beaten = {}
    local splits = course.splits_of(0)
    for number, stage in ipairs(mode.stages) do
        local split = splits[number]
        if split ~= nil and split > 0 then
            if course.keep_best(mode.key, stage.name, split) then
                table.insert(beaten, stage.name)
            end
        end
    end
    return beaten
end

function course.board()
    local mode = OF.gamemodes.current()
    if mode == nil or mode.stages == nil then return {} end
    local last = #mode.stages

    local board = {}
    for _, entry in ipairs(OF.gamemodes.played()) do
        local index = entry.localIndex
        local done = cleared_by(index)
        local total = course.total_of(index)
        local finished = done >= last
        table.insert(board, {
            localIndex = index,
            name = entry.np.name,
            done = done,
            total = total,
            finished = finished,
            right = finished and OF.gamemodes.clock(total)
                or OF.lang.fill("@ of @", done, last),
        })
    end

    table.sort(board, function(a, b)
        if a.finished ~= b.finished then return a.finished end
        if a.finished then
            if a.total ~= b.total then return a.total < b.total end
        elseif a.done ~= b.done then
            return a.done > b.done
        end
        return a.name < b.name
    end)
    return board
end

function course.print_board()
    local mode = OF.gamemodes.current()
    if mode == nil or mode.stages == nil then return false end
    local board = course.board()
    if #board == 0 then return false end

    OF.util.chat(OF.lang.t("Boss by boss:"))
    for place, entry in ipairs(board) do
        local splits = course.splits_of(entry.localIndex)
        local done = gPlayerSyncTable[entry.localIndex].ofScore or 0

        local mine = entry.localIndex == 0

        local passed = {}
        do
            local lane = course.lane_of(mode, entry.localIndex)
            for position = 1, done do
                local at = course.index_at(mode, position, lane)
                if at ~= nil then passed[at] = true end
            end
        end

        local parts = {}
        for number, stage in ipairs(mode.stages) do
            local split = splits[number]
            if split ~= nil and split > 0 then
                local said = OF.lang.t(stage.name) .. " "
                    .. OF.gamemodes.clock(split)
                if mine then
                    local best = course.best_for(mode.key, stage.name)

                    if best ~= nil and best < split then
                        said = said .. OF.lang.fill(" (best @)",
                            OF.gamemodes.clock(best))
                    end
                end
                table.insert(parts, said)
            elseif passed[number] then

                table.insert(parts, OF.lang.t(stage.name) .. " "
                    .. OF.lang.t("--"))
            end
        end
        djui_chat_message_create("  " .. OF.util.accent() .. place .. ".\\#dcdcdc\\ "
            .. OF.util.plain(entry.name) .. "  " .. entry.right)
        if #parts > 0 then
            djui_chat_message_create("     \\#808080\\"
                .. table.concat(parts, "   "))
        end
    end

    local beaten = course.keep_bests()
    if #beaten > 0 then
        OF.util.chat("\\#a0ffa0\\" .. OF.lang.fill(
            "Your best yet: @", table.concat(beaten, ", ")))
    end
    return true
end

local function stage_covers(stage, level)
    if stage == nil then return false end
    if level == stage.level then return true end
    for _, other in ipairs(stage.also or {}) do
        if level == other then return true end
    end
    return false
end

course.stage_covers = stage_covers

function course.red_coins_here()
    local m = gMarioStates[0]
    local area = m ~= nil and m.area or nil
    local total = area ~= nil and area.numRedCoins or nil
    if type(total) ~= "number" or total <= 0 then return nil end

    if count_objects_with_behavior == nil or get_behavior_from_id == nil then
        return nil
    end
    local ok, left = pcall(count_objects_with_behavior,
        get_behavior_from_id(id_bhvRedCoin))
    if not ok or type(left) ~= "number" or left < 0 then return nil end

    local taken = total - left
    if taken < 0 then taken = 0 end
    if taken > total then taken = total end
    return taken, total
end

local function counts_for(stage, obj)
    if not stage_covers(stage, gNetworkPlayers[0].currLevelNum) then return false end
    if stage.star == nil then return true end
    local index = OF.util.star_act_index(obj)

    return index ~= nil and index == stage.star
end

local function others_needing(mode, stage, index)
    if stage == nil or index == nil then return 0 end
    if stage.instanced then return 0 end

    local waiting = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RUNNING)) do
        local i = entry.localIndex
        if i ~= 0 then

            local theirs = course.index_at(mode, cleared_by(i) + 1,
                course.lane_of(mode, i))
            local np = gNetworkPlayers[i]

            if theirs == index and np ~= nil
                and stage_covers(stage, np.currLevelNum) then
                waiting = waiting + 1
            end
        end
    end
    return waiting
end

local function on_interact(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_STAR_OR_KEY then return end

    local mode = running_course()
    if mode == nil then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    local number = my_stage_number()

    local lane = course.lane_of(mode, 0)
    local index = course.index_at(mode, number, lane)
    local stage = course.stage_at(mode, number, lane)
    if stage == nil or index == nil then return end
    if not counts_for(stage, obj) then return end

    local nextStage = course.stage_at(mode, number + 1, lane)
    local leaving = nextStage ~= nil
    OF.reserve.again(obj, others_needing(mode, stage, index), leaving)

    if nextStage == nil then
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    end

    OF.util.publish_row(0, "ofScore", number)
    record_split(index)

    OF.gamemodes.heal_checkpoint()

    if nextStage == nil then

        OF.notify.show("All of them, in @!", "good", 6,
            OF.gamemodes.clock(gPlayerSyncTable[0].ofGmTime or 0))
        OF.celebrate.win()
        return
    end

    OF.notify.show("@ down - on to @", "good", 4, stage.name, nextStage.name)
    OF.sounds.play(SOUND_MENU_STAR_SOUND)
    go_to(mode, number + 1)
end

hook_event(HOOK_ON_INTERACT, on_interact)

local capsWere = nil

local function write_caps(list, value)
    local wasUndo = OF.save.before
    local ok = OF.save.set_flags(list, value)
    OF.save.before = wasUndo
    return ok
end

function course.hold_caps(wanted)
    if not OF.util.is_host() then return false end
    if not OF.util.asks(OF.save, "set_flags") then return false end

    if wanted then
        if capsWere ~= nil then return false end
        local were, off = {}, {}
        for _, flag in ipairs(OF.save.CAP_FLAGS) do
            were[flag] = OF.save.has_flag(flag)
            if not were[flag] then table.insert(off, flag) end
        end
        capsWere = were
        if #off > 0 then write_caps(off, true) end
        return true
    end

    if capsWere == nil then return false end
    local were = capsWere
    capsWere = nil
    local back = {}
    for _, flag in ipairs(OF.save.CAP_FLAGS) do
        if not were[flag] then table.insert(back, flag) end
    end
    if #back > 0 then write_caps(back, false) end
    return true
end

function course.caps_held()
    return capsWere ~= nil
end

function course.make(spec)

    local stalledAt, stalledFor, lastFloor = -1, 0, 0

    local mode = {
        key = spec.key,
        name = spec.name,
        blurb = spec.blurb,

        how = spec.how,
        stages = spec.stages,
        minPlayers = spec.minPlayers or 1,

        countsUp = spec.countsUp == true,

        defaultLimit = spec.defaultLimit or 0,

        stallSeconds = spec.stallSeconds,

        lanes = spec.lanes ~= false,

        redCoins = spec.redCoins == true,

        fightsBosses = spec.fightsBosses == true,

        wantsCaps = spec.wantsCaps == true,

        holdsPerRunner = true,
        music = spec.music,

        noArena = true,

        maps = "own",

        resultsBy = "splits",

        caps = { canDraw = true },
        board = course.board,
        print_board = course.print_board,
    }

    function mode.setup(players)

        course.publish_order(mode)

        OF.util.publish(course.FLOOR_KEY, 0)

        if mode.wantsCaps then course.hold_caps(true) end

        for _, entry in ipairs(players) do
            OF.gamemodes.set_role(entry.localIndex, ROLE_RUNNING)
        end
    end

    function mode.on_start()

        OF.notify.show("@ stages. First one through wins.", "info", 6,
            #mode.stages)

        stalledAt, stalledFor, lastFloor = -1, 0, course.floor()

        if OF.gamemodes.role(0) ~= ROLE_RUNNING then return end

        remember_here()

        go_to(mode, my_stage_number())
    end

    function mode.late_join(localIndex)
        local np = gNetworkPlayers[localIndex]
        local number = course.floor() + 1

        local stage = course.stage_at(mode, number,
            course.lane_of(mode, localIndex))
        if np ~= nil and stage ~= nil then

            local sent, why = OF.net.warp_player(np.globalIndex,
                stage.level, stage.area,
                course.act_for(stage, np.globalIndex))
            if not sent then
                OF.notify.send_to(np.globalIndex,
                    "The round could not take you to @ - @", "bad", 6,
                    stage.name, why or OF.lang.t("no reason was given"))
            elseif number > 1 then

                OF.notify.send_to(np.globalIndex, "The round is on @ - @",
                    "warn", 6, stage.name, number .. " of " .. #mode.stages)
            end
        end
        return ROLE_RUNNING
    end

    function mode.cleanup()
        stocking = 0
        go_home()
        stalledAt, stalledFor, lastFloor = -1, 0, 0

        course.hold_caps(false)
    end

    function mode.update()
        local floor = course.floor()
        if floor == lastFloor then return end
        lastFloor = floor

        if OF.gamemodes.role(0) ~= ROLE_RUNNING then return end
        if (gPlayerSyncTable[0].ofScore or 0) >= floor then return end

        local number = my_stage_number()

        local stage = course.stage_at(mode, number, course.lane_of(mode, 0))
        if stage == nil then return end
        OF.notify.show("On to @", "warn", 5, stage.name)
        go_to(mode, number)
    end

    function mode.host_update()

        local furthest = 0
        for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RUNNING)) do
            local done = gPlayerSyncTable[entry.localIndex].ofScore or 0
            if done > furthest then furthest = done end
            if done >= #mode.stages then

                local took = gPlayerSyncTable[entry.localIndex].ofGmTime or 0
                if took > 0 then
                    OF.gamemodes.finish("@ takes the whole run - @ on the clock.",
                        entry.np.name, entry.np.name, OF.gamemodes.clock(took))
                else
                    OF.gamemodes.finish("@ takes the whole run.", entry.np.name,
                        entry.np.name)
                end
                return
            end
        end

        local reached = math.max(furthest, course.floor())
        if reached ~= stalledAt then
            stalledAt = reached
            stalledFor = 0
            return
        end

        stalledFor = stalledFor + 1

        if stalledFor < course.stall_seconds(mode) * 30 then return end
        stalledFor = 0

        if reached >= #mode.stages - 1 then return end

        OF.util.publish(course.FLOOR_KEY, reached + 1)

        OF.notify.send_all("Nobody is getting through - everybody moves on.",
            "warn", 6)
    end

    function mode.on_timeout()
        local best, names = OF.gamemodes.best_of(
            OF.gamemodes.with_role(ROLE_RUNNING),
            function(entry)
                return gPlayerSyncTable[entry.localIndex].ofScore or 0
            end)
        if best == nil or best <= 0 then
            OF.gamemodes.finish("Nobody cleared a stage.")
        elseif #names > 1 then
            OF.gamemodes.finish("Time - a draw at @ each.", nil,
                best .. " of " .. #mode.stages)
        else

            OF.gamemodes.finish("@ got furthest: @.", names[1], names[1],
                best .. " of " .. #mode.stages)
        end
    end

    function mode.terms()

        local mine = #mode.stages > 0
        for _, stage in ipairs(mode.stages) do
            if not stage.instanced then mine = false end
        end
        if mine then
            return OF.lang.fill("first to clear all @ stages, one each",
                tostring(#mode.stages))
        end
        return OF.lang.fill("first to clear all @ stages", tostring(#mode.stages))
    end

    function mode.standing(localIndex)
        if OF.gamemodes.role(localIndex) ~= ROLE_RUNNING then return nil end
        return cleared_by(localIndex) .. "/" .. #mode.stages
    end

    function mode.hud()
        local screenWidth = djui_hud_get_screen_width()
        local screenHeight = djui_hud_get_screen_height()

        local number = my_stage_number()
        local stage = course.stage_at(mode, number, course.lane_of(mode, 0))
        local text
        if stage == nil then
            text = OF.lang.fill("All @ done!", #mode.stages)
        else
            text = OF.lang.fill("Fight @ of @", number, #mode.stages)
                .. "   -   " .. OF.lang.t(stage.name)
        end

        local under = nil
        local taken, total = nil, nil
        if mode.redCoins and stage ~= nil then
            taken, total = course.red_coins_here()
            if taken ~= nil then
                under = { { text = OF.lang.fill("@ of @ red coins",
                    tostring(taken), tostring(total)),
                    r = 255, g = 120, b = 120 } }
            end
        end

        local top, bannerX = OF.util.banner(text, 1.0, OF.util.gold().r,
            OF.util.gold().g, OF.util.gold().b, 255,
            under ~= nil and { under = under } or nil)

        if taken ~= nil and OF.util.asks(OF.util, "banner_checks") then
            OF.util.banner_checks(top, bannerX, taken, total,
                { r = 255, g = 120, b = 120 })
        end

        OF.util.board(screenWidth * 0.03, screenHeight * 0.26,
            OF.lang.t("Progress"), course.board(),
            { scale = 0.8, width = 180, column = 120 })
    end

    OF.gamemodes.register(mode)
    return mode
end

course.SECRETS = {
    { name = "Tower of the Wing Cap", level = LEVEL_TOTWC,  area = 1, act = 1, star = 0, instanced = true },
    { name = "Cavern of the Metal Cap", level = LEVEL_COTMC, area = 1, act = 1, star = 0, instanced = true },
    { name = "Vanish Cap under the Moat", level = LEVEL_VCUTM, area = 1, act = 1, star = 0, instanced = true },
    { name = "The Secret Aquarium", level = LEVEL_SA,     area = 1, act = 1, star = 0, instanced = true },
    { name = "Wing Mario over the Rainbow", level = LEVEL_WMOTR, area = 1, act = 1, star = 0, instanced = true },
}

course.make({
    key = "secretrun",

    how = "The five secret courses, one after another.\n"
        .. "Eight red coins in each, then the star, then the next.\n"
        .. "Your own copy of each, and your own eight coins.\n"
        .. "Everybody runs the same five in the same order.\n"
        .. "First to clear all five ends it for the lobby.",
    name = "The Secret Five",
    blurb = "eight red coins in each of the five secret courses",
    stages = course.SECRETS,

    lanes = false,

    wantsCaps = true,

    music = SEQ_LEVEL_SLIDE,
    countsUp = true,

    redCoins = true,

    defaultLimit = 15 * 60,
})

course.make({
    key = "bossrush",
    how = "Every boss in the game, back to back.\n"
        .. "Everybody runs the same ten in the same order.\n"
        .. "Every one of them is your own copy to fight.\n"
        .. "Beat one and you are sent straight to the next.\n"
        .. "Five minutes on one before you are moved on.\n"
        .. "First to clear them all ends it for the lobby.",
    name = "Boss Rush",
    blurb = "every boss in the game, one each",
    stages = course.BOSSES,

    lanes = false,
    music = SEQ_EVENT_BOSS,

    fightsBosses = true,

    stallSeconds = 5 * 60,

    countsUp = true,
    defaultLimit = 10 * 5 * 60,
})
