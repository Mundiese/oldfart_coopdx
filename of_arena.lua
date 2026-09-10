OF = OF or {}
OF.arena = OF.arena or {}

local arena = OF.arena

local SWEEP_FRAMES = 12 * 30
local SWEEP_EVERY = 10

arena.KEEP = {
    id_bhvBowserKey, id_bhvBowserKeyUnlockDoor, id_bhvBowserKeyCourseExit,
    id_bhvGrandStar, id_bhvStar, id_bhvStarSpawnCoordinates,
    id_bhvSpawnedStar, id_bhvSpawnedStarNoLevelExit, id_bhvCelebrationStar,
    id_bhvHiddenStar, id_bhvHiddenStarTrigger, id_bhvHiddenRedCoinStar,
    id_bhvBowserCourseRedCoinStar, id_bhvRedCoinStarMarker,
    id_bhvUnlockDoorStar, id_bhvUkikiCageStar, id_bhvHiddenAt120Stars,
    id_bhvActSelectorStarType, id_bhvAirborneStarCollectWarp,
    id_bhvLaunchStarCollectWarp, id_bhvPaintingStarCollectWarp,

    id_bhvBooBossSpawnedBridge,
}

arena.KEEP_SET = {}
for _, id in ipairs(arena.KEEP) do
    if id ~= nil then arena.KEEP_SET[id] = true end
end

arena.BOSSES = {
    id_bhvBowser, id_bhvBowserBodyAnchor, id_bhvBowserTailAnchor,
    id_bhvBowserBomb, id_bhvBowserBombExplosion, id_bhvBowserFlameSpawn,
    id_bhvBowserShockWave, id_bhvFlameBowser, id_bhvBlueBowserFlame,
    id_bhvKingBobomb, id_bhvWhompKingBoss, id_bhvEyerokBoss, id_bhvEyerokHand,
    id_bhvBigBully, id_bhvBigBullyWithMinions, id_bhvBigChillBully,
    id_bhvWigglerHead, id_bhvWigglerBody,

    id_bhvGhostHuntBigBoo, id_bhvMerryGoRoundBigBoo,

    id_bhvBigSnowmanWhole, id_bhvSnowmansBottom, id_bhvSnowmansHead,
    id_bhvSnowmansBodyCheckpoint,
}

arena.HAZARDS = {
    id_bhvFlamethrower, id_bhvFlamethrowerFlame, id_bhvFlame,
    id_bhvFlameBouncing, id_bhvFireSpitter, id_bhvBouncingFireball,
    id_bhvBouncingFireballFlame, id_bhvSmallPiranhaFlame, id_bhvFlyguyFlame,
    id_bhvVolcanoFlames, id_bhvBulletBillCannon, id_bhvThwomp, id_bhvThwomp2,
    id_bhvWaterBombSpawner, id_bhvWaterBomb, id_bhvWaterBombCannon,
    id_bhvHomingAmp, id_bhvCirclingAmp, id_bhvMrI, id_bhvMrIBody,

    id_bhvBlueFlamesGroup, id_bhvFlameFloatingLanding,
    id_bhvFlameLargeBurningOut, id_bhvFlameMovingForwardGrowing,
    id_bhvLllRotatingHexFlame, id_bhvKoopaShellFlame,

    id_bhvGrindel, id_bhvHorizontalGrindel, id_bhvSpindel,
    id_bhvFallingPillar, id_bhvFallingPillarHitbox,

    id_bhvBowlingBall, id_bhvPitBowlingBall, id_bhvFreeBowlingBall,
    id_bhvBobBowlingBallSpawner, id_bhvTtmBowlingBallSpawner,
    id_bhvThiBowlingBallSpawner,
}

arena.ENEMIES = {
    id_bhvGoomba, id_bhvGoombaTripletSpawner, id_bhvKoopa, id_bhvBobomb,
    id_bhvSmallBully, id_bhvSmallChillBully, id_bhvSmallWhomp, id_bhvChuckya,
    id_bhvHeaveHo, id_bhvPokey, id_bhvPokeyBodyPart, id_bhvSpiny,
    id_bhvEnemyLakitu, id_bhvMontyMole, id_bhvKlepto, id_bhvSnufit,
    id_bhvSnufitBalls, id_bhvSwoop, id_bhvScuttlebug, id_bhvScuttlebugSpawn,
    id_bhvSkeeter, id_bhvBoo, id_bhvGhostHuntBoo, id_bhvBalconyBigBoo,
    id_bhvMrBlizzard, id_bhvSpindrift, id_bhvPiranhaPlant,
    id_bhvFirePiranhaPlant, id_bhvToxBox, id_bhvUnagi, id_bhvBubba,
    id_bhvFlyingBookend, id_bhvMoneybag,

    id_bhvBooWithCage, id_bhvMerryGoRoundBoo,

    id_bhvChuckyaAnchorMario, id_bhvHeaveHoThrowMario, id_bhvBobombAnchorMario,

    id_bhvUnagiSubobject, id_bhvChainChomp, id_bhvChainChompChainPart,
    id_bhvSushiShark, id_bhvSushiSharkCollisionChild,

    id_bhvMadPiano, id_bhvHauntedChair,

    id_bhvBulletBill, id_bhvClamShell, id_bhvBub, id_bhvUkiki, id_bhvMacroUkiki,
    id_bhvSmallPenguin, id_bhvPenguinBaby, id_bhvRacingPenguin,
    id_bhvSLWalkingPenguin,

    id_bhvFlyGuy,
}

