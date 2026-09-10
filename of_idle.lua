OF = OF or {}
OF.idle = OF.idle or {}

local idle = OF.idle

local AWAY_FRAMES = 180 * 30
local MOVED = 8

idle.LEFT_OUT_FRAMES = 120 * 30

local stillFrames = 0
local awayFrames = 0
local lastX, lastY, lastZ = nil, nil, nil

local function span_text(frames)
    local seconds = math.floor((frames or 0) / 30)
    if seconds < 60 then return string.format("%.0fs", seconds) end
    return string.format("%.0fm", math.floor(seconds / 60))
end

function idle.in_a_round(localIndex)
    if OF.gamemodes == nil or not OF.gamemodes.is_running() then return false end
    local role = OF.gamemodes.role(localIndex)
    return role ~= "" and role ~= OF.gamemodes.WAITING
end

function idle.is_idle(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return false end
    return row.ofIdle == true
end

function idle.left_out(localIndex)
    if not idle.is_idle(localIndex) then return false end
    if idle.in_a_round(localIndex) then return false end
    local since = idle.away_for(localIndex)
    if since == nil then return false end
    return since >= idle.LEFT_OUT_FRAMES
end

function idle.seconds_still()
    return math.floor(stillFrames / 30)
end

local function publish(value)
    if gPlayerSyncTable[0].ofIdle == value then return end
    OF.util.publish_row(0, "ofIdle", value)
    if value then
        awayFrames = 0

        OF.notify.show(
            "Away after three idle minutes. You sit out the next round.",
            "warn", 5)
    else

        if OF.util.asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running()
            and not idle.in_a_round(0) then
            OF.notify.show("Back after @. A round is on - you are in the next.",
                "good", 6, span_text(awayFrames))
        else
            OF.notify.show("Back after @. You are in the next round again.",
                "good", 4, span_text(awayFrames))
        end
        awayFrames = 0
    end
end

function idle.mark_back()
    stillFrames = 0
    publish(false)
    return true
end

local function watch(m)
    if m == nil or m.playerIndex ~= 0 then return end

    OF.input.poll(m)

    if idle.is_idle(0) then awayFrames = awayFrames + 1 else awayFrames = 0 end

    local moved = false
    if lastX ~= nil then
        moved = math.abs(m.pos.x - lastX) > MOVED
            or math.abs(m.pos.y - lastY) > MOVED
            or math.abs(m.pos.z - lastZ) > MOVED
    end
    lastX, lastY, lastZ = m.pos.x, m.pos.y, m.pos.z

    if idle.in_a_round(0) then
        stillFrames = 0

        if idle.is_idle(0) then publish(false) end
        return
    end

    local touched = (OF.input.down ~= 0) or moved

    if touched then
        stillFrames = 0

        if idle.is_idle(0) then publish(false) end
        return
    end

    stillFrames = stillFrames + 1
    if stillFrames >= AWAY_FRAMES and not idle.is_idle(0) then
        publish(true)
    end
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, watch)

hook_event(HOOK_ON_LEVEL_INIT, function()
    lastX, lastY, lastZ = nil, nil, nil
end)

idle.PACKET_BACK = "iback"
local frames = 0
local seenAwayAt = {}
local wasAway = {}
local wentQuiet = {}

local function forget(localIndex)
    seenAwayAt[localIndex] = nil
    wasAway[localIndex] = nil
    wentQuiet[localIndex] = nil
end

function idle.away_for(localIndex)
    local since = seenAwayAt[localIndex]
    if since == nil then return nil end
    if not idle.is_idle(localIndex) then return nil end
    return frames - since
end

function idle.away_text(localIndex)
    if not idle.is_idle(localIndex) then return "" end
    local since = idle.away_for(localIndex)
    if since == nil then return OF.lang.t("away") end
    return OF.lang.fill("away @", span_text(since))
end

local function quiet_watch()
    if not OF.util.is_host() then return end
    for i = 1, MAX_PLAYERS - 1 do
        local gap = idle.silent_for(i)
        if gap == nil then

            wentQuiet[i] = nil
        elseif gap >= idle.QUIET_SECONDS then
            if not wentQuiet[i] then
                wentQuiet[i] = true
                local np = gNetworkPlayers[i]
                local name = np ~= nil and OF.util.plain(np.name) or ""
                if name ~= "" then

                    local since = nil
                    if OF.util.asks(OF.unstick, "stalled_within") then
                        since = OF.unstick.stalled_within(
                            tonumber(OF.util.optional("clock_elapsed", 0)) or 0, gap)
                    end

                    if since ~= nil then
                        OF.notify.show("@ looks quiet - this machine stopped, not theirs",
                            "warn", 6, name)
                    else
                        OF.notify.show("@ has gone quiet - nothing for @s",
                            "warn", 6, name, string.format("%.0f", gap))
                    end
                    if OF.util.asks(OF.actionlog, "auto") then
                        OF.actionlog.auto(OF.lang.fill("@ went quiet on the wire", name))
                    end
                end
            end
        elseif wentQuiet[i] then
            wentQuiet[i] = false
            local np = gNetworkPlayers[i]
            local name = np ~= nil and OF.util.plain(np.name) or ""
            if name ~= "" then
                OF.notify.show("@ is back on the wire", "good", 4, name)
                if OF.util.asks(OF.actionlog, "auto") then
                    OF.actionlog.auto(OF.lang.fill("@ came back on the wire", name))
                end
            end
        end
    end
