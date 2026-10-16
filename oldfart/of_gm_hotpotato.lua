OF = OF or {}

local PASS_RANGE   = 170
local HOLD_FRAMES  = 30
local BACK_FRAMES  = 60

local HOLDER_SPEED = 1.15

local CARRY_STOPS = { quick = HOLDER_SPEED, even = 1.0, quicker = 1.30 }
local CARRY_DEFAULT = "quick"
local function holder_speed()
    local stop = CARRY_STOPS[OF.gamemodes.option_now("carry") or CARRY_DEFAULT]
    if stop == nil then return CARRY_STOPS[CARRY_DEFAULT] end
    return stop
end

OF.gm_hotpotato_holder_speed = holder_speed

local WALK_TARGET = 32

local ROLE_IN  = "in"
local ROLE_OUT = "out"
local START_FUSE = 20
local MIN_FUSE   = 8
local FUSE_STEP  = 3

local MAX_FUSE   = 30

local PACE_STOPS = {
    steady = { step = FUSE_STEP, floor = MIN_FUSE },
    gentle = { step = 2, floor = 12 },
    sudden = { step = 5, floor = MIN_FUSE },
}

local BACKSTOP_SECONDS = 4 * 60

local BOMBS_PER_LIVING = 4

local MAX_BOMBS = 4

local MAX_EXTRA_BOMBS = MAX_BOMBS - 1

local grabs = 0

local heldSince = { 0, 0, 0, 0 }
local sincePass = 0

local giver = { -1, -1, -1, -1 }

local seenGrabs = {}

local seenRole = {}
local lastOutSeat, lastOutAt = nil, -9999
local outTick = 0

local function track_last_out()
    outTick = outTick + 1
    for s = 0, (MAX_PLAYERS or 16) - 1 do
        local role = OF.gamemodes.role(s)
        if role == ROLE_OUT and seenRole[s] ~= ROLE_OUT then
            lastOutSeat, lastOutAt = s, outTick
        end
        seenRole[s] = role
    end
end

local fuseFrames = { 0, 0, 0, 0 }

local seated = false

local function holder_global()
    return gGlobalSyncTable.ofHpHolder or -1
end

local function no_tagbacks()
    return OF.gamemodes.option_now("tagback") == "never"
end

local function ramp()
    return PACE_STOPS[OF.gamemodes.option_now("pace") or "steady"]
        or PACE_STOPS.steady
end

local AUTO_SCALED_FROM = 9
local function bomb_target(living)
    local how = OF.gamemodes.option_now("bombs")
    if how == "auto" then
        how = #OF.gamemodes.participants() >= AUTO_SCALED_FROM and "scaled" or "one"
    end
    if how ~= "scaled" then return 1 end
    if living == nil or living <= 1 then return 1 end
    return math.max(1, math.min(MAX_BOMBS, math.floor(living / BOMBS_PER_LIVING)))
end

local function pack3(a, b, c)
    return string.format("%.0f %.0f %.0f", a or -1, b or -1, c or -1)
end

local unpackSeen, unpackSeenCount = {}, 0
local UNPACK_SEEN_MAX = 32

local function unpack3(s)
    if type(s) ~= "string" then return -1, -1, -1 end
    local seen = unpackSeen[s]
    if seen ~= nil then return seen[1], seen[2], seen[3] end

    local a, b, c = -1, -1, -1
    local i = 0
    for tok in s:gmatch("%S+") do
        i = i + 1
        local n = tonumber(tok)
        if i == 1 then a = n or -1
        elseif i == 2 then b = n or -1
        elseif i == 3 then c = n or -1 end
    end

    if unpackSeenCount >= UNPACK_SEEN_MAX then
        unpackSeen, unpackSeenCount = {}, 0
    end
    unpackSeen[s] = { a, b, c }
    unpackSeenCount = unpackSeenCount + 1
    return a, b, c
end

