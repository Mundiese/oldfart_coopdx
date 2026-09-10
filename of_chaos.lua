OF = OF or {}
OF.chaos = OF.chaos or {}

local chaos = OF.chaos

chaos.KEY = "ofChaos"
chaos.NEXT_KEY = "ofChaosNext"
chaos.ACTION = "chaos"
chaos.WILD_ACTION = "chaoswild"
chaos.STEPS = { 0, 30, 60, 120 }

local DEAL = 2

chaos.STRENGTHS = {
    { key = "gentle",   deal = 1, anomalies = 0, stunt = 8, enemies = false,
      surprises = 4, mean = false, tunes = 0, victims = 3 },
    { key = "standard", deal = 2, anomalies = 1, stunt = 5, enemies = false,
      surprises = 3, mean = false, tunes = 6, victims = 2 },
    { key = "rowdy",    deal = 2, anomalies = 1, stunt = 4, enemies = true,
      surprises = 2, mean = false, tunes = 4, life = 90,  slots = 4,
      victims = 3 },
    { key = "edition",  deal = 3, anomalies = 1, stunt = 3, enemies = true,
      surprises = 2, mean = false, tunes = 2, life = 120, slots = 6,
      victims = 3 },
    { key = "meltdown", deal = 4, anomalies = 2, stunt = 2, enemies = true,
      surprises = 1, mean = true,  tunes = 1, life = 150, slots = 8,
      victims = 2 },
}

chaos.WILD_KEY = "ofChaosWild"
local DEFAULT_STRENGTH = "standard"
chaos.BY_STRENGTH = {}
for _, entry in ipairs(chaos.STRENGTHS) do
    chaos.BY_STRENGTH[entry.key] = entry
end

function chaos.strength()
    local value = gGlobalSyncTable[chaos.WILD_KEY]
    if type(value) == "string" then
        local entry = chaos.BY_STRENGTH[value]
        if entry ~= nil then return entry end
    end
    return chaos.BY_STRENGTH[DEFAULT_STRENGTH]
end

function chaos.strength_at()
    local current = chaos.strength().key
    for index, entry in ipairs(chaos.STRENGTHS) do
        if entry.key == current then return index end
    end
    return 1
end

function chaos.strength_name()
    return tostring(chaos.strength_at())
end

function chaos.strength_label()
    return chaos.strength_at() .. "/" .. #chaos.STRENGTHS
end

function chaos.strength_note()
    return OF.lang.t("further up is more at once, more often, and less kind")
end

function chaos.deal_count()
    return chaos.strength().deal or DEAL
end

function chaos.set_strength(key)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local entry = chaos.BY_STRENGTH[tostring(key or "")]
    if entry == nil then return false, "There is no such setting." end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(chaos.WILD_ACTION, entry.key)
        end
        return false, "No host to ask yet - try again in a second."
    end
    if entry.key == DEFAULT_STRENGTH then
        OF.util.publish(chaos.WILD_KEY, nil)
    else
        OF.util.publish(chaos.WILD_KEY, entry.key)
    end
    return true
end

function chaos.cycle_strength()
    local at = 1
    local current = chaos.strength().key
    for i, entry in ipairs(chaos.STRENGTHS) do
        if entry.key == current then at = i end
    end
    at = at + 1
    if at > #chaos.STRENGTHS then at = 1 end
    return chaos.set_strength(chaos.STRENGTHS[at].key)
end

local ANOMALIES = {

    lowgrav = true, giant = true, tiny = true, softland = true,

    learn = true, cloud = true,

    controls = true, buttons = true, budget = true,

    view = true, horizon = true, fisheye = true,

    water = true, swim = true,

    anim = true,

    lava = true, mirror = true,
}

function chaos.is_anomaly(key)
    return ANOMALIES[key] == true
end

function chaos.anomaly_cap()
    local cap = chaos.strength().anomalies
    if type(cap) ~= "number" then return 1 end
    return cap
end

local dealt = {}

local function dealt_levels()
    local out = {}
    for key, held in pairs(dealt) do out[key] = held.level end
    return out
end

local function take_back(set, levels)
    for key, level in pairs(levels) do

        if set[key] == level then set[key] = nil end
    end
end

local SHORTEST = 5

local ANOMALY_SHARE = 2

local function life_of(key, level)
    local base = chaos.strength().life
    if type(base) ~= "number" or base <= 0 then return nil end

    local entry = OF.modifiers.BY_KEY[key]
    local own = entry ~= nil and entry.life or nil
    if type(own) == "number" and own > 0 then
        return math.floor(own * 30)
    end

    local steps = OF.modifiers.step_count(entry)
    if type(steps) ~= "number" or steps < 1 then steps = 1 end
    if type(level) ~= "number" or level < 1 then level = 1 end
    if level > steps then level = steps end

    local seconds = base * (steps + 1 - level) / steps
    if chaos.is_anomaly(key) then seconds = seconds / ANOMALY_SHARE end
    if seconds < SHORTEST then seconds = SHORTEST end
    return math.floor(seconds * 30)
end

function chaos.slot_cap()
    local cap = chaos.strength().slots
    if type(cap) ~= "number" or cap < 1 then return nil end
    return cap
end

function chaos.stop_life()
    local base = chaos.strength().life
    if type(base) ~= "number" or base <= 0 then return nil end
    return base
end

function chaos.dealt_left(key)
    if not OF.util.is_host() then return nil end
    local held = dealt[key]
    return held ~= nil and held.left or nil
end

local frames = 0

local borrowed = nil

local SERIES = 5

local seriesAt = 0
local cleanAt = 0
local seriesState = 0

local function step_of(state)
    return (1103515245 * state + 12345) % 2147483648
end

local function begin_series()
    if seriesState == 0 then

        seriesState = (OF.util.optional("get_time", 0) or 0)
            + math.floor(((OF.util.optional("get_global_timer", 0) or 0)) % 100000)
    end
    seriesState = step_of(seriesState)
    seriesAt = 0
    cleanAt = 2 + (seriesState % (SERIES - 1))
end

function chaos.series_length()
    return SERIES
end

