OF = OF or {}
OF.swap = OF.swap or {}

local swap = OF.swap

swap.PACKET_ASK  = "swpask"
swap.PACKET_HERE = "swphere"
swap.PACKET_GO   = "swpgo"
swap.WAIT_FRAMES = 5 * 30

local pending = nil

local plan = {}

local PLAN_GAP = 20
local planWait = 0

local frames = 0
local lastToken = 0

local REASONS = {
    notready = "@ is not in the game yet.",
    loading  = "@ is still loading their level.",
    cutscene = "@ is in a cutscene.",

    nofloor  = "@ is not standing anywhere - a swap would freeze the other one.",
}

function swap.here()
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or np == nil or m.pos == nil then return nil, "notready" end
    if not np.currAreaSyncValid then return nil, "loading" end
    if m.floor == nil then return nil, "nofloor" end
    if m.action ~= nil and (m.action & ACT_GROUP_MASK) == ACT_GROUP_CUTSCENE then
        return nil, "cutscene"
    end
    return {
        level = np.currLevelNum,
        area = np.currAreaIndex,
        act = np.currActNum,
        x = m.pos.x, y = m.pos.y, z = m.pos.z,
        angle = m.faceAngle.y,
    }
end

function swap.cannot(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return "That player has left." end
    local name = OF.util.plain(np.name)

    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex) then
        return OF.lang.fill("@ is serving a sentence.", name)
    end

    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return OF.lang.fill("@ is watching somebody.", name)
    end

    if OF.util.asks(OF.idle, "is_idle") and OF.idle.is_idle(localIndex) then
        return OF.lang.fill("@ is away.", name)
    end

    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(localIndex) then
        return OF.lang.fill("@ is in a round.", name)
    end
    return nil
end

local function name_of(globalIndex)
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return "" end
    local np = gNetworkPlayers[li]
    if np == nil then return "" end
    return OF.util.plain(np.name)
end

local function call_off(sentence)
    if pending == nil then return end
    local a, b = pending.order[1], pending.order[2]
    pending = nil

    local said = sentence
    if said == nil or said == "" then
        said = "The swap was called off - nobody moved."
    end
    OF.notify.show("@", "warn", 5, said)
    for _, globalIndex in ipairs({ a, b }) do
        OF.notify.send_to(globalIndex, "The swap was called off - you did not move",
            "warn", 5)
    end
end

local function send_go(globalIndex, point)
    if not OF.util.is_host() then return false end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false end
    if li == 0 then
        OF.net.teleport_to_position(point)
        return true
    end
    return OF.util.send_to_player(li, {
        ofp = swap.PACKET_GO,
        lvl = point.level, area = point.area, act = point.act,
        x = point.x, y = point.y, z = point.z, angle = point.angle,
    })
end

local function finish()
    local a, b = pending.order[1], pending.order[2]
    local pa, pb = pending.who[a].point, pending.who[b].point
    if pa == nil or pb == nil then return end

    if OF.util.local_from_global(a) == nil or OF.util.local_from_global(b) == nil then
        call_off(OF.lang.t("One of them left before it could finish."))
        return
    end

    local nameA, nameB = name_of(a), name_of(b)
    local byTimer = pending.timer == true
    local byChaos = pending.cause == "chaos"
    pending = nil

    send_go(a, pb)
    send_go(b, pa)

    local mine = network_global_index_from_local(0)
    if byTimer then
        OF.notify.show("The swap timer traded @ and @.", "good", 5, nameA, nameB)
        OF.notify.send_to(a, "The swap timer swapped you with @", "good", 5, nameB)
        OF.notify.send_to(b, "The swap timer swapped you with @", "good", 5, nameA)
    elseif byChaos then

        OF.notify.show("Chaos traded @ and @.", "good", 5, nameA, nameB)
        OF.notify.send_to(a, "Chaos swapped you with @", "good", 5, nameB)
        OF.notify.send_to(b, "Chaos swapped you with @", "good", 5, nameA)
    else
        if a ~= mine and b ~= mine then
            OF.notify.show("Swapped @ and @.", "good", 4, nameA, nameB)
        end
        OF.notify.send_to(a, "You swapped places with @", "good", 5, nameB)
        OF.notify.send_to(b, "You swapped places with @", "good", 5, nameA)
    end
    if OF.util.asks(OF.chatlog, "add_system") then
        OF.chatlog.add_system(OF.lang.fill("swapped @ and @", nameA, nameB))
    end
