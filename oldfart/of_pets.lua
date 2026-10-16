OF = OF or {}
OF.pets = OF.pets or {}

local pets = OF.pets

local ROW_KEY = "ofPet"
pets.ROW_KEY = ROW_KEY
local STORE_KEY = "pet"
pets.STORE_KEY = STORE_KEY

local NEED = "fun_self"
pets.CATALOGUE = {

    { key = "goomba", group = "enemies", name = "Goomba", model = E_MODEL_GOOMBA,
      anims = "goomba_seg8_anims_0801DA4C", walk = 0, idle = 0,
      walkRate = 0.12, idleAccel = 1.0, scale = 0.8 },

    { key = "buddy", group = "friends", name = "Bob-omb Buddy", model = E_MODEL_BOBOMB_BUDDY,
      anims = "bobomb_seg8_anims_0802396C", walk = 0, idle = 0,
      walkRate = 0.1, idleAccel = 0.5, scale = 0.7 },

    { key = "koopa", group = "friends", name = "Koopa", model = E_MODEL_KOOPA_WITHOUT_SHELL,
      anims = "koopa_seg6_anims_06011364", walk = 3, idle = 7,
      walkRate = 0.09, idleAccel = 1.0, scale = 0.9 },

    { key = "chuckya", group = "enemies", name = "Chuckya", model = E_MODEL_CHUCKYA,
      anims = "chuckya_seg8_anims_0800C070", walk = 4, idle = 4,
      walkRate = 0.08, idleAccel = 0.4, scale = 0.8 },

    { key = "penguin", group = "friends", name = "Baby penguin", model = E_MODEL_PENGUIN,
      anims = "penguin_seg5_anims_05008B74", walk = 0, idle = 3,
      walkRate = 0.1, idleAccel = 1.0, scale = 1.0 },

    { key = "yoshi", group = "friends", name = "Yoshi", model = E_MODEL_YOSHI,
      anims = "yoshi_seg5_anims_05024100", walk = 1, idle = 0,
      walkRate = 0.08, idleAccel = 1.0, scale = 0.5 },

    { key = "mips", group = "friends", name = "Mips", model = E_MODEL_MIPS,
      anims = "mips_seg6_anims_06015634", walk = 1, idle = 0,
      walkRate = 0.07, idleAccel = 1.0, scale = 0.8 },

    { key = "scuttlebug", group = "enemies", name = "Scuttlebug", model = E_MODEL_SCUTTLEBUG,
      anims = "scuttlebug_seg6_anims_06015064", walk = 0, idle = 0,
      walkRate = 0.1, idleAccel = 0.3, scale = 0.5 },

    { key = "ukiki", group = "friends", name = "Ukiki", model = E_MODEL_UKIKI,
      anims = "ukiki_seg5_anims_05015784", walk = 0, idle = 9,
      walkRate = 0.07, idleAccel = 1.0, scale = 0.8 },

    { key = "chomp", group = "enemies", name = "Chain Chomp", model = E_MODEL_CHAIN_CHOMP,
      anims = "chain_chomp_seg6_anims_06025178", walk = 0, idle = 0,
      walkRate = 0.05, idleAccel = 0.6, scale = 0.45,
      hop = true, lift = 120 },

    { key = "boo", group = "air", name = "Boo", model = E_MODEL_BOO,
      scale = 0.55, fly = true, hover = 90, wobble = true },

    { key = "klepto", group = "air", name = "Klepto", model = E_MODEL_KLEPTO,
      anims = "klepto_seg5_anims_05008CFC", walk = 0, idle = 0,
      walkRate = 0.03, idleAccel = 1.0, scale = 0.38,
      fly = true, hover = 170 },

    { key = "hoot", group = "air", name = "Hoot", model = E_MODEL_HOOT,
      anims = "hoot_seg5_anims_05005768", walk = 0, idle = 0,
      walkRate = 0.03, idleAccel = 1.0, scale = 0.45,
      fly = true, hover = 160 },

    { key = "bird", group = "air", name = "Bird", model = E_MODEL_BIRDS,
      anims = "birds_seg5_anims_050009E8", walk = 0, idle = 0,
      walkRate = 0.03, idleAccel = 1.0, scale = 0.7,
      fly = true, hover = 150 },

    { key = "butterfly", group = "air", name = "Butterfly", model = E_MODEL_BUTTERFLY,
      anims = "butterfly_seg3_anims_030056B0", walk = 0, idle = 0,
      walkRate = 0.03, idleAccel = 1.0, scale = 1.65,
      fly = true, hover = 120 },

    { key = "fish", group = "water", name = "Fish", model = E_MODEL_FISH,
      anims = "blue_fish_seg3_anims_0301C2B0", walk = 0, idle = 0,
      walkRate = 0.05, idleAccel = 1.0, scale = 0.9,
      fly = true, hover = 110 },

    { key = "toad", group = "friends", name = "Toad", model = E_MODEL_TOAD,
      anims = "toad_seg6_anims_0600FB58", walk = 6, idle = 6,
      walkRate = 0.05, idleAccel = 1.0, scale = 0.9 },

    { key = "peach", group = "friends", name = "Princess Peach", model = E_MODEL_PEACH,
      anims = "peach_seg5_anims_0501C41C", walk = 11, idle = 11,
      walkRate = 0.05, idleAccel = 1.0, scale = 0.85 },

    { key = "moneybags", group = "friends", name = "Moneybags", model = E_MODEL_MONEYBAG,
      anims = "moneybag_seg6_anims_06005E5C", walk = 0, idle = 0,
      walkRate = 0.08, idleAccel = 0.5, scale = 0.6, hop = true },

    { key = "bobomb", group = "enemies", name = "Black Bob-omb", model = E_MODEL_BLACK_BOBOMB,
      anims = "bobomb_seg8_anims_0802396C", walk = 0, idle = 0,
      walkRate = 0.1, idleAccel = 0.5, scale = 0.7 },

    { key = "shelledkoopa", group = "enemies", name = "Shelled Koopa", model = E_MODEL_KOOPA_WITH_SHELL,
      anims = "koopa_seg6_anims_06011364", walk = 9, idle = 9,
      walkRate = 0.09, idleAccel = 0.99, scale = 0.9 },

    { key = "bully", group = "enemies", name = "Bully", model = E_MODEL_BULLY,
      anims = "bully_seg5_anims_0500470C", walk = 0, idle = 0,
      walkRate = 0.07, idleAccel = 0.4, scale = 0.55 },

    { key = "spiny", group = "enemies", name = "Spiny", model = E_MODEL_SPINY,
      anims = "spiny_seg5_anims_05016EAC", walk = 0, idle = 0,
      walkRate = 0.1, idleAccel = 0.5, scale = 0.7, lift = -17 },

    { key = "montymole", group = "enemies", name = "Monty Mole", model = E_MODEL_MONTY_MOLE,
      anims = "monty_mole_seg5_anims_05007248", walk = 1, idle = 1,
      walkRate = 0.06, idleAccel = 0.6, scale = 0.7 },

    { key = "piranha", group = "enemies", name = "Piranha Plant", model = E_MODEL_PIRANHA_PLANT,
      anims = "piranha_plant_seg6_anims_0601C31C", walk = 8, idle = 8,
      walkRate = 0.05, idleAccel = 0.7, scale = 0.35 },

    { key = "thwomp", group = "enemies", name = "Thwomp", model = E_MODEL_THWOMP,
      still = true, scale = 0.3, hop = true },

    { key = "whomp", group = "enemies", name = "Whomp", model = E_MODEL_WHOMP,
      anims = "whomp_seg6_anims_06020A04", walk = 0, idle = 0,
      walkRate = 0.05, idleAccel = 0.4, scale = 0.4, noShadow = true,
      shadow = 200 },

    { key = "heaveho", group = "enemies", name = "Heave-Ho", model = E_MODEL_HEAVE_HO,
      anims = "heave_ho_seg5_anims_0501534C", walk = 0, idle = 2,
      walkRate = 0.1, idleAccel = 1.0, scale = 0.7 },

    { key = "madpiano", group = "enemies", name = "Mad Piano", model = E_MODEL_MAD_PIANO,
      anims = "mad_piano_seg5_anims_05009B14", walk = 1, idle = 0,
      walkRate = 0.06, idleAccel = 0.5, scale = 0.35, hop = true },

    { key = "chair", group = "enemies", name = "Haunted Chair", model = E_MODEL_HAUNTED_CHAIR,
      anims = "chair_seg5_anims_05005784", walk = 0, idle = 0,
      walkRate = 0.06, idleAccel = 0.4, scale = 0.47, hop = true },

    { key = "pokey", group = "enemies", name = "Pokey", model = E_MODEL_POKEY_HEAD,
      still = true, scale = 1.5, hop = true, lift = 22 },

    { key = "spindrift", group = "enemies", name = "Spindrift", model = E_MODEL_SPINDRIFT,
      anims = "spindrift_seg5_anims_05002D68", walk = 0, idle = 0,
      walkRate = 0.08, idleAccel = 0.5, scale = 0.6 },

    { key = "blizzard", group = "enemies", name = "Mr. Blizzard", model = E_MODEL_MR_BLIZZARD,
      anims = "snowman_seg5_anims_0500D118", walk = 0, idle = 0,
      walkRate = 0.06, idleAccel = 0.5, scale = 0.4 },

    { key = "skeeter", group = "enemies", name = "Skeeter", model = E_MODEL_SKEETER,
      anims = "skeeter_seg6_anims_06007DE0", walk = 2, idle = 0,
      walkRate = 0.08, idleAccel = 0.5, scale = 0.6 },

    { key = "bowser", group = "bosses", name = "Bowser", model = E_MODEL_BOWSER,
      anims = "bowser_seg6_anims_06057690", walk = 13, idle = 12,
      walkRate = 0.06, idleAccel = 1.0, scale = 0.22 },

    { key = "kingbobomb", group = "bosses", name = "King Bob-omb", model = E_MODEL_KING_BOBOMB,
      anims = "king_bobomb_seg5_anims_0500FE30", walk = 2, idle = 11,
      walkRate = 0.06, idleAccel = 1.0, scale = 0.35 },

    { key = "bigbully", group = "bosses", name = "Big Bully", model = E_MODEL_BULLY_BOSS,
      anims = "bully_seg5_anims_0500470C", walk = 0, idle = 0,
      walkRate = 0.05, idleAccel = 0.4, scale = 0.5 },

    { key = "wiggler", group = "bosses", name = "Wiggler", model = E_MODEL_WIGGLER_HEAD,
      anims = "wiggler_seg5_anims_0500EC8C", walk = 0, idle = 0,
      walkRate = 0.05, idleAccel = 0.5, scale = 1.2 },

    { key = "eyerok", group = "bosses", name = "Eyerok's hand", model = E_MODEL_EYEROK_LEFT_HAND,
      anims = "eyerok_seg5_anims_050116E4", walk = 2, idle = 2,
      walkRate = 0.04, idleAccel = 1.0, scale = 0.25,
      fly = true, hover = 90 },

    { key = "dorrie", group = "bosses", name = "Dorrie", model = E_MODEL_DORRIE,
      anims = "dorrie_seg6_anims_0600F638", walk = 1, idle = 1,
      walkRate = 0.03, idleAccel = 0.7, scale = 0.12, lift = 400 },

    { key = "amp", group = "air", name = "Amp", model = E_MODEL_AMP,
      anims = "amp_seg8_anims_08004034", walk = 0, idle = 0,
      walkRate = 0.05, idleAccel = 1.0, scale = 0.7,
      fly = true, hover = 90 },

    { key = "flyguy", group = "air", name = "Fly Guy", model = E_MODEL_FLYGUY,
      anims = "flyguy_seg8_anims_08011A64", walk = 0, idle = 0,
      walkRate = 0.03, idleAccel = 1.0, scale = 0.6,
      fly = true, hover = 130 },

    { key = "bulletbill", group = "air", name = "Bullet Bill", model = E_MODEL_BULLET_BILL,
      still = true, scale = 0.25, fly = true, hover = 100 },

    { key = "swoop", group = "air", name = "Swoop", model = E_MODEL_SWOOP,
      anims = "swoop_seg6_anims_060070D0", walk = 0, idle = 0,
      walkRate = 0.03, idleAccel = 1.5, scale = 0.6,
      fly = true, hover = 120 },

    { key = "snufit", group = "air", name = "Snufit", model = E_MODEL_SNUFIT,
      still = true, scale = 0.8, fly = true, hover = 110,
      fields = { oSnufitBodyScale = 1000 } },

    { key = "fwoosh", group = "air", name = "Fwoosh", model = E_MODEL_FWOOSH,
      still = true, scale = 0.6, fly = true, hover = 100, cloud = true },

    { key = "bigboo", group = "air", name = "Big Boo", model = E_MODEL_BOO,
      scale = 1.2, fly = true, hover = 130, wobble = true },

    { key = "cheepcheep", group = "water", name = "Bub", model = E_MODEL_BUB,
      anims = "bub_seg6_anims_06012354", walk = 0, idle = 0,
      walkRate = 0.05, idleAccel = 1.0, scale = 0.82,
      fly = true, hover = 90 },
    { key = "cyanfish", group = "water", name = "Cyan fish", model = E_MODEL_CYAN_FISH,
      anims = "cyan_fish_seg6_anims_0600E264", walk = 0, idle = 0,
      walkRate = 0.05, idleAccel = 1.0, scale = 0.9,
      fly = true, hover = 100 },
    { key = "shark", group = "water", name = "Shark", model = E_MODEL_SUSHI,
      anims = "sushi_seg5_anims_0500AE54", walk = 0, idle = 0,
      walkRate = 0.03, idleAccel = 1.0, scale = 0.25,
      fly = true, hover = 110 },
    { key = "manta", group = "water", name = "Manta ray", model = E_MODEL_MANTA_RAY,
      anims = "manta_seg5_anims_05008EB4", walk = 0, idle = 0,
      walkRate = 0.03, idleAccel = 1.0, scale = 0.3,
      fly = true, hover = 120 },
}

