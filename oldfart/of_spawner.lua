OF = OF or {}
OF.spawner = OF.spawner or {}

local spawner = OF.spawner

spawner.POOL_CAPACITY = OBJECT_POOL_CAPACITY or 1200
spawner.THIN_AT = math.floor(spawner.POOL_CAPACITY * 150 / 240)

spawner.CEILING = math.floor(spawner.POOL_CAPACITY * 210 / 240)

spawner.RESERVE = 300

local LIST_NAMES = { "OBJ_LIST_PLAYER", "OBJ_LIST_EXT", "OBJ_LIST_DESTRUCTIVE",
    "OBJ_LIST_GENACTOR", "OBJ_LIST_PUSHABLE", "OBJ_LIST_LEVEL",
    "OBJ_LIST_DEFAULT", "OBJ_LIST_SURFACE", "OBJ_LIST_POLELIKE",
    "OBJ_LIST_SPAWNER", "OBJ_LIST_UNIMPORTANT" }

local walked, walkedFrame = nil, nil

local function frame_now()
    return OF.util.optional("get_global_timer", nil)
end

function spawner.pool_count()
    local now = frame_now()
    if walked ~= nil and now ~= nil and now == walkedFrame then return walked end
    local total = 0
    local first = OF.util.binding("obj_get_first")
    local nxt = OF.util.binding("obj_get_next")
    if first ~= nil and nxt ~= nil then
        for _, name in ipairs(LIST_NAMES) do
            local list = _G[name]
            local o = list ~= nil and first(list) or nil
            local guard = 0
            while o ~= nil and guard < spawner.POOL_CAPACITY do
                total = total + 1
                guard = guard + 1
                o = nxt(o)
            end
        end
    end
    walked, walkedFrame = total, now
    return total
end

function spawner.pool_spawned()
    if walked ~= nil then walked = walked + 1 end
end

spawner.VENUE_HEADROOM = 32 + 16 * (2 + 6 + 7) + 50
spawner.VENUE_LINE = spawner.POOL_CAPACITY - spawner.VENUE_HEADROOM

function spawner.venue_standing()
    local v = OF.venues
    if v == nil or v.built == nil or not OF.util.asks(v, "count") then return 0 end
    local n = OF.util.asks(v, "cost") and v.cost() or v.count()
    for _, t in ipairs(v.things or {}) do
        local o = t.object
        if o ~= nil and OF.util.alive(o) and o.activeFlags ~= 0 then n = n + 1 end
    end
    return n
end

function spawner.free()
    local pool = spawner.pool_count()
    local free = spawner.CEILING - spawner.RESERVE - pool
    local map = spawner.venue_standing()
    if map > 0 then
        free = math.min(free + map, spawner.VENUE_LINE - pool)
    end
    if free < 0 then return 0 end
    return math.floor(free)
end

function spawner.fair_share(wanted)
    local free = spawner.free()
    local players = #OF.util.connected_players()
    if players < 1 then players = 1 end
    local share = math.floor(free / players)
    if share < 1 and free > 0 then share = 1 end
    wanted = math.floor(tonumber(wanted) or 0)
    if wanted > share then return share end
    return wanted
end

local pressLeft, pressRefused = nil, false

function spawner.begin_press()
    pressLeft = spawner.fair_share(spawner.POOL_CAPACITY)
    pressRefused = false
end

function spawner.end_press()
    pressLeft = nil
    pressRefused = false
end

function spawner.room_text()
    return OF.lang.fill("@ used / @ free", tostring(spawner.pool_count()),
        tostring(spawner.free()))
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
    local mask = variant ~= nil and variant.mask or nil
    if type(second) ~= "number" and type(first) ~= "number"
        and type(mask) ~= "number" then return nil end

    local params = 0
    if type(second) == "number" then params = params + ((second & 0xFF) << 16) end

    if type(entry.rtex) == "number" then params = params + (math.floor(entry.rtex) & 0x3FF) end

    if type(mask) == "number" then params = params + ((math.floor(mask) & 0xFF) << 8) end

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

spawner.DECOR_SHELF = "Decor"
spawner.SIZELESS = {
    boulder = true, chuckya = true, exclam = true, heaveho = true,
    shell = true, blueswitch = true,
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

    finalbowser = true,
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

          { name = "stone plank", value = 4, model = E_MODEL_BITFS_SEESAW_PLATFORM },
          { name = "sky plank", value = 1, model = E_MODEL_BITS_SEESAW_PLATFORM },
          { name = "sky S-bend", value = 2, model = E_MODEL_BITS_TILTING_W_PLATFORM },
          { name = "rainbow plank", value = 5, model = E_MODEL_RR_SEESAW_PLATFORM },
          { name = "cloud plank", value = 7, model = E_MODEL_VCUTM_SEESAW_PLATFORM },
      } },

    { key = "swingplat", name = "Swinging platform", bhv = id_bhvSwingPlatform,
      model = E_MODEL_RR_SWINGING_PLATFORM, reach = STANDING_REACH },

    { key = "trampoline", name = "Trampoline", bhv = id_bhvBetaTrampolineTop,
      model = E_MODEL_TRAMPOLINE, reach = STANDING_REACH,
      variants = {
          { name = "standard", value = 1, model = E_MODEL_TRAMPOLINE },
          { name = "gentle", value = 0, model = E_MODEL_TRAMPOLINE },
          { name = "launch", value = 2, model = E_MODEL_TRAMPOLINE },
      } },

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
    { key = "grindel",  name = "Grindel", ground = true,        bhv = id_bhvGrindel,
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

    { key = "purpleswitch", name = "Purple switch", ground = true, bhv = id_bhvFloorSwitchHardcodedModel,
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

    { key = "warppipe", name = "Warp pipe",       bhv = id_bhvWarpPipe,
      model = E_MODEL_BITS_WARP_PIPE, reach = STANDING_REACH, pipe = true },
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

    { key = "kickboard", name = "Kickable board", ground = true, bhv = id_bhvKickableBoard,
      model = E_MODEL_WF_KICKABLE_BOARD, reach = STANDING_REACH, turn = 0x8000 },

    { key = "pole",     name = "Climbing pole", ground = true,  bhv = id_bhvPoleGrabbing,
      model = E_MODEL_DDD_POLE, variant = 80, solid = false },

    { key = "capswitch", name = "Cap switch", ground = true,    bhv = id_bhvCapSwitch,
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

    { key = "coin",     name = "Coin",           bhv = id_bhvSingleCoinGetsSpawned, model = E_MODEL_YELLOW_COIN,
      params = 0x4F000000 },
    { key = "bluecoin", name = "Blue coin",      bhv = id_bhvBlueCoinJumping, model = E_MODEL_BLUE_COIN,
      params = 0x4F000000 },
    { key = "box",      name = "Breakable box",  bhv = id_bhvBreakableBox,  model = E_MODEL_BREAKABLE_BOX },

    { key = "exclam",   name = "Exclamation box", bhv = id_bhvExclamationBox, model = E_MODEL_EXCLAMATION_BOX,
      variants = {
          { name = "wing cap", value = 0, first = 1, model = E_MODEL_EXCLAMATION_BOX },
          { name = "metal cap", value = 1, first = 1, model = E_MODEL_EXCLAMATION_BOX },
          { name = "vanish cap", value = 2, first = 1, model = E_MODEL_EXCLAMATION_BOX },
          { name = "koopa shell", value = 3, model = E_MODEL_EXCLAMATION_BOX },
          { name = "three coins", value = 5, model = E_MODEL_EXCLAMATION_BOX },
          { name = "ten coins", value = 6, model = E_MODEL_EXCLAMATION_BOX },
          { name = "1-up", value = 7, model = E_MODEL_EXCLAMATION_BOX },
      } },
    { key = "shell",    name = "Koopa shell",    bhv = id_bhvKoopaShell,    model = E_MODEL_KOOPA_SHELL },

    { key = "tree",     name = "Tree", ground = true,           bhv = id_bhvTree,
      model = E_MODEL_BUBBLY_TREE,
      variants = {
          { name = "leafy", value = 0, model = E_MODEL_BUBBLY_TREE },
          { name = "palm", value = 0, model = E_MODEL_PALM_TREE },
          { name = "snowy", value = 0, model = E_MODEL_SNOW_TREE },
          { name = "spiky", value = 0, model = E_MODEL_COURTYARD_SPIKY_TREE },
      } },

    { key = "chainchomp", name = "Chain Chomp",  bhv = id_bhvChainChomp,    model = E_MODEL_CHAIN_CHOMP },

    { key = "thwomp",   name = "Thwomp", ground = true,         bhv = id_bhvThwomp,
      model = E_MODEL_THWOMP,
      variants = {
          { name = "low", value = 0, model = E_MODEL_THWOMP },
          { name = "high", value = 60, model = E_MODEL_THWOMP },
          { name = "very high", value = 140, model = E_MODEL_THWOMP },
      } },
    { key = "piranha",  name = "Piranha Plant", ground = true,  bhv = id_bhvPiranhaPlant,  model = E_MODEL_PIRANHA_PLANT },

    { key = "pokey",    name = "Pokey",          bhv = id_bhvPokey,         model = E_MODEL_NONE },
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

    { key = "moneybag", name = "Moneybag",       bhv = id_bhvMoneybagHidden, model = E_MODEL_YELLOW_COIN },
    { key = "unagi",    name = "Unagi",          bhv = id_bhvUnagi,         model = E_MODEL_UNAGI },
    { key = "bubba",    name = "Bubba",          bhv = id_bhvBubba,         model = E_MODEL_BUBBA },
    { key = "mrI",      name = "Mr. I",          bhv = id_bhvMrI,           model = E_MODEL_MR_I },

    { key = "waterbomb", name = "Water bomb",    bhv = id_bhvWaterBomb,     model = E_MODEL_WATER_BOMB,
      action = 1 },

    { key = "fire",     name = "Bouncing flame", bhv = id_bhvBouncingFireballFlame, model = E_MODEL_RED_FLAME },

    { key = "firespitter", name = "Fire spitter", bhv = id_bhvFireSpitter,  model = E_MODEL_BOWLING_BALL },

    { key = "bowserbomb", name = "Bowser bomb",  bhv = id_bhvBowserBomb,    model = E_MODEL_BOWSER_BOMB },

    { key = "kingbobomb", name = "King Bob-omb", bhv = id_bhvKingBobomb,    model = E_MODEL_KING_BOBOMB },
    { key = "whompking", name = "King Whomp",    bhv = id_bhvWhompKingBoss, model = E_MODEL_WHOMP },
    { key = "bigbully", name = "Big Bully",      bhv = id_bhvBigBully,      model = E_MODEL_BULLY_BOSS },
    { key = "wiggler",  name = "Wiggler",        bhv = id_bhvWigglerHead,   model = E_MODEL_WIGGLER_HEAD },
    { key = "bowser",   name = "Bowser",         bhv = id_bhvBowser,        model = E_MODEL_BOWSER },

    { key = "finalbowser", name = "Final Bowser", bhv = id_bhvBowser,      model = E_MODEL_BOWSER,
      params = 0x00020000 },

    { key = "mips",     name = "MIPS the rabbit", bhv = id_bhvMips,         model = E_MODEL_MIPS },
    { key = "yoshi",    name = "Yoshi",          bhv = id_bhvYoshi,         model = E_MODEL_YOSHI },
    { key = "redcoin",  name = "Red coin",       bhv = id_bhvRedCoin,       model = E_MODEL_RED_COIN },
    { key = "heart",    name = "Spinning heart", bhv = id_bhvRecoveryHeart, model = E_MODEL_HEART },
    { key = "1upwalk",  name = "Running 1-Up",   bhv = id_bhv1upWalking,    model = E_MODEL_1UP,
      params = 0x4F000000 },

    { key = "wingcap",  name = "Wing cap",       bhv = id_bhvWingCap,       model = E_MODEL_MARIOS_WING_CAP },
    { key = "metalbox", name = "Pushable metal box", bhv = id_bhvPushableMetalBox, model = E_MODEL_METAL_BOX },
    { key = "woodpost", name = "Wooden post", ground = true,    bhv = id_bhvWoodenPost,    model = E_MODEL_WOODEN_POST },

    { key = "cannon",   name = "Cannon", ground = true,         bhv = id_bhvCannon,        model = E_MODEL_CANNON_BASE },
    { key = "blueswitch", name = "Blue coin switch", ground = true, bhv = id_bhvBlueCoinSwitch, model = E_MODEL_BLUE_COIN_SWITCH },

    { key = "checkers", name = "Checkerboard lift", bhv = id_bhvCheckerboardElevatorGroup, model = E_MODEL_CHECKERBOARD_PLATFORM },

    { key = "spiny",    name = "Spiny",          bhv = id_bhvSpiny,        model = E_MODEL_SPINY,
      params = 0x4F460000 },

    { key = "skeeter",  name = "Skeeter",        bhv = id_bhvSkeeter,      model = E_MODEL_SKEETER },

    { key = "bookend",  name = "Flying book",    bhv = id_bhvFlyingBookend, model = E_MODEL_BOOKEND },

    { key = "piano",    name = "Mad Piano", ground = true,      bhv = id_bhvMadPiano,     model = E_MODEL_MAD_PIANO },
    { key = "chair",    name = "Haunted chair", ground = true,  bhv = id_bhvHauntedChair, model = E_MODEL_HAUNTED_CHAIR },

    { key = "penguin",  name = "Baby penguin",   bhv = id_bhvSmallPenguin, model = E_MODEL_PENGUIN },

    { key = "bub",      name = "Bub",            bhv = id_bhvBub,          model = E_MODEL_BUB,
      water = true },
    { key = "clam",     name = "Clam", ground = true,           bhv = id_bhvClamShell,    model = E_MODEL_CLAM_SHELL },

    { key = "flamejet", name = "Flamethrower",   bhv = id_bhvFlamethrower, model = E_MODEL_NONE },

    { key = "montymole", name = "Monty Mole", ground = true,    bhv = id_bhvMontyMoleHole, model = E_MODEL_DL_MONTY_MOLE_HOLE,
      companion = { bhv = id_bhvMontyMole, model = E_MODEL_MONTY_MOLE, second = 1 } },

    { key = "bowling",  name = "Bowling ball",   bhv = id_bhvBowlingBall,  model = E_MODEL_BOWLING_BALL },

    { key = "tweester", name = "Tornado", ground = true,        bhv = id_bhvTweester,
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

    { key = "firepiranha", name = "Fire Piranha Plant", ground = true, bhv = id_bhvFirePiranhaPlant,
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

          { name = "an arch", value = 3, mask = 0xE0, model = E_MODEL_NONE },
          { name = "an arrow", value = 0x14, model = E_MODEL_NONE },
      } },

    { key = "soundspot", name = "Sound spot", bhv = id_bhvStaticObject, model = E_MODEL_PURPLE_SWITCH,
      variants = {
          { name = "a coin", value = 1, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "a red coin", value = 2, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "a 1-up", value = 3, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "a spring", value = 4, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "a star", value = 5, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "the right answer", value = 6, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "a buzz", value = 7, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "a Goomba", value = 8, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "a big clock", value = 9, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
          { name = "Bowser's laugh", value = 10, first = 0x5D, model = E_MODEL_PURPLE_SWITCH },
      } },
}

spawner.SOUND_SPOT_SIGN = 0x5D
spawner.SOUND_SPOT_SOUNDS = {
    "SOUND_GENERAL_COIN", "SOUND_GENERAL_RED_COIN", "SOUND_GENERAL_COLLECT_1UP",
    "SOUND_GENERAL_BOING1", "SOUND_MENU_STAR_SOUND", "SOUND_GENERAL2_RIGHT_ANSWER",
    "SOUND_MENU_CAMERA_BUZZ", "SOUND_OBJ_GOOMBA_ALERT", "SOUND_GENERAL_BIG_CLOCK",
    "SOUND_OBJ_BOWSER_LAUGH",
}

spawner.SOUND_SPOT_REACH = 110
spawner.SOUND_SPOT_HEIGHT = 60
spawner.SOUND_SPOT_RESCAN = 30
spawner.soundSpots = {}
spawner.soundSpotScan = 0
spawner.soundSpotOn = setmetatable({}, { __mode = "k" })

function spawner.sound_spot_kind(o)
    if o == nil or o.oBehParams == nil then return nil end
    local params = math.floor(o.oBehParams)
    if (params >> 24) & 0xFF ~= spawner.SOUND_SPOT_SIGN then return nil end
    local kind = (params >> 16) & 0xFF
    if spawner.SOUND_SPOT_SOUNDS[kind] == nil then return nil end
    return kind
end

function spawner.sound_spots_update()
    spawner.soundSpotScan = spawner.soundSpotScan - 1
    if spawner.soundSpotScan <= 0 then
        spawner.soundSpotScan = spawner.SOUND_SPOT_RESCAN
        local found = {}
        local get_first = rawget(_G, "obj_get_first_with_behavior_id")
        local get_next = rawget(_G, "obj_get_next_with_same_behavior_id")
        if get_first ~= nil and get_next ~= nil and id_bhvStaticObject ~= nil then
            local o = get_first(id_bhvStaticObject)
            while o ~= nil do
                if spawner.sound_spot_kind(o) ~= nil then found[#found + 1] = o end
                o = get_next(o)
            end
        end
        spawner.soundSpots = found
    end
    local played = 0
    local reach2 = spawner.SOUND_SPOT_REACH * spawner.SOUND_SPOT_REACH
    for _, o in ipairs(spawner.soundSpots) do
        if OF.util.alive(o) and o.activeFlags ~= 0 then
            local on = spawner.soundSpotOn[o] or {}
            spawner.soundSpotOn[o] = on
            local arrived = false
            for i = 0, (MAX_PLAYERS or 16) - 1 do
                local m = gMarioStates ~= nil and gMarioStates[i] or nil
                local here = false
                if m ~= nil and m.marioObj ~= nil and (i == 0 or is_player_active == nil
                    or is_player_active(m) ~= 0) then
                    local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
                    here = not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR)
                        and math.abs(m.pos.y - o.oPosY) <= spawner.SOUND_SPOT_HEIGHT
                        and dx * dx + dz * dz <= reach2
                end
                if here and not on[i] then arrived = true end
                on[i] = here or nil
            end
            if arrived then
                local sound = rawget(_G, spawner.SOUND_SPOT_SOUNDS[spawner.sound_spot_kind(o)])
                if sound ~= nil then
                    OF.util.optional("play_sound", nil, sound, o.header.gfx.cameraToObject)
                    played = played + 1
                end
            end
        end
    end
    return played
end

hook_event(HOOK_UPDATE, spawner.sound_spots_update)

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function() return spawner.LIST end)

for _, entry in ipairs(FURNITURE) do
    entry.furniture = true
    table.insert(spawner.LIST, entry)
end

spawner.CHILDREN = {
    cageplat = id_bhvDddMovingPole,

    montymole = id_bhvMontyMole,
    capswitch = id_bhvCapSwitchBase,
    coins = id_bhvCoinFormationSpawn,

}

spawner.FOLLOWERS = {
    trapdoor = { id_bhvFloorTrapInCastle },
    montymole = { id_bhvMontyMole },
    capswitch = { id_bhvCapSwitchBase },
    coins = { id_bhvCoinFormationSpawn, id_bhvYellowCoin },
}

function spawner.followers(key)
    return key ~= nil and spawner.FOLLOWERS[key] or nil
end

spawner.ALSO_TAKES = {
    coins = id_bhvYellowCoin,
}

spawner.NATIVE_SCALE = {
    { bhv = id_bhvBreakableBoxSmall, scale = 0.4 },
    { bhv = id_bhvBubba, scale = 0.5 },
    { bhv = id_bhvBulletBill, scale = 0.4 },
    { bhv = id_bhvChainChomp, scale = 2.0 },
    { bhv = id_bhvFireSpitter, scale = 0.4 },
    { bhv = id_bhvFlyGuy, scale = 1.5 },
    { bhv = id_bhvFlyingBookend, scale = 0.7 },
    { bhv = id_bhvHorizontalGrindel, scale = 0.9 },
    { bhv = id_bhvMontyMole, scale = 1.5 },
    { bhv = id_bhvMontyMoleHole, scale = 1.5 },
    { bhv = id_bhvThwomp, scale = 1.4 },
    { bhv = id_bhvThwomp2, scale = 1.4 },
    { bhv = id_bhvUnagi, scale = 3.0 },
    { bhv = id_bhvWigglerHead, scale = 4.0 },
    { bhv = id_bhvWoodenPost, scale = 0.5 },
    { bhv = id_bhvCapSwitch, scale = 0.5 },
}

function spawner.native_scale(object)
    if object == nil or type(obj_has_behavior_id) ~= "function" then return 1.0 end

    if spawner.ONOFF ~= nil and obj_has_behavior_id(object, spawner.ONOFF) ~= 0
        and spawner.onoff_kind ~= nil then
        return spawner.onoff_kind(object) == spawner.ONOFF_SWITCH and 1.0
            or spawner.onoff_block_scale(object)
    end
    for _, row in ipairs(spawner.NATIVE_SCALE) do
        if row.bhv ~= nil and obj_has_behavior_id(object, row.bhv) ~= 0 then
            return row.scale
        end
    end
    return 1.0
end

function spawner.has_water(x, z)
    if type(find_water_level) ~= "function" then return false end
    local level = tonumber(find_water_level(x, z)) or -11000
    return level > -10000
end

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
    local also = key ~= nil and spawner.ALSO_TAKES[key] or nil
    if also ~= nil then reap_children(also, object) end
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
    local block = spawner.build_find ~= nil and spawner.build_find(key) or nil
    if block ~= nil then return block end

    local onoff = spawner.onoff_find ~= nil and spawner.onoff_find(key) or nil
    if onoff ~= nil then return onoff end

    if spawner.LOGIC ~= nil and OF.logic ~= nil and type(OF.logic.find) == "function" then
        local piece = OF.logic.find(key)
        if piece ~= nil then return piece end
    end

    return spawner.mover_find ~= nil and spawner.mover_find(key) or nil
end

local function spot_in_front(m)
    local angle = m.faceAngle.y
    return m.pos.x + sins(angle) * DISTANCE,
           m.pos.y + 80,
           m.pos.z + coss(angle) * DISTANCE
end

local function spawn_at_body(key, x, y, z, yaw, extra)
    if not OF.util.allowed("spawn_object") then
        return nil
    end

    if OF.util.asks(OF.roundscope, "shares_room_with_round")
        and OF.roundscope.shares_room_with_round() then
        return nil
    end

    local entry = spawner.find(key)
    if entry == nil then return nil end

    local wanted = entry.companion ~= nil and 2 or 1
    if spawner.free() < wanted then
        OF.notify.show("No room left in this level (@)", "warn", nil,
            spawner.room_text())
        return nil
    end
    if pressLeft ~= nil then
        if pressLeft <= 0 then

            if not pressRefused then
                pressRefused = true
                OF.notify.show("That is this press's share of the lobby (@)",
                    "warn", 4, spawner.room_text())
            end
            return nil
        end
        pressLeft = pressLeft - wanted
    end

    if entry.water and not spawner.has_water(x, z) then
        OF.notify.show("That one only lives in water - aim at a lake", "warn", 4)
        return nil
    end

    if extra ~= nil and extra.arms == nil
        and (extra.w or 1) == 1 and (extra.h or 1) == 1 and (extra.d or 1) == 1 then
        extra = nil
    end

    local word = (extra ~= nil or (entry ~= nil and entry.decorWord ~= nil))
        and spawner.block_word(entry, extra) or nil
    if extra ~= nil and word == nil then return nil end

    local setup = no_setup
    if entry.reach ~= nil or entry.variant ~= nil or entry.variants ~= nil
        or entry.square or entry.turn ~= nil or entry.action ~= nil
        or entry.params ~= nil or entry.pipe or word ~= nil then
        setup = function(o)
            if entry.reach ~= nil then o.oCollisionDistance = entry.reach end

            if entry.turn ~= nil then
                local yaw = ((tonumber(o.oMoveAngleYaw) or 0) + entry.turn) % 0x10000
                if yaw >= 0x8000 then yaw = yaw - 0x10000 end
                spawner.face(o, yaw)
            end

            if entry.action ~= nil then o.oAction = entry.action end

            if entry.square then spawner.square_up(o, yaw or 0) end

            if entry.mover then spawner.mover_setup(o) end

            if entry.pipe and OF.util.asks(OF.forge, "pipe_setup") then
                OF.forge.pipe_setup(o)
            end

            local second = second_of(entry)
            if second ~= nil then o.oBehParams2ndByte = second end

            if entry.params ~= nil then o.oBehParams = entry.params end
            local params = params_of(entry)
            if params ~= nil then o.oBehParams = params end
            if word ~= nil then o.oBehParams = word end

            if entry.racer ~= nil and OF.util.asks(OF.forge, "racer_setup") then
                OF.forge.racer_setup(o, entry)
            end

            if entry.logic and OF.util.asks(OF.logic, "setup") then OF.logic.setup(o) end
        end
    end

    local variant = spawner.chosen(entry)
    local model = (variant ~= nil and variant.model) or entry.model
    if word ~= nil then model = spawner.SHAPE_MODEL_ID end

    local object = OF.slots.spawn_lobby(entry.bhv, model, x, y, z, setup)
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

    spawner.count()
    table.insert(spawner.objects, object)
    spawner.pool_spawned()

    if entry.companion ~= nil then
        spawner.spawn_companion(entry.companion, object, x, y, z)
    end

    if entry.reach ~= nil or entry.settle ~= nil then
        table.insert(reapply, { object = object, reach = entry.reach,
                                settle = entry.settle, x = x, y = y, z = z,
                                frames = REAPPLY_FRAMES })
    end

    return object, entry
end

function spawner.spawn_companion(companion, parent, x, y, z)
    if companion == nil or parent == nil then return nil end
    local friend = OF.slots.spawn_lobby(companion.bhv, companion.model, x, y, z, function(o)
        if companion.second ~= nil then
            o.oBehParams2ndByte = companion.second
            o.oBehParams = (math.floor(companion.second) & 0xFF) << 16
        end
        o.parentObj = parent
    end)
    if friend ~= nil then
        table.insert(spawner.objects, friend)
        spawner.pool_spawned()
    end
    return friend
end

function spawner.spawn_at(key, x, y, z, yaw, extra)
    return spawn_at_body(key, x, y, z, yaw, extra)
end

function spawner.block_parts(entry)
    if entry == nil or entry.bhv == nil or entry.bhv ~= spawner.BLOCK then return nil end
    local byte = entry.variant or 0
    local slug = entry.material
    if slug == nil and type(entry.key) == "string" then
        if entry.key:sub(1, 3) == "blk" then
            slug = entry.key:sub(4)
        elseif type(entry.slope) == "string" and entry.key:sub(1, #entry.slope) == entry.slope then
            slug = entry.key:sub(#entry.slope + 1)
        end
    end
    if slug == nil or spawner.block_index(slug) == nil then return nil end
    return byte, slug
end

function spawner.block_word(entry, extra)
    local ST = OF.stretch

    if entry ~= nil and entry.decorWord ~= nil then return entry.decorWord end
    if ST == nil or extra == nil or spawner.SHAPE_MODEL_ID == nil then return nil end
    local byte, slug = spawner.block_parts(entry)
    if byte == nil or slug == spawner.WATER_MATERIAL or entry.span ~= nil then return nil end
    local texture = spawner.block_index(slug)
    if extra.arms ~= nil then
        local join = byte == ST.PILLAR_BYTE and ST.JOIN_PILLAR
            or (byte == ST.FENCE_BYTE or byte == ST.FENCE_BYTE + 1) and ST.JOIN_FENCE or nil
        if join == nil then return nil end
        local other = extra.other ~= nil and spawner.block_index(extra.other) or 0
        return ST.join_encode(join, texture, extra.arms, other)
    end
    local w, h, d = extra.w or 1, extra.h or 1, extra.d or 1
    if w == 1 and h == 1 and d == 1 then return nil end
    if byte ~= 0 and ST.SHAPES[byte] == nil then return nil end
    return ST.shape_encode(byte, texture, w, h, d)
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

local function on_level_init()
    spawner.objects = {}
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

local STAGE_MESH = {
    [0] = "checkerboard_platform_seg8_collision_0800D710",
    [1] = "metal_box_seg8_collision_08024C28",
    [2] = "breakable_box_seg8_collision_08012D70",
    [3] = "exclamation_box_outline_seg8_collision_08025F78",
}

local STAGE_STILL, STAGE_SPIN, STAGE_LIFT = 0, 1, 2

local STAGE_SPIN_STEP = 0x140
local STAGE_LIFT_RANGE = 500
local STAGE_LIFT_PERIOD = 300

local function stage_shape(o)
    local shape = math.floor(tonumber(o.oBehParams2ndByte) or 0)
    if STAGE_MESH[shape] == nil then return 0 end
    return shape
end

local function stage_motion(o)
    local params = math.floor(tonumber(o.oBehParams) or 0)

    local high = (params >> 24) & 0xFF
    if high > 127 then high = high - 256 end
    return high
end

local function wear_mesh(o, mesh)
    if o == nil or mesh == nil then return false end
    o.collisionData = mesh
    return true
end

local function stage_init(o)
    if o == nil then return end

    local data = _G["gGlobalObjectCollisionData"]
    local mesh = data ~= nil and data[STAGE_MESH[stage_shape(o)]] or nil
    wear_mesh(o, mesh)

    o.oCollisionDistance = STANDING_REACH

    o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosY, o.oPosZ
    o.oFaceAngleYaw = o.oMoveAngleYaw
end

local function stage_loop(o)
    if o == nil then return end

    local motion = stage_motion(o)
    local timer = math.floor(tonumber(o.oTimer) or 0)

    o.oAngleVelYaw = 0

    if motion == STAGE_SPIN then
        local yaw = (timer * STAGE_SPIN_STEP) % 0x10000
        o.oMoveAngleYaw = yaw

        o.oFaceAngleYaw = yaw

        o.oAngleVelYaw = STAGE_SPIN_STEP
    elseif motion == STAGE_LIFT then
        local phase = (timer % STAGE_LIFT_PERIOD) / STAGE_LIFT_PERIOD
        o.oPosY = (tonumber(o.oHomeY) or 0)
            + math.sin(phase * 2 * math.pi) * STAGE_LIFT_RANGE
    end

    if type(load_object_collision_model) == "function" then
        load_object_collision_model()
    end
end

spawner.STAGE = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    stage_init, stage_loop, "of stage")

spawner.STAGE_STILL = STAGE_STILL
spawner.STAGE_SPIN = STAGE_SPIN
spawner.STAGE_LIFT = STAGE_LIFT

function spawner.stage_mesh_name(shape)
    return STAGE_MESH[shape]
end

if spawner.STAGE ~= nil then
    table.insert(spawner.LIST, {
        key = "stage", name = "Stage", bhv = spawner.STAGE,
        model = E_MODEL_CHECKERBOARD_PLATFORM, reach = STANDING_REACH,
        variants = {
            { name = "a platform", value = 0, first = STAGE_STILL,
              model = E_MODEL_CHECKERBOARD_PLATFORM },
            { name = "a block", value = 1, first = STAGE_STILL,
              model = E_MODEL_METAL_BOX },
            { name = "a crate", value = 2, first = STAGE_STILL,
              model = E_MODEL_BREAKABLE_BOX },
            { name = "an outline", value = 3, first = STAGE_STILL,
              model = E_MODEL_EXCLAMATION_BOX_OUTLINE },
            { name = "a turntable", value = 0, first = STAGE_SPIN,
              model = E_MODEL_CHECKERBOARD_PLATFORM },
            { name = "a lift", value = 0, first = STAGE_LIFT,
              model = E_MODEL_CHECKERBOARD_PLATFORM },
        },
    })
end

local function racer_loop(o)
    if OF.forge ~= nil and type(OF.forge.racer_loop) == "function" then
        OF.forge.racer_loop(o)
    end
end
spawner.RACER = at_load("hook_behavior", nil, OBJ_LIST_LEVEL, false,
    nil, racer_loop, "of racer piece")

if spawner.RACER ~= nil then
    for _, row in ipairs({

        { key = "racestart", name = "Track start ring", racer = 1, model = E_MODEL_NONE },
        { key = "racegate", name = "Track checkpoint ring", racer = 2, model = E_MODEL_NONE },
        { key = "racefinish", name = "Track finish flag", racer = 3, model = E_MODEL_NONE },
        { key = "racebox", name = "Track item box", racer = 4, model = E_MODEL_EXCLAMATION_BOX },
        { key = "raceboost", name = "Track boost pad", racer = 5, model = E_MODEL_NONE },
        { key = "racecoin", name = "Track coin", racer = 6, model = E_MODEL_YELLOW_COIN },
        { key = "racerespawn", name = "Track respawn point", racer = 7, model = E_MODEL_NONE },
        { key = "raceout", name = "Track out zone", racer = 8, model = E_MODEL_NONE },
    }) do
        row.bhv = spawner.RACER
        row.reach = STANDING_REACH
        table.insert(spawner.LIST, row)
    end
end

spawner.ONOFF_KEYS = { [0] = "ofOnOff", [1] = "ofOcBit" }
spawner.ONOFF_ACTION = "onoff"
spawner.ONOFF_COOLDOWN = 60

spawner.ONOFF_SETTLE = { [0] = 0, [1] = spawner.ONOFF_COOLDOWN }
function spawner.onoff_settle(channel)
    return spawner.ONOFF_SETTLE[channel or 0] or spawner.ONOFF_COOLDOWN
end
spawner.ONOFF_SWITCH, spawner.ONOFF_RED, spawner.ONOFF_BLUE = 0, 1, 2

local ONOFF_MESH = {
    [0] = "purple_switch_seg8_collision_0800C7A8",
    [1] = "breakable_box_seg8_collision_08012D70",
    [2] = "breakable_box_seg8_collision_08012D70",
}
spawner.ONOFF_MESH_SHARE = 0.25

local ONOFF_RED_STATE, ONOFF_BLUE_STATE = 0, 2

spawner.ONOFF_BLOCK_SCALE = 4.0

function spawner.onoff_block_scale(o)
    return spawner.ONOFF_BLOCK_SCALE
end

local function onoff_kind(o)
    local kind = math.floor(tonumber(o.oBehParams2ndByte) or 0)
    if ONOFF_MESH[kind] == nil then return 0 end
    return kind
end

local function onoff_channel(o)
    local params = math.floor(tonumber(o.oBehParams) or 0)
    local channel = (params >> 24) & 0xFF
    if spawner.ONOFF_KEYS[channel] == nil then return 0 end
    return channel
end
spawner.onoff_channel = onoff_channel
spawner.onoff_kind = onoff_kind

function spawner.onoff_count(channel)
    local key = spawner.ONOFF_KEYS[channel or 0]
    return math.floor(tonumber(key ~= nil and gGlobalSyncTable[key] or 0) or 0)
end

function spawner.onoff_is_on(channel)
    return spawner.onoff_count(channel) % 2 == 0
end

function spawner.onoff_solid(kind, channel)
    if kind == spawner.ONOFF_SWITCH then return true end
    local on = spawner.onoff_is_on(channel)
    if kind == spawner.ONOFF_RED then return on end
    return not on
end

local onoffFlippedAt = {}

local onoffSeen = {}

local function now_frames()
    return get_global_timer ~= nil and get_global_timer() or 0
end

function spawner.host_onoff(channel)
    if not OF.util.is_host() then return false, "Only the host." end
    channel = math.floor(tonumber(channel) or 0)
    local key = spawner.ONOFF_KEYS[channel]
    if key == nil then return false, "No such switch." end
    local now = now_frames()
    if onoffFlippedAt[channel] ~= nil and now - onoffFlippedAt[channel] < spawner.onoff_settle(channel) then
        return false, "The switch is still settling."
    end
    onoffFlippedAt[channel] = now
    OF.util.publish(key, spawner.onoff_count(channel) + 1)
    return true
end

function spawner.press_onoff(channel)
    if channel == 0 and OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then
        return false, "Not inside a round"
    end
    if OF.util.is_host() then return spawner.host_onoff(channel) end
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does(spawner.ONOFF_ACTION, channel)
    end
    return false, "No host to ask yet - try again in a second."
end

function spawner.onoff_since(channel)
    local seen = onoffSeen[channel or 0]
    local count = spawner.onoff_count(channel)
    if seen == nil or seen.count ~= count then
        onoffSeen[channel or 0] = { count = count, at = now_frames(), first = seen == nil }
        seen = onoffSeen[channel or 0]
        if not seen.first and OF.util.asks(OF.sounds, "play") and SOUND_GENERAL2_PURPLE_SWITCH ~= nil then
            OF.sounds.play(SOUND_GENERAL2_PURPLE_SWITCH)
        end
    end
    if seen.first then return nil end
    return now_frames() - seen.at
end

local onoffStoodOn = nil

local function onoff_init(o)
    if o == nil then return end
    local data = _G["gGlobalObjectCollisionData"]
    local mesh = data ~= nil and data[ONOFF_MESH[onoff_kind(o)]] or nil
    wear_mesh(o, mesh)
    if onoff_kind(o) ~= spawner.ONOFF_SWITCH then
        OF.util.optional("obj_scale", nil, o, spawner.onoff_block_scale(o))
    end
    o.oCollisionDistance = STANDING_REACH
    o.oFlags = OF.util.add_flag(tonumber(o.oFlags) or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 0)
end

local function onoff_loop(o)
    if o == nil then return end
    local kind, channel = onoff_kind(o), onoff_channel(o)
    if kind == spawner.ONOFF_SWITCH then

        local m = gMarioStates[0]
        local standing = m ~= nil and m.floor ~= nil and m.floor.object == o
            and not OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x800)
        if standing and onoffStoodOn ~= o then spawner.press_onoff(channel) end
        if standing then
            onoffStoodOn = o
        elseif onoffStoodOn == o then
            onoffStoodOn = nil
        end
    else
        local solid = spawner.onoff_solid(kind, channel)
        local model = solid and E_MODEL_EXCLAMATION_BOX or E_MODEL_EXCLAMATION_BOX_OUTLINE
        if model ~= nil then
            if OF.util.optional("obj_has_model_extended", nil, o, model) ~= true then
                OF.slots.set_model(o, model)
            end
        end
        o.oAnimState = kind == spawner.ONOFF_RED and ONOFF_RED_STATE or ONOFF_BLUE_STATE
        if not solid then return end

        local scale = o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.scale or nil
        if scale ~= nil and type(load_object_collision_model) == "function" then
            local sx, sy, sz = scale.x, scale.y, scale.z
            local k = spawner.ONOFF_MESH_SHARE
            scale.x, scale.y, scale.z = sx * k, sy * k, sz * k
            local ok = pcall(load_object_collision_model)
            scale.x, scale.y, scale.z = sx, sy, sz
            if not ok then return end
        end
        return
    end
    if type(load_object_collision_model) == "function" then
        load_object_collision_model()
    end
end

spawner.ONOFF_KEYS_BY_NAME = { onoffswitch = 0, onoffred = 1, onoffblue = 2 }
function spawner.onoff_find(key)
    local kind = spawner.ONOFF_KEYS_BY_NAME[key]
    if kind == nil or spawner.ONOFF == nil then return nil end
    local models = { [0] = E_MODEL_PURPLE_SWITCH, [1] = E_MODEL_EXCLAMATION_BOX,
                     [2] = E_MODEL_EXCLAMATION_BOX_OUTLINE }
    return { key = key, name = "ON/OFF", bhv = spawner.ONOFF, model = models[kind],
             reach = STANDING_REACH, params = kind * 0x10000 }
end

spawner.ONOFF = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    onoff_init, onoff_loop, "of onoff")
spawner.onoff_loop = onoff_loop

local ONOFF_LIFT = 140
local onoffOut = { x = 0, y = 0, z = 0 }
local onoffAt = { x = 0, y = 0, z = 0 }
function spawner.draw_onoff_labels()
    if spawner.ONOFF == nil or obj_get_first_with_behavior_id == nil then return 0 end
    if OF.util.world_screen == nil or OF.util.world_label == nil then return 0 end
    local drawn = 0
    local o = obj_get_first_with_behavior_id(spawner.ONOFF)
    while o ~= nil do
        if onoff_kind(o) == spawner.ONOFF_SWITCH then
            local channel = onoff_channel(o)
            local since = spawner.onoff_since(channel)
            local on = spawner.onoff_is_on(channel)
            local r, g, b = 255, 90, 90
            if not on then r, g, b = 110, 150, 255 end
            if since ~= nil and since < spawner.onoff_settle(channel) then r, g, b = 150, 150, 150 end
            onoffAt.x, onoffAt.y, onoffAt.z = o.oPosX, o.oPosY + ONOFF_LIFT, o.oPosZ
            if OF.util.world_screen(onoffAt, onoffOut) then
                OF.util.world_label(onoffOut.x, onoffOut.y, OF.lang.t(on and "ON" or "OFF"),
                    0.6, r, g, b, 230)
                drawn = drawn + 1
            end
        end
        o = obj_get_next_with_same_behavior_id(o)
    end
    return drawn
end

hook_event(HOOK_ON_HUD_RENDER, function()

    if OF.util.menu_has_screen() then return end
    if djui_hud_set_resolution ~= nil then djui_hud_set_resolution(RESOLUTION_DJUI) end
    spawner.draw_onoff_labels()
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_action") then
        OF.net.register_action(spawner.ONOFF_ACTION, "round_move", function(fromLocal, x)
            if not OF.util.is_host() then return false, "Only the host." end
            local channel = math.floor(tonumber(x) or 0)

            if channel == 0 and OF.util.asks(OF.roundscope, "inside")
                and OF.roundscope.inside(tonumber(fromLocal) or 0) then
                return false, "Not inside a round"
            end
            return spawner.host_onoff(channel)
        end)
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    onoffStoodOn = nil
end)

if spawner.ONOFF ~= nil then
    table.insert(spawner.LIST, {
        key = "onoff", name = "ON/OFF", bhv = spawner.ONOFF,
        model = E_MODEL_PURPLE_SWITCH, reach = STANDING_REACH,
        variants = {
            { name = "a switch", value = spawner.ONOFF_SWITCH, first = 0,
              model = E_MODEL_PURPLE_SWITCH },
            { name = "a red block, solid on ON", value = spawner.ONOFF_RED, first = 0,
              model = E_MODEL_EXCLAMATION_BOX },
            { name = "a blue block, solid on OFF", value = spawner.ONOFF_BLUE, first = 0,
              model = E_MODEL_EXCLAMATION_BOX_OUTLINE },
        },
    })
end

local function logic_init(o)
    if o == nil then return end
    if OF.util.asks(OF.logic, "kind") and OF.logic.kind(o) == 2 then
        local data = _G["gGlobalObjectCollisionData"]
        wear_mesh(o, data ~= nil and data["purple_switch_seg8_collision_0800C7A8"] or nil)
    end
    o.oFlags = OF.util.add_flag(tonumber(o.oFlags) or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 0)
    if OF.logic ~= nil and type(OF.logic.init) == "function" then OF.logic.init(o) end
end

local function logic_loop(o)
    if OF.logic ~= nil and type(OF.logic.loop) == "function" then OF.logic.loop(o) end
end

spawner.LOGIC = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    logic_init, logic_loop, "of logic")