end

local WORLD_EDGE = 0x8000

local function believable(localIndex, point)
    if point == nil then return false end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return false end

    if point.level ~= np.currLevelNum then return false end
    if point.area ~= np.currAreaIndex then return false end

    local x, y, z = tonumber(point.x), tonumber(point.y), tonumber(point.z)
    if x == nil or y == nil or z == nil then return false end

    local floor = -11000

    if OF.is_object(gLevelValues) then
        floor = tonumber(gLevelValues.floorLowerLimit) or floor
    end
    if y < floor then return false end
    if math.abs(x) > WORLD_EDGE or math.abs(z) > WORLD_EDGE then return false end
    return true
end

local function answered(globalIndex, point, why)
    if pending == nil then return end
    local entry = pending.who[globalIndex]
    if entry == nil or entry.point ~= nil then return end

    if point == nil then
        local template = REASONS[tostring(why)] or "@ cannot be moved right now."
        call_off(OF.lang.fill(template, name_of(globalIndex)))
        return
    end

    if not believable(entry.localIndex, point) then
        call_off(OF.lang.fill("@ answered with a place they are not in.",
            name_of(globalIndex)))
        return
    end

    entry.point = point
    finish()
end

local function run(fromLocal, whoA, whoB, cause)

    local a = tonumber(whoA)
    local b = tonumber(whoB)
    if not OF.util.is_host() then return false, "Only the host." end
    if a == nil or b == nil then return false, "Nobody to swap." end
    if a == b then return false, "That is the same player twice." end
    if pending ~= nil then return false, "A swap is already going on." end

    local la = OF.util.local_from_global(a)
    local lb = OF.util.local_from_global(b)
    if la == nil or lb == nil then return false, "That player has left." end

    for _, li in ipairs({ la, lb }) do
        local may, whyNot = OF.util.may_act_on(fromLocal, li)
        if not may then return false, whyNot end
    end

    local why = swap.cannot(la) or swap.cannot(lb)
    if why ~= nil then return false, why end

    local mine, minePoint = nil, nil
    if la == 0 then mine = a elseif lb == 0 then mine = b end
    if mine ~= nil then
        local point, no = swap.here()
        if point == nil then
            return false, OF.lang.fill(
                REASONS[tostring(no)] or "@ cannot be moved right now.",
                name_of(mine))
        end
        minePoint = point
    end

    local id = lastToken + 1
    for _, entry in ipairs({ { a, la }, { b, lb } }) do
        if entry[2] ~= 0 then
            local sent, whyNot = OF.util.send_to_player(entry[2],
                { ofp = swap.PACKET_ASK, id = id })
            if not sent then
                return false, whyNot or "That player has left."
            end
        end
    end

    lastToken = id
    pending = {
        id = id,
        at = frames,
        order = { a, b },
        who = { [a] = { localIndex = la }, [b] = { localIndex = lb } },
    }
    if mine ~= nil then pending.who[mine].point = minePoint end

    if cause == "chaos" and fromLocal == 0 then pending.cause = "chaos" end

    return true, "Asked them both where they are."
end

function swap.waiting()
    return pending ~= nil
end

function swap.begin(globalA, globalB, cause)
    if not OF.util.asks(OF.net, "host_does") then
        return false, "The lobby's network part is not loaded."
    end
    return OF.net.host_does("swap", globalA, globalB, cause)
end

local function shufflable(fromLocal)
    local out = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        if swap.cannot(li) == nil and OF.util.may_act_on(fromLocal, li) then
            local globalIndex = network_global_index_from_local(li)
            if globalIndex ~= nil then table.insert(out, globalIndex) end
        end
    end
    return out
end

