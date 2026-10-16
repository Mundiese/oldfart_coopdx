local persist = {}

persist.LIMIT = 96

persist.PACKET_KEEP = "keep"
persist.PACKET_ASK = "keepask"
persist.PACKET_SAY = "keepsay"
local ASK_AGAIN = 300

local kept = {}
local askedAt = -9999

local carried = {}
persist.FIELDS_MAX = 8

local wantedBy = {}

function persist.carries(behaviourId, fields, stillWanted)
    if type(behaviourId) ~= "number" then return false end
    if type(fields) ~= "table" then return false end
    if #fields == 0 or #fields > persist.FIELDS_MAX then return false end
    for _, name in ipairs(fields) do
        if type(name) ~= "string" then return false end
    end
    carried[behaviourId] = fields
    if type(stillWanted) == "function" then wantedBy[behaviourId] = stillWanted end
    return true
end

function persist.fields_of(behaviourId)
    return carried[behaviourId]
end

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function here_level()
    local np = gNetworkPlayers[0]
    if np == nil then return nil, nil end
    return np.currLevelNum, np.currAreaIndex
end

function persist.count()
    return #kept
end

function persist.records()
    local out = {}
    for index, one in ipairs(kept) do
        out[index] = { id = one.id, model = one.model, x = one.x, y = one.y,
                       z = one.z, yaw = one.yaw, param = one.param,
                       level = one.level, area = one.area }
    end
    return out
end

function persist.forget_all()
    for index = #kept, 1, -1 do kept[index] = nil end
    askedAt = -9999
    return true
end

function persist.forget_kind(behaviourId)
    local gone = 0
    for index = #kept, 1, -1 do
        if kept[index].id == behaviourId then
            table.remove(kept, index)
            gone = gone + 1
        end
    end
    return gone
end

local function already_held(one)
    for _, held in ipairs(kept) do
        if held.id == one.id and held.level == one.level
            and held.area == one.area
            and math.abs(held.x - one.x) < 1
            and math.abs(held.y - one.y) < 1
            and math.abs(held.z - one.z) < 1 then
            return true
        end
    end
    return false
end

local function displaced_by(one)
    if one.uniq == nil then return nil end
    for index, held in ipairs(kept) do
        if held.id == one.id and held.uniq == one.uniq then return index end
    end
    return nil
end

local function store(one)
    if type(one) ~= "table" then return false end
    if type(one.id) ~= "number" or type(one.x) ~= "number" then return false end
    if already_held(one) then return false end
    local displaced = displaced_by(one)
    if displaced ~= nil then table.remove(kept, displaced) end
    while #kept >= persist.LIMIT do table.remove(kept, 1) end
    table.insert(kept, one)
    return true
end

persist.store = store

function persist.remember(behaviourId, obj, opts)
    if obj == nil then return false end
    if type(behaviourId) ~= "number" then return false end
    opts = opts or {}
    local atLevel, atArea = here_level()
    local level = opts.level or atLevel
    local area = opts.area or atArea
    if level == nil then return false end

    local model = tonumber(opts.model)
        or tonumber(OF.util.optional("obj_get_model_id_extended", nil, obj))
    local one = {
        id = behaviourId,
        model = model,
        x = obj.oPosX, y = obj.oPosY, z = obj.oPosZ,
        yaw = obj.oMoveAngleYaw or 0,
        param = obj.oBehParams or 0,
        uniq = opts.uniq,
        level = level, area = area,
    }

    local fields = carried[behaviourId]
    if fields ~= nil then
        one.vals = {}
        for index, name in ipairs(fields) do
            one.vals[index] = tonumber(obj[name]) or 0
        end
    end

    if type(one.x) ~= "number" or one.model == nil then return false end
    if not store(one) then return false end

    persist.put_it_about(one)
    return true
end

local function wire_of(one)
    local wire = {
        id = one.id, mdl = one.model,
        x = one.x, y = one.y, z = one.z, yw = one.yaw, pr = one.param,
        uq = one.uniq,
        lvl = one.level, ar = one.area,
    }

    for index = 1, persist.FIELDS_MAX do
        local value = one.vals ~= nil and one.vals[index] or nil
        if value == nil then break end
        wire["v" .. index] = value
    end
    return wire
end

persist.wire_of = wire_of

function persist.put_it_about(one)
    local wire = wire_of(one)

    if OF.util.is_host() then
        wire.ofp = persist.PACKET_KEEP
        if not OF.util.asks(OF.util, "tell_all") then return false end
        return OF.util.tell_all(wire) ~= false
    end
    wire.ofp = persist.PACKET_SAY
    if not OF.util.asks(OF.util, "send_to_host") then return false end
    return OF.util.send_to_host(wire) ~= false