end

local function watch_the_room()
    frames = frames + 1
    if frames % 30 ~= 0 then return end

    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np == nil or not np.connected then
            forget(i)
        else
            local away = idle.is_idle(i)

            if away and wasAway[i] == false then seenAwayAt[i] = frames end
            if not away then seenAwayAt[i] = nil end
            wasAway[i] = away
        end
    end

    quiet_watch()
end

hook_event(HOOK_UPDATE, watch_the_room)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    forget(m.playerIndex)
end)

hook_event(HOOK_ON_PLAYER_CONNECTED, function(m)
    if m == nil then return end
    forget(m.playerIndex)
end)

local function ask_them_back(localIndex)
    if not OF.util.is_host() then return false, "Only the host." end
    if localIndex == 0 then
        idle.mark_back()
        return true
    end
    local ok, why = OF.util.send_to_player(localIndex, { ofp = idle.PACKET_BACK })
    if not ok then return false, why or "They have left the lobby." end
    return true
end

function idle.bring_back(globalIndex)
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false, "That player has left." end
    if not idle.is_idle(li) then return false, "They are not away." end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("awayback", globalIndex)
    end
    return ask_them_back(li)
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= idle.PACKET_BACK then return end

    if not OF.util.from_host(data) then return end
    if not idle.is_idle(0) then return end
    idle.mark_back()
    OF.notify.show("The host marked you as back", "info", 5)
end)

idle.DROP_SECONDS = 15

idle.QUIET_SECONDS = 7

function idle.silent_for(localIndex)
    if not OF.util.is_host() then return nil end
    if localIndex == nil or localIndex == 0 then return nil end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return nil end

    local now = tonumber(OF.util.optional("clock_elapsed", 0))

    if now == nil or now ~= now or now <= 0 then return nil end

    local last = tonumber(np.lastReceived)
    if last == nil or last ~= last or last <= 0 then return nil end

    local gap = now - last
    if gap < 0 then gap = 0 end
    return gap
end

function idle.gone_quiet(localIndex)
    local gap = idle.silent_for(localIndex)
    return gap ~= nil and gap >= idle.QUIET_SECONDS
end

function idle.silent_text(localIndex)
    local gap = idle.silent_for(localIndex)
    if gap == nil or gap < idle.QUIET_SECONDS then return "" end
    return OF.lang.fill("silent @s", string.format("%.0f", gap))
end

function idle.link_note(localIndex)
    local np = localIndex ~= nil and gNetworkPlayers[localIndex] or nil
    if np == nil then return OF.lang.t("no connection to read") end
    local ping = math.floor(tonumber(np.ping) or 0)
    if ping >= 1000 then
        return OF.lang.t("round trip is over a second - the game stops counting there")
    end
    return OF.lang.fill("@ms there and back - the game shows half of that", ping)
end

function idle.build_rows(panel, localIndex)
    local rows = {}
    if localIndex == nil then return rows end

    local np = gNetworkPlayers[localIndex]
    if np == nil then return rows end

    local silent = idle.silent_for(localIndex)
    if silent ~= nil and silent >= idle.QUIET_SECONDS then
        local left = idle.DROP_SECONDS - silent
        if left < 0 then left = 0 end
        rows[#rows + 1] = panel.with_help(panel.with_right(
            panel.label_row(OF.lang.fill(
                "@'s game has said nothing for @s", OF.util.plain(np.name),
                string.format("%.0f", silent)), 255, 150, 150),
            OF.lang.fill("dropped in @s", string.format("%.0f", left))),
            idle.link_note(localIndex))
    end

    if not idle.is_idle(localIndex) then return rows end
    local globalIndex = network_global_index_from_local(localIndex)

    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("speedrun", OF.lang.fill("Mark @ as back", np.name),
            160, 255, 160, function()
                OF.util.report(idle.bring_back(globalIndex))
            end),
        idle.away_text(localIndex)),
        OF.lang.t("they decide for themselves - this asks their game to clear it")))

    return rows
end

local registered = false

function idle.ready()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action("awayback", "speedrun", function(fromLocal, who)
        if not OF.util.is_host() then return false, "Only the host." end
        local target = OF.util.local_from_global(tonumber(who))

        local may, whyNot = OF.util.may_act_on(fromLocal, target)
        if not may then return false, whyNot end
        return ask_them_back(target)
    end)
end

hook_event(HOOK_UPDATE, function() idle.ready() end)
