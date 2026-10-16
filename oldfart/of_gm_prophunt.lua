OF = OF or {}

local ROLE_SEEKER = "a seeker"
local ROLE_HIDER = "a hider"
local WRONG_HOLD = 3 * 30

local HOLD_STILL = 6

local FURNITURE = {
    "crate", "cratesmall", "metalbox", "exbox", "boxoutline",
    "signpost", "post",
    "tree", "snowtree", "palmtree", "spikytree",
    "shell", "yoshiegg", "clam", "seaweed", "coinswitch",
}

local LEVEL_KEY = "ofPhProps"
local LEVEL_CHARS = 250

local PROP_MODELS = {
    "E_MODEL_BREAKABLE_BOX", "E_MODEL_BREAKABLE_BOX_SMALL", "E_MODEL_METAL_BOX",
    "E_MODEL_EXCLAMATION_BOX", "E_MODEL_EXCLAMATION_BOX_OUTLINE",
    "E_MODEL_WOODEN_SIGNPOST", "E_MODEL_WOODEN_POST",
    "E_MODEL_BUBBLY_TREE", "E_MODEL_COURTYARD_SPIKY_TREE", "E_MODEL_SNOW_TREE",
    "E_MODEL_PALM_TREE",
    "E_MODEL_KOOPA_SHELL", "E_MODEL_YOSHI_EGG", "E_MODEL_CLAM_SHELL",
    "E_MODEL_SEAWEED", "E_MODEL_WATER_MINE",
    "E_MODEL_BLUE_COIN_SWITCH", "E_MODEL_PURPLE_SWITCH",
    "E_MODEL_STAR", "E_MODEL_1UP", "E_MODEL_HEART",
    "E_MODEL_YELLOW_COIN", "E_MODEL_YELLOW_COIN_NO_SHADOW",
    "E_MODEL_RED_COIN", "E_MODEL_RED_COIN_NO_SHADOW",
    "E_MODEL_BLUE_COIN", "E_MODEL_BLUE_COIN_NO_SHADOW",

    "E_MODEL_CAP_SWITCH", "E_MODEL_CANNON_BASE", "E_MODEL_BBH_WOODEN_TOMB",
    "E_MODEL_BOOKEND", "E_MODEL_HAUNTED_CHAIR", "E_MODEL_MAD_PIANO",
    "E_MODEL_JRB_ROCK", "E_MODEL_HMC_ROCK_PIECE", "E_MODEL_BOWSER_BOMB",
    "E_MODEL_BOWLING_BALL", "E_MODEL_CASTLE_WATER_LEVEL_PILLAR",
    "E_MODEL_TTC_PUSH_BLOCK", "E_MODEL_SSL_TOX_BOX", "E_MODEL_TOADS_CAP",

    "E_MODEL_GOOMBA", "E_MODEL_BLACK_BOBOMB", "E_MODEL_BOBOMB_BUDDY",
    "E_MODEL_KOOPA_WITH_SHELL", "E_MODEL_CHAIN_CHOMP", "E_MODEL_PIRANHA_PLANT",
    "E_MODEL_SPINDRIFT", "E_MODEL_PENGUIN", "E_MODEL_SCUTTLEBUG", "E_MODEL_BULLY",
    "E_MODEL_CHUCKYA", "E_MODEL_SKEETER", "E_MODEL_MONTY_MOLE", "E_MODEL_FLYGUY",
    "E_MODEL_AMP", "E_MODEL_SWOOP", "E_MODEL_MONEYBAG", "E_MODEL_HEAVE_HO",
    "E_MODEL_KLEPTO", "E_MODEL_MR_BLIZZARD", "E_MODEL_BOO", "E_MODEL_SNUFIT",
    "E_MODEL_TOAD", "E_MODEL_MIPS", "E_MODEL_UKIKI",
}

local propModels = nil
local function is_prop_model(model)
    if type(model) ~= "number" or model <= 0 then return false end
    if model == E_MODEL_ERROR_MODEL then return false end
    if propModels == nil then
        propModels = {}
        for _, name in ipairs(PROP_MODELS) do
            local id = _G[name]
            if type(id) == "number" and id ~= E_MODEL_ERROR_MODEL then
                propModels[id] = true
            end
        end
    end
    return propModels[model] == true
end

function OF.gm_prophunt_prop_model(model)
    return is_prop_model(model)
end

local SOLID_FURNITURE = {
    "id_bhvBreakableBox", "id_bhvBreakableBoxSmall", "id_bhvExclamationBox",
    "id_bhvJumpingBox", "id_bhvPushableMetalBox", "id_bhvMessagePanel",
    "id_bhvWoodenPost", "id_bhvBlueCoinSwitch", "id_bhvCapSwitch",
    "id_bhvFloorSwitchHardcodedModel", "id_bhvFloorSwitchAnimatesObject",
    "id_bhvFloorSwitchGrills", "id_bhvFloorSwitchHiddenObjects",
}

local STAR_LIFT = 100

local STAR_SPIN = 0x800

local PIECE_SMALLEST, PIECE_BIGGEST = 0.1, 4.0
local PIECE_HIGHEST = 1200

local LIFT_STEP = 50
local LIFT_KEY = "ofPhLift"
local usable = nil

