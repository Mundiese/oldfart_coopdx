OF = OF or {}

local PASS_RANGE   = 170
local HOLD_FRAMES  = 30
local BACK_FRAMES  = 60

local HOLDER_SPEED = 1.15

local WALK_TARGET = 32

local ROLE_IN  = "in"
local ROLE_OUT = "out"
local START_FUSE = 22
local MIN_FUSE   = 8
local FUSE_STEP  = 3

local MAX_FUSE   = 30

local PACE_STOPS = {
    steady = { step = FUSE_STEP, floor = MIN_FUSE },
    gentle = { step = 2, floor = 12 },
    sudden = { step = 5, floor = MIN_FUSE },
}

local BACKSTOP_SECONDS = 7 * 60

local grabs = 0

local heldSince = 0
local sincePass = 0

local seenGrabs = {}
local fuseFrames = 0

local seated = false

local function holder_global()
    return gGlobalSyncTable.ofHpHolder or -1
end

local function am_holder()
    local np = gNetworkPlayers[0]
    return np ~= nil and holder_global() == np.globalIndex
end

local function ramp()
    return PACE_STOPS[OF.gamemodes.option_now("pace") or "steady"]
        or PACE_STOPS.steady
end

local function place_bomb()
    local holder = OF.util.local_from_global(holder_global())
    local m = holder ~= nil and gMarioStates[holder] or nil
    local np = holder ~= nil and gNetworkPlayers[holder] or nil
    if m == nil or np == nil or m.pos == nil then
        OF.gamemodes.hide_token("bomb")
        return
    end
    OF.gamemodes.mark_place("bomb", E_MODEL_BLACK_BOBOMB,
        { x = m.pos.x, y = m.pos.y + 140, z = m.pos.z,
          level = np.currLevelNum, area = np.currAreaIndex }, 0x0600)
end

function OF.gm_hotpotato_object()
    return OF.gamemodes.tokens["bomb"]
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

local function holder_local()
    local target = holder_global()
    if target < 0 then return nil end
    return OF.util.local_from_global(target)
end

local mode = {
    key = "hotpotato",

    resultsBy = "survival",
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

    maps = OF.gamemodes.ARENA_SET,

    room = { sweep = { "cannons" },
             rules = { knockback = 1, interactions = 0 } },

    defaultLimit = BACKSTOP_SECONDS,
    music = SEQ_EVENT_BOSS,

    teams = true,

    target = { name = "seconds on the fuse",
               asks = "How many seconds the first fuse burns",
               default = START_FUSE,

               min = MIN_FUSE, max = MAX_FUSE, step = 2 },

    lensRole = ROLE_OUT,

    options = {
        { key = "pace", name = "How fast the fuse tightens",
          help = "how much each explosion takes off the fuse and how short it "
              .. "is allowed to get",
          choices = {
              { key = "steady", name = "three a bomb, down to eight",
                help = "the round this mode shipped with - every explosion "
                    .. "takes three seconds off and it stops at eight" },
              { key = "gentle", name = "two a bomb, down to twelve",
                help = "for a big lobby, or one meeting the passing range for "
                    .. "the first time - it never becomes frantic, and the "
                    .. "longer round is what the backstop clock is there for" },
              { key = "sudden", name = "five a bomb, down to eight",
                help = "for a lobby that already knows the range - three bombs "
                    .. "and the fuse is on its floor" },
          } },
    },
}

mode.ramp_stops = PACE_STOPS

