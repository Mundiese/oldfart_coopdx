OF = OF or {}
OF.perms = OF.perms or {}

local perms = OF.perms

OF.TIER = {
    MUTED   = 0,
    NORMAL  = 10,
    CREW    = 30,
    MOD     = 40,
    COHOST  = 45,
    HOST    = 50,
}
OF.TIER.VIP = OF.TIER.CREW
OF.TIER.TRUSTED = OF.TIER.CREW

OF.TIER_ALIAS = { [20] = OF.TIER.CREW }

function perms.canon(tier)
    if tier == nil then return nil end
    return OF.TIER_ALIAS[tier] or tier
end

OF.TIER_ORDER = { OF.TIER.MUTED, OF.TIER.NORMAL, OF.TIER.CREW,
                  OF.TIER.MOD, OF.TIER.COHOST, OF.TIER.HOST }

local CREW_LABEL = "CREW"
OF.TIER_INFO = {
    [OF.TIER.MUTED]   = { key = "muted",   label = "MUTED",   r = 120, g = 120, b = 120 },
    [OF.TIER.NORMAL]  = { key = "normal",  label = "",        r = 200, g = 200, b = 200 },
    [OF.TIER.CREW]    = { key = "crew",    label = CREW_LABEL, r = 255, g = 215, b = 0   },
    [OF.TIER.MOD]     = { key = "mod",     label = "MOD",     r = 150, g = 255, b = 150 },
    [OF.TIER.COHOST]  = { key = "cohost",  label = "CO-HOST", r = 255, g = 150, b = 60  },
    [OF.TIER.HOST]    = { key = "host",    label = "HOST",    r = 255, g = 80,  b = 80  },
}

perms.TIER_NAMES = {
    [OF.TIER.MUTED]   = { "MUTED", "SILENCED", "BENCHED" },
    [OF.TIER.NORMAL]  = { "", "PLAYER", "GUEST" },
    [OF.TIER.CREW]     = { CREW_LABEL, "PATRON", "VETERAN" },

    [OF.TIER.MOD]     = { "MOD", "STAFF", "TEAM" },
    [OF.TIER.COHOST]  = { "CO-HOST", "DEPUTY", "SECOND" },
    [OF.TIER.HOST]    = { "HOST", "OWNER", "KEEPER" },
}

perms.RUNG_ID = {
    [OF.TIER.MUTED]   = "The silenced rung",
    [OF.TIER.NORMAL]  = "The rung everybody joins on",
    [OF.TIER.CREW]     = "The rung with the menu",
    [OF.TIER.MOD]     = "The moderators' rung",
    [OF.TIER.COHOST]  = "The host's second",
    [OF.TIER.HOST]    = "The host's own rung",
}

perms.OPTIONAL_TIERS = {
    [OF.TIER.CREW]     = true,
    [OF.TIER.MOD]     = true,
    [OF.TIER.COHOST]  = true,
}

perms.DEFAULTS = {

    panel          = OF.TIER.CREW,

    round_move     = OF.TIER.MUTED,

    corpse_find    = OF.TIER.MUTED,

    harsh_report   = OF.TIER.MUTED,

    spray          = OF.TIER.CREW,

    spray_clear    = OF.TIER.MOD,

    chat           = OF.TIER.NORMAL,
    vote           = OF.TIER.NORMAL,

    share_health   = OF.TIER.MOD,
    teleport_self  = OF.TIER.CREW,
    waypoint_use   = OF.TIER.CREW,
    waypoint_save  = OF.TIER.CREW,
    spectate       = OF.TIER.CREW,

    costume_self   = OF.TIER.CREW,

    possess_self   = OF.TIER.CREW,

    doorway_own    = OF.TIER.CREW,
    powerup_self   = OF.TIER.CREW,

    modifier_self  = OF.TIER.CREW,

    harsh_self     = OF.TIER.CREW,

    powerup_tune   = OF.TIER.CREW,
    spawn_object   = OF.TIER.CREW,

    teleport_other = OF.TIER.MOD,

    music          = OF.TIER.MOD,

    rules          = OF.TIER.MOD,
    warp_lobby     = OF.TIER.MOD,
    message        = OF.TIER.MOD,
    mute           = OF.TIER.MOD,
    jail           = OF.TIER.MOD,
    speedrun       = OF.TIER.MOD,

    end_round      = OF.TIER.MOD,

    vision         = OF.TIER.MOD,
    powerup_other  = OF.TIER.MOD,

    costume_other  = OF.TIER.MOD,

    possess_other  = OF.TIER.MOD,

    save_edit      = OF.TIER.MOD,

    ban            = OF.TIER.COHOST,
    ranks          = OF.TIER.COHOST,

    settings       = OF.TIER.COHOST,

    permissions    = OF.TIER.HOST,

    cheats_self    = OF.TIER.CREW,
    cheats_lobby   = OF.TIER.MOD,

    fun_self       = OF.TIER.CREW,

    chaos          = OF.TIER.MOD,

    signpost       = OF.TIER.CREW,

    music_self     = OF.TIER.CREW,
}

perms.CARVED_FROM = {
    cheats_self  = "powerup_self",
    cheats_lobby = "powerup_other",
    fun_self     = "costume_self",
    chaos        = "speedrun",
    signpost     = "chat",
    music_self   = "costume_self",
}

