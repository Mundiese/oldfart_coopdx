OF = OF or {}
OF.spawner = OF.spawner or {}

local spawner = OF.spawner

spawner.MIN_LIMIT = 10
spawner.MAX_LIMIT = 400
spawner.MAX_PER_SESSION = 100

function spawner.set_limit(value)
    if not OF.perms.can("spawn_object") then
        return false, "Your rank cannot do that.", "spawn_object"
    end
    local wanted = tonumber(value)
    if wanted == nil then return false, "Give the limit a number." end
    spawner.MAX_PER_SESSION = OF.util.clamp(math.floor(wanted),
        spawner.MIN_LIMIT, spawner.MAX_LIMIT)
    return true
end

spawner.objects = {}

function spawner.count()
    local alive = {}
    for _, object in ipairs(spawner.objects) do
        if object ~= nil and object.activeFlags ~= 0 then
            table.insert(alive, object)
        end
    end
    spawner.objects = alive
    return #alive
end

local reapply = {}

local function settle_log(o, x, y, z)

    o.oPitouneUnkF8 = x
    o.oPitouneUnkFC = z
end

local LIFT_DROP = 512.0

local function settle_lift(o, x, y, z)
    o.oElevatorUnkF8 = y
    o.oElevatorUnkF4 = y - LIFT_DROP
    o.oElevatorUnkFC = (o.oElevatorUnkF4 + o.oElevatorUnkF8) / 2
end

local REAPPLY_FRAMES = 6

hook_event(HOOK_UPDATE, function()
    if #reapply == 0 then return end
    local still = {}
    for _, owed in ipairs(reapply) do
        local o = owed.object
        if o ~= nil and o.activeFlags ~= 0 then
            if owed.reach ~= nil then o.oCollisionDistance = owed.reach end

            if owed.settle ~= nil then
                owed.settle(o, owed.x, owed.y, owed.z)
            end
            owed.frames = owed.frames - 1
            if owed.frames > 0 then table.insert(still, owed) end
        end
    end
    reapply = still
end)

local DISTANCE = 300

local function no_setup(o) end

local STANDING_REACH = 20000

local function params_of(entry)
    local variant = spawner.chosen(entry)
    local second = variant ~= nil and variant.value or entry.variant
    local first = variant ~= nil and variant.first or nil
    if type(second) ~= "number" and type(first) ~= "number" then return nil end

    local params = 0
    if type(second) == "number" then params = params + ((second & 0xFF) << 16) end

    if type(first) == "number" then
        params = params + ((math.floor(first) & 0xFF) << 24)
    end
    return params
end

local function second_of(entry)
    local variant = spawner.chosen(entry)
    local second = variant ~= nil and variant.value or entry.variant
    if type(second) ~= "number" then return nil end

    return math.floor(second)
end

function spawner.face(object, yaw)
    if object == nil or type(yaw) ~= "number" then return false end
    object.oFaceAngleYaw = yaw
    object.oMoveAngleYaw = yaw
    return true
end

spawner.SIZELESS = {
    boulder = true, chuckya = true, exclam = true, heaveho = true,
    shell = true, blueswitch = true, turntable = true,
    goomba = true, blizzard = true, snufit = true,
    firepiranha = true, tweester = true,
}

function spawner.keeps_size(key)
    return spawner.SIZELESS[key] ~= true
end

spawner.MINTS_STAR = {
    kingbobomb = true, whompking = true, bigbully = true,
    wiggler = true, mips = true, bowser = true, bigchill = true,
    firepiranha = true,
}

spawner.EDITS_SAVE = {
    capswitch = true,
}

function spawner.edits_save(key)
    return spawner.EDITS_SAVE[key] == true
end

function spawner.mints_star(key)
    return spawner.MINTS_STAR[key] == true
end

local chosenVariant = {}

function spawner.variants(key)
    local entry = spawner.find(key)
    if entry == nil then return nil end
    return entry.variants
end

function spawner.chosen(entry)
    if entry == nil or entry.variants == nil then return nil end
    local index = chosenVariant[entry.key] or 1
    return entry.variants[index] or entry.variants[1]
end

function spawner.variant_name(key)
    local variant = spawner.chosen(spawner.find(key))
    if variant == nil then return nil end
    return variant.name
end

function spawner.next_variant(key, step)
    local entry = spawner.find(key)
    if entry == nil or entry.variants == nil then return false end
    local count = #entry.variants
    if count <= 1 then return false end
    local index = (chosenVariant[entry.key] or 1) + (step or 1) - 1
    chosenVariant[entry.key] = (index % count) + 1
    return true
end

function spawner.pick_variant(key, value)
    local entry = spawner.find(key)
    if entry == nil or entry.variants == nil then return nil end
    if type(value) ~= "number" then return nil end
    for index, variant in ipairs(entry.variants) do
        if variant.value == (math.floor(value) & 0xFF) then
            chosenVariant[entry.key] = index
            return variant.name
        end
    end
    return nil
end

function spawner.forget_variants()
    chosenVariant = {}
end