function mode.marked_player(localIndex)
    if holder_local() ~= localIndex then return nil end
    return "bomb", 255, 150, 90
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end

    seenGrabs = {}

    local fuse = tonumber(options ~= nil and options.fuse)
    if fuse == nil then
        fuse = tonumber(options ~= nil and options.target)
            or OF.gamemodes.target_for(mode.key) or START_FUSE

        fuse = OF.util.clamp(math.floor(fuse), MIN_FUSE, MAX_FUSE)
    end
    fuseFrames = fuse * 30

    local first = nil
    local it = OF.gamemodes.deal_it(players, 1, false)
    for _, entry in ipairs(players) do
        if it[entry.localIndex] and entry.np ~= nil then first = entry end
    end
    if first == nil then first = players[1] end
    if first ~= nil and first.np ~= nil then
        OF.util.publish("ofHpHolder", first.np.globalIndex)
    end
    OF.util.publish("ofHpFuse", fuse)
    OF.util.publish("ofHpStartFuse", fuse)
    OF.util.publish("ofHpRound", 0)
    OF.util.publish("ofHpBoom", 0)
    OF.util.publish("ofHpBlown", -1)
end

function mode.on_start()
    grabs = 0
    sincePass = 0
    seated = false

    heldSince = 0
    if am_holder() then
        OF.notify.show("You have the bomb. Give it to somebody.", "bad", 6)
        OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
    else
        OF.notify.show("Stay away from whoever is lit up.", "warn", 6)
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
    end
    seenGrabs = {}
    fuseFrames = 0
    grabs = 0
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

    local holderIndex = holder_local()
    if holderIndex == nil then return end
    if OF.gamemodes.role(holderIndex) ~= ROLE_IN then return end

    local distance = reach_to(holderIndex)
    if distance == nil or distance > PASS_RANGE then return end

    grabs = grabs + 1
    OF.util.publish_row(0, "ofHpGrab", grabs)
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