pets.GROUPS = {
    { key = "friends", name = "Friends" },
    { key = "enemies", name = "Enemies" },
    { key = "bosses",  name = "Bosses and giants" },
    { key = "air",     name = "In the air" },
    { key = "water",   name = "In the water" },
}

pets.BY_KEY = {}
for at, entry in ipairs(pets.CATALOGUE) do
    entry.seq = at
    pets.BY_KEY[entry.key] = entry
end

pets.OWN_PREFIX = "of_pet_"
function pets.own_geo(entry)
    return pets.OWN_PREFIX .. tostring(entry and entry.key) .. "_geo"
end

local ownModel = {}

function pets.model_of(entry)
    if entry == nil then return nil end
    local known = ownModel[entry.key]
    if known ~= nil then return known end
    local id = entry.model
    local geo = pets.own_geo(entry)
    if OF.util.optional("mod_file_exists", false, "actors/" .. geo .. ".bin") then
        local found = OF.util.optional("smlua_model_util_get_id", nil, geo)
        if type(found) == "number" and found ~= E_MODEL_ERROR_MODEL then id = found end
    end
    ownModel[entry.key] = id
    return id
end

function pets.has_own_model(entry)
    local id = pets.model_of(entry)
    return id ~= nil and entry ~= nil and id ~= entry.model
