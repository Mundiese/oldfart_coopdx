OF = OF or {}
OF.forge = OF.forge or {}

local forge = OF.forge

forge.open = false
forge.held = nil
forge.heldKey = nil

local sizeHold = 0
local SIZE_HOLD_FRAMES = 6

forge.distance = 300
forge.height = 80

forge.sideways = 0
forge.size = 4

local MIN_DISTANCE = 90
local MAX_DISTANCE = 1400
local STEP = 40
local ROTATE_STEP = 4096
local GRAB_RANGE = 700

local SIZES = { 0.3, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0 }
local SIZE_NAMES = { "Tiny", "Small", "A bit small", "Normal", "A bit big",
                     "Huge", "Enormous" }
local NORMAL_SIZE = 4

local PUBLISH_BUDGET = 256
local ROW_WIDTH = 3 + 1 + 5 + 1 + 1
local MAX_RESIZED = math.floor((PUBLISH_BUDGET + 1) / (ROW_WIDTH + 1))

forge.placed = {}

local batchSeq = 0
local openBatch = nil

local function begin_batch()
    batchSeq = batchSeq + 1
    openBatch = batchSeq
    return openBatch
end

local function end_batch()
    openBatch = nil
end

local function next_batch()
    if openBatch ~= nil then return openBatch end
    batchSeq = batchSeq + 1
    return batchSeq
end

local UNDONE_MAX = 8
local undone = {}

local function forget_redo()
    undone = {}
end

function forge.undone_count()
    return #undone
end

function forge.turned_yaw(yaw, direction, scale)
    return (yaw or 0) + ROTATE_STEP * direction * (scale or 1)
end

local function angle_of(m)
    return m.faceAngle.y
end

local function carry_spot(m, sideways)
    local angle = angle_of(m)

    sideways = sideways or 0

    return m.pos.x + sins(angle) * forge.distance + coss(angle) * sideways,
           m.pos.y + forge.height,
           m.pos.z + coss(angle) * forge.distance - sins(angle) * sideways
end

local function is_mine(object)
    if object == nil then return false end
    if object.oSyncID == nil then return true end
    return sync_object_is_owned_locally(object.oSyncID) == true
end

function forge.size_count()
    return #SIZES
end

function forge.size_name(step)
    return SIZE_NAMES[step or forge.size] or SIZE_NAMES[NORMAL_SIZE]
end

local function apply_size(object, step)
    if object == nil or object.activeFlags == 0 then return false end

    if OF.util.binding("obj_scale") == nil then return false end
    obj_scale(object, SIZES[step] or 1.0)
    return true
end

local function entry_for(object)
    for _, entry in ipairs(forge.placed) do
        if entry.object == object then return entry end
    end
    return nil
end

local function resized()
    local list = {}
    for _, entry in ipairs(forge.placed) do
        local object = entry.object
        if object ~= nil and object.activeFlags ~= 0
            and (entry.size or NORMAL_SIZE) ~= NORMAL_SIZE
            and object.oSyncID ~= nil then
            table.insert(list, entry)
        end
    end
    return list
end

local keyIndex = nil

local function index_of_key(key)
    if keyIndex == nil then
        keyIndex = {}
        for i, entry in ipairs((OF.spawner or {}).LIST or {}) do
            keyIndex[entry.key] = i
        end
    end
    return keyIndex[key]
end

local function live_with_sync_id(bhv, syncId)
    if bhv == nil or syncId == nil then return nil end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return nil end

    local object = obj_get_first_with_behavior_id(bhv)
    local guard = 0
    while object ~= nil and guard < 512 do
        if object.oSyncID == syncId then return object end
        object = obj_get_next_with_same_behavior_id(object)
        guard = guard + 1
    end
    return nil
end

local function live_by_sync_id(bhv)
    local found = {}
    if bhv == nil then return found end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return found end

    local object = obj_get_first_with_behavior_id(bhv)
    local guard = 0
    while object ~= nil and guard < 512 do
        if object.oSyncID ~= nil then found[object.oSyncID] = object end
        object = obj_get_next_with_same_behavior_id(object)
        guard = guard + 1
    end
    return found
end

function forge.publish_sizes()
    local rows = {}
    for _, entry in ipairs(resized()) do
        local at = index_of_key(entry.key)
        if at ~= nil then
            table.insert(rows, at .. ":" .. tostring(entry.object.oSyncID)
                .. ":" .. tostring(entry.size))
        end
    end
    local packed, used = OF.util.pack_rows(rows)
    return OF.util.publish_row(0, "ofForgeSize", packed), #rows - used
end

function forge.apply_published()

    local index = {}
    local function objects_of(bhv)
        if index[bhv] == nil then index[bhv] = live_by_sync_id(bhv) end
        return index[bhv]
    end

    for i = 0, MAX_PLAYERS - 1 do
        local row = gPlayerSyncTable[i]
        local packed = row ~= nil and row.ofForgeSize or nil
        if type(packed) == "string" and packed ~= "" then
            for chunk in string.gmatch(packed, "[^;]+") do

                local at, id, step = string.match(chunk, "^(%d+):(%d+):(%d+)$")
                if at ~= nil then
                    local spawn = ((OF.spawner or {}).LIST or {})[tonumber(at)]
                    if spawn ~= nil then
                        apply_size(objects_of(spawn.bhv)[tonumber(id)],
                            tonumber(step))
                    end
                end
            end
        end
    end
end

local REACH_KEY = "ofForgeReach"
local function restore_reach(spawn)
    if spawn == nil or spawn.reach == nil or spawn.bhv == nil then return end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return end

    local network = COOP_OBJ_FLAG_NETWORK or 0x1
    local object = obj_get_first_with_behavior_id(spawn.bhv)
    local guard = 0
    while object ~= nil and guard < 512 do
        if OF.util.has_flag(object.coopFlags or 0, network)
            and (object.oCollisionDistance or 0) < spawn.reach then
            object.oCollisionDistance = spawn.reach
        end
        object = obj_get_next_with_same_behavior_id(object)
        guard = guard + 1
    end
end

function forge.publish_reach()
    local seen, list = {}, {}
    for _, entry in ipairs(forge.placed) do
        local object = entry.object
        if object ~= nil and object.activeFlags ~= 0 then
            local at = index_of_key(entry.key)
            local spawn = at ~= nil
                and ((OF.spawner or {}).LIST or {})[at] or nil
            if spawn ~= nil and spawn.reach ~= nil and not seen[at] then
                seen[at] = true
                table.insert(list, tostring(at))
            end
        end
    end
    return OF.util.publish_row(0, REACH_KEY,
        OF.util.pack_rows(list, ","))
end

function forge.apply_reach()
    local done = {}
    for i = 0, MAX_PLAYERS - 1 do
        local row = gPlayerSyncTable[i]
        local packed = row ~= nil and row[REACH_KEY] or nil
        if type(packed) == "string" and packed ~= "" then
            for at in string.gmatch(packed, "%d+") do
                local index = tonumber(at)
                if index ~= nil and not done[index] then
                    done[index] = true
                    restore_reach(((OF.spawner or {}).LIST or {})[index])
                end
            end
        end
    end
end

function forge.sizeless_in_hand()
    local key = forge.heldKey or forge.in_hand()
    if key == nil then return nil end
    if not OF.util.asks(OF.spawner, "keeps_size") then return nil end
    if OF.spawner.keeps_size(key) then return nil end
    return key
end

