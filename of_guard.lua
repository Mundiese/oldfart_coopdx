OF = OF or {}
OF.guard = OF.guard or {}

local guard = OF.guard

guard.truth = guard.truth or {}

guard.owned = guard.owned or {}

function guard.remember(key, value)
    guard.truth[key] = value
    guard.owned[key] = true
end

guard.repairs = guard.repairs or 0
local sinceTold = 0
local TELL_EVERY = 30 * 20

local puttingBack = 0

function guard.putting_back()
    return puttingBack > 0
end

local function put_back(key, value)
    puttingBack = puttingBack + 1
    gGlobalSyncTable[key] = value
    puttingBack = puttingBack - 1
end

local function empty_as_nil(value)
    if value == "" then return nil end
    return value
end

function guard.repair(key)
    if not OF.util.is_host() then return false end

    if not guard.owned[key] then return false end
    local wanted = guard.truth[key]
    if gGlobalSyncTable[key] == wanted then return false end

    local was = gGlobalSyncTable[key]
    put_back(key, empty_as_nil(wanted))
    if OF.wireWatch then OF.note_sync(key, was ~= empty_as_nil(wanted)) end
    guard.repairs = guard.repairs + 1

    guard.note(tostring(key))

    return true
end

function guard.tell(message, notice, seconds)
    if sinceTold > 0 then return false end
    sinceTold = TELL_EVERY
    OF.util.chat("\\#ff6060\\" .. message)
    OF.notify.show(notice, "bad", seconds or 6)
    return true
end

local KINDS_MOST = 12

guard.forgeries = guard.forgeries or {}
guard.ledgerCount = guard.ledgerCount or 0

guard.together = guard.together

local kinds = 0

local LOUD_AT = { 10, 100, 1000 }

local toldWitnesses = nil

local function others_here()
    local here = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 then
            local id = OF.util.player_id(entry.localIndex)
            if id ~= nil then here[id] = OF.util.plain(entry.np.name) end
        end
    end
    return here
end

local function say_the_room()
    if not OF.util.asks(OF.chatlog, "add_system") then return end
    local names = guard.witnesses()
    local line = #names > 0 and table.concat(names, ", ") or ""
    if line == toldWitnesses then return end
    toldWitnesses = line
    if #names == 0 then
        OF.chatlog.add_system(OF.lang.t(
            "nobody has been here for every forgery - somebody left, or it is more than one machine"))
        return
    end
    OF.chatlog.add_system(OF.lang.fill(
        "in the lobby for every forgery so far: @", line))
end

function guard.note(what)
    if what == nil or what == "" then return false end
    guard.ledgerCount = guard.ledgerCount + 1

    local here = others_here()
    if guard.together == nil then
        guard.together = here
    else

        local kept = {}
        for id, _ in pairs(guard.together) do
            if here[id] ~= nil then kept[id] = here[id] end
        end
        guard.together = kept
    end

    local count = (guard.forgeries[what] or 0) + 1
    guard.forgeries[what] = count

    if count == 1 and kinds < KINDS_MOST
        and OF.util.asks(OF.chatlog, "add_system") then
        kinds = kinds + 1
        OF.chatlog.add_system(OF.lang.fill("put back a forgery: @", what))
    elseif OF.util.asks(OF.chatlog, "add_system") then
        for _, at in ipairs(LOUD_AT) do
            if count == at then
                OF.chatlog.add_system(OF.lang.fill("put back @ - @ times now",
                    what, tostring(count)))
            end
        end
    end

    say_the_room()
    return true
end
function guard.forget_forged()
    guard.forgeries = {}
    guard.ledgerCount = 0
    guard.together = nil
    kinds = 0
    toldWitnesses = nil
    return true
end