end

function pets.forget_models()
    for k in pairs(ownModel) do ownModel[k] = nil end
end

local saidWaiting = {}
pets.saidWaiting = saidWaiting
function pets.say_waiting(entry)
    if entry == nil or saidWaiting[entry.key] then return false end
    saidWaiting[entry.key] = true
    if OF.util.asks(OF.notify, "show") then
        OF.notify.show("@ cannot be drawn here - it comes back in the next course",
            "warn", 5, entry.name)
    end
    return true
end

function pets.count()
    return #pets.CATALOGUE
end

pets.SLOTS = 2
local SLOTS = pets.SLOTS
local SLOT_SEP = ";"
function pets.read_row(raw)
    local keys = {}
    if type(raw) ~= "string" or raw == "" then return keys end
    for part in string.gmatch(raw, "[^;]+") do
        if pets.BY_KEY[part] ~= nil then
            local seen = false
            for _, one in ipairs(keys) do
                if one == part then seen = true end
            end
            if not seen and #keys < SLOTS then keys[#keys + 1] = part end
        end
    end
    return keys
end

function pets.write_row(keys)
    return table.concat(keys, SLOT_SEP)
end

local parsedRaw, parsedFirst, parsedSecond = {}, {}, {}

local function parsed(localIndex)
    local s = gPlayerSyncTable[localIndex]
    local raw = s ~= nil and s[ROW_KEY] or nil
    if raw == nil then raw = "" end
    if parsedRaw[localIndex] ~= raw then
        parsedRaw[localIndex] = raw
        local keys = pets.read_row(raw)
        parsedFirst[localIndex] = keys[1] ~= nil and pets.BY_KEY[keys[1]] or false
        parsedSecond[localIndex] = keys[2] ~= nil and pets.BY_KEY[keys[2]] or false
    end
    return parsedFirst[localIndex] or nil, parsedSecond[localIndex] or nil
end

function pets.chosen(localIndex)
    local first = parsed(localIndex)
    return first
end

