OF = OF or {}
OF.net = OF.net or {}

local net = OF.net

net.PACKET_WARP    = "warp"
net.PACKET_TP      = "tp"
net.PACKET_POS     = "pos"
net.PACKET_ANNOUNCE = "say"
net.PACKET_MOON    = "moon"
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

local function ask_host(data)

    if OF.util.is_host() then return false, "You are the host." end
    if OF.util.asks(OF.pass, "post") then return OF.pass.post(data) end

    if not OF.util.send_to_host(data) then
        return false, "There is no host to ask."
    end
    return true, "Asked the host."
end

function net.warp_local(level, area, act, alsoLevels, refusal)

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

function net.warp_everyone(level, area, act, refusal)
    if not OF.perms.can("warp_lobby") then
        return false, "Your rank cannot do that.", "warp_lobby"
    end
    if not OF.util.is_host() then

        return ask_host({
            ofp = net.PACKET_WARP_ASK, lvl = level, area = area, act = act,
        })
    end
    snapshot_lobby()
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

function net.undo_warp()
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
        net.warp_player(entry.globalIndex, entry.level, entry.area, entry.act)
    end
    return true
end

net.PACKET_WARP_ASK = "wrpask"
net.PACKET_MOVE_ASK = "moveask"
net.MOVE_WARP = "w"
net.MOVE_MOON = "m"
net.MOVE_ONTO = "t"
net.MOVE_SPOT = "p"
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

function net.warp_the_round(level, area, act)
    if not OF.perms.can("warp_lobby") then
        return false, "Your rank cannot do that.", "warp_lobby"
    end
    if not OF.util.is_host() then
        return ask_host({
            ofp = net.PACKET_WARP_ASK, lvl = level, area = area, act = act,
        })
    end

    local sittingOut = OF.util.asks(OF.speedrun, "is_excluded")

    local awayKnown = OF.util.asks(OF.idle, "left_out")
    local behind = 0
    snapshot_lobby()
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        if li ~= 0 then
            if sittingOut and OF.speedrun.is_excluded(li) then

                OF.notify.send_to(network_global_index_from_local(li),
                    "The round has gone on without you - you are sitting out",
                    "info", 5)
            elseif awayKnown and OF.idle.left_out(li) then

                behind = behind + 1
            else
                send_one(li, { ofp = net.PACKET_WARP,
                    lvl = level, area = area, act = act })
            end
        end
    end

    if behind > 0 and OF.util.asks(OF.notify, "show") then
        OF.notify.show("@ away from the keyboard - the round starts without them.",
            "info", 6, tostring(behind))
    end

    if OF.util.asks(OF.gamemodes, "room_moving") then
        OF.gamemodes.room_moving()
    end

    net.warp_to(level, area, act)
    return true
end

function net.warp_player(globalIndex, level, area, act)
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
    send_one(li, { ofp = net.PACKET_WARP, lvl = level, area = area, act = act })
    return true
end

function net.teleport_to(globalIndex)
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
    send_all({
        ofp = net.PACKET_POS,
        lvl = point.level, area = point.area, act = point.act,
        x = point.x, y = point.y, z = point.z, angle = point.angle,
    })
    net.teleport_to_position(point)

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
    if OF.util.is_host() then return entry.run(0, x, y, z) end
    local ok, why = ask_host({ ofp = net.PACKET_DO, a = name, x = x, y = y,
        z = z ~= nil and clean_say(z) or nil })
    if not ok then return false, why or "No host to ask yet - try again in a second." end

    return true, "asked"
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

    OF.notify.show("@ is asking for @", "warn", 6, who, tostring(data.t))
    OF.chatlog.add_system(OF.lang.fill("@ asked for @", who, tostring(data.t)))
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
        if globalIndex ~= nil then net.answers[globalIndex] = nil end
    end)
end

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
        djui_chat_message_create("  \\#a0ffa0\\" .. who
            .. "\\#dcdcdc\\ - everything loaded (" .. tostring(data.v) .. ")")
        return
    end
    djui_chat_message_create("  \\#ff6060\\" .. who .. "\\#dcdcdc\\ - "
        .. table.concat(faults, "; "))
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
        OF.util.chat("\\#ffb060\\" .. OF.lang.fill(
            "@ is still arriving - the mod answers for them on its own once they are in.",
            table.concat(arriving, ", ")))
    end

    if #silent == 0 then
        if #arriving == 0 then
            OF.util.chat("\\#a0ffa0\\" .. OF.lang.t("Everybody in the lobby has the mod."))
        end
        return
    end
    OF.util.chat("\\#ff6060\\" .. OF.lang.fill(
        "No answer from @ - they do not have the mod, so nothing you do reaches them.",
        table.concat(silent, ", ")))
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

            OF.util.chat("\\#ff6060\\" .. OF.lang.fill("@ threw while catching a joiner up: @",
                name, OF.util.plain(tostring(why or "no reason given"))))
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
        if OF.perms.tier(asker) < OF.perms.required(entry.perm) then
            OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
            return
        end

        local ok, why = entry.run(asker, data.x, data.y,
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

        if OF.perms.tier(asker) < OF.perms.required("message") then
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
        if OF.perms.tier(asker) < OF.perms.required("warp_lobby") then
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
        if OF.perms.tier(asker) < OF.perms.required("teleport_other") then
            OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
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

    if data.ofp == net.PACKET_CHECK then
        answer_roll_call()
        return
    end

    if data.ofp == net.PACKET_WARP then

        net.warp_to(data.lvl, data.area, data.act)

        if OF.util.asks(OF.notify, "show") then
            OF.notify.show("The lobby moved to @", "info", 4,
                OF.util.level_name(data.lvl))
        end

    elseif data.ofp == net.PACKET_TP then
        net.teleport_to(data.tg)

    elseif data.ofp == net.PACKET_POS then
        net.teleport_to_position({
            level = data.lvl, area = data.area, act = data.act,
            x = data.x, y = data.y, z = data.z, angle = data.angle,
        })

    elseif data.ofp == net.PACKET_MOON then
        net.moon_local()

    elseif data.ofp == net.PACKET_ANNOUNCE then

        OF.welcome.show_banner(banner_segments(clean_say(data.msg)),
            said_by(data.by), true)

    end
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
hook_event(HOOK_UPDATE, function() net.tp_update() net.roll_update() end)
