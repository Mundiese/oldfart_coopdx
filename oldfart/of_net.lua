OF = OF or {}
OF.net = OF.net or {}

local net = OF.net

net.PACKET_WARP    = "warp"
net.PACKET_TP      = "tp"
net.PACKET_POS     = "pos"
net.PACKET_ANNOUNCE = "say"
net.PACKET_MOON    = "moon"
net.PACKET_CREDITS = "credits"
net.PACKET_THINGS  = "things"
net.pendingTarget = nil
net.pendingPos = nil

net.pendingWarp = nil
net.pendingTimer = 0
net.pendingWarped = false

net.lastSnapshot = nil

local function my_global()
    return network_global_index_from_local(0)
end

local function send_all(data)
    data.from = my_global()
    return OF.util.tell_all(data)
end

local function send_one(localIndex, data)
    return OF.util.send_to_player(localIndex, data)
end

function net.in_a_round(localIndex)
    return OF.util.asks(OF.roundscope, "inside")
        and OF.roundscope.inside(localIndex) == true
end

net.IN_A_ROUND = "They are in a round - it owns where they stand."
local function ask_host(data)

    if OF.util.is_host() then return false, "You are the host." end
    if OF.util.asks(OF.pass, "post") then return OF.pass.post(data) end

    if not OF.util.send_to_host(data) then
        return false, "There is no host to ask."
    end
    return true, "Asked the host."
end

function net.warp_local(level, area, act, alsoLevels, refusal)

    if OF.util.asks(OF.roundact, "translate") then
        act = OF.roundact.translate(level, act)
    end

    if OF.util.asks(OF.venues, "select_before_warp")
        and OF.venues.select_before_warp(level, area, act, alsoLevels, refusal) then
        return true
    end

    if OF.util.asks(OF.gamemodes, "hold_here") and OF.gamemodes.holding() ~= nil then
        OF.gamemodes.hold_here(level, area, act, alsoLevels)
    end

    local standing = net.pendingWarp

    if warp_to_level(level, area, act) then
        if standing ~= nil and net.pendingWarp == standing
            and standing.level ~= level then
            net.pendingWarp = nil
        end
        return true
    end
    if refusal ~= nil and refusal ~= "" then
        OF.util.report(false, refusal)
        return false
    end
    OF.util.report(false, "There is no way into that part of the level.")
    return false
end

