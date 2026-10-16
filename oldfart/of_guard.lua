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
    OF.util.chat(message, "warn")
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

    "ofOfFlag", "ofOfDrop", "ofOfHome", "ofOfBase", "ofOfLevel", "ofOfArea",
    "ofOfRed", "ofOfBlue", "ofOfTarget",

    "ofPerms",

    "ofPerms2", "ofPerms3", "ofPerms4", "ofPerms5", "ofPerms6", "ofPerms7",
    "ofPerms8",
    "ofFilter",

    "ofBoardTonight", "ofBoardTonight2",
    "ofGmKey", "ofGmWinner", "ofQueueNext",

    "ofGmOpts",

    "ofSimonOff",

    "ofSimonSeq",

    "ofFzStep", "ofFzAt", "ofFzJudge", "ofFzOff",
    "ofArenaPlace", "ofMessage", "ofNight", "ofRunStars",

    "ofShow", "ofShape",
    "ofUndoWarp",

    "ofDoors",
    "ofCourseFloor",

    "ofArenaEnemies", "ofArenaHazards",

    "ofArenaSweep",
    "ofGmLimit",
    "ofGmSeed",

    "ofGmSecs",

    "ofGmFinal", "ofGmFinal2",

    "ofGmNonstop", "ofGmNextIn",

    "ofGmBlastTurn", "ofGmBlastLeft", "ofGmBlastTimer",
    "ofGmBlastCycle", "ofGmBlastCount",

    "ofGmBlastRow", "ofGmBlastUsed", "ofGmBlastBoom",

    "ofSmashSD",

    "ofSmashItems",
    "ofHillLevel", "ofHillArea", "ofHillX", "ofHillY", "ofHillZ",
    "ofHillTarget",
    "ofChaos", "ofChaosNext",

    "ofCorpse",
    "ofChaosStunt",
    "ofChaosWild",

    "ofChaosNot",

    "ofRoomCostume",
    "ofRoomHats",
    "ofRoomHatFit",

    "ofRoomPowers",
    "ofRoomPowers2",
    "ofLearn",

    "ofCrownTarget",
    "ofCrownStreak",
    "ofCrownStreak2", "ofCrownStreak3",
    "ofCrownActive",

    "ofCrownNeed", "ofCrownNeed2", "ofCrownNeed3",

    "ofMhRunner",
    "ofLavaFront",
    "ofShuffleSeed",

    "ofTexMix",

    "ofShuffleShape",

    "ofChaosDeck",

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

    "ofCoinFever",

    "ofRingAt", "ofRingLevel", "ofRingArea", "ofRingR",

    "ofRingTarget",

    "ofRcSeed", "ofRcGrid", "ofRcOrder",

    "ofBountyTarget",

    "ofShootTo",

    "ofRushPool", "ofCrCellAt",

    "ofSilverPts", "ofSilverSeed", "ofSilverTo",

    "ofWantedIs", "ofWantedLeft", "ofWantedBy", "ofWantedSeq", "ofWantedTo",

    "ofRcPts", "ofRcAt", "ofRcMobs", "ofRcMobs2", "ofRcMobs3", "ofRcGot",
    "ofRcPen", "ofRcTo",

    "ofBsAt", "ofBsBombs", "ofBsBombs2", "ofBsBombs3", "ofBsBombs4", "ofBsBombs5",
    "ofBsBombs6", "ofBsGot", "ofBsTo",

    "ofFgAt", "ofFgFlies", "ofFgFlies2", "ofFgFlies3", "ofFgGot", "ofFgTo",

    "ofFsSeed", "ofFsStars",

    "ofSdSpots", "ofSdState", "ofSdBomb",

    "ofLkAt", "ofLkSpin", "ofLkSpin2", "ofLkGot", "ofLkTo",

    "ofOcAt", "ofOcBit",

    "ofMrAt", "ofMrBig", "ofMrGot",

    "ofRktTarget", "ofRktPickPts", "ofRktPickAt", "ofRktRunes",

    "ofOitcPts",

    "ofDmQuad",

    "ofRushTarget",

    "ofSpotsAt", "ofSpotsAt2", "ofSpotsAt3", "ofSpotsAt4",
    "ofSpotsLevel", "ofSpotsArea", "ofSpotsGrab", "ofSpotsRound",
    "ofHpFuse", "ofHpRound", "ofHpStartFuse",
    "ofHpHolders2", "ofHpFuses2",

    "ofHpBlown", "ofHpBlown2",

    "ofMurderFound", "ofMurderGun",
    "ofQueueOn", "ofQueueLeft",

    "ofQueueLoop",

    "ofPlaylist",

    "ofAlwaysOn", "ofTourney", "ofTourBoard",

    "ofRunLevel", "ofRunAct", "ofRunMode", "ofRunTitle",

    "ofRunRecord",

    "ofRoundLead",

    "ofGmRoomBy",

    "ofRunOpts",

    "ofDemonOpts",

    "ofClonesOpts",

    "ofSprayOpts",

    "ofOnOff",

    "ofLogic",
    "ofWires",

    "ofWires2", "ofWires3", "ofWires4", "ofWires5", "ofWires6", "ofWires7", "ofWires8",

    "ofPetEat",

    "ofRandoView",

    "ofRandoEntries",

    "ofDomAt", "ofDomLevel", "ofDomArea", "ofDomCap",
    "ofShootAt",

    "ofHillPts",

    "ofGdPlan",
    "ofDomRed", "ofDomBlue", "ofDomTarget",

    "ofDomLost",
    "ofTeamsOn", "ofTeamRound",
    "ofVoteWait",

    "ofCourseOrder",

    "ofRoundMusic",

    "ofTogether", "ofRopeLen",

    "ofRopeBite", "ofToss",

    "ofWarp",

    "ofStandings",

    "ofMvCard", "ofMvLeft", "ofMvWon",

    "ofGroundTide",

    "ofGridLevel", "ofGridArea", "ofGridAt", "ofTurfLost",
    "ofTurfBoard", "ofTurfBoard2",

    "ofSbRule", "ofSbPts", "ofSbBombs", "ofSbShine",

    "ofFbBall", "ofFbScore", "ofFbAt", "ofFbTarget",

    "ofFbPen",

    "ofVbBall", "ofVbScore", "ofVbAt", "ofVbTarget",

    "ofBzThrows",

    "ofBxBombs", "ofBxBombs2", "ofBxBombs3", "ofBxBombs4", "ofBxBombs5",

    "ofBmField", "ofBmAt", "ofBmBoard", "ofBmGot", "ofBmLoose", "ofBmPow",
    "ofBmSD", "ofBmSeats", "ofBmBack",
    "ofBmBombs", "ofBmBombs2", "ofBmBombs3", "ofBmBombs4", "ofBmBombs5", "ofBmBombs6",
    "ofBmBurst", "ofBmBurst2", "ofBmBurst3", "ofBmBurst4",

    "ofGlassAt", "ofGlassLevel", "ofGlassArea", "ofGlassState",

    "ofDfAt", "ofDfBall",

    "ofChompAt",

    "ofPhProps",

    "ofPoll", "ofRtv", "ofReady", "ofCountdown",

    "ofBonus",
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

    ofGmPaid = true,

    ofCtfRed = true, ofCtfBlue = true,

    ofLineLight = true, ofSimonCall = true,
    ofArenaClear = true,
    ofHpHolder = true, ofHpBoom = true,

    ofCrown = true,

    ofCrown2 = true, ofCrown3 = true,
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

    ofNoBoxes = true,
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

    { key = "ofInMenu",     start = false },

    { key = "ofPicking",    start = false },

    { key = "ofSteerYaw",   start = nil },

    { key = "ofScale",      start = nil },
    { key = "ofCheats",     start = nil },

    { key = "ofCheats2",    start = nil },
    { key = "ofCheats3",    start = nil },
    { key = "ofCheats4",    start = nil },
    { key = "ofCheats5",    start = nil },

    { key = "ofUnseen",     start = nil },

    { key = "ofTasPlay",    start = false },

    { key = "ofClones",     start = 0 },

    { key = "ofClonesGone", start = 0 },

    { key = "ofInvisible",  start = 0 },

    { key = "ofClass",      start = 0 },

    { key = "ofGulp",       start = 0 },

    { key = "ofMouth",      start = 0 },

    { key = "ofCoinSpill",  start = 0 },
    { key = "ofForgeSize",  start = nil },

    { key = "ofForgeReach", start = nil },

    { key = "ofForgeMoved", start = nil },
    { key = "ofHsFresh",    start = nil },
    { key = "ofHsFrozen",   start = nil },
    { key = "ofStill",      start = nil },
    { key = "ofBingoMarks", start = nil },
    { key = "ofPresses",    start = nil },

    { key = "ofMvPick",     start = 0 },

    { key = "ofDoorMine",   start = nil },

    { key = "ofScore",      start = 0 },
    { key = "ofGmTime",     start = 0 },
    { key = "ofHpGrab",     start = 0 },

    { key = "ofHpGrabAt",   start = 1 },

    { key = "ofSpotsClaim", start = 0 },

    { key = "ofBonusTook", start = "" },

    { key = "ofRollAim",    start = 0 },

    { key = "ofBankHeld",   start = 0 },

    { key = "ofRcState",    start = nil },

    { key = "ofDhState",    start = nil },

    { key = "ofBountyAt",   start = "" },
    { key = "ofBountyTo",   start = -1 },
    { key = "ofBountySeq",  start = 0 },

    { key = "ofCaughtBy",   start = "" },

    { key = "ofBalAt",      start = nil },
    { key = "ofBalFound",   start = nil },

    { key = "ofPhProp",     start = 0 },

    { key = "ofPhLift",     start = 0 },

    { key = "ofOitcKills",    start = 0 },

    { key = "ofRktBlast",     start = "" },
    { key = "ofRktGrab",      start = 0 },

    { key = "ofRktShot",      start = "" },
    { key = "ofRktDownBy",    start = "" },

    { key = "ofSmashGrab",    start = 0 },
    { key = "ofSmashUse",     start = "" },
    { key = "ofSmashShare",   start = "" },

    { key = "ofSplits",     start = "" },

    { key = "ofHold",       start = nil },

    { key = "ofHeld",       start = nil },

    { key = "ofPerch",      start = nil },

    { key = "ofWorn",       start = nil },

    { key = "ofRunTime",    start = 0 },

    { key = "ofRunGot",     start = 0 },

    { key = "ofSplitGot",   start = 0 },
    { key = "ofVoted",      start = "" },
    { key = "ofNoRace",     start = false },

    { key = "ofNoRun",      start = false },

    { key = "ofCrownTo",    start = nil },
    { key = "ofCrownGave",  start = 0 },

    { key = "ofCrownDied",  start = 0 },

    { key = "ofSmashPct",   start = 0 },
    { key = "ofSmashKOs",   start = 0 },
    { key = "ofSmashFall",  start = nil },
    { key = "ofCostume",    start = "" },

    { key = "ofHat",        start = "" },

    { key = "ofPet",        start = "" },

    { key = "ofPetName",    start = "" },

    { key = "ofFacing",     start = false },

    { key = "ofMyShape",    start = "" },

    { key = "ofPossess",    start = "" },

    { key = "ofEmote",      start = 0 },

    { key = "ofTicks",      start = "" },

    { key = "ofMhDied",     start = 0 },

    { key = "ofMhCard",     start = nil },

    { key = "ofFsHits",     start = nil },

    { key = "ofPhoto",      start = false },

    { key = "ofGmBlastPress", start = 0 },

    { key = "ofShotFar",      start = 0 },

    { key = "ofTurfPaint",    start = "" },

    { key = "ofFzRow",        start = "" },

    { key = "ofSilverGot",    start = nil },

    { key = "ofSbState",      start = nil },
    { key = "ofSbGrab",       start = nil },

    { key = "ofPermadead",    start = false },

    { key = "ofFbKick",       start = "" },

    { key = "ofVbHit",        start = "" },

    { key = "ofBallRide",     start = "" },

    { key = "ofGlassRow",     start = 0 },
    { key = "ofGlassFell",    start = 0 },

    { key = "ofGdPos",        start = "" },

    { key = "ofDfParry",      start = "0 0 0" },
    { key = "ofDfHit",        start = "0 0" },
    { key = "ofDfLives",      start = 0 },

    { key = "ofUpside",       start = 0 },
}

