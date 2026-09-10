OF = OF or {}

local ROLE_PLAYING = "playing"
local ROLE_OUT = "out"
local CALL_KEY = "ofSimonCall"
local CALL_SECONDS = 4.0
local SETTLE_SECONDS = 1.5

local CALL_STOPS = {
    four  = 4.0,
    three = 3.0,
    two   = 2.0,
    six   = 6.0,
}

local function stop_seconds()
    local said = CALL_STOPS[OF.gamemodes.option_now("call") or "four"]
    if type(said) ~= "number" then return CALL_STOPS.four end
    return said
end

local function window_seconds(_gone)
    return stop_seconds()
end

function OF.gm_simon_window(gone)
    return window_seconds(gone)
end

local function call_shift()
    return math.floor((window_seconds() - CALL_SECONDS) * 30)
end

local function call_frames()
    return math.floor(CALL_SECONDS * 30) + call_shift()
end

local function deal_frames()
    return math.floor((CALL_SECONDS + SETTLE_SECONDS) * 30) + call_shift()
end

local DRIFT_PER_FRAME = 2.0

local STILL_FRAMES = 10
local MOVING_GRACE = 8

local TOGETHER_RADIUS = 700
local APART_RADIUS = 1000

local FLAT_OUT_SPEED = 20

local calledAt = nil

local callFrames = 0

local wentOut = {}
local wentOutFor = nil
local wasOut = {}

local lastCall = nil
local judged = true
local frame = 0
local lastX, lastZ = nil, nil
local stillFor = 0

local leftGround = 0
local wasAirborne = false
local out = false

local seated = false

local dealAt = 0
local dealt = 0

local function call_index()
    return gGlobalSyncTable[CALL_KEY] or 0
end

local function am_playing()
    return OF.gamemodes.role(0) == ROLE_PLAYING
end

local function in_contention(localIndex)
    return OF.gamemodes.in_contention(localIndex)
end

local function contenders()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAYING)) do
        if in_contention(entry.localIndex) then table.insert(list, entry) end
    end
    return list
end

local function group(m)
    if m == nil then return nil end
    return m.action & ACT_GROUP_MASK
end

local passedThrough = {}

local function move_taken(m, ...)
    if m == nil then return false end
    for index = 1, select("#", ...) do
        local action = select(index, ...)
        if m.action == action or passedThrough[action] then return true end
    end
    return false
end

local function forget_moves()
    passedThrough = {}
end

hook_event(HOOK_ON_SET_MARIO_ACTION, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if type(m.action) ~= "number" then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "simon" then return end
    if call_index() == 0 then return end
    passedThrough[m.action] = true
end)

local function others_here()
    local list = {}
    local mine = gNetworkPlayers[0]
    if mine == nil then return list end

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PLAYING)) do
        if entry.localIndex ~= 0 then
            local np = entry.np
            local other = gMarioStates[entry.localIndex]
            if np ~= nil and other ~= nil
                and np.currLevelNum == mine.currLevelNum
                and np.currAreaIndex == mine.currAreaIndex then
                table.insert(list, other)
            end
        end
    end
    return list
end

local function nearest_other(m)
    local best = nil
    for _, other in ipairs(others_here()) do
        local dx, dy, dz = other.pos.x - m.pos.x, other.pos.y - m.pos.y,
            other.pos.z - m.pos.z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if best == nil or distance < best then best = distance end
    end
    return best
end