function guard.witnesses()
    local names = {}
    for _, name in pairs(guard.together or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function guard.watch(key)
    hook_on_sync_table_change(gGlobalSyncTable, key, key, function()
        guard.repair(key)
    end)
end

hook_event(HOOK_UPDATE, function()
    if sinceTold > 0 then sinceTold = sinceTold - 1 end
end)

function guard.forget_report()
    sinceTold = 0
end

function guard.quiet_for()
    return sinceTold
end

hook_event(HOOK_ON_LEVEL_INIT, function() guard.forget_report() end)

guard.GUARDED = {
    "ofPerms",

    "ofPerms2", "ofPerms3", "ofPerms4", "ofPerms5", "ofPerms6",
    "ofFilter",

    "ofOffLimits",

    "ofBoard", "ofBoardTonight", "ofBoardBest", "ofBoardHere",

    "ofBoard2", "ofBoardTonight2",

    "ofBoardHere2", "ofBoardHere3", "ofBoardHere4",

    "ofAwards", "ofModeBest",
    "ofGmKey", "ofGmWinner", "ofQueueNext",

    "ofGmOpts",

    "ofSimonOff",
    "ofArenaPlace", "ofMessage", "ofNight", "ofRunStars",

    "ofShow", "ofShape",
    "ofUndoWarp",

    "ofDoors",
    "ofCourseFloor",

    "ofArenaEnemies", "ofArenaHazards",

    "ofArenaSweep",
    "ofGmLimit",

    "ofGmSecs",

    "ofGmNonstop", "ofGmNextIn",
    "ofHillLevel", "ofHillArea", "ofHillX", "ofHillY", "ofHillZ",
    "ofHillTarget",
    "ofChaos", "ofChaosNext",
    "ofChaosStunt",
    "ofChaosWild",

    "ofRoomCostume",
    "ofRoomHats",

    "ofRoomPowers",
    "ofLearn",

    "ofCrownTarget",
    "ofCrownStreak",

    "ofMhRunner",
    "ofLavaFront",
    "ofShuffleSeed",

    "ofSign",

    "ofSignPosts", "ofSignPosts2", "ofSignPostsOn",

    "ofSignSaid", "ofSignSaid2",

    "ofWelcome",

    "ofHouse",
    "ofFloodAt", "ofFloodLevel", "ofFloodArea",

    "ofHexAt", "ofHexLevel", "ofHexArea", "ofHexGone",

    "ofHeatAt", "ofHeatLevel", "ofHeatArea", "ofHeatCall",

    "ofRollAt", "ofRollLevel", "ofRollArea",

    "ofCtfRedS", "ofCtfBlueS", "ofCtfTarget",
    "ofCtfLevel", "ofCtfArea",
    "ofCtfRedBase", "ofCtfBlueBase", "ofCtfRedDrop", "ofCtfBlueDrop",

    "ofBankAt", "ofBankLevel", "ofBankArea",

    "ofSumoAt", "ofSumoLevel", "ofSumoArea", "ofSumoR",

    "ofSumoTarget",

    "ofTrialHome",

    "ofBountyTarget",

    "ofRushTarget",

    "ofSpotsAt", "ofSpotsAt2", "ofSpotsAt3", "ofSpotsAt4",
    "ofSpotsLevel", "ofSpotsArea", "ofSpotsGrab", "ofSpotsRound",
    "ofHpFuse", "ofHpRound", "ofHpStartFuse",

    "ofHpBlown",
    "ofQueueOn", "ofQueueLeft",

    "ofQueueLoop",

    "ofPlaylist",

    "ofRunLevel", "ofRunAct", "ofRunMode", "ofRunTitle",

    "ofRunRecord",

    "ofDomAt", "ofDomLevel", "ofDomArea", "ofDomCap",
    "ofDomRed", "ofDomBlue", "ofDomTarget",

    "ofDomLost",
    "ofTeamsOn", "ofTeamRound",
    "ofVoteWait",

    "ofCourseOrder",

    "ofRoundMusic",

    "ofReins",

    "ofTogether", "ofRopeLen",

    "ofRopeBite", "ofToss",

    "ofWarp",

    "ofStandings",
}

guard.GUARDED_SET = {}
for _, key in ipairs(guard.GUARDED) do guard.GUARDED_SET[key] = true end

guard.DELEGATED = {
    ofRules = true, ofMods = true, ofVote = true, ofClearNow = true,

    ofRules2 = true, ofRules3 = true, ofRules4 = true,
    ofMods2 = true, ofMods3 = true, ofMods4 = true,

    ofRoundMods = true,

    ofRoundRules = true,

    ofRoomCheats = true, ofRoomCheats2 = true, ofRoomCheats3 = true,
    ofRoomCheats4 = true, ofRoomCheats5 = true,

    ofWhoDid = true,

    ofGmState = true, ofGmElapsed = true, ofGmCount = true,

    ofGmPlace = true,

    ofCtfRed = true, ofCtfBlue = true,

    ofLineLight = true, ofSimonCall = true,
    ofArenaClear = true,
    ofHpHolder = true, ofHpBoom = true,

    ofCrown = true,
    ofMusic = true, ofRunState = true,

    ofRunElapsed = true,

    ofVision = true,

    ofLock = true,

    ofMusicVol = true,

    ofBingoSeed = true,

    ofBingoMode = true,

    ofEnemy = true,

    ofMove = true,

    ofHarsh = true,
}

for _, key in ipairs(guard.GUARDED) do guard.watch(key) end

function guard.begin(key)
    return guard.GUARDED_SET[key] == true
end

function guard.report()
    return guard.repairs
end

guard.MY_ROW = {
    { key = "ofMuted",  wanted = false },
    { key = "ofJailed", wanted = nil },
}

local function same(a, b)
    if a == nil or a == false or a == "" then return b == nil or b == false or b == "" end
    return a == b
end

guard.MINE = {
    { key = "ofSpectating", start = false },
    { key = "ofIdle",       start = false },

    { key = "ofScale",      start = nil },
    { key = "ofCheats",     start = nil },

    { key = "ofUnseen",     start = nil },
    { key = "ofForgeSize",  start = nil },

    { key = "ofForgeReach", start = nil },

    { key = "ofForgeMoved", start = nil },
    { key = "ofHsFresh",    start = nil },
    { key = "ofHsFrozen",   start = nil },
    { key = "ofStill",      start = nil },
    { key = "ofBingoMarks", start = nil },
    { key = "ofPresses",    start = nil },

    { key = "ofDoorMine",   start = nil },

    { key = "ofScore",      start = 0 },
    { key = "ofGmTime",     start = 0 },
    { key = "ofHpGrab",     start = 0 },

    { key = "ofSpotsClaim", start = 0 },

    { key = "ofRollAim",    start = 0 },

    { key = "ofBankHeld",   start = 0 },

    { key = "ofBountyAt",   start = "" },
    { key = "ofBountyTo",   start = -1 },
    { key = "ofBountySeq",  start = 0 },

    { key = "ofSplits",     start = "" },

    { key = "ofHold",       start = nil },

    { key = "ofPerch",      start = nil },

    { key = "ofWorn",       start = nil },

    { key = "ofRunTime",    start = 0 },

    { key = "ofRunGot",     start = 0 },
    { key = "ofVoted",      start = "" },
    { key = "ofNoRace",     start = false },

    { key = "ofCrownTo",    start = nil },
    { key = "ofCrownGave",  start = 0 },

    { key = "ofCrownDied",  start = 0 },

    { key = "ofCostume",    start = "" },

    { key = "ofHat",        start = "" },

    { key = "ofFacing",     start = false },

    { key = "ofMyShape",    start = "" },

    { key = "ofPossess",    start = "" },

    { key = "ofEmote",      start = 0 },

    { key = "ofTicks",      start = "" },

    { key = "ofMhDied",     start = 0 },
}

guard.ROW_OWNER = {
    ofSpectating = "mine",
    ofIdle       = "mine",
    ofScale      = "mine",
    ofCheats     = "mine",
    ofUnseen     = "mine",
    ofForgeSize  = "mine",

    ofForgeReach = "mine",

    ofForgeMoved = "mine",
    ofHsFresh    = "mine",

    ofMhDied     = "mine",

    ofHsFrozen   = "mine",
    ofStill      = "mine",
    ofBingoMarks = "mine",
    ofPresses    = "mine",

    ofDoorMine   = "mine",

    ofMuted      = "host",
    ofJailed     = "host",
    ofTier       = "host",
    ofRole       = "host",
    ofTeam       = "host",

    ofRope       = "host",
    ofBond       = "host",

    ofScore      = "mine",
    ofGmTime     = "mine",

    ofSpotsClaim = "mine",

    ofRollAim    = "mine",

    ofBankHeld   = "mine",

    ofBountyAt   = "mine",
    ofBountyTo   = "mine",
    ofBountySeq  = "mine",
    ofHpGrab     = "mine",
    ofSplits     = "mine",

    ofRunTime    = "mine",

    ofRunGot     = "mine",
    ofVoted      = "mine",
    ofNoRace     = "mine",

    ofCrownTo    = "mine",
    ofCrownGave  = "mine",

    ofCrownDied  = "mine",

    ofCostume    = "mine",

    ofFacing     = "mine",

    ofMyShape    = "mine",

    ofHat        = "mine",

    ofPossess    = "mine",

    ofEmote      = "mine",

    ofHold       = "mine",

    ofPerch      = "mine",

    ofWorn       = "mine",

    ofTicks      = "mine",
}

guard.mine = guard.mine or {}
guard.mineRepairs = guard.mineRepairs or 0

guard.MINE_KEYS = {}
for _, entry in ipairs(guard.MINE) do
    guard.MINE_KEYS[entry.key] = true
    if guard.mine[entry.key] == nil then guard.mine[entry.key] = entry.start end
end

function guard.remember_mine(key, value)
    if not guard.MINE_KEYS[key] then return false end
    guard.mine[key] = value
    return true
end

function guard.repair_mine(key)
    if not guard.MINE_KEYS[key] then return false end

    local wanted = guard.mine[key]
    local row = gPlayerSyncTable[0]
    if row == nil then return false end
    if same(row[key], wanted) then return false end

    row[key] = empty_as_nil(wanted)
    guard.mineRepairs = guard.mineRepairs + 1

    guard.note(OF.lang.fill("@ in your own row", tostring(key)))

    guard.tell(OF.lang.t(
        "Somebody is writing to your player. Put back. /kick removes them."),
        "Somebody is writing to your player", 8)
    return true
end

function guard.mine_report()
    return guard.mineRepairs
end

for _, key in ipairs({ "ofIdle", "ofScale", "ofUnseen", "ofCheats", "ofForgeSize",
                       "ofForgeReach", "ofForgeMoved",
                       "ofHsFresh", "ofHsFrozen",
                       "ofStill", "ofBingoMarks", "ofPresses",
                       "ofScore", "ofGmTime", "ofHpGrab",
                       "ofSplits", "ofRunTime", "ofRunGot", "ofVoted",

                       "ofSpotsClaim", "ofBankHeld",

                       "ofRollAim",
                       "ofBountyAt", "ofBountyTo", "ofBountySeq",
                       "ofCrownTo", "ofCrownGave",

                       "ofCostume", "ofHat", "ofPossess", "ofEmote",

                       "ofHold", "ofPerch", "ofWorn",

                       "ofDoorMine",

                       "ofTicks",
                       "ofFacing" }) do
    hook_on_sync_table_change(gPlayerSyncTable[0], key, 0, function()
        guard.repair_mine(key)
    end)
end

hook_on_sync_table_change(gPlayerSyncTable[0], "ofCrownDied", 0, function()
    guard.repair_mine("ofCrownDied")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofMhDied", 0, function()
    guard.repair_mine("ofMhDied")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofMyShape", 0, function()
    guard.repair_mine("ofMyShape")
end)

guard.rowRepairs = guard.rowRepairs or 0

function guard.repair_my_row(key)
    if not OF.util.is_host() then return false end

    local entry
    for _, item in ipairs(guard.MY_ROW) do
        if item.key == key then entry = item end
    end
    if entry == nil then return false end

    local row = gPlayerSyncTable[0]
    if row == nil then return false end
    if same(row[key], entry.wanted) then return false end

    row[key] = entry.wanted
    guard.rowRepairs = guard.rowRepairs + 1

    guard.note(OF.lang.fill("@ in the host's own row", tostring(key)))

    guard.tell(OF.lang.t(
        "Somebody tried to mute or jail the host. Put back. /kick removes them."),
        "Somebody is aiming at the host", 8)
    return true
end

function guard.row_report()
    return guard.rowRepairs
end
