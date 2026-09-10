OF = OF or {}
OF.hats = OF.hats or {}

local hats = OF.hats

local ROW_KEY = "ofHat"
hats.ROW_KEY = ROW_KEY

hats.SLOTS = 2
local SLOTS = hats.SLOTS
local SLOT_SEP = ";"
local SLOT_PATTERN = "[^;]+"
local NONE = "-"
hats.NONE = NONE

local ROOM_KEY = "ofRoomHats"
hats.ROOM_KEY = ROOM_KEY

local STORE_KEY = "hat"
local HEAD_MARK = 0x4F

local DEFAULT_LIFT = 62
local DEFAULT_SCALE = 1.0

local STACK_LIFT = 46
hats.STACK_LIFT = STACK_LIFT

local LIFT_MIN, LIFT_MAX, LIFT_STEP = -32, 96, 8
local TILT_MIN, TILT_MAX, TILT_STEP = -60, 60, 15
local PITCH_MIN, PITCH_MAX, PITCH_STEP = -60, 60, 15

hats.LIFT_STEPS = (LIFT_MAX - LIFT_MIN) // LIFT_STEP
hats.TILT_STEPS = (TILT_MAX - TILT_MIN) // TILT_STEP
hats.PITCH_STEPS = (PITCH_MAX - PITCH_MIN) // PITCH_STEP

hats.PITCH_WORDS = {
    [-60] = "Right back off the head",
    [-45] = "Well back",
    [-30] = "Pushed back",
    [-15] = "Back a touch",
    [0]   = "Level",
    [15]  = "Forward a touch",
    [30]  = "Down over the brow",
    [45]  = "Well down over the eyes",
    [60]  = "Right down over the eyes",
}

function hats.pitch_word(degrees)
    degrees = tonumber(degrees) or 0
    local word = hats.PITCH_WORDS[degrees]
    if word == nil then return tostring(degrees) end
    return OF.lang.t(word)
end

local FIT_KEY = "hatfit"
local function clamp_step(value, low, high, step)
    value = tonumber(value)
    if value == nil then return 0 end

    value = math.floor(value / step + 0.5) * step
    if value < low then return low end
    if value > high then return high end
    return value
end

local myLift = {}
local myTilt = {}
local myPitch = {}
for slot = 1, SLOTS do
    myLift[slot], myTilt[slot], myPitch[slot] = 0, 0, 0
end

local function read_fit(raw)
    if raw == nil or raw == "" then return nil, 0, 0, 0 end
    raw = tostring(raw)
    local key, lift, tilt, pitch =
        string.match(raw, "^([^|]+)|(-?%d+)|(-?%d+)|(-?%d+)$")
    if key == nil then
        key, lift, tilt = string.match(raw, "^([^|]+)|(-?%d+)|(-?%d+)$")
        pitch = 0
    end
    if key == nil then return raw, 0, 0, 0 end
    return key, clamp_step(lift, LIFT_MIN, LIFT_MAX, LIFT_STEP),
        clamp_step(tilt, TILT_MIN, TILT_MAX, TILT_STEP),
        clamp_step(pitch, PITCH_MIN, PITCH_MAX, PITCH_STEP)
end

local function write_fit(key, lift, tilt, pitch)
    if key == nil or key == "" then return "" end
    lift = lift or 0
    tilt = tilt or 0
    pitch = pitch or 0
    if lift == 0 and tilt == 0 and pitch == 0 then return key end
    if pitch == 0 then
        return key .. "|" .. tostring(lift) .. "|" .. tostring(tilt)
    end
    return key .. "|" .. tostring(lift) .. "|" .. tostring(tilt)
        .. "|" .. tostring(pitch)
end

hats.read_fit = read_fit
hats.write_fit = write_fit

local function read_row(raw, slot)
    if raw == nil or raw == "" then return nil, 0, 0, 0 end
    slot = slot or 1
    if slot < 1 or slot > SLOTS then return nil, 0, 0, 0 end
    local at = 1
    for part in string.gmatch(tostring(raw), SLOT_PATTERN) do
        if at == slot then return read_fit(part) end
        at = at + 1
        if at > SLOTS then break end
    end
    return nil, 0, 0, 0
end