local function snapshot_lobby()
    local snapshot = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local np = entry.np
        table.insert(snapshot, {
            globalIndex = network_global_index_from_local(entry.localIndex),
            level = np.currLevelNum,
            area = np.currAreaIndex,
            act = np.currActNum,
        })
    end
    net.lastSnapshot = snapshot

    if OF.util.is_host() then
        OF.util.publish("ofUndoWarp", #snapshot > 0)
    end
end

function net.can_undo()
    if OF.util.is_host() then
        return net.lastSnapshot ~= nil and #net.lastSnapshot > 0
    end
    return gGlobalSyncTable.ofUndoWarp == true
end

function net.warp_everyone(level, area, act, refusal, forTheRound)
    if not OF.perms.can("warp_lobby") then
        return false, "Your rank cannot do that.", "warp_lobby"
    end
    if not OF.util.is_host() then

        return ask_host({
            ofp = net.PACKET_WARP_ASK, lvl = level, area = area, act = act,
            rd = (forTheRound == true) and 1 or nil,
        })
    end
    snapshot_lobby()

    local lobbyOnly = forTheRound ~= true
        and OF.util.asks(OF.lockdown, "round_or_run") and OF.lockdown.round_or_run()
    if lobbyOnly then
        for _, entry in ipairs(OF.util.connected_players()) do
            local li = entry.localIndex
            if li ~= 0 and not net.in_a_round(li) then
                send_one(li, { ofp = net.PACKET_WARP, lvl = level, area = area,
                    act = act, lw = 1, from = my_global() })
            end
        end

        if net.in_a_round(0) then return true end
        net.warp_local(level, area, act, nil, refusal)
        return true
    end

    if forTheRound == true then
        local runKind = OF.speedrun ~= nil and OF.speedrun.KIND_RUN or nil
        net.send_the_field(level, area, act, nil, runKind)
        if OF.util.asks(OF.gamemodes, "room_moving") then
            OF.gamemodes.room_moving()
        end
        if net.leaves_behind(0, runKind) == nil then
            net.warp_local(level, area, act, nil, refusal)
        end
        return true
    end
    send_all({ ofp = net.PACKET_WARP, lvl = level, area = area, act = act })

    if OF.util.asks(OF.gamemodes, "room_moving") then
        OF.gamemodes.room_moving()
    end
    net.warp_local(level, area, act, nil, refusal)
    return true
end

function net.entrance_into_here(level, area)
    if level == LEVEL_CASTLE_GROUNDS then return true end
    local id = 0x0A
    if level == LEVEL_CASTLE then
        id = (area == 3) and 0x00 or 0x01
    elseif level == LEVEL_CASTLE_COURTYARD then
        id = 0x01
    end
    local node = OF.util.optional("area_get_warp_node", false, id)
    if node == false then return true end
    return node ~= nil
end

function net.reload_level()
    local me = gNetworkPlayers[0]
    if me == nil then return false, "Nothing is loaded to reload." end

    local level = me.currLevelNum
    local area = me.currAreaIndex
    local act = me.currActNum

    local fromTheStart = false
    if area ~= 1 and not net.entrance_into_here(level, area) then
        area = 1
        fromTheStart = true
    end

    local ok, why, feature = net.warp_everyone(level, area, act,
        "This map has no entrance, so it cannot be loaded again.")
    if ok and fromTheStart and OF.util.asks(OF.notify, "show") then
        OF.notify.show("No entrance here, so the map reloads from its start.",
            "info", 6)
    end
    return ok, why, feature
end

function net.reload_here()
    local me = gNetworkPlayers[0]
    if me == nil then return false, "Nothing is loaded to reload." end

    local level = me.currLevelNum
    local area = me.currAreaIndex
    local act = me.currActNum

    local fromTheStart = false
    if area ~= 1 and not net.entrance_into_here(level, area) then
        area = 1
        fromTheStart = true
    end

    local ok = net.warp_local(level, area, act,
        "This map has no entrance, so it cannot be loaded again.")
    if ok and fromTheStart and OF.util.asks(OF.notify, "show") then
        OF.notify.show("No entrance here, so the map reloads from its start.",
            "info", 6)
    end
    return ok == true
end

net.fieldMoved = {}
function net.undo_warp(roundOnly)
    if not OF.perms.can("warp_lobby") then
        return false, "Your rank cannot do that.", "warp_lobby"
    end
    if not OF.util.is_host() then

        return ask_host({ ofp = net.PACKET_WARP_ASK, u = true })
    end
    if net.lastSnapshot == nil or #net.lastSnapshot == 0 then
        return false, "There is no warp to take back."
    end

    local snapshot = net.lastSnapshot
    snapshot_lobby()
    for _, entry in ipairs(snapshot) do

        local li = OF.util.local_from_global(entry.globalIndex)
        local moved = not roundOnly or net.fieldMoved[entry.globalIndex] == true
        if moved and (li == nil or not (OF.util.asks(OF.roundscope, "inside")
            and OF.roundscope.inside(li))) then
            net.warp_player(entry.globalIndex, entry.level, entry.area, entry.act)
        end
    end
    return true
end

net.PACKET_WARP_ASK = "wrpask"
net.PACKET_MOVE_ASK = "moveask"
net.MOVE_WARP = "w"
net.MOVE_MOON = "m"
net.MOVE_ONTO = "t"
net.MOVE_SPOT = "p"
net.MOVE_CREDITS = "c"
net.MOVE_THINGS = "e"
local function everyone()
    local all = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        table.insert(all, network_global_index_from_local(entry.localIndex))
    end
    return all
end

local function point_packet(point)
    return {
        lvl = point.level, area = point.area, act = point.act,
        x = point.x, y = point.y, z = point.z, angle = point.angle,
    }
end

local function may_move(asker, target)
    if asker == nil or target == nil then return false end
    if target == asker then return true end

    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(target) then
        return false, "They are in a round - it owns where they stand."
    end

    local may, whyNot = OF.util.may_act_on(asker, target)
    if not may then return false, whyNot end
    return true
end

function net.report_move(ok, why, done)
    if not OF.util.report(ok, why) then return false end
    if OF.util.is_host() then

        if done ~= nil then
            local signed = OF.util.asks(OF.notify, "credit_named")
                and OF.notify.credit_named(0, done)
            if not signed and OF.util.asks(OF.notify, "show") then
                OF.notify.show("@", "info", 4, done)
            end
        end
    else

        local said = why
        if type(said) ~= "string" or said == "" then said = "Asked the host." end

        if OF.util.asks(OF.notify, "show") then
            OF.notify.show("@", "quiet", 3, OF.lang.t(said))
        end
    end
    return true
end

local function ask_to_move(action, globalIndexes, extra)
    local data = extra or {}
    data.ofp = net.PACKET_MOVE_ASK
    data.a = action

    data.who = table.concat(globalIndexes, ",")

    if OF.util.asks(OF.pass, "post") then return OF.pass.post(data) end
    if not OF.util.send_to_host(data) then
        return false, "There is no host to ask."
    end
    return true, "Asked the host."
end

function net.leaves_behind(li, kind)
    if OF.util.asks(OF.speedrun, "is_excluded") and OF.speedrun.is_excluded(li, kind) then
        return "sitting"
    end

    if OF.util.asks(OF.idle, "left_out") and OF.idle.left_out(li) then
        return "away"
    end
    if not OF.util.can_play(li, kind) then return "cannot" end
    return nil
end

function net.send_the_field(level, area, act, skipLocal, kind)
    local behind = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        if li ~= 0 and li ~= skipLocal then
            local why = net.leaves_behind(li, kind)

            if why == "sitting" then

                if kind == nil or kind ~= (OF.speedrun and OF.speedrun.KIND_RUN) then
                    OF.notify.send_to(network_global_index_from_local(li),
                        "The round has gone on without you - you are sitting out",
                        "info", 5)
                end
            elseif why == "away" then

                behind = behind + 1
            elseif why == "cannot" then

            else
                send_one(li, { ofp = net.PACKET_WARP,
                    lvl = level, area = area, act = act })
                net.fieldMoved[entry.np.globalIndex] = true
            end
        end
    end
    return behind
end

function net.warp_the_round(level, area, act, skipLocal)
    if not OF.perms.can("warp_lobby") then
        return false, "Your rank cannot do that.", "warp_lobby"
    end
    if not OF.util.is_host() then

        return ask_host({
            ofp = net.PACKET_WARP_ASK, lvl = level, area = area, act = act,
            rd = 1,
        })
    end

    if OF.util.asks(OF.roundact, "opening_act") then
        act = OF.roundact.opening_act(level, act)
    end

    snapshot_lobby()

    net.fieldMoved = {}
    local modeKind = OF.speedrun ~= nil and OF.speedrun.KIND_MODE or nil
    local behind = net.send_the_field(level, area, act, skipLocal, modeKind)

    if behind > 0 and OF.util.asks(OF.notify, "show") then
        OF.notify.show("@ away from the keyboard - the round starts without them.",
            "info", 6, tostring(behind))
    end

    if OF.util.asks(OF.gamemodes, "room_moving") then
        OF.gamemodes.room_moving()
    end

    if net.leaves_behind(0, modeKind) == nil and skipLocal ~= 0 then
        net.fieldMoved[0] = true
        net.warp_to(level, area, act)
    end
    return true
end

function net.warp_player(globalIndex, level, area, act, forTheRound)
    if not OF.perms.can("teleport_other") then
        return false, "Your rank cannot do that.", "teleport_other"
    end
    if globalIndex == my_global() then
        net.warp_local(level, area, act)
        return true
    end
    if not OF.util.is_host() then
        return ask_to_move(net.MOVE_WARP, { globalIndex },
            { lvl = level, area = area, act = act })
    end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false, "That player has left." end
    if forTheRound == true then
        send_one(li, { ofp = net.PACKET_WARP, lvl = level, area = area, act = act })
        return true
    end
    if net.in_a_round(li) then return false, net.IN_A_ROUND end
    send_one(li, { ofp = net.PACKET_WARP, lvl = level, area = area, act = act,
        lw = 1 })
    return true
end

net.LEAD_KEY = "ofRoundLead"
net.LEAD_EVERY = 30
local leadTick = 0

function net.round_lead()
    local g = gGlobalSyncTable[net.LEAD_KEY]
    if type(g) ~= "number" then return nil end
    return OF.util.local_from_global(g)
end

function net.is_round_lead(localIndex)
    local lead = net.round_lead()
    return lead ~= nil and lead == (localIndex or 0)
end

function net.may_lead(li)
    if type(li) ~= "number" or li < 0 or li >= MAX_PLAYERS then return false end
    local np = gNetworkPlayers[li]
    if np == nil or not np.connected then return false end
    return net.leaves_behind(li) == nil
end

function net.pick_lead(askerLocal, may)
    may = may or net.may_lead
    if askerLocal ~= nil and may(askerLocal) then return askerLocal end
    local best, bestGlobal = nil, nil
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected and may(i) then
            if bestGlobal == nil or np.globalIndex < bestGlobal then
                best, bestGlobal = i, np.globalIndex
            end
        end
    end
    return best
end

function net.set_round_lead(li)
    if not OF.util.is_host() then return false end
    local g = nil
    if li ~= nil and gNetworkPlayers[li] ~= nil and gNetworkPlayers[li].connected then
        g = gNetworkPlayers[li].globalIndex
    end
    if gGlobalSyncTable[net.LEAD_KEY] ~= g then OF.util.publish(net.LEAD_KEY, g) end
    return true
end

function net.lead_settle()
    if not OF.util.is_host() then return false end
    if gGlobalSyncTable[net.LEAD_KEY] == nil then return false end
    if OF.util.asks(OF.lockdown, "round_or_run") and OF.lockdown.round_or_run() then
        return false
    end
    OF.util.publish(net.LEAD_KEY, nil)
    return true
end

local function lead_dealt(li)
    return OF.util.asks(OF.roundscope, "dealt") and OF.roundscope.dealt(li) == true
end

local function round_or_run_on()
    return OF.util.asks(OF.lockdown, "round_or_run") and OF.lockdown.round_or_run() == true
end

function net.lead_update()
    if not OF.util.is_host() then return nil end
    leadTick = leadTick + 1
    if leadTick < net.LEAD_EVERY then return net.round_lead() end
    leadTick = 0
    if not round_or_run_on() then
        if gGlobalSyncTable[net.LEAD_KEY] ~= nil then OF.util.publish(net.LEAD_KEY, nil) end
        return nil
    end
    local lead = net.round_lead()
    if lead ~= nil and lead_dealt(lead) then return lead end
    local new = net.pick_lead(nil, lead_dealt)
    if new == lead then return lead end
    net.set_round_lead(new)
    if new ~= nil and OF.util.asks(OF.notify, "send_all") then
        OF.notify.send_all("@ leads the round now", "info", 5,
            OF.util.plain(gNetworkPlayers[new].name or ""))
    end
    return new
end

function net.lead_moves_round(asker, level, area, act)
    if not OF.util.is_host() then return false, "You are not the host." end
    if not round_or_run_on() then return false, "There is no round to move." end
    if asker == nil or not net.is_round_lead(asker) then
        return false, "Only the round's lead can move the round."
    end
    if OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running() then
        return net.warp_everyone(level, area, act, nil, true)
    end

    local np = gNetworkPlayers[asker]
    local skip = nil
    if np ~= nil and np.currLevelNum == level and (np.currAreaIndex or 1) == area then
        skip = asker
    end
    return net.warp_the_round(level, area, act, skip)
end

function net.move_round_here()
    if not net.is_round_lead(0) then
        return false, "Only the round's lead can move the round."
    end
    local np = gNetworkPlayers[0]
    if np == nil or np.currLevelNum == nil or np.currLevelNum == 0 then
        return false, "You are not standing anywhere yet."
    end
    local level, area, act = np.currLevelNum, np.currAreaIndex or 1, np.currActNum or 1
    if OF.util.is_host() then return net.lead_moves_round(0, level, area, act) end
    return ask_host({ ofp = net.PACKET_WARP_ASK, lvl = level, area = area,
        act = act, rd = 1 })
end

function net.teleport_to(globalIndex)

    local li = OF.util.local_from_global(globalIndex)
    if li ~= nil and OF.util.asks(OF.roundscope, "may_watch")
        and not OF.roundscope.may_watch(li) then
        OF.notify.show("A hide round is on - you cannot go to its players", "warn", 4)
        return false
    end
    net.pendingTarget = globalIndex
    net.pendingPos = nil
    net.pendingWarp = nil
    net.pendingTimer = 0
    net.pendingWarped = false
end

function net.teleport_to_position(point)
    net.pendingTarget = nil
    net.pendingPos = point
    net.pendingWarp = nil
    net.pendingTimer = 0
    net.pendingWarped = false
end

function net.warp_to(level, area, act)
    if level == nil then return false end
    net.pendingTarget = nil
    net.pendingPos = nil
    net.pendingWarp = { level = level, area = area or 1, act = act or 1 }
    net.pendingTimer = 0
    net.pendingWarped = false
    return net.warp_local(level, area or 1, act or 1)
end

function net.forget_pending_warp()
    net.pendingWarp = nil
end

function net.send_to_position(globalIndex, point)
    if not OF.perms.can("teleport_other") then
        return false, "Your rank cannot do that.", "teleport_other"
    end
    if globalIndex == my_global() then
        net.teleport_to_position(point)
        return true
    end
    if not OF.util.is_host() then
        return ask_to_move(net.MOVE_SPOT, { globalIndex }, point_packet(point))
    end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return end
    if net.in_a_round(li) then return false, net.IN_A_ROUND end
    send_one(li, {
        ofp = net.PACKET_POS,
        lvl = point.level, area = point.area, act = point.act,
        x = point.x, y = point.y, z = point.z, angle = point.angle,
    })
end

function net.send_everyone_to_position(point)
    if not OF.perms.can("teleport_other") then
        return false, "Your rank cannot do that.", "teleport_other"
    end
    if not OF.util.is_host() then
        return ask_to_move(net.MOVE_SPOT, everyone(), point_packet(point))
    end
    snapshot_lobby()

    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        if li ~= 0 and not net.in_a_round(li) then
            send_one(li, {
                ofp = net.PACKET_POS, from = my_global(),
                lvl = point.level, area = point.area, act = point.act,
                x = point.x, y = point.y, z = point.z, angle = point.angle,
            })
        end
    end
    if not net.in_a_round(0) then net.teleport_to_position(point) end

    return true
end

local MOON_LIFT = 320
local MOON_SPIN = 40

local MOON_SAFE = 300

function net.moon_local()
    local m = gMarioStates[0]
    if m == nil then return end

    m.vel.y = MOON_LIFT

    m.forwardVel = MOON_SPIN
    m.invincTimer = MOON_SAFE
    m.peakHeight = m.pos.y
    set_mario_action(m, ACT_THROWN_BACKWARD, 1)

    OF.util.limp_until_landed()
    OF.notify.show("To the moon", "info", 4)
end

function net.moon_player(globalIndex)
    if not OF.perms.can("teleport_other") then
        return false, "Your rank cannot do that.", "teleport_other"
    end
    if globalIndex == my_global() then
        net.moon_local()
        return true
    end
    if not OF.util.is_host() then
        return ask_to_move(net.MOVE_MOON, { globalIndex })
    end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false, "That player has left." end
    if net.in_a_round(li) then return false, net.IN_A_ROUND end
    send_one(li, { ofp = net.PACKET_MOON })
    return true
end

function net.moon_many(globalIndexes)
    if not OF.util.is_host() then
        return ask_to_move(net.MOVE_MOON, globalIndexes) and #globalIndexes or 0
    end
    local sent = 0
    for _, globalIndex in ipairs(globalIndexes or {}) do
        if net.moon_player(globalIndex) then sent = sent + 1 end
    end
    return sent
end

net.CREDITS_OP = WARP_OP_CREDITS_START or 0x17
net.YOU_IN_A_ROUND = "You are in a round - it owns where you stand."
function net.credits_local()
    local m = gMarioStates[0]
    if m == nil then return false, "Nobody to send." end
    if net.in_a_round(0) then return false, net.YOU_IN_A_ROUND end

    if level_trigger_warp(m, net.CREDITS_OP) == 0 then
        return false, "A warp is already under way."
    end
    return true
end

function net.credits_player(globalIndex)
    if not OF.perms.can("teleport_other") then
        return false, "Your rank cannot do that.", "teleport_other"
    end
    if globalIndex == my_global() then return net.credits_local() end
    if not OF.util.is_host() then
        return ask_to_move(net.MOVE_CREDITS, { globalIndex })
    end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false, "That player has left." end
    if net.in_a_round(li) then return false, net.IN_A_ROUND end
    send_one(li, { ofp = net.PACKET_CREDITS })
    return true
end

function net.credits_many(globalIndexes)
    if not OF.util.is_host() then
        local mine, others = false, {}
        for _, globalIndex in ipairs(globalIndexes or {}) do
            if globalIndex == my_global() then mine = true
            else table.insert(others, globalIndex) end
        end
        local sent = 0
        if #others > 0 and ask_to_move(net.MOVE_CREDITS, others) then
            sent = #others
        end
        if mine and net.credits_local() then sent = sent + 1 end
        return sent
    end
    local sent = 0
    for _, globalIndex in ipairs(globalIndexes or {}) do
        if net.credits_player(globalIndex) then sent = sent + 1 end
    end
    return sent
end

function net.title_local()
    if net.in_a_round(0) then return false, net.YOU_IN_A_ROUND end
    warp_special(SPECIAL_WARP_TITLE)
    return true
end

function net.summon_player(globalIndex, toGlobalIndex)
    if not OF.perms.can("teleport_other") then
        return false, "Your rank cannot do that.", "teleport_other"
    end
    if globalIndex == my_global() then
        net.teleport_to(toGlobalIndex)
        return true
    end
    if not OF.util.is_host() then
        return ask_to_move(net.MOVE_ONTO, { globalIndex }, { tg = toGlobalIndex })
    end

    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false, "That player has left." end
    if net.in_a_round(li) then return false, net.IN_A_ROUND end
    send_one(li, { ofp = net.PACKET_TP, tg = toGlobalIndex })
    return true
end

function net.summon_many(globalIndexes, toGlobalIndex)
    if not OF.util.is_host() then
        return ask_to_move(net.MOVE_ONTO, globalIndexes, { tg = toGlobalIndex })
            and #globalIndexes or 0
    end

    local moved, refusal = 0, nil
    for _, globalIndex in ipairs(globalIndexes) do
        if globalIndex ~= toGlobalIndex then
            local ok, why = net.summon_player(globalIndex, toGlobalIndex)
            if ok then moved = moved + 1 elseif refusal == nil then refusal = why end
        end
    end
    return moved, refusal
end

function net.summon_everyone_to(toGlobalIndex)
    if not OF.perms.can("teleport_other") then
        return 0, "Your rank cannot do that.", "teleport_other"
    end
    if not OF.util.is_host() then
        local ok, why = ask_to_move(net.MOVE_ONTO, everyone(), { tg = toGlobalIndex })
        return ok and #everyone() or 0, why
    end
    return net.summon_many(everyone(), toGlobalIndex)
end

local THING_LISTS = { "OBJ_LIST_GENACTOR", "OBJ_LIST_PUSHABLE",
    "OBJ_LIST_DESTRUCTIVE", "OBJ_LIST_LEVEL" }
local NOT_A_THING = { "INTERACT_DOOR", "INTERACT_WARP_DOOR", "INTERACT_WARP",
    "INTERACT_POLE", "INTERACT_CANNON_BASE", "INTERACT_WHIRLPOOL",
    "INTERACT_IGLOO_BARRIER", "INTERACT_BBH_ENTRANCE", "INTERACT_TORNADO" }
net.THING_LISTS = THING_LISTS

local function is_thing(o)
    if o == nil or o.activeFlags == 0 then return false end
    if o.collisionData ~= nil then return false end
    local interact = tonumber(o.oInteractType) or 0
    for _, name in ipairs(NOT_A_THING) do
        local flag = _G[name]
        if flag ~= nil and OF.util.has_flag(interact, flag) then return false end
    end
    local spine = OF.forge ~= nil and OF.forge.LEVEL_SPINE or {}
    for _, id in ipairs(spine) do
        if id ~= nil and OF.util.optional("obj_has_behavior_id", 0, o, id) ~= 0 then
            return false
        end
    end
    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        if m ~= nil and (m.marioObj == o or m.heldObj == o or m.riddenObj == o
            or m.usedObj == o
            or (m.marioObj ~= nil and m.marioObj.platform == o)) then
            return false
        end
    end
    return true
end
net.is_thing = is_thing

function net.things()
    local found = {}
    local first = OF.util.binding("obj_get_first")
    local nxt = OF.util.binding("obj_get_next")
    if first == nil or nxt == nil then return found end
    for _, name in ipairs(THING_LISTS) do
        local list = _G[name]
        local o = list ~= nil and first(list) or nil
        local guard = 0
        while o ~= nil and guard < 1200 do
            if is_thing(o) then table.insert(found, o) end
            guard = guard + 1
            o = nxt(o)
        end
    end
    return found
end

net.THING_KINDS = {
    { key = "goomba",  ids = { "id_bhvGoomba" } },
    { key = "bobomb",  ids = { "id_bhvBobomb" } },
    { key = "koopa",   ids = { "id_bhvKoopa" } },
    { key = "bully",   ids = { "id_bhvSmallBully", "id_bhvBigBully", "id_bhvSmallChillBully" } },
    { key = "boo",     ids = { "id_bhvBoo" } },
    { key = "piranha", ids = { "id_bhvPiranhaPlant" } },
    { key = "chuckya", ids = { "id_bhvChuckya" } },
    { key = "amp",     ids = { "id_bhvCirclingAmp", "id_bhvHomingAmp" } },
    { key = "shell",   ids = { "id_bhvKoopaShell" } },
    { key = "coin",    ids = { "id_bhvYellowCoin", "id_bhvMovingYellowCoin",
                               "id_bhvSingleCoinGetsSpawned", "id_bhvOneCoin" } },
    { key = "redcoin", ids = { "id_bhvRedCoin" } },
    { key = "bluecoin", ids = { "id_bhvBlueCoinJumping", "id_bhvMovingBlueCoin",
                                "id_bhvHiddenBlueCoin" } },
    { key = "star",    ids = { "id_bhvStar", "id_bhvSpawnedStar" } },
    { key = "heart",   ids = { "id_bhvRecoveryHeart" } },
    { key = "1up",     ids = { "id_bhv1Up", "id_bhv1upWalking", "id_bhv1upRunningAway",
                               "id_bhvHidden1up" } },
}

function net.kind_of(o)
    for _, kind in ipairs(net.THING_KINDS) do
        for _, name in ipairs(kind.ids) do
            local id = _G[name]
            if id ~= nil and OF.util.optional("obj_has_behavior_id", 0, o, id) ~= 0 then
                return kind.key
            end
        end
    end
    return nil
end

local function is_kind(word)
    for _, kind in ipairs(net.THING_KINDS) do
        if kind.key == word then return true end
    end
    return false
end

function net.parse_selector_args(text, forPlayers)
    local spec = { notTypes = {}, notNames = {} }
    if text == nil or text == "" then return spec end
    for pair in string.gmatch(text, "[^,]+") do
        local key, value = string.match(pair, "^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key == nil then return nil, OF.lang.fill("Expected value for option '@'", pair) end
        key = string.lower(key)
        if key == "limit" then
            local n = tonumber(value)
            if n == nil or n ~= math.floor(n) then
                return nil, OF.lang.fill("Invalid integer '@'", value)
            end
            if n < 1 then return nil, "Limit must be at least 1" end
            spec.limit = n
        elseif key == "sort" then
            value = string.lower(value)
            if value ~= "nearest" and value ~= "furthest" and value ~= "random"
                and value ~= "arbitrary" then
                return nil, OF.lang.fill("Invalid or unknown sort type '@'", value)
            end
            spec.sort = value
        elseif key == "distance" then
            local lo, hi = string.match(value, "^([%d%.]*)%.%.([%d%.]*)$")
            if lo == nil then
                local exact = tonumber(value)
                if exact == nil then return nil, OF.lang.fill("Invalid range '@'", value) end
                spec.dmin, spec.dmax = exact, exact
            else
                spec.dmin = lo ~= "" and tonumber(lo) or nil
                spec.dmax = hi ~= "" and tonumber(hi) or nil
                if (lo ~= "" and spec.dmin == nil) or (hi ~= "" and spec.dmax == nil)
                    or (lo == "" and hi == "") then
                    return nil, OF.lang.fill("Invalid range '@'", value)
                end
            end
            if (spec.dmin or 0) < 0 then return nil, "Distance cannot be negative" end
        elseif key == "name" then
            if string.sub(value, 1, 1) == "!" then
                table.insert(spec.notNames, string.lower(string.sub(value, 2)))
            else
                spec.name = string.lower(value)
            end
        elseif key == "type" then
            local negate = string.sub(value, 1, 1) == "!"
            local word = string.lower(negate and string.sub(value, 2) or value)
            word = string.gsub(word, "^minecraft:", "")
            local known = forPlayers and word == "player" or (not forPlayers and is_kind(word))
            if not known then return nil, OF.lang.fill("Unknown entity type '@'", word) end
            if negate then table.insert(spec.notTypes, word) else spec.type = word end
        else
            return nil, OF.lang.fill("Unknown option '@'", key)
        end
    end
    return spec
end

local function shuffled(list, seed)
    local state = math.floor(tonumber(seed) or 1) % 2147483647
    if state <= 0 then state = 1 end
    for i = #list, 2, -1 do
        state = (state * 48271) % 2147483647
        local j = (state % i) + 1
        list[i], list[j] = list[j], list[i]
    end
    return list
end

function net.sort_and_limit(entries, spec, defaultSort, defaultLimit, seed)
    local sort = spec.sort or defaultSort or "arbitrary"
    if sort == "nearest" or sort == "furthest" then
        table.sort(entries, function(a, b)
            local da, db = a.d or math.huge, b.d or math.huge
            if da == db then return (a.order or 0) < (b.order or 0) end
            if sort == "nearest" then return da < db end
            return da > db
        end)
    elseif sort == "random" then
        shuffled(entries, seed)
    end
    local limit = spec.limit or defaultLimit
    if limit ~= nil then
        while #entries > limit do table.remove(entries) end
    end
    return entries
end

local function in_range(d, spec)
    if spec.dmin == nil and spec.dmax == nil then return true end
    if d == nil then return false end
    if spec.dmin ~= nil and d < spec.dmin then return false end
    if spec.dmax ~= nil and d > spec.dmax then return false end
    return true
end

function net.select_things(job)
    local me = gNetworkPlayers[0]
    if me == nil or job == nil then return {} end
    if me.currLevelNum ~= job.lvl or me.currAreaIndex ~= job.area then return {} end
    local spec = net.parse_selector_args(job.args, false)
    if spec == nil then return {} end
    local entries = {}
    for index, o in ipairs(net.things()) do
        local kind = net.kind_of(o)
        local ok = true
        if spec.type ~= nil and kind ~= spec.type then ok = false end
        for _, not_kind in ipairs(spec.notTypes) do
            if kind == not_kind then ok = false end
        end

        if spec.name ~= nil and kind ~= spec.name then ok = false end
        for _, not_name in ipairs(spec.notNames) do
            if kind == not_name then ok = false end
        end
        local d = nil
        if job.ox ~= nil then
            local dx, dy, dz = o.oPosX - job.ox, o.oPosY - job.oy, o.oPosZ - job.oz
            d = math.sqrt(dx * dx + dy * dy + dz * dz)
        end
        if ok and in_range(d, spec) then
            table.insert(entries, { o = o, d = d, order = index, kind = kind })
        end
    end
    local defaultSort = job.sel == "n" and "nearest" or "arbitrary"
    local defaultLimit = job.sel == "n" and 1 or nil
    return net.sort_and_limit(entries, spec, defaultSort, defaultLimit, job.seed)
end

function net.things_local(job)
    local picked = net.select_things(job)
    for _, entry in ipairs(picked) do
        local o = entry.o
        o.oPosX, o.oPosY, o.oPosZ = job.x, job.y, job.z
        o.oHomeX, o.oHomeY, o.oHomeZ = job.x, job.y, job.z
        local yaw = nil
        if job.yaw ~= nil then
            yaw = job.yaw
        elseif job.yr ~= nil then
            yaw = (tonumber(o.oFaceAngleYaw) or 0) + job.yr
        end
        if yaw ~= nil then
            yaw = math.floor(yaw) % 0x10000
            if yaw >= 0x8000 then yaw = yaw - 0x10000 end
            o.oFaceAngleYaw, o.oMoveAngleYaw = yaw, yaw
        end
    end
    return #picked, picked[1] ~= nil and picked[1].kind or nil
end

local function round_in_level(level, area)
    for _, entry in ipairs(OF.util.connected_players()) do
        local np = entry.np
        if np ~= nil and np.currLevelNum == level and np.currAreaIndex == area
            and net.in_a_round(entry.localIndex) then
            return true
        end
    end
    return false
end

net.THINGS_IN_A_ROUND = "A round is using that level - it owns what stands in it."
net.THINGS_TIER = OF.TIER ~= nil and OF.TIER.MOD or nil

local JOB_FIELDS = { "lvl", "area", "act", "x", "y", "z", "ox", "oy", "oz",
    "sel", "args", "seed", "yaw", "yr" }
net.JOB_FIELDS = JOB_FIELDS

local function job_packet(job, ofp)
    local out = { ofp = ofp }
    for _, key in ipairs(JOB_FIELDS) do out[key] = job[key] end
    return out
end

local function run_things_job(job)
    if round_in_level(job.lvl, job.area) then return false, net.THINGS_IN_A_ROUND end
    send_all(job_packet(job, net.PACKET_THINGS))
    return true, net.things_local(job)
end

function net.move_things(job)
    if not OF.perms.can("teleport_other") then
        return false, "Your rank cannot do that.", "teleport_other"
    end
    local tier = net.THINGS_TIER or (OF.TIER and OF.TIER.MOD)
    if tier ~= nil and OF.perms.tier(0) < tier then
        return false, "Moving enemies and items is for Mod and up."
    end
    if job == nil then return false end
    if not OF.util.is_host() then
        local data = job_packet(job, nil)
        data.ofp = nil
        local ok, why = ask_to_move(net.MOVE_THINGS, {}, data)
        if not ok then return false, why end
        return true, "asked"
    end
    return run_things_job(job)
end
net.run_things_job = run_things_job

local function banner_segments(message)
    return { { text = message, r = 255, g = 255, b = 255, raw = true } }
end

net.PACKET_SAY_ASK = "sayask"
local SAY_MAX = 120

local function clean_say(message)
    return OF.util.cut_coloured(tostring(message or ""), SAY_MAX)
end

local function said_by(name)
    return { text = OF.lang.t("from "), name = name or OF.lang.t("the host") }
end

local function my_name()
    local np = gNetworkPlayers[0]
    if np == nil or np.name == nil or np.name == "" then return nil end
    return np.name
end

function net.announce(message, byName)

    local held = OF.util.asks(OF.gamemodes, "announce_held") and OF.gamemodes.announce_held() or nil
    if held ~= nil then
        OF.notify.show(held, "bad", 5)
        return false, held
    end
    if not OF.util.is_host() then

        return ask_host({
            ofp = net.PACKET_SAY_ASK,
            msg = clean_say(message),
        })
    end
    message = clean_say(message)
    byName = byName or my_name()
    send_all({ ofp = net.PACKET_ANNOUNCE, msg = message, by = byName })
    OF.welcome.show_banner(banner_segments(message), said_by(byName), true)

    return true
end

function net.announce_to(globalIndexes, message, byName)
    if not OF.util.is_host() then

        local ok, why = ask_host({
            ofp = net.PACKET_SAY_ASK,
            msg = clean_say(message),
            who = table.concat(globalIndexes, ","),
        })
        if not ok then return 0, why end
        return #globalIndexes, why
    end
    message = clean_say(message)
    byName = byName or my_name()
    local sent = 0
    for _, globalIndex in ipairs(globalIndexes) do
        if globalIndex == my_global() then
            OF.welcome.show_banner(banner_segments(message), said_by(byName), true)
            sent = sent + 1
        else
            local li = OF.util.local_from_global(globalIndex)
            if li ~= nil then
                send_one(li, { ofp = net.PACKET_ANNOUNCE, msg = message,
                    by = byName })
                sent = sent + 1
            end
        end
    end
    return sent
end

net.PACKET_CHECK   = "chk"
net.PACKET_CHECKED = "chkd"
net.PACKET_ASK    = "ask"
net.PACKET_DO     = "hostdo"
net.ACTIONS = {}

function net.register_action(name, permission, run)
    net.ACTIONS[name] = { perm = permission, run = run }
end

function net.host_does(name, x, y, z)
    local entry = net.ACTIONS[name]
    if entry == nil then return false, "No such thing." end
    if not OF.perms.can(entry.perm) then
        return false, "Your rank cannot do that.", entry.perm
    end

    if OF.util.is_host() then return OF.notify.acting(0, entry.run, 0, x, y, z) end
    local ok, why = ask_host({ ofp = net.PACKET_DO, a = name, x = x, y = y,
        z = z ~= nil and clean_say(z) or nil })
    if not ok then return false, why or "No host to ask yet - try again in a second." end

    return true, "asked"
end

net.PACKET_ECHO = "hostecho"
net.COHOST = {}

function net.register_cohost_action(name, permission, run, echo)
    net.COHOST[name] = { echo = echo }
    net.register_action(name, permission, function(asker, x, y, z)
        if asker ~= nil and asker ~= 0 and not OF.perms.is_cohost(asker) then
            return false, "Only the host or a co-host may do that."
        end
        local ok, why, value = run(asker, x, y, z)
        if OF.util.is_host() and asker ~= nil and asker ~= 0 and ok ~= false
            and value ~= nil then
            OF.util.send_to_player(asker,
                { ofp = net.PACKET_ECHO, a = name, v = tostring(value) })
        end
        return ok, why
    end)
end

function net.cohost_does(name, x, y, z)
    if not OF.util.is_host() and not OF.perms.is_cohost(0) then
        return false, "Only the host or a co-host may do that."
    end
    return net.host_does(name, x, y, z)
end

function net.take_echo(data)
    local entry = net.COHOST[tostring(data.a)]
    if entry == nil or entry.echo == nil then return false end
    entry.echo(data.v ~= nil and tostring(data.v) or "")
    if OF.util.asks(OF.panel, "mark_dirty") then OF.panel.mark_dirty() end
    return true
end

local askedAt = -9999

function net.asked_recently()
    if askedAt <= -9999 then return false end
    local now = get_global_timer and get_global_timer() or 0
    return (now - askedAt) < 1800
end

function net.ask_for_rank(tierName)
    local li = OF.util.local_from_global(0)
    if li == nil then return false, "There is no host to ask." end
    if OF.util.is_host() then return false, "You are the host." end

    if string.lower(tostring(tierName)) == "host" then
        return false, "Host is not a rank anybody can be given."
    end

    if OF.util.asks(OF.perms, "tier_from_word")
        and OF.perms.tier_from_word(tierName) == nil then
        return false, "There is no rank by that name."
    end

    local now = get_global_timer and get_global_timer() or 0
    if now - askedAt < 1800 then return false, "Already asked - give them a moment." end
    askedAt = now

    local ok, why = ask_host({ ofp = net.PACKET_ASK, t = tostring(tierName) })
    if not ok then

        askedAt = -9999
        return false, why or "There is no host to ask."
    end
    return true, why or "Asked the host."
end

function net.show_request(data)
    local li, globalIndex = OF.util.asked_by(data)
    if li == nil then return end
    local who = OF.util.plain(gNetworkPlayers[li].name)
        or ("player " .. tostring(globalIndex))

    local tier = OF.util.asks(OF.perms, "tier_from_word")
        and OF.perms.tier_from_word(data.t) or nil
    if tier == nil then return end
    local wanted = OF.perms.tier_name(tier)
    OF.notify.show("@ is asking for @", "warn", 6, who, wanted)
    OF.chatlog.add_system(OF.lang.fill("@ asked for @", who, wanted))
end

local function short_list(names, limit)
    local text = table.concat(names, ",")
    if #text <= limit then return text end
    return string.sub(text, 1, limit - 1) .. "+"
end

local function holds_engine_kick()
    return OF.util.optional("network_is_moderator", false) == true
end

net.rollAnswered = false

local function answer_roll_call()

    local answer = {
        ofp = net.PACKET_CHECKED,
        v = OF.VERSION,
        p = short_list(OF.missing_parts and OF.missing_parts() or {}, 120),
        b = short_list(OF.util.missing_bindings(), 120),

        k = OF.perms.can("panel"),

        c = OF.util.asks(OF.panel, "controller_failure")
            and OF.panel.controller_failure() or nil,

        r = OF.util.asks(OF.panel, "render_failure")
            and OF.panel.render_failure() or nil,

        m = holds_engine_kick() or nil,
    }

    net.rollAnswered = true

    if OF.util.asks(OF.pass, "post") then return OF.pass.post(answer) end
    return OF.util.send_to_host(answer)
end

net.answers = net.answers or {}

local function enrol_forgetting()
    if not OF.util.asks(OF.util, "on_forget_seat") then return false end
    return OF.util.on_forget_seat("roll call answers", function(localIndex)

        local globalIndex = network_global_index_from_local(localIndex)
        if globalIndex ~= nil then
            net.answers[globalIndex] = nil
            net.saidFaults[globalIndex] = nil
        end
    end)
end

net.saidFaults = net.saidFaults or {}

function net.show_answer(data, localIndex, quiet)
    local li = localIndex or select(1, OF.util.asked_by(data))
    if li == nil then return end
    local globalIndex = network_global_index_from_local(li)

    enrol_forgetting()
    net.answers[globalIndex] = {
        version = tostring(data.v or "?"),
        parts = tostring(data.p or ""),
        bindings = tostring(data.b or ""),
        panel = data.k,
        controller = data.c ~= nil and tostring(data.c) or nil,
        drawing = data.r ~= nil and tostring(data.r) or nil,

        moderator = data.m == true,
    }

    local who = OF.util.plain(gNetworkPlayers[li].name)
        or ("player " .. tostring(globalIndex))

    if data.m == true then
        OF.notify.show("@ holds the game's own kick", "warn", 8, who)
        OF.chatlog.add_system(OF.lang.fill(
            "@ is a moderator in the game itself - /kick and /ban are theirs, not this menu's",
            who))
    end

    local faults = {}
    if (data.p or "") ~= "" then table.insert(faults, "files: " .. data.p) end
    if (data.b or "") ~= "" then table.insert(faults, "missing: " .. data.b) end
    if data.k == false then table.insert(faults, "rank cannot open the mod menu") end

    if data.c ~= nil and tostring(data.c) ~= "" then
        table.insert(faults, "controls threw: " .. tostring(data.c))
    end
    if data.r ~= nil and tostring(data.r) ~= "" then
        table.insert(faults, "drawing threw: " .. tostring(data.r))
    end

    if #faults == 0 then
        if quiet then return end
        OF.util.chat(who
            .. " - everything loaded (" .. tostring(data.v) .. ")", nil, { more = true })
        return
    end

    local line = who .. " - " .. table.concat(faults, "; ")
    if quiet and net.saidFaults[globalIndex] == line then return end
    net.saidFaults[globalIndex] = line
    OF.util.chat(line, "warn", { more = true })
end

local ROLL_WAIT = 90
local rollAsked = nil
local rollFrames = 0

local function roll_answered(localIndex)
    if rollAsked == nil or localIndex == nil then return end
    rollAsked[localIndex] = nil
end

net.roll_answered = roll_answered

local function roll_finish()
    local silent, arriving = {}, {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if rollAsked[entry.localIndex] then
            local np = entry.np
            local name = OF.util.plain(np ~= nil and np.name or "?")
            local globalIndex = network_global_index_from_local(entry.localIndex)
            if OF.util.asks(OF.pass, "arriving")
                and OF.pass.arriving(globalIndex) then
                table.insert(arriving, name)
            else
                table.insert(silent, name)
            end
        end
    end
    rollAsked = nil

    if #arriving > 0 then
        OF.util.chat(OF.lang.fill(
            "@ is still arriving - the mod answers for them on its own once they are in.",
            table.concat(arriving, ", ")), "warn")
    end

    if #silent == 0 then
        if #arriving == 0 then
            OF.util.chat(OF.lang.t("Everybody in the lobby has the mod."))
        end
        return
    end
    OF.util.chat(OF.lang.fill(
        "No answer from @ - they do not have the mod, so nothing you do reaches them.",
        table.concat(silent, ", ")), "warn")
end

function net.roll_update()
    if rollAsked == nil then return end
    if not OF.util.is_host() then rollAsked = nil return end
    rollFrames = rollFrames + 1
    if rollFrames < ROLL_WAIT then return end
    roll_finish()
end

function net.roll_call()
    if not OF.util.is_host() then
        return false, "Only the host can ask the lobby."
    end
    send_all({ ofp = net.PACKET_CHECK })
    OF.util.chat("Asking the lobby what loaded...")
    local mine = OF.missing_parts and OF.missing_parts() or {}
    net.show_answer({
        v = OF.VERSION,
        p = table.concat(mine, ","),
        b = table.concat(OF.util.missing_bindings(), ","),
        k = OF.perms.can("panel"),

        m = holds_engine_kick() or nil,
    }, 0)

    rollAsked = {}
    rollFrames = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if not OF.util.is_host_player(entry.localIndex) then
            rollAsked[entry.localIndex] = true
        end
    end
    return true
end

local JOINER_MAX = 48
local joinerNames = {}
local joinerRuns = {}
local joinerThrew = {}

function net.on_joiner(name, run)
    if type(name) ~= "string" or name == "" then return false end
    if type(run) ~= "function" then return false end
    if joinerRuns[name] == nil then

        if #joinerNames >= JOINER_MAX then return false end
        table.insert(joinerNames, name)
    end
    joinerRuns[name] = run
    joinerThrew[name] = nil
    return true
end

function net.joiners()
    local out = {}
    for _, name in ipairs(joinerNames) do table.insert(out, name) end
    return out
end

function net.catch_up(globalIndex)
    if not OF.util.is_host() then return 0 end
    if globalIndex == nil or globalIndex == 0 then return 0 end
    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil or localIndex <= 0 then return 0 end

    if OF.wireWatch then OF.wire_mark("a joiner was caught up") end

    local ran = 0
    for _, name in ipairs(joinerNames) do
        local ok, why = pcall(joinerRuns[name], globalIndex, localIndex)
        if ok then
            ran = ran + 1
        elseif not joinerThrew[name] then

            joinerThrew[name] = true

            OF.notify.show("@ could not catch a joining player up", "bad", 8, name)

            OF.util.chat(OF.lang.fill("@ threw while catching a joiner up: @",
                name, OF.util.plain(tostring(why or "no reason given"))), "warn")
        end
    end
    return ran
end

local function ask_a_joiner_what_they_have(globalIndex, localIndex)
    if not OF.util.is_host() then return false end
    return OF.util.send_to_player(localIndex, { ofp = net.PACKET_CHECK })
end

net.on_joiner("roll call", ask_a_joiner_what_they_have)

function net.joiners_broken()
    local out = {}
    for _, name in ipairs(joinerNames) do
        if joinerThrew[name] then table.insert(out, name) end
    end
    return out
end

local ARRIVAL_MAX = 48
local arrivalNames = {}
local arrivalRuns = {}
local arrivalThrew = {}

net.arrived = false

function net.on_arrival(name, run)
    if type(name) ~= "string" or name == "" then return false end
    if type(run) ~= "function" then return false end
    if arrivalRuns[name] == nil then

        if #arrivalNames >= ARRIVAL_MAX then return false end
        table.insert(arrivalNames, name)
    end
    arrivalRuns[name] = run
    arrivalThrew[name] = nil
    return true
end

function net.arrivals()
    local out = {}
    for _, name in ipairs(arrivalNames) do table.insert(out, name) end
    return out
end

function net.arrivals_broken()
    local out = {}
    for _, name in ipairs(arrivalNames) do
        if arrivalThrew[name] then table.insert(out, name) end
    end
    return out
end

function net.arrival_reason(name)
    local why = arrivalThrew[name]
    if type(why) ~= "string" then return nil end
    return why
end

function net.arrive()

    if OF.util.is_host() then return 0 end
    if my_global() == 0 then return 0 end
    if net.arrived then return 0 end
    net.arrived = true

    local ran = 0
    for _, name in ipairs(arrivalNames) do
        local ok, why = pcall(arrivalRuns[name])
        if ok then
            ran = ran + 1
        elseif not arrivalThrew[name] then

            arrivalThrew[name] =
                OF.util.plain(tostring(why or "no reason given")) or true

            if OF.util.asks(OF.notify, "show") then
                OF.notify.show("@ could not settle you into the lobby", "bad", 8,
                    name)
            end
        end
    end
    return ran
end

hook_event(HOOK_ON_SYNC_VALID, net.arrive)

local function report_on_arrival()
    if net.rollAnswered then return false end
    return answer_roll_call()
end

net.on_arrival("roll call answer", report_on_arrival)

function net.engine_moderators()
    local out = {}

    for globalIndex = 0, MAX_PLAYERS - 1 do
        local answer = net.answers[globalIndex]
        if answer ~= nil and answer.moderator == true then

            local li = OF.util.local_from_global(globalIndex)
            local np = li ~= nil and gNetworkPlayers[li] or nil
            if np ~= nil and np.connected then
                table.insert(out, globalIndex)
            else

                net.answers[globalIndex] = nil
            end
        end
    end
    return out
end

local function snap_onto(targetLocalIndex)
    local t = gMarioStates[targetLocalIndex]
    if t == nil then return end
    net.snap_to(t.pos.x, t.pos.y + 60, t.pos.z, t.faceAngle.y)
end

local function snap_to(x, y, z, angle)
    local m = gMarioStates[0]
    if m == nil then return end

    if not OF.util.place_player(0, x, y, z) then return end

    m.vel.x = 0
    m.vel.y = 0
    m.vel.z = 0
    m.forwardVel = 0
    if angle ~= nil then m.faceAngle.y = angle end
    set_mario_action(m, ACT_FREEFALL, 0)

    if m.area ~= nil and m.area.camera ~= nil then
        OF.util.optional("soft_reset_camera", nil, m.area.camera)
    end
end

net.snap_to = snap_to

local FAVOURITES_KEY = "destfav"
local NOTE_PREFIX = "destnote_"
net.RECENT_PLACES = 6
net.recentPlaces = net.recentPlaces or {}

function net.favourite_names()

    local packed = mod_storage_load(FAVOURITES_KEY, "")
    local names = {}
    for name in string.gmatch(tostring(packed or ""), "[^,]+") do
        table.insert(names, name)
    end
    return names
end

function net.favourites()
    local list = {}
    for _, name in ipairs(net.favourite_names()) do
        local entry = OF.util.find_destination(name)
        if entry ~= nil then table.insert(list, entry) end
    end
    return list
end

function net.is_favourite(name)
    local wanted = string.lower(tostring(name or ""))
    for _, kept in ipairs(net.favourite_names()) do
        if string.lower(kept) == wanted then return true end
    end
    return false
end

function net.toggle_favourite(name)
    local entry = OF.util.find_destination(name)
    if entry == nil then return false, "Nowhere called that." end

    local kept = {}
    local removed = false
    for _, was in ipairs(net.favourite_names()) do
        if string.lower(was) == string.lower(entry.name) then
            removed = true
        else
            table.insert(kept, was)
        end
    end
    if not removed then table.insert(kept, entry.name) end

    OF.util.store(FAVOURITES_KEY, table.concat(kept, ","))
    return true, entry.name, not removed
end

function net.note_of(name)
    local entry = OF.util.find_destination(name)
    if entry == nil then return "" end

    return mod_storage_load(OF.util.storage_key(NOTE_PREFIX, entry.name), "")
end

function net.set_note(name, text)
    local entry = OF.util.find_destination(name)
    if entry == nil then return false, "Nowhere called that." end
    local key = OF.util.storage_key(NOTE_PREFIX, entry.name)
    if text == nil or text == "" then
        OF.util.store(key, "")
        return true, entry.name, false
    end
    OF.util.store(key, OF.util.storage_value(text))
    return true, entry.name, true
end

function net.recent_destinations()
    local list = {}
    for _, name in ipairs(net.recentPlaces) do
        local entry = OF.util.find_destination(name)
        if entry ~= nil then table.insert(list, entry) end
    end
    return list
end

function net.note_arrival(levelNum, areaIndex)
    local name = OF.util.level_name(levelNum, areaIndex)
    if name == nil or name == "" then return false end

    local kept = { name }
    for _, was in ipairs(net.recentPlaces) do
        if was ~= name and #kept < net.RECENT_PLACES then
            table.insert(kept, was)
        end
    end
    net.recentPlaces = kept
    return true
end

function net.random_destination()
    local me = gNetworkPlayers[0]
    local pool = {}

    for _, entry in ipairs(OF.LEVELS) do table.insert(pool, entry) end
    for _, entry in ipairs(OF.util.custom_levels()) do table.insert(pool, entry) end

    local choices = {}
    for _, entry in ipairs(pool) do
        local here = me ~= nil and entry.level == me.currLevelNum
            and entry.area == me.currAreaIndex
        if not here then table.insert(choices, entry) end
    end

    if #choices == 0 then return nil end
    return choices[math.random(#choices)]
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    local me = gNetworkPlayers[0]
    if me == nil then return end
    net.note_arrival(me.currLevelNum, me.currAreaIndex)
end)

function net.instant_warp(areaIndex)
    local me = gNetworkPlayers[0]
    if me == nil then return false end
    if type(areaIndex) ~= "number" then return false end
    return net.note_arrival(me.currLevelNum, areaIndex)
end

if HOOK_ON_INSTANT_WARP ~= nil then
    hook_event(HOOK_ON_INSTANT_WARP, net.instant_warp)
end

local function pos_update()
    local point = net.pendingPos
    local me = gNetworkPlayers[0]

    if me.currLevelNum ~= point.level or me.currAreaIndex ~= point.area then
        if not net.pendingWarped then
            net.pendingWarped = true
            net.warp_local(point.level, point.area, point.act)
        end
        return
    end

    if not me.currAreaSyncValid then return end

    snap_to(point.x, point.y, point.z, point.angle)
    net.pendingPos = nil
end

local WARP_RETRY = 45

local function warp_update()
    local want = net.pendingWarp
    local me = gNetworkPlayers[0]

    if me == nil or me.currLevelNum == nil or me.currLevelNum == 0 then return end

    if me.currLevelNum == want.level then

        if not me.currAreaSyncValid then return end
        net.pendingWarp = nil
        return
    end

    if (net.pendingTimer % WARP_RETRY) == 0 then
        net.warp_local(want.level, want.area, want.act)
    end
end

function net.tp_update()
    if net.pendingTarget == nil and net.pendingPos == nil
        and net.pendingWarp == nil then
        return
    end

    net.pendingTimer = net.pendingTimer + 1
    if net.pendingTimer > 900 then

        if OF.util.asks(OF.notify, "show") then
            if net.pendingWarp ~= nil then
                OF.notify.show("Could not get you to that level.", "bad", 5)
            else
                OF.notify.show("Teleport timed out.", "bad", 5)
            end
        end
        net.pendingTarget = nil
        net.pendingPos = nil
        net.pendingWarp = nil
        return
    end

    if net.pendingWarp ~= nil then
        warp_update()
        return
    end

    if net.pendingPos ~= nil then
        pos_update()
        return
    end

    local li = OF.util.local_from_global(net.pendingTarget)
    if li == nil then
        net.pendingTarget = nil
        return
    end

    local me = gNetworkPlayers[0]
    local them = gNetworkPlayers[li]

    if me.currLevelNum ~= them.currLevelNum or me.currAreaIndex ~= them.currAreaIndex then
        if not net.pendingWarped then
            net.pendingWarped = true
            net.warp_local(them.currLevelNum, them.currAreaIndex, them.currActNum)
        end
        return
    end

    if not them.currPositionValid then return end

    snap_onto(li)
    net.pendingTarget = nil
end

local function credit_the_asker(asker, what)
    if asker == nil then return false end
    if not OF.util.asks(OF.notify, "credit_named") then return false end
    return OF.notify.credit_named(asker, what)
end

function net.refuses_move(data)
    if data == nil then return false end
    local lobbys = data.ofp == net.PACKET_TP or data.ofp == net.PACKET_POS
        or data.ofp == net.PACKET_MOON or data.ofp == net.PACKET_CREDITS
        or (data.ofp == net.PACKET_WARP and data.lw ~= nil)
    if not lobbys then return false end
    return net.in_a_round(0)
end

local function on_packet_receive(data)
    if data == nil or data.ofp == nil then return end

    if data.ofp == net.PACKET_CHECKED then
        if OF.util.is_host() then

            local who = select(1, OF.util.asked_by(data))
            roll_answered(who)

            net.show_answer(data, nil, rollAsked == nil)
        end
        return
    end

    if data.ofp == net.PACKET_ASK then
        if OF.util.is_host() then net.show_request(data) end
        return
    end

    if data.ofp == net.PACKET_DO then
        if not OF.util.is_host() then return end
        local entry = net.ACTIONS[data.a]
        if entry == nil then return end

        local asker, askerGlobal = OF.util.asked_by(data)
        if asker == nil then return end
        if OF.perms.tier(asker) < OF.perms.required(entry.perm, asker) then
            OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
            return
        end

        local ok, why = OF.notify.acting(asker, entry.run, asker, data.x, data.y,
            data.z ~= nil and clean_say(data.z) or nil)
        if not ok and why ~= nil then
            OF.notify.send_to(askerGlobal, why, "warn", 4)
        end
        return
    end

    if data.ofp == net.PACKET_SAY_ASK then
        if not OF.util.is_host() then return end

        local asker, askerGlobal = OF.util.asked_by(data)
        if asker == nil then return end

        if OF.perms.tier(asker) < OF.perms.required("message", asker) then
            OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
            return
        end

        local message = clean_say(data.msg)
        if message == "" then return end

        local askerName = nil
        if gNetworkPlayers[asker] ~= nil then askerName = gNetworkPlayers[asker].name end
        if data.who == nil or data.who == "" then
            net.announce(message, askerName)
        else
            local aimed = {}
            for piece in string.gmatch(tostring(data.who), "[^,]+") do
                local index = tonumber(piece)
                if index ~= nil then table.insert(aimed, index) end
            end
            net.announce_to(aimed, message, askerName)
        end

        local np = gNetworkPlayers[asker]

        OF.chatlog.add_system(
            OF.lang.fill("showed the lobby: @", OF.util.plain(message)),
            np ~= nil and np.name or nil)
        return
    end

    if data.ofp == net.PACKET_WARP_ASK then
        if not OF.util.is_host() then return end

        local asker, askerGlobal = OF.util.asked_by(data)
        if asker == nil then return end

        if data.rd ~= nil then
            local level = tonumber(data.lvl)
            if level == nil then return end
            local moved, whyNot = net.lead_moves_round(asker, level,
                tonumber(data.area) or 1, tonumber(data.act) or 1)
            if not moved then
                OF.notify.send_to(askerGlobal, "@", "bad", 5,
                    tostring(whyNot or "Refused."))
            end
            return
        end
        if OF.perms.tier(asker) < OF.perms.required("warp_lobby", asker) then
            OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
            return
        end

        local np = gNetworkPlayers[asker]
        local who = np ~= nil and np.name or nil

        if data.u then
            local ok, why = net.undo_warp()
            if not ok then
                OF.notify.send_to(askerGlobal, "@", "bad", 5,
                    tostring(why or "Refused."))
                return
            end
            OF.chatlog.add_system(OF.lang.t("took the last lobby warp back"), who)
            credit_the_asker(asker, OF.lang.t("took the last lobby warp back"))
            return
        end

        local level = tonumber(data.lvl)
        if level == nil then return end
        local ok, why = net.warp_everyone(level, tonumber(data.area) or 1,
            tonumber(data.act) or 1)
        if not ok then
            OF.notify.send_to(askerGlobal, "@", "bad", 5, tostring(why or "Refused."))
            return
        end

        OF.chatlog.add_system(
            OF.lang.fill("moved the lobby to @", OF.util.level_name(level)), who)
        credit_the_asker(asker,
            OF.lang.fill("moved the lobby to @", OF.util.level_name(level)))
        return
    end

    if data.ofp == net.PACKET_MOVE_ASK then
        if not OF.util.is_host() then return end

        local asker, askerGlobal = OF.util.asked_by(data)
        if asker == nil then return end
        if OF.perms.tier(asker) < OF.perms.required("teleport_other", asker) then
            OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
            return
        end

        if data.a == net.MOVE_THINGS then
            local tier = net.THINGS_TIER or (OF.TIER and OF.TIER.MOD)
            if tier ~= nil and OF.perms.tier(asker) < tier then
                OF.notify.send_to(askerGlobal,
                    "Moving enemies and items is for Mod and up.", "bad", 5)
                return
            end
            local job = {}
            for _, key in ipairs(net.JOB_FIELDS) do job[key] = data[key] end
            local ok, why = net.run_things_job(job)
            if not ok then OF.notify.send_to(askerGlobal, why, "bad", 5) end
            return
        end

        local moved = 0
        for piece in string.gmatch(tostring(data.who or ""), "[^,]+") do
            local globalIndex = tonumber(piece)
            local target = globalIndex ~= nil
                and OF.util.local_from_global(globalIndex) or nil
            if may_move(asker, target) and globalIndex ~= data.tg then
                if data.a == net.MOVE_MOON then
                    net.moon_player(globalIndex)
                elseif data.a == net.MOVE_CREDITS then
                    net.credits_player(globalIndex)
                elseif data.a == net.MOVE_ONTO then
                    net.summon_player(globalIndex, data.tg)
                elseif data.a == net.MOVE_SPOT then
                    net.send_to_position(globalIndex, {
                        level = data.lvl, area = data.area, act = data.act,
                        x = data.x, y = data.y, z = data.z, angle = data.angle,
                    })
                else
                    net.warp_player(globalIndex, data.lvl, data.area, data.act)
                end
                moved = moved + 1
            end
        end

        if moved > 0 then
            local np = gNetworkPlayers[asker]
            OF.chatlog.add_system(
                OF.lang.fill("moved @ player(s)", moved),
                np ~= nil and np.name or nil)
            credit_the_asker(asker, OF.lang.fill("moved @ player(s)", moved))
        end
        return
    end

    if not OF.util.from_host_effect(data) then return end

    if data.ofp == net.PACKET_ECHO then
        net.take_echo(data)
        return
    end

    if data.ofp == net.PACKET_CHECK then
        answer_roll_call()
        return
    end

    if net.refuses_move(data) then return end

    if data.ofp == net.PACKET_WARP then

        net.warp_to(data.lvl, data.area, data.act)

        if OF.util.asks(OF.notify, "show") then
            OF.notify.show("The lobby moved to @", "info", 4,
                OF.util.level_name(data.lvl))
        end

    elseif data.ofp == net.PACKET_TP then
        net.teleport_to(data.tg)

    elseif data.ofp == net.PACKET_THINGS then
        net.things_local(data)

    elseif data.ofp == net.PACKET_POS then
        net.teleport_to_position({
            level = data.lvl, area = data.area, act = data.act,
            x = data.x, y = data.y, z = data.z, angle = data.angle,
        })

    elseif data.ofp == net.PACKET_MOON then
        net.moon_local()

    elseif data.ofp == net.PACKET_CREDITS then
        net.credits_local()

    elseif data.ofp == net.PACKET_ANNOUNCE then

        OF.welcome.show_banner(banner_segments(clean_say(data.msg)),
            said_by(data.by), true)

    end
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
hook_event(HOOK_UPDATE, function() net.tp_update() net.roll_update() net.lead_update() end)