arena.PROJECTILES = {
    id_bhvBulletBill, id_bhvMrBlizzardSnowball, id_bhvMontyMoleRock,
    id_bhvSnufitBalls, id_bhvMrIParticle, id_bhvKoopaShellFlame,
    id_bhvBowserBomb, id_bhvBowserBombExplosion, id_bhvExplosion,
    id_bhvWaterBomb, id_bhvWaterBombShadow, id_bhvKoopaShell,
    id_bhvKoopaShellUnderwater,

    id_bhvBowlingBall, id_bhvPitBowlingBall, id_bhvFreeBowlingBall,
}

arena.SPAWNERS = {
    id_bhvGoombaTripletSpawner, id_bhvScuttlebugSpawn, id_bhvBookendSpawn,
    id_bhvWaterBombSpawner, id_bhvBowserFlameSpawn, id_bhvMontyMoleHole,
    id_bhvCourtyardBooTriplet, id_bhvMerryGoRoundBooManager,
    id_bhvFishSpawner, id_bhvFishGroup, id_bhvManyBlueFishSpawner,
    id_bhvFewBlueFishSpawner, id_bhvTankFishGroup, id_bhvJetStreamRingSpawner,

    id_bhvBobBowlingBallSpawner, id_bhvTtmBowlingBallSpawner,
    id_bhvThiBowlingBallSpawner,

    id_bhvChirpChirp,

    id_bhvSnowMoundSpawn,
}

arena.BYSTANDERS = {
    id_bhvToadMessage, id_bhvEndToad, id_bhvBobombBuddy,
    id_bhvBobombBuddyOpensCannon, id_bhvButterfly, id_bhvTripletButterfly,
    id_bhvFish, id_bhvBlueFish, id_bhvSeaweed, id_bhvSeaweedBundle,
    id_bhvMantaRay, id_bhvDorrie, id_bhvBooCage, id_bhvSkeeterWave,
    id_bhvPiranhaPlantBubble,

    id_bhvMessagePanel, id_bhvSignOnWall, id_bhvTuxiesMother, id_bhvYoshi,

    id_bhvBird,

    id_bhvHoot,
}

arena.CURRENTS = {
    id_bhvTweester, id_bhvTweesterSandParticle, id_bhvWhirlpool,
    id_bhvJetStream, id_bhvStrongWindParticle, id_bhvTinyStrongWindParticle,
    id_bhvSLSnowmanWind, id_bhvWind,

    id_bhvCloud, id_bhvCloudPart,
}

arena.CANNONS = {
    id_bhvCannon, id_bhvCannonBarrel,
    id_bhvCannonBarrelBubbles, id_bhvCannonBaseUnused, id_bhvInsideCannon,
}

arena.PICKUPS = {
    id_bhvYellowCoin, id_bhvTemporaryYellowCoin, id_bhvMovingYellowCoin,
    id_bhvSingleCoinGetsSpawned, id_bhvOneCoin, id_bhvCoinFormation,
    id_bhvCoinFormationSpawn, id_bhvThreeCoinsSpawn, id_bhvTenCoinsSpawn,
    id_bhvRedCoin, id_bhvHiddenBlueCoin, id_bhvBlueCoinSwitch,
    id_bhvBlueCoinJumping, id_bhvBlueCoinSliding, id_bhvMovingBlueCoin,
    id_bhvMrIBlueCoin, id_bhvCoinInsideBoo,
    id_bhv1Up, id_bhv1upWalking, id_bhv1upRunningAway, id_bhv1upSliding,
    id_bhv1upJumpOnApproach, id_bhvHidden1up, id_bhvHidden1upInPole,
    id_bhvNormalCap, id_bhvWingCap, id_bhvMetalCap, id_bhvVanishCap,
    id_bhvRecoveryHeart, id_bhvBreakableBox, id_bhvBreakableBoxSmall,
    id_bhvExclamationBox, id_bhvJumpingBox, id_bhvMoneybagHidden,
}

local SWEEP_BARE = { "bosses", "hazards", "enemies", "projectiles", "spawners",
                     "bystanders", "currents", "cannons", "pickups" }
local SWEEP_CLEAR = { "bosses", "hazards", "enemies", "projectiles", "spawners",
                      "bystanders", "currents" }