function chaos.series_position()
    if not OF.util.is_host() then return 0 end
    return seriesAt
end

function chaos.clean_round_at()
    if not OF.util.is_host() then return 0 end
    return cleanAt
end

function chaos.quiet()
    if not OF.util.is_host() then return false end

    chaos.end_stunt()

    chaos.give_back_enemies()

    chaos.give_back_powerups()

    local set = OF.modifiers.parse(OF.modifiers.text())
    take_back(set, dealt_levels())
    dealt = {}

    OF.modifiers.borrow(function()
        OF.modifiers.set_text(OF.modifiers.pack(set))
    end)
    return true
end

function chaos.interval()
    local value = gGlobalSyncTable[chaos.KEY]
    if type(value) ~= "number" or value <= 0 then return 0 end
    return value
end

function chaos.on()
    return chaos.interval() > 0
end

function chaos.next_in()
    if not chaos.on() then return nil end
    local value = gGlobalSyncTable[chaos.NEXT_KEY]
    if type(value) ~= "number" or value < 0 then return nil end
    return value
end

local function a_round_has_them()
    return OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down()
end

chaos.paused_by_round = a_round_has_them

local function spared(entry)
    local list = type(entry) == "table" and entry.spares or nil
    if type(list) ~= "table" or #list == 0 then return false end

    local np = gNetworkPlayers[0]
    if np == nil then return false end
    local here = OF.util.course_of_level(np.currLevelNum)
    if type(here) ~= "number" or here <= 0 then return false end

    for _, num in ipairs(list) do
        if tonumber(num) == here then return true end
    end
    return false
end

chaos.spared = spared

local function pool()
    local out = {}
    for _, entry in ipairs(OF.modifiers.LIST) do

        local steps = spared(entry) and 0 or OF.modifiers.step_count(entry)
        local copies = OF.util.draw_weight(entry, 0)
        for level = 1, steps do
            for _ = 1, copies do
                table.insert(out, { key = entry.key, level = level, id = entry.id })
            end
        end
    end
    if OF.util.asks(OF.offlimits, "keep") then
        out = OF.offlimits.keep("mod", out, "id", "level")
    end
    return out
end

chaos.pool = pool

chaos.STUNTS = {
    { key = "blackout", id = "bl",  name = "Blackout",          seconds = 20,
      wear = { dark = 3, fog = 3 } },
    { key = "moonshot", id = "mo",  name = "Moonshot",          seconds = 30,
      wear = { lowgrav = 3, softland = 1 } },

    { key = "rushhour", id = "ru",  name = "Rush hour",         seconds = 20,
      wear = { quick = 3, delay = 1 } },
    { key = "bigday", id = "bd",    name = "Big day out",       seconds = 25,
      wear = { giant = 3, fisheye = 3 } },
    { key = "dollhouse", id = "dh", name = "The doll's house",  seconds = 25,
      wear = { tiny = 3, view = 2 } },
    { key = "graveyard", id = "gy", name = "The graveyard shift", seconds = 30,
      wear = { night = 1, dark = 2, voice = 5 } },
    { key = "reallava", id = "rl",  name = "The floor really is lava", seconds = 20,
      wear = { lava = 4, quick = 1 } },
    { key = "thechase", id = "tc",  name = "The chase",         seconds = 30,
      wear = { demon = 3, lowgrav = 1 } },

    { key = "fever", id = "fv",     name = "A fever dream",     seconds = 25,
      wear = { tint = 4, horizon = 3 } },
    { key = "butter", id = "bu",    name = "Butterfingers",     seconds = 20,
      wear = { controls = 1, buttons = 3 } },

    { key = "icerink", id = "ir",   name = "The ice rink",      seconds = 25,
      wear = { floor = 2, camlag = 2 } },
    { key = "whiteout", id = "wo",  name = "Whiteout",          seconds = 30,
      wear = { snow = 2, fog = 2, night = 10 } },

    { key = "fastfwd", id = "ff",   name = "Fast forward",      seconds = 20,
      wear = { quick = 2, anim = 2 } },
    { key = "upended", id = "up",   name = "Upside down",       seconds = 20,
      wear = { horizon = 4, view = 5 } },

    { key = "deepend", id = "de",   name = "The deep end",      seconds = 25,
      wear = { water = 3, night = 3 } },

    { key = "hardhats", id = "hh",  name = "Hard hats on",      seconds = 25,
      wear = { cluster = 3, quake = 2 } },

    { key = "cavein", id = "cv",    name = "The cave-in",       seconds = 20,
      wear = { quake = 3, camlag = 2 } },
    { key = "featherfall", id = "fe", name = "Feather fall",    seconds = 30,
      wear = { lowgrav = 2, cloud = 3 } },
    { key = "gaslight", id = "gl",  name = "The gaslight",      seconds = 25,
      wear = { flat = 1, shadow = 1 } },

    { key = "longlens", id = "ll",  name = "The long lens",     seconds = 20,
      wear = { fog = 3, near = 2 } },

    { key = "monkeybars", id = "mb", name = "Monkey bars",      seconds = 25,
      wear = { lowgrav = 3, mirror = 1 } },
    { key = "silence", id = "si",   name = "The silent hour",   seconds = 25,
      wear = { quiet = 3, night = 8 } },
    { key = "slipway", id = "sw",   name = "The slipway",       seconds = 20,
      wear = { floor = 3, lowgrav = 1 } },
    { key = "swimming", id = "sm",  name = "Swimming lessons",  seconds = 30,
      wear = { swim = 1, water = 2 } },
}

chaos.STUNT_KEY = "ofChaosStunt"
function chaos.stunt_odds()
    local odds = chaos.strength().stunt
    if type(odds) ~= "number" or odds < 1 then return 5 end
    return odds
end

function chaos.stunt_pool()
    local out = {}
    for _, entry in ipairs(chaos.STUNTS) do

        if not spared(entry) then table.insert(out, entry) end
    end
    if OF.util.asks(OF.offlimits, "keep") then
        out = OF.offlimits.keep("stunt", out, "id")
    end
    return out
end

local worn = nil
local stuntFrames = 0

