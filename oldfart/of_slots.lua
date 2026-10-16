OF = OF or {}
OF.slots = OF.slots or {}
local slots = OF.slots

slots.forced = slots.forced or 0

slots.VANILLA_END = 255

slots.WARM_PER_FRAME = 4

slots.KNOWN = "BBH BITDW BITFS BITS BOB BOWSER_1 BOWSER_2 BOWSER_3 CASTLE CASTLE_COURTYARD CASTLE_GROUNDS CCM COTMC DDD ENDING HMC JRB LLL PSS RR SA SL SSL THI TOTWC TTC TTM VCUTM WDW WF WMOTR"
slots.TABLE = {
    [0x12] = {
        { "E_MODEL_BITS_WARP_PIPE", "BITDW" },
        { false, "BITFS BITS RR TTM WF" },
    },
    [0x16] = {
        { "E_MODEL_BITS_WARP_PIPE", "CASTLE_GROUNDS THI VCUTM" },
        { false, "RR TTM" },
    },
    [0x1D] = {
        { "E_MODEL_BBH_HAUNTED_DOOR", "BBH" },
        { "E_MODEL_HMC_WOODEN_DOOR", "CASTLE HMC" },
    },
    [0x27] = {
        { "E_MODEL_CCM_CABIN_DOOR", "CCM" },
        { "E_MODEL_HMC_WOODEN_DOOR", "CASTLE CASTLE_COURTYARD" },
    },
    [0x35] = {
        { "E_MODEL_CASTLE_BOWSER_TRAP", "CASTLE" },
        { "E_MODEL_BBH_STAIRCASE_STEP", "BBH" },
        { "E_MODEL_JRB_SHIP_LEFT_HALF_PART", "JRB" },
        { "E_MODEL_LLL_WOOD_BRIDGE", "LLL" },
        { "E_MODEL_TTM_ROLLING_LOG", "TTM" },
    },
    [0x36] = {
        { "E_MODEL_BITFS_PLATFORM_ON_TRACK", "BITFS" },
        { "E_MODEL_BITS_SLIDING_PLATFORM", "BITS" },
        { "E_MODEL_BOB_CHAIN_CHOMP_GATE", "BOB" },
        { "E_MODEL_BOWSER_2_TILTING_ARENA", "BOWSER_2" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_1", "BOWSER_3" },
        { "E_MODEL_CASTLE_WATER_LEVEL_PILLAR", "CASTLE" },
        { "E_MODEL_CASTLE_GROUNDS_VCUTM_GRILL", "CASTLE_GROUNDS" },
        { "E_MODEL_CCM_ROPEWAY_LIFT", "CCM" },
        { "E_MODEL_DDD_BOWSER_SUB_DOOR", "DDD" },
        { "E_MODEL_BBH_TILTING_FLOOR_PLATFORM", "BBH" },
        { "E_MODEL_BITDW_SQUARE_PLATFORM", "BITDW" },
        { "E_MODEL_HMC_METAL_PLATFORM", "HMC" },
        { "E_MODEL_JRB_SHIP_BACK_LEFT_PART", "JRB" },
        { "E_MODEL_LLL_MOVING_OCTAGONAL_MESH_PLATFORM", "LLL" },
        { "E_MODEL_RR_SLIDING_PLATFORM", "RR" },
        { "E_MODEL_SL_SNOW_TRIANGLE", "SL" },
        { "E_MODEL_SSL_GRINDEL", "SSL" },
        { "E_MODEL_THI_HUGE_ISLAND_TOP", "THI" },
        { "E_MODEL_TTC_ROTATING_CUBE", "TTC" },
        { "E_MODEL_TTM_STAR_CAGE", "TTM" },
        { "E_MODEL_WDW_SQUARE_FLOATING_PLATFORM", "WDW" },
        { "E_MODEL_WF_BREAKABLE_WALL_RIGHT", "WF" },
        { false, "VCUTM" },
    },
    [0x37] = {
        { "E_MODEL_BITFS_TILTING_SQUARE_PLATFORM", "BITFS" },
        { "E_MODEL_BITS_TWIN_SLIDING_PLATFORMS", "BITS" },
        { "E_MODEL_BOB_SEESAW_PLATFORM", "BOB" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_2", "BOWSER_3" },
        { "E_MODEL_CASTLE_CLOCK_MINUTE_HAND", "CASTLE" },
        { "E_MODEL_CASTLE_GROUNDS_FLAG", "CASTLE_GROUNDS" },
        { "E_MODEL_CCM_SNOWMAN_HEAD", "CCM" },
        { "E_MODEL_DDD_BOWSER_SUB", "DDD" },
        { "E_MODEL_BBH_TUMBLING_PLATFORM", "BBH" },
        { "E_MODEL_BITDW_SEESAW_PLATFORM", "BITDW" },
        { "E_MODEL_HMC_METAL_ARROW_PLATFORM", "HMC" },
        { "E_MODEL_JRB_SHIP_RIGHT_HALF_PART", "JRB" },
        { "E_MODEL_LLL_SINKING_ROCK_BLOCK", "LLL" },
        { "E_MODEL_RR_FLYING_CARPET", "RR" },
        { "E_MODEL_SL_CRACKED_ICE", "SL" },
        { "E_MODEL_SSL_SPINDEL", "SSL" },
        { "E_MODEL_THI_TINY_ISLAND_TOP", "THI" },
        { "E_MODEL_TTC_ROTATING_PRISM", "TTC" },
        { "E_MODEL_TTM_BLUE_SMILEY", "TTM" },
        { "E_MODEL_WDW_ARROW_LIFT", "WDW" },
        { "E_MODEL_WF_BREAKABLE_WALL_LEFT", "WF" },
    },
    [0x38] = {
        { "E_MODEL_BITFS_SINKING_PLATFORMS", "BITFS" },
        { "E_MODEL_BOB_BARS_GRILLS", "BOB" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_3", "BOWSER_3" },
        { "E_MODEL_CASTLE_CLOCK_HOUR_HAND", "CASTLE" },
        { "E_MODEL_CASTLE_GROUNDS_CANNON_GRILL", "CASTLE_GROUNDS" },
        { "E_MODEL_DDD_POLE", "DDD" },
        { "E_MODEL_BBH_TUMBLING_PLATFORM_PART", "BBH" },
        { "E_MODEL_BITDW_SLIDING_PLATFORM", "BITDW" },
        { "E_MODEL_HMC_ELEVATOR_PLATFORM", "HMC" },
        { "E_MODEL_JRB_SHIP_BACK_RIGHT_PART", "JRB" },
        { "E_MODEL_LLL_DRAWBRIDGE_PART", "LLL" },
        { "E_MODEL_RR_OCTAGONAL_PLATFORM", "RR" },
        { "E_MODEL_SL_CRACKED_ICE_CHUNK", "SL" },
        { "E_MODEL_SSL_MOVING_PYRAMID_WALL", "SSL" },
        { "E_MODEL_TTC_PENDULUM", "TTC" },
        { "E_MODEL_TTM_YELLOW_SMILEY", "TTM" },
        { "E_MODEL_WDW_WATER_LEVEL_DIAMOND", "WDW" },
        { "E_MODEL_WF_KICKABLE_BOARD", "WF" },
    },
    [0x39] = {
        { "E_MODEL_BITFS_BLUE_POLE", "BITFS" },
        { "E_MODEL_BITS_OCTAGONAL_PLATFORM", "BITS" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_4", "BOWSER_3" },
        { "E_MODEL_CASTLE_CLOCK_PENDULUM", "CASTLE" },
        { "E_MODEL_BBH_MOVING_BOOKSHELF", "BBH" },
        { "E_MODEL_BITDW_FERRIS_WHEEL_AXLE", "BITDW" },
        { "E_MODEL_HMC_ROLLING_ROCK", "HMC" },
        { "E_MODEL_JRB_SUNKEN_SHIP", "JRB" },
        { "E_MODEL_LLL_ROLLING_LOG", "LLL" },
        { "E_MODEL_RR_ROTATING_BRIDGE_PLATFORM", "RR" },
        { "E_MODEL_SSL_PYRAMID_ELEVATOR", "SSL" },
        { "E_MODEL_TTC_LARGE_TREADMILL", "TTC" },
        { "E_MODEL_TTM_STAR_SMILEY", "TTM" },
        { "E_MODEL_WDW_HIDDEN_PLATFORM", "WDW" },
        { "E_MODEL_WF_TOWER_DOOR", "WF" },
    },
    [0x3A] = {
        { "E_MODEL_BITFS_SINKING_CAGE_PLATFORM", "BITFS" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_5", "BOWSER_3" },
        { "E_MODEL_BBH_MESH_ELEVATOR", "BBH" },
        { "E_MODEL_BITDW_BLUE_PLATFORM", "BITDW" },
        { "E_MODEL_HMC_ROCK_PIECE", "HMC" },
        { "E_MODEL_JRB_SUNKEN_SHIP_BACK", "JRB" },
        { "E_MODEL_LLL_ROTATING_BLOCK_FIRE_BARS", "LLL" },
        { "E_MODEL_RR_TRIANGLE_PLATFORM", "RR" },
        { "E_MODEL_SSL_PYRAMID_TOP", "SSL" },
        { "E_MODEL_TTC_SMALL_TREADMILL", "TTC" },
        { "E_MODEL_TTM_MOON_SMILEY", "TTM" },
        { "E_MODEL_WDW_EXPRESS_ELEVATOR", "WDW" },
        { "E_MODEL_WF_KICKABLE_BOARD_FELLED", "WF" },
    },
    [0x3B] = {
        { "E_MODEL_BITFS_ELEVATOR", "BITFS" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_6", "BOWSER_3" },
        { "E_MODEL_BBH_MERRY_GO_ROUND", "BBH" },
        { "E_MODEL_BITDW_STAIRCASE_FRAME4", "BITDW" },
        { "E_MODEL_HMC_ROCK_SMALL_PIECE", "HMC" },
        { "E_MODEL_JRB_ROCK", "JRB" },
        { "E_MODEL_LLL_LARGE_WOOD_BRIDGE", "LLL" },
        { "E_MODEL_RR_CRUISER_WING", "RR" },
        { "E_MODEL_TTC_PUSH_BLOCK", "TTC" },
        { "E_MODEL_WDW_RECTANGULAR_FLOATING_PLATFORM", "WDW" },
    },
    [0x3C] = {
        { "E_MODEL_BITFS_STRETCHING_PLATFORMS", "BITFS" },
        { "E_MODEL_BITS_BLUE_PLATFORM", "BITS" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_7", "BOWSER_3" },
        { "E_MODEL_BBH_WOODEN_TOMB", "BBH" },
        { "E_MODEL_BITDW_STAIRCASE_FRAME3", "BITDW" },
        { "E_MODEL_HMC_RED_GRILLS", "HMC" },
        { "E_MODEL_JRB_SLIDING_BOX", "JRB" },
        { "E_MODEL_LLL_FALLING_PLATFORM", "LLL" },
        { "E_MODEL_RR_SEESAW_PLATFORM", "RR" },
        { "E_MODEL_TTC_ROTATING_HEXAGON", "TTC" },
        { "E_MODEL_WDW_ROTATING_PLATFORM", "WDW" },
    },
    [0x3D] = {
        { "E_MODEL_BITFS_SEESAW_PLATFORM", "BITFS" },
        { "E_MODEL_BITS_FERRIS_WHEEL_AXLE", "BITS" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_8", "BOWSER_3" },
        { "E_MODEL_BITDW_STAIRCASE_FRAME2", "BITDW" },
        { "E_MODEL_JRB_FALLING_PILLAR", "JRB" },
        { "E_MODEL_LLL_LARGE_FALLING_PLATFORM", "LLL" },
        { "E_MODEL_RR_L_SHAPED_PLATFORM", "RR" },
        { "E_MODEL_TTC_ROTATING_TRIANGLE", "TTC" },
    },
    [0x3E] = {
        { "E_MODEL_BITFS_MOVING_SQUARE_PLATFORM", "BITFS" },
        { "E_MODEL_BITS_ARROW_PLATFORM", "BITS" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_9", "BOWSER_3" },
        { "E_MODEL_BITDW_STAIRCASE_FRAME1", "BITDW" },
        { "E_MODEL_JRB_FALLING_PILLAR_BASE", "JRB" },
        { "E_MODEL_LLL_ROTATING_HEXAGONAL_RING", "LLL" },
        { "E_MODEL_RR_SWINGING_PLATFORM", "RR" },
        { "E_MODEL_TTC_PIT_BLOCK", "TTC" },
    },
    [0x3F] = {
        { "E_MODEL_BITFS_SLIDING_PLATFORM", "BITFS" },
        { "E_MODEL_BITS_SEESAW_PLATFORM", "BITS" },
        { "E_MODEL_BOWSER_3_FALLING_PLATFORM_10", "BOWSER_3" },
        { "E_MODEL_BITDW_STAIRCASE", "BITDW" },
        { "E_MODEL_JRB_FLOATING_PLATFORM", "JRB" },
        { "E_MODEL_LLL_SINKING_RECTANGULAR_PLATFORM", "LLL" },
        { "E_MODEL_RR_DONUT_PLATFORM", "RR" },
        { "E_MODEL_TTC_PIT_BLOCK_UNUSED", "TTC" },
    },
    [0x40] = {
        { "E_MODEL_BITFS_TUMBLING_PLATFORM_PART", "BITFS" },
        { "E_MODEL_BITS_TILTING_W_PLATFORM", "BITS" },
        { "E_MODEL_LLL_SINKING_SQUARE_PLATFORMS", "LLL" },
        { "E_MODEL_RR_ELEVATOR_PLATFORM", "RR" },
        { "E_MODEL_TTC_ELEVATOR_PLATFORM", "TTC" },
    },
    [0x41] = {
        { "E_MODEL_BITFS_TUMBLING_PLATFORM", "BITFS" },
        { "E_MODEL_BITS_STAIRCASE", "BITS" },
        { "E_MODEL_LLL_TILTING_SQUARE_PLATFORM", "LLL" },
        { "E_MODEL_RR_TRICKY_TRIANGLES", "RR" },
        { "E_MODEL_TTC_CLOCK_HAND", "TTC" },
    },
    [0x42] = {
        { "E_MODEL_BITS_STAIRCASE_FRAME1", "BITS" },
        { "E_MODEL_RR_TRICKY_TRIANGLES_FRAME1", "RR" },
        { "E_MODEL_TTC_SPINNER", "TTC" },
    },
    [0x43] = {
        { "E_MODEL_BITS_STAIRCASE_FRAME2", "BITS" },
        { "E_MODEL_LLL_BOWSER_PIECE_1", "LLL" },
        { "E_MODEL_RR_TRICKY_TRIANGLES_FRAME2", "RR" },
        { "E_MODEL_TTC_SMALL_GEAR", "TTC" },
    },
    [0x44] = {
        { "E_MODEL_BITS_STAIRCASE_FRAME3", "BITS" },
        { "E_MODEL_LLL_BOWSER_PIECE_2", "LLL" },
        { "E_MODEL_RR_TRICKY_TRIANGLES_FRAME3", "RR" },
        { "E_MODEL_TTC_LARGE_GEAR", "TTC" },
    },
    [0x45] = {
        { "E_MODEL_BITS_STAIRCASE_FRAME4", "BITS" },
        { "E_MODEL_LLL_BOWSER_PIECE_3", "LLL" },
        { "E_MODEL_RR_TRICKY_TRIANGLES_FRAME4", "RR" },
    },
    [0x49] = {
        { "E_MODEL_LLL_BOWSER_PIECE_7", "LLL" },
        { "E_MODEL_BITS_WARP_PIPE", "BITS" },
    },
    [0x54] = {
        { "E_MODEL_BIRDS", "CASTLE_GROUNDS" },
        { "E_MODEL_BLARGG", "BITFS LLL WMOTR" },
        { "E_MODEL_BOO", "BBH CASTLE_COURTYARD" },
        { "E_MODEL_BULLET_BILL", "TTC WDW WF" },
        { "E_MODEL_ENEMY_LAKITU", "BITDW RR THI" },
        { "E_MODEL_MANTA_RAY", "DDD JRB SA" },
        { "E_MODEL_POKEY_HEAD", "SSL" },
        { "E_MODEL_SPINDRIFT", "CCM SL" },
        { "E_MODEL_WATER_BOMB", "BOB" },
        { false, "COTMC HMC PSS TOTWC TTM VCUTM" },
    },
    [0x55] = {
        { "E_MODEL_CAP_SWITCH", "COTMC PSS TOTWC VCUTM" },
        { "E_MODEL_MONTY_MOLE", "HMC TTM" },
        { "E_MODEL_MR_BLIZZARD_HIDDEN", "CCM SL" },
        { "E_MODEL_POKEY_BODY_PART", "SSL" },
        { "E_MODEL_BETA_BOO_KEY", "BBH CASTLE_COURTYARD" },
        { "E_MODEL_SPINY_BALL", "BITDW RR THI" },
        { "E_MODEL_UNAGI", "DDD JRB SA" },
        { "E_MODEL_WATER_BOMB_SHADOW", "BOB" },
        { "E_MODEL_YELLOW_SPHERE", "TTC WDW WF" },
        { "E_MODEL_YOSHI", "CASTLE_GROUNDS" },
    },
    [0x56] = {
        { "E_MODEL_BULLY", "BITFS LLL WMOTR" },
        { "E_MODEL_HAUNTED_CHAIR", "BBH CASTLE_COURTYARD" },
        { "E_MODEL_HOOT", "TTC WDW WF" },
        { "E_MODEL_KING_BOBOMB", "BOB" },
        { "E_MODEL_MR_BLIZZARD", "CCM SL" },
        { "E_MODEL_SPINY", "BITDW RR THI" },
        { "E_MODEL_SUSHI", "DDD JRB SA" },
        { "E_MODEL_TWEESTER", "SSL" },
        { "E_MODEL_UKIKI", "HMC TTM" },
        { false, "COTMC PSS TOTWC VCUTM" },
    },
    [0x57] = {
        { "E_MODEL_BULLY_BOSS", "BITFS LLL WMOTR" },
        { "E_MODEL_FWOOSH", "HMC TTM" },
        { "E_MODEL_KLEPTO", "SSL" },
        { "E_MODEL_MAD_PIANO", "BBH CASTLE_COURTYARD" },
        { "E_MODEL_PENGUIN", "CCM SL" },
        { "E_MODEL_WIGGLER_HEAD", "BITDW RR THI" },
        { "E_MODEL_YOSHI_EGG", "TTC WDW WF" },
        { false, "DDD JRB SA" },
    },
    [0x58] = {
        { "E_MODEL_BOOKEND_PART", "BBH CASTLE_COURTYARD" },
        { "E_MODEL_CLAM_SHELL", "DDD JRB SA" },
        { "E_MODEL_EYEROK_LEFT_HAND", "SSL" },
        { "E_MODEL_THWOMP", "TTC WDW WF" },
        { "E_MODEL_WIGGLER_BODY", "BITDW RR THI" },
    },
    [0x59] = {
        { "E_MODEL_BOOKEND", "BBH CASTLE_COURTYARD" },
        { "E_MODEL_BUBBA", "BITDW RR THI" },
        { "E_MODEL_EYEROK_RIGHT_HAND", "SSL" },
        { "E_MODEL_HEAVE_HO", "TTC WDW WF" },
    },
    [0x64] = {
        { "E_MODEL_BOWSER", "BOWSER_1 BOWSER_2 BOWSER_3" },
        { "E_MODEL_BUB", "DDD JRB SA WDW" },
        { "E_MODEL_CHILL_BULLY", "CCM SL" },
        { "E_MODEL_MIPS", "CASTLE CASTLE_GROUNDS" },
        { "E_MODEL_PIRANHA_PLANT", "BITS BOB THI WF" },
        { "E_MODEL_SWOOP", "BBH BITDW BITFS COTMC HMC LLL WMOTR" },
    },
    [0x65] = {
        { "E_MODEL_BOO_CASTLE", "CASTLE CASTLE_GROUNDS" },
        { "E_MODEL_BOWSER_BOMB_CHILD_OBJ E_MODEL_BOWSER_BOMB", "BOWSER_1 BOWSER_2 BOWSER_3" },
        { "E_MODEL_BIG_CHILL_BULLY", "CCM SL" },
        { "E_MODEL_METALLIC_BALL", "BITS BOB THI WF" },
        { "E_MODEL_SCUTTLEBUG", "BBH BITDW BITFS COTMC HMC LLL WMOTR" },
        { "E_MODEL_TREASURE_CHEST_BASE", "DDD JRB SA WDW" },
    },
    [0x66] = {
        { "E_MODEL_BOWSER_SMOKE", "BOWSER_1 BOWSER_2 BOWSER_3" },
        { "E_MODEL_CHAIN_CHOMP", "BITS BOB THI WF" },
        { "E_MODEL_LAKITU", "CASTLE CASTLE_GROUNDS" },
        { "E_MODEL_MONEYBAG", "CCM SL" },
        { "E_MODEL_MR_I_IRIS", "BBH BITDW BITFS COTMC HMC LLL WMOTR" },
        { "E_MODEL_TREASURE_CHEST_LID", "DDD JRB SA WDW" },
    },
    [0x67] = {
        { "E_MODEL_BOWSER_FLAMES", "BOWSER_1 BOWSER_2 BOWSER_3" },
        { "E_MODEL_CYAN_FISH", "DDD JRB SA WDW" },
        { "E_MODEL_MR_I", "BBH BITDW BITFS COTMC HMC LLL WMOTR" },
        { "E_MODEL_WHOMP", "BITS BOB THI WF" },
    },
    [0x68] = {
        { "E_MODEL_DORRIE", "BBH BITDW BITFS COTMC HMC LLL WMOTR" },
        { "E_MODEL_BOWSER_WAVE", "BOWSER_1 BOWSER_2 BOWSER_3" },
        { "E_MODEL_KOOPA_WITH_SHELL", "BITS BOB THI WF" },
        { "E_MODEL_WATER_RING", "DDD JRB SA WDW" },
    },
    [0x69] = {
        { "E_MODEL_BOWSER2", "BOWSER_1 BOWSER_2 BOWSER_3" },
        { "E_MODEL_SKEETER", "DDD JRB SA WDW" },
    },
    [0xB3] = {
        { "E_MODEL_BOWSER_BOMB_CHILD_OBJ E_MODEL_BOWSER_BOMB", "BOWSER_1 BOWSER_2 BOWSER_3" },
        { "E_MODEL_WATER_MINE", "DDD JRB SA WDW" },
    },
}

local MODEL, HOLDS, KNOWN = {}, {}, {}
slots.MODEL, slots.HOLDS, slots.KNOWN_LEVELS = MODEL, HOLDS, KNOWN

local function words(text)
    local out = {}
    for word in string.gmatch(text or "", "%S+") do out[#out + 1] = word end
    return out
end

function slots.build()
    for k in pairs(MODEL) do MODEL[k] = nil end
    for k in pairs(HOLDS) do HOLDS[k] = nil end
    for k in pairs(KNOWN) do KNOWN[k] = nil end
    for _, name in ipairs(words(slots.KNOWN)) do
        local level = _G["LEVEL_" .. name]
        if type(level) == "number" then
            KNOWN[level] = true
            HOLDS[level] = HOLDS[level] or {}
        end
    end
    for id, rows in pairs(slots.TABLE or {}) do
        for _, row in ipairs(rows) do
            local key = false
            if row[1] then
                local names = words(row[1])
                key = names[1]
                for _, name in ipairs(names) do
                    local e = _G[name]
                    if type(e) == "number" then
                        MODEL[e] = MODEL[e] or { key = key, at = {} }
                        MODEL[e].at[id] = true
                    end
                end
            end
            for _, name in ipairs(words(row[2])) do
                local level = _G["LEVEL_" .. name]
                if type(level) == "number" and HOLDS[level] ~= nil then
                    HOLDS[level][id] = key
                end
            end
        end
    end
end

slots.build()

function slots.risky(e)
    return MODEL[e] ~= nil
end

function slots.level()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    return np ~= nil and np.currLevelNum or nil
end

local function known(level)
    if level == nil or not KNOWN[level] then return false end
    if type(level_is_vanilla_level) == "function" then
        local ok, vanilla = pcall(level_is_vanilla_level, level)
        if ok and vanilla == false then return false end
    end
    return true
end
slots.known = known

function slots.held(id, level)
    level = level or slots.level()
    if not known(level) then return nil end
    return HOLDS[level][id]
end

local function level_has(info, level)
    if not known(level) then return false end
    local here = HOLDS[level]
    for id in pairs(info.at) do
        if here[id] == info.key then return true end
    end
    return false
end

function slots.room_ready()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return false end
    if np.currAreaSyncValid == false or np.currLevelSyncValid == false then return false end
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    return m ~= nil and m.area ~= nil
end

slots.copy = {}

local notFreeHere = {}

function slots.free(e)
    if type(spawn_non_sync_object) ~= "function" or type(obj_has_model_extended) ~= "function" then
        return nil
    end
    local probe = spawn_non_sync_object(id_bhvStaticObject, E_MODEL_ERROR_MODEL, 0, -30000, 0, nil)
    if probe == nil then return nil end
    local answer = obj_has_model_extended(probe, e) ~= 0
    obj_mark_for_deletion(probe)
    return answer
end

function slots.safe(e)
    local info = MODEL[e]
    if info == nil then return true, "no level puts another model at its id" end
    if not slots.room_ready() then return false, "the lobby is not synchronised" end
    local state = slots.copy[info.key]
    if state == "good" then return true, "its own copy" end
    local level = slots.level()
    if level_has(info, level) then return true, "this level loads it" end
    if type(state) == "number" then
        if known(level) and HOLDS[level][state] == nil then
            return true, "filed under a slot this level leaves empty"
        end
        return false, "filed under a slot this level fills"
    end
    if notFreeHere[info.key] then return false, "its slot is not free" end
    if slots.free(e) == true then return true, "its slot is free" end
    notFreeHere[info.key] = true
    return false, "its slot is not free"
end

function slots.would_misfile(e)
    local info = MODEL[e]
    if info == nil then return false end
    if not slots.room_ready() then return false end
    if slots.copy[info.key] ~= nil then return false end
    if level_has(info, slots.level()) then return false end
    if notFreeHere[info.key] then return true end
    if slots.free(e) == false then
        notFreeHere[info.key] = true
        return true
    end
    return false
end

local pending, seenRaw = nil, nil

local function settle(e, raw)
    local info = MODEL[e]
    if info == nil or type(raw) ~= "number" then return true end
    if raw > slots.VANILLA_END then
        slots.copy[info.key] = "good"
        return true
    end
    local level = slots.level()
    if not known(level) then
        if slots.copy[info.key] ~= "good" then slots.copy[info.key] = raw end
        return true
    end
    local here = HOLDS[level][raw]
    if here == info.key then return true end
    if slots.copy[info.key] ~= "good" then slots.copy[info.key] = raw end
    return here == nil
end

local function spawn_read(binding, bhv, e, x, y, z, fn)
    local outer, outerRaw = pending, seenRaw
    pending, seenRaw = e, nil
    local o = OF.util.optional(binding, nil, bhv, e, x, y, z, fn)
    local raw = seenRaw
    pending, seenRaw = outer, outerRaw
    if o ~= nil then settle(e, raw) end
    return o
end

local function guarded(binding, bhv, e, x, y, z, fn, must)

    if MODEL[e] == nil then return OF.util.optional(binding, nil, bhv, e, x, y, z, fn) end
    if not slots.safe(e) then slots.forced = (slots.forced or 0) + 1 end
    return spawn_read(binding, bhv, e, x, y, z, fn)
end

function slots.spawn_sync(bhv, e, x, y, z, fn, must)
    return guarded("spawn_sync_object", bhv, e, x, y, z, fn, must)
end

function slots.spawn_lobby(bhv, e, x, y, z, fn, must, always)
    if OF.util.asks(OF.roundscope, "lobby_setup") then
        fn = OF.roundscope.lobby_setup(fn, always)
    end
    return slots.spawn_sync(bhv, e, x, y, z, fn, must)
end

slots.POOL_HEADROOM = 60
slots.poolSeen, slots.poolSeenAt = 0, nil
slots.refusedFull = 0

function slots.pool_full()
    if not OF.util.asks(OF.spawner, "pool_count") then return false end
    local now = get_global_timer ~= nil and get_global_timer() or 0
    if slots.poolSeenAt == nil or now < slots.poolSeenAt or now - slots.poolSeenAt >= 30 then
        slots.poolSeen = OF.spawner.pool_count() or 0
        slots.poolSeenAt = now
    end
    return slots.poolSeen >= (OF.spawner.POOL_CAPACITY or 1200) - slots.POOL_HEADROOM
end

function slots.spawn_non_sync(bhv, e, x, y, z, fn, must)
    if slots.pool_full() then
        slots.refusedFull = slots.refusedFull + 1
        return nil
    end
    local o = guarded("spawn_non_sync_object", bhv, e, x, y, z, fn, must)
    if o ~= nil then slots.poolSeen = slots.poolSeen + 1 end
    return o
end

function slots.set_model(o, e)
    if o == nil then return false end

    if MODEL[e] == nil then
        OF.util.optional("obj_set_model_extended", nil, o, e)
        return true
    end
    if not slots.safe(e) then slots.forced = (slots.forced or 0) + 1 end
    local outer, outerRaw = pending, seenRaw
    pending, seenRaw = e, nil
    OF.util.optional("obj_set_model_extended", nil, o, e)
    local raw = seenRaw
    pending, seenRaw = outer, outerRaw
    settle(e, raw)
    return true
end

local function on_set_model(o, raw, ext)
    if pending ~= nil then
        if seenRaw == nil then seenRaw = raw end
        return
    end
    if type(raw) ~= "number" or raw > slots.VANILLA_END then return end
    local info = ext ~= nil and MODEL[ext] or nil
    if info == nil or slots.copy[info.key] == "good" then return end
    local level = slots.level()
    if known(level) and HOLDS[level][raw] == info.key then return end
    slots.copy[info.key] = raw
end
slots.on_set_model = on_set_model

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}

function slots.needs()
    local out, seen = {}, {}
    local function add(e)
        if type(e) == "number" and MODEL[e] ~= nil and not seen[e] then
            seen[e] = true
            out[#out + 1] = e
        end
    end
    local function row(value)
        if type(value) == "number" then
            add(value)
        elseif type(value) == "table" then
            add(value.model)
            if type(value.variants) == "table" then
                for _, variant in pairs(value.variants) do
                    if type(variant) == "table" then add(variant.model) end
                end
            end
        end
    end
    for _, provider in ipairs(OF.SLOT_NEEDS) do
        local list = provider
        if type(provider) == "function" then
            local ok, result = pcall(provider)
            list = ok and result or nil
        end
        if type(list) == "number" then
            add(list)
        elseif type(list) == "table" then
            for _, value in pairs(list) do row(value) end
        end
    end
    table.sort(out)
    return out
end

slots.warmPending = true
local queue, queueAt = nil, 0

function slots.warm_step()
    if queue == nil then
        queue, queueAt = {}, 1
        local level = slots.level()
        for _, e in ipairs(slots.needs()) do
            local info = MODEL[e]
            if slots.copy[info.key] ~= "good" and not level_has(info, level) then
                queue[#queue + 1] = e
            end
        end
    end

    local made, asked = 0, 0
    while queueAt <= #queue and asked < slots.WARM_PER_FRAME do
        local e = queue[queueAt]
        queueAt = queueAt + 1
        asked = asked + 1

        if slots.safe(e) then
            local o = spawn_read("spawn_non_sync_object", id_bhvStaticObject, e, 0, -30000, 0, nil)
            if o ~= nil then
                obj_mark_for_deletion(o)
                made = made + 1
            end
        end
    end
    if queueAt > #queue then
        queue = nil
        slots.warmPending = false
    end
    return made
end

local function new_room()
    for k in pairs(notFreeHere) do notFreeHere[k] = nil end
    queue = nil
    slots.warmPending = true
end
slots.new_room = new_room

function slots.forget()
    for k in pairs(slots.copy) do slots.copy[k] = nil end
    new_room()
end

hook_event(HOOK_OBJECT_SET_MODEL, on_set_model)
hook_event(HOOK_ON_LEVEL_INIT, new_room)
hook_event(HOOK_ON_SYNC_VALID, new_room)
hook_event(HOOK_UPDATE, function()
    if slots.warmPending and slots.room_ready() then slots.warm_step() end
end)

function slots.ready()
    return next(MODEL) ~= nil
end