arena.PLACES = {
    {
        key = "bowser1", name = "Bowser 1 Arena",
        blurb = "flat, round, and a long way down",
        note = "an empty disc with a rim - the only thing in it is Bowser",
        level = LEVEL_BOWSER_1, area = 1, act = 1,
        sweep = SWEEP_BARE,
        clock = 0.75,
        suits = { "sumo", "laststanding", "koth" },
    },
    {
        key = "bowser2", name = "Bowser 2 Arena",
        blurb = "the tilting slab over the lava",
        note = "one platform that tips under whoever stands on the edge of it",
        level = LEVEL_BOWSER_2, area = 1, act = 1,
        sweep = SWEEP_BARE,
        clock = 0.75,
        suits = { "sumo", "laststanding", "hotpotato" },
    },
    {
        key = "bowser3", name = "Bowser 3 Arena",
        blurb = "the big star-shaped floor",
        note = "the largest of the three, with points you can be pushed off",
        level = LEVEL_BOWSER_3, area = 1, act = 1,
        sweep = SWEEP_BARE,
        suits = { "domination", "crown", "spots" },
    },
    {
        key = "igloo", name = "The Igloo",
        blurb = "one round room with one way out",
        note = "a ring of ice with a goomba, a spindrift and the cannon that is the exit",
        level = LEVEL_SL, area = 2, act = 1,
        sweep = SWEEP_BARE,
        clock = 0.75,
        suits = { "sumo", "murder", "hotpotato" },
    },
    {
        key = "volcano", name = "Inside the Volcano",
        blurb = "ledges over the lava, and two bullies already on them",
        note = "a spiral of ledges around a lava pit: two bullies, one bouncing fireball",
        level = LEVEL_LLL, area = 2, act = 1,
        sweep = SWEEP_BARE,
        suits = { "sumo", "laststanding", "koth" },
    },
    {
        key = "pyramid", name = "Inside the Pyramid",
        blurb = "ramps down to a sand pit, with amps on the way",
        note = "a homing amp, a circling amp, and a spawner that keeps making Goombas",
        level = LEVEL_SSL, area = 2, act = 1,
        sweep = SWEEP_BARE,
        clock = 1.25,
        suits = { "hideseek", "murder" },

        notFor = { "sumo" },
    },
    {
        key = "wigglercave", name = "Wiggler's Cave",
        blurb = "one round chamber under Tiny-Huge Island",
        note = "the wiggler itself, one fire spitter and eight red coins - one way back out",
        level = LEVEL_THI, area = 3, act = 1,
        sweep = SWEEP_BARE,
        clock = 0.75,
        suits = { "sumo", "laststanding", "murder", "hotpotato" },
    },

    {
        key = "desert_cage", name = "Desert Cage",
        blurb = "your own map, opened from the level you exported",
        note = "whatever you built into it - the sweep is all this mod brings",
        script = "desert_cage", area = 1, act = 1,
        sweep = SWEEP_BARE,
        suits = { "sumo", "laststanding", "koth" },
    },

    {
        key = "ice_donut", name = "Ice Donut",
        blurb = "your own map, opened from the level you exported",
        note = "whatever you built into it - the sweep is all this mod brings",
        script = "ice_donut", area = 1, act = 1,
        sweep = SWEEP_BARE,
        suits = { "sumo", "laststanding", "koth", "hotpotato" },
    },
    {
        key = "the_plate", name = "The Plate",
        blurb = "your own map, opened from the level you exported",
        note = "whatever you built into it - the sweep is all this mod brings",
        script = "the_plate", area = 1, act = 1,
        sweep = SWEEP_BARE,
        suits = { "sumo", "laststanding", "koth", "hotpotato" },
    },

    {
        key = "tower", name = "Tower of the Wing Cap",
        blurb = "one platform in the sky",
        note = "a square of floor, eight red coins, and open air on every side",
        level = LEVEL_TOTWC, area = 1, act = 1,
        sweep = SWEEP_BARE,
        clock = 0.75,

        suits = {},
    },
    {
        key = "wmotr", name = "Wing Mario over the Rainbow",
        blurb = "scattered islands, endless drop",
        note = "islands too far apart to walk between - a round here is a flying round",
        level = LEVEL_WMOTR, area = 1, act = 1,
        sweep = SWEEP_CLEAR,
        clock = 1.25,
        suits = { "laststanding", "hideseek", "coinrush" },
    },

    {
        key = "cotmc", name = "Cavern of the Metal Cap",
        blurb = "a river through a cave, and nothing in it",
        note = "one long cave with a current running through it and no enemies at all",
        level = LEVEL_COTMC, area = 1, act = 1,
        sweep = SWEEP_CLEAR,
        mods = "water=5",
        clock = 1.25,
        suits = { "hideseek", "manhunt" },
    },

    {
        key = "aquarium", name = "The Secret Aquarium",
        blurb = "underwater, nowhere to run",
        note = "one glass box, eight red coins and a great many fish",
        level = LEVEL_SA, area = 1, act = 1,
        sweep = SWEEP_CLEAR,
        mods = "water=5,softland=1",
        clock = 0.75,
        suits = { "hideseek", "manhunt" },
    },
    {
        key = "ship", name = "Inside the Sunken Ship",
        blurb = "a flooded hull with one box in it",
        note = "the emptiest room in the game: one star box, and water above the deck",
        level = LEVEL_JRB, area = 2, act = 1,
        sweep = SWEEP_CLEAR,
        clock = 0.75,
        suits = { "hideseek", "manhunt" },
    },
}