function pets.chosen_all(localIndex)
    local first, second = parsed(localIndex)
    local list = {}
    if first ~= nil then list[1] = first end
    if second ~= nil then list[#list + 1] = second end
    return list
end

function pets.slot_of(localIndex, key)
    local first, second = parsed(localIndex)
    if first ~= nil and first.key == key then return 1 end
    if second ~= nil and second.key == key then return 2 end
    return nil
end

function pets.name_of(localIndex)
    local first, second = parsed(localIndex)
    if first == nil then return nil end
    if second == nil then return first.name end

    return first.name .. " +1"
end

function pets.round_hides(localIndex)
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down(localIndex) == true
end

function pets.in_force_slot(localIndex, slot)
    local first, second = parsed(localIndex)
    local entry = slot == 2 and second or (slot == 1 and first or nil)
    if entry == nil then return nil end
    if pets.round_hides(localIndex) then return nil end
    return entry
end

local function publish_keys(keys)
    local row = pets.write_row(keys)
    OF.util.publish_row(0, ROW_KEY, row)
    OF.util.store(STORE_KEY, row)
end

function pets.set(key, second)
    if key ~= nil and pets.BY_KEY[key] == nil then
        return false, "There is no pet by that name."
    end
    if second ~= nil and pets.BY_KEY[second] == nil then
        return false, "There is no pet by that name."
    end
    if not OF.perms.can(NEED) then
        return false, "Your rank cannot do that.", NEED
    end
    local keys = {}
    if key ~= nil then keys[1] = key end
    if key ~= nil and second ~= nil and second ~= key then keys[2] = second end
    publish_keys(keys)
    return true
end

function pets.toggle(key)
    if key == nil or pets.BY_KEY[key] == nil then
        return false, "There is no pet by that name."
    end
    if not OF.perms.can(NEED) then
        return false, "Your rank cannot do that.", NEED
    end
    local keys = pets.read_row(gPlayerSyncTable[0][ROW_KEY])
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
    publish_keys(keys)
    return true
end

function pets.random_key(notThis, alsoNot)
    local count = #pets.CATALOGUE
    if count == 0 then return nil end
    if count == 1 then return pets.CATALOGUE[1].key end
    for _ = 1, 8 do
        local pick = pets.CATALOGUE[math.random(count)]
        if pick.key ~= notThis and pick.key ~= alsoNot then return pick.key end
    end
    local pick = pets.CATALOGUE[math.random(count)]
    while pick.key == notThis or pick.key == alsoNot do
        pick = pets.CATALOGUE[(pick.seq % count) + 1]
    end
    return pick.key
end

local RING = 32
local CRUMB_STEP = 40
local GAP = 150
local TELEPORT = 1400
local WARP_JUMP = 600
local MAX_SPEED = 90
local ARRIVE = 8

pets.RING, pets.CRUMB_STEP, pets.GAP = RING, CRUMB_STEP, GAP
pets.TELEPORT = TELEPORT

local COUNT = MAX_PLAYERS * SLOTS
pets.COUNT = COUNT

local crumbX, crumbY, crumbZ = {}, {}, {}
for n = 0, COUNT * RING - 1 do
    crumbX[n], crumbY[n], crumbZ[n] = 0, 0, 0
end

local written, cursor = {}, {}
local lastX, lastY, lastZ = {}, {}, {}

local petX, petY, petZ, petYaw = {}, {}, {}, {}
local petSpeed, petTimer = {}, {}

local petFall = {}

local followed = {}

for n = 0, COUNT - 1 do
    written[n], cursor[n] = 0, 0
    lastX[n], lastY[n], lastZ[n] = 0, 0, 0
    petX[n], petY[n], petZ[n], petYaw[n] = 0, 0, 0, 0
    petSpeed[n], petTimer[n] = 0, 0
    petFall[n] = 0
    followed[n] = { pos = { x = 0, y = 0, z = 0 }, faceAngle = { y = 0 } }
end

local function leader_of(n)
    if n < MAX_PLAYERS then return gMarioStates[n] end
    local f, first = followed[n], n - MAX_PLAYERS
    f.pos.x, f.pos.y, f.pos.z = petX[first], petY[first], petZ[first]
    f.faceAngle.y = petYaw[first]
    return f
end

local function push_crumb(i, x, y, z)
    local at = i * RING + (written[i] % RING)
    crumbX[at], crumbY[at], crumbZ[at] = x, y, z
    written[i] = written[i] + 1

    if cursor[i] < written[i] - RING then cursor[i] = written[i] - RING end
end

local function heel(i, m)
    local yaw = m.faceAngle.y
    petX[i] = m.pos.x - sins(yaw) * GAP
    petZ[i] = m.pos.z - coss(yaw) * GAP
    petY[i] = m.pos.y
    petYaw[i] = yaw
    petSpeed[i] = 0
    petFall[i] = 0
    written[i], cursor[i] = 0, 0
    push_crumb(i, m.pos.x, m.pos.y, m.pos.z)
    cursor[i] = written[i]
    lastX[i], lastY[i], lastZ[i] = m.pos.x, m.pos.y, m.pos.z
end

pets.heel = heel

local function record(i, m)
    local x, y, z = m.pos.x, m.pos.y, m.pos.z
    local dx, dy, dz = x - lastX[i], y - lastY[i], z - lastZ[i]
    lastX[i], lastY[i], lastZ[i] = x, y, z
    if dx * dx + dy * dy + dz * dz > WARP_JUMP * WARP_JUMP then
        heel(i, m)
        return
    end
    local newest = i * RING + ((written[i] - 1) % RING)
    local ex, ey, ez = x - crumbX[newest], y - crumbY[newest], z - crumbZ[newest]
    if ex * ex + ey * ey + ez * ez >= CRUMB_STEP * CRUMB_STEP then
        push_crumb(i, x, y, z)
    end
end

local function turn(from, to, step)
    local d = (to - from) % 0x10000
    if d > 0x8000 then d = d - 0x10000 end
    if d > step then d = step elseif d < -step then d = -step end
    return (from + d) % 0x10000
end

local FALL_ACCEL, FALL_MAX = 4, 75

local function settle(i, entry)
    if entry.fly then petFall[i] = 0 return end
    local x, y, z = petX[i], petY[i], petZ[i]
    local floor = find_floor_height(x, y + 100, z)
    if floor == nil or floor <= -10000 then petFall[i] = 0 return end
    if y <= floor then
        petY[i], petFall[i] = floor, 0
        return
    end
    petFall[i] = math.min(petFall[i] + FALL_ACCEL, FALL_MAX)
    y = y - petFall[i]
    if y <= floor then y, petFall[i] = floor, 0 end
    petY[i] = y
end

pets.settle = settle

local function walk(i, m, entry)
    local ox, oy, oz = m.pos.x, m.pos.y, m.pos.z
    local x, y, z = petX[i], petY[i], petZ[i]
    local dx, dz = ox - x, oz - z
    local far = math.sqrt(dx * dx + dz * dz)

    if far > TELEPORT or math.abs(oy - y) > TELEPORT then
        heel(i, m)
        return 0
    end

    if far <= GAP then
        petSpeed[i] = 0
        if far > 1 then petYaw[i] = turn(petYaw[i], atan2s(dz, dx), 0x600) end

        cursor[i] = written[i]

        settle(i, entry)
        return 0
    end

    local want = (far - GAP) * 0.3
    if want > MAX_SPEED then want = MAX_SPEED end
    local speed = petSpeed[i] + (want - petSpeed[i]) * 0.35
    petSpeed[i] = speed

    local budget = speed
    local moved = 0
    local heading = petYaw[i]

    for _ = 1, 4 do
        if budget <= 0 then break end
        local tx, ty, tz
        if cursor[i] < written[i] then
            local at = i * RING + (cursor[i] % RING)
            tx, ty, tz = crumbX[at], crumbY[at], crumbZ[at]
        else

            tx, ty, tz = ox, oy, oz
        end
        local sx, sy, sz = tx - x, ty - y, tz - z
        local len = math.sqrt(sx * sx + sz * sz)
        if len > 0.01 then heading = atan2s(sz, sx) end
        if len <= budget or len < ARRIVE then
            x, y, z = tx, ty, tz
            budget = budget - len
            moved = moved + len
            if cursor[i] < written[i] then
                cursor[i] = cursor[i] + 1
            else
                break
            end
        else
            local f = budget / len
            x, y, z = x + sx * f, y + sy * f, z + sz * f
            moved = moved + budget
            budget = 0
        end
    end

    if not entry.fly then
        local floor = find_floor_height(x, y + 100, z)
        if floor ~= nil and floor > -10000 and y < floor then y = floor end
    end

    petX[i], petY[i], petZ[i] = x, y, z

    petFall[i] = 0
    petYaw[i] = turn(petYaw[i], heading, 0x1000)
    return moved
end

pets.walk = walk

local objects = {}
local objectKey = {}
pets.objects = objects

local GRAPH_INVISIBLE = GRAPH_RENDER_INVISIBLE or 0x10

local function pet_init(o)
    if o == nil then return end

    o.oInteractType = 0
    o.oIntangibleTimer = -1
    o.oCollisionDistance = 0
    o.oAnimState = 0
    o.oFlags = OF.util.add_flag(o.oFlags or 0, OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
end

local OPAQUE = 255

local function dress(o, entry)
    obj_scale(o, entry.scale)
    o.oOpacity = OPAQUE
    if entry.noShadow and o.header ~= nil and o.header.gfx ~= nil then
        o.header.gfx.shadowInvisible = true
    end

    if entry.fields ~= nil then
        for name, value in pairs(entry.fields) do o[name] = value end
    end
    if entry.anims ~= nil and gObjectAnimations ~= nil then
        local anims = gObjectAnimations[entry.anims]
        if anims ~= nil then
            o.oAnimations = anims
            obj_init_animation_with_accel_and_sound(o, entry.idle, entry.idleAccel)
        end
    end
end

local shades = {}
pets.shades = shades
pets.SHADE_MODEL = E_MODEL_WATER_BOMB_SHADOW
pets.SHADE_WIDTH = 160

local function unshade(i)
    local s = shades[i]
    shades[i] = nil
    if s ~= nil and s.activeFlags ~= 0 then obj_mark_for_deletion(s) end
end

function pets.shade(i, o, entry)
    if o == nil or entry == nil or entry.shadow == nil or pets.SHADE_MODEL == nil then
        unshade(i)
        return nil
    end
    local s = shades[i]
    if s == nil or s.activeFlags == 0 then
        s = OF.slots.spawn_non_sync(id_bhvStaticObject, pets.SHADE_MODEL,
            o.oPosX, o.oPosY, o.oPosZ, nil)
        shades[i] = s
        if s == nil then return nil end
    end
    s.oPosX, s.oPosY, s.oPosZ = o.oPosX, o.oPosY, o.oPosZ
    obj_scale(s, entry.scale * entry.shadow / pets.SHADE_WIDTH)
    return s
end

local puffs = {}
pets.puffs = puffs
pets.PUFF_MODEL = E_MODEL_MIST
pets.PUFF_HEIGHTS = { 11, 8, 12, 8, 9 }
pets.PUFF_FACE_HEIGHT = 9
pets.PUFF_RADIUS = 25

local function unpuff(i)
    local list = puffs[i]
    puffs[i] = nil
    if list == nil then return end
    for _, p in pairs(list) do
        if p ~= nil and p.activeFlags ~= 0 then obj_mark_for_deletion(p) end
    end
end

function pets.cloud(i, o, entry, timer)
    if o == nil or entry == nil or not entry.cloud or pets.PUFF_MODEL == nil then
        unpuff(i)
        return nil
    end
    local list = puffs[i] or {}
    puffs[i] = list
    local size = entry.scale
    local radius = pets.PUFF_RADIUS * size
    local yaw = o.oFaceAngleYaw or 0
    local cx = o.oPosX - radius * sins(yaw)
    local cz = o.oPosZ - radius * coss(yaw)
    local base = o.oPosY - pets.PUFF_FACE_HEIGHT * size
    for n = 1, #pets.PUFF_HEIGHTS do
        local p = list[n]
        if p == nil or p.activeFlags == 0 then
            p = OF.slots.spawn_non_sync(id_bhvStaticObject, pets.PUFF_MODEL,
                o.oPosX, o.oPosY, o.oPosZ, nil)
            list[n] = p
            if p ~= nil then OF.util.optional("obj_set_billboard", nil, p) end
        end
        if p ~= nil then
            local angle = yaw + 0x10000 // 5 * n

            local wobble = 2 * coss(0x800 * (timer or 0) + 0x4000 * n) * size
            p.oPosX = cx + radius * sins(angle) + wobble
            p.oPosY = base + pets.PUFF_HEIGHTS[n] * size + wobble
            p.oPosZ = cz + radius * coss(angle) + wobble
            obj_scale(p, size)
        end
    end
    return list
end

local function drop(i)
    local o = objects[i]
    objects[i] = nil
    objectKey[i] = nil

    if pets.lunges ~= nil then pets.lunges[i] = nil end
    if o ~= nil and o.activeFlags ~= 0 then obj_mark_for_deletion(o) end
    unshade(i)
    unpuff(i)
end

pets.drop = drop

local function forget_all()
    for n = 0, COUNT - 1 do
        local o = objects[n]
        if o ~= nil and o.activeFlags ~= 0 and pets.BEHAVIOUR ~= nil
            and obj_has_behavior_id(o, pets.BEHAVIOUR) ~= 0 then
            obj_mark_for_deletion(o)
        end
        objects[n] = nil
        objectKey[n] = nil
        if pets.lunges ~= nil then pets.lunges[n] = nil end
        unshade(n)
        unpuff(n)
        written[n], cursor[n] = 0, 0
    end
    for k in pairs(saidWaiting) do saidWaiting[k] = nil end

    pets.forget_models()
end

pets.forget_all = forget_all

local function should_have(i)
    local np = gNetworkPlayers[i]
    if np == nil or not np.connected then return false end
    local m = gMarioStates[i]
    if m == nil or m.marioObj == nil then return false end
    if is_player_active(m) == 0 then return false end
    if OF.util.asks(OF.possess, "hides_from_world")
        and OF.possess.hides_from_world(i) then
        return false
    end
    local me = gNetworkPlayers[0]
    if me ~= nil and np.currLevelNum ~= me.currLevelNum then return false end
    if me ~= nil and np.currAreaIndex ~= me.currAreaIndex then return false end
    return true
end

pets.should_have = should_have

function pets.room_ready()
    return OF.util.asks(OF.slots, "room_ready") and OF.slots.room_ready()
end

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}

table.insert(OF.SLOT_NEEDS, function()
    local out = {}
    for _, entry in ipairs(pets.CATALOGUE) do
        if not pets.has_own_model(entry) then out[#out + 1] = entry end
    end
    return out
end)
table.insert(OF.SLOT_NEEDS, function() return { pets.SHADE_MODEL, pets.PUFF_MODEL } end)

local function keep_in_step()
    local ready = pets.room_ready()
    for n = 0, COUNT - 1 do
        local i = n % MAX_PLAYERS
        local slot = n < MAX_PLAYERS and 1 or 2
        local entry = pets.in_force_slot(i, slot)
        local want = entry ~= nil and should_have(i)
        local have = objects[n]

        if have ~= nil and have.activeFlags == 0 then
            objects[n] = nil
            objectKey[n] = nil
            have = nil
        end

        if have ~= nil and entry ~= nil and objectKey[n] ~= entry.key then
            drop(n)
            have = nil
        end

        if want and have == nil and ready then

            local leader = leader_of(n)
            if slot == 2 and objects[i] == nil then
                leader = nil
            end

            local model = pets.model_of(entry)
            if leader ~= nil and model == entry.model
                and OF.util.asks(OF.slots, "would_misfile")
                and OF.slots.would_misfile(entry.model) then
                leader = nil
                pets.waiting = (pets.waiting or 0) + 1
                pets.say_waiting(entry)
            end
            if leader ~= nil then
                heel(n, leader)
                local o = OF.slots.spawn_non_sync(pets.BEHAVIOUR, model,
                    petX[n], petY[n], petZ[n], pet_init)
                if o ~= nil then

                    o.globalPlayerIndex = network_global_index_from_local(i)
                    o.oAction = slot
                    dress(o, entry)
                    o.oFaceAngleYaw = petYaw[n]
                    o.oMoveAngleYaw = petYaw[n]
                    objects[n] = o
                    objectKey[n] = entry.key
                end
            end
        elseif not want and have ~= nil then
            drop(n)
        end
    end
end

pets.keep_in_step = keep_in_step

pets.MODEL_CHECK_EVERY = 30
local function pet_loop(o)
    if o == nil then return end
    local owner = OF.util.local_from_global(o.globalPlayerIndex)
    local i = owner ~= nil and (owner + (o.oAction == 2 and MAX_PLAYERS or 0)) or nil
    if i == nil or objects[i] ~= o then
        obj_mark_for_deletion(o)
        return
    end
    local entry = pets.BY_KEY[objectKey[i]]
    local m = gMarioStates[owner]
    if entry == nil or m == nil or m.marioObj == nil then
        drop(i)
        return
    end

    local leader = leader_of(i)

    if o.oOpacity ~= OPAQUE then o.oOpacity = OPAQUE end
    if entry.noShadow and not o.header.gfx.shadowInvisible then
        o.header.gfx.shadowInvisible = true
    end

    if (petTimer[i] % pets.MODEL_CHECK_EVERY) == 0 then
        local now = OF.util.optional("obj_get_model_id_extended", nil, o)
        local model = pets.model_of(entry)
        if now ~= nil and now ~= model
            and not (model == entry.model and OF.util.asks(OF.slots, "would_misfile")
                and OF.slots.would_misfile(entry.model)) then
            OF.slots.set_model(o, model)
            pets.remodelled = (pets.remodelled or 0) + 1
        end
    end

    record(i, leader)
    local moved = walk(i, leader, entry)

    local timer = petTimer[i] + 1
    petTimer[i] = timer

    local y = petY[i]
    if entry.fly then

        y = y + (entry.hover or 100) + sins((timer * 0x300) + i * 0x1800) * 10
    else

        if entry.lift then y = y + entry.lift * entry.scale end
        if entry.hop and moved > 0.5 then
            y = y + math.abs(sins(timer * 0x900)) * 40
        end
    end

    local dx, dy, dz = pets.lunge_offset(i)
    o.oPosX, o.oPosY, o.oPosZ = petX[i] + dx, y + dy, petZ[i] + dz
    o.oFaceAngleYaw = petYaw[i]
    o.oMoveAngleYaw = petYaw[i]

    pets.shade(i, o, entry)
    pets.cloud(i, o, entry, timer)

    if entry.anims ~= nil then
        if moved > 0.5 then
            local accel = moved * entry.walkRate
            if accel < 0.5 then accel = 0.5 elseif accel > 3 then accel = 3 end
            obj_init_animation_with_accel_and_sound(o, entry.walk, accel)
        else
            obj_init_animation_with_accel_and_sound(o, entry.idle, entry.idleAccel)
        end
    end

    if entry.wobble then

        local wob = sins(timer * 0x400) * 0.08
        local s = entry.scale
        obj_scale_xyz(o, s + wob * s, s - wob * s, s + wob * s)
    end

    local flags = o.header.gfx.node.flags
    local ownerHidden = OF.util.has_flag(m.marioObj.header.gfx.node.flags,
        GRAPH_INVISIBLE)
    local petHidden = OF.util.has_flag(flags, GRAPH_INVISIBLE)
    if ownerHidden and not petHidden then
        o.header.gfx.node.flags = flags + GRAPH_INVISIBLE
    elseif petHidden and not ownerHidden then
        o.header.gfx.node.flags = flags - GRAPH_INVISIBLE
    end
end

pets.BEHAVIOUR = hook_behavior(nil, OBJ_LIST_DEFAULT, false, pet_init, pet_loop,
    "of pet")

hook_event(HOOK_UPDATE, keep_in_step)
hook_event(HOOK_ON_LEVEL_INIT, forget_all)
hook_event(HOOK_ON_SYNC_VALID, forget_all)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    drop(m.playerIndex)
    drop(m.playerIndex + MAX_PLAYERS)
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    local stored = mod_storage_load(STORE_KEY)
    if stored == nil or stored == "" then return end

    local keys = pets.read_row(stored)
    if #keys == 0 then return end
    if not OF.perms.can(NEED) then return end
    OF.util.publish_row(0, ROW_KEY, pets.write_row(keys))
end)

pets.PREY = {
    id_bhvGoomba, id_bhvBobomb, id_bhvSmallBully, id_bhvSmallChillBully,
    id_bhvSpiny, id_bhvScuttlebug, id_bhvSkeeter, id_bhvSnufit, id_bhvSwoop,
    id_bhvMontyMole, id_bhvFlyGuy, id_bhvBulletBill, id_bhvBub,
    id_bhvMrBlizzard, id_bhvSpindrift, id_bhvFlyingBookend, id_bhvMoneybag,
}
pets.PREY_SET = {}
for _, id in ipairs(pets.PREY) do
    if id ~= nil then pets.PREY_SET[id] = true end
end

pets.EAT_KEY = "ofPetEat"
pets.EAT_ACTION = "peteat"
pets.PACKET_EAT_ASK = "petEatAsk"
pets.PACKET_EAT = "petEat"
pets.EAT_REACH = 400
pets.EAT_SNAP = 250
pets.EAT_GAP = 90
pets.EAT_LOOK_EVERY = 10

pets.EAT_LUNGE = 8

pets.lunges = {}

local lastMeal, hostLastMeal = {}, {}
local eatClock = 0

function pets.eat_on()
    return gGlobalSyncTable[pets.EAT_KEY] == "1"
end

function pets.eat_allowed()
    if not pets.eat_on() then return false end
    local lockdown = OF.lockdown
    if lockdown ~= nil and lockdown.round_or_run ~= nil and lockdown.round_or_run() then
        return false
    end
    return true
end

function pets.reset_options()
    if not OF.util.is_host() or not pets.eat_on() then return false end
    OF.util.publish(pets.EAT_KEY, nil)
    return true
end

function pets.reset_mine()
    if #pets.chosen_all(0) == 0 then return false end
    publish_keys({})
    return true
end

function pets.set_eat(on, askerLocal)
    if askerLocal == nil and not OF.perms.can("spawn_object") then
        return false, "Your rank cannot do that.", "spawn_object"
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(pets.EAT_ACTION, on and 1 or 0, nil, nil)
        end
        return false, "No host to ask yet - try again in a second."
    end
    OF.util.publish(pets.EAT_KEY, on and "1" or nil)
    return true, on and "Pets eat enemies now." or "Pets leave enemies alone."
end

function pets.is_prey(o)
    if o == nil or o.activeFlags == nil or o.activeFlags == 0 then return false end
    local listed = false
    for _, id in ipairs(pets.PREY) do
        if OF.util.optional("obj_has_behavior_id", 0, o, id) ~= 0 then
            listed = true
            break
        end
    end
    if not listed then return false end
    local arena = OF.arena
    if arena ~= nil then
        if arena.is_hushed ~= nil and arena.is_hushed(o) then return false end
        if arena.in_use ~= nil and arena.in_use(o) then return false end
    end
    return true
end

function pets.nearest_prey(x, y, z, reach)
    if obj_get_first_with_behavior_id == nil then return nil end
    local best, bestD = nil, reach * reach
    for _, id in ipairs(pets.PREY) do
        local o = obj_get_first_with_behavior_id(id)
        local seen = 0
        while o ~= nil and seen < 200 do
            seen = seen + 1
            if pets.is_prey(o) then
                local dx, dy, dz = o.oPosX - x, o.oPosY - y, o.oPosZ - z
                local d = dx * dx + dy * dy + dz * dz
                if d < bestD then best, bestD = o, d end
            end
            o = obj_get_next_with_same_behavior_id(o)
        end
    end
    return best
end

function pets.lunge_offset(n)
    local l = pets.lunges[n]
    if l == nil then return 0, 0, 0 end
    l.t = l.t + 1
    local half = pets.EAT_LUNGE / 2
    if l.t >= pets.EAT_LUNGE then
        pets.lunges[n] = nil
        return 0, 0, 0
    end
    local reach = l.t <= half and (l.t / half) or ((pets.EAT_LUNGE - l.t) / half)
    return (l.x - petX[n]) * reach, (l.y - petY[n]) * reach, (l.z - petZ[n]) * reach
end

function pets.eat_here(ownerLocal, slot, x, y, z)
    if ownerLocal == nil or type(x) ~= "number" or type(y) ~= "number"
        or type(z) ~= "number" then return false end
    if not pets.eat_allowed() then return false end
    if not should_have(ownerLocal) then return false end
    local m = gMarioStates[ownerLocal]
    if m == nil or m.pos == nil then return false end

    local ox, oz = m.pos.x - x, m.pos.z - z
    if ox * ox + oz * oz > (pets.EAT_REACH + TELEPORT) ^ 2 then return false end
    local prey = pets.nearest_prey(x, y, z, pets.EAT_SNAP)
    if prey == nil then return false end
    local arena = OF.arena
    if arena == nil or arena.hush == nil or not arena.hush(prey) then return false end
    local n = ownerLocal + ((slot == 2) and MAX_PLAYERS or 0)
    pets.lunges[n] = { x = prey.oPosX, y = prey.oPosY, z = prey.oPosZ, t = 0 }
    if OF.slots ~= nil and (id_bhvBlackSmokeUpward or id_bhvStarKeyCollectionPuffSpawner) ~= nil then
        OF.slots.spawn_non_sync(id_bhvBlackSmokeUpward or id_bhvStarKeyCollectionPuffSpawner,
            E_MODEL_NONE or 0, prey.oPosX, prey.oPosY + 40, prey.oPosZ, nil)
    end
    if prey.header ~= nil and prey.header.gfx ~= nil then
        OF.util.optional("play_sound", nil, SOUND_GENERAL_CHAIN_CHOMP2,
            prey.header.gfx.cameraToObject)
    end
    pets.eaten = (pets.eaten or 0) + 1
    return true
end

function pets.host_eat(ownerLocal, slot, x, y, z)
    if not OF.util.is_host() then return false end
    if not pets.eat_allowed() then return false end
    slot = (slot == 2) and 2 or 1
    if pets.in_force_slot(ownerLocal, slot) == nil then return false end
    local np = gNetworkPlayers[ownerLocal]
    if np == nil then return false end
    local key = ownerLocal * 2 + slot
    local now = eatClock
    if hostLastMeal[key] ~= nil and now - hostLastMeal[key] < pets.EAT_GAP then
        return false
    end
    hostLastMeal[key] = now
    OF.util.tell_all({ ofp = pets.PACKET_EAT, g = np.globalIndex, s = slot,
        x = x, y = y, z = z })
    pets.eat_here(ownerLocal, slot, x, y, z)
    return true
end

function pets.hunt()
    eatClock = eatClock + 1
    if (eatClock % pets.EAT_LOOK_EVERY) ~= 0 then return false end
    if not pets.eat_allowed() then return false end
    local asked = false
    for slot = 1, SLOTS do
        local n = (slot == 2) and MAX_PLAYERS or 0
        local o = objects[n]
        if o ~= nil and o.activeFlags ~= 0 and pets.lunges[n] == nil
            and (lastMeal[n] == nil or eatClock - lastMeal[n] >= pets.EAT_GAP) then
            local prey = pets.nearest_prey(petX[n], petY[n], petZ[n], pets.EAT_REACH)
            if prey ~= nil then
                lastMeal[n] = eatClock
                if OF.util.is_host() then
                    pets.host_eat(0, slot, prey.oPosX, prey.oPosY, prey.oPosZ)
                else
                    OF.util.send_to_host({ ofp = pets.PACKET_EAT_ASK, s = slot,
                        x = prey.oPosX, y = prey.oPosY, z = prey.oPosZ })
                end
                asked = true
            end
        end
    end
    return asked
end

hook_event(HOOK_UPDATE, pets.hunt)

local function on_eat_packet(data)
    if type(data) ~= "table" then return end
    if data.ofp == pets.PACKET_EAT_ASK then
        if not OF.util.is_host() then return end
        local asker = OF.util.asked_by(data)
        if asker == nil then return end
        pets.host_eat(asker, tonumber(data.s), tonumber(data.x), tonumber(data.y),
            tonumber(data.z))
        return
    end
    if data.ofp == pets.PACKET_EAT then
        if not OF.util.from_host_effect(data) then return end
        local owner = OF.util.local_from_global(tonumber(data.g))
        pets.eat_here(owner, tonumber(data.s), tonumber(data.x), tonumber(data.y),
            tonumber(data.z))
    end
end
pets.on_eat_packet = on_eat_packet
hook_event(HOOK_ON_PACKET_RECEIVE, on_eat_packet)

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_action") then
        OF.net.register_action(pets.EAT_ACTION, "spawn_object", function(fromLocal, x)
            return pets.set_eat(tonumber(x) == 1, fromLocal)
        end)
    end
end)