local FURNITURE = {

    { key = "seesaw",   name = "Seesaw",         bhv = id_bhvSeesawPlatform,
      model = E_MODEL_BOB_SEESAW_PLATFORM, reach = STANDING_REACH,
      variants = {
          { name = "wooden bridge", value = 3, model = E_MODEL_BOB_SEESAW_PLATFORM },
          { name = "dark plank", value = 0, model = E_MODEL_BITDW_SEESAW_PLATFORM },
          { name = "fire plank", value = 4, model = E_MODEL_BITFS_SEESAW_PLATFORM },
          { name = "sky plank", value = 1, model = E_MODEL_BITS_SEESAW_PLATFORM },
          { name = "sky S-bend", value = 2, model = E_MODEL_BITS_TILTING_W_PLATFORM },
          { name = "rainbow plank", value = 5, model = E_MODEL_RR_SEESAW_PLATFORM },
          { name = "cloud plank", value = 7, model = E_MODEL_VCUTM_SEESAW_PLATFORM },
      } },

    { key = "turntable", name = "Turntable",     bhv = id_bhvRotatingPlatform,
      model = E_MODEL_WF_ROTATING_PLATFORM, reach = STANDING_REACH,
      variants = {
          { name = "slow", value = 0, first = 8, model = E_MODEL_WF_ROTATING_PLATFORM },
          { name = "slow, backwards", value = 0, first = -8,
            model = E_MODEL_WF_ROTATING_PLATFORM },
          { name = "fast", value = 1, first = 70, model = E_MODEL_WDW_ROTATING_PLATFORM },
          { name = "fast, backwards", value = 1, first = -70,
            model = E_MODEL_WDW_ROTATING_PLATFORM },
      } },
    { key = "swingplat", name = "Swinging platform", bhv = id_bhvSwingPlatform,
      model = E_MODEL_RR_SWINGING_PLATFORM, reach = STANDING_REACH },

    { key = "ttccog",   name = "Clock cog",      bhv = id_bhvTTCCog,
      model = E_MODEL_TTC_ROTATING_HEXAGON, reach = STANDING_REACH,
      variants = {
          { name = "hexagon", value = 0, model = E_MODEL_TTC_ROTATING_HEXAGON },
          { name = "triangle", value = 2, model = E_MODEL_TTC_ROTATING_TRIANGLE },
      } },
    { key = "ttcgear",  name = "Clock gear",     bhv = id_bhvTTC2DRotator,
      model = E_MODEL_TTC_SMALL_GEAR, reach = STANDING_REACH,
      variants = {
          { name = "small gear", value = 1, model = E_MODEL_TTC_SMALL_GEAR },
          { name = "large gear", value = 1, model = E_MODEL_TTC_LARGE_GEAR },
          { name = "clock hand", value = 0, model = E_MODEL_TTC_CLOCK_HAND },
      } },
    { key = "ttcsolid", name = "Turning block",  bhv = id_bhvTTCRotatingSolid,
      model = E_MODEL_TTC_ROTATING_CUBE, reach = STANDING_REACH,
      variants = {
          { name = "cube", value = 0, model = E_MODEL_TTC_ROTATING_CUBE },
          { name = "prism", value = 1, model = E_MODEL_TTC_ROTATING_PRISM },
      } },
    { key = "ttctread", name = "Treadmill",      bhv = id_bhvTTCTreadmill,
      model = E_MODEL_TTC_LARGE_TREADMILL, reach = STANDING_REACH,
      variants = {
          { name = "large", value = 0, model = E_MODEL_TTC_LARGE_TREADMILL },
          { name = "small", value = 1, model = E_MODEL_TTC_SMALL_TREADMILL },
          { name = "large, reversed", value = 2, model = E_MODEL_TTC_LARGE_TREADMILL },
          { name = "small, reversed", value = 3, model = E_MODEL_TTC_SMALL_TREADMILL },
      } },

    { key = "ttcpend",  name = "Pendulum",       bhv = id_bhvTTCPendulum,
      model = E_MODEL_TTC_PENDULUM, reach = STANDING_REACH },
    { key = "ttcbar",   name = "Push bar",       bhv = id_bhvTTCMovingBar,
      model = E_MODEL_TTC_PUSH_BLOCK, reach = STANDING_REACH },

    { key = "ttcpit",   name = "Pit block",      bhv = id_bhvTTCPitBlock,
      model = E_MODEL_TTC_PIT_BLOCK, reach = STANDING_REACH },
    { key = "ttcspin",  name = "Spinner",        bhv = id_bhvTTCSpinner,
      model = E_MODEL_TTC_SPINNER, reach = STANDING_REACH },
    { key = "ttclift",  name = "Clock lift",     bhv = id_bhvTTCElevator,
      model = E_MODEL_TTC_ELEVATOR_PLATFORM, reach = STANDING_REACH },

    { key = "tugplat",  name = "Tilting floor",  bhv = id_bhvBbhTiltingTrapPlatform,
      model = E_MODEL_BBH_TILTING_FLOOR_PLATFORM, reach = STANDING_REACH },

    { key = "octaplat", name = "Turning octagon", bhv = id_bhvOctagonalPlatformRotating,
      model = E_MODEL_RR_OCTAGONAL_PLATFORM, reach = STANDING_REACH,
      variants = {
          { name = "rainbow octagon", value = 1, first = 0,
            model = E_MODEL_RR_OCTAGONAL_PLATFORM },
          { name = "rainbow octagon, spinning back", value = 1, first = 3,
            model = E_MODEL_RR_OCTAGONAL_PLATFORM },
          { name = "sky octagon", value = 0, first = 0,
            model = E_MODEL_BITS_OCTAGONAL_PLATFORM },
          { name = "sky octagon, spinning fast", value = 0, first = 2,
            model = E_MODEL_BITS_OCTAGONAL_PLATFORM },
      } },
    { key = "hexring",  name = "Turning ring",   bhv = id_bhvLllRotatingHexagonalRing,
      model = E_MODEL_LLL_ROTATING_HEXAGONAL_RING, reach = STANDING_REACH },
    { key = "meshplat", name = "Moving mesh",    bhv = id_bhvLllMovingOctagonalMeshPlatform,
      model = E_MODEL_LLL_MOVING_OCTAGONAL_MESH_PLATFORM, reach = STANDING_REACH },
    { key = "tiltplat", name = "Tilting square", bhv = id_bhvLllTiltingInvertedPyramid,
      model = E_MODEL_LLL_TILTING_SQUARE_PLATFORM, reach = STANDING_REACH },

    { key = "lavaplat", name = "Lava arena",     bhv = id_bhvTiltingBowserLavaPlatform,
      model = E_MODEL_BOWSER_2_TILTING_ARENA, reach = STANDING_REACH },
    { key = "elevator", name = "Elevator",       bhv = id_bhvAnotherElavator,
      model = E_MODEL_HMC_ELEVATOR_PLATFORM, reach = STANDING_REACH },

    { key = "ferris",   name = "Ferris wheel",   bhv = id_bhvFerrisWheelAxle,
      model = E_MODEL_BITDW_FERRIS_WHEEL_AXLE, reach = STANDING_REACH },

    { key = "trapdoor", name = "Trapdoor",       bhv = id_bhvCastleFloorTrap,
      model = E_MODEL_CASTLE_BOWSER_TRAP, reach = STANDING_REACH },

    { key = "firebar",  name = "Fire bar block", bhv = id_bhvLllRotatingBlockWithFireBars,
      model = E_MODEL_LLL_ROTATING_BLOCK_FIRE_BARS, reach = STANDING_REACH },
    { key = "grindel",  name = "Grindel",        bhv = id_bhvGrindel,
      model = E_MODEL_SSL_GRINDEL, reach = STANDING_REACH },
    { key = "spindel",  name = "Spindel",        bhv = id_bhvSpindel,
      model = E_MODEL_SSL_SPINDEL, reach = STANDING_REACH },
    { key = "toxbox",   name = "Tox Box",        bhv = id_bhvToxBox,
      model = E_MODEL_SSL_TOX_BOX, reach = STANDING_REACH },

    { key = "pillar",   name = "Falling pillar", bhv = id_bhvFallingPillar,
      model = E_MODEL_JRB_FALLING_PILLAR, solid = false },

    { key = "grindelh", name = "Sliding Grindel", bhv = id_bhvHorizontalGrindel,
      model = E_MODEL_SSL_GRINDEL, reach = STANDING_REACH },

    { key = "boulder",  name = "Boulder",        bhv = id_bhvBigBoulder,
      model = E_MODEL_HMC_ROLLING_ROCK, solid = false,
      variants = {
          { name = "keeps rolling", value = 0, model = E_MODEL_HMC_ROLLING_ROCK },
          { name = "shatters on a wall", value = 2, model = E_MODEL_HMC_ROLLING_ROCK },
      } },

    { key = "homingamp", name = "Homing Amp",    bhv = id_bhvHomingAmp,
      model = E_MODEL_AMP, solid = false },

    { key = "fireball", name = "Fireball vent",  bhv = id_bhvBouncingFireball,
      model = E_MODEL_NONE, solid = false },
    { key = "snowvent", name = "Snow mound vent", bhv = id_bhvSnowMoundSpawn,
      model = E_MODEL_NONE, solid = false },

    { key = "checkplat", name = "Solid platform", bhv = id_bhvStaticCheckeredPlatform,
      model = E_MODEL_CHECKERBOARD_PLATFORM, reach = STANDING_REACH },

    { key = "arrowlift", name = "Arrow lift",     bhv = id_bhvArrowLift,
      model = E_MODEL_WDW_ARROW_LIFT, reach = STANDING_REACH },

    { key = "firebridge", name = "Fire bridge",   bhv = id_bhvRrRotatingBridgePlatform,
      model = E_MODEL_RR_ROTATING_BRIDGE_PLATFORM, reach = STANDING_REACH },

    { key = "sinkplat", name = "Sinking platform", bhv = id_bhvBitfsSinkingPlatforms,
      model = E_MODEL_BITFS_SINKING_PLATFORMS, reach = STANDING_REACH },

    { key = "squishplat", name = "Squishing platform", bhv = id_bhvSquishablePlatform,
      model = E_MODEL_BITFS_STRETCHING_PLATFORMS, reach = STANDING_REACH },

    { key = "towerlift", name = "Tower lift",     bhv = id_bhvWfElevatorTowerPlatform,
      model = E_MODEL_WF_TOWER_SQUARE_PLATORM_ELEVATOR, reach = STANDING_REACH },

    { key = "tumbling", name = "Tumbling bridge", bhv = id_bhvBbhTumblingBridge,
      model = E_MODEL_BBH_TUMBLING_PLATFORM, reach = STANDING_REACH },

    { key = "purpleswitch", name = "Purple switch", bhv = id_bhvFloorSwitchHardcodedModel,
      model = E_MODEL_PURPLE_SWITCH, reach = STANDING_REACH },

    { key = "donut",    name = "Falling platform", bhv = id_bhvDonutPlatform,
      model = E_MODEL_RR_DONUT_PLATFORM, reach = STANDING_REACH },

    { key = "risewall", name = "Rising wall",     bhv = id_bhvSslMovingPyramidWall,
      model = E_MODEL_SSL_MOVING_PYRAMID_WALL, reach = STANDING_REACH,
      variants = {
          { name = "starts high", value = 0, model = E_MODEL_SSL_MOVING_PYRAMID_WALL },
          { name = "starts halfway", value = 1, model = E_MODEL_SSL_MOVING_PYRAMID_WALL },
          { name = "starts low", value = 2, model = E_MODEL_SSL_MOVING_PYRAMID_WALL },
      } },

    { key = "rrlift",   name = "Rising lift",     bhv = id_bhvRrElevatorPlatform,
      model = E_MODEL_RR_ELEVATOR_PLATFORM, reach = STANDING_REACH,
      settle = settle_lift },

    { key = "cageplat", name = "Bobbing cage",    bhv = id_bhvBitfsSinkingCagePlatform,
      model = E_MODEL_BITFS_SINKING_CAGE_PLATFORM, reach = STANDING_REACH,
      variants = {
          { name = "at your reach", value = 0,
            model = E_MODEL_BITFS_SINKING_CAGE_PLATFORM },
          { name = "a drop lower", value = 1,
            model = E_MODEL_BITFS_SINKING_CAGE_PLATFORM },
      } },

    { key = "rockblock", name = "Sinking block", bhv = id_bhvLllSinkingRockBlock,
      model = E_MODEL_LLL_SINKING_ROCK_BLOCK, reach = STANDING_REACH },

    { key = "fallwall", name = "Falling wall",   bhv = id_bhvLllVolcanoFallingTrap,
      model = E_MODEL_LLL_VOLCANO_FALLING_TRAP, reach = STANDING_REACH },

    { key = "logroll",  name = "Rolling log",    bhv = id_bhvLllRollingLog,
      model = E_MODEL_LLL_ROLLING_LOG, reach = STANDING_REACH, settle = settle_log },
    { key = "logwide",  name = "Wide rolling log", bhv = id_bhvTtmRollingLog,
      model = E_MODEL_TTM_ROLLING_LOG, reach = STANDING_REACH, settle = settle_log },

    { key = "raft",     name = "Floating raft",  bhv = id_bhvJrbFloatingPlatform,
      model = E_MODEL_JRB_FLOATING_PLATFORM, reach = STANDING_REACH },
    { key = "floatplat", name = "Floating platform", bhv = id_bhvWdwSquareFloatingPlatform,
      model = E_MODEL_WDW_SQUARE_FLOATING_PLATFORM, reach = STANDING_REACH },

    { key = "kickboard", name = "Kickable board", bhv = id_bhvKickableBoard,
      model = E_MODEL_WF_KICKABLE_BOARD, reach = STANDING_REACH },

    { key = "pole",     name = "Climbing pole",  bhv = id_bhvPoleGrabbing,
      model = E_MODEL_DDD_POLE, variant = 80, solid = false },

    { key = "capswitch", name = "Cap switch",    bhv = id_bhvCapSwitch,
      model = E_MODEL_CAP_SWITCH, reach = STANDING_REACH,
      variants = {
          { name = "wing cap", value = 0, model = E_MODEL_CAP_SWITCH },
          { name = "metal cap", value = 1, model = E_MODEL_CAP_SWITCH },
          { name = "vanish cap", value = 2, model = E_MODEL_CAP_SWITCH },
      } },

}