local function wire_holder(slot)
    if slot == 1 then return gGlobalSyncTable.ofHpHolder or -1 end
    local a, b, c = unpack3(gGlobalSyncTable.ofHpHolders2)
    if slot == 2 then return a elseif slot == 3 then return b else return c end
end

local function wire_holder_local(slot)
    local g = wire_holder(slot)
    if g < 0 then return nil end
    return OF.util.local_from_global(g)
end

local function wire_fuse_seconds(slot)
    if slot == 1 then return gGlobalSyncTable.ofHpFuse or 0 end
    local a, b, c = unpack3(gGlobalSyncTable.ofHpFuses2)
    if slot == 2 then return a elseif slot == 3 then return b else return c end
end

local function wire_blown(slot)
    if slot == 1 then return gGlobalSyncTable.ofHpBlown end
    local a, b, c = unpack3(gGlobalSyncTable.ofHpBlown2)
    if slot == 2 then return a elseif slot == 3 then return b else return c end
end

local function publish_holder(slot, g)
    if slot == 1 then
        OF.util.publish("ofHpHolder", g)
        return
    end
    local a, b, c = wire_holder(2), wire_holder(3), wire_holder(4)
    if slot == 2 then a = g elseif slot == 3 then b = g else c = g end
    OF.util.publish("ofHpHolders2", pack3(a, b, c))
end

local function publish_fuse_seconds(slot, seconds)
    if slot == 1 then
        OF.util.publish("ofHpFuse", seconds)
        return
    end
    local a, b, c = wire_fuse_seconds(2), wire_fuse_seconds(3), wire_fuse_seconds(4)
    if slot == 2 then a = seconds elseif slot == 3 then b = seconds else c = seconds end
    OF.util.publish("ofHpFuses2", pack3(a, b, c))
end

local function publish_blown(slot, g)
    if slot == 1 then
        OF.util.publish("ofHpBlown", g)
        return
    end
    local a, b, c = wire_blown(2), wire_blown(3), wire_blown(4)
    if slot == 2 then a = g elseif slot == 3 then b = g else c = g end
    OF.util.publish("ofHpBlown2", pack3(a, b, c))
end

local function my_slot()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    for slot = 1, MAX_BOMBS do
        if wire_holder(slot) == np.globalIndex then return slot end
    end
    return nil
end

local function holds_a_bomb(globalIndex)
    for slot = 1, MAX_BOMBS do
        if wire_holder(slot) == globalIndex then return true end
    end
    return false
end

local function am_holder()
    return my_slot() ~= nil
end

local BOMB_LIFT = 140

local function dress_bomb(token, m)
    if token == nil then return end
    OF.gamemodes.pose_bobomb(token, OF.gamemodes.BOBOMB_CARRIED, 1.0)
    if m ~= nil and m.faceAngle ~= nil then token.oFaceAngleYaw = m.faceAngle.y end
end

local function place_bomb()
    for slot = 1, MAX_BOMBS do
        local key = slot == 1 and "bomb" or ("bomb" .. slot)
        local holder = wire_holder_local(slot)
        local m = holder ~= nil and gMarioStates[holder] or nil
        local np = holder ~= nil and gNetworkPlayers[holder] or nil
        if m == nil or np == nil or m.pos == nil then
            OF.gamemodes.hide_token(key)
        else
            dress_bomb(OF.gamemodes.mark_place(key, E_MODEL_BLACK_BOBOMB,
                { x = m.pos.x, y = m.pos.y + BOMB_LIFT, z = m.pos.z,
                  level = np.currLevelNum, area = np.currAreaIndex }), m)
        end
    end
end

function OF.gm_hotpotato_object()
    return OF.gamemodes.tokens["bomb"]
end

function OF.gm_hotpotato_slots()
    local out = {}
    for slot = 1, MAX_BOMBS do
        out[slot] = wire_holder(slot)
    end
    return out
end

function OF.gm_hotpotato_fuses()
    local out = {}
    for slot = 1, MAX_BOMBS do
        out[slot] = wire_fuse_seconds(slot)
    end
    return out
end