local NAME_KEY = "ofPetName"
pets.NAME_KEY = NAME_KEY
local NAME_STORE_KEY = "petname"
pets.NAME_STORE_KEY = NAME_STORE_KEY

local NAME_MAX = 16

pets.PACKET_ASK_CLEAR_NAME = "petClrNameAsk"
pets.PACKET_CLEAR_NAME = "petClrName"
local function trim(text)
    return (string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1"))
end

local NAME_SEP = "|"
function pets.named(localIndex, slot)
    local s = gPlayerSyncTable[localIndex]
    if s == nil then return "" end
    local name = s[NAME_KEY]
    if type(name) ~= "string" then return "" end
    local cut = string.find(name, NAME_SEP, 1, true)
    if slot == 2 then
        if cut == nil then return "" end
        return string.sub(name, cut + 1)
    end
    if cut == nil then return name end
    return string.sub(name, 1, cut - 1)
end

local function join_names(first, second)
    if second == nil or second == "" then return first end
    return first .. NAME_SEP .. second
end

local function names_fit(row)
    for part in string.gmatch(row .. NAME_SEP, "(.-)" .. NAME_SEP) do
        if #part > NAME_MAX then return false end
    end
    return true
end

local function staff(localIndex)
    if OF.util.is_host_player(localIndex) then return true end
    return OF.perms.tier(localIndex) >= OF.perms.required("mute", localIndex)
end

function pets.set_name(text, slot)
    slot = slot == 2 and 2 or 1
    if not OF.perms.can(NEED) then
        return false, "Your rank cannot do that.", NEED
    end
    if OF.util.asks(OF.mute, "is_muted") and OF.mute.is_muted(0) then
        return false, "You are muted - you cannot rename your pet."
    end
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(0) then
        return false, "You are jailed - you cannot rename your pet."
    end

    text = trim(string.gsub(string.gsub(OF.util.plain(tostring(text or "")),
        "%c", " "), "|", "/"))
    if #text > NAME_MAX then
        return false, OF.lang.fill("A pet's name is @ characters at most.", NAME_MAX)
    end

    if text ~= "" and OF.util.asks(OF.filter, "blocks") then
        local word = OF.filter.blocks(text)
        local hold = word ~= nil

        if hold and OF.util.asks(OF.trouble, "would") then
            local np = gNetworkPlayers[0]
            hold = OF.trouble.would("filter",
                "would have hidden a pet name from @ ('@')",
                np ~= nil and OF.util.plain(np.name) or "?", OF.util.plain(word))
        end
        if hold then
            return false, OF.lang.fill("That name is on the lobby filter ('@').",
                OF.util.plain(word))
        end
    end

    local row
    if slot == 2 then
        row = join_names(pets.named(0, 1), text)
    else
        row = join_names(text, pets.named(0, 2))
    end
    OF.util.publish_row(0, NAME_KEY, row)
    OF.util.store(NAME_STORE_KEY, row)
    return true
end

function pets.clear_name(localIndex)
    if localIndex == 0 then
        return false, "Use /pet name to clear your own."
    end
    if not staff(0) then
        return false, "Your rank cannot do that."
    end
    local globalIndex = network_global_index_from_local(localIndex)
    if globalIndex == nil then return false, "They are not here." end

    if not OF.util.is_host() then
        OF.util.send_to_host({ ofp = pets.PACKET_ASK_CLEAR_NAME, who = globalIndex })
        return true, "Asked the host."
    end

    if not OF.util.send_to_player(localIndex, { ofp = pets.PACKET_CLEAR_NAME }) then
        return false, "They are not here to tell."
    end
    return true
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= pets.PACKET_CLEAR_NAME then return end
    if not OF.util.from_host(data) then return end
    OF.util.publish_row(0, NAME_KEY, "")
    OF.util.store(NAME_STORE_KEY, "")
    if OF.util.asks(OF.notify, "show") then
        OF.notify.show("A moderator cleared your pet's name", "info", 5)
    end
end)