local PERM_PREFIX = "perm_"
perms.LABELS = {
    panel = "Open the mod menu",

    round_move = "Play their part in a round",

    corpse_find = "Report a body they find",
    harsh_report = "Set off an armed save wipe",
    spray = "Spray their mark on a wall",
    spray_clear = "Clear every spray",

    chat = "Talk in chat",
    vote = "Start a vote",

    share_health = "Share a health bar",
    teleport_self = "Teleport themselves",
    waypoint_use = "Use waypoints",
    waypoint_save = "Save waypoints",

    doorway_own = "Place their own doorways",
    spectate = "Spectate players",
    powerup_self = "Give themselves powerups",

    modifier_self = "Set modifiers and moves for themselves",

    harsh_self = "Set what a mistake costs for themselves",
    powerup_tune = "Change how powerups are handed out",

    spawn_object = "Build and spawn (Forge)",
    teleport_other = "Teleport other players",
    music = "Change the lobby's music",
    warp_lobby = "Load a map for everybody",
    message = "Send screen messages",
    mute = "Mute players",
    jail = "Jail and freeze players",

    speedrun = "Run rounds, modes and modifiers",

    end_round = "End a round that is running",
    vision = "Build the lobby's picture",
    powerup_other = "Give others powerups",
    costume_self = "Wear a costume",
    costume_other = "Dress other players",
    possess_self = "Ride a creature",

    possess_other = "Put others on creatures",
    save_edit = "Edit save files",
    ban = "Ban players",
    ranks = "Change ranks",

    settings = "Change the lobby's settings",

    rules = "Change how the game plays",
    permissions = "Change what a rank may do",
    cheats_self = "Use cheats on themselves",
    cheats_lobby = "Turn on cheats for the lobby",

    fun_self = "Use emotes, pets and hats",
    chaos = "Run Chaos and the Randomizer",
    signpost = "Leave signposts",
    music_self = "Personal music",
}

perms.COVERS = {
    panel = "opening this menu at all - everything else is decided inside it",
    round_move = "a player's own move inside a round: the swing, the accusation, the answer",
    corpse_find = "telling the lobby about a body you walked up to, and taking your own coins back off yours",
    harsh_report = "a bonk or a death of their own reaching the save wipe the host armed on Hard mode",
    spray = "spraying a mark in their own colour where they aim, and wiping their own",
    spray_clear = "wiping every mark in the lobby off every screen at once",
    chat = "typing in the lobby's chat, and nothing else",
    vote = "putting a question to the lobby and starting the count on it",
    share_health = "tying two players to one health bar, with nobody asked",
    teleport_self = "moving yourself - to a player, to a waypoint, to the moon",
    waypoint_use = "travelling to a place somebody has already saved",
    waypoint_save = "writing a new place into the lobby's list of them",
    spectate = "watching the lobby from somebody else's camera",

    costume_self = "your own character, and what your own screen and speakers do",
    possess_self = "getting on a creature yourself",
    possess_other = "putting somebody else on a creature",
    doorway_own = "placing a pair of openings the whole lobby can see and walk through",
    powerup_self = "handing yourself a cap, a shell, a star or a boost",
    modifier_self = "the right-hand box on a modifier or a move row - your own camera, sound, body and moveset",
    harsh_self = "the right-hand box on Hard mode - what your own mistakes cost you",
    powerup_tune = "the amount on a counted hand-out - how many coins or lives one gives",
    spawn_object = "the Forge: building, and dropping objects and creatures into the level",
    teleport_other = "moving somebody else - to you, to a player, to a place, to the moon",
    music = "what the lobby is listening to, and whether it plays at all",
    warp_lobby = "loading a level for the whole lobby, taking one back, and opening an arena",
    message = "putting a line of your own on everybody's screen",
    mute = "taking somebody's chat away, giving it back, the reports the lobby files, and clearing a pet name or a poll somebody else put up",
    jail = "timeouts, the moon, freezing somebody, and lifting any of it",
    speedrun = "the rounds, the queue, every game mode, the teams and the modifiers",
    end_round = "stopping a game mode or a race that is already running, which a round's own lock never takes away",
    vision = "how the lobby is drawn - the light, the lens, the weather, the shapes",
    powerup_other = "handing somebody else a cap, a shell, a star or a boost",
    costume_other = "changing what another player looks like",
    save_edit = "rewriting the stars, coins and keys in another player's save file",
    ban = "keeping somebody out of the lobby, and letting them back in",
    ranks = "promoting and demoting people, and how long a promotion lasts",
    rules = "the game's own settings, and what a mistake costs, while nothing is running",
    settings = "the session reset, the chat filter, the stats and calling a vote off",
    permissions = "this page and the four beside it - what every rung in the lobby may reach",
    cheats_self = "the right-hand box on the Cheats page - cheats that reach only their own Mario",
    cheats_lobby = "the left-hand box on the Cheats page, and the item boxes the lobby never shows",
    fun_self = "playing an emote, keeping a pet and wearing a hat - an emote also needs chat",
    chaos = "the Chaos clock, its deck and blocklist, and the Randomizer's rows",
    signpost = "leaving a signpost where they stand, and taking their own down",
    music_self = "Z on a track or the volume on the Music page - what this machine alone hears",
}

perms.IMPLIES = {
    teleport_other = { "teleport_self" },
    warp_lobby     = { "teleport_self" },

    speedrun       = { "end_round" },
}

