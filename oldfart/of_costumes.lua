OF = OF or {}
OF.costumes = OF.costumes or {}

local costumes = OF.costumes

local ROW_KEY = "ofCostume"
costumes.ROW_KEY = ROW_KEY

local NONE = "-"
costumes.NONE = NONE

local STORE_KEY = "costume"
local FAV_KEY = "costumefav"
local ROLL_KEY = "costumeroll"
local CATALOGUE = {

    {
        key = "heroes", name = "Heroes",
        blurb = "the five the game ships, and two it does not let you be",
        items = {
            { key = "mario",   name = "Mario",   model = E_MODEL_MARIO },
            { key = "luigi",   name = "Luigi",   model = E_MODEL_LUIGI },
            { key = "wario",   name = "Wario",   model = E_MODEL_WARIO },
            { key = "waluigi", name = "Waluigi", model = E_MODEL_WALUIGI },
            { key = "toad",    name = "Toad",    model = E_MODEL_TOAD_PLAYER },

            { key = "peach",   name = "Peach",   model = E_MODEL_PEACH },
            { key = "yoshi",   name = "Yoshi",   model = E_MODEL_YOSHI },
        },
    },
    {
        key = "friends", name = "Friends",
        blurb = "the ones that do not want a fight",
        items = {

            { key = "koopa",     name = "Koopa",          model = E_MODEL_KOOPA_WITH_SHELL },
            { key = "buddy",     name = "Bob-omb Buddy",  model = E_MODEL_BOBOMB_BUDDY },
            { key = "penguin",   name = "Penguin",        model = E_MODEL_PENGUIN },
            { key = "ukiki",     name = "Ukiki",          model = E_MODEL_UKIKI },
            { key = "dorrie",    name = "Dorrie",         model = E_MODEL_DORRIE },
            { key = "hoot",      name = "Hoot",           model = E_MODEL_HOOT },
            { key = "lakitu",    name = "Lakitu",         model = E_MODEL_LAKITU },
            { key = "mips",      name = "MIPS",           model = E_MODEL_MIPS },
            { key = "butterfly", name = "Butterfly",      model = E_MODEL_BUTTERFLY },

            { key = "castletoad", name = "Castle Toad",   model = E_MODEL_TOAD },

            { key = "birds",     name = "Birds",          model = E_MODEL_BIRDS },
        },
    },
    {
        key = "enemies", name = "Enemies",
        blurb = "everything in the game that has ever knocked you off something",
        items = {
            { key = "goomba",     name = "Goomba",              model = E_MODEL_GOOMBA },
            { key = "koopabare",  name = "Koopa without shell", model = E_MODEL_KOOPA_WITHOUT_SHELL },
            { key = "bobomb",     name = "Black Bob-omb",       model = E_MODEL_BLACK_BOBOMB },
            { key = "spiny",      name = "Spiny",               model = E_MODEL_SPINY },
            { key = "spinyball",  name = "Spiny ball",          model = E_MODEL_SPINY_BALL },
            { key = "flyguy",     name = "Fly Guy",             model = E_MODEL_FLYGUY },
            { key = "chuckya",    name = "Chuckya",             model = E_MODEL_CHUCKYA },
            { key = "amp",        name = "Amp",                 model = E_MODEL_AMP },
            { key = "thwomp",     name = "Thwomp",              model = E_MODEL_THWOMP },
            { key = "whomp",      name = "Whomp",               model = E_MODEL_WHOMP },
            { key = "montymole",  name = "Monty Mole",          model = E_MODEL_MONTY_MOLE },
            { key = "pokey",      name = "Pokey head",          model = E_MODEL_POKEY_HEAD },
            { key = "piranha",    name = "Piranha Plant",       model = E_MODEL_PIRANHA_PLANT },
            { key = "bulletbill", name = "Bullet Bill",         model = E_MODEL_BULLET_BILL },
            { key = "chomp",      name = "Chain Chomp",         model = E_MODEL_CHAIN_CHOMP },
            { key = "heaveho",    name = "Heave-Ho",            model = E_MODEL_HEAVE_HO },

            { key = "snufit",     name = "Snufit",              model = E_MODEL_SNUFIT },
            { key = "scuttlebug", name = "Scuttlebug",          model = E_MODEL_SCUTTLEBUG },
            { key = "swoop",      name = "Swoop",               model = E_MODEL_SWOOP },
            { key = "spindrift",  name = "Spindrift",           model = E_MODEL_SPINDRIFT },
            { key = "blizzard",   name = "Mr. Blizzard",        model = E_MODEL_MR_BLIZZARD },
            { key = "klepto",     name = "Klepto",              model = E_MODEL_KLEPTO },
            { key = "moneybag",   name = "Moneybag",            model = E_MODEL_MONEYBAG },
            { key = "lakituenemy", name = "Enemy Lakitu",       model = E_MODEL_ENEMY_LAKITU },
            { key = "bully",      name = "Bully",               model = E_MODEL_BULLY },
            { key = "chillbully", name = "Chill Bully",         model = E_MODEL_CHILL_BULLY },

            { key = "tweester",   name = "Tweester",            model = E_MODEL_TWEESTER },

            { key = "blizzardhid", name = "Mr. Blizzard hiding", model = E_MODEL_MR_BLIZZARD_HIDDEN },
        },
    },
    {
        key = "ghosts", name = "Ghosts",
        blurb = "Big Boo's Haunt, which is furniture as much as it is ghosts",
        items = {

            { key = "boo",        name = "Boo",            model = E_MODEL_BOO },
            { key = "mri",        name = "Mr. I",          model = E_MODEL_MR_I },
            { key = "piano",      name = "Mad piano",      model = E_MODEL_MAD_PIANO },
            { key = "chair",      name = "Haunted chair",  model = E_MODEL_HAUNTED_CHAIR },
            { key = "bookend",    name = "Bookend",        model = E_MODEL_BOOKEND },
            { key = "cage",       name = "Haunted cage",   model = E_MODEL_HAUNTED_CAGE },
        },
    },
    {
        key = "bosses", name = "Bosses",
        blurb = "the big ones, at exactly the size the game draws them",
        items = {
            { key = "bowser",     name = "Bowser",           model = E_MODEL_BOWSER },
            { key = "kingbobomb", name = "King Bob-omb",     model = E_MODEL_KING_BOBOMB },
            { key = "bigbully",   name = "Big Bully",        model = E_MODEL_BULLY_BOSS },
            { key = "bigchill",   name = "Big Chill Bully",  model = E_MODEL_BIG_CHILL_BULLY },

            { key = "wiggler",    name = "Wiggler head",     model = E_MODEL_WIGGLER_HEAD },
            { key = "eyerok",     name = "Eyerok's hand",    model = E_MODEL_EYEROK_LEFT_HAND },

            { key = "eyerokright", name = "Eyerok's other hand", model = E_MODEL_EYEROK_RIGHT_HAND },
            { key = "blargg",     name = "Blargg",           model = E_MODEL_BLARGG },

        },
    },
    {
        key = "water", name = "In the water",
        blurb = "Jolly Roger Bay and Dire Dire Docks, on dry land if you like",
        items = {
            { key = "sushi",     name = "Sushi",       model = E_MODEL_SUSHI },
            { key = "manta",     name = "Manta ray",   model = E_MODEL_MANTA_RAY },
            { key = "unagi",     name = "Unagi",       model = E_MODEL_UNAGI },
            { key = "bubba",     name = "Bubba",       model = E_MODEL_BUBBA },
            { key = "bub",       name = "Bub",         model = E_MODEL_BUB },
            { key = "cyanfish",  name = "Cyan fish",   model = E_MODEL_CYAN_FISH },
            { key = "fish",      name = "Fish",        model = E_MODEL_FISH },
            { key = "clam",      name = "Clam shell",  model = E_MODEL_CLAM_SHELL },
            { key = "skeeter",   name = "Skeeter",     model = E_MODEL_SKEETER },
            { key = "watermine", name = "Water mine",  model = E_MODEL_WATER_MINE },
            { key = "seaweed",   name = "Seaweed",     model = E_MODEL_SEAWEED },
            { key = "waterbomb", name = "Water bomb",  model = E_MODEL_WATER_BOMB },
        },
    },
    {
        key = "things", name = "Things",
        blurb = "props, and the reason a room full of crates is funny",
        items = {
            { key = "crate",      name = "Breakable box",        model = E_MODEL_BREAKABLE_BOX },
            { key = "cratesmall", name = "Small breakable box",  model = E_MODEL_BREAKABLE_BOX_SMALL },
            { key = "metalbox",   name = "Metal box",            model = E_MODEL_METAL_BOX },
            { key = "exbox",      name = "Exclamation box",      model = E_MODEL_EXCLAMATION_BOX },
            { key = "shell",      name = "Koopa shell",          model = E_MODEL_KOOPA_SHELL },
            { key = "bowlingball", name = "Bowling ball",        model = E_MODEL_BOWLING_BALL },
            { key = "yoshiegg",   name = "Yoshi egg",            model = E_MODEL_YOSHI_EGG },
            { key = "star",       name = "Star",                 model = E_MODEL_STAR },
            { key = "starghost",  name = "Transparent star",     model = E_MODEL_TRANSPARENT_STAR },
            { key = "key",        name = "Bowser key",           model = E_MODEL_BOWSER_KEY },
            { key = "chest",      name = "Treasure chest",       model = E_MODEL_TREASURE_CHEST_BASE },
            { key = "metalball",  name = "Metallic ball",        model = E_MODEL_METALLIC_BALL },
            { key = "marble",     name = "Purple marble",        model = E_MODEL_PURPLE_MARBLE },
            { key = "sphere",     name = "Yellow sphere",        model = E_MODEL_YELLOW_SPHERE },
            { key = "cannon",     name = "Cannon barrel",        model = E_MODEL_CANNON_BARREL },
            { key = "signpost",   name = "Wooden signpost",      model = E_MODEL_WOODEN_SIGNPOST },
            { key = "post",       name = "Wooden post",          model = E_MODEL_WOODEN_POST },
            { key = "flag",       name = "Koopa flag",           model = E_MODEL_KOOPA_FLAG },
            { key = "platform",   name = "Checkerboard platform", model = E_MODEL_CHECKERBOARD_PLATFORM },
            { key = "purpleswitch", name = "Purple switch",      model = E_MODEL_PURPLE_SWITCH },
            { key = "capswitch",  name = "Cap switch",           model = E_MODEL_CAP_SWITCH },
            { key = "coinswitch", name = "Blue coin switch",     model = E_MODEL_BLUE_COIN_SWITCH },

            { key = "boxoutline", name = "Box outline",          model = E_MODEL_EXCLAMATION_BOX_OUTLINE },

            { key = "cannonbase", name = "Cannon base",          model = E_MODEL_CANNON_BASE },
            { key = "chestlid",   name = "Treasure chest lid",   model = E_MODEL_TREASURE_CHEST_LID },

            { key = "trampoline", name = "Trampoline top",       model = E_MODEL_TRAMPOLINE },
            { key = "spring",     name = "Trampoline spring",    model = E_MODEL_TRAMPOLINE_CENTER },
            { key = "springbase", name = "Trampoline base",      model = E_MODEL_TRAMPOLINE_BASE },

            { key = "smallkey",   name = "Small key",            model = E_MODEL_BETA_BOO_KEY },

            { key = "switchbase", name = "Cap switch base",      model = E_MODEL_CAP_SWITCH_BASE },

            { key = "bomb",       name = "Bomb",                 model = E_MODEL_BOWSER_BOMB },

            { key = "error",      name = "Error model",          model = E_MODEL_ERROR_MODEL },
        },
    },

    {
        key = "caps", name = "Caps you become",
        blurb = "a hat with legs, which is smaller than it sounds",
        items = {

            { key = "mariocap",   name = "Mario's cap",              model = E_MODEL_MARIOS_CAP },
            { key = "wingcap",    name = "Mario's wing cap",         model = E_MODEL_MARIOS_WING_CAP },
            { key = "metalcap",   name = "Mario's metal cap",        model = E_MODEL_MARIOS_METAL_CAP },
            { key = "wingmetal",  name = "Mario's winged metal cap", model = E_MODEL_MARIOS_WINGED_METAL_CAP },
            { key = "luigicap",   name = "Luigi's cap",              model = E_MODEL_LUIGIS_CAP },
            { key = "luigiwing",  name = "Luigi's wing cap",         model = E_MODEL_LUIGIS_WING_CAP },
            { key = "luigimetal", name = "Luigi's metal cap",        model = E_MODEL_LUIGIS_METAL_CAP },
            { key = "luigiwingmetal", name = "Luigi's winged metal cap", model = E_MODEL_LUIGIS_WINGED_METAL_CAP },
            { key = "toadcap",    name = "Toad's cap",               model = E_MODEL_TOADS_CAP },
            { key = "toadwing",   name = "Toad's wing cap",          model = E_MODEL_TOADS_WING_CAP },
            { key = "toadmetal",  name = "Toad's metal cap",         model = E_MODEL_TOADS_METAL_CAP },
            { key = "waluigicap", name = "Waluigi's cap",            model = E_MODEL_WALUIGIS_CAP },
            { key = "waluigiwing", name = "Waluigi's wing cap",      model = E_MODEL_WALUIGIS_WING_CAP },
            { key = "waluigimetal", name = "Waluigi's metal cap",    model = E_MODEL_WALUIGIS_METAL_CAP },
            { key = "waluigiwingmetal", name = "Waluigi's winged metal cap", model = E_MODEL_WALUIGIS_WINGED_METAL_CAP },
            { key = "wariocap",   name = "Wario's cap",              model = E_MODEL_WARIOS_CAP },
            { key = "wariowing",  name = "Wario's wing cap",         model = E_MODEL_WARIOS_WING_CAP },
            { key = "wariometal", name = "Wario's metal cap",        model = E_MODEL_WARIOS_METAL_CAP },
            { key = "wariowingmetal", name = "Wario's winged metal cap", model = E_MODEL_WARIOS_WINGED_METAL_CAP },
        },
    },
    {
        key = "scenery", name = "Scenery",
        blurb = "the level itself, walking about",
        items = {
            { key = "tree",        name = "Bubbly tree",          model = E_MODEL_BUBBLY_TREE },
            { key = "snowtree",    name = "Snow tree",            model = E_MODEL_SNOW_TREE },
            { key = "palmtree",    name = "Palm tree",            model = E_MODEL_PALM_TREE },
            { key = "spikytree",   name = "Courtyard spiky tree", model = E_MODEL_COURTYARD_SPIKY_TREE },
            { key = "castledoor",  name = "Castle door",          model = E_MODEL_CASTLE_CASTLE_DOOR },
            { key = "haunteddoor", name = "Haunted door",         model = E_MODEL_BBH_HAUNTED_DOOR },
            { key = "woodendoor",  name = "Wooden door",          model = E_MODEL_HMC_WOODEN_DOOR },
            { key = "metaldoor",   name = "Metal door",           model = E_MODEL_HMC_METAL_DOOR },

            { key = "hazydoor",    name = "Hazy maze door",       model = E_MODEL_HMC_HAZY_MAZE_DOOR },

            { key = "door0",       name = "Castle door, no stars", model = E_MODEL_CASTLE_DOOR_0_STARS },
            { key = "door1",       name = "Castle door, one star", model = E_MODEL_CASTLE_DOOR_1_STAR },
            { key = "door3",       name = "Castle door, three stars", model = E_MODEL_CASTLE_DOOR_3_STARS },
            { key = "keydoor",     name = "Key door",             model = E_MODEL_CASTLE_KEY_DOOR },
            { key = "cabindoor",   name = "Cabin door",           model = E_MODEL_CCM_CABIN_DOOR },

            { key = "pipe",        name = "Warp pipe",            model = E_MODEL_BITS_WARP_PIPE },
        },
    },
}