local function on_clear_name_ask(data)
    if data == nil or data.ofp ~= pets.PACKET_ASK_CLEAR_NAME then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    if not staff(asker) then
        OF.util.tell_asker(askerGlobal, "Your rank cannot do that.")
        return
    end
    local target = OF.util.local_from_global(data.who)
    local may, whyNot = OF.util.may_act_on(asker, target)
    if not may then
        OF.util.tell_asker(askerGlobal, whyNot)
        return
    end
    local ok, why = pets.clear_name(target)
    if not ok then OF.util.tell_asker(askerGlobal, why) end
end
hook_event(HOOK_ON_PACKET_RECEIVE, on_clear_name_ask)

function pets.chat_pet(msg)
    msg = trim(msg or "")
    local word, rest = string.match(msg, "^(%S*)%s*(.*)$")
    word = string.lower(word or "")

    if word == "" or word == "help" then
        OF.util.chat(OF.lang.t(
            "/pet name <text> - name your pet, blank clears it. /pet name2 <text> - the one behind it. /pet clearname <player> - a moderator clears theirs."))
        return true
    end
    if word == "name" then
        OF.util.report(pets.set_name(rest, 1))
        return true
    end
    if word == "name2" then
        OF.util.report(pets.set_name(rest, 2))
        return true
    end
    if word == "clearname" then
        local target = OF.util.find_player_by_name(rest)
        if target == nil then
            OF.util.report(false, "Clear whose pet's name? /pet clearname <player>")
            return true
        end
        OF.util.report(pets.clear_name(target))
        return true
    end
    OF.util.chat(OF.lang.t("/pet name <text>, or /pet clearname <player>."))
    return true
