OF = OF or {}
OF.pass = OF.pass or {}

local pass = OF.pass

pass.PACKET_ASK = "ofpka"
pass.PACKET = "ofpk"
pass.PACKET_OK = "ofpko"
pass.PACKET_DONE = "ofpkd"
pass.PACKET_SET = "ofpks"
pass.PACKET_POKE = "ofpkp"
local LENGTH = 24
local ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789"
local mine = nil
local settled = false

local nonce = nil

local staleOffers = 0
local STALE_AFTER = 10

local issued = {}
local answered = {}
local ready = {}

local caughtUp = {}

local tries = {}
local told = {}
local TELL_AFTER = 10

local RETRY_FRAMES = 60

local repliedReady = {}

local pokeGap = RETRY_FRAMES

local function fine_clock()
    local seconds = OF.util.optional("clock_elapsed_f64", nil)
    if type(seconds) ~= "number" then

        seconds = (OF.util.optional("get_global_timer", 0) or 0) / 30
    end
    return math.floor((seconds % 1) * 1000000000)
end

local function mint()

    OF.util.seed_random()

    local out = {}
    for _ = 1, LENGTH do

        local at = (OF.util.random_int(1, #ALPHABET) + fine_clock()) % #ALPHABET + 1
        out[#out + 1] = string.sub(ALPHABET, at, at)
    end
    return table.concat(out)
end

pass.mint = mint

function pass.mine()
    return mine
end

function pass.settled()
    return settled and mine ~= nil
end

function pass.is_mine(value)
    if not pass.settled() then return false end
    return value ~= nil and value == mine
end

function pass.owner(value)
    if value == nil or value == "" then return nil end
    for globalIndex, held in pairs(issued) do
        if held == value and answered[globalIndex] then return globalIndex end
    end
    return nil
end

function pass.of(globalIndex)
    if globalIndex == nil then return nil end
    if not ready[globalIndex] then return nil end
    return issued[globalIndex]
end

function pass.confirmed(globalIndex)
    return ready[globalIndex] == true
end

function pass.arriving(globalIndex)
    if globalIndex == nil then return false end
    if ready[globalIndex] then return false end
    local localIndex = OF.util.local_from_global(globalIndex)
    return localIndex ~= nil and localIndex > 0
end

function pass.caught_up(globalIndex)
    return caughtUp[globalIndex] == true
end

function pass.unreachable()
    local out = {}
    if not OF.util.is_host() then return out end
    for _, entry in ipairs(OF.util.connected_players()) do
        local globalIndex = network_global_index_from_local(entry.localIndex)
        if globalIndex ~= 0 and not ready[globalIndex] then
            table.insert(out, entry.localIndex)
        end
    end
    return out
end

local HELD_MAX = 16
local waiting = {}

function pass.hold(globalIndex, data)
    if globalIndex == nil then return false end
    local queue = waiting[globalIndex]
    if queue == nil then
        queue = {}
        waiting[globalIndex] = queue
    end

    if #queue >= HELD_MAX then table.remove(queue, 1) end
    table.insert(queue, data)
    return true
end

function pass.held(globalIndex)
    return #(waiting[globalIndex] or {})
end

local function deliver_held(globalIndex)
    local queue = waiting[globalIndex]
    waiting[globalIndex] = nil
    if queue == nil then return 0 end
    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil or localIndex <= 0 then return 0 end
    local sent = 0
    for _, data in ipairs(queue) do
        if OF.util.send_to_player(localIndex, data) then sent = sent + 1 end
    end
    return sent
end

local OUT_MAX = 8
local outbox = {}

local function flush_outbox()

    if OF.util.is_host() then return 0 end
    if #outbox == 0 then return 0 end
    local queue = outbox
    outbox = {}
    local sent = 0
    for _, data in ipairs(queue) do
        if OF.util.send_to_host(data) then sent = sent + 1 end
    end
    return sent
end

function pass.post(data)

    if OF.util.is_host() then return false, "You are the host." end
    if type(data) ~= "table" then return false, "There is nothing to ask." end

    local hostLocal = OF.util.local_from_global(0)
    if hostLocal == nil or hostLocal <= 0 then
        return false, "There is no host to ask."
    end
    if pass.settled() then
        if OF.util.send_to_host(data) then return true, "Asked the host." end
        return false, "There is no host to ask."
    end

    if #outbox >= OUT_MAX then table.remove(outbox, 1) end
    table.insert(outbox, data)
    return true, "You are still arriving - it will reach the host."
end

function pass.posted()
    return #outbox
end

function pass.forget(globalIndex)
    if globalIndex == nil then return end
    issued[globalIndex] = nil
    answered[globalIndex] = nil
    ready[globalIndex] = nil
    tries[globalIndex] = nil
    told[globalIndex] = nil
    waiting[globalIndex] = nil

    caughtUp[globalIndex] = nil
end

function pass.drop_mine()
    mine = nil
    settled = false
    staleOffers = 0

    outbox = {}
end

function pass.stale()
    return staleOffers >= STALE_AFTER
end

function pass.forget_all()
    issued = {}
    answered = {}
    ready = {}
    tries = {}
    told = {}
    waiting = {}
    repliedReady = {}
    caughtUp = {}

    nonce = nil
    pass.drop_mine()
end

local function offer(globalIndex, answering)

    if not OF.util.is_host() then return false end
    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil or localIndex <= 0 then return false end
    if issued[globalIndex] == nil then issued[globalIndex] = mint() end

    return OF.util.send_raw(localIndex, {
        ofp = pass.PACKET, n = issued[globalIndex], c = answering,
    })
end

pass.offer = offer

function pass.ask()
    if OF.util.is_host() then return false end
    local hostLocal = OF.util.local_from_global(0)
    if hostLocal == nil or hostLocal <= 0 then return false end
    if nonce == nil then nonce = mint() end
    return OF.util.send_raw(hostLocal, { ofp = pass.PACKET_ASK, c = nonce })
end

local function poke(globalIndex)
    if not OF.util.is_host() then return false end
    local localIndex = OF.util.local_from_global(globalIndex)
    if localIndex == nil or localIndex <= 0 then return false end
    return OF.util.send_raw(localIndex, { ofp = pass.PACKET_POKE })
end

local frames = 0

local function host_update()
    frames = frames + 1
    if frames < RETRY_FRAMES then return end
    frames = 0

    repliedReady = {}

    for _, entry in ipairs(OF.util.connected_players()) do
        local globalIndex = network_global_index_from_local(entry.localIndex)
        if globalIndex ~= 0 and not ready[globalIndex] then
            poke(globalIndex)

            tries[globalIndex] = (tries[globalIndex] or 0) + 1
            if tries[globalIndex] == TELL_AFTER and not told[globalIndex] then
                told[globalIndex] = true
                local np = gNetworkPlayers[entry.localIndex]
                OF.notify.show(OF.lang.fill(
                    "@ is not answering the mod - nothing you press will reach them. They need to rejoin.",
                    OF.util.plain(np ~= nil and np.name or "Somebody")), "bad", 10)
            end
        end
    end
end

local function client_update()
    if pokeGap < RETRY_FRAMES then pokeGap = pokeGap + 1 end
    frames = frames + 1
    if frames < RETRY_FRAMES then return end
    frames = 0
    if settled then return end
    pass.ask()
end

local function on_update()
    if OF.util.is_host() then host_update() else client_update() end
end

local function on_packet_receive(data)
    if data == nil then return end

    if data.ofp == pass.PACKET_POKE then
        if OF.util.is_host() then return end
        if pokeGap < RETRY_FRAMES then return end
        pokeGap = 0
        pass.ask()
        return
    end

    if data.ofp == pass.PACKET then

        if OF.util.is_host() then return end
        if type(data.n) ~= "string" or data.n == "" then return end

        if nonce == nil or data.c ~= nonce then
            staleOffers = staleOffers + 1
            return
        end
        staleOffers = 0

        if settled and data.n == mine then
            OF.util.send_raw(OF.util.local_from_global(0), {
                ofp = pass.PACKET_SET, pk = mine,
            })
            return
        end

        mine = data.n
        settled = false
        OF.util.send_raw(OF.util.local_from_global(0), {
            ofp = pass.PACKET_OK, pk = mine,
        })
        return
    end

    if data.ofp == pass.PACKET_ASK then
        if not OF.util.is_host() then return end

        if type(data.c) ~= "string" or data.c == "" then return end

        local globalIndex = tonumber(data.from)
        if globalIndex == nil or globalIndex == 0 then return end
        local localIndex = OF.util.local_from_global(globalIndex)
        if localIndex == nil or localIndex <= 0 then return end

        if ready[globalIndex] then
            if repliedReady[globalIndex] then return end
            repliedReady[globalIndex] = true
        end
        offer(globalIndex, data.c)
        return
    end

    if data.ofp == pass.PACKET_OK then
        if not OF.util.is_host() then return end
        if type(data.pk) ~= "string" then return end

        for globalIndex, held in pairs(issued) do
            if held == data.pk then
                answered[globalIndex] = true
                local localIndex = OF.util.local_from_global(globalIndex)
                if localIndex ~= nil and localIndex > 0 then
                    OF.util.send_raw(localIndex, { ofp = pass.PACKET_DONE, pk = held })
                end

                return
            end
        end
        return
    end

    if data.ofp == pass.PACKET_DONE then
        if OF.util.is_host() then return end
        if mine == nil or data.pk ~= mine then return end
        settled = true

        OF.util.send_raw(OF.util.local_from_global(0), {
            ofp = pass.PACKET_SET, pk = mine,
        })

        flush_outbox()
        return
    end

    if data.ofp == pass.PACKET_SET then
        if not OF.util.is_host() then return end
        if type(data.pk) ~= "string" then return end
        for globalIndex, held in pairs(issued) do
            if held == data.pk then
                answered[globalIndex] = true
                ready[globalIndex] = true
                tries[globalIndex] = 0

                deliver_held(globalIndex)

                if not caughtUp[globalIndex] then
                    caughtUp[globalIndex] = true
                    if OF.util.asks(OF.net, "catch_up") then
                        OF.net.catch_up(globalIndex)
                    end
                end
                return
            end
        end
        return
    end
end

local function on_connected(m)
    if not OF.util.is_host() then return end
    if m == nil then return end
    local globalIndex = network_global_index_from_local(m.playerIndex)
    if globalIndex == nil or globalIndex == 0 then return end
    pass.forget(globalIndex)
end

local function on_disconnected(m)
    if m == nil then return end
    local globalIndex = network_global_index_from_local(m.playerIndex)

    if not OF.util.is_host() and globalIndex == 0 then
        pass.drop_mine()
        return
    end

    pass.forget(globalIndex)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
hook_event(HOOK_UPDATE, on_update)
hook_event(HOOK_ON_PLAYER_CONNECTED, on_connected)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_disconnected)

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.is_host() then
        pass.ask()
        return
    end
    for _, entry in ipairs(OF.util.connected_players()) do
        local globalIndex = network_global_index_from_local(entry.localIndex)
        if globalIndex ~= 0 then poke(globalIndex) end
    end
end)

function pass.ready()
    return true
end
