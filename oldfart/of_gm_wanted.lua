OF = OF or {}

local ROLE_HUNTING = "hunting"
local DEFAULT_TARGET = 5

local HEAD_START = 45
local BETWEEN = 60

local CLOCK_MAX = 20
local CLOCK_MIN = 10

local IS_KEY = "ofWantedIs"
local LEFT_KEY = "ofWantedLeft"
local BY_KEY = "ofWantedBy"
local SEQ_KEY = "ofWantedSeq"
local TARGET_KEY = "ofWantedTo"
local WIRE_KEYS = { IS_KEY, LEFT_KEY, BY_KEY, SEQ_KEY, TARGET_KEY }

local namedAt = nil
local nextAt = nil
local deadline = nil

local seenSeq = 0
local seenWanted = nil

local mode = {
    key = "wanted",
    name = "Wanted!",
    blurb = "one player is wanted - the first to punch them scores",
    how = "One player's name goes up on the poster.\n"
        .. "The first to punch, kick or pound them scores a point.\n"
        .. "Last out the poster's clock and the point is yours.\n"
        .. "Then a new name goes up - everybody gets a turn.\n"
        .. "First to the target wins, or the most points at the clock.",
    aims = { [ROLE_HUNTING] = "Punch whoever is wanted first. Wanted? Get away." },

    aimInLine = true,
    minPlayers = 2,
    maps = "surveyed",
    surveyKeys = { "points" },
    openCourses = true,

    roomsOut = {
        { level = LEVEL_RR, area = 1 }, { level = LEVEL_BITDW, area = 1 },
        { level = LEVEL_BITFS, area = 1 }, { level = LEVEL_TTC, area = 1 },

        { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },

        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_LLL, area = 2 },
        { level = LEVEL_COTMC, area = 1 },

        { level = LEVEL_TTM, area = 1 }, { level = LEVEL_THI, area = 2 },
    },
    room = { rules = { interactions = PLAYER_INTERACTIONS_PVP } },
    target = { name = "points to win",
               asks = "Points to win",
               default = DEFAULT_TARGET, min = 3, max = 10, step = 1 },

    boardTitle = "Points",

    defaultLimit = 240,
    music = SEQ_EVENT_POWERUP,
    teams = false,
}

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function target_points()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return DEFAULT_TARGET end
    return value
end

local function points_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row.ofScore)) or 0)
end

local function hunters()
    return OF.gamemodes.with_role(ROLE_HUNTING)
end

function mode.clock_for(players)
    players = players or 0
    return math.max(CLOCK_MIN, math.min(CLOCK_MAX, CLOCK_MAX - math.max(0, players - 4)))
end

local function wanted_local()
    local g = gGlobalSyncTable[IS_KEY]
    if type(g) ~= "number" then return nil end
    return OF.util.local_from_global(g)
end

local wantedTarget = { id = "wanted", label = "wanted", tone = "hunter",
    priority = 90, compass = "offscreen" }
local wantedList = { wantedTarget }
function mode.targets(viewer)
    local _ = viewer
    local who = wanted_local()
    if who == nil or who == 0 then return nil end
    wantedTarget.player = who
    return wantedList
end

local hadTurn = {}
local lastNamed = nil
local turnNo = 0

local function turn_keys(entry)
    local np = entry ~= nil and entry.np or nil
    local g = np ~= nil and ("g" .. tostring(np.globalIndex)) or nil
    local key = OF.util.asks(OF.gamemodes, "deal_key") and OF.gamemodes.deal_key(entry) or g
    return key, g
end

local function had_turn(had, entry)
    local key, g = turn_keys(entry)
    return (key ~= nil and had[key] == true) or (g ~= nil and had[g] == true)
end

local function bag_order(seed, turn, globalIndex)
    local x = ((seed or 0) * 31 + (turn or 0) * 7919 + (globalIndex or 0) * 104729 + 1)
        % 2147483647
    if x <= 0 then x = x + 2147483646 end
    x = (x * 48271) % 2147483647
    x = (x * 48271) % 2147483647
    return x
end
mode.bag_order = bag_order