local function all_props()
    if usable ~= nil then return usable end
    usable = {}
    local possess = OF.possess
    if possess == nil or possess.catalogue == nil then return usable end
    local costumes = possess.catalogue()
    if costumes == nil then

        usable = nil
        return {}
    end
    for _, key in ipairs(FURNITURE) do
        if costumes.BY_KEY[key] ~= nil then table.insert(usable, key) end
    end
    return usable
end

local levelSaid, levelList = nil, nil
local levelPieces = {}

local LIFT_AT_LEAST = { E_MODEL_1UP = 32, E_MODEL_HEART = 40 }
local function least_lift(model)
    for name, lift in pairs(LIFT_AT_LEAST) do
        if _G[name] ~= nil and _G[name] == model then return lift end
    end
    return 0
end
OF.gm_prophunt_least_lift = least_lift

local function parse_pieces(said)
    local pieces = {}
    for part in string.gmatch(said or "", "[^;]+") do
        local model, size, lift, turns = part:match("^(%d+),(%d+),(%d+),(%d)$")

        if model ~= nil and is_prop_model(tonumber(model)) then
            local size100 = tonumber(size) / 100
            pieces[#pieces + 1] = { model = tonumber(model),
                size = size100,
                lift = math.max(tonumber(lift), least_lift(tonumber(model)) * size100),
                turns = turns == "1" }
        end
    end
    return pieces
end

local function prop_list()
    local all = all_props()
    local said = gGlobalSyncTable[LEVEL_KEY]
    if type(said) ~= "string" or said == "" then
        levelPieces = {}
        return all
    end
    if said == levelSaid and levelList ~= nil then return levelList end
    levelPieces = parse_pieces(said)
    local list = {}
    for i = 1, #levelPieces do list[i] = "lv" .. i end
    if #list == 0 then list = all end
    levelSaid, levelList = said, list
    return list
end

local function piece_of(key)
    if type(key) ~= "string" then return nil end
    local n = tonumber(key:match("^lv(%d+)$"))
    if n == nil then return nil end
    prop_list()
    return levelPieces[n]
end

