OF = OF or {}
OF.swap = OF.swap or {}

local swap = OF.swap

swap.PACKET_ASK  = "swpask"
swap.PACKET_HERE = "swphere"
swap.PACKET_GO   = "swpgo"
swap.WAIT_FRAMES = 5 * 30

local pending = nil

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
    pending = nil

    send_go(a, pb)
    send_go(b, pa)

    local mine = network_global_index_from_local(0)
    if a ~= mine and b ~= mine then
        OF.notify.show("Swapped @ and @.", "good", 4, nameA, nameB)
    end
    OF.notify.send_to(a, "You swapped places with @", "good", 5, nameB)
    OF.notify.send_to(b, "You swapped places with @", "good", 5, nameA)
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

local function run(fromLocal, whoA, whoB)

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

    return true, "Asked them both where they are."
end

function swap.waiting()
    return pending ~= nil
end

function swap.begin(globalA, globalB)
    if not OF.util.asks(OF.net, "host_does") then
        return false, "The lobby's network part is not loaded."
    end
    return OF.net.host_does("swap", globalA, globalB)
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

hook_event(HOOK_UPDATE, function()
    frames = frames + 1
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

local registered = false

function swap.ready()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action("swap", "teleport_other", run)
end

hook_event(HOOK_UPDATE, function() swap.ready() end)