function chaos.stunt()
    local value = gGlobalSyncTable[chaos.STUNT_KEY]
    if type(value) ~= "string" then return nil end
    for _, entry in ipairs(chaos.STUNTS) do
        if entry.key == value then return entry end
    end

    return nil
end

function chaos.stunt_name()
    local entry = chaos.stunt()
    return entry ~= nil and entry.name or nil
end

function chaos.worn_keys()
    if not OF.util.is_host() then return {} end
    local out = {}
    for key, level in pairs(worn ~= nil and worn.wear or {}) do out[key] = level end
    return out
end

function chaos.dealt_keys()
    if not OF.util.is_host() then return {} end
    return dealt_levels()
end

function chaos.owned_keys()
    if not OF.util.is_host() then return {} end
    local out = chaos.dealt_keys()
    for key, level in pairs(worn ~= nil and worn.wear or {}) do out[key] = level end
    return out
end

function chaos.stunt_frames()
    if not OF.util.is_host() then return 0 end
    return stuntFrames
end

function chaos.hand_size()
    local most = DEAL
    for _, entry in ipairs(chaos.STRENGTHS) do
        if type(entry.deal) == "number" and entry.deal > most then
            most = entry.deal
        end

        if type(entry.slots) == "number" and entry.slots > most then
            most = entry.slots
        end
    end
    for _, entry in ipairs(chaos.STUNTS) do
        local n = 0
        for _ in pairs(entry.wear) do n = n + 1 end
        if n > most then most = n end
    end
    return most
end

function chaos.end_stunt()
    if not OF.util.is_host() then return false end
    if worn == nil then
        if gGlobalSyncTable[chaos.STUNT_KEY] ~= nil then
            OF.util.publish(chaos.STUNT_KEY, nil)
        end
        return false
    end

    local set = OF.modifiers.parse(OF.modifiers.text())
    take_back(set, worn.wear)
    OF.modifiers.borrow(function()
        OF.modifiers.set_text(OF.modifiers.pack(set))
    end)

    worn = nil
    stuntFrames = 0
    OF.util.publish(chaos.STUNT_KEY, nil)
    return true
end

function chaos.wear_stunt(entry)
    if not OF.util.is_host() then return nil end
    if entry == nil then return nil end

    chaos.end_stunt()

    local set = OF.modifiers.parse(OF.modifiers.text())
    local mine = {}
    for key, level in pairs(entry.wear) do
        local known = OF.modifiers.BY_KEY[key]

        if known ~= nil and set[key] == nil then
            set[key] = level
            mine[key] = level

            for _, other in ipairs(known.excludes or {}) do
                set[other] = nil
                mine[other] = nil
                dealt[other] = nil
            end
        end
    end

    local any = false
    for _ in pairs(mine) do any = true end
    if not any then return nil end

    OF.modifiers.borrow(function()
        OF.modifiers.set_text(OF.modifiers.pack(set))
    end)

    worn = { key = entry.key, wear = mine }
    stuntFrames = entry.seconds * 30
    OF.util.publish(chaos.STUNT_KEY, entry.key)
    return entry
end

function chaos.release(key)
    if key == nil then return end

    dealt[key] = nil

    if worn ~= nil then worn.wear[key] = nil end
end

function chaos.release_all()

    dealt = {}

    if worn ~= nil then
        worn = nil
        stuntFrames = 0
        if OF.util.is_host() and gGlobalSyncTable[chaos.STUNT_KEY] ~= nil then
            OF.util.publish(chaos.STUNT_KEY, nil)
        end
    end
end

local enemyDealt = {}

local dealingEnemies = false

function chaos.release_enemy(key)
    if dealingEnemies then return end
    if key == nil then return end
    enemyDealt[key] = nil
end

function chaos.enemy_keys()
    if not OF.util.is_host() then return {} end
    local out = {}
    for key, step in pairs(enemyDealt) do out[key] = step end
    return out
end

function chaos.enemy_pool()
    local out = {}
    if not OF.util.asks(OF.enemies, "set_step") then return out end
    for _, row in ipairs(OF.enemies.ROWS or {}) do
        for step = 1, #(row.steps or {}) do
            if step ~= row.plain then
                table.insert(out, { key = row.key, id = row.id, step = step,
                    name = row.name, stop = row.steps[step].name })
            end
        end
    end
    if OF.util.asks(OF.offlimits, "keep") then
        out = OF.offlimits.keep("enemy", out, "id", "step")
    end
    return out
end

function chaos.deal_enemy(pick)
    if not OF.util.is_host() then return nil end
    if pick == nil then return nil end
    if not OF.util.asks(OF.enemies, "set_step") then return nil end

    dealingEnemies = true
    local ok = OF.enemies.set_step(pick.key, pick.step, true)
    dealingEnemies = false
    if not ok then return nil end

    enemyDealt[pick.key] = pick.step
    return pick
end

function chaos.give_back_enemies()
    if not OF.util.is_host() then return false end
    if not OF.util.asks(OF.enemies, "set_step") then
        enemyDealt = {}
        return false
    end

    local any = false
    dealingEnemies = true
    for key, step in pairs(enemyDealt) do
        local row = OF.enemies.BY_KEY[key]
        if row ~= nil and OF.enemies.wanted_step(key) == step then
            OF.enemies.set_step(key, row.plain, true)
            any = true
        end
    end
    dealingEnemies = false
    enemyDealt = {}
    return any
end