end

hook_chat_command("pet",
    "name <text> - name your pet, blank clears it; name2 <text> - name the second one; clearname <player> - a moderator clears theirs",
    function(msg) return pets.chat_pet(msg or "") end)

hook_event(HOOK_ON_MODS_LOADED, function()
    local stored = mod_storage_load(NAME_STORE_KEY)
    if stored == nil or stored == "" then return end
    if not names_fit(stored) then return end
    if not OF.perms.can(NEED) then return end
    OF.util.publish_row(0, NAME_KEY, stored)
end)

local NAME_FADE_RANGE = 1600

local NAME_LIFT = 130
local NAME_SCALE = 0.7

local NAME_ALPHA_FLOOR = 60

local nameWorld = { x = 0, y = 0, z = 0 }
local nameScreen = { x = 0, y = 0, z = 0 }

local function draw_name(o, entry, name)
    if OF.util.has_flag(o.header.gfx.node.flags, GRAPH_INVISIBLE) then return end

    local eye = gLakituState
    local dist = NAME_FADE_RANGE
    if eye ~= nil and eye.pos ~= nil then
        local dx, dy, dz = o.oPosX - eye.pos.x, o.oPosY - eye.pos.y, o.oPosZ - eye.pos.z
        dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    end
    if dist >= NAME_FADE_RANGE then return end
    local close = 1 - dist / NAME_FADE_RANGE
    local alpha = math.floor(NAME_ALPHA_FLOOR + (255 - NAME_ALPHA_FLOOR) * close)

    nameWorld.x = o.oPosX
    nameWorld.y = o.oPosY + NAME_LIFT * (entry.scale or 1)
    nameWorld.z = o.oPosZ
    if not OF.util.world_screen(nameWorld, nameScreen) then return end

    local width = OF.util.width(name, NAME_SCALE)
    OF.util.text(name, nameScreen.x - width * 0.5, nameScreen.y, NAME_SCALE,
        255, 255, 255, alpha)