if spawner.LOGIC ~= nil then
    table.insert(spawner.LIST, {
        key = "logic", name = "Targets and triggers", bhv = spawner.LOGIC,
        model = E_MODEL_WOODEN_SIGNPOST, reach = STANDING_REACH, logic = true,
        variants = {
            { name = "a pop-up target", value = 1, model = E_MODEL_WOODEN_SIGNPOST },
            { name = "a button", value = 2, model = E_MODEL_PURPLE_SWITCH },
            { name = "a zone", value = 3, model = E_MODEL_NONE },
        },
    })
end

local function ball_anchor_init(o)
    if o == nil then return end
    local node = o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.node or nil
    local hidden = GRAPH_RENDER_INVISIBLE or 16
    if node ~= nil and not OF.util.has_flag(node.flags or 0, hidden) then
        node.flags = (node.flags or 0) + hidden
    end
    o.oInteractType = 0
    o.oIntangibleTimer = -1
end

spawner.BALL = at_load("hook_behavior", nil, OBJ_LIST_DEFAULT, false,
    ball_anchor_init, nil, "of ball")

if spawner.BALL ~= nil then
    table.insert(spawner.LIST, {
        key = "ball", name = "Ball to ride", bhv = spawner.BALL,
        model = E_MODEL_BOWLING_BALL,
    })
end

do
    local TRI_MODEL_NAME = "of_triblock_geo"
    local TRI_COL_NAME = "of_triblock_col"
    function spawner.triblock_model()
        if at_load("mod_file_exists", "actors/" .. TRI_MODEL_NAME .. ".bin") ~= true then
            return E_MODEL_CHECKERBOARD_PLATFORM
        end
        local id = at_load("smlua_model_util_get_id", TRI_MODEL_NAME)
        if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then
            return E_MODEL_CHECKERBOARD_PLATFORM
        end
        return id
    end

    local function triblock_mesh()
        return at_load("smlua_collision_util_get", TRI_COL_NAME)
    end

    local docked = setmetatable({}, { __mode = "k" })

    local function tri_init(o)
        if o == nil then return end
        wear_mesh(o, triblock_mesh())
        o.oCollisionDistance = STANDING_REACH
        o.oFlags = OF.util.add_flag(tonumber(o.oFlags) or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 0)
    end

    local function owned_here(o)
        if (tonumber(o.oSyncID) or 0) == 0 then return true end
        return OF.util.optional("sync_object_is_owned_locally", false, o.oSyncID) == true
    end

    local function tri_loop(o)
        if o == nil then return end
        local held = OF.forge ~= nil and OF.forge.held == o
        if held then
            docked[o] = nil
        elseif not docked[o] and (tonumber(o.oTimer) or 0) >= 2 and owned_here(o) then
            docked[o] = true
            spawner.dock_triblock(o)
        end
        spawner.triblock_trigger(o)
        if type(load_object_collision_model) == "function" then
            load_object_collision_model()
        end
    end

    spawner.TRIBLOCK = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
        tri_init, tri_loop, "of triblock")

    spawner.WALL_RUN = at_load("allocate_mario_action",
        (ACT_GROUP_AIRBORNE or 0x080) | (ACT_FLAG_AIR or 0x800))
end

function spawner.in_a_round()
    return OF.util.asks(OF.lockdown, "menu_stands_down") and OF.lockdown.menu_stands_down() == true
end

spawner.TRIBLOCK_WIDE = 200
spawner.TRIBLOCK_DEEP = 200
spawner.TRIBLOCK_TALL = 200
spawner.TRIBLOCK_RUN_SPEED = 29
spawner.TRIBLOCK_DOCK_REACH = 600
spawner.WALL_RUN_SPEED = 40
spawner.WALL_RUN_LEAST = 24
spawner.WALL_RUN_GAP = 50
spawner.WALL_RUN_MOST = 240
spawner.WALL_RUN_HOP = 52
do
    local PITCH_SLOPE, PITCH_WALL = -0x2000, -0x4000
    local function has_flag(value, flag)
        if value == nil or flag == nil or flag == 0 then return false end
        return math.floor(value / flag) % 2 == 1
    end

    local function facing(yaw)
        local turn = (tonumber(yaw) or 0) * 2 * math.pi / 0x10000
        return math.sin(turn), math.cos(turn)
    end

    local function yaw_of(x, z)
        return math.floor(math.atan(x, z) * 0x8000 / math.pi) % 0x10000
    end

    local function ray(sx, sy, sz, dx, dy, dz)
        if collision_find_surface_on_ray == nil then return nil end
        local info = collision_find_surface_on_ray(sx, sy, sz, dx, dy, dz)
        if info == nil or info.surface == nil or info.surface.normal == nil then return nil end
        return info.hitPos.x, info.hitPos.y, info.hitPos.z, info.surface.normal
    end

    function spawner.dock_triblock(o)
        if o == nil then return false end
        local bx, bz = facing(o.oFaceAngleYaw)
        local tries = { { -bx, -bz } }
        for k = 0, 7 do
            local a = k * math.pi / 4
            tries[#tries + 1] = { math.sin(a), math.cos(a) }
        end
        local best, bestD = nil, nil
        local reach = spawner.TRIBLOCK_DOCK_REACH
        for _, d in ipairs(tries) do
            local hx, _, hz, n = ray(o.oPosX, o.oPosY + 50, o.oPosZ, d[1] * reach, 0, d[2] * reach)
            if hx ~= nil and math.abs(n.y or 0) < 0.3 then
                local dist = (hx - o.oPosX) ^ 2 + (hz - o.oPosZ) ^ 2
                if bestD == nil or dist < bestD - 1 then best, bestD = { hx, hz, n }, dist end
            end
        end
        if best == nil then return false end
        local n = best[3]
        local len = math.sqrt((n.x or 0) ^ 2 + (n.z or 0) ^ 2)
        if len < 0.01 then return false end
        local nx, nz = n.x / len, n.z / len
        o.oPosX, o.oPosZ = best[1] + nx * 1, best[2] + nz * 1
        local floor = spawner.optional("find_floor_height", nil, o.oPosX, o.oPosY + 200, o.oPosZ)
        if type(floor) == "number" and floor > -10000 then o.oPosY = floor end
        local yaw = yaw_of(nx, nz)
        o.oFaceAngleYaw, o.oMoveAngleYaw = yaw, yaw
        return true
    end

    spawner.facing, spawner.yaw_of = facing, yaw_of

    local run = nil

    function spawner.wall_running(m)
        m = m or gMarioStates[0]
        return m ~= nil and spawner.WALL_RUN ~= nil and m.action == spawner.WALL_RUN
    end

    function spawner.wall_run_state()
        return run
    end

    local function in_a_round()
        return spawner.in_a_round()
    end

    function spawner.triblock_trigger(o)
        local m = gMarioStates[0]
        if o == nil or m == nil or m.pos == nil or spawner.WALL_RUN == nil then return false end
        if spawner.wall_running(m) or in_a_round() then return false end
        if m.floor == nil or m.floor.object ~= o then return false end
        if has_flag(m.action or 0, ACT_FLAG_AIR or 0x800) then return false end
        if (m.forwardVel or 0) < spawner.TRIBLOCK_RUN_SPEED then return false end
        local nx, nz = facing(o.oFaceAngleYaw)
        local fx, fz = facing(m.faceAngle ~= nil and m.faceAngle.y or 0)

        if fx * nx + fz * nz > -0.7 then return false end
        local scale = o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.scale ~= nil
            and (o.header.gfx.scale.y or 1) or 1
        run = { nx = nx, nz = nz, wx = o.oPosX, wz = o.oPosZ,
                speed = math.max(spawner.WALL_RUN_SPEED, m.forwardVel or 0), frames = 0,
                slope = true, slopeTop = o.oPosY + spawner.TRIBLOCK_TALL * scale }
        set_mario_action(m, spawner.WALL_RUN, 0)
        return true
    end

    local function out_from_wall(m)
        return (m.pos.x - run.wx) * run.nx + (m.pos.z - run.wz) * run.nz
    end

    local function end_run(m, action)
        run = nil
        if m ~= nil and set_mario_action ~= nil then set_mario_action(m, action or ACT_FREEFALL, 0) end
    end

    local TOP_FIRST, TOP_LAST, TOP_STEP, TOP_REACH, TOP_UNDER = 40, 260, 10, 120, 10
    local WALL_PROBES = { 100, 70, 130 }
    local TOP_RUN
    local function top_ahead(m)
        local first, last, height = nil, nil, nil
        for d = TOP_FIRST, TOP_LAST, TOP_STEP do
            local f = spawner.optional("find_floor_height", nil, m.pos.x - run.nx * d,
                m.pos.y + 300, m.pos.z - run.nz * d)

            local under = TOP_UNDER + (run ~= nil and run.speed or 0)
            local ok = type(f) == "number" and f >= m.pos.y - under and f < m.pos.y + 300
            if ok and (height == nil or math.abs(f - height) <= 30) then
                if first == nil then first, height = d, f end
                last = d
            elseif first ~= nil then
                break
            end
        end
        if first == nil then return nil end
        local d = math.min((first + last) / 2, TOP_REACH)
        if d < first then d = first end
        local ox, oz = m.pos.x - run.nx * d, m.pos.z - run.nz * d
        return ox, oz, spawner.optional("find_floor_height", nil, ox, m.pos.y + 300, oz)
    end
    spawner.wall_run_top_ahead = top_ahead

    TOP_RUN = 32
    local function over_the_top(m)
        local ox, oz, floor = top_ahead(m)
        local speed = math.min(run.speed, TOP_RUN)
        local nx, nz = run.nx, run.nz
        if type(floor) == "number" and floor > m.pos.y - 200 - run.speed
                and floor < m.pos.y + 300 then
            m.pos.x, m.pos.y, m.pos.z = ox, floor, oz
            m.faceAngle.y = yaw_of(-nx, -nz)
            end_run(m, ACT_WALKING)
            m.vel.x, m.vel.y, m.vel.z = -nx * speed, 0, -nz * speed
            m.forwardVel = speed
            return "top"
        end
        end_run(m, ACT_FREEFALL)
        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        m.forwardVel = 0
        return "fell"
    end

    function spawner.wall_run_step(m)
        if m == nil or run == nil then return nil end
        if in_a_round() then
            end_run(m, ACT_FREEFALL)
            return "round"
        end
        local c = m.controller
        if c ~= nil and has_flag(c.buttonPressed or 0, A_BUTTON or 0x8000) then
            m.faceAngle.y = yaw_of(run.nx, run.nz)
            m.forwardVel = 24
            m.vel.y = spawner.WALL_RUN_HOP
            run = nil
            set_mario_action(m, ACT_WALL_KICK_AIR or ACT_JUMP, 0)
            m.vel.y = spawner.WALL_RUN_HOP
            m.forwardVel = 24
            return "jump"
        end
        run.frames = run.frames + 1
        if run.frames > spawner.WALL_RUN_MOST then
            end_run(m, ACT_FREEFALL)
            return "fell"
        end
        m.faceAngle.y = yaw_of(-run.nx, -run.nz)
        m.vel.x, m.vel.y, m.vel.z = 0, run.speed, 0
        m.forwardVel = run.speed

        if run.slope then
            local step = run.speed * 0.7071
            m.pos.x = m.pos.x - run.nx * step
            m.pos.z = m.pos.z - run.nz * step
            m.pos.y = m.pos.y + step
            if out_from_wall(m) <= spawner.WALL_RUN_GAP or m.pos.y >= run.slopeTop then
                run.slope = false
                local d = out_from_wall(m)
                m.pos.x = m.pos.x + run.nx * (spawner.WALL_RUN_GAP - d)
                m.pos.z = m.pos.z + run.nz * (spawner.WALL_RUN_GAP - d)
            end
            return "slope"
        end

        local ceil = spawner.optional("find_ceil_height", nil, m.pos.x, m.pos.y + 80, m.pos.z)
        if type(ceil) == "number" and ceil < m.pos.y + 160 + run.speed then
            m.faceAngle.y = yaw_of(run.nx, run.nz)
            local nx, nz = run.nx, run.nz
            end_run(m, ACT_FREEFALL)
            m.vel.y = 0
            m.forwardVel = 12
            m.pos.x, m.pos.z = m.pos.x + nx * 20, m.pos.z + nz * 20
            if SOUND_ACTION_BONK ~= nil then spawner.play_sound(SOUND_ACTION_BONK) end
            return "bonk"
        end

        local hx = nil
        for _, up in ipairs(WALL_PROBES) do
            hx = hx or ray(m.pos.x + run.nx * 10, m.pos.y + up, m.pos.z + run.nz * 10,
                -run.nx * 160, 0, -run.nz * 160)
        end
        if hx == nil then return over_the_top(m) end
        m.pos.y = m.pos.y + run.speed
        run.speed = math.max(spawner.WALL_RUN_LEAST, run.speed - 0.15)
        local d = out_from_wall(m)
        m.pos.x = m.pos.x + run.nx * (spawner.WALL_RUN_GAP - d)
        m.pos.z = m.pos.z + run.nz * (spawner.WALL_RUN_GAP - d)
        return "wall"
    end

    local function act_wall_run(m)
        if m == nil then return false end
        if m.playerIndex == 0 then
            if run == nil then
                set_mario_action(m, ACT_FREEFALL, 0)
                return false
            end
            spawner.wall_run_step(m)
        end
        if set_character_anim_with_accel ~= nil and spawner.wall_running(m) then
            set_character_anim_with_accel(m, CHAR_ANIM_RUNNING, 0x40000)
        end
        spawner.wall_run_picture(m)
        return false
    end

    function spawner.wall_run_picture(m)
        if m == nil or m.marioObj == nil or m.pos == nil then return false end
        local gfx = m.marioObj.header.gfx
        if gfx == nil or gfx.pos == nil then return false end
        gfx.pos.x, gfx.pos.y, gfx.pos.z = m.pos.x, m.pos.y, m.pos.z
        if gfx.angle ~= nil and m.faceAngle ~= nil then
            gfx.angle.y = m.faceAngle.y
            gfx.angle.z = 0
        end
        return true
    end

    function spawner.wall_run_pose(m)
        if m == nil or m.marioObj == nil or not spawner.wall_running(m) then return false end
        local gfx = m.marioObj.header.gfx
        if gfx == nil or gfx.angle == nil then return false end
        local onSlope = m.playerIndex == 0 and run ~= nil and run.slope
        gfx.angle.x = onSlope and PITCH_SLOPE or PITCH_WALL
        return true
    end

    function spawner.forget_wall_run()
        run = nil
    end
    spawner.act_wall_run = act_wall_run
end

if spawner.WALL_RUN ~= nil then
    at_load("hook_mario_action", spawner.WALL_RUN, { every_frame = spawner.act_wall_run })
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    spawner.wall_run_pose(m)
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    spawner.forget_wall_run()
end)