local CALLS = {
    {
        key = "air", words = "IN THE AIR", hint = "jump, and be off the ground",
        test = function(m) return group(m) == ACT_GROUP_AIRBORNE end,
    },
    {
        key = "ground", words = "ON YOUR FEET", hint = "both feet on the floor",
        test = function(m)
            local g = group(m)
            return g == ACT_GROUP_STATIONARY or g == ACT_GROUP_MOVING
        end,
    },
    {
        key = "still", words = "DO NOT MOVE", hint = "stop, and mean it",

        holds = true,
        test = function() return stillFor >= STILL_FRAMES end,
    },
    {
        key = "move", words = "KEEP MOVING", hint = "do not stop",
        holds = true,
        test = function() return stillFor < MOVING_GRACE end,
    },
    {

        key = "crouch", words = "GET DOWN", hint = "crouch or crawl",
        test = function(m)
            return m ~= nil and (m.action & ACT_FLAG_SHORT_HITBOX) ~= 0
        end,
    },
    {
        key = "together", words = "GET TOGETHER",
        hint = "stand next to somebody", needs = 2,
        test = function(m)
            local near = nearest_other(m)
            return near ~= nil and near < TOGETHER_RADIUS
        end,
    },
    {
        key = "apart", words = "GET AWAY FROM EVERYBODY",
        hint = "nobody within reach", needs = 2,
        test = function(m)
            local near = nearest_other(m)
            return near == nil or near > APART_RADIUS
        end,
    },
    {
        key = "water", words = "GET IN THE WATER", hint = "under the surface",
        wet = true,
        test = function(m) return group(m) == ACT_GROUP_SUBMERGED end,
    },

    {

        key = "pound", words = "GROUND POUND", hint = "jump, then press down",
        test = function(m)
            return move_taken(m, ACT_GROUND_POUND, ACT_GROUND_POUND_LAND)
        end,
    },
    {

        key = "dive", words = "DIVE", hint = "run and dive",
        test = function(m)
            return m ~= nil and (m.action & ACT_FLAG_DIVING) ~= 0
        end,
    },

    {

        key = "fast", words = "RUN AT FULL SPEED",
        hint = "top speed, and hold it",
        test = function(m)
            return m ~= nil and math.abs(tonumber(m.forwardVel) or 0)
                >= FLAT_OUT_SPEED
        end,
    },
    {

        key = "grounded", words = "KEEP YOUR FEET ON THE FLOOR",
        hint = "do not leave the ground",
        holds = true,
        test = function() return leftGround == 0 end,
    },
    {

        key = "lowstill", words = "GET DOWN AND FREEZE",
        hint = "crouch, and do not move",

        holds = true,
        test = function(m)
            return m ~= nil and (m.action & ACT_FLAG_SHORT_HITBOX) ~= 0
                and stillFor >= STILL_FRAMES
        end,
    },

    {

        key = "leap", words = "LONG JUMP", hint = "crouch, then jump",
        test = function(m)
            return move_taken(m, ACT_LONG_JUMP, ACT_LONG_JUMP_LAND)
        end,
    },
    {

        key = "slidekick", words = "SLIDE KICK", hint = "run, crouch, punch",
        test = function(m)
            return move_taken(m, ACT_SLIDE_KICK, ACT_SLIDE_KICK_SLIDE)
        end,
    },
    {

        key = "jumpkick", words = "JUMP KICK", hint = "jump, then punch",
        test = function(m)
            return move_taken(m, ACT_JUMP_KICK)
        end,
    },
    {

        key = "backflip", words = "BACKFLIP", hint = "crouch, then jump",
        test = function(m)
            return move_taken(m, ACT_BACKFLIP)
        end,
    },
    {
        key = "sideflip", words = "SIDE FLIP", hint = "run, turn, jump",
        test = function(m)
            return move_taken(m, ACT_SIDE_FLIP)
        end,
    },
    {

        key = "triple", words = "TRIPLE JUMP", hint = "three jumps, running",
        test = function(m)
            return move_taken(m, ACT_TRIPLE_JUMP, ACT_FLYING_TRIPLE_JUMP,
                ACT_SPECIAL_TRIPLE_JUMP)
        end,
    },
    {

        key = "punch", words = "THROW A PUNCH", hint = "hit the air",
        test = function(m)
            return move_taken(m, ACT_PUNCHING, ACT_MOVE_PUNCHING)
        end,
    },

    {

        key = "double", words = "DOUBLE JUMP", hint = "jump, then jump again",
        test = function(m)
            return move_taken(m, ACT_DOUBLE_JUMP)
        end,
    },
    {

        key = "crawl", words = "CRAWL", hint = "crouch, then keep going",
        test = function(m)
            return move_taken(m, ACT_CRAWLING)
        end,
    },
    {

        key = "hops", words = "KEEP JUMPING", hint = "off the ground, twice",
        test = function() return leftGround >= 2 end,
    },
    {

        key = "lownear", words = "GET DOWN NEXT TO SOMEBODY",
        hint = "crouch beside somebody", needs = 2,
        test = function(m)
            if m == nil or (m.action & ACT_FLAG_SHORT_HITBOX) == 0 then
                return false
            end
            local near = nearest_other(m)
            return near ~= nil and near < TOGETHER_RADIUS
        end,
    },
    {

        key = "runaway", words = "RUN AWAY FROM EVERYBODY",
        hint = "top speed, nobody near", needs = 2,
        test = function(m)
            if m == nil or math.abs(tonumber(m.forwardVel) or 0)
                < FLAT_OUT_SPEED then
                return false
            end
            local near = nearest_other(m)
            return near == nil or near > APART_RADIUS
        end,
    },
}