function mode.next_wanted(list, had, last, seed, turn)
    local fresh = {}
    for _, entry in ipairs(list or {}) do
        if not had_turn(had, entry) then fresh[#fresh + 1] = entry end
    end
    if #fresh == 0 then
        for k in pairs(had) do had[k] = nil end
        for _, entry in ipairs(list or {}) do
            local key, g = turn_keys(entry)
            if #list < 2 or (key ~= last and g ~= last) then fresh[#fresh + 1] = entry end
        end
    end
    table.sort(fresh, function(a, b)
        local ga, gb = a.np.globalIndex, b.np.globalIndex
        local oa, ob = bag_order(seed, turn, ga), bag_order(seed, turn, gb)
        if oa ~= ob then return oa < ob end
        return ga < gb
    end)
    return fresh[1]
end

function mode.forget_turns()
    hadTurn, lastNamed, turnNo = {}, nil, 0
end

local function name_next()
    local list = {}
    for _, entry in ipairs(hunters()) do
        if OF.util.can_play(entry.localIndex) and entry.np ~= nil then table.insert(list, entry) end
    end
    if #list < 2 then
        OF.util.publish(IS_KEY, nil)
        nextAt = now_frame() + BETWEEN
        return false
    end
    local seed = OF.util.asks(OF.gamemodes, "round_seed") and OF.gamemodes.round_seed() or 0
    local entry = mode.next_wanted(list, hadTurn, lastNamed, seed, turnNo)
    if entry == nil then return false end
    turnNo = turnNo + 1
    local key, g = turn_keys(entry)
    if key ~= nil then hadTurn[key] = true end
    if g ~= nil then hadTurn[g] = true end
    lastNamed = key or g
    local now = now_frame()
    namedAt, nextAt = now, nil
    deadline = now + HEAD_START + mode.clock_for(#list) * 30
    OF.util.publish(IS_KEY, entry.np.globalIndex)
    OF.util.publish(LEFT_KEY, mode.clock_for(#list))
    return true
end
mode.name_next = name_next

function OF.gm_wanted_read_seq(value)
    if type(value) == "number" then return value, nil end
    if type(value) ~= "string" then return 0, nil end
    local seq, by = string.match(value, "^(%d+):(%-?%d+)$")
    if seq == nil then return 0, nil end
    return tonumber(seq), tonumber(by)
end

local function award(globalIndex)
    local seq = OF.gm_wanted_read_seq(gGlobalSyncTable[SEQ_KEY])
    OF.util.publish(SEQ_KEY, (seq + 1) .. ":" .. tostring(globalIndex))
    OF.util.publish(BY_KEY, globalIndex)
    OF.util.publish(IS_KEY, nil)
    OF.util.publish(LEFT_KEY, nil)
    namedAt, deadline = nil, nil
    nextAt = now_frame() + BETWEEN
end

mode.target.auto = function(n)
    if n >= 13 then return 3 end
    if n >= 9 then return 4 end
    return 5
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_HUNTING)
    end
    OF.util.publish(TARGET_KEY, OF.gamemodes.auto_target(mode, players,
        { target = (options ~= nil and options.target) or DEFAULT_TARGET,
          targetNamed = options ~= nil and options.targetNamed }))
end

function mode.pin()
    mode.forget_turns()
    namedAt, deadline = nil, nil
    nextAt = now_frame()
    OF.util.publish(SEQ_KEY, 0)
    OF.util.publish(BY_KEY, nil)
    OF.util.publish(IS_KEY, nil)
    OF.util.publish(LEFT_KEY, nil)
end

function mode.on_start()
    seenSeq, seenWanted = 0, nil
end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_HUNTING)
    return ROLE_HUNTING
end

local function on_pvp_tag(attacker, victim, interaction)
    if attacker == nil or victim == nil then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.is_host() then return end
    local wanted = wanted_local()
    if wanted == nil or victim.playerIndex ~= wanted then return end
    if OF.gamemodes.role(attacker.playerIndex) ~= ROLE_HUNTING then return end
    if namedAt == nil or now_frame() - namedAt < HEAD_START then return end
    local np = gNetworkPlayers[attacker.playerIndex]
    if np == nil or not np.connected then return end
    award(np.globalIndex)
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local now = now_frame()

    local wanted = wanted_local()
    if gGlobalSyncTable[IS_KEY] ~= nil and (wanted == nil
        or not gNetworkPlayers[wanted].connected
        or OF.gamemodes.role(wanted) ~= ROLE_HUNTING) then

        OF.util.publish(IS_KEY, nil)
        namedAt, deadline, nextAt = nil, nil, now
        wanted = nil
    end

    if wanted == nil and nextAt ~= nil and now >= nextAt then
        name_next()
    elseif wanted ~= nil and deadline ~= nil then
        local left = math.max(0, math.ceil((deadline - now) / 30))
        if left ~= gGlobalSyncTable[LEFT_KEY] then OF.util.publish(LEFT_KEY, left) end
        if now >= deadline then award(gNetworkPlayers[wanted].globalIndex) end
    end

    local target = target_points()
    for _, entry in ipairs(hunters()) do
        local points = points_of(entry.localIndex)
        if points >= target and entry.np ~= nil then
            OF.gamemodes.finish("@ scored @ points and won.",
                entry.np.name, entry.np.name, tostring(points))
            return
        end
    end
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end

    local wanted = gGlobalSyncTable[IS_KEY]
    if wanted ~= seenWanted then
        seenWanted = wanted

        if wanted ~= nil and OF.util.asks(OF.hud, "banner") then
            local li = OF.util.local_from_global(wanted)
            local who = li ~= nil and gNetworkPlayers[li] ~= nil and gNetworkPlayers[li].name or nil
            OF.hud.banner("objective", OF.lang.t(wanted == np.globalIndex and "YOU ARE WANTED" or "NEW TARGET"),
                wanted ~= np.globalIndex and who ~= nil and OF.util.plain(who) or nil, { quiet = true })
        end
        if wanted == np.globalIndex then
            OF.gamemodes.cue("hazard")

            local m = gMarioStates[0]
            if m ~= nil then m.invincTimer = math.max(m.invincTimer or 0, HEAD_START) end
        elseif wanted ~= nil then
            OF.gamemodes.cue("chime")
        end
    end

    local seq, by = OF.gm_wanted_read_seq(gGlobalSyncTable[SEQ_KEY])
    if seq > seenSeq then
        seenSeq = seq
        if by == np.globalIndex and OF.gamemodes.role(0) == ROLE_HUNTING then
            OF.util.publish_row(0, "ofScore", points_of(0) + 1)

            OF.gamemodes.cue("good")
        end
    end
end

function mode.still_winnable()
    return #hunters() >= 2
end

function mode.terms()
    return OF.lang.fill("first to @ points, or most at the clock", tostring(target_points()))
end

function mode.on_timeout()
    local best, names = OF.gamemodes.best_of(hunters(),
        function(entry) return points_of(entry.localIndex) end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody scored.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("Time - a draw at @ points.", tostring(best)))
    else
        OF.gamemodes.finish("@ won - the most points.", names[1], names[1])
    end
end

local HURRY = 5

function mode.line_for(wanted, left, name)
    left = tonumber(left)
    if wanted == 0 then
        return OF.lang.t("You are wanted"), "bad", left ~= nil and math.floor(left) or nil
    elseif wanted ~= nil then
        local plain = OF.util.plain(name or "?")
        if #plain > 12 then plain = plain:sub(1, 11) .. "." end
        return OF.lang.fill("Wanted @", plain), "target",
            (left ~= nil and left <= HURRY) and math.floor(left) or nil
    end
    return nil
end

function mode.hud()
    local wanted = wanted_local()
    local np = wanted ~= nil and gNetworkPlayers[wanted] or nil
    local text, tone, figure = mode.line_for(wanted, gGlobalSyncTable[LEFT_KEY], np ~= nil and np.name or nil)
    if text ~= nil and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("poster", text, { prio = wanted == 0 and 85 or 50, tone = tone,
            urgent = wanted == 0, figure = figure })
    end

end

function mode.cleanup()
    if OF.util.is_host() then
        for _, wireKey in ipairs(WIRE_KEYS) do
            OF.util.publish(wireKey, nil)
        end
    end
    namedAt, nextAt, deadline = nil, nil, nil
    seenSeq, seenWanted = 0, nil
    mode.forget_turns()
    return true
end

mode.on_tag = function(a, v)
    return on_pvp_tag(gMarioStates[a], gMarioStates[v])
end

OF.gamemodes.register(mode)