spawner.LIST = {
    { key = "goomba",   name = "Goomba",         bhv = id_bhvGoomba,        model = E_MODEL_GOOMBA },
    { key = "bobomb",   name = "Bob-omb",        bhv = id_bhvBobomb,        model = E_MODEL_BLACK_BOBOMB },
    { key = "koopa",    name = "Koopa",          bhv = id_bhvKoopa,         model = E_MODEL_KOOPA_WITH_SHELL },
    { key = "bully",    name = "Bully",          bhv = id_bhvSmallBully,    model = E_MODEL_BULLY },
    { key = "chuckya",  name = "Chuckya",        bhv = id_bhvChuckya,       model = E_MODEL_CHUCKYA },
    { key = "amp",      name = "Amp",            bhv = id_bhvCirclingAmp,   model = E_MODEL_AMP },
    { key = "bulletbill", name = "Bullet Bill",  bhv = id_bhvBulletBill,    model = E_MODEL_BULLET_BILL },

    { key = "1up",      name = "1-Up",           bhv = id_bhv1Up,           model = E_MODEL_1UP },
    { key = "coin",     name = "Coin",           bhv = id_bhvSingleCoinGetsSpawned, model = E_MODEL_YELLOW_COIN },
    { key = "bluecoin", name = "Blue coin",      bhv = id_bhvBlueCoinJumping, model = E_MODEL_BLUE_COIN },
    { key = "box",      name = "Breakable box",  bhv = id_bhvBreakableBox,  model = E_MODEL_BREAKABLE_BOX },
    { key = "exclam",   name = "Exclamation box", bhv = id_bhvExclamationBox, model = E_MODEL_EXCLAMATION_BOX },
    { key = "shell",    name = "Koopa shell",    bhv = id_bhvKoopaShell,    model = E_MODEL_KOOPA_SHELL },

    { key = "tree",     name = "Tree",           bhv = id_bhvTree,
      model = E_MODEL_BUBBLY_TREE,
      variants = {
          { name = "leafy", value = 0, model = E_MODEL_BUBBLY_TREE },
          { name = "palm", value = 0, model = E_MODEL_PALM_TREE },
          { name = "snowy", value = 0, model = E_MODEL_SNOW_TREE },
          { name = "spiky", value = 0, model = E_MODEL_COURTYARD_SPIKY_TREE },
      } },

    { key = "chainchomp", name = "Chain Chomp",  bhv = id_bhvChainChomp,    model = E_MODEL_CHAIN_CHOMP },

    { key = "thwomp",   name = "Thwomp",         bhv = id_bhvThwomp,
      model = E_MODEL_THWOMP,
      variants = {
          { name = "low", value = 0, model = E_MODEL_THWOMP },
          { name = "high", value = 60, model = E_MODEL_THWOMP },
          { name = "very high", value = 140, model = E_MODEL_THWOMP },
      } },
    { key = "piranha",  name = "Piranha Plant",  bhv = id_bhvPiranhaPlant,  model = E_MODEL_PIRANHA_PLANT },
    { key = "pokey",    name = "Pokey",          bhv = id_bhvPokey,         model = E_MODEL_POKEY_HEAD },
    { key = "spindrift", name = "Spindrift",     bhv = id_bhvSpindrift,     model = E_MODEL_SPINDRIFT },
    { key = "blizzard", name = "Mr. Blizzard",   bhv = id_bhvMrBlizzard,    model = E_MODEL_MR_BLIZZARD },
    { key = "boo",      name = "Boo",            bhv = id_bhvBoo,           model = E_MODEL_BOO },
    { key = "scuttlebug", name = "Scuttlebug",   bhv = id_bhvScuttlebug,    model = E_MODEL_SCUTTLEBUG },
    { key = "swoop",    name = "Swoop",          bhv = id_bhvSwoop,         model = E_MODEL_SWOOP },
    { key = "heaveho",  name = "Heave-Ho",       bhv = id_bhvHeaveHo,       model = E_MODEL_HEAVE_HO },
    { key = "flyguy",   name = "Fly Guy",        bhv = id_bhvFlyGuy,        model = E_MODEL_FLYGUY },
    { key = "lakitu",   name = "Lakitu",         bhv = id_bhvEnemyLakitu,   model = E_MODEL_ENEMY_LAKITU },
    { key = "snufit",   name = "Snufit",         bhv = id_bhvSnufit,        model = E_MODEL_SNUFIT },
    { key = "klepto",   name = "Klepto",         bhv = id_bhvKlepto,        model = E_MODEL_KLEPTO },
    { key = "moneybag", name = "Moneybag",       bhv = id_bhvMoneybag,      model = E_MODEL_MONEYBAG },
    { key = "unagi",    name = "Unagi",          bhv = id_bhvUnagi,         model = E_MODEL_UNAGI },
    { key = "bubba",    name = "Bubba",          bhv = id_bhvBubba,         model = E_MODEL_BUBBA },
    { key = "mrI",      name = "Mr. I",          bhv = id_bhvMrI,           model = E_MODEL_MR_I },
    { key = "waterbomb", name = "Water bomb",    bhv = id_bhvWaterBomb,     model = E_MODEL_WATER_BOMB },

    { key = "fire",     name = "Bouncing flame", bhv = id_bhvBouncingFireballFlame, model = E_MODEL_RED_FLAME },
    { key = "firespitter", name = "Fire spitter", bhv = id_bhvFireSpitter,  model = E_MODEL_RED_FLAME },

    { key = "kingbobomb", name = "King Bob-omb", bhv = id_bhvKingBobomb,    model = E_MODEL_KING_BOBOMB },
    { key = "whompking", name = "King Whomp",    bhv = id_bhvWhompKingBoss, model = E_MODEL_WHOMP },
    { key = "bigbully", name = "Big Bully",      bhv = id_bhvBigBully,      model = E_MODEL_BULLY_BOSS },
    { key = "wiggler",  name = "Wiggler",        bhv = id_bhvWigglerHead,   model = E_MODEL_WIGGLER_HEAD },
    { key = "bowser",   name = "Bowser",         bhv = id_bhvBowser,        model = E_MODEL_BOWSER },

    { key = "mips",     name = "MIPS the rabbit", bhv = id_bhvMips,         model = E_MODEL_MIPS },
    { key = "yoshi",    name = "Yoshi",          bhv = id_bhvYoshi,         model = E_MODEL_YOSHI },
    { key = "redcoin",  name = "Red coin",       bhv = id_bhvRedCoin,       model = E_MODEL_RED_COIN },
    { key = "heart",    name = "Spinning heart", bhv = id_bhvRecoveryHeart, model = E_MODEL_HEART },
    { key = "1upwalk",  name = "Running 1-Up",   bhv = id_bhv1upWalking,    model = E_MODEL_1UP },
    { key = "wingcap",  name = "Wing cap",       bhv = id_bhvNormalCap,     model = E_MODEL_MARIOS_WING_CAP },
    { key = "metalbox", name = "Pushable metal box", bhv = id_bhvPushableMetalBox, model = E_MODEL_METAL_BOX },
    { key = "woodpost", name = "Wooden post",    bhv = id_bhvWoodenPost,    model = E_MODEL_WOODEN_POST },
    { key = "cannon",   name = "Cannon",         bhv = id_bhvCannonBarrel,  model = E_MODEL_CANNON_BARREL },
    { key = "blueswitch", name = "Blue coin switch", bhv = id_bhvBlueCoinSwitch, model = E_MODEL_BLUE_COIN_SWITCH },

    { key = "checkers", name = "Checkerboard lift", bhv = id_bhvCheckerboardElevatorGroup, model = E_MODEL_CHECKERBOARD_PLATFORM },

    { key = "spiny",    name = "Spiny",          bhv = id_bhvSpiny,        model = E_MODEL_SPINY },

    { key = "skeeter",  name = "Skeeter",        bhv = id_bhvSkeeter,      model = E_MODEL_SKEETER },

    { key = "bookend",  name = "Flying book",    bhv = id_bhvFlyingBookend, model = E_MODEL_BOOKEND },

    { key = "piano",    name = "Mad Piano",      bhv = id_bhvMadPiano,     model = E_MODEL_MAD_PIANO },
    { key = "chair",    name = "Haunted chair",  bhv = id_bhvHauntedChair, model = E_MODEL_HAUNTED_CHAIR },

    { key = "penguin",  name = "Baby penguin",   bhv = id_bhvSmallPenguin, model = E_MODEL_PENGUIN },

    { key = "bub",      name = "Bub",            bhv = id_bhvBub,          model = E_MODEL_BUB },
    { key = "clam",     name = "Clam",           bhv = id_bhvClamShell,    model = E_MODEL_CLAM_SHELL },

    { key = "flamejet", name = "Flamethrower",   bhv = id_bhvFlamethrower, model = E_MODEL_NONE },

    { key = "molehole", name = "Mole hole",      bhv = id_bhvMontyMoleHole, model = E_MODEL_DL_MONTY_MOLE_HOLE },
    { key = "montymole", name = "Monty Mole",    bhv = id_bhvMontyMole,    model = E_MODEL_MONTY_MOLE },

    { key = "bowling",  name = "Bowling ball",   bhv = id_bhvBowlingBall,  model = E_MODEL_BOWLING_BALL },

    { key = "tweester", name = "Tornado",        bhv = id_bhvTweester,
      model = E_MODEL_TWEESTER,
      variants = {
          { name = "roams", value = 18, model = E_MODEL_TWEESTER },
          { name = "roams wide", value = 25, model = E_MODEL_TWEESTER },
      } },

    { key = "whomp",    name = "Whomp",          bhv = id_bhvSmallWhomp,   model = E_MODEL_WHOMP },

    { key = "chillbully", name = "Chill Bully",  bhv = id_bhvSmallChillBully,
      model = E_MODEL_CHILL_BULLY },

    { key = "bigchill", name = "Big Chill Bully", bhv = id_bhvBigChillBully,
      model = E_MODEL_BIG_CHILL_BULLY },

    { key = "firepiranha", name = "Fire Piranha Plant", bhv = id_bhvFirePiranhaPlant,
      model = E_MODEL_PIRANHA_PLANT,
      variants = {
          { name = "small", value = 0, model = E_MODEL_PIRANHA_PLANT },
          { name = "giant", value = 1, model = E_MODEL_PIRANHA_PLANT },
      } },

    { key = "smallbox", name = "Small box",      bhv = id_bhvBreakableBoxSmall,
      model = E_MODEL_BREAKABLE_BOX_SMALL },

    { key = "coins",    name = "Coins",          bhv = id_bhvCoinFormation, model = E_MODEL_NONE,
      variants = {
          { name = "a line", value = 0x10, model = E_MODEL_NONE },
          { name = "a column", value = 1, model = E_MODEL_NONE },
          { name = "a ring", value = 0x12, model = E_MODEL_NONE },
          { name = "an arch", value = 3, model = E_MODEL_NONE },
          { name = "an arrow", value = 0x14, model = E_MODEL_NONE },
      } },
}