OF.gm_simon_calls = CALLS

local function current_call()
    return CALLS[call_index()]
end

local POOL_KEY = "ofSimonOff"
local leftOut = {}

local INDEX_OF = {}
for index, call in ipairs(CALLS) do INDEX_OF[call.key] = index end

local OFF_WIDTH = 2

local function packed_off()
    local pieces = {}
    for index, call in ipairs(CALLS) do
        if leftOut[call.key] then
            local digits = tostring(index)
            while #digits < OFF_WIDTH do digits = "0" .. digits end
            table.insert(pieces, digits)
        end
    end
    return table.concat(pieces)
end

local function off_from(text)
    local set = {}
    if type(text) ~= "string" then return set end
    for at = 1, #text - (OFF_WIDTH - 1), OFF_WIDTH do
        local index = tonumber(string.sub(text, at, at + OFF_WIDTH - 1))
        if index ~= nil and CALLS[index] ~= nil then set[index] = true end
    end
    return set
end

local offRaw = nil
local offParsed = {}

local function off_now()
    local text = gGlobalSyncTable[POOL_KEY]
    if type(text) ~= "string" then text = "" end
    if text ~= offRaw then
        offRaw = text
        offParsed = off_from(text)
    end
    return offParsed
end

local function in_the_pool(index)
    return off_now()[index] ~= true
end

local function off_showing()
    local current = OF.gamemodes.current()
    if current ~= nil and current.key == "simon"
        and OF.gamemodes.state() ~= OF.gamemodes.OFF then
        return off_now()
    end
    return nil
end

function OF.gm_simon_left_out(callKey)
    if INDEX_OF[callKey] == nil then return nil end
    return leftOut[callKey] == true
end

function OF.gm_simon_leave_out(callKey, off)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if INDEX_OF[callKey] == nil then return false, "No such call." end
    if off then
        local left = 0
        for _, call in ipairs(CALLS) do
            if call.key ~= callKey and not leftOut[call.key] then
                left = left + 1
            end
        end
        if left == 0 then
            return false, "Simon Says needs at least one call."
        end
    end

    if off == true then
        leftOut[callKey] = true
    else
        leftOut[callKey] = nil
    end
    return true
end

function OF.gm_simon_pool_size()

    local off = off_showing()
    local inDeck = 0
    for index, call in ipairs(CALLS) do
        local isOff
        if off ~= nil then isOff = off[index] else isOff = leftOut[call.key] end
        if not isOff then inDeck = inDeck + 1 end
    end
    return inDeck, #CALLS
end

function OF.gm_simon_in_pool(index)
    return in_the_pool(index)
end

local function obeying()
    local call = current_call()
    if call == nil then return true end
    local m = gMarioStates[0]
    if m == nil then return true end
    return call.test(m) == true
end

OF.gm_simon_obeying = obeying

local did = false

local function safe_here()
    local call = current_call()
    if call ~= nil and call.holds then return obeying() end
    return did or obeying()
end

OF.gm_simon_safe_here = safe_here