chaos.SURPRISES = {

    { id = "wg", name = "Wings for everybody",            give = "wing",     kind = "good",
      solo = "@ gets wings" },
    { id = "mt", name = "Everybody turns to metal",       give = "metal",    kind = "good",
      solo = "@ turns to metal" },
    { id = "vn", name = "Everybody goes see-through",     give = "vanish",   kind = "good",
      solo = "@ goes see-through" },
    { id = "ac", name = "Every cap, for everybody",       give = "allcaps",  kind = "good",
      solo = "@ gets every cap at once" },
    { id = "st", name = "Star power for everybody",       give = "invinc",   kind = "good",
      solo = "@ has star power" },
    { id = "sf", name = "A surfboard each",               give = "surf",     kind = "good",
      solo = "@ gets a surfboard" },
    { id = "ff", name = "Fire Mario all round",           give = "fire",     kind = "good",
      solo = "@ is Fire Mario" },
    { id = "fr", name = "Ice Mario all round",            give = "ice",      kind = "good",
      solo = "@ is Ice Mario" },
    { id = "tj", name = "A winged triple jump each",      give = "triple",   kind = "good",
      solo = "@ gets a winged triple jump" },
    { id = "hp", name = "Everybody back to full health",  give = "healfull", kind = "good",
      solo = "@ is back to full health" },
    { id = "lf", name = "An extra life each",             give = "life",     kind = "good",
      solo = "@ gets an extra life" },
    { id = "cn", name = "Coins for everybody",            give = "coins",    kind = "good",
      solo = "@ gets a pocketful of coins" },
    { id = "cb", name = "A cap box each",                 give = "capbox",   kind = "good",
      solo = "A cap box lands in front of @" },
    { id = "cs", name = "Coins scattered round everybody", give = "coinburst", kind = "good",
      solo = "Coins scatter round @" },
    { id = "mg", name = "Coins come to everybody",        give = "magnet",   kind = "good",
      solo = "Coins come to @" },
    { id = "jp", name = "The lot, for everybody",         give = "jackpot",  kind = "good",
      solo = "@ gets the lot" },
    { id = "fa", name = "A fanfare for everybody",        give = "fanfare",  kind = "good",
      solo = "A fanfare for @" },

    { id = "co", name = "Everybody's cap comes off",      give = "capoff",   kind = "warn",
      solo = "@'s cap comes off" },
    { id = "ko", name = "Everybody is knocked over",      give = "knockup",  kind = "warn",
      solo = "@ is knocked over" },
    { id = "tw", name = "Everybody spins like a top",     give = "spintop",  kind = "warn",
      solo = "@ spins like a top" },
    { id = "th", name = "Everybody is thrown across the room", give = "toss", kind = "warn",
      solo = "@ is sent flying" },
    { id = "bo", name = "Everybody bounces like a ball",  give = "ballbounce", kind = "warn",
      solo = "@ bounces like a ball" },
    { id = "rl", name = "Rubber legs for everybody",      give = "spring",   kind = "warn",
      solo = "@ has rubber legs" },
    { id = "pl", name = "Everybody is planted in the ground", give = "planted", kind = "warn",
      solo = "@ is planted in the ground" },
    { id = "dr", name = "Everybody drops what they are carrying", give = "dropit", kind = "warn",
      solo = "@ drops what they are carrying" },
    { id = "sl", name = "Everybody falls asleep",         give = "sleep",    kind = "warn",
      solo = "@ falls asleep" },
    { id = "qk", name = "Everybody's screen shakes",      give = "shakescreen", kind = "warn" },
    { id = "fl", name = "Everybody is flattened",         give = "flatten",  kind = "warn",
      solo = "@ is flattened" },

    { id = "mn", name = "Everybody is sent to the moon",  give = "moon",     kind = "bad",
      solo = "@ is sent to the moon" },
    { id = "pk", name = "Everybody's pockets are emptied", give = "takecoins", kind = "bad",
      solo = "@'s pockets are emptied" },
    { id = "fz", name = "Everybody is frozen",            give = "freeze",   kind = "bad",
      solo = "@ is frozen" },
    { id = "zp", name = "Everybody is zapped",            give = "shock",    kind = "bad",
      solo = "@ is zapped" },
}

chaos.BY_SURPRISE = {}
for _, entry in ipairs(chaos.SURPRISES) do
    chaos.BY_SURPRISE[entry.id] = entry
end

function chaos.surprise_pool()
    local mean = chaos.strength().mean == true
    local out = {}
    for _, entry in ipairs(chaos.SURPRISES) do
        if mean or entry.kind ~= "bad" then table.insert(out, entry) end
    end
    if OF.util.asks(OF.offlimits, "keep") then
        out = OF.offlimits.keep("surprise", out, "id")
    end
    return out
end

local lentSuits = {}

function chaos.lent_keys()
    local list = {}
    if not OF.util.is_host() then return list end
    for key in pairs(lentSuits) do table.insert(list, key) end
    table.sort(list)
    return list
end

function chaos.give_back_powerups()
    if not OF.util.is_host() then return 0 end
    if not OF.util.asks(OF.powerups, "take_back_many") then
        lentSuits = {}
        return 0
    end

    local targets = {}
    for _, player in ipairs(OF.util.connected_players()) do
        local globalIndex = network_global_index_from_local(player.localIndex)
        if globalIndex ~= nil then table.insert(targets, globalIndex) end
    end

    local given = 0
    for _, key in ipairs(chaos.lent_keys()) do
        given = given + OF.powerups.take_back_many(targets, key)
    end
    lentSuits = {}
    return given
end

function chaos.deal_surprise(entry)
    if not OF.util.is_host() then return nil end
    if entry == nil then return nil end
    if not OF.util.asks(OF.powerups, "give_many") then return nil end

    local targets = {}
    for _, player in ipairs(OF.util.connected_players()) do
        local globalIndex = network_global_index_from_local(player.localIndex)
        if globalIndex ~= nil then table.insert(targets, globalIndex) end
    end
    if #targets == 0 then return nil end

    local given = OF.powerups.give_many(targets, entry.give)
    if given == 0 then return nil end

    if OF.util.asks(OF.powerups, "carried_row") then
        if OF.powerups.carried_row(entry.give) then
            lentSuits[entry.give] = true
        end
    end
    return entry, given
end

local dealState = 0

local function next_pick(count)
    if type(count) ~= "number" or count < 1 then return nil end
    if dealState == 0 then
        dealState = (OF.util.optional("get_time", 0) or 0)
            + math.floor(((OF.util.optional("get_global_timer", 0) or 0)) % 100000)
            + 7
    end
    dealState = step_of(dealState)
    return (dealState % count) + 1
end

local bags = {}

local function bag_name(entry)
    if type(entry) ~= "table" or entry.id == nil then return nil end
    local name = tostring(entry.id)
    if entry.step ~= nil then name = name .. "/" .. tostring(entry.step) end
    if entry.level ~= nil then name = name .. "/" .. tostring(entry.level) end
    return name