function arena.find(key)
    if key == nil then return nil end
    for _, place in ipairs(arena.PLACES) do
        if place.key == key then return place end
    end

    return nil
end

function arena.name_of(key)
    local place = arena.find(key)
    if place == nil then return nil end
    return place.name
end

function arena.clock_of(key)
    local place = arena.find(key)
    if place == nil then return 1 end
    local scale = tonumber(place.clock)
    if scale == nil or scale <= 0 then return 1 end
    return scale
end

function arena.recommended(key)
    local place = arena.find(key)
    local keys = {}
    if place ~= nil and type(place.sweep) == "table" then
        for _, option in ipairs(place.sweep) do table.insert(keys, option) end
    end
    if #keys == 0 then keys = { "bosses" } end
    return keys
end

local MEMORY_PREFIX = "arenafor_"
function arena.remembered_for(modeKey)
    if modeKey == nil or modeKey == "" then return {} end

    local packed = mod_storage_load(MEMORY_PREFIX .. modeKey, "")
    local list = {}
    for key in string.gmatch(tostring(packed or ""), "[^,]+") do
        if arena.find(key) ~= nil then table.insert(list, key) end
    end
    return list
end

function arena.note_pairing(modeKey, placeKey)
    if modeKey == nil or modeKey == "" then return false end
    if arena.find(placeKey) == nil then return false end

    local was = arena.remembered_for(modeKey)
    local out = { placeKey }
    for _, key in ipairs(was) do
        if key ~= placeKey and #out < 3 then table.insert(out, key) end
    end

    if table.concat(out, ",") == table.concat(was, ",") then return false end
    return OF.util.store(MEMORY_PREFIX .. modeKey, table.concat(out, ","))
end

function arena.for_mode(modeKey)
    local out, seen = {}, {}
    for _, key in ipairs(arena.remembered_for(modeKey)) do
        if not seen[key] then
            seen[key] = true
            table.insert(out, key)
        end
    end
    for _, place in ipairs(arena.PLACES) do
        for _, key in ipairs(place.suits or {}) do
            if key == modeKey and not seen[place.key] then
                seen[place.key] = true
                table.insert(out, place.key)
            end
        end
    end
    return out
end

function arena.suits_named(key)
    local place = arena.find(key)
    if place == nil then return {} end
    local names = {}
    for _, modeKey in ipairs(place.suits or {}) do
        local mode = nil
        if OF.gamemodes ~= nil and OF.gamemodes.BY_KEY ~= nil then
            mode = OF.gamemodes.BY_KEY[modeKey]
        end
        if mode ~= nil then table.insert(names, OF.lang.t(mode.name)) end
    end
    return names
end

arena.OPTIONS = {
    { key = "bosses",      id = "bo", list = "BOSSES",
      name = "Bosses",      blurb = "Bowser, the kings, the big bullies" },
    { key = "hazards",     id = "ha", list = "HAZARDS",
      name = "Hazards",     blurb = "fire, thwomps, amps, crushers" },
    { key = "enemies",     id = "en", list = "ENEMIES",
      name = "Enemies",     blurb = "the ordinary cast, goomba to boo" },
    { key = "projectiles", id = "pr", list = "PROJECTILES",
      name = "In flight",   blurb = "bullets, snowballs, rocks, shells" },
    { key = "spawners",    id = "sp", list = "SPAWNERS",
      name = "Spawners",    blurb = "the things that make more things" },
    { key = "bystanders",  id = "by", list = "BYSTANDERS",
      name = "Bystanders",  blurb = "toads, buddies, fish, scenery" },
    { key = "currents",    id = "cu", list = "CURRENTS",
      name = "Currents",    blurb = "tweesters, whirlpools, wind" },
    { key = "cannons",     id = "ca", list = "CANNONS",
      name = "Cannons",     blurb = "the ways out of the ring, sealed shut" },
    { key = "pickups",     id = "pi", list = "PICKUPS",
      name = "Pickups",     blurb = "coins, caps, boxes - never stars" },
}

arena.OPTION_BY_KEY = {}
arena.OPTION_BY_ID = {}
for _, option in ipairs(arena.OPTIONS) do
    arena.OPTION_BY_KEY[option.key] = option
    arena.OPTION_BY_ID[option.id] = option
end

function arena.pack(keys)
    if keys == nil then return "" end
    local wanted = {}
    for _, key in ipairs(keys) do wanted[key] = true end
    local out = {}
    for _, option in ipairs(arena.OPTIONS) do
        if wanted[option.key] then table.insert(out, option.id) end
    end
    return table.concat(out, ",")
end

function arena.unpack(packed)
    local keys = {}
    if type(packed) ~= "string" then return keys end
    for id in string.gmatch(packed, "[^,]+") do
        local option = arena.OPTION_BY_ID[id]
        if option ~= nil then table.insert(keys, option.key) end
    end
    return keys
end