local mode = {
    key = "simon",
    name = "Simon Says",
    blurb = "do what the call says before the clock runs out, or you are out",

    how = "The lobby is told to do something, and has a moment.\n"
        .. "Do it any time in that moment and it counts.\n"
        .. "Four seconds a call, the same one all round.\n"
        .. "Last player in wins; on the clock, all left share.",
    minPlayers = 2,

    maps = OF.gamemodes.ARENA_SET,

    saysOut = true,

    room = { sweep = { "cannons" }, rules = { interactions = 0 } },

    music = SEQ_EVENT_MERRY_GO_ROUND,
    defaultLimit = 300,

    resultsBy = "survival",

    teams = false,

    lensRole = ROLE_OUT,

    options = {
        { key = "call", name = "How long a call gives",
          help = "the moment between a call landing and everybody being "
              .. "judged on it - the same on the first call of the round and "
              .. "on the last",
          choices = {
              { key = "four", name = "four seconds",
                help = "the round this mode shipped with - long enough to read "
                    .. "the call, look about and still get there" },
              { key = "three", name = "three seconds",
                help = "quick without being a reaction test: enough to act on "
                    .. "a call you already know" },
              { key = "two", name = "two seconds",
                help = "the shortest the calls were written to be passable "
                    .. "at - you have to know the whole deck by heart" },
              { key = "six", name = "six seconds",
                help = "for a lobby learning the calls, or one spread out "
                    .. "enough that GET IN THE WATER is a walk" },
          } },
    },
}

function mode.setup(players, options)

    OF.util.publish(CALL_KEY, 0)

    OF.util.publish(POOL_KEY, packed_off())

    if OF.util.asks(OF.util, "seed_random") then OF.util.seed_random() end

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_PLAYING)
    end
end

function mode.late_join(localIndex)
    return ROLE_PLAYING
end

function mode.on_start()

    calledAt = nil

    callFrames = call_frames()
    lastCall = nil
    judged = true
    did = false
    wentOut = {}
    wentOutFor = nil
    wasOut = {}
    frame = 0
    lastX, lastZ = nil, nil
    stillFor = 0
    leftGround = 0
    wasAirborne = false
    forget_moves()
    out = false
    seated = false

    dealAt = math.floor(SETTLE_SECONDS * 30)
    dealt = 0
    if am_playing() then
        OF.notify.show("Do what the call says before the clock runs out.",
            "info", 6)
    end
end

function mode.cleanup()

    if seated and OF.util.asks(OF.spectate, "stop") then OF.spectate.stop() end
    seated = false

    calledAt = nil
    callFrames = 0
    lastCall = nil
    judged = true
    did = false
    lastX, lastZ = nil, nil
    stillFor = 0
    leftGround = 0
    wasAirborne = false
    forget_moves()
    out = false

    if OF.util.is_host() then OF.util.publish(POOL_KEY, nil) end
end

local function best_seat()
    local best, bestNear = nil, nil
    for _, entry in ipairs(contenders()) do
        if entry.localIndex ~= 0 then

            local near = OF.gamemodes.distance(0, entry.localIndex) or math.huge
            if best == nil or near < bestNear then
                best, bestNear = entry, near
            end
        end
    end
    if best == nil then return nil end
    return network_global_index_from_local(best.localIndex)
end

local function watch_toggle(m)
    if not OF.util.asks(OF.spectate, "start") then return end
    if OF.util.menu_has_screen() then return end

    OF.input.poll(m)
    if not OF.input.pressed(L_JPAD) then return end

    if OF.spectate.is_active() then
        OF.spectate.stop()
        seated = false
        return
    end

    local seat = best_seat()
    if seat == nil then
        OF.util.report(false, "There is nobody left to watch.")
        return
    end
    seated = OF.spectate.start(seat) == true
end

local function go_out(reason)
    if out or not am_playing() then return end
    out = true
    OF.gamemodes.set_role(0, ROLE_OUT)

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.gamemodes.set_ghost(true)
    OF.notify.show(reason, "bad", 5)
    OF.sounds.play(OF.sounds.DENIED)

    OF.notify.show("D-pad left watches the nearest of them - hold L to look further",
        "info", 7)
end