if spawner.TRIBLOCK ~= nil then
    table.insert(spawner.LIST, {
        key = "triblock", name = "Triangular Block", bhv = spawner.TRIBLOCK,
        model = spawner.triblock_model(), reach = STANDING_REACH,
    })
end

local BUILD_CELL = 200
spawner.BUILD_CELL = BUILD_CELL

local BLOCK_WIDTH = 200
local BLOCK_SHELVES = {
    { name = "Stone", blocks = {
        { key = "blkstone1", name = "Light flagstone", geo = "of_blk_stone1_geo", tex = "of_blk_stone1_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkstone2", name = "Dark cobble", geo = "of_blk_stone2_geo", tex = "of_blk_stone2_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkflagstone", name = "Warm flagstone", geo = "of_blk_flagstone_geo", tex = "of_blk_flagstone_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkmossyrock", name = "Mossy cliff", geo = "of_blk_mossyrock_geo", tex = "of_blk_mossyrock_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkgreystone", name = "Smooth stone", geo = "of_blk_greystone_geo", tex = "of_blk_greystone_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkfrostedrock", name = "Frosted rock", geo = "of_blk_frostedrock_geo", tex = "of_blk_frostedrock_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blksbdark", name = "Dark stone brick", geo = "of_blk_sbdark_geo", tex = "of_blk_sbdark_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksbgreymossy", name = "Stone brick, mossy", geo = "of_blk_sbgreymossy_geo", tex = "of_blk_sbgreymossy_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksbgreyworn", name = "Stone brick, worn", geo = "of_blk_sbgreyworn_geo", tex = "of_blk_sbgreyworn_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksbsmall", name = "Small stone brick", geo = "of_blk_sbsmall_geo", tex = "of_blk_sbsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blksbgreycracked", name = "Stone brick, cracked", geo = "of_blk_sbgreycracked_geo", tex = "of_blk_sbgreycracked_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksbrustic", name = "Rustic stone brick", geo = "of_blk_sbrustic_geo", tex = "of_blk_sbrustic_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksbgrey", name = "Stone brick", geo = "of_blk_sbgrey_geo", tex = "of_blk_sbgrey_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksblarge", name = "Large stone brick", geo = "of_blk_sblarge_geo", tex = "of_blk_sblarge_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksbblue", name = "Blue stone brick", geo = "of_blk_sbblue_geo", tex = "of_blk_sbblue_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksbwarm", name = "Warm stone brick", geo = "of_blk_sbwarm_geo", tex = "of_blk_sbwarm_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcobblemossy", name = "Cobble, mossy", geo = "of_blk_cobblemossy_geo", tex = "of_blk_cobblemossy_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkcobbleworn", name = "Cobble, worn", geo = "of_blk_cobbleworn_geo", tex = "of_blk_cobbleworn_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflagslate", name = "Slate flagstone", geo = "of_blk_flagslate_geo", tex = "of_blk_flagslate_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkcobble", name = "Cobble", geo = "of_blk_cobble_geo", tex = "of_blk_cobble_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkflagmossy", name = "Flagstone, mossy", geo = "of_blk_flagmossy_geo", tex = "of_blk_flagmossy_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksetts", name = "Setts", geo = "of_blk_setts_geo", tex = "of_blk_setts_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkcobblewarm", name = "Warm cobble", geo = "of_blk_cobblewarm_geo", tex = "of_blk_cobblewarm_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflagcracked", name = "Flagstone, cracked", geo = "of_blk_flagcracked_geo", tex = "of_blk_flagcracked_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkcastledark", name = "Dark castle stone", geo = "of_blk_castledark_geo", tex = "of_blk_castledark_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcastlemossy", name = "Castle stone, mossy", geo = "of_blk_castlemossy_geo", tex = "of_blk_castlemossy_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcastleworn", name = "Castle stone, worn", geo = "of_blk_castleworn_geo", tex = "of_blk_castleworn_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcastlegrey", name = "Castle stone", geo = "of_blk_castlegrey_geo", tex = "of_blk_castlegrey_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcastleblue", name = "Blue castle stone", geo = "of_blk_castleblue_geo", tex = "of_blk_castleblue_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcastlesand", name = "Sand castle stone", geo = "of_blk_castlesand_geo", tex = "of_blk_castlesand_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcastlelight", name = "Light castle stone", geo = "of_blk_castlelight_geo", tex = "of_blk_castlelight_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
    } },
    { name = "Cut stone and marble", blocks = {
        { key = "blkmarbleblack", name = "Black marble", geo = "of_blk_marbleblack_geo", tex = "of_blk_marbleblack_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcutdark", name = "Dark cut stone", geo = "of_blk_cutdark_geo", tex = "of_blk_cutdark_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcutband", name = "Cornice band", geo = "of_blk_cutband_geo", tex = "of_blk_cutband_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkmarblegreen", name = "Jade marble", geo = "of_blk_marblegreen_geo", tex = "of_blk_marblegreen_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkmarblegreencalm", name = "Jade marble, calm", geo = "of_blk_marblegreencalm_geo", tex = "of_blk_marblegreencalm_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcutpanel", name = "Stone panel", geo = "of_blk_cutpanel_geo", tex = "of_blk_cutpanel_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcutfluted", name = "Fluted stone", geo = "of_blk_cutfluted_geo", tex = "of_blk_cutfluted_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkmarblerose", name = "Rose marble", geo = "of_blk_marblerose_geo", tex = "of_blk_marblerose_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcutlight", name = "Light cut stone", geo = "of_blk_cutlight_geo", tex = "of_blk_cutlight_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkmarblewhitecalm", name = "White marble, calm", geo = "of_blk_marblewhitecalm_geo", tex = "of_blk_marblewhitecalm_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
    } },
    { name = "Brick", blocks = {
        { key = "blkbrickdarkgrey", name = "Castle base stone", geo = "of_blk_brickdarkgrey_geo", tex = "of_blk_brickdarkgrey_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbricklightgrey", name = "White brick", geo = "of_blk_bricklightgrey_geo", tex = "of_blk_bricklightgrey_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrickpyramid", name = "Sandstone brick", geo = "of_blk_brickpyramid_geo", tex = "of_blk_brickpyramid_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,prism,roundcorner,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbricktwocolored", name = "Terracotta tiles", geo = "of_blk_bricktwocolored_geo", tex = "of_blk_bricktwocolored_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,prism,roundcorner,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkredbrick", name = "Red brick", geo = "of_blk_redbrick_geo", tex = "of_blk_redbrick_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwhitestonebrick", name = "Light stone brick", geo = "of_blk_whitestonebrick_geo", tex = "of_blk_whitestonebrick_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,prism,roundcorner,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrdarkcracked", name = "Dark brick, cracked", geo = "of_blk_brdarkcracked_geo", tex = "of_blk_brdarkcracked_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrreddark", name = "Dark red brick", geo = "of_blk_brreddark_geo", tex = "of_blk_brreddark_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrdark", name = "Dark brick", geo = "of_blk_brdark_geo", tex = "of_blk_brdark_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrbrown", name = "Brown brick", geo = "of_blk_brbrown_geo", tex = "of_blk_brbrown_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrsoldier", name = "Soldier course", geo = "of_blk_brsoldier_geo", tex = "of_blk_brsoldier_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrclinker", name = "Clinker brick", geo = "of_blk_brclinker_geo", tex = "of_blk_brclinker_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrredmossy", name = "Red brick, mossy", geo = "of_blk_brredmossy_geo", tex = "of_blk_brredmossy_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrredcracked", name = "Red brick, cracked", geo = "of_blk_brredcracked_geo", tex = "of_blk_brredcracked_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrredworn", name = "Red brick, worn", geo = "of_blk_brredworn_geo", tex = "of_blk_brredworn_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrstack", name = "Stack bond brick", geo = "of_blk_brstack_geo", tex = "of_blk_brstack_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrbasket", name = "Basketweave brick", geo = "of_blk_brbasket_geo", tex = "of_blk_brbasket_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkbrredlight", name = "Light red brick", geo = "of_blk_brredlight_geo", tex = "of_blk_brredlight_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbryellowworn", name = "Yellow brick, worn", geo = "of_blk_bryellowworn_geo", tex = "of_blk_bryellowworn_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbryellow", name = "Yellow brick", geo = "of_blk_bryellow_geo", tex = "of_blk_bryellow_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrbasketyellow", name = "Yellow basketweave", geo = "of_blk_brbasketyellow_geo", tex = "of_blk_brbasketyellow_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Wood", blocks = {
        { key = "blkwoodenplank1", name = "Dark oak planks", geo = "of_blk_woodenplank1_geo", tex = "of_blk_woodenplank1_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkwoodenplank2", name = "Mahogany planks", geo = "of_blk_woodenplank2_geo", tex = "of_blk_woodenplank2_texture", runtime = "doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,plate,pole,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkdarkplanks", name = "Walnut planks", geo = "of_blk_darkplanks_geo", tex = "of_blk_darkplanks_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkshipplanks", name = "Dark boards", geo = "of_blk_shipplanks_geo", tex = "of_blk_shipplanks_texture", runtime = "doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkhatchedwood", name = "Pine planks", geo = "of_blk_hatchedwood_geo", tex = "of_blk_hatchedwood_texture", runtime = "doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,plate,pole,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkgreenplanks", name = "Oak planks, mossy", geo = "of_blk_greenplanks_geo", tex = "of_blk_greenplanks_texture", runtime = "doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,plate,pole,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcrate", name = "Crate", geo = "of_blk_crate_geo", tex = "of_blk_crate_texture", runtime = "doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,plate,pole,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdpaneldark", name = "Dark wood panel", geo = "of_blk_wdpaneldark_geo", tex = "of_blk_wdpaneldark_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdvertred", name = "Red boards", geo = "of_blk_wdvertred_geo", tex = "of_blk_wdvertred_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdpanel", name = "Wood panel", geo = "of_blk_wdpanel_geo", tex = "of_blk_wdpanel_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdoakworn", name = "Oak planks, worn", geo = "of_blk_wdoakworn_geo", tex = "of_blk_wdoakworn_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdvert", name = "Vertical boards", geo = "of_blk_wdvert_geo", tex = "of_blk_wdvert_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdvertblue", name = "Blue boards", geo = "of_blk_wdvertblue_geo", tex = "of_blk_wdvertblue_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwddeck", name = "Deck", geo = "of_blk_wddeck_geo", tex = "of_blk_wddeck_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkwdparquet", name = "Parquet", geo = "of_blk_wdparquet_geo", tex = "of_blk_wdparquet_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope" },
        { key = "blkwddrift", name = "Driftwood", geo = "of_blk_wddrift_geo", tex = "of_blk_wddrift_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdoaklight", name = "Light oak planks", geo = "of_blk_wdoaklight_geo", tex = "of_blk_wdoaklight_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope" },
    } },
    { name = "Roof", blocks = {
        { key = "blkrfslatedark", name = "Dark slate roof", geo = "of_blk_rfslatedark_geo", tex = "of_blk_rfslatedark_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfclaydark", name = "Dark clay roof", geo = "of_blk_rfclaydark_geo", tex = "of_blk_rfclaydark_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfshinglegreen", name = "Green shingles", geo = "of_blk_rfshinglegreen_geo", tex = "of_blk_rfshinglegreen_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfslate", name = "Slate roof", geo = "of_blk_rfslate_geo", tex = "of_blk_rfslate_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfslateworn", name = "Slate roof, worn", geo = "of_blk_rfslateworn_geo", tex = "of_blk_rfslateworn_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfthatchdark", name = "Old thatch", geo = "of_blk_rfthatchdark_geo", tex = "of_blk_rfthatchdark_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfclaymossy", name = "Clay roof, mossy", geo = "of_blk_rfclaymossy_geo", tex = "of_blk_rfclaymossy_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfshingle", name = "Wood shingles", geo = "of_blk_rfshingle_geo", tex = "of_blk_rfshingle_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfshingleblue", name = "Blue shingles", geo = "of_blk_rfshingleblue_geo", tex = "of_blk_rfshingleblue_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfslategreen", name = "Green slate roof", geo = "of_blk_rfslategreen_geo", tex = "of_blk_rfslategreen_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrftin", name = "Red tin roof", geo = "of_blk_rftin_geo", tex = "of_blk_rftin_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkrfclay", name = "Clay roof", geo = "of_blk_rfclay_geo", tex = "of_blk_rfclay_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfshinglegrey", name = "Grey shingles", geo = "of_blk_rfshinglegrey_geo", tex = "of_blk_rfshinglegrey_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfbarrel", name = "Barrel tiles", geo = "of_blk_rfbarrel_geo", tex = "of_blk_rfbarrel_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfmetal", name = "Metal roof", geo = "of_blk_rfmetal_geo", tex = "of_blk_rfmetal_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfclayorange", name = "Orange clay roof", geo = "of_blk_rfclayorange_geo", tex = "of_blk_rfclayorange_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfcopper", name = "Copper roof", geo = "of_blk_rfcopper_geo", tex = "of_blk_rfcopper_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfthatch", name = "Thatch", geo = "of_blk_rfthatch_geo", tex = "of_blk_rfthatch_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Metal", blocks = {
        { key = "blkdiamondplate", name = "Tread plate", geo = "of_blk_diamondplate_geo", tex = "of_blk_diamondplate_texture", runtime = "doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,plate,pole,prism,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,window" },
        { key = "blkstuddedsteel", name = "Riveted steel", geo = "of_blk_studdedsteel_geo", tex = "of_blk_studdedsteel_texture", runtime = "doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,pole,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkrivetedplate", name = "Rusty riveted plate", geo = "of_blk_rivetedplate_geo", tex = "of_blk_rivetedplate_texture", runtime = "doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,pole,prism,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner,window" },
        { key = "blksteeldark", name = "Dark iron", geo = "of_blk_steeldark_geo", tex = "of_blk_steeldark_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksteelgrate", name = "Steel grate", geo = "of_blk_steelgrate_geo", tex = "of_blk_steelgrate_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkrustplate", name = "Rusty plate", geo = "of_blk_rustplate_geo", tex = "of_blk_rustplate_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksteelvent", name = "Vent", geo = "of_blk_steelvent_geo", tex = "of_blk_steelvent_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrasspipes", name = "Brass pipes", geo = "of_blk_brasspipes_geo", tex = "of_blk_brasspipes_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcopperpatina", name = "Verdigris copper", geo = "of_blk_copperpatina_geo", tex = "of_blk_copperpatina_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkcopperplate", name = "Copper plate", geo = "of_blk_copperplate_geo", tex = "of_blk_copperplate_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksteelcorrugated", name = "Corrugated steel", geo = "of_blk_steelcorrugated_geo", tex = "of_blk_steelcorrugated_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksteelplate", name = "Steel plate", geo = "of_blk_steelplate_geo", tex = "of_blk_steelplate_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkgoldplate", name = "Gold plate", geo = "of_blk_goldplate_geo", tex = "of_blk_goldplate_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Earth and grass", blocks = {
        { key = "blksand", name = "Sand", geo = "of_blk_sand_geo", tex = "of_blk_sand_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgrass", name = "Grass", geo = "of_blk_grass_geo", tex = "of_blk_grass_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkdirt", name = "Dirt", geo = "of_blk_dirt_geo", tex = "of_blk_dirt_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgrassblock", name = "Grass block", geo = "of_blk_grassblock_geo", tex = "of_blk_grassblock_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksnowblock", name = "Snow block", geo = "of_blk_snowblock_geo", tex = "of_blk_snowblock_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksandblock", name = "Sand block", geo = "of_blk_sandblock_geo", tex = "of_blk_sandblock_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkdirtdark", name = "Dark loam", geo = "of_blk_dirtdark_geo", tex = "of_blk_dirtdark_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkmud", name = "Mud", geo = "of_blk_mud_geo", tex = "of_blk_mud_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrockdark", name = "Dark cliff", geo = "of_blk_rockdark_geo", tex = "of_blk_rockdark_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkdirtred", name = "Red earth", geo = "of_blk_dirtred_geo", tex = "of_blk_dirtred_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkmoss", name = "Moss", geo = "of_blk_moss_geo", tex = "of_blk_moss_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkdirtpebbly", name = "Pebbly dirt", geo = "of_blk_dirtpebbly_geo", tex = "of_blk_dirtpebbly_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgrasslush", name = "Lush grass", geo = "of_blk_grasslush_geo", tex = "of_blk_grasslush_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrockbrown", name = "Brown cliff", geo = "of_blk_rockbrown_geo", tex = "of_blk_rockbrown_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkgrassclover", name = "Clover", geo = "of_blk_grassclover_geo", tex = "of_blk_grassclover_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgravelbrown", name = "Brown gravel", geo = "of_blk_gravelbrown_geo", tex = "of_blk_gravelbrown_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrockgrey", name = "Grey cliff", geo = "of_blk_rockgrey_geo", tex = "of_blk_rockgrey_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkgrassteal", name = "Cool grass", geo = "of_blk_grassteal_geo", tex = "of_blk_grassteal_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrockboulder", name = "Boulders", geo = "of_blk_rockboulder_geo", tex = "of_blk_rockboulder_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkgravel", name = "Gravel", geo = "of_blk_gravel_geo", tex = "of_blk_gravel_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkmudcracked", name = "Cracked mud", geo = "of_blk_mudcracked_geo", tex = "of_blk_mudcracked_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkpathgravel", name = "Gravel path", geo = "of_blk_pathgravel_geo", tex = "of_blk_pathgravel_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksandwet", name = "Wet sand", geo = "of_blk_sandwet_geo", tex = "of_blk_sandwet_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkpath", name = "Trodden path", geo = "of_blk_path_geo", tex = "of_blk_path_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgrassdry", name = "Dry grass", geo = "of_blk_grassdry_geo", tex = "of_blk_grassdry_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksanddune", name = "Dune sand", geo = "of_blk_sanddune_geo", tex = "of_blk_sanddune_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksandwhite", name = "White sand", geo = "of_blk_sandwhite_geo", tex = "of_blk_sandwhite_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgrasscliffcube", name = "Grass cliff block", geo = "of_blk_grasscliffcube_geo", tex = "of_blk_grasscliffcube_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgrassdrycube", name = "Dry grass block", geo = "of_blk_grassdrycube_geo", tex = "of_blk_grassdrycube_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgrasslushcube", name = "Lush grass block", geo = "of_blk_grasslushcube_geo", tex = "of_blk_grasslushcube_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkmosscube", name = "Moss block", geo = "of_blk_mosscube_geo", tex = "of_blk_mosscube_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksanddirtcube", name = "Sandy dirt block", geo = "of_blk_sanddirtcube_geo", tex = "of_blk_sanddirtcube_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Plants", blocks = {
        { key = "blkleavesdark", name = "Conifer leaves", geo = "of_blk_leavesdark_geo", tex = "of_blk_leavesdark_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkhedge", name = "Hedge", geo = "of_blk_hedge_geo", tex = "of_blk_hedge_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkleaves", name = "Leaves", geo = "of_blk_leaves_geo", tex = "of_blk_leaves_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflowersred", name = "Red flower bed", geo = "of_blk_flowersred_geo", tex = "of_blk_flowersred_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflowersblue", name = "Blue flower bed", geo = "of_blk_flowersblue_geo", tex = "of_blk_flowersblue_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkleavesautumn", name = "Autumn leaves", geo = "of_blk_leavesautumn_geo", tex = "of_blk_leavesautumn_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflowerswhite", name = "White flower bed", geo = "of_blk_flowerswhite_geo", tex = "of_blk_flowerswhite_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgrassflowers", name = "Grass with flowers", geo = "of_blk_grassflowers_geo", tex = "of_blk_grassflowers_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Snow and ice", blocks = {
        { key = "blkicedeep", name = "Deep ice", geo = "of_blk_icedeep_geo", tex = "of_blk_icedeep_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkicecracked", name = "Cracked ice", geo = "of_blk_icecracked_geo", tex = "of_blk_icecracked_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope" },
        { key = "blksnowdirty", name = "Dirty snow", geo = "of_blk_snowdirty_geo", tex = "of_blk_snowdirty_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkicebrick", name = "Ice brick", geo = "of_blk_icebrick_geo", tex = "of_blk_icebrick_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksnowpacked", name = "Packed snow", geo = "of_blk_snowpacked_geo", tex = "of_blk_snowpacked_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkicepacked", name = "Packed ice", geo = "of_blk_icepacked_geo", tex = "of_blk_icepacked_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksnowbrick", name = "Snow brick", geo = "of_blk_snowbrick_geo", tex = "of_blk_snowbrick_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksnowridge", name = "Wind-blown snow", geo = "of_blk_snowridge_geo", tex = "of_blk_snowridge_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksnowfresh", name = "Snow", geo = "of_blk_snowfresh_geo", tex = "of_blk_snowfresh_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blksnowcliffcube", name = "Snow cliff block", geo = "of_blk_snowcliffcube_geo", tex = "of_blk_snowcliffcube_texture", layered = true, runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Desert", blocks = {
        { key = "blksandstonered", name = "Red sandstone", geo = "of_blk_sandstonered_geo", tex = "of_blk_sandstonered_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkadobebrick", name = "Mud brick", geo = "of_blk_adobebrick_geo", tex = "of_blk_adobebrick_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blktileglazedblue", name = "Blue glazed tile", geo = "of_blk_tileglazedblue_geo", tex = "of_blk_tileglazedblue_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blktileglazedgreen", name = "Green glazed tile", geo = "of_blk_tileglazedgreen_geo", tex = "of_blk_tileglazedgreen_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkterracottasmall", name = "Small terracotta tiles", geo = "of_blk_terracottasmall_geo", tex = "of_blk_terracottasmall_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope" },
        { key = "blkadobeworn", name = "Adobe, worn", geo = "of_blk_adobeworn_geo", tex = "of_blk_adobeworn_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksandstonecarved", name = "Carved sandstone", geo = "of_blk_sandstonecarved_geo", tex = "of_blk_sandstonecarved_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blksandstonelayered", name = "Layered sandstone", geo = "of_blk_sandstonelayered_geo", tex = "of_blk_sandstonelayered_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkadobe", name = "Adobe", geo = "of_blk_adobe_geo", tex = "of_blk_adobe_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksandstone", name = "Sandstone", geo = "of_blk_sandstone_geo", tex = "of_blk_sandstone_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blksandstonecut", name = "Cut sandstone", geo = "of_blk_sandstonecut_geo", tex = "of_blk_sandstonecut_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkadobewhite", name = "Whitewash", geo = "of_blk_adobewhite_geo", tex = "of_blk_adobewhite_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
    } },
    { name = "Volcanic", blocks = {
        { key = "blkobsidian", name = "Obsidian", geo = "of_blk_obsidian_geo", tex = "of_blk_obsidian_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkobsidianbrick", name = "Obsidian brick", geo = "of_blk_obsidianbrick_geo", tex = "of_blk_obsidianbrick_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrickscorched", name = "Scorched brick", geo = "of_blk_brickscorched_geo", tex = "of_blk_brickscorched_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbasaltbrick", name = "Basalt brick", geo = "of_blk_basaltbrick_geo", tex = "of_blk_basaltbrick_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbasaltrough", name = "Rough basalt", geo = "of_blk_basaltrough_geo", tex = "of_blk_basaltrough_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkbasaltcolumns", name = "Basalt columns", geo = "of_blk_basaltcolumns_geo", tex = "of_blk_basaltcolumns_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkvolcanicred", name = "Red volcanic rock", geo = "of_blk_volcanicred_geo", tex = "of_blk_volcanicred_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkmagmacrust", name = "Magma crust", geo = "of_blk_magmacrust_geo", tex = "of_blk_magmacrust_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbasalttop", name = "Basalt tops", geo = "of_blk_basalttop_geo", tex = "of_blk_basalttop_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkash", name = "Ash", geo = "of_blk_ash_geo", tex = "of_blk_ash_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Water", blocks = {
        { key = "blkwetalgae", name = "Algae stone", geo = "of_blk_wetalgae_geo", tex = "of_blk_wetalgae_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwetstone", name = "Wet cobble", geo = "of_blk_wetstone_geo", tex = "of_blk_wetstone_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkseawall", name = "Sea wall", geo = "of_blk_seawall_geo", tex = "of_blk_seawall_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbarnaclerock", name = "Barnacle rock", geo = "of_blk_barnaclerock_geo", tex = "of_blk_barnaclerock_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkmosaicteal", name = "Teal mosaic", geo = "of_blk_mosaicteal_geo", tex = "of_blk_mosaicteal_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkquaystone", name = "Quay slabs", geo = "of_blk_quaystone_geo", tex = "of_blk_quaystone_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkpoolblue", name = "Blue pool tiles", geo = "of_blk_poolblue_geo", tex = "of_blk_poolblue_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkpoolwhite", name = "White pool tiles", geo = "of_blk_poolwhite_geo", tex = "of_blk_poolwhite_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
    } },
    { name = "Tiles", blocks = {
        { key = "blktile1", name = "Checker", geo = "of_blk_tile1_geo", tex = "of_blk_tile1_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner" },
        { key = "blktile2", name = "Stone tiles", geo = "of_blk_tile2_geo", tex = "of_blk_tile2_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner" },
        { key = "blkhexpaving", name = "Hex paving", geo = "of_blk_hexpaving_geo", tex = "of_blk_hexpaving_texture", runtime = "arch,inner,innerstairs,outer,outerstairs,plate,prism,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner" },
        { key = "blkwhitemarble", name = "White marble", geo = "of_blk_whitemarble_geo", tex = "of_blk_whitemarble_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
    } },
    { name = "Crystal", blocks = {
        { key = "blkstarpanel", name = "Star panel", geo = "of_blk_starpanel_geo", tex = "of_blk_starpanel_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkrunestone", name = "Rune stone", geo = "of_blk_runestone_geo", tex = "of_blk_runestone_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbrickenchanted", name = "Enchanted brick", geo = "of_blk_brickenchanted_geo", tex = "of_blk_brickenchanted_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkoreamethyst", name = "Amethyst ore", geo = "of_blk_oreamethyst_geo", tex = "of_blk_oreamethyst_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkoreemerald", name = "Emerald ore", geo = "of_blk_oreemerald_geo", tex = "of_blk_oreemerald_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkoregold", name = "Gold ore", geo = "of_blk_oregold_geo", tex = "of_blk_oregold_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkoreruby", name = "Ruby ore", geo = "of_blk_oreruby_geo", tex = "of_blk_oreruby_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkoresapphire", name = "Sapphire ore", geo = "of_blk_oresapphire_geo", tex = "of_blk_oresapphire_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcrystalamethyst", name = "Amethyst crystal", geo = "of_blk_crystalamethyst_geo", tex = "of_blk_crystalamethyst_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcrystalblue", name = "Blue crystal", geo = "of_blk_crystalblue_geo", tex = "of_blk_crystalblue_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcrystalrose", name = "Rose crystal", geo = "of_blk_crystalrose_geo", tex = "of_blk_crystalrose_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Fabric", blocks = {
        { key = "blkcarpetpurple", name = "Purple carpet", geo = "of_blk_carpetpurple_geo", tex = "of_blk_carpetpurple_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcarpetblue", name = "Blue carpet", geo = "of_blk_carpetblue_geo", tex = "of_blk_carpetblue_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcarpetgreen", name = "Green carpet", geo = "of_blk_carpetgreen_geo", tex = "of_blk_carpetgreen_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbannerblue", name = "Blue banner", geo = "of_blk_bannerblue_geo", tex = "of_blk_bannerblue_texture" },
        { key = "blkbannergreen", name = "Green banner", geo = "of_blk_bannergreen_geo", tex = "of_blk_bannergreen_texture" },
        { key = "blkbannerred", name = "Red banner", geo = "of_blk_bannerred_geo", tex = "of_blk_bannerred_texture" },
        { key = "blkrugstriped", name = "Striped rug", geo = "of_blk_rugstriped_geo", tex = "of_blk_rugstriped_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkwool", name = "Felt", geo = "of_blk_wool_geo", tex = "of_blk_wool_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcanvasstripe", name = "Tent stripes", geo = "of_blk_canvasstripe_geo", tex = "of_blk_canvasstripe_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkquilt", name = "Quilted cloth", geo = "of_blk_quilt_geo", tex = "of_blk_quilt_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkcanvasblue", name = "Blue tent stripes", geo = "of_blk_canvasblue_geo", tex = "of_blk_canvasblue_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkbanneryellow", name = "Yellow banner", geo = "of_blk_banneryellow_geo", tex = "of_blk_banneryellow_texture" },
    } },
    { name = "Special", blocks = {
        { key = "blkcarpet", name = "Red carpet", geo = "of_blk_carpet_geo", tex = "of_blk_carpet_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope" },
        { key = "blklava", name = "Lava", geo = "of_blk_lava_geo", tex = "of_blk_lava_texture", runtime = "inner,innerstairs,outer,outerstairs,prism,slab,slope,stairs,uinner,uouter,uslab,uslope" },
        { key = "blkice", name = "Ice", geo = "of_blk_ice_geo", tex = "of_blk_ice_texture", runtime = "inner,innerstairs,outer,outerstairs,prism,slab,slope,stairs,uinner,uouter,uslab,uslope" },
        { key = "blkglassblock", name = "Glass block", geo = "of_blk_glassblock_geo", tex = "of_blk_glassblock_texture", runtime = "inner,innerstairs,outer,outerstairs,prism,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner" },
        { key = "blkhazardstripes", name = "Hazard stripes", geo = "of_blk_hazardstripes_geo", tex = "of_blk_hazardstripes_texture", runtime = "inner,innerstairs,outer,outerstairs,prism,slab,slope,stairs,uinner,uouter,uslab,uslope,wall,wallcorner" },
        { key = "blkwatersurface", name = "Water surface", geo = "of_blk_watersurface_geo", tex = "of_blk_watersurface_texture" },
        { key = "blkteamblue", name = "Blue team panel", geo = "of_blk_teamblue_geo", tex = "of_blk_teamblue_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkteamred", name = "Red team panel", geo = "of_blk_teamred_geo", tex = "of_blk_teamred_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkarrowtile", name = "Arrow tile", geo = "of_blk_arrowtile_geo", tex = "of_blk_arrowtile_texture" },
        { key = "blkglowpink", name = "Pink glow tile", geo = "of_blk_glowpink_geo", tex = "of_blk_glowpink_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkglowblue", name = "Blue glow tile", geo = "of_blk_glowblue_geo", tex = "of_blk_glowblue_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkglowamber", name = "Amber glow tile", geo = "of_blk_glowamber_geo", tex = "of_blk_glowamber_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkglowgreen", name = "Green glow tile", geo = "of_blk_glowgreen_geo", tex = "of_blk_glowgreen_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blktarget", name = "Target", geo = "of_blk_target_geo", tex = "of_blk_target_texture" },
        { key = "blkstripesrw", name = "Red stripes", geo = "of_blk_stripesrw_geo", tex = "of_blk_stripesrw_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcheckerrw", name = "Red checker", geo = "of_blk_checkerrw_geo", tex = "of_blk_checkerrw_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Small brick", blocks = {
        { key = "blkbrdarkcrackedsmall", name = "Small dark brick, cracked", geo = "of_blk_brdarkcrackedsmall_geo", tex = "of_blk_brdarkcrackedsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrreddarksmall", name = "Small dark red brick", geo = "of_blk_brreddarksmall_geo", tex = "of_blk_brreddarksmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrdarksmall", name = "Small dark brick", geo = "of_blk_brdarksmall_geo", tex = "of_blk_brdarksmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrbrownsmall", name = "Small brown brick", geo = "of_blk_brbrownsmall_geo", tex = "of_blk_brbrownsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrclinkersmall", name = "Small clinker brick", geo = "of_blk_brclinkersmall_geo", tex = "of_blk_brclinkersmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrredmossysmall", name = "Small red brick, mossy", geo = "of_blk_brredmossysmall_geo", tex = "of_blk_brredmossysmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrredcrackedsmall", name = "Small red brick, cracked", geo = "of_blk_brredcrackedsmall_geo", tex = "of_blk_brredcrackedsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrredsmall", name = "Small red brick", geo = "of_blk_brredsmall_geo", tex = "of_blk_brredsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrredwornsmall", name = "Small red brick, worn", geo = "of_blk_brredwornsmall_geo", tex = "of_blk_brredwornsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrstacksmall", name = "Small stack bond brick", geo = "of_blk_brstacksmall_geo", tex = "of_blk_brstacksmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrredlightsmall", name = "Small light red brick", geo = "of_blk_brredlightsmall_geo", tex = "of_blk_brredlightsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbryellowwornsmall", name = "Small yellow brick, worn", geo = "of_blk_bryellowwornsmall_geo", tex = "of_blk_bryellowwornsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbryellowsmall", name = "Small yellow brick", geo = "of_blk_bryellowsmall_geo", tex = "of_blk_bryellowsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrwhitesmall", name = "Small white brick", geo = "of_blk_brwhitesmall_geo", tex = "of_blk_brwhitesmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbrickscorchedsmall", name = "Small scorched brick", geo = "of_blk_brickscorchedsmall_geo", tex = "of_blk_brickscorchedsmall_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Wood sets: oak, birch", blocks = {
        { key = "blkbarkoak", name = "Oak bark", geo = "of_blk_barkoak_geo", tex = "of_blk_barkoak_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkbeamoak", name = "Oak beam", geo = "of_blk_beamoak_geo", tex = "of_blk_beamoak_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdoak", name = "Oak planks", geo = "of_blk_wdoak_geo", tex = "of_blk_wdoak_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogoaktop", name = "Oak log end", geo = "of_blk_logoaktop_geo", tex = "of_blk_logoaktop_texture" },
        { key = "blklogbirchtop", name = "Birch log end", geo = "of_blk_logbirchtop_geo", tex = "of_blk_logbirchtop_texture" },
        { key = "blkwdbirch", name = "Birch planks", geo = "of_blk_wdbirch_geo", tex = "of_blk_wdbirch_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbarkbirch", name = "Birch bark", geo = "of_blk_barkbirch_geo", tex = "of_blk_barkbirch_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkwdoakdoortop", name = "Oak door, upper", geo = "of_blk_wdoakdoortop_geo", tex = "of_blk_wdoakdoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdoakdoor", name = "Oak door, lower", geo = "of_blk_wdoakdoor_geo", tex = "of_blk_wdoakdoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripoak", name = "Stripped oak wood", geo = "of_blk_stripoak_geo", tex = "of_blk_stripoak_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripoaktop", name = "Stripped oak log end", geo = "of_blk_logstripoaktop_geo", tex = "of_blk_logstripoaktop_texture" },
        { key = "blkwdbirchdoortop", name = "Birch door, upper", geo = "of_blk_wdbirchdoortop_geo", tex = "of_blk_wdbirchdoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdbirchdoor", name = "Birch door, lower", geo = "of_blk_wdbirchdoor_geo", tex = "of_blk_wdbirchdoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkbeambirch", name = "Birch beam", geo = "of_blk_beambirch_geo", tex = "of_blk_beambirch_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkstripbirch", name = "Stripped birch wood", geo = "of_blk_stripbirch_geo", tex = "of_blk_stripbirch_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripbirchtop", name = "Stripped birch log end", geo = "of_blk_logstripbirchtop_geo", tex = "of_blk_logstripbirchtop_texture" },
        { key = "blkbirchlog", name = "Birch log", geo = "of_blk_birchlog_geo", tex = "of_blk_birchlog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkoaklog", name = "Oak log", geo = "of_blk_oaklog_geo", tex = "of_blk_oaklog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripbirchlog", name = "Stripped birch log", geo = "of_blk_stripbirchlog_geo", tex = "of_blk_stripbirchlog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripoaklog", name = "Stripped oak log", geo = "of_blk_stripoaklog_geo", tex = "of_blk_stripoaklog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Wood sets: pine, dark oak", blocks = {
        { key = "blkbarkdark", name = "Dark bark", geo = "of_blk_barkdark_geo", tex = "of_blk_barkdark_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkbeamdark", name = "Dark beam", geo = "of_blk_beamdark_geo", tex = "of_blk_beamdark_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbarkpine", name = "Pine bark", geo = "of_blk_barkpine_geo", tex = "of_blk_barkpine_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blklogdarktop", name = "Dark log end", geo = "of_blk_logdarktop_geo", tex = "of_blk_logdarktop_texture" },
        { key = "blklogpinetop", name = "Pine log end", geo = "of_blk_logpinetop_geo", tex = "of_blk_logpinetop_texture" },
        { key = "blkbeampale", name = "Pale beam", geo = "of_blk_beampale_geo", tex = "of_blk_beampale_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwddarkdoor", name = "Dark oak door, lower", geo = "of_blk_wddarkdoor_geo", tex = "of_blk_wddarkdoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwddarkdoortop", name = "Dark oak door, upper", geo = "of_blk_wddarkdoortop_geo", tex = "of_blk_wddarkdoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripdark", name = "Stripped dark oak wood", geo = "of_blk_stripdark_geo", tex = "of_blk_stripdark_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripdarktop", name = "Stripped dark oak log end", geo = "of_blk_logstripdarktop_geo", tex = "of_blk_logstripdarktop_texture" },
        { key = "blkwdpinedoor", name = "Pine door, lower", geo = "of_blk_wdpinedoor_geo", tex = "of_blk_wdpinedoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdpinedoortop", name = "Pine door, upper", geo = "of_blk_wdpinedoortop_geo", tex = "of_blk_wdpinedoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstrippine", name = "Stripped pine wood", geo = "of_blk_strippine_geo", tex = "of_blk_strippine_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstrippinetop", name = "Stripped pine log end", geo = "of_blk_logstrippinetop_geo", tex = "of_blk_logstrippinetop_texture" },
        { key = "blkdarklog", name = "Dark log", geo = "of_blk_darklog_geo", tex = "of_blk_darklog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkpinelog", name = "Pine log", geo = "of_blk_pinelog_geo", tex = "of_blk_pinelog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripdarklog", name = "Stripped dark oak log", geo = "of_blk_stripdarklog_geo", tex = "of_blk_stripdarklog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstrippinelog", name = "Stripped pine log", geo = "of_blk_strippinelog_geo", tex = "of_blk_strippinelog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Wood sets: jungle, acacia, mangrove", blocks = {
        { key = "blkbeammangrove", name = "Mangrove beam", geo = "of_blk_beammangrove_geo", tex = "of_blk_beammangrove_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbarkmangrove", name = "Mangrove bark", geo = "of_blk_barkmangrove_geo", tex = "of_blk_barkmangrove_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkwdmangrovedoor", name = "Mangrove door, lower", geo = "of_blk_wdmangrovedoor_geo", tex = "of_blk_wdmangrovedoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdmangrovedoortop", name = "Mangrove door, upper", geo = "of_blk_wdmangrovedoortop_geo", tex = "of_blk_wdmangrovedoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdmangrove", name = "Mangrove planks", geo = "of_blk_wdmangrove_geo", tex = "of_blk_wdmangrove_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbarkjungle", name = "Jungle bark", geo = "of_blk_barkjungle_geo", tex = "of_blk_barkjungle_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blklogmangrovetop", name = "Mangrove log end", geo = "of_blk_logmangrovetop_geo", tex = "of_blk_logmangrovetop_texture" },
        { key = "blkstripmangrove", name = "Stripped mangrove wood", geo = "of_blk_stripmangrove_geo", tex = "of_blk_stripmangrove_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripmangrovetop", name = "Stripped mangrove log end", geo = "of_blk_logstripmangrovetop_geo", tex = "of_blk_logstripmangrovetop_texture" },
        { key = "blkbarkacacia", name = "Acacia bark", geo = "of_blk_barkacacia_geo", tex = "of_blk_barkacacia_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkbeamacacia", name = "Acacia beam", geo = "of_blk_beamacacia_geo", tex = "of_blk_beamacacia_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkbeamjungle", name = "Jungle beam", geo = "of_blk_beamjungle_geo", tex = "of_blk_beamjungle_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdjungledoortop", name = "Jungle door, upper", geo = "of_blk_wdjungledoortop_geo", tex = "of_blk_wdjungledoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdacaciadoor", name = "Acacia door, lower", geo = "of_blk_wdacaciadoor_geo", tex = "of_blk_wdacaciadoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdacaciadoortop", name = "Acacia door, upper", geo = "of_blk_wdacaciadoortop_geo", tex = "of_blk_wdacaciadoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdjungledoor", name = "Jungle door, lower", geo = "of_blk_wdjungledoor_geo", tex = "of_blk_wdjungledoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdacacia", name = "Acacia planks", geo = "of_blk_wdacacia_geo", tex = "of_blk_wdacacia_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdjungle", name = "Jungle planks", geo = "of_blk_wdjungle_geo", tex = "of_blk_wdjungle_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogacaciatop", name = "Acacia log end", geo = "of_blk_logacaciatop_geo", tex = "of_blk_logacaciatop_texture" },
        { key = "blklogjungletop", name = "Jungle log end", geo = "of_blk_logjungletop_geo", tex = "of_blk_logjungletop_texture" },
        { key = "blkstripacacia", name = "Stripped acacia wood", geo = "of_blk_stripacacia_geo", tex = "of_blk_stripacacia_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripacaciatop", name = "Stripped acacia log end", geo = "of_blk_logstripacaciatop_geo", tex = "of_blk_logstripacaciatop_texture" },
        { key = "blkstripjungle", name = "Stripped jungle wood", geo = "of_blk_stripjungle_geo", tex = "of_blk_stripjungle_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripjungletop", name = "Stripped jungle log end", geo = "of_blk_logstripjungletop_geo", tex = "of_blk_logstripjungletop_texture" },
        { key = "blkacacialog", name = "Acacia log", geo = "of_blk_acacialog_geo", tex = "of_blk_acacialog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkjunglelog", name = "Jungle log", geo = "of_blk_junglelog_geo", tex = "of_blk_junglelog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkmangrovelog", name = "Mangrove log", geo = "of_blk_mangrovelog_geo", tex = "of_blk_mangrovelog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripacacialog", name = "Stripped acacia log", geo = "of_blk_stripacacialog_geo", tex = "of_blk_stripacacialog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripjunglelog", name = "Stripped jungle log", geo = "of_blk_stripjunglelog_geo", tex = "of_blk_stripjunglelog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripmangrovelog", name = "Stripped mangrove log", geo = "of_blk_stripmangrovelog_geo", tex = "of_blk_stripmangrovelog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Wood sets: cherry, bamboo", blocks = {
        { key = "blkbarkcherry", name = "Cherry bark", geo = "of_blk_barkcherry_geo", tex = "of_blk_barkcherry_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkbarkbamboo", name = "Bamboo stalks", geo = "of_blk_barkbamboo_geo", tex = "of_blk_barkbamboo_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blklogbambootop", name = "Bamboo bundle end", geo = "of_blk_logbambootop_geo", tex = "of_blk_logbambootop_texture" },
        { key = "blkbeambamboo", name = "Bamboo beam", geo = "of_blk_beambamboo_geo", tex = "of_blk_beambamboo_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdbamboodoortop", name = "Bamboo door, upper", geo = "of_blk_wdbamboodoortop_geo", tex = "of_blk_wdbamboodoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdbamboodoor", name = "Bamboo door, lower", geo = "of_blk_wdbamboodoor_geo", tex = "of_blk_wdbamboodoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkbeamcherry", name = "Cherry beam", geo = "of_blk_beamcherry_geo", tex = "of_blk_beamcherry_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdbamboo", name = "Bamboo planks", geo = "of_blk_wdbamboo_geo", tex = "of_blk_wdbamboo_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdcherrydoortop", name = "Cherry door, upper", geo = "of_blk_wdcherrydoortop_geo", tex = "of_blk_wdcherrydoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blklogstripbambootop", name = "Stripped bamboo bundle end", geo = "of_blk_logstripbambootop_geo", tex = "of_blk_logstripbambootop_texture" },
        { key = "blkwdcherrydoor", name = "Cherry door, lower", geo = "of_blk_wdcherrydoor_geo", tex = "of_blk_wdcherrydoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blklogcherrytop", name = "Cherry log end", geo = "of_blk_logcherrytop_geo", tex = "of_blk_logcherrytop_texture" },
        { key = "blkstripbamboo", name = "Stripped bamboo stalks", geo = "of_blk_stripbamboo_geo", tex = "of_blk_stripbamboo_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdcherry", name = "Cherry planks", geo = "of_blk_wdcherry_geo", tex = "of_blk_wdcherry_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkstripcherry", name = "Stripped cherry wood", geo = "of_blk_stripcherry_geo", tex = "of_blk_stripcherry_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripcherrytop", name = "Stripped cherry log end", geo = "of_blk_logstripcherrytop_geo", tex = "of_blk_logstripcherrytop_texture" },
        { key = "blkbamboolog", name = "Bamboo bundle", geo = "of_blk_bamboolog_geo", tex = "of_blk_bamboolog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkcherrylog", name = "Cherry log", geo = "of_blk_cherrylog_geo", tex = "of_blk_cherrylog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripbamboolog", name = "Stripped bamboo bundle", geo = "of_blk_stripbamboolog_geo", tex = "of_blk_stripbamboolog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripcherrylog", name = "Stripped cherry log", geo = "of_blk_stripcherrylog_geo", tex = "of_blk_stripcherrylog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Wood sets: mystic, ghost", blocks = {
        { key = "blkbarkmystic", name = "Mystic bark", geo = "of_blk_barkmystic_geo", tex = "of_blk_barkmystic_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkbeammystic", name = "Mystic beam", geo = "of_blk_beammystic_geo", tex = "of_blk_beammystic_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdmysticdoor", name = "Mystic door, lower", geo = "of_blk_wdmysticdoor_geo", tex = "of_blk_wdmysticdoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdmysticdoortop", name = "Mystic door, upper", geo = "of_blk_wdmysticdoortop_geo", tex = "of_blk_wdmysticdoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdmystic", name = "Mystic planks", geo = "of_blk_wdmystic_geo", tex = "of_blk_wdmystic_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogmystictop", name = "Mystic log end", geo = "of_blk_logmystictop_geo", tex = "of_blk_logmystictop_texture" },
        { key = "blkstripmystic", name = "Stripped mystic wood", geo = "of_blk_stripmystic_geo", tex = "of_blk_stripmystic_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripmystictop", name = "Stripped mystic log end", geo = "of_blk_logstripmystictop_geo", tex = "of_blk_logstripmystictop_texture" },
        { key = "blkbarkghost", name = "Ghost bark", geo = "of_blk_barkghost_geo", tex = "of_blk_barkghost_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter,window" },
        { key = "blkbeamghost", name = "Ghost beam", geo = "of_blk_beamghost_geo", tex = "of_blk_beamghost_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwdghostdoortop", name = "Ghost door, upper", geo = "of_blk_wdghostdoortop_geo", tex = "of_blk_wdghostdoortop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdghostdoor", name = "Ghost door, lower", geo = "of_blk_wdghostdoor_geo", tex = "of_blk_wdghostdoor_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwdghost", name = "Ghost planks", geo = "of_blk_wdghost_geo", tex = "of_blk_wdghost_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogghosttop", name = "Ghost log end", geo = "of_blk_logghosttop_geo", tex = "of_blk_logghosttop_texture" },
        { key = "blkstripghost", name = "Stripped ghost wood", geo = "of_blk_stripghost_geo", tex = "of_blk_stripghost_texture", runtime = "arch,doorway,fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blklogstripghosttop", name = "Stripped ghost log end", geo = "of_blk_logstripghosttop_geo", tex = "of_blk_logstripghosttop_texture" },
        { key = "blkghostlog", name = "Ghost log", geo = "of_blk_ghostlog_geo", tex = "of_blk_ghostlog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkmysticlog", name = "Mystic log", geo = "of_blk_mysticlog_geo", tex = "of_blk_mysticlog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripghostlog", name = "Stripped ghost log", geo = "of_blk_stripghostlog_geo", tex = "of_blk_stripghostlog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
        { key = "blkstripmysticlog", name = "Stripped mystic log", geo = "of_blk_stripmysticlog_geo", tex = "of_blk_stripmysticlog_texture", layered = true, runtime = "panel,pillar,plate,pole,prism,roundcorner,slab,wall,wallcorner,wallcross,wallt" },
    } },
    { name = "Windows and doors", blocks = {
        { key = "blkdoorstudded", name = "Studded door, lower", geo = "of_blk_doorstudded_geo", tex = "of_blk_doorstudded_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkdoordouble", name = "Double door, lower", geo = "of_blk_doordouble_geo", tex = "of_blk_doordouble_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkdoordoubletop", name = "Double door, upper", geo = "of_blk_doordoubletop_geo", tex = "of_blk_doordoubletop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkrailiron", name = "Iron balcony rail", geo = "of_blk_railiron_geo", tex = "of_blk_railiron_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwinarched", name = "Arched window", geo = "of_blk_winarched_geo", tex = "of_blk_winarched_texture", runtime = "arch,doorway,panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkdoorstuddedtop", name = "Studded door, upper", geo = "of_blk_doorstuddedtop_geo", tex = "of_blk_doorstuddedtop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkrailwood", name = "Wooden balcony rail", geo = "of_blk_railwood_geo", tex = "of_blk_railwood_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkdoorarched", name = "Arched door, lower", geo = "of_blk_doorarched_geo", tex = "of_blk_doorarched_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkshopgreen", name = "Shop front, green awning", geo = "of_blk_shopgreen_geo", tex = "of_blk_shopgreen_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkshopred", name = "Shop front, red awning", geo = "of_blk_shopred_geo", tex = "of_blk_shopred_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwinshop", name = "Shop window", geo = "of_blk_winshop_geo", tex = "of_blk_winshop_texture", runtime = "arch,doorway,panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkdoorarchedtop", name = "Arched door, upper", geo = "of_blk_doorarchedtop_geo", tex = "of_blk_doorarchedtop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkdoorplank", name = "Plank door, lower", geo = "of_blk_doorplank_geo", tex = "of_blk_doorplank_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkshutred", name = "Red shutters", geo = "of_blk_shutred_geo", tex = "of_blk_shutred_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwinstone", name = "Stone window", geo = "of_blk_winstone_geo", tex = "of_blk_winstone_texture", runtime = "arch,doorway,panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkdoorplanktop", name = "Plank door, upper", geo = "of_blk_doorplanktop_geo", tex = "of_blk_doorplanktop_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkshutgreen", name = "Green shutters", geo = "of_blk_shutgreen_geo", tex = "of_blk_shutgreen_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkwinround", name = "Round window", geo = "of_blk_winround_geo", tex = "of_blk_winround_texture", runtime = "arch,doorway,panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwincottage", name = "Cottage window", geo = "of_blk_wincottage_geo", tex = "of_blk_wincottage_texture", runtime = "arch,doorway,panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkwinshutter", name = "Window with shutters", geo = "of_blk_winshutter_geo", tex = "of_blk_winshutter_texture", runtime = "arch,doorway,panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt,window" },
    } },
    { name = "Facades", blocks = {
        { key = "blktimberherring", name = "Half-timber, herringbone", geo = "of_blk_timberherring_geo", tex = "of_blk_timberherring_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blktimberbrace", name = "Half-timber, braces", geo = "of_blk_timberbrace_geo", tex = "of_blk_timberbrace_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blktimbercross", name = "Half-timber, cross", geo = "of_blk_timbercross_geo", tex = "of_blk_timbercross_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blktimbergrid", name = "Half-timber, posts", geo = "of_blk_timbergrid_geo", tex = "of_blk_timbergrid_texture", runtime = "panel,plate,prism,slab,uplate,uslab,wall,wallcorner,wallcross,wallt" },
        { key = "blkplasterochre", name = "Ochre plaster", geo = "of_blk_plasterochre_geo", tex = "of_blk_plasterochre_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkplastersage", name = "Sage plaster", geo = "of_blk_plastersage_geo", tex = "of_blk_plastersage_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkplasterpink", name = "Pink plaster", geo = "of_blk_plasterpink_geo", tex = "of_blk_plasterpink_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkplastercream", name = "Cream plaster", geo = "of_blk_plastercream_geo", tex = "of_blk_plastercream_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
        { key = "blkplasterwhite", name = "White plaster", geo = "of_blk_plasterwhite_geo", tex = "of_blk_plasterwhite_texture", runtime = "arch,doorway,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,window" },
    } },
    { name = "Roofs of the world", blocks = {
        { key = "blkrfshingleblack", name = "Black shingles", geo = "of_blk_rfshingleblack_geo", tex = "of_blk_rfshingleblack_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfslatepurple", name = "Purple slate roof", geo = "of_blk_rfslatepurple_geo", tex = "of_blk_rfslatepurple_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfglazedblue", name = "Blue glazed tiles", geo = "of_blk_rfglazedblue_geo", tex = "of_blk_rfglazedblue_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfshinglepurple", name = "Plum shingles", geo = "of_blk_rfshinglepurple_geo", tex = "of_blk_rfshinglepurple_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfshinglered", name = "Red shingles", geo = "of_blk_rfshinglered_geo", tex = "of_blk_rfshinglered_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfglazedgreen", name = "Green glazed tiles", geo = "of_blk_rfglazedgreen_geo", tex = "of_blk_rfglazedgreen_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfslatefish", name = "Fish-scale slate", geo = "of_blk_rfslatefish_geo", tex = "of_blk_rfslatefish_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfpalm", name = "Palm-leaf thatch", geo = "of_blk_rfpalm_geo", tex = "of_blk_rfpalm_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfpantile", name = "Pantiles", geo = "of_blk_rfpantile_geo", tex = "of_blk_rfpantile_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfverdigris", name = "Copper roof, turning", geo = "of_blk_rfverdigris_geo", tex = "of_blk_rfverdigris_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfcopperbright", name = "New copper roof", geo = "of_blk_rfcopperbright_geo", tex = "of_blk_rfcopperbright_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfshinglehoney", name = "Honey shingles", geo = "of_blk_rfshinglehoney_geo", tex = "of_blk_rfshinglehoney_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfpalmdry", name = "Dry palm thatch", geo = "of_blk_rfpalmdry_geo", tex = "of_blk_rfpalmdry_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkrfthatchreed", name = "Reed thatch", geo = "of_blk_rfthatchreed_geo", tex = "of_blk_rfthatchreed_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Paths and edging", blocks = {
        { key = "blkcurbgrass", name = "Kerb between grass", geo = "of_blk_curbgrass_geo", tex = "of_blk_curbgrass_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkcurbgranite", name = "Granite kerb", geo = "of_blk_curbgranite_geo", tex = "of_blk_curbgranite_texture", runtime = "fence,fencecorner,inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgravelred", name = "Red gravel", geo = "of_blk_gravelred_geo", tex = "of_blk_gravelred_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgravelgrass", name = "Gravel path with verges", geo = "of_blk_gravelgrass_geo", tex = "of_blk_gravelgrass_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkpathgrass", name = "Path with verges", geo = "of_blk_pathgrass_geo", tex = "of_blk_pathgrass_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkpathstepping", name = "Stepping stones", geo = "of_blk_pathstepping_geo", tex = "of_blk_pathstepping_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkgravelwhite", name = "White gravel", geo = "of_blk_gravelwhite_geo", tex = "of_blk_gravelwhite_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Garden plants", blocks = {
        { key = "blkferndark", name = "Ferns in shade", geo = "of_blk_ferndark_geo", tex = "of_blk_ferndark_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkmushroomsred", name = "Red mushrooms", geo = "of_blk_mushroomsred_geo", tex = "of_blk_mushroomsred_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkmushroomsbrown", name = "Brown mushrooms", geo = "of_blk_mushroomsbrown_geo", tex = "of_blk_mushroomsbrown_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkfern", name = "Ferns", geo = "of_blk_fern_geo", tex = "of_blk_fern_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflowerspurple", name = "Purple flower bed", geo = "of_blk_flowerspurple_geo", tex = "of_blk_flowerspurple_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflowersorange", name = "Orange flower bed", geo = "of_blk_flowersorange_geo", tex = "of_blk_flowersorange_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflowerspink", name = "Pink flower bed", geo = "of_blk_flowerspink_geo", tex = "of_blk_flowerspink_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkflowersyellow", name = "Yellow flower bed", geo = "of_blk_flowersyellow_geo", tex = "of_blk_flowersyellow_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,pyramid,ridge,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
        { key = "blkmossbright", name = "Moss cushions", geo = "of_blk_mossbright_geo", tex = "of_blk_mossbright_texture", runtime = "inner,innerstairs,outer,outerstairs,plate,prism,pyramid,ridge,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wedge,wedgeinner,wedgeouter,wedgetip,wedgetipinner,wedgetipouter" },
    } },
    { name = "Market and props", blocks = {
        { key = "blkclothpurple", name = "Purple market cloth", geo = "of_blk_clothpurple_geo", tex = "of_blk_clothpurple_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkclothblue", name = "Blue market cloth", geo = "of_blk_clothblue_geo", tex = "of_blk_clothblue_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkclothred", name = "Red market cloth", geo = "of_blk_clothred_geo", tex = "of_blk_clothred_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcratedark", name = "Dark crate", geo = "of_blk_cratedark_geo", tex = "of_blk_cratedark_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blksignpainted", name = "Painted sign board", geo = "of_blk_signpainted_geo", tex = "of_blk_signpainted_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkclothgreen", name = "Green market cloth", geo = "of_blk_clothgreen_geo", tex = "of_blk_clothgreen_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbarreltop", name = "Barrel head", geo = "of_blk_barreltop_geo", tex = "of_blk_barreltop_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkbarrelside", name = "Barrel side", geo = "of_blk_barrelside_geo", tex = "of_blk_barrelside_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkcrateslat", name = "Slatted crate", geo = "of_blk_crateslat_geo", tex = "of_blk_crateslat_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blksignboard", name = "Sign board", geo = "of_blk_signboard_geo", tex = "of_blk_signboard_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blklanterncool", name = "Lantern glass, cool", geo = "of_blk_lanterncool_geo", tex = "of_blk_lanterncool_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blkclothyellow", name = "Yellow market cloth", geo = "of_blk_clothyellow_geo", tex = "of_blk_clothyellow_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
        { key = "blklanternwarm", name = "Lantern glass, warm", geo = "of_blk_lanternwarm_geo", tex = "of_blk_lanternwarm_texture", runtime = "inner,innerstairs,outer,outerstairs,panel,pillar,plate,pole,prism,roundcorner,slab,slope,stairs,uinner,uouter,uplate,uslab,uslope,wall,wallcorner,wallcross,wallt" },
    } },
}
local BLOCK_WAS = {
}

spawner.PREFABS = {
    { key = "castlewall", name = "Castle wall", size = { 5, 3, 1 }, pieces = {
        { 0, 0, 0, "cube", "brickdarkgrey", 0, false, { 5, 2, 1 } },
        { 0, 2, 0, "cube", "brickdarkgrey", 0, false },
        { 2, 2, 0, "cube", "brickdarkgrey", 0, false },
        { 4, 2, 0, "cube", "brickdarkgrey", 0, false },
    } },
    { key = "cottage", name = "Cottage", size = { 3, 4, 3 }, pieces = {
        { 0, 0, 0, "cube", "redbrick", 0, false, { 1, 1, 3 } },
        { 2, 0, 0, "cube", "redbrick", 0, false, { 1, 1, 3 } },
        { 1, 0, 2, "cube", "redbrick", 0, false, { 1, 2, 1 } },
        { 0, 1, 0, "cube", "redbrick", 0, false, { 3, 1, 1 } },
        { 0, 1, 2, "cube", "redbrick", 0, false },
        { 2, 1, 2, "cube", "redbrick", 0, false },
        { 0, 2, 1, "cube", "redbrick", 0, false, { 3, 1, 1 } },
        { 1, 0, 1, "plate", "woodenplank1", 0, false },
        { 0, 2, 0, "slope", "darkplanks", 2, false },
        { 0, 2, 2, "slope", "darkplanks", 0, false },
        { 0, 3, 1, "ridge", "darkplanks", 0, false },
        { 1, 2, 0, "slope", "darkplanks", 2, false },
        { 1, 2, 2, "slope", "darkplanks", 0, false },
        { 1, 3, 1, "ridge", "darkplanks", 0, false },
        { 2, 2, 0, "slope", "darkplanks", 2, false },
        { 2, 2, 2, "slope", "darkplanks", 0, false },
        { 2, 3, 1, "ridge", "darkplanks", 0, false },
    } },
    { key = "footbridge", name = "Footbridge", size = { 7, 2, 3 }, pieces = {
        { 1, 0, 0, "cube", "woodenplank1", 0, false, { 5, 1, 3 } },
        { 0, 0, 1, "slope", "woodenplank1", 3, false },
        { 6, 0, 1, "slope", "woodenplank1", 1, false },
        { 1, 1, 0, "fence", "woodenplank2", 0, false },
        { 1, 1, 2, "fence", "woodenplank2", 0, false },
        { 2, 1, 0, "fence", "woodenplank2", 0, false },
        { 2, 1, 2, "fence", "woodenplank2", 0, false },
        { 3, 1, 0, "fence", "woodenplank2", 0, false },
        { 3, 1, 2, "fence", "woodenplank2", 0, false },
        { 4, 1, 0, "fence", "woodenplank2", 0, false },
        { 4, 1, 2, "fence", "woodenplank2", 0, false },
        { 5, 1, 0, "fence", "woodenplank2", 0, false },
        { 5, 1, 2, "fence", "woodenplank2", 0, false },
    } },
    { key = "gate", name = "Gate", size = { 5, 3, 1 }, pieces = {
        { 0, 0, 0, "cube", "whitestonebrick", 0, false, { 2, 2, 1 } },
        { 3, 0, 0, "cube", "whitestonebrick", 0, false, { 2, 2, 1 } },
        { 0, 2, 0, "cube", "whitestonebrick", 0, false },
        { 2, 2, 0, "cube", "whitestonebrick", 0, false },
        { 4, 2, 0, "cube", "whitestonebrick", 0, false },
        { 2, 1, 0, "arch", "whitestonebrick", 0, false },
    } },
    { key = "marketstall", name = "Market stall", size = { 3, 2, 2 }, pieces = {
        { 0, 1, 0, "plate", "greenplanks", 0, false, { 3, 1, 2 } },
        { 1, 0, 0, "cube", "crate", 0, false },
        { 0, 0, 0, "pole", "woodenplank1", 0, false },
        { 0, 0, 1, "pole", "woodenplank1", 0, false },
        { 2, 0, 0, "pole", "woodenplank1", 0, false },
        { 2, 0, 1, "pole", "woodenplank1", 0, false },
    } },
    { key = "watchtower", name = "Watchtower", size = { 3, 4, 3 }, pieces = {
        { 0, 2, 0, "cube", "stone1", 0, false, { 3, 1, 3 } },
        { 0, 0, 0, "cube", "greystone", 0, false, { 1, 1, 3 } },
        { 2, 0, 0, "cube", "greystone", 0, false, { 1, 1, 3 } },
        { 1, 0, 2, "cube", "greystone", 0, false },
        { 0, 1, 0, "cube", "greystone", 0, false },
        { 2, 1, 0, "cube", "greystone", 0, false },
        { 0, 1, 2, "cube", "greystone", 0, false },
        { 2, 1, 2, "cube", "greystone", 0, false },
        { 0, 3, 0, "cube", "greystone", 0, false },
        { 2, 3, 0, "cube", "greystone", 0, false },
        { 0, 3, 2, "cube", "greystone", 0, false },
        { 2, 3, 2, "cube", "greystone", 0, false },
    } },
}

local BUILD_MESH = {
    [0] = "breakable_box_seg8_collision_08012D70",
}

local BUILD_SPAN = {
    [0] = 200,
}

local SLOPE_SHAPES = {
    { tag = "slope", byte = 1, up = "", shelf = "Slopes", noun = "slope" },
    { tag = "outer", byte = 2, up = "", shelf = "Outer corners", noun = "outer corner" },
    { tag = "inner", byte = 3, up = "", shelf = "Inner corners", noun = "inner corner" },
    { tag = "uslope", byte = 4, up = "slope" },
    { tag = "uouter", byte = 5, up = "outer" },
    { tag = "uinner", byte = 6, up = "inner" },

    { tag = "stairs", byte = 7, up = "", shelf = "Stairs", noun = "stairs" },

    { tag = "slab", byte = 8, up = "", shelf = "Slabs", noun = "slab", flat = true },
    { tag = "uslab", byte = 9, up = "slab", flat = true },
    { tag = "wall", byte = 10, up = "", shelf = "Walls", noun = "wall", flat = true },
    { tag = "wallcorner", byte = 11, up = "", shelf = "Wall corners", noun = "wall corner", flat = true },
    { tag = "fence", byte = 12, up = "", shelf = "Fences", noun = "fence", flat = true },
    { tag = "fencecorner", byte = 13, up = "", shelf = "Fence corners", noun = "fence corner", flat = true },
    { tag = "pillar", byte = 14, up = "", shelf = "Pillars", noun = "pillar", flat = true },
    { tag = "arch", byte = 15, up = "", shelf = "Arches", noun = "arch", flat = true },
    { tag = "prism", byte = 16, up = "", shelf = "Diagonal halves", noun = "diagonal half", flat = true },

    { tag = "outerstairs", byte = 17, up = "", shelf = "Outer corner stairs", noun = "outer corner stairs" },
    { tag = "innerstairs", byte = 18, up = "", shelf = "Inner corner stairs", noun = "inner corner stairs" },

    { tag = "plate", byte = 19, up = "", shelf = "Plates", noun = "plate", flat = true },
    { tag = "uplate", byte = 20, up = "plate", flat = true },
    { tag = "wedge", byte = 21, up = "", shelf = "Wedges", noun = "wedge" },
    { tag = "wedgetip", byte = 22, up = "", shelf = "Wedge tips", noun = "wedge tip" },
    { tag = "wedgeouter", byte = 23, up = "", shelf = "Wedge outer corners", noun = "wedge outer corner" },
    { tag = "wedgeinner", byte = 24, up = "", shelf = "Wedge inner corners", noun = "wedge inner corner" },
    { tag = "wedgetipouter", byte = 25, up = "", shelf = "Wedge tip outer corners", noun = "wedge tip outer corner" },
    { tag = "wedgetipinner", byte = 26, up = "", shelf = "Wedge tip inner corners", noun = "wedge tip inner corner" },
    { tag = "ridge", byte = 27, up = "", shelf = "Ridges", noun = "ridge", roof = true },
    { tag = "pyramid", byte = 28, up = "", shelf = "Pyramids", noun = "pyramid", roof = true },
    { tag = "wallt", byte = 29, up = "", shelf = "Wall T joints", noun = "wall T joint", flat = true },
    { tag = "wallcross", byte = 30, up = "", shelf = "Wall crossings", noun = "wall crossing", flat = true },
    { tag = "panel", byte = 31, up = "", shelf = "Panels", noun = "panel", flat = true },
    { tag = "pole", byte = 32, up = "", shelf = "Poles", noun = "pole", flat = true },
    { tag = "roundcorner", byte = 33, up = "", shelf = "Round corners", noun = "round corner", flat = true },
    { tag = "doorway", byte = 34, up = "", shelf = "Doorways", noun = "doorway", flat = true },
    { tag = "window", byte = 35, up = "", shelf = "Windows", noun = "window", flat = true },

    { tag = "slab2", byte = 36, up = "", shelf = "Slabs, 2 long", noun = "slab, 2 long", flat = true, span = 2 },
    { tag = "slab4", byte = 37, up = "", shelf = "Slabs, 4 long", noun = "slab, 4 long", flat = true, span = 4 },
    { tag = "plate2", byte = 38, up = "", shelf = "Plates, 2 long", noun = "plate, 2 long", flat = true, span = 2 },
    { tag = "plate4", byte = 39, up = "", shelf = "Plates, 4 long", noun = "plate, 4 long", flat = true, span = 4 },
    { tag = "wall2", byte = 40, up = "", shelf = "Walls, 2 long", noun = "wall, 2 long", flat = true, span = 2 },
    { tag = "wall4", byte = 41, up = "", shelf = "Walls, 4 long", noun = "wall, 4 long", flat = true, span = 4 },
    { tag = "panel2", byte = 42, up = "", shelf = "Panels, 2 long", noun = "panel, 2 long", flat = true, span = 2 },
    { tag = "panel4", byte = 43, up = "", shelf = "Panels, 4 long", noun = "panel, 4 long", flat = true, span = 4 },
}
spawner.SLOPE_SHAPES = SLOPE_SHAPES

spawner.BUILD_SPANS = {}

function spawner.span_of(object)
    if object == nil then return 1 end
    local model = OF.util.optional("obj_get_model_id_extended", nil, object)
    return model ~= nil and spawner.BUILD_SPANS[model] or 1
end

local SLOPE_COL = {}
for _, shape in ipairs(SLOPE_SHAPES) do
    SLOPE_COL[shape.byte] = "of_slp_" .. shape.tag .. "_col"
    BUILD_SPAN[shape.byte] = 200
end

local buildFit = {}
local buildMeasured = {}

for shape, span in pairs(BUILD_SPAN) do
    buildFit[shape] = BUILD_CELL / span

    buildMeasured[shape] = SLOPE_COL[shape] ~= nil
end

local function build_shape(o)
    local shape = math.floor(tonumber(o.oBehParams2ndByte) or 0)
    if BUILD_MESH[shape] == nil and SLOPE_COL[shape] == nil then return 0 end
    return shape
end

local function build_mesh(shape)
    if SLOPE_COL[shape] ~= nil then
        return at_load("smlua_collision_util_get", SLOPE_COL[shape])
    end
    local data = _G["gGlobalObjectCollisionData"]
    return data ~= nil and data[BUILD_MESH[shape] or BUILD_MESH[0]] or nil
end

local FIT_TRUST = 0.1
local FIT_SNAP = 2

local function fit_to_cell(o, shape)
    local bounds = OF.util.asks(OF.forge, "bounds")
        and OF.forge.bounds(o) or nil
    if bounds == nil or bounds.solid ~= true then return false end
    local span = math.max(bounds.halfX, bounds.halfY, bounds.halfZ) * 2
    if span <= 0 then return false end
    if math.abs(span - BUILD_CELL) <= FIT_SNAP then
        buildMeasured[shape] = true
        return true
    end
    if math.abs(span - BUILD_CELL) > BUILD_CELL * FIT_TRUST then return false end

    local was = buildFit[shape] or 1
    buildFit[shape] = was * BUILD_CELL / span
    buildMeasured[shape] = true
    return true
end

local QUARTER = 0x4000
local QUARTERS = { [0] = 0, 0x4000, -0x8000, -0x4000 }

function spawner.quarter_of(yaw)
    local turn = (tonumber(yaw) or 0) % 0x10000
    return math.floor(turn / QUARTER + 0.5) % 4
end

function spawner.quarter_yaw(yaw)
    return QUARTERS[spawner.quarter_of(yaw)]
end

function spawner.square_up(o, yaw)
    if o == nil then return false end
    local square = spawner.quarter_yaw(yaw == nil and o.oFaceAngleYaw or yaw)
    o.oFaceAnglePitch = 0
    o.oFaceAngleYaw = square
    o.oFaceAngleRoll = 0
    o.oMoveAnglePitch = 0
    o.oMoveAngleYaw = square
    o.oMoveAngleRoll = 0
    return true
end

spawner.LAVA_MATERIAL = "lava"
spawner.LAVA_MODELS = {}

function spawner.is_lava_block(o)
    if o == nil or spawner.BLOCK == nil or type(obj_has_behavior_id) ~= "function" then
        return false
    end
    if not OF.util.alive(o) or obj_has_behavior_id(o, spawner.BLOCK) == 0 then return false end
    local word = math.floor(tonumber(o.oBehParams) or 0) & 0x3FF
    if word > 0 then return word == spawner.block_index(spawner.LAVA_MATERIAL) end
    local model = OF.util.optional("obj_get_model_id_extended", nil, o)
    return model ~= nil and spawner.LAVA_MODELS[model] == true
end

function spawner.lava_floor(m)
    if m == nil or m.playerIndex ~= 0 or SURFACE_BURNING == nil then return false end
    local floor = m.floor
    if floor == nil or floor.type == SURFACE_BURNING then return false end
    local o = floor.object
    if o == nil or not spawner.is_lava_block(o) then return false end
    floor.type = SURFACE_BURNING
    return true
end
hook_event(HOOK_BEFORE_MARIO_UPDATE, spawner.lava_floor, OF.LOCAL_MARIO)

spawner.WATER_MATERIAL = "watersurface"
spawner.WATER_MODELS = {}
spawner.WATER_CELL = 200
local waterOf = {}

function spawner.is_water_block(o)
    if o == nil or type(obj_has_model_extended) ~= "function" then return false end
    for model in pairs(spawner.WATER_MODELS) do
        if obj_has_model_extended(o, model) ~= 0 then return true end
    end
    return false
end

function spawner.water_here()
    return OF.util.asks(OF.venues, "water_possible") and OF.venues.water_possible() == true
end

local function water_block(o)
    local held = waterOf[o]
    if held ~= nil and held.x == o.oPosX and held.y == o.oPosY and held.z == o.oPosZ then
        return
    end
    if not OF.util.asks(OF.venues, "water_add") then return end
    local h = spawner.WATER_CELL / 2
    OF.venues.water_add(o, o.oPosX - h, o.oPosZ - h, o.oPosX + h, o.oPosZ + h,
        o.oPosY + spawner.WATER_CELL, o.oPosY)
    waterOf[o] = { x = o.oPosX, y = o.oPosY, z = o.oPosZ }
end

local function water_gone(o)
    if waterOf[o] == nil then return end
    waterOf[o] = nil
    if OF.util.asks(OF.venues, "water_remove") then OF.venues.water_remove(o) end
end
spawner.water_gone = water_gone

local function runtime_word(o, known)
    local ST = OF.stretch
    if o == nil or ST == nil or type(ST.sized) ~= "function" then return nil end
    if not known and (spawner.BLOCK == nil or type(obj_has_behavior_id) ~= "function"
        or obj_has_behavior_id(o, spawner.BLOCK) == 0) then
        return nil
    end
    local params = math.floor(tonumber(o.oBehParams) or 0)
    local byte = (params & 0xFFFFFFFF) >> 16 & 0xFF
    if ST.sized(params) or ST.JOIN_BYTES[byte] ~= nil then return params end
    return nil
end
spawner.runtime_word = runtime_word

local joins = {}
do
local JOIN_PILLAR_BYTE, JOIN_FENCE_BYTES = 14, { [12] = true, [13] = true }

local WALL_ARMS = {
    [10] = { 1, 3 }, [11] = { 3, 4 }, [29] = { 1, 3, 4 }, [30] = { 1, 2, 3, 4 },
    [34] = { 1, 3 }, [35] = { 1, 3 }, [40] = { 1, 3 }, [41] = { 1, 3 },
}
spawner.WALL_ARMS = WALL_ARMS
local SIDE_DX, SIDE_DZ = { 1, 0, -1, 0 }, { 0, 1, 0, -1 }
local blockAt, keyOf, sizedBlocks, joinDirty, joinedFrom, joinBlocks = {}, {}, {}, {}, {}, {}

local function cell_key(x, y, z)
    local c = BUILD_CELL
    return math.floor(x / c + 0.5) .. ":" .. math.floor(y / c + 0.5) .. ":" .. math.floor(z / c + 0.5)
end

local function world_side(k, q) return ((k - 1 - q) % 4) + 1 end
local function own_side(k, q) return ((k - 1 + q) % 4) + 1 end
local function across(k) return ((k + 1) % 4) + 1 end
spawner.world_side, spawner.own_side = world_side, own_side

local function join_kind(o)
    local byte = math.floor(tonumber(o.oBehParams2ndByte) or 0)
    if byte == JOIN_PILLAR_BYTE then return "pillar" end
    if JOIN_FENCE_BYTES[byte] then return "fence" end
    return nil
end

local function wall_reaches(o, k)
    local arms = WALL_ARMS[math.floor(tonumber(o.oBehParams2ndByte) or 0)]
    if arms == nil then return false end
    local q = spawner.quarter_of(o.oFaceAngleYaw or 0)
    for _, a in ipairs(arms) do
        if world_side(a, q) == k then return true end
    end
    return false
end
spawner.wall_reaches = wall_reaches

local function block_in(x, y, z)
    local o = blockAt[cell_key(x, y, z)]
    if o ~= nil and o.activeFlags ~= 0 then return o end
    for s, box in pairs(sizedBlocks) do
        if s.activeFlags ~= 0 and x > box[1] and x < box[2] and y >= box[3] - 1 and y < box[4] - 1
            and z > box[5] and z < box[6] then
            return s
        end
    end
    return nil
end
spawner.block_in = block_in

local function texture_number(o)
    local word = math.floor(tonumber(o.oBehParams) or 0) & 0x3FF
    if word > 0 then return word end
    local model = OF.util.optional("obj_get_model_id_extended", nil, o)
    for _, e in ipairs(spawner.BUILD_LIST) do
        if e.model == model and e.material ~= nil then return spawner.block_index(e.material) end
    end
    for _, e in pairs(spawner.BUILD_TWINS) do
        if e.model == model and type(e.upright) == "string" then
            local up = spawner.build_find(e.upright)
            if up ~= nil and up.material ~= nil then return spawner.block_index(up.material) end
        end
    end
    return nil
end

function spawner.join_word(o)
    local kind = join_kind(o)
    local ST = OF.stretch
    if kind == nil or ST == nil or ST.join_codes == nil then return nil end
    local laidAs = joinedFrom[o] ~= nil and joinedFrom[o].params or o.oBehParams
    if ST.sized(laidAs) then return nil end
    local texture = texture_number(o)
    if texture == nil then return nil end
    local sides = {}
    for k = 1, 4 do
        local n = block_in(o.oPosX + SIDE_DX[k] * BUILD_CELL, o.oPosY, o.oPosZ + SIDE_DZ[k] * BUILD_CELL)
        if n ~= nil and n ~= o then
            local word = runtime_word(n, true)
            sides[k] = { byte = math.floor(tonumber(n.oBehParams2ndByte) or 0),
                         q = spawner.quarter_of(n.oFaceAngleYaw or 0),
                         texture = texture_number(n) or 0,
                         thick = word ~= nil and ST.wall_thick(word) or 1 }
        end
    end
    return ST.join_codes(kind, spawner.quarter_of(o.oFaceAngleYaw or 0), texture, sides)
end

local function rejoin(o)
    joinDirty[o] = nil
    local want = spawner.join_word(o)
    local now = joinedFrom[o] ~= nil and math.floor(tonumber(o.oBehParams) or 0) or nil
    if want == now then return false end
    if want ~= nil then
        if joinedFrom[o] == nil then
            joinedFrom[o] = { params = o.oBehParams,
                model = OF.util.optional("obj_get_model_id_extended", nil, o) }
        end
        o.oBehParams = want
        if spawner.SHAPE_MODEL_ID ~= nil and OF.util.asks(OF.slots, "set_model") then
            OF.slots.set_model(o, spawner.SHAPE_MODEL_ID)
        end
    else
        local was = joinedFrom[o]
        joinedFrom[o] = nil
        o.oBehParams = was.params
        if was.model ~= nil and OF.util.asks(OF.slots, "set_model") then
            OF.slots.set_model(o, was.model)
        end
    end
    spawner.block_changed(o)
    return true
end
spawner.rejoin = rejoin

local function touch(x, y, z)
    local here = blockAt[cell_key(x, y, z)]
    if here ~= nil and join_kind(here) ~= nil then joinDirty[here] = true end
    for k = 1, 4 do
        local n = blockAt[cell_key(x + SIDE_DX[k] * BUILD_CELL, y, z + SIDE_DZ[k] * BUILD_CELL)]
        if n ~= nil and join_kind(n) ~= nil then joinDirty[n] = true end
    end
end

local function touch_box(box)
    local reach = BUILD_CELL * 1.5
    for n in pairs(joinBlocks) do
        if n.activeFlags ~= 0 and n.oPosX > box[1] - reach and n.oPosX < box[2] + reach
            and n.oPosZ > box[5] - reach and n.oPosZ < box[6] + reach
            and n.oPosY >= box[3] - 1 and n.oPosY < box[4] then
            joinDirty[n] = true
        end
    end
end

local function file_block(o, gone)
    local old = keyOf[o]
    if old ~= nil then
        if blockAt[old.key] == o then blockAt[old.key] = nil end
        keyOf[o] = nil
        touch(old.x, old.y, old.z)
    end
    local box = sizedBlocks[o]
    if box ~= nil then
        sizedBlocks[o] = nil
        touch_box(box)
    end
    if gone then
        joinDirty[o] = nil
        joinedFrom[o] = nil
        joinBlocks[o] = nil
        return
    end
    if join_kind(o) ~= nil then joinBlocks[o] = true end
    local word = runtime_word(o, true)
    if word ~= nil and OF.stretch.sized(word) then
        local _, _, w, h, d = OF.stretch.shape_decode(word)
        local q = spawner.quarter_of(o.oFaceAngleYaw or 0)
        local ex, ez = w, d
        if q % 2 == 1 then ex, ez = d, w end
        box = { o.oPosX - ex * BUILD_CELL / 2, o.oPosX + ex * BUILD_CELL / 2, o.oPosY,
                o.oPosY + h * BUILD_CELL, o.oPosZ - ez * BUILD_CELL / 2, o.oPosZ + ez * BUILD_CELL / 2 }
        sizedBlocks[o] = box
        touch_box(box)
        return
    end
    local key = cell_key(o.oPosX, o.oPosY, o.oPosZ)
    blockAt[key] = o
    keyOf[o] = { key = key, x = o.oPosX, y = o.oPosY, z = o.oPosZ }
    if join_kind(o) ~= nil then joinDirty[o] = true end
    touch(o.oPosX, o.oPosY, o.oPosZ)
end
spawner.file_block = file_block

local function moved_off(o)
    local at = keyOf[o]
    if at == nil then return sizedBlocks[o] == nil end
    return at.x ~= o.oPosX or at.y ~= o.oPosY or at.z ~= o.oPosZ
end

function spawner.joins_forget()
    blockAt, keyOf, sizedBlocks, joinDirty, joinedFrom, joinBlocks = {}, {}, {}, {}, {}, {}
end
if type(hook_event) == "function" and HOOK_ON_LEVEL_INIT ~= nil then
    hook_event(HOOK_ON_LEVEL_INIT, spawner.joins_forget)
end

joins.file_block, joins.rejoin, joins.moved_off = file_block, rejoin, moved_off
function joins.filed(o) return keyOf[o] ~= nil or sizedBlocks[o] ~= nil end
function joins.dirty(o) return joinDirty[o] ~= nil end
end

local function build_init(o)
    if o == nil then return end

    local shape = build_shape(o)
    if not spawner.is_water_block(o) then
        wear_mesh(o, build_mesh(shape))
    end

    local word = runtime_word(o, true)
    if word ~= nil and OF.stretch.sized(word) then
        local _, _, w, h, d = OF.stretch.shape_decode(word)
        OF.stretch.cull_for(o, w, h, d)
    end

    o.oCollisionDistance = STANDING_REACH

    o.oDrawingDistance = STANDING_REACH

    o.oFlags = OF.util.add_flag(tonumber(o.oFlags) or 0,
        OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    spawner.square_up(o)

    o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosY, o.oPosZ

    joins.file_block(o)
end

local socOf = {}

local function soc_free(o)
    local held = socOf[o]
    socOf[o] = nil
    if held == nil then return end
    for _, handle in ipairs(held.handles or { held.handle }) do
        if handle ~= nil and OF.util.alive(handle) then
            at_load("remove_static_object_collision", handle)
        end
    end
end

function spawner.build_static(o)
    return socOf[o] ~= nil
end

function spawner.block_changed(o)
    if o == nil then return end
    soc_free(o)
    if OF.util.asks(OF.stretch, "refresh") then OF.stretch.refresh(o) end
end

local function soc_load(o, shape)
    local scale = buildFit[shape] or 1
    local word = runtime_word(o, true)
    local held = socOf[o]
    if held ~= nil and held.x == o.oPosX and held.y == o.oPosY and held.z == o.oPosZ
        and held.yaw == o.oFaceAngleYaw and held.scale == scale
        and held.shape == shape and held.word == word
        and (held.none or OF.util.alive((held.handles or {})[1] or held.handle)) then
        return true
    end
    soc_free(o)

    if word ~= nil then
        local pieces = OF.stretch.solid_pieces(word, build_mesh(shape), build_mesh(0), scale,
            buildFit[0] or 1)

        if #pieces == 0 then
            o.collisionData = nil
            socOf[o] = { handles = {}, none = true, x = o.oPosX, y = o.oPosY, z = o.oPosZ,
                         yaw = o.oFaceAngleYaw, scale = scale, shape = shape, word = word }
            return true
        end
        local handles = OF.stretch.solid(o, pieces)
        if #handles == 0 then return false end
        socOf[o] = { handles = handles, x = o.oPosX, y = o.oPosY, z = o.oPosZ,
                     yaw = o.oFaceAngleYaw, scale = scale, shape = shape, word = word }
        return true
    end
    local handle = at_load("load_static_object_collision")
    if handle == nil then return false end
    socOf[o] = { handle = handle, x = o.oPosX, y = o.oPosY, z = o.oPosZ,
                 yaw = o.oFaceAngleYaw, scale = scale, shape = shape }
    return true
end

hook_event(HOOK_ON_OBJECT_UNLOAD, function(o)
    if o ~= nil and socOf[o] ~= nil then soc_free(o) end
    if o ~= nil and waterOf[o] ~= nil then water_gone(o) end
    if o ~= nil and joins.filed(o) then joins.file_block(o, true) end
end)

function spawner.level_reset()
    local wet = {}
    for o in pairs(waterOf) do wet[#wet + 1] = o end
    for _, o in ipairs(wet) do water_gone(o) end
    for o in pairs(socOf) do socOf[o] = nil end
    return #wet
end
if type(hook_event) == "function" and HOOK_ON_LEVEL_INIT ~= nil then
    hook_event(HOOK_ON_LEVEL_INIT, spawner.level_reset)
end

local function fresh_transform(o)
    if type(obj_build_transform_from_pos_and_angle) ~= "function" then return end
    obj_build_transform_from_pos_and_angle(o, 0x06, 0x12)
end
spawner.fresh_transform = fresh_transform

local function build_loop(o)
    if o == nil then return end

    if OF.util.asks(OF.roundscope, "ghosts") and OF.roundscope.ghosts(o) then
        if socOf[o] ~= nil then soc_free(o) end
        water_gone(o)
        return
    end

    if spawner.is_water_block(o) then
        o.collisionData = nil
        water_block(o)
        return
    end

    if joins.dirty(o) then joins.rejoin(o) end

    local held = socOf[o]
    if held ~= nil and held.x == o.oPosX and held.y == o.oPosY
        and held.z == o.oPosZ and held.yaw == o.oFaceAngleYaw
        and o.oFaceAnglePitch == 0 then
        return
    end

    if joins.moved_off(o) then joins.file_block(o) end

    local shape = build_shape(o)

    if o.collisionData == nil then
        wear_mesh(o, build_mesh(shape))
    end

    spawner.square_up(o)

    local word = runtime_word(o, true)
    if type(obj_scale) == "function" then
        obj_scale(o, (word ~= nil and OF.stretch.sized(word)) and 1 or (buildFit[shape] or 1))
    end

    fresh_transform(o)
    if o.collisionData ~= nil and (buildMeasured[shape] or word ~= nil) and soc_load(o, shape) then
        return
    end
    if type(load_object_collision_model) == "function" then
        load_object_collision_model()
    end

    if not buildMeasured[shape] then fit_to_cell(o, shape) end
end

spawner.BLOCK = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    build_init, build_loop, "of block")

function spawner.build_mesh_name(shape)
    return BUILD_MESH[shape]
end

function spawner.build_fit(shape)
    return buildFit[shape], buildMeasured[shape] == true
end

function spawner.build_span(shape)
    return BUILD_SPAN[shape]
end

spawner.BUILD_LIST = {}
spawner.BUILD_SHELVES = {}

spawner.BUILD_TWINS = {}

local function block_model(geo)
    if at_load("mod_file_exists", "actors/" .. geo .. ".bin") ~= true then
        return nil
    end
    local id = at_load("smlua_model_util_get_id", geo)
    if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then return nil end
    return id
end

local blockOrder, blockAt, blockLayered = nil, {}, {}
local function block_order()
    if blockOrder ~= nil then return blockOrder end
    blockOrder = {}
    for _, shelf in ipairs(BLOCK_SHELVES) do
        for _, block in ipairs(shelf.blocks) do
            local slug = block.key:gsub("^blk", "")
            table.insert(blockOrder, slug)
            blockAt[slug] = #blockOrder
            blockLayered[slug] = block.layered == true
        end
    end
    return blockOrder
end

function spawner.block_index(slug)
    block_order()
    return blockAt[slug]
end

function spawner.block_slug(index)
    return block_order()[index]
end

function spawner.block_layered(slug)
    block_order()
    return blockLayered[slug] == true
end

function spawner.build_resolve()
    for index = #spawner.BUILD_LIST, 1, -1 do spawner.BUILD_LIST[index] = nil end
    for index = #spawner.BUILD_SHELVES, 1, -1 do spawner.BUILD_SHELVES[index] = nil end
    for key in pairs(spawner.BUILD_TWINS) do spawner.BUILD_TWINS[key] = nil end
    for key in pairs(spawner.WATER_MODELS) do spawner.WATER_MODELS[key] = nil end
    for key in pairs(spawner.LAVA_MODELS) do spawner.LAVA_MODELS[key] = nil end
    for key in pairs(spawner.BUILD_SPANS) do spawner.BUILD_SPANS[key] = nil end
    if spawner.BLOCK == nil then return 0 end
    for _, shelf in ipairs(BLOCK_SHELVES) do
        local keys = {}
        for _, block in ipairs(shelf.blocks) do
            local model = block_model(block.geo)
            if model ~= nil then
                table.insert(spawner.BUILD_LIST, {
                    key = block.key, name = block.name, bhv = spawner.BLOCK,
                    model = model, variant = 0, reach = STANDING_REACH,
                    shelf = shelf.name, geo = block.geo, square = true,

                    material = block.key:gsub("^blk", ""), shape = "cube",

                    swatch = block.tex,

                    icon = "of_bsw_" .. block.key:gsub("^blk", ""),
                })
                table.insert(keys, block.key)
                spawner.SIZELESS[block.key] = true
                if block.key == "blk" .. spawner.WATER_MATERIAL then
                    spawner.WATER_MODELS[model] = true
                end
                if block.key == "blk" .. spawner.LAVA_MATERIAL then
                    spawner.LAVA_MODELS[model] = true
                end
            end
        end
        if #keys > 0 then
            table.insert(spawner.BUILD_SHELVES, { name = shelf.name, keys = keys })
        end
    end

    local shapeModel = block_model((OF.stretch and OF.stretch.SHAPE_MODEL) or "of_shape_geo")
    spawner.SHAPE_MODEL_ID = shapeModel
    local runtimeOf = {}
    for _, shelf in ipairs(BLOCK_SHELVES) do
        for _, block in ipairs(shelf.blocks) do
            if block.runtime ~= nil and shapeModel ~= nil then
                local set = {}
                for tag in string.gmatch(block.runtime, "[%w]+") do set[tag] = true end
                runtimeOf[block.key:gsub("^blk", "")] = set
            end
        end
    end
    local function shape_model(slug, tag, geo)
        local model = block_model(geo)
        if model ~= nil then return model, nil end
        local set = runtimeOf[slug]
        if set ~= nil and set[tag] then return shapeModel, spawner.block_index(slug) end
        return nil, nil
    end
    local byTag = {}
    for _, shape in ipairs(SLOPE_SHAPES) do byTag[shape.tag] = shape end
    for _, shape in ipairs(SLOPE_SHAPES) do
        if shape.up == "" then
            local twin = byTag["u" .. shape.tag]
            local keys = {}
            for _, shelf in ipairs(BLOCK_SHELVES) do
                for _, block in ipairs(shelf.blocks) do
                    local slug = block.key:gsub("^blk", "")
                    local geo = "of_slp_" .. shape.tag .. "_" .. slug .. "_geo"
                    local model, rtex = shape_model(slug, shape.tag, geo)
                    if model ~= nil then
                        local key = shape.tag .. slug
                        local entry = {
                            key = key, name = block.name .. " " .. shape.noun,
                            bhv = spawner.BLOCK, model = model, variant = shape.byte,
                            reach = STANDING_REACH, shelf = shape.shelf, geo = geo,
                            square = true, slope = shape.tag, swatch = block.tex,
                            flat = shape.flat, roof = shape.roof, material = slug, shape = shape.tag,
                            span = shape.span, rtex = rtex,
                        }
                        if shape.span ~= nil and rtex == nil then
                            spawner.BUILD_SPANS[model] = shape.span
                        end
                        local twinGeo = twin ~= nil
                            and ("of_slp_" .. twin.tag .. "_" .. slug .. "_geo") or nil
                        local twinModel, twinRtex = nil, nil
                        if twinGeo ~= nil then
                            twinModel, twinRtex = shape_model(slug, twin.tag, twinGeo)
                        end
                        if twinModel ~= nil then
                            entry.flipped = "u" .. key
                            spawner.BUILD_TWINS[entry.flipped] = {
                                key = entry.flipped, name = entry.name .. ", upside down",
                                bhv = spawner.BLOCK, model = twinModel, variant = twin.byte,
                                reach = STANDING_REACH, shelf = shape.shelf, geo = twinGeo,
                                square = true, slope = twin.tag, upright = key, flat = twin.flat,
                                swatch = block.tex, rtex = twinRtex,
                            }
                            spawner.SIZELESS[entry.flipped] = true
                        end
                        table.insert(spawner.BUILD_LIST, entry)
                        table.insert(keys, key)
                        spawner.SIZELESS[key] = true

                        if slug == spawner.WATER_MATERIAL and model ~= shapeModel then
                            spawner.WATER_MODELS[model] = true
                            if twinModel ~= nil and twinModel ~= shapeModel then
                                spawner.WATER_MODELS[twinModel] = true
                            end
                        end

                        if slug == spawner.LAVA_MATERIAL and model ~= shapeModel then
                            spawner.LAVA_MODELS[model] = true
                            if twinModel ~= nil and twinModel ~= shapeModel then
                                spawner.LAVA_MODELS[twinModel] = true
                            end
                        end
                    end
                end
            end
            if #keys > 0 then
                table.insert(spawner.BUILD_SHELVES, { name = shape.shelf, keys = keys })
            end
        end
    end
    spawner.decor_resolve()
    return #spawner.BUILD_LIST
end

function spawner.decor_resolve()

    local ST = OF.stretch
    local shapeModel = spawner.SHAPE_MODEL_ID
    if spawner.BLOCK ~= nil and shapeModel ~= nil and ST ~= nil and ST.RECIPES ~= nil and type(ST.prop_encode) == "function" then
        local keys = {}
        local rids = {}
        for rid in pairs(ST.RECIPES) do rids[#rids + 1] = rid end
        table.sort(rids)
        for _, rid in ipairs(rids) do
            local r = ST.RECIPES[rid]
            local slug = string.format("decor%s", (tostring(r.key):gsub("[^%w]", "")))
            if spawner.build_find(slug) == nil then
                table.insert(spawner.BUILD_LIST, {
                    key = slug, name = r.name, bhv = spawner.BLOCK, model = shapeModel,
                    variant = 0, reach = STANDING_REACH, shelf = spawner.DECOR_SHELF,
                    square = true, decor = rid, decorWord = ST.prop_encode(rid, 0, 0),
                    shape = "decor",
                })
                spawner.SIZELESS[slug] = true
                table.insert(keys, slug)
            end
        end
        if #keys > 0 then
            table.insert(spawner.BUILD_SHELVES, { name = spawner.DECOR_SHELF, keys = keys })
        end
    end
end

if type(hook_event) == "function" and HOOK_ON_MODS_LOADED ~= nil then
    hook_event(HOOK_ON_MODS_LOADED, function() spawner.decor_resolve() end)
end

spawner.build_resolve()

function spawner.runtime_key(object)
    if object == nil or spawner.SHAPE_MODEL_ID == nil then return nil end
    local model = OF.util.optional("obj_get_model_id_extended", nil, object)
    if model ~= spawner.SHAPE_MODEL_ID then return nil end
    local byte = math.floor(tonumber(object.oBehParams2ndByte) or 0)
    local slug = spawner.block_slug(math.floor(tonumber(object.oBehParams) or 0) & 0x3FF)
    if slug == nil then return nil end

    if byte == 0 then
        return spawner.build_find("blk" .. slug) ~= nil and ("blk" .. slug) or nil
    end
    for _, shape in ipairs(SLOPE_SHAPES) do
        if shape.byte == byte then
            local key = shape.tag .. slug
            return spawner.build_find(key) ~= nil and key or nil
        end
    end
    return nil
end

local buildAt = { list = nil, count = -1, at = {} }

function spawner.build_find(key)
    local list = spawner.BUILD_LIST
    if buildAt.list ~= list or buildAt.count ~= #list or buildAt.first ~= list[1]
        or buildAt.last ~= list[#list] then
        buildAt.list, buildAt.count, buildAt.first, buildAt.last = list, #list, list[1], list[#list]
        buildAt.at = {}
        for index, entry in ipairs(list) do
            if buildAt.at[entry.key] == nil then buildAt.at[entry.key] = index end
        end
    end
    local index = buildAt.at[key]
    if index ~= nil and list[index] ~= nil and list[index].key == key then
        return list[index]
    end
    if index == nil and spawner.BUILD_TWINS[key] ~= nil then
        return spawner.BUILD_TWINS[key]
    end
    for _, entry in ipairs(list) do
        if entry.key == key then return entry end
    end
    return spawner.BUILD_TWINS[key]
end

spawner.BLOCK_WAS = BLOCK_WAS

function spawner.renamed_key(key)
    if type(key) ~= "string" then return nil end
    local prefixes = { "blk" }
    for _, shape in ipairs(SLOPE_SHAPES) do table.insert(prefixes, shape.tag) end
    for _, prefix in ipairs(prefixes) do
        if key:sub(1, #prefix) == prefix then
            local new = spawner.BLOCK_WAS[key:sub(#prefix + 1)]
            if new ~= nil and spawner.build_find(prefix .. new) ~= nil then
                return prefix .. new
            end
        end
    end
    return nil
end

function spawner.block_entry(key)
    local entry = spawner.build_find(key)
    if entry ~= nil then return entry end
    local now = spawner.renamed_key(key)
    return now ~= nil and spawner.build_find(now) or nil
end

function spawner.block_geo(key)
    local entry = spawner.block_entry(key)
    if entry ~= nil and entry.geo ~= nil then return entry.geo end
    if type(key) ~= "string" or key:sub(1, 3) ~= "blk" then return nil end
    return "of_blk_" .. key:sub(4) .. "_geo"
end

function spawner.is_building(key)
    return spawner.build_find(key) ~= nil
end

do

spawner.MOVER_MAX_POINTS = 12
spawner.MOVER_MODES = { "loop", "pingpong", "oneway" }

spawner.MOVER_TRIGGERS = { "always", "ridden", "wired" }

local function waits(trigger) return trigger == "ridden" or trigger == "wired" end
spawner.mover_waits = waits

spawner.MOVER_MIN_SPEED = 30
spawner.MOVER_MAX_SPEED = 4200
spawner.MOVER_SPEED = 300

spawner.MOVER_RISE = 50

spawner.MOVER_CARRY = 150

spawner.MOVER_MAX_WAIT = 600
spawner.MOVER_WAIT = 10

spawner.MOVER_CAP = 32

spawner.MOVER_ROLL = 0x40

spawner.MOVER_LOG = 100
spawner.MOVER_LOG_WIDE = 101
local MOVER_FPS = 30

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function index_of(list, word, default)
    for i, w in ipairs(list) do if w == word then return i end end
    return default
end

function spawner.mover_normalise(spec)
    spec = type(spec) == "table" and spec or {}
    local out = {
        mode = spawner.MOVER_MODES[index_of(spawner.MOVER_MODES, spec.mode, 2)],
        trigger = spawner.MOVER_TRIGGERS[index_of(spawner.MOVER_TRIGGERS, spec.trigger, 1)],

        phase = math.floor(clamp(spec.phase or 0, 0, 0x3FFFFFFF) + 0.5),
        link = math.floor(clamp(spec.link or 0, 0, 255) + 0.5),
        points = {},
    }
    local limit = 32000
    for i, p in ipairs(type(spec.points) == "table" and spec.points or {}) do
        if i > spawner.MOVER_MAX_POINTS then break end
        table.insert(out.points, {
            x = math.floor(clamp(p.x, -limit, limit) + 0.5),
            y = math.floor(clamp(p.y, -limit, limit) + 0.5),
            z = math.floor(clamp(p.z, -limit, limit) + 0.5),
            speed = math.floor(clamp(p.speed or spawner.MOVER_SPEED,
                spawner.MOVER_MIN_SPEED, spawner.MOVER_MAX_SPEED) + 0.5),
            wait = math.floor(clamp(p.wait or spawner.MOVER_WAIT, 0,
                spawner.MOVER_MAX_WAIT) + 0.5),
        })
    end
    if #out.points == 0 then
        table.insert(out.points, { x = 0, y = 0, z = 0,
            speed = spawner.MOVER_SPEED, wait = spawner.MOVER_WAIT })
    end

    local first = out.points[1]
    first.x, first.y, first.z = 0, 0, 0
    if #out.points == 1 then
        table.insert(out.points, { x = 0, y = 0, z = 600,
            speed = first.speed, wait = first.wait })
    end
    return out
end

function spawner.mover_default()
    return spawner.mover_normalise({ mode = "pingpong", trigger = "always",
        points = { { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1200 } } })
end

local function leg_frames(a, b, speed)
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    local perFrame = math.max(1, speed / MOVER_FPS)
    local frames = math.ceil(len / perFrame)
    frames = math.max(frames, math.ceil(math.abs(dy) / spawner.MOVER_RISE))
    return math.max(1, frames), len
end

local function yaw_of(dx, dz)
    if dx == 0 and dz == 0 then return nil end
    return math.floor(math.atan(dx, dz) * 0x8000 / math.pi + 0.5) % 0x10000
end

local function short_turn(from, to)
    local d = (to - from) % 0x10000
    if d >= 0x8000 then d = d - 0x10000 end
    return d
end

spawner.mover_turn, spawner.mover_yaw = short_turn, yaw_of

function spawner.mover_timeline(spec)
    spec = spawner.mover_normalise(spec)
    local pts = spec.points
    local n = #pts
    local legs = {}
    local function wait(i, frames)
        table.insert(legs, { wait = true, a = i, frames = frames })
    end
    local function move(i, j, speed)
        local frames, len = leg_frames(pts[i], pts[j], speed)
        table.insert(legs, { a = i, b = j, frames = frames, len = len })
    end
    local w = function(i) return pts[i].wait * 3 end
    if spec.mode == "loop" then
        for i = 1, n do
            wait(i, w(i))
            move(i, i % n + 1, pts[i].speed)
        end
    elseif spec.mode == "oneway" then
        for i = 1, n - 1 do
            wait(i, w(i))
            move(i, i + 1, pts[i].speed)
        end
        wait(n, w(n))
        for i = n, 2, -1 do move(i, i - 1, pts[i - 1].speed) end
    else
        for i = 1, n - 1 do
            wait(i, w(i))
            move(i, i + 1, pts[i].speed)
        end
        wait(n, w(n))
        for i = n, 2, -1 do
            move(i, i - 1, pts[i - 1].speed)
            if i - 1 > 1 then wait(i - 1, w(i - 1)) end
        end
    end

    local at, roll, face = 0, 0, nil
    for _, leg in ipairs(legs) do
        leg.start = at
        at = at + leg.frames
        if not leg.wait then
            local a, b = pts[leg.a], pts[leg.b]
            local yaw = yaw_of(b.x - a.x, b.z - a.z)
            leg.sign = 1
            if yaw ~= nil then
                if face ~= nil and math.abs(short_turn(face, yaw)) > 0x4000 then
                    yaw = (yaw + 0x8000) % 0x10000
                    leg.sign = -1
                end
                face = yaw
            end
            leg.face = face or 0
            leg.roll = roll

            local flat = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
            roll = roll + leg.sign * flat
        end
    end

    local function face_after(k)
        for j = k + 1, #legs + k do
            local leg = legs[(j - 1) % #legs + 1]
            if not leg.wait then return leg.face end
        end
        return 0
    end
    local function face_before(k)
        for j = k - 1, k - #legs, -1 do
            local leg = legs[(j - 1) % #legs + 1]
            if not leg.wait then return leg.face end
        end
        return 0
    end
    local rollAt = 0
    for k, leg in ipairs(legs) do
        if leg.wait then
            leg.faceFrom = face_before(k)
            leg.faceTo = face_after(k)
            leg.roll = rollAt
        else
            rollAt = leg.roll + leg.sign * math.sqrt((pts[leg.b].x - pts[leg.a].x) ^ 2
                + (pts[leg.b].z - pts[leg.a].z) ^ 2)
        end
    end
    return { spec = spec, legs = legs, period = math.max(1, at),
             firstWait = legs[1] ~= nil and legs[1].wait and legs[1].frames or 0 }
end

function spawner.mover_at(timeline, t)
    local legs = timeline.legs
    local pts = timeline.spec.points
    t = t % timeline.period
    for _, leg in ipairs(legs) do
        if t < leg.start + leg.frames or leg == legs[#legs] then
            local f = leg.frames > 0 and (t - leg.start) / leg.frames or 1
            if f < 0 then f = 0 elseif f > 1 then f = 1 end
            if leg.wait then
                local p = pts[leg.a]
                local face = (leg.faceFrom + short_turn(leg.faceFrom, leg.faceTo) * f) % 0x10000
                return p.x, p.y, p.z, math.floor(face + 0.5) % 0x10000,
                    leg.roll * spawner.MOVER_ROLL
            end
            local a, b = pts[leg.a], pts[leg.b]
            local flat = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
            return a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, a.z + (b.z - a.z) * f,
                leg.face, (leg.roll + leg.sign * flat * f) * spawner.MOVER_ROLL
        end
    end
    local p = pts[1]
    return p.x, p.y, p.z, 0, 0
end

local MOVER_LOG_MESH = {
    [100] = "lll_seg7_collision_pitoune",
    [101] = "ttm_seg7_collision_pitoune_2",
}

local MF = 0x51
spawner.MOVER_FIELDS = MF
local MF_MAGIC, MF_COUNT, MF_MODE, MF_TRIGGER, MF_START, MF_PHASE = 0, 1, 2, 3, 4, 5

local MF_LINK = 6
local MF_POINTS, MF_PER_POINT = 8, 4
local MOVER_MAGIC = 0x4D56

local function field_get(o, offset)
    if type(obj_get_field_s32) ~= "function" then return 0 end
    return math.floor(tonumber(obj_get_field_s32(o, MF + offset)) or 0)
end

local function field_set(o, offset, value)
    if type(obj_set_field_s32) ~= "function" then return end
    obj_set_field_s32(o, MF + offset, math.floor(value))
end

local moverCache = {}

function spawner.mover_write(o, spec)
    if o == nil then return nil end
    spec = spawner.mover_normalise(spec)
    field_set(o, MF_MAGIC, MOVER_MAGIC)
    field_set(o, MF_COUNT, #spec.points)
    field_set(o, MF_MODE, index_of(spawner.MOVER_MODES, spec.mode, 2))
    field_set(o, MF_TRIGGER, index_of(spawner.MOVER_TRIGGERS, spec.trigger, 1))
    field_set(o, MF_PHASE, spec.phase)
    field_set(o, MF_LINK, spec.link)
    for i, p in ipairs(spec.points) do
        local base = MF_POINTS + (i - 1) * MF_PER_POINT
        field_set(o, base, p.x)
        field_set(o, base + 1, p.y)
        field_set(o, base + 2, p.z)
        field_set(o, base + 3, p.speed * 1024 + p.wait)
    end
    moverCache[o] = nil
    return spec
end

function spawner.mover_read(o)
    if o == nil or field_get(o, MF_MAGIC) ~= MOVER_MAGIC then return nil end
    local count = field_get(o, MF_COUNT)
    if count < 1 or count > spawner.MOVER_MAX_POINTS then return nil end
    local spec = {
        mode = spawner.MOVER_MODES[field_get(o, MF_MODE)],
        trigger = spawner.MOVER_TRIGGERS[field_get(o, MF_TRIGGER)],
        phase = field_get(o, MF_PHASE),
        link = field_get(o, MF_LINK),
        points = {},
    }
    for i = 1, count do
        local base = MF_POINTS + (i - 1) * MF_PER_POINT
        local packed = field_get(o, base + 3)
        table.insert(spec.points, { x = field_get(o, base), y = field_get(o, base + 1),
            z = field_get(o, base + 2), speed = packed // 1024, wait = packed % 1024 })
    end
    return spawner.mover_normalise(spec)
end

function spawner.mover_start(o)
    return field_get(o, MF_START)
end

local function area_now()
    if type(get_network_area_timer) ~= "function" then return 0 end
    return math.floor(tonumber(get_network_area_timer()) or 0)
end
spawner.mover_now = area_now

local function mover_state(o)
    local state = moverCache[o]
    if state ~= nil then return state end
    local spec = spawner.mover_read(o)
    if spec == nil then return nil end
    state = { timeline = spawner.mover_timeline(spec),
              kind = math.floor(tonumber(o.oBehParams2ndByte) or 0) }
    moverCache[o] = state
    return state
end
spawner.mover_state = mover_state

function spawner.mover_phase(o, state, now)
    state = state or mover_state(o)
    if state == nil then return 0 end
    now = now or area_now()
    local start = spawner.mover_start(o)
    local timeline = state.timeline
    if waits(timeline.spec.trigger) then
        if start < 0 then return 0, false end
        local t = timeline.firstWait + (now - start)
        if now < start or t >= timeline.period then return 0, false end
        return t, true
    end
    return (now - start + timeline.spec.phase) % timeline.period, true
end

function spawner.mover_go(o, t0)
    if o == nil then return false end
    local state = mover_state(o)
    if state == nil then return false end
    t0 = math.floor(tonumber(t0) or area_now())
    local cur = spawner.mover_start(o)
    local cycle = state.timeline.period - state.timeline.firstWait
    if cur >= 0 and t0 >= cur and t0 < cur + cycle then return false end
    if cur >= 0 and t0 < cur and cur - t0 >= cycle then return false end
    field_set(o, MF_START, t0)
    return true
end

spawner.PACKET_MOVER_GO = "movergo"
spawner.PACKET_MOVER_PATH = "moverpath"
function spawner.mover_ride_on(o, state, now, t, running)
    local tl = state.timeline
    local start = spawner.mover_start(o)
    local cycle = tl.period - tl.firstWait
    if start >= 0 and now >= start + cycle and now <= start + tl.period
        and state.decided ~= start then
        state.decided = start
        if spawner.mover_ridden_here(o) then
            local t0 = start + tl.period
            if spawner.mover_go(o, t0) then
                OF.util.send_all({ ofp = spawner.PACKET_MOVER_GO, id = o.oSyncID, t0 = t0 })
                return spawner.mover_phase(o, state, now)
            end
        end
    elseif not running and start <= now and spawner.mover_ridden_here(o) then

        if spawner.mover_go(o, now) then
            OF.util.send_all({ ofp = spawner.PACKET_MOVER_GO, id = o.oSyncID, t0 = now })
            return spawner.mover_phase(o, state, now)
        end
    end
    return t, running
end

function spawner.movers_here()
    local out = {}
    if spawner.MOVER == nil or type(obj_get_first_with_behavior_id) ~= "function" then
        return out
    end
    local o = obj_get_first_with_behavior_id(spawner.MOVER)
    local guard = 0
    while o ~= nil and guard < 1024 do
        if o.activeFlags ~= 0 then table.insert(out, o) end
        o = obj_get_next_with_same_behavior_id(o)
        guard = guard + 1
    end
    return out
end

local function mover_by_sync_id(id)
    id = tonumber(id)
    if id == nil or id == 0 then return nil end
    for _, o in ipairs(spawner.movers_here()) do
        if o.oSyncID == id then return o end
    end
    return nil
end
spawner.mover_by_sync_id = mover_by_sync_id

function spawner.mover_packet(o, spec)
    spec = spawner.mover_normalise(spec)
    local data = { ofp = spawner.PACKET_MOVER_PATH, id = o.oSyncID,
        mode = spec.mode, trigger = spec.trigger, phase = spec.phase, link = spec.link,
        n = #spec.points }
    for i, p in ipairs(spec.points) do
        data["p" .. i] = table.concat({ p.x, p.y, p.z, p.speed, p.wait }, ",")
    end
    return data
end

function spawner.mover_unpacket(data)
    if type(data) ~= "table" then return nil end
    local n = math.floor(tonumber(data.n) or 0)
    if n < 1 or n > spawner.MOVER_MAX_POINTS then return nil end
    local spec = { mode = data.mode, trigger = data.trigger, phase = tonumber(data.phase),
        link = tonumber(data.link), points = {} }
    for i = 1, n do
        local text = data["p" .. i]
        if type(text) ~= "string" then return nil end
        local v = {}
        for word in text:gmatch("[^,]+") do table.insert(v, tonumber(word)) end
        if #v ~= 5 then return nil end
        table.insert(spec.points, { x = v[1], y = v[2], z = v[3], speed = v[4], wait = v[5] })
    end
    return spawner.mover_normalise(spec)
end

function spawner.mover_cycle_frame(o, spec, now)
    local tl = spawner.mover_timeline(spec)
    local start = spawner.mover_start(o)
    if waits(tl.spec.trigger) then
        if start < 0 then return nil, tl end
        local t = tl.firstWait + (now - start)
        if now < start or t >= tl.period then return nil, tl end
        return t, tl
    end
    return (now - start + tl.spec.phase) % tl.period, tl
end

function spawner.mover_match_frame(oldTl, t, newTl, map)
    local legs = oldTl.legs
    local cur, curK = nil, 0
    for k, leg in ipairs(legs) do
        if t < leg.start + leg.frames or k == #legs then cur, curK = leg, k break end
    end
    if cur == nil then return 0 end
    local f = cur.frames > 0 and (t - cur.start) / cur.frames or 0
    f = math.max(0, math.min(1, f))
    local function same(a, b)
        return a.wait == b.wait and a.a == b.a and (a.wait or a.b == b.b)
    end
    local mine = { wait = cur.wait, a = map(cur.a), b = cur.b ~= nil and map(cur.b) or nil }
    if mine.a ~= nil and (mine.wait or mine.b ~= nil) then
        local nth = 0
        for k = 1, curK do
            local l = legs[k]
            if same(l, cur) then nth = nth + 1 end
        end
        local seen = 0
        for _, l in ipairs(newTl.legs) do
            if same(l, mine) then
                seen = seen + 1
                if seen == nth then return l.start + f * l.frames end
            end
        end
    end

    local px, py, pz = spawner.mover_at(oldTl, t)
    local opts, npts = oldTl.spec.points, newTl.spec.points
    local hx, hy, hz = 0, 0, 0
    for j = curK, curK + #legs - 1 do
        local l = legs[(j - 1) % #legs + 1]
        if not l.wait then
            hx, hy, hz = opts[l.b].x - opts[l.a].x, opts[l.b].y - opts[l.a].y,
                opts[l.b].z - opts[l.a].z
            break
        end
    end
    local best, bestD, bestAny, bestAnyD = nil, math.huge, nil, math.huge
    for _, l in ipairs(newTl.legs) do
        if not l.wait then
            local a, b = npts[l.a], npts[l.b]
            local vx, vy, vz = b.x - a.x, b.y - a.y, b.z - a.z
            local len2 = vx * vx + vy * vy + vz * vz
            local s = 0
            if len2 > 0 then
                s = ((px - a.x) * vx + (py - a.y) * vy + (pz - a.z) * vz) / len2
                s = math.max(0, math.min(1, s))
            end
            local d = (a.x + vx * s - px) ^ 2 + (a.y + vy * s - py) ^ 2 + (a.z + vz * s - pz) ^ 2
            local at = l.start + s * l.frames
            if d < bestAnyD then bestAny, bestAnyD = at, d end
            if vx * hx + vy * hy + vz * hz >= 0 and d < bestD then best, bestD = at, d end
        end
    end
    return best or bestAny or 0
end

function spawner.mover_set_path(o, spec, map)
    if o == nil then return nil end
    local old = spawner.mover_read(o)
    local start
    spec = spawner.mover_normalise(spec)
    if old ~= nil then
        local now = area_now()
        local t, oldTl = spawner.mover_cycle_frame(o, old, now)
        if t ~= nil then
            local newTl = spawner.mover_timeline(spec)
            local nt = spawner.mover_match_frame(oldTl, t, newTl,
                map or function(i) return spec.points[i] ~= nil and i or nil end)
            nt = math.floor(nt + 0.5) % newTl.period
            if spec.trigger == "wired" and not waits(old.trigger) then

                start = -1
            elseif waits(spec.trigger) and waits(old.trigger) then
                start = newTl.firstWait + now - nt
            elseif not waits(spec.trigger) then
                spec.phase = (nt - (now - spawner.mover_start(o))) % newTl.period
            end
        end
    end
    spec = spawner.mover_write(o, spec)
    if start ~= nil then field_set(o, MF_START, start) end
    if o.oSyncID ~= nil and o.oSyncID ~= 0 then
        local data = spawner.mover_packet(o, spec)
        data.t0 = start
        OF.util.send_all(data)
    end
    return spec
end

local moverPending = {}

local function mover_receive(data)
    local o = mover_by_sync_id(data.id)
    if o == nil then return false end
    if data.ofp == spawner.PACKET_MOVER_GO then
        spawner.mover_go(o, data.t0)
    else
        local spec = spawner.mover_unpacket(data)
        if spec ~= nil then
            spawner.mover_write(o, spec)

            if tonumber(data.t0) ~= nil then field_set(o, MF_START, tonumber(data.t0)) end
        end
    end
    return true
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" then return end
    if data.ofp ~= spawner.PACKET_MOVER_GO and data.ofp ~= spawner.PACKET_MOVER_PATH then
        return
    end
    if not mover_receive(data) then
        table.insert(moverPending, { data = data, left = 150 })
    end
end)

hook_event(HOOK_UPDATE, function()
    if #moverPending == 0 then return end
    local keep = {}
    for _, wait in ipairs(moverPending) do
        wait.left = wait.left - 1
        if not mover_receive(wait.data) and wait.left > 0 then table.insert(keep, wait) end
    end
    moverPending = keep
end)

hook_event(HOOK_ON_OBJECT_UNLOAD, function(o)
    if o ~= nil and moverCache[o] ~= nil then moverCache[o] = nil end
end)

local function mover_mesh(kind)
    if MOVER_LOG_MESH[kind] ~= nil then
        local data = _G["gGlobalObjectCollisionData"]
        return data ~= nil and data[MOVER_LOG_MESH[kind]] or nil
    end
    return build_mesh(kind)
end

local function ridden_here(o)
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    local body = m ~= nil and m.marioObj or nil
    return body ~= nil and body.platform == o
end
spawner.mover_ridden_here = ridden_here

local function mover_init(o)
    if o == nil then return end
    local kind = math.floor(tonumber(o.oBehParams2ndByte) or 0)
    wear_mesh(o, mover_mesh(kind))
    o.oCollisionDistance = STANDING_REACH
    o.oDrawingDistance = STANDING_REACH
    o.oFlags = OF.util.add_flag(tonumber(o.oFlags) or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)

    moverCache[o] = nil
end

local function mover_loop(o)
    if o == nil then return end
    local kind = math.floor(tonumber(o.oBehParams2ndByte) or 0)
    local isLog = MOVER_LOG_MESH[kind] ~= nil
    if o.collisionData == nil then wear_mesh(o, mover_mesh(kind)) end

    local state = mover_state(o)
    local held = OF.forge ~= nil and OF.forge.held == o
    local ox, oy, oz = o.oPosX, o.oPosY, o.oPosZ
    o.oVelX, o.oVelY, o.oVelZ = 0, 0, 0
    o.oAngleVelPitch, o.oAngleVelYaw = 0, 0

    if held or state == nil then

        if held then o.oHomeX, o.oHomeY, o.oHomeZ = ox, oy, oz end
    else
        local now = area_now()
        local t, running = spawner.mover_phase(o, state, now)
        if state.timeline.spec.trigger == "ridden" then
            t, running = spawner.mover_ride_on(o, state, now, t, running)
        end
        local dx, dy, dz, face, roll = spawner.mover_at(state.timeline, t)
        local nx = (tonumber(o.oHomeX) or 0) + dx
        local ny = (tonumber(o.oHomeY) or 0) + dy
        local nz = (tonumber(o.oHomeZ) or 0) + dz
        local vx, vy, vz = nx - ox, ny - oy, nz - oz
        if vx * vx + vy * vy + vz * vz <= spawner.MOVER_CARRY * spawner.MOVER_CARRY then
            o.oVelX, o.oVelY, o.oVelZ = vx, vy, vz
        end
        o.oPosX, o.oPosY, o.oPosZ = nx, ny, nz
        if isLog then

            local pitch = math.floor(roll + 0.5) % 0x10000
            local was = tonumber(o.oFaceAnglePitch) or 0
            local wasYaw = tonumber(o.oFaceAngleYaw) or 0
            local spin = short_turn(was, pitch)
            local turn = short_turn(wasYaw, face)
            if math.abs(spin) < 0x2000 then o.oAngleVelPitch = spin end
            if math.abs(turn) < 0x2000 then o.oAngleVelYaw = turn end
            o.oFaceAnglePitch = pitch >= 0x8000 and pitch - 0x10000 or pitch
            o.oFaceAngleYaw = face >= 0x8000 and face - 0x10000 or face
            o.oMoveAngleYaw = o.oFaceAngleYaw
        end
    end

    if not isLog then
        spawner.square_up(o)
        if type(obj_scale) == "function" then obj_scale(o, buildFit[kind] or 1) end
    end
    fresh_transform(o)
    if type(load_object_collision_model) == "function" then load_object_collision_model() end
end

spawner.MOVER = at_load("hook_behavior", nil, OBJ_LIST_SURFACE, false,
    mover_init, mover_loop, "of mover")

local moverEntries = {}
spawner.MOVER_LOGS = {
    log = { name = "Rolling log on a path", model = "E_MODEL_LLL_ROLLING_LOG",
            byte = spawner.MOVER_LOG },
    logwide = { name = "Wide rolling log on a path", model = "E_MODEL_TTM_ROLLING_LOG",
                byte = spawner.MOVER_LOG_WIDE },
}

function spawner.mover_find(key)
    if type(key) ~= "string" or key:sub(1, 2) ~= "mv" or spawner.MOVER == nil then
        return nil
    end
    if moverEntries[key] ~= nil then return moverEntries[key] end
    local rest = key:sub(3)
    local entry
    local log = spawner.MOVER_LOGS[rest]
    if log ~= nil then
        local model = _G[log.model]
        if model == nil then return nil end
        entry = { key = key, name = log.name, bhv = spawner.MOVER, model = model,
                  variant = log.byte, reach = STANDING_REACH, mover = true, log = true }
    else
        local block = spawner.build_find(rest)
        if block == nil then return nil end

        entry = { key = key, name = block.name .. " on a path", bhv = spawner.MOVER,
                  model = block.model, variant = block.variant, reach = STANDING_REACH,
                  square = true, mover = true, block = rest, material = block.material,
                  shape = block.shape, swatch = block.swatch, rtex = block.rtex }
    end
    spawner.SIZELESS[key] = true
    moverEntries[key] = entry
    return entry
end

function spawner.is_mover(key)
    return spawner.mover_find(key) ~= nil
end

function spawner.mover_room()
    return spawner.MOVER_CAP - #spawner.movers_here()
end

local nextMoverSpec = nil

function spawner.spawn_mover(key, x, y, z, yaw, spec)
    if spawner.mover_find(key) == nil then return nil end
    if spawner.mover_room() <= 0 then
        OF.notify.show("This level already has @ moving platforms", "warn", 4,
            tostring(spawner.MOVER_CAP))
        return nil
    end
    nextMoverSpec = spawner.mover_normalise(spec or spawner.mover_default())
    local o, entry = spawner.spawn_at(key, x, y, z, yaw)
    nextMoverSpec = nil
    return o, entry
end

function spawner.place_mover(key, x, y, z, yaw, spec)
    local entry = spawner.mover_find(key)
    if entry == nil or spawner.mover_room() <= 0 then return nil end
    if OF.slots == nil or type(OF.slots.spawn_sync) ~= "function" then return nil end
    nextMoverSpec = spawner.mover_normalise(spec or spawner.mover_default())
    local o = OF.slots.spawn_lobby(entry.bhv, entry.model, x, y, z, function(obj)
        obj.oCollisionDistance = STANDING_REACH
        obj.oBehParams2ndByte = entry.variant

        local params = params_of(entry)
        if params ~= nil then obj.oBehParams = params end
        if entry.square then
            spawner.square_up(obj, yaw or 0)
        else
            spawner.face(obj, math.floor(tonumber(yaw) or 0))
        end
        spawner.mover_setup(obj)
    end)
    nextMoverSpec = nil
    return o
end

function spawner.mover_setup(o)

    o.oHomeX, o.oHomeY, o.oHomeZ = o.oPosX, o.oPosY, o.oPosZ
    spawner.mover_write(o, nextMoverSpec or spawner.mover_default())

    local spec = spawner.mover_read(o)
    field_set(o, MF_START, (spec ~= nil and waits(spec.trigger)) and -1 or area_now())
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

spawner.TRAMPOLINE = {

    HEIGHT = 150,

    SINK = 110,
    RISE = 45,

    PULL = 0.30,
    DAMP = 0.86,

    BASE = 30,

    STRENGTH = {
        [0] = { name = "gentle", low = 45, high = 65 },
        [1] = { name = "standard", low = 70, high = 100 },
        [2] = { name = "launch", low = 105, high = 145 },
    },

    KNOCK = 0.34,
    KNOCK_MIN = 9,

    POUND_FRAMES = 8,
    POUND_WEIGHT = 2.0,

    HOLD = 6,
}

do
    local T = spawner.TRAMPOLINE

    local before = {}
    local now = {}

    local fell = {}
    local held = {}
    local pounded = {}

    local seen = -1

    local function remember()
        local at = get_global_timer()
        if at == seen then return end
        seen = at
        for i = 0, MAX_PLAYERS - 1 do
            local m = gMarioStates[i]
            local o = m ~= nil and m.marioObj or nil
            before[i] = now[i]
            now[i] = o ~= nil and o.platform or nil
            if m ~= nil then
                local down = 0
                if m.vel ~= nil and type(m.vel.y) == "number" and m.vel.y < 0 then
                    down = -m.vel.y
                end
                if down > 0 then
                    fell[i] = down
                    held[i] = T.HOLD
                else
                    local left = (held[i] or 0) - 1
                    if left > 0 then
                        held[i] = left
                    else
                        held[i] = 0
                        fell[i] = 0
                    end
                end

                if m.action == ACT_GROUND_POUND
                    or m.action == ACT_GROUND_POUND_LAND then
                    pounded[i] = T.POUND_FRAMES
                else
                    local left = (pounded[i] or 0) - 1
                    pounded[i] = left > 0 and left or 0
                end
            end
        end
    end

    local function strength_of(o)
        local byte = o ~= nil and o.oBehParams2ndByte or nil
        if type(byte) ~= "number" then return T.STRENGTH[1] end
        return T.STRENGTH[math.floor(byte)] or T.STRENGTH[1]
    end

    local function throw_for(o, speed)
        local band = strength_of(o)
        local want = T.BASE + speed
        if want < band.low then want = band.low end
        if want > band.high then want = band.high end
        return want
    end

    local function throw_local(owed)
        local m = gMarioStates[0]
        if m == nil or owed <= 0 then return false end
        if m.action == ACT_TWIRLING then return false end

        mario_stop_riding_and_holding(m)
        set_mario_action(m, ACT_TWIRLING, 0)
        if m.vel ~= nil then m.vel.y = owed end
        return true
    end

    local function trampoline_top(o)
        if o == nil then return false end
        remember()

        local home = o.oHomeY
        if type(home) ~= "number" then return false end
        local displace = o.oForwardVel or 0
        local speed = o.oVelY or 0
        local owed = o.oGravity or 0

        local knock = 0
        for i = 0, MAX_PLAYERS - 1 do
            if now[i] == o and before[i] ~= o then
                local came = fell[i] or 0
                if (pounded[i] or 0) > 0 then came = came * T.POUND_WEIGHT end
                local hit = T.KNOCK_MIN + came * T.KNOCK
                if hit > knock then knock = hit end

                if i == 0 then owed = throw_for(o, came) end
            end
        end
        speed = speed - knock

        speed = (speed - displace * T.PULL) * T.DAMP
        displace = displace + speed
        if displace < -T.SINK then
            displace = -T.SINK
            if speed < 0 then speed = 0 end
        elseif displace > T.RISE then
            displace = T.RISE
            if speed > 0 then speed = 0 end
        end

        if owed > 0 and displace < 0 and speed >= 0 then
            throw_local(owed)
            owed = 0
        end

        if owed <= 0 and displace < 0.5 and displace > -0.5
            and speed < 0.5 and speed > -0.5 then
            displace = 0
            speed = 0
        end

        o.oForwardVel = displace
        o.oVelY = speed
        o.oGravity = owed
        o.oPosY = home + displace
        return true
    end

    local function trampoline_spring(o)
        if o == nil then return false end
        local parent = o.parentObj

        if parent == nil or parent == o then return false end

        if parent.activeFlags == 0 then
            reap_children(id_bhvStaticObject, parent)
            obj_mark_for_deletion(o)
            return true
        end

        local home = o.oHomeY
        if type(home) ~= "number" or type(o.oPosY) ~= "number" then return false end

        local scale = 1.0 + (o.oPosY - home) / T.HEIGHT

        if scale < 0.05 then scale = 0.05 end

        local wide = 1.0
        local gfx = parent.header ~= nil and parent.header.gfx or nil
        if gfx ~= nil and gfx.scale ~= nil and type(gfx.scale.x) == "number" then
            wide = gfx.scale.x
        end

        obj_scale_xyz(o, wide, wide * scale, wide)
        return true
    end

    spawner.trampoline_top, spawner.trampoline_spring = trampoline_top, trampoline_spring
end

if id_bhvBetaTrampolineTop ~= nil then
    at_load("hook_behavior", id_bhvBetaTrampolineTop, OBJ_LIST_SURFACE,
        false, nil, spawner.trampoline_top)
end
if id_bhvBetaTrampolineSpring ~= nil then
    at_load("hook_behavior", id_bhvBetaTrampolineSpring, OBJ_LIST_DEFAULT,
        false, nil, spawner.trampoline_spring)
end

spawner.PYRAMID_WALL_PERIOD = 200

local AREA_LOOP = AREA_TIMER_TYPE_LOOP or 1
local AREA_MAXIMUM = AREA_TIMER_TYPE_MAXIMUM or 2

function spawner.catch_up_area_timer(o)
    if o == nil or type(get_network_area_timer) ~= "function" then return false end
    local kind = math.floor(tonumber(o.areaTimerType) or 0)
    local period = math.floor(tonumber(o.areaTimerDuration) or 0)
    local now = math.floor(tonumber(get_network_area_timer()) or 0)
    local timer = math.floor(tonumber(o.areaTimer) or 0)
    local behind = now - timer
    if kind == AREA_MAXIMUM then
        if behind < period or timer >= 10 then return false end
        o.areaTimer = now
        return true
    end
    if period <= 0 or behind < period then return false end
    o.areaTimer = timer + math.floor(behind / period) * period
    return true
end

spawner.AREA_TIMED = {
    { id_bhvSslMovingPyramidWall, OBJ_LIST_SURFACE },
    { id_bhvExclamationBox, OBJ_LIST_SURFACE },
    { id_bhvSmallBomp, OBJ_LIST_SURFACE },
    { id_bhvLargeBomp, OBJ_LIST_SURFACE },
    { id_bhvWfSlidingPlatform, OBJ_LIST_SURFACE },
    { id_bhvWfRotatingWoodenPlatform, OBJ_LIST_SURFACE },
    { id_bhvCheckerboardPlatformSub, OBJ_LIST_SURFACE },
    { id_bhvDddMovingPole, OBJ_LIST_POLELIKE },
}
for _, row in ipairs(spawner.AREA_TIMED) do
    if row[1] ~= nil then
        at_load("hook_behavior", row[1], row[2], false, spawner.catch_up_area_timer, nil)
    end
end

function spawner.placed_by_a_mod(o)
    if o == nil then return false end
    local flags = math.floor(tonumber(o.coopFlags) or 0)
    return OF.util.has_flag(flags, COOP_OBJ_FLAG_LUA or 2)
        or OF.util.has_flag(flags, COOP_OBJ_FLAG_NETWORK or 1)
end
local placed_by_a_mod = spawner.placed_by_a_mod

function spawner.level() return OF.slots.level() end
function spawner.spawn_non_sync(bhv, model, x, y, z, setup)
    return OF.slots.spawn_non_sync(bhv, model, x, y, z, setup)
end
function spawner.set_model(o, model) return OF.slots.set_model(o, model) end
function spawner.held_here(o) return OF.forge ~= nil and OF.forge.held == o end
function spawner.play_sound(id)
    if OF.util.asks(OF.sounds, "play") then OF.sounds.play(id) end
end
function spawner.optional(name, fallback, ...) return OF.util.optional(name, fallback, ...) end
function spawner.binding(name) return OF.util.binding(name) end

function spawner.dress_unplaced(o)
    local level = OF.slots.level()
    if OF.slots.known == nil or not OF.slots.known(level) then return false end
    local drawn = OF.util.optional("obj_get_model_id_extended", nil, o)
    local broken = E_MODEL_ERROR_MODEL ~= nil and type(obj_has_model_extended) == "function"
        and obj_has_model_extended(o, E_MODEL_ERROR_MODEL) ~= 0
    return broken or (drawn ~= nil and OF.slots.risky(drawn))
end

local function has_flag(value, flag)
    if value == nil or flag == nil or flag == 0 then return false end
    return math.floor(value / flag) % 2 == 1
end

spawner.CHILD_MODEL = {
    { bhv = id_bhvCapSwitchBase, list = OBJ_LIST_SURFACE, model = E_MODEL_CAP_SWITCH_BASE },
    { bhv = id_bhvFloorTrapInCastle, list = OBJ_LIST_SURFACE, model = E_MODEL_CASTLE_BOWSER_TRAP },
    { bhv = id_bhvSlidingSnowMound, list = OBJ_LIST_SURFACE, model = E_MODEL_SL_SNOW_TRIANGLE },
    { bhv = id_bhvWigglerBody, list = OBJ_LIST_GENACTOR, model = E_MODEL_WIGGLER_BODY },
    { bhv = id_bhvPokeyBodyPart, list = OBJ_LIST_GENACTOR, model = E_MODEL_POKEY_BODY_PART,
      head = E_MODEL_POKEY_HEAD },
    { bhv = id_bhvChainChompChainPart, list = OBJ_LIST_GENACTOR, model = E_MODEL_METALLIC_BALL },
    { bhv = id_bhvWoodenPost, list = OBJ_LIST_SURFACE, model = E_MODEL_WOODEN_POST },
    { bhv = id_bhvMoneybag, list = OBJ_LIST_GENACTOR, model = E_MODEL_MONEYBAG },
    { bhv = id_bhvBowserShockWave, list = OBJ_LIST_DEFAULT, model = E_MODEL_BOWSER_WAVE },

    { bhv = id_bhvFerrisWheelPlatform, list = OBJ_LIST_SURFACE, model = E_MODEL_BITS_BLUE_PLATFORM,
      byParent = { [0] = E_MODEL_BITS_BLUE_PLATFORM, [1] = E_MODEL_BITDW_BLUE_PLATFORM } },
    { bhv = id_bhvTumblingBridgePlatform, list = OBJ_LIST_SURFACE, model = E_MODEL_BBH_TUMBLING_PLATFORM_PART,
      byParent = { [1] = E_MODEL_BBH_TUMBLING_PLATFORM_PART, [2] = E_MODEL_LLL_FALLING_PLATFORM,
                   [3] = E_MODEL_BITFS_TUMBLING_PLATFORM_PART } },
    { bhv = id_bhvCheckerboardPlatformSub, list = OBJ_LIST_SURFACE, model = E_MODEL_CHECKERBOARD_PLATFORM },
    { bhv = id_bhvCannonBarrel, list = OBJ_LIST_DEFAULT, model = E_MODEL_CANNON_BARREL },
    { bhv = id_bhvMrIBody, list = OBJ_LIST_DEFAULT, model = E_MODEL_MR_I_IRIS },
    { bhv = id_bhvDddMovingPole, list = OBJ_LIST_POLELIKE, model = E_MODEL_BITFS_BLUE_POLE },
    { bhv = id_bhvKoopaShell, list = OBJ_LIST_LEVEL, model = E_MODEL_KOOPA_SHELL },
    { bhv = id_bhvSnufitBalls, list = OBJ_LIST_GENACTOR, model = E_MODEL_BOWLING_BALL },
    { bhv = id_bhvBobomb, list = OBJ_LIST_DESTRUCTIVE, model = E_MODEL_BLACK_BOBOMB },
    { bhv = id_bhvSpiny, list = OBJ_LIST_PUSHABLE, model = E_MODEL_SPINY_BALL,
      keeps = { E_MODEL_SPINY } },
}

function spawner.child_model(row, o)
    if row == nil then return nil end
    if row.head ~= nil and o ~= nil and math.floor(tonumber(o.oBehParams2ndByte) or 0) == 0 then
        return row.head
    end
    if row.byParent ~= nil then
        local parent = o ~= nil and o.parentObj or nil
        local byte = parent ~= nil and math.floor(tonumber(parent.oBehParams2ndByte) or 0) or 0
        return row.byParent[byte]
    end
    return row.model
end

local CHILD_HOPS = 3

function spawner.of_a_placed_family(o)
    local at = o ~= nil and o.parentObj or nil
    for _ = 1, CHILD_HOPS do
        if at == nil then return false end
        if placed_by_a_mod(at) then return true end
        if at.parentObj == at then return false end
        at = at.parentObj
    end
    return false
end

local function wears(o, model)
    if type(obj_has_model_extended) ~= "function" then return false end
    if E_MODEL_ERROR_MODEL ~= nil and obj_has_model_extended(o, E_MODEL_ERROR_MODEL) ~= 0 then
        return false
    end
    return obj_has_model_extended(o, model) ~= 0
end

function spawner.dress_child(row, o)
    if o == nil or row == nil then return false end
    local model = spawner.child_model(row, o)
    if model == nil or wears(o, model) then return false end
    for _, other in ipairs(row.keeps or {}) do
        if wears(o, other) then return false end
    end
    if not spawner.of_a_placed_family(o) then

        if not spawner.dress_unplaced(o) then return false end
    end
    if type(obj_set_model_extended) ~= "function" then return false end
    spawner.set_model(o, model)
    return true
end

local ALIVE = (ACTIVE_FLAG_ACTIVE or 1) + (ACTIVE_FLAG_UNK8 or 0x100)

function spawner.wake_mips(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    if o.activeFlags ~= 0 then return false end
    o.activeFlags = ALIVE
    o.oBehParams2ndByte = 0
    o.oMipsForwardVelocity = 40.0
    return true
end

local YOSHI_IDLE = YOSHI_ACT_IDLE or 0
local YOSHI_STAYS = {
    [YOSHI_ACT_WALK or 1] = true,
    [YOSHI_ACT_WALK_JUMP_OFF_ROOF or 3] = true,
    [YOSHI_ACT_FINISH_JUMPING_AND_DESPAWN or 4] = true,
    [YOSHI_ACT_GONE or 6] = true,
    [YOSHI_ACT_REAPPEAR or 7] = true,
}
local INVISIBLE = GRAPH_RENDER_INVISIBLE or 16

local function show(o)
    local node = o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.node or nil
    if node ~= nil and has_flag(node.flags or 0, INVISIBLE) then
        node.flags = node.flags - INVISIBLE
    end
end

function spawner.keep_yoshi(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    if not YOSHI_STAYS[o.oAction] then return false end
    o.oAction = YOSHI_IDLE
    o.oForwardVel = 0
    o.oVelY = 0
    o.oIntangibleTimer = 0
    show(o)
    return true
end

spawner.CANNON_SINK = 340

function spawner.lift_cannon(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    o.oPosY = o.oPosY + spawner.CANNON_SINK
    o.oHomeY = o.oHomeY + spawner.CANNON_SINK
    return true
end

function spawner.keep_bub(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    local mario = gMarioStates[0] ~= nil and gMarioStates[0].marioObj or nil
    if mario == nil then return false end
    o.parentObj = mario
    return true
end

local AMP_ASLEEP = HOMING_AMP_ACT_INACTIVE or 0

function spawner.show_amp(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    if o.oAction ~= AMP_ASLEEP then return false end
    show(o)
    return true
end

spawner.CAP_HOLD_TIMER = 60

function spawner.keep_cap(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    if (tonumber(o.oTimer) or 0) <= 250 then return false end
    o.oTimer = spawner.CAP_HOLD_TIMER
    return true
end

spawner.HOLD_CLOCK = {
    { bhv = id_bhvSingleCoinGetsSpawned, list = OBJ_LIST_LEVEL, past = 350, back = 300 },
    { bhv = id_bhvBlueCoinJumping, list = OBJ_LIST_GENACTOR, action = 3, past = 50, back = 0 },
    { bhv = id_bhv1upWalking, list = OBJ_LIST_LEVEL, action = 1, past = 250, back = 200 },
}

spawner.CLOCK_MARK = 0x4F000000

function spawner.hold_clock(row, o)
    if row == nil or o == nil or o.oBehParams ~= spawner.CLOCK_MARK then return false end
    if not placed_by_a_mod(o) then return false end
    if row.action ~= nil and o.oAction ~= row.action then return false end
    if (tonumber(o.oTimer) or 0) <= row.past then return false end
    o.oTimer = row.back
    return true
end

spawner.BOX_FALL = 20

function spawner.settle_box(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    if spawner.held_here(o) then return false end
    if type(find_floor_height) ~= "function" then return false end
    local floor = tonumber(find_floor_height(o.oPosX, o.oPosY + 10, o.oPosZ)) or -11000
    if floor <= -10000 or o.oPosY <= floor then return false end
    o.oPosY = math.max(floor, o.oPosY - spawner.BOX_FALL)
    o.oHomeY = o.oPosY
    return true
end

spawner.BOWSER_SKIP_INTRO = 2
local BOWSER_WAITING = { [5] = true, [6] = true, [20] = true }

function spawner.wake_bowser(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    o.oBowserUnk88 = spawner.BOWSER_SKIP_INTRO
    if BOWSER_WAITING[o.oAction] then o.oAction = 0 end
    return true
end

local BOWSER_ARENA_LEVELS = {}
for _, name in ipairs({ "LEVEL_BOWSER_1", "LEVEL_BOWSER_2", "LEVEL_BOWSER_3" }) do
    if type(_G[name]) == "number" then BOWSER_ARENA_LEVELS[_G[name]] = true end
end
spawner.BOWSER_JUMP_ONTO_STAGE = 2
spawner.BOWSER_LAND_RADIUS = 200

function spawner.home_bowser(o)
    if o == nil or not placed_by_a_mod(o) then return false end

    if BOWSER_WAITING[o.oAction] then return spawner.wake_bowser(o) end
    if BOWSER_ARENA_LEVELS[spawner.level() or -1] then return false end
    local hx, hz = tonumber(o.oHomeX) or 0, tonumber(o.oHomeZ) or 0
    local moved = false
    if o.oPosX == 0 and o.oPosZ == 0 and o.oPosY == (tonumber(o.oHomeY) or 0) + 2000 then
        o.oPosX, o.oPosZ = hx, hz
        moved = true
    end
    if o.oAction == spawner.BOWSER_JUMP_ONTO_STAGE and o.oSubAction == 2 then
        local dx, dz = hx - o.oPosX, hz - o.oPosZ
        o.oMoveAngleYaw = atan2s(dz, dx)
        local r = spawner.BOWSER_LAND_RADIUS
        if dx * dx + dz * dz < r * r then o.oForwardVel = 0 end
        moved = true
    end
    return moved
end

spawner.FINAL_BOWSER = 2
spawner.FINAL_BOWSER_HITS = 3
spawner.FINAL_BOWSER_UNLIT = 1

function spawner.is_final_bowser(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    local params = math.floor(tonumber(o.oBehParams) or 0)
    return ((params >> 16) & 0xFF) == spawner.FINAL_BOWSER
end

function spawner.final_bowser(o, init)
    if not spawner.is_final_bowser(o) then return false end
    o.oBehParams2ndByte = spawner.FINAL_BOWSER
    o.oBowserUnk1B2 = spawner.FINAL_BOWSER_UNLIT
    if init then o.oHealth = spawner.FINAL_BOWSER_HITS end
    return true
end

function spawner.start_bowser(o)
    local woke = spawner.wake_bowser(o)
    spawner.final_bowser(o, true)
    return woke
end

function spawner.keep_bowser(o)
    spawner.final_bowser(o, false)
    return spawner.home_bowser(o)
end

spawner.GRAND_STAR_FLYING = 1

function spawner.drop_grand_star(o)
    if o == nil or o.oAction ~= spawner.GRAND_STAR_FLYING or o.oSubAction ~= 0 then return false end
    if LEVEL_BOWSER_3 ~= nil and spawner.level() == LEVEL_BOWSER_3 then return false end
    local boss = o.parentObj
    if boss == nil or boss == o or obj_has_behavior_id(boss, id_bhvBowser) == 0
        or not placed_by_a_mod(boss) then return false end
    o.oForwardVel = 0
    return true
end

spawner.CHILL_FALL = 1000
spawner.BULLY_CHILL_BIT = 0x10
spawner.BULLY_LAVA_DEATH = 100
local BULLY_ON_ITS_FEET = { [0] = true, [1] = true, [2] = true, [3] = true }

local function chill_line()
    local values = gBehaviorValues
    local line = values ~= nil and tonumber(values.ChillBullyDeathPosY) or nil
    return line or 1030
end

function spawner.chill_keeps_the_game_line(o)
    if o == nil or LEVEL_SL == nil or spawner.level() ~= LEVEL_SL then return false end
    return (tonumber(o.oHomeY) or -20000) >= chill_line()
end

function spawner.unchill(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    if spawner.chill_keeps_the_game_line(o) then return false end
    o.oBullySubtype = 0
    if o.oAction == spawner.BULLY_LAVA_DEATH and (tonumber(o.oPosY) or 0) < chill_line() then
        o.oAction = 0
    end
    return true
end

function spawner.chill_edge(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    if o.oBullySubtype ~= 0 then return false end
    if not BULLY_ON_ITS_FEET[o.oAction] then return false end
    if (tonumber(o.oPosY) or 0) >= (tonumber(o.oHomeY) or 0) - spawner.CHILL_FALL then return false end
    o.oBullySubtype = spawner.BULLY_CHILL_BIT
    o.oAction = spawner.BULLY_LAVA_DEATH
    return true
end

spawner.SPINY_MARK = 0x4F460000
spawner.SPINY_ANCHOR_Y = -30000
local SPINY_ALIVE = (ACTIVE_FLAG_ACTIVE or 1) + (ACTIVE_FLAG_UNK8 or 0x100)
local spinyAnchor = nil
local spinyOpen = {}

function spawner.is_placed_spiny(o)
    return o ~= nil and o.oBehParams == spawner.SPINY_MARK and placed_by_a_mod(o)
end

function spawner.forget_spiny_anchor()
    spinyAnchor = nil
end

function spawner.spiny_anchor()
    if spinyAnchor ~= nil and spinyAnchor.activeFlags ~= 0 then return spinyAnchor end
    spinyAnchor = nil
    if id_bhvEnemyLakitu == nil then return nil end
    spinyAnchor = spawner.spawn_non_sync(id_bhvEnemyLakitu, E_MODEL_NONE,
        0, spawner.SPINY_ANCHOR_Y, 0, no_setup)
    return spinyAnchor
end

function spawner.open_spiny_window(m)
    if m == nil or m.playerIndex ~= 0 then return 0 end
    for k in pairs(spinyOpen) do spinyOpen[k] = nil end
    if id_bhvSpiny == nil or spawner.binding("obj_get_first_with_behavior_id") == nil then
        return 0
    end
    local opened, guard = 0, 0
    local spiny = obj_get_first_with_behavior_id(id_bhvSpiny)
    while spiny ~= nil and guard < CHILD_WALK_LIMIT do
        if spiny.activeFlags ~= 0 and spawner.is_placed_spiny(spiny) then
            local anchor = spawner.spiny_anchor()
            if anchor == nil then return opened end
            spiny.parentObj = anchor
            spinyOpen[spiny.oSyncID or 0] = true
            opened = opened + 1
        end
        spiny = obj_get_next_with_same_behavior_id(spiny)
        guard = guard + 1
    end
    return opened
end

function spawner.close_spiny_window(o)
    if not spawner.is_placed_spiny(o) then return false end
    o.parentObj = o
    if o.activeFlags == 0 and spinyOpen[o.oSyncID or 0] then
        o.activeFlags = SPINY_ALIVE
    end
    return true
end

spawner.BOMB_BURST_SCALE = 1
function spawner.burst_bowser_bomb(o)
    if o == nil or not placed_by_a_mod(o) then return false end
    if (tonumber(o.activeFlags) or 0) ~= 0 then return false end
    local hitMine = INT_STATUS_HIT_MINE or 0x00200000
    if has_flag(math.floor(tonumber(o.oInteractStatus) or 0), hitMine) then
        return false
    end
    local x, y, z = o.oPosX or 0, o.oPosY or 0, o.oPosZ or 0
    if id_bhvBowserBombExplosion ~= nil and E_MODEL_BOWSER_FLAMES ~= nil then
        spawner.spawn_non_sync(id_bhvBowserBombExplosion,
            E_MODEL_BOWSER_FLAMES, x, y, z, nil)
    end
    if SOUND_GENERAL_BOWSER_BOMB_EXPLOSION ~= nil then
        spawner.play_sound(SOUND_GENERAL_BOWSER_BOMB_EXPLOSION)
    end
    spawner.optional("set_camera_shake_from_point", nil, SHAKE_POS_LARGE, x, y, z)
    return true
end

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function()
    local out = {}
    for _, row in ipairs(spawner.CHILD_MODEL) do
        out[#out + 1] = row.model
        if row.head ~= nil then out[#out + 1] = row.head end
        for _, model in pairs(row.byParent or {}) do out[#out + 1] = model end
    end
    return out
end)
for _, row in ipairs(spawner.CHILD_MODEL) do
    if row.bhv ~= nil and row.model ~= nil then
        at_load("hook_behavior", row.bhv, row.list, false, function(o)
            spawner.dress_child(row, o)
        end, nil)
    end
end
for _, row in ipairs(spawner.HOLD_CLOCK) do
    if row.bhv ~= nil then
        at_load("hook_behavior", row.bhv, row.list, false, nil, function(o)
            spawner.hold_clock(row, o)
        end)
    end
end
for _, id in ipairs({ id_bhvSmallChillBully, id_bhvBigChillBully }) do
    if id ~= nil then
        at_load("hook_behavior", id, OBJ_LIST_GENACTOR, false, spawner.unchill, spawner.chill_edge)
    end
end
hook_event(HOOK_BEFORE_MARIO_UPDATE, spawner.open_spiny_window, OF.LOCAL_MARIO)
hook_event(HOOK_ON_LEVEL_INIT, spawner.forget_spiny_anchor)
if id_bhvSpiny ~= nil then
    at_load("hook_behavior", id_bhvSpiny, OBJ_LIST_PUSHABLE, false, nil, spawner.close_spiny_window)
end
if id_bhvBowser ~= nil then
    at_load("hook_behavior", id_bhvBowser, OBJ_LIST_GENACTOR, false,
        spawner.start_bowser, spawner.keep_bowser)
end
if id_bhvGrandStar ~= nil then
    at_load("hook_behavior", id_bhvGrandStar, OBJ_LIST_LEVEL, false, nil, spawner.drop_grand_star)
end
if id_bhvBowserBomb ~= nil then
    at_load("hook_behavior", id_bhvBowserBomb, OBJ_LIST_GENACTOR, false, nil,
        spawner.burst_bowser_bomb)
end

if id_bhvMips ~= nil then
    at_load("hook_behavior", id_bhvMips, OBJ_LIST_GENACTOR, false, spawner.wake_mips, nil)
end
if id_bhvYoshi ~= nil then
    at_load("hook_behavior", id_bhvYoshi, OBJ_LIST_GENACTOR, false,
        spawner.keep_yoshi, spawner.keep_yoshi)
end
if id_bhvCannon ~= nil then
    at_load("hook_behavior", id_bhvCannon, OBJ_LIST_LEVEL, false, spawner.lift_cannon, nil)
end
if id_bhvBub ~= nil then
    at_load("hook_behavior", id_bhvBub, OBJ_LIST_GENACTOR, false, spawner.keep_bub, nil)
end
if id_bhvHomingAmp ~= nil then
    at_load("hook_behavior", id_bhvHomingAmp, OBJ_LIST_GENACTOR, false, spawner.show_amp,
        spawner.show_amp)
end
if id_bhvWingCap ~= nil then
    at_load("hook_behavior", id_bhvWingCap, OBJ_LIST_LEVEL, false, nil, spawner.keep_cap)
end
if id_bhvPushableMetalBox ~= nil then
    at_load("hook_behavior", id_bhvPushableMetalBox, OBJ_LIST_SURFACE, false,
        nil, spawner.settle_box)
end

spawner.WIGGLER_UNINITIALIZED = WIGGLER_ACT_UNINITIALIZED or 0
spawner.WIGGLER_DIALOG_READ = WIGGLER_TEXT_STATUS_COMPLETED_DIALOG or 2

function spawner.mend_wiggler(o)
    if o == nil then return false end
    local mended = false
    if o.oWigglerSegments == nil and o.oAction ~= spawner.WIGGLER_UNINITIALIZED then
        o.oAction = spawner.WIGGLER_UNINITIALIZED
        mended = true
    end
    local np = gNetworkPlayers[0]
    if np ~= nil and np.currLevelNum ~= LEVEL_THI
        and (tonumber(o.oWigglerTextStatus) or 0) < spawner.WIGGLER_DIALOG_READ then
        o.oWigglerTextStatus = spawner.WIGGLER_DIALOG_READ
    end
    return mended
end

if id_bhvWigglerHead ~= nil then
    at_load("hook_behavior", id_bhvWigglerHead, OBJ_LIST_GENACTOR, false,
        spawner.mend_wiggler, nil)
end

function spawner.spawn(key)
    local m = gMarioStates[0]
    if m == nil then return false end

    local x, y, z = spot_in_front(m)
    local object, entry = spawner.spawn_at(key, x, y, z)
    if object == nil then return false end

    OF.notify.show("@ spawned  (@)", "good", 2, entry.name, spawner.room_text())
    return true
end