end

local BAG_HEAVIEST = 8

local function bag_weight(entry)
    local weight = type(entry) == "table" and tonumber(entry.weight) or nil
    if weight == nil then return 1 end
    weight = math.floor(weight)
    if weight < 1 then return 1 end
    if weight > BAG_HEAVIEST then return BAG_HEAVIEST end
    return weight
end

local function bag_refuses(entry, last)
    if entry == nil or last == nil then return false end
    local name = bag_name(entry)
    if name ~= nil and name == bag_name(last) then return true end
    for _, other in ipairs(entry.avoid or {}) do
        if other == last.id or other == last.key then return true end
    end
    return false
end

local function bag_signature(choices)
    local names = {}
    for _, entry in ipairs(choices) do
        table.insert(names, bag_name(entry) or "?")
    end
    return table.concat(names, ",")
end

local function bag_fill(choices)
    local left = {}
    for _, entry in ipairs(choices) do
        local name = bag_name(entry)
        if name ~= nil then
            for _ = 1, bag_weight(entry) do table.insert(left, name) end
        end
    end
    return left
end

function chaos.draw_from_bag(kind, choices, roll)

    if not OF.util.is_host() then return nil end
    if type(choices) ~= "table" or #choices == 0 then return nil end
    roll = roll or next_pick

    local bag = bags[kind]
    local signature = bag_signature(choices)
    if bag == nil or bag.signature ~= signature or #bag.left == 0 then

        bag = { signature = signature, left = bag_fill(choices),
                last = bag ~= nil and bag.last or nil }
        bags[kind] = bag
    end
    if #bag.left == 0 then return nil end

    local at = roll(#bag.left)
    if type(at) ~= "number" then return nil end
    at = math.floor(at)
    if at < 1 or at > #bag.left then return nil end

    local rows = {}
    for _, entry in ipairs(choices) do
        local name = bag_name(entry)
        if name ~= nil then rows[name] = entry end
    end

    local function walk()
        for step = 0, #bag.left - 1 do
            local try = ((at - 1 + step) % #bag.left) + 1
            if not bag_refuses(rows[bag.left[try]], bag.last) then return try end
        end
        return nil
    end

    local found = walk()
    if found == nil then

        local helps = false
        for _, entry in ipairs(choices) do
            if not bag_refuses(entry, bag.last) then
                helps = true
                break
            end
        end
        if helps then
            for _, name in ipairs(bag_fill(choices)) do
                table.insert(bag.left, name)
            end
            found = walk()
        end
    end

    local entry = rows[table.remove(bag.left, found or at)]
    if entry ~= nil then bag.last = entry end
    return entry
end

function chaos.bag_left(kind)
    if not OF.util.is_host() then return {} end
    local bag = bags[kind]
    local out = {}
    for _, name in ipairs(bag ~= nil and bag.left or {}) do
        table.insert(out, name)
    end
    return out
end

function chaos.bag_last(kind)
    if not OF.util.is_host() then return nil end
    local bag = bags[kind]
    if bag == nil then return nil end
    return bag_name(bag.last)
end

function chaos.forget_bags()
    bags = {}
end

local hands = 0

function chaos.hands_dealt()
    if not OF.util.is_host() then return 0 end
    return hands
end

function chaos.surprise_due()

    if not OF.util.is_host() then return false end
    local every = chaos.strength().surprises
    if type(every) ~= "number" or every < 1 then return false end
    return hands % every == 0
end

function chaos.surprise_now()
    if not OF.util.is_host() then return nil end

    local choices = chaos.surprise_pool()
    local pick = chaos.draw_from_bag("surprise", choices)
    if pick == nil then return nil end

    local entry, given = chaos.deal_surprise(pick)
    if entry == nil then return nil end

    return entry, given
end

function chaos.hand_out_a_surprise()
    if not OF.util.is_host() then return nil end
    if not chaos.surprise_due() then return nil end
    return chaos.surprise_now()
end

local lastSolo = nil

function chaos.forget_victims()
    lastSolo = nil
    return true
end

function chaos.last_solo()
    if not OF.util.is_host() then return nil end
    return lastSolo
end

function chaos.victim_seats()
    local out = {}
    if not OF.util.is_host() then return out end

    local headless = gServerSettings ~= nil
        and (tonumber(gServerSettings.headlessServer) or 0) ~= 0

    for _, player in ipairs(OF.util.connected_players()) do
        local globalIndex = network_global_index_from_local(player.localIndex)
        if globalIndex ~= nil and not (headless and player.localIndex == 0) then
            table.insert(out, {
                id = tostring(globalIndex),
                globalIndex = globalIndex,
                localIndex = player.localIndex,
            })
        end
    end
    return out
end

function chaos.solo_pool()
    local mean = chaos.strength().mean == true
    local out = {}
    for _, entry in ipairs(chaos.SURPRISES) do
        if type(entry.solo) == "string"
            and (mean or entry.kind ~= "bad") then
            table.insert(out, entry)
        end
    end
    if OF.util.asks(OF.offlimits, "keep") then
        out = OF.offlimits.keep("surprise", out, "id")
    end
    return out
end

function chaos.solo_odds(globalIndex)
    local lag = 0
    if OF.util.asks(OF.powerups, "lag_of") then
        lag = OF.powerups.lag_of(globalIndex) or 0
    end

    local odds = {}
    for _, entry in ipairs(chaos.solo_pool()) do
        local lift = entry.lift
        if lift == nil then
            local kinder = 1
            if OF.util.asks(OF.powerups, "kindness") then
                kinder = OF.powerups.kindness(entry.kind) or 1
            end
            lift = (tonumber(entry.weight) or 1) * kinder
        end

        table.insert(odds, {
            row = entry,
            weight = OF.util.draw_weight(
                { weight = entry.weight, lift = lift }, lag),
        })
    end
    return odds
end

function chaos.victim_due()
    if not OF.util.is_host() then return false end
    local every = chaos.strength().victims
    if type(every) ~= "number" or every < 1 then return false end
    return hands % every == 0
end

local function already_worn(globalIndex, key)
    if not OF.util.asks(OF.powerups, "carrying") then return false end
    return OF.powerups.carrying(globalIndex, key) == true
end

local function toast_kind(kind)
    if kind == "good" then return "good" end
    if kind == "bad" then return "bad" end
    return "warn"
end

function chaos.victim_now()
    if not OF.util.is_host() then return nil end
    if not OF.util.asks(OF.powerups, "give") then return nil end

    local seats = chaos.victim_seats()
    if #seats == 0 then return nil end
    local seat = chaos.draw_from_bag("victim", seats)
    if seat == nil then return nil end

    local odds = chaos.solo_odds(seat.globalIndex)

    local choices = {}
    for _, item in ipairs(odds) do
        if (lastSolo == nil or item.row.id ~= lastSolo)
            and not already_worn(seat.globalIndex, item.row.give) then
            table.insert(choices, item)
        end
    end
    if #choices == 0 then choices = odds end
    if #choices == 0 then return nil end

    local picked = OF.util.pick_weighted(choices, 0, next_pick)
    if picked == nil then return nil end
    local entry = picked.row

    local ok = OF.powerups.give(seat.globalIndex, entry.give)
    if not ok then return nil end
    lastSolo = entry.id

    if OF.util.asks(OF.powerups, "carried_row") then
        if OF.powerups.carried_row(entry.give) then
            lentSuits[entry.give] = true
        end
    end

    local np = gNetworkPlayers[seat.localIndex]
    local name = OF.util.plain(np ~= nil and np.name or "Somebody")
    OF.notify.send_all(entry.solo, toast_kind(entry.kind), 5, name)
    return entry, seat, name
end

function chaos.hand_out_a_victim()
    if not OF.util.is_host() then return nil end
    if not chaos.victim_due() then return nil end
    return chaos.victim_now()
end

function chaos.tunes()
    local out = {}
    if not OF.util.asks(OF.music, "apply_lobby") then return out end
    for _, entry in ipairs(OF.music.TRACKS or {}) do
        table.insert(out, { id = tostring(entry.seq), seq = entry.seq,
            name = entry.name })
    end
    return out
end

function chaos.tune_pool()
    local out = chaos.tunes()
    if OF.util.asks(OF.offlimits, "keep") then
        out = OF.offlimits.keep("tune", out, "id")
    end
    return out
end

local tuneDealt = nil
local tuneBefore = nil

function chaos.tune_dealt()
    if not OF.util.is_host() then return nil end
    return tuneDealt
end

function chaos.deal_tune(pick)
    if not OF.util.is_host() then return nil end
    if pick == nil or pick.seq == nil then return nil end
    if not OF.util.asks(OF.music, "apply_lobby") then return nil end

    local before = OF.music.lobby_track()
    if not OF.music.apply_lobby(pick.seq) then return nil end
    if tuneBefore == nil then tuneBefore = before end
    tuneDealt = pick.seq
    return pick
end

function chaos.give_back_tune()
    if not OF.util.is_host() then return false end

    local was, mine = tuneBefore, tuneDealt
    tuneBefore, tuneDealt = nil, nil
    if was == nil then return false end
    if not OF.util.asks(OF.music, "apply_lobby") then return false end

    if mine ~= nil and OF.music.lobby_track() ~= mine then return false end
    return OF.music.apply_lobby(was) == true
end

function chaos.tune_due()

    if not OF.util.is_host() then return false end
    local every = chaos.strength().tunes
    if type(every) ~= "number" or every < 1 then return false end
    return hands % every == 0
end

function chaos.tune_now()
    if not OF.util.is_host() then return nil end

    local pick = chaos.draw_from_bag("tune", chaos.tune_pool())
    if pick == nil then return nil end
    return chaos.deal_tune(pick)
end

function chaos.put_on_a_tune()
    if not OF.util.is_host() then return nil end
    if not chaos.tune_due() then return nil end
    return chaos.tune_now()
end

local function deal_an_enemy_row(names)
    if not chaos.strength().enemies then return end

    local pick = chaos.deal_enemy(
        chaos.draw_from_bag("enemy", chaos.enemy_pool()))
    if pick == nil then return end
    table.insert(names, OF.lang.fill("@ - @", OF.lang.t(pick.name),
        OF.lang.t(pick.stop)))
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.asks(OF.offlimits, "register") then return end

    OF.offlimits.register({
        kind = "stunt", id = "s",
        name = "Stunts", one = "stunt",
        items = function()
            local out = {}
            for _, entry in ipairs(chaos.STUNTS) do
                if entry.id ~= nil then
                    table.insert(out, { id = entry.id, name = entry.name })
                end
            end
            return out
        end,
    })

    OF.offlimits.register({
        kind = "surprise", id = "x",
        name = "Surprises", one = "surprise",
        items = function()
            local out = {}
            for _, entry in ipairs(chaos.SURPRISES) do
                table.insert(out, { id = entry.id, name = entry.name })
            end
            return out
        end,
    })

    OF.offlimits.register({
        kind = "enemy", id = "e",
        name = "The enemies", one = "enemy setting",
        items = function()
            local out = {}
            for _, row in ipairs(OF.util.asks(OF.enemies, "set_step")
                and OF.enemies.ROWS or {}) do
                local levels = {}
                for _, step in ipairs(row.steps or {}) do
                    table.insert(levels, step.name)
                end
                table.insert(out, { id = row.id, name = row.name,
                    levels = levels })
            end
            return out
        end,
    })

    OF.offlimits.register({
        kind = "tune", id = "t",
        name = "The music", one = "track",
        items = function()
            local out = {}
            for _, entry in ipairs(chaos.tunes()) do
                table.insert(out, { id = entry.id, name = entry.name })
            end
            return out
        end,
    })
end)

local function hand_state()
    local state = { anomalies = 0, held = 0 }
    for key in pairs(dealt) do
        state.held = state.held + 1
        if chaos.is_anomaly(key) then state.anomalies = state.anomalies + 1 end
    end
    return state
end

local function put_on(set, pick, state)
    local entry = OF.modifiers.BY_KEY[pick.key]
    if entry == nil then return nil end

    local anomaly = chaos.is_anomaly(pick.key)
    if anomaly and state.anomalies >= chaos.anomaly_cap() then return nil end

    local cap = chaos.slot_cap()
    if cap ~= nil and state.held >= cap then return nil end

    if set[pick.key] ~= nil then return nil end

    if anomaly then state.anomalies = state.anomalies + 1 end
    set[pick.key] = pick.level
    dealt[pick.key] = { level = pick.level, left = life_of(pick.key, pick.level) }
    state.held = state.held + 1

    for _, other in ipairs(entry.excludes or {}) do
        if dealt[other] ~= nil then
            state.held = state.held - 1
            if chaos.is_anomaly(other) then
                state.anomalies = state.anomalies - 1
            end
        end
        set[other] = nil
        dealt[other] = nil
    end

    return OF.modifiers.step_name(pick.key, pick.key .. "=" .. pick.level)
end

function chaos.deal_modifier(key, level)
    if not OF.util.is_host() then return nil end
    local entry = OF.modifiers.BY_KEY[tostring(key or "")]
    if entry == nil then return nil end
    level = math.floor(tonumber(level) or 0)
    if level < 1 or level > OF.modifiers.step_count(entry) then return nil end
    if OF.util.asks(OF.offlimits, "allows")
        and not OF.offlimits.allows("mod", entry.id, level) then
        return nil
    end

    local set = OF.modifiers.parse(OF.modifiers.text())
    local name = put_on(set, { key = entry.key, level = level }, hand_state())
    if name == nil then return nil end
    OF.modifiers.borrow(function()
        OF.modifiers.set_text(OF.modifiers.pack(set))
    end)
    return name
end

local function log_the_stunt(entry)
    if entry == nil or type(entry.name) ~= "string" then return end
    if not OF.util.asks(OF.actionlog, "auto") then return end
    OF.actionlog.auto(OF.lang.fill("the chaos dealt a stunt: @",
        OF.lang.t(entry.name)))
end

function chaos.roll()
    if not OF.util.is_host() then return nil end

    chaos.end_stunt()

    chaos.give_back_enemies()

    hands = hands + 1

    local set = OF.modifiers.parse(OF.modifiers.text())
    local going, staying = {}, {}
    for key, held in pairs(dealt) do
        if held.left == nil then
            going[key] = held.level
        else
            staying[key] = held
        end
    end
    take_back(set, going)
    dealt = staying

    OF.util.seed_random()

    if math.random(chaos.stunt_odds()) == 1 then
        OF.modifiers.borrow(function()
            OF.modifiers.set_text(OF.modifiers.pack(set))
        end)
        local stunts = chaos.stunt_pool()
        local entry = chaos.draw_from_bag("stunt", stunts, math.random)
        local put = entry ~= nil and chaos.wear_stunt(entry) or nil
        if put ~= nil then
            log_the_stunt(entry)
            chaos.hand_out_a_surprise()
            chaos.hand_out_a_victim()

            chaos.put_on_a_tune()
            return OF.modifiers.parse(OF.modifiers.text())
        end

    end

    local choices = pool()
    local names = {}

    local state = hand_state()

    for _ = 1, chaos.deal_count() do
        if #choices == 0 then break end
        local at = math.random(#choices)
        local pick = choices[at]
        table.remove(choices, at)

        local name = put_on(set, pick, state)
        if name ~= nil then table.insert(names, name) end
    end

    OF.modifiers.borrow(function()
        OF.modifiers.set_text(OF.modifiers.pack(set))
    end)

    deal_an_enemy_row(names)

    chaos.hand_out_a_surprise()

    chaos.hand_out_a_victim()

    chaos.put_on_a_tune()
    return set
end

function chaos.age(count)
    if not OF.util.is_host() then return {} end
    count = math.floor(tonumber(count) or 1)
    if count < 1 then count = 1 end

    local lapsed = {}
    local gone = {}
    for key, held in pairs(dealt) do
        if held.left ~= nil then
            held.left = held.left - count
            if held.left <= 0 then
                lapsed[key] = held.level
                table.insert(gone, key)
            end
        end
    end
    if #gone == 0 then return gone end

    local set = OF.modifiers.parse(OF.modifiers.text())
    take_back(set, lapsed)
    for key in pairs(lapsed) do dealt[key] = nil end
    OF.modifiers.borrow(function()
        OF.modifiers.set_text(OF.modifiers.pack(set))
    end)

    table.sort(gone)
    return gone
end

function chaos.set(seconds, askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then seconds = 0 end

    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(chaos.ACTION, seconds)
        end
        return false, "No host to ask yet - try again in a second."
    end

    if seconds <= 0 then
        if not chaos.on() then return false, "The chaos is already off." end

        chaos.end_stunt()

        chaos.give_back_enemies()

        chaos.give_back_powerups()

        chaos.give_back_tune()
        OF.util.publish(chaos.KEY, nil)
        OF.util.publish(chaos.NEXT_KEY, nil)

        local set = OF.modifiers.parse(OF.modifiers.text())
        take_back(set, dealt_levels())
        for key, level in pairs(borrowed or {}) do
            if set[key] == nil then set[key] = level end
        end
        OF.modifiers.borrow(function()
        OF.modifiers.set_text(OF.modifiers.pack(set))
    end)
        dealt = {}
        borrowed = nil
        frames = 0
        hands = 0

        chaos.forget_bags()

        chaos.forget_victims()
        OF.notify.send_all("The chaos is over", "info", 4)

        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal, OF.lang.t("stopped the chaos"))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.t("stopped the chaos"))
        return true
    end

    local first = not chaos.on()
    if first then borrowed = OF.modifiers.parse(OF.modifiers.text()) end
    OF.util.publish(chaos.KEY, seconds)
    OF.util.publish(chaos.NEXT_KEY, seconds)
    frames = seconds * 30

    if first then
        OF.notify.send_all("Chaos every @ seconds - hold on", "warn", 6, seconds)

        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal,
                OF.lang.fill("chaos every @ seconds", tostring(seconds)))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.fill("started the chaos: every @ seconds",
                tostring(seconds)))

        begin_series()
        seriesAt = 1

        hands = 0
        chaos.roll()
        frames = seconds * 30
        OF.util.publish(chaos.NEXT_KEY, seconds)
    end
    return true