guard.SHARED = {
    ofRole = "modes.set_role",
}

guard.ROW_OWNER = {
    ofSpectating = "mine",
    ofIdle       = "mine",
    ofScale      = "mine",
    ofCheats     = "mine",

    ofCheats2    = "mine",
    ofCheats3    = "mine",
    ofCheats4    = "mine",
    ofCheats5    = "mine",
    ofUnseen     = "mine",
    ofTasPlay    = "mine",
    ofClones     = "mine",
    ofClonesGone = "mine",
    ofInvisible  = "mine",
    ofClass      = "mine",
    ofGulp       = "mine",
    ofMouth      = "mine",
    ofCoinSpill  = "mine",
    ofForgeSize  = "mine",

    ofForgeReach = "mine",

    ofForgeMoved = "mine",
    ofHsFresh    = "mine",

    ofMhDied     = "mine",
    ofMhCard     = "mine",
    ofFsHits     = "mine",

    ofHsFrozen   = "mine",
    ofStill      = "mine",
    ofBingoMarks = "mine",
    ofPresses    = "mine",

    ofDoorMine   = "mine",

    ofMvPick     = "mine",

    ofMuted      = "host",
    ofJailed     = "host",
    ofTier       = "host",
    ofCrHeld     = "host",

    ofRole       = "shared",
    ofTeam       = "host",

    ofRope       = "host",
    ofBond       = "host",

    ofCrew       = "host",

    ofSteerYaw   = "mine",

    ofScore      = "mine",
    ofGmTime     = "mine",

    ofSpotsClaim = "mine",

    ofBonusTook  = "mine",

    ofRollAim    = "mine",

    ofBankHeld   = "mine",

    ofBountyAt   = "mine",
    ofBountyTo   = "mine",
    ofBountySeq  = "mine",

    ofCaughtBy   = "mine",
    ofBalAt      = "mine",
    ofBalFound   = "mine",
    ofPhProp     = "mine",
    ofPhLift     = "mine",
    ofOitcKills  = "mine",
    ofRktBlast   = "mine",
    ofRktGrab    = "mine",
    ofRktShot    = "mine",
    ofRktDownBy  = "mine",
    ofSmashGrab  = "mine",
    ofSmashUse   = "mine",
    ofSmashShare = "mine",
    ofHpGrab     = "mine",
    ofHpGrabAt   = "mine",
    ofRcState    = "mine",
    ofDhState    = "mine",
    ofSplits     = "mine",

    ofRunTime    = "mine",

    ofRunGot     = "mine",

    ofSplitGot   = "mine",
    ofVoted      = "mine",
    ofNoRace     = "mine",
    ofNoRun      = "mine",

    ofCrownTo    = "mine",
    ofCrownGave  = "mine",

    ofCrownDied  = "mine",

    ofSmashPct   = "mine",
    ofSmashKOs   = "mine",
    ofSmashFall  = "mine",

    ofGmBlastPress = "mine",

    ofShotFar    = "mine",

    ofCostume    = "mine",

    ofFacing     = "mine",

    ofMyShape    = "mine",

    ofHat        = "mine",

    ofPet        = "mine",

    ofPetName    = "mine",

    ofPossess    = "mine",

    ofEmote      = "mine",

    ofInMenu     = "mine",

    ofPicking    = "mine",

    ofHold       = "mine",

    ofHeld       = "mine",

    ofPerch      = "mine",

    ofWorn       = "mine",

    ofTicks      = "mine",

    ofPhoto      = "mine",

    ofTurfPaint  = "mine",

    ofFzRow      = "mine",

    ofSilverGot  = "mine",

    ofSbState    = "mine",
    ofSbGrab     = "mine",

    ofPermadead  = "mine",

    ofFbKick     = "mine",

    ofVbHit      = "mine",

    ofBallRide   = "mine",

    ofGlassRow   = "mine",
    ofGlassFell  = "mine",

    ofGdPos      = "mine",

    ofDfParry    = "mine",
    ofDfHit      = "mine",
    ofDfLives    = "mine",

    ofUpside     = "mine",
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

    return true
end

function guard.mine_report()
    return guard.mineRepairs
end

for _, key in ipairs({ "ofIdle", "ofInMenu", "ofPicking", "ofSteerYaw", "ofScale", "ofUnseen", "ofTasPlay", "ofCheats",

                       "ofCheats2", "ofCheats3", "ofCheats4", "ofCheats5",
                       "ofForgeSize", "ofClones", "ofClonesGone", "ofInvisible",
                       "ofForgeReach", "ofForgeMoved",
                       "ofHsFresh", "ofHsFrozen",
                       "ofStill", "ofBingoMarks", "ofPresses",
                       "ofScore", "ofGmTime", "ofHpGrab", "ofHpGrabAt",
                       "ofSplits", "ofRunTime", "ofRunGot", "ofSplitGot",
                       "ofVoted",

                       "ofNoRun",

                       "ofSpotsClaim", "ofBankHeld", "ofBonusTook",
                       "ofRcState", "ofDhState",

                       "ofRollAim",

                       "ofUpside",
                       "ofBountyAt", "ofBountyTo", "ofBountySeq",
                       "ofCrownTo", "ofCrownGave", "ofCaughtBy",
                       "ofBalAt", "ofBalFound", "ofPhProp", "ofPhLift",
                       "ofOitcKills", "ofRktBlast", "ofRktGrab", "ofRktShot", "ofRktDownBy",

                       "ofSmashGrab", "ofSmashUse", "ofSmashShare",

                       "ofCostume", "ofHat", "ofPet", "ofPossess", "ofEmote",

                       "ofHold", "ofHeld", "ofPerch", "ofWorn",

                       "ofDoorMine",

                       "ofTicks",
                       "ofFacing",

                       "ofClass", "ofGulp", "ofMouth",

                       "ofCoinSpill",
                       "ofFsHits", "ofMhCard" }) do
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

hook_on_sync_table_change(gPlayerSyncTable[0], "ofPhoto", 0, function()
    guard.repair_mine("ofPhoto")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofSmashPct", 0, function()
    guard.repair_mine("ofSmashPct")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofSmashKOs", 0, function()
    guard.repair_mine("ofSmashKOs")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofSmashFall", 0, function()
    guard.repair_mine("ofSmashFall")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofGmBlastPress", 0, function()
    guard.repair_mine("ofGmBlastPress")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofShotFar", 0, function()
    guard.repair_mine("ofShotFar")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofMvPick", 0, function()
    guard.repair_mine("ofMvPick")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofTurfPaint", 0, function()
    guard.repair_mine("ofTurfPaint")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofFzRow", 0, function()
    guard.repair_mine("ofFzRow")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofSilverGot", 0, function()
    guard.repair_mine("ofSilverGot")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofSbState", 0, function()
    guard.repair_mine("ofSbState")
end)
hook_on_sync_table_change(gPlayerSyncTable[0], "ofSbGrab", 0, function()
    guard.repair_mine("ofSbGrab")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofFbKick", 0, function()
    guard.repair_mine("ofFbKick")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofVbHit", 0, function()
    guard.repair_mine("ofVbHit")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofBallRide", 0, function()
    guard.repair_mine("ofBallRide")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofPermadead", 0, function()
    guard.repair_mine("ofPermadead")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofGlassRow", 0, function()
    guard.repair_mine("ofGlassRow")
end)
hook_on_sync_table_change(gPlayerSyncTable[0], "ofGlassFell", 0, function()
    guard.repair_mine("ofGlassFell")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofGdPos", 0, function()
    guard.repair_mine("ofGdPos")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofDfParry", 0, function()
    guard.repair_mine("ofDfParry")
end)
hook_on_sync_table_change(gPlayerSyncTable[0], "ofDfHit", 0, function()
    guard.repair_mine("ofDfHit")
end)
hook_on_sync_table_change(gPlayerSyncTable[0], "ofDfLives", 0, function()
    guard.repair_mine("ofDfLives")
end)

hook_on_sync_table_change(gPlayerSyncTable[0], "ofPetName", 0, function()
    guard.repair_mine("ofPetName")
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