local SCENERY_LISTS = {}
local function scenery_list(list)
    if list ~= nil then SCENERY_LISTS[#SCENERY_LISTS + 1] = list end
end
scenery_list(OBJ_LIST_DESTRUCTIVE)
scenery_list(OBJ_LIST_GENACTOR)
scenery_list(OBJ_LIST_PUSHABLE)
scenery_list(OBJ_LIST_LEVEL)
scenery_list(OBJ_LIST_DEFAULT)
scenery_list(OBJ_LIST_SURFACE)
scenery_list(OBJ_LIST_POLELIKE)
scenery_list(OBJ_LIST_UNIMPORTANT)

local function solid_furniture(o)
    for _, name in ipairs(SOLID_FURNITURE) do
        local id = _G[name]
        if type(id) == "number" then
            local yes = OF.util.optional("obj_has_behavior_id", 0, o, id)
            if yes ~= nil and yes ~= 0 and yes ~= false then return true end
        end
    end
    return false
end

local function still_and_seen(o)
    local gfx = o.header ~= nil and o.header.gfx or nil
    if gfx == nil then return false end
    if OF.util.has_flag(gfx.node ~= nil and gfx.node.flags or 0,
        GRAPH_RENDER_INVISIBLE or 0x10) then
        return false
    end
    local ok, anim = pcall(function() return gfx.animInfo.curAnim end)
    if ok and anim ~= nil then return false end
    return true
end

local PIECES = {
    coin      = { model = "E_MODEL_YELLOW_COIN", lift = 32, coin = true },
    redcoin   = { model = "E_MODEL_RED_COIN", lift = 32, coin = true },
    bluecoin  = { model = "E_MODEL_BLUE_COIN", lift = 32, coin = true },
    star      = { model = "E_MODEL_STAR", lift = STAR_LIFT, spin = true },
    oneup     = { model = "E_MODEL_1UP", lift = 32 },
    heart     = { model = "E_MODEL_HEART", lift = 40 },
    sign      = { model = "E_MODEL_WOODEN_SIGNPOST" },
    post      = { model = "E_MODEL_WOODEN_POST", size = 0.5 },
    exbox     = { model = "E_MODEL_EXCLAMATION_BOX", size = 2.0 },
    crate     = { model = "E_MODEL_BREAKABLE_BOX" },
    cratesmall = { model = "E_MODEL_BREAKABLE_BOX_SMALL", size = 0.4 },
    metalbox  = { model = "E_MODEL_METAL_BOX" },
    coinswitch = { model = "E_MODEL_BLUE_COIN_SWITCH", size = 3.0 },
    purpleswitch = { model = "E_MODEL_PURPLE_SWITCH" },
    capswitch = { model = "E_MODEL_CAP_SWITCH" },
    bubblytree = { model = "E_MODEL_BUBBLY_TREE", turns = true },
    snowtree  = { model = "E_MODEL_SNOW_TREE", turns = true },
    spikytree = { model = "E_MODEL_COURTYARD_SPIKY_TREE", turns = true },
    clam      = { model = "E_MODEL_CLAM_SHELL", anims = "clam_shell_seg5_anims_05001744", anim = 0 },
    seaweed   = { model = "E_MODEL_SEAWEED", anims = "seaweed_seg6_anims_0600A4D4", anim = 0 },
    goomba    = { model = "E_MODEL_GOOMBA", size = 1.5, anims = "goomba_seg8_anims_0801DA4C", anim = 0 },
    bobomb    = { model = "E_MODEL_BLACK_BOBOMB", anims = "bobomb_seg8_anims_0802396C", anim = 0 },
    buddy     = { model = "E_MODEL_BOBOMB_BUDDY", anims = "bobomb_seg8_anims_0802396C", anim = 0 },
    koopa     = { model = "E_MODEL_KOOPA_WITH_SHELL", size = 1.5, anims = "koopa_seg6_anims_06011364", anim = 9 },
    chomp     = { model = "E_MODEL_CHAIN_CHOMP", size = 2.0, anims = "chain_chomp_seg6_anims_06025178", anim = 0 },
    piranha   = { model = "E_MODEL_PIRANHA_PLANT", anims = "piranha_plant_seg6_anims_0601C31C", anim = 8 },
    spindrift = { model = "E_MODEL_SPINDRIFT", anims = "spindrift_seg5_anims_05002D68", anim = 0 },
    penguin   = { model = "E_MODEL_PENGUIN", anims = "penguin_seg5_anims_05008B74", anim = 0 },
    blizzard  = { model = "E_MODEL_MR_BLIZZARD", anims = "snowman_seg5_anims_0500D118", anim = 0 },
    scuttlebug = { model = "E_MODEL_SCUTTLEBUG", anims = "scuttlebug_seg6_anims_06015064", anim = 0 },
    bully     = { model = "E_MODEL_BULLY", anims = "bully_seg5_anims_0500470C", anim = 0 },
    chuckya   = { model = "E_MODEL_CHUCKYA", anims = "chuckya_seg8_anims_0800C070", anim = 5 },
    skeeter   = { model = "E_MODEL_SKEETER", anims = "skeeter_seg6_anims_06007DE0", anim = 0 },
    montymole = { model = "E_MODEL_MONTY_MOLE", size = 1.5, anims = "monty_mole_seg5_anims_05007248", anim = 3 },
    flyguy    = { model = "E_MODEL_FLYGUY", size = 1.5, anims = "flyguy_seg8_anims_08011A64", anim = 0 },
    amp       = { model = "E_MODEL_AMP", anims = "amp_seg8_anims_08004034", anim = 0, lift = 60 },
    swoop     = { model = "E_MODEL_SWOOP", anims = "swoop_seg6_anims_060070D0", anim = 0 },
    moneybag  = { model = "E_MODEL_MONEYBAG", anims = "moneybag_seg6_anims_06005E5C", anim = 0 },
    heaveho   = { model = "E_MODEL_HEAVE_HO", anims = "heave_ho_seg5_anims_0501534C", anim = 0 },
    klepto    = { model = "E_MODEL_KLEPTO", anims = "klepto_seg5_anims_05008CFC", anim = 0, lift = 200 },
    chair     = { model = "E_MODEL_HAUNTED_CHAIR", anims = "chair_seg5_anims_05005784", anim = 0 },
    piano     = { model = "E_MODEL_MAD_PIANO", anims = "mad_piano_seg5_anims_05009B14", anim = 0 },
    boo       = { model = "E_MODEL_BOO", lift = 60 },
    snufit    = { model = "E_MODEL_SNUFIT", lift = 60 },
    ukiki     = { model = "E_MODEL_UKIKI", anims = "ukiki_seg5_anims_05015784", anim = 0 },
    toad      = { model = "E_MODEL_TOAD", anims = "toad_seg6_anims_0600FB58", anim = 0 },
    mips      = { model = "E_MODEL_MIPS", anims = "mips_seg6_anims_06015634", anim = 0 },
}
OF.gm_prophunt_PIECES = PIECES

local COURSE_PIECES = {}
local function course(level, keys)
    if type(level) == "number" then COURSE_PIECES[level] = keys end
end
course(LEVEL_BOB, { "star", "goomba", "bobomb", "buddy", "koopa", "chomp", "sign", "post",
    "bubblytree", "exbox", "cratesmall", "crate", "coin", "redcoin", "oneup", "heart" })
course(LEVEL_WF, { "star", "piranha", "sign", "exbox", "cratesmall", "coinswitch",
    "coin", "redcoin", "bluecoin", "oneup" })
course(LEVEL_JRB, { "star", "clam", "seaweed", "sign", "exbox", "coinswitch", "coin",
    "redcoin", "bluecoin", "oneup" })
course(LEVEL_CCM, { "star", "spindrift", "penguin", "blizzard", "snowtree", "sign", "exbox",
    "coinswitch", "coin", "redcoin", "bluecoin", "oneup", "heart" })
course(LEVEL_BBH, { "star", "boo", "chair", "piano", "scuttlebug", "sign", "exbox", "crate",
    "coinswitch", "coin", "redcoin", "bluecoin", "oneup" })
course(LEVEL_HMC, { "star", "swoop", "scuttlebug", "montymole", "snufit", "sign", "exbox",
    "crate", "coinswitch", "purpleswitch", "coin", "redcoin", "bluecoin", "oneup", "heart" })
course(LEVEL_LLL, { "star", "bully", "sign", "exbox", "coin", "redcoin", "oneup", "heart" })
course(LEVEL_SSL, { "star", "goomba", "bobomb", "klepto", "flyguy", "amp", "sign", "exbox",
    "crate", "cratesmall", "coin", "redcoin", "bluecoin", "oneup", "heart" })
course(LEVEL_DDD, { "star", "clam", "seaweed", "sign", "exbox", "coinswitch", "coin",
    "redcoin", "bluecoin", "oneup" })
course(LEVEL_SL, { "star", "spindrift", "blizzard", "goomba", "moneybag", "flyguy", "amp",
    "penguin", "snowtree", "sign", "exbox", "coin", "redcoin", "oneup" })
course(LEVEL_WDW, { "star", "skeeter", "heaveho", "chuckya", "amp", "sign", "exbox", "crate",
    "metalbox", "coin", "redcoin", "bluecoin", "oneup" })
course(LEVEL_TTM, { "star", "bobomb", "goomba", "ukiki", "montymole", "chuckya", "flyguy",
    "sign", "exbox", "coin", "redcoin", "bluecoin", "oneup" })
course(LEVEL_THI, { "star", "goomba", "koopa", "piranha", "flyguy", "chuckya", "bubblytree",
    "sign", "post", "exbox", "coinswitch", "coin", "redcoin", "bluecoin", "oneup" })
course(LEVEL_TTC, { "star", "bobomb", "heaveho", "amp", "exbox", "coinswitch", "coin",
    "redcoin", "bluecoin", "oneup", "heart" })
course(LEVEL_RR, { "star", "bobomb", "amp", "exbox", "coin", "redcoin", "bluecoin", "oneup",
    "heart" })
course(LEVEL_CASTLE_GROUNDS, { "star", "bubblytree", "sign", "exbox", "coin", "oneup" })
course(LEVEL_CASTLE, { "star", "toad", "mips", "coin", "oneup" })
course(LEVEL_CASTLE_COURTYARD, { "star", "boo", "spikytree", "sign", "coin" })
course(LEVEL_BITDW, { "star", "goomba", "amp", "sign", "exbox", "purpleswitch", "coin",
    "redcoin", "oneup" })
course(LEVEL_BITFS, { "star", "bully", "bobomb", "amp", "exbox", "coin", "redcoin", "oneup",
    "heart" })
course(LEVEL_BITS, { "star", "goomba", "bobomb", "chuckya", "amp", "metalbox",
    "purpleswitch", "exbox", "coin", "redcoin", "oneup", "heart" })
course(LEVEL_PSS, { "star", "sign", "exbox", "coinswitch", "coin", "bluecoin", "oneup" })
course(LEVEL_SA, { "star", "redcoin", "oneup" })
course(LEVEL_WMOTR, { "star", "buddy", "exbox", "coin", "redcoin", "oneup" })
course(LEVEL_TOTWC, { "star", "exbox", "capswitch", "coin", "redcoin" })
course(LEVEL_COTMC, { "star", "snufit", "sign", "exbox", "capswitch", "coin", "redcoin", "oneup" })
course(LEVEL_VCUTM, { "star", "amp", "exbox", "capswitch", "coin", "redcoin", "oneup" })
OF.gm_prophunt_COURSE_PIECES = COURSE_PIECES

local pieceByModel = nil
local function piece_spec(model)
    if pieceByModel == nil then
        pieceByModel = {}
        for _, spec in pairs(PIECES) do
            local id = _G[spec.model]
            if type(id) == "number" and pieceByModel[id] == nil then pieceByModel[id] = spec end
        end
    end
    return model ~= nil and pieceByModel[model] or nil
end
OF.gm_prophunt_piece_spec = piece_spec

local function course_pieces(level)
    local keys = level ~= nil and COURSE_PIECES[level] or nil
    if keys == nil then return nil end
    local parts, used = {}, 0
    for _, key in ipairs(keys) do
        local spec = PIECES[key]
        local id = spec ~= nil and _G[spec.model] or nil
        if type(id) == "number" and is_prop_model(id) then
            local part = string.format("%.0f,%.0f,%.0f,%.0f", id,
                math.floor((spec.size or 1) * 100 + 0.5), spec.lift or 0, spec.turns and 1 or 0)
            if used + #part + 1 <= LEVEL_CHARS then
                parts[#parts + 1] = part
                used = used + #part + 1
            end
        end
    end
    return table.concat(parts, ";")
end
OF.gm_prophunt_course_pieces = course_pieces

local function level_pieces()
    if obj_get_first == nil or obj_get_next == nil then return nil end

    local worn = {}
    local props = OF.possess ~= nil and OF.possess.props or nil
    if type(props) == "table" then
        for _, prop in pairs(props) do worn[prop] = true end
    end
    local seen, parts, used = {}, {}, 0
    for _, list in ipairs(SCENERY_LISTS) do
        local o = obj_get_first(list)
        while o ~= nil do
            if o.activeFlags ~= 0 and not worn[o] and still_and_seen(o)
                and (o.collisionData == nil or solid_furniture(o)) then
                local model = OF.util.optional("obj_get_model_id_extended", nil, o)

                local spec = piece_spec(model)
                if is_prop_model(model) and not seen[model]
                    and not (spec ~= nil and spec.anims ~= nil) then
                    seen[model] = true
                    local scale = o.header.gfx.scale ~= nil and o.header.gfx.scale.y or 1
                    local x, y, z = o.oPosX or 0, o.oPosY or 0, o.oPosZ or 0
                    local floor = OF.util.optional("find_floor_height", nil, x, y + 80, z)
                    local lift = 0
                    if type(floor) == "number" and floor > -10000 then
                        lift = math.max(0, y - floor)
                    end
                    if scale >= PIECE_SMALLEST and scale <= PIECE_BIGGEST
                        and lift <= PIECE_HIGHEST then
                        local turns = OF.util.has_flag(o.header.gfx.node.flags or 0,
                            GRAPH_RENDER_BILLBOARD or 4)
                            or OF.util.has_flag(o.header.gfx.node.flags or 0,
                                GRAPH_RENDER_CYLBOARD or 0x40)
                        local part = string.format("%.0f,%.0f,%.0f,%.0f", model,
                            math.floor(scale * 100 + 0.5), math.floor(lift + 0.5),
                            turns and 1 or 0)
                        if used + #part + 1 <= LEVEL_CHARS then
                            parts[#parts + 1] = part
                            used = used + #part + 1
                        end
                    end
                end
            end
            o = obj_get_next(o)
        end
    end

    local star = E_MODEL_STAR
    if type(star) == "number" and not seen[star] and #parts > 0 then
        local part = string.format("%.0f,100,%.0f,0", star, STAR_LIFT)
        while #parts > 0 and used + #part + 1 > LEVEL_CHARS do
            used = used - #parts[#parts] - 1
            parts[#parts] = nil
        end
        table.insert(parts, 1, part)
    end
    return table.concat(parts, ";")
end

local function place_number()
    local place = gGlobalSyncTable.ofGmPlace
    if type(place) == "number" then return place end
    if type(place) ~= "string" then return 0 end
    local total = 0
    for i = 1, #place do
        total = (total + place:byte(i) * i) % 100003
    end
    return total
end

local SWAP_KEY = "ofPhProp"
local function swaps_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local n = row ~= nil and row[SWAP_KEY] or 0
    if type(n) ~= "number" then return 0 end
    return math.floor(n)
end

local function disguise_for(localIndex)
    local list = prop_list()
    if #list == 0 then return nil end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return nil end
    local seed = (np.globalIndex or localIndex) * 7 + place_number() * 13
        + swaps_of(localIndex)
    return list[(seed % #list) + 1]
end

local PROP_SIZE = {
    coinswitch = 3.0,
    exbox = 2.0,
    boxoutline = 2.0,
    cratesmall = 0.4,
    post = 0.5,
}

local function prop_size(key)
    local piece = piece_of(key)
    if piece ~= nil then return piece.size end
    return PROP_SIZE[key] or 1
end

local function lift_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local n = row ~= nil and row[LIFT_KEY] or 0
    if type(n) ~= "number" then return 0 end
    return math.floor(n)
end

local function prop_y(localIndex, m)
    if m == nil or m.pos == nil then return nil end
    local key = disguise_for(localIndex)
    local piece = piece_of(key)
    local floor = m.pos.y
    local lift = (piece ~= nil and piece.lift or 0) + lift_of(localIndex) * LIFT_STEP
    return floor + math.max(0, math.min(lift, PIECE_HIGHEST))
end

OF.gm_prophunt_prop_y = prop_y

local function pose_prop(o, m)
    if o == nil or m == nil then return false end

    local key = disguise_for(m.playerIndex or 0)
    local piece = piece_of(key)
    local model = piece ~= nil and piece.model or nil
    if model == nil then
        local costumes = OF.util.asks(OF.possess, "catalogue") and OF.possess.catalogue() or nil
        local entry = costumes ~= nil and key ~= nil and costumes.BY_KEY[key] or nil
        model = entry ~= nil and entry.model or nil
    end
    local spec = piece_spec(model)
    if spec == nil then return false end
    local now = OF.util.optional("get_global_timer", 0) or 0
    if spec.spin then
        o.oFaceAngleYaw = (now * STAR_SPIN) % 0x10000
    elseif spec.coin then
        o.oAnimState = now % 8
    elseif spec.anims ~= nil then
        local table_ = gObjectAnimations ~= nil and gObjectAnimations[spec.anims] or nil
        if table_ ~= nil then
            if o.oAnimations ~= table_ then o.oAnimations = table_ end
            OF.util.optional("obj_init_animation_with_accel_and_sound", nil, o, spec.anim or 0, 1.0)
        end
    end
    return true
end
OF.gm_prophunt_pose_prop = pose_prop

local LOOK = {
    pose = pose_prop,
    model = function(key)
        local piece = piece_of(key)
        return piece ~= nil and piece.model or nil
    end,
    y = prop_y,
    flat = function(key)
        local piece = piece_of(key)
        return piece ~= nil and piece.turns or false
    end,
}

local SWAP_BUTTONS = { L_TRIG, R_JPAD }

local RAISE_BUTTON = X_BUTTON or 0x0040
local LOWER_BUTTON = Y_BUTTON or 0x0080

local heightWasDown = 0
local function height_press(m, button)
    local down = OF.util.has_flag(m.controller.buttonDown or 0, button)
    local was = OF.util.has_flag(heightWasDown, button)
    return down and not was
end

local function is_opener(button)
    return OF.util.asks(OF.input, "opener") and OF.input.opener() == button
end

local function wearing(localIndex)
    if OF.gamemodes == nil or not OF.gamemodes.is_running() then return false end
    local now = OF.gamemodes.current()
    if now == nil or now.key ~= "prophunt" then return false end
    if OF.gamemodes.role(localIndex) ~= ROLE_HIDER then return false end
    return true
end

local function sliding(m)
    if m == nil then return false end
    return math.abs(m.forwardVel or 0) > HOLD_STILL
end

local wrongFrames = 0

function OF.gm_prophunt_miss_left()
    if wrongFrames <= 0 then return nil end
    return math.min(1, wrongFrames / WRONG_HOLD)
end

local CATCH_REACH = 170
function OF.gm_prophunt_catch_point(localIndex)
    if not wearing(localIndex) then return nil end
    local m = gMarioStates[localIndex]
    if m == nil or m.pos == nil then return nil end
    local y = prop_y(localIndex, m)
    if y == nil then return nil end
    local size = prop_size(disguise_for(localIndex)) or 1
    return m.pos.x, y + 40 * size, m.pos.z, CATCH_REACH * math.max(1, size)
end

function OF.gm_prophunt_disguise_for(localIndex)
    if not wearing(localIndex) then return nil end
    return disguise_for(localIndex)
end

function OF.gm_prophunt_animate_props()
    local props = OF.possess ~= nil and OF.possess.props or nil
    if type(props) ~= "table" then return end
    for localIndex, o in pairs(props) do
        if o ~= nil and o.activeFlags ~= 0 and wearing(localIndex) then
            pose_prop(o, gMarioStates[localIndex])
        end
    end
end

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil then return end
    OF.gamemodes.quiet_bubbles(m, wearing(m.playerIndex or 0))
end)

local mode = {
    key = "prophunt",

    marking = { players = false },

    noNametags = true,

    allActs = true,

    catchers = { [ROLE_SEEKER] = true },
    catchChime = true,

    name = "Prop Hunt",
    blurb = "the hiders are the furniture - the seekers have to guess",

    seekerMetal = true,
    aims = {
        [ROLE_SEEKER] = "Swing at what you think is a person. A wrong guess costs you.",
        [ROLE_HIDER] = "You are part of the furniture. Hold still until the clock runs out.",
        ["out"] = "You were found - watch the rest of it.",
    },

    how = "One course. The hiders are dressed as its furniture.\n"
        .. "You are hidden, not a ghost - you can still be hit.\n"
        .. "Hiders and seekers bump; your side and the out pass.\n"
        .. "A prop slides when you walk, so holding still is the skill.\n"
        .. "How many of you seek is set below.\n"
        .. "A wrong swing holds a seeker for three seconds.\n"
        .. "Seekers are held while the hiders scatter and settle.\n"
        .. "A catch is a close attack, as in Hide and Seek.\n"
        .. "What being found costs a hider is set below.\n"
        .. "Every catch puts the clock back to the round's length.",
    minPlayers = 2,

    maps = "anywhere",

    roomsOut = OF.gm_single_level_rooms_out({
        "bowser1", "bowser2", "bowser3", "the_plate", "ice_donut",
        "desert_cage", "tower", "wmotr", "aquarium",
        { level = LEVEL_CCM, area = 2 }, { level = LEVEL_TTM, area = 2 },
        { level = LEVEL_PSS, area = 1 },
        { level = LEVEL_DDD, area = 1 },
    }),
    mainCourses = true,

    oneSpace = { [LEVEL_JRB] = true },

    cheatsGiven = OF.gamemodes.water_rule("hide"),

    noDozing = true,

    room = { sweep = { "cannons" }, rules = { interactions = 0 } },

    defaultLimit = 3 * 60,

    target = { name = "seconds on the clock",
               asks = "How long the round runs",
               help = "each catch adds a minute",
               clock = true,
               default = 3 * 60,
               min = 60, max = 480, step = 30 },

    caps = { tiebreak = false },

    outWord = "FOUND",
    lastWord = "LAST PROP",

    options = {
        { key = "seekers", name = "How many of you seek",
          help = "the share of the lobby that is looking",
          choices = {
              { key = "quarter", name = "one in four",
                help = "about a quarter - two from five players" },
              { key = "third", name = "one in three",
                help = "a faster sweep, for a course with few places to "
                    .. "stand" },
              { key = "half", name = "one in two",
                help = "half is looking, so a good hiding spot beats a far "
                    .. "one" },
              { key = "one", name = "one, however many are playing",
                help = "one seeker against a full level; the long game" },
          } },
        { key = "scatter", name = "How long the hiders get",
          help = "the seekers are held, and cannot see out",
          choices = {
              { key = "twenty", name = "twenty seconds",
                help = "long enough to cross a course and settle in" },
              { key = "ten", name = "ten seconds",
                help = "there is no time to reach the good half of the "
                    .. "course" },
              { key = "forty", name = "forty seconds",
                help = "enough to choose a place, not grab the first one" },
              { key = "sixty", name = "a minute",
                help = "the widest setting; it eats into a short round's "
                    .. "clock" },
          } },
        { key = "caught", name = "A hider who is found",
          help = "what being caught costs you",
          choices = {
              { key = "seeks", name = "seeks with them",
                help = "the hunt speeds up; one fewer prop, one more "
                    .. "seeker" },
              { key = "out", name = "is out, and the last one hiding wins",
                help = "the last prop left standing takes the round" },
              { key = "freeze", name = "is frozen until a hider frees them",
                help = "break cover to free them, or stay hidden" },
          } },

        { key = "miss", name = "A seeker who guesses wrong",
          help = "what it costs a seeker to guess wrong",
          choices = {
              { key = "held", name = "is held for three seconds",
                help = "keeps swinging a guess, not a habit" },
              { key = "free", name = "pays nothing",
                help = "a wrong swing is free, so stillness no longer helps" },
          } },
    },
}

local function charges_for_a_miss()
    return OF.gamemodes.option_is("miss", "held")
end

mode.target.auto = function(n)
    return n >= 9 and 240 or 180
end

function mode.setup(players, options)
    if options ~= nil then options.target = OF.gamemodes.auto_target(mode, players, options) end

    OF.hunt.setup(players, options)
end

function mode.on_start()
    OF.hunt.on_start()

    OF.gm_prophunt_forget_catches()

    if OF.util.asks(OF.possess, "set_round_layer") then
        OF.possess.set_round_layer(OF.gm_prophunt_disguise_for, prop_size, LOOK)
    end
    OF.util.publish_row(0, SWAP_KEY, 0)
    OF.util.publish_row(0, LIFT_KEY, 0)

    if OF.util.asks(OF.markers, "set_hide_veto") then
        OF.markers.set_hide_veto(wearing)
    end

    wrongFrames = 0
end

function mode.late_join(localIndex)
    OF.hunt.late_join(localIndex)
end

function mode.update()

    OF.hunt.update()

    if wrongFrames > 0 then wrongFrames = wrongFrames - 1 end
end

local function swung_at_the_room(m, o)
    if m == nil or o == nil then return false end
    if m.playerIndex ~= 0 then return false end
    if not OF.gamemodes.is_running() then return false end
    local now = OF.gamemodes.current()
    if now == nil or now.key ~= "prophunt" then return false end
    if OF.gamemodes.role(0) ~= ROLE_SEEKER then return false end
    if not charges_for_a_miss() then return false end
    if OF.hunt.head_start_left() > 0 then return false end

    local props = OF.possess ~= nil and OF.possess.props or nil
    if type(props) == "table" then
        for _, prop in pairs(props) do
            if prop == o then return false end
        end
    end
    return true
end

local function struck_a_prop(m, o)
    if m == nil or o == nil or m.playerIndex ~= 0 then return nil end
    if not OF.gamemodes.is_running() then return nil end
    local now = OF.gamemodes.current()
    if now == nil or now.key ~= "prophunt" then return nil end
    if OF.gamemodes.role(0) ~= ROLE_SEEKER then return nil end
    local props = OF.possess ~= nil and OF.possess.props or nil
    if type(props) ~= "table" then return nil end
    for li, prop in pairs(props) do
        if prop == o and type(li) == "number" and li ~= 0 then
            OF.gamemodes.send_hit_claim(li)
            return li
        end
    end
    return nil
end
OF.gm_prophunt_struck = struck_a_prop

hook_event(HOOK_ON_ATTACK_OBJECT, function(m, o)
    struck_a_prop(m, o)
    if not swung_at_the_room(m, o) then return end
    wrongFrames = WRONG_HOLD

    if OF.util.asks(OF.hud, "banner") then OF.hud.banner("medal", OF.lang.t("MISS"), nil, { tone = "bad" }) end
    OF.gamemodes.cue("bad")
end)

local SHIP_DOOR = { x = 928, y = 1050, z = -1248 }
local SHIP_DOOR_REACH = 300
local SHIP_DOOR_ARMS = 700
local BAY_OUTSIDE_SHIP = { x = 5795, y = -4600, z = 2900 }
local shipDoorArmed = false

local function ship_door(m)
    local held = OF.gamemodes.holding()
    local np = gNetworkPlayers[0]
    if held == nil or np == nil or m == nil or m.pos == nil
        or held.level ~= LEVEL_JRB or np.currLevelNum ~= LEVEL_JRB
        or np.currAreaIndex ~= 2 or not OF.gamemodes.one_space(LEVEL_JRB) then
        shipDoorArmed = false
        return false
    end
    local dx = m.pos.x - SHIP_DOOR.x
    local dy = m.pos.y - SHIP_DOOR.y
    local dz = m.pos.z - SHIP_DOOR.z
    local far = math.sqrt(dx * dx + dy * dy + dz * dz)
    if far > SHIP_DOOR_ARMS then shipDoorArmed = true end
    if not shipDoorArmed or far > SHIP_DOOR_REACH then return false end
    shipDoorArmed = false
    return OF.gamemodes.owe_passage(1, BAY_OUTSIDE_SHIP)
end

function OF.gm_prophunt_ship_door(m)
    return ship_door(m)
end
OF.gm_prophunt_SHIP_DOOR = SHIP_DOOR
OF.gm_prophunt_BAY_OUTSIDE_SHIP = BAY_OUTSIDE_SHIP

function mode.before_mario_update(m)

    OF.hunt.before_mario_update(m)

    if m ~= nil and m.playerIndex == 0 then ship_door(m) end

    if wrongFrames > 0 and m ~= nil and m.playerIndex == 0 then
        OF.input.hold(m)
    end

    if m ~= nil and m.playerIndex == 0 and wearing(0) then
        OF.input.poll(m)
        local pressed = false
        for _, button in ipairs(SWAP_BUTTONS) do
            if not is_opener(button) and OF.input.pressed(button) then
                pressed = true
            end
        end
        if pressed then
            OF.util.publish_row(0, SWAP_KEY, swaps_of(0) + 1)

            OF.util.publish_row(0, LIFT_KEY, 0)
            OF.gamemodes.round_sound(SOUND_MENU_CLICK_CHANGE_VIEW)
        end

        local step = 0
        if height_press(m, RAISE_BUTTON) then step = 1 end
        if height_press(m, LOWER_BUTTON) then step = -1 end
        local down = m.controller.buttonDown or 0
        heightWasDown = 0
        for _, button in ipairs({ RAISE_BUTTON, LOWER_BUTTON }) do
            if OF.util.has_flag(down, button) then
                heightWasDown = heightWasDown + button
            end
        end
        if step ~= 0 then
            local piece = piece_of(disguise_for(0))
            local base = piece ~= nil and piece.lift or 0
            local want = lift_of(0) + step
            local total = base + want * LIFT_STEP
            if total >= 0 and total <= PIECE_HIGHEST then
                OF.util.publish_row(0, LIFT_KEY, want)
                OF.gamemodes.round_sound(SOUND_MENU_CLICK_CHANGE_VIEW)
            end
        end
    end
end

local CATCH_ADDS = 60
local hidersSeen = nil
function OF.gm_prophunt_forget_catches()
    hidersSeen = nil
end

function OF.gm_prophunt_catch_minute()
    if not OF.util.is_host() then return false end
    local now = #OF.gamemodes.with_role(ROLE_HIDER)
    local was = hidersSeen
    hidersSeen = now
    if was == nil or now >= was or now <= 0 then return false end
    local limit = gGlobalSyncTable.ofGmLimit or 0
    if limit <= 0 then return false end
    OF.util.publish("ofGmLimit", limit + CATCH_ADDS * (was - now))
    return true
end

function mode.host_update()
    OF.gm_prophunt_catch_minute()

    OF.hunt.host_update()
end

function mode.on_timeout()
    OF.hunt.on_timeout()
end

function mode.pin()

    local at = OF.util.asks(OF.gamemodes, "round_place") and OF.gamemodes.round_place() or nil
    local here = at == nil and OF.gamemodes.here_place(0) or nil
    local np = gNetworkPlayers[0]
    local level = (at ~= nil and at.level) or (here ~= nil and here.level)
        or (np ~= nil and np.currLevelNum) or nil
    local own = course_pieces(level)
    OF.util.publish(LEVEL_KEY, own or level_pieces() or "")
end

function mode.cleanup()
    OF.hunt.cleanup()
    if OF.util.is_host() then OF.util.publish(LEVEL_KEY, nil) end
    levelSaid, levelList, levelPieces = nil, nil, {}

    if OF.util.asks(OF.possess, "set_round_layer") then
        OF.possess.set_round_layer(nil)
    end
    if OF.util.asks(OF.markers, "set_hide_veto") then
        OF.markers.set_hide_veto(nil)
    end
    wrongFrames = 0
end

function mode.paint(localIndex)
    return OF.hunt.side_colour(OF.gamemodes.role(localIndex))
end

function mode.terms()

    local showing = OF.gamemodes.option_showing(mode.key, "caught")
    if showing == "out" then
        return OF.lang.t("every prop found, one prop left, or the clock")
    end
    if showing == "freeze" then
        return OF.lang.t("every prop frozen at once, or the clock")
    end
    return OF.lang.t("every prop found, or furniture beats the clock")
end

function mode.controls_lines()
    if not wearing(0) then return {} end
    local swap = is_opener(R_JPAD) and "L - another prop"
        or "L or D-pad right - another prop"
    return {
        OF.lang.t(swap),
        OF.lang.t("X - raise it"),
        OF.lang.t("Y - lower it"),
        OF.lang.t("Stand still - a prop that moves is a player"),
    }
end

function mode.hud()
    if not OF.gamemodes.is_running() then return end

    if OF.util.asks(OF.hunt, "hud") then OF.hunt.hud() end

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    local left = OF.gm_prophunt_miss_left()
    if left ~= nil then
        state("held", OF.lang.t("Held"), { prio = 80, tone = "bad",
            figure = tostring(math.floor(left * 100)) .. "%" })
        return
    end

    if OF.gamemodes.role(0) ~= ROLE_HIDER then return end
    local key = disguise_for(0)
    if key ~= nil then OF.util.legend(mode.controls_lines()) end
    if OF.hunt.head_start_left() > 0 then return end
    if sliding(gMarioStates[0]) then
        state("sliding", OF.lang.t("Sliding"), { prio = 70, tone = "warn", urgent = true })
    end
end

mode.catch_point = OF.gm_prophunt_catch_point

function mode.cluster()
    if OF.util.asks(OF.hunt, "cluster") then return OF.hunt.cluster() end
    return nil
end

function mode.blind()
    return OF.util.asks(OF.hunt, "blind") and OF.hunt.blind() == true
end

OF.gamemodes.register(mode)