function arena.armed_set()

    if gGlobalSyncTable.ofArenaClear ~= true then return {} end

    local packed = gGlobalSyncTable.ofArenaSweep
    if type(packed) == "string" and packed ~= "" then
        local set = {}
        for _, key in ipairs(arena.unpack(packed)) do set[key] = true end
        return set
    end

    local set = { bosses = true }
    if gGlobalSyncTable.ofArenaHazards == true then set.hazards = true end
    if gGlobalSyncTable.ofArenaEnemies == true then set.enemies = true end
    return set
end

function arena.option_on(key)
    return arena.armed_set()[key] == true
end

function arena.script_names(script)
    if type(script) ~= "string" or script == "" then return {} end
    return { "level_" .. script .. "_entry", script }
end

local CUSTOM_COURSE = 0
local CUSTOM_REACH = 20000
local CUSTOM_ECHO = 0x00

local function resolve_custom(place)
    place.tried = arena.script_names(place.script)
    place.level = nil
    place.foundAs = nil

    for _, name in ipairs(place.tried) do

        local found = tonumber(OF.util.optional("level_register", 0,
            name, CUSTOM_COURSE, place.name, place.script,
            CUSTOM_REACH, CUSTOM_ECHO, CUSTOM_ECHO, CUSTOM_ECHO))
        if found ~= nil and found ~= 0 then
            place.level = math.floor(found)
            place.foundAs = name
            return true
        end
    end
    return false
end

function arena.resolve_custom_levels()
    local found = 0
    for _, place in ipairs(arena.PLACES) do
        if place.script ~= nil and resolve_custom(place) then found = found + 1 end
    end
    return found
end

hook_event(HOOK_ON_MODS_LOADED, arena.resolve_custom_levels)

function arena.custom_missing(place)
    if place == nil or place.script == nil then return nil end
    if place.level ~= nil then return nil end
    local tried = place.tried
    if tried == nil or #tried == 0 then tried = arena.script_names(place.script) end
    return table.concat(tried, ", ")
end

local sweepFrames = 0
local sweepSet = {}
arena.swept = 0

arena.PAYING_OUT = {
    { id = id_bhvBowser,              actions = { [4] = true } },
    { id = id_bhvKingBobomb,          actions = { [7] = true, [8] = true } },
    { id = id_bhvWhompKingBoss,       actions = { [8] = true } },
    { id = id_bhvEyerokBoss,          actions = { [4] = true } },
    { id = id_bhvWigglerHead,         actions = { [4] = true } },
    { id = id_bhvBigBully,            actions = { [100] = true, [101] = true } },
    { id = id_bhvBigBullyWithMinions, actions = { [100] = true, [101] = true } },
    { id = id_bhvBigChillBully,       actions = { [100] = true, [101] = true } },
}

function arena.may_take(object)
    if object == nil then return false end

    local interact = object.oInteractType
    if interact ~= nil and OF.util.has_flag(interact, INTERACT_STAR_OR_KEY) then
        return false
    end

    for _, entry in ipairs(arena.PAYING_OUT) do
        if entry.id ~= nil
            and OF.util.optional("obj_has_behavior_id", 0, object, entry.id) ~= 0
            and entry.actions[object.oAction or -1] then
            return false
        end
    end

    return true
end

local function hush(object)
    if object == nil then return false end
    local flags = object.activeFlags
    if type(flags) ~= "number" then return false end
    if flags & ACTIVE_FLAG_DORMANT ~= 0 then return false end

    object.activeFlags = flags | ACTIVE_FLAG_DORMANT
    local gfx = object.header ~= nil and object.header.gfx or nil
    local node = gfx ~= nil and gfx.node or nil
    if node ~= nil and type(node.flags) == "number" then
        node.flags = node.flags & ~GRAPH_RENDER_ACTIVE
    end
    object.oInteractStatus = INT_STATUS_INTERACTED
    object.oIntangibleTimer = -1
    return true
end

local function wake(object)
    if object == nil then return false end
    local flags = object.activeFlags
    if type(flags) ~= "number" then return false end
    if flags & ACTIVE_FLAG_DORMANT == 0 then return false end

    object.activeFlags = flags & ~ACTIVE_FLAG_DORMANT
    local gfx = object.header ~= nil and object.header.gfx or nil
    local node = gfx ~= nil and gfx.node or nil
    if node ~= nil and type(node.flags) == "number" then
        node.flags = node.flags | GRAPH_RENDER_ACTIVE
    end
    object.oInteractStatus = 0
    object.oIntangibleTimer = 0
    return true
end

arena.hush = hush
arena.wake = wake

function arena.is_hushed(object)
    if object == nil then return false end
    local flags = object.activeFlags
    if type(flags) ~= "number" then return false end
    return flags & ACTIVE_FLAG_DORMANT ~= 0
end

function arena.in_use(object)
    if object == nil then return false end
    for _, entry in ipairs(OF.util.connected_players()) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil then
            local floor = m.floor
            if floor ~= nil and floor.object == object then return true end
            if m.heldObj == object then return true end
            if m.heldByObj == object then return true end
            if m.usedObj == object then return true end
            if m.riddenObj == object then return true end
        end
    end
    return false
end

local hushCount = 0

function arena.hushed()
    return hushCount
end

