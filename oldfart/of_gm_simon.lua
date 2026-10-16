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

local callSaid, outCause = nil, nil
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

local SEQ_KEY = "ofSimonSeq"
local SEQ_BUTTONS = {
    { flag = A_BUTTON, name = "A" },
    { flag = B_BUTTON, name = "B" },
    { flag = Z_TRIG, name = "Z" },
    { flag = L_TRIG, name = "L" },
    { flag = R_TRIG, name = "R" },
    { flag = U_CBUTTONS, name = "C-UP" },
    { flag = D_CBUTTONS, name = "C-DOWN" },
    { flag = L_CBUTTONS, name = "C-LEFT" },
    { flag = R_CBUTTONS, name = "C-RIGHT" },
}

local QTE_SECONDS = 2.0
local COMBO_SECONDS = 5
local COMBO_LENGTH = 6

local seq = { wire = nil, want = {}, got = 0, failed = false, stamp = nil,
              down = 0 }

local function seq_read()
    local text = gGlobalSyncTable[SEQ_KEY]
    if type(text) ~= "string" then text = "" end
    if text == seq.wire then return seq end
    seq.wire = text
    seq.want = {}
    seq.got = 0
    seq.failed = false
    local digits = string.match(text, "^%d+:(%d+)$") or ""
    for at = 1, #digits do
        local one = SEQ_BUTTONS[tonumber(string.sub(digits, at, at))]
        if one ~= nil then table.insert(seq.want, one) end
    end
    return seq
end

local function seq_presses(m)
    local c = m ~= nil and m.controller or nil
    if c == nil then return 0, {} end
    local pressed = c.buttonPressed or 0
    local down = c.buttonDown or 0
    local rose = {}
    for _, one in ipairs(SEQ_BUTTONS) do
        if OF.util.has_flag(pressed, one.flag)
            or (OF.util.has_flag(down, one.flag)
                and not OF.util.has_flag(seq.down, one.flag)) then
            rose[one.flag] = true
        end
    end
    seq.down = down
    return pressed, rose
end

local function seq_judge(m)
    local s = seq_read()
    if #s.want == 0 then return false end
    if s.stamp ~= frame then
        s.stamp = frame
        local _, rose = seq_presses(m)
        if not s.failed and s.got < #s.want and next(rose) ~= nil then
            for _, one in ipairs(SEQ_BUTTONS) do
                if rose[one.flag] then
                    local next = s.want[s.got + 1]
                    if next ~= nil and one.flag == next.flag then
                        s.got = s.got + 1
                    else
                        s.failed = true

                        OF.gamemodes.cue("bad", nil, "simonwrong")
                    end
                end
            end
        end
    end
    return not s.failed and s.got >= #s.want
end

table.insert(CALLS, {
    key = "qte", words = "QUICK - PRESS IT", hint = "the button shown, now",
    buttons = 1, seconds = QTE_SECONDS, capped = true,
    test = seq_judge,
})
table.insert(CALLS, {
    key = "buttons", words = "BUTTON COMBO", hint = "all six, in order",
    buttons = COMBO_LENGTH, seconds = COMBO_SECONDS,
    test = seq_judge,
})

function OF.gm_simon_sequence()
    local s = seq_read()
    local names = {}
    for i, one in ipairs(s.want) do names[i] = one.name end
    return names, s.got, s.failed
end

local function frames_for(call)
    if call ~= nil and type(call.seconds) == "number" then
        local seconds = call.seconds

        if call.capped then seconds = math.min(seconds, window_seconds()) end
        return math.floor(seconds * 30)
    end
    return call_frames()
end

local function deal_frames_for(call)
    local beat = deal_frames()
    if call ~= nil and type(call.seconds) == "number" then
        local own = math.floor((call.seconds + SETTLE_SECONDS) * 30)
        if own > beat then return own end
    end
    return beat
end