perms.IMPLIED_BY = {}
for holder, gets in pairs(perms.IMPLIES) do
    for _, feature in ipairs(gets) do
        local holders = perms.IMPLIED_BY[feature] or {}
        holders[#holders + 1] = holder
        perms.IMPLIED_BY[feature] = holders
    end
end

perms.HOST_ONLY = {

    permissions    = true,
}

function perms.needs_host(feature)
    return perms.HOST_ONLY[feature] == true
end

perms.ORDER = {
    "panel", "vote", "teleport_self", "waypoint_use", "waypoint_save", "spectate",
    "powerup_self", "spawn_object", "teleport_other", "warp_lobby", "message",
    "mute", "jail", "speedrun", "powerup_other", "save_edit", "ban", "ranks",
    "settings",

    "music",

    "permissions",

    "vision",

    "costume_self", "costume_other",

    "powerup_tune",

    "chat",

    "possess_self", "possess_other",

    "share_health",
    "rules",

    "doorway_own",

    "end_round",

    "modifier_self",

    "harsh_self",

    "round_move",

    "corpse_find",

    "spray",

    "spray_clear",

    "cheats_self",
    "cheats_lobby",
    "fun_self",
    "chaos",
    "signpost",

    "music_self",

    "harsh_report",
}

perms.GROUPS = {
    { key = "self", name = "Yourself",
      help = "what a player may do with and for their own Mario, which lands on nobody else",
      subs = { panel = "Being here", teleport_self = "Getting around",
               costume_self = "Their own look and sound",
               powerup_self = "Their own Mario" },
      features = { "panel", "chat", "vote", "spray", "signpost",
                   "teleport_self", "waypoint_use", "spectate",
                   "costume_self", "fun_self", "music_self", "possess_self",
                   "powerup_self", "cheats_self", "modifier_self",
                   "harsh_self" } },
    { key = "others", name = "Others",
      help = "every row here is felt by a player who did not press it",
      features = { "teleport_other", "costume_other", "possess_other",
                   "powerup_other", "share_health" } },
    { key = "lobby", name = "The lobby",
      help = "the level everybody stands in, what it looks and sounds like, and how it plays",
      features = { "warp_lobby", "music", "vision", "rules", "cheats_lobby",
                   "chaos", "powerup_tune" } },
    { key = "rounds", name = "Rounds",
      help = "game modes, the queue, races, and a player's own part in a round",
      features = { "round_move", "corpse_find", "harsh_report", "speedrun", "end_round" } },
    { key = "building", name = "Building",
      help = "the Forge, and the doorways and waypoints that stay in a level",
      features = { "spawn_object", "doorway_own", "waypoint_save" } },

    { key = "moderation", name = "Moderation",
      help = "keeping the lobby in order: chat, the jail, bans, ranks and the save file",
      subs = { message = "Chat and conduct", settings = "The lobby's records" },
      features = { "message", "mute", "jail", "spray_clear",
                   "settings", "save_edit", "ban", "ranks" } },
    { key = "host", name = "Host only",
      help = "the ladder itself - no rank can be handed it",
      features = { "permissions" } },
}

perms.OLD_GROUP_KEYS = { "own", "others", "world", "evening", "around", "record" }

function perms.grouped_order()
    local filed, out = {}, {}
    for _, group in ipairs(perms.GROUPS) do
        local features = {}
        for _, feature in ipairs(group.features) do

            if perms.DEFAULTS[feature] ~= nil and not filed[feature] then
                filed[feature] = true
                features[#features + 1] = feature
            end
        end
        if #features > 0 then
            out[#out + 1] = { key = group.key, name = group.name,
                              help = group.help, features = features,
                              subs = group.subs }
        end
    end

    local rest = {}
    for _, feature in ipairs(perms.ORDER) do
        if not filed[feature] then rest[#rest + 1] = feature end
    end
    if #rest > 0 then
        out[#out + 1] = { key = "unfiled",
            name = "Not sorted into a group yet",
            help = "this build added them and has not said what they are about",
            features = rest }
    end
    return out
end

local function stored_required(feature)
    local stored = mod_storage_load_integer(PERM_PREFIX .. feature, -1)
    if stored >= 0 then return perms.canon(stored) end
    return nil
end

local PUBLISH_FIELD = ":"
local PUBLISH_ROW = ","
local NAME_ROW = 900
local RUNG_ROW = 901

local ROUND_ROW = 800
perms.NAME_ROW = NAME_ROW
perms.RUNG_ROW = RUNG_ROW

local RUNG_PREFIX = "permrung_"
local TIER_NAME_PREFIX = "permname_"
local function tier_position(tier)
    for at, value in ipairs(OF.TIER_ORDER) do
        if value == tier then return at end
    end
    return nil
end

perms.tier_position = tier_position

local function stored_name_index(tier)
    local ring = perms.TIER_NAMES[tier]
    if ring == nil then return 1 end
    local pick = mod_storage_load_integer(
        TIER_NAME_PREFIX .. perms.tier_info(tier).key, 1)
    if pick < 1 or pick > #ring then return 1 end
    return pick
end

local function stored_in_use(tier)
    if perms.OPTIONAL_TIERS[tier] ~= true then return true end
    return mod_storage_load_integer(
        RUNG_PREFIX .. perms.tier_info(tier).key, 1) ~= 0
end

perms.stored_in_use = stored_in_use
perms.stored_name_index = stored_name_index

local function tier_wire_rows()
    local names, rungs = {}, {}
    local moved = false
    for at, tier in ipairs(OF.TIER_ORDER) do
        local pick = stored_name_index(tier)
        names[at] = tostring(pick)
        rungs[at] = stored_in_use(tier) and "1" or "0"
        if pick ~= 1 or rungs[at] == "0" then moved = true end
    end
    if not moved then return nil, nil end
    return table.concat(names), table.concat(rungs)
end

local WIRE_CHUNK = 112

local WIRE_KEYS = { "ofPerms", "ofPerms2", "ofPerms3", "ofPerms4", "ofPerms5",
                    "ofPerms6", "ofPerms7", "ofPerms8" }

perms.WIRE_CHUNK = WIRE_CHUNK
perms.WIRE_KEYS = WIRE_KEYS

function perms.wire_text()
    return OF.util.joined(WIRE_KEYS)
end

local function publish_parts(parts)
    local chunks = OF.util.chunk_parts(parts, WIRE_CHUNK)
    if chunks == nil or #chunks > #WIRE_KEYS then
        OF.util.chat("Too many permission changes to send at once ("
            .. tostring(#parts) .. " of them).", "warn")
        return false
    end
    local ok = true
    for index, wireKey in ipairs(WIRE_KEYS) do
        if not OF.util.publish(wireKey, chunks[index] or "") then ok = false end
    end
    return ok
end

local overrideText = nil
local overrideCache = {}
local roundCache = {}

local nameCache = nil
local rungCache = nil

local function overrides()
    local packed = perms.wire_text()

    if packed == overrideText then return overrideCache end

    local parsed = {}
    local names, rungs = nil, nil
    local round = {}
    for row in string.gmatch(packed, "[^" .. PUBLISH_ROW .. "]+") do

        local index, tier = string.match(row,
            "^(%d+)" .. PUBLISH_FIELD .. "(%d+)$")
        local at = index ~= nil and tonumber(index) or nil

        if at == NAME_ROW then
            names = tier
        elseif at == RUNG_ROW then
            rungs = tier
        elseif at == ROUND_ROW then
            round[true] = true
        elseif at ~= nil and at > ROUND_ROW and at < NAME_ROW then

        else
            local feature = at ~= nil and perms.ORDER[at] or nil
            if feature ~= nil and perms.DEFAULTS[feature] ~= nil then
                parsed[feature] = tonumber(tier)
            end
        end
    end

    overrideText = packed
    overrideCache = parsed
    roundCache = round
    nameCache = names
    rungCache = rungs
    return parsed
end

perms.lockdown = false

perms.roundHold = false

function perms.set_round_hold(on)
    if not OF.util.is_host() then return false end
    on = (on == true)
    if perms.roundHold == on then return true end
    perms.roundHold = on
    perms.publish()
    return true
end

function perms.set_lockdown(on)
    if not OF.util.is_host() then return false end
    perms.lockdown = (on == true)
    perms.publish()
    return true
end

function perms.publish()
    if not OF.util.is_host() then return false end

    local parts = {}
    for index, feature in ipairs(perms.ORDER) do
        local stored = stored_required(feature)

        if perms.FIXED[feature] or perms.HOST_ONLY[feature] then stored = nil end

        if perms.lockdown and not perms.FIXED[feature] and feature ~= "chat"
            and feature ~= "end_round" then

            stored = OF.TIER.HOST
        end
        if stored ~= nil and stored ~= perms.DEFAULTS[feature] then

            table.insert(parts,
                index .. PUBLISH_FIELD .. stored .. PUBLISH_ROW)
        end
    end

    if perms.roundHold and not perms.lockdown then

        table.insert(parts, ROUND_ROW .. PUBLISH_FIELD .. "1" .. PUBLISH_ROW)
    end

    local names, rungs = tier_wire_rows()
    if names ~= nil then
        table.insert(parts, NAME_ROW .. PUBLISH_FIELD .. names .. PUBLISH_ROW)
        table.insert(parts, RUNG_ROW .. PUBLISH_FIELD .. rungs .. PUBLISH_ROW)
    end

    if perms.wire_text() == table.concat(parts, "") then return true end
    return publish_parts(parts)
end

perms.FIXED = { panel = true, round_move = true, corpse_find = true, harsh_report = true }

local function own_required(feature, who)

    if perms.FIXED[feature] then
        return perms.DEFAULTS[feature] or OF.TIER.NORMAL
    end

    if perms.HOST_ONLY[feature] then return OF.TIER.HOST end
    local override = overrides()[feature]
    local needs = override
    if needs == nil then needs = perms.DEFAULTS[feature] or OF.TIER.HOST end
    return perms.in_the_round(feature, needs, who)
end

function perms.in_the_round(feature, needs, who)
    if feature == "chat" or feature == "end_round" then return needs end
    if roundCache[true] ~= true then return needs end
    local rung = OF.TIER.HOST
    if rung <= needs then return needs end

    local lockdown = OF.lockdown
    if OF.util.asks(lockdown, "round_or_run") and not lockdown.round_or_run() then
        return rung
    end
    local scope = OF.roundscope
    if scope == nil or scope.inside == nil then return rung end
    if scope.inside(who or 0) then return rung end
    return needs
end

function perms.required(feature, who)
    local needs = own_required(feature, who)

    local holders = perms.IMPLIED_BY[feature]
    if holders ~= nil then
        for _, holder in ipairs(holders) do
            local theirs = own_required(holder, who)
            if theirs < needs then needs = theirs end
        end
    end

    return perms.nearest_in_use(needs, 1)
end

local function may_set_perms()

    if not OF.perms.can("permissions") then
        return false, "Your rank cannot do that.", "permissions"
    end
    if not OF.util.is_host() then
        return false, "Only the host may change what a rank can do."
    end
    return true
end

perms.may_set = may_set_perms

function perms.set_required(feature, tier)
    tier = perms.canon(tier)
    local allowed, why = may_set_perms()
    if not allowed then return false, why end
    if perms.DEFAULTS[feature] == nil then return false end

    if perms.FIXED[feature] then
        return false, "That rung is fixed in the build - it is not a setting."
    end

    if perms.HOST_ONLY[feature] then
        return false, "That one is the host's own machine, whatever the rank."
    end

    for _, holder in ipairs(perms.IMPLIED_BY[feature] or {}) do
        if tier > own_required(holder) then
            return false, OF.lang.fill(
                "Anyone who may already do @ can do this - move that one first.",
                perms.LABELS[holder] or holder)
        end
    end
    for _, gets in ipairs(perms.IMPLIES[feature] or {}) do
        if tier < own_required(gets) then
            return false, OF.lang.fill(
                "This already opens @, which sits higher - move that one first.",
                perms.LABELS[gets] or gets)
        end
    end
    if not OF.util.store_integer(PERM_PREFIX .. feature, tier) then return false end
    perms.publish()
    return true
end

function perms.reset()
    local allowed, why = may_set_perms()
    if not allowed then return false, why end
    for feature, _ in pairs(perms.DEFAULTS) do
        mod_storage_remove(PERM_PREFIX .. feature)
    end
    perms.publish()
    return true
end

local ROUND_PREFIX = "permround_"
function perms.set_tier_name(tier, index)
    local allowed, why = may_set_perms()
    if not allowed then return false, why end
    local ring = perms.TIER_NAMES[tier]
    if ring == nil then return false, "That is not a rung." end
    index = OF.util.clamp(math.floor(tonumber(index) or 1), 1, #ring)
    if not OF.util.store_integer(
        TIER_NAME_PREFIX .. perms.tier_info(tier).key, index) then
        return false, "The save file would not take that name - nothing changed."
    end
    perms.publish()
    return true
end

function perms.cycle_tier_name(tier)
    local ring = perms.TIER_NAMES[tier]
    if ring == nil then return false, "That is not a rung." end
    return perms.set_tier_name(tier, (perms.tier_name_index(tier) % #ring) + 1)
end

function perms.set_tier_in_use(tier, on)
    local allowed, why = may_set_perms()
    if not allowed then return false, why end
    if perms.OPTIONAL_TIERS[tier] ~= true then
        return false, "That rung is on every ladder - it cannot be switched off."
    end
    on = (on == true)

    if not on then
        local left = 0
        for other, _ in pairs(perms.OPTIONAL_TIERS) do
            if other ~= tier and perms.tier_in_use(other) then left = left + 1 end
        end
        if left == 0 then
            return false, "Keep one rung between joining and the host."
        end
    end
    if not OF.util.store_integer(
        RUNG_PREFIX .. perms.tier_info(tier).key, on and 1 or 0) then
        return false, "The save file would not take that - nothing changed."
    end
    perms.publish()
    return true
end

function perms.reset_rungs()
    local allowed, why = may_set_perms()
    if not allowed then return false, why end
    for _, tier in ipairs(OF.TIER_ORDER) do
        local key = perms.tier_info(tier).key
        mod_storage_remove(TIER_NAME_PREFIX .. key)
        mod_storage_remove(RUNG_PREFIX .. key)
    end
    perms.publish()
    return true
end

local MIGRATED_KEY = "permmigrate"
local MIGRATION = 2
perms.MIGRATED_KEY = MIGRATED_KEY
perms.MIGRATION = MIGRATION

local ABSENT = -99

local function drop_round_values()
    for _, group in ipairs(perms.GROUPS) do
        mod_storage_remove(ROUND_PREFIX .. group.key)
    end
    for _, key in ipairs(perms.OLD_GROUP_KEYS) do
        mod_storage_remove(ROUND_PREFIX .. key)
    end
    mod_storage_remove(ROUND_PREFIX .. "unfiled")
end

function perms.migrate()
    if not OF.util.is_host() then return false end
    local done = mod_storage_load_integer(MIGRATED_KEY, 0)
    if done >= MIGRATION then return false end

    if done >= 1 then
        drop_round_values()
        OF.util.store_integer(MIGRATED_KEY, MIGRATION)
        return true
    end

    mod_storage_remove(PERM_PREFIX .. "pact")

    for feature, _ in pairs(perms.DEFAULTS) do
        local raw = mod_storage_load_integer(PERM_PREFIX .. feature, -1)
        if OF.TIER_ALIAS[raw] ~= nil then
            OF.util.store_integer(PERM_PREFIX .. feature, OF.TIER_ALIAS[raw])
        end
    end

    for _, prefix in ipairs({ TIER_NAME_PREFIX, RUNG_PREFIX }) do
        local was = mod_storage_load_integer(prefix .. "vip", ABSENT)
        if was ~= ABSENT and mod_storage_load_integer(prefix .. "crew", ABSENT) == ABSENT then
            OF.util.store_integer(prefix .. "crew", was)
        end
        mod_storage_remove(prefix .. "vip")
        mod_storage_remove(prefix .. "trusted")
    end

    if OF.util.asks(OF.ranks, "remembered") then OF.ranks.remembered() end

    for feature, source in pairs(perms.CARVED_FROM) do
        local own = stored_required(feature)
        local old = stored_required(source)
        if own == nil and old ~= nil and old ~= perms.DEFAULTS[feature] then
            OF.util.store_integer(PERM_PREFIX .. feature, old)
        end
    end

    drop_round_values()

    OF.util.store_integer(MIGRATED_KEY, MIGRATION)
    return true
end

local function on_the_ladder(tier)
    return perms.nearest_in_use(perms.canon(tier) or OF.TIER.NORMAL, -1)
end

function perms.tier(localIndex)
    if localIndex == nil then return OF.TIER.NORMAL end

    if network_is_server() then
        if OF.util.asks(OF.util, "is_host_player") and OF.util.is_host_player(localIndex) then
            return OF.TIER.HOST
        end
        if OF.util.asks(OF.ranks, "published") then
            return on_the_ladder(OF.ranks.published[localIndex]
                or OF.TIER.NORMAL)
        end
        return OF.TIER.NORMAL
    end

    local s = gPlayerSyncTable[localIndex]
    if s == nil or s.ofTier == nil then

        if localIndex == 0 and network_is_server() then return OF.TIER.HOST end
        return OF.TIER.NORMAL
    end
    return on_the_ladder(s.ofTier)
end

function perms.my_tier()
    if network_is_server() then return OF.TIER.HOST end
    return perms.tier(0)
end

function perms.can(feature)
    return perms.my_tier() >= perms.required(feature)
end

function perms.is_cohost(localIndex)
    return perms.tier(localIndex or 0) >= OF.TIER.COHOST
end

function perms.is_muted_rank(localIndex)
    localIndex = localIndex or 0
    local raw
    if network_is_server() then
        local ranks = OF.ranks
        raw = ranks ~= nil and type(ranks.published) == "table" and ranks.published[localIndex] or nil
    else
        local row = gPlayerSyncTable[localIndex]
        raw = row ~= nil and row.ofTier or nil
    end
    if raw == nil then return false end

    local tier = perms.canon(raw)
    if tier ~= OF.TIER.MUTED and perms.tier_position(tier) ~= nil then return false end
    return perms.tier(localIndex) <= OF.TIER.MUTED
end

function perms.tier_info(tier)
    tier = perms.canon(tier)
    return OF.TIER_INFO[tier] or OF.TIER_INFO[OF.TIER.NORMAL]
end

function perms.tier_in_use(tier)
    if perms.OPTIONAL_TIERS[tier] ~= true then return true end
    overrides()
    if rungCache == nil then return true end
    local at = tier_position(tier)
    if at == nil then return true end
    return string.sub(rungCache, at, at) ~= "0"
end

function perms.tiers_in_use()
    local list = {}
    for _, tier in ipairs(OF.TIER_ORDER) do
        if perms.tier_in_use(tier) then list[#list + 1] = tier end
    end
    return list
end

function perms.nearest_in_use(tier, direction)
    if perms.tier_in_use(tier) then return tier end
    local at = tier_position(tier)
    if at == nil then return tier end
    local step = (direction or 1) >= 0 and 1 or -1
    local i = at + step
    while OF.TIER_ORDER[i] ~= nil do
        if perms.tier_in_use(OF.TIER_ORDER[i]) then return OF.TIER_ORDER[i] end
        i = i + step
    end

    i = at - step
    while OF.TIER_ORDER[i] ~= nil do
        if perms.tier_in_use(OF.TIER_ORDER[i]) then return OF.TIER_ORDER[i] end
        i = i - step
    end
    return tier
end

function perms.tier_name_index(tier)
    local ring = perms.TIER_NAMES[tier]
    if ring == nil then return 1 end
    overrides()
    if nameCache == nil then return 1 end
    local at = tier_position(tier)
    if at == nil then return 1 end
    local pick = tonumber(string.sub(nameCache, at, at))
    if pick == nil or pick < 1 or pick > #ring then return 1 end
    return pick
end

function perms.tier_label(tier)
    tier = perms.canon(tier)
    local ring = perms.TIER_NAMES[tier]
    if ring ~= nil then
        local pick = ring[perms.tier_name_index(tier)]

        if pick ~= nil then return pick end
    end
    return perms.tier_info(tier).label
end

function perms.tier_from_word(word)
    word = string.lower(tostring(word or ""))
    if word == "" then return nil end
    for _, tier in ipairs(OF.TIER_ORDER) do
        if perms.tier_info(tier).key == word or perms.tier_name(tier) == word then
            return tier
        end
    end
    return nil
end

function perms.tier_name(tier)
    local label = perms.tier_label(tier)
    if label == "" then return "normal" end
    return string.lower(label)
end

function perms.tier_color(tier)
    local info = perms.tier_info(tier)
    return info.r, info.g, info.b
end

function perms.tier_opens(tier, limit)
    limit = limit or 3
    local named, extra = {}, 0
    for _, feature in ipairs(perms.ORDER) do
        if perms.required(feature) == tier and not perms.FIXED[feature] then
            if #named < limit then
                local label = OF.lang.t(perms.LABELS[feature] or feature)
                table.insert(named, string.lower(string.sub(label, 1, 1))
                    .. string.sub(label, 2))
            else
                extra = extra + 1
            end
        end
    end
    if #named == 0 then return nil end
    local text = table.concat(named, ", ")
    if extra > 0 then text = text .. OF.lang.t(", and more") end
    return text
end

function perms.ladder()
    local rungs = {}
    for _, tier in ipairs(OF.TIER_ORDER) do
        local adds = {}
        for _, feature in ipairs(perms.ORDER) do
            if perms.required(feature) == tier then
                table.insert(adds, {
                    feature = feature,
                    label = OF.lang.t(perms.LABELS[feature] or feature),
                    fixed = perms.FIXED[feature] == true,
                    hostOnly = perms.needs_host(feature),
                    opens = perms.IMPLIES[feature],
                })
            end
        end
        table.insert(rungs, {
            tier = tier,
            name = perms.tier_name(tier),
            label = perms.tier_label(tier),

            inUse = perms.tier_in_use(tier),
            adds = adds,
        })
    end
    return rungs
end

function perms.step_tier(tier, direction)
    local index = 1
    for i, value in ipairs(OF.TIER_ORDER) do
        if value == tier then index = i end
    end
    if direction == 0 then return OF.TIER_ORDER[index] end
    local step = (direction or 1) >= 0 and 1 or -1
    local at = index + step
    while OF.TIER_ORDER[at] ~= nil do
        if perms.tier_in_use(OF.TIER_ORDER[at]) then return OF.TIER_ORDER[at] end
        at = at + step
    end
    return OF.TIER_ORDER[OF.util.clamp(index, 1, #OF.TIER_ORDER)]
end

local SHIELD_PREFIX = "permshield_"
function perms.stored_shield(playerId)
    if playerId == nil then return nil end
    local stored = perms.canon(mod_storage_load_integer(
        OF.util.storage_key(SHIELD_PREFIX, playerId), -1))
    if stored < 0 then return nil end
    if tier_position(stored) == nil then return nil end
    return stored
end

function perms.shield(localIndex)
    local tier = perms.tier(localIndex)
    if localIndex == nil then return tier end
    if not OF.util.is_host() then return tier end

    if OF.util.is_host_player(localIndex) then return tier end
    local stored = perms.stored_shield(OF.util.player_id(localIndex))
    if stored == nil then return tier end
    return perms.nearest_in_use(stored, -1)
end

function perms.is_shielded(localIndex)
    if localIndex == nil then return false end
    if not OF.util.is_host() then return false end
    return perms.stored_shield(OF.util.player_id(localIndex)) ~= nil
end

function perms.set_shield(localIndex, tier)
    if not perms.can("ranks") then
        return false, "Your rank cannot do that.", "ranks"
    end
    if not OF.util.is_host() then
        return false, "Only the host may change who is protected."
    end
    if OF.util.is_host_player(localIndex) then
        return false, "The host is already out of everybody's reach."
    end
    local id = OF.util.player_id(localIndex)
    if id == nil then return false, "They have left the lobby." end

    if tier == nil or tier == perms.tier(localIndex) then
        mod_storage_remove(OF.util.storage_key(SHIELD_PREFIX, id))
        return true
    end
    if tier_position(tier) == nil then return false, "That is not a rung." end
    if not OF.util.store_integer(
        OF.util.storage_key(SHIELD_PREFIX, id), tier) then
        return false, "The save file would not take that - nothing changed."
    end
    return true
end

function perms.cycle_shield(localIndex, direction)
    local own = perms.tier(localIndex)
    local ring = { own }
    for _, tier in ipairs(perms.tiers_in_use()) do
        if tier > own then ring[#ring + 1] = tier end
    end
    local now = perms.shield(localIndex)
    local at = 1
    for i, value in ipairs(ring) do
        if value == now then at = i end
    end
    if (direction or 1) < 0 then
        if at <= 1 then
            return false, "They are already behind nothing but their own rank."
        end
        return perms.set_shield(localIndex, ring[at - 1])
    end
    return perms.set_shield(localIndex, ring[(at % #ring) + 1])
end

function perms.shielded_ids()
    local ids = {}
    if not OF.util.is_host() then return ids end
    local all = mod_storage_load_all()
    if all == nil then return ids end
    for key, _ in pairs(all) do
        if string.sub(key, 1, #SHIELD_PREFIX) == SHIELD_PREFIX then
            ids[#ids + 1] = OF.util.storage_unescape(
                string.sub(key, #SHIELD_PREFIX + 1))
        end
    end

    table.sort(ids)
    return ids
end

local shieldMemo = {}

function perms.shielded_count()
    return OF.util.stored_count(shieldMemo, perms.shielded_ids)
end

function perms.lift_all_shields()
    if not perms.can("ranks") then
        return false, "Your rank cannot do that.", "ranks"
    end
    if not OF.util.is_host() then
        return false, "Only the host may change who is protected."
    end
    local lifted = 0
    for _, id in ipairs(perms.shielded_ids()) do
        mod_storage_remove(OF.util.storage_key(SHIELD_PREFIX, id))
        lifted = lifted + 1
    end
    return true, lifted
end

function perms.rank_view(tier)
    local may, mayNot = {}, {}
    for _, group in ipairs(perms.grouped_order()) do
        for _, feature in ipairs(group.features) do
            local needs = perms.required(feature)
            local entry = { feature = feature, needs = needs }
            if tier ~= nil and tier >= needs then
                may[#may + 1] = entry
            else
                mayNot[#mayNot + 1] = entry
            end
        end
    end
    return may, mayNot
end

function perms.step_rank_view(now, direction)
    local ring = { false }
    for _, tier in ipairs(perms.tiers_in_use()) do ring[#ring + 1] = tier end
    local at = 1
    for i, value in ipairs(ring) do
        if value == (now or false) then at = i end
    end
    local step = (direction or 1) >= 0 and 1 or -1
    local nextValue = ring[((at - 1 + step) % #ring) + 1]
    if nextValue == false then return nil end
    return nextValue
end

function perms.build_ladder_page(panel)
    local rows = {}

    local viewing = panel.permRankView
    if viewing ~= nil and not perms.tier_in_use(viewing) then viewing = nil end
    local picker = panel.gated_row("permissions", OF.lang.t("What can this rank do?"),
        255, 255, 255,
        function() panel.permRankView = perms.step_rank_view(panel.permRankView, 1) end)
    if picker.action ~= nil then
        picker.altAction = function()
            panel.permRankView = perms.step_rank_view(panel.permRankView, -1)
        end
        picker.altPad = true
        picker.altLabel = "back"
    end
    picker = panel.with_right(picker, viewing ~= nil
        and string.upper(OF.lang.t(perms.tier_name(viewing))) or OF.lang.t("every rung"))
    if viewing ~= nil then
        local r, g, b = perms.tier_color(viewing)
        picker.rightInk = { r, g, b }
    end
    rows[#rows + 1] = panel.with_help(picker,
        OF.lang.t("pick a rank to see all it may and may not do; read-only"))

    if viewing ~= nil then
        local may, mayNot = perms.rank_view(viewing)
        local function line(entry, word)
            local built = panel.with_right(panel.label_row(
                OF.lang.t(perms.LABELS[entry.feature] or entry.feature), 235, 235, 235),
                OF.lang.fill(word, OF.lang.t(perms.tier_name(entry.needs))))
            built.walk = true
            local r, g, b = perms.tier_color(entry.needs)
            built.rightInk = { r, g, b }
            return panel.with_help(built, perms.COVERS[entry.feature])
        end
        rows[#rows + 1] = panel.with_help(panel.header_row(OF.lang.fill("It may (@)",
            tostring(#may))), OF.lang.t("everything this rank reaches in this lobby"))
        for _, entry in ipairs(may) do rows[#rows + 1] = line(entry, "@ and up") end
        rows[#rows + 1] = panel.with_help(panel.header_row(OF.lang.fill("It may not (@)",
            tostring(#mayNot))), OF.lang.t("and the rank each of these waits for"))
        for _, entry in ipairs(mayNot) do rows[#rows + 1] = line(entry, "needs @") end
        rows[#rows + 1] = panel.back_row()
        return rows
    end

    rows[#rows + 1] = panel.with_help(panel.label_row(OF.lang.t(
        "A rank may do everything the ranks below it may. This is what each one adds.")),
        OF.lang.t("read down, and each rung is what that rank adds to the one under it"))

    for _, rung in ipairs(perms.ladder()) do
        rows[#rows + 1] = panel.header_row(
            string.upper(OF.lang.t(perms.tier_name(rung.tier))))

        if not rung.inUse then
            rows[#rows + 1] = panel.with_help(panel.label_row(OF.lang.t(
                "This lobby does not use this rung.")),
                OF.lang.t("switched off on the rungs page, so nothing sits here"))
        elseif #rung.adds == 0 then
            rows[#rows + 1] = panel.with_help(panel.label_row(OF.lang.t(
                "Nothing of its own - it inherits the rung below.")),
                OF.lang.t("a step on the ladder that opens nothing new in this lobby"))
        else
            for _, add in ipairs(rung.adds) do

                local note = ""
                if add.fixed then
                    note = OF.lang.t("the way in")
                elseif add.hostOnly then
                    note = OF.lang.t("host only")
                elseif add.opens ~= nil and add.opens[1] ~= nil then

                    local carried = OF.lang.t(
                        perms.LABELS[add.opens[1]] or add.opens[1])
                    note = OF.lang.fill("also @",
                        string.lower(string.sub(carried, 1, 1))
                            .. string.sub(carried, 2))
                end
                local built = panel.with_right(
                    panel.label_row(add.label, 235, 235, 235), note)
                built.walk = true
                rows[#rows + 1] = panel.with_help(built,
                    perms.COVERS[add.feature])
            end
        end
    end

    rows[#rows + 1] = panel.back_row()
    return rows
end

function perms.build_rungs_page(panel)
    local rows = {}
    rows[#rows + 1] = panel.with_help(panel.label_row(OF.lang.t(
        "Six rungs as this build ships. Both halves are yours to change.")),
        OF.lang.t("how many ranks this lobby has, and what the lobby calls each of them"))

    rows[#rows + 1] = panel.with_help(panel.gated_confirm_row("permissions",
        "resetrungs", OF.lang.t("Reset this page"),
        255, 140, 90, function()
            OF.util.report(perms.reset_rungs())
        end),
        OF.lang.t("six rungs again, each under the name this build gives it"))

    rows[#rows + 1] = panel.header_row(OF.lang.t("Which rungs this lobby has"))
    for _, tier in ipairs(OF.TIER_ORDER) do
        local on = perms.tier_in_use(tier)
        local optional = perms.OPTIONAL_TIERS[tier] == true
        local text = panel.tick(on, OF.lang.t(perms.RUNG_ID[tier]))
        local built
        if optional then
            built = panel.gated_row("permissions", text, 255, 255, 255,
                function()
                    OF.util.report(perms.set_tier_in_use(tier, not on))
                end)
        else

            built = panel.label_row(text)
        end
        built = panel.level_right(built, on,
            string.upper(OF.lang.t(perms.tier_name(tier))))
        rows[#rows + 1] = panel.with_help(built, optional
            and OF.lang.t("switch it off and everything on it moves to the rung above")
            or OF.lang.t("every ladder has this one - it cannot be switched off"))
    end

    rows[#rows + 1] = panel.header_row(OF.lang.t("What each rung is called"))
    for _, tier in ipairs(OF.TIER_ORDER) do
        local ring = perms.TIER_NAMES[tier] or {}
        local shown = perms.tier_label(tier)
        if shown == "" then shown = OF.lang.t("no tag") end
        rows[#rows + 1] = panel.with_help(panel.with_right(
            panel.gated_row("permissions",
                OF.lang.fill("What @ is called",
                    string.lower(OF.lang.t(perms.RUNG_ID[tier]))),
                255, 255, 255, function()
                    OF.util.report(perms.cycle_tier_name(tier))
                end),
            shown),
            OF.lang.fill("one of @ this lobby can call it, everywhere the rank is drawn",
                tostring(#ring)))
    end

    rows[#rows + 1] = panel.back_row()
    return rows
end

function perms.build_shields_page(panel)
    local rows = {}

    local shieldLead = panel.with_help(panel.label_row(OF.lang.t(
        "Rank says what somebody may do. This says what may be done to them.")),
        OF.lang.t("press a name to put them out of a moderator's reach; Z brings them back"))
    shieldLead.walk = true
    rows[#rows + 1] = shieldLead

    rows[#rows + 1] = panel.with_help(
        panel.header_row(OF.lang.t("Everybody here")),
        OF.lang.t("the lobby as it stands, and who a moderator may not act on"))

    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local own = perms.tier(li)
        local shield = perms.shield(li)
        local name = tostring(entry.np ~= nil and entry.np.name or li)
        if OF.util.is_host_player(li) then

            rows[#rows + 1] = panel.with_help(panel.with_right(
                panel.label_row(name),
                OF.lang.t("out of reach")),
                OF.lang.t("the host is not somebody anybody in the lobby can act on"))
        else

            local built = panel.host_row("ranks",
                panel.tick(shield ~= own, name), 255, 255, 255,
                function()
                    OF.util.report(perms.cycle_shield(li, 1))
                end)
            if built.action ~= nil then
                built.altAction = function()
                    OF.util.report(perms.cycle_shield(li, -1))
                end
                built.altPad = true
                built.altLabel = "back"
            end

            built = panel.level_right(built, shield ~= own,
                OF.lang.t(perms.tier_name(shield)))
            rows[#rows + 1] = panel.with_help(built, shield ~= own
                and OF.lang.fill("only somebody above the rung on the right can act on @", name)
                or OF.lang.fill("@ can be acted on by anybody who outranks them, which is the ladder as it stands", name))
        end
    end

    rows[#rows + 1] = panel.with_help(
        panel.header_row(OF.lang.t("The host's own record")),
        OF.lang.t("protections outlive a session, so this is where the ones nobody is standing in show up"))
    local liftText = OF.lang.fill("Put everybody back behind their own rank (@)",
        tostring(perms.shielded_count()))
    local function lift()
        local ok, lifted = perms.lift_all_shields()
        OF.util.report(ok, lifted)
    end
    rows[#rows + 1] = panel.with_help(OF.util.is_host()
        and panel.gated_confirm_row("ranks", "liftshields", liftText, 255, 140, 90, lift)
        or panel.host_row("ranks", liftText, 255, 140, 90, lift),
        OF.lang.t("every protection this lobby is holding, including players who have gone home"))

    rows[#rows + 1] = panel.back_row()
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()

    perms.migrate()
    perms.publish()
end)