local function watch_who_fell()

    local index = call_index()
    if wentOutFor ~= index then
        wentOut = {}
        wentOutFor = index
    end

    local nowOut = {}
    for index = 0, MAX_PLAYERS - 1 do
        if OF.gamemodes.role(index) == ROLE_OUT then
            nowOut[index] = true
            if not wasOut[index] then
                local np = gNetworkPlayers[index]
                if np ~= nil and np.connected and np.name ~= nil
                    and np.name ~= "" then
                    table.insert(wentOut, np.name)
                end
            end
        end
    end
    wasOut = nowOut
end

function mode.update()
    frame = frame + 1

    local m = gMarioStates[0]
    if m == nil then return end

    local movedBy = 0
    if lastX ~= nil then
        local dx, dz = m.pos.x - lastX, m.pos.z - lastZ
        movedBy = math.sqrt(dx * dx + dz * dz)
    end
    lastX, lastZ = m.pos.x, m.pos.z
    if movedBy > DRIFT_PER_FRAME then
        stillFor = 0
    else
        stillFor = stillFor + 1
    end

    local airNow = group(m) == ACT_GROUP_AIRBORNE
    if airNow and not wasAirborne then leftGround = leftGround + 1 end
    wasAirborne = airNow

    if not am_playing() then return end

    local index = call_index()
    if lastCall == nil then

        lastCall = index
        calledAt = nil
        judged = true
        did = false
        forget_moves()
    elseif index ~= lastCall then
        lastCall = index
        calledAt = index > 0 and frame or nil
        judged = index == 0

        did = false

        callFrames = call_frames()

        leftGround = 0
        forget_moves()
    end

    if judged or calledAt == nil then return end

    if not did and group(m) ~= ACT_GROUP_CUTSCENE and obeying() then
        did = true
    end

    if frame - calledAt < callFrames then return end

    judged = true

    if group(m) == ACT_GROUP_CUTSCENE then return end

    if not safe_here() then
        local call = current_call()

        go_out(OF.lang.fill("You did not do it: @",
            OF.lang.t(call ~= nil and call.words or "")))
    end
end

function mode.before_mario_update(m)

    watch_who_fell()

    if am_playing() then return end
    if OF.gamemodes.role(0) ~= ROLE_OUT then return end
    OF.gamemodes.set_ghost(true)
    watch_toggle(m)
end

local function same_ground(np)
    local mine = gNetworkPlayers[0]
    return np ~= nil and mine ~= nil
        and np.currLevelNum == mine.currLevelNum
        and np.currAreaIndex == mine.currAreaIndex
end

local function water_under(x, z)
    local at = OF.util.optional("find_water_level", nil, x, z)
    if at == nil then return false end
    local floor = (gLevelValues or {}).floorLowerLimit or -11000
    return at > floor
end

local function dealable(call, playing, whoIsIn)
    if call == nil then return false end
    if (call.needs or 1) > playing then return false end
    if call.wet then

        if whoIsIn == nil then
            local m = gMarioStates[0]
            return m ~= nil and water_under(m.pos.x, m.pos.z)
        end
        if #whoIsIn == 0 then return false end
        for _, entry in ipairs(whoIsIn) do
            local m = gMarioStates[entry.localIndex]
            if m == nil or not same_ground(entry.np)
                or not water_under(m.pos.x, m.pos.z) then
                return false
            end
        end
    end
    return true
end

OF.gm_simon_dealable = dealable

function OF.gm_simon_caught()
    local said = {}
    for _, name in ipairs(wentOut) do table.insert(said, name) end
    return said
end