end

function chaos.cycle(askerLocal)
    local current = chaos.interval()
    local at = 1
    for i, seconds in ipairs(chaos.STEPS) do
        if seconds == current then at = i end
    end
    at = at + 1
    if at > #chaos.STEPS then at = 1 end
    return chaos.set(chaos.STEPS[at], askerLocal)
end

function chaos.can_ask_host()
    if OF.util.is_host() then return true end
    if not OF.util.asks(OF.net, "host_does") then return false end
    local seat = OF.util.local_from_global(0)
    return seat ~= nil and seat > 0
end

function chaos.label()
    local seconds = chaos.interval()
    if seconds <= 0 then return nil end
    return OF.lang.fill("every @s", seconds)
end

local function host_update()
    if not OF.util.is_host() then return end
    if not chaos.on() then return end

    if a_round_has_them() then return end

    if worn ~= nil then
        stuntFrames = stuntFrames - 1
        if stuntFrames <= 0 then

            chaos.end_stunt()
        end
    end

    chaos.age(1)

    frames = frames - 1
    if frames > 0 then
        if frames % 30 == 0 then
            OF.util.publish(chaos.NEXT_KEY, math.floor(frames / 30))
        end
        return
    end

    seriesAt = seriesAt + 1
    if seriesAt > SERIES then
        begin_series()
        seriesAt = 1
    end

    if seriesAt == cleanAt then
        chaos.quiet()
    else
        chaos.roll()
    end

    frames = chaos.interval() * 30
    OF.util.publish(chaos.NEXT_KEY, chaos.interval())