local function still_in()
    return OF.gamemodes.with_role(ROLE_IN)
end

local function can_hold()
    local list = {}
    for _, entry in ipairs(still_in()) do
        if OF.gamemodes.can_play(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function reachable()
    for _, entry in ipairs(still_in()) do
        if OF.gamemodes.in_contention(entry.localIndex) then return true end
    end
    return false
end

local function eligible_carriers(list)
    local out = {}
    for _, entry in ipairs(list) do
        if not holds_a_bomb(entry.np.globalIndex) then
            table.insert(out, entry)
        end
    end
    return out
end

local function pick_carrier(candidates)
    if #candidates == 0 then return nil end
    local round = gGlobalSyncTable.ofHpRound or 0
    local pick = candidates[(round % #candidates) + 1]
    OF.util.publish("ofHpRound", round + 1)
    return pick
end

local function holder_local()
    local target = holder_global()
    if target < 0 then return nil end
    return OF.util.local_from_global(target)
end

local mode = {
    key = "hotpotato",

    resultsBy = "survival",

    saysOut = true,
    name = "Hot Potato",
    blurb = "pass the bomb before it goes off",

    blurbTeams = "pass the bomb before it goes off - the last side with anybody left wins",

    aims = { [ROLE_IN] = "Touch somebody to hand the bomb on before it "
                      .. "goes off." },
    how = "One player holds a bomb with a burning fuse.\n"
        .. "Touch somebody to hand it on before it goes off.\n"
        .. "Whoever holds it when it blows is out.\n"
        .. "The fuse gets shorter after every bomb.\n"
        .. "One left wins. The clock is only a backstop.",
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3", "desert_cage", "ice_donut", "the_plate", "aquarium", "tower", "igloo" },

    room = { sweep = { "cannons" },
             rules = { knockback = 1, interactions = 0 } },

    defaultLimit = BACKSTOP_SECONDS,
    music = SEQ_EVENT_BOSS,

    teams = true,

    outWord = "BOOM",
    target = { name = "seconds on the fuse",
               asks = "How many seconds the first fuse burns",
               default = START_FUSE,

               min = MIN_FUSE, max = MAX_FUSE, step = 2 },

    lensRole = ROLE_OUT,

    options = {
        { key = "pace", name = "How fast the fuse tightens",
          help = "what each explosion takes off the fuse",
          choices = {

              { key = "steady", name = "normal",
                help = "three seconds off each explosion, and it stops at eight" },
              { key = "gentle", name = "gentle",
                help = "two off each, down to twelve - for a big lobby" },
              { key = "sudden", name = "sudden",
                help = "five off each, down to eight: three bombs reach the floor" },
          } },
        { key = "carry", name = "What holding the bomb does to you",
          help = "whether carrying it moves you, and by how much",
          choices = {
              { key = "quick", name = "a little faster",
                help = "a body length over an arena; enough to gain" },
              { key = "even", name = "nothing",
                help = "the bomb is dead weight; passing is about position" },
              { key = "quicker", name = "much faster",
                help = "the holder is the fastest in the lobby" },
          } },

        { key = "bombs", name = "How many bombs are lit at once",
          help = "whether the bomb count scales with how many are left",
          choices = {

              { key = "auto", name = "auto",
                help = "one bomb up to eight players, scaled from nine" },
              { key = "one", name = "one",
                help = "a single carrier, whatever the lobby holds" },
              { key = "scaled", name = "scaled",
                help = "one bomb per four living players; one up to seven" },
          } },

        { key = "tagback", name = "Tag-backs",
          help = "whether the bomb can go back to whoever passed it",
          choices = {
              { key = "wait", name = "after two seconds",
                help = "a short wait, then it can go back" },
              { key = "never", name = "never straight back",
                help = "it has to reach somebody else before it can go back" },
          } },

        { key = "replay", name = "Replay at the end",
          help = "the seconds before the round was decided, again",
          choices = {
              { key = "short", name = "the last three seconds",
                help = "played inside the ending - no extra wait" },
              { key = "long", name = "the last six seconds",
                help = "the ending waits three seconds more" },
              { key = "off", name = "no replay",
                help = "the winner's line over the world, as before" },
          } },
    },
}

mode.ramp_stops = PACE_STOPS

function mode.ladder_seconds(count, fuse, stop)
    local total = 0
    for _ = 1, math.max(0, (count or 0) - 1) do
        total = total + fuse
        fuse = math.max(math.min(stop.floor, fuse), fuse - stop.step)
    end
    return total
end

local bombTargets = {}
local bombList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #bombList, 1, -1 do bombList[i] = nil end
    for slot = 1, MAX_BOMBS do
        local holder = wire_holder_local(slot)
        if holder ~= nil and holder ~= 0 then
            local t = bombTargets[slot] or { label = "bomb", tone = "hunter",
                priority = 80, compass = "offscreen" }
            bombTargets[slot] = t
            t.id = "bomb:" .. tostring(slot)
            t.player = holder
            bombList[#bombList + 1] = t
        end
    end
    return bombList
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end

    seenGrabs = {}
    giver = { -1, -1, -1, -1 }

    local fuse = tonumber(options ~= nil and options.fuse)
    if fuse == nil then
        fuse = tonumber(options ~= nil and options.target)
            or OF.gamemodes.target_for(mode.key) or START_FUSE

        fuse = OF.util.clamp(math.floor(fuse), MIN_FUSE, MAX_FUSE)
    end
    fuseFrames[1] = fuse * 30

    if options == nil or tonumber(options.limit) == nil then
        local ladder = mode.ladder_seconds(#players, fuse, ramp())
        if ladder + 30 > BACKSTOP_SECONDS then
            OF.util.publish("ofGmLimit", ladder + 30)
        end
    end

    local target = bomb_target(#players)
    local picks = {}
    local it = OF.gamemodes.deal_it(players, target, false)
    for _, entry in ipairs(players) do
        if it[entry.localIndex] and entry.np ~= nil then
            table.insert(picks, entry)
        end
    end
    if #picks == 0 then picks[1] = players[1] end

    local first = picks[1]
    if first ~= nil and first.np ~= nil then
        OF.util.publish("ofHpHolder", first.np.globalIndex)
    else
        OF.util.publish("ofHpHolder", -1)
    end
    OF.util.publish("ofHpFuse", fuse)
    OF.util.publish("ofHpStartFuse", fuse)
    OF.util.publish("ofHpRound", 0)
    OF.util.publish("ofHpBoom", 0)
    OF.util.publish("ofHpBlown", -1)

    local extraHolders = { -1, -1, -1 }
    local extraFuses = { 0, 0, 0 }
    for extra = 1, MAX_EXTRA_BOMBS do
        fuseFrames[extra + 1] = 0
        local entry = picks[extra + 1]
        if extra < target and entry ~= nil and entry.np ~= nil then
            extraHolders[extra] = entry.np.globalIndex
            extraFuses[extra] = fuse
            fuseFrames[extra + 1] = fuse * 30
        end
    end
    OF.util.publish("ofHpHolders2",
        pack3(extraHolders[1], extraHolders[2], extraHolders[3]))
    OF.util.publish("ofHpFuses2",
        pack3(extraFuses[1], extraFuses[2], extraFuses[3]))
    OF.util.publish("ofHpBlown2", pack3(-1, -1, -1))
end

function mode.on_start()
    grabs = 0
    sincePass = 0
    seated = false

    heldSince = { 0, 0, 0, 0 }
    giver = { -1, -1, -1, -1 }
    if am_holder() then

        OF.gamemodes.cue("hazard")
    end
end

function mode.cleanup()

    if seated and OF.util.asks(OF.spectate, "stop") then
        OF.spectate.stop()
    end
    seated = false

    if OF.util.is_host() then
        OF.util.publish("ofHpHolder", -1)
        OF.util.publish("ofHpFuse", 0)
        OF.util.publish("ofHpBoom", 0)
        OF.util.publish("ofHpBlown", -1)

        OF.util.publish("ofHpStartFuse", 0)
        OF.util.publish("ofHpRound", 0)

        OF.util.publish("ofHpHolders2", pack3(-1, -1, -1))
        OF.util.publish("ofHpFuses2", pack3(0, 0, 0))
        OF.util.publish("ofHpBlown2", pack3(-1, -1, -1))
    end
    seenGrabs = {}
    fuseFrames = { 0, 0, 0, 0 }
    heldSince = { 0, 0, 0, 0 }
    giver = { -1, -1, -1, -1 }
    grabs = 0
    seenRole = {}
    lastOutSeat, lastOutAt = nil, -9999
    outTick = 0
end

function mode.replayDecider()
    if lastOutSeat == nil or outTick - lastOutAt > 300 then return nil end
    return lastOutSeat
end

function mode.update()

    if sincePass > 0 then sincePass = sincePass - 1 end

    if OF.gamemodes.role(0) ~= ROLE_IN then return end

local function reach_to(localIndex)
    local na, nb = gNetworkPlayers[0], gNetworkPlayers[localIndex]
    if na == nil or nb == nil then return nil end
    if na.currLevelNum ~= nb.currLevelNum then return nil end
    if na.currAreaIndex ~= nb.currAreaIndex then return nil end
    if not nb.currPositionValid then return nil end

    local ma, mb = gMarioStates[0], gMarioStates[localIndex]
    if ma == nil or mb == nil or ma.pos == nil or mb.pos == nil then
        return nil
    end
    local dx = ma.pos.x - mb.pos.x
    local dy = ma.pos.y - mb.pos.y
    local dz = ma.pos.z - mb.pos.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

    if am_holder() then return end

    if sincePass > 0 then return end

    local bestSlot, bestDistance = nil, nil
    for slot = 1, MAX_BOMBS do
        local holderIndex = wire_holder_local(slot)
        if holderIndex ~= nil and OF.gamemodes.role(holderIndex) == ROLE_IN then
            local distance = reach_to(holderIndex)
            if distance ~= nil and distance <= PASS_RANGE
                and (bestSlot == nil or distance < bestDistance) then
                bestSlot, bestDistance = slot, distance
            end
        end
    end
    if bestSlot == nil then return end

    grabs = grabs + 1
    OF.util.publish_row(0, "ofHpGrab", grabs)
    OF.util.publish_row(0, "ofHpGrabAt", bestSlot)
end

local function finish_if_over()
    local left = still_in()

    if OF.teams.in_play() then
        local side = OF.teams.last_side_standing(function(localIndex)
            return OF.gamemodes.role(localIndex) == ROLE_IN
        end)
        if side ~= nil then
            OF.gamemodes.finish(OF.teams.survival_text(side),
                OF.gamemodes.team_winner(side))
            return true
        end
        return false
    end

    if #left <= 1 then
        mode.declare(left)
        return true
    end
    return false
end

local function tagback_refused(slot, g, playing)
    if not no_tagbacks() or g ~= giver[slot] or g < 0 then return false end
    local holder = wire_holder(slot)
    for _, entry in ipairs(playing) do
        local other = entry.np ~= nil and entry.np.globalIndex
        if other ~= nil and other ~= g and other ~= holder
            and not holds_a_bomb(other) then
            return true
        end
    end
    return false
end

function mode.host_update()

    local playing = can_hold()

    local target = bomb_target(#still_in())

    for slot = MAX_BOMBS, target + 1, -1 do
        if wire_holder(slot) ~= -1 or fuseFrames[slot] > 0 then
            publish_holder(slot, -1)
            publish_fuse_seconds(slot, 0)
            fuseFrames[slot] = 0
            heldSince[slot] = 0
        end
    end

    if #still_in() > 0 and not reachable() then
        OF.gamemodes.abandon("Nobody was left who could carry it.")
        return
    end

    for slot = 1, target do
        heldSince[slot] = heldSince[slot] + 1
    end

    for slot = 1, target do
        local g = wire_holder(slot)
        if g ~= -1 then
            local stillPlaying = false
            for _, entry in ipairs(playing) do
                if entry.np.globalIndex == g then
                    stillPlaying = true
                    break
                end
            end
            if not stillPlaying then
                local pick = pick_carrier(eligible_carriers(playing))
                if pick ~= nil then
                    publish_holder(slot, pick.np.globalIndex)
                    giver[slot] = -1
                    if slot == 1 then
                        OF.notify.send_all("The bomb was dropped - @ has it now",
                            "warn", 4, pick.np.name)
                    end
                end
            end
        end
    end

    for slot = 1, target do
        if heldSince[slot] < HOLD_FRAMES then
            for _, entry in ipairs(playing) do
                local grabAt = tonumber(gPlayerSyncTable[entry.localIndex].ofHpGrabAt) or 1
                if grabAt == slot then

                    seenGrabs[entry.localIndex] =
                        gPlayerSyncTable[entry.localIndex].ofHpGrab or 0
                end
            end
        else
            for _, entry in ipairs(playing) do
                local grabAt = tonumber(gPlayerSyncTable[entry.localIndex].ofHpGrabAt) or 1
                if grabAt == slot then
                    local asked = gPlayerSyncTable[entry.localIndex].ofHpGrab or 0
                    local seen = seenGrabs[entry.localIndex] or 0
                    if asked > seen then
                        seenGrabs[entry.localIndex] = asked
                        local np = gNetworkPlayers[entry.localIndex]

                        if np ~= nil and np.globalIndex ~= wire_holder(slot)
                            and not holds_a_bomb(np.globalIndex)
                            and not tagback_refused(slot, np.globalIndex, playing) then
                            giver[slot] = wire_holder(slot)
                            publish_holder(slot, np.globalIndex)
                            heldSince[slot] = 0
                            break
                        end
                    end
                end
            end
        end
    end

    local exploded = {}
    for slot = 1, target do
        if fuseFrames[slot] > 0 then
            fuseFrames[slot] = fuseFrames[slot] - 1
            publish_fuse_seconds(slot, math.ceil(fuseFrames[slot] / 30))
            if fuseFrames[slot] <= 0 then
                table.insert(exploded, slot)
            end
        end
    end

    for _, slot in ipairs(exploded) do
    local loserIndex = wire_holder_local(slot)
    if loserIndex ~= nil then
        OF.gamemodes.set_role(loserIndex, ROLE_OUT)

        if loserIndex == 0 then
            OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
        end

        local _ = loserIndex
    end

    local blownGlobal = -1
    if loserIndex ~= nil then
        local blownNp = gNetworkPlayers[loserIndex]
        if blownNp ~= nil then blownGlobal = blownNp.globalIndex end
    end
    publish_blown(slot, blownGlobal)
    end

    if #exploded > 0 then
        OF.util.publish("ofHpBoom", (gGlobalSyncTable.ofHpBoom or 0) + 1)
    end

    if finish_if_over() then return end

    if #exploded == 0 then return end

    local pace = ramp()
    local burned = gGlobalSyncTable.ofHpStartFuse or START_FUSE
    local nextFuse = math.max(math.min(pace.floor, burned), burned - pace.step)
    OF.util.publish("ofHpStartFuse", nextFuse)

    for _, slot in ipairs(exploded) do
        fuseFrames[slot] = nextFuse * 30
        publish_fuse_seconds(slot, nextFuse)

        local pick = pick_carrier(eligible_carriers(can_hold()))
        giver[slot] = -1
        if pick ~= nil then
            publish_holder(slot, pick.np.globalIndex)
        else
            publish_holder(slot, -1)
        end
    end
end

function mode.declare(left)
    if #left == 1 then
        OF.gamemodes.finish("@ won.", left[1].np.name,
            left[1].np.name)
    else
        OF.gamemodes.finish("The bomb took everybody.")
    end
end

function mode.terms()
    local said = gGlobalSyncTable.ofHpStartFuse
    if type(said) ~= "number" or said <= 0 then
        said = OF.gamemodes.target_for(mode.key) or START_FUSE
    end
    return OF.lang.fill("the last one still in - @s of fuse",
        string.format("%.0f", said))
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

local function side_left(key)
    local total = 0
    for _, entry in ipairs(OF.teams.members(key)) do
        if OF.gamemodes.role(entry.localIndex) == ROLE_IN then
            total = total + 1
        end
    end
    return total
end

function mode.on_timeout()
    local left = still_in()

    if #left <= 1 then
        mode.declare(left)
        return
    end

    if OF.teams.in_play() then
        local red, blue = side_left("red"), side_left("blue")
        OF.gamemodes.finish(OF.teams.result_text(red, blue),
            OF.gamemodes.team_winner(OF.teams.leader(red, blue)))
        return
    end

    local best, names = OF.gamemodes.best_of(left, function(entry)
        return gPlayerSyncTable[entry.localIndex].ofScore or 0
    end)
    if best == nil then
        OF.gamemodes.finish("Nobody won.")
    elseif #names > 1 then
        OF.gamemodes.finish(best == 1 and "Time - a draw at 1 bomb each."
            or "Time - a draw at @ bombs each.", nil, best)
    else
        OF.gamemodes.finish(best == 1 and "@ won - 1 bomb." or "@ won - @ bombs.",
            names[1], names[1], best)
    end
end

local function seat_rank(localIndex)

    local rank = tonumber(gPlayerSyncTable[localIndex].ofScore) or 0
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        local mine = OF.teams.of(0)
        if mine ~= nil and mine ~= OF.teams.NONE
            and OF.teams.of(localIndex) == mine then

            rank = rank + 1000
        end
    end
    return rank
end

local function best_seat()
    local best, bestRank, bestNear = nil, nil, nil

    for _, entry in ipairs(can_hold()) do
        if entry.localIndex ~= 0 then
            local rank = seat_rank(entry.localIndex)

            local near = OF.gamemodes.distance(0, entry.localIndex) or math.huge
            if best == nil or rank > bestRank
                or (rank == bestRank and near < bestNear) then
                best, bestRank, bestNear = entry, rank, near
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

local function hurry_holder(m)

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if not OF.util.can_play(0) then return end
    if not am_holder() then return end

    if OF.util.has_flag(m.action, ACT_FLAG_AIR) then return end
    if OF.util.has_flag(m.action, ACT_FLAG_SWIMMING) then return end

    if (m.intendedMag or 0) <= 8 then return end

    OF.util.speed_up(m, math.min(m.intendedMag or 0, WALK_TARGET) * holder_speed())
end

function mode.before_mario_update(m)
    if OF.gamemodes.role(0) == ROLE_OUT then
        OF.gamemodes.set_ghost(true)
        watch_toggle(m)
        return
    end
    hurry_holder(m)
end

hook_on_sync_table_change(gGlobalSyncTable, "ofHpHolder", 0, function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofHpHolder") then return end
    if OF.gamemodes.current() == nil or OF.gamemodes.current().key ~= "hotpotato" then
        return
    end
    local np = gNetworkPlayers[0]
    if np == nil then return end

    if newVal == np.globalIndex then
        sincePass = 0

        OF.gamemodes.cue("hazard")
        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("objective", OF.lang.t("YOU HAVE IT"), nil, { side = "them", quiet = true })
        end
    elseif oldVal == np.globalIndex then

        sincePass = BACK_FRAMES

        if type(newVal) == "number" and newVal < 0 then return end

        if OF.gamemodes.role(0) == ROLE_OUT then return end

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("medal", OF.lang.t("PASSED"), nil, { tone = "good" })
        end

        OF.gamemodes.cue("good")
    end
end)

function mode.out_cause() return "The bomb went off on you" end

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "panic", name = "Panic", help = "a sudden fuse, never straight back, bombs scaled",
      sets = { pace = "sudden", tagback = "never", bombs = "scaled" } },
    { key = "gentle", name = "Gentle", help = "the fuse tightens slowly",
      sets = { pace = "gentle" } },
}

function mode.hud()

    local out = OF.gamemodes.role(0) == ROLE_OUT
    local mySlot = nil
    if not out then mySlot = my_slot() end

    if out then

        OF.gamemodes.out_banner()
        return
    end

    if not OF.util.asks(OF.hud, "state_line") then return end
    local state = OF.hud.state_line
    if mySlot ~= nil then
        local fuse = wire_fuse_seconds(mySlot)
        state("mine", OF.lang.t("You have it"), { prio = 80, tone = "hunter", figure = fuse,
            urgent = fuse <= 5, colour = true })
        return
    end
    local count, soonest, name = 0, nil, nil
    for slot = 1, MAX_BOMBS do
        local g = wire_holder(slot)
        if g >= 0 then
            count = count + 1
            local fuse = wire_fuse_seconds(slot)
            if soonest == nil or fuse < soonest then soonest = fuse end
            if count == 1 then
                local li = OF.util.local_from_global(g)
                if li ~= nil then name = gNetworkPlayers[li].name end
            end
        end
    end
    if count == 1 and name ~= nil then
        state("holder", OF.lang.fill("@ has it", OF.util.short_name(OF.util.plain(name), 10)),
            { prio = 50, tone = "warn", figure = soonest or 0 })
    elseif count > 1 then
        state("holder", OF.lang.fill("@ bombs live", tostring(count)),
            { prio = 50, tone = "warn", figure = soonest or 0 })
    end
end

hook_on_sync_table_change(gGlobalSyncTable, "ofHpBoom", 0, function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofHpBoom") then return end
    if newVal == nil or newVal == 0 then return end

    if oldVal ~= nil and newVal <= oldVal then return end

    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "hotpotato" then return end

    local role = OF.gamemodes.role(0)
    if role == nil or role == "" then return end

    OF.celebrate.shake()

    local blown = { gGlobalSyncTable.ofHpBlown, unpack3(gGlobalSyncTable.ofHpBlown2) }
    for at = 1, MAX_BOMBS do
        local g = blown[at]
        local li = type(g) == "number" and g >= 0 and OF.util.local_from_global(g) or nil
        local bm = li ~= nil and gMarioStates[li] or nil
        if bm ~= nil then
            OF.gamemodes.round_sound_from(bm.marioObj, SOUND_GENERAL2_BOBOMB_EXPLOSION)
        end
    end

    local myGlobal = network_global_index_from_local(0)
    local wasBlown = gGlobalSyncTable.ofHpBlown == myGlobal
    if not wasBlown then
        local a, b, c = unpack3(gGlobalSyncTable.ofHpBlown2)
        wasBlown = a == myGlobal or b == myGlobal or c == myGlobal
    end
    if wasBlown and OF.util.asks(OF.powerups, "firework") then
        OF.powerups.firework(gMarioStates[0])
    end

    if role == ROLE_IN then
        OF.util.publish_row(0, "ofScore",
            (gPlayerSyncTable[0].ofScore or 0) + 1)
    end
end)

function mode.scenery()
    track_last_out()
    place_bomb()
    mode.tick_my_fuse()
end

function mode.tick_my_fuse()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    local soonest = nil
    for slot = 1, MAX_BOMBS do
        if wire_holder(slot) == np.globalIndex then
            local fuse = wire_fuse_seconds(slot)
            if type(fuse) == "number" and (soonest == nil or fuse < soonest) then
                soonest = fuse
            end
        end
    end
    if soonest == nil then return nil end
    if OF.gamemodes.tick_down(soonest) == nil then return nil end
    return soonest
end

mode.roundKeys = { "ofHpHolder", "ofHpHolders2", "ofHpFuse", "ofHpFuses2", "ofHpBlown", "ofHpBlown2", "ofHpStartFuse" }
OF.gamemodes.register(mode)