end

hook_event(HOOK_ON_HUD_RENDER, function()
    if OF.util.menu_has_screen() then return end
    local ready = false
    for n = 0, COUNT - 1 do
        local o = objects[n]
        if o ~= nil and o.activeFlags ~= 0 then
            local name = pets.named(n % MAX_PLAYERS, n < MAX_PLAYERS and 1 or 2)
            if name ~= "" then
                local entry = pets.BY_KEY[objectKey[n]]
                if entry ~= nil then
                    if not ready then
                        djui_hud_set_resolution(RESOLUTION_DJUI)
                        djui_hud_set_font(FONT_NORMAL)
                        ready = true
                    end
                    draw_name(o, entry, name)
                end
            end
        end
    end
end)

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end

    if panel.PAGES.pets == nil then

        panel.PAGES.pets = {
            title = "Pets", tab = "room", up = "shapes",
            build = function() return pets.build_page(panel) end,
        }
    end
end)

function pets.build_page(panel)
    local rows = {}
    local all = pets.chosen_all(0)
    local now = pets.chosen(0)

    if now ~= nil then
        local names = all[2] ~= nil and (now.name .. " + " .. all[2].name) or now.name
        rows[#rows + 1] = panel.with_help(
            panel.label_row(OF.lang.fill("Following you: @", names)),
            all[2] ~= nil and OF.lang.t("everybody sees them walk behind you, in a line")
                or OF.lang.t("everybody sees it walk behind you"))
        rows[#rows + 1] = panel.with_help(
            panel.gated_row(NEED,
                all[2] ~= nil and OF.lang.t("Send them home") or OF.lang.t("Send it home"),
                255, 200, 120,
                function() OF.util.report(pets.set(nil)) end),
            OF.lang.t("nothing follows you any more"))
        if pets.round_hides(0) then
            rows[#rows + 1] = panel.label_row(OF.lang.t(
                "A round is on, so it waits until the round ends."))
        end
    else
        rows[#rows + 1] = panel.with_help(
            panel.label_row(OF.lang.t("Nothing follows you.")),
            OF.lang.t("pick up to two below and they walk where you walk"))
    end

    local myName = pets.named(0, 1)
    rows[#rows + 1] = panel.with_walk(panel.with_help(
        panel.label_row(OF.lang.fill("Name: @",
            myName ~= "" and myName or OF.lang.t("(none)"))),
        OF.lang.t("type /pet name <text> in chat")))

    local second = pets.named(0, 2)
    rows[#rows + 1] = panel.with_walk(panel.with_help(
        panel.label_row(OF.lang.fill("Second name: @",
            second ~= "" and second or OF.lang.t("(none)"))),
        OF.lang.t("type /pet name2 <text> in chat")))

    rows[#rows + 1] = panel.with_help(
        panel.gated_row(NEED, OF.lang.t("Surprise me"), 120, 255, 120,
            function()
                OF.util.report(pets.set(
                    pets.random_key(now and now.key, all[2] and all[2].key)))
            end),
        OF.lang.fill("one of the @, and never one you have", pets.count()))

    local eats = pets.eat_on()
    local eatRow = panel.with_help(
        panel.gated_row("spawn_object", panel.tick(eats, OF.lang.t("Pets eat enemies")),
            255, 255, 255,
            function() OF.util.report(pets.set_eat(not eats)) end),
        OF.lang.t("a pet eats small enemies near it, never in a round"))
    rows[#rows + 1] = eatRow

    for _, group in ipairs(pets.GROUPS) do
        rows[#rows + 1] = panel.header_row(OF.lang.t(group.name))
        for _, entry in ipairs(pets.CATALOGUE) do
            if entry.group == group.key then
                local key = entry.key
                local slot = pets.slot_of(0, key)
                local mine = slot ~= nil
                rows[#rows + 1] = panel.with_help(
                    panel.gated_row(NEED, panel.tick(mine, entry.name), 255, 255, 255,
                        function()

                            OF.util.report(pets.toggle(key))
                        end),
                    mine and OF.lang.t("press again to send it home")
                        or (entry.fly and OF.lang.t("flies along behind you")
                            or OF.lang.t("walks along behind you")))
            end
        end
    end

    rows[#rows + 1] = panel.back_row("shapes")
    panel.all_for_me(rows)

    eatRow.mine = nil
    return rows
end
