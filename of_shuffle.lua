OF = OF or {}
OF.shuffle = OF.shuffle or {}

local shuffle = OF.shuffle

shuffle.SEED_KEY = "ofShuffleSeed"
local ENTRY_AREA = 1
local ENTRY_NODE = 0x0A

local FROM = {
    [LEVEL_CASTLE] = true,
    [LEVEL_CASTLE_GROUNDS] = true,
    [LEVEL_CASTLE_COURTYARD] = true,
}

function shuffle.seed()
    local value = gGlobalSyncTable[shuffle.SEED_KEY]
    if type(value) ~= "number" then return 0 end
    return value
end

function shuffle.is_on()
    return shuffle.seed() > 0
end

local function step_of(state)
    return (1103515245 * state + 12345) % 2147483648
end

function shuffle.map()
    local seed = shuffle.seed()
    local map = {}
    if seed <= 0 then return map end

    local order = {}
    for _, course in ipairs(OF.COURSES or {}) do
        table.insert(order, course.level)
    end

    local state = seed % 2147483648
    for index = #order, 2, -1 do
        state = step_of(state)
        local pick = (state % (index - 1)) + 1
        order[index], order[pick] = order[pick], order[index]
    end

    for index, course in ipairs(OF.COURSES or {}) do
        map[course.level] = order[index]
    end
    return map
end

function shuffle.behind(levelNum)
    local map = shuffle.map()
    local to = map[levelNum]
    if to == nil then return nil end
    return OF.util.level_name(to)
end

local function clock_seed(avoid)
    local now = (OF.util.optional("get_time", 0) or 0)
        + math.floor(((OF.util.optional("get_global_timer", 0) or 0)) % 100000)
    local seed = (step_of(now) % 9000) + 1000
    if avoid ~= nil and seed == avoid then
        seed = (step_of(seed) % 9000) + 1000
    end
    return seed
end

local drifting = false

local seatsAt = {}

function shuffle.drifting() return drifting end

local function set_drift(on)
    drifting = on and true or false
    seatsAt = {}
    if drifting then shuffle.watch_seats() end
end

function shuffle.drift(on)
    if not OF.util.is_host() then return false, "Only the host." end
    set_drift(on)
    return true
end

local function seat_place(np)
    if np == nil or not np.connected then return nil end
    local level, area = np.currLevelNum, np.currAreaIndex
    if type(level) ~= "number" or type(area) ~= "number" then return nil end
    if level <= 0 then return nil end
    return tostring(level) .. ":" .. tostring(area)
end

function shuffle.watch_seats()
    local moved = false
    for index = 0, (MAX_PLAYERS or 16) - 1 do
        local place = seat_place(gNetworkPlayers[index])
        if place == nil then
            seatsAt[index] = nil
        elseif seatsAt[index] == nil then
            seatsAt[index] = place
        elseif seatsAt[index] ~= place then
            seatsAt[index] = place
            moved = true
        end
    end
    return moved
end

local function redraw()
    local seed = shuffle.seed()
    if seed <= 0 then return false end
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then return false end
    OF.util.publish(shuffle.SEED_KEY, clock_seed(seed))
    return true
end

function shuffle.drift_tick()
    if not drifting then return false end
    if not OF.util.is_host() then return false end
    if not shuffle.watch_seats() then return false end
    return redraw()
end

hook_event(HOOK_UPDATE, function() shuffle.drift_tick() end)

function shuffle.roll(wanted)
    if not OF.util.is_host() then return false, "Only the host." end
    local seed = tonumber(wanted)
    if seed == nil then seed = clock_seed() end
    seed = math.floor(seed)
    if seed < 1 then return false, "A seed is a number above zero." end
    set_drift(false)
    OF.util.publish(shuffle.SEED_KEY, seed)
    return true
end

function shuffle.borrow_seed(seed)
    if not OF.util.is_host() then return false end
    seed = math.floor(tonumber(seed) or 0)
    if seed < 0 then return false end
    if shuffle.seed() == seed then return false end
    OF.util.publish(shuffle.SEED_KEY, seed)
    return true
end

function shuffle.off()
    if not OF.util.is_host() then return false, "Only the host." end
    set_drift(false)
    OF.util.publish(shuffle.SEED_KEY, 0)
    return true
end

local function closed(levelNum)
    return OF.util.asks(OF.offlimits, "level_closed")
        and OF.offlimits.level_closed(levelNum)
end

local function refuse(here, area)
    OF.util.report(false, "That way is closed.")
    return { destLevel = here, destArea = area, destWarpNode = 0x1F }
end

hook_event(HOOK_BEFORE_WARP, function(destLevel, destArea, destWarpNode, arg)

    local np = gNetworkPlayers[0]
    local here, area = nil, nil
    if np ~= nil then here, area = np.currLevelNum, np.currAreaIndex end

    local leaving = here ~= nil and FROM[here] and destLevel ~= here

    if shuffle.is_on() and FROM[here] then
        local map = shuffle.map()
        local to = map[destLevel]
        if to ~= nil and to ~= destLevel then

            if closed(to) then return refuse(here, area) end
            return { destLevel = to, destArea = ENTRY_AREA, destWarpNode = ENTRY_NODE }
        end

        if leaving and closed(destLevel) then return refuse(here, area) end
        return
    end

    if leaving and closed(destLevel) then return refuse(here, area) end
end)