for _, entry in ipairs(FURNITURE) do
    entry.furniture = true
    table.insert(spawner.LIST, entry)
end

spawner.CHILDREN = {
    cageplat = id_bhvDddMovingPole,
    capswitch = id_bhvCapSwitchBase,
    coins = id_bhvCoinFormationSpawn,
}

local CHILD_WALK_LIMIT = 512

local function reap_children(bhv, parent)
    if bhv == nil then return 0 end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return 0 end

    local doomed = {}
    local object = obj_get_first_with_behavior_id(bhv)
    local guard = 0
    while object ~= nil and guard < CHILD_WALK_LIMIT do
        local mine = object.parentObj
        if parent ~= nil then
            if mine == parent then table.insert(doomed, object) end
        elseif mine ~= nil and mine ~= object and mine.activeFlags == 0 then
            table.insert(doomed, object)
        end
        object = obj_get_next_with_same_behavior_id(object)
        guard = guard + 1
    end

    for _, child in ipairs(doomed) do obj_mark_for_deletion(child) end
    return #doomed
end

function spawner.take_down(object, key)
    if object == nil then return false end
    local child = key ~= nil and spawner.CHILDREN[key] or nil
    if child ~= nil then reap_children(child, object) end
    obj_mark_for_deletion(object)
    return true