end

local function place(one)

    if one == nil or one.model == nil then return nil end
    local fields = carried[one.id]

    return OF.slots.spawn_lobby(
        one.id, one.model, one.x, one.y, one.z, function(obj)
            obj.oMoveAngleYaw = one.yaw or 0
            obj.oBehParams = one.param or 0

            if fields ~= nil and one.vals ~= nil then
                for index, name in ipairs(fields) do
                    local value = one.vals[index]
                    if value ~= nil then obj[name] = value end
                end
            end
        end, nil, true)
end

function persist.put_down(id, model, x, y, z, yaw, param, opts)
    local level, area = here_level()
    if level == nil then return nil end
    if type(id) ~= "number" or type(x) ~= "number" then return nil end

    opts = opts or {}
    local one = { id = id, model = model, x = x, y = y, z = z,
                  yaw = yaw or 0, param = param or 0,
                  vals = opts.vals, uniq = opts.uniq,
                  level = level, area = area }
    local obj = place(one)
    if obj == nil then return nil end
    if store(one) then persist.put_it_about(one) end
    return obj
end

function persist.drop_the_unwanted()
    local answered = {}
    local gone = 0
    for index = #kept, 1, -1 do
        local behaviourId = kept[index].id
        if answered[behaviourId] == nil then
            local ask = wantedBy[behaviourId]
            answered[behaviourId] = (ask == nil) or (ask() ~= false)
        end
        if not answered[behaviourId] then
            table.remove(kept, index)
            gone = gone + 1
        end
    end
    return gone
end

function persist.replay_here()
    persist.drop_the_unwanted()

    local level, area = here_level()
    if level == nil then return 0 end
    if not OF.util.asks(OF.util, "area_authority") then return 0 end
    if OF.util.area_authority() ~= 0 then return 0 end

    local made = 0
    for _, one in ipairs(kept) do
        if one.level == level and one.area == area then
            if place(one) ~= nil then made = made + 1 end
        end
    end
    return made
end

function persist.ask_for_the_set()
    if #kept > 0 then return false end
    if now_frame() - askedAt < ASK_AGAIN then return false end
    askedAt = now_frame()
    if not OF.util.asks(OF.util, "send_to_host") then return false end
    return OF.util.send_to_host({ ofp = persist.PACKET_ASK }) ~= false
end

function persist.answer_an_ask(localIndex)
    if not OF.util.is_host() then return 0 end
    if localIndex == nil then return 0 end
    if #kept == 0 then return 0 end
    local sent = 0
    for _, one in ipairs(kept) do
        local wire = wire_of(one)
        wire.ofp = persist.PACKET_KEEP
        if OF.util.asks(OF.util, "send_to_player")
            and OF.util.send_to_player(localIndex, wire) then sent = sent + 1 end
    end
    return sent
end

local function record_off_the_wire(data)
    local one = {
        id = tonumber(data.id), model = tonumber(data.mdl),
        x = tonumber(data.x), y = tonumber(data.y), z = tonumber(data.z),
        yaw = tonumber(data.yw) or 0, param = tonumber(data.pr) or 0,
        uniq = tonumber(data.uq),
        level = tonumber(data.lvl), area = tonumber(data.ar),
    }

    local fields = one.id ~= nil and carried[one.id] or nil
    if fields ~= nil then
        one.vals = {}
        for index = 1, #fields do
            one.vals[index] = tonumber(data["v" .. index]) or 0
        end
    end
    return one
end

local function on_packet(data)
    if data == nil or data.ofp == nil then return end

    if data.ofp == persist.PACKET_KEEP then
        if not OF.util.from_host_effect(data) then return end
        store(record_off_the_wire(data))
        return
    end

    if data.ofp == persist.PACKET_SAY then
        if OF.util.asked_by(data) == nil then return end
        local one = record_off_the_wire(data)
        if store(one) then persist.put_it_about(one) end
        return
    end

    if data.ofp == persist.PACKET_ASK then
        local who = OF.util.asked_by(data)
        if who ~= nil then persist.answer_an_ask(who) end
    end
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet)

local replayOwed = false

function persist.on_level_init()
    replayOwed = true
    persist.ask_for_the_set()
end

function persist.on_sync_valid()
    if not replayOwed then return 0 end
    replayOwed = false
    return persist.replay_here()
end

hook_event(HOOK_ON_LEVEL_INIT, persist.on_level_init)
hook_event(HOOK_ON_SYNC_VALID, persist.on_sync_valid)

function persist.ready()
    return true
end

OF.persist = persist