function forge.set_size(step)
    step = OF.util.clamp(math.floor(tonumber(step) or NORMAL_SIZE), 1, #SIZES)

    local deaf = forge.sizeless_in_hand()
    if deaf ~= nil and step ~= NORMAL_SIZE then
        forge.size = step
        return false, "That one sets its own size every frame - the slider cannot hold it."
    end

    if forge.foreign_held() then
        forge.size = step
        return false,
            "That one is the level's - its size cannot be sent to the lobby."
    end

    local entry = entry_for(forge.held)
    if entry ~= nil then
        local was = entry.size or NORMAL_SIZE
        if step ~= NORMAL_SIZE and was == NORMAL_SIZE
            and #resized() >= MAX_RESIZED then
            return false, "That is as many resized objects as the lobby can be told about."
        end
        entry.size = step
        apply_size(entry.object, step)
    end

    forge.size = step
    if entry ~= nil then forge.publish_sizes() end
    return true
end

local wasOpenBeforeHold = false

local function room_is_held()
    if OF.util.asks(OF.lockdown, "menu_stands_down") then
        return OF.lockdown.menu_stands_down()
    end
    return false
end

forge.room_is_held = room_is_held

function forge.mode_live()
    return forge.open == true
end

function forge.mode_suspend()
    if not forge.open then return false end
    forge.open = false

    forge.drop()
    return true
end

function forge.mode_resume()
    if forge.open then return true end

    if not OF.perms.can("spawn_object") then return false end
    if room_is_held() then return false end
    forge.open = true
    return true
end

hook_event(HOOK_UPDATE, function()
    local held = room_is_held()
    if held and forge.open then
        wasOpenBeforeHold = true
        forge.open = false
        forge.drop()

        OF.util.leave_mode("forge")
        OF.notify.show("Forge put away until the round ends", "warn", 4)
    elseif not held and wasOpenBeforeHold then
        wasOpenBeforeHold = false

        if OF.perms.can("spawn_object") then

            local ok = OF.util.enter_mode("forge")
            if ok then
                forge.open = true
                OF.notify.show("Forge back on", "good", 4)
            end
        end
    end
end)

function forge.toggle()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end

    if not forge.open and room_is_held() then
        return false, "A round is on - the forge is put away until it ends."
    end

    if not forge.open then
        local ok, why = OF.util.enter_mode("forge")
        if not ok then return false, why end
    end
    forge.open = not forge.open
    if not forge.open then
        OF.util.leave_mode("forge")
        forge.drop()

        forge.slot = 1
        forge.select_inventory(1)
    end
    OF.notify.show(forge.open and "Forge on - B places, L+B copies, Z deletes"
        or "Forge off", "info", 5)
    return true
end

function forge.hold(object, key)
    forge.held = object
    forge.heldKey = key

    forge.sideways = 0
end

local BAR_SLOTS = 6

local BAR_PAGES = 3
local BAR_STORE = "forge_bar"
forge.bars = {}
for page = 1, BAR_PAGES do forge.bars[page] = {} end
forge.inventory = 1
forge.bar = forge.bars[1]
forge.slot = 1

local function use_inventory(index)
    forge.inventory = ((math.floor(index) - 1) % BAR_PAGES) + 1
    forge.bar = forge.bars[forge.inventory]
end

function forge.inventory_count()
    return BAR_PAGES
end

function forge.select_inventory(index)
    if type(index) ~= "number" then return false end
    use_inventory(index)
    OF.sounds.play(OF.sounds.MOVE)
    return true
end

function forge.next_inventory()
    return forge.select_inventory(forge.inventory + 1)
end

function forge.in_hand()
    return forge.bar[forge.slot]
end

function forge.slot_count()
    return BAR_SLOTS
end

local PAGE_SEP = ";"
local function pack_page(page)
    local parts = {}
    for i = 1, BAR_SLOTS do
        table.insert(parts, (forge.bars[page] or {})[i] or "")
    end
    return table.concat(parts, ",")
end

local function pack_bar()
    local pages = {}
    for page = 1, BAR_PAGES do
        table.insert(pages, pack_page(page))
    end
    return table.concat(pages, PAGE_SEP)
end

function forge.pack_widest()
    local longest = 0

    for _, entry in ipairs((OF.spawner or {}).LIST or {}) do
        if #entry.key > longest then longest = #entry.key end
    end
    return BAR_PAGES * (BAR_SLOTS * (longest + 1) - 1) + (BAR_PAGES - 1)
end

local function save_bar()
    OF.util.store(BAR_STORE, pack_bar())
end

function forge.load_bar()
    for page = 1, BAR_PAGES do forge.bars[page] = {} end
    use_inventory(1)
    forge.slot = 1
    local packed = OF.util.optional("mod_storage_load", "", BAR_STORE, "")
    if type(packed) ~= "string" or packed == "" then return false end

    local page = 0
    for chunk in string.gmatch(packed .. PAGE_SEP, "([^" .. PAGE_SEP .. "]*)" .. PAGE_SEP) do
        page = page + 1
        if page > BAR_PAGES then break end
        local index = 0
        for part in string.gmatch(chunk .. ",", "([^,]*),") do
            index = index + 1
            if index > BAR_SLOTS then break end
            if part ~= "" and OF.util.asks(OF.spawner, "find")
                and OF.spawner.find(part) ~= nil then
                forge.bars[page][index] = part
            end
        end
    end
    return true
end

function forge.set_slot(key)
    forge.bar[forge.slot] = key
    save_bar()
    return true
end

function forge.clear_bar()
    forge.bars[forge.inventory] = {}
    use_inventory(forge.inventory)
    forge.slot = 1
    save_bar()
    return true
end

function forge.clear_bars()
    for page = 1, BAR_PAGES do forge.bars[page] = {} end
    use_inventory(1)
    forge.slot = 1
    save_bar()
    return true
end

function forge.select_slot(index)
    if type(index) ~= "number" then return false end

    forge.slot = ((math.floor(index) - 1) % BAR_SLOTS) + 1
    OF.sounds.play(OF.sounds.MOVE)
    return true
end

function forge.next_slot()
    return forge.select_slot(forge.slot + 1)
end

function forge.step_inventory(step)
    step = (step ~= nil and step < 0) and -1 or 1
    local want = forge.slot + step
    if want > BAR_SLOTS then
        use_inventory(forge.inventory + 1)
        want = 1
    elseif want < 1 then
        use_inventory(forge.inventory - 1)
        want = BAR_SLOTS
    end
    return forge.select_slot(want)
end

function forge.slot_name(index)
    local key = forge.bar[index]
    if key == nil then return nil end
    if not OF.util.asks(OF.spawner, "find") then return nil end
    local entry = OF.spawner.find(key)
    return entry ~= nil and entry.name or nil
end

function forge.drop()
    if forge.held == nil then return false end

    local wasForeign = forge.foreign_held()
    forge.held = nil
    forge.heldKey = nil
    if wasForeign then forge.publish_moved() end
    OF.sounds.play(OF.sounds.PICK)
    return true
end

function forge.forget_kind()
    if forge.in_hand() == nil then return false end
    forge.set_slot(nil)
    OF.sounds.play(OF.sounds.BACK)
    return true
end

function forge.kind_name()
    return forge.slot_name(forge.slot)
end

function forge.place(key, sideways)
    if not forge.open then
        local ok, why = forge.toggle()
        if not ok then return false, why end
    end

    local m = gMarioStates[0]
    if m == nil then return false end

    local x, y, z = carry_spot(m, sideways)
    local object, entry = OF.spawner.spawn_at(key, x, y, z)
    if object == nil then return false, "Nothing was placed." end

    local size = forge.size
    if size ~= NORMAL_SIZE and #resized() >= MAX_RESIZED then
        size = NORMAL_SIZE
        OF.notify.show(

            "That is all the lobby can be told about - this one is normal.",
            "warn", 5)
    end

    forget_redo()
    local placedEntry = { object = object, key = key, size = size,
                          batch = next_batch() }
    table.insert(forge.placed, placedEntry)
    apply_size(object, size)
    if size ~= NORMAL_SIZE then forge.publish_sizes() end

    forge.publish_reach()

    forge.hold(object, key)

    forge.set_slot(key)
    OF.notify.show("@ - B puts it down, B again for another", "good", 3, entry.name)
    return true
end

function forge.count()
    local alive = {}
    local placed = 0
    for _, entry in ipairs(forge.placed) do
        if entry.object ~= nil and entry.object.activeFlags ~= 0 then
            table.insert(alive, entry)
            if not entry.foreign then placed = placed + 1 end
        end
    end
    forge.placed = alive
    return placed
end

function forge.nearest(m, at, range)
    at = at or m.pos
    local best, bestDistance = nil, range or GRAB_RANGE
    for _, entry in ipairs(forge.placed) do
        local object = entry.object
        if object ~= nil and object.activeFlags ~= 0 then
            local dx = object.oPosX - at.x
            local dy = object.oPosY - at.y
            local dz = object.oPosZ - at.z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            if distance < bestDistance then
                best = entry
                bestDistance = distance
            end
        end
    end
    return best
end

local LEVEL_SPINE = {
    id_bhvDoorWarp, id_bhvStar, id_bhvExitPodiumWarp, id_bhvWarp,
    id_bhvWarpPipe, id_bhvFadingWarp, id_bhvInstantActiveWarp, id_bhvAirborneWarp,
    id_bhvHardAirKnockBackWarp, id_bhvSpinAirborneCircleWarp, id_bhvDeathWarp,
    id_bhvSpinAirborneWarp, id_bhvFlyingWarp, id_bhvSwimmingWarp,
    id_bhvPaintingStarCollectWarp, id_bhvPaintingDeathWarp,
    id_bhvAirborneStarCollectWarp, id_bhvAirborneDeathWarp,
    id_bhvLaunchStarCollectWarp, id_bhvLaunchDeathWarp,
}

forge.LEVEL_SPINE = LEVEL_SPINE

local SPINE_NAMES = {
    "Door", "Level start", "Podium", "Pipe",
    "Pipe", "Fade in", "Instant", "Airborne",
    "Knocked back", "Spin in", "Death", "Spin in",
    "Flying in", "Swimming in",
    "Star, painting", "Death, painting",
    "Star, airborne", "Death, airborne",
    "Star, launch", "Death, launch",
}

forge.SPINE_NAMES = SPINE_NAMES

local EDIT_LISTS = {
    OBJ_LIST_SURFACE, OBJ_LIST_LEVEL, OBJ_LIST_DEFAULT,
    OBJ_LIST_GENACTOR, OBJ_LIST_PUSHABLE, OBJ_LIST_POLELIKE,
    OBJ_LIST_DESTRUCTIVE, OBJ_LIST_SPAWNER,
}

forge.EDIT_LISTS = EDIT_LISTS

local function origin_of(object)
    return {
        x = object.oPosX, y = object.oPosY, z = object.oPosZ,
        yaw = object.oFaceAngleYaw or 0, pitch = object.oFaceAnglePitch or 0,
        homeX = object.oHomeX, homeY = object.oHomeY, homeZ = object.oHomeZ,
    }
end

local KINDRED = {
    { id = id_bhvYellowCoin,          key = "coin" },
    { id = id_bhvOneCoin,             key = "coin" },
    { id = id_bhvTemporaryYellowCoin, key = "coin" },
    { id = id_bhvMovingYellowCoin,    key = "coin" },
    { id = id_bhvCoinInsideBoo,       key = "coin" },
    { id = id_bhvCoinFormationSpawn,  key = "coin" },
    { id = id_bhvHiddenBlueCoin,      key = "bluecoin" },
    { id = id_bhvBlueCoinSliding,     key = "bluecoin" },
    { id = id_bhvMovingBlueCoin,      key = "bluecoin" },
    { id = id_bhvMrIBlueCoin,         key = "bluecoin" },
    { id = id_bhvHiddenRedCoinStar,   key = "redcoin" },
    { id = id_bhvVanishCap,           key = "wingcap" },
    { id = id_bhvMetalCap,            key = "wingcap" },
    { id = id_bhvWingCap,             key = "wingcap" },
    { id = id_bhvJumpingBox,          key = "box" },
    { id = id_bhvTuxiesMother,        key = "penguin" },
}

forge.KINDRED = KINDRED

local function kind_of(object)
    if object == nil then return nil end
    for _, item in ipairs((OF.spawner or {}).LIST or {}) do
        if item.bhv ~= nil
            and OF.util.optional("obj_has_behavior_id", 0, object, item.bhv) ~= 0 then
            return item.key, item.name
        end
    end
    for _, row in ipairs(KINDRED) do
        if row.id ~= nil
            and OF.util.optional("obj_has_behavior_id", 0, object, row.id) ~= 0 then
            local name = nil
            if OF.util.asks(OF.spawner, "find") then
                local item = OF.spawner.find(row.key)
                name = item ~= nil and item.name or nil
            end
            return row.key, name
        end
    end
    return nil
end

forge.kind_of = kind_of

function forge.editable(object)
    if object == nil then return false, "Nothing within reach." end
    if object.activeFlags == 0 then return false, "That one is already gone." end

    for i = 0, MAX_PLAYERS - 1 do
        local other = gMarioStates[i]
        if other ~= nil and other.marioObj == object then
            return false, "That is a player."
        end
    end

    for _, id in ipairs(LEVEL_SPINE) do
        if id ~= nil and OF.util.optional("obj_has_behavior_id", 0, object, id) ~= 0 then
            return false, "That is a warp - the level lands people on it."
        end
    end

    for i = 0, MAX_PLAYERS - 1 do
        local other = gMarioStates[i]
        if other ~= nil then
            if other.heldObj == object or other.heldByObj == object
                or other.usedObj == object or other.riddenObj == object
                or (other.marioObj ~= nil and other.marioObj.platform == object) then
                return false, "Somebody is using that right now."
            end
        end
    end

    if object.parentObj ~= nil and object.parentObj ~= object then
        return false, "Something else in the level holds that in place."
    end

    local waypoint = object.oPathedStartWaypoint
    if waypoint ~= nil and waypoint ~= 0 then
        return false, "The level walks that along a path of its own."
    end

    local node = object.header ~= nil and object.header.gfx ~= nil
        and object.header.gfx.node or nil
    if node ~= nil and type(node.flags) == "number"
        and not OF.util.has_flag(node.flags, GRAPH_RENDER_ACTIVE) then
        return false, "You cannot see that one - the level does not draw it."
    end

    local syncId = object.oSyncID
    if syncId == nil or syncId == 0
        or OF.util.optional("sync_object_is_initialized", false, syncId) ~= true then
        local _, name = kind_of(object)
        if name ~= nil then
            return false, OF.lang.fill(
                "@ is not networked - it would move on your screen only.", name)
        end
        return false, "That one is not networked - it would move on your screen only."
    end

    if OF.util.optional("sync_object_is_owned_locally", false, syncId) ~= true then
        return false, "Somebody is nearer to that one - the lobby would put it back."
    end

    return true
end

local MOVED_KEY = "ofForgeMoved"
local MOVED_ROW = 5 + 1 + 6 + 1 + 6 + 1 + 6 + 1 + 5
local MAX_MOVED = math.floor((PUBLISH_BUDGET + 1) / (MOVED_ROW + 1))

forge.MAX_MOVED = MAX_MOVED

local function borrowed()
    local list = {}
    for _, entry in ipairs(forge.placed) do
        if entry.foreign and entry.object ~= nil
            and entry.object.activeFlags ~= 0 then
            table.insert(list, entry)
        end
    end
    return list
end

function forge.borrowed_count()
    local n = 0
    for _, entry in ipairs(forge.placed) do
        if entry.foreign and entry.object ~= nil
            and entry.object.activeFlags ~= 0 then
            n = n + 1
        end
    end
    return n
end

function forge.foreign_held()
    if forge.held == nil then return false end
    for _, entry in ipairs(forge.placed) do
        if entry.object == forge.held then return entry.foreign == true end
    end
    return false
end

local function held_entry()
    if forge.held == nil then return nil end
    for _, entry in ipairs(forge.placed) do
        if entry.object == forge.held then return entry end
    end
    return nil
end

local function level_by_sync_id()
    local found = {}
    if OF.util.binding("obj_get_first") == nil then return found end
    for _, list in ipairs(EDIT_LISTS) do
        local object = obj_get_first(list)
        local guard = 0
        while object ~= nil and guard < 512 do
            local id = object.oSyncID
            if id ~= nil and id ~= 0 and object.activeFlags ~= 0 then
                found[id] = object
            end
            object = obj_get_next(object)
            guard = guard + 1
        end
    end
    return found
end

function forge.publish_moved()
    local rows = {}
    for _, entry in ipairs(borrowed()) do
        local object = entry.object
        if object ~= forge.held then
            entry.moved = {
                x = math.floor(object.oPosX or 0),
                y = math.floor(object.oPosY or 0),
                z = math.floor(object.oPosZ or 0),
                yaw = math.floor(object.oFaceAngleYaw or 0) % 0x10000,
            }
        end
        local moved = entry.moved
        if moved ~= nil then
            table.insert(rows, table.concat({
                tostring(object.oSyncID),
                tostring(moved.x),
                tostring(moved.y),
                tostring(moved.z),
                tostring(moved.yaw),
            }, ":"))
        end
    end
    local packed, used = OF.util.pack_rows(rows)
    return OF.util.publish_row(0, MOVED_KEY, packed), #rows - used
end

local movedSeen = {}

function forge.apply_moved()
    local index = nil
    local standing = {}

    for i = 0, MAX_PLAYERS - 1 do
        local row = gPlayerSyncTable[i]
        local packed = row ~= nil and row[MOVED_KEY] or nil
        if type(packed) == "string" and packed ~= "" then
            for chunk in string.gmatch(packed, "[^;]+") do
                local id, x, y, z, yaw =
                    string.match(chunk, "^(%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%d+)$")
                if id ~= nil then
                    if index == nil then index = level_by_sync_id() end
                    id = tonumber(id)
                    standing[id] = true
                    local object = index[id]

                    if object ~= nil and object ~= forge.held then
                        local seen = movedSeen[id]
                        if seen == nil then

                            local entry = nil
                            for _, placed in ipairs(forge.placed) do
                                if placed.object == object then entry = placed end
                            end
                            seen = { origin = entry ~= nil and entry.origin
                                or origin_of(object) }
                            movedSeen[id] = seen
                        end
                        if seen.row ~= chunk then
                            seen.row = chunk
                            object.oPosX = tonumber(x)
                            object.oPosY = tonumber(y)
                            object.oPosZ = tonumber(z)
                            object.oHomeX, object.oHomeY, object.oHomeZ =
                                object.oPosX, object.oPosY, object.oPosZ
                            OF.spawner.face(object, tonumber(yaw))
                            OF.util.optional("obj_update_gfx_pos_and_angle",
                                nil, object)

                            OF.util.skip_interpolation(object)
                        end
                    end
                end
            end
        end
    end

    for id, seen in pairs(movedSeen) do
        if not standing[id] then
            if index == nil then index = level_by_sync_id() end
            local object = index[id]
            if object ~= nil and object ~= forge.held then
                forge.restore({ object = object, origin = seen.origin })
            end
            movedSeen[id] = nil
        end
    end
end

function forge.moved_seen_count()
    local n = 0
    for _ in pairs(movedSeen) do n = n + 1 end
    return n
end

function forge.forget_moved()
    movedSeen = {}
end

function forge.restore(entry)
    if entry == nil or entry.origin == nil then return false end

    entry.moved = nil
    local object = entry.object
    if object == nil or object.activeFlags == 0 then return false end
    local origin = entry.origin
    object.oPosX, object.oPosY, object.oPosZ = origin.x, origin.y, origin.z
    object.oHomeX, object.oHomeY, object.oHomeZ =
        origin.homeX, origin.homeY, origin.homeZ

    OF.spawner.face(object, origin.yaw)
    object.oFaceAnglePitch = origin.pitch
    OF.util.optional("obj_update_gfx_pos_and_angle", nil, object)

    OF.util.skip_interpolation(object)
    return true
end

function forge.put_back_all()
    local put, lost = 0, 0
    local kept = {}
    for _, entry in ipairs(forge.placed) do
        if entry.foreign then
            if forge.restore(entry) then put = put + 1 else lost = lost + 1 end
            if forge.held == entry.object then
                forge.held = nil
                forge.heldKey = nil
            end
        else
            table.insert(kept, entry)
        end
    end
    forge.placed = kept
    forge.publish_moved()
    if put == 0 and lost == 0 then
        return false, "None of the level's own has been moved."
    end
    return true, put, lost
end

function forge.nearest_level(m, at, range)
    if OF.util.binding("obj_get_first") == nil then return nil end
    at = at or m.pos
    range = range or GRAB_RANGE

    local best, bestSquare = nil, range * range
    local why, whySquare = nil, range * range
    local mine = {}
    for _, entry in ipairs(forge.placed) do
        if entry.object ~= nil then mine[entry.object] = true end
    end

    for _, list in ipairs(EDIT_LISTS) do
        local object = obj_get_first(list)
        local guard = 0
        while object ~= nil and guard < 512 do
            if not mine[object] then
                local dx = (object.oPosX or 0) - at.x
                local dy = (object.oPosY or 0) - at.y
                local dz = (object.oPosZ or 0) - at.z
                local square = dx * dx + dy * dy + dz * dz
                if square < bestSquare or square < whySquare then
                    local ok, reason = forge.editable(object)
                    if ok and square < bestSquare then
                        best, bestSquare = object, square
                    elseif not ok and square < whySquare then
                        why, whySquare = reason, square
                    end
                end
            end
            object = obj_get_next(object)
            guard = guard + 1
        end
    end

    return best, why, math.sqrt(bestSquare)
end

local AIM_RANGE = 170

function forge.aim_spot(m)
    local x, y, z = carry_spot(m)
    return { x = x, y = y, z = z }
end

function forge.sighted(m, cursorOnly)
    if m == nil then return nil end
    local at = forge.aim_spot(m)

    local entry = forge.nearest(m, at, AIM_RANGE)
    if entry ~= nil then return entry.object, entry, nil end
    local object, why = forge.nearest_level(m, at, AIM_RANGE)
    if object ~= nil then return object, nil, nil end
    if cursorOnly then return nil, nil, why end

    entry = forge.nearest(m)
    if entry ~= nil then return entry.object, entry, nil end
    local far, farWhy = forge.nearest_level(m)
    return far, nil, farWhy or why
end

function forge.target(m)
    local placing = forge.in_hand() ~= nil
    local object, entry, why = forge.sighted(m, placing)
    if object ~= nil and entry ~= nil and not entry.foreign and placing then
        return nil, nil, nil
    end
    return object, entry, why
end

local function borrow(object)

    if #borrowed() >= MAX_MOVED then
        return nil, "That is all the lobby can be told about - put one back first"
    end

    local entry = {
        object = object, key = nil, size = NORMAL_SIZE, foreign = true,
        batch = next_batch(), origin = origin_of(object),
    }
    table.insert(forge.placed, entry)

    forge.publish_moved()
    return entry
end

function forge.grab(want)
    local m = gMarioStates[0]
    if m == nil then return false end

    local entry = want ~= nil and entry_for(want) or nil
    if entry == nil and want ~= nil then

        local ok, why = forge.editable(want)
        if not ok then
            OF.notify.show(why or "Nothing within reach", "warn", 4)
            return false
        end
        local borrowedEntry, refused = borrow(want)
        if borrowedEntry == nil then
            OF.notify.show(refused, "warn", 5)
            return false
        end
        entry = borrowedEntry
    end

    if entry == nil then
        entry = forge.nearest(m)
    end

    if entry ~= nil and not is_mine(entry.object) then
        OF.notify.show("That one belongs to whoever placed it", "warn", 4)
        return false
    end

    if entry == nil then

        local object, why = forge.nearest_level(m)
        if object == nil then
            OF.notify.show(why or "Nothing of yours within reach", "warn", 4)
            return false
        end
        local borrowedEntry, refused = borrow(object)
        if borrowedEntry == nil then
            OF.notify.show(refused, "warn", 5)
            return false
        end
        entry = borrowedEntry
    end

    local dx = entry.object.oPosX - m.pos.x
    local dz = entry.object.oPosZ - m.pos.z
    forge.distance = math.max(MIN_DISTANCE,
        math.min(MAX_DISTANCE, math.sqrt(dx * dx + dz * dz)))
    forge.height = entry.object.oPosY - m.pos.y

    forge.size = entry.size or NORMAL_SIZE

    forge.hold(entry.object, entry.key)
    OF.sounds.play(OF.sounds.OPEN)
    return true
end

local function nearest_anything(at, range)
    local players = {}
    for i = 0, MAX_PLAYERS - 1 do
        local other = gMarioStates[i]
        if other ~= nil and other.marioObj ~= nil then
            players[other.marioObj] = true
        end
    end
    local mine = {}
    for _, placed in ipairs(forge.placed) do
        if placed.object ~= nil then mine[placed.object] = true end
    end

    local best, bestSquare = nil, range * range
    for _, list in ipairs(EDIT_LISTS) do
        local object = obj_get_first(list)
        local guard = 0
        while object ~= nil and guard < 512 do
            if not mine[object] and not players[object]
                and object.activeFlags ~= 0 then
                local dx = (object.oPosX or 0) - at.x
                local dy = (object.oPosY or 0) - at.y
                local dz = (object.oPosZ or 0) - at.z
                local square = dx * dx + dy * dy + dz * dz
                if square < bestSquare then best, bestSquare = object, square end
            end
            object = obj_get_next(object)
            guard = guard + 1
        end
    end
    return best
end

local function sighted_kind(m)
    if m == nil then return nil end
    if OF.util.binding("obj_get_first") == nil then return nil end

    local at = forge.aim_spot(m)

    local entry = forge.nearest(m, at, AIM_RANGE)
    if entry ~= nil then return entry.object, entry end
    local object = nearest_anything(at, AIM_RANGE)
    if object ~= nil then return object, nil end

    entry = forge.nearest(m)
    if entry ~= nil then return entry.object, entry end
    object = nearest_anything(m.pos, GRAB_RANGE)
    if object ~= nil then return object, nil end
    return nil, nil, nil
end

forge.sighted_kind = sighted_kind

function forge.eyedrop()
    local m = gMarioStates[0]
    if m == nil then return false end

    local object, entry = sighted_kind(m)
    if object == nil then

        return false, "Nothing in your sights."
    end

    local key = entry ~= nil and entry.key or nil
    local name = nil
    if key == nil then key, name = kind_of(object) end
    if key == nil then
        return false, "The forge has nothing like that to place."
    end
    if name == nil and OF.util.asks(OF.spawner, "find") then
        local item = OF.spawner.find(key)
        name = item ~= nil and item.name or nil
    end

    local variant = nil
    if OF.util.asks(OF.spawner, "pick_variant") then
        variant = OF.spawner.pick_variant(key, object.oBehParams2ndByte)
    end

    forge.set_slot(key)
    OF.sounds.play(OF.sounds.MOVE)
    if variant ~= nil then
        return true, (name or key) .. " (" .. variant .. ")"
    end
    return true, name or key
end

local NO_FLOOR_BELOW = -10000

function forge.ground()
    if forge.held == nil then return false, "Nothing in hand to put down." end
    local m = gMarioStates[0]
    if m == nil then return false end
    if OF.util.binding("find_floor_height") == nil then return false end

    local floor = find_floor_height(forge.held.oPosX, forge.held.oPosY + 80,
        forge.held.oPosZ)
    if type(floor) ~= "number" or floor <= NO_FLOOR_BELOW then
        return false, "There is no floor under that."
    end

    forge.height = floor - m.pos.y
    forge.held.oPosY = floor
    OF.sounds.play(OF.sounds.PICK)
    return true
end

function forge.undo()
    local batch, key, found = nil, nil, false
    for index = #forge.placed, 1, -1 do
        local entry = forge.placed[index]
        if entry.object ~= nil and entry.object.activeFlags ~= 0 then
            batch, key, found = entry.batch, entry.key, true
            break
        end
        table.remove(forge.placed, index)
    end
    if not found then return false, "Nothing of yours left to take back." end

    key = key or "piece of the level"
    local taken = 0

    local recipe = {}
    for index = #forge.placed, 1, -1 do
        local entry = forge.placed[index]
        local same = (batch ~= nil and entry.batch == batch)
            or (batch == nil and entry.batch == nil and taken == 0)
        if same then
            if entry.object ~= nil then
                if forge.held == entry.object then
                    forge.held = nil
                    forge.heldKey = nil
                end

                if entry.foreign then
                    forge.restore(entry)
                    table.remove(forge.placed, index)
                    taken = taken + 1
                    goto continue
                end

                if entry.object.activeFlags ~= 0 then
                    table.insert(recipe, 1, {
                        key = entry.key,
                        x = entry.object.oPosX,
                        y = entry.object.oPosY,
                        z = entry.object.oPosZ,
                        yaw = entry.object.oFaceAngleYaw or 0,
                        pitch = entry.object.oFaceAnglePitch or 0,
                        size = entry.size or NORMAL_SIZE,
                    })
                end

                OF.spawner.take_down(entry.object, entry.key)
            end
            table.remove(forge.placed, index)
            taken = taken + 1
        end
        ::continue::
    end

    if #recipe > 0 then
        table.insert(undone, recipe)

        while #undone > UNDONE_MAX do table.remove(undone, 1) end
    end

    forge.publish_sizes()
    forge.publish_reach()
    forge.publish_moved()
    OF.sounds.play(OF.sounds.BACK)
    return true, key, taken
end

function forge.redo()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local recipe = undone[#undone]
    if recipe == nil then return false, "Nothing has been taken back to put again." end

    local placed, wanted = 0, #recipe
    local batch = begin_batch()
    for _, row in ipairs(recipe) do
        local object = OF.spawner.spawn_at(row.key, row.x, row.y, row.z)
        if object ~= nil then

            OF.spawner.face(object, row.yaw)
            object.oFaceAnglePitch = row.pitch

            local size = row.size
            if size ~= NORMAL_SIZE and #resized() >= MAX_RESIZED then
                size = NORMAL_SIZE
            end
            table.insert(forge.placed,
                { object = object, key = row.key, size = size, batch = batch })
            apply_size(object, size)
            placed = placed + 1
        end
    end
    end_batch()
    forge.publish_sizes()
    forge.publish_reach()

    if placed == 0 then return false, "None of that could go back here." end

    table.remove(undone)
    OF.sounds.play(OF.sounds.PICK)

    if placed < wanted then
        return true, placed, wanted,
            "Put back " .. placed .. " of " .. wanted
                .. " - the rest could not go here."
    end
    return true, placed, wanted
end

local MAX_STAMP = 12

local STAMP_GAP = 260

function forge.stamp_line(count)
    local key = forge.in_hand()
    if key == nil then return false, "Pick something to place first." end
    local m = gMarioStates[0]
    if m == nil then return false end

    count = OF.util.clamp(math.floor(tonumber(count) or 5), 2, MAX_STAMP)
    local angle = angle_of(m)
    local placed = 0
    local was = forge.distance

    begin_batch()
    for step = count, 1, -1 do
        forge.distance = OF.util.clamp(was + (step - 1) * STAMP_GAP,
            MIN_DISTANCE, MAX_DISTANCE)
        if forge.place(key) then placed = placed + 1 end
    end
    end_batch()
    forge.distance = was
    if placed == 0 then return false, "Nothing was placed." end

    if placed < count then
        return true, placed, count,
            "Placed " .. placed .. " of " .. count .. " - the rest could not go here."
    end
    return true, placed, count
end

function forge.stamp_ring(count)
    local key = forge.in_hand()
    if key == nil then return false, "Pick something to place first." end
    local m = gMarioStates[0]
    if m == nil then return false end

    count = OF.util.clamp(math.floor(tonumber(count) or 6), 2, MAX_STAMP)
    local radius = forge.distance
    local placed = 0
    local wasAngle = m.faceAngle.y
    begin_batch()
    for step = 0, count - 1 do

        m.faceAngle.y = math.floor(wasAngle + step * (0x10000 / count)) & 0xFFFF
        forge.distance = radius
        if forge.place(key) then placed = placed + 1 end
    end
    end_batch()
    m.faceAngle.y = wasAngle
    forge.distance = radius

    forge.drop()
    if placed == 0 then return false, "Nothing was placed." end
    if placed < count then
        return true, placed, count,
            "Placed " .. placed .. " of " .. count .. " - the rest could not go here."
    end
    return true, placed, count
end

local STAMP_RISE = 120

function forge.stamp_stairs(count)
    local key = forge.in_hand()
    if key == nil then return false, "Pick something to place first." end
    local m = gMarioStates[0]
    if m == nil then return false end

    count = OF.util.clamp(math.floor(tonumber(count) or 5), 2, MAX_STAMP)
    local placed = 0
    local wasDistance = forge.distance
    local wasHeight = forge.height
    begin_batch()
    for step = count, 1, -1 do
        forge.distance = OF.util.clamp(wasDistance + (step - 1) * STAMP_GAP,
            MIN_DISTANCE, MAX_DISTANCE)
        forge.height = wasHeight + (step - 1) * STAMP_RISE
        if forge.place(key) then placed = placed + 1 end
    end
    end_batch()
    forge.distance = wasDistance
    forge.height = wasHeight
    if placed == 0 then return false, "Nothing was placed." end
    if placed < count then
        return true, placed, count,
            "Placed " .. placed .. " of " .. count .. " - the rest could not go here."
    end
    return true, placed, count
end

function forge.stamp_column(count)
    local key = forge.in_hand()
    if key == nil then return false, "Pick something to place first." end
    local m = gMarioStates[0]
    if m == nil then return false end

    count = OF.util.clamp(math.floor(tonumber(count) or 4), 2, MAX_STAMP)
    local placed = 0
    local wasHeight = forge.height
    begin_batch()

    for step = count, 1, -1 do
        forge.height = wasHeight + (step - 1) * STAMP_RISE
        if forge.place(key) then placed = placed + 1 end
    end
    end_batch()
    forge.height = wasHeight
    if placed == 0 then return false, "Nothing was placed." end
    if placed < count then
        return true, placed, count,
            "Placed " .. placed .. " of " .. count .. " - the rest could not go here."
    end
    return true, placed, count
end

local MAX_SIDE = 3

local function stamp_plane(side, upward)
    local key = forge.in_hand()
    if key == nil then return false, "Pick something to place first." end
    local m = gMarioStates[0]
    if m == nil then return false end

    side = OF.util.clamp(math.floor(tonumber(side) or MAX_SIDE), 2, MAX_SIDE)
    local wanted = side * side
    local placed = 0
    local wasDistance = forge.distance
    local wasHeight = forge.height

    local middle = (side + 1) / 2

    begin_batch()

    for row = side, 1, -1 do
        if upward then
            forge.height = wasHeight + (row - 1) * STAMP_RISE
        else
            forge.distance = OF.util.clamp(
                wasDistance + (row - 1) * STAMP_GAP,
                MIN_DISTANCE, MAX_DISTANCE)
        end
        for col = 1, side do
            if forge.place(key, (col - middle) * STAMP_GAP) then
                placed = placed + 1
            end
        end
    end
    end_batch()
    forge.distance = wasDistance
    forge.height = wasHeight

    forge.drop()

    if placed == 0 then return false, "Nothing was placed." end
    if placed < wanted then
        return true, placed, wanted,
            "Placed " .. placed .. " of " .. wanted .. " - the rest could not go here."
    end
    return true, placed, wanted
end

function forge.stamp_floor(side)
    return stamp_plane(side, false)
end

function forge.stamp_wall(side)
    return stamp_plane(side, true)
end

local MIN_ARCH = 3

function forge.stamp_arch(count)
    local key = forge.in_hand()
    if key == nil then return false, "Pick something to place first." end
    local m = gMarioStates[0]
    if m == nil then return false end

    count = OF.util.clamp(math.floor(tonumber(count) or 5), MIN_ARCH, MAX_STAMP)

    local radius = STAMP_GAP * (count - 1) / math.pi
    local wasDistance = forge.distance
    local wasHeight = forge.height
    local placed = 0

    begin_batch()

    for step = count, 1, -1 do

        local turn = math.floor((step - 1) * (0x8000 / (count - 1)))
        forge.distance = OF.util.clamp(wasDistance + radius * (1 - coss(turn)),
            MIN_DISTANCE, MAX_DISTANCE)
        forge.height = wasHeight + radius * sins(turn)
        if forge.place(key) then
            placed = placed + 1
            if forge.held ~= nil then
                forge.held.oFaceAnglePitch = 0x4000 - turn
            end
        end
    end
    end_batch()
    forge.distance = wasDistance
    forge.height = wasHeight

    forge.drop()

    if placed == 0 then return false, "Nothing was placed." end
    if placed < count then
        return true, placed, count,
            "Placed " .. placed .. " of " .. count .. " - the rest could not go here."
    end
    return true, placed, count
end

local TRAILS = { 0, 200, 400, 800 }
local TRAIL_NAMES = { "Off", "Every 200", "Every 400", "Every 800" }
forge.trail = 1

local trailFrom = nil

local trailBatch = nil

function forge.trail_count()
    return #TRAILS
end

function forge.trail_name(step)
    return TRAIL_NAMES[step or forge.trail] or TRAIL_NAMES[1]
end

function forge.trail_step(step)
    return TRAILS[step or forge.trail] or 0
end

local function stop_trail()
    forge.trail = 1
    trailFrom = nil
    trailBatch = nil
end

function forge.set_trail(step)
    step = OF.util.clamp(math.floor(tonumber(step) or 1), 1, #TRAILS)

    if TRAILS[step] == 0 then
        stop_trail()
        return true
    end
    if not OF.perms.can("spawn_object") then
        return false, "Your rank cannot do that."
    end
    forge.trail = step
    trailFrom = nil

    trailBatch = begin_batch()
    end_batch()
    return true
end

local function trail_update()
    if forge.trail_step() <= 0 then return end

    if not forge.open then return end
    local key = forge.in_hand()
    if key == nil then return end

    if not OF.perms.can("spawn_object") then return end
    local m = gMarioStates[0]
    if m == nil then return end

    if trailFrom == nil then
        trailFrom = { x = m.pos.x, y = m.pos.y, z = m.pos.z, yaw = angle_of(m) }
        return
    end

    local step = forge.trail_step()
    local dx = m.pos.x - trailFrom.x
    local dy = m.pos.y - trailFrom.y
    local dz = m.pos.z - trailFrom.z

    if dx * dx + dy * dy + dz * dz < step * step then return end

    local at = trailFrom
    trailFrom = { x = m.pos.x, y = m.pos.y, z = m.pos.z, yaw = angle_of(m) }

    local object = OF.spawner.spawn_at(key, at.x, at.y, at.z)
    if object == nil then

        stop_trail()
        OF.notify.show("The trail stopped - nothing more would go down", "warn", 5)
        return
    end

    OF.spawner.face(object, at.yaw)

    local size = forge.size
    if size ~= NORMAL_SIZE and #resized() >= MAX_RESIZED then
        size = NORMAL_SIZE
    end
    forget_redo()
    table.insert(forge.placed,
        { object = object, key = key, size = size, batch = trailBatch })
    apply_size(object, size)
    forge.publish_sizes()
    forge.publish_reach()
end

hook_event(HOOK_UPDATE, trail_update)

function forge.copy()

    if forge.foreign_held() then
        return false, "That one is the level's - there is no copy of it to make."
    end
    if forge.held == nil or forge.heldKey == nil then return false end
    local yaw = forge.held.oFaceAngleYaw or 0
    local pitch = forge.held.oFaceAnglePitch or 0
    local ok, why = forge.place(forge.heldKey)
    if ok and forge.held ~= nil then
        OF.spawner.face(forge.held, yaw)
        forge.held.oFaceAnglePitch = pitch
    end
    return ok, why
end

function forge.delete_held()
    if forge.held == nil then return false end

    if forge.foreign_held() then
        local entry = held_entry()
        local back = forge.restore(entry)
        for index, row in ipairs(forge.placed) do
            if row == entry then table.remove(forge.placed, index) break end
        end
        forge.held = nil
        forge.heldKey = nil
        forge.publish_moved()

        if back then
            OF.notify.show("That one is the level's - put back where it stood",
                "warn", 4)
        else
            OF.notify.show("That one is gone - there was nothing left to put back",
                "warn", 4)
        end
        OF.sounds.play(OF.sounds.BACK)
        return true
    end
    local held = forge.held
    for index, entry in ipairs(forge.placed) do
        if entry.object == held then
            table.remove(forge.placed, index)
            break
        end
    end
    OF.spawner.take_down(held, forge.heldKey)
    forge.held = nil
    forge.heldKey = nil

    forge.publish_sizes()
    forge.publish_reach()
    OF.sounds.play(OF.sounds.BACK)
    return true
end

function forge.clear()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local count, restored = 0, 0
    for _, entry in ipairs(forge.placed) do
        if entry.object ~= nil then

            if entry.foreign then
                if forge.restore(entry) then restored = restored + 1 end
            else
                OF.spawner.take_down(entry.object, entry.key)
                count = count + 1
            end
        end
    end
    forge.placed = {}
    forge.held = nil
    forge.heldKey = nil
    forge.publish_moved()
    if restored > 0 then
        OF.notify.show("Put @ of the level's own back where they stood",
            "info", 4, restored)
    end

    forget_redo()
    forge.publish_sizes()
    forge.publish_reach()
    return true, count
end

local MEASURE_SURFACES = 64

function forge.bounds(object)
    if object == nil then return nil end

    local minX, minY, minZ, maxX, maxY, maxZ

    local count = object.numSurfaces
    if type(count) == "number" and count > 0
        and OF.util.binding("obj_get_surface_from_index") ~= nil then
        if count > MEASURE_SURFACES then count = MEASURE_SURFACES end
        for index = 0, count - 1 do
            local surface = obj_get_surface_from_index(object, index)
            if surface ~= nil then
                for _, vertex in ipairs({ surface.vertex1, surface.vertex2,
                                          surface.vertex3 }) do
                    if vertex ~= nil then
                        local vx, vy, vz = vertex.x, vertex.y, vertex.z
                        if type(vx) == "number" and type(vy) == "number"
                            and type(vz) == "number" then
                            if minX == nil then
                                minX, maxX = vx, vx
                                minY, maxY = vy, vy
                                minZ, maxZ = vz, vz
                            else
                                if vx < minX then minX = vx end
                                if vx > maxX then maxX = vx end
                                if vy < minY then minY = vy end
                                if vy > maxY then maxY = vy end
                                if vz < minZ then minZ = vz end
                                if vz > maxZ then maxZ = vz end
                            end
                        end
                    end
                end
            end
        end
    end

    if minX ~= nil then

        local ox = object.oPosX or 0
        local oy = object.oPosY or 0
        local oz = object.oPosZ or 0
        return {
            halfX = (maxX - minX) * 0.5, halfY = (maxY - minY) * 0.5,
            halfZ = (maxZ - minZ) * 0.5,
            offX = (maxX + minX) * 0.5 - ox,
            offY = (maxY + minY) * 0.5 - oy,
            offZ = (maxZ + minZ) * 0.5 - oz,
            solid = true,
        }
    end

    local radius = object.hitboxRadius
    local height = object.hitboxHeight
    if type(radius) ~= "number" or type(height) ~= "number" then return nil end
    if radius <= 0 or height <= 0 then return nil end
    local down = object.hitboxDownOffset
    if type(down) ~= "number" then down = 0 end
    return {
        halfX = radius, halfY = height * 0.5, halfZ = radius,
        offX = 0, offY = height * 0.5 - down, offZ = 0,
        solid = false,
    }
end

local function carry_update()
    if forge.held == nil then return end
    local m = gMarioStates[0]
    if m == nil then return end

    if forge.held.activeFlags == 0 then
        forge.held = nil
        forge.heldKey = nil
        return
    end

    local x, y, z = carry_spot(m, forge.sideways)
    forge.held.oPosX = x
    forge.held.oPosY = y
    forge.held.oPosZ = z

    forge.held.oHomeX = x
    forge.held.oHomeY = y
    forge.held.oHomeZ = z

    if not forge.foreign_held() then apply_size(forge.held, forge.size) end

    obj_update_gfx_pos_and_angle(forge.held)
end

hook_event(HOOK_UPDATE, carry_update)

local sizeTicks = 0
hook_event(HOOK_UPDATE, function()
    sizeTicks = sizeTicks + 1
    if sizeTicks < 15 then return end
    sizeTicks = 0
    forge.apply_published()

    forge.apply_reach()

    forge.apply_moved()
end)

local EMPTY_CHORDS = {
    { mod = L_TRIG, mod2 = R_TRIG, button = B_BUTTON, legend = "L+R+B: put it back",
      run = function()

          local ok, placed, wanted, short = forge.redo()
          if not ok then
              OF.util.report(false, placed)
          elseif short ~= nil then
              OF.notify.show(short, "warn", 5)
          else
              OF.notify.show("Put back @ object(s)", "good", 3, placed)
          end
      end },
    { mod = L_TRIG, button = Z_TRIG, legend = "L+Z: one to the left",
      run = function() forge.step_inventory(-1) end },
    { mod = L_TRIG, button = B_BUTTON, legend = "L+B: take back the last",
      run = function()

          local ok, what, taken = forge.undo()
          if not ok then
              OF.util.report(false, what)
          elseif (taken or 1) > 1 then
              OF.notify.show("Took back @ of the last stamp", "good", 3, taken)
          end
      end },

    { mod = R_TRIG, button = B_BUTTON, legend = "R+B: take the kind",
      run = function()
          local ok, what = forge.eyedrop()
          if not ok then
              OF.util.report(false, what)
          else
              OF.notify.show("@ is in slot @", "good", 3, what, forge.slot)
          end
      end },
    { mod = R_TRIG, button = Z_TRIG, legend = "R+Z: one to the right",
      run = function() forge.step_inventory(1) end },
}

local function chord_rank(chord)
    local hand = 1
    if chord.mod2 ~= nil then
        hand = 2
    elseif chord.mod == R_TRIG then
        hand = 3
    end
    local button = chord.button == B_BUTTON and 1 or 2
    return button * 10 + hand
end

local function empty_legend()
    local sorted = {}
    for _, chord in ipairs(EMPTY_CHORDS) do table.insert(sorted, chord) end

    table.sort(sorted, function(a, b) return chord_rank(a) < chord_rank(b) end)

    local parts = {}
    for _, chord in ipairs(sorted) do
        table.insert(parts, OF.lang.t(chord.legend))
    end
    return table.concat(parts, "   ")
end

function forge.legend_order()
    local names = {}
    for _, chord in ipairs(EMPTY_CHORDS) do
        table.insert(names, { legend = chord.legend, rank = chord_rank(chord) })
    end
    table.sort(names, function(a, b) return a.rank < b.rank end)
    return names
end

local STICK_DEAD = 30

local function cursor_chords(m, input)
    local rHeld = OF.util.has_flag(input.down, R_TRIG)
    local lHeld = OF.util.has_flag(input.down, L_TRIG)
    local stickX = m.controller.stickX or 0
    local stickY = m.controller.stickY or 0

    local rx = m.controller.extStickX or 0
    local ry = m.controller.extStickY or 0

    if rHeld or lHeld then

        OF.input.lock_movement(m)
    end

    if lHeld then

        local by = STEP
        if stickY > STICK_DEAD then
            forge.height = forge.height + by
        elseif stickY < -STICK_DEAD then
            forge.height = forge.height - by
        end
    end

    if rHeld and math.abs(stickY) > STICK_DEAD then
        local by = STEP * (stickY > 0 and 1 or -1)
        forge.distance = OF.util.clamp(forge.distance + by,
            MIN_DISTANCE, MAX_DISTANCE)
    end
    if rHeld and math.abs(stickX) > STICK_DEAD then
        local by = STEP * (stickX > 0 and 1 or -1)
        forge.sideways = OF.util.clamp(forge.sideways + by,
            -MAX_DISTANCE, MAX_DISTANCE)
    end

    return lHeld, rHeld, rx, ry
end

local function hold_camera(m, lHeld, rHeld, holding)
    local lock = OF.input.forge_camera()
    local wanted = (holding and lock == "holding")
        or (lock == "chord" and (rHeld or lHeld))
    if wanted then
        OF.input.claim_camera(m)
    end

    OF.input.hold_mouse("forge", wanted)
    return wanted
end

local function release_controls()
    if not OF.util.asks(OF.input, "holds_mouse") then return false end
    if not OF.input.holds_mouse("forge") then return false end
    return OF.input.hold_mouse("forge", false)
end

local function on_before_mario_update(m)
    if m.playerIndex ~= 0 then return end
    if not forge.open or OF.panel.open then
        release_controls()
        return
    end

    OF.input.poll(m)
    local input = OF.input

    local lHeld, rHeld, rx, ry = cursor_chords(m, input)

    if forge.held == nil then

        hold_camera(m, lHeld, rHeld, false)

        for _, chord in ipairs(EMPTY_CHORDS) do
            if input.pressed(chord.button)
                and OF.util.has_flag(input.down, chord.mod)

                and (chord.mod2 == nil
                    or OF.util.has_flag(input.down, chord.mod2)) then
                chord.run()

                OF.input.take(m, chord.button)
                return
            end
        end

        if input.pressed(B_BUTTON) then
            local aimed = forge.target(m)
            local key = forge.in_hand()
            if aimed ~= nil then
                forge.grab(aimed)
            elseif key ~= nil then
                OF.util.report(forge.place(key))
            else
                forge.grab()
            end
            OF.input.take(m, B_BUTTON)
        end

        return
    end

    if input.pressed(B_BUTTON) then
        if OF.util.has_flag(input.down, L_TRIG) then

            OF.util.report(forge.copy())
        else
            forge.drop()
        end
    elseif input.pressed(Z_TRIG) then
        forge.delete_held()
    end

    if lHeld then

        if math.abs(ry) > STICK_DEAD then
            sizeHold = sizeHold + 1
            if sizeHold >= SIZE_HOLD_FRAMES then
                sizeHold = 0
                local wanted = forge.size + (ry > 0 and 1 or -1)
                if wanted >= 1 and wanted <= forge.size_count() then
                    OF.util.report(forge.set_size(wanted))
                end
            end
        else
            sizeHold = 0
        end
    else
        sizeHold = 0
    end

    if rHeld and forge.held ~= nil then

        local sense = OF.input.forge_scale()
        if math.abs(rx) > STICK_DEAD then

            OF.spawner.face(forge.held, forge.turned_yaw(
                forge.held.oFaceAngleYaw or 0,
                (rx > 0 and 1 or -1), 0.5 * sense))
        end

        local pitch = OF.input.forge_pitch(ry)
        if math.abs(pitch) > STICK_DEAD then
            forge.held.oFaceAnglePitch = (forge.held.oFaceAnglePitch or 0)
                + ROTATE_STEP * (pitch > 0 and 1 or -1) * 0.5 * sense
        end
    end

    if input.pressed(L_JPAD) then
        OF.input.take(m, L_JPAD)
        OF.util.report(forge.toggle())
        return
    end

    local reach, turn = 0, 0
    if input.pressed(U_CBUTTONS) then reach = 1 end
    if input.pressed(D_CBUTTONS) then reach = -1 end
    if input.pressed(L_CBUTTONS) then turn = -1 end
    if input.pressed(R_CBUTTONS) then turn = 1 end

    local senseCB = OF.input.forge_scale()

    local reachBy = STEP * senseCB
    if reach > 0 then
        forge.distance = math.min(MAX_DISTANCE, forge.distance + reachBy)
    elseif reach < 0 then
        forge.distance = math.max(MIN_DISTANCE, forge.distance - reachBy)
    end
    if turn ~= 0 then
        OF.spawner.face(forge.held,
            forge.turned_yaw(forge.held.oFaceAngleYaw or 0, turn, senseCB))
    end

    OF.input.take(m, B_BUTTON)
    OF.input.take(m, Z_TRIG)

    hold_camera(m, lHeld, rHeld, true)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update)

hook_event(HOOK_ON_LEVEL_INIT, function()

    release_controls()
    forge.placed = {}
    forge.held = nil
    forge.heldKey = nil

    forge.forget_moved()

    forget_redo()

    stop_trail()

    forge.publish_sizes()
    forge.publish_reach()

    forge.publish_moved()
end)

local PREVIEW_SEGMENTS = 20
local PREVIEW_RADIUS = 55

local PREVIEW_DROP = 40

local function ground_under(x, y, z)
    if OF.util.binding("find_floor_height") == nil then return nil end
    local floor = find_floor_height(x, y + 80, z)
    if type(floor) ~= "number" or floor <= NO_FLOOR_BELOW then return nil end
    return floor + 2
end

local aimTicks = 0
local aimedAt = nil

hook_event(HOOK_UPDATE, function()
    if not forge.open or forge.held ~= nil then
        aimedAt = nil
        return
    end
    aimTicks = aimTicks + 1
    if aimTicks < 3 then return end
    aimTicks = 0
    aimedAt = forge.target(gMarioStates[0])
end)

function forge.aimed_at()
    if not forge.open or forge.held ~= nil then return nil end
    if aimedAt ~= nil and aimedAt.activeFlags == 0 then aimedAt = nil end
    return aimedAt
end

local function draw_landing_spot()
    local m = gMarioStates[0]
    if m == nil then return end

    local x, y, z = carry_spot(m)
    local gold = OF.util.gold()
    local radius = PREVIEW_RADIUS * (SIZES[forge.size] or 1.0)
    local ground = ground_under(x, y, z)

    local target = forge.aimed_at()
    if target ~= nil then
        local tx, ty, tz = target.oPosX or 0, target.oPosY or 0, target.oPosZ or 0
        OF.util.world_ring({ x = tx, y = ty, z = tz },
            PREVIEW_RADIUS, PREVIEW_SEGMENTS, 4, gold.r, gold.g, gold.b, 235)
        local under = ground_under(tx, ty, tz)
        if under ~= nil and ty - under >= PREVIEW_DROP then
            OF.util.world_arrow({ x = tx, y = under, z = tz }, ty - under, 3,
                gold.r, gold.g, gold.b, 130)
        end

        OF.util.world_ring({ x = x, y = ground or y, z = z }, radius,
            PREVIEW_SEGMENTS, 2, gold.r, gold.g, gold.b, 90)
        return
    end

    if ground == nil then

        OF.util.world_ring({ x = x, y = y, z = z }, radius, PREVIEW_SEGMENTS, 3,
            gold.r, gold.g, gold.b, 210)
        return
    end

    OF.util.world_ring({ x = x, y = ground, z = z }, radius, PREVIEW_SEGMENTS, 3,
        gold.r, gold.g, gold.b, 210)

    if y - ground < PREVIEW_DROP then return end

    OF.util.world_ring({ x = x, y = y, z = z }, radius, PREVIEW_SEGMENTS, 2,
        gold.r, gold.g, gold.b, 110)
    OF.util.world_arrow({ x = x, y = ground, z = z }, y - ground, 3,
        gold.r, gold.g, gold.b, 150)
end

local SPARKLE_SEGMENTS = 10
local SPARKLE_RADIUS = 34
local SPARKLE_SWELL = 16
local MAX_SPARKLES = 12
local SPARKLE_REFRESH = 15

local SPARKLE_LIFT = 30
local SPARKLE_BEACON = 260

local sparkleTicks = SPARKLE_REFRESH
local sparklePulse = 0
local warpSpots = {}

local function refresh_warps()
    warpSpots = {}
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return end
    if OF.util.binding("obj_get_next_with_same_behavior_id") == nil then return end

    for index, id in ipairs(LEVEL_SPINE) do
        if id ~= nil then
            local object = obj_get_first_with_behavior_id(id)
            local guard = 0
            while object ~= nil and guard < 64 do
                if object.activeFlags ~= 0 then
                    table.insert(warpSpots, {
                        x = object.oPosX or 0,
                        y = object.oPosY or 0,
                        z = object.oPosZ or 0,

                        name = SPINE_NAMES[index],
                    })
                end
                object = obj_get_next_with_same_behavior_id(object)
                guard = guard + 1
            end
        end
    end
end

hook_event(HOOK_UPDATE, function()
    if not forge.open then

        if #warpSpots > 0 then warpSpots = {} end
        sparkleTicks = SPARKLE_REFRESH
        return
    end
    sparklePulse = sparklePulse + 1
    sparkleTicks = sparkleTicks + 1
    if sparkleTicks < SPARKLE_REFRESH then return end
    sparkleTicks = 0
    refresh_warps()
end)

function forge.warp_spots()
    return warpSpots
end

local function draw_warp_sparkles()
    if #warpSpots == 0 then return end
    local m = gMarioStates[0]
    if m == nil then return end

    local near = {}
    for _, spot in ipairs(warpSpots) do
        local dx, dy, dz = spot.x - m.pos.x, spot.y - m.pos.y, spot.z - m.pos.z
        table.insert(near,
            { spot = spot, away = dx * dx + dy * dy + dz * dz })
    end
    table.sort(near, function(a, b) return a.away < b.away end)

    local gold = OF.util.gold()

    local swell = SPARKLE_RADIUS
        + SPARKLE_SWELL * math.sin(sparklePulse * 0.13)
    for index, entry in ipairs(near) do
        if index > MAX_SPARKLES then break end
        local spot = entry.spot
        OF.util.world_ring(spot, swell, SPARKLE_SEGMENTS, 2,
            gold.r, gold.g, gold.b, 200)

        local tip = { x = spot.x, y = spot.y + SPARKLE_LIFT, z = spot.z }
        OF.util.world_arrow(tip, SPARKLE_BEACON, 3,
            gold.r, gold.g, gold.b, 225)

        if spot.name ~= nil then
            local out = { x = 0, y = 0, z = 0 }
            local above = { x = spot.x,
                y = spot.y + SPARKLE_LIFT + SPARKLE_BEACON + 40,
                z = spot.z }
            if OF.util.world_screen(above, out) then
                local shown = OF.lang.t(spot.name)
                OF.util.text(shown, out.x - OF.util.width(shown, 0.4) * 0.5,
                    out.y, 0.4, 255, 255, 255, 225)
            end
        end
    end
end

local function render()
    if not forge.open then return end
    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    draw_warp_sparkles()

    local text
    local under = nil
    if forge.held == nil and forge.in_hand() ~= nil
        and forge.aimed_at() ~= nil then

        text = OF.lang.t("Forge  -  B: pick up what the ring is round")
        under = { text = empty_legend() }
    elseif forge.held == nil and forge.in_hand() ~= nil then

        text = OF.lang.fill("Forge  -  B: another @",
            OF.lang.t(forge.kind_name() or ""))

        under = { text = empty_legend() }
    elseif forge.held == nil then

        local waiting = forge.undone_count()
        local moved = forge.borrowed_count()
        if moved > 0 then
            text = OF.lang.fill("Forge  -  B: pick up   (@ placed, @ of the level's moved)",
                forge.count(), moved)
        elseif waiting > 0 then
            text = OF.lang.fill("Forge  -  B: pick up   (@ placed, @ to put back)",
                forge.count(), waiting)
        else
            text = OF.lang.fill("Forge  -  B: pick up   (@ placed)",
                forge.count())
        end
        under = { text = empty_legend() }
    else

        if forge.foreign_held() then
            text = OF.lang.t(
                "Holding the level's own  -  B: place   Z: put it back")
        else
            text = OF.lang.fill("Holding, @  -  B: place   L+B: copy   Z: delete",
                OF.lang.t(forge.size_name()))
        end

        under = { text = OF.lang.t(
            "L+stick: height   L+right stick: size   "
                .. "R+stick: nearer/further/sideways   R+right stick: turn") }
    end

    local gold = OF.util.gold()
    OF.util.banner(text, 0.7, gold.r, gold.g, gold.b, 255, { under = under })

    if forge.held ~= nil then return end

    draw_landing_spot()

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local cell, gap = 46, 6
    local total = BAR_SLOTS * cell + (BAR_SLOTS - 1) * gap
    local left = (screenWidth - total) * 0.5
    local top = screenHeight - cell - 26

    for i = 1, BAR_SLOTS do
        local x = left + (i - 1) * (cell + gap)
        local mine = (i == forge.slot)
        local filled = forge.bar[i] ~= nil

        OF.util.plate(x, top, cell, cell, {
            alpha = mine and 255 or 165,
            accent = mine and OF.util.gold() or nil,
        })

        local label = tostring(i)
        local width = OF.util.width(label, 0.5)
        OF.util.text(label, x + cell - width - 5, top + cell - 16, 0.5,
            filled and 255 or 140, filled and 255 or 140,
            filled and 255 or 140, 220)
    end

    local page = tostring(forge.inventory) .. "/" .. tostring(BAR_PAGES)
    OF.util.text(page, left - OF.util.width(page, 0.5) - 10,
        top + cell - 16, 0.5, 255, 255, 255, 200)

    local name = forge.slot_name(forge.slot)
    if name ~= nil then
        local shown = OF.lang.t(name)
        local width = OF.util.width(shown, 0.6)
        OF.util.text(shown, (screenWidth - width) * 0.5, top - 20, 0.6,
            255, 255, 255, 235)
    end
end

hook_event(HOOK_ON_HUD_RENDER, render)

forge.CATEGORIES = {

    { name = "Enemies", keys = {

        "goomba", "bobomb", "koopa", "bully", "chillbully",
        "chuckya", "spiny", "pokey", "spindrift", "blizzard", "scuttlebug",
        "heaveho", "moneybag", "montymole", "molehole", "whomp", "thwomp",
        "chainchomp", "piranha", "firepiranha" } },

    { name = "Bosses", keys = {
        "kingbobomb", "whompking", "bigbully", "bigchill", "wiggler",
        "bowser" } },

    { name = "Fliers and ghosts", keys = {
        "amp", "homingamp", "bulletbill", "swoop", "flyguy", "lakitu",
        "snufit", "klepto", "boo", "mrI", "bookend", "piano", "chair" } },

    { name = "In the water", keys = {
        "unagi", "bubba", "skeeter", "bub", "clam" } },

    { name = "Friends and scenery", keys = {
        "mips", "yoshi", "penguin", "tree", "cannon" } },

    { name = "Coins and pickups", keys = {
        "coin", "bluecoin", "redcoin", "coins", "1up", "1upwalk", "heart",
        "wingcap" } },

    { name = "Things to carry", keys = {
        "box", "smallbox", "exclam", "metalbox", "shell", "waterbomb",
        "bowling" } },

    { name = "Fire and hazards", keys = {
        "fire", "firespitter", "flamejet", "fireball", "firebar", "firebridge",
        "lavaplat", "toxbox", "tweester", "snowvent" } },

    { name = "Crushers and traps", keys = {
        "grindel", "grindelh", "spindel", "boulder", "pillar", "trapdoor",
        "fallwall", "risewall", "squishplat", "donut" } },

    { name = "Platforms", keys = {
        "checkplat", "floatplat", "raft", "kickboard", "tumbling", "logroll",
        "logwide", "rockblock", "sinkplat", "tugplat", "tiltplat",
        "meshplat" } },

    { name = "Lifts", keys = {
        "elevator", "arrowlift", "towerlift", "rrlift", "checkers", "ferris",
        "cageplat", "ttclift" } },

    { name = "Clockwork", keys = {
        "seesaw", "turntable", "swingplat", "octaplat", "hexring", "ttccog",
        "ttcgear", "ttcsolid", "ttctread", "ttcpend", "ttcbar", "ttcpit",
        "ttcspin" } },

    { name = "Switches and posts", keys = {
        "purpleswitch", "capswitch", "blueswitch", "pole", "woodpost" } },
}

function forge.shelf_of(key)
    for _, shelf in ipairs(forge.CATEGORIES) do
        for _, on in ipairs(shelf.keys) do
            if on == key then return shelf.name end
        end
    end
    return nil
end

forge.BLURBS = {

    goomba      = "walks at whoever is nearest, and one stomp ends it",
    bobomb      = "walks up, lights its fuse and blows up",
    koopa       = "the shell-less one - he runs off, and dives for a shell",
    bully       = "charges, and tries to shove you off the edge",
    chillbully  = "the cold one, and it shoves just as hard",
    chuckya     = "grabs whoever comes close and throws them",
    spiny       = "walks about on its own, with no Lakitu to throw it",
    pokey       = "a stack of segments that comes apart one at a time",
    spindrift   = "walks at you, and stomping one twirls you off the top",
    blizzard    = "throws snowballs at anybody who comes into range",
    scuttlebug  = "sits still until somebody is close, then charges",
    heaveho     = "picks you up and throws you into the air",
    moneybag    = "poses as a coin, hops away, and turns on you",
    montymole   = "throws rocks out of a hole - place a hole for it first",
    molehole    = "the hole a mole needs; without one it never shows itself",
    whomp       = "a floor that walks, and falls flat on whoever is under it",
    thwomp      = "waits overhead and slams down on whatever is below",
    chainchomp  = "lunges the length of its chain at anybody near",
    piranha     = "sleeps until somebody comes close, then bites",
    firepiranha = "hides in the ground, then stands up and spits fire",

    kingbobomb  = "throws whoever grabs him, and has to be thrown first",
    whompking   = "slams down, and the weak spot is his back",
    bigbully    = "charges hard, and only an edge over lava finishes him",
    bigchill    = "the ice one, and cold water is what finishes him",
    wiggler     = "takes three ground pounds, and speeds up after each",
    bowser      = "the whole fight, wherever you choose to put him",

    amp         = "circles a point and shocks whoever touches it",
    homingamp   = "the Amp that comes after you instead of circling",
    bulletbill  = "flies straight ahead and bursts on whatever it hits",
    swoop       = "hangs still, then dives at whoever passes under",
    flyguy      = "hovers over you, then lunges or breathes fire",
    lakitu      = "follows on a cloud and drops Spinies behind you",
    snufit      = "floats out of reach and shoots from a distance",
    klepto      = "swoops past and takes the cap off your head",
    boo         = "hides while you face it and comes at your back",
    mrI         = "an eye that watches - run rings round it to pop it",
    bookend     = "waits until you look at it, then flies straight at you",
    piano       = "sits there doing nothing at all until you are close",
    chair       = "slides across the floor at whoever walks by",

    unagi       = "the eel, and it swims a fixed course of its own",
    bubba       = "it swallows whoever swims into it",
    skeeter     = "the water strider, and it is better on a lake than a floor",
    bub         = "it bites from the moment it exists",
    clam        = "it waits open, then shuts on whoever swims through",

    mips        = "he runs from you, and can be caught and carried",
    yoshi       = "he leaves at once unless the save has all 120 stars",
    penguin     = "you can pick her up and carry her about",
    tree        = "scenery with a hitbox, and nothing more than that",
    cannon      = "the barrel only - there is no base here to climb into",

    coin        = "worth one, and it stays exactly where you put it",
    bluecoin    = "worth five, and it hops away before it fades",
    redcoin     = "worth two, and it counts if the level has a red star",
    coins       = "eight coins in a shape, for one press",
    ["1up"]     = "an extra life for whoever touches it",
    ["1upwalk"] = "an extra life that runs away when you go for it",
    heart       = "spin through it and it gives your health back",
    wingcap     = "a cap on the ground - it puts yours back on, no flight",

    box         = "smash it, and it bursts into coins",
    smallbox    = "holdable and throwable, and it breaks into a coin",
    exclam      = "the wing cap one, hollow until that switch is pressed",
    metalbox    = "heavy - push it about, and it holds a switch down",
    shell       = "ride it, and it carries you over water and lava",
    waterbomb   = "falls, bursts, and knocks over whoever is beside it",
    bowling     = "rolls off and keeps going - six make a hillside",

    fire        = "a flame that bounces along and then burns out",
    firespitter = "stays where it is and spits flame out at you",
    flamejet    = "an invisible jet that fires at anybody who comes near",
    fireball    = "an invisible vent, and what you see is what it throws",
    snowvent    = "an invisible vent that sends snowballs rolling out",
    firebar     = "a turning block with a bar of fire out of each side",
    firebridge  = "turns on the spot, and carries fire on its ends",
    lavaplat    = "a wide slab that tilts underfoot - made to be fought on",
    toxbox      = "a stone cube that rolls along and flattens you",
    tweester    = "chases, throws whoever it catches upward, then rests",

    grindel     = "a stone slab that lifts and stamps down again",
    grindelh    = "the same slab, sliding across instead of stamping",
    spindel     = "a stone block that turns as it slides along",
    boulder     = "rolls off at a heading of its own the moment it exists",
    pillar      = "topples onto whoever comes and stands under it",
    trapdoor    = "opens under whoever stands on it, doors and all",
    fallwall    = "waits for somebody near, drops, and re-arms itself",
    risewall    = "rises and sinks on a loop of its own - a piston",
    squishplat  = "squashes flat and stretches out again",
    donut       = "shakes underfoot, falls, and is back once you leave",

    checkplat   = "a plain solid floor, and you can put it in mid-air",
    floatplat   = "rides the water, not your height - aim at water",
    raft        = "rides the water and tips under you - aim at the water",
    kickboard   = "punch it once and it falls flat into a bridge",
    tumbling    = "falls apart under you, and rebuilds once you leave",
    logroll     = "turns under your feet as you walk along it",
    logwide     = "the same roll, with more room to stand on",
    rockblock   = "sinks under you, and settles below where you aim",
    sinkplat    = "dips under your weight and comes back up after you",
    tugplat     = "it averages everybody standing on it - a tug of war",
    tiltplat    = "tilts whichever way the weight on it is",
    meshplat    = "a mesh floor that slides back and forth on its own",

    elevator    = "rides up and down its own shaft, with nobody asking it",
    arrowlift   = "rises while you stand on it, and no two are in step",
    towerlift   = "starts when somebody stands on it and stops at the top",
    rrlift      = "sinks under you, and climbs back when you step off",
    checkers    = "one press gives two platforms, riding past each other",
    ferris      = "one press builds the whole wheel and its four cars",
    cageplat    = "bobs on the spot, and brings a climbing pole up with it",
    ttclift     = "rides up and down at the clockwork's own speed",

    seesaw      = "tilts under weight - a bridge and a hazard at once",
    turntable   = "turns on the spot, and carries you round with it",
    swingplat   = "swings from one side of a gap to the other",
    octaplat    = "an eight-sided floor that spins where it stands",
    hexring     = "a ring that turns - stand on the rim and ride it",
    ttccog      = "a flat cog, and you stand on it while it turns",
    ttcgear     = "a gear turning on its face, like a hand round a clock",
    ttcsolid    = "a solid block that turns end over end",
    ttctread    = "a belt that carries you along while you stand still",
    ttcpend     = "swings across the gap and takes you over with it",
    ttcbar      = "slides out and shoves whoever is standing in the way",
    ttcpit      = "drops out from under you, and comes back again",
    ttcspin     = "spins on its own, at whatever speed the clockwork runs",

    purpleswitch = "it presses and counts down, with nothing wired to it yet",
    capswitch   = "stand on it and that cap is on in your own file for good",
    blueswitch  = "ground-pound it - the coins it shows are the level's own",
    pole        = "the way back down off everything else on this page",
    woodpost    = "ground-pound it and it goes down into the floor",
}

forge.VARIANT_NAME = {
    tree        = "Which tree",
    thwomp      = "How high it rises",
    tweester    = "How far it reaches",
    firepiranha = "Which size",
    coins       = "Which shape",
    seesaw      = "Which plank",
    turntable   = "Which way, how fast",
    ttccog      = "Which cog",
    ttcgear     = "Which gear",
    ttcsolid    = "Which block",
    ttctread    = "Which treadmill",
    octaplat    = "Which platform",
    boulder     = "What a wall does to it",
    risewall    = "Where it starts",
    cageplat    = "How far it settles",
    capswitch   = "Which cap",
}

forge.VARIANT_HELP = {
    tree        = "press to change which one you get",
    thwomp      = "press to change how far it rises before each drop",
    tweester    = "press to change how far away it will start chasing",
    firepiranha = "press to change its size - the bigger one takes a hit",
    coins       = "press to change the shape the eight land in",
    seesaw      = "press to change the plank, and what it is made of",
    turntable   = "press to change how fast it turns, and which way",
    ttccog      = "press to change its shape",
    ttcgear     = "press to change which of the three it is",
    ttcsolid    = "press to change its shape",
    ttctread    = "press to change its size and which way it runs",
    octaplat    = "press to change its look and how fast it spins",
    boulder     = "press to change what it does when it meets a wall",
    risewall    = "press to change where in its cycle it starts",
    cageplat    = "press to change how far down it settles",
    capswitch   = "press to change which cap it switches on",
}

function forge.build_pick_page(panel)
    local rows = {}

    table.insert(rows, panel.label_row(
        OF.lang.t("Press one and it lands in front of you.")))

    local shown = {}
    for _, shelf in ipairs(forge.CATEGORIES) do
        local entries = {}
        for _, key in ipairs(shelf.keys) do
            local entry = OF.spawner.find(key)

            if entry ~= nil then table.insert(entries, entry) end
        end
        if #entries > 0 then

            table.insert(rows, panel.with_right(
                panel.header_row(OF.lang.t(shelf.name)), tostring(#entries)))
            for _, entry in ipairs(entries) do
                shown[entry.key] = true
                forge.add_pick_rows(panel, rows, entry)
            end
        end
    end

    local strays = {}
    for _, entry in ipairs(OF.spawner.LIST) do
        if shown[entry.key] ~= true then table.insert(strays, entry) end
    end
    if #strays > 0 then
        table.insert(rows, panel.with_right(
            panel.header_row(OF.lang.t("Everything else")),
            tostring(#strays)))
        for _, entry in ipairs(strays) do
            forge.add_pick_rows(panel, rows, entry)
        end
    end

    table.insert(rows, panel.back_row())
    return rows
end

function forge.add_pick_rows(panel, rows, entry)
    local key = entry.key

    local said = forge.BLURBS[key]
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t(entry.name), 255, 255, 255,
        function()

            OF.util.report(forge.place(key))
            panel.close()
        end), said ~= nil and OF.lang.t(said) or nil))

    if entry.variants ~= nil and #entry.variants > 1 then
        local shown = OF.spawner.variant_name(key)
        local choice = forge.VARIANT_HELP[key]
        local named = forge.VARIANT_NAME[key]
        if named == nil then
            named = OF.lang.fill("Which @", string.lower(entry.name))
        else
            named = OF.lang.t(named)
        end
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("spawn_object", "  " .. named,
                180, 210, 255, function()
                    OF.util.report(OF.spawner.next_variant(key))
                end),
            OF.lang.t(shown or "")),
            choice ~= nil and OF.lang.t(choice) or nil))
    end
end

function forge.build_page(panel)
    local rows = {}

    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t(forge.open and "Forge is on - switch it off"
            or "Switch forge on"),
        255, 255, 255, function() OF.util.report(forge.toggle()) end),
        OF.lang.t("gives B to the hand, so it picks up and puts down")))

    local notice = OF.util.mode_notice("forge")
    if notice ~= nil then table.insert(rows, panel.label_row(notice)) end

    if forge.held ~= nil then
        table.insert(rows, panel.label_row(
            OF.lang.t("Holding something. Close this to place it.")))
    end

    if OF.util.asks(OF.sign, "build_posts_page") then
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("chat", OF.lang.t("Signposts players leave..."),
                255, 255, 255, function() panel.go("signposts") end),
            #OF.sign.posts() > 0
                and OF.lang.fill("@ up", tostring(#OF.sign.posts())) or ""),
            OF.lang.t("a board left where somebody stood, picked or written")))
    end

    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object",
            OF.lang.t("Things to place..."), 255, 255, 255,
            function() panel.go("forgepick") end),
        tostring(#OF.spawner.LIST)),
        OF.lang.t("opens the shelves of everything there is to place")))

    local sizeRow = panel.gated_row("spawn_object",
        OF.lang.t("Size") .. "  -  " .. OF.lang.t(forge.size_name()),
        255, 255, 255, function()
            OF.util.report(forge.set_size(forge.size % forge.size_count() + 1))
        end)
    table.insert(rows, panel.with_help(panel.with_slider(sizeRow, forge.size - 1,
        forge.size_count() - 1, function(wanted)
            OF.util.report(forge.set_size(wanted + 1))
        end), OF.lang.t("how big the next thing you place comes out")))
    table.insert(rows, panel.label_row(
        OF.lang.t("Size is how big it looks, not how big it is to touch.")))

    local trailRow = panel.gated_row("spawn_object",
        OF.lang.t("Leave a trail") .. "  -  "
            .. OF.lang.t(forge.trail_name()),
        255, 255, 255, function()
            OF.util.report(forge.set_trail(
                forge.trail % forge.trail_count() + 1))
        end)
    table.insert(rows, panel.with_help(panel.with_slider(trailRow, forge.trail - 1,
        forge.trail_count() - 1, function(wanted)
            OF.util.report(forge.set_trail(wanted + 1))
        end), OF.lang.t("drops a copy behind you every so far as you walk")))
    table.insert(rows, panel.label_row(
        OF.lang.t("Close this and walk. One goes down every so many steps.")))
    table.insert(rows, panel.label_row(
        OF.lang.t("It places the spot you last passed, and stops on a level change.")))

    table.insert(rows, panel.with_help(panel.confirm_row("forgeclear",
        OF.lang.t("Remove everything placed"),
        255, 140, 90, function() OF.util.report(forge.clear()) end),
        OF.lang.t("takes away what the forge put here, and only that")))

    local moved = forge.borrowed_count()
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object",
        OF.lang.t("Put the level back the way it was"), 255, 200, 140,
        function()
            local ok, put, lost = forge.put_back_all()
            if not ok then
                OF.util.report(false, put)
            elseif (lost or 0) > 0 then

                OF.notify.show("Put @ back - @ had been broken meanwhile",
                    "warn", 5, put, lost)
            else
                OF.notify.show("Put @ of the level's own back", "good", 4, put)
            end
        end), tostring(moved)),
        OF.lang.t("puts the level's own back where they were standing")))

    table.insert(rows, panel.label_row(
        OF.lang.t("B picks up whatever the ring is round - the level's own included.")))

    table.insert(rows, panel.label_row(
        OF.lang.t("Never its warps, marked while you build, nor what is not networked.")))

    table.insert(rows, panel.header_row(OF.lang.t("Inventories")))

    local invRow = panel.gated_row("spawn_object",
        OF.lang.t("Inventory") .. "  -  " .. tostring(forge.inventory)
            .. " / " .. tostring(forge.inventory_count()),
        255, 255, 255, function()
            OF.util.report(forge.select_inventory(forge.inventory + 1))
        end)
    table.insert(rows, panel.with_help(panel.with_slider(invRow,
        forge.inventory - 1, forge.inventory_count() - 1, function(wanted)
            OF.util.report(forge.select_inventory(wanted + 1))
        end), OF.lang.t("which of the three bars the six rows below show")))
    table.insert(rows, panel.label_row(
        OF.lang.t("Three bars of six. L+Z and R+Z walk them, one slot at a time.")))

    for i = 1, forge.slot_count() do
        local index = i
        local name = forge.slot_name(i)
        local r, g, b = 255, 255, 255
        if i == forge.slot then
            local gold = OF.util.gold()
            r, g, b = gold.r, gold.g, gold.b
        end

        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("spawn_object", "   " .. tostring(i), r, g, b,
                function() OF.util.report(forge.select_slot(index)) end),
            name ~= nil and OF.lang.t(name) or OF.lang.t("empty")),
            OF.lang.t("picks this slot - what is in it is what B puts down")))
    end
    if forge.in_hand() ~= nil then
        table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
            OF.lang.t("Empty this slot"), 255, 200, 140,
            function() OF.util.report(forge.forget_kind()) end),
            OF.lang.t("forgets the kind in the slot you have picked")))
    end

    table.insert(rows, panel.label_row(
        OF.lang.t("Fill it from Things to place, two rows up.")))

    table.insert(rows, panel.label_row(
        OF.lang.t("Or aim at one already in the level and press R+B.")))

    table.insert(rows, panel.with_help(panel.confirm_row("forgebar",
        OF.lang.t("Empty this inventory"), 255, 140, 90,
        function() OF.util.report(forge.clear_bar()) end),
        OF.lang.t("clears the six slots on screen and leaves the rest")))
    table.insert(rows, panel.with_help(panel.confirm_row("forgebars",
        OF.lang.t("Empty every inventory"), 255, 140, 90,
        function() OF.util.report(forge.clear_bars()) end),
        OF.lang.t("clears all eighteen slots, not only the six shown")))

    table.insert(rows, panel.label_row(
        OF.lang.t("In game, L+Z steps along the bar. Emptying a slot is this row.")))

    table.insert(rows, panel.label_row(
        OF.lang.t("L+B takes the last one back, L+R+B puts it back again.")))
    table.insert(rows, panel.label_row(
        OF.lang.t("Holding one: L+stick height, R+stick reach and sideways.")))
    table.insert(rows, panel.label_row(
        OF.lang.t("L+right stick is the size, R+right stick turns it.")))

    if OF.util.asks(OF.input, "step_forge_scale") then
        table.insert(rows, panel.header_row(OF.lang.t("Your pad - yours only")))

        table.insert(rows, panel.with_help(panel.with_right(
            panel.row(OF.lang.t("Reach and turn sensitivity"), 255, 220, 120,
                function() OF.input.step_forge_scale() end),
            OF.lang.fill("@ of @", tostring(OF.input.forge_scale_index()),
                tostring(OF.input.forge_scale_count()))),
            OF.lang.t("how hard your stick bites while you hold something")))

        local inverted = OF.input.forge_inverts_pitch()
        table.insert(rows, panel.with_help(panel.row(panel.tick(inverted,
            OF.lang.t("Invert up and down when turning (this only, not the camera)")),
            inverted and 140 or 200, inverted and 255 or 200, inverted and 160 or 200,
            function() OF.input.toggle_forge_invert_pitch() end),
            OF.lang.t("flips up and down on the stick that turns what you hold")))

        local CAMERA_SAID = {
            chord   = "while a combo is held",
            holding = "the whole time you hold something",
            off     = "never",
        }
        table.insert(rows, panel.with_help(panel.with_right(
            panel.row(OF.lang.t("Hold the camera still"), 255, 255, 255,
                function() OF.input.step_forge_camera() end),
            OF.lang.t(CAMERA_SAID[OF.input.forge_camera()] or "while a combo is held")),
            OF.lang.t("stops the camera swinging about while you aim")))
    end

    table.insert(rows, panel.back_row("fun"))
    return rows
end

local barLoaded = false
hook_event(HOOK_ON_LEVEL_INIT, function()
    if barLoaded then return end
    barLoaded = true
    forge.load_bar()
end)