function arena.restore()
    if hushCount <= 0 then
        hushCount = 0
        return 0
    end
    local woken = 0
    for _, option in ipairs(arena.OPTIONS) do
        for _, behaviourId in ipairs(arena[option.list]) do
            if behaviourId ~= nil then
                local object = obj_get_first_with_behavior_id(behaviourId)
                while object ~= nil do
                    if wake(object) then woken = woken + 1 end
                    object = obj_get_next_with_same_behavior_id(object)
                end
            end
        end
    end
    hushCount = 0
    return woken
end

function arena.forget_hushed()
    hushCount = 0
end

local function collect(list, doomed, seen)
    for _, behaviourId in ipairs(list) do

        if behaviourId ~= nil and not arena.KEEP_SET[behaviourId] then
            local object = obj_get_first_with_behavior_id(behaviourId)
            while object ~= nil do
                local nextObject = obj_get_next_with_same_behavior_id(object)
                if not seen[object] and arena.may_take(object) then
                    seen[object] = true
                    table.insert(doomed, object)
                end
                object = nextObject
            end
        end
    end
end

local function sweep_list(list)
    local doomed, seen = {}, {}
    collect(list, doomed, seen)
    for _, object in ipairs(doomed) do obj_mark_for_deletion(object) end
    return #doomed
end

arena.sweep_list = sweep_list
arena.collect = collect

function arena.begin_sweep(bosses, hazards, enemies)

    arena.restore()
    sweepSet = {}
    if type(bosses) == "table" then
        for _, key in ipairs(bosses) do
            if arena.OPTION_BY_KEY[key] ~= nil then sweepSet[key] = true end
        end
    else
        sweepSet.bosses = bosses ~= false
        sweepSet.hazards = hazards == true
        sweepSet.enemies = enemies == true
    end
    sweepFrames = SWEEP_FRAMES
    arena.swept = 0
end

function arena.stop_sweep()
    sweepFrames = 0
    sweepSet = {}
    arena.restore()
end

function arena.is_sweeping()
    return sweepFrames > 0
end

function arena.sweeping_set()
    local out = {}
    for key, on in pairs(sweepSet) do if on then out[key] = true end end
    return out
end

local lastPair = ""
local function watch_pairing()
    local placeKey = gGlobalSyncTable.ofArenaPlace
    if type(placeKey) ~= "string" or placeKey == "" then
        lastPair = ""
        return
    end
    if gGlobalSyncTable.ofArenaClear ~= true then
        lastPair = ""
        return
    end
    if not OF.util.asks(OF.gamemodes, "is_running") or not OF.gamemodes.is_running() then
        lastPair = ""
        return
    end

    local modeKey = gGlobalSyncTable.ofGmKey
    if type(modeKey) ~= "string" or modeKey == "" then
        lastPair = ""
        return
    end

    local pair = modeKey .. "/" .. placeKey
    if pair == lastPair then return end
    lastPair = pair
    arena.note_pairing(modeKey, placeKey)
end

function arena.update()

    watch_pairing()

    if sweepFrames <= 0 then return end

    local due = (sweepFrames % SWEEP_EVERY == 0)
    sweepFrames = sweepFrames - 1
    if not due then return end

    local doomed, seen = {}, {}
    for _, option in ipairs(arena.OPTIONS) do
        if sweepSet[option.key] then collect(arena[option.list], doomed, seen) end
    end

    local slept = 0
    for _, object in ipairs(doomed) do

        if not arena.in_use(object) then
            if hush(object) then slept = slept + 1 end
        end
    end
    hushCount = hushCount + slept
    arena.swept = arena.swept + slept
end

function arena.wanted()
    local set = arena.armed_set()
    return gGlobalSyncTable.ofArenaClear == true,
           set.hazards == true,
           set.enemies == true
end

function arena.sync_sweep()
    if gGlobalSyncTable.ofArenaClear ~= true then
        arena.stop_sweep()
        return
    end
    local keys = {}
    for key in pairs(arena.armed_set()) do table.insert(keys, key) end
    arena.begin_sweep(keys)
end

function arena.on_level_init(...)
    arena.forget_hushed()
    arena.sync_sweep(...)
end

hook_event(HOOK_UPDATE, arena.update)
hook_event(HOOK_ON_LEVEL_INIT, arena.on_level_init)

hook_on_sync_table_change(gGlobalSyncTable, "ofArenaClear", 0, function()

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofArenaClear") then return end
    arena.sync_sweep()
end)