local function read_row_all(raw)
    local out = {}
    for slot = 1, SLOTS do
        local key, lift, tilt, pitch = read_row(raw, slot)
        if key == nil or key == "" then break end
        out[#out + 1] = { key = key, lift = lift, tilt = tilt, pitch = pitch }
    end
    return out
end

local function write_row(entries)
    local parts = {}
    for slot = 1, SLOTS do
        local one = entries[slot]
        local text = (one ~= nil) and write_fit(one.key, one.lift, one.tilt,
            one.pitch) or ""
        if text == "" then break end
        parts[#parts + 1] = text
    end
    return table.concat(parts, SLOT_SEP)
end

hats.read_row = read_row
hats.write_row = write_row

local CATALOGUE = {

    {
        key = "caps", name = "Caps you wear",
        blurb = "every cap the game has, worn in your own colours",
        items = {

            { key = "cap",       name = "Cap",               model = E_MODEL_MARIOS_CAP },
            { key = "wingcap",   name = "Wing cap",          model = E_MODEL_MARIOS_WING_CAP },
            { key = "metalcap",  name = "Metal cap",         model = E_MODEL_MARIOS_METAL_CAP },
            { key = "wingmetal", name = "Winged metal cap",  model = E_MODEL_MARIOS_WINGED_METAL_CAP },
            { key = "luigicap",  name = "Luigi's cap",       model = E_MODEL_LUIGIS_CAP },
            { key = "luigiwing", name = "Luigi's wing cap",  model = E_MODEL_LUIGIS_WING_CAP },
            { key = "luigimetal", name = "Luigi's metal cap", model = E_MODEL_LUIGIS_METAL_CAP },
            { key = "luigiwingmetal", name = "Luigi's winged metal cap",
              model = E_MODEL_LUIGIS_WINGED_METAL_CAP },

            { key = "toadcap",   name = "Toad's cap",        model = E_MODEL_TOADS_CAP,
              scale = 0.90 },
            { key = "toadwing",  name = "Toad's wing cap",   model = E_MODEL_TOADS_WING_CAP,
              scale = 0.90 },
            { key = "toadmetal", name = "Toad's metal cap",  model = E_MODEL_TOADS_METAL_CAP,
              scale = 0.90 },
            { key = "waluigicap", name = "Waluigi's cap",    model = E_MODEL_WALUIGIS_CAP },
            { key = "waluigiwing", name = "Waluigi's wing cap",
              model = E_MODEL_WALUIGIS_WING_CAP },
            { key = "waluigimetal", name = "Waluigi's metal cap",
              model = E_MODEL_WALUIGIS_METAL_CAP },
            { key = "waluigiwingmetal", name = "Waluigi's winged metal cap",
              model = E_MODEL_WALUIGIS_WINGED_METAL_CAP },
            { key = "wariocap",  name = "Wario's cap",       model = E_MODEL_WARIOS_CAP },
            { key = "wariowing", name = "Wario's wing cap",  model = E_MODEL_WARIOS_WING_CAP },
            { key = "wariometal", name = "Wario's metal cap", model = E_MODEL_WARIOS_METAL_CAP },
            { key = "wariowingmetal", name = "Wario's winged metal cap",
              model = E_MODEL_WARIOS_WINGED_METAL_CAP },
        },
    },

    {
        key = "heroes", name = "Heroes",
        blurb = "the five of them, head-high, moving the way you move",
        items = {

            { key = "hmario",   name = "Mario",   model = E_MODEL_MARIO,
              scale = 0.38, lift = 64, mimic = true },
            { key = "hluigi",   name = "Luigi",   model = E_MODEL_LUIGI,
              scale = 0.38, lift = 64, mimic = true },
            { key = "htoad",    name = "Toad",    model = E_MODEL_TOAD_PLAYER,
              scale = 0.38, lift = 64, mimic = true },
            { key = "hwaluigi", name = "Waluigi", model = E_MODEL_WALUIGI,
              scale = 0.38, lift = 64, mimic = true },
            { key = "hwario",   name = "Wario",   model = E_MODEL_WARIO,
              scale = 0.38, lift = 64, mimic = true },
        },
    },

    {
        key = "helmets", name = "Helmets",
        blurb = "shells and domes - worn on the head, not balanced on it",
        items = {

            { key = "shell",    name = "Shell",          model = E_MODEL_KOOPA_SHELL,
              scale = 0.72, lift = 54 },

            { key = "spiky",    name = "Spiked shell",   model = E_MODEL_SPINY_BALL,
              scale = 0.60, lift = 56 },

            { key = "bubble",   name = "Bubble",         model = E_MODEL_WATER_BOMB,
              scale = 0.42, lift = 58 },

            { key = "clam",     name = "Clam shell",     model = E_MODEL_CLAM_SHELL,
              scale = 0.55, lift = 54 },

            { key = "snufit",   name = "Snufit mask",    model = E_MODEL_SNUFIT,
              scale = 0.50, lift = 58 },

        },
    },

    {
        key = "over", name = "Over your head",
        blurb = "marks, not hats - they float rather than sit",
        items = {

            { key = "star",      name = "Star",         model = E_MODEL_STAR,
              scale = 0.80, lift = 118 },

            { key = "dizzy",     name = "Seeing stars", model = E_MODEL_CARTOON_STAR,
              scale = 0.90, lift = 104 },

            { key = "ghoststar", name = "Ghost star",   model = E_MODEL_TRANSPARENT_STAR,
              scale = 0.80, lift = 118 },

            { key = "boo",       name = "Boo",          model = E_MODEL_BOO,
              scale = 0.45, lift = 132 },

            { key = "key",       name = "Key",          model = E_MODEL_BOWSER_KEY,
              scale = 0.55, lift = 112 },

            { key = "ring",      name = "Water ring",   model = E_MODEL_WATER_RING,
              scale = 0.75, lift = 116 },
        },
    },

    {
        key = "silly", name = "Silly",
        blurb = "a stretch, and they know it",
        items = {

            { key = "crate",   name = "Small crate", model = E_MODEL_BREAKABLE_BOX_SMALL,
              scale = 0.50, lift = 62 },

            { key = "sack",    name = "Money bag",   model = E_MODEL_MONEYBAG,
              scale = 0.60, lift = 60 },

            { key = "metalbox", name = "Metal box",   model = E_MODEL_METAL_BOX,
              scale = 0.42, lift = 64 },

            { key = "exbox",   name = "Question box", model = E_MODEL_EXCLAMATION_BOX,
              scale = 0.45, lift = 66 },

            { key = "thwomp",  name = "Thwomp",      model = E_MODEL_THWOMP,
              scale = 0.30, lift = 70 },

            { key = "book",    name = "Book",        model = E_MODEL_BOOKEND,
              scale = 0.85, lift = 58 },

            { key = "chestlid", name = "Chest lid",  model = E_MODEL_TREASURE_CHEST_LID,
              scale = 0.50, lift = 56 },

            { key = "cannon",  name = "Cannon barrel", model = E_MODEL_CANNON_BARREL,
              scale = 0.35, lift = 60 },

            { key = "chair",   name = "Haunted chair", model = E_MODEL_HAUNTED_CHAIR,
              scale = 0.45, lift = 60 },
            { key = "spring",  name = "Springboard",  model = E_MODEL_TRAMPOLINE,
              scale = 0.32, lift = 58 },
            { key = "cannonbase", name = "Cannon base", model = E_MODEL_CANNON_BASE,
              scale = 0.30, lift = 58 },
        },
    },

    {
        key = "creatures", name = "Creatures",
        blurb = "something small, sitting on your head",
        items = {

            { key = "goomba",   name = "Goomba",       model = E_MODEL_GOOMBA,
              scale = 0.45, lift = 60 },
            { key = "bobomb",   name = "Bob-omb",      model = E_MODEL_BLACK_BOBOMB,
              scale = 0.55, lift = 58 },

            { key = "buddy",    name = "Bob-omb Buddy", model = E_MODEL_BOBOMB_BUDDY,
              scale = 0.55, lift = 58 },
            { key = "spiny",    name = "Spiny",        model = E_MODEL_SPINY,
              scale = 0.45, lift = 58 },
            { key = "monty",    name = "Monty Mole",   model = E_MODEL_MONTY_MOLE,
              scale = 0.50, lift = 58 },
            { key = "ukiki",    name = "Ukiki",        model = E_MODEL_UKIKI,
              scale = 0.45, lift = 58 },
            { key = "mips",     name = "Mips",         model = E_MODEL_MIPS,
              scale = 0.48, lift = 58 },
            { key = "penguin",  name = "Baby penguin", model = E_MODEL_PENGUIN,
              scale = 0.34, lift = 60 },
            { key = "spindrift", name = "Spindrift",   model = E_MODEL_SPINDRIFT,
              scale = 0.38, lift = 60 },
            { key = "swoop",    name = "Swoop",        model = E_MODEL_SWOOP,
              scale = 0.55, lift = 66 },
            { key = "scuttle",  name = "Scuttlebug",   model = E_MODEL_SCUTTLEBUG,
              scale = 0.40, lift = 58 },
            { key = "amp",      name = "Amp",          model = E_MODEL_AMP,
              scale = 0.48, lift = 66 },
            { key = "flyguy",   name = "Fly Guy",      model = E_MODEL_FLYGUY,
              scale = 0.34, lift = 68 },

            { key = "blizzard", name = "Mr. Blizzard", model = E_MODEL_MR_BLIZZARD,
              scale = 0.28, lift = 60 },
        },
    },

    {
        key = "absurd", name = "Far too big",
        blurb = "a boss, or a piece of the level, shrunk until it fits",
        items = {
            { key = "whomp",    name = "Whomp",        model = E_MODEL_WHOMP,
              scale = 0.22, lift = 64 },
            { key = "chuckya",  name = "Chuckya",      model = E_MODEL_CHUCKYA,
              scale = 0.30, lift = 62 },
            { key = "bully",    name = "Bully",        model = E_MODEL_BULLY,
              scale = 0.32, lift = 60 },
            { key = "piano",    name = "Mad Piano",    model = E_MODEL_MAD_PIANO,
              scale = 0.24, lift = 62 },
            { key = "lakitu",   name = "Lakitu",       model = E_MODEL_LAKITU,
              scale = 0.28, lift = 70 },
            { key = "klepto",   name = "Klepto",       model = E_MODEL_KLEPTO,
              scale = 0.24, lift = 70 },
            { key = "hoot",     name = "Hoot",         model = E_MODEL_HOOT,
              scale = 0.26, lift = 72 },

            { key = "bullet",   name = "Bullet Bill",  model = E_MODEL_BULLET_BILL,
              scale = 0.20, lift = 62 },
            { key = "manta",    name = "Manta ray",    model = E_MODEL_MANTA_RAY,
              scale = 0.18, lift = 66 },
            { key = "sushi",    name = "Sushi",        model = E_MODEL_SUSHI,
              scale = 0.20, lift = 64 },

            { key = "unagi",    name = "Unagi",        model = E_MODEL_UNAGI,
              scale = 0.14, lift = 62 },
            { key = "koopa",    name = "Koopa",        model = E_MODEL_KOOPA_WITH_SHELL,
              scale = 0.30, lift = 60 },
            { key = "wiggler",  name = "Wiggler's head", model = E_MODEL_WIGGLER_HEAD,
              scale = 0.28, lift = 62 },

            { key = "chest",    name = "Treasure chest", model = E_MODEL_TREASURE_CHEST_BASE,
              scale = 0.26, lift = 58 },
        },
    },
}

hats.GROUPS = {}
hats.BY_KEY = {}
hats.LIST = {}

for _, group in ipairs(CATALOGUE) do
    local kept = {}
    for _, item in ipairs(group.items) do
        if type(item.model) == "number" and item.model > 0 then
            item.group = group.key
            item.lift = item.lift or DEFAULT_LIFT
            item.scale = item.scale or DEFAULT_SCALE
            kept[#kept + 1] = item
            hats.BY_KEY[item.key] = item
            hats.LIST[#hats.LIST + 1] = item
        end
    end
    if #kept > 0 then
        hats.GROUPS[#hats.GROUPS + 1] = {
            key = group.key, name = group.name, blurb = group.blurb, items = kept,
        }
    end
end

function hats.count()
    return #hats.LIST
end

function hats.group_of(key)
    for _, group in ipairs(hats.GROUPS) do
        if group.key == key then return group end
    end
    return nil
end

function hats.find(text)
    if text == nil then return nil end
    local needle = string.lower(tostring(text))
    if needle == "" then return nil end
    if hats.BY_KEY[needle] ~= nil then return hats.BY_KEY[needle] end
    for _, item in ipairs(hats.LIST) do
        if string.lower(item.name) == needle then return item end
    end
    return nil
end

function hats.random_key(notThis)
    local n = #hats.LIST
    if n == 0 then return nil end
    local taken = {}
    if type(notThis) == "table" then
        for _, key in ipairs(notThis) do taken[key] = true end
    elseif notThis ~= nil then
        taken[notThis] = true
    end

    local free = 0
    for _, item in ipairs(hats.LIST) do
        if not taken[item.key] then free = free + 1 end
    end
    if free == 0 then return hats.LIST[math.random(n)].key end

    for _ = 1, 12 do
        local key = hats.LIST[math.random(n)].key
        if not taken[key] then return key end
    end

    local want = math.random(free)
    for _, item in ipairs(hats.LIST) do
        if not taken[item.key] then
            want = want - 1
            if want <= 0 then return item.key end
        end
    end
    return hats.LIST[math.random(n)].key
end

function hats.room_row()
    local row = gGlobalSyncTable[ROOM_KEY]
    if row == nil then return "" end
    return tostring(row)
end

function hats.room_keys()
    local out = {}
    for _, one in ipairs(read_row_all(hats.room_row())) do
        if hats.BY_KEY[one.key] ~= nil then out[#out + 1] = one.key end
    end
    return out
end

function hats.room_on(key)
    if key == nil then return false end
    for _, one in ipairs(hats.room_keys()) do
        if one == key then return true end
    end
    return false
end

function hats.room_any()
    return #hats.room_keys() > 0
end

local roomRegistered = false

local function register_room_action()
    if roomRegistered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    roomRegistered = true

    OF.net.register_action("roomhats", "costume_other",
        function(_, _, _, row)
            if not OF.util.is_host() then return false, "Only the host." end
            return hats.write_room(tostring(row or ""))
        end)
end

function hats.write_room(row)
    local entries = {}
    for _, one in ipairs(read_row_all(row or "")) do
        if hats.BY_KEY[one.key] ~= nil and #entries < SLOTS then

            entries[#entries + 1] = { key = one.key, lift = 0, tilt = 0,
                pitch = 0 }
        end
    end
    if not OF.util.publish(ROOM_KEY, write_row(entries)) then
        return false, "The lobby would not take that."
    end
    return true
end

function hats.set_room(row)
    if not OF.perms.can("costume_other") then
        return false, "Your rank cannot set the lobby's hats. ("
            .. OF.perms.tier_name(OF.perms.required("costume_other")) .. "+)"
    end
    register_room_action()
    if OF.util.asks(OF.net, "host_does") then
        return OF.net.host_does("roomhats", 0, 0, row or "")
    end
    if not OF.util.is_host() then
        return false, "No host to ask yet - try again in a second."
    end
    return hats.write_room(row)
end

function hats.press_room(key)
    if key == nil or hats.BY_KEY[key] == nil then
        return false, "There is no hat by that name."
    end
    local keys = hats.room_keys()
    local at = nil
    for slot, one in ipairs(keys) do
        if one == key then at = slot end
    end
    if at ~= nil then
        table.remove(keys, at)
    elseif #keys < SLOTS then
        keys[#keys + 1] = key
    else
        keys[SLOTS] = key
    end
    local entries = {}
    for slot, one in ipairs(keys) do
        entries[slot] = { key = one, lift = 0, tilt = 0, pitch = 0 }
    end
    return hats.set_room(write_row(entries))
end

function hats.clear_room()
    return hats.set_room("")
end

function hats.settled_row(row)
    if row == nil or row == "" then return nil end
    row = tostring(row)
    local roomKeys = hats.room_keys()
    if row == NONE then

        if #roomKeys == 0 then return nil end
        return NONE
    end
    local mine = read_row_all(row)
    if #mine ~= #roomKeys then return row end
    for at = 1, #mine do
        local one = mine[at]
        if one.key ~= roomKeys[at] then return row end
        if one.lift ~= 0 or one.tilt ~= 0 or one.pitch ~= 0 then return row end
    end
    return nil
end

function hats.worn(localIndex, slot)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return nil end
    local raw = s[ROW_KEY]
    if raw == nil or raw == "" then raw = hats.room_row() end
    local key = read_row(raw, slot or 1)
    if key == nil or key == "" then return nil end
    if hats.BY_KEY[key] == nil then return nil end
    return key
end

function hats.mine_choice(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return nil end
    local raw = s[ROW_KEY]
    if raw == nil or raw == "" then return nil end
    return hats.settled_row(raw)
end

function hats.mine_state(localIndex, key)
    if hats.mine_choice(localIndex) == nil then return nil end
    if hats.slot_of_key(localIndex, key) ~= nil then return true end
    if hats.room_on(key) then return false end
    return nil
end

function hats.worn_all(localIndex)
    local out = {}
    for slot = 1, SLOTS do
        local key = hats.worn(localIndex, slot)
        if key == nil then break end
        out[#out + 1] = key
    end
    return out
end

function hats.fit(localIndex, slot)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return 0, 0, 0 end
    local key, lift, tilt, pitch = read_row(s[ROW_KEY], slot or 1)
    if key == nil then return 0, 0, 0 end
    return lift, tilt, pitch
end

function hats.my_fit(slot)
    slot = slot or 1
    return myLift[slot] or 0, myTilt[slot] or 0, myPitch[slot] or 0
end

function hats.name_worn(localIndex, slot)
    local key = hats.worn(localIndex, slot)
    if key == nil then return nil end
    return hats.BY_KEY[key].name
end

function hats.head_is_covered(localIndex)
    if not OF.util.asks(OF.costumes, "head_is_covered") then return false end
    return OF.costumes.head_is_covered(localIndex) == true
end

local function mark_head(node, depth)
    if node == nil then return nil end
    if depth > 12 then return nil end

    local first = node
    local at = node
    while at ~= nil do
        if at.type == GRAPH_NODE_TYPE_ROTATION then
            local child = at.children
            if child ~= nil and child.type == GRAPH_NODE_TYPE_ANIMATED_PART then
                local check = child.children
                if check ~= nil and check.type == GRAPH_NODE_TYPE_DISPLAY_LIST then
                    check = check.next
                end
                if check ~= nil and check.type == GRAPH_NODE_TYPE_ANIMATED_PART then
                    return check
                end
            end
        end

        if at.children ~= nil then
            local found = mark_head(at.children, depth + 1)
            if found ~= nil then return found end
        end

        at = at.next
        if at == nil or at == first then break end
    end
    return nil
end

local headMat = {}

local headFrame = {}

local borrowed = {}

hats.headMat = headMat

local camInvFrame = -1
local camInv = nil

local function camera_inverse()
    local frame = get_global_timer()
    if camInv ~= nil and camInvFrame == frame then return camInv end
    local m = gMarioStates[0]
    if m == nil or m.area == nil or m.area.camera == nil then return nil end

    if m.area.camera.mtx == nil then return nil end
    local out = gMat4Zero()
    mtxf_inverse(out, m.area.camera.mtx)
    camInv = out
    camInvFrame = frame
    return camInv
end

local function on_geo_process(graphNode, matStackIndex)
    if graphNode == nil then return end
    if graphNode.hookProcess ~= HEAD_MARK then return end

    local m = geo_get_mario_state()
    if m == nil then return end

    if OF.util.flag(m.marioBodyState.mirrorMario) == 1 then return end

    local inverse = camera_inverse()
    if inverse == nil then return end

    local out = gMat4Zero()
    mtxf_mul(out, gMatStack[matStackIndex], inverse)
    headMat[m.playerIndex] = out
    headFrame[m.playerIndex] = get_global_timer()
end

local mine = {}

local mineKey = {}

local mineUp = {}
local mineKeyUp = {}

local SLOT_OBJECTS = { mine, mineUp }
local SLOT_KEYS = { mineKey, mineKeyUp }

hats.objects = mine
hats.slot_objects = SLOT_OBJECTS

local function slot_of(o, localIndex)
    for slot = 1, SLOTS do
        if SLOT_OBJECTS[slot][localIndex] == o then return slot end
    end
    return nil
end

local function hat_init(o)
    if o == nil then return end

    o.oInteractType = 0
    o.oIntangibleTimer = -1
    o.oCollisionDistance = 0

    o.oAnimState = 0

    o.hookRender = 1
end

local function drop(localIndex, slot)
    if slot == nil then
        local any = false
        for one = 1, SLOTS do
            if drop(localIndex, one) then any = true end
        end
        return any
    end

    local o = SLOT_OBJECTS[slot][localIndex]
    SLOT_OBJECTS[slot][localIndex] = nil
    SLOT_KEYS[slot][localIndex] = nil

    local bare = true
    for one = 1, SLOTS do
        if SLOT_OBJECTS[one][localIndex] ~= nil then bare = false end
    end
    if bare then
        headMat[localIndex] = nil
        headFrame[localIndex] = nil
        borrowed[localIndex] = nil
    end

    if o == nil then return false end
    if o.activeFlags ~= 0 then obj_mark_for_deletion(o) end
    return true
end

hats.drop = drop

local function forget_all()
    for i = 0, MAX_PLAYERS - 1 do
        for slot = 1, SLOTS do
            SLOT_OBJECTS[slot][i] = nil
            SLOT_KEYS[slot][i] = nil
        end
        headMat[i] = nil
        headFrame[i] = nil
        borrowed[i] = nil
    end
end

hats.forget_all = forget_all

function hats.round_hides()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down()
end

function hats.in_force(localIndex, slot)
    if hats.round_hides() then return nil end
    return hats.worn(localIndex, slot or 1)
end

local function should_wear(localIndex, slot)

    if hats.in_force(localIndex, slot or 1) == nil then return false end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false end
    local m = gMarioStates[localIndex]
    if m == nil or m.marioObj == nil then return false end
    if is_player_active(m) == 0 then return false end
    if OF.util.asks(OF.possess, "hides_from_world")
        and OF.possess.hides_from_world(localIndex) then
        return false
    end
    local me = gNetworkPlayers[0]
    if me ~= nil and np.currAreaIndex ~= me.currAreaIndex then return false end
    if me ~= nil and np.currLevelNum ~= me.currLevelNum then return false end
    return true
end

hats.should_wear = should_wear

local function keep_in_step()
    for i = 0, MAX_PLAYERS - 1 do
    for slot = 1, SLOTS do
        local objects, keys = SLOT_OBJECTS[slot], SLOT_KEYS[slot]
        local want = should_wear(i, slot)
        local have = objects[i]

        if have ~= nil and have.activeFlags == 0 then
            objects[i] = nil
            keys[i] = nil
            have = nil
        end

        local key = hats.worn(i, slot)
        if have ~= nil and key ~= nil and keys[i] ~= key then
            drop(i, slot)
            have = nil
        end

        if want and have == nil then
            local entry = hats.BY_KEY[key]
            local m = gMarioStates[i]
            local o = spawn_non_sync_object(hats.BEHAVIOUR, entry.model,
                m.pos.x, m.pos.y, m.pos.z, hat_init)
            if o ~= nil then

                o.globalPlayerIndex = network_global_index_from_local(i)
                objects[i] = o
                keys[i] = key
            end
        elseif not want and have ~= nil then
            drop(i, slot)
        end
    end
    end
end

hats.keep_in_step = keep_in_step

local function hat_loop(o)
    if o == nil then return end
    local i = OF.util.local_from_global(o.globalPlayerIndex)

    local slot = (i ~= nil) and slot_of(o, i) or nil
    if i == nil or slot == nil or not should_wear(i, slot) then

        obj_mark_for_deletion(o)
        if i ~= nil and slot ~= nil then drop(i, slot) end
        return
    end

    local m = gMarioStates[i]
    local mGfx = m.marioObj.header.gfx
    local oGfx = o.header.gfx

    oGfx.node.flags = mGfx.node.flags

    o.oOpacity = 255
    if (m.marioBodyState.modelState & MODEL_STATE_NOISE_ALPHA) ~= 0 then
        o.oOpacity = 128
    end

    local wornKey = SLOT_KEYS[slot][i]
    local entry = wornKey ~= nil and hats.BY_KEY[wornKey] or nil
    if entry ~= nil and entry.mimic and mGfx.animInfo ~= nil
        and oGfx.animInfo ~= nil then
        local from, to = mGfx.animInfo, oGfx.animInfo
        to.curAnim = from.curAnim
        to.animID = from.animID
        to.animFrame = from.animFrame
        to.animFrameAccelAssist = from.animFrameAccelAssist
        to.animAccel = from.animAccel
        to.animYTrans = from.animYTrans
        to.animTimer = from.animTimer
    end

    if o.hookRender ~= 1 then o.hookRender = 1 end

    local head = mark_head(mGfx.sharedChild, 0)
    if head == nil then
        borrowed[i] = nil
    elseif head.hookProcess == 0 then
        head.hookProcess = HEAD_MARK
        borrowed[i] = nil
    elseif head.hookProcess ~= HEAD_MARK then
        borrowed[i] = true
    else
        borrowed[i] = nil
    end
end

local FRESH = 2

local function fresh_matrix(localIndex)
    local mat = headMat[localIndex]
    if mat == nil then return nil end
    local when = headFrame[localIndex] or -1
    if get_global_timer() - when > FRESH then return nil end
    return mat
end

hats.fresh_matrix = fresh_matrix

local function bone_to_model(mat)
    if mat == nil then return nil end
    return {
        m00 = mat.m20, m01 = mat.m21, m02 = mat.m22, m03 = mat.m23,
        m10 = mat.m00, m11 = mat.m01, m12 = mat.m02, m13 = mat.m03,
        m20 = mat.m10, m21 = mat.m11, m22 = mat.m12, m23 = mat.m13,
        m30 = mat.m30, m31 = mat.m31, m32 = mat.m32, m33 = mat.m33,
    }
end

hats.bone_to_model = bone_to_model

local function angles_from(mat)
    local ux, uy, uz = mat.m10, mat.m11, mat.m12
    local scale = math.sqrt(ux * ux + uy * uy + uz * uz)
    if scale < 0.0001 then return nil end

    local sx = -mat.m21 / scale
    if sx > 1 then sx = 1 elseif sx < -1 then sx = -1 end

    local pitch = radians_to_sm64(math.asin(sx))
    local yaw = radians_to_sm64(math.atan(mat.m20, mat.m22))
    local roll = radians_to_sm64(math.atan(mat.m01, mat.m11))
    return pitch, yaw, roll, scale
end

hats.angles_from = angles_from

local function tilt_units(degrees)
    if degrees == nil or degrees == 0 then return 0 end
    local units = math.floor(degrees * 65536 / 360 + 0.5) % 65536
    if units >= 32768 then units = units - 65536 end
    return units
end

local function wrap_angle(units)
    units = units % 65536
    if units >= 32768 then units = units - 65536 end
    return units
end

local function place_hat(o)
    if o == nil then return end
    if obj_has_behavior_id(o, hats.BEHAVIOUR) == 0 then return end

    local i = OF.util.local_from_global(o.globalPlayerIndex)
    if i == nil then return end
    local slot = slot_of(o, i)
    if slot == nil then return end
    local key = hats.worn(i, slot)
    if key == nil then return end
    local entry = hats.BY_KEY[key]
    local m = gMarioStates[i]
    if m == nil or m.marioObj == nil then return end

    local fitLift, fitTilt, fitPitch = hats.fit(i, slot)
    local tilted = tilt_units(fitTilt)
    local pitched = tilt_units(fitPitch)

    local oGfx = o.header.gfx
    local mGfx = m.marioObj.header.gfx
    local worn = entry.scale * (mGfx.scale.y ~= 0 and mGfx.scale.y or 1)
    oGfx.scale.x = worn
    oGfx.scale.y = worn
    oGfx.scale.z = worn

    local mat = bone_to_model(fresh_matrix(i))
    if mat ~= nil then
        local pitch, yaw, roll, scale = angles_from(mat)
        if pitch ~= nil then
            oGfx.angle.x = pitch
            oGfx.angle.y = yaw
            oGfx.angle.z = roll

            local lift = entry.lift + fitLift + STACK_LIFT * (slot - 1)
            oGfx.pos.x = mat.m30 + lift * mat.m10 / scale * worn
            oGfx.pos.y = mat.m31 + lift * mat.m11 / scale * worn
            oGfx.pos.z = mat.m32 + lift * mat.m12 / scale * worn
            roll = wrap_angle(roll + tilted)
            oGfx.angle.z = roll

            pitch = wrap_angle(pitch + pitched)
            oGfx.angle.x = pitch
            o.oPosX, o.oPosY, o.oPosZ = oGfx.pos.x, oGfx.pos.y, oGfx.pos.z
            o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll = pitch, yaw, roll
            return
        end
    end

    local body = m.marioBodyState
    local stamp = body ~= nil and body.updateHeadPosTime or nil
    if type(stamp) == "number" and body.headPos ~= nil
        and get_global_timer() - stamp <= FRESH then
        oGfx.pos.x = body.headPos.x
        oGfx.pos.y = body.headPos.y
            + (entry.lift + fitLift + STACK_LIFT * (slot - 1)) * worn
        oGfx.pos.z = body.headPos.z
    else

        oGfx.pos.x = mGfx.pos.x
        oGfx.pos.y = mGfx.pos.y + (m.marioObj.hitboxHeight * worn)
            + STACK_LIFT * (slot - 1) * worn
        oGfx.pos.z = mGfx.pos.z
    end

    oGfx.angle.x = pitched
    oGfx.angle.z = tilted
    oGfx.angle.y = mGfx.angle.y
    o.oPosX, o.oPosY, o.oPosZ = oGfx.pos.x, oGfx.pos.y, oGfx.pos.z
    o.oFaceAnglePitch, o.oFaceAngleYaw, o.oFaceAngleRoll =
        pitched, oGfx.angle.y, tilted
end

hats.place_hat = place_hat

function hats.on_the_head(localIndex)
    if borrowed[localIndex] then return false end
    return fresh_matrix(localIndex) ~= nil
end

function hats.sits_on_a_head(localIndex)
    if fresh_matrix(localIndex) ~= nil then return true end
    local m = gMarioStates[localIndex]
    local body = m ~= nil and m.marioBodyState or nil
    local stamp = body ~= nil and body.updateHeadPosTime or nil
    if type(stamp) ~= "number" or body.headPos == nil then return false end
    return get_global_timer() - stamp <= FRESH
end

hats.PACKET_SET = "hatset"
hats.PACKET_ASK = "hatask"
function hats.slot_of_key(localIndex, key)
    if key == nil then return nil end
    for slot = 1, SLOTS do
        if hats.worn(localIndex, slot) == key then return slot end
    end
    return nil
end

function hats.free_slot(localIndex)
    for slot = 1, SLOTS do
        if hats.worn(localIndex, slot) == nil then return slot end
    end
    return nil
end

local function slide_down(entries, slot)
    table.remove(entries, slot)
    for one = slot, SLOTS - 1 do
        myLift[one], myTilt[one], myPitch[one] =
            myLift[one + 1], myTilt[one + 1], myPitch[one + 1]
    end
    myLift[SLOTS], myTilt[SLOTS], myPitch[SLOTS] = 0, 0, 0
end

local function my_entries()
    local raw = gPlayerSyncTable[0] ~= nil and gPlayerSyncTable[0][ROW_KEY]
        or nil
    if raw == NONE then return {} end
    if raw ~= nil and raw ~= "" then return read_row_all(raw) end
    return read_row_all(hats.room_row())
end

local function wear_locally(key, slot)
    slot = slot or 1
    local entries = my_entries()

    if key == nil then
        if entries[slot] ~= nil then slide_down(entries, slot) end
    else

        if slot > #entries + 1 then slot = #entries + 1 end

        entries[slot] = { key = key, lift = myLift[slot], tilt = myTilt[slot],
            pitch = myPitch[slot] }
    end

    local row = write_row(entries)
    if row == "" then row = NONE end
    row = hats.settled_row(row) or ""
    OF.util.publish_row(0, ROW_KEY, row)

    OF.util.store(STORE_KEY, row)
end

local function fit_store()
    local parts = {}
    for slot = 1, SLOTS do
        parts[slot] = myLift[slot] .. "," .. myTilt[slot] .. "," .. myPitch[slot]
    end
    return table.concat(parts, SLOT_SEP)
end

function hats.set_fit(lift, tilt, pitch, slot)
    if not OF.perms.can("costume_self") then
        return false, "Your rank cannot do that.", "costume_self"
    end
    slot = slot or 1
    if slot < 1 or slot > SLOTS then return false, "There is no such slot." end
    myLift[slot] = clamp_step(lift, LIFT_MIN, LIFT_MAX, LIFT_STEP)
    myTilt[slot] = clamp_step(tilt, TILT_MIN, TILT_MAX, TILT_STEP)

    myPitch[slot] = clamp_step(pitch, PITCH_MIN, PITCH_MAX, PITCH_STEP)
    OF.util.store(FIT_KEY, fit_store())

    local entries = my_entries()
    for one = 1, #entries do
        entries[one].lift = myLift[one]
        entries[one].tilt = myTilt[one]
        entries[one].pitch = myPitch[one]
    end

    if #entries == 0 then return true end
    OF.util.publish_row(0, ROW_KEY, hats.settled_row(write_row(entries)) or "")
    return true
end

function hats.fit_steps(slot)
    slot = slot or 1
    return (myLift[slot] - LIFT_MIN) // LIFT_STEP,
        (myTilt[slot] - TILT_MIN) // TILT_STEP,
        (myPitch[slot] - PITCH_MIN) // PITCH_STEP
end

function hats.set_lift_step(step, slot)
    slot = slot or 1
    return hats.set_fit(LIFT_MIN + (tonumber(step) or 0) * LIFT_STEP,
        myTilt[slot], myPitch[slot], slot)
end

function hats.set_tilt_step(step, slot)
    slot = slot or 1
    return hats.set_fit(myLift[slot],
        TILT_MIN + (tonumber(step) or 0) * TILT_STEP, myPitch[slot], slot)
end

function hats.set_pitch_step(step, slot)
    slot = slot or 1
    return hats.set_fit(myLift[slot], myTilt[slot],
        PITCH_MIN + (tonumber(step) or 0) * PITCH_STEP, slot)
end

function hats.pitch_now_word(slot)
    return hats.pitch_word(myPitch[slot or 1])
end

function hats.set(localIndex, key, slot)
    if key ~= nil and hats.BY_KEY[key] == nil then
        return false, "There is no hat by that name."
    end
    slot = slot or 1
    if slot < 1 or slot > SLOTS then return false, "There is no such slot." end

    if localIndex == 0 then
        if not OF.perms.can("costume_self") then
            return false, "Your rank cannot do that.", "costume_self"
        end
        wear_locally(key, slot)
        return true
    end

    if not OF.perms.can("costume_other") then
        return false, "Your rank cannot do that.", "costume_other"
    end

    local globalIndex = network_global_index_from_local(localIndex)
    if globalIndex == nil then return false, "They are not here." end

    if not OF.util.is_host() then
        OF.util.send_to_host({
            ofp = hats.PACKET_ASK,
            who = globalIndex,

            off = (key == nil) and 1 or 0,
            key = key or "off",
            slot = slot,
        })
        return true, "Asked the host."
    end

    if not OF.util.send_to_player(localIndex, {
        ofp = hats.PACKET_SET,
        off = (key == nil) and 1 or 0,
        key = key or "off",
        slot = slot,
    }) then
        return false, "They are not here to tell."
    end
    return true
end

function hats.forget_mine()
    OF.util.publish_row(0, ROW_KEY, "")
    OF.util.store(STORE_KEY, "")
    return true
end

function hats.anyone_chose()
    for index = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[index]
        if np ~= nil and np.connected
            and hats.mine_choice(index) ~= nil then
            return true
        end
    end
    return false
end

local function on_hat_set(data)
    if data == nil or data.ofp ~= hats.PACKET_SET then return end
    if not OF.util.from_host(data) then return end

    if data.clear == 1 then
        hats.forget_mine()
        return
    end

    local key = (data.off == 1) and nil or data.key
    if key ~= nil and hats.BY_KEY[key] == nil then return end

    local slot = tonumber(data.slot) or 1
    if slot < 1 or slot > SLOTS then return end
    wear_locally(key, slot)

    if key == nil then
        OF.notify.show("The host took your hat off", "info", 5)
    else
        OF.notify.show("The host put a @ on you", "info", 5,
            hats.BY_KEY[key].name)
    end
end

local function on_hat_ask(data)
    if data == nil or data.ofp ~= hats.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    if OF.perms.tier(asker) < OF.perms.required("costume_other") then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    local target = OF.util.local_from_global(data.who)
    local may, whyNot = OF.util.may_act_on(asker, target)
    if not may then
        OF.util.tell_asker(askerGlobal, whyNot)
        return
    end

    local ok, why = hats.set(target, (data.off == 1) and nil or data.key,
        tonumber(data.slot) or 1)
    if not ok then OF.util.tell_asker(askerGlobal, why) end
end

hats.BEHAVIOUR = hook_behavior(nil, OBJ_LIST_DEFAULT, false, hat_init, hat_loop,
    "of hat")

hook_event(HOOK_UPDATE, keep_in_step)
hook_event(HOOK_ON_GEO_PROCESS, on_geo_process)
hook_event(HOOK_ON_OBJECT_RENDER, place_hat)
hook_event(HOOK_ON_PACKET_RECEIVE, on_hat_set)
hook_event(HOOK_ON_PACKET_RECEIVE, on_hat_ask)

hook_event(HOOK_ON_LEVEL_INIT, forget_all)
hook_event(HOOK_ON_SYNC_VALID, forget_all)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    drop(m.playerIndex)
    if not OF.util.is_host() then return end
    local s = gPlayerSyncTable[m.playerIndex]
    if s ~= nil then s[ROW_KEY] = "" end
end)

hook_event(HOOK_ON_MODS_LOADED, function()

    local fit = mod_storage_load(FIT_KEY, "")
    if fit ~= nil and fit ~= "" then

        local slot = 1
        for part in string.gmatch(tostring(fit), SLOT_PATTERN) do
            if slot > SLOTS then break end
            local lift, tilt, pitch =
                string.match(part, "^(-?%d+),(-?%d+),(-?%d+)$")
            if lift == nil then
                lift, tilt = string.match(part, "^(-?%d+),(-?%d+)$")
                pitch = 0
            end
            myLift[slot] = clamp_step(lift, LIFT_MIN, LIFT_MAX, LIFT_STEP)
            myTilt[slot] = clamp_step(tilt, TILT_MIN, TILT_MAX, TILT_STEP)
            myPitch[slot] = clamp_step(pitch, PITCH_MIN, PITCH_MAX, PITCH_STEP)
            slot = slot + 1
        end
    end

    local stored = mod_storage_load(STORE_KEY, "")
    if stored == nil or stored == "" then return end

    if not OF.perms.can("costume_self") then return end

    if stored == NONE then
        OF.util.publish_row(0, ROW_KEY, hats.settled_row(NONE) or "")
        return
    end

    local entries = {}
    for _, one in ipairs(read_row_all(stored)) do
        if hats.BY_KEY[one.key] ~= nil and #entries < SLOTS then
            local slot = #entries + 1
            myLift[slot], myTilt[slot], myPitch[slot] = one.lift, one.tilt,
                one.pitch
            entries[slot] = one
        end
    end
    if #entries == 0 then return end
    OF.util.publish_row(0, ROW_KEY,
        hats.settled_row(write_row(entries)) or "")
end)

local LOBBY_NEED = "costume_other"
local MINE_NEED = "costume_self"
local function mine_row(panel, built)
    panel.all_for_me({ built })
    return built
end

local function press_mine(key)
    local already = hats.slot_of_key(0, key)
    if already ~= nil then
        OF.util.report(hats.set(0, nil, already))
        return
    end
    OF.util.report(hats.set(0, key, hats.free_slot(0) or hats.SLOTS))
end

local function fit_rows(panel, rows, slot)

    local from = #rows + 1
    local liftStep, tiltStep, pitchStep = hats.fit_steps(slot)
    local myLiftNow, myTiltNow, myPitchNow = hats.my_fit(slot)
    rows[#rows + 1] = panel.with_help(
        panel.with_slider(
            panel.with_right(

                panel.gated_row("costume_self", OF.lang.t("Height"),
                    200, 200, 255, function()
                        OF.util.report(hats.set_lift_step(
                            (liftStep + 1) % (hats.LIFT_STEPS + 1),
                            slot))
                    end),
                (myLiftNow > 0 and "+" or "") .. tostring(myLiftNow)),
            liftStep, hats.LIFT_STEPS, function(wanted)
                OF.util.report(hats.set_lift_step(wanted, slot))
            end),
        OF.lang.t("up and down the head's own axis, so it leans with you"))
    rows[#rows + 1] = panel.with_help(
        panel.with_slider(
            panel.with_right(
                panel.gated_row("costume_self", OF.lang.t("Tilt"),
                    200, 200, 255, function()
                        OF.util.report(hats.set_tilt_step(
                            (tiltStep + 1) % (hats.TILT_STEPS + 1),
                            slot))
                    end),
                tostring(myTiltNow)),
            tiltStep, hats.TILT_STEPS, function(wanted)
                OF.util.report(hats.set_tilt_step(wanted, slot))
            end),
        OF.lang.t("a jaunty angle, kept through a dive and a ground pound"))

    rows[#rows + 1] = panel.with_help(
        panel.with_slider(
            panel.with_right(
                panel.gated_row("costume_self", OF.lang.t("Front to back"),
                    200, 200, 255, function()
                        OF.util.report(hats.set_pitch_step(
                            (pitchStep + 1) % (hats.PITCH_STEPS + 1),
                            slot))
                    end),
                hats.pitch_word(myPitchNow)),
            pitchStep, hats.PITCH_STEPS, function(wanted)
                OF.util.report(hats.set_pitch_step(wanted, slot))
            end),
        OF.lang.t("right dials it down over the eyes, left pushes it back "
            .. "off the forehead"))

    if myLiftNow ~= 0 or myTiltNow ~= 0 or myPitchNow ~= 0 then
        rows[#rows + 1] = panel.gated_row("costume_self",
            OF.lang.t("Straighten it"), 255, 200, 120, function()
                OF.util.report(hats.set_fit(0, 0, 0, slot))
            end)
    end

    local mine = {}
    for at = from, #rows do mine[#mine + 1] = rows[at] end
    panel.all_for_me(mine)
end

function hats.build_page(panel)
    local rows = {}

    local localIndex = 0

    local stack = hats.worn_all(localIndex)
    local worn = stack[1] ~= nil and hats.BY_KEY[stack[1]].name or nil

    local mineWorn = hats.mine_choice(localIndex) ~= nil
    if worn ~= nil then
        local names = {}
        for at, key in ipairs(stack) do names[at] = hats.BY_KEY[key].name end
        local said
        if #names > 1 then
            said = OF.lang.fill("Wearing: @, with @ on top", names[1], names[2])
        else
            said = OF.lang.fill("Wearing: @", names[1])
        end
        rows[#rows + 1] = panel.with_help(
            panel.label_row(mineWorn and said
                or OF.lang.fill("@ - the lobby's", said)),
            OF.lang.t("what is on that head right now"))

        for at = #stack, 1, -1 do
            local slot = at
            rows[#rows + 1] = mine_row(panel, panel.with_help(
                panel.gated_row(MINE_NEED,
                    (#stack > 1)
                        and OF.lang.fill("Take off the @", names[slot])
                        or OF.lang.t("Take it off"),
                    255, 200, 120, function()
                        OF.util.report(hats.set(0, nil, slot))
                    end),
                (#stack > 1)
                    and OF.lang.t("the other one stays where it is")
                    or OF.lang.t("leaves your head bare, whatever the lobby "
                        .. "is wearing")))
        end
    else
        rows[#rows + 1] = panel.with_help(
            panel.label_row(OF.lang.t("Wearing: nothing.")),
            OF.lang.t("what is on that head right now"))
    end

    if worn ~= nil and hats.head_is_covered(localIndex)
        and not hats.sits_on_a_head(localIndex) then
        rows[#rows + 1] = panel.label_row(OF.lang.t(
            "That model has no head, so it floats just above."))
    end

    if worn ~= nil and hats.round_hides() then
        rows[#rows + 1] = panel.label_row(OF.lang.t(
            "A round is on, so it is off until the round ends."))
    end

    if worn ~= nil then
        for slot = 1, #stack do
            if #stack > 1 then
                rows[#rows + 1] = panel.header_row(
                    OF.lang.fill("How the @ sits",
                        hats.BY_KEY[stack[slot]].name))
            end
            fit_rows(panel, rows, slot)
        end
    end

    rows[#rows + 1] = panel.header_row(OF.lang.t("Pick one"))

    rows[#rows + 1] = panel.with_help(panel.two_box({
        boxes = false,
        name = OF.lang.t("Surprise me"),
        lobbyNeed = LOBBY_NEED,
        mineNeed = MINE_NEED,
        r = 120, g = 255, b = 120,
        onLobby = function()
            OF.util.report(hats.press_room(hats.random_key(hats.room_keys())))
        end,
        onMine = function()

            local pick = hats.random_key(hats.worn_all(0))
            if pick ~= nil then press_mine(pick) end
        end,
    }), OF.lang.fill("one of the @, and never the one already on",
        hats.count()))

    if hats.room_any() then
        rows[#rows + 1] = panel.with_help(
            panel.gated_row(LOBBY_NEED,
                OF.lang.t("Take the lobby's hats off everybody"),
                255, 200, 120, function()
                    OF.util.report(hats.clear_room())
                end),
            OF.lang.t("everybody following the lobby is bare-headed again"))
    end

    for _, group in ipairs(hats.GROUPS) do
        rows[#rows + 1] = panel.with_help(
            panel.with_right(
                panel.row(group.name .. "...", 255, 255, 255, function()
                    panel.hatGroup = group.key
                    panel.go("hatset")
                end),
                tostring(#group.items)),
            group.blurb)
    end

    rows[#rows + 1] = panel.back_row("fun")
    return rows
end

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end

    if panel.PAGES.hats == nil then
        panel.PAGES.hats = {
            title = "Hats", tab = "players", up = "players", fold = false,
            build = function() return hats.build_page(panel) end,
        }
    end
    if panel.PAGES.hatset == nil then
        panel.PAGES.hatset = {
            title = "Pick a hat", tab = "players", up = "hats",
            build = function() return hats.build_group_page(panel) end,
        }
    end
end)

function hats.build_group_page(panel)
    local group = hats.group_of(panel.hatGroup) or hats.GROUPS[1]
    local rows = {}
    if group == nil then
        rows[#rows + 1] = panel.label_row(OF.lang.t("This build has no hats to offer."))
        rows[#rows + 1] = panel.back_row("hats")
        return rows
    end

    rows[#rows + 1] = panel.with_help(
        panel.label_row(OF.lang.fill("@ - @", group.name, group.blurb)),
        OF.lang.t("left box the lobby, right box you - and yours wins"))

    local full = hats.free_slot(0) == nil
    for _, item in ipairs(group.items) do

        local room = hats.room_on(item.key)
        local state = hats.mine_state(0, item.key)
        local built = panel.two_box({
            lobbyOn = room,

            mineBox = panel.mine_shown(state, room),
            name = item.name,
            lobbyNeed = LOBBY_NEED,
            mineNeed = MINE_NEED,
            r = 255, g = 255, b = 255,
            onLobby = function() OF.util.report(hats.press_room(item.key)) end,
            onMine = function() press_mine(item.key) end,
        })

        local marked = panel.mine_marked(state)
        rows[#rows + 1] = panel.with_help(
            panel.level_right(built, marked, OF.lang.t("(yours)")),
            (state == true) and OF.lang.t("Z takes it back off again")
                or (full and OF.lang.t("two is the most one head holds, so "
                    .. "this replaces the top one")
                or OF.lang.t("A for the whole lobby, Z for your own head")))
    end

    rows[#rows + 1] = panel.back_row("hats")
    return rows
end