end

local ORPHAN_EVERY = 30
local orphanTick = 0

hook_event(HOOK_UPDATE, function()
    orphanTick = orphanTick + 1
    if orphanTick < ORPHAN_EVERY then return end
    orphanTick = 0
    for _, bhv in pairs(spawner.CHILDREN) do
        reap_children(bhv, nil)
    end
end)

local CLEARABLE = {
    bosses = true, hazards = true, enemies = true,
}

local clearSerial = 0

local function list_for(kind)
    if kind == "bosses" then return OF.arena.BOSSES end
    if kind == "hazards" then return OF.arena.HAZARDS end
    if kind == "enemies" then return OF.arena.ENEMIES end
    return nil
end

function spawner.clear_here(kind)
    local list = list_for(kind)
    if list == nil then return 0 end
    return OF.arena.sweep_list(list)
end

function spawner.clear_kind(kind)
    if not OF.perms.can("spawn_object") then
        return false, "Your rank cannot do that.", "spawn_object"
    end
    if CLEARABLE[kind] == nil then return false, "No such thing to clear." end
    if not OF.util.is_host() then
        return false, "Only the host can clear the level for everybody."
    end

    clearSerial = clearSerial + 1
    OF.util.publish("ofClearNow", kind .. ":" .. clearSerial)
    return true
end

hook_on_sync_table_change(gGlobalSyncTable, "ofClearNow", 0, function()
    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofClearNow") then
        return
    end
    local packed = gGlobalSyncTable.ofClearNow
    if type(packed) ~= "string" or packed == "" then return end
    local kind = string.match(packed, "^(%a+):%d+$")
    if kind == nil then return end
    spawner.clear_here(kind)
end)

function spawner.find(key)
    for _, entry in ipairs(spawner.LIST) do
        if entry.key == key then return entry end
    end
    return nil
end

local function spot_in_front(m)
    local angle = m.faceAngle.y
    return m.pos.x + sins(angle) * DISTANCE,
           m.pos.y + 80,
           m.pos.z + coss(angle) * DISTANCE
end