function arena.preview(key)
    local place = arena.find(key)
    if place == nil then return nil end

    local lines = {}
    local function say(label, value)
        if value == nil or value == "" then return end
        table.insert(lines, { label = label, value = value })
    end

    say(OF.lang.t("What it is"), OF.lang.t(place.blurb))
    say(OF.lang.t("What lives here"), OF.lang.t(place.note))

    local tried = arena.custom_missing(place)
    if tried ~= nil then
        say(OF.lang.t("Not installed here"),
            OF.lang.fill("no level called @", tried))
        say(OF.lang.t("Where that name comes from"), OF.lang.t(
            "the LevelScript array in the folder's script.c, not the folder"))
    elseif place.script ~= nil then
        say(OF.lang.t("Your own level"), tostring(place.foundAs or place.script))
    end

    local levelName = OF.util.level_name(place.level, place.area)
    if levelName ~= nil and levelName ~= place.name then
        say(OF.lang.t("The level"), levelName)
    end

    local wanted = {}
    for _, optionKey in ipairs(arena.recommended(key)) do wanted[optionKey] = true end
    local named = {}
    for _, option in ipairs(arena.OPTIONS) do
        if wanted[option.key] then table.insert(named, OF.lang.t(option.name)) end
    end
    say(OF.lang.t("Its own sweep"), table.concat(named, ", "))

    local armed = {}
    for _, option in ipairs(arena.OPTIONS) do
        if arena.armed_set()[option.key] then table.insert(armed, OF.lang.t(option.name)) end
    end
    if table.concat(armed, ", ") ~= table.concat(named, ", ") then
        say(OF.lang.t("Armed right now"),
            #armed > 0 and table.concat(armed, ", ") or OF.lang.t("nothing"))
    end

    local suits = arena.suits_named(key)
    if #suits > 0 then say(OF.lang.t("Good for"), table.concat(suits, ", ")) end

    local there = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local np = gNetworkPlayers[entry.localIndex]
        if np ~= nil and np.currLevelNum == place.level
            and np.currAreaIndex == place.area then
            there = there + 1
        end
    end
    if there > 0 then
        say(OF.lang.t("Standing there now"),
            OF.lang.fill("@ of @", tostring(there),
                tostring(#OF.util.connected_players())))
    end

    return { place = place, lines = lines }
end

function arena.scout(key)
    if not OF.perms.can("teleport_self") then
        return false, "Your rank cannot do that.", "teleport_self"
    end

    local place = arena.find(key)
    if place == nil then return false, "No such arena." end

    local tried = arena.custom_missing(place)
    if tried ~= nil then
        return false, OF.lang.fill("@ is not installed here. Tried: @",
            place.name, tried)
    end

    if not OF.net.warp_local(place.level, place.area, place.act) then
        return false
    end

    OF.notify.show("@ - you are there alone. The lobby has not moved.", "info", 5,
        place.name)
    return true
end

arena.PACKET_ASK = "arnask"
function arena.open(key, hazards, enemies, forRound, askerLocal)
    if not OF.perms.can("warp_lobby") then
        return false, "Your rank cannot do that.", "warp_lobby"
    end

    local place = arena.find(key)
    if place == nil then return false, "No such arena." end

    local tried = arena.custom_missing(place)
    if tried ~= nil then
        return false, OF.lang.fill("@ is not installed here. Tried: @",
            place.name, tried)
    end

    local keys
    if type(hazards) == "table" then
        keys = hazards
    else
        keys = { "bosses" }
        if hazards == true then table.insert(keys, "hazards") end
        if enemies == true then table.insert(keys, "enemies") end
    end

    if not OF.util.is_host() then

        local set = {}
        for _, k in ipairs(keys) do set[k] = true end
        if not OF.util.send_to_host({
            ofp = arena.PACKET_ASK, k = place.key,
            h = set.hazards == true, e = set.enemies == true,
            s = arena.pack(keys),
        }) then
            return false, "There is no host to ask."
        end
        return true
    end

    local send = OF.net.warp_everyone
    if forRound and OF.util.asks(OF.net, "warp_the_round") then
        send = OF.net.warp_the_round
    end
    local moved, why = send(place.level, place.area, place.act)
    if not moved then return false, why or "The lobby could not be moved." end

    arena.arm(true, keys, place.key)

    OF.notify.send_all("@ - swept clear for a fight", "info", 5, place.name)

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("opened @", OF.lang.t(place.name)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("opened the arena: @", OF.lang.t(place.name)))
    return true
end

function arena.arm(clear, hazards, enemies, place)
    local keys
    if type(hazards) == "table" then
        keys = hazards
        place = enemies
    else
        keys = {}
        if clear ~= false then table.insert(keys, "bosses") end
        if hazards == true then table.insert(keys, "hazards") end
        if enemies == true then table.insert(keys, "enemies") end
    end

    local set = {}
    for _, key in ipairs(keys) do set[key] = true end

    OF.util.publish("ofArenaClear", clear == true)

    OF.util.publish("ofArenaHazards", clear == true and set.hazards == true)
    OF.util.publish("ofArenaEnemies", clear == true and set.enemies == true)
    OF.util.publish("ofArenaSweep", clear == true and arena.pack(keys) or "")
    OF.util.publish("ofArenaPlace", clear and (place or "") or "")
    arena.sync_sweep()
end

function arena.close()
    arena.arm(false, false, false, nil)
end

local function on_packet_receive(data)
    if data == nil then return end

    if data.ofp ~= arena.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    if OF.perms.tier(asker) < OF.perms.required("warp_lobby") then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    local keys
    if type(data.s) == "string" and data.s ~= "" then
        keys = arena.unpack(data.s)
    else
        keys = { "bosses" }
        if data.h == true then table.insert(keys, "hazards") end
        if data.e == true then table.insert(keys, "enemies") end
    end

    local ok, why = arena.open(data.k, keys, nil, nil, asker)
    if not ok then
        OF.notify.send_to(askerGlobal, "@", "bad", 5, tostring(why or "Refused."))
        return
    end
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)

local function on_player_connected(m)
    if m == nil then return end
    if not network_is_server() then return end
    if m.playerIndex == 0 then return end
    if gGlobalSyncTable.ofArenaClear ~= true then return end

    local place = arena.find(gGlobalSyncTable.ofArenaPlace)
    if place == nil then return end

    local np = gNetworkPlayers[m.playerIndex]
    if np == nil or not np.connected then return end

    if arena.custom_missing(place) ~= nil then
        OF.notify.send_to(np.globalIndex,
            "The lobby is in @, which is not installed here", "warn", 6,
            place.name)
        return
    end

    OF.net.warp_player(np.globalIndex, place.level, place.area, place.act)

    OF.notify.send_to(np.globalIndex, "The lobby is in @", "info", 5, place.name)
end

hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected)

function arena.build_page(panel)
    local rows = {}

    local on = gGlobalSyncTable.ofArenaClear == true

    table.insert(rows, panel.label_row(
        OF.lang.t("Warps the lobby in and sweeps the level.")))

    for _, place in ipairs(arena.PLACES) do
        local key = place.key

        local tried = arena.custom_missing(place)
        if tried ~= nil then

            local named = panel.label_row(place.name)
            named.walk = true
            table.insert(rows, panel.with_help(named,
                "a level you exported yourself, and this machine has not got it"))

            local why = panel.label_row(
                OF.lang.fill("  not installed - tried @", tried))
            why.walk = true
            table.insert(rows, panel.with_help(why,
                "the name is the LevelScript array in the folder's script.c, not the folder"))
        else
            table.insert(rows, panel.with_help(panel.gated_row("warp_lobby",
                place.name, 255, 255, 255, function()

                    if OF.util.report(arena.open(key, arena.recommended(key),
                        nil, nil, 0)) then
                        panel.close()
                    end
                end), place.blurb))
        end
    end

    table.insert(rows, panel.with_help(panel.gated_row("warp_lobby",
        OF.lang.t("Clear the level out..."), 255, 255, 255,
        function() panel.go("sweep") end),
        OF.lang.t("the nine kinds a sweep takes, and a sweep of the level you are already in")))

    if on then

        table.insert(rows, panel.label_row(
            OF.lang.fill("Swept so far: @", tostring(arena.swept))))
    end

    table.insert(rows, panel.back_row("travel"))
    return rows
end

function arena.build_sweep_page(panel)
    local rows = {}

    local armed = arena.armed_set()
    local on = gGlobalSyncTable.ofArenaClear == true

    table.insert(rows, panel.label_row(
        OF.lang.t("Takes whole kinds of thing out of the level, on every screen.")))
    table.insert(rows, panel.label_row(
        OF.lang.t("Nothing is saved - reload the level and it is all back.")))

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("What gets swept")),
        "nine kinds of thing, each of them on or off on its own"))
    for _, option in ipairs(arena.OPTIONS) do
        local key = option.key
        local isOn = armed[key] == true
        local built = panel.gated_row("warp_lobby",
            panel.tick(isOn, OF.lang.t(option.name)),
            255, 255, 255, function()
                local keys = {}
                for other in pairs(arena.armed_set()) do
                    if other ~= key then table.insert(keys, other) end
                end
                if not isOn then table.insert(keys, key) end

                arena.arm(#keys > 0, keys, gGlobalSyncTable.ofArenaPlace)
            end)
        table.insert(rows, panel.with_help(
            panel.level_right(built, isOn, OF.lang.t("swept")), option.blurb))
    end

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("Right here")),
        "the same sweep, in whatever level the lobby is already standing in"))
    table.insert(rows, panel.with_help(panel.gated_row("warp_lobby",
        OF.lang.t("Sweep this level without moving"), 255, 255, 255, function()
            local keys = {}
            for other in pairs(arena.armed_set()) do table.insert(keys, other) end
            if #keys == 0 then keys = { "bosses" } end
            arena.arm(true, keys, nil)
            OF.notify.send_all("Clearing this level out", "info", 4)

            if OF.util.asks(OF.notify, "credit_named") then
                OF.notify.credit_named(0,
                    OF.lang.t("swept this level without moving anybody"))
            end
            OF.actionlog.by_hand(OF.util.presser(0),
                OF.lang.t("swept this level without moving anybody"))
        end),
        "arms the switches above here, with nobody warped anywhere"))
    table.insert(rows, panel.with_help(panel.gated_row("warp_lobby",
        OF.lang.t("Stop sweeping (reload to bring them back)"),
        200, 200, 200, function()
            arena.close()
            OF.notify.show("The arena sweep is off", "info", 3)
        end),
        "disarms it - what was taken away comes back on the next level load"))

    if on then

        table.insert(rows, panel.label_row(
            OF.lang.fill("Swept so far: @", tostring(arena.swept))))
    end

    table.insert(rows, panel.back_row())
    return rows
end