end

hook_event(HOOK_UPDATE, host_update)

local function render()
    if not chaos.on() then return end

    if OF.util.menu_has_screen() then return end

    local left = chaos.next_in()
    if left == nil then return end

    local text
    local stunt = chaos.stunt_name()
    if a_round_has_them() then
        text = OF.lang.t("Chaos - waiting for the round")
    elseif stunt ~= nil then

        text = OF.lang.fill("Chaos: @", OF.lang.t(stunt))
    else
        text = OF.lang.fill("Chaos in @s", left)
    end

    djui_hud_set_resolution(RESOLUTION_DJUI)

    djui_hud_set_font(FONT_NORMAL)

    local r, g, b = 255, 200, 90
    if left <= 5 and math.floor(left * 2) % 2 == 0 then r, g, b = 255, 255, 255 end
    OF.util.banner(text, 0.7, r, g, b, 255)
end

hook_event(HOOK_ON_HUD_RENDER, render)

local learnStars = nil

function chaos.forget_learning_stars()
    learnStars = nil
end

local function learn_update()
    if not OF.util.is_host() then return end
    if OF.modifiers.level("learn") <= 0 then
        learnStars = nil
        return
    end

    if a_round_has_them() then return end

    local m = gMarioStates[0]
    if m == nil or type(m.numStars) ~= "number" then return end
    if learnStars == nil or m.numStars <= learnStars then
        learnStars = m.numStars
        return
    end

    learnStars = m.numStars
    local action = OF.modifiers.learn_one()
    if action ~= nil then

        local progress = OF.lang.fill("@ of @",
            tostring(OF.modifiers.learned()),
            tostring(OF.modifiers.learnable_count()))
        local named = OF.util.asks(OF.modifiers, "move_name")
            and OF.modifiers.move_name(action) or nil
        if named ~= nil then
            OF.notify.send_all("@ comes back - @", "good", 5, named, progress)
        else
            OF.notify.send_all("A move comes back - @", "good", 5, progress)
        end
    end