local seqSerial = 0
local function publish_sequence(call)
    if call == nil or type(call.buttons) ~= "number" then return end
    seqSerial = (seqSerial + 1) % 1000
    local digits = {}
    for i = 1, call.buttons do
        digits[i] = tostring(math.random(#SEQ_BUTTONS))
    end
    OF.util.publish(SEQ_KEY, tostring(seqSerial) .. ":" .. table.concat(digits))
end

OF.gm_simon_calls = CALLS
OF.gm_simon_frames_for = frames_for

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

    maps = { "bowser1", "bowser2", "bowser3", "desert_cage", "ice_donut", "the_plate", "aquarium" },

    saysOut = true,

    room = { sweep = { "cannons" }, rules = { interactions = 0 } },

    music = SEQ_EVENT_MERRY_GO_ROUND,

    defaultLimit = 180,

    resultsBy = "survival",

    caps = { tiebreak = false },

    out_cause = function() return outCause end,

    teams = false,

    lensRole = ROLE_OUT,

    options = {
        { key = "call", name = "Call length",
          help = "how long between a call landing and being judged on it",
          choices = {
              { key = "four", name = "four seconds",
                help = "long enough to read the call, look about and get there" },
              { key = "three", name = "three seconds",
                help = "enough to act on a call you already know" },
              { key = "two", name = "two seconds",
                help = "the shortest a call is passable at; know the deck" },
              { key = "six", name = "six seconds",
                help = "for a lobby learning the calls, or a spread-out one" },
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
    callSaid, outCause = nil, nil

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

    if OF.util.is_host() then OF.util.publish(SEQ_KEY, nil) end
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

local function mark_out(reason)
    if out then return end
    out = true

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.gamemodes.set_ghost(true)

    outCause = reason
end

local function go_out(reason)
    if out or not am_playing() then return end
    OF.gamemodes.set_role(0, ROLE_OUT)
    mark_out(reason)
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

        callFrames = frames_for(CALLS[index])

        leftGround = 0
        forget_moves()
    end

    local shown = CALLS[index]
    if shown ~= nil and type(shown.buttons) == "number" then seq_judge(m) end

    if judged or calledAt == nil then return end

    if not did and group(m) ~= ACT_GROUP_CUTSCENE and obeying() then
        did = true

        OF.gamemodes.cue("good", nil, "simondid")
    end

    OF.gamemodes.tick_down(math.ceil((callFrames - (frame - calledAt)) / 30))

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
        OF.gamemodes.finish("@ won.", np.name, np.name)
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
    publish_sequence(CALLS[dealt])
    OF.util.publish(CALL_KEY, dealt)

    dealAt = deal_frames_for(CALLS[dealt])
end

function mode.terms()
    local said = CALL_STOPS[OF.gamemodes.option_showing(mode.key, "call")
        or "four"]
    if type(said) ~= "number" then said = CALL_STOPS.four end
    return OF.lang.fill("the last one doing as they are told - @s a call",
        string.format("%.0f", said))
end

local TRICKS = { qte = true, buttons = true, leap = true, slidekick = true, jumpkick = true,
    backflip = true, sideflip = true, triple = true, pound = true, dive = true }
local MOVES = { pound = true, dive = true, leap = true, slidekick = true, jumpkick = true,
    backflip = true, sideflip = true, triple = true, punch = true, double = true,
    crawl = true, hops = true }
mode.DECKS = {
    { key = "all", name = "all", help = "every call", out = function() return false end },
    { key = "nowater", name = "no water", help = "everything but the swim",
      out = function(key) return key == "water" end },
    { key = "beginner", name = "beginner", help = "no button calls and no tricks",
      out = function(key) return TRICKS[key] == true end },
    { key = "moves", name = "moves only", help = "the jumps, kicks and dives",
      out = function(key) return MOVES[key] ~= true end },
}

function mode.deck_now()
    for _, deck in ipairs(mode.DECKS) do
        local same = true
        for _, call in ipairs(CALLS) do
            if (OF.gm_simon_left_out(call.key) == true) ~= deck.out(call.key) then same = false end
        end
        if same then return deck end
    end
    return nil
end

function mode.apply_deck(key)
    local deck = nil
    for _, entry in ipairs(mode.DECKS) do
        if entry.key == key then deck = entry end
    end
    if deck == nil then return false, "No such deck." end
    for _, call in ipairs(CALLS) do
        if not deck.out(call.key) then
            local ok, why, feature = OF.gm_simon_leave_out(call.key, false)
            if not ok then return ok, why, feature end
        end
    end
    for _, call in ipairs(CALLS) do
        if deck.out(call.key) then
            local ok, why, feature = OF.gm_simon_leave_out(call.key, true)
            if not ok then return ok, why, feature end
        end
    end
    return true
end

function mode.build_rows(panel)
    local rows = {}
    local now = mode.deck_now()
    table.insert(rows, panel.with_key(panel.with_help(panel.with_right(
        panel.gated_row("speedrun", OF.lang.t("Deck"), 255, 255, 255, function()
            local at = 0
            for index, deck in ipairs(mode.DECKS) do
                if now ~= nil and deck.key == now.key then at = index end
            end
            local nextDeck = mode.DECKS[at % #mode.DECKS + 1]
            OF.util.report(mode.apply_deck(nextDeck.key))
        end),
        OF.lang.t(now ~= nil and now.name or "custom")),
        OF.lang.t(now ~= nil and now.help or "the ticks below, as you set them")),
        "gamemode:simondeck"))
    local inDeck, total = OF.gm_simon_pool_size()
    table.insert(rows, panel.with_right(
        panel.sub_header_row(OF.lang.t("Which calls come up")),
        OF.lang.fill("@ of @", tostring(inDeck), tostring(total))))

    for _, call in ipairs(CALLS) do
        do
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
    end

    return rows
end

function mode.on_timeout()
    local left = contenders()
    if #left == 1 then
        OF.gamemodes.finish("@ won.", left[1].np.name,
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
        OF.gamemodes.finish(#left == 1 and "Time - 1 player won." or "Time - @ players won.",
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

    OF.gamemodes.round_sound(OF.sounds.COUNT)
end)

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return "IN"
end

function mode.hud()
    local call = current_call()
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end

    local index = call_index()
    if call ~= nil and index ~= 0 and callSaid ~= index then
        callSaid = index
        local hold = callFrames > 0 and callFrames or 120
        if calledAt ~= nil then hold = callFrames - (frame - calledAt) end
        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("call", OF.lang.t(call.words), nil,
                { hold = math.max(1, hold), tone = "warn", quiet = true })
        end
    elseif index == 0 then
        callSaid = 0
    end

    if call ~= nil and type(call.buttons) == "number" then
        local names, got, failed = OF.gm_simon_sequence()
        local playing = OF.gamemodes.role(0) ~= ROLE_OUT
        if #names > 0 then
            local segments, plain = {}, {}
            for i, name in ipairs(names) do
                local tone = "text"
                if playing and failed then
                    tone = "bad"
                elseif playing and i <= got then
                    tone = "good"
                elseif playing and i == got + 1 then
                    tone = "warn"
                end
                local r, g, b = OF.util.round_tone(tone)
                local piece = (i > 1 and "  " or "") .. name
                table.insert(segments, { text = piece, r = r, g = g, b = b })
                table.insert(plain, piece)
            end
            OF.util.round_line_low(table.concat(plain), "line", "text", { segments = segments })
        end
    end

    if OF.gamemodes.role(0) == ROLE_OUT then
        OF.gamemodes.out_banner()
        return
    end
    if call == nil then
        state("wait", OF.lang.t("Wait"), { prio = 20, tone = "mute" })
        return
    end
    if not am_playing() then return end

    local left = 0
    if calledAt ~= nil and not judged then
        left = math.max(0, math.ceil((callFrames - (frame - calledAt)) / 30))
    end

    local _, _, missed = OF.gm_simon_sequence()
    if type(call.buttons) == "number" and missed then
        state("wrong", OF.lang.t("Wrong button"), { prio = 85, tone = "bad" })
    elseif safe_here() then
        state("done", OF.lang.t("Done"), { prio = 70, tone = "good" })
    else
        state("notyet", OF.lang.t("Not yet"), { prio = 80, tone = "bad", urgent = true,
            figure = left })
    end
end

mode.roundKeys = { "ofSimonCall" }
OF.gamemodes.register(mode)