local function run_shuffle(fromLocal)
    if not OF.util.is_host() then return false, "Only the host." end
    if pending ~= nil or #plan > 0 then
        return false, "A swap is already going on."
    end

    local who = shufflable(fromLocal)
    if #who < 2 then
        return false, "There are not two people who can be moved."
    end

    for i = #who, 2, -1 do
        local j = math.random(i)
        who[i], who[j] = who[j], who[i]
    end

    plan = {}
    for i = 1, #who - 1, 2 do
        table.insert(plan, { who[i], who[i + 1] })
    end
    planWait = 0

    local left = #who % 2
    if left == 1 then
        return true, OF.lang.fill("Shuffling @ pair(s) - one person stays put.",
            #plan)
    end
    return true, OF.lang.fill("Shuffling @ pair(s).", #plan)
end

function swap.pairs_left()
    return #plan
end

function swap.plan_pairs()
    local out = {}
    for _, pair in ipairs(plan) do
        table.insert(out, { pair[1], pair[2] })
    end
    return out
end

local function run_stop_shuffle()
    if not OF.util.is_host() then return false, "Only the host." end
    local left = #plan
    plan = {}
    planWait = 0
    if left == 0 then return false, "No shuffle is going on." end
    return true, OF.lang.fill("Stopped - @ pair(s) will not trade.", left)
end

function swap.stop_shuffle()
    if not OF.util.asks(OF.net, "host_does") then
        return false, "The lobby's network part is not loaded."
    end
    return OF.net.host_does("swapstop")
end

function swap.shuffle()
    if not OF.util.asks(OF.net, "host_does") then
        return false, "The lobby's network part is not loaded."
    end
    return OF.net.host_does("swapall")
end

swap.EVERY_STOPS = {
    { name = "never" },
    { name = "every half minute", seconds = 30 },
    { name = "every 90 seconds",  seconds = 90 },
    { name = "every three minutes", seconds = 180 },
    { name = "every five minutes",  seconds = 300 },
}
swap.EVERY_PLAIN = 1

local everyAt = swap.EVERY_PLAIN
local everySeen = nil

function swap.every_stop()
    local at = math.floor(tonumber(everyAt) or swap.EVERY_PLAIN)
    if at < 1 or at > #swap.EVERY_STOPS then at = swap.EVERY_PLAIN end
    return swap.EVERY_STOPS[at], at
end

local function run_every(fromLocal, want)
    if not OF.util.is_host() then return false, "Only the host." end
    local at = math.floor(tonumber(want) or swap.EVERY_PLAIN)
    if at < 1 then at = #swap.EVERY_STOPS end
    if at > #swap.EVERY_STOPS then at = 1 end
    everyAt = at

    everySeen = clock_elapsed()

    local stop = swap.EVERY_STOPS[at]
    if stop == nil or stop.seconds == nil then
        return true, "The swap timer is off."
    end
    return true, OF.lang.fill("Two random players now swap places @.", OF.lang.t(stop.name))
end

function swap.stop_timer()
    if not OF.util.is_host() then return false end
    local was = swap.every_stop().seconds ~= nil
    everyAt = swap.EVERY_PLAIN
    everySeen = nil
    return was
end

function swap.set_every(at)
    if not OF.util.asks(OF.net, "host_does") then
        return false, "The lobby's network part is not loaded."
    end
    return OF.net.host_does("swapevery", at)
end

function swap.next_every()
    local _, at = swap.every_stop()
    return swap.set_every(at + 1)
end

local function timer_may_fire()
    local stop = swap.every_stop()
    if stop.seconds == nil then return false end
    if not OF.util.is_host() then return false end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false
    end
    return true
end

local function answer_the_host(id)
    if OF.util.is_host() then return end

    local point, why = swap.here()
    local answer
    if point == nil then
        answer = { ofp = swap.PACKET_HERE, id = id, no = why }
    else
        answer = {
            ofp = swap.PACKET_HERE, id = id,
            lvl = point.level, area = point.area, act = point.act,
            x = point.x, y = point.y, z = point.z, angle = point.angle,
        }
    end

    if OF.util.asks(OF.pass, "post") then return OF.pass.post(answer) end
    return OF.util.send_to_host(answer)
end

local function on_packet_receive(data)
    if data == nil or data.ofp == nil then return end

    if data.ofp == swap.PACKET_HERE then
        if not OF.util.is_host() then return end
        if pending == nil then return end

        local _, globalIndex = OF.util.asked_by(data)
        if globalIndex == nil then return end
        if tonumber(data.id) ~= pending.id then return end

        if data.no ~= nil then
            answered(globalIndex, nil, data.no)
            return
        end
        answered(globalIndex, {
            level = data.lvl, area = data.area, act = data.act,
            x = data.x, y = data.y, z = data.z, angle = data.angle,
        })
        return
    end

    if not OF.util.from_host_effect(data) then return end

    if data.ofp == swap.PACKET_ASK then
        answer_the_host(tonumber(data.id))
        return
    end

    if data.ofp == swap.PACKET_GO then

        OF.net.teleport_to_position({
            level = data.lvl, area = data.area, act = data.act,
            x = data.x, y = data.y, z = data.z, angle = data.angle,
        })
        return
    end
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)

local function step_plan()
    if pending ~= nil then planWait = PLAN_GAP; return end
    if #plan == 0 then return end
    if planWait > 0 then planWait = planWait - 1; return end

    local pair = table.remove(plan, 1)

    local ok, why = run(0, pair[1], pair[2])
    if ok and pending ~= nil and pair.timer == true then pending.timer = true end
    if not ok then

        OF.notify.show("@", "warn", 4, why or OF.lang.t("That pair could not trade."))
    end
    planWait = PLAN_GAP
end

hook_event(HOOK_UPDATE, function()
    frames = frames + 1

    if OF.util.is_host() then
        step_plan()

        if timer_may_fire() then
            local now = clock_elapsed()
            if everySeen == nil then everySeen = now end
            local stop = swap.every_stop()
            if now - everySeen >= stop.seconds then
                everySeen = now

                if pending == nil and #plan == 0 then
                    local who = shufflable(0)
                    if #who >= 2 then
                        local i = math.random(#who)
                        local j = math.random(#who - 1)
                        if j >= i then j = j + 1 end
                        plan = { { who[i], who[j], timer = true } }
                        planWait = 0
                    end
                end
            end
        else

            everySeen = nil
        end
    end

    if pending == nil then return end

    for _, globalIndex in ipairs(pending.order) do
        if OF.util.local_from_global(globalIndex) == nil then
            call_off(OF.lang.t("One of them left before it could finish."))
            return
        end
    end

    if frames - pending.at > swap.WAIT_FRAMES then
        local waiting = {}
        for _, globalIndex in ipairs(pending.order) do
            if pending.who[globalIndex].point == nil then
                table.insert(waiting, name_of(globalIndex))
            end
        end
        call_off(OF.lang.fill("@ never answered.", table.concat(waiting, ", ")))
    end
end)

function swap.build_rows(panel, localIndex)
    local rows = {}
    if localIndex == nil or panel == nil then return rows end

    local other = panel.selection_only_other(localIndex)
    if other == nil then return rows end

    local mine = network_global_index_from_local(localIndex)
    local otherLocal = OF.util.local_from_global(other)
    if otherLocal == nil then return rows end

    local here = gNetworkPlayers[localIndex]
    local there = gNetworkPlayers[otherLocal]
    if here == nil or there == nil then return rows end

    table.insert(rows, panel.with_help(panel.gated_confirm_row("teleport_other",
        "swap" .. tostring(mine) .. "_" .. tostring(other),
        OF.lang.fill("Swap @ with @", here.name, there.name),
        255, 200, 120, function()

            local ok, why = swap.begin(mine, other)
            OF.net.report_move(ok, why,
                OF.lang.t("Asked them both where they are."))
        end),
        OF.lang.t("they exchange places, across levels as readily as across a room")))

    return rows
end

function swap.build_room_rows(panel)
    local rows = {}
    if panel == nil then return rows end

    local left = swap.pairs_left()
    if left > 0 then
        table.insert(rows, panel.with_help(panel.gated_row("teleport_other",
            OF.lang.fill("Stop shuffling (@ pair(s) left)", left),
            255, 200, 120, function()
                OF.util.report(swap.stop_shuffle())
            end),
            OF.lang.t("the pair being asked finishes; nothing after it starts")))
    else
        table.insert(rows, panel.with_help(panel.gated_confirm_row("teleport_other",
            "swapall",
            OF.lang.t("Shuffle everybody"),
            255, 200, 120, function()
                OF.util.report(swap.shuffle())
            end),
            OF.lang.t("the lobby is dealt into pairs and every pair swaps places")))
    end

    return rows
end

function swap.build_timer_row(panel)
    if panel == nil then return nil end
    local stop = swap.every_stop()
    local built = panel.gated_row("teleport_other",
        OF.lang.t("Two players swap places"), 255, 255, 255, function()
            OF.util.report(swap.next_every())
        end)
    return panel.with_help(
        panel.level_right(built, stop.seconds ~= nil, OF.lang.t(stop.name)),
        OF.lang.t("on its own, and never inside a round or a run"))
end

local registered = false

function swap.ready()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action("swap", "teleport_other", run)

    OF.net.register_action("swapall", "teleport_other", run_shuffle)
    OF.net.register_action("swapstop", "teleport_other", run_stop_shuffle)
    OF.net.register_action("swapevery", "teleport_other", run_every)
end

hook_event(HOOK_UPDATE, function() swap.ready() end)