function mode.host_update()
    local playing = contenders()

    if #playing == 1 then
        local np = playing[1].np
        OF.gamemodes.finish("@ did as they were told.", np.name, np.name)
        return
    end
    if #playing == 0 then
        OF.gamemodes.finish("Everybody was caught out.")
        return
    end

    dealAt = dealAt - 1
    if dealAt > 0 then return end

    local deck = {}
    for index, call in ipairs(CALLS) do
        if index ~= dealt and in_the_pool(index)
            and dealable(call, #playing, playing) then
            table.insert(deck, index)
        end
    end

    if #deck == 0 then
        if dealt > 0 and in_the_pool(dealt)
            and dealable(CALLS[dealt], #playing, playing) then
            deck = { dealt }
        else
            OF.util.publish(CALL_KEY, 0)
            dealAt = deal_frames()
            return
        end
    end

    dealt = deck[math.random(#deck)]
    OF.util.publish(CALL_KEY, dealt)

    dealAt = deal_frames()
end

function mode.terms()
    local said = CALL_STOPS[OF.gamemodes.option_showing(mode.key, "call")
        or "four"]
    if type(said) ~= "number" then said = CALL_STOPS.four end
    return OF.lang.fill("the last one doing as they are told - @s a call",
        string.format("%.0f", said))
end

function mode.build_rows(panel)
    local rows = {}
    local inDeck, total = OF.gm_simon_pool_size()
    table.insert(rows, panel.with_right(
        panel.sub_header_row(OF.lang.t("Which calls come up")),
        OF.lang.fill("@ of @", tostring(inDeck), tostring(total))))

    for _, call in ipairs(CALLS) do
        local key = call.key
        local on = OF.gm_simon_left_out(key) ~= true
        table.insert(rows, panel.with_key(panel.with_help(
            panel.gated_row("speedrun",
                panel.tick(on, OF.lang.t(call.words)), 255, 220, 120,
                function()

                    local ok, why, feature = OF.gm_simon_leave_out(key, on)
                    OF.util.report(ok, why, feature)
                end),

            OF.lang.t(call.hint)),

            "gamemode:deck:" .. key))
    end
    return rows
end

function mode.on_timeout()
    local left = contenders()
    if #left == 1 then
        OF.gamemodes.finish("@ did as they were told.", left[1].np.name,
            left[1].np.name)
    elseif #left == 0 then
        OF.gamemodes.finish("Everybody was caught out.")
    else

        local names = {}
        for _, entry in ipairs(left) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish("@ were still in when time ran out.",
            { names = names }, tostring(#left))
    end
end

hook_on_sync_table_change(gGlobalSyncTable, CALL_KEY, 0, function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair(CALL_KEY) then
        return
    end
    if newVal == oldVal or (newVal or 0) == 0 then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "simon" then return end

    if OF.gamemodes.role(0) ~= "" then OF.sounds.play(OF.sounds.COUNT) end
end)

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return "IN"
end

function mode.hud()
    local call = current_call()
    if call == nil then
        OF.util.banner(OF.lang.t("Wait for the call..."), 1.0, 220, 220, 220)
    else
        OF.util.banner(OF.lang.t(call.words), 1.0, 255, 240, 140)
    end

    if am_playing() and call ~= nil then

        local left = 0
        if calledAt ~= nil and not judged then
            left = math.max(0, math.ceil(
                (callFrames - (frame - calledAt)) / 30))
        end

        if safe_here() then
            OF.util.banner(OF.lang.fill("@ - you did it", tostring(left)),
                0.7, 140, 255, 150)
        else
            OF.util.banner(OF.lang.fill("@ - not yet: @", tostring(left),
                OF.lang.t(call.hint)), 0.7, 255, 150, 150)
        end
    elseif OF.gamemodes.role(0) == ROLE_OUT then

        local watching = OF.util.asks(OF.spectate, "is_active")
            and OF.spectate.is_active()
        OF.util.banner(OF.lang.t(watching and "Out - L / R watch somebody else"
            or "Out - D-pad left to watch"), 0.7, 255, 150, 150)
    end

    local board = {}
    for _, entry in ipairs(contenders()) do
        table.insert(board, { name = entry.np.name, localIndex = entry.localIndex })
    end

    table.sort(board, function(a, b) return a.name < b.name end)

    local under = OF.util.board(djui_hud_get_screen_width() * 0.03,
        djui_hud_get_screen_height() * 0.24,
        OF.lang.t("Still in"), board, { column = 130 })

    if #wentOut > 0 then
        local fell = {}
        for _, name in ipairs(wentOut) do
            table.insert(fell, { name = name })
        end
        OF.util.board(djui_hud_get_screen_width() * 0.03, under + 12,
            OF.lang.t("Caught out by that one"), fell, { column = 130 })
    end
end

OF.gamemodes.register(mode)