costumes.GROUPS = {}
costumes.BY_KEY = {}
costumes.LIST = {}

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function() return costumes.LIST end)

for _, group in ipairs(CATALOGUE) do
    local kept = {}
    for _, item in ipairs(group.items) do
        if type(item.model) == "number" and item.model > 0 then
            item.group = group.key
            kept[#kept + 1] = item
            costumes.BY_KEY[item.key] = item
            costumes.LIST[#costumes.LIST + 1] = item
        end
    end
    if #kept > 0 then
        costumes.GROUPS[#costumes.GROUPS + 1] = {
            key = group.key, name = group.name, blurb = group.blurb, items = kept,
        }
    end
end

function costumes.count()
    return #costumes.LIST
end

function costumes.group_of(key)
    for _, group in ipairs(costumes.GROUPS) do
        if group.key == key then return group end
    end
    return nil
end

function costumes.find(text)
    if text == nil then return nil end
    local needle = string.lower(tostring(text))
    if needle == "" then return nil end
    if costumes.BY_KEY[needle] ~= nil then return costumes.BY_KEY[needle] end
    for _, item in ipairs(costumes.LIST) do
        if string.lower(item.name) == needle then return item end
    end
    return nil
end

function costumes.random_key(notThis)
    local n = #costumes.LIST
    if n == 0 then return nil end
    if n == 1 then return costumes.LIST[1].key end
    for _ = 1, 12 do
        local key = costumes.LIST[math.random(n)].key
        if key ~= notThis then return key end
    end
    return costumes.LIST[math.random(n)].key
end

costumes.LOOK_LISTS = {
    "OBJ_LIST_EXT", "OBJ_LIST_DESTRUCTIVE", "OBJ_LIST_GENACTOR",
    "OBJ_LIST_PUSHABLE", "OBJ_LIST_LEVEL", "OBJ_LIST_DEFAULT",
    "OBJ_LIST_SURFACE", "OBJ_LIST_POLELIKE", "OBJ_LIST_SPAWNER",
    "OBJ_LIST_UNIMPORTANT",
}

costumes.LOOK_AHEAD = 220
costumes.LOOK_REACH = 420

costumes.BY_MODEL = {}
for _, item in ipairs(costumes.LIST) do
    if costumes.BY_MODEL[item.model] == nil then
        costumes.BY_MODEL[item.model] = item
    end
end

function costumes.in_your_sights(m)
    m = m or (gMarioStates ~= nil and gMarioStates[0] or nil)
    if m == nil or m.pos == nil then return nil end
    if OF.util.binding("obj_get_first") == nil then return nil end
    if OF.util.binding("obj_get_next") == nil then return nil end

    local yaw = (m.faceAngle ~= nil and tonumber(m.faceAngle.y)) or 0
    local at = {
        x = m.pos.x + sins(yaw) * costumes.LOOK_AHEAD,
        y = m.pos.y,
        z = m.pos.z + coss(yaw) * costumes.LOOK_AHEAD,
    }

    local best, bestSquare = nil, costumes.LOOK_REACH * costumes.LOOK_REACH

    for _, name in ipairs(costumes.LOOK_LISTS) do
        local list = _G[name]
        if type(list) == "number" then
            local object = obj_get_first(list)
            local guard = 0
            while object ~= nil and guard < 512 do
                if object.activeFlags ~= 0 then
                    local dx = (object.oPosX or 0) - at.x
                    local dy = (object.oPosY or 0) - at.y
                    local dz = (object.oPosZ or 0) - at.z
                    local square = dx * dx + dy * dy + dz * dz
                    if square < bestSquare then
                        local model = OF.util.optional(
                            "obj_get_model_id_extended", nil, object)
                        local item = model ~= nil and costumes.BY_MODEL[model]
                            or nil
                        if item ~= nil then best, bestSquare = item, square end
                    end
                end
                object = obj_get_next(object)
                guard = guard + 1
            end
        end
    end

    return best, best ~= nil and math.sqrt(bestSquare) or nil
end

local favourites = {}
local favIndex = {}

local FAV_MAX = 12
costumes.FAV_MAX = FAV_MAX

local function save_favourites()
    OF.util.store(FAV_KEY, table.concat(favourites, ","))
end

function costumes.favourites()
    local out = {}
    for _, key in ipairs(favourites) do
        local entry = costumes.BY_KEY[key]
        if entry ~= nil then out[#out + 1] = entry end
    end
    return out
end

function costumes.is_favourite(key)
    return key ~= nil and favIndex[key] == true
end

function costumes.toggle_favourite(key)
    if key == nil or costumes.BY_KEY[key] == nil then
        return false, "There is no costume by that name."
    end
    if favIndex[key] then
        favIndex[key] = nil
        for i = #favourites, 1, -1 do
            if favourites[i] == key then table.remove(favourites, i) end
        end
        save_favourites()
        return true, false
    end
    if #favourites >= FAV_MAX then
        return false, OF.lang.fill("You can keep @ at a time.", FAV_MAX)
    end
    favourites[#favourites + 1] = key
    favIndex[key] = true
    save_favourites()
    return true, true
end

local function load_favourites()
    favourites = {}
    favIndex = {}
    local stored = mod_storage_load(FAV_KEY, "")
    if stored == nil or stored == "" then return end
    for piece in string.gmatch(stored, "[^,]+") do

        if not favIndex[piece] and #favourites < FAV_MAX then
            favourites[#favourites + 1] = piece
            favIndex[piece] = true
        end
    end
end

costumes.load_favourites = load_favourites

local rolling = false

function costumes.rolling()
    return rolling
end

function costumes.set_rolling(on)
    rolling = (on == true)
    OF.util.store(ROLL_KEY, rolling and "1" or "")
    return true
end

local ROOM_KEY = "ofRoomCostume"
costumes.ROOM_KEY = ROOM_KEY

function costumes.room_key()
    local key = gGlobalSyncTable[ROOM_KEY]
    if key == nil or key == "" then return nil end
    if costumes.BY_KEY[key] == nil then return nil end
    return key
end

function costumes.room_on(key)
    return key ~= nil and costumes.room_key() == key
end

function costumes.room_any()
    return costumes.room_key() ~= nil
end

local roomRegistered = false

local function register_room_action()
    if roomRegistered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    roomRegistered = true

    OF.net.register_action("roomcostume", "costume_other",
        function(_, _, _, key)
            if not OF.util.is_host() then return false, "Only the host." end
            return costumes.write_room(tostring(key or ""))
        end)
end

function costumes.write_room(key)
    if key == nil or key == "" then
        if not OF.util.publish(ROOM_KEY, "") then
            return false, "The lobby would not take that."
        end
        return true
    end
    if costumes.BY_KEY[key] == nil then
        return false, "There is no costume by that name."
    end
    if not OF.util.publish(ROOM_KEY, key) then
        return false, "The lobby would not take that."
    end
    return true
end

function costumes.set_room(key)
    if not OF.perms.can("costume_other") then
        return false, "Your rank cannot set the lobby's costume. ("
            .. OF.perms.tier_name(OF.perms.required("costume_other")) .. "+)"
    end
    if key ~= nil and key ~= "" and costumes.BY_KEY[key] == nil then
        return false, "There is no costume by that name."
    end

    register_room_action()
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("roomcostume", 0, 0, key or "")
    end

    if not OF.util.is_host() then
        return false, "No host to ask yet - try again in a second."
    end
    return costumes.write_room(key)
end

function costumes.clear_room()
    return costumes.set_room(nil)
end

function costumes.mine_choice(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return nil end
    local key = s[ROW_KEY]
    if key == nil or key == "" then return nil end
    local room = costumes.room_key()
    if key == NONE then

        if room == nil then return nil end
        return NONE
    end
    if costumes.BY_KEY[key] == nil then return nil end
    if key == room then return nil end
    return key
end

function costumes.mine_state(localIndex, key)
    local choice = costumes.mine_choice(localIndex)
    if choice == nil then return nil end
    if choice == key then return true end
    if costumes.room_on(key) then return false end
    return nil
end

function costumes.settled_choice(choice)
    local room = costumes.room_key()
    if choice == nil or choice == "" then return nil end
    if choice == NONE then
        if room == nil then return nil end
        return NONE
    end
    if costumes.BY_KEY[choice] == nil then return nil end
    if choice == room then return nil end
    return choice
end

function costumes.worn(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return nil end
    local key = s[ROW_KEY]
    if key ~= nil and key ~= "" then
        if key == NONE then return nil end
        if costumes.BY_KEY[key] ~= nil then return key end
    end
    return costumes.room_key()
end

function costumes.name_worn(localIndex)
    local key = costumes.worn(localIndex)
    if key == nil then return nil end
    return costumes.BY_KEY[key].name
end

function costumes.routed()
    if not OF.util.asks(OF.charselect, "can_dress") then return false end
    return OF.charselect.can_dress()
end

function costumes.blocked()
    if not OF.util.asks(OF.charselect, "present") then return false end
    if not OF.charselect.present() then return false end
    return not costumes.routed()
end

function costumes.round_hides(localIndex)
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down(localIndex)
end

function costumes.suppressed(localIndex)
    return costumes.round_hides(localIndex)
end

function costumes.in_force(localIndex)
    local key = costumes.worn(localIndex)
    if key == nil then return nil, false end
    if costumes.suppressed(localIndex) then return nil, false end
    return key, costumes.mine_choice(localIndex) == key
end

function costumes.model_for(localIndex)
    if costumes.blocked() then return nil end
    local key = costumes.in_force(localIndex)
    if key == nil then return nil end
    return costumes.BY_KEY[key].model
end

function costumes.head_is_covered(localIndex)
    if costumes.suppressed(localIndex) then return true end
    return costumes.model_for(localIndex) ~= nil
end

local woreBefore = {}

local faceComplained = false

local blockedComplained = false

function costumes.forget_faces()
    woreBefore = {}
    faceComplained = false
end

function costumes.note_blocked()
    if blockedComplained then return false end
    blockedComplained = true
    OF.notify.show("This build of Character Select has no way to show a costume",
        "warn", 7)
    return true
end

local function note_no_face()
    if faceComplained then return false end
    faceComplained = true
    OF.notify.show("This build cannot read your model, so it will not change it",
        "warn", 6)
    return true
end

local roundHid = false

local wear_locally

local function watch_round()
    local hiding = costumes.round_hides()
    if hiding == roundHid then return false end
    roundHid = hiding

    if not hiding then

        if not rolling then return false end

        local was = costumes.mine_choice(0)
        if was == nil or was == NONE then return false end

        if not OF.perms.can("costume_self") then return false end
        local key = costumes.random_key(was)
        if key == nil or key == was then return false end

        costumes.set_mine(key)
        OF.notify.show("A new face for the next round: @", "info", 6,
            costumes.BY_KEY[key].name)
        return true
    end

    if costumes.worn(0) == nil then return false end
    OF.notify.show("Costumes are off for the round - yours comes back at the end",
        "info", 6)
    return true
end

local function repaint_after_model_change(localIndex)
    if OF.util.asks(OF.teams, "repaint") then OF.teams.repaint(localIndex) end
end

local BILLBOARDED = {
    tree = true, snowtree = true, palmtree = true, spikytree = true,
    mri = true, bowlingball = true, metalball = true, sphere = true,
    marble = true,
}
costumes.BILLBOARDED = BILLBOARDED

local FACING_KEY = "ofFacing"
costumes.FACING_KEY = FACING_KEY

costumes.FACING_FLAT = "flat"
function costumes.facing_held(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return false end
    local said = row[FACING_KEY]
    return said == true or said == costumes.FACING_FLAT
end

function costumes.facing_kind(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return nil end
    local said = row[FACING_KEY]
    if said == costumes.FACING_FLAT then return costumes.FACING_FLAT end
    if said == true then return true end
    return nil
end

function costumes.reset_mine()
    if costumes.facing_kind(0) == nil then return false end
    OF.util.publish_row(0, FACING_KEY, nil)
    return true
end

function costumes.set_facing(on)
    if on == costumes.FACING_FLAT then
        return OF.util.publish_row(0, FACING_KEY, costumes.FACING_FLAT)
    end
    return OF.util.publish_row(0, FACING_KEY, on == true)
end

function costumes.cycle_facing()
    local now = costumes.facing_kind(0)
    if now == nil then return costumes.set_facing(true) end
    if now == true then return costumes.set_facing(costumes.FACING_FLAT) end
    return costumes.set_facing(false)
end

function costumes.facing_name(localIndex)
    local now = costumes.facing_kind(localIndex)
    if now == costumes.FACING_FLAT then return "flat" end
    if now == true then return "upright" end
    return "off"
end

local turned = {}

function costumes.vanilla_turn()
    if OF.util.optional("camera_config_is_free_cam_enabled", false) == true then
        return true
    end
    if OF.util.optional("get_first_person_enabled", false) == true then
        return true
    end
    return costumes.FACING_FLAT
end

function costumes.turn_reaches(localIndex)
    local m = gMarioStates[localIndex]
    local obj = m ~= nil and m.marioObj or nil
    local header = obj ~= nil and obj.header or nil
    local gfx = header ~= nil and header.gfx or nil
    local shared = gfx ~= nil and gfx.sharedChild or nil
    if shared == nil then return true end
    local extra = shared.extraFlags
    if type(extra) ~= "number" then return true end
    local forced = GRAPH_EXTRA_FORCE_3D
    if type(forced) ~= "number" then return true end
    return not OF.util.has_flag(extra, forced)
end

function costumes.facing_level(localIndex)
    local kind = costumes.facing_kind(localIndex)
    if kind == nil then return nil end
    local said = "Upright, like a tree"
    if kind == costumes.FACING_FLAT then said = "Flat, like a coin" end
    if not costumes.turn_reaches(localIndex) then
        return said .. ", but your model pack is holding it still"
    end
    return said
end

local function turn_wanted(localIndex, key)
    local said = costumes.facing_kind(localIndex)
    if key ~= nil and BILLBOARDED[key] then
        if said == costumes.FACING_FLAT then return said end
        return costumes.vanilla_turn()
    end

    if said == nil then return nil end
    if costumes.round_hides(localIndex) then return nil end
    return said
end
costumes.turn_wanted = turn_wanted

local function hold_facing(m, key)
    local obj = m.marioObj
    local header = obj.header
    local gfx = header ~= nil and header.gfx or nil
    local node = gfx ~= nil and gfx.node or nil
    if node == nil then return end
    local localIndex = m.playerIndex

    local wear = turn_wanted(localIndex, key)

    if wear ~= nil then

        if wear == costumes.FACING_FLAT then
            if type(node.flags) == "number"
                and OF.util.has_flag(node.flags, GRAPH_RENDER_CYLBOARD) then
                node.flags = node.flags - GRAPH_RENDER_CYLBOARD
            end
            OF.util.optional("obj_set_billboard", nil, obj)
        else
            if type(node.flags) == "number"
                and OF.util.has_flag(node.flags, GRAPH_RENDER_BILLBOARD) then
                node.flags = node.flags - GRAPH_RENDER_BILLBOARD
            end
            OF.util.optional("obj_set_cylboard", nil, obj)
        end
        turned[localIndex] = true
        return
    end

    if turned[localIndex] == nil then return end
    turned[localIndex] = nil
    if type(node.flags) ~= "number" then return end
    for _, flag in ipairs({ GRAPH_RENDER_CYLBOARD, GRAPH_RENDER_BILLBOARD }) do
        if OF.util.has_flag(node.flags, flag) then
            node.flags = node.flags - flag
        end
    end
end

function costumes.forget_facing(localIndex)
    if localIndex == nil then
        turned = {}
    else
        turned[localIndex] = nil
    end
end

local litUp = {}

local function hold_opacity(m, wearing)
    local obj = m.marioObj
    local localIndex = m.playerIndex

    if wearing then

        if litUp[localIndex] == nil then litUp[localIndex] = obj.oOpacity or 0 end
        if obj.oOpacity ~= 255 then obj.oOpacity = 255 end
        return
    end

    if litUp[localIndex] == nil then return end
    local was = litUp[localIndex]
    litUp[localIndex] = nil
    obj.oOpacity = was
end

local BLINK_PERIOD = 150

local BLINK_SHUT = 4

local BLINKS = {
    yoshi = true, koopa = true, koopabare = true, buddy = true, bobomb = true,
    lakitu = true, lakituenemy = true, goomba = true, pokey = true, ukiki = true,
}

local FIXED_ANIM_STATE = {
    amp = 1,
    cratesmall = 1,
}

local heldAnim = {}

local function hold_anim_state(m, wearing, key)
    local obj = m.marioObj
    local localIndex = m.playerIndex

    if not wearing then
        if heldAnim[localIndex] == nil then return end
        local was = heldAnim[localIndex]
        heldAnim[localIndex] = nil
        obj.oAnimState = was
        return
    end

    local fixed = FIXED_ANIM_STATE[key]
    if fixed == nil and not BLINKS[key] then return end

    if heldAnim[localIndex] == nil then heldAnim[localIndex] = obj.oAnimState or 0 end

    if fixed ~= nil then
        if obj.oAnimState ~= fixed then obj.oAnimState = fixed end
        return
    end

    local t = OF.util.optional("get_global_timer", 0) or 0
    local phase = (t + localIndex * 53) % BLINK_PERIOD
    local want = (phase < BLINK_SHUT) and 1 or 0
    if obj.oAnimState ~= want then obj.oAnimState = want end
end

function costumes.forget_anim_state(localIndex)
    if localIndex == nil then
        heldAnim = {}
    else
        heldAnim[localIndex] = nil
    end
end

local function hold_unsquished(m, wearing)
    if not wearing then return end
    if (m.squishTimer or 0) == 0 and (m.bounceSquishTimer or 0) == 0 then return end

    local wanted = 1.0
    if OF.util.asks(OF.cheats, "wanted_scale_for") then
        wanted = tonumber(OF.cheats.wanted_scale_for(m.playerIndex)) or 1.0
    end

    local scale = m.marioObj.header.gfx.scale
    if scale.x ~= wanted or scale.y ~= wanted or scale.z ~= wanted then
        scale.x, scale.y, scale.z = wanted, wanted, wanted
    end
end

local hold_squash

do

    local SHORT_HITBOX = ACT_FLAG_SHORT_HITBOX or 0x00008000

    local AIRBORNE = ACT_FLAG_AIR or 0x00000800

    local LONG_JUMP = ACT_LONG_JUMP or 0x03000888
    local GROUND_POUND = ACT_GROUND_POUND or 0x008008A9
    local GROUND_POUND_LAND = ACT_GROUND_POUND_LAND or 0x0080023C

    local shaped = {}

    local FALL_DEPTH = 1000.0

    local SHAPES = {
        { flag   = SHORT_HITBOX,                    wide = 1.20, tall = 0.62 },
        { action = GROUND_POUND_LAND,               wide = 1.30, tall = 0.55 },
        { action = GROUND_POUND,       state = 1,   wide = 1.14, tall = 0.78 },
        { depth  = FALL_DEPTH,                      wide = 1.10, tall = 0.86 },
        { action = LONG_JUMP,                       wide = 0.86, tall = 1.18 },
    }

    local function shape_of(m)
        local action = m.action
        for _, rule in ipairs(SHAPES) do
            local hit
            if rule.flag ~= nil then
                hit = OF.util.has_flag(action, rule.flag)
            elseif rule.action ~= nil then
                hit = action == rule.action
                    and (rule.state == nil or m.actionState == rule.state)
            else
                local pos = m.pos
                hit = pos ~= nil
                    and OF.util.has_flag(action, AIRBORNE)
                    and ((m.peakHeight or 0) - (pos.y or 0)) > rule.depth
            end
            if hit then return rule.wide, rule.tall end
        end
        return nil
    end

    function hold_squash(m, wearing)
        local localIndex = m.playerIndex

        local base = 1.0
        if OF.util.asks(OF.cheats, "wanted_scale_for") then
            base = tonumber(OF.cheats.wanted_scale_for(localIndex)) or 1.0
        end

        local wide, tall
        if wearing then

            if (m.squishTimer or 0) ~= 0 or (m.bounceSquishTimer or 0) ~= 0 then
                shaped[localIndex] = nil
                return
            end
            wide, tall = shape_of(m)
        end

        local scale = m.marioObj.header.gfx.scale
        if wide == nil then

            if shaped[localIndex] == nil then return end
            shaped[localIndex] = nil

            if (m.squishTimer or 0) ~= 0 or (m.bounceSquishTimer or 0) ~= 0 then
                return
            end
            if scale.x ~= base or scale.y ~= base or scale.z ~= base then
                scale.x, scale.y, scale.z = base, base, base
            end
            return
        end

        shaped[localIndex] = true
        local wideAt, tallAt = base * wide, base * tall
        if scale.x ~= wideAt or scale.y ~= tallAt or scale.z ~= wideAt then
            scale.x, scale.y, scale.z = wideAt, tallAt, wideAt
        end
    end

    function costumes.shape_held(localIndex)
        return shaped[localIndex] == true
    end

    function costumes.forget_squash(localIndex)
        if localIndex == nil then
            shaped = {}
        else
            shaped[localIndex] = nil
        end
    end
end

function costumes.squashes(key)
    if key == nil then return false end
    return BILLBOARDED[key] == true or costumes.HEROES[key] == true
end

costumes.HEROES = { mario = true, luigi = true, wario = true, waluigi = true, toad = true }

function costumes.forget_opacity(localIndex)
    if localIndex == nil then
        litUp = {}
    else
        litUp[localIndex] = nil
    end
end

local hold_motion, spin_at_render
do
    local MOTION = {

        star      = { yaw = 0x800 },

        starghost = { yaw = 0x800 },

        shell     = { yaw = 0x1000 },

        key       = { yaw = 0x400 },

        smallkey  = { yaw = 0x200, roll = 0x200 },

        tweester  = { yaw = 0x2C00 },
    }
    costumes.MOTION = MOTION

    function costumes.motion_of(key)
        if key == nil then return nil end
        return MOTION[key]
    end

    local motionPhase = {}
    local hookBorrowed = {}

    local untilt = {}

    local function advance(localIndex, motion)
        local phase = motionPhase[localIndex]
        if phase == nil then
            phase = { yaw = 0, pitch = 0, roll = 0 }
            motionPhase[localIndex] = phase
        end
        phase.yaw = (phase.yaw + (motion.yaw or 0)) % 0x10000
        phase.pitch = (phase.pitch + (motion.pitch or 0)) % 0x10000
        phase.roll = (phase.roll + (motion.roll or 0)) % 0x10000
        return phase
    end

    function costumes.motion_phase(localIndex)
        return motionPhase[localIndex]
    end

    function hold_motion(m)
        if m == nil or m.marioObj == nil then return end
        local localIndex = m.playerIndex
        local obj = m.marioObj

        local key = costumes.worn(localIndex)
        if key ~= nil and (costumes.blocked() or costumes.suppressed(localIndex)
            or costumes.BY_KEY[key].model == nil) then
            key = nil
        end
        local motion = key ~= nil and MOTION[key] or nil

        local turning = turn_wanted(localIndex, key) ~= nil

        if motion == nil and not turning then

            if hookBorrowed[localIndex] == nil then return end
            obj.hookRender = hookBorrowed[localIndex]
            hookBorrowed[localIndex] = nil
            motionPhase[localIndex] = nil
            untilt[localIndex] = nil
            return
        end

        if hookBorrowed[localIndex] == nil then
            hookBorrowed[localIndex] = obj.hookRender or 0
        end
        obj.hookRender = 1

        untilt[localIndex] = turning or (motion ~= nil) or nil
        if motion ~= nil then
            advance(localIndex, motion)
        else
            motionPhase[localIndex] = nil
        end
    end

    function spin_at_render(obj)
        if obj == nil then return end
        for localIndex = 0, MAX_PLAYERS - 1 do
            local phase = motionPhase[localIndex]
            if phase ~= nil or untilt[localIndex] then
                local m = gMarioStates[localIndex]
                local mine = m ~= nil and m.marioObj or nil
                if mine ~= nil and mine == obj then
                    local header = obj.header
                    local gfx = header ~= nil and header.gfx or nil
                    if gfx == nil then return end

                    if untilt[localIndex] then gfx.throwMatrix = nil end

                    local angle = gfx.angle
                    if angle == nil or phase == nil then return end
                    angle.x = (angle.x + phase.pitch) % 0x10000
                    angle.y = (angle.y + phase.yaw) % 0x10000
                    angle.z = (angle.z + phase.roll) % 0x10000
                    return
                end
            end
        end
    end

    function costumes.forget_motion(localIndex)
        if localIndex == nil then
            motionPhase = {}
            hookBorrowed = {}
            untilt = {}
        else
            untilt[localIndex] = nil
            motionPhase[localIndex] = nil
            hookBorrowed[localIndex] = nil
        end
    end

end

hook_event(HOOK_MARIO_UPDATE, hold_motion)
hook_event(HOOK_ON_OBJECT_RENDER, spin_at_render)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    costumes.forget_motion(m.playerIndex)
end)

local function hold(m)
    if m == nil or m.marioObj == nil then return end
    local localIndex = m.playerIndex

    if localIndex == 0 then watch_round() end
    local wanted = costumes.model_for(localIndex)

    local worn = costumes.worn(localIndex)

    hold_facing(m, wanted ~= nil and worn or nil)

    hold_opacity(m, wanted ~= nil)

    hold_anim_state(m, wanted ~= nil, worn)

    local dressed = wanted ~= nil

    hold_squash(m, dressed and not costumes.HEROES[worn])
    hold_unsquished(m, dressed and not costumes.squashes(worn))

    if costumes.routed() then

        local was = woreBefore[localIndex]
        if was ~= nil then
            woreBefore[localIndex] = nil
            OF.slots.set_model(m.marioObj, was)
        end

        if localIndex ~= 0 then return end

        if wanted == nil then
            if OF.charselect.undress() then repaint_after_model_change(0) end
        else
            local ok, changed = OF.charselect.dress(wanted)

            if ok and changed then repaint_after_model_change(0) end
        end
        return
    end

    if wanted == nil then

        local was = woreBefore[localIndex]
        if was == nil then return end
        woreBefore[localIndex] = nil
        OF.slots.set_model(m.marioObj, was)
        return
    end

    if woreBefore[localIndex] == nil then

        local was = OF.util.optional("obj_get_model_id_extended", nil, m.marioObj)

        if was == nil or was == E_MODEL_NONE then
            if localIndex == 0 then note_no_face() end
            return
        end
        woreBefore[localIndex] = was
    end

    OF.slots.set_model(m.marioObj, wanted)
end

hook_event(HOOK_MARIO_UPDATE, hold)

hook_event(HOOK_ON_LEVEL_INIT, function()
    costumes.forget_faces()

    costumes.forget_opacity()

    costumes.forget_motion()
    costumes.forget_squash()

    costumes.forget_anim_state()

    for localIndex = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[localIndex]
        if m ~= nil and m.marioObj ~= nil then
            hold_motion(m)
            hold(m)
        end
    end
end)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    woreBefore[m.playerIndex] = nil
    costumes.forget_facing(m.playerIndex)
    costumes.forget_opacity(m.playerIndex)
    costumes.forget_squash(m.playerIndex)
    costumes.forget_anim_state(m.playerIndex)
end)

costumes.PACKET_SET = "dressset"
costumes.PACKET_ASK = "dressask"
function wear_locally(key)
    OF.util.publish_row(0, ROW_KEY, key or "")

    OF.util.store(STORE_KEY, key or "")
end

function costumes.set_mine(choice)
    wear_locally(costumes.settled_choice(choice))
    return true
end

function costumes.set(localIndex, key)
    if key ~= nil and costumes.BY_KEY[key] == nil then
        return false, "There is no costume by that name."
    end

    if localIndex == 0 then
        if not OF.perms.can("costume_self") then
            return false, "Your rank cannot do that.", "costume_self"
        end

        costumes.set_mine(key == nil and NONE or key)

        if key ~= nil and costumes.blocked() then costumes.note_blocked() end
        return true
    end

    if not OF.perms.can("costume_other") then
        return false, "Your rank cannot do that.", "costume_other"
    end

    local globalIndex = network_global_index_from_local(localIndex)
    if globalIndex == nil then return false, "They are not here." end

    if not OF.util.is_host() then
        OF.util.send_to_host({
            ofp = costumes.PACKET_ASK,
            who = globalIndex,

            off = (key == nil) and 1 or 0,
            key = key or "off",
        })
        return true, "Asked the host."
    end

    if not OF.util.send_to_player(localIndex, {
        ofp = costumes.PACKET_SET,
        off = (key == nil) and 1 or 0,
        key = key or "off",
    }) then
        return false, "They are not here to tell."
    end
    return true
end

function costumes.forget_mine()
    OF.util.publish_row(0, ROW_KEY, "")
    OF.util.store(STORE_KEY, "")
    return true
end

function costumes.anyone_chose()
    for index = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[index]
        if np ~= nil and np.connected
            and costumes.mine_choice(index) ~= nil then
            return true
        end
    end
    return false
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= costumes.PACKET_SET then return end
    if not OF.util.from_host(data) then return end

    if data.clear == 1 then
        costumes.forget_mine()
        return
    end

    local key = data.key
    if data.off == 1 then key = nil end
    if key ~= nil and costumes.BY_KEY[key] == nil then return end

    costumes.set_mine(key == nil and NONE or key)

    if key == nil then
        OF.notify.show("The host took your costume off", "info", 5)
    else
        OF.notify.show("The host dressed you as @", "info", 5,
            costumes.BY_KEY[key].name)
    end
end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= costumes.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    if OF.perms.tier(asker) < OF.perms.required("costume_other", asker) then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    local target = OF.util.local_from_global(data.who)
    local may, whyNot = OF.util.may_act_on(asker, target)
    if not may then
        OF.util.tell_asker(askerGlobal, whyNot)
        return
    end

    local key = data.key
    if data.off == 1 then key = nil end
    local ok, why = costumes.set(target, key)
    if not ok then OF.util.tell_asker(askerGlobal, why) end
end)

hook_event(HOOK_ON_MODS_LOADED, function()

    load_favourites()
    rolling = mod_storage_load(ROLL_KEY, "") == "1"
    local stored = mod_storage_load(STORE_KEY, "")
    if stored == nil or stored == "" then return end

    if stored ~= NONE and costumes.BY_KEY[stored] == nil then return end

    if not OF.perms.can("costume_self") then return end

    costumes.set_mine(stored)
end)

local LOBBY_NEED = "costume_other"
local MINE_NEED = "costume_self"
local function press_lobby(key)
    if costumes.room_on(key) then
        OF.util.report(costumes.set_room(nil))
        return
    end
    OF.util.report(costumes.set_room(key))
end

local function press_mine(panel, key)
    local state = costumes.mine_state(0, key)
    local next = panel.next_mine(state, costumes.room_on(key))
    if next == true then
        OF.util.report(costumes.set(0, key))
        return
    end
    if next == false then
        OF.util.report(costumes.set(0, nil))
        return
    end
    OF.util.report(costumes.set_mine(nil))
end

local function row_column(marked, kept)
    local right = marked and OF.lang.t("(yours)") or nil
    if kept then
        right = (right ~= nil) and OF.lang.fill("kept @", right)
            or OF.lang.t("kept")
    end
    return right
end

local function mine_row(panel, built)
    panel.all_for_me({ built })
    return built
end

local function catalogue_row(panel, item)
    local room = costumes.room_on(item.key)
    local state = costumes.mine_state(0, item.key)
    local marked = panel.mine_marked(state)
    local built = panel.two_box({
        lobbyOn = room,

        mineBox = panel.mine_shown(state, room),
        name = item.name,
        lobbyNeed = LOBBY_NEED,
        mineNeed = MINE_NEED,
        r = 255, g = 255, b = 255,
        onLobby = function() press_lobby(item.key) end,
        onMine = function() press_mine(panel, item.key) end,
    })
    local right = row_column(marked, costumes.is_favourite(item.key))
    return panel.with_help(panel.level_right(built, right ~= nil, right),
        OF.lang.t("A dresses the lobby, Z dresses you - and yours wins"))
end

function costumes.build_page(panel)
    local rows = {}

    local localIndex = 0

    local worn = costumes.name_worn(localIndex)
    local mineWorn = costumes.mine_choice(localIndex) ~= nil
    if worn ~= nil then
        rows[#rows + 1] = panel.label_row(mineWorn
            and OF.lang.fill("Wearing: @ - your own choice.", worn)
            or OF.lang.fill("Wearing: @ - the lobby's.", worn))
        rows[#rows + 1] = mine_row(panel, panel.with_help(
            panel.gated_row(MINE_NEED, OF.lang.t("Take it off"),
                255, 200, 120, function()
                    OF.util.report(costumes.set(0, nil))
                end),
            OF.lang.t("your own face, whatever the lobby is wearing")))
    else
        rows[#rows + 1] = panel.label_row("Wearing: nothing - your own face.")
    end

    if costumes.room_any() then
        rows[#rows + 1] = panel.with_help(
            panel.gated_row(LOBBY_NEED,
                OF.lang.fill("Take the lobby's @ off everybody",
                    costumes.BY_KEY[costumes.room_key()].name),
                255, 200, 120, function()
                    OF.util.report(costumes.clear_room())
                end),
            OF.lang.t("everybody following the lobby goes back to their own face"))
    end

    rows[#rows + 1] = panel.label_row(
        "A costume reshapes your own Mario - your walk, your name tag, only you.")

    do
        local kind = costumes.facing_kind(0)

        local said = costumes.facing_level(0) or "Off"
        rows[#rows + 1] = mine_row(panel, panel.level_right(
            panel.with_help(panel.row(

                panel.tick(kind ~= nil,
                    OF.lang.t("Turn to face whoever is looking")),
                255, 255, 255, function()
                    OF.util.report(costumes.cycle_facing())
                end),
                OF.lang.t("your own model turns to the camera, on your screen only")),

            kind ~= nil, OF.lang.t(said)))

        rows[#rows + 1] = panel.label_row(
            "Upright is the trick the trees use - yawed, feet on the floor.")
        rows[#rows + 1] = panel.label_row(
            "Flat turns on every axis, so a slope lays you on your back.")
    end

    if costumes.blocked() then
        rows[#rows + 1] = panel.label_row(
            "Character Select is here, and this build of it has no way in.")
        rows[#rows + 1] = panel.label_row(
            "A costume is still saved here and comes back without that mod.")

    elseif costumes.round_hides() then
        rows[#rows + 1] = panel.label_row(
            "A round is on, so costumes are put away until it is over.")
        rows[#rows + 1] = panel.label_row(
            "Pick one now and you will be wearing it when the round ends.")
    end

    local kept = costumes.favourites()
    if #kept > 0 then
        rows[#rows + 1] = panel.header_row("Kept")
        for _, item in ipairs(kept) do
            rows[#rows + 1] = catalogue_row(panel, item)
        end
    end

    local wornKey = costumes.worn(localIndex)
    if wornKey ~= nil then
        local isFav = costumes.is_favourite(wornKey)
        rows[#rows + 1] = mine_row(panel, panel.with_help(
            panel.row(isFav and "Stop keeping this one" or "Keep this one",
                200, 200, 255, function()
                    local ok, added = costumes.toggle_favourite(wornKey)
                    if not ok then
                        OF.util.report(false, added)
                        return
                    end
                    panel.mark_dirty()
                end),
            isFav
                and "takes it off the short list at the top of this page"
                or "puts it on the short list at the top of this page"))
    elseif #kept > 0 then
        rows[#rows + 1] = panel.label_row(
            "Wear one and this page will offer to keep it.")
    end

    rows[#rows + 1] = panel.header_row("Pick one")

    rows[#rows + 1] = panel.with_help(panel.two_box({
        boxes = false,
        name = OF.lang.t("Surprise me"),
        lobbyNeed = LOBBY_NEED,
        mineNeed = MINE_NEED,
        r = 120, g = 255, b = 120,
        onLobby = function()
            OF.util.report(costumes.set_room(
                costumes.random_key(costumes.room_key())))
        end,
        onMine = function()
            OF.util.report(costumes.set(0, costumes.random_key(wornKey)))
        end,
    }), "one of the " .. costumes.count() .. ", and never the one already on")

    local function looked_at()
        local item = costumes.in_your_sights()
        if item == nil then
            OF.util.report(false,
                "Nothing in front of you that this page has a face for.")
            return nil
        end
        return item.key
    end
    rows[#rows + 1] = panel.with_help(panel.two_box({
        boxes = false,
        name = OF.lang.t("Be what you are looking at"),
        lobbyNeed = LOBBY_NEED,
        mineNeed = MINE_NEED,
        r = 120, g = 255, b = 120,
        onLobby = function()
            local key = looked_at()
            if key ~= nil then OF.util.report(costumes.set_room(key)) end
        end,
        onMine = function()
            local key = looked_at()
            if key ~= nil then OF.util.report(costumes.set(0, key)) end
        end,
    }), "the nearest thing ahead of you that is one of the "
        .. costumes.count())

    rows[#rows + 1] = mine_row(panel, panel.with_help(
        panel.with_right(
            panel.gated_row(MINE_NEED, "A different one every round",
                120, 255, 120, function()
                    costumes.set_rolling(not costumes.rolling())
                    panel.mark_dirty()
                end),
            costumes.rolling() and "on" or "off"),
        "when a round ends and yours comes back, it comes back different"))

    for _, group in ipairs(costumes.GROUPS) do
        rows[#rows + 1] = panel.with_help(
            panel.with_right(
                panel.row(group.name .. "...", 255, 255, 255, function()
                    panel.dressGroup = group.key
                    panel.go("costumeset")
                end),
                tostring(#group.items)),
            group.blurb)
    end

    rows[#rows + 1] = panel.back_row("fun")
    return rows
end

function costumes.build_group_page(panel)
    local group = costumes.group_of(panel.dressGroup) or costumes.GROUPS[1]
    local rows = {}
    if group == nil then
        rows[#rows + 1] = panel.label_row("This build has no costumes to offer.")
        rows[#rows + 1] = panel.back_row("costumes")
        return rows
    end

    rows[#rows + 1] = panel.label_row(
        group.name .. " - " .. group.blurb .. ".")
    rows[#rows + 1] = panel.label_row(OF.lang.t(
        "Left box the lobby, right box you - and yours wins."))

    for _, item in ipairs(group.items) do

        rows[#rows + 1] = catalogue_row(panel, item)
    end

    rows[#rows + 1] = panel.back_row("costumes")
    return rows
end