function spawner.spawn_at(key, x, y, z)
    if not OF.util.allowed("spawn_object") then return nil end

    local entry = spawner.find(key)
    if entry == nil then return nil end

    if spawner.count() >= spawner.MAX_PER_SESSION then
        OF.notify.show("Spawn limit reached (@)", "warn", nil, spawner.MAX_PER_SESSION)
        return nil
    end

    local setup = no_setup
    if entry.reach ~= nil or entry.variant ~= nil or entry.variants ~= nil then
        setup = function(o)
            if entry.reach ~= nil then o.oCollisionDistance = entry.reach end

            local second = second_of(entry)
            if second ~= nil then o.oBehParams2ndByte = second end
            local params = params_of(entry)
            if params ~= nil then o.oBehParams = params end
        end
    end

    local variant = spawner.chosen(entry)
    local model = (variant ~= nil and variant.model) or entry.model

    local object = spawn_sync_object(entry.bhv, model, x, y, z, setup)
    if object == nil then

        local me = gNetworkPlayers[0]
        if me ~= nil and not me.currAreaSyncValid then
            OF.notify.show("The level is still loading - try again in a second",
                "warn", 4)
        else
            OF.notify.show("The game refused to spawn that here", "warn")
        end
        return nil
    end

    table.insert(spawner.objects, object)

    if entry.reach ~= nil or entry.settle ~= nil then
        table.insert(reapply, { object = object, reach = entry.reach,
                                settle = entry.settle, x = x, y = y, z = z,
                                frames = REAPPLY_FRAMES })
    end

    return object, entry
end

spawner.HOLDABLE = {
    bobomb = true, box = true, exclam = true, waterbomb = true,
    metalbox = true, koopa = true, shell = true, penguin = true,

    smallbox = true,
}

function spawner.can_hold(key)
    return spawner.HOLDABLE[key] == true
end

function spawner.spawn_into_hands(key)
    if not spawner.can_hold(key) then
        return false, "That is not something you can carry."
    end

    local m = gMarioStates[0]
    if m == nil then return false end
    if m.heldObj ~= nil then
        return false, "Your hands are full."
    end

    local object = spawner.spawn_at(key, m.pos.x, m.pos.y + 40, m.pos.z)
    if object == nil then return false end

    object.oInteractType = INTERACT_GRABBABLE
    object.oHeldState = HELD_FREE

    local holdable = 0x0400
    if not OF.util.has_flag(tonumber(object.oFlags) or 0, holdable) then
        object.oFlags = (tonumber(object.oFlags) or 0) + holdable
    end
    m.usedObj = object
    mario_grab_used_object(m)

    if m.heldObj == nil then

        return false, "The game would not let you hold that."
    end

    set_mario_action(m, ACT_PICKING_UP, 0)
    return true
end

local FIRE_SPEED = 55
local FIRE_LIFT = 28

function spawner.shoot_fire()
    local m = gMarioStates[0]
    if m == nil then return false end

    local angle = m.faceAngle.y
    local object = spawner.spawn_at("fire",
        m.pos.x + sins(angle) * 120,
        m.pos.y + 60,
        m.pos.z + coss(angle) * 120)
    if object == nil then return false end

    object.oMoveAngleYaw = angle
    object.oFaceAngleYaw = angle
    object.oAction = 1
    object.oTimer = 0
    object.oForwardVel = FIRE_SPEED
    object.oVelY = FIRE_LIFT
    return true
end

local RING_MOST = 12

local FULL_TURN = 0x10000

function spawner.ring(key, count, radius, at)
    local entry = spawner.find(key)
    if entry == nil then return 0, 0 end

    local wanted = math.floor(OF.util.clamp(tonumber(count) or 1, 1, RING_MOST))
    local out = tonumber(radius) or DISTANCE

    local centre = at
    if centre == nil then
        local m = gMarioStates[0]
        if m == nil then return 0, 0 end
        centre = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
    end

    local placed = 0
    for index = 1, wanted do
        local angle = math.floor(FULL_TURN * (index - 1) / wanted) % FULL_TURN
        local object = spawner.spawn_at(key,
            centre.x + sins(angle) * out,
            centre.y,
            centre.z + coss(angle) * out)

        if object == nil then break end
        placed = placed + 1

        spawner.face(object, (angle + math.floor(FULL_TURN / 2)) % FULL_TURN)
    end
    return placed, wanted
end

local SAMPLE_EVERY = 6
local TRAIL_STEPS = 30

local trail = {}
local trailTick = 0
local echoCursor = 0

function spawner.forget_trails()
    trail = {}
    echoCursor = 0
end

local function coming_back(action)
    local group = OF.util.action_group(action)
    return group ~= nil and group == OF.util.action_group(ACT_GROUP_CUTSCENE)
end

local function sample_trails()
    trailTick = trailTick + 1
    if trailTick < SAMPLE_EVERY then return end
    trailTick = 0

    for _, player in ipairs(OF.util.connected_players()) do
        local index = player.localIndex
        local kept = trail[index]
        if kept == nil then
            kept = { x = {}, y = {}, z = {}, at = 0, filled = 0 }
            trail[index] = kept
        end

        local m = gMarioStates[index]
        if m == nil or coming_back(m.action) then
            kept.filled = 0
        else
            local at = (kept.at % TRAIL_STEPS) + 1
            kept.at = at
            kept.x[at], kept.y[at], kept.z[at] = m.pos.x, m.pos.y, m.pos.z
            if kept.filled < TRAIL_STEPS then kept.filled = kept.filled + 1 end
        end
    end
end

hook_event(HOOK_UPDATE, sample_trails)

function spawner.echo_spot(localIndex)
    local kept = trail[localIndex]
    if kept == nil or kept.filled < TRAIL_STEPS then return nil end
    local oldest = (kept.at % TRAIL_STEPS) + 1
    return kept.x[oldest], kept.y[oldest], kept.z[oldest]
end