end

hook_event(HOOK_UPDATE, learn_update)

function chaos.build_page(panel)
    local rows = {}

    table.insert(rows, panel.with_help(panel.label_row(OF.lang.t(
        "The lobby deals itself something new on a clock, and never says what.")),
        OF.lang.t("nobody is told what landed - finding out is the game")))

    if not chaos.can_ask_host() then
        table.insert(rows, panel.label_row(
            OF.lang.t("Waiting for the host - these are the host's to run.")))
    end

    local on = chaos.on()
    local r, g, b = 255, 255, 255
    if on then r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b end

    local switch = panel.with_help(panel.gated_row("speedrun",
        panel.tick(on, OF.lang.t("Chaos")), r, g, b,

        function() OF.util.report(chaos.cycle(0)) end),
        OF.lang.t("press for the next interval, again to turn it off"))

    switch = panel.level_right(switch, on, chaos.label())
    table.insert(rows, switch)

    local wild = panel.with_help(panel.gated_row("speedrun",
        OF.lang.t("How wild"), 255, 255, 255,
        function() OF.util.report(chaos.cycle_strength()) end),
        chaos.strength_note())
    wild.right = chaos.strength_label()
    table.insert(rows, wild)

    if on then
        if chaos.paused_by_round() then
            table.insert(rows, panel.label_row(
                OF.lang.t("Paused - the round has the lobby.")))
        else
            local left = chaos.next_in()
            if left ~= nil then
                table.insert(rows, panel.label_row(
                    OF.lang.fill("Next in @s", left)))
            end
        end
    end

    table.insert(rows, panel.back_row("fun"))
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.chaos ~= nil then return end
    panel.PAGES.chaos = {
        title = "Chaos", tab = "room", up = "chance", fold = false,
        build = function() return chaos.build_page(panel) end,
    }
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.net == nil or OF.net.register_action == nil then return end

    OF.net.register_action(chaos.ACTION, "speedrun", function(asker, seconds)
        if not OF.util.is_host() then return false, "Only the host." end
        return chaos.set(math.floor(tonumber(seconds) or 0), asker)
    end)

    OF.net.register_action(chaos.WILD_ACTION, "speedrun", function(_, key)
        if not OF.util.is_host() then return false, "Only the host." end
        return chaos.set_strength(tostring(key or ""))
    end)
end)

function chaos.ready()
    return true
end