function mode.host_update()

    local playing = can_hold()

    if #still_in() > 0 and not reachable() then
        OF.gamemodes.abandon("Nobody was left who could carry it.")
        return
    end

    heldSince = heldSince + 1

    local current = holder_local()
    local currentIsIn = false
    for _, entry in ipairs(playing) do
        if entry.localIndex == current then currentIsIn = true end
    end
    if not currentIsIn and #playing > 0 then
        local pick = playing[((gGlobalSyncTable.ofHpRound or 0) % #playing) + 1]
        OF.util.publish("ofHpRound", (gGlobalSyncTable.ofHpRound or 0) + 1)
        OF.util.publish("ofHpHolder", pick.np.globalIndex)
        OF.notify.send_all("The bomb was dropped - @ has it now", "warn", 4,
            OF.util.plain(pick.np.name))
    end

    if heldSince < HOLD_FRAMES then
        for _, entry in ipairs(playing) do

            seenGrabs[entry.localIndex] =
                gPlayerSyncTable[entry.localIndex].ofHpGrab or 0
        end
    else
        for _, entry in ipairs(playing) do
            local asked = gPlayerSyncTable[entry.localIndex].ofHpGrab or 0
            local seen = seenGrabs[entry.localIndex] or 0
            if asked > seen then
                seenGrabs[entry.localIndex] = asked

                local np = gNetworkPlayers[entry.localIndex]
                if np ~= nil and np.globalIndex ~= holder_global() then
                    OF.util.publish("ofHpHolder", np.globalIndex)
                    heldSince = 0
                    break
                end
            end
        end
    end
    local holderIndex = holder_local()

    if fuseFrames > 0 then
        fuseFrames = fuseFrames - 1
        OF.util.publish("ofHpFuse", math.ceil(fuseFrames / 30))
    end

    if fuseFrames > 0 then

        finish_if_over()
        return
    end

    local loserIndex = holder_local()
    if loserIndex ~= nil then
        OF.gamemodes.set_role(loserIndex, ROLE_OUT)

        if loserIndex == 0 then
            OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
        end

        local np = gNetworkPlayers[loserIndex]
        if np ~= nil then
            OF.notify.send_to(np.globalIndex,
                "The bomb went off on you - you are out", "bad", 5)

            OF.notify.send_to(np.globalIndex,
                "D-pad left watches the best of them - hold L to look further",
                "info", 7)
        end
    end

    local blownGlobal = -1
    if loserIndex ~= nil then
        local blownNp = gNetworkPlayers[loserIndex]
        if blownNp ~= nil then blownGlobal = blownNp.globalIndex end
    end
    OF.util.publish("ofHpBlown", blownGlobal)
    OF.util.publish("ofHpBoom", (gGlobalSyncTable.ofHpBoom or 0) + 1)

    if finish_if_over() then return end

    local pace = ramp()
    local burned = gGlobalSyncTable.ofHpStartFuse or START_FUSE
    local nextFuse = math.max(math.min(pace.floor, burned), burned - pace.step)
    OF.util.publish("ofHpStartFuse", nextFuse)
    fuseFrames = nextFuse * 30
    OF.util.publish("ofHpFuse", nextFuse)

    local carriers = can_hold()
    if #carriers > 0 then
        local pick = carriers[((gGlobalSyncTable.ofHpRound or 0) % #carriers) + 1]
        OF.util.publish("ofHpRound", (gGlobalSyncTable.ofHpRound or 0) + 1)
        OF.util.publish("ofHpHolder", pick.np.globalIndex)
    else
        OF.util.publish("ofHpHolder", -1)
    end

end

function mode.declare(left)
    if #left == 1 then
        OF.gamemodes.finish("@ was the last one still in.", left[1].np.name,
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
        OF.gamemodes.finish("Nobody survived.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ bomb(s) survived.", nil, best)
    else
        OF.gamemodes.finish("@ survived @ bomb(s).", names[1], names[1], best)
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

    OF.util.speed_up(m, math.min(m.intendedMag or 0, WALK_TARGET) * HOLDER_SPEED)
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
        OF.notify.show("You have it! Pass it on!", "bad", 3)
        OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
    elseif oldVal == np.globalIndex then

        sincePass = BACK_FRAMES

        if type(newVal) == "number" and newVal < 0 then return end

        if OF.gamemodes.role(0) == ROLE_OUT then return end

        OF.notify.show("Passed it on", "good", 2)
    end
end)

function mode.hud()

    local holder = OF.util.local_from_global(holder_global())
    local hm = holder ~= nil and gMarioStates[holder] or nil
    if hm ~= nil and hm.pos ~= nil then
        OF.util.world_arrow({ x = hm.pos.x, y = hm.pos.y + 260, z = hm.pos.z },
            200, 5, 255, 120, 90, 230)
    end

    local fuse = gGlobalSyncTable.ofHpFuse or 0
    local out = OF.gamemodes.role(0) == ROLE_OUT

    local text, r, g, b
    if out then

        local watching = OF.util.asks(OF.spectate, "is_active")
            and OF.spectate.is_active()
        text = watching and "Out - L / R watch somebody else"
            or "Out - D-pad left to watch"
        r, g, b = 255, 140, 140
    elseif am_holder() then
        text = "YOU HAVE IT   -   " .. fuse .. "s"
        if fuse <= 5 and math.floor(fuse * 2) % 2 == 0 then
            r, g, b = 255, 255, 255
        else
            r, g, b = 255, 90, 90
        end
    else
        local holderIndex = holder_local()
        local name = holderIndex ~= nil and gNetworkPlayers[holderIndex].name or "nobody"
        text = name .. " has it   -   " .. fuse .. "s"
        r, g, b = 255, 220, 90
    end

    local under = #still_in() .. " still in"
    OF.util.banner(text, 1.1, r, g, b, 255,
        { under = { text = under, scale = 0.8 } })
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

    if gGlobalSyncTable.ofHpBlown ~= nil
        and gGlobalSyncTable.ofHpBlown == network_global_index_from_local(0)
        and OF.util.asks(OF.powerups, "firework") then
        OF.powerups.firework(gMarioStates[0])
    end

    if role == ROLE_IN then
        OF.util.publish_row(0, "ofScore",
            (gPlayerSyncTable[0].ofScore or 0) + 1)
    end
end)

function mode.scenery()
    place_bomb()
end

OF.gamemodes.register(mode)