function spawner.spawn_echo(key)
    if spawner.find(key) == nil then return false, "No such thing to spawn." end

    local others, mine = {}, nil
    for _, player in ipairs(OF.util.connected_players()) do
        local x, y, z = spawner.echo_spot(player.localIndex)
        if x ~= nil then
            if player.localIndex == 0 then
                mine = { x = x, y = y, z = z }
            else
                table.insert(others, { x = x, y = y, z = z })
            end
        end
    end

    local pick
    if #others > 0 then
        echoCursor = (echoCursor % #others) + 1
        pick = others[echoCursor]
    else
        pick = mine
    end
    if pick == nil then
        return false, "Nobody has been on their feet long enough for that."
    end

    if spawner.spawn_at(key, pick.x, pick.y, pick.z) == nil then return false end
    return true
end

function spawner.spawn(key)
    local m = gMarioStates[0]
    if m == nil then return false end

    local x, y, z = spot_in_front(m)
    local object, entry = spawner.spawn_at(key, x, y, z)
    if object == nil then return false end

    OF.notify.show("@ spawned  (@)", "good", 2, entry.name,
        string.format("%.0f/%.0f", spawner.count(), spawner.MAX_PER_SESSION))
    return true
end

local function on_level_init()
    spawner.objects = {}

    spawner.forget_trails()
end

hook_event(HOOK_ON_LEVEL_INIT, on_level_init)

local FIGHT_GRAVITY = { 2, 5, 10, 20, 45 }

local FIGHT_SPIN = { 0.5, 1.0, 2.0, 4.0, 9.0 }

local FIGHT_SLIDE = { 0.2, 0.4, 0.7, 1.1, 1.5 }

local FIGHT_SHOT = { 0.15, 0.3, 0.5, 0.75, 1.0 }

local FIGHT_CLOCK = { 0.25, 0.6, 1.2, 2.5, 5.0 }

local CLOCK_CEILING = 6

local function fight_level()
    if not OF.util.asks(OF.modifiers, "level") then return 0 end
    return OF.modifiers.level("fightback")
end

local function fight_crusher(o)
    local level = fight_level()
    if level <= 0 or o == nil then return false end

    if o.oAction ~= 2 then return false end
    o.oVelY = o.oVelY - (FIGHT_GRAVITY[level] or 0)
    return true
end

local function fight_turn(o, onMoveAngle)
    local level = fight_level()
    if level <= 0 or o == nil then return false end
    local extra = FIGHT_SPIN[level]
    if extra == nil then return false end
    local turn = math.floor((o.oAngleVelYaw or 0) * extra)
    if turn == 0 then return false end
    if onMoveAngle then
        o.oMoveAngleYaw = (o.oMoveAngleYaw or 0) + turn
    else
        o.oFaceAngleYaw = (o.oFaceAngleYaw or 0) + turn
    end
    return true
end

local function fight_turntable(o) return fight_turn(o, false) end
local function fight_turntable_move(o) return fight_turn(o, true) end

local function fight_turn_both(o)
    local level = fight_level()
    if level <= 0 or o == nil then return false end
    local extra = FIGHT_SPIN[level]
    if extra == nil then return false end
    local turn = math.floor((o.oAngleVelYaw or 0) * extra)
    if turn == 0 then return false end
    o.oMoveAngleYaw = (o.oMoveAngleYaw or 0) + turn
    o.oFaceAngleYaw = (o.oFaceAngleYaw or 0) + turn
    return true
end

local FERRIS_TURN = 400

local function fight_wheel(o)
    local level = fight_level()
    if level <= 0 or o == nil then return false end
    local extra = FIGHT_SPIN[level]
    if extra == nil then return false end
    o.oFaceAngleRoll = (o.oFaceAngleRoll or 0) + math.floor(FERRIS_TURN * extra)
    return true
end

local function fight_slider(o)
    local level = fight_level()
    if level <= 0 or o == nil then return false end
    local extra = FIGHT_SLIDE[level]
    if extra == nil then return false end
    local vel = o.oForwardVel or 0
    if vel == 0 then return false end
    o.oForwardVel = vel + vel * extra
    return true
end

local WF_SLIDER_BASE = { [0] = 10, [1] = 15, [2] = 20 }

local function fight_wf_slider(o)
    local level = fight_level()
    if level <= 0 or o == nil then return false end
    local extra = FIGHT_SLIDE[level]
    if extra == nil then return false end
    local base = WF_SLIDER_BASE[o.oBehParams2ndByte or 0]
    if base == nil then return false end
    o.oWFSlidBrickPtfmMovVel = base + base * extra
    return fight_slider(o)
end

local function sliding2_base(o)
    local index = (((o.oBehParams or 0) >> 16) & 0x0380) >> 7
    if index < 5 or index > 6 then return 15.0 end
    return 10.0
end

local function fight_slider2(o)
    local level = fight_level()
    if level <= 0 or o == nil then return false end
    local extra = FIGHT_SLIDE[level]
    if extra == nil then return false end
    local now = o.oBackAndForthPlatformVel or 0

    if now == 0 then return false end
    local want = sliding2_base(o) * (1 + extra)
    if now < 0 then want = -want end
    o.oBackAndForthPlatformVel = want
    return true
end

local ACTIVATED_BASE = 10.0

local function fight_lift(o)
    local level = fight_level()
    if level <= 0 or o == nil then return false end
    local extra = FIGHT_SLIDE[level]
    if extra == nil then return false end
    local now = o.oActivatedBackAndForthPlatformVel or 0
    if now == 0 then return false end
    local want = ACTIVATED_BASE * (1 + extra)
    if now < 0 then want = -want end
    o.oActivatedBackAndForthPlatformVel = want
    return true
end

local function fight_bullet(o)
    local level = fight_level()
    if level <= 0 or o == nil then return false end
    if o.oAction ~= 2 then return false end
    local extra = FIGHT_SHOT[level]
    if extra == nil then return false end
    local vel = o.oForwardVel or 0
    if vel == 0 then return false end
    o.oForwardVel = vel + vel * extra
    return true
end

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

spawner.FIGHTS = {

    { bhv = id_bhvThwomp, list = OBJ_LIST_SURFACE, loop = fight_crusher },
    { bhv = id_bhvThwomp2, list = OBJ_LIST_SURFACE, loop = fight_crusher },
    { bhv = id_bhvGrindel, list = OBJ_LIST_SURFACE, loop = fight_crusher },
    { bhv = id_bhvHorizontalGrindel, list = OBJ_LIST_SURFACE, loop = fight_crusher },

    { bhv = id_bhvRotatingPlatform, list = OBJ_LIST_SURFACE, loop = fight_turntable },
    { bhv = id_bhvWfRotatingWoodenPlatform, list = OBJ_LIST_SURFACE,
      loop = fight_turntable },
    { bhv = id_bhvOctagonalPlatformRotating, list = OBJ_LIST_SURFACE,
      loop = fight_turntable },

    { bhv = id_bhvLllRotatingHexagonalPlatform, list = OBJ_LIST_SURFACE,
      loop = fight_turntable_move },
    { bhv = id_bhvLllRotatingHexagonalRing, list = OBJ_LIST_SURFACE,
      loop = fight_turntable_move },
    { bhv = id_bhvLllRotatingBlockWithFireBars, list = OBJ_LIST_SURFACE,
      loop = fight_turntable_move },

    { bhv = id_bhvSmallBomp, list = OBJ_LIST_SURFACE, loop = fight_slider },
    { bhv = id_bhvLargeBomp, list = OBJ_LIST_SURFACE, loop = fight_slider },
    { bhv = id_bhvWfSlidingPlatform, list = OBJ_LIST_SURFACE, loop = fight_wf_slider },

    { bhv = id_bhvRrRotatingBridgePlatform, list = OBJ_LIST_SURFACE,
      loop = fight_turntable_move },

    { bhv = id_bhvMerryGoRound, list = OBJ_LIST_SURFACE, loop = fight_turn_both },

    { bhv = id_bhvFerrisWheelAxle, list = OBJ_LIST_SURFACE, loop = fight_wheel },

    { bhv = id_bhvSlidingPlatform2, list = OBJ_LIST_SURFACE, loop = fight_slider2 },
    { bhv = id_bhvActivatedBackAndForthPlatform, list = OBJ_LIST_SURFACE,
      loop = fight_lift },

    { bhv = id_bhvBulletBill, list = OBJ_LIST_GENACTOR, loop = fight_bullet },
}

for _, fight in ipairs(spawner.FIGHTS) do
    if fight.bhv ~= nil then
        at_load("hook_behavior", fight.bhv, fight.list, false, nil, fight.loop)
    end
end

local TTC_TREADMILL = { 50, 100, 0, 0 }
local TTC_BAR_DELAY = { 55, 30, 55, 0 }
local TTC_PENDULUM = { 13.0, 22.0, 13.0, 0.0 }

local TTC_ROTATOR = { { 40, 10, 10, 0 }, { 20, 5, 5, 0 } }

local TTC_SOLID_DELAY = { 120, 40, 0, 0 }

local TTC_PIT = { { 11, -9 }, { 18, -11 }, { 11, -9 }, { 0, 0 } }

local TTC_COG = { 200, 400 }

local function clock_factor()
    local own = 1
    if OF.util.asks(OF.modifiers, "clock_overdrive") then
        local said = OF.modifiers.clock_overdrive()
        if type(said) == "number" and said > 1 then own = said end
    end

    local extra = FIGHT_CLOCK[fight_level()]
    if extra == nil then return own end

    local want = own * (1 + extra)
    if want > CLOCK_CEILING then want = CLOCK_CEILING end

    if want < own then want = own end
    return want
end

local function clock_overdrive()
    local factor = clock_factor()
    if type(factor) ~= "number" or factor < 1 then return 1 end
    return factor
end

local function clock_speed()
    local said = OF.util.optional("get_ttc_speed_setting", nil)
    if type(said) ~= "number" or said < 0 or said > 3 then return nil end
    return said + 1
end

local function hurried(delay, factor)
    if type(delay) ~= "number" then return delay end
    if delay <= 0 or factor <= 1 then return delay end
    local want = math.floor(delay / factor)
    if want < 1 then want = 1 end
    return want
end

local function keep_treadmill(o)
    local at = clock_speed()
    if at == nil or o == nil then return false end
    if at == TTC_SPEED_RANDOM + 1 then return false end
    local want = 0.084 * TTC_TREADMILL[at] * clock_overdrive()
    o.oForwardVel = want

    o.oVelX = want * sins(o.oMoveAngleYaw or 0)
    o.oVelZ = want * coss(o.oMoveAngleYaw or 0)
    return true
end

local function keep_bar(o)
    local at = clock_speed()
    if at == nil or o == nil then return false end
    o.oTTCMovingBarDelay = hurried(TTC_BAR_DELAY[at], clock_overdrive())
    return true
end

local function keep_pendulum(o)
    local at = clock_speed()
    if at == nil or o == nil then return false end
    local want = TTC_PENDULUM[at] * clock_overdrive()
    local now = o.oTTCPendulumAngleAccel or 0
    if now < 0 then want = -want end
    o.oTTCPendulumAngleAccel = want
    return true
end

local function keep_rotator(o)
    local at = clock_speed()
    if at == nil or o == nil then return false end

    local row = TTC_ROTATOR[((o.oBehParams2ndByte or 0) % 2) + 1]
    if row == nil then return false end
    o.oTTC2DRotatorMinTimeUntilNextTurn = hurried(row[at], clock_overdrive())
    return true
end

local function keep_solid(o)
    local at = clock_speed()
    if at == nil or o == nil then return false end

    if at == TTC_SPEED_RANDOM + 1 then return false end
    o.oTTCRotatingSolidRotationDelay =
        hurried(TTC_SOLID_DELAY[at], clock_overdrive())
    return true
end

local function keep_pit(o)
    local at = clock_speed()
    if at == nil or o == nil then return false end
    local factor = clock_overdrive()
    if factor <= 1 then return false end
    local row = TTC_PIT[at]
    if row == nil then return false end
    local dir = (o.oTTCPitBlockDir or 0) % 2
    o.oVelY = row[dir + 1] * factor
    o.oTTCPitBlockWaitTime = hurried(o.oTTCPitBlockWaitTime, factor)
    return true
end

local function keep_cog(o)
    local factor = clock_overdrive()
    if factor <= 1 or o == nil then return false end
    o.oFaceAngleYaw = o.oFaceAngleYaw
        + math.floor((o.oAngleVelYaw or 0) * (factor - 1))
    return true
end

local function keep_spinner(o)
    local factor = clock_overdrive()
    if factor <= 1 or o == nil then return false end
    o.oFaceAnglePitch = o.oFaceAnglePitch
        + math.floor((o.oAngleVelPitch or 0) * (factor - 1))
    return true
end

local function keep_elevator(o)
    local factor = clock_overdrive()
    if factor <= 1 or o == nil then return false end
    local low, high = o.oHomeY, o.oTTCElevatorPeakY
    if type(low) ~= "number" or type(high) ~= "number" then return false end
    local want = o.oPosY + (o.oVelY or 0) * (factor - 1)
    if want < low then want = low end
    if want > high then want = high end
    o.oPosY = want
    return true
end

spawner.CLOCKWORK = {
    { bhv = id_bhvTTCTreadmill, list = OBJ_LIST_SURFACE, loop = keep_treadmill },
    { bhv = id_bhvTTCMovingBar, list = OBJ_LIST_SURFACE, loop = keep_bar },
    { bhv = id_bhvTTCPendulum, list = OBJ_LIST_SURFACE, loop = keep_pendulum },
    { bhv = id_bhvTTC2DRotator, list = OBJ_LIST_SURFACE, loop = keep_rotator },
    { bhv = id_bhvTTCRotatingSolid, list = OBJ_LIST_SURFACE, loop = keep_solid },
    { bhv = id_bhvTTCPitBlock, list = OBJ_LIST_SURFACE, loop = keep_pit },
    { bhv = id_bhvTTCCog, list = OBJ_LIST_SURFACE, loop = keep_cog },
    { bhv = id_bhvTTCSpinner, list = OBJ_LIST_SURFACE, loop = keep_spinner },
    { bhv = id_bhvTTCElevator, list = OBJ_LIST_SURFACE, loop = keep_elevator },
}

for _, part in ipairs(spawner.CLOCKWORK) do
    if part.bhv ~= nil then
        at_load("hook_behavior", part.bhv, part.list, false, nil, part.loop)
    end
end
