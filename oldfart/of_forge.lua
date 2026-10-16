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

local HISTORY_MAX = 64
local history = {}

local replaying = false

local function remember_place(batch)
    if replaying then return end
    table.insert(history, { kind = "place", batch = batch })
    while #history > HISTORY_MAX do table.remove(history, 1) end
end

local function remember_delete(recipe)
    table.insert(history, { kind = "delete", recipe = recipe })
    while #history > HISTORY_MAX do table.remove(history, 1) end
end

local function begin_batch()

    if OF.util.asks(OF.spawner, "begin_press") then
        OF.spawner.begin_press()
    end
    batchSeq = batchSeq + 1
    openBatch = batchSeq
    remember_place(openBatch)
    return openBatch
end

local function end_batch()
    openBatch = nil
    if OF.util.asks(OF.spawner, "end_press") then
        OF.spawner.end_press()
    end
end

local function next_batch()
    if openBatch ~= nil then return openBatch end
    batchSeq = batchSeq + 1
    remember_place(batchSeq)
    return batchSeq
end

local function batch_is_live(batch)
    for _, entry in ipairs(forge.placed) do
        if entry.batch == batch and entry.object ~= nil
            and entry.object.activeFlags ~= 0 then
            return true
        end
    end
    return false
end

local function forget_history()
    history = {}
end

forge.forget_history = forget_history

local UNDONE_MAX = 8
local undone = {}

local function forget_redo()
    undone = {}
end

function forge.undone_count()
    return #undone
end

function forge.restorable_count()
    if #history == 0 then return 0 end

    local top = history[#history]
    if top.kind == "delete" then return #top.recipe end
    local live = {}

    for _, entry in ipairs(forge.placed) do
        if entry.batch ~= nil and entry.object ~= nil and entry.object.activeFlags ~= 0 then
            live[entry.batch] = true
        end
    end
    for index = #history, 1, -1 do
        local entry = history[index]
        if entry.kind == "delete" then return #entry.recipe end
        if entry.batch ~= nil and live[entry.batch] then return 0 end
    end
    return 0
end

function forge.turned_yaw(yaw, direction, scale)
    return (yaw or 0) + ROTATE_STEP * direction * (scale or 1)
end

local function angle_of(m)
    return m.faceAngle.y
end

local function carry_spot(m, sideways)
    local angle = angle_of(m)

    local aim = forge.mouseAim
    if aim ~= nil and m == gMarioStates[0] then
        sideways = sideways or 0
        return aim.x + coss(angle) * sideways, aim.y, aim.z - sins(angle) * sideways
    end

    sideways = sideways or 0

    return m.pos.x + sins(angle) * forge.distance + coss(angle) * sideways,
           m.pos.y + forge.height,
           m.pos.z + coss(angle) * forge.distance - sins(angle) * sideways
end

forge.GROUND_ABOVE = 150
forge.GROUND_BELOW = 100
local GROUND_NO_FLOOR = -10000

function forge.grounded_y(key, x, y, z)
    if key == nil or y == nil then return y end
    local entry = OF.util.asks(OF.spawner, "find") and OF.spawner.find(key) or nil
    if entry == nil or not entry.ground then return y end
    if OF.util.binding("find_floor_height") == nil then return y end
    local floor = tonumber(find_floor_height(x, y + forge.GROUND_BELOW, z))
    if floor == nil or floor <= GROUND_NO_FLOOR then return y end
    local above = y - floor
    if above > forge.GROUND_ABOVE or above < -forge.GROUND_BELOW then return y end
    return floor
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

    local native = OF.util.asks(OF.spawner, "native_scale")
        and OF.spawner.native_scale(object) or 1.0
    obj_scale(object, (SIZES[step] or 1.0) * native)
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

    if OF.util.asks(OF.roundscope, "shares_room_with_round")
        and OF.roundscope.shares_room_with_round() then
        return true
    end
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

        forge.build_on = false

        forge.select_on = false

        forge.clear_selection()
    end

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
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.reset_mine()
    local moved = forge.select_on == true or forge.inventory ~= 1
        or forge.mouse_aim_on ~= true
    if forge.select_on == true then forge.select_on = false end
    if forge.inventory ~= 1 then use_inventory(1) end

    if forge.guide_on() then
        forge.set_guide(1)
        moved = true
    end

    if forge.mouse_aim_on ~= true then forge.set_mouse_aim(true) end

    if forge.mouse_aim_mode ~= "pointer" then
        forge.set_mouse_aim_mode("pointer")
        moved = true
    end

    if forge.KEEP_SETTING ~= nil and not forge.keep_on() then
        OF.util.store(forge.KEEP_SETTING, "1")
        moved = true
    end

    if forge.KEEP_ON_KEY ~= nil and OF.util.is_host() and gPlayerSyncTable[0] ~= nil
        and gPlayerSyncTable[0][forge.KEEP_ON_KEY] ~= "1" then
        OF.util.publish_row(0, forge.KEEP_ON_KEY, "1")
        moved = true
    end
    return moved
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
    local packed = OF.util.stored(BAR_STORE, "")
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
                and OF.spawner.find(part) == nil
                and OF.util.asks(OF.spawner, "renamed_key") then

                part = OF.spawner.renamed_key(part) or part
            end
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
    OF.sounds.ui("move", OF.sounds.MOVE)
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

forge.PACKET_AT = "forgeat"
function forge.publish_at(object, key)
    if object == nil or object.oSyncID == nil or object.oSyncID == 0 then return false end
    local at = index_of_key(key)

    if at == nil and OF.util.asks(OF.spawner, "is_building")
        and OF.spawner.is_building(key) then
        at = 0
    end
    if at == nil then return false end
    OF.util.send_all({ ofp = forge.PACKET_AT, at = at, id = object.oSyncID,
        x = object.oPosX, y = object.oPosY, z = object.oPosZ,
        fyaw = tonumber(object.oFaceAngleYaw) or 0,
        myaw = tonumber(object.oMoveAngleYaw) or 0 })
    return true
end

function forge.apply_at(data)
    if type(data) ~= "table" then return false end
    local spawn = ((OF.spawner or {}).LIST or {})[tonumber(data.at) or -1]
    if tonumber(data.at) == 0 and (OF.spawner or {}).BLOCK ~= nil then
        spawn = { bhv = OF.spawner.BLOCK, key = "block" }
    end
    if spawn == nil then return false end
    local object = live_by_sync_id(spawn.bhv)[tonumber(data.id) or -1]
    if object == nil or object.activeFlags == 0 then return false end

    if not OF.util.has_flag(tonumber(object.coopFlags) or 0,
        COOP_OBJ_FLAG_NETWORK or 0x1)
        and not (forge.keep_given ~= nil and forge.keep_given(object.oSyncID)) then
        return true
    end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if x == nil or y == nil or z == nil then return false end
    local fyaw = math.floor(tonumber(data.fyaw) or 0)
    local myaw = math.floor(tonumber(data.myaw) or fyaw)

    local oldYaw = tonumber(object.oFaceAngleYaw) or 0
    local oc, os = coss(oldYaw), sins(oldYaw)
    local nc, ns = coss(fyaw), sins(fyaw)
    local kinds = OF.util.asks(OF.spawner, "followers") and OF.spawner.followers(spawn.key) or nil
    local moved = {}
    if kinds ~= nil and OF.util.binding("obj_get_first_with_behavior_id") ~= nil then
        for _, bhv in ipairs(kinds) do
            local child = obj_get_first_with_behavior_id(bhv)
            local guard = 0
            while child ~= nil and guard < 512 do
                if child.parentObj == object and child ~= object and child.activeFlags ~= 0 then
                    local dx, dz = child.oPosX - object.oPosX, child.oPosZ - object.oPosZ
                    local rx, rz = dx * oc - dz * os, dx * os + dz * oc
                    table.insert(moved, { object = child, rx = rx, rz = rz,
                        ry = child.oPosY - object.oPosY,
                        yaw = (tonumber(child.oMoveAngleYaw) or 0) - oldYaw })
                end
                child = obj_get_next_with_same_behavior_id(child)
                guard = guard + 1
            end
        end
    end

    object.oPosX, object.oPosY, object.oPosZ = x, y, z
    object.oHomeX, object.oHomeY, object.oHomeZ = x, y, z
    object.oFaceAngleYaw = fyaw
    object.oMoveAngleYaw = myaw
    OF.util.optional("obj_update_gfx_pos_and_angle", nil, object)
    for _, rider in ipairs(moved) do
        local child = rider.object
        child.oPosX = x + rider.rx * nc + rider.rz * ns
        child.oPosY = y + rider.ry
        child.oPosZ = z - rider.rx * ns + rider.rz * nc
        child.oHomeX, child.oHomeY, child.oHomeZ = child.oPosX, child.oPosY, child.oPosZ
        local turned = (fyaw + rider.yaw) % 0x10000
        if turned >= 0x8000 then turned = turned - 0x10000 end
        child.oMoveAngleYaw = turned
        child.oFaceAngleYaw = turned
        OF.util.optional("obj_update_gfx_pos_and_angle", nil, child)
    end
    return true
end

local pendingAt = {}
hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= forge.PACKET_AT then return end
    if not forge.apply_at(data) then
        table.insert(pendingAt, { data = data, left = 150 })
    end
end)
hook_event(HOOK_UPDATE, function()
    if #pendingAt == 0 then return end
    local keep = {}
    for _, wait in ipairs(pendingAt) do
        wait.left = wait.left - 1
        if not forge.apply_at(wait.data) and wait.left > 0 then
            table.insert(keep, wait)
        end
    end
    pendingAt = keep
end)

function forge.drop()
    if forge.held == nil then return false end

    if not forge.foreign_held() then
        forge.publish_at(forge.held, forge.heldKey)
    end

    local wasForeign = forge.foreign_held()
    forge.held = nil
    forge.heldKey = nil
    if wasForeign then forge.publish_moved() end
    OF.sounds.ui("select", OF.sounds.PICK)
    return true
end

function forge.forget_kind()
    if forge.in_hand() == nil then return false end
    forge.set_slot(nil)
    OF.sounds.ui("back", OF.sounds.BACK)
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
    y = forge.grounded_y(key, x, y, z)
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
    OF.sounds.ui("open", OF.sounds.OPEN)
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
    OF.sounds.ui("move", OF.sounds.MOVE)
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
    OF.sounds.ui("select", OF.sounds.PICK)
    return true
end

local function undo_placement(wantBatch)
    local batch, key, found = nil, nil, false
    for index = #forge.placed, 1, -1 do
        local entry = forge.placed[index]
        local live = entry.object ~= nil and entry.object.activeFlags ~= 0
        if live and (wantBatch == nil or entry.batch == wantBatch) then
            batch, key, found = entry.batch, entry.key, true
            break
        end

        if wantBatch == nil and not live then table.remove(forge.placed, index) end
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
                    table.insert(recipe, 1, forge.mover_row({
                        key = entry.key,
                        x = entry.object.oPosX,
                        y = entry.object.oPosY,
                        z = entry.object.oPosZ,
                        yaw = entry.object.oFaceAngleYaw or 0,
                        pitch = entry.object.oFaceAnglePitch or 0,
                        size = entry.size or NORMAL_SIZE,
                    }, entry.object))
                end

                OF.spawner.take_down(entry.object, entry.key)
            end
            table.remove(forge.placed, index)
            taken = taken + 1
        end
        ::continue::
    end

    if #recipe > 0 then

        table.insert(undone, { kind = "place", recipe = recipe })

        while #undone > UNDONE_MAX do table.remove(undone, 1) end
    end

    forge.publish_sizes()
    forge.publish_reach()
    forge.publish_moved()
    OF.sounds.ui("back", OF.sounds.BACK)
    return true, key, taken, "place"
end

local function spawn_recipe(recipe)
    local placed, full = 0, 0
    local batch = begin_batch()
    for _, row in ipairs(recipe) do
        local taken = OF.util.asks(OF.spawner, "is_building")
            and OF.spawner.is_building(row.key)
            and forge.cell_here(row.x, row.y, row.z) ~= nil
        if taken then full = full + 1 end
        local object = (not taken)
            and forge.spawn_row(row, row.x, row.y, row.z, row.yaw, 0) or nil
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
    return batch, placed, full
end

local function undo_deletion(entry)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local wanted = #entry.recipe
    replaying = true
    local batch, placed, full = spawn_recipe(entry.recipe)
    replaying = false
    if placed == 0 then return false, "None of that could come back here." end

    table.insert(undone, { kind = "delete", batch = batch })
    while #undone > UNDONE_MAX do table.remove(undone, 1) end
    forge.publish_moved()
    OF.sounds.ui("select", OF.sounds.PICK)
    if placed < wanted then
        if full > 0 then
            return true, nil, placed, "restore",
                "Brought back " .. placed .. " of " .. wanted .. " - "
                    .. full .. " of those cells are taken now."
        end
        return true, nil, placed, "restore",
            "Brought back " .. placed .. " of " .. wanted
                .. " - the rest could not go here."
    end
    return true, nil, placed, "restore"
end

do
    function forge.remember_swap(recipe, batch)
        table.insert(history, { kind = "swap", recipe = recipe, batch = batch })
        while #history > HISTORY_MAX do table.remove(history, 1) end
    end

    function forge.merge_swap(was, batch)
        if was == nil then return false end
        local top, place = nil, nil
        for i = #history, 1, -1 do
            local h = history[i]
            if h.kind == "place" and h.batch == batch and place == nil then
                place = i
            elseif h.kind == "swap" and h.batch == was then
                top = h
                break
            end
        end
        if top == nil then return false end
        if place ~= nil then table.remove(history, place) end
        top.batch = batch
        return true
    end

    function forge.swap_round(batch, recipe)
        local ok, why = undo_placement(batch)
        if not ok then return false, why end
        local pushed = undone[#undone]
        local took = {}
        if pushed ~= nil and pushed.kind == "place" then
            table.remove(undone)
            took = pushed.recipe
        end
        replaying = true
        local newBatch, placed = spawn_recipe(recipe)
        replaying = false
        return true, took, newBatch, placed
    end
end

function forge.undo()
    while #history > 0 do
        local top = history[#history]
        if top.kind == "swap" and batch_is_live(top.batch) then
            local ok, took, batch, placed = forge.swap_round(top.batch, top.recipe)
            if not ok then return false, took end
            table.remove(history)
            table.insert(undone, { kind = "swap", recipe = took, batch = batch })
            while #undone > UNDONE_MAX do table.remove(undone, 1) end
            OF.sounds.ui("select", OF.sounds.PICK)
            return true, nil, placed, "restore"
        end
        if top.kind == "delete" then

            local ok, key, count, kind, short = undo_deletion(top)
            if ok then table.remove(history) end
            return ok, key, count, kind, short
        end
        if batch_is_live(top.batch) then
            table.remove(history)
            return undo_placement(top.batch)
        end

        table.remove(history)
    end

    return undo_placement(nil)
end

local function redo_deletion(entry)

    local ok, key, taken = undo_placement(entry.batch)
    if not ok then return false, key end

    local pushed = undone[#undone]
    if pushed ~= nil and pushed.kind == "place" then
        table.remove(undone)
        remember_delete(pushed.recipe)
    end
    return true, taken
end

function forge.redo()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local top = undone[#undone]
    if top == nil then return false, "Nothing has been taken back to put again." end

    if top.kind == "swap" then
        local ok, took, batch, placed = forge.swap_round(top.batch, top.recipe)
        if not ok then return false, took end
        table.remove(undone)
        forge.remember_swap(took, batch)
        OF.sounds.ui("select", OF.sounds.PICK)
        return true, placed, placed, nil, "place"
    end

    if top.kind == "delete" then
        local ok, taken = redo_deletion(top)
        if not ok then return false, taken end
        table.remove(undone)

        return true, taken, taken, nil, "delete"
    end

    local recipe = top.recipe
    local wanted = #recipe
    local _, placed, full = spawn_recipe(recipe)

    if placed == 0 then return false, "None of that could go back here." end

    table.remove(undone)
    OF.sounds.ui("select", OF.sounds.PICK)

    if placed < wanted then

        if full > 0 then
            return true, placed, wanted,
                "Put back " .. placed .. " of " .. wanted .. " - "
                    .. full .. " of those cells are taken now.", "place"
        end
        return true, placed, wanted,
            "Put back " .. placed .. " of " .. wanted
                .. " - the rest could not go here.", "place"
    end
    return true, placed, wanted, nil, "place"
end

local MAX_STAMP = 12

local build_stamp_line, build_stamp_plane

local STAMP_GAP = 260

function forge.stamp_line(count)

    if forge.build_live() then return build_stamp_line(count) end
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

    if forge.build_live() then
        return false, "A ring is a free-placing stamp, not a grid one."
    end
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

    if forge.build_live() then
        return false, "A staircase is a free-placing stamp, not a grid one."
    end
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

    if forge.build_live() then
        return false, "A column is a free-placing stamp, not a grid one."
    end
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
    if forge.build_live() then return build_stamp_plane(side, upward) end
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

    if forge.build_live() then
        return false, "An arch is a free-placing stamp, not a grid one."
    end
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
        OF.sounds.ui("back", OF.sounds.BACK)
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
    OF.sounds.ui("back", OF.sounds.BACK)
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
    forget_history()
    forge.publish_sizes()
    forge.publish_reach()
    return true, count
end

do

local cornerA = nil
local cornerB = nil

local group = nil

local clipboard = {}

local clipboardYaw = 0

local HALF_TURN = 0x8000

local function inside(box, x, y, z)
    return x >= box.minX and x <= box.maxX
       and y >= box.minY and y <= box.maxY
       and z >= box.minZ and z <= box.maxZ
end

local function selectable(entry)
    if entry == nil or entry.foreign then return false end
    local object = entry.object
    if object == nil or object.activeFlags == 0 then return false end
    if entry.key ~= nil and OF.util.asks(OF.spawner, "is_building")
        and OF.spawner.is_building(entry.key) then
        return false
    end
    return true
end

function forge.selection()
    if cornerA == nil or cornerB == nil then return nil end
    return {
        minX = math.min(cornerA.x, cornerB.x),
        minY = math.min(cornerA.y, cornerB.y),
        minZ = math.min(cornerA.z, cornerB.z),
        maxX = math.max(cornerA.x, cornerB.x),
        maxY = math.max(cornerA.y, cornerB.y),
        maxZ = math.max(cornerA.z, cornerB.z),
    }
end

function forge.marks()
    if cornerA == nil then return 0 end
    if cornerB == nil then return 1 end
    return 2
end

function forge.mark(m)
    m = m or gMarioStates[0]
    if m == nil then return false end
    local at = forge.aim_spot(m)
    if cornerA == nil or cornerB ~= nil then
        cornerA, cornerB = at, nil
        OF.sounds.ui("move", OF.sounds.MOVE)
        return true, 1
    end
    cornerB = at
    OF.sounds.ui("select", OF.sounds.PICK)
    return true, 2
end

function forge.clear_selection()
    cornerA, cornerB = nil, nil
    group = nil
    return true
end

function forge.selected()
    local box = forge.selection()
    local found = {}
    if box == nil then return found end
    for _, entry in ipairs(forge.placed) do
        if selectable(entry)
            and inside(box, entry.object.oPosX, entry.object.oPosY,
                       entry.object.oPosZ) then
            table.insert(found, entry)
        end
    end
    return found
end

function forge.selected_count()
    return #forge.selected()
end

local function frame_of(box)
    return (box.minX + box.maxX) / 2, box.minY, (box.minZ + box.maxZ) / 2
end

local function turned(dx, dz, yaw)
    yaw = math.floor(yaw)
    local s, c = sins(yaw), coss(yaw)
    return dx * c + dz * s, dz * c - dx * s
end

function forge.group_form()
    local members = forge.selected()
    if #members == 0 then
        return false, "Mark a box round something of yours first."
    end
    local box = forge.selection()
    local x, y, z = frame_of(box)
    local rows = {}
    for _, entry in ipairs(members) do
        local object = entry.object
        table.insert(rows, {
            entry = entry,
            dx = object.oPosX - x,
            dy = object.oPosY - y,
            dz = object.oPosZ - z,
            yaw = object.oFaceAngleYaw or 0,
            pitch = object.oFaceAnglePitch or 0,
        })
    end
    group = { x = x, y = y, z = z, yaw = 0, members = rows }
    OF.sounds.ui("select", OF.sounds.PICK)
    return true, #rows
end

function forge.group_count()
    if group == nil then return 0 end
    return #group.members
end

function forge.group_release()
    if group == nil then return false, "Nothing is grouped." end
    local n = #group.members
    group = nil
    OF.sounds.ui("back", OF.sounds.BACK)
    return true, n
end

local function carry_fields(object, dx, dz, dyaw)
    object.oVelX = dx
    object.oVelZ = dz
    object.oAngleVelYaw = dyaw
end

local function rebuild(dyaw)
    if group == nil then return 0 end
    local alive = {}
    for _, row in ipairs(group.members) do
        local object = row.entry.object

        if object ~= nil and object.activeFlags ~= 0 then
            local wasX, wasZ = object.oPosX, object.oPosZ
            local ox, oz = turned(row.dx, row.dz, group.yaw)
            object.oPosX = group.x + ox
            object.oPosY = group.y + row.dy
            object.oPosZ = group.z + oz

            object.oHomeX, object.oHomeY, object.oHomeZ =
                object.oPosX, object.oPosY, object.oPosZ

            OF.spawner.face(object, (row.yaw + group.yaw) % 0x10000)
            object.oFaceAnglePitch = row.pitch
            carry_fields(object, object.oPosX - wasX, object.oPosZ - wasZ, dyaw)
            OF.util.optional("obj_update_gfx_pos_and_angle", nil, object)
            table.insert(alive, row)
        end
    end
    group.members = alive
    return #alive
end

function forge.group_move(dx, dy, dz)
    if group == nil then return false, "Nothing is grouped." end
    group.x = group.x + (tonumber(dx) or 0)
    group.y = group.y + (tonumber(dy) or 0)
    group.z = group.z + (tonumber(dz) or 0)
    local n = rebuild(0)
    if n == 0 then
        group = nil
        return false, "Nothing of that group is still standing."
    end
    return true, n
end

local function turn_delta(step)
    local d = step % 0x10000
    if d > HALF_TURN then d = d - 0x10000 end
    return d
end

function forge.group_turn(direction, scale)
    if group == nil then return false, "Nothing is grouped." end

    local step = math.floor(
        ROTATE_STEP * ((direction or 1) < 0 and -1 or 1) * (scale or 1))
    group.yaw = (group.yaw + step) % 0x10000
    local n = rebuild(turn_delta(step))
    if n == 0 then
        group = nil
        return false, "Nothing of that group is still standing."
    end
    return true, n
end

local function group_update()
    if group == nil then return end
    if rebuild(0) == 0 then group = nil end
end

hook_event(HOOK_UPDATE, group_update)

function forge.copy_selection()
    local members = forge.selected()
    if #members == 0 then
        return false, "Mark a box round something of yours first."
    end
    local box = forge.selection()
    local x, y, z = frame_of(box)
    local rows = {}
    for _, entry in ipairs(members) do
        local object = entry.object
        table.insert(rows, forge.mover_row({
            key = entry.key,
            dx = object.oPosX - x,
            dy = object.oPosY - y,
            dz = object.oPosZ - z,
            yaw = object.oFaceAngleYaw or 0,
            pitch = object.oFaceAnglePitch or 0,
            size = entry.size or NORMAL_SIZE,
        }, object, x, y, z))
    end
    clipboard = rows
    clipboardYaw = 0
    OF.sounds.ui("select", OF.sounds.PICK)
    return true, #rows
end

function forge.clipboard_count()
    return #clipboard
end

function forge.forget_copy()
    clipboard = {}
    clipboardYaw = 0
    return true
end

local function to_delete()
    if group ~= nil then
        local rows = {}
        for _, row in ipairs(group.members) do
            if selectable(row.entry) then table.insert(rows, row.entry) end
        end
        return rows
    end
    return forge.selected()
end

function forge.delete_count()
    return #to_delete()
end

function forge.delete_selection()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local members = to_delete()
    if #members == 0 then
        return false, "Mark a box round something of yours first."
    end

    local recipe = {}
    local doomed = {}
    for _, entry in ipairs(members) do
        local object = entry.object
        doomed[entry] = true
        table.insert(recipe, forge.mover_row({
            key = entry.key,
            x = object.oPosX,
            y = object.oPosY,
            z = object.oPosZ,
            yaw = object.oFaceAngleYaw or 0,
            pitch = object.oFaceAnglePitch or 0,
            size = entry.size or NORMAL_SIZE,
        }, object))
    end

    group = nil

    for index = #forge.placed, 1, -1 do
        local entry = forge.placed[index]
        if doomed[entry] then

            if forge.held == entry.object then
                forge.held = nil
                forge.heldKey = nil
            end

            OF.spawner.take_down(entry.object, entry.key)
            table.remove(forge.placed, index)
        end
    end

    remember_delete(recipe)

    forget_redo()

    forge.publish_sizes()
    forge.publish_reach()
    OF.sounds.ui("back", OF.sounds.BACK)
    return true, #recipe
end

local function room_for(n)
    if not OF.util.asks(OF.spawner, "fair_share") then return true, n end
    local share = OF.spawner.fair_share(n)
    return n <= share, share
end

function forge.paste(m)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if #clipboard == 0 then return false, "Nothing has been copied." end
    m = m or gMarioStates[0]
    if m == nil then return false end

    local fits, free = room_for(#clipboard)
    if not fits then
        return false, "This copy is " .. #clipboard
            .. " and there is space for " .. free .. ". Nothing was placed."
    end

    if not forge.open then
        local ok, why = forge.toggle()
        if not ok then return false, why end
    end

    local at = forge.aim_spot(m)

    forget_redo()
    local batch = begin_batch()
    local placed = 0
    for _, row in ipairs(clipboard) do
        local ox, oz = turned(row.dx, row.dz, clipboardYaw)

        local object = forge.spawn_row(row,
            at.x + ox, at.y + row.dy, at.z + oz, (row.yaw + clipboardYaw) % 0x10000, clipboardYaw)
        if object ~= nil then
            OF.spawner.face(object, (row.yaw + clipboardYaw) % 0x10000)
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

    if placed == 0 then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, "None of that could go here."
    end
    OF.sounds.ui("select", OF.sounds.PICK)
    return true, placed
end

function forge.mark_at(which)
    local corner = (which == 2) and cornerB or cornerA
    if corner == nil then return nil end
    return { x = corner.x, y = corner.y, z = corner.z }
end

function forge.group_frame()
    if group == nil then return nil end
    local minX, minY, minZ, maxX, maxY, maxZ
    local standing = 0
    for _, row in ipairs(group.members) do
        local object = row.entry.object
        if object ~= nil and object.activeFlags ~= 0 then
            local x, y, z = object.oPosX, object.oPosY, object.oPosZ
            if type(x) == "number" and type(y) == "number"
                and type(z) == "number" then
                if minX == nil then
                    minX, maxX = x, x
                    minY, maxY = y, y
                    minZ, maxZ = z, z
                else
                    if x < minX then minX = x end
                    if x > maxX then maxX = x end
                    if y < minY then minY = y end
                    if y > maxY then maxY = y end
                    if z < minZ then minZ = z end
                    if z > maxZ then maxZ = z end
                end
                standing = standing + 1
            end
        end
    end
    return {
        x = group.x, y = group.y, z = group.z, yaw = group.yaw,
        count = standing,
        minX = minX, minY = minY, minZ = minZ,
        maxX = maxX, maxY = maxY, maxZ = maxZ,
    }
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    cornerA, cornerB = nil, nil
    group = nil
end)

end

forge.select_on = false
forge.selectFromBuild = false

function forge.select_live()
    return forge.open == true and forge.select_on == true
end

function forge.select_verb()
    if forge.group_count() > 0 then return "let the build go" end
    if forge.marks() >= 2 and forge.selected_count() > 0 then
        return "grab what is in the box"
    end
    if forge.marks() >= 2 then return "start a new box" end
    if forge.marks() == 1 then return "mark the other corner" end
    return "mark a corner"
end

function forge.select_toggle()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    forge.select_on = not forge.select_on
    if forge.select_on then

        forge.drop()

        forge.selectFromBuild = forge.build_on == true
        forge.build_on = false
        OF.notify.show(
            "Marking - B marks a corner, R+B drops the box, L+Z copies",
            "info", 5)
    else

        forge.clear_selection()
        local back = forge.selectFromBuild == true and forge.build_count() > 0
        forge.selectFromBuild = false
        if back then

            forge.build_on = true
            OF.notify.show("Building - B lays a @, R+B takes one out", "info", 4,
                OF.lang.t(forge.build_name() or ""))
        else
            OF.notify.show("Free placing again - B puts down what the bar holds",
                "info", 4)
        end
    end
    return true
end

function forge.select_clear()
    local held = forge.group_count()
    local marks = forge.marks()
    forge.clear_selection()
    OF.sounds.ui("back", OF.sounds.BACK)
    if held > 0 then
        OF.notify.show("Let the build go - @ still standing where it is",
            "info", 3, held)
    elseif marks > 0 then
        OF.notify.show("Box dropped", "info", 3)
    end
    return true
end

function forge.select_act(m)
    m = m or gMarioStates[0]
    if forge.group_count() > 0 then
        local ok, n = forge.group_release()
        if not ok then return false, n end
        OF.notify.show("Let go - @ standing where the build is now",
            "good", 3, n)
        return true, n
    end
    if forge.marks() >= 2 and forge.selected_count() > 0 then
        local ok, n = forge.group_form()
        if not ok then return false, n end
        OF.notify.show("The build is in hand - @ in it, and the cursor carries it",
            "good", 4, n)
        return true, n
    end
    local ok, marks = forge.mark(m)
    if not ok then return false, "There is nobody here to mark a corner for." end
    if marks == 1 then
        OF.notify.show("One corner down - B marks the other", "info", 3)
    else
        OF.notify.show("Box marked - @ of yours inside it", "good", 3,
            forge.selected_count())
    end
    return true, marks
end

function forge.headroom()
    if not OF.util.asks(OF.spawner, "free") then return nil end
    return OF.spawner.free()
end

local carriedAt = nil

local function carry_group(m)
    if m == nil or not forge.select_live() or forge.group_count() == 0 then
        carriedAt = nil
        return false
    end
    local at = forge.aim_spot(m)
    if carriedAt ~= nil then
        local dx = at.x - carriedAt.x
        local dy = at.y - carriedAt.y
        local dz = at.z - carriedAt.z
        if dx ~= 0 or dy ~= 0 or dz ~= 0 then
            forge.group_move(dx, dy, dz)
        end
    end
    carriedAt = at
    return true
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

forge.build_on = false
forge.build_pick = 1

forge.pick_blocks = false

function forge.build_live()
    return forge.open == true and forge.build_on == true
end

function forge.build_count()
    return #((OF.spawner or {}).BUILD_LIST or {})
end

local function build_entry(step)
    local list = (OF.spawner or {}).BUILD_LIST or {}
    if #list == 0 then return nil end
    return list[((math.floor(step or 1) - 1) % #list) + 1]
end

forge.build_entry = build_entry

function forge.build_name(step)
    local entry = build_entry(step or forge.build_pick)
    return entry ~= nil and entry.name or nil
end

function forge.build_key(step)
    local entry = build_entry(step or forge.build_pick)
    return entry ~= nil and entry.key or nil
end

forge.build_turn = 0
forge.build_flip = false

local TURN_NAMES = { [0] = "not turned", "turned 90", "turned 180", "turned 270" }

function forge.build_turn_name()
    return TURN_NAMES[forge.build_turn % 4]
end

function forge.view_yaw(m)
    m = m or gMarioStates[0]
    if m == nil then return 0 end
    local cam = m.area ~= nil and m.area.camera or nil
    if cam ~= nil and type(cam.yaw) == "number" then
        return math.floor(cam.yaw + 0x8000) % 0x10000
    end
    return math.floor(tonumber(m.faceAngle.y) or 0) % 0x10000
end

function forge.build_yaw()
    local turn = (forge.build_turn % 4) * 0x4000
    local entry = build_entry(forge.build_pick)
    if entry ~= nil and entry.slope ~= nil then

        return OF.spawner.quarter_yaw((forge.view_yaw() + 0x8000 + turn) % 0x10000)
    end
    return OF.spawner.quarter_yaw(turn)
end

function forge.build_flippable(step)
    local entry = build_entry(step or forge.build_pick)
    return entry ~= nil and entry.flipped ~= nil
end

function forge.build_place_key(step)
    local entry = build_entry(step or forge.build_pick)
    if entry == nil then return nil end
    if forge.build_flip and entry.flipped ~= nil then return entry.flipped end
    return forge.build_key(step)
end

function forge.build_said()
    local name = OF.lang.t(forge.build_name() or "")
    local turned = OF.lang.t(forge.build_turn_name())
    if forge.build_flip and forge.build_flippable() then
        return OF.lang.fill("@, @, upside down", name, turned)
    end
    return OF.lang.fill("@, @", name, turned)
end

function forge.build_turn_by(step)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    step = math.floor(tonumber(step) or 1)
    forge.build_turn = (forge.build_turn + step) % 4
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.build_flip_toggle()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if not forge.build_flippable() then
        return false, "Only slopes, corners and slabs turn upside down."
    end
    forge.build_flip = not forge.build_flip
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.build_rise()
    local entry = build_entry(forge.build_pick)

    if entry == nil or entry.slope == nil or entry.flat or entry.roof then return nil end
    local yaw = forge.build_yaw()
    return -sins(yaw), -coss(yaw)
end

function forge.set_build(step)
    if type(step) ~= "number" then return false end
    if forge.build_count() == 0 then
        return false, "This build has no blocks to build with."
    end
    forge.build_pick = ((math.floor(step) - 1) % forge.build_count()) + 1
    forge.prefabPick = nil
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

do

forge.SHAPE_FAMILIES = {
    { name = "Blocks", shapes = { "cube", "slab", "plate", "slab2", "slab4", "plate2", "plate4" } },
    { name = "Ramps", shapes = { "slope", "outer", "inner", "ridge", "pyramid" } },
    { name = "Wedges", shapes = { "wedge", "wedgetip", "wedgeouter", "wedgeinner",
        "wedgetipouter", "wedgetipinner" } },
    { name = "Stairs", shapes = { "stairs", "outerstairs", "innerstairs" } },
    { name = "Walls", shapes = { "wall", "wallcorner", "wallt", "wallcross", "panel", "prism",
        "wall2", "wall4", "panel2", "panel4" } },
    { name = "Fences", shapes = { "fence", "fencecorner" } },
    { name = "Columns", shapes = { "pillar", "pole", "roundcorner" } },
    { name = "Openings", shapes = { "doorway", "window", "arch" } },
}
forge.SHAPE_NAMES = {
    cube = "Cube", slab = "Slab", slope = "Slope", outer = "Outer corner",
    inner = "Inner corner", stairs = "Stairs", outerstairs = "Outer corner stairs",
    innerstairs = "Inner corner stairs", wall = "Wall", wallcorner = "Wall corner",
    prism = "Diagonal half", fence = "Fence", fencecorner = "Fence corner",
    pillar = "Pillar", arch = "Arch",
    plate = "Plate", ridge = "Ridge", pyramid = "Pyramid", wedge = "Wedge",
    wedgetip = "Wedge tip", wedgeouter = "Wedge outer", wedgeinner = "Wedge inner",
    wedgetipouter = "Tip outer", wedgetipinner = "Tip inner", wallt = "Wall T",
    wallcross = "Wall cross", panel = "Panel", pole = "Pole",
    roundcorner = "Round corner", doorway = "Doorway", window = "Window",
    slab2 = "Slab, 2 long", slab4 = "Slab, 4 long", plate2 = "Plate, 2 long",
    plate4 = "Plate, 4 long", wall2 = "Wall, 2 long", wall4 = "Wall, 4 long",
    panel2 = "Panel, 2 long", panel4 = "Panel, 4 long",
}

local familyOf = {}
for f, family in ipairs(forge.SHAPE_FAMILIES) do
    for v, shape in ipairs(family.shapes) do familyOf[shape] = { f, v } end
end

local familyLast = {}

function forge.shape_of(entry)
    if entry == nil then return nil end
    return entry.shape or entry.slope or "cube"
end

function forge.material_of(entry)
    if entry == nil then return nil end

    if entry.decor ~= nil then return nil end
    if entry.material ~= nil then return entry.material end
    local key = tostring(entry.key or "")
    if entry.slope == nil then return (key:gsub("^blk", "")) end
    return key:sub(#entry.slope + 1)
end

local kit = { list = nil, count = -1, at = {}, materials = {} }

local function kit_index()
    local list = (OF.spawner or {}).BUILD_LIST or {}
    if kit.list == list and kit.count == #list and kit.first == list[1]
        and kit.last == list[#list] then
        return kit
    end
    kit.list, kit.count, kit.first, kit.last = list, #list, list[1], list[#list]
    kit.at, kit.materials, kit.counts = {}, {}, {}
    local seen = {}
    for index, entry in ipairs(list) do
        local material, shape = forge.material_of(entry), forge.shape_of(entry)
        if material ~= nil and shape ~= nil then
            if not seen[material] then
                seen[material] = true
                table.insert(kit.materials, material)
            end
            if kit.at[material .. ":" .. shape] == nil then
                kit.counts[material] = (kit.counts[material] or 0) + 1
            end
            kit.at[material .. ":" .. shape] = index
        end
    end
    return kit
end

function forge.shape_count(material)
    if material == nil then return 0 end
    return kit_index().counts[material] or 0
end

function forge.build_shape()
    return forge.shape_of(build_entry(forge.build_pick))
end

function forge.build_material()
    return forge.material_of(build_entry(forge.build_pick))
end

function forge.picture_name(entry)
    if entry == nil then return nil end
    if entry.icon ~= nil and OF.panel ~= nil and type(OF.panel.texture_info) == "function"
        and OF.panel.texture_info(entry.icon) ~= nil then
        return entry.icon
    end
    return entry.swatch
end

function forge.build_swatch()
    return forge.picture_name(build_entry(forge.build_pick))
end

function forge.build_index(material, shape)
    if material == nil or shape == nil then return nil end
    return kit_index().at[material .. ":" .. shape]
end

function forge.shape_family(shape)
    local at = familyOf[shape or ""]
    if at == nil then return nil end
    return at[1], at[2]
end

function forge.family_open(f, material)
    local family = forge.SHAPE_FAMILIES[f]
    material = material or forge.build_material()
    if family == nil or material == nil then return false end
    for _, shape in ipairs(family.shapes) do
        if forge.build_index(material, shape) ~= nil then return true end
    end
    return false
end

function forge.shape_name(shape)
    return forge.SHAPE_NAMES[shape or ""] or tostring(shape or "")
end

forge.kitTouched = -1000

local function pick_row(index)
    if index == nil then return false end
    forge.build_pick = index
    forge.prefabPick = nil
    local f = forge.shape_family(forge.build_shape())
    if f ~= nil then familyLast[f] = forge.build_shape() end
    forge.kitTouched = get_global_timer ~= nil and get_global_timer() or 0
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.build_pick_shape(shape)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local material = forge.build_material()
    if material == nil then return false, "This build has no blocks to build with." end
    local index = forge.build_index(material, shape)
    if index == nil then
        return false, OF.lang.fill("No @ in this texture", OF.lang.t(forge.shape_name(shape)))
    end
    return pick_row(index)
end

function forge.build_shape_by(step)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local material, shape = forge.build_material(), forge.build_shape()
    local f, v = forge.shape_family(shape)
    if f == nil then return false, "This build has no blocks to build with." end
    local shapes = forge.SHAPE_FAMILIES[f].shapes
    step = (tonumber(step) or 1) >= 0 and 1 or -1
    for k = 1, #shapes - 1 do
        local want = shapes[((v - 1 + k * step) % #shapes) + 1]
        local index = forge.build_index(material, want)
        if index ~= nil then return pick_row(index) end
    end
    return false, OF.lang.fill("Only one shape of @ in this texture",
        string.lower(OF.lang.t(forge.SHAPE_FAMILIES[f].name)))
end

function forge.build_family_pick(f)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local family = forge.SHAPE_FAMILIES[f]
    if family == nil then return false, "No such shape." end
    local material = forge.build_material()
    if material == nil then return false, "This build has no blocks to build with." end
    if forge.shape_family(forge.build_shape()) == f then
        return forge.build_shape_by(1)
    end
    local want = familyLast[f]
    local index = want ~= nil and forge.build_index(material, want) or nil
    if index == nil then
        for _, shape in ipairs(family.shapes) do
            index = forge.build_index(material, shape)
            if index ~= nil then break end
        end
    end
    if index == nil then
        return false, OF.lang.fill("No @ in this texture", string.lower(OF.lang.t(family.name)))
    end
    return pick_row(index)
end

function forge.build_family_by(step)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local f = forge.shape_family(forge.build_shape())
    if f == nil then return false, "This build has no blocks to build with." end
    step = (tonumber(step) or 1) >= 0 and 1 or -1
    local count = #forge.SHAPE_FAMILIES
    for k = 1, count - 1 do
        local want = ((f - 1 + k * step) % count) + 1
        if forge.family_open(want) then return forge.build_family_pick(want) end
    end
    return false, "This texture comes in one kind of shape only."
end

function forge.build_cycle_by(step)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local material, shape = forge.build_material(), forge.build_shape()
    if material == nil then return false, "This build has no blocks to build with." end
    local order = {}
    for _, family in ipairs(forge.SHAPE_FAMILIES) do
        for _, s in ipairs(family.shapes) do
            if forge.build_index(material, s) ~= nil then table.insert(order, s) end
        end
    end
    if #order < 2 then return false, "This texture comes in one shape only." end
    local here = 1
    for i, s in ipairs(order) do if s == shape then here = i end end
    step = (tonumber(step) or 1) >= 0 and 1 or -1
    return pick_row(forge.build_index(material, order[((here - 1 + step) % #order) + 1]))
end

function forge.build_material_by(step)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local k = kit_index()
    local material, shape = forge.build_material(), forge.build_shape()
    if material == nil then return false, "This build has no blocks to build with." end
    local here = 1
    for i, m in ipairs(k.materials) do if m == material then here = i end end
    step = (tonumber(step) or 1) >= 0 and 1 or -1
    for n = 1, #k.materials - 1 do
        local want = k.materials[((here - 1 + n * step) % #k.materials) + 1]
        local index = forge.build_index(want, shape)
        if index ~= nil then return pick_row(index) end
    end
    return false, OF.lang.fill("No other texture comes as a @",
        string.lower(OF.lang.t(forge.shape_name(shape))))
end

function forge.forget_shape_memory()
    familyLast = {}
end

local LO, HI, TOP = -100, 100, 200
local function zigzag(fromX, fromZ, toX, toZ, steps)
    local out, rise = {}, TOP / steps
    for k = 0, steps - 1 do
        local x0 = fromX + (toX - fromX) * k / steps
        local z0 = fromZ + (toZ - fromZ) * k / steps
        local x1 = fromX + (toX - fromX) * (k + 1) / steps
        local z1 = fromZ + (toZ - fromZ) * (k + 1) / steps
        table.insert(out, { x0, rise * k, z0, x0, rise * (k + 1), z0 })
        table.insert(out, { x0, rise * (k + 1), z0, x1, rise * (k + 1), z1 })
    end
    return out
end
local function rect_x(x0, x1, z, high)
    return { { x0, 0, z, x1, 0, z }, { x1, 0, z, x1, high, z },
             { x1, high, z, x0, high, z }, { x0, high, z, x0, 0, z } }
end
local function rect_z(z0, z1, x, high)
    return { { x, 0, z0, x, 0, z1 }, { x, 0, z1, x, high, z1 },
             { x, high, z1, x, high, z0 }, { x, high, z0, x, 0, z0 } }
end
local function join(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, seg in ipairs(list) do table.insert(out, seg) end
    end
    return out
end
local function arch_end(z)
    local out, n = {}, 8
    for k = 0, n - 1 do
        local a0, a1 = math.pi * k / n, math.pi * (k + 1) / n
        table.insert(out, { HI * math.cos(a0), HI * math.sin(a0), z,
                            HI * math.cos(a1), HI * math.sin(a1), z })
    end
    return out
end
local function rect_xy(x0, x1, y0, y1, z)
    return { { x0, y0, z, x1, y0, z }, { x1, y0, z, x1, y1, z },
             { x1, y1, z, x0, y1, z }, { x0, y1, z, x0, y0, z } }
end
local function quarter_arc(y)
    local out, n = {}, 6
    for k = 0, n - 1 do
        local a0, a1 = (math.pi / 2) * k / n, (math.pi / 2) * (k + 1) / n
        table.insert(out, { LO + 200 * math.cos(a0), y, LO + 200 * math.sin(a0),
                            LO + 200 * math.cos(a1), y, LO + 200 * math.sin(a1) })
    end
    return out
end

local function wedge_guide(lo)
    return { { LO, lo, HI, HI, lo, HI }, { LO, lo + 100, LO, HI, lo + 100, LO },
             { 0, lo, HI, 0, lo + 100, LO } }
end
local function wedge_corner_guide(lo, inner)
    local hi = lo + 100
    if inner then
        return { { HI, lo, HI, LO, hi, LO }, { LO, hi, LO, HI, hi, LO }, { LO, hi, LO, LO, hi, HI } }
    end
    return { { HI, lo, HI, LO, hi, LO }, { HI, lo, LO, HI, lo, HI }, { LO, lo, HI, HI, lo, HI } }
end
local function octagon(y, r)
    local out, n = {}, 8
    for k = 0, n - 1 do
        local a0, a1 = (k + 0.5) * 2 * math.pi / n, (k + 1.5) * 2 * math.pi / n
        table.insert(out, { r * math.cos(a0), y, r * math.sin(a0),
                            r * math.cos(a1), y, r * math.sin(a1) })
    end
    return out
end

forge.SHAPE_GUIDES = {
    cube = { { 0, TOP, 0, 0, TOP, LO } },
    slab = { { LO, 100, LO, HI, 100, LO }, { HI, 100, LO, HI, 100, HI },
             { HI, 100, HI, LO, 100, HI }, { LO, 100, HI, LO, 100, LO },
             { 0, 100, 0, 0, 20, 0 } },
    slope = { { LO, 0, HI, HI, 0, HI }, { LO, TOP, LO, HI, TOP, LO }, { 0, 0, HI, 0, TOP, LO } },
    outer = { { HI, 0, HI, LO, TOP, LO }, { HI, 0, LO, HI, 0, HI }, { LO, 0, HI, HI, 0, HI } },
    inner = { { HI, 0, HI, LO, TOP, LO }, { LO, TOP, LO, HI, TOP, LO }, { LO, TOP, LO, LO, TOP, HI } },
    stairs = zigzag(0, HI, 0, LO, 5),
    outerstairs = join(zigzag(HI, HI, LO, LO, 5),
        { { HI, 0, LO, HI, 0, HI }, { LO, 0, HI, HI, 0, HI } }),
    innerstairs = join(zigzag(HI, HI, LO, LO, 5),
        { { LO, TOP, LO, HI, TOP, LO }, { LO, TOP, LO, LO, TOP, HI } }),
    wall = rect_x(LO, HI, 0, TOP),
    wallcorner = join(rect_x(LO, 0, 0, TOP), rect_z(LO, 0, 0, TOP)),
    fence = join(rect_x(LO, HI, 0, 160), { { LO, 80, 0, HI, 80, 0 } }),
    fencecorner = join(rect_x(LO, 0, 0, 160), rect_z(LO, 0, 0, 160)),
    pillar = join(octagon(TOP, 60), { { 0, 0, 0, 0, TOP, 0 } }),
    arch = join(arch_end(LO), arch_end(HI),
        { { LO, TOP, LO, LO, TOP, HI }, { HI, TOP, LO, HI, TOP, HI } }),
    prism = { { HI, 0, LO, LO, 0, HI }, { HI, TOP, LO, LO, TOP, HI },
              { HI, 0, LO, HI, TOP, LO }, { LO, 0, HI, LO, TOP, HI },
              { LO, 0, LO, HI, 0, LO }, { LO, 0, LO, LO, 0, HI } },

    plate = { { LO, 20, LO, HI, 20, LO }, { HI, 20, LO, HI, 20, HI },
              { HI, 20, HI, LO, 20, HI }, { LO, 20, HI, LO, 20, LO } },
    wedge = wedge_guide(0),
    wedgetip = wedge_guide(100),
    wedgeouter = wedge_corner_guide(0, false),
    wedgeinner = wedge_corner_guide(0, true),
    wedgetipouter = wedge_corner_guide(100, false),
    wedgetipinner = wedge_corner_guide(100, true),
    ridge = { { LO, 100, 0, HI, 100, 0 }, { LO, 0, HI, HI, 0, HI }, { LO, 0, LO, HI, 0, LO } },
    pyramid = { { LO, 0, LO, 0, 100, 0 }, { HI, 0, LO, 0, 100, 0 },
                { HI, 0, HI, 0, 100, 0 }, { LO, 0, HI, 0, 100, 0 } },
    wallt = join(rect_x(LO, HI, 0, TOP), rect_z(LO, 0, 0, TOP)),
    wallcross = join(rect_x(LO, HI, 0, TOP), rect_z(LO, HI, 0, TOP)),
    panel = rect_x(LO, HI, LO + 20, TOP),
    pole = { { -20, TOP, -20, 20, TOP, -20 }, { 20, TOP, -20, 20, TOP, 20 },
             { 20, TOP, 20, -20, TOP, 20 }, { -20, TOP, 20, -20, TOP, -20 },
             { 0, 0, 0, 0, TOP, 0 } },
    roundcorner = join(quarter_arc(TOP), quarter_arc(0)),
    doorway = join(rect_x(LO, HI, 0, TOP), rect_xy(-70, 70, 0, 180, 0)),
    window = join(rect_x(LO, HI, 0, TOP), rect_xy(-50, 50, 80, 160, 0)),

    slab2 = join(rect_xy(LO, LO + 400, 0, 100, LO), rect_xy(LO, LO + 400, 0, 100, HI)),
    slab4 = join(rect_xy(LO, LO + 800, 0, 100, LO), rect_xy(LO, LO + 800, 0, 100, HI)),
    plate2 = join(rect_xy(LO, LO + 400, 0, 20, LO), rect_xy(LO, LO + 400, 0, 20, HI)),
    plate4 = join(rect_xy(LO, LO + 800, 0, 20, LO), rect_xy(LO, LO + 800, 0, 20, HI)),
    wall2 = rect_x(LO, LO + 400, 0, TOP),
    wall4 = rect_x(LO, LO + 800, 0, TOP),
    panel2 = rect_x(LO, LO + 400, LO + 20, TOP),
    panel4 = rect_x(LO, LO + 800, LO + 20, TOP),
}

function forge.shape_guide(shape, cx, cy, cz, yaw, flipped)
    local frame = forge.SHAPE_GUIDES[shape or ""]
    if frame == nil or cx == nil then return nil end
    local s, c = sins(yaw or 0), coss(yaw or 0)
    local function at(x, y, z)
        if flipped then y = TOP - y end
        return { x = cx + x * c + z * s, y = cy + y, z = cz - x * s + z * c }
    end
    local out = {}
    for _, seg in ipairs(frame) do
        table.insert(out, { at(seg[1], seg[2], seg[3]), at(seg[4], seg[5], seg[6]) })
    end
    return out
end

function forge.build_guide(m)
    if forge.prefabPick ~= nil and forge.prefab_guide ~= nil then return forge.prefab_guide(m) end
    local entry = build_entry(forge.build_pick)
    if entry == nil then return nil end
    local cx, cy, cz = forge.cell_cursor(m)
    if cx == nil then return nil end
    return forge.shape_guide(forge.shape_of(entry), cx, cy, cz, forge.build_yaw(),
        forge.build_flip and entry.flipped ~= nil)
end
end

function forge.ensure_open()
    if forge.open then return true end
    return forge.toggle()
end

function forge.choose_block(step)
    local ok, why = forge.set_build(step)
    if not ok then return false, why end
    local opened, notOpened = forge.ensure_open()
    if not opened then return false, notOpened end
    if not forge.build_on then return forge.build_toggle() end
    return true
end

function forge.choose_slot(index)
    local ok, why = forge.select_slot(index)
    if not ok then return false, why end
    return forge.ensure_open()
end

function forge.build_toggle()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if not forge.build_on and forge.build_count() == 0 then
        return false, "This build has no blocks to build with."
    end
    forge.build_on = not forge.build_on
    if forge.build_on then

        forge.select_on = false
        forge.clear_selection()

        forge.drop()
    end

    return true
end

local function build_cell()
    local cell = (OF.spawner or {}).BUILD_CELL
    if type(cell) ~= "number" or cell <= 0 then return 200 end
    return cell
end

function forge.cell_of(value)
    if type(value) ~= "number" then return nil end
    return math.floor(value / build_cell() + 0.5)
end

function forge.cell_at(index)
    if type(index) ~= "number" then return nil end
    return index * build_cell()
end

function forge.cell_cursor(m)
    m = m or gMarioStates[0]
    if m == nil then return nil end

    local aim = forge.mouseAim
    if aim ~= nil and m == gMarioStates[0] then return aim.cx, aim.cy, aim.cz end
    local x, y, z = carry_spot(m, 0)
    return forge.cell_at(forge.cell_of(x)),
           forge.cell_at(forge.cell_of(y)),
           forge.cell_at(forge.cell_of(z))
end

function forge.cell_here(x, y, z)
    local bhv = (OF.spawner or {}).BLOCK
    if bhv == nil then return nil end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return nil end
    local wantX, wantY, wantZ =
        forge.cell_of(x), forge.cell_of(y), forge.cell_of(z)
    if wantX == nil or wantY == nil or wantZ == nil then return nil end

    local object = obj_get_first_with_behavior_id(bhv)
    local reach = forge.STRETCH_REACH
    while object ~= nil do
        if object.activeFlags ~= 0 then
            local oy = forge.cell_of(object.oPosY)
            local ox, oz = forge.cell_of(object.oPosX), forge.cell_of(object.oPosZ)
            if oy == wantY and ox == wantX and oz == wantZ then return object end

            if wantY >= oy and wantY - oy < reach and math.abs(ox - wantX) <= reach
                and math.abs(oz - wantZ) <= reach and forge.fills(object, x, y, z) then
                return object
            end
        end
        object = obj_get_next_with_same_behavior_id(object)
    end
    return nil
end

forge.STRETCH_REACH = 32

function forge.fills(object, x, y, z)
    if object == nil or not OF.util.asks(OF.spawner, "runtime_word") then return false end
    local cell = build_cell()
    local word = OF.spawner.runtime_word(object, true)
    if word == nil then

        local ox, oz = forge.cell_of(object.oPosX), forge.cell_of(object.oPosZ)
        local wx, wz = forge.cell_of(x), forge.cell_of(z)
        if forge.cell_of(object.oPosY) ~= forge.cell_of(y) or math.abs(ox - wx) > 3
            or math.abs(oz - wz) > 3 then
            return false
        end
        local span = OF.spawner.span_of(object)
        local dx, dz = forge.span_step(object.oFaceAngleYaw)
        for k = 1, span - 1 do
            if ox + dx * k == wx and oz + dz * k == wz then return true end
        end
        return false
    end
    if not OF.stretch.sized(word) then return false end
    local _, _, w, h, d = OF.stretch.shape_decode(word)
    local q = OF.spawner.quarter_of(object.oFaceAngleYaw or 0)
    local c = ({ 1, 0, -1, 0 })[q + 1]
    local s = ({ 0, 1, 0, -1 })[q + 1]
    local dx, dy, dz = x - object.oPosX, y - object.oPosY, z - object.oPosZ

    local lx, lz = dx * c - dz * s, dx * s + dz * c
    return math.abs(lx) < w * cell / 2 - 1 and math.abs(lz) < d * cell / 2 - 1
        and dy > -1 and dy < h * cell - cell + 1
end

function forge.span_step(yaw)
    local q = OF.spawner.quarter_of(yaw or 0)
    if q == 0 then return 1, 0 end
    if q == 1 then return 0, -1 end
    if q == 2 then return -1, 0 end
    return 0, 1
end

function forge.span_cells(key, x, z, yaw)
    local entry = OF.spawner.build_find(key)
    local span = entry ~= nil and entry.span or 1
    local out = { { x = x, z = z } }
    if span > 1 then
        local dx, dz = forge.span_step(yaw)
        local cell = ((OF.spawner or {}).BUILD_CELL) or 200
        for k = 1, span - 1 do
            table.insert(out, { x = x + dx * k * cell, z = z + dz * k * cell })
        end
    end
    return out
end

forge.waterWarned = nil
function forge.water_notice(key)
    local mat = OF.spawner and OF.spawner.WATER_MATERIAL
    if type(key) ~= "string" or type(mat) ~= "string" or key:sub(-#mat) ~= mat then
        return false
    end
    if not OF.util.asks(OF.spawner, "water_here") or OF.spawner.water_here() then
        return false
    end
    local np = gNetworkPlayers[0]
    local here = (np ~= nil) and (tostring(np.currLevelNum) .. ":" .. tostring(np.currAreaIndex))
        or "?"
    if forge.waterWarned == here then return false end
    forge.waterWarned = here
    OF.notify.show("No water in this level: the block is only its picture", "warn", 5)
    return true
end

local function lay_block(key, x, y, z, yaw, extra)

    if extra ~= nil and extra.w ~= nil then
        if not forge.box_free(forge.size_box(x, y, z, yaw, extra.w, extra.h, extra.d)) then
            return false, "full"
        end
    else
        for _, c in ipairs(forge.span_cells(key, x, z, yaw)) do
            if forge.cell_here(c.x, y, c.z) ~= nil then return false, "full" end
        end
    end
    local object = OF.spawner.spawn_at(key, x, y, z, yaw, extra)
    if object == nil then return false, "no" end
    forge.water_notice(key)

    forget_redo()
    table.insert(forge.placed, { object = object, key = key,
                                 size = NORMAL_SIZE, batch = next_batch() })
    return true
end

function forge.build_place()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end

    if forge.prefabPick ~= nil and forge.prefab_place ~= nil then return forge.prefab_place() end
    local entry = build_entry(forge.build_pick)
    if entry == nil then return false, "This build has no blocks to build with." end

    if not forge.open then
        local ok, why = forge.toggle()
        if not ok then return false, why end
    end

    local m = gMarioStates[0]
    if m == nil then return false end

    local x, y, z = forge.cell_cursor(m)
    if x == nil then return false end

    if forge.build_tool == "stretch" then return forge.stretch_press(m, 1) end

    if forge.build_tool ~= "lay" then return forge.paint_press(m) end

    if forge.brush > 1 or forge.sym_on() then
        local placed, wanted, full = forge.lay_all(m)
        if placed == 0 then
            OF.sounds.ui("back", OF.sounds.BACK)
            if full > 0 then return false, "There is already one there." end
            return false, "Nothing was placed."
        end
        forge.publish_reach()
        OF.sounds.ui("select", OF.sounds.PICK)
        if placed < wanted then
            return true, OF.lang.fill("Laid @ of @", tostring(placed), tostring(wanted))
        end
        return true
    end

    local key, yaw = forge.wall_join(forge.build_place_key(), x, y, z, forge.build_yaw())
    local ok, why = lay_block(key, x, y, z, yaw)
    if not ok then
        OF.sounds.ui("back", OF.sounds.BACK)
        if why == "full" then return false, "There is already one there." end
        return false, "Nothing was placed."
    end

    forge.publish_reach()
    OF.sounds.ui("select", OF.sounds.PICK)
    return true
end

function forge.build_take()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local m = gMarioStates[0]
    if m == nil then return false end

    if forge.build_tool == "stretch" then return forge.stretch_press(m, -1) end

    local x, y, z = forge.cell_cursor(m)
    if x == nil then return false end

    local object = forge.cell_here(x, y, z)
    if object == nil then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, "Nothing of ours in that cell."
    end

    if not is_mine(object) then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, "That one is somebody else's."
    end

    local key = nil
    for index = #forge.placed, 1, -1 do
        local entry = forge.placed[index]
        if entry.object == object then
            key = entry.key
            table.remove(forge.placed, index)
        end
    end

    OF.spawner.take_down(object, key)

    if forge.take_twins ~= nil then forge.take_twins(x, y, z) end
    forge.publish_reach()
    OF.sounds.ui("back", OF.sounds.BACK)
    return true
end

do
local CELL_OF = function() return ((OF.spawner or {}).BUILD_CELL) or 200 end

forge.SYM_MODES = { "off", "x", "z", "xz" }
forge.SYM_NAMES = { off = "Off", x = "Left-right", z = "Front-back", xz = "Both ways" }
forge.sym = { mode = "off", x = 0, z = 0, edge = false }

function forge.sym_on()
    return forge.sym.mode ~= "off"
end

function forge.sym_name()
    local name = forge.SYM_NAMES[forge.sym.mode] or "Off"
    if forge.sym_on() and forge.sym.edge then return name .. ", on the edge" end
    return name
end

function forge.sym_set(mode, cx, cz, edge)
    if forge.SYM_NAMES[mode] == nil then return false, "No such symmetry." end
    local half = edge and CELL_OF() * 0.5 or 0
    forge.sym = { mode = mode, x = (cx or 0) + half, z = (cz or 0) + half, edge = edge == true }
    return true
end

function forge.sym_next(m)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    m = m or gMarioStates[0]
    local cx, _, cz = forge.cell_cursor(m)
    if cx == nil then cx, cz = 0, 0 end
    local order = { { "off", false }, { "x", false }, { "z", false }, { "xz", false },
                    { "x", true }, { "z", true }, { "xz", true } }
    local here = 1
    for i, o in ipairs(order) do
        if o[1] == forge.sym.mode and (o[1] == "off" or o[2] == forge.sym.edge) then here = i end
    end
    local nextOne = order[(here % #order) + 1]
    local ok, why = forge.sym_set(nextOne[1], cx, cz, nextOne[2])
    if not ok then return false, why end
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.sym_images(x, z)
    local s = forge.sym
    local out = {}
    if s.mode == "off" then return out end
    local function add(px, pz, acrossX, acrossZ)
        if math.abs(px - x) < 0.5 and math.abs(pz - z) < 0.5 then return end
        for _, o in ipairs(out) do
            if math.abs(o.x - px) < 0.5 and math.abs(o.z - pz) < 0.5 then return end
        end
        table.insert(out, { x = px, z = pz, acrossX = acrossX, acrossZ = acrossZ })
    end
    if s.mode == "x" or s.mode == "xz" then add(2 * s.x - x, z, true, false) end
    if s.mode == "z" or s.mode == "xz" then add(x, 2 * s.z - z, false, true) end
    if s.mode == "xz" then add(2 * s.x - x, 2 * s.z - z, true, true) end
    return out
end

local function upright_of(key)
    local entry = OF.spawner.build_find(key)
    if entry == nil then return nil, false end
    if entry.upright ~= nil then
        return OF.spawner.build_find(entry.upright) or entry, true
    end
    return entry, false
end
forge.upright_of = upright_of

local function guide_set(shape, yaw, flipped, acrossX, acrossZ, ox, oz)
    local guide = forge.shape_guide(shape, ox or 0, 0, oz or 0, yaw, flipped)
    if guide == nil then return nil end
    local set = {}
    for _, seg in ipairs(guide) do
        local ends = {}
        for i = 1, 2 do
            local p = seg[i]
            local px = acrossX and -p.x or p.x
            local pz = acrossZ and -p.z or p.z

            ends[i] = tostring(math.floor(px + 0.5)) .. "," .. tostring(math.floor(p.y + 0.5))
                .. "," .. tostring(math.floor(pz + 0.5))
        end
        if ends[1] > ends[2] then ends[1], ends[2] = ends[2], ends[1] end
        set[ends[1] .. "|" .. ends[2]] = true
    end
    return set
end

local function same_set(a, b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

function forge.mirror_block(key, yaw, acrossX, acrossZ)
    yaw = math.floor(tonumber(yaw) or 0) % 0x10000
    if not acrossX and not acrossZ then return key, yaw, 0, 0 end
    local base, flipped = upright_of(key)
    local shape = base ~= nil and forge.shape_of(base) or "cube"
    local want = guide_set(shape, yaw, flipped, acrossX, acrossZ)
    if want ~= nil then

        local origins = {}
        for _, c in ipairs(forge.span_cells(key, 0, 0, yaw)) do
            table.insert(origins, { x = acrossX and -c.x or c.x, z = acrossZ and -c.z or c.z })
        end
        for _, o in ipairs(origins) do
            for q = 0, 3 do
                local cand = guide_set(shape, q * 0x4000, flipped, false, false, o.x, o.z)
                if cand ~= nil and same_set(cand, want) then return key, q * 0x4000, o.x, o.z end
            end
        end
    end

    if acrossX then yaw = (0x10000 - yaw) % 0x10000 end
    if acrossZ then yaw = (0x8000 - yaw) % 0x10000 end
    return key, OF.spawner.quarter_yaw(yaw), 0, 0
end

forge.BRUSH_MAX = 3
forge.brush = 1

function forge.set_brush(n)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    n = math.floor(tonumber(n) or 1)
    forge.brush = ((n - 1) % forge.BRUSH_MAX) + 1
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.brush_name()
    return OF.lang.fill("@ x @", tostring(forge.brush), tostring(forge.brush))
end

function forge.brush_cells(cx, cy, cz, nx, ny, nz, size)
    size = size or forge.brush
    local cell = CELL_OF()
    nx, ny, nz = math.abs(nx or 0), math.abs(ny or 1), math.abs(nz or 0)
    local ax, bx = { 1, 0, 0 }, { 0, 0, 1 }
    if nx >= ny and nx >= nz then ax, bx = { 0, 1, 0 }, { 0, 0, 1 }
    elseif nz > ny and nz > nx then ax, bx = { 1, 0, 0 }, { 0, 1, 0 } end
    local lo = -math.floor((size - 1) / 2)
    local out = {}
    for i = lo, lo + size - 1 do
        for j = lo, lo + size - 1 do
            table.insert(out, { x = cx + (ax[1] * i + bx[1] * j) * cell,
                                y = cy + (ax[2] * i + bx[2] * j) * cell,
                                z = cz + (ax[3] * i + bx[3] * j) * cell })
        end
    end
    return out
end

forge.BUILD_TOOLS = { "lay", "paint", "surface" }
forge.BUILD_TOOL_NAMES = { lay = "Lay blocks", paint = "Paint (shape kept)",
    surface = "Paint a whole surface" }
forge.build_tool = "lay"
function forge.build_tool_name()
    return forge.BUILD_TOOL_NAMES[forge.build_tool] or "Lay blocks"
end

function forge.build_tool_next()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local here = 1
    for i, t in ipairs(forge.BUILD_TOOLS) do if t == forge.build_tool then here = i end end
    forge.build_tool = forge.BUILD_TOOLS[(here % #forge.BUILD_TOOLS) + 1]
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

forge.WALL_JOINS = { { tag = "wall", arms = { 1, 3 } }, { tag = "wallcorner", arms = { 3, 4 } },
    { tag = "wallt", arms = { 1, 3, 4 } }, { tag = "wallcross", arms = { 1, 2, 3, 4 } } }

function forge.join_mask(x, y, z)
    local S = OF.spawner
    local mask, n = {}, 0
    if not OF.util.asks(S, "block_in") then return mask, n end
    local dx, dz = { 1, 0, -1, 0 }, { 0, 1, 0, -1 }
    local cell = build_cell()
    for k = 1, 4 do
        local o = S.block_in(x + dx[k] * cell, y, z + dz[k] * cell)
        if o ~= nil then
            local byte = math.floor(tonumber(o.oBehParams2ndByte) or 0)
            local back = ((k + 1) % 4) + 1
            if byte == 14 or (S.WALL_ARMS[byte] ~= nil and S.wall_reaches(o, back)) then
                mask[k] = true
                n = n + 1
            end
        end
    end
    return mask, n
end

function forge.wall_join(key, x, y, z, yaw)
    local entry = key ~= nil and OF.spawner.build_find(key) or nil
    if entry == nil or entry.shape ~= "wall" or entry.material == nil then return key, yaw end
    local mask, n = forge.join_mask(x, y, z)
    if n == 0 then return key, yaw end
    for _, j in ipairs(forge.WALL_JOINS) do
        local want = j.tag .. entry.material
        if OF.spawner.build_find(want) ~= nil then
            for q = 0, 3 do
                local got, hits = {}, 0
                for _, a in ipairs(j.arms) do
                    got[OF.spawner.world_side(a, q)] = true
                end
                local same = true
                for k = 1, 4 do
                    if (got[k] == true) ~= (mask[k] == true) then

                        if not (n == 1 and j.tag == "wall" and got[k] and not mask[k]) then
                            same = false
                        end
                    end
                    if got[k] and mask[k] then hits = hits + 1 end
                end
                if same and hits == n then return want, OF.spawner.quarter_yaw(q * 0x4000) end
            end
        end
    end
    return key, yaw
end

forge.BUILD_TOOLS[#forge.BUILD_TOOLS + 1] = "stretch"
forge.BUILD_TOOL_NAMES.stretch = "Stretch (B pulls a face, R+B pushes)"
forge.STRETCH_DELAY = 12
forge.STRETCH_REPEAT = 6
forge.stretchHold = nil

function forge.stretch_of(object)
    if object == nil or not OF.util.asks(OF.spawner, "runtime_word") then return nil end
    local word = OF.spawner.runtime_word(object)
    if word == nil or not OF.stretch.sized(word) then return nil end
    local _, _, w, h, d = OF.stretch.shape_decode(word)
    return { w = w, h = h, d = d }
end

function forge.size_box(x, y, z, yaw, w, h, d)
    local cell = build_cell()
    local q = OF.spawner.quarter_of(yaw or 0)
    local ex, ez = w, d
    if q % 2 == 1 then ex, ez = d, w end
    return { x - ex * cell / 2, x + ex * cell / 2, y, y + h * cell,
             z - ez * cell / 2, z + ez * cell / 2 }
end

function forge.block_box(object)
    local cell = build_cell()
    local size = forge.stretch_of(object)
    if size ~= nil then
        return forge.size_box(object.oPosX, object.oPosY, object.oPosZ, object.oFaceAngleYaw,
            size.w, size.h, size.d)
    end
    local x0, x1 = object.oPosX - cell / 2, object.oPosX + cell / 2
    local z0, z1 = object.oPosZ - cell / 2, object.oPosZ + cell / 2
    local span = OF.util.asks(OF.spawner, "span_of") and OF.spawner.span_of(object) or 1
    if span > 1 then
        local dx, dz = forge.span_step(object.oFaceAngleYaw)
        local ex, ez = object.oPosX + dx * (span - 1) * cell, object.oPosZ + dz * (span - 1) * cell
        x0, x1 = math.min(x0, ex - cell / 2), math.max(x1, ex + cell / 2)
        z0, z1 = math.min(z0, ez - cell / 2), math.max(z1, ez + cell / 2)
    end
    return { x0, x1, object.oPosY, object.oPosY + cell, z0, z1 }
end

function forge.box_free(box, except)
    local bhv = (OF.spawner or {}).BLOCK
    if bhv == nil or box == nil or OF.util.binding("obj_get_first_with_behavior_id") == nil then
        return true
    end
    local o = obj_get_first_with_behavior_id(bhv)
    while o ~= nil do
        if o ~= except and o.activeFlags ~= 0 then
            local b = forge.block_box(o)
            if b[1] < box[2] - 1 and b[2] > box[1] + 1 and b[3] < box[4] - 1 and b[4] > box[3] + 1
                and b[5] < box[6] - 1 and b[6] > box[5] + 1 then
                return false
            end
        end
        o = obj_get_next_with_same_behavior_id(o)
    end
    return true
end

function forge.stretch_face(m)
    m = m or gMarioStates[0]
    local x, y, z, nx, ny, nz = forge.aimed_block(m)
    if x == nil then return nil end
    local object = forge.cell_here(x, y, z)
    if object == nil then return nil end
    local aim = forge.mouseAim
    local pointer = aim ~= nil and aim.hx ~= nil and m == gMarioStates[0]
    if not pointer and m ~= nil and m.pos ~= nil then
        local cx, cy, cz = forge.cell_cursor(m)
        if cx ~= nil and forge.cell_here(cx, cy, cz) == object then
            local dx, dz = m.pos.x - object.oPosX, m.pos.z - object.oPosZ
            if math.abs(dx) >= math.abs(dz) then
                nx, ny, nz = dx >= 0 and 1 or -1, 0, 0
            else
                nx, ny, nz = 0, 0, dz >= 0 and 1 or -1
            end
        end
    end
    return object, nx or 0, ny or 1, nz or 0
end

function forge.stretch_step(object, nx, ny, nz, dir, merge)
    if object == nil or object.activeFlags == 0 then return false, "Aim at a block's face to stretch it." end
    if not is_mine(object) then return false, "That one is somebody else's." end
    local key = forge.block_key(object)
    local entry = key ~= nil and OF.spawner.build_find(key) or nil
    local byte, slug = OF.spawner.block_parts(entry)
    if byte == nil then return false, "Only blocks stretch." end
    if entry.span ~= nil then return false, "A long piece has its own length." end
    if slug == OF.spawner.WATER_MATERIAL then return false, "A water block is one cell." end
    local ST = OF.stretch
    local size = forge.stretch_of(object) or { w = 1, h = 1, d = 1 }
    local q = OF.spawner.quarter_of(object.oFaceAngleYaw or 0)
    local c = ({ 1, 0, -1, 0 })[q + 1]
    local s = ({ 0, 1, 0, -1 })[q + 1]
    local axis, sign
    if math.abs(ny) > 0.5 then
        axis, sign = "h", ny > 0 and 1 or -1
    else

        local alongX, alongZ = nx * c - nz * s, nx * s + nz * c
        if math.abs(alongX) >= math.abs(alongZ) then
            axis, sign = "w", alongX > 0 and 1 or -1
        else
            axis, sign = "d", alongZ > 0 and 1 or -1
        end
    end
    local most = { w = ST.MAX_W, h = ST.MAX_H, d = ST.MAX_D }
    local want = size[axis] + dir
    if want < 1 then return false, "It is one cell that way already." end
    if want > most[axis] then
        return false, OF.lang.fill("@ cells is the most that way", tostring(most[axis]))
    end
    local cell = build_cell()
    local x, y, z = object.oPosX, object.oPosY, object.oPosZ
    if axis == "h" then
        if sign < 0 then y = y - dir * cell end
    else

        local wx = nx > 0.5 and 1 or (nx < -0.5 and -1 or 0)
        local wz = nz > 0.5 and 1 or (nz < -0.5 and -1 or 0)
        x, z = x + wx * dir * cell / 2, z + wz * dir * cell / 2
    end
    local new = { w = size.w, h = size.h, d = size.d }
    new[axis] = want
    if dir > 0 and not forge.box_free(forge.size_box(x, y, z, object.oFaceAngleYaw,
        new.w, new.h, new.d), object) then
        return false, "Another block is in the way."
    end

    local extra = new
    if new.w == 1 and new.h == 1 and new.d == 1 then extra = false end
    local made, _, objects, batch = forge.swap_blocks({ { object = object, key = key, x = x,
        y = y, z = z, extra = extra } }, merge)
    local fresh = objects ~= nil and objects[1] or nil
    if made == 0 or not fresh then return false, "Nothing was stretched." end
    return true, new.w .. " x " .. new.h .. " x " .. new.d,
        fresh, batch
end

function forge.stretch_press(m, dir)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local object, nx, ny, nz = forge.stretch_face(m)
    if object == nil then return false, "Aim at a block's face to stretch it." end
    local ok, said, fresh, batch = forge.stretch_step(object, nx, ny, nz, dir, nil)
    forge.stretchHold = nil
    if ok then
        forge.stretchHold = { object = fresh, nx = nx, ny = ny, nz = nz, dir = dir,
            frames = 0, batch = batch }
        OF.notify.show("Stretched to @", "info", 2, said)
        return true
    end
    OF.sounds.ui("back", OF.sounds.BACK)
    return false, said
end

function forge.stretch_hold(m, input)
    local hold = forge.stretchHold
    if hold == nil then return false end
    if input == nil or not input.held(B_BUTTON) or forge.build_tool ~= "stretch" then
        forge.stretchHold = nil
        return false
    end
    hold.frames = hold.frames + 1
    if hold.frames < forge.STRETCH_DELAY
        or (hold.frames - forge.STRETCH_DELAY) % forge.STRETCH_REPEAT ~= 0 then
        return false
    end
    local ok, said, fresh, batch = forge.stretch_step(hold.object, hold.nx, hold.ny, hold.nz,
        hold.dir, hold.batch)
    if not ok then
        forge.stretchHold = nil
        return false
    end
    hold.object, hold.batch = fresh, batch
    OF.notify.show("Stretched to @", "info", 2, said)
    return true
end

local modelKeys = { list = nil, count = -1, map = {} }
function forge.block_key(object)
    if object == nil then return nil end
    for _, entry in ipairs(forge.placed) do
        if entry.object == object then return entry.key end
    end
    local list = (OF.spawner or {}).BUILD_LIST or {}
    if modelKeys.list ~= list or modelKeys.count ~= #list then
        modelKeys.list, modelKeys.count, modelKeys.map = list, #list, {}
        for _, e in ipairs(list) do modelKeys.map[e.model] = e.key end
        for k, e in pairs((OF.spawner or {}).BUILD_TWINS or {}) do modelKeys.map[e.model] = k end
    end

    local runtime = OF.util.asks(OF.spawner, "runtime_key") and OF.spawner.runtime_key(object) or nil
    if runtime ~= nil then return runtime end
    local model = OF.util.optional("obj_get_model_id_extended", nil, object)
    return model ~= nil and modelKeys.map[model] or nil
end

function forge.aimed_block(m)
    m = m or gMarioStates[0]
    local aim = forge.mouseAim
    if aim ~= nil and aim.hx ~= nil and m == gMarioStates[0] then
        return aim.hx, aim.hy, aim.hz, aim.nx, aim.ny, aim.nz
    end
    local x, y, z = forge.cell_cursor(m)
    if x == nil then return nil end
    if forge.cell_here(x, y, z) ~= nil then return x, y, z, 0, 1, 0 end
    if forge.cell_here(x, y - CELL_OF(), z) ~= nil then return x, y - CELL_OF(), z, 0, 1, 0 end
    return nil
end

function forge.pick_block(m)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    m = m or gMarioStates[0]
    local x, y, z = forge.aimed_block(m)
    local object = x ~= nil and forge.cell_here(x, y, z) or nil
    if object == nil then return false, "Aim at a block to pick it." end
    local key = forge.block_key(object)
    local base, flipped = upright_of(key)
    if base == nil then return false, "The forge has no block like that." end
    local index = nil
    for i, e in ipairs(OF.spawner.BUILD_LIST) do
        if e.key == base.key then index = i end
    end
    if index == nil then return false, "The forge has no block like that." end
    forge.build_pick = index
    forge.prefabPick = nil
    forge.build_flip = flipped
    local yaw = OF.spawner.quarter_yaw(object.oFaceAngleYaw or 0)
    if base.slope ~= nil then
        yaw = (yaw - forge.view_yaw(m) - 0x8000) % 0x10000
    end
    forge.build_turn = math.floor(OF.spawner.quarter_yaw(yaw) / 0x4000 + 0.5) % 4
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true, base.name
end

function forge.swap_blocks(list, merge)
    local recipe, theirs, wanted = {}, 0, {}
    for _, row in ipairs(list) do
        local object = row.object
        if object ~= nil and object.activeFlags ~= 0 and is_mine(object) then
            local oldKey = forge.block_key(object)
            local was = forge.mover_row({
                key = oldKey, x = object.oPosX, y = object.oPosY, z = object.oPosZ,
                yaw = object.oFaceAngleYaw or 0, pitch = object.oFaceAnglePitch or 0,
                size = NORMAL_SIZE }, object)
            table.insert(recipe, was)
            local extra = row.extra
            if extra == nil then extra = was.stretch end
            if extra == false then extra = nil end
            table.insert(wanted, { key = row.key, x = row.x or object.oPosX,
                y = row.y or object.oPosY, z = row.z or object.oPosZ,
                yaw = row.yaw or object.oFaceAngleYaw or 0, old = oldKey, extra = extra,
                was = was })
            for index = #forge.placed, 1, -1 do
                if forge.placed[index].object == object then table.remove(forge.placed, index) end
            end
            OF.spawner.take_down(object, oldKey)
        elseif object ~= nil then
            theirs = theirs + 1
        end
    end
    if #wanted == 0 then return 0, theirs end
    replaying = true
    local batch = begin_batch()
    local made, objects = 0, {}
    for _, w in ipairs(wanted) do
        local object = OF.spawner.spawn_at(w.key, w.x, w.y, w.z, w.yaw, w.extra)
        if object == nil and w.old ~= nil then

            object = forge.spawn_row(w.was, w.was.x, w.was.y, w.was.z, w.was.yaw, 0)
            if object ~= nil then
                table.insert(forge.placed, { object = object, key = w.old,
                    size = NORMAL_SIZE, batch = batch })
            end
        elseif object ~= nil then
            table.insert(forge.placed, { object = object, key = w.key,
                size = NORMAL_SIZE, batch = batch })
            made = made + 1
        end
        table.insert(objects, object or false)
    end
    end_batch()
    replaying = false
    if not forge.merge_swap(merge, batch) then forge.remember_swap(recipe, batch) end
    forget_redo()
    forge.publish_reach()
    OF.sounds.ui("select", OF.sounds.PICK)
    return made, theirs, objects, batch
end

local function repainted(key, material)
    local base, flipped = upright_of(key)
    if base == nil then return nil end
    local index = forge.build_index(material, forge.shape_of(base))
    local entry = index ~= nil and OF.spawner.BUILD_LIST[index] or nil
    if entry == nil then return nil end
    if flipped then return entry.flipped end
    return entry.key
end

function forge.reshape_block(m, step)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    m = m or gMarioStates[0]
    local x, y, z = forge.aimed_block(m)
    local object = x ~= nil and forge.cell_here(x, y, z) or nil
    if object == nil then return false, "Aim at a block to reshape it." end
    if not is_mine(object) then return false, "That one is somebody else's." end
    local base, flipped = upright_of(forge.block_key(object))
    if base == nil then return false, "The forge has no block like that." end
    local material, shape = forge.material_of(base), forge.shape_of(base)
    local f, v = forge.shape_family(shape)
    if f == nil then return false, "This block has no other shape." end
    local shapes = forge.SHAPE_FAMILIES[f].shapes
    step = (tonumber(step) or 1) >= 0 and 1 or -1
    for k = 1, #shapes - 1 do
        local want = shapes[((v - 1 + k * step) % #shapes) + 1]
        local index = forge.build_index(material, want)
        local entry = index ~= nil and OF.spawner.BUILD_LIST[index] or nil
        local key = entry ~= nil and ((flipped and entry.flipped) or (not flipped and entry.key))
            or nil
        if key then
            forge.swap_blocks({ { object = object, key = key } })
            return true, forge.shape_name(want)
        end
    end
    return false, OF.lang.fill("Only one shape of @ in this texture",
        string.lower(OF.lang.t(forge.SHAPE_FAMILIES[f].name)))
end

forge.SURFACE_MAX = 64
local function paint_targets(m)
    local x, y, z, nx, ny, nz = forge.aimed_block(m)
    if x == nil then return nil end
    local cell = CELL_OF()
    if forge.build_tool ~= "surface" then
        return forge.brush_cells(x, y, z, nx, ny, nz), nx, ny, nz
    end
    local first = forge.cell_here(x, y, z)
    local base = first ~= nil and upright_of(forge.block_key(first)) or nil
    local material = base ~= nil and forge.material_of(base) or nil
    if material == nil then return {}, nx, ny, nz end
    local plane = forge.brush_cells(0, 0, 0, nx, ny, nz, 3)
    local steps = {}
    for _, p in ipairs(plane) do
        if (p.x ~= 0 and p.y == 0 and p.z == 0) or (p.x == 0 and p.y ~= 0 and p.z == 0)
            or (p.x == 0 and p.y == 0 and p.z ~= 0) then
            table.insert(steps, p)
        end
    end
    local seen, out, queue = {}, {}, { { x = x, y = y, z = z } }
    local fx, fy, fz = math.floor((nx or 0) + 0.5), math.floor((ny or 0) + 0.5),
        math.floor((nz or 0) + 0.5)
    while #queue > 0 and #out < forge.SURFACE_MAX do
        local c = table.remove(queue, 1)
        local id = forge.cell_of(c.x) .. ":" .. forge.cell_of(c.y) .. ":" .. forge.cell_of(c.z)
        if not seen[id] then
            seen[id] = true
            local o = forge.cell_here(c.x, c.y, c.z)
            local b = o ~= nil and upright_of(forge.block_key(o)) or nil

            if b ~= nil and forge.material_of(b) == material
                and forge.cell_here(c.x + fx * cell, c.y + fy * cell, c.z + fz * cell) == nil then
                table.insert(out, c)
                for _, s in ipairs(steps) do
                    table.insert(queue, { x = c.x + s.x, y = c.y + s.y, z = c.z + s.z })
                end
            end
        end
    end
    return out, nx, ny, nz
end

function forge.paint_press(m)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    m = m or gMarioStates[0]
    local material = forge.build_material()
    if material == nil then return false, "This build has no blocks to build with." end
    local cells = paint_targets(m)
    if cells == nil then return false, "Aim at a block to paint it." end
    local list, seen, missing = {}, {}, 0
    local function want(x, y, z)
        local o = forge.cell_here(x, y, z)
        if o == nil or seen[o] then return end
        seen[o] = true
        local key = forge.block_key(o)
        local new = key ~= nil and repainted(key, material) or nil
        if new == nil then missing = missing + 1 return end
        if new ~= key then table.insert(list, { object = o, key = new }) end
    end
    for _, c in ipairs(cells) do
        want(c.x, c.y, c.z)
        for _, img in ipairs(forge.sym_images(c.x, c.z)) do want(img.x, c.y, img.z) end
    end
    if #list == 0 then
        OF.sounds.ui("back", OF.sounds.BACK)
        if missing > 0 then
            return false, "This texture does not come in that shape."
        end
        return false, "Nothing to paint there."
    end
    local made, theirs = forge.swap_blocks(list)
    if made == 0 then return false, "Those are somebody else's." end
    if theirs > 0 then
        return true, OF.lang.fill("Painted @ - @ were somebody else's", tostring(made),
            tostring(theirs))
    end
    return true
end

function forge.lay_all(m)
    local x, y, z = forge.cell_cursor(m)
    if x == nil then return 0, 0, 0 end
    local aim = forge.mouseAim
    local nx, ny, nz = 0, 1, 0
    if aim ~= nil and m == gMarioStates[0] then nx, ny, nz = aim.nx, aim.ny, aim.nz end
    local key, yaw = forge.build_place_key(), forge.build_yaw()
    local placed, wanted, full = 0, 0, 0
    begin_batch()
    for _, c in ipairs(forge.brush_cells(x, y, z, nx, ny, nz)) do
        local spots = { { x = c.x, z = c.z, key = key, yaw = yaw } }
        for _, img in ipairs(forge.sym_images(c.x, c.z)) do
            local k, w, sx, sz = forge.mirror_block(key, yaw, img.acrossX, img.acrossZ)
            table.insert(spots, { x = img.x + sx, z = img.z + sz, key = k, yaw = w })
        end
        for _, s in ipairs(spots) do
            wanted = wanted + 1
            local ok, said = lay_block(s.key, s.x, c.y, s.z, s.yaw)
            if ok then placed = placed + 1 elseif said == "full" then full = full + 1 end
        end
    end
    end_batch()
    return placed, wanted, full
end

forge.FILL_MAX = 1000

function forge.box_cells(hollow)
    local box = forge.selection()
    if box == nil then return nil, 0 end
    local x0, x1 = forge.cell_of(box.minX), forge.cell_of(box.maxX)
    local y0, y1 = forge.cell_of(box.minY), forge.cell_of(box.maxY)
    local z0, z1 = forge.cell_of(box.minZ), forge.cell_of(box.maxZ)
    local count = (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1)
    if count > forge.FILL_MAX then return nil, count end
    local out = {}
    for y = y0, y1 do
        for z = z0, z1 do
            for x = x0, x1 do
                local face = x == x0 or x == x1 or y == y0 or y == y1 or z == z0 or z == z1
                if not hollow or face then
                    out[#out + 1] = { x = forge.cell_at(x), y = forge.cell_at(y),
                        z = forge.cell_at(z), i = x, j = y, k = z }
                end
            end
        end
    end
    return out, count, { x0 = x0, x1 = x1, z0 = z0, z1 = z1 }
end

function forge.box_fill(hollow)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if forge.marks() < 2 then return false, "Mark a box first - B marks two corners." end
    local key = forge.build_place_key()
    if key == nil then return false, "Choose a block first." end
    local cells, count, edge = forge.box_cells(hollow)
    if cells == nil then
        return false, OF.lang.fill("That box is @ cells - @ at most in one fill",
            tostring(count), tostring(forge.FILL_MAX))
    end
    local yaw = forge.build_yaw()

    local todo, claimed = {}, {}
    for _, c in ipairs(cells) do
        local run = forge.span_cells(key, c.x, c.z, yaw)
        local fits = true
        for _, r in ipairs(run) do
            local ri, rk = forge.cell_of(r.x), forge.cell_of(r.z)
            local id = ri .. "," .. c.j .. "," .. rk
            if ri < edge.x0 or ri > edge.x1 or rk < edge.z0 or rk > edge.z1
                or claimed[id] or forge.cell_here(r.x, c.y, r.z) ~= nil then
                fits = false
                break
            end
        end
        if fits then
            for _, r in ipairs(run) do
                claimed[forge.cell_of(r.x) .. "," .. c.j .. "," .. forge.cell_of(r.z)] = true
            end
            todo[#todo + 1] = c
        end
    end
    if #todo == 0 then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, "The box is full already."
    end
    local room = OF.util.asks(OF.spawner, "fair_share") and OF.spawner.fair_share(#todo) or #todo
    if room < #todo then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, OF.lang.fill("That needs @ blocks - there is room for @",
            tostring(#todo), tostring(room))
    end
    local placed = 0
    begin_batch()
    for _, c in ipairs(todo) do
        if lay_block(key, c.x, c.y, c.z, yaw) then placed = placed + 1 end
    end
    end_batch()
    if placed == 0 then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, "Nothing was placed."
    end
    forge.publish_reach()
    OF.sounds.ui("select", OF.sounds.PICK)
    if placed < #todo then
        return true, OF.lang.fill("Laid @ of @", tostring(placed), tostring(#todo))
    end
    return true, OF.lang.fill("Filled the box - @ blocks", tostring(placed))
end

function forge.take_twins(x, y, z)
    local taken = 0
    for _, img in ipairs(forge.sym_images(x, z)) do
        local o = forge.cell_here(img.x, y, img.z)
        if o ~= nil and is_mine(o) then
            local key = nil
            for index = #forge.placed, 1, -1 do
                if forge.placed[index].object == o then
                    key = forge.placed[index].key
                    table.remove(forge.placed, index)
                end
            end
            OF.spawner.take_down(o, key)
            taken = taken + 1
        end
    end
    return taken
end

forge.REACH_EDGES = { walk = 24, jump = 362, double = 504, triple = 656, drop_safe = 1100 }
forge.REACH_CLASS_ORDER = { "walk", "drop", "jump", "double", "triple", "hurts", "kick", "out" }
forge.REACH_WORDS = { walk = "walk on", drop = "a safe drop", jump = "one jump",
    double = "a double jump", triple = "a triple jump or a ledge grab",
    hurts = "a drop that hurts", kick = "wall kicks only", out = "out of reach" }
forge.REACH_COLOURS = {
    walk = { 92, 214, 120 }, drop = { 140, 204, 242 }, jump = { 204, 230, 89 },
    double = { 250, 204, 64 }, triple = { 250, 148, 51 }, hurts = { 242, 115, 166 },
    kick = { 191, 128, 242 }, out = { 235, 77, 77 },
}

forge.SHAPE_TOPS = { slab = 100, plate = 20, slab2 = 100, slab4 = 100, plate2 = 20, plate4 = 20 }

function forge.walk_class(rise, wallNear)
    local e = forge.REACH_EDGES
    rise = tonumber(rise) or 0
    if rise < 0 then
        if -rise > e.drop_safe then return "hurts" end
        if -rise <= e.walk then return "walk" end
        return "drop"
    end
    if rise <= e.walk then return "walk" end
    if rise <= e.jump then return "jump" end
    if rise <= e.double then return "double" end
    if rise <= e.triple then return "triple" end
    return wallNear and "kick" or "out"
end

function forge.cell_walk(m, cx, cy, cz)
    m = m or gMarioStates[0]
    if m == nil or m.pos == nil or cx == nil then return nil end
    local entry = build_entry(forge.build_pick)
    local shape = forge.shape_of(entry)
    local top = forge.SHAPE_TOPS[shape or ""] or CELL_OF()
    if forge.build_flip then top = CELL_OF() end
    local rise = cy + top - m.pos.y
    local wallNear = false
    if rise > forge.REACH_EDGES.triple then
        local cell = CELL_OF()
        for _, d in ipairs({ { cell, 0 }, { -cell, 0 }, { 0, cell }, { 0, -cell } }) do
            if forge.cell_here(cx + d[1], cy + cell, cz + d[2]) ~= nil then wallNear = true end
        end
    end
    return forge.walk_class(rise, wallNear), rise
end
end

do
forge.prefabPick = nil
local DRAFT_KEY = "prefab_draft"
local DRAFT_PART = 900
local DRAFT_PARTS = 16

function forge.prefab_list()
    return (OF.spawner or {}).PREFABS or {}
end

function forge.prefab_picked()
    if forge.prefabPick == nil then return nil end
    return forge.prefab_list()[forge.prefabPick]
end

function forge.prefab_cells(prefab, cx, cy, cz, turn)
    local out = {}
    if prefab == nil then return out end
    local cell = build_cell()
    for _, piece in ipairs(prefab.pieces or {}) do

        local size = type(piece[8]) == "table" and piece[8] or nil
        local sx, sy, sz = 1, 1, 1
        if size ~= nil then sx, sy, sz = size[1] or 1, size[2] or 1, size[3] or 1 end
        local x, z = piece[1] + (sx - 1) / 2, piece[3] + (sz - 1) / 2
        for _ = 1, (turn or 0) % 4 do x, z = z, -x end
        local key
        if piece[4] == "cube" then
            key = "blk" .. piece[5]
        else
            key = (piece[7] and "u" or "") .. piece[4] .. piece[5]
        end
        local extra = nil
        if sx * sy * sz > 1 then
            local w, d = sx, sz
            if (piece[6] or 0) % 2 == 1 then w, d = sz, sx end
            extra = { w = w, h = sy, d = d }
        end
        table.insert(out, { x = cx + x * cell, y = cy + piece[2] * cell, z = cz + z * cell,
            key = key, yaw = ((piece[6] + (turn or 0)) % 4) * 0x4000, extra = extra })
    end
    return out
end

function forge.prefab_movers(prefab, cx, cy, cz, turn)
    local out = {}
    if prefab == nil then return out end
    local cell = build_cell()
    for _, row in ipairs(prefab.movers or {}) do
        local x, z = row[1], row[3]
        for _ = 1, (turn or 0) % 4 do x, z = z, -x end
        local shape, slug = row[4], row[5]
        local key
        if shape == "log" or shape == "logwide" then key = "mv" .. shape
        elseif shape == "cube" then key = "mvblk" .. slug
        else key = "mv" .. shape .. slug end
        local points = {}
        for _, p in ipairs(row[10] or {}) do
            local px, pz = p[1], p[3]
            for _ = 1, (turn or 0) % 4 do px, pz = pz, -px end
            table.insert(points, { x = px, y = p[2], z = pz, speed = p[4], wait = p[5] })
        end
        table.insert(out, { key = key, x = cx + x * cell, y = cy + row[2] * cell,
            z = cz + z * cell, yaw = (((row[6] or 0) + (turn or 0)) % 4) * 0x4000,
            spec = { mode = row[7], trigger = row[8], phase = row[9], points = points,
                     link = tonumber(row[11]) or 0 } })
    end
    return out
end

forge.PREFAB_LOGIC_KEYS = { target = "lgtarget", button = "lgbutton", zone = "lgzone" }
function forge.prefab_logic(prefab, cx, cy, cz, turn)
    local out = {}
    if prefab == nil or prefab.logic == nil then return out end
    local cell = build_cell()
    for _, row in ipairs(prefab.logic) do
        local key = forge.PREFAB_LOGIC_KEYS[row[4]]
        if key ~= nil then
            local x, z = row[1], row[3]
            for _ = 1, (turn or 0) % 4 do x, z = z, -x end
            table.insert(out, { key = key, x = cx + x * cell, y = cy + row[2] * cell,
                z = cz + z * cell, yaw = (((row[5] or 0) + (turn or 0)) % 4) * 0x4000,
                link = tonumber(row[6]) or 1 })
        end
    end
    return out
end

function forge.prefab_numbers(prefab)
    local olds = {}
    for _, row in ipairs(prefab ~= nil and prefab.movers or {}) do
        if row[8] == "wired" and (tonumber(row[11]) or 0) > 0 then table.insert(olds, row[11]) end
    end
    for _, row in ipairs(prefab ~= nil and prefab.logic or {}) do table.insert(olds, row[6]) end
    if #olds == 0 then return {} end
    if not OF.util.asks(OF.logic, "renumber") then return nil end
    return OF.logic.renumber(olds)
end

function forge.prefab_pipes(prefab, cx, cy, cz, turn)
    local out = {}
    if prefab == nil or prefab.pipes == nil then return out end
    local cell = build_cell()
    local fresh, used = {}, {}
    local function tag_for(t)
        t = tonumber(t) or 0
        if t == 0 then return 0 end
        if fresh[t] == nil then
            local n = forge.pipe_new_tag()
            while used[n] do n = n % 0x7FFF + 1 end
            used[n] = true
            fresh[t] = n
        end
        return fresh[t]
    end
    for _, row in ipairs(prefab.pipes) do
        local x, z = row[1], row[3]
        for _ = 1, (turn or 0) % 4 do x, z = z, -x end
        local kind = tonumber(row[5]) or 0
        local level = kind == forge.PIPE_LEVEL and forge.keep_level_of_id(tostring(row[6])) or 0
        if kind == forge.PIPE_LEVEL and level == nil then kind, level = forge.PIPE_NONE, 0 end
        table.insert(out, { x = cx + x * cell, y = cy + row[2] * cell, z = cz + z * cell,
            yaw = (((row[4] or 0) + (turn or 0)) % 4) * 0x4000,
            pipe = { kind = kind, level = level, area = tonumber(row[7]) or 1,
                tag = tag_for(row[8]), pair = tag_for(row[9]) } })
    end
    return out
end

function forge.prefab_choose(index)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if forge.prefab_list()[index] == nil then return false, "No such prefab." end
    forge.prefabPick = index
    local opened, notOpened = forge.ensure_open()
    if not opened then return false, notOpened end
    if not forge.build_on then
        local ok, why = forge.build_toggle()
        if not ok then return false, why end
    end
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.prefab_place()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local prefab = forge.prefab_picked()
    if prefab == nil then return false, "No prefab picked." end
    local m = gMarioStates[0]
    if m == nil then return false end
    local cx, cy, cz = forge.cell_cursor(m)
    if cx == nil then return false end
    local cells = forge.prefab_cells(prefab, cx, cy, cz, forge.build_turn)
    local missing = 0
    for _, c in ipairs(cells) do
        if OF.spawner.build_find(c.key) == nil then missing = missing + 1 end
    end
    if missing > 0 then
        return false, OF.lang.fill("@ of its blocks are not in this copy of the mod",
            tostring(missing))
    end

    local room = OF.util.asks(OF.spawner, "fair_share")
        and OF.spawner.fair_share(#cells) or #cells
    if room < #cells then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, OF.lang.fill("It needs @ blocks; only @ are free", tostring(#cells),
            tostring(room))
    end

    local numbers = forge.prefab_numbers(prefab)
    if numbers == nil then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, "Every number in this level is taken."
    end
    local placed, full = 0, 0
    begin_batch()
    for _, c in ipairs(cells) do
        local ok, said = lay_block(c.key, c.x, c.y, c.z, OF.spawner.quarter_yaw(c.yaw), c.extra)
        if ok then placed = placed + 1
        elseif said == "full" then full = full + 1 end
    end

    for _, mv in ipairs(forge.prefab_movers(prefab, cx, cy, cz, forge.build_turn)) do
        if mv.spec.trigger == "wired" then mv.spec.link = numbers[mv.spec.link] or 0 end
        local o = OF.spawner.spawn_mover(mv.key, mv.x, mv.y, mv.z, mv.yaw, mv.spec)
        if o ~= nil then
            forget_redo()
            table.insert(forge.placed, { object = o, key = mv.key, size = NORMAL_SIZE,
                batch = next_batch() })
            placed = placed + 1
        end
    end

    local wasLink = OF.logic ~= nil and OF.logic.forgeLink or nil
    for _, lg in ipairs(forge.prefab_logic(prefab, cx, cy, cz, forge.build_turn)) do
        if OF.logic ~= nil then OF.logic.forgeLink = numbers[lg.link] or lg.link end
        local o = OF.spawner.spawn_at(lg.key, lg.x, lg.y, lg.z, lg.yaw)
        if o ~= nil then
            forget_redo()
            table.insert(forge.placed, { object = o, key = lg.key, size = NORMAL_SIZE,
                batch = next_batch() })
            placed = placed + 1
        end
    end
    if OF.logic ~= nil and wasLink ~= nil then OF.logic.forgeLink = wasLink end

    local wires = {}
    for _, row in ipairs(prefab.wires or {}) do
        local w = OF.util.asks(OF.logic, "wire_mapped") and OF.logic.wire_mapped(row, numbers) or nil
        if w ~= nil then table.insert(wires, w) end
    end
    if #wires > 0 and OF.util.asks(OF.logic, "ask_wires") then
        OF.util.report(OF.logic.ask_wires("add", OF.logic.encode(wires)))
    end

    for _, pp in ipairs(forge.prefab_pipes(prefab, cx, cy, cz, forge.build_turn)) do
        local o = forge.pipe_spawn("warppipe", pp.x, pp.y, pp.z, pp.yaw, pp.pipe)
        if o ~= nil then
            forget_redo()
            table.insert(forge.placed, { object = o, key = "warppipe", size = NORMAL_SIZE,
                batch = next_batch() })
            placed = placed + 1
        end
    end
    end_batch()
    forge.publish_reach()
    if placed == 0 then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, full > 0 and "Those cells all have blocks in them." or "Nothing was placed."
    end
    OF.sounds.ui("select", OF.sounds.PICK)
    if full > 0 then
        return true, OF.lang.fill("Laid @; @ cells were already full", tostring(placed),
            tostring(full))
    end
    return true
end

function forge.prefab_guide(m)
    local prefab = forge.prefab_picked()
    if prefab == nil then return nil end
    local cx, cy, cz = forge.cell_cursor(m)
    if cx == nil then return nil end
    local cells = forge.prefab_cells(prefab, cx, cy, cz, forge.build_turn)
    if #cells == 0 then return nil end
    local half = build_cell() / 2
    local x0, x1, y0, y1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
    for _, c in ipairs(cells) do
        local e = c.extra or { w = 1, h = 1, d = 1 }
        local b = forge.size_box(c.x, c.y, c.z, c.yaw, e.w, e.h, e.d)
        x0, x1 = math.min(x0, b[1]), math.max(x1, b[2])
        z0, z1 = math.min(z0, b[5]), math.max(z1, b[6])
        y0, y1 = math.min(y0, b[3]), math.max(y1, b[4])
    end
    local function p(x, y, z) return { x = x, y = y, z = z } end
    local out = {}
    for _, y in ipairs({ y0, y1 }) do
        table.insert(out, { p(x0, y, z0), p(x1, y, z0) })
        table.insert(out, { p(x1, y, z0), p(x1, y, z1) })
        table.insert(out, { p(x1, y, z1), p(x0, y, z1) })
        table.insert(out, { p(x0, y, z1), p(x0, y, z0) })
    end
    for _, x in ipairs({ x0, x1 }) do
        for _, z in ipairs({ z0, z1 }) do table.insert(out, { p(x, y0, z), p(x, y1, z) }) end
    end
    return out
end

function forge.prefab_draft()
    local box = forge.selection()
    if box == nil then return nil, "Mark a box round the blocks first." end
    local found = {}
    local lo = { math.huge, math.huge, math.huge }
    for _, placed in ipairs(forge.placed) do
        local o = placed.object
        local entry = placed.key ~= nil and OF.spawner.build_find(placed.key) or nil
        if o ~= nil and o.activeFlags ~= 0 and entry ~= nil
            and o.oPosX >= box.minX and o.oPosX <= box.maxX
            and o.oPosY >= box.minY and o.oPosY <= box.maxY
            and o.oPosZ >= box.minZ and o.oPosZ <= box.maxZ then
            local shape, flip = forge.shape_of(entry), 0
            if entry.upright ~= nil then
                shape = shape:gsub("^u", "")
                flip = 1
            end
            local material = forge.material_of(entry)
            if entry.upright ~= nil then material = placed.key:sub(#entry.slope + 1) end
            local turn = math.floor((tonumber(o.oFaceAngleYaw) or 0) / 0x4000 + 0.5) % 4
            local c = { shape, material, forge.cell_of(o.oPosX), forge.cell_of(o.oPosY),
                forge.cell_of(o.oPosZ), turn, flip }

            local size = forge.stretch_of(o)
            if size ~= nil then
                local ex, ez = size.w, size.d
                if turn % 2 == 1 then ex, ez = size.d, size.w end
                local cell = build_cell()
                c[3] = forge.cell_of(o.oPosX - (ex - 1) * cell / 2)
                c[5] = forge.cell_of(o.oPosZ - (ez - 1) * cell / 2)
                c[8] = ex .. "x" .. size.h .. "x" .. ez
            end
            for k = 1, 3 do lo[k] = math.min(lo[k], c[k + 2]) end
            table.insert(found, c)
        end
    end
    local links = {}

    local movs = {}
    for _, placed in ipairs(forge.placed) do
        local o = placed.object
        local entry = placed.key ~= nil and OF.spawner.mover_find(placed.key) or nil
        local spec = (o ~= nil and o.activeFlags ~= 0 and entry ~= nil)
            and OF.spawner.mover_read(o) or nil
        if spec ~= nil and o.oHomeX >= box.minX and o.oHomeX <= box.maxX
            and o.oHomeY >= box.minY and o.oHomeY <= box.maxY
            and o.oHomeZ >= box.minZ and o.oHomeZ <= box.maxZ then
            local shape, slug
            if entry.log then shape, slug = placed.key:sub(3), "-"
            else
                local block = OF.spawner.build_find(entry.block)
                shape = block ~= nil and forge.shape_of(block) or "cube"
                slug = entry.material or "-"
            end
            local pts = {}
            for _, p in ipairs(spec.points) do
                table.insert(pts, table.concat({ p.x, p.y, p.z, p.speed, p.wait }, ":"))
            end
            local c = { forge.cell_of(o.oHomeX), forge.cell_of(o.oHomeY), forge.cell_of(o.oHomeZ) }
            for k = 1, 3 do lo[k] = math.min(lo[k], c[k]) end

            if spec.trigger == "wired" and (spec.link or 0) > 0 then links[spec.link] = true end
            table.insert(movs, { shape = shape, slug = slug, c = c, spec = spec,
                pts = table.concat(pts, ","),
                turn = math.floor((tonumber(o.oFaceAngleYaw) or 0) / 0x4000 + 0.5) % 4 })
        end
    end

    local pipes = {}
    for _, placed in ipairs(forge.placed) do
        local o = placed.object
        local d = forge.pipe_read ~= nil and forge.pipe_read(o) or nil
        if d ~= nil and o.oPosX >= box.minX and o.oPosX <= box.maxX
            and o.oPosY >= box.minY and o.oPosY <= box.maxY
            and o.oPosZ >= box.minZ and o.oPosZ <= box.maxZ then
            local c = { forge.cell_of(o.oPosX), forge.cell_of(o.oPosY), forge.cell_of(o.oPosZ) }
            for k = 1, 3 do lo[k] = math.min(lo[k], c[k]) end
            local id = d.kind == forge.PIPE_LEVEL and forge.keep_level_id(d.level) or "-"
            table.insert(pipes, { c = c, d = d, id = id or "-",
                turn = math.floor((tonumber(o.oFaceAngleYaw) or 0) / 0x4000 + 0.5) % 4 })
        end
    end

    local lgs, lws = {}, {}
    local LG = OF.logic
    for _, placed in ipairs(forge.placed) do
        local o = placed.object

        local kind = (o ~= nil and o.activeFlags ~= 0 and LG ~= nil and placed.key ~= nil)
            and (LG.KEYS[placed.key] or 0) or 0
        if kind > 0 and o.oPosX >= box.minX and o.oPosX <= box.maxX
            and o.oPosY >= box.minY and o.oPosY <= box.maxY
            and o.oPosZ >= box.minZ and o.oPosZ <= box.maxZ then
            local c = { forge.cell_of(o.oPosX), forge.cell_of(o.oPosY), forge.cell_of(o.oPosZ) }
            for k = 1, 3 do lo[k] = math.min(lo[k], c[k]) end
            links[LG.link(o)] = true
            table.insert(lgs, { c = c, kind = LG.KIND_NAMES[kind], link = LG.link(o),
                turn = math.floor((tonumber(o.oFaceAngleYaw) or 0) / 0x4000 + 0.5) % 4 })
        end
    end
    if LG ~= nil and type(LG.forge_wires) == "function" then
        for _, w in ipairs(LG.forge_wires()) do
            local code = LG.encode({ w })
            if OF.logic.wire_inside(w, links) and not code:find("[%.,;]") then
                table.insert(lws, code)
            end
        end
    end
    if #found == 0 and #movs == 0 and #pipes == 0 and #lgs == 0 then
        return nil, "None of your blocks is inside the box."
    end
    local parts = { "v1" }
    for _, c in ipairs(found) do
        local fields = { c[1], c[2], c[3] - lo[1], c[4] - lo[2], c[5] - lo[3], c[6], c[7] }
        if c[8] ~= nil then table.insert(fields, c[8]) end
        table.insert(parts, table.concat(fields, "."))
    end
    for _, mv in ipairs(movs) do
        local fields = { "mv", mv.shape, mv.slug, mv.c[1] - lo[1],
            mv.c[2] - lo[2], mv.c[3] - lo[3], mv.turn, mv.spec.mode, mv.spec.trigger,
            mv.spec.phase, mv.pts }
        if mv.spec.trigger == "wired" then table.insert(fields, mv.spec.link or 0) end
        table.insert(parts, table.concat(fields, "."))
    end
    for _, lg in ipairs(lgs) do
        table.insert(parts, table.concat({ "lg", lg.kind, lg.c[1] - lo[1], lg.c[2] - lo[2],
            lg.c[3] - lo[3], lg.turn, lg.link }, "."))
    end
    for _, code in ipairs(lws) do table.insert(parts, "lw." .. code) end
    for _, p in ipairs(pipes) do
        table.insert(parts, table.concat({ "pp", p.c[1] - lo[1], p.c[2] - lo[2], p.c[3] - lo[3],
            p.turn, p.d.kind, p.id, p.d.area, p.d.tag, p.d.pair }, "."))
    end
    return table.concat(parts, ";"), #found + #movs + #pipes + #lgs
end

function forge.prefab_capture()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local text, count = forge.prefab_draft()
    if text == nil then return false, count end
    local parts = math.ceil(#text / DRAFT_PART)
    if parts > DRAFT_PARTS then
        return false, OF.lang.fill("Too big to keep: @ blocks", tostring(count))
    end
    for k = 1, DRAFT_PARTS do
        OF.util.store(DRAFT_KEY .. k, text:sub((k - 1) * DRAFT_PART + 1, k * DRAFT_PART))
    end
    OF.sounds.ui("select", OF.sounds.PICK)
    return true, OF.lang.fill("Kept @ blocks - tools/prefabs.py import-save adds them",
        tostring(count))
end
end

do
forge.path = nil

forge.PATH_SPEEDS = { 60, 120, 180, 240, 300, 450, 600, 900, 1200, 1800, 2400,
    3000, 3600, 4200 }
forge.PATH_WAITS = { 0, 5, 10, 20, 30, 50, 100, 200, 600 }
local PATH_LENGTH = 1200

local function path_live()
    local p = forge.path
    if p == nil then return nil end
    local o = p.object
    if o == nil or o.activeFlags == 0 or not OF.util.alive(o) then
        forge.path = nil
        return nil
    end
    return p
end

function forge.path_object()
    local p = path_live()
    return p ~= nil and p.object or nil
end

function forge.path_spec()
    local o = forge.path_object()
    return o ~= nil and OF.spawner.mover_read(o) or nil
end

function forge.path_cursor(m)
    if m == nil then return nil end
    if forge.build_live() then return forge.cell_cursor(m) end
    return carry_spot(m)
end

local function step_in(list, value, step)
    local best = 1
    for i, v in ipairs(list) do
        if math.abs(v - value) < math.abs(list[best] - value) then best = i end
    end
    return list[math.max(1, math.min(#list, best + step))]
end

local function edit(change, renumber)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local p = path_live()
    if p == nil then return false, "No path in hand - put a mover down or aim at one." end
    local spec = OF.spawner.mover_read(p.object)
    if spec == nil then return false, "That one has no path." end
    local selWas = p.sel
    local ok, said = change(spec, p)
    if ok == false then
        OF.sounds.ui("back", OF.sounds.BACK)
        return false, said
    end
    OF.spawner.mover_set_path(p.object, spec, renumber ~= nil and renumber(selWas) or nil)
    p.sel = math.max(1, math.min(#OF.spawner.mover_read(p.object).points, p.sel))
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true, said
end

function forge.mover_place(kind)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local opened, notOpened = forge.ensure_open()
    if not opened then return false, notOpened end
    local m = gMarioStates[0]
    if m == nil then return false end
    local key
    if kind == "block" then
        local blockKey = forge.build_place_key ~= nil and forge.build_place_key() or nil
        if blockKey == nil then return false, "Choose a block first." end
        key = "mv" .. blockKey
    else
        key = "mv" .. tostring(kind)
    end
    if OF.spawner.mover_find(key) == nil then return false, "That cannot move in this copy of the mod." end
    local x, y, z
    if kind == "block" and forge.build_live() then x, y, z = forge.cell_cursor(m)
    else x, y, z = carry_spot(m) end
    if x == nil then return false end

    local yaw = tonumber(m.faceAngle.y) or 0
    local quarter = OF.spawner.quarter_yaw(yaw)
    local dx = math.floor(sins(quarter) * PATH_LENGTH + 0.5)
    local dz = math.floor(coss(quarter) * PATH_LENGTH + 0.5)
    local spec = { mode = "pingpong", trigger = "always",
        points = { { x = 0, y = 0, z = 0 }, { x = dx, y = 0, z = dz } } }
    local o = OF.spawner.spawn_mover(key, x, y, z,
        kind == "block" and forge.build_yaw() or quarter, spec)
    if o == nil then return false, "Nothing was placed." end
    forget_redo()
    table.insert(forge.placed, { object = o, key = key, size = NORMAL_SIZE, batch = next_batch() })
    forge.publish_reach()
    forge.path = { object = o, sel = 2 }
    OF.sounds.ui("select", OF.sounds.PICK)
    return true, "B adds a point, L+Z / R+Z choose one, L+R+Z lets the path go."
end

function forge.path_aimed(m)
    if m == nil then return nil end
    local cx, cy, cz = carry_spot(m)
    if cx == nil then return nil end
    local best, bestDist = nil, GRAB_RANGE * GRAB_RANGE
    for _, o in ipairs(OF.spawner.movers_here()) do
        local d = (o.oPosX - cx) ^ 2 + (o.oPosY - cy) ^ 2 + (o.oPosZ - cz) ^ 2
        if d < bestDist and is_mine(o) then best, bestDist = o, d end
    end
    return best
end

function forge.path_begin(m)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local o = forge.path_aimed(m or gMarioStates[0])
    if o == nil then return false, "No mover of yours near the cursor." end
    forge.path = { object = o, sel = 1 }
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.path_end()
    if forge.path == nil then return false, "No path in hand." end
    forge.path = nil
    OF.sounds.ui("back", OF.sounds.BACK)
    return true
end

function forge.path_add(m)
    local x, y, z = forge.path_cursor(m or gMarioStates[0])
    if x == nil then return false end
    return edit(function(spec, p)
        if #spec.points >= OF.spawner.MOVER_MAX_POINTS then
            return false, OF.lang.fill("A path has @ points at most", tostring(OF.spawner.MOVER_MAX_POINTS))
        end
        local o = p.object
        local from = spec.points[p.sel] or spec.points[#spec.points]
        table.insert(spec.points, p.sel + 1, { x = x - o.oHomeX, y = y - o.oHomeY,
            z = z - o.oHomeZ, speed = from.speed, wait = from.wait })
        p.sel = p.sel + 1
    end, function(sel)
        return function(i) return i <= sel and i or i + 1 end
    end)
end

function forge.path_move(m)
    local x, y, z = forge.path_cursor(m or gMarioStates[0])
    if x == nil then return false end
    return edit(function(spec, p)
        if p.sel == 1 then return false, "The first point is where it stands - pick it up to move it." end
        local o = p.object
        local pt = spec.points[p.sel]
        pt.x, pt.y, pt.z = x - o.oHomeX, y - o.oHomeY, z - o.oHomeZ
    end)
end

function forge.path_delete()
    return edit(function(spec, p)
        if p.sel == 1 then return false, "The first point is where it stands." end
        if #spec.points <= 2 then return false, "A path needs two points." end
        table.remove(spec.points, p.sel)
        p.sel = p.sel - 1
    end, function(sel)
        return function(i)
            if i == sel then return nil end
            return i < sel and i or i - 1
        end
    end)
end

function forge.path_select(step)
    local p = path_live()
    if p == nil then return false, "No path in hand." end
    local spec = OF.spawner.mover_read(p.object)
    if spec == nil then return false end
    p.sel = (p.sel - 1 + step) % #spec.points + 1
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.path_speed_by(step)
    return edit(function(spec, p)
        local pt = spec.points[p.sel]
        pt.speed = step_in(forge.PATH_SPEEDS, pt.speed, step)
    end)
end

function forge.path_wait_by(step)
    return edit(function(spec, p)
        local pt = spec.points[p.sel]
        pt.wait = step_in(forge.PATH_WAITS, pt.wait, step)
    end)
end

function forge.path_mode_by(step)
    return edit(function(spec)
        local modes = OF.spawner.MOVER_MODES
        local at = 1
        for i, w in ipairs(modes) do if w == spec.mode then at = i end end
        spec.mode = modes[(at - 1 + step) % #modes + 1]
    end)
end

function forge.path_trigger_toggle()
    return edit(function(spec)
        spec.trigger = spec.trigger == "ridden" and "always" or "ridden"
    end)
end

function forge.path_wired_toggle()
    return edit(function(spec)
        if spec.trigger == "wired" then
            spec.trigger = "always"
        else
            spec.trigger = "wired"
            spec.link = OF.logic ~= nil and OF.logic.forgeLink or 1
        end
    end)
end

function forge.path_legend()
    local spec = forge.path_spec()
    local sel = forge.path ~= nil and forge.path.sel or 0
    return OF.lang.fill("Move & paths  -  point @   B: add a point   R+B: take it out",
            OF.lang.fill("@ of @", tostring(sel), tostring(spec ~= nil and #spec.points or 0))),
        OF.lang.t("L+Z / R+Z: choose   L+R+Z: done   X: move it here   R+X: way round   "
            .. "L+R+X: only when ridden   R+right stick: speed, wait")
end

function forge.mover_row(row, object, x, y, z)

    if object ~= nil and forge.pipe_read ~= nil then row.pipe = forge.pipe_read(object) end

    if object ~= nil then row.stretch = forge.stretch_of(object) end

    if object ~= nil and OF.logic ~= nil and OF.logic.KEYS ~= nil and OF.logic.KEYS[row.key] ~= nil then
        row.link = OF.logic.link(object)
    end
    if object == nil or not OF.spawner.is_mover(row.key) then return row end
    local hx, hy, hz = object.oHomeX, object.oHomeY, object.oHomeZ
    if row.dx ~= nil then
        row.dx, row.dy, row.dz = hx - x, hy - y, hz - z
    else
        row.x, row.y, row.z = hx, hy, hz
    end
    row.path = OF.spawner.mover_read(object)
    return row
end

function forge.spawn_row(row, x, y, z, yaw, turn)
    if row.pipe ~= nil and forge.pipe_spawn ~= nil then
        return forge.pipe_spawn(row.key, x, y, z, yaw, row.pipe)
    end
    if row.path == nil then
        local wasLink = OF.logic ~= nil and OF.logic.forgeLink or nil
        if row.link ~= nil and wasLink ~= nil then OF.logic.forgeLink = row.link end
        local o = OF.spawner.spawn_at(row.key, x, y, z, yaw, row.stretch)
        if wasLink ~= nil then OF.logic.forgeLink = wasLink end
        return o
    end

    local spec = { mode = row.path.mode, trigger = row.path.trigger,
        phase = row.path.phase, link = row.path.link, points = {} }
    local s, c = sins(math.floor(turn or 0)), coss(math.floor(turn or 0))
    for _, p in ipairs(row.path.points) do
        table.insert(spec.points, { x = p.x * c + p.z * s, y = p.y, z = p.z * c - p.x * s,
            speed = p.speed, wait = p.wait })
    end
    return OF.spawner.spawn_mover(row.key, x, y, z, yaw, spec)
end

forge.PATH_MODE_NAMES = { loop = "Round and round", pingpong = "There and back",
    oneway = "Up, then straight home" }

function forge.path_mode_name(spec)
    return forge.PATH_MODE_NAMES[spec ~= nil and spec.mode or ""] or "?"
end

local pathStick = { x = 0, y = 0 }

function forge.path_input(m, input)
    if path_live() == nil or m == nil or input == nil then return false end
    local l = OF.util.has_flag(input.down, L_TRIG)
    local r = OF.util.has_flag(input.down, R_TRIG)

    local xBit = X_BUTTON or 0x0040
    if OF.util.has_flag(m.controller.buttonPressed or 0, xBit) and not (l and not r) then
        if l and r then OF.util.report(forge.path_trigger_toggle())
        elseif r then OF.util.report(forge.path_mode_by(1))
        else OF.util.report(forge.path_move(m)) end
        OF.input.take(m, xBit)
        return true
    end
    local wantX, wantY = 0, 0
    if r and not l then
        local ex, ey = m.controller.extStickX or 0, m.controller.extStickY or 0
        if math.abs(ex) > 30 then wantX = ex > 0 and 1 or -1 end
        if math.abs(ey) > 30 then wantY = ey > 0 and 1 or -1 end
    end
    local stepped = false
    if wantX ~= 0 and wantX ~= pathStick.x then
        OF.util.report(forge.path_speed_by(wantX))
        stepped = true
    elseif wantX == 0 and wantY ~= 0 and wantY ~= pathStick.y then
        OF.util.report(forge.path_wait_by(wantY))
        stepped = true
    end
    pathStick.x, pathStick.y = wantX, wantY
    if stepped then return true end
    if input.pressed(Z_TRIG) and l and r then
        OF.util.report(forge.path_end())
        OF.input.take(m, Z_TRIG)
        return true
    end
    if input.pressed(Z_TRIG) and (l or r) then
        OF.util.report(forge.path_select(r and 1 or -1))
        OF.input.take(m, Z_TRIG)
        return true
    end
    if input.pressed(B_BUTTON) and not l then
        if r then OF.util.report(forge.path_delete())
        else OF.util.report(forge.path_add(m)) end
        OF.input.take(m, B_BUTTON)
        return true
    end
    return false
end

function forge.path_mouse(m, wheel, pressed)
    if path_live() == nil then return false end
    local did = false
    if wheel ~= 0 then
        OF.util.report(forge.path_select(wheel > 0 and -1 or 1))
        did = true
    end
    if M_MOUSE_BUTTON ~= nil and OF.util.has_flag(pressed, M_MOUSE_BUTTON) then
        OF.util.report(forge.path_move(m))
        did = true
    end
    if R_MOUSE_BUTTON ~= nil and OF.util.has_flag(pressed, R_MOUSE_BUTTON) then
        OF.util.report(forge.path_delete())
        did = true
    end
    return did
end

function forge.path_points(o)
    local spec = o ~= nil and OF.spawner.mover_read(o) or nil
    if spec == nil then return nil end
    local out = {}
    for _, p in ipairs(spec.points) do
        table.insert(out, { x = o.oHomeX + p.x, y = o.oHomeY + p.y, z = o.oHomeZ + p.z })
    end
    return out, spec.mode == "loop"
end

function forge.draw_paths()
    if not forge.open then return 0 end
    local held = forge.path_object()
    local sel = forge.path ~= nil and forge.path.sel or 0
    local gold = OF.util.gold()
    local drawn = 0
    for _, o in ipairs(OF.spawner.movers_here()) do
        local pts, closed = forge.path_points(o)
        if pts ~= nil then
            local mine = o == held
            local alpha = mine and 235 or 90
            for i = 1, #pts - 1 do
                OF.util.world_line(pts[i], pts[i + 1], mine and 3 or 2, gold.r, gold.g, gold.b, alpha)
                drawn = drawn + 1
            end
            if closed then
                OF.util.world_line(pts[#pts], pts[1], mine and 3 or 2, gold.r, gold.g, gold.b, alpha)
                drawn = drawn + 1
            end
            if mine then
                for i, p in ipairs(pts) do
                    OF.util.world_ring(p, i == sel and 90 or 40, 16, i == sel and 4 or 2,
                        gold.r, gold.g, gold.b, 235)
                end
            end
        end
    end
    return drawn
end

function forge.mover_rows(panel, rows)
    local spec = forge.path_spec()
    table.insert(rows, panel.with_right(
        panel.header_row(OF.lang.t("Moving platforms")),
        tostring(#OF.spawner.movers_here())))
    if spec == nil then

        table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
            OF.lang.t("Put down a rolling log on a path"), 255, 255, 255,
            function() OF.util.report(forge.mover_place("log")) end),
            OF.lang.t("rolls along its path the way Lethal Lava Land's does")))
        table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
            OF.lang.t("Put down a wide rolling log on a path"), 255, 255, 255,
            function() OF.util.report(forge.mover_place("logwide")) end),
            OF.lang.t("the long log, on a path of its own")))
        table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
            OF.lang.t("Edit the path of the one you aim at"), 255, 255, 255,
            function() OF.util.report(forge.path_begin()) end),
            OF.lang.t("a moving platform of yours near the cursor")))
        return
    end
    local p = forge.path
    local pt = spec.points[p.sel] or spec.points[1]
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object", OF.lang.t("Point"), 255, 255, 255,
            function() OF.util.report(forge.path_select(1)) end),
        OF.lang.fill("@ of @", tostring(p.sel), tostring(#spec.points))),
        OF.lang.t("the next point a press; L+Z / R+Z in game")))

    local speedAt = 1
    for i, v in ipairs(forge.PATH_SPEEDS) do
        if math.abs(v - pt.speed) < math.abs(forge.PATH_SPEEDS[speedAt] - pt.speed) then speedAt = i end
    end
    local speedCount = #forge.PATH_SPEEDS
    table.insert(rows, panel.with_help(panel.with_slider(panel.with_right(
        panel.gated_row("spawn_object", OF.lang.t("Speed to the next point"), 255, 255, 255,
            function()
                OF.util.report(forge.path_speed_by(speedAt < speedCount and 1 or 1 - speedCount))
            end),
        OF.lang.fill("@ a second", tostring(pt.speed))),
        speedAt - 1, speedCount - 1,
        function(wanted) OF.util.report(forge.path_speed_by(wanted + 1 - speedAt)) end),
        OF.lang.t("how fast it rides there; Mario at a run is 960")))
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object", OF.lang.t("Wait at this point"), 255, 255, 255,
            function() OF.util.report(forge.path_wait_by(1)) end),
        OF.lang.fill("@ s", string.format("%.1f", pt.wait / 10))),
        OF.lang.t("how long it stands here before it goes on")))
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object", OF.lang.t("Way round"), 255, 255, 255,
            function() OF.util.report(forge.path_mode_by(1)) end),
        OF.lang.t(forge.path_mode_name(spec))),
        OF.lang.t("loop, there and back, or up and straight home")))
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        panel.tick(spec.trigger == "ridden", OF.lang.t("Only when somebody stands on it")),
        255, 255, 255, function() OF.util.report(forge.path_trigger_toggle()) end),
        OF.lang.t("rests at its first point, goes round while ridden")))
    table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("spawn_object",
        panel.tick(spec.trigger == "wired", OF.lang.t("Only when a wire starts it")),
        255, 255, 255, function() OF.util.report(forge.path_wired_toggle()) end),
        spec.trigger == "wired" and tostring(spec.link or 1) or ""),
        OF.lang.t("a door: a button or a zone wired to this number opens it")))
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t("Add a point at the cursor"), 255, 255, 255,
        function() OF.util.report(forge.path_add()) end),
        OF.lang.t("after this one; B does the same in game")))
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t("Move this point to the cursor"), 255, 255, 255,
        function() OF.util.report(forge.path_move()) end),
        OF.lang.t("the middle mouse button does the same")))
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t("Take this point out"), 255, 200, 140,
        function() OF.util.report(forge.path_delete()) end),
        OF.lang.t("R+B does the same in game")))
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t("Done with this path"), 255, 255, 255,
        function() OF.util.report(forge.path_end()) end),
        OF.lang.t("lets the path go; L+R+Z does the same in game")))
end
end

do
forge.PIPE_MAGIC = 0x5750
forge.PIPE_NONE, forge.PIPE_LEVEL, forge.PIPE_PAIR = 0, 1, 2
forge.PACKET_PIPE = "pipeto"
forge.PIPE_DELAY = 20

forge.PIPE_GIVE_UP = 90

local PF = 0x51
forge.PIPE_FIELDS = PF
local PF_MAGIC, PF_KIND, PF_LEVEL, PF_AREA, PF_TAG, PF_PAIR = 0, 1, 2, 3, 4, 5
forge.pipeNext = { kind = 0, level = 0, area = 0, pair = 0 }
forge.pipePick = nil
forge.pipeTravel = nil
forge.pipeArmed = true

local function fget(o, i)
    if o == nil or type(obj_get_field_s32) ~= "function" then return 0 end
    return math.floor(tonumber(obj_get_field_s32(o, PF + i)) or 0)
end

local function fset(o, i, v)
    if o == nil or type(obj_set_field_s32) ~= "function" then return end
    obj_set_field_s32(o, PF + i, math.floor(tonumber(v) or 0))
end

function forge.pipe_is(o)
    return o ~= nil and o.activeFlags ~= 0 and fget(o, PF_MAGIC) == forge.PIPE_MAGIC
end

function forge.pipe_read(o)
    if not forge.pipe_is(o) then return nil end
    return { kind = fget(o, PF_KIND), level = fget(o, PF_LEVEL), area = fget(o, PF_AREA),
        tag = fget(o, PF_TAG), pair = fget(o, PF_PAIR) }
end

local function clean(dest)
    dest = dest or {}
    local kind = math.floor(tonumber(dest.kind) or 0)
    if kind ~= forge.PIPE_LEVEL and kind ~= forge.PIPE_PAIR then
        return { kind = forge.PIPE_NONE, level = 0, area = 0, pair = 0 }
    end
    return { kind = kind, level = math.floor(tonumber(dest.level) or 0),
        area = math.max(1, math.floor(tonumber(dest.area) or 1)),
        pair = math.floor(tonumber(dest.pair) or 0) }
end

function forge.pipe_write(o, dest)
    if o == nil then return nil end
    dest = clean(dest)
    fset(o, PF_KIND, dest.kind)
    fset(o, PF_LEVEL, dest.level)
    fset(o, PF_AREA, dest.area)
    fset(o, PF_PAIR, dest.pair)
    return dest
end

function forge.pipes_here()
    local out = {}
    if id_bhvWarpPipe == nil or OF.util.binding("obj_get_first_with_behavior_id") == nil then
        return out
    end
    local o = obj_get_first_with_behavior_id(id_bhvWarpPipe)
    local guard = 0
    while o ~= nil and guard < 512 do
        if forge.pipe_is(o) then table.insert(out, o) end
        o = obj_get_next_with_same_behavior_id(o)
        guard = guard + 1
    end
    return out
end

function forge.pipe_by_tag(tag)
    if tag == nil or tag == 0 then return nil end
    for _, o in ipairs(forge.pipes_here()) do
        if fget(o, PF_TAG) == tag then return o end
    end
    return nil
end

local function pipe_by_sync_id(id)
    id = tonumber(id)
    if id == nil then return nil end
    for _, o in ipairs(forge.pipes_here()) do
        if o.oSyncID == id then return o end
    end
    return nil
end
forge.pipe_by_sync_id = pipe_by_sync_id

local function new_tag()
    local used = {}
    for _, o in ipairs(forge.pipes_here()) do used[fget(o, PF_TAG)] = true end
    local tag = math.random(1, 0x7FFF)
    local guard = 0
    while used[tag] and guard < 64 do
        tag = tag % 0x7FFF + 1
        guard = guard + 1
    end
    return tag
end
forge.pipe_new_tag = new_tag

function forge.pipe_setup(o)
    fset(o, PF_MAGIC, forge.PIPE_MAGIC)
    local tag = tonumber(forge.pipeTagNext)
    if tag == nil or tag <= 0 then tag = new_tag() end
    fset(o, PF_TAG, tag)
    forge.pipe_write(o, forge.pipeDestNext or forge.pipeNext)
end

function forge.pipe_spawn(key, x, y, z, yaw, pipe)
    local tag = pipe ~= nil and tonumber(pipe.tag) or nil
    if tag ~= nil and forge.pipe_by_tag(tag) ~= nil then tag = nil end
    forge.pipeDestNext = pipe ~= nil and clean(pipe) or nil
    forge.pipeTagNext = tag
    local ok, o = pcall(OF.spawner.spawn_at, key, x, y, z, yaw)
    forge.pipeDestNext, forge.pipeTagNext = nil, nil
    if not ok then error(o) end
    return o
end

local function dest_entry(level, area)
    for _, entry in ipairs(OF.LEVELS or {}) do
        if entry.level == level and (entry.area or 1) == (area or 1) then return entry end
    end
    if OF.util.asks(OF.util, "venue_destinations") then
        for _, entry in ipairs(OF.util.venue_destinations()) do
            if entry.level == level and (entry.area or 1) == (area or 1) then return entry end
        end
    end
    if OF.util.asks(OF.util, "custom_levels") then
        for _, entry in ipairs(OF.util.custom_levels()) do
            if entry.level == level then return entry end
        end
    end
    return nil
end
forge.pipe_dest_entry = dest_entry

function forge.pipe_dest_name(dest)
    dest = clean(dest)
    if dest.kind == forge.PIPE_LEVEL then
        local entry = dest_entry(dest.level, dest.area)
        if entry ~= nil then return entry.name end
        return OF.lang.fill("level @", tostring(dest.level))
    end
    if dest.kind == forge.PIPE_PAIR then
        if forge.pipe_by_tag(dest.pair) == nil then return OF.lang.t("a pipe that is gone") end
        return OF.lang.fill("pipe @", tostring(dest.pair))
    end
    return OF.lang.t("nowhere")
end

function forge.pipe_set(pipe, dest)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if not forge.pipe_is(pipe) then return false, "That is not a Forge pipe." end
    if not is_mine(pipe) then return false, "That pipe is somebody else's." end
    dest = forge.pipe_write(pipe, dest)
    if pipe.oSyncID ~= nil and pipe.oSyncID ~= 0 then
        OF.util.send_all({ ofp = forge.PACKET_PIPE, id = pipe.oSyncID, k = dest.kind,
            l = dest.level, a = dest.area, p = dest.pair })
    end
    return true
end

local pipePending = {}

local function pipe_receive(data)
    local o = pipe_by_sync_id(data.id)
    if o == nil then return false end
    forge.pipe_write(o, { kind = data.k, level = data.l, area = data.a, pair = data.p })
    return true
end
forge.pipe_receive = pipe_receive

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" or data.ofp ~= forge.PACKET_PIPE then return end
    if not pipe_receive(data) then
        table.insert(pipePending, { data = data, left = 150 })
    end
end)

function forge.pipe_aimed(m)
    m = m or gMarioStates[0]
    if m == nil then return nil end
    if forge.held ~= nil and forge.pipe_is(forge.held) then return forge.held end
    local cx, cy, cz = carry_spot(m)
    local best, bestD = nil, GRAB_RANGE
    for _, entry in ipairs(forge.placed) do
        local o = entry.object
        if forge.pipe_is(o) then
            for _, at in ipairs({ { cx, cy, cz }, { m.pos.x, m.pos.y, m.pos.z } }) do
                if at[1] ~= nil then
                    local dx, dy, dz = o.oPosX - at[1], o.oPosY - at[2], o.oPosZ - at[3]
                    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if d < bestD then best, bestD = o, d end
                end
            end
        end
    end
    return best
end

function forge.pipe_pick_begin(o)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if o ~= nil then
        if not forge.pipe_is(o) or not is_mine(o) then return false, "That pipe is somebody else's." end
        forge.pipePick = { id = o.oSyncID }
    else
        forge.pipePick = { next = true }
    end
    OF.panel.levelMode = "pipe"
    if OF.util.asks(OF.panel, "travel_from_here") then OF.panel.travel_from_here() end
    return true
end

function forge.pipe_pick_cancel()
    forge.pipePick = nil
    return true
end

local function pick_target()
    local pick = forge.pipePick
    if pick == nil or pick.next then return nil, pick ~= nil end
    local o = pipe_by_sync_id(pick.id)
    return o, o ~= nil
end

local function pick_apply(dest)
    local o, live = pick_target()
    if not live then
        forge.pipePick = nil
        return false, "That pipe is gone."
    end
    if o == nil then
        forge.pipeNext = clean(dest)
        forge.pipePick = nil
        OF.sounds.ui("select", OF.sounds.PICK)
        return true, OF.lang.fill("The next pipe leads to @", forge.pipe_dest_name(dest))
    end
    local ok, why = forge.pipe_set(o, dest)
    forge.pipePick = nil
    if not ok then return false, why end
    OF.sounds.ui("select", OF.sounds.PICK)
    return true, OF.lang.fill("This pipe leads to @", forge.pipe_dest_name(dest))
end

function forge.pipe_choose(entry)
    if type(entry) ~= "table" or entry.point ~= nil or type(entry.level) ~= "number" then
        return false, "A pipe leads to a level."
    end
    return pick_apply({ kind = forge.PIPE_LEVEL, level = entry.level, area = entry.area or 1 })
end

function forge.pipe_choose_pipe(partner)
    local o, live = pick_target()
    if not live then forge.pipePick = nil; return false, "That pipe is gone." end
    if o == nil then
        return false, "Put the pipe down first, then pick its partner from it."
    end
    if partner == nil or partner == o or not forge.pipe_is(partner) then
        return false, "Pick another pipe."
    end
    if not is_mine(partner) then return false, "That pipe is somebody else's." end
    local ok, why = forge.pipe_set(partner, { kind = forge.PIPE_PAIR, pair = fget(o, PF_TAG) })
    if not ok then return false, why end
    return pick_apply({ kind = forge.PIPE_PAIR, pair = fget(partner, PF_TAG) })
end

function forge.pipe_choose_none()
    return pick_apply({ kind = forge.PIPE_NONE })
end

function forge.pipe_back()
    if OF.util.asks(OF.panel, "travel_return") then return OF.panel.travel_return("forge") end
    return "forge"
end

function forge.pipe_group_rows(panel, rows)
    local target = pick_target()
    table.insert(rows, panel.label_row(OF.lang.t("Pipes in this level")))
    local any = false
    for i = 1, #forge.placed do
        local other = forge.placed[i].object
        if forge.pipe_is(other) and other ~= target then
            any = true
            local tag = fget(other, PF_TAG)
            table.insert(rows, panel.with_help(panel.with_right(
                panel.gated_row("spawn_object", OF.lang.fill("Pipe @", tostring(tag)),
                    255, 255, 255, function()
                        if OF.util.report(forge.pipe_choose_pipe(other)) then
                            panel.go(forge.pipe_back())
                        end
                    end),
                forge.pipe_dest_name(forge.pipe_read(other))),
                OF.lang.t("a pair: each of the two leads to the other")))
        end
    end
    if not any then
        table.insert(rows, panel.label_row(OF.lang.t("No other pipe of yours here")))
    end
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t("Nowhere - just a pipe"), 255, 255, 255, function()
            if OF.util.report(forge.pipe_choose_none()) then panel.go(forge.pipe_back()) end
        end), OF.lang.t("the pipe stands there and takes nobody anywhere")))
end

function forge.pipe_rows(panel, rows)
    local o = forge.pipe_aimed()
    if o ~= nil then
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("spawn_object", OF.lang.t("Where this pipe leads..."),
                255, 255, 255, function()
                    if OF.util.report(forge.pipe_pick_begin(o)) then panel.go("groups") end
                end),
            forge.pipe_dest_name(forge.pipe_read(o))),
            OF.lang.t("the pipe of yours you aim at; pick a level or another pipe")))
    end
end

function forge.pipe_may_enter()
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then
        local def = OF.util.asks(OF.gamemodes, "current") and OF.gamemodes.current() or nil
        if def == nil or def.forgePipes ~= true then
            return false, "No pipes during the round."
        end
    end
    return true
end

function forge.pipe_touches(m, o)
    local body = m ~= nil and m.marioObj or nil
    if body == nil or o == nil then return false end
    local r1 = math.max(tonumber(body.hitboxRadius) or 37, tonumber(body.hurtboxRadius) or 0)
    local h1 = math.max(tonumber(body.hitboxHeight) or 160, tonumber(body.hurtboxHeight) or 0)
    local r2 = math.max(tonumber(o.hitboxRadius) or 50, tonumber(o.hurtboxRadius) or 0)
    local h2 = math.max(tonumber(o.hitboxHeight) or 50, tonumber(o.hurtboxHeight) or 0)
    if r2 <= 0 then r2 = 50 end
    if h2 <= 0 then h2 = 50 end
    local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
    if dx * dx + dz * dz > (r1 + r2) * (r1 + r2) then return false end
    local lo1 = m.pos.y - (tonumber(body.hitboxDownOffset) or 0)
    local lo2 = o.oPosY - (tonumber(o.hitboxDownOffset) or 0)
    if (lo2 + h2 - lo1) > h1 + h2 or (lo1 + h1 - lo2) > h1 + h2 then return false end
    return true
end

local function fade(into)
    if type(play_transition) ~= "function" then return end
    if into then
        play_transition(WARP_TRANSITION_FADE_INTO_STAR, 0x14, 0, 0, 0)
    else
        play_transition(WARP_TRANSITION_FADE_FROM_STAR, 0x14, 0, 0, 0)
    end
end

local function give_back(m, why)
    forge.pipeTravel = nil
    fade(false)
    if m ~= nil and m.action == ACT_DISAPPEARED then set_mario_action(m, ACT_IDLE, 0) end
    if why ~= nil then OF.util.report(false, why) end
end

local NOWHERE = "This pipe leads nowhere anymore"
function forge.pipe_resolve(dest)
    if dest == nil then return false, NOWHERE end
    if dest.kind == forge.PIPE_PAIR then
        if forge.pipe_by_tag(dest.pair) == nil then return false, NOWHERE end
        return true
    end
    if dest.kind == forge.PIPE_LEVEL then
        local level = tonumber(dest.level)
        if level == nil or level <= 0 or dest_entry(level, dest.area) == nil then
            return false, NOWHERE
        end
        return true
    end
    return false, NOWHERE
end

local function eject(m, at, why)
    forge.pipeTravel = nil
    if m == nil then return end
    if at ~= nil then
        m.pos.x, m.pos.y, m.pos.z = at.x, at.y, at.z
        m.faceAngle.y = at.yaw or m.faceAngle.y
    end
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    set_mario_action(m, ACT_EMERGE_FROM_PIPE, 0)
    if why ~= nil then OF.util.report(false, OF.lang.t(why)) end
end

local function mouth_of(o)
    return { x = o.oPosX, y = o.oPosY, z = o.oPosZ, yaw = tonumber(o.oFaceAngleYaw) }
end

function forge.pipe_enter(m, o)
    local dest = forge.pipe_read(o)
    if dest == nil or dest.kind == forge.PIPE_NONE then return false end
    forge.pipeArmed = false
    local ok, why = forge.pipe_may_enter()
    if not ok then
        OF.notify.show(why, "warn", 3)
        return false
    end
    local found, nowhere = forge.pipe_resolve(dest)
    if not found then
        eject(m, mouth_of(o), nowhere)
        return false
    end
    local body = m.marioObj
    local at = body ~= nil and body.header ~= nil and body.header.gfx.cameraToObject or nil
    play_sound(SOUND_MENU_ENTER_PIPE, at)
    set_mario_action(m, ACT_DISAPPEARED, 0)
    fade(true)
    forge.pipeTravel = { left = forge.PIPE_DELAY, dest = dest, mouth = mouth_of(o),
        level = gNetworkPlayers[0] ~= nil and gNetworkPlayers[0].currLevelNum or nil,
        area = gNetworkPlayers[0] ~= nil and gNetworkPlayers[0].currAreaIndex or nil }
    return true
end

function forge.pipe_arrive(m)
    local t = forge.pipeTravel
    if t == nil then return end
    local dest = t.dest

    local found, nowhere = forge.pipe_resolve(dest)
    if not found then
        fade(false)
        return eject(m, t.mouth, nowhere)
    end
    if dest.kind == forge.PIPE_PAIR then
        local other = forge.pipe_by_tag(dest.pair)
        forge.pipeTravel = nil
        m.pos.x, m.pos.y, m.pos.z = other.oPosX, other.oPosY, other.oPosZ
        m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
        m.forwardVel = 0
        m.faceAngle.y = tonumber(other.oFaceAngleYaw) or m.faceAngle.y
        set_mario_action(m, ACT_EMERGE_FROM_PIPE, 0)
        fade(false)
        return
    end
    local ok, why = forge.pipe_may_enter()
    if not ok then return give_back(m, why) end
    local entry = dest_entry(dest.level, dest.area)
    local act = OF.util.destination_act(entry)
    if not OF.net.warp_local(dest.level, dest.area, act) then
        fade(false)
        return eject(m, t.mouth, NOWHERE)
    end

    t.left = nil
    t.waited = 0
end

function forge.pipe_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local t = forge.pipeTravel
    if t ~= nil then
        if t.left ~= nil then
            if m.action ~= ACT_DISAPPEARED then forge.pipeTravel = nil; return end
            t.left = t.left - 1
            if t.left <= 0 then forge.pipe_arrive(m) end
        else

            local np = gNetworkPlayers[0]
            if np ~= nil and (np.currLevelNum ~= t.level or np.currAreaIndex ~= t.area) then
                forge.pipeTravel = nil
                return
            end
            t.waited = t.waited + 1
            if t.waited > forge.PIPE_GIVE_UP then give_back(m, nil) end
        end
        return
    end
    if m.action == ACT_EMERGE_FROM_PIPE or m.action == ACT_DISAPPEARED then return end
    local touching = nil
    for _, o in ipairs(forge.pipes_here()) do
        if forge.pipe_touches(m, o) then touching = o; break end
    end
    if touching == nil then
        forge.pipeArmed = true
        return
    end
    if forge.pipeArmed and (m.health or 0x880) > 0xFF then forge.pipe_enter(m, touching) end
end

hook_event(HOOK_UPDATE, function()
    if #pipePending > 0 then
        local keep = {}
        for _, wait in ipairs(pipePending) do
            wait.left = wait.left - 1
            if not pipe_receive(wait.data) and wait.left > 0 then table.insert(keep, wait) end
        end
        pipePending = keep
    end
    local m = gMarioStates[0]
    if m ~= nil then forge.pipe_update(m) end
end)

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if interactType == INTERACT_WARP and forge.pipe_is(o) then return false end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    forge.pipeTravel = nil
    forge.pipeArmed = false
    pipePending = {}
    if forge.pipePick ~= nil and not forge.pipePick.next then forge.pipePick = nil end
end)
end

do
forge.KEEP_SETTING = "forge_keep"
forge.KEEP_PART = 1000
forge.KEEP_PARTS = 12
forge.KEEP_LEVELS = 40
forge.KEEP_PER_FRAME = 4

forge.KEEP_ALONE_PER_FRAME = 64
local KEEP_SCAN = 60
local KEEP_IDLE = 300
local KEEP_SETTLE = 30
local KEEP_MATCH = 12
local INDEX_KEY = "fkindex"
forge.KEEP_ON_KEY = "ofFkOn"
forge.PACKET_KEEP_REPORT = "fkrep"
forge.PACKET_KEEP_CLEAR = "fkclr"
forge.PACKET_KEEP_ALL = "fkall"
forge.KEEP_REPORT_PART = 240

forge.PACKET_KEEP_ROWS = "fkrows"
forge.PACKET_KEEP_ASK = "fkask"
forge.PACKET_KEEP_ACK = "fkack"
forge.PACKET_KEEP_YOURS = "fkyours"
local KEEP_RECENT = 3

local keep = { key = nil, text = nil, pending = nil, changedAt = 0, restored = nil,
    arrivedAt = 0, queue = nil, frame = 0, skipped = 0, putBack = 0, carry = {},
    reported = {}, parts = {}, given = {}, handed = {}, out = {}, recent = {},
    seq = 0 }
forge.keepState = keep

local guest = { key = nil, sent = nil, pending = nil, changedAt = 0, out = nil,
    seq = 0, hostHere = false, asked = false, rows = nil, restore = nil,
    queue = nil, askedFor = nil, arrivedAt = 0, putBack = 0 }
forge.keepGuest = guest

function forge.keep_synced_here()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.currAreaSyncValid ~= false and keep.validLevel ~= nil
        and keep.validLevel == np.currLevelNum and keep.validArea == np.currAreaIndex
end

hook_event(HOOK_ON_SYNC_VALID, function()
    local np = gNetworkPlayers[0]
    if np == nil then return end
    keep.validLevel, keep.validArea = np.currLevelNum, np.currAreaIndex
end)

function forge.keep_others_here()
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    for i = 1, (MAX_PLAYERS or 16) - 1 do
        local other = gNetworkPlayers[i]
        if other ~= nil and other.connected and other.currCourseNum == np.currCourseNum
            and other.currActNum == np.currActNum and other.currLevelNum == np.currLevelNum
            and other.currAreaIndex == np.currAreaIndex then
            return true
        end
    end
    return false
end

local function keep_pace()
    return forge.keep_others_here() and forge.KEEP_PER_FRAME or forge.KEEP_ALONE_PER_FRAME
end

function forge.builder_of(localIndex)
    local id = OF.util.asks(OF.util, "player_id") and OF.util.player_id(localIndex or 0) or nil
    id = tostring(id or ""):gsub("[^%w]", "")
    if #id > 24 then id = id:sub(1, 24) end
    if id == "" then id = "host" end
    return id
end

function forge.keep_on()
    if not OF.util.is_host() then

        local li = OF.util.local_from_global(0)
        local row = li ~= nil and gPlayerSyncTable[li] or nil
        return row ~= nil and row[forge.KEEP_ON_KEY] == "1"
    end
    return OF.util.stored(forge.KEEP_SETTING, "1") ~= "0"
end

function forge.keep_toggle()
    if not OF.util.is_host() then return false, "Only the host can switch kept builds." end
    local on = not forge.keep_on()
    OF.util.store(forge.KEEP_SETTING, on and "1" or "0")
    OF.util.publish_row(0, forge.KEEP_ON_KEY, on and "1" or "0")
    return true, on and "Builds are kept per level." or "Builds are no longer kept."
end

local function level_id(level)
    if type(level) ~= "number" then return nil end
    for _, e in ipairs(OF.LEVELS or {}) do
        if e.level == level then return tostring(level) end
    end
    if OF.util.asks(OF.util, "custom_levels") then
        for _, e in ipairs(OF.util.custom_levels()) do
            if e.level == level and type(e.name) == "string" then
                local name = e.name:gsub("[^%w]", "")
                if name ~= "" then return "c" .. name end
            end
        end
    end
    return tostring(level)
end
forge.keep_level_id = level_id

local function level_of_id(id)
    if type(id) ~= "string" then return nil end
    if id:sub(1, 1) ~= "c" then return tonumber(id) end
    if OF.util.asks(OF.util, "custom_levels") then
        for _, e in ipairs(OF.util.custom_levels()) do
            if type(e.name) == "string" and "c" .. e.name:gsub("[^%w]", "") == id then
                return e.level
            end
        end
    end
    return nil
end
forge.keep_level_of_id = level_of_id

function forge.keep_key_for(level, area)
    local id = level_id(level)
    if id == nil then return nil end
    return id .. "a" .. tostring(math.floor(tonumber(area) or 1))
end

function forge.keep_here()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return nil end
    return forge.keep_key_for(np.currLevelNum, np.currAreaIndex)
end

local function r0(v) return math.floor((tonumber(v) or 0) + 0.5) end

local function capture_one(entry, me)
    local o = entry.object
    if o == nil or o.activeFlags == 0 or entry.foreign or entry.key == nil
        or OF.spawner.find(entry.key) == nil
        or (OF.util.asks(OF.spawner, "is_mover") and OF.spawner.is_mover(entry.key)) then
        return nil
    end
    local fields = { entry.key, r0(o.oPosX), r0(o.oPosY), r0(o.oPosZ),
        r0(o.oFaceAngleYaw) % 0x10000, r0(o.oFaceAnglePitch) % 0x10000,
        entry.size or NORMAL_SIZE, r0(o.oBehParams2ndByte) % 0x100 }
    local pipe = forge.pipe_read ~= nil and forge.pipe_read(o) or nil
    if pipe ~= nil then
        local id = pipe.kind == forge.PIPE_LEVEL and level_id(pipe.level) or "-"
        for _, v in ipairs({ pipe.kind, id, pipe.area, pipe.tag, pipe.pair }) do
            table.insert(fields, v)
        end
    end

    local size = forge.stretch_of(o)
    if size ~= nil then table.insert(fields, "#" .. size.w .. "x" .. size.h .. "x" .. size.d) end

    local track = forge.track_field ~= nil and forge.track_field(o, entry.key) or nil
    if track ~= nil then table.insert(fields, track) end

    if OF.logic ~= nil and OF.logic.KEYS[entry.key] ~= nil then
        table.insert(fields, "%" .. OF.logic.link(o))
    end
    table.insert(fields, "@" .. (entry.builder or me))
    return table.concat(fields, ",")
end

function forge.keep_capture()
    local out, count = {}, 0
    local me = forge.builder_of(0)
    for _, entry in ipairs(forge.placed) do
        local text = capture_one(entry, me)
        if text ~= nil then
            table.insert(out, text)
            count = count + 1
        end
    end

    if OF.util.is_host() then
        for _, row in ipairs(keep.carry or {}) do
            if row.builder == nil or keep.reported[row.builder] == nil then
                table.insert(out, row.text)
                count = count + 1
            end
        end

        local names = {}
        for b in pairs(keep.reported) do table.insert(names, b) end
        table.sort(names)
        for _, b in ipairs(names) do
            for _, text in ipairs(keep.reported[b]) do
                table.insert(out, text)
                count = count + 1
            end
        end
    end
    return table.concat(out, ";"), count
end

local function tagged(text, builder)
    local fields = {}
    for word in tostring(text):gmatch("[^,]+") do
        if word:sub(1, 1) ~= "@" then table.insert(fields, word) end
    end
    table.insert(fields, "@" .. builder)
    return table.concat(fields, ",")
end
forge.keep_tagged = tagged

function forge.keep_parse(text)
    local rows = {}
    if type(text) ~= "string" then return rows end
    for item in text:gmatch("[^;]+") do
        local f, builder, stretch, trackText, link = {}, nil, nil, nil, nil
        for word in item:gmatch("[^,]+") do
            local w, h, d = word:match("^#(%d+)x(%d+)x(%d+)$")
            if word:sub(1, 1) == "@" then builder = word:sub(2)
            elseif word:sub(1, 1) == "~" then trackText = word:sub(2)
            elseif word:sub(1, 1) == "%" then link = tonumber(word:sub(2))
            elseif w ~= nil then stretch = { w = tonumber(w), h = tonumber(h), d = tonumber(d) }
            else table.insert(f, word) end
        end
        if #f >= 8 then
            local row = { key = f[1], x = tonumber(f[2]), y = tonumber(f[3]), z = tonumber(f[4]),
                yaw = tonumber(f[5]) or 0, pitch = tonumber(f[6]) or 0,
                size = tonumber(f[7]) or NORMAL_SIZE, byte = tonumber(f[8]) or 0 }
            if #f >= 13 then
                row.pipe = { kind = tonumber(f[9]) or 0, level = level_of_id(f[10]) or 0,
                    area = tonumber(f[11]) or 1, tag = tonumber(f[12]) or 0,
                    pair = tonumber(f[13]) or 0 }
            end
            row.text = item
            row.stretch = stretch
            row.link = link
            if trackText ~= nil and forge.track_field_read ~= nil then
                row.track, row.meta = forge.track_field_read(trackText)
            end
            if builder ~= nil and builder ~= "" then row.builder = builder end
            if row.x ~= nil and row.y ~= nil and row.z ~= nil then table.insert(rows, row) end
        end
    end
    return rows
end

local function index_read()
    local list = {}
    local text = OF.util.stored(INDEX_KEY, "")
    for key, n in tostring(text or ""):gmatch("([%w]+):(%d+)") do
        table.insert(list, { key = key, count = tonumber(n) })
    end
    return list
end

local function index_write(list)
    local parts = {}
    for _, e in ipairs(list) do table.insert(parts, e.key .. ":" .. e.count) end
    return OF.util.store_soon(INDEX_KEY, table.concat(parts, ","))
end

function forge.keep_read(key)
    local n = tonumber(OF.util.stored("fk" .. key .. "n", "0")) or 0
    local parts = {}
    for k = 1, math.min(n, forge.KEEP_PARTS) do
        table.insert(parts, OF.util.stored("fk" .. key .. "p" .. k, "") or "")
    end

    return table.concat(parts, ";")
end

function forge.keep_forget(key)
    if key == nil then return false end
    local n = tonumber(OF.util.stored("fk" .. key .. "n", "0")) or 0
    for k = 1, math.max(n, forge.KEEP_PARTS) do
        if OF.util.stored("fk" .. key .. "p" .. k) ~= nil then OF.util.clear("fk" .. key .. "p" .. k) end
    end
    OF.util.clear("fk" .. key .. "n")
    if forge.racer_index ~= nil then forge.racer_index(key, nil) end
    local list, kept = index_read(), {}
    for _, e in ipairs(list) do if e.key ~= key then table.insert(kept, e) end end
    if #kept ~= #list then
        if #kept == 0 then OF.util.clear(INDEX_KEY) else index_write(kept) end
    end
    if keep.key == key then keep.text, keep.pending = "", nil end
    return true
end

function forge.keep_write(key, text, quiet)
    if key == nil then return 0, 0 end
    if text == nil or text == "" then

        if OF.util.stored("fk" .. key .. "n") ~= nil then forge.keep_forget(key) end
        return 0, 0
    end
    local parts, current, count, dropped = {}, "", 0, 0
    for item in text:gmatch("[^;]+") do
        if #parts >= forge.KEEP_PARTS then
            dropped = dropped + 1
        else
            local add = current == "" and item or (current .. ";" .. item)
            if #add > forge.KEEP_PART then
                table.insert(parts, current)
                current = ""
                if #parts >= forge.KEEP_PARTS then
                    dropped = dropped + 1
                else
                    current = item
                    count = count + 1
                end
            else
                current = add
                count = count + 1
            end
        end
    end
    if current ~= "" then table.insert(parts, current) end
    local list, found = index_read(), false
    for _, e in ipairs(list) do
        if e.key == key then e.count = count; found = true end
    end
    if not found then
        if #list >= forge.KEEP_LEVELS then
            if not quiet then
                OF.notify.show("Kept builds are full (@ levels) - forget one", "warn", 5,
                    tostring(forge.KEEP_LEVELS))
            end
            return 0, count + dropped
        end
        table.insert(list, { key = key, count = count })
    end
    local old = tonumber(OF.util.stored("fk" .. key .. "n", "0")) or 0
    for k, part in ipairs(parts) do OF.util.store_soon("fk" .. key .. "p" .. k, part) end
    for k = #parts + 1, old do OF.util.clear("fk" .. key .. "p" .. k) end
    OF.util.store_soon("fk" .. key .. "n", tostring(#parts))
    index_write(list)
    if forge.racer_index ~= nil then forge.racer_index(key, text) end
    if dropped > 0 and not quiet then
        OF.notify.show("Kept @ things here; the rest did not fit", "warn", 5, tostring(count))
    end
    return count, dropped
end

function forge.keep_list()
    local out = {}
    for _, e in ipairs(index_read()) do
        local id, area = e.key:match("^(.-)a(%d+)$")
        local level = level_of_id(id)
        local name = nil
        if level ~= nil and OF.util.asks(OF.util, "level_name") then
            local ok, n = pcall(OF.util.level_name, level, tonumber(area))
            if ok then name = n end
        end
        table.insert(out, { key = e.key, count = e.count,
            name = name or OF.lang.fill("level @", tostring(id)) })
    end
    return out
end

function forge.keep_may()
    if not OF.util.is_host() or not forge.keep_on() then return false end

    if forge.racer_round_here ~= nil and forge.racer_round_here() then
        local np = gNetworkPlayers[0]
        return np ~= nil and np.currAreaSyncValid ~= false
    end
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then return false end
    if forge.room_is_held() then return false end
    local np = gNetworkPlayers[0]
    return np ~= nil and np.currAreaSyncValid ~= false
end

local function guest_may()
    if OF.util.is_host() or not forge.keep_on() then return false end
    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0) then return false end
    if forge.room_is_held() then return false end
    local np = gNetworkPlayers[0]
    return np ~= nil and np.currAreaSyncValid ~= false
end

function forge.keep_present()
    local out = {}
    local np0 = gNetworkPlayers[0]
    if np0 == nil then return out end
    for li = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[li]

        if np ~= nil and np.connected and np.currLevelNum == np0.currLevelNum
            and np.currAreaIndex == np0.currAreaIndex and np.currAreaSyncValid ~= false
            and (np.currActNum or 0) == (np0.currActNum or 0) then
            out[forge.builder_of(li)] = li
        end
    end
    return out
end

local function rows_out(li, key, texts)
    local parts, current = {}, ""
    for _, item in ipairs(texts) do
        if #item <= forge.KEEP_REPORT_PART then
            local add = current == "" and item or (current .. ";" .. item)
            if #add > forge.KEEP_REPORT_PART then
                table.insert(parts, current)
                current = item
            else
                current = add
            end
        end
    end
    if current ~= "" then table.insert(parts, current) end
    keep.seq = (keep.seq % 999) + 1
    if #parts == 0 then
        table.insert(keep.out, { li = li, data = { ofp = forge.PACKET_KEEP_ROWS, k = key,
            s = keep.seq, i = 0, n = 0 } })
    end
    for i, part in ipairs(parts) do
        table.insert(keep.out, { li = li, data = { ofp = forge.PACKET_KEEP_ROWS, k = key,
            s = keep.seq, i = i, n = #parts, d = part } })
    end
    return #parts
end
forge.keep_rows_out = rows_out

function forge.keep_hand_over(builder, li)
    if not OF.util.is_host() or builder == nil or li == nil or keep.key == nil then return 0 end
    local texts, seen = {}, {}
    local function add(text)
        if text ~= nil and not seen[text] then
            seen[text] = true
            table.insert(texts, text)
        end
    end
    local me = forge.builder_of(0)
    local moved = false
    for i = #forge.placed, 1, -1 do
        local e = forge.placed[i]
        if not e.foreign and e.builder ~= nil and e.builder ~= me and e.builder == builder then
            add(capture_one(e, me))
            if e.object ~= nil and e.object.oSyncID ~= nil then
                keep.given[e.object.oSyncID] = { builder = builder, object = e.object, key = e.key }
            end
            if forge.held == e.object then forge.held, forge.heldKey = nil, nil end
            table.remove(forge.placed, i)
            moved = true
        end
    end
    local carry = {}
    for _, row in ipairs(keep.carry or {}) do
        if row.builder == builder then add(row.text) else table.insert(carry, row) end
    end
    keep.carry = carry
    for _, text in ipairs(keep.reported[builder] or {}) do add(text) end
    keep.reported[builder] = texts
    keep.handed[builder] = true
    if moved then
        forge.publish_sizes()
        forge.publish_reach()
    end
    rows_out(li, keep.key, texts)
    return #texts
end

local function holds_of(builder)
    for _, e in ipairs(forge.placed) do
        if not e.foreign and e.builder == builder then return true end
    end
    return false
end

local function hand_present()
    local present = forge.keep_present()
    local me = forge.builder_of(0)
    for b in pairs(keep.handed) do
        if present[b] == nil then keep.handed[b] = nil end
    end
    for b, li in pairs(present) do
        if b ~= me and (not keep.handed[b] or holds_of(b)) then forge.keep_hand_over(b, li) end
    end
end
forge.keep_hand_present = hand_present

function forge.keep_given(syncId)
    return syncId ~= nil and keep.given[syncId] ~= nil
end

function forge.keep_restore_start(key)
    local rows = forge.keep_parse(forge.keep_read(key))
    keep.carry = {}
    if #rows == 0 then return 0 end
    local standing = {}
    local function live_of(bhv)
        if standing[bhv] == nil then
            local list = {}
            for _, o in pairs(live_by_sync_id(bhv)) do table.insert(list, o) end
            standing[bhv] = list
        end
        return standing[bhv]
    end
    local queue = {}

    local present = OF.util.is_host() and forge.keep_present() or {}
    local me = forge.builder_of(0)
    local filling = {}
    for _, row in ipairs(rows) do
        local entry = OF.spawner.find(row.key)
        local b = row.builder
        if entry ~= nil and b ~= nil and b ~= me and present[b] ~= nil then
            if keep.reported[b] == nil then keep.reported[b], filling[b] = {}, true end
            if filling[b] then table.insert(keep.reported[b], row.text) end
            keep.handed[b] = nil
            entry = nil
        end
        if entry ~= nil then
            local there = false
            for i, o in ipairs(live_of(entry.bhv)) do
                if o ~= false and math.abs(o.oPosX - row.x) <= KEEP_MATCH
                    and math.abs(o.oPosY - row.y) <= KEEP_MATCH
                    and math.abs(o.oPosZ - row.z) <= KEEP_MATCH then
                    standing[entry.bhv][i] = false
                    there = true

                    if not OF.util.has_flag(tonumber(o.coopFlags) or 0, COOP_OBJ_FLAG_NETWORK or 0x1) then
                        local mine = false
                        for _, p in ipairs(forge.placed) do if p.object == o then mine = true end end
                        if not mine then
                            table.insert(forge.placed, { object = o, key = row.key,
                                size = math.floor(row.size or NORMAL_SIZE),
                                builder = row.builder })
                        end
                    else
                        table.insert(keep.carry, row)
                    end
                    break
                end
            end
            if not there then table.insert(queue, row) end
        end
    end
    local room = OF.util.asks(OF.spawner, "free") and OF.spawner.free() or #queue
    keep.skipped = math.max(0, #queue - room)
    while #queue > room do table.remove(queue) end
    keep.queue = queue
    keep.putBack = 0
    return #queue
end

local function keep_one(row)
    local entry = OF.spawner.find(row.key)
    if entry == nil then return nil end
    local was = entry.variants ~= nil and OF.spawner.variant_name(row.key) or nil
    if entry.variants ~= nil then OF.spawner.pick_variant(row.key, row.byte) end
    local o
    if row.pipe ~= nil and entry.pipe then
        o = forge.pipe_spawn(row.key, row.x, row.y, row.z, row.yaw, row.pipe)
    else

        if entry.racer ~= nil then
            forge.racerOrderNext, forge.racerTrackNext, forge.racerMetaNext = row.byte, row.track or 1, row.meta
        end

        local wasLink = OF.logic ~= nil and OF.logic.forgeLink or nil
        if row.link ~= nil and wasLink ~= nil then OF.logic.forgeLink = row.link end
        o = OF.spawner.spawn_at(row.key, row.x, row.y, row.z, row.yaw, row.stretch)
        if wasLink ~= nil then OF.logic.forgeLink = wasLink end
        forge.racerOrderNext, forge.racerTrackNext, forge.racerMetaNext = nil, nil, nil
    end
    if was ~= nil then
        for _, v in ipairs(entry.variants) do
            if v.name == was then OF.spawner.pick_variant(row.key, v.value) break end
        end
    end
    if o == nil then return nil end
    OF.spawner.face(o, row.yaw)
    o.oFaceAnglePitch = row.pitch
    local size = math.floor(row.size or NORMAL_SIZE)
    if size ~= NORMAL_SIZE then apply_size(o, size) end
    table.insert(forge.placed, { object = o, key = row.key, size = size,
        builder = row.builder })
    return o
end

forge.keep_one = keep_one

local function keep_drain()
    local queue = keep.queue
    for _ = 1, keep_pace() do
        local row = table.remove(queue, 1)
        if row == nil then break end
        if keep_one(row) ~= nil then keep.putBack = keep.putBack + 1 end
    end
    if #queue > 0 then return end
    keep.queue = nil
    forge.publish_sizes()
    forge.publish_reach()

    if OF.util.is_host() then hand_present() end

    keep.text = forge.keep_capture()
    if keep.putBack > 0 or keep.skipped > 0 then
        if keep.skipped > 0 then
            OF.notify.show("Put back @ of your kept build; @ had no room", "warn", 5,
                tostring(keep.putBack), tostring(keep.skipped))
        else
            OF.notify.show("Put back your kept build (@)", "info", 3, tostring(keep.putBack))
        end
    end
end

function forge.keep_guest_restore(rows)
    local taken, queue = 0, {}
    local mine = {}
    for _, p in ipairs(forge.placed) do if p.object ~= nil then mine[p.object] = true end end
    local standing = {}
    for _, row in ipairs(rows or {}) do
        local entry = OF.spawner.find(row.key)
        if entry ~= nil then
            if standing[entry.bhv] == nil then
                local list = {}
                for _, o in pairs(live_by_sync_id(entry.bhv)) do table.insert(list, o) end
                standing[entry.bhv] = list
            end
            local found = nil
            for i, o in ipairs(standing[entry.bhv]) do
                if o ~= false and o.activeFlags ~= 0 and math.abs(o.oPosX - row.x) <= KEEP_MATCH
                    and math.abs(o.oPosY - row.y) <= KEEP_MATCH
                    and math.abs(o.oPosZ - row.z) <= KEEP_MATCH then
                    standing[entry.bhv][i] = false
                    found = o
                    break
                end
            end
            if found ~= nil then
                if not mine[found] then
                    mine[found] = true
                    table.insert(forge.placed, { object = found, key = row.key,
                        size = math.floor(row.size or NORMAL_SIZE) })
                    taken = taken + 1
                end
            else
                table.insert(queue, row)
            end
        end
    end
    local room = OF.util.asks(OF.spawner, "free") and OF.spawner.free() or #queue
    while #queue > room do table.remove(queue) end
    guest.queue = #queue > 0 and queue or nil
    guest.putBack = 0
    if taken > 0 then
        forge.publish_sizes()
        forge.publish_reach()
    end
    return taken, #queue
end

local function guest_drain()
    for _ = 1, keep_pace() do
        local row = table.remove(guest.queue, 1)
        if row == nil then break end
        if keep_one(row) ~= nil then guest.putBack = guest.putBack + 1 end
    end
    if #guest.queue > 0 then return end
    guest.queue = nil
    forge.publish_sizes()
    forge.publish_reach()

    guest.sent, guest.pending = forge.keep_capture(), nil
    if guest.putBack > 0 then
        OF.notify.show("Put back your kept build (@)", "info", 3, tostring(guest.putBack))
    end
end
forge.keep_guest_drain = guest_drain

function forge.keep_update()
    keep.frame = keep.frame + 1
    if not OF.util.is_host() then
        forge.keep_guest_update()
        return
    end

    if #keep.out > 0 then
        local item = table.remove(keep.out, 1)
        if item ~= nil then OF.util.send_to_player(item.li, item.data) end
    end

    if keep.frame % 15 == 7 then forge.keep_note_recent() end

    if keep.frame % 30 == 15 and gPlayerSyncTable[0] ~= nil then
        local on = forge.keep_on() and "1" or "0"
        if gPlayerSyncTable[0][forge.KEEP_ON_KEY] ~= on then
            OF.util.publish_row(0, forge.KEEP_ON_KEY, on)
        end
    end

    local np = gNetworkPlayers[0]
    local level, area = np ~= nil and np.currLevelNum or nil, np ~= nil and np.currAreaIndex or nil
    if level ~= keep.atLevel or area ~= keep.atArea then
        keep.atLevel, keep.atArea = level, area
        keep.hereKey = forge.keep_here()
    end
    local here = keep.hereKey
    if here ~= keep.key then

        if keep.key ~= nil and keep.pending ~= nil then forge.keep_write(keep.key, keep.pending) end
        keep.key, keep.pending, keep.restored, keep.queue = here, nil, nil, nil
        keep.carry = {}
        keep.reported, keep.parts = {}, {}
        keep.given, keep.handed = {}, {}
        keep.text = nil
        keep.arrivedAt = keep.frame
        return
    end
    if keep.queue ~= nil then
        if forge.keep_may() then keep_drain() end
        return
    end
    if here == nil then return end

    if keep.restored ~= here then
        if not (forge.keep_synced_here() or keep.frame - keep.arrivedAt >= KEEP_SETTLE) then return end
        if not forge.keep_may() then return end
        keep.restored = here
        keep.text = forge.keep_read(here)
        forge.keep_restore_start(here)
        if keep.queue ~= nil then keep_drain() end
        return
    end
    if keep.frame % 30 ~= 0 then return end
    if not forge.keep_may() then return end

    local racing = forge.racer_round_here ~= nil and forge.racer_round_here()
    if racing then return end
    if keep.frame % KEEP_SCAN == 0 then
        hand_present()
        local now = forge.keep_capture()
        if now ~= keep.text then
            keep.text = now
            keep.pending = now
            keep.changedAt = keep.frame
        end
    end
    if keep.pending ~= nil and keep.frame - keep.changedAt >= KEEP_IDLE then
        forge.keep_write(here, keep.pending)
        keep.pending = nil
    end
end

hook_event(HOOK_UPDATE, forge.keep_update)

function forge.keep_clear_here()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local here = forge.keep_here()
    local cleared, why = forge.clear()
    if cleared == false then return false, why end
    keep.queue = nil
    forge.keep_forget(here)
    keep.text, keep.pending, keep.carry, keep.reported = "", nil, {}, {}
    if OF.util.is_host() and here ~= nil then
        OF.util.tell_all({ ofp = forge.PACKET_KEEP_ALL, k = here })

        if OF.util.asks(OF.logic, "forget_room_wires") then OF.logic.forget_room_wires(here) end
    end
    return true, "This level's build is cleared and forgotten."
end

function forge.keep_clear_builder(key, builder)
    if not OF.util.is_host() or key == nil or builder == nil then return 0 end
    local me = forge.builder_of(0)
    local gone = 0
    if key == keep.key then
        for i = #forge.placed, 1, -1 do
            local e = forge.placed[i]
            if not e.foreign and (e.builder or me) == builder then
                if e.object ~= nil then OF.spawner.take_down(e.object, e.key) end
                table.remove(forge.placed, i)
                gone = gone + 1
            end
        end

        for id, g in pairs(keep.given) do
            if g.builder == builder then
                if g.object ~= nil and g.object.activeFlags ~= 0 and g.object.oSyncID == id then
                    OF.spawner.take_down(g.object, g.key)
                end
                keep.given[id] = nil
            end
        end
        gone = gone + #(keep.reported[builder] or {})
        keep.reported[builder] = nil
        local carry = {}
        for _, row in ipairs(keep.carry or {}) do
            if (row.builder or me) ~= builder then table.insert(carry, row) else gone = gone + 1 end
        end
        keep.carry = carry
        local now = forge.keep_capture()
        keep.text, keep.pending = now, nil
        forge.keep_write(key, now)
        forge.publish_sizes()
        forge.publish_reach()
        return gone
    end
    local kept = {}
    for _, row in ipairs(forge.keep_parse(forge.keep_read(key))) do
        if (row.builder or me) ~= builder then table.insert(kept, row.text) else gone = gone + 1 end
    end
    forge.keep_write(key, table.concat(kept, ";"))
    return gone
end

function forge.keep_clear_mine()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local here = forge.keep_here()
    if here == nil then return false, "Nowhere to clear." end
    if OF.util.is_host() then
        forge.keep_clear_builder(here, forge.builder_of(0))
        return true, "Your build here is cleared and forgotten."
    end
    local cleared, why = forge.clear()
    if cleared == false then return false, why end
    guest.sent, guest.pending, guest.out = "", nil, nil
    OF.util.send_to_host({ ofp = forge.PACKET_KEEP_CLEAR, k = here })
    return true, "Your build here is cleared and forgotten."
end

function forge.keep_guest_update()
    local here = forge.keep_here()

    local hostLi = OF.util.local_from_global(0)
    local hnp = hostLi ~= nil and gNetworkPlayers[hostLi] or nil
    local np = gNetworkPlayers[0]

    local hostHere = hnp ~= nil and np ~= nil and hnp.currLevelNum == np.currLevelNum
        and hnp.currAreaIndex == np.currAreaIndex
        and (hnp.currActNum or 0) == (np.currActNum or 0)
    if hostHere and not guest.hostHere then guest.sent, guest.asked = nil, true end
    guest.hostHere = hostHere
    if here ~= guest.key then

        if guest.key ~= nil and guest.pending ~= nil then forge.keep_report(guest.key, guest.pending) end
        guest.key, guest.pending, guest.sent = here, nil, nil
        guest.changedAt = keep.frame
        guest.arrivedAt = keep.frame
        guest.askedFor, guest.restore, guest.queue, guest.rows = nil, nil, nil, nil
    end
    if guest.out ~= nil then
        local part = table.remove(guest.out, 1)
        if part ~= nil then OF.util.send_to_host(part) end
        if #guest.out == 0 then guest.out = nil end
    end

    local settled = here ~= nil and np ~= nil and np.currAreaSyncValid ~= false
        and (forge.keep_synced_here() or keep.frame - guest.arrivedAt >= KEEP_SETTLE * 2)
    if guest.queue ~= nil then
        if settled and guest_may() then guest_drain() end
        return
    end
    if settled and guest.restore ~= nil and guest_may() then
        local rows = guest.restore
        guest.restore = nil
        forge.keep_guest_restore(rows)
        if guest.queue == nil then guest.sent, guest.pending = forge.keep_capture(), nil end
        return
    end
    if settled and not hostHere and guest.askedFor ~= here and guest_may() then
        guest.askedFor = here
        OF.util.send_to_host({ ofp = forge.PACKET_KEEP_ASK, k = here })
    end
    if here == nil or keep.frame % 30 ~= 0 or not guest_may() then return end
    if keep.frame % KEEP_SCAN == 0 then
        local now = forge.keep_capture()
        if now ~= guest.sent and now ~= guest.pending then

            if not (now == "" and guest.sent == nil) then
                guest.pending, guest.changedAt = now, keep.frame

                if guest.asked then
                    guest.asked = false
                    guest.changedAt = keep.frame - KEEP_IDLE + KEEP_SETTLE * 2
                end
            end
        end
    end
    if guest.pending ~= nil and keep.frame - guest.changedAt >= KEEP_IDLE then
        forge.keep_report(here, guest.pending)
    end
end

function forge.keep_report(key, text)
    local parts, current = {}, ""
    for item in tostring(text or ""):gmatch("[^;]+") do
        if #item <= forge.KEEP_REPORT_PART then
            local add = current == "" and item or (current .. ";" .. item)
            if #add > forge.KEEP_REPORT_PART then
                table.insert(parts, current)
                current = item
            else
                current = add
            end
        end
    end
    if current ~= "" then table.insert(parts, current) end
    guest.seq = (guest.seq % 999) + 1
    guest.out = guest.out or {}
    if #parts == 0 then
        table.insert(guest.out, { ofp = forge.PACKET_KEEP_REPORT, k = key, s = guest.seq,
            i = 0, n = 0 })
    end
    for i, part in ipairs(parts) do
        table.insert(guest.out, { ofp = forge.PACKET_KEEP_REPORT, k = key, s = guest.seq,
            i = i, n = #parts, d = part })
    end
    guest.sent, guest.pending = text, nil
    return #parts
end

function forge.keep_heard(data)
    if not OF.util.is_host() or not forge.keep_on() then return false end
    local li = OF.util.asked_by(data)
    if li == nil then return false end
    local key, n = tostring(data.k or ""), math.floor(tonumber(data.n) or -1)
    if n < 0 or n > forge.KEEP_PARTS * 8 then return false end
    local builder = forge.builder_of(li)
    local got = keep.parts[li]
    if got == nil or got.seq ~= data.s or got.key ~= key then
        got = { seq = data.s, key = key, have = {}, count = 0 }
        keep.parts[li] = got
    end
    local i = math.floor(tonumber(data.i) or 0)
    if n > 0 and (i < 1 or i > n or type(data.d) ~= "string") then return false end
    if n > 0 and got.have[i] == nil then
        got.have[i] = data.d
        got.count = got.count + 1
    end
    if got.count < n then return false end
    keep.parts[li] = nil

    if not forge.keep_was_in(li, key) then return false end
    local rows = {}
    for k = 1, n do
        for item in tostring(got.have[k]):gmatch("[^;]+") do
            table.insert(rows, tagged(item, builder))
        end
    end
    if key == keep.key then

        keep.reported[builder] = rows
        return true
    end

    local kept, dropped = forge.keep_file_away(key, builder, rows)
    if dropped > 0 then
        OF.util.send_to_player(li, { ofp = forge.PACKET_KEEP_ACK, k = key, kept = kept,
            dropped = dropped })
    end
    return true
end

function forge.keep_file_away(key, builder, rows)
    if not OF.util.is_host() or key == nil or builder == nil then return 0, 0 end
    local me = forge.builder_of(0)
    local kept = {}
    for _, row in ipairs(forge.keep_parse(forge.keep_read(key))) do
        if (row.builder or me) ~= builder then table.insert(kept, row.text) end
    end
    local others = #kept
    for _, text in ipairs(rows or {}) do table.insert(kept, text) end
    local count, dropped = forge.keep_write(key, table.concat(kept, ";"), true)
    return math.max(0, count - others), dropped
end

function forge.keep_note_recent()
    for li = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[li]
        if np == nil or not np.connected then
            keep.recent[li] = nil
        else
            local list = keep.recent[li] or {}
            if list.level ~= np.currLevelNum or list.area ~= np.currAreaIndex then
                list.level, list.area = np.currLevelNum, np.currAreaIndex
                local key = forge.keep_key_for(np.currLevelNum, np.currAreaIndex)
                if key ~= nil and list[1] ~= key then
                    table.insert(list, 1, key)
                    while #list > KEEP_RECENT do table.remove(list) end
                end
            end
            keep.recent[li] = list
        end
    end
end

function forge.keep_was_in(li, key)
    if li == nil or key == nil then return false end

    forge.keep_note_recent()
    for _, k in ipairs(keep.recent[li] or {}) do
        if k == key then return true end
    end
    return false
end

function forge.keep_asked(data)
    if not OF.util.is_host() or not forge.keep_on() then return false end
    local li = OF.util.asked_by(data)
    if li == nil or type(data.k) ~= "string" then return false end
    keep.askedAt = keep.askedAt or {}
    if keep.askedAt[li] ~= nil and keep.frame - keep.askedAt[li] < 30 then return false end
    keep.askedAt[li] = keep.frame
    if not forge.keep_was_in(li, data.k) then return false end
    local builder = forge.builder_of(li)
    if data.k == keep.key and keep.restored == keep.key then
        forge.keep_hand_over(builder, li)
        return true
    end
    local texts = {}
    for _, row in ipairs(forge.keep_parse(forge.keep_read(data.k))) do
        if row.builder == builder then table.insert(texts, row.text) end
    end
    rows_out(li, data.k, texts)
    return true
end

function forge.keep_heard_rows(data)
    if OF.util.is_host() or not OF.util.from_host(data) then return false end
    local n = math.floor(tonumber(data.n) or -1)
    if n < 0 or n > forge.KEEP_PARTS * 8 then return false end
    local got = guest.rows
    if got == nil or got.seq ~= data.s or got.key ~= data.k then
        got = { seq = data.s, key = data.k, have = {}, count = 0 }
        guest.rows = got
    end
    local i = math.floor(tonumber(data.i) or 0)
    if n > 0 and (i < 1 or i > n or type(data.d) ~= "string") then return false end
    if n > 0 and got.have[i] == nil then
        got.have[i] = data.d
        got.count = got.count + 1
    end
    if got.count < n then return false end
    guest.rows = nil
    if data.k ~= forge.keep_here() then return false end
    local text = {}
    for k = 1, n do table.insert(text, got.have[k]) end
    guest.restore = forge.keep_parse(table.concat(text, ";"))
    return true
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" then return end
    if data.ofp == forge.PACKET_KEEP_REPORT then
        forge.keep_heard(data)
    elseif data.ofp == forge.PACKET_KEEP_CLEAR then
        if not OF.util.is_host() then return end
        local li = OF.util.asked_by(data)
        if li == nil or type(data.k) ~= "string" then return end
        forge.keep_clear_builder(data.k, forge.builder_of(li))
    elseif data.ofp == forge.PACKET_KEEP_ASK then
        forge.keep_asked(data)
    elseif data.ofp == forge.PACKET_KEEP_ROWS then
        forge.keep_heard_rows(data)
    elseif data.ofp == forge.PACKET_KEEP_ACK then
        if not OF.util.from_host(data) then return end
        OF.notify.show("The host kept @ of your things there; the rest did not fit", "warn", 5,
            tostring(math.floor(tonumber(data.kept) or 0)))
    elseif data.ofp == forge.PACKET_KEEP_YOURS then

        if not OF.util.from_host(data) then return end
        if data.k ~= forge.keep_here() then return end
        OF.util.report(forge.clear())
        guest.sent, guest.pending, guest.out = "", nil, nil
        OF.notify.show("The host cleared your pieces here", "warn", 4)
    elseif data.ofp == forge.PACKET_KEEP_ALL then

        if not OF.util.from_host(data) then return end

        if data.k ~= forge.keep_here() and data.k ~= "*" then return end
        OF.util.report(forge.clear())
        guest.sent, guest.pending, guest.out = "", nil, nil
    end
end)

function forge.keep_rows(panel, rows)
    if not OF.util.is_host() then
        table.insert(rows, panel.label_row(OF.lang.t(forge.keep_on()
            and "The host keeps what you build in every level"
            or "The host is not keeping builds")))
        return
    end
    local list = forge.keep_list()
    table.insert(rows, panel.with_help(panel.with_right(panel.row(
        panel.tick(forge.keep_on(), OF.lang.t("Keep what I build in each level")),
        255, 255, 255, function() OF.util.report(forge.keep_toggle()) end),
        OF.lang.fill("@ kept", tostring(#list))),
        OF.lang.t("put back when you come in; written when you leave")))
end

function forge.clear_player(localIndex)
    if not OF.util.is_host() then return false, "Only the host clears somebody else's pieces." end
    if localIndex == nil or localIndex == 0 then return forge.keep_clear_mine() end
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false, "That player is not here." end
    local here = forge.keep_here()
    if here == nil then return false, "Nowhere to clear." end
    forge.keep_clear_builder(here, forge.builder_of(localIndex))
    OF.util.send_to_player(localIndex, { ofp = forge.PACKET_KEEP_YOURS, k = here })
    return true, OF.lang.fill("@'s pieces here are cleared", tostring(np.name or "?"))
end

function forge.put_back_said()
    local ok, put, lost = forge.put_back_all()
    if not ok then
        OF.util.report(false, put)
    elseif (lost or 0) > 0 then

        OF.notify.show("Put @ back - @ had been broken meanwhile", "warn", 5, put, lost)
    else
        OF.notify.show("Put @ of the level's own back", "good", 4, put)
    end
    return ok
end

function forge.reset_everywhere()
    if not OF.util.is_host() then return false, "Only the host resets the Forge everywhere." end
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local cleared, why = forge.clear()
    if cleared == false then return false, why end
    keep.queue = nil
    keep.text, keep.pending, keep.carry, keep.reported = "", nil, {}, {}
    local levels = 0
    for _, e in ipairs(index_read()) do
        forge.keep_forget(e.key)
        levels = levels + 1
    end
    local here = forge.keep_here()
    if here ~= nil then forge.keep_forget(here) end

    if OF.util.asks(OF.logic, "forget_all_wires") then OF.logic.forget_all_wires() end
    OF.util.tell_all({ ofp = forge.PACKET_KEEP_ALL, k = "*" })
    return true, OF.lang.fill("The Forge is reset: every piece here and @ kept build(s) gone",
        tostring(levels))
end

function forge.pieces_here()
    if OF.util.is_host() then
        local _, count = forge.keep_capture()
        return count
    end
    return forge.count()
end

forge.KEEP_ROW_CHARS = 48
forge.KEEP_ROOM_GUESS = math.floor(forge.KEEP_PARTS * forge.KEEP_PART / forge.KEEP_ROW_CHARS)

function forge.keep_room(key, count)
    local used = #(forge.keep_read(key) or "")
    count = count or 0
    local each = count > 0 and math.max(1, used / count) or forge.KEEP_ROW_CHARS
    return math.max(0, math.floor((forge.KEEP_PARTS * forge.KEEP_PART - used) / each))
end

function forge.overview()
    local out, seen = {}, {}
    local counts = {}
    for _, e in ipairs(index_read()) do counts[e.key] = e.count end
    local here = forge.keep_here()
    local function add(level, area, name, group)
        local key = forge.keep_key_for(level, area)
        if key == nil or seen[key] then return end
        seen[key] = true
        local entry = { key = key, name = name, group = group, level = level, area = area,
            here = key == here, kept = counts[key] ~= nil }
        if entry.here then
            entry.pieces = forge.pieces_here()
            entry.left = forge.headroom() or 0
        else
            entry.pieces = counts[key] or 0
            entry.left = forge.keep_room(key, entry.pieces)
        end
        table.insert(out, entry)
    end
    for _, e in ipairs(OF.LEVELS or {}) do
        if type(e.level) == "number" then add(e.level, e.area or 1, e.name, e.group or "Courses") end
    end

    local V = OF.venues
    if V ~= nil and type(V.LAYOUTS) == "table" and OF.util.asks(V, "place_of") then
        local keys = {}
        for key in pairs(V.LAYOUTS) do keys[#keys + 1] = key end
        table.sort(keys)
        local bonus = {}
        for _, key in ipairs(keys) do
            local place = V.place_of(key)
            if place ~= nil and type(place.level) == "number" then
                local name = OF.util.asks(OF.arena, "name_of") and OF.arena.name_of(key) or key
                bonus[#bonus + 1] = { level = place.level, area = place.area or 1, name = tostring(name) }
            end
        end
        table.sort(bonus, function(a, b) return a.name < b.name end)
        for _, b in ipairs(bonus) do add(b.level, b.area, b.name, "Studio bonus courses") end
    end
    for _, e in ipairs(forge.keep_list()) do
        if not seen[e.key] then
            seen[e.key] = true
            table.insert(out, { key = e.key, name = e.name, group = "Other levels",
                pieces = e.count, left = forge.keep_room(e.key, e.count), kept = true,
                here = e.key == here })
        end
    end
    return out
end

function forge.kept_page(panel)
    local rows = {}
    local shut = {}
    if not OF.util.is_host() then
        table.insert(rows, panel.label_row(OF.lang.t("The host keeps the builds and sees every level")))
        table.insert(rows, panel.back_row())
        return rows, shut
    end
    local group = nil
    for _, e in ipairs(forge.overview()) do
        if e.group ~= group and (e.group == "Studio bonus courses" or e.group == "Other levels") then

            local label = panel.label_row(OF.lang.t(e.group))
            label.outside = true
            table.insert(rows, label)
        end
        group = e.group
        local head = panel.with_right(panel.header_row(e.name),
            OF.lang.fill(e.pieces == 1 and "@ piece, @ left" or "@ pieces, @ left",
                tostring(e.pieces), tostring(e.left)))
        head.help = OF.lang.t(e.here and "standing here, and the space the lobby has left"
            or "kept for this level, and the space left in its save")
        table.insert(rows, head)
        shut[#shut + 1] = e.name
        if e.here then
            table.insert(rows, panel.with_help(panel.gated_confirm_row("spawn_object",
                "forgekepthere", OF.lang.t("Clear this level's build"), 255, 200, 140,
                function() OF.util.report(forge.keep_clear_here()) end),
                OF.lang.t("everybody's pieces here, taken down and forgotten")))
        elseif e.kept then
            local key, name = e.key, e.name
            table.insert(rows, panel.with_help(panel.gated_confirm_row(
                "spawn_object", "forgeforget" .. key, OF.lang.t("Forget this level's build"),
                255, 200, 140, function()
                    forge.keep_forget(key)
                    if OF.util.asks(OF.logic, "forget_room_wires") then OF.logic.forget_room_wires(key) end
                    OF.notify.show("Forgot the build kept in @", "info", 3, name)
                end),
                OF.lang.t("forgets the build kept in that level")))
        else
            table.insert(rows, panel.label_row(OF.lang.t("Nothing is kept here")))
        end
    end
    if OF.panel ~= nil and OF.panel.PAGES ~= nil and OF.panel.PAGES.forgekept ~= nil then
        OF.panel.PAGES.forgekept.shutOnArrival = shut
    end
    table.insert(rows, panel.back_row())
    return rows, shut
end

function forge.clear_page(panel)
    local rows = {}
    local host = OF.util.is_host()

    table.insert(rows, panel.with_help(panel.gated_confirm_row("spawn_object", "forgeclear",
        OF.lang.t("Remove Forge pieces in this level"),
        255, 140, 90, function() OF.util.report(forge.clear()) end),
        OF.lang.t("what the Forge put down here comes down; the level's own stay")))
    table.insert(rows, panel.with_help(panel.gated_confirm_row("spawn_object", "forgeclearmine",
        OF.lang.t("Clear my build here"), 255, 200, 140,
        function() OF.util.report(forge.keep_clear_mine()) end),
        OF.lang.t("your pieces here come down, and the kept copy is forgotten")))
    local moved = forge.borrowed_count()
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object",
        OF.lang.t("Bring back the level's own objects"), 255, 200, 140,
        function() forge.put_back_said() end), tostring(moved)),
        OF.lang.t("the level's own things that were moved go back where they stood")))
    if host then
        table.insert(rows, panel.with_help(panel.gated_confirm_row("spawn_object",
            "forgeclearlevel", OF.lang.t("Clear this level's build (everybody's)"), 255, 200, 140,
            function() OF.util.report(forge.keep_clear_here()) end),
            OF.lang.t("everybody's pieces here, taken down and forgotten")))
        table.insert(rows, panel.with_help(panel.with_right(panel.row(
            OF.lang.t("Builds in every level..."), 255, 255, 255,
            function() panel.go("forgekept") end), tostring(#forge.keep_list())),
            OF.lang.t("every course and bonus course: pieces, space left, and forgetting one")))
        table.insert(rows, panel.with_help(panel.with_tone(panel.gated_confirm_row("spawn_object",
            "forgeresetall", OF.lang.t("Reset Forge everywhere"), 255, 140, 90,
            function() OF.util.report(forge.reset_everywhere()) end), "danger"),
            OF.lang.t("every Forge piece and every kept build, in every level - press twice")))

        local any = false
        for li = 1, MAX_PLAYERS - 1 do
            local np = gNetworkPlayers[li]
            if np ~= nil and np.connected then
                if not any then
                    table.insert(rows, panel.header_row(OF.lang.t("One player's pieces")))
                    any = true
                end
                table.insert(rows, panel.with_help(panel.gated_confirm_row("spawn_object",
                    "forgeclearp" .. li, OF.lang.fill("Clear @'s pieces here", tostring(np.name)),
                    255, 200, 140, function() OF.util.report(forge.clear_player(li)) end),
                    OF.lang.t("that player's pieces here, taken down and forgotten")))
            end
        end
    end
    table.insert(rows, panel.back_row())
    return rows
end
end

do
forge.RACER_KINDS = { start = 1, gate = 2, finish = 3, box = 4, boost = 5,
    coin = 6, respawn = 7, out = 8 }
forge.RACER_KEYS = { racestart = 1, racegate = 2, racefinish = 3, racebox = 4,
    raceboost = 5, racecoin = 6, racerespawn = 7, raceout = 8 }
forge.RACER_KEY_OF = {}
for key, kind in pairs(forge.RACER_KEYS) do forge.RACER_KEY_OF[kind] = key end
forge.RACER_PUBLISH = "ofFtk"
forge.RACER_PUBLISH_PARTS = 8
forge.RACER_PART = 240

forge.TRACK_INDEX_PUBLISH = "ofFtx"
forge.RACER_INDEX = "fkrace"
forge.RACER_BEST = "fkbest"
forge.PACKET_RACER_ORDER = "racerord"
forge.PACKET_TRACK_META = "trackmeta"
forge.RACER_GATES_FEWEST = 3

forge.RACER_GATE_WIDTH = 16
forge.RACER_START_BACK = 300
forge.RACER_BOOST_R = 300

forge.RACER_OUT_R, forge.RACER_OUT_H = 4, 6
forge.TRACK_SPEEDRUN, forge.TRACK_RACE = "speedrun", "race"
forge.TRACK_KIND_NAMES = { speedrun = "Speedrun track", race = "Shell Racer track" }
forge.TRACK_MOST = 9
forge.TRACK_NAME_MOST = 20
forge.TRACK_LAPS_MOST = 9
forge.TRACK_LAPS = 3

forge.TRACK_FIELD = 0x70

local K = forge.RACER_KINDS
local pub = { frame = 0, text = nil, index = nil, seen = {}, round = nil, cache = {} }
forge.racerState = pub
forge.trackPick = 1
forge.trackKindPick = forge.TRACK_SPEEDRUN

local function round_num(v) return math.floor((tonumber(v) or 0) + 0.5) end

local function piece_kind(o)
    if o == nil then return 0 end
    return math.floor((tonumber(o.oBehParams) or 0) / 0x1000000) % 0x100
end
forge.racer_kind_of = piece_kind

local function piece_track(o)
    if o == nil then return 1 end
    local n = math.floor((tonumber(o.oBehParams) or 0) / 0x100) % 0x100
    return n > 0 and n or 1
end
forge.racer_track_of = piece_track

local function params_of(kind, order, track)
    return (kind << 24) | ((order % 0x100) << 16) | ((track % 0x100) << 8)
end

function forge.track_clean_name(text)
    local s = tostring(text or ""):gsub("[^%w %-%.!'?]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("%s+", " ")
    if #s > forge.TRACK_NAME_MOST then s = s:sub(1, forge.TRACK_NAME_MOST) end
    return s
end

function forge.track_default_meta(track)
    return { name = OF.lang.fill("Track @", tostring(track or 1)),
        kind = forge.trackKindPick or forge.TRACK_SPEEDRUN, laps = forge.TRACK_LAPS }
end

forge.TRACK_KIND_CODE = { speedrun = 1, race = 2 }
forge.TRACK_CODE_KIND = { [1] = "speedrun", [2] = "race" }

local function field_set(o, offset, value)
    if type(obj_set_field_s32) ~= "function" then return end
    obj_set_field_s32(o, forge.TRACK_FIELD + offset, math.floor(value))
end

local function field_get(o, offset)
    if type(obj_get_field_s32) ~= "function" then return 0 end
    return math.floor(tonumber(obj_get_field_s32(o, forge.TRACK_FIELD + offset)) or 0)
end

function forge.track_meta_write(o, meta)
    if o == nil or meta == nil then return end
    local name = forge.track_clean_name(meta.name)
    local laps = math.max(1, math.min(forge.TRACK_LAPS_MOST, math.floor(tonumber(meta.laps) or forge.TRACK_LAPS)))
    field_set(o, 0, laps + (forge.TRACK_KIND_CODE[meta.kind] or 1) * 0x100 + #name * 0x10000)
    for word = 0, 4 do
        local v = 0
        for j = 4, 1, -1 do v = v * 0x100 + (name:byte(word * 4 + j) or 0) end
        field_set(o, 1 + word, v)
    end
end

function forge.track_meta_read(o)
    if o == nil then return nil end
    local head = field_get(o, 0)
    local kind = forge.TRACK_CODE_KIND[math.floor(head / 0x100) % 0x100]
    if kind == nil then return nil end
    local len = math.floor(head / 0x10000) % 0x100
    local chars = {}
    for word = 0, 4 do
        local v = field_get(o, 1 + word)
        for _ = 1, 4 do
            local c = v % 0x100
            if c > 0 then chars[#chars + 1] = string.char(c) end
            v = math.floor(v / 0x100)
        end
    end
    local name = table.concat(chars):sub(1, len)
    return { name = name, kind = kind, laps = math.max(1, head % 0x100) }
end

function forge.track_field(o, key)
    if forge.RACER_KEYS[key] == nil or o == nil then return nil end
    local text = "~" .. piece_track(o)
    if piece_kind(o) == K.start then
        local meta = forge.track_meta_read(o)
        if meta ~= nil then
            text = text .. ":" .. (meta.kind == forge.TRACK_RACE and "r" or "s") .. ":"
                .. meta.laps .. ":" .. meta.name
        end
    end
    return text
end

function forge.track_field_read(text)
    local track, rest = tostring(text or ""):match("^(%d+)(.*)$")
    if track == nil then return nil, nil end
    local k, laps, name = rest:match("^:([sr]):(%d+):(.*)$")
    local meta = nil
    if k ~= nil then
        meta = { kind = k == "r" and forge.TRACK_RACE or forge.TRACK_SPEEDRUN,
            laps = tonumber(laps) or forge.TRACK_LAPS, name = forge.track_clean_name(name) }
    end
    return math.max(1, tonumber(track) or 1), meta
end

function forge.racer_setup(o, entry)
    local kind = math.floor(tonumber(entry ~= nil and entry.racer) or 0)
    local track = math.max(1, math.min(255, math.floor(tonumber(forge.racerTrackNext)
        or tonumber(forge.trackPick) or 1)))
    local order = 0
    if kind == K.gate then
        order = tonumber(forge.racerOrderNext)
        if order == nil then
            order = 0
            for _, p in ipairs(forge.racer_pieces_here()) do
                if p.kind == K.gate and p.track == track and p.object ~= o and p.order > order then
                    order = p.order
                end
            end
            order = order + 1
        end
        order = math.max(1, math.min(255, math.floor(order)))
    end
    o.oBehParams2ndByte = order
    o.oBehParams = params_of(kind, order, track)
    if kind == K.start then
        forge.track_meta_write(o, forge.racerMetaNext or forge.track_default_meta(track))
    end
end

function forge.racer_pieces_here()
    local out = {}
    local bhv = OF.spawner ~= nil and OF.spawner.RACER or nil
    if bhv == nil or OF.util.binding("obj_get_first_with_behavior_id") == nil then return out end
    local o = obj_get_first_with_behavior_id(bhv)
    local guard = 0
    while o ~= nil and guard < 512 do
        guard = guard + 1
        local k = piece_kind(o)
        if o.activeFlags ~= 0 and k >= K.start and k <= K.out then
            local p = { kind = k, order = math.floor(tonumber(o.oBehParams2ndByte) or 0) % 0x100,
                track = piece_track(o),
                x = o.oPosX, y = o.oPosY, z = o.oPosZ,
                yaw = math.floor(tonumber(o.oFaceAngleYaw) or 0) % 0x10000, object = o }
            if k == K.start then p.meta = forge.track_meta_read(o) end
            table.insert(out, p)
        end
        o = obj_get_next_with_same_behavior_id(o)
    end
    return out
end

function forge.racer_pieces_of_rows(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
        local k = forge.RACER_KEYS[row.key]
        if k ~= nil then
            table.insert(out, { kind = k, order = math.floor(row.byte or 0) % 0x100,
                track = row.track or 1, meta = row.meta,
                x = row.x, y = row.y, z = row.z, yaw = math.floor(row.yaw or 0) % 0x10000 })
        end
    end
    return out
end

function forge.racer_pieces_of_markers(markers)
    local out, gates = {}, {}
    for _, m in ipairs(markers or {}) do
        local kind, num = tonumber(m[1]), tonumber(m[2]) or 0
        if kind == 16 then gates[num] = m
        elseif kind == 32 then
            table.insert(out, { kind = K.box, order = 0, x = m[5], y = m[6], z = m[7], yaw = 0 })
        elseif kind == 33 then
            table.insert(out, { kind = K.coin, order = 0, x = m[5], y = m[6], z = m[7], yaw = 0 })
        elseif kind == 64 then
            table.insert(out, { kind = K.boost, order = 0, x = m[5], y = m[6], z = m[7], yaw = 0 })
        end
    end
    local count = 0
    while gates[count] ~= nil do count = count + 1 end
    if count < 2 then return out end
    for n = 0, count - 1 do
        local g = gates[n]
        if n == 0 then
            local a, b = gates[count - 1], gates[1]
            local yaw = atan2s ~= nil and (atan2s(b[7] - a[7], b[5] - a[5]) or 0) or 0
            table.insert(out, { kind = K.start, order = 0, x = g[5], y = g[6], z = g[7],
                yaw = math.floor(yaw) % 0x10000 })
        else

            local yaw
            local shipped = tonumber(g[8])
            if shipped ~= nil and (math.floor(tonumber(g[4]) or 0) & 2) ~= 0 then
                yaw = shipped
            else
                local a, b = gates[n - 1], gates[(n + 1) % count]
                yaw = atan2s ~= nil and (atan2s(b[7] - a[7], b[5] - a[5]) or 0) or 0
            end
            table.insert(out, { kind = K.gate, order = n, x = g[5], y = g[6], z = g[7],
                yaw = math.floor(yaw) % 0x10000, ownYaw = true })
        end
    end
    return out
end

function forge.racer_by_order(a, b)
    if a.order ~= b.order then return a.order < b.order end
    if a.x ~= b.x then return a.x < b.x end
    return a.z < b.z
end

function forge.racer_shape(pieces, track)
    local shape = { starts = {}, finishes = {}, gates = {}, boxes = {}, boosts = {},
        coins = {}, respawns = {}, outs = {} }
    local list = { [K.start] = shape.starts, [K.finish] = shape.finishes, [K.gate] = shape.gates,
        [K.box] = shape.boxes, [K.boost] = shape.boosts, [K.coin] = shape.coins,
        [K.respawn] = shape.respawns, [K.out] = shape.outs }
    for _, p in ipairs(pieces or {}) do
        if (track == nil or (p.track or 1) == track) and list[p.kind] ~= nil then
            table.insert(list[p.kind], p)
        end
    end
    if #shape.starts == 0 then return nil, "No start ring here." end
    if #shape.starts > 1 then return nil, "Two start rings in one track - take one away." end
    if #shape.finishes > 1 then return nil, "Two finish flags in one track - take one away." end
    table.sort(shape.gates, forge.racer_by_order)
    shape.start = shape.starts[1]
    shape.finish = shape.finishes[1]
    shape.track = track or shape.start.track or 1
    local meta = shape.start.meta or forge.track_default_meta(shape.track)
    shape.name = meta.name ~= "" and meta.name or OF.lang.fill("Track @", tostring(shape.track))
    shape.kind = meta.kind or forge.TRACK_SPEEDRUN
    shape.laps = meta.laps or forge.TRACK_LAPS
    return shape
end

forge.NO_TRACKS = setmetatable({}, { __newindex = function()
    error("forge.NO_TRACKS is shared and read-only", 2)
end })
function forge.tracks_of(pieces)
    if pieces == nil or next(pieces) == nil then return forge.NO_TRACKS end
    local numbers, seen = {}, {}
    for _, p in ipairs(pieces or {}) do
        local n = p.track or 1
        if not seen[n] then seen[n] = true table.insert(numbers, n) end
    end
    table.sort(numbers)
    local out = {}
    for _, n in ipairs(numbers) do
        local shape, why = forge.racer_shape(pieces, n)
        table.insert(out, { track = n, shape = shape, why = why })
    end
    return out
end

function forge.racer_problem(shape)
    if shape == nil then return nil end
    if shape.kind == forge.TRACK_RACE then
        if #shape.gates < forge.RACER_GATES_FEWEST then
            return OF.lang.fill("A Shell Racer track needs @ gates - @ laid.",
                tostring(forge.RACER_GATES_FEWEST), tostring(#shape.gates))
        end
        return nil
    end
    if shape.finish == nil then return OF.lang.t("A speedrun track needs a finish flag.") end
    return nil
end

function forge.track_ready(shape)
    return shape ~= nil and forge.racer_problem(shape) == nil
end

function forge.track_facing(shape)
    if shape == nil or shape.start == nil then return 0 end
    local s = shape.start
    local to = shape.gates[1] or shape.finish
    if to ~= nil and atan2s ~= nil and (math.abs(to.x - s.x) + math.abs(to.z - s.z)) > 1 then
        return math.floor(atan2s(to.z - s.z, to.x - s.x) or 0) % 0x10000
    end
    return math.floor(tonumber(s.yaw) or 0) % 0x10000
end

function forge.racer_text(level, area, shape)
    if shape == nil then return nil end
    local function pt(p, withYaw)
        local t = round_num(p.x) .. "," .. round_num(p.y) .. "," .. round_num(p.z)
        if withYaw then t = t .. "," .. (round_num(p.yaw) % 0x10000) end
        return t
    end
    local function list(items, withYaw)
        local out = {}
        for _, p in ipairs(items or {}) do table.insert(out, pt(p, withYaw)) end
        return table.concat(out, ";")
    end
    return tostring(level) .. "," .. tostring(area) .. "," .. tostring(shape.track or 1) .. ","
        .. tostring(shape.laps or forge.TRACK_LAPS) .. "|" .. pt(shape.start, true) .. "|"
        .. list(shape.gates) .. "|" .. list(shape.boxes) .. "|" .. list(shape.boosts, true)
        .. "|" .. list(shape.coins) .. "|" .. list(shape.respawns) .. "|" .. list(shape.outs)
end

local function read_pt(text)
    local n = {}
    for v in tostring(text or ""):gmatch("[^,]+") do table.insert(n, tonumber(v)) end
    if n[1] == nil or n[2] == nil or n[3] == nil then return nil end
    return { x = n[1], y = n[2], z = n[3], yaw = n[4] or 0 }
end

function forge.racer_read(text)
    if type(text) ~= "string" or text == "" then return nil end
    local parts = {}
    for part in (text .. "|"):gmatch("([^|]*)|") do table.insert(parts, part) end
    if #parts ~= 8 then return nil end
    local l, a, tr, laps = parts[1]:match("^(%-?%d+),(%-?%d+),(%d+),(%d+)$")
    local s = read_pt(parts[2])
    if l == nil or s == nil then return nil end
    local t = { level = tonumber(l), area = tonumber(a), track = tonumber(tr),
        laps = tonumber(laps), start = s }
    for i, name in ipairs({ "gates", "boxes", "boosts", "coins", "respawns", "outs" }) do
        t[name] = {}
        for piece in parts[i + 2]:gmatch("[^;]+") do
            local p = read_pt(piece)
            if p ~= nil then table.insert(t[name], p) end
        end
    end
    return t
end

local function facing(yaw)
    local a = (tonumber(yaw) or 0) * math.pi / 0x8000
    return math.sin(a), math.cos(a)
end

function forge.racer_ready(t)
    if t == nil or t.start == nil then return nil end
    local nx, nz = facing(t.start.yaw)
    local ft = { level = t.level, area = t.area, track = t.track, laps = t.laps,
        start = { x = t.start.x, y = t.start.y, z = t.start.z, yaw = t.start.yaw, nx = nx, nz = nz },
        gates = t.gates, fewest = forge.RACER_GATES_FEWEST + 1 }
    local m = {}
    local function mk(kind, num, a, b, p, yaw)
        table.insert(m, { kind = kind, num = num, a = a, b = b, x = p.x, y = p.y, z = p.z,
            yaw = yaw or 0 })
    end
    mk(1, 0, 12, 4, { x = t.start.x - nx * forge.RACER_START_BACK, y = t.start.y,
        z = t.start.z - nz * forge.RACER_START_BACK })
    mk(3, math.max(1, math.min(255, t.laps or forge.TRACK_LAPS)), 0, 0, t.start)

    mk(16, 0, forge.RACER_GATE_WIDTH, 2, t.start, t.start.yaw)

    for i, g in ipairs(t.gates) do
        local yaw = math.floor(g.yaw or 0) % 0x10000
        if yaw ~= 0 then
            mk(16, i, forge.RACER_GATE_WIDTH, 2, g, yaw)
        else
            mk(16, i, forge.RACER_GATE_WIDTH, 0, g)
        end
    end

    local all = { t.start }
    for _, g in ipairs(t.gates) do table.insert(all, g) end
    for _, r in ipairs(t.respawns or {}) do
        local best, bestD = 0, math.huge
        for i, g in ipairs(all) do
            local d = (g.x - r.x) ^ 2 + (g.z - r.z) ^ 2
            if d < bestD then best, bestD = i - 1, d end
        end
        mk(18, best, 0, 0, r)
    end
    for _, b in ipairs(t.boxes or {}) do mk(32, 1, 0, 0, b) end
    for _, c in ipairs(t.coins or {}) do mk(33, 0, 0, 0, c) end
    for _, b in ipairs(t.boosts or {}) do mk(64, 0, 6, 4, b) end
    for _, o in ipairs(t.outs or {}) do mk(80, 0, forge.RACER_OUT_R, forge.RACER_OUT_H, o) end
    ft.markers = m
    return ft
end

function forge.racer_sum(text)
    local s = 0
    for i = 1, #text do s = (s * 31 + text:byte(i)) % 999983 end
    return s
end

local function publish_parts(prefix, text)
    if not OF.util.is_host() then return false end
    if text ~= nil and #text > forge.RACER_PART * forge.RACER_PUBLISH_PARTS then return false end
    local parts = {}
    if text ~= nil and text ~= "" then
        for i = 1, #text, forge.RACER_PART do table.insert(parts, text:sub(i, i + forge.RACER_PART - 1)) end
    end
    for i = 1, forge.RACER_PUBLISH_PARTS do
        OF.util.publish_row(0, prefix .. i, parts[i])
    end
    OF.util.publish_row(0, prefix .. "N", #parts > 0
        and (#parts .. ":" .. #text .. ":" .. forge.racer_sum(text)) or nil)
    return true
end

local function host_row()
    local li = OF.util.is_host() and 0 or OF.util.local_from_global(0)
    return li ~= nil and gPlayerSyncTable[li] or nil
end

local function read_parts(prefix)
    local row = host_row()
    if row == nil then return nil end
    local n, len, sum = tostring(row[prefix .. "N"] or ""):match("^(%d+):(%d+):(%d+)$")
    if n == nil then return nil end
    local parts = {}
    for i = 1, tonumber(n) do
        local part = row[prefix .. i]
        if type(part) ~= "string" then return nil end
        table.insert(parts, part)
    end
    local text = table.concat(parts)
    if #text ~= tonumber(len) or forge.racer_sum(text) ~= tonumber(sum) then return nil end
    return text
end

function forge.racer_publish(text)
    if not publish_parts(forge.RACER_PUBLISH, text) then return false end
    pub.text = text
    return true
end

function forge.racer_published()
    return read_parts(forge.RACER_PUBLISH)
end

function forge.racer_track(level, area)
    local t = forge.racer_read(forge.racer_published())
    if t == nil or t.level ~= level or t.area ~= (area or 1) then return nil end
    return forge.racer_ready(t)
end

function forge.racer_index(key, text)
    if key == nil then return end
    local has = type(text) == "string" and text:find("racestart,", 1, true) ~= nil
    local list, found = {}, false
    for k in tostring(OF.util.stored(forge.RACER_INDEX, "") or ""):gmatch("[%w]+") do
        if k == key then found = true end
        if k ~= key or has then table.insert(list, k) end
    end
    if has and not found then table.insert(list, key) end
    if has == found then return end
    if #list == 0 then OF.util.clear(forge.RACER_INDEX)
    else OF.util.store_soon(forge.RACER_INDEX, table.concat(list, ",")) end
end

local function pieces_of_level(level, area)
    local np = gNetworkPlayers[0]
    if np ~= nil and np.currLevelNum == level and np.currAreaIndex == area then
        local live = forge.racer_pieces_here()
        if #live > 0 then return live end
    end
    local key = forge.keep_key_for(level, area)

    return key ~= nil and forge.racer_pieces_of_rows(forge.keep_parse(forge.keep_read(key))) or {}
end

function forge.racer_shape_of(level, area, track)
    local pieces = pieces_of_level(level, area)
    if #pieces == 0 then return nil end
    for _, t in ipairs(forge.tracks_of(pieces)) do
        if (track == nil or t.track == track) and t.shape ~= nil
            and t.shape.kind == forge.TRACK_RACE and forge.track_ready(t.shape) then
            return t.shape
        end
    end
    return nil
end

function forge.track_index_entry(key, shape)
    local s = shape.start
    return table.concat({ key, shape.track, shape.kind == forge.TRACK_RACE and "r" or "s",
        shape.laps or forge.TRACK_LAPS, round_num(s.x), round_num(s.y), round_num(s.z),
        forge.track_facing(shape), forge.track_ready(shape) and 1 or 0, shape.name }, ":")
end

function forge.track_index_text()
    local keys, seen = {}, {}
    local here = forge.keep_here()
    for k in tostring(OF.util.stored(forge.RACER_INDEX, "") or ""):gmatch("[%w]+") do
        if not seen[k] then seen[k] = true table.insert(keys, k) end
    end
    if here ~= nil and not seen[here] then table.insert(keys, here) end
    table.sort(keys)
    local out = {}
    for _, key in ipairs(keys) do
        local pieces
        if key == here then pieces = forge.racer_pieces_here() end
        if pieces == nil or #pieces == 0 then
            local kept = forge.keep_read(key)
            local c = pub.cache[key]
            if c == nil or c.text ~= kept then
                c = { text = kept, pieces = forge.racer_pieces_of_rows(forge.keep_parse(kept)) }
                pub.cache[key] = c
            end
            pieces = c.pieces
        end
        for _, t in ipairs(forge.tracks_of(pieces)) do
            if t.shape ~= nil then table.insert(out, forge.track_index_entry(key, t.shape)) end
        end
    end
    return table.concat(out, ";")
end

local function read_index(text)
    local out = {}
    for item in tostring(text or ""):gmatch("[^;]+") do
        local key, tr, k, laps, x, y, z, face, ready, name = item:match(
            "^([%w]+):(%d+):([sr]):(%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%d+):([01]):(.*)$")
        if key ~= nil then
            local id, area = key:match("^(.-)a(%d+)$")
            local level = id ~= nil and forge.keep_level_of_id(id) or nil
            if level ~= nil then
                table.insert(out, { key = key, level = level, area = tonumber(area) or 1,
                    track = tonumber(tr), kind = k == "r" and forge.TRACK_RACE or forge.TRACK_SPEEDRUN,
                    laps = tonumber(laps), name = name, ready = ready == "1",
                    start = { x = tonumber(x), y = tonumber(y), z = tonumber(z) },
                    face = tonumber(face) or 0 })
            end
        end
    end
    return out
end
forge.track_index_read = read_index

function forge.track_index()
    local list = read_index(OF.util.is_host() and forge.track_index_text() or read_parts(forge.TRACK_INDEX_PUBLISH))
    if OF.util.is_host() then return list end
    local here = forge.keep_here()
    if here == nil then return list end
    local live = forge.racer_pieces_here()
    if #live == 0 then return list end
    local out = {}
    for _, e in ipairs(list) do if e.key ~= here then table.insert(out, e) end end
    for _, t in ipairs(forge.tracks_of(live)) do
        if t.shape ~= nil then
            for _, e in ipairs(read_index(forge.track_index_entry(here, t.shape))) do table.insert(out, e) end
        end
    end
    return out
end

function forge.racer_levels()
    local out = {}
    for _, e in ipairs(forge.track_index()) do
        if e.kind == forge.TRACK_RACE and e.ready then table.insert(out, e) end
    end
    return out
end

function forge.racer_round_here()
    if not OF.util.asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    if mode == nil or mode.forgeTracks ~= true or OF.gamemodes.state() == OF.gamemodes.OFF then
        return false
    end
    local at = OF.gamemodes.round_place()
    local np = gNetworkPlayers[0]
    if at == nil or np == nil or at.level ~= np.currLevelNum or at.area ~= np.currAreaIndex then
        return false
    end
    return forge.racer_track(at.level, at.area) ~= nil
end

function forge.racer_best_key(key, track)
    if key == nil then return nil end
    return key .. "t" .. tostring(track or 1)
end

local function best_read(key)
    local out = {}
    for laps, tenths, name in tostring(OF.util.stored(forge.RACER_BEST .. key, "") or "")
        :gmatch("(%d+)=(%d+):([^;]*)") do
        out[tonumber(laps)] = { tenths = tonumber(tenths), name = name }
    end
    return out
end
forge.racer_best_read = best_read

function forge.racer_best(key, laps)

    if key == nil or not OF.util.is_host() then return nil end
    local all = best_read(key)
    if laps ~= nil then return all[laps] end
    for _, b in pairs(all) do return b end
    return nil
end

function forge.racer_best_text(best)
    if best == nil then return nil end
    return forge.run_clock(math.floor(best.tenths * 3 + 0.5))
end

function forge.racer_record(key, laps, seconds, name)
    if not OF.util.is_host() or key == nil then return false end
    local tenths = math.floor((tonumber(seconds) or 0) * 10 + 0.5)
    if tenths <= 0 then return false end
    laps = math.max(1, math.floor(tonumber(laps) or 1))
    local all = best_read(key)
    local was = all[laps]
    if was ~= nil and was.tenths <= tenths then return false end
    all[laps] = { tenths = tenths, name = tostring(name or ""):gsub("[^%w _%-%.]", ""):sub(1, 24) }
    local parts = {}
    for l, b in pairs(all) do table.insert(parts, l .. "=" .. b.tenths .. ":" .. b.name) end
    table.sort(parts)
    OF.util.store_soon(forge.RACER_BEST .. key, table.concat(parts, ";"))
    return true
end

function forge.racer_race_laps()
    local racer = OF.gm_shellrace
    if racer == nil or type(racer.current_track) ~= "function" then return 1 end
    local t = racer.current_track()
    return type(racer.laps_of) == "function" and racer.laps_of(t) or 1
end

function forge.racer_update()
    pub.frame = pub.frame + 1
    if not OF.util.is_host() or pub.frame % 15 ~= 0 then return end
    local index = forge.track_index_text()
    if index ~= pub.index then
        pub.index = index
        publish_parts(forge.TRACK_INDEX_PUBLISH, index ~= "" and index or nil)
    end
    local modes = OF.gamemodes
    local running = modes ~= nil and modes.state() ~= modes.OFF
    if running then

        local mode = modes.current()
        local at = modes.round_place()
        if mode == nil or mode.forgeTracks ~= true or at == nil then return end
        local ft = forge.racer_track(at.level, at.area)
        if ft == nil then return end
        local roundId = tostring(modes.liveAt) .. ":" .. tostring(at.level)
        if pub.round ~= roundId then pub.round, pub.seen = roundId, {} end
        local key = forge.racer_best_key(forge.keep_key_for(at.level, at.area), ft.track)
        for _, entry in ipairs(modes.with_role("home")) do
            local li = entry.localIndex
            local row = gPlayerSyncTable[li]
            local time = row ~= nil and tonumber(row.ofGmTime) or nil
            if time ~= nil and not pub.seen[li] then
                pub.seen[li] = true
                local np = gNetworkPlayers[li]
                local name = np ~= nil and OF.util.plain(np.name or "") or ""
                if forge.racer_record(key, forge.racer_race_laps(), time, name) then
                    OF.notify.show("New best on this Forge track: @ by @", "good", 5,
                        forge.run_clock(math.floor(time * 30 + 0.5)), name)
                end
            end
        end
        return
    end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    local target = modes ~= nil and modes.levelChoice or nil
    local level = target ~= nil and target.level or np.currLevelNum
    local area = target ~= nil and (target.area or 1) or np.currAreaIndex
    local track = target ~= nil and tonumber(target.track) or nil
    local shape = forge.racer_shape_of(level, area, track)
    local text = shape ~= nil and forge.racer_text(level, area, shape) or nil
    if text ~= pub.text then forge.racer_publish(text) end
end

hook_event(HOOK_UPDATE, forge.racer_update)

function forge.racer_loop(o)
    local kind = piece_kind(o)
    if kind ~= K.box and kind ~= K.boost and kind ~= K.coin then return end

    if kind == K.coin then o.oAnimState = (tonumber(o.oAnimState) or 0) + 1 end
    local hide = OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0)
        and OF.util.asks(OF.gamemodes, "current") and OF.gamemodes.current() ~= nil
        and OF.gamemodes.current().forgeTracks == true
    local node = o.header ~= nil and o.header.gfx ~= nil and o.header.gfx.node or nil
    if node == nil then return end
    local invisible = GRAPH_RENDER_INVISIBLE or 16
    local flags = tonumber(node.flags) or 0
    local now = (flags & invisible) ~= 0
    if hide and not now then node.flags = flags | invisible
    elseif not hide and now then node.flags = flags & ~invisible end
end

local function set_order(o, order)
    order = math.max(1, math.min(255, math.floor(order)))
    o.oBehParams2ndByte = order
    o.oBehParams = params_of(K.gate, order, piece_track(o))
end

function forge.racer_renumber(o, order)
    if o == nil or piece_kind(o) ~= K.gate then return false end
    set_order(o, order)
    if o.oSyncID ~= nil and o.oSyncID ~= 0 then
        OF.util.send_all({ ofp = forge.PACKET_RACER_ORDER, id = o.oSyncID, n = math.floor(order) })
    end
    return true
end

function forge.track_meta_text(meta)
    return (meta.kind == forge.TRACK_RACE and "r" or "s") .. ":" .. tostring(meta.laps) .. ":"
        .. forge.track_clean_name(meta.name)
end

function forge.track_meta_set(o, meta)
    if o == nil or piece_kind(o) ~= K.start or meta == nil then return false end
    forge.track_meta_write(o, meta)
    if o.oSyncID ~= nil and o.oSyncID ~= 0 then
        local packet = { ofp = forge.PACKET_TRACK_META, id = o.oSyncID, m = forge.track_meta_text(meta) }
        if OF.util.is_host() then
            OF.util.tell_all(packet)
        else
            OF.util.send_to_host(packet)
        end
    end
    return true
end

function forge.track_meta_may(li)
    if li == nil then return false end
    if not OF.util.asks(OF.perms, "tier") or not OF.util.asks(OF.perms, "required") then return false end
    return OF.perms.tier(li) >= OF.perms.required("spawn_object")
end

local function racer_named(data)
    local bhv = OF.spawner ~= nil and OF.spawner.RACER or nil
    return bhv ~= nil and live_by_sync_id(bhv)[tonumber(data.id) or -1] or nil
end

function forge.racer_order_heard(data)
    local o = racer_named(data)
    local n = tonumber(data.n)
    if o == nil or n == nil or piece_kind(o) ~= K.gate then return false end
    set_order(o, n)
    return true
end

function forge.track_meta_heard(data)
    local relay = false
    if OF.util.is_host() then
        local li = OF.util.asked_by(data)
        if not forge.track_meta_may(li) then return false end
        relay = true
    elseif not OF.util.from_host(data) then
        return false
    end
    local _, meta = forge.track_field_read("1:" .. tostring(data.m or ""))
    if meta == nil then return false end

    if relay then
        OF.util.tell_all({ ofp = forge.PACKET_TRACK_META, id = tonumber(data.id),
            m = forge.track_meta_text(meta) })
    end
    local o = racer_named(data)
    if o == nil or piece_kind(o) ~= K.start then return relay end
    forge.track_meta_write(o, meta)
    return true
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" then return end
    if data.ofp == forge.PACKET_RACER_ORDER then
        forge.racer_order_heard(data)
    elseif data.ofp == forge.PACKET_TRACK_META then
        forge.track_meta_heard(data)
    end
end)

end

do
local K = forge.RACER_KINDS
local piece_kind, piece_track = forge.racer_kind_of, forge.racer_track_of

function forge.track_here(track)
    return forge.racer_shape(forge.racer_pieces_here(), track or forge.trackPick)
end

function forge.track_numbers_here()
    local out = {}
    for _, t in ipairs(forge.tracks_of(forge.racer_pieces_here())) do table.insert(out, t.track) end
    return out
end

function forge.track_pick_step(step)
    local numbers = forge.track_numbers_here()
    local free = 1
    local taken = {}
    for _, n in ipairs(numbers) do taken[n] = true end
    while taken[free] do free = free + 1 end
    local ring = {}
    for _, n in ipairs(numbers) do table.insert(ring, n) end
    if free <= forge.TRACK_MOST then table.insert(ring, free) end
    table.sort(ring)
    local at = 1
    for i, n in ipairs(ring) do if n == forge.trackPick then at = i end end
    at = ((at - 1 + (step or 1)) % #ring) + 1
    forge.trackPick = ring[at]
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.track_pick_name()
    local shape = forge.track_here(forge.trackPick)
    if shape ~= nil then return tostring(forge.trackPick) .. " - " .. shape.name end
    for _, n in ipairs(forge.track_numbers_here()) do
        if n == forge.trackPick then return OF.lang.fill("@ - no start ring yet", tostring(n)) end
    end
    return OF.lang.fill("@ - a new track", tostring(forge.trackPick))
end

local function may_lay()
    if not OF.perms.can("spawn_object") then return nil, "Your rank cannot do that." end
    if room_is_held() then return nil, "A round is using this level." end
    local m = gMarioStates[0]
    if m == nil or gNetworkPlayers[0] == nil then return nil, "Nowhere to stand." end
    return m
end

local function placed_entry(o)
    for i, entry in ipairs(forge.placed) do
        if entry.object == o then return entry, i end
    end
    return nil
end

local function take_piece(o)
    local entry, i = placed_entry(o)
    if entry == nil then return false end
    if forge.held == o then forge.held, forge.heldKey = nil, nil end
    OF.spawner.take_down(o, entry.key)
    table.remove(forge.placed, i)
    return true
end
forge.track_take_piece = take_piece

function forge.track_lay(kind)
    local m, why = may_lay()
    if m == nil then return false, why end
    local key = forge.RACER_KEY_OF[kind]
    if key == nil then return false, "That is not a track piece." end
    local track = forge.trackPick or 1
    local shape = forge.track_here(track)
    local meta = nil
    local race = (shape ~= nil and shape.kind or forge.trackKindPick) == forge.TRACK_RACE
    if kind == K.finish and race then
        return false, "A Shell Racer track finishes on its start ring."
    end
    if kind == K.start or kind == K.finish then
        local was = nil
        for _, p in ipairs(forge.racer_pieces_here()) do
            if p.kind == kind and p.track == track then was = p end
        end
        if was ~= nil then
            if placed_entry(was.object) == nil then
                return false, kind == K.start and "Somebody else laid this track's start ring."
                    or "Somebody else laid this track's finish flag."
            end
            meta = was.meta
            take_piece(was.object)
        end
    end
    if kind == K.start and meta == nil then meta = forge.track_default_meta(track) end
    local yaw = math.floor(tonumber(m.faceAngle.y) or 0) % 0x10000
    forge.racerTrackNext, forge.racerMetaNext = track, meta
    local o = OF.spawner.spawn_at(key, m.pos.x, m.pos.y, m.pos.z, yaw)
    forge.racerTrackNext, forge.racerMetaNext = nil, nil
    if o == nil then return false, "No space left in this level." end
    OF.spawner.face(o, yaw)
    table.insert(forge.placed, { object = o, key = key, size = NORMAL_SIZE })
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.track_set_start() return forge.track_lay(K.start) end
function forge.track_add_checkpoint() return forge.track_lay(K.gate) end
function forge.track_set_finish() return forge.track_lay(K.finish) end

function forge.track_take_last()
    local track = forge.trackPick or 1
    for i = #forge.placed, 1, -1 do
        local entry = forge.placed[i]
        local o = entry.object
        if o ~= nil and o.activeFlags ~= 0 and forge.RACER_KEYS[entry.key] ~= nil
            and piece_track(o) == track then
            take_piece(o)
            return true
        end
    end
    return false, "You have laid nothing in this track to take back."
end

function forge.track_clear()
    local track = forge.trackPick or 1
    local taken = 0
    for i = #forge.placed, 1, -1 do
        local entry = forge.placed[i]
        local o = entry.object
        if o ~= nil and o.activeFlags ~= 0 and forge.RACER_KEYS[entry.key] ~= nil
            and piece_track(o) == track then
            take_piece(o)
            taken = taken + 1
        end
    end
    return true, taken
end

function forge.track_start_of(track)
    for _, p in ipairs(forge.racer_pieces_here()) do
        if p.kind == K.start and p.track == track then return p end
    end
    return nil
end

local function change_meta(fn)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    local p = forge.track_start_of(forge.trackPick or 1)
    if p == nil then return false, "Lay this track's start ring first." end
    local meta = p.meta or forge.track_default_meta(p.track)
    fn(meta)
    forge.track_meta_set(p.object, meta)
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.track_set_name(text)
    local name = forge.track_clean_name(text)
    if name == "" then return false, "Give the track a name of letters and numbers." end
    return change_meta(function(meta) meta.name = name end)
end

function forge.track_kind_toggle()
    local p = forge.track_start_of(forge.trackPick or 1)
    if p == nil then
        forge.trackKindPick = forge.trackKindPick == forge.TRACK_RACE and forge.TRACK_SPEEDRUN
            or forge.TRACK_RACE
        OF.sounds.ui("move", OF.sounds.MOVE)
        return true
    end
    return change_meta(function(meta)
        meta.kind = meta.kind == forge.TRACK_RACE and forge.TRACK_SPEEDRUN or forge.TRACK_RACE
        forge.trackKindPick = meta.kind
    end)
end

function forge.track_laps_step(step)
    return change_meta(function(meta)
        meta.laps = ((math.floor(meta.laps or forge.TRACK_LAPS) - 1 + (step or 1))
            % forge.TRACK_LAPS_MOST) + 1
    end)
end

function forge.track_chat(msg)
    if not OF.util.allowed("spawn_object") then return true end
    local ok, why = forge.track_set_name(msg)
    if ok then
        OF.util.chat(OF.lang.fill("Track @ is called @.", tostring(forge.trackPick),
            forge.track_clean_name(msg)))
    else
        OF.util.chat(OF.lang.t(why), "warn")
    end
    return true
end

function forge.racer_gate_aimed(m)
    m = m or gMarioStates[0]
    if m == nil then return nil end
    if forge.held ~= nil and piece_kind(forge.held) == K.gate then return forge.held end
    local cx, cy, cz = carry_spot(m)
    local best, bestD = nil, GRAB_RANGE * 2
    for _, p in ipairs(forge.racer_pieces_here()) do
        if p.kind == K.gate and p.track == (forge.trackPick or 1) then
            for _, at in ipairs({ { cx, cy, cz }, { m.pos.x, m.pos.y, m.pos.z } }) do
                if at[1] ~= nil then
                    local dx, dy, dz = p.x - at[1], p.y - at[2], p.z - at[3]
                    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if d < bestD then best, bestD = p.object, d end
                end
            end
        end
    end
    return best
end

function forge.racer_move_gate(o, step)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if o == nil then return false, "Aim at a checkpoint ring first." end
    local track = piece_track(o)
    local gates = {}
    for _, p in ipairs(forge.racer_pieces_here()) do
        if p.kind == K.gate and p.track == track then table.insert(gates, p) end
    end
    table.sort(gates, forge.racer_by_order)
    local at = nil
    for i, g in ipairs(gates) do if g.object == o then at = i end end
    if at == nil then return false, "Aim at a checkpoint ring first." end
    local other = gates[at + step]
    if other == nil then
        return false, step < 0 and "That ring is already the first." or "That ring is already the last."
    end

    for i, g in ipairs(gates) do
        if g.order ~= i then forge.racer_renumber(g.object, i) end
    end
    forge.racer_renumber(o, at + step)
    forge.racer_renumber(other.object, at)
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.racer_lay_shipped()
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if forge.room_is_held() then return false, "A round is using this level." end
    local np = gNetworkPlayers[0]
    local vkey = np ~= nil and OF.util.asks(OF.venues, "at")
        and OF.venues.at(np.currLevelNum, np.currAreaIndex) or nil
    local layout = vkey ~= nil and OF.venues.LAYOUTS[vkey] or nil
    if layout == nil or type(layout.markers) ~= "table" then
        return false, "This level ships no track."
    end
    local taken = {}
    for _, n in ipairs(forge.track_numbers_here()) do taken[n] = true end
    local track = 1
    while taken[track] do track = track + 1 end
    if track > forge.TRACK_MOST then return false, "This level has as many tracks as it can hold." end
    local laid = 0
    for _, p in ipairs(forge.racer_pieces_of_markers(layout.markers)) do
        forge.racerOrderNext = p.kind == K.gate and p.order or nil
        forge.racerTrackNext = track
        forge.racerMetaNext = p.kind == K.start and { name = OF.lang.t("Shipped track"),
            kind = forge.TRACK_RACE, laps = forge.TRACK_LAPS } or nil
        local o = OF.spawner.spawn_at(forge.RACER_KEY_OF[p.kind], p.x, p.y, p.z, p.yaw)
        forge.racerOrderNext, forge.racerTrackNext, forge.racerMetaNext = nil, nil, nil
        if o ~= nil then
            OF.spawner.face(o, p.yaw)
            table.insert(forge.placed, { object = o, key = forge.RACER_KEY_OF[p.kind], size = NORMAL_SIZE })
            laid = laid + 1
        end
    end
    if laid == 0 then return false, "No space left in this level." end
    forge.trackPick = track
    return true, OF.lang.fill("Laid the shipped track: @ pieces.", tostring(laid))
end

end

do
local K = forge.RACER_KINDS
local pub = forge.racerState
local function pad_facing(yaw)
    local a = (tonumber(yaw) or 0) * math.pi / 0x8000
    return math.sin(a), math.cos(a)
end

forge.TRACK_RING = 200
forge.TRACK_SEEN = 12000
forge.TRACK_LIFT = 160
local labelOut = { x = 0, y = 0, z = 0 }
local function draw_track_label(p, text, r, g, b, radius)
    OF.util.zone_ring(p, radius or forge.TRACK_RING, 40, 3, r, g, b, 200)
    if text == nil then return end
    if OF.util.world_screen({ x = p.x, y = p.y + forge.TRACK_LIFT, z = p.z }, labelOut) then
        OF.util.world_label(labelOut.x, labelOut.y, text, 0.5, r, g, b, 230)
    end
end
forge.track_label = draw_track_label

local function near(p, m)
    if m == nil or m.pos == nil then return true end
    local dx, dz = p.x - m.pos.x, p.z - m.pos.z
    return dx * dx + dz * dz <= forge.TRACK_SEEN * forge.TRACK_SEEN
end

forge.TRACK_GOAL_RADIUS = 400
pub.flags = {}
function forge.track_flag_name(track) return "fktrackgoal" .. tostring(track) end

function forge.track_flags_update()
    local modes = OF.gamemodes
    if modes == nil or modes.mark_flag == nil then return end
    local np = gNetworkPlayers[0]
    local want = {}
    if np ~= nil and not room_is_held() then
        for _, t in ipairs(forge.tracks_of(forge.racer_pieces_here())) do
            local s = t.shape
            if s ~= nil and s.kind == forge.TRACK_SPEEDRUN and s.finish ~= nil then
                want[t.track] = true
                modes.mark_flag(forge.track_flag_name(t.track), { x = s.finish.x, y = s.finish.y, z = s.finish.z,
                    level = np.currLevelNum, area = np.currAreaIndex })
            end
        end
    end
    for track in pairs(pub.flags) do
        if not want[track] then modes.hide_token(forge.track_flag_name(track)) end
    end
    pub.flags = want
    return want
end

hook_event(HOOK_UPDATE, function() forge.track_flags_update() end)

function forge.draw_tracks(detail)
    if OF.util.zone_ring == nil or OF.util.world_screen == nil then return 0 end
    if room_is_held() then return 0 end
    local m = gMarioStates[0]
    local gold = OF.util.gold()
    local drawn = 0
    local pieces = forge.racer_pieces_here()
    for _, t in ipairs(forge.tracks_of(pieces)) do
        local s = t.shape

        if s == nil and detail then
            for _, p in ipairs(pieces) do
                if (p.track or 1) == t.track and near(p, m) then
                    if p.kind == K.gate then
                        draw_track_label(p, tostring(p.order), 255, 220, 120)
                    elseif p.kind == K.finish then
                        OF.util.zone_ring(p, forge.TRACK_GOAL_RADIUS, 40, 4, gold.r, gold.g, gold.b, 200)
                    elseif p.kind == K.respawn then
                        draw_track_label(p, OF.lang.t("Respawn"), 120, 200, 255, 80)
                    elseif p.kind == K.out then
                        draw_track_label(p, OF.lang.t("Out"), 255, 90, 90, forge.RACER_OUT_R * 100)
                    else
                        draw_track_label(p, nil, 200, 200, 200, 120)
                    end
                    drawn = drawn + 1
                end
            end
        end
        if s ~= nil then
            local race = s.kind == forge.TRACK_RACE
            if near(s.start, m) then
                draw_track_label(s.start, race and OF.lang.fill("@ - Shell Racer", s.name) or s.name,
                    120, 255, 140)
                drawn = drawn + 1
            end
            if s.finish ~= nil and not race and near(s.finish, m) then
                OF.util.zone_ring(s.finish, forge.TRACK_GOAL_RADIUS, 40, 4, gold.r, gold.g, gold.b, 200)
                drawn = drawn + 1
            end
            if race and #s.boosts > 0 and OF.util.asks(OF.gm_shellrace, "draw_boosts") then
                local pads = {}
                for _, b in ipairs(s.boosts) do
                    local nx, nz = pad_facing(b.yaw)
                    table.insert(pads, { x = b.x, y = b.y, z = b.z, r = forge.RACER_BOOST_R, nx = nx, nz = nz })
                end
                drawn = drawn + OF.gm_shellrace.draw_boosts({ boosts = pads }, m)
            end
            if detail then
                for i, g in ipairs(s.gates) do
                    if near(g, m) then draw_track_label(g, tostring(i), 255, 220, 120) end
                end
                for _, r in ipairs(s.respawns) do
                    if near(r, m) then draw_track_label(r, OF.lang.t("Respawn"), 120, 200, 255, 80) end
                end
                for _, o in ipairs(s.outs) do
                    if near(o, m) then
                        draw_track_label(o, OF.lang.t("Out"), 255, 90, 90, forge.RACER_OUT_R * 100)
                    end
                end
            end
        end
    end
    return drawn
end

function forge.track_rows(panel, rows)
    local track = forge.trackPick or 1
    local shape, why = forge.track_here(track)
    local race
    if shape ~= nil then race = shape.kind == forge.TRACK_RACE
    else race = forge.trackKindPick == forge.TRACK_RACE end
    table.insert(rows, panel.with_right(panel.header_row(OF.lang.t("Tracks")),
        tostring(#forge.track_numbers_here())))
    table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("spawn_object",
        OF.lang.t("Track you are laying"), 255, 255, 255,
        function() OF.util.report(forge.track_pick_step(1)) end),
        forge.track_pick_name()),
        OF.lang.t("every piece you lay goes into this track and no other")))
    table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("spawn_object",
        OF.lang.t("Kind"), 255, 255, 255,
        function() OF.util.report(forge.track_kind_toggle()) end),
        OF.lang.t(forge.TRACK_KIND_NAMES[race and forge.TRACK_RACE or forge.TRACK_SPEEDRUN])),
        OF.lang.t("a speedrun on your own clock, or a Shell Racer map")))
    if shape ~= nil then
        table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("spawn_object",
            OF.lang.t("Name"), 255, 255, 255,
            function() OF.notify.show("Type /track and a name in chat", "info", 4) end),
            shape.name),
            OF.lang.t("type /track and a name in chat to rename it")))
        if race then
            table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("spawn_object",
                OF.lang.t("Laps"), 255, 255, 255,
                function() OF.util.report(forge.track_laps_step(1)) end),
                tostring(shape.laps)),
                OF.lang.t("how many times round before the line counts home")))
        end
    end
    local function lay(label, kind, help)
        table.insert(rows, panel.with_help(panel.gated_row("spawn_object", OF.lang.t(label),
            255, 255, 255, function() OF.util.report(forge.track_lay(kind)) end), OF.lang.t(help)))
    end
    lay("Start ring here", K.start, race and "the start and finish line, the grid behind it"
        or "where you stand, facing down the track")
    lay(race and "Gate here" or "Checkpoint here", K.gate, race
        and "the next gate a racer passes, in the order laid"
        or "the next ring a runner touches, in the order laid")
    if race then
        lay("Item box here", K.box, "a box that hands out an item")
        lay("Boost pad here", K.boost, "a pad that throws a shell forward, facing your way")
        lay("Coin here", K.coin, "a coin that makes a shell faster")
        lay("Respawn point here", K.respawn, "where Lakitu puts a racer back near this gate")
        lay("Out zone here", K.out, "a racer inside it is fished out by Lakitu")
    else
        lay("Finish flag here", K.finish, "where the clock stops, once every ring is touched")
    end
    local o = forge.racer_gate_aimed()
    if o ~= nil then
        local n = tostring(math.floor(tonumber(o.oBehParams2ndByte) or 0))
        table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("spawn_object",
            OF.lang.t("This ring earlier"), 255, 255, 255,
            function() OF.util.report(forge.racer_move_gate(forge.racer_gate_aimed(), -1)) end),
            OF.lang.fill("ring @", n)),
            OF.lang.t("swaps it with the ring before it")))
        table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("spawn_object",
            OF.lang.t("This ring later"), 255, 255, 255,
            function() OF.util.report(forge.racer_move_gate(forge.racer_gate_aimed(), 1)) end),
            OF.lang.fill("ring @", n)),
            OF.lang.t("swaps it with the ring after it")))
    end
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t("Take back the last piece"), 255, 200, 140,
        function() OF.util.report(forge.track_take_last()) end),
        OF.lang.t("the last piece you laid in this track")))
    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t("Clear this track"), 255, 140, 90,
        function() OF.util.report(forge.track_clear()) end),
        OF.lang.t("every piece of this track that you laid")))

    local say = why
    if shape ~= nil then
        say = forge.racer_problem(shape)
        if say == nil then

            say = race and OF.lang.fill("Gates: @, laps: @ - in Shell Racer's map picker",
                tostring(#shape.gates), tostring(shape.laps))
                or OF.lang.fill("Checkpoints: @, then the flag - in the Speedruns tab",
                tostring(#shape.gates))
        end
    end
    if say ~= nil and #forge.racer_pieces_here() > 0 then
        table.insert(rows, panel.label_row(OF.lang.t(say)))
    end

    if forge.run_live() then
        table.insert(rows, panel.with_help(panel.row(OF.lang.t("Stop the run"),
            255, 200, 140, function() OF.util.report(forge.run_stop()) end),
            OF.lang.t("drops the clock; nothing else changes")))
    elseif shape ~= nil and not race and forge.track_ready(shape) then
        table.insert(rows, panel.with_help(panel.gated_row("teleport_self",
            OF.lang.t("Run this track"), 120, 255, 140,
            function()
                local ok, w = forge.run_track(track)
                OF.util.report(ok, w)
                if ok then panel.close() end
            end),
            OF.lang.t("onto the start ring, then the countdown")))
    end

    local np = gNetworkPlayers[0]
    local here = forge.keep_here()
    local elsewhere = {}
    for _, e in ipairs(forge.track_index()) do
        if e.key ~= here then table.insert(elsewhere, e) end
    end
    if #elsewhere > 0 then
        table.insert(rows, panel.with_help(panel.with_right(panel.header_row(OF.lang.t("Your tracks elsewhere")),
            tostring(#elsewhere)),
            OF.lang.t("tracks kept in other levels - go there to build on them")))
        for _, e in ipairs(elsewhere) do
            local entry = e
            local ok, levelName = false, nil
            if OF.util.asks(OF.util, "level_name") then ok, levelName = pcall(OF.util.level_name, e.level, e.area) end
            if not ok or type(levelName) ~= "string" or levelName == "" then
                levelName = OF.lang.fill("level @", tostring(e.level))
            end
            local kindWord = OF.lang.t(forge.TRACK_KIND_NAMES[e.kind] or "")
            if not e.ready then kindWord = OF.lang.fill("@, unfinished", kindWord) end
            table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("teleport_self",
                levelName .. " - " .. e.name, 255, 255, 255, function()
                    local went, why = forge.track_visit(entry)
                    OF.util.report(went, why)
                    if went then panel.close() end
                end), kindWord),
                OF.lang.t("goes to its start ring to keep building it - no run starts")))
        end
    end

    local known = #forge.track_index()
    if known > 0 then
        table.insert(rows, panel.with_help(panel.with_right(panel.row(
            OF.lang.t("Tracks in every level..."), 255, 255, 255,
            function() panel.go("forgetracks") end), tostring(known)),
            OF.lang.t("every kept track by level - go there or delete it here")))
    end

    if np ~= nil and OF.util.asks(OF.venues, "at") then
        local vkey = OF.venues.at(np.currLevelNum, np.currAreaIndex)
        local layout = vkey ~= nil and OF.venues.LAYOUTS[vkey] or nil
        if layout ~= nil and type(layout.markers) == "table" then
            table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
                OF.lang.t("Lay the shipped track as pieces"), 255, 255, 255,
                function() OF.util.report(forge.racer_lay_shipped()) end),
                OF.lang.t("the map's own track, to move and keep as yours")))
        end
    end
    if race and shape ~= nil and np ~= nil and OF.util.is_host() then
        local best = forge.racer_best(forge.racer_best_key(
            forge.keep_key_for(np.currLevelNum, np.currAreaIndex), track))
        if best ~= nil then
            table.insert(rows, panel.label_row(OF.lang.fill("Best: @ by @",
                forge.racer_best_text(best), best.name)))
        end
    end
end
end

do

local FPS = 30
forge.RUN_COUNT = 3 * FPS
forge.RUN_HOLD_MOST = 150
local GO_FRAMES = 24
local RESULT_FRAMES = 6 * FPS
local run = nil
local wasOnStart = false
local result = nil
forge.runBests = {}

local function frame_now()
    return tonumber(OF.util.optional("get_global_timer", 0)) or 0
end

local function in_ring(p, radius)
    local m = gMarioStates[0]
    if m == nil or p == nil then return false end
    local dx, dz, dy = m.pos.x - p.x, m.pos.z - p.z, m.pos.y - p.y
    return dx * dx + dz * dz <= radius * radius and dy >= -150 and dy <= 600
end
forge.run_inside = in_ring

function forge.run_clock(frames)
    local tenths = math.floor((tonumber(frames) or 0) * 10 / FPS + 0.5)
    local seconds = math.floor(tenths / 10)
    return string.format("%.0f:%02.0f.%.0f", math.floor(seconds / 60), seconds % 60,
        tenths % 10)
end

function forge.run_live()
    return run ~= nil
end

function forge.run_now()
    return run, result
end

local function best_key(levelKey, track)
    return tostring(levelKey or "") .. ":" .. tostring(track or 1)
end

function forge.run_best(levelKey, track)
    return forge.runBests[best_key(levelKey, track)]
end

local function track_now(number)
    local shape = forge.racer_shape(forge.racer_pieces_here(), number)
    if shape == nil or shape.kind ~= forge.TRACK_SPEEDRUN or not forge.track_ready(shape) then
        return nil
    end
    return shape
end
forge.run_track_now = track_now

local function begin_count(shape)
    local np = gNetworkPlayers[0]
    run = { phase = "count", track = shape.track, name = shape.name, frames = 0,
        level = np.currLevelNum, area = np.currAreaIndex, levelKey = forge.keep_here() }
    result = nil
end

local function drop_run(why)
    run = nil
    if why ~= nil then OF.notify.show(why, "warn", 3) end
end

function forge.run_stop()
    if run == nil then return false, "You are not running a track." end
    run = nil
    return true
end

local function may_run()
    if room_is_held() then return false, "A round is using this level." end
    if not OF.perms.can("teleport_self") then return false, "Your rank cannot do that." end
    return true
end

local function travel(level, area, act, at, face, track)
    OF.net.teleport_to_position({ level = level, area = area, act = act,
        x = at.x, y = at.y, z = at.z, angle = face })
    run = { phase = "arrive", track = track, level = level, area = area, frames = 0,
        at = { x = at.x, y = at.y, z = at.z, face = face } }
    result = nil
end

function forge.run_track(number)
    local ok, why = may_run()
    if not ok then return false, why end
    local shape = track_now(number or forge.trackPick)
    if shape == nil then return false, "This track needs a start ring and a finish flag." end
    local np = gNetworkPlayers[0]
    travel(np.currLevelNum, np.currAreaIndex, np.currActNum, shape.start,
        forge.track_facing(shape), shape.track)
    return true
end

function forge.track_travel(entry)
    local ok, why = may_run()
    if not ok then return false, why end
    if entry == nil or entry.start == nil then return false, "That track is gone." end
    local np = gNetworkPlayers[0]
    local same = np.currLevelNum == entry.level and np.currAreaIndex == entry.area
    travel(entry.level, entry.area, same and np.currActNum or 1, entry.start, entry.face or 0,
        entry.track)
    return true
end

function forge.track_visit(entry)
    if entry == nil or entry.start == nil then return false, "That track is gone." end
    if not OF.util.asks(OF.net, "teleport_to_position") then return false, "Travel is not loaded." end
    OF.net.teleport_to_position({ level = entry.level, area = entry.area, act = 1,
        x = entry.start.x, y = entry.start.y, z = entry.start.z, angle = entry.face or 0 })
    forge.trackPick = entry.track or 1
    forge.trackKindPick = entry.kind
    return true
end

forge.TRACK_DELETE_ACTION = "forgetrackdel"
forge.PACKET_TRACK_DEL = "fktdel"
local function row_of_track(item, track)
    local rows = forge.keep_parse(item)
    local row = rows[1]
    return row ~= nil and forge.RACER_KEYS[row.key] ~= nil and (row.track or 1) == track
end

function forge.track_rows_out(text, track)
    local kept, gone = {}, 0
    for item in tostring(text or ""):gmatch("[^;]+") do
        if row_of_track(item, track) then gone = gone + 1 else kept[#kept + 1] = item end
    end
    return table.concat(kept, ";"), gone
end

function forge.track_take_mine(track)
    local taken = 0
    for i = #forge.placed, 1, -1 do
        local entry = forge.placed[i]
        local o = entry ~= nil and entry.object or nil
        if o ~= nil and o.activeFlags ~= 0 and forge.RACER_KEYS[entry.key] ~= nil
            and forge.racer_track_of(o) == track then
            if forge.track_take_piece(o) then taken = taken + 1 end
        end
    end
    return taken
end

function forge.track_delete_host(key, track)
    if not OF.util.is_host() then return false, "Only the host's save holds the tracks." end
    track = math.floor(tonumber(track) or 0)
    if type(key) ~= "string" or key == "" or track < 1 then return false, "That track is gone." end
    local name = nil
    for _, e in ipairs(forge.track_index()) do
        if e.key == key and e.track == track then name = e.name end
    end
    if name == nil then return false, "That track is gone." end
    local gone = 0
    local keep = forge.keepState
    if key == forge.keep_here() and keep ~= nil then
        gone = gone + forge.track_take_mine(track)
        local carry = {}
        for _, row in ipairs(keep.carry or {}) do
            if row_of_track(row.text, track) then gone = gone + 1 else table.insert(carry, row) end
        end
        keep.carry = carry
        for builder, texts in pairs(keep.reported or {}) do
            local left = {}
            for _, text in ipairs(texts) do
                if row_of_track(text, track) then gone = gone + 1 else table.insert(left, text) end
            end
            keep.reported[builder] = left
        end
    end
    local kept = forge.keep_read(key)
    if kept ~= "" then
        local text, n = forge.track_rows_out(kept, track)
        if n > 0 then
            forge.keep_write(key, text)
            gone = gone + n
        end
    end
    local best = forge.RACER_BEST .. forge.racer_best_key(key, track)
    if OF.util.stored(best) ~= nil then OF.util.clear(best) end
    OF.util.tell_all({ ofp = forge.PACKET_TRACK_DEL, k = key, t = track })
    return true, OF.lang.fill("Deleted the track @", name)
end

function forge.track_delete(entry)
    if entry == nil then return false, "That track is gone." end
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if OF.util.is_host() then return forge.track_delete_host(entry.key, entry.track) end
    if not OF.util.asks(OF.net, "host_does") then return false, "No host to ask yet - try again in a second." end
    return OF.net.host_does(forge.TRACK_DELETE_ACTION, entry.track, nil, entry.key)
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_action") then
        OF.net.register_action(forge.TRACK_DELETE_ACTION, "spawn_object", function(asker, x, y, z)
            return forge.track_delete_host(z, x)
        end)
    end
end)

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" or data.ofp ~= forge.PACKET_TRACK_DEL then return end
    if not OF.util.from_host(data) then return end
    if data.k ~= forge.keep_here() then return end
    forge.track_take_mine(math.floor(tonumber(data.t) or 0))
end)

function forge.tracks_page(panel)
    local rows = {}
    local list = forge.track_index()
    if #list == 0 then
        table.insert(rows, panel.label_row(OF.lang.t("No track is kept anywhere yet")))
        table.insert(rows, panel.back_row())
        return rows
    end
    local groups, order = {}, {}
    for _, e in ipairs(list) do
        if groups[e.key] == nil then
            groups[e.key] = {}
            table.insert(order, e.key)
        end
        table.insert(groups[e.key], e)
    end
    local here = forge.keep_here()
    for _, key in ipairs(order) do
        local first = groups[key][1]
        local ok, levelName = false, nil
        if OF.util.asks(OF.util, "level_name") then ok, levelName = pcall(OF.util.level_name, first.level, first.area) end
        if not ok or type(levelName) ~= "string" or levelName == "" then
            levelName = OF.lang.fill("level @", tostring(first.level))
        end
        if key == here then levelName = OF.lang.fill("@ (here)", levelName) end
        local head = panel.with_right(panel.header_row(levelName), tostring(#groups[key]))
        head.help = OF.lang.t("the tracks kept in this level")
        table.insert(rows, head)
        for _, e in ipairs(groups[key]) do
            local entry = e
            local kindWord = OF.lang.t(forge.TRACK_KIND_NAMES[e.kind] or "")
            if not e.ready then kindWord = OF.lang.fill("@, unfinished", kindWord) end
            table.insert(rows, panel.with_key(panel.with_help(panel.with_right(panel.gated_row("teleport_self",
                OF.lang.fill("Go to @", e.name), 255, 255, 255, function()
                    local went, why = forge.track_visit(entry)
                    OF.util.report(went, why)
                    if went then panel.close() end
                end), kindWord),
                OF.lang.t("goes to its start ring to keep building it - no run starts")),
                "trackgo:" .. key .. ":" .. tostring(e.track)))
            table.insert(rows, panel.with_key(panel.with_help(panel.gated_confirm_row("spawn_object",
                "forgetrackdel" .. key .. "t" .. tostring(e.track),
                OF.lang.fill("Delete @", e.name), 255, 140, 90, function()
                    OF.util.report(forge.track_delete(entry))
                end),
                OF.lang.t("every piece of it in its level, and its best times - asks twice")),
                "trackdel:" .. key .. ":" .. tostring(e.track)))
        end
    end
    table.insert(rows, panel.back_row())
    return rows
end

local function floor_under(x, y, z)
    local f = OF.util.optional("find_floor_height", nil, x, y + 100, z)
    local lowest = gLevelValues ~= nil and tonumber(gLevelValues.floorLowerLimit) or -11000
    return type(f) == "number" and f > lowest + 1 and f >= y - 400
end
forge.run_floor_under = floor_under

local function finish(shape)
    local took = frame_now() - run.startFrame
    local key = best_key(run.levelKey, run.track)
    local was = forge.runBests[key]
    local better = was == nil or took < was
    if better then forge.runBests[key] = took end
    result = { name = run.name, took = took, best = forge.runBests[key], better = better and was ~= nil,
        frames = 0 }
    run = nil
    wasOnStart = true
    OF.notify.show("@ finished in @", "good", 6, shape.name, forge.run_clock(took))
    OF.sounds.play(OF.sounds.FINISH)
    if result.better then OF.sounds.play(OF.sounds.BEST) end
end

local function run_update()
    local m, np = gMarioStates[0], gNetworkPlayers[0]
    if m == nil or np == nil then return end
    if result ~= nil then
        result.frames = result.frames + 1
        if result.frames > RESULT_FRAMES then result = nil end
    end

    if run ~= nil then
        if room_is_held() then
            drop_run("Track stopped - a round took the level")
            return
        end
        if np.currLevelNum ~= run.level or np.currAreaIndex ~= run.area then
            if run.phase == "arrive" and (OF.net.pendingPos ~= nil or run.frames < FPS) then
                run.frames = run.frames + 1
                return
            end
            drop_run("Track stopped - you left its level")
            return
        end
        if run.phase == "arrive" then
            if OF.net.pendingPos ~= nil then return end
            run.frames = run.frames + 1
            local shape = track_now(run.track)
            if (shape ~= nil and floor_under(run.at.x, run.at.y, run.at.z))
                or run.frames > forge.RUN_HOLD_MOST then
                if shape == nil then
                    drop_run("That track's pieces are not in this level")
                    return
                end
                begin_count(shape)
            end
            return
        end
        if run.phase == "count" then
            run.frames = run.frames + 1
            local left = math.ceil((forge.RUN_COUNT - run.frames + 1) / FPS)
            if left >= 1 and left ~= run.heard then
                run.heard = left
                if OF.util.asks(OF.gamemodes, "count_sound") then
                    OF.sounds.play(OF.gamemodes.count_sound(left))
                end
            end
            if run.frames >= forge.RUN_COUNT then
                run.phase = "go"
                run.startFrame = frame_now()
                run.nextPoint = 1
                OF.sounds.play(OF.sounds.SHOT)
            end
            return
        end
        local shape = track_now(run.track)
        if shape == nil then
            drop_run("Track stopped - it was taken down")
            return
        end
        if run.nextPoint <= #shape.gates then
            if in_ring(shape.gates[run.nextPoint], forge.TRACK_RING + 50) then
                run.nextPoint = run.nextPoint + 1
                OF.notify.show("Checkpoint @ of @", "good", 2,
                    tostring(run.nextPoint - 1), tostring(#shape.gates))
                OF.sounds.ui("select", OF.sounds.PICK)
            end
            return
        end
        if in_ring(shape.finish, forge.TRACK_GOAL_RADIUS) then finish(shape) end
        return
    end

    if forge.open or room_is_held() then
        wasOnStart = false
        return
    end
    local onStart = nil
    for _, t in ipairs(forge.tracks_of(forge.racer_pieces_here())) do
        local s = t.shape
        if s ~= nil and s.kind == forge.TRACK_SPEEDRUN and forge.track_ready(s)
            and in_ring(s.start, forge.TRACK_RING) then
            onStart = s
        end
    end
    if onStart ~= nil and not wasOnStart then begin_count(onStart) end
    wasOnStart = onStart ~= nil
end
forge.run_update = run_update

hook_event(HOOK_UPDATE, run_update)

local function keep_still(m)
    OF.input.freeze(m)
    m.vel.x, m.vel.z = 0, 0
    m.forwardVel = 0
end

local function run_hold(m)
    if m == nil or m.playerIndex ~= 0 or run == nil then return end
    if run.phase == "arrive" and OF.net.pendingPos == nil then
        m.pos.x, m.pos.y, m.pos.z = run.at.x, run.at.y, run.at.z
        m.faceAngle.y = run.at.face
        m.vel.y = 0
        keep_still(m)
    elseif run.phase == "count" then
        keep_still(m)
    end
end
forge.run_hold = run_hold

hook_event(HOOK_BEFORE_MARIO_UPDATE, run_hold, OF.LOCAL_MARIO)

local function run_render()
    if OF.util.menu_has_screen() then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    if not forge.open then forge.draw_tracks(false) end
    local modes = OF.gamemodes
    if run ~= nil and run.phase == "count" then
        if OF.util.asks(modes, "draw_count_digit") then
            if OF.util.asks(modes, "draw_count_title") then modes.draw_count_title(run.name) end
            local seconds = math.max(1, math.ceil((forge.RUN_COUNT - run.frames) / FPS))
            modes.draw_count_digit(seconds, run.frames % FPS)
        end
        return
    end
    if run ~= nil and run.phase == "go" then

        local age = frame_now() - run.startFrame
        if age <= GO_FRAMES and OF.util.asks(OF.hud, "go") then OF.hud.go(age) end
        local shape = track_now(run.track)
        if shape == nil then return end
        local target, nextName
        if run.nextPoint <= #shape.gates then
            target = shape.gates[run.nextPoint]
            nextName = OF.lang.fill("checkpoint @ of @", tostring(run.nextPoint), tostring(#shape.gates))
            forge.track_label(target, tostring(run.nextPoint), 255, 220, 120)
        else
            nextName = OF.lang.t("the flag")
        end
        OF.util.banner(OF.lang.fill("@  -  next: @", forge.run_clock(frame_now() - run.startFrame),
            nextName), 0.95, 200, 230, 255)
        return
    end
    if result ~= nil then
        local gold = OF.util.gold()
        OF.util.banner(OF.lang.fill("@ in @", result.name, forge.run_clock(result.took)),
            1.0, gold.r, gold.g, gold.b)
        OF.util.banner_low(OF.lang.fill(result.better and "New best this session: @"
            or "Best this session: @", forge.run_clock(result.best)), 0.8, 255, 255, 255)
    end
end

forge.run_render = run_render

hook_event(HOOK_ON_HUD_RENDER, run_render)

function forge.speedrun_tracks()
    local out = {}
    for _, e in ipairs(forge.track_index()) do
        if e.kind == forge.TRACK_SPEEDRUN and e.ready then
            local ok, name = false, nil
            if OF.util.asks(OF.util, "level_name") then
                ok, name = pcall(OF.util.level_name, e.level, e.area)
            end
            e.levelName = (ok and type(name) == "string" and name ~= "") and name
                or OF.lang.fill("level @", tostring(e.level))
            table.insert(out, e)
        end
    end
    table.sort(out, function(a, b)
        if a.levelName ~= b.levelName then return a.levelName < b.levelName end
        return a.track < b.track
    end)
    return out
end

function forge.tracks_rows(panel, rows)
    local list = forge.speedrun_tracks()
    table.insert(rows, panel.with_help(panel.with_right(panel.header_row(OF.lang.t("Tracks")),
        tostring(#list)), OF.lang.t("speedrun tracks built in the Forge, run alone on your own clock")))
    if #list == 0 then
        table.insert(rows, panel.label_row(
            OF.lang.t("No speedrun tracks yet - lay one in the Forge, under More.")))
        return rows
    end
    for _, e in ipairs(list) do
        local entry = e
        local best = forge.run_best(e.key, e.track)
        table.insert(rows, panel.with_help(panel.with_right(panel.gated_row("teleport_self",
            e.levelName .. " - " .. e.name, 255, 255, 255, function()
                local ok, why = forge.track_travel(entry)
                OF.util.report(ok, why)
                if ok then panel.close() end
            end), best ~= nil and forge.run_clock(best) or OF.lang.t("no time yet")),
            OF.lang.t("travels to its start ring, then the countdown")))
    end
    return rows
end

hook_chat_command("track", "- name the Forge track you are laying",
    function(msg) return forge.track_chat(msg) end)

end

local function grid_forward(m)
    local angle = angle_of(m)
    local fx, fz = sins(angle), coss(angle)
    if math.abs(fx) >= math.abs(fz) then
        return (fx >= 0) and 1 or -1, 0
    end
    return 0, (fz >= 0) and 1 or -1
end

local function grid_stamp_said(placed, wanted, full)
    if placed == 0 then
        if full > 0 then return false, "Those cells all have blocks in them." end
        return false, "Nothing was placed."
    end
    if placed >= wanted then return true, placed, wanted end
    if full > 0 then
        return true, placed, wanted,
            "Laid " .. placed .. " of " .. wanted .. " - "
                .. full .. " of those cells were already full."
    end
    return true, placed, wanted,
        "Laid " .. placed .. " of " .. wanted .. " - the rest could not go here."
end

local function grid_stamp_start(m)
    if not OF.perms.can("spawn_object") then
        return nil, "Your rank cannot do that."
    end

    local key = forge.build_place_key()
    if key == nil then return nil, "This build has no blocks to build with." end
    local x, y, z = forge.cell_cursor(m)
    if x == nil then return nil end
    local fx, fz = grid_forward(m)
    return { key = key, x = x, y = y, z = z, cell = build_cell(),
             fx = fx, fz = fz, sx = fz, sz = -fx, yaw = forge.build_yaw() }
end

build_stamp_line = function(count)
    local m = gMarioStates[0]
    if m == nil then return false end
    local at, why = grid_stamp_start(m)
    if at == nil then return false, why end

    count = OF.util.clamp(math.floor(tonumber(count) or 5), 2, MAX_STAMP)
    local placed, full = 0, 0

    begin_batch()
    for step = 0, count - 1 do
        local ok, said = lay_block(at.key,
            at.x + at.fx * step * at.cell, at.y,
            at.z + at.fz * step * at.cell, at.yaw)
        if ok then placed = placed + 1
        elseif said == "full" then full = full + 1 end
    end
    end_batch()

    if placed > 0 then
        forge.publish_reach()
        OF.sounds.ui("select", OF.sounds.PICK)
    else
        OF.sounds.ui("back", OF.sounds.BACK)
    end
    return grid_stamp_said(placed, count, full)
end

build_stamp_plane = function(side, upward)
    local m = gMarioStates[0]
    if m == nil then return false end
    local at, why = grid_stamp_start(m)
    if at == nil then return false, why end

    side = OF.util.clamp(math.floor(tonumber(side) or MAX_SIDE), 2, MAX_SIDE)
    local wanted = side * side

    local middle = math.ceil(side / 2)
    local placed, full = 0, 0

    begin_batch()
    for row = 1, side do
        for col = 1, side do
            local off = col - middle
            local ox = at.x + at.sx * off * at.cell
            local oy = at.y
            local oz = at.z + at.sz * off * at.cell
            if upward then
                oy = at.y + (row - 1) * at.cell
            else
                ox = ox + at.fx * (row - 1) * at.cell
                oz = oz + at.fz * (row - 1) * at.cell
            end
            local ok, said = lay_block(at.key, ox, oy, oz, at.yaw)
            if ok then placed = placed + 1
            elseif said == "full" then full = full + 1 end
        end
    end
    end_batch()
    if placed > 0 then
        forge.publish_reach()
        OF.sounds.ui("select", OF.sounds.PICK)
    else
        OF.sounds.ui("back", OF.sounds.BACK)
    end
    return grid_stamp_said(placed, wanted, full)
end

local riders = { parent = nil, list = {} }

local function rider_of(child)
    for _, rider in ipairs(riders.list) do
        if rider.object == child then return rider end
    end
    return nil
end

local function yaw_of(object)
    return tonumber(object.oFaceAngleYaw) or 0
end

local function gather_riders(parent, key)
    local kinds = OF.util.asks(OF.spawner, "followers")
        and OF.spawner.followers(key) or nil
    if riders.parent ~= parent then riders = { parent = parent, list = {} } end
    if kinds == nil or OF.util.binding("obj_get_first_with_behavior_id") == nil then
        return
    end
    local yaw = yaw_of(parent)
    local c, s = coss(yaw), sins(yaw)
    for _, bhv in ipairs(kinds) do
        local child = obj_get_first_with_behavior_id(bhv)
        local guard = 0
        while child ~= nil and guard < 512 do
            if child.parentObj == parent and child ~= parent
                and child.activeFlags ~= 0 and rider_of(child) == nil then

                local dx = child.oPosX - parent.oPosX
                local dz = child.oPosZ - parent.oPosZ
                table.insert(riders.list, {
                    object = child,
                    x = dx * c - dz * s,
                    y = child.oPosY - parent.oPosY,
                    z = dx * s + dz * c,
                    yaw = (tonumber(child.oMoveAngleYaw) or 0) - yaw,
                })
            end
            child = obj_get_next_with_same_behavior_id(child)
            guard = guard + 1
        end
    end
end

local function carry_riders(parent)
    if riders.parent ~= parent then return end
    local yaw = yaw_of(parent)
    local c, s = coss(yaw), sins(yaw)
    local alive = {}
    for _, rider in ipairs(riders.list) do
        local child = rider.object
        if child ~= nil and child.activeFlags ~= 0 then
            child.oPosX = parent.oPosX + rider.x * c + rider.z * s
            child.oPosY = parent.oPosY + rider.y
            child.oPosZ = parent.oPosZ - rider.x * s + rider.z * c
            child.oHomeX, child.oHomeY, child.oHomeZ =
                child.oPosX, child.oPosY, child.oPosZ
            local turned = (yaw + rider.yaw) % 0x10000
            if turned >= 0x8000 then turned = turned - 0x10000 end
            child.oMoveAngleYaw = turned
            child.oFaceAngleYaw = turned
            obj_update_gfx_pos_and_angle(child)
            table.insert(alive, rider)
        end
    end
    riders.list = alive
end

forge.riders = function() return riders end

local function carry_update()
    if forge.held == nil then return end
    local m = gMarioStates[0]
    if m == nil then return end

    if forge.held.activeFlags == 0 then
        forge.held = nil
        forge.heldKey = nil
        return
    end

    gather_riders(forge.held, forge.heldKey)

    local x, y, z = carry_spot(m, forge.sideways)
    y = forge.grounded_y(forge.heldKey, x, y, z)
    forge.held.oPosX = x
    forge.held.oPosY = y
    forge.held.oPosZ = z

    forge.held.oHomeX = x
    forge.held.oHomeY = y
    forge.held.oHomeZ = z

    if not forge.foreign_held() then apply_size(forge.held, forge.size) end

    obj_update_gfx_pos_and_angle(forge.held)
    carry_riders(forge.held)
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

forge.mouse_aim_on = true
forge.mouseAim = nil
forge.MOUSE_REACH = 5000
forge.MOUSE_LIFT_FROM = 80

function forge.set_mouse_aim(on)
    forge.mouse_aim_on = on == true
    if not forge.mouse_aim_on then forge.mouseAim = nil end
    return true
end

forge.MOUSE_AIMS = { "pointer", "crosshair" }
forge.MOUSE_AIM_NAMES = { pointer = "a free pointer", crosshair = "the crosshair" }
forge.mouse_aim_mode = "pointer"
forge.ORBIT_PX = 8
forge.orbit = { down = false, fromX = nil, fromY = nil, dragging = false, clicked = false }

function forge.set_mouse_aim_mode(mode)
    if forge.MOUSE_AIM_NAMES[mode] == nil then return false, "No such setting." end
    forge.mouse_aim_mode = mode
    return true
end

function forge.pointer_mode()
    return forge.open == true and forge.mouse_aim_on == true
        and forge.mouse_aim_mode == "pointer" and forge.mouse_driving()
        and not forge.screen_over()
end

function forge.mouse_hold_update()
    local o = forge.orbit
    local pointer = forge.pointer_mode()
    local down = math.floor(tonumber(OF.util.optional("djui_hud_get_mouse_buttons_down", 0)) or 0)
    local pressed = math.floor(tonumber(OF.util.optional("djui_hud_get_mouse_buttons_pressed", 0)) or 0)
    local mid = M_MOUSE_BUTTON ~= nil and OF.util.has_flag(down, M_MOUSE_BUTTON)
    local tap = M_MOUSE_BUTTON ~= nil and OF.util.has_flag(pressed, M_MOUSE_BUTTON) and not mid
    o.clicked = false
    if pointer and mid then
        local x = tonumber(OF.util.optional("djui_hud_get_mouse_x", nil))
        local y = tonumber(OF.util.optional("djui_hud_get_mouse_y", nil))
        if not o.down then
            o.down, o.dragging, o.fromX, o.fromY = true, false, x, y
        elseif not o.dragging and x ~= nil and o.fromX ~= nil
            and math.abs(x - o.fromX) + math.abs(y - (o.fromY or y)) >= forge.ORBIT_PX then
            o.dragging = true
            OF.util.lend_setting("cam.mouse", "forgeorbit", "camera_config_is_mouse_look_enabled",
                "camera_config_enable_mouse_look", true)
        end
    else
        if o.down and not o.dragging then o.clicked = true end
        if tap then o.clicked = true end
        if o.dragging then OF.util.return_setting("cam.mouse", "forgeorbit") end
        o.down, o.dragging, o.fromX, o.fromY = false, false, nil, nil
    end
    local hold = pointer and not o.dragging
    if OF.util.asks(OF.input, "hold_mouse") then OF.input.hold_mouse("forgeaim", hold) end
    return hold
end

function forge.mouse_release()
    local o = forge.orbit
    if o.dragging then OF.util.return_setting("cam.mouse", "forgeorbit") end
    o.down, o.dragging, o.fromX, o.fromY, o.clicked = false, false, nil, nil, false
    if OF.util.asks(OF.input, "holds_mouse") and OF.input.holds_mouse("forgeaim") then
        OF.input.hold_mouse("forgeaim", false)
    end
    return true
end

function forge.mouse_driving()
    return OF.util.asks(OF.input, "mouse_driving") and OF.input.mouse_driving() == true
end

function forge.pointer()
    if djui_hud_set_resolution ~= nil and RESOLUTION_DJUI ~= nil then
        djui_hud_set_resolution(RESOLUTION_DJUI)
    end
    local width = OF.util.optional("djui_hud_get_screen_width", nil)
    local height = OF.util.optional("djui_hud_get_screen_height", nil)
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
        return nil
    end
    local locked = OF.util.optional("djui_hud_is_mouse_locked", false) == true
        or OF.util.optional("camera_config_is_mouse_look_enabled", false) == true
    if locked then return width * 0.5, height * 0.5, width, height, true end
    local x = OF.util.optional("djui_hud_get_mouse_x", nil)
    local y = OF.util.optional("djui_hud_get_mouse_y", nil)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y, width, height, false
end

function forge.screen_ray(sx, sy, width, height)
    local lak = gLakituState
    if lak == nil or lak.pos == nil or lak.focus == nil then return nil end
    local px, py, pz = lak.pos.x, lak.pos.y, lak.pos.z
    local fx, fy, fz = lak.focus.x - px, lak.focus.y - py, lak.focus.z - pz
    local len = math.sqrt(fx * fx + fy * fy + fz * fz)
    if len < 0.001 then return nil end
    fx, fy, fz = fx / len, fy / len, fz / len

    local rx, rz = -fz, fx
    local rl = math.sqrt(rx * rx + rz * rz)
    if rl < 0.001 then rx, rz, rl = 1, 0, 1 end
    rx, rz = rx / rl, rz / rl
    local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy
    local coeff = OF.util.optional("djui_hud_get_fov_coeff", nil)
    if type(coeff) ~= "number" then
        local fov = tonumber(OF.util.optional("get_current_fov", 45)) or 45
        coeff = math.tan(45 * math.pi / 360) / math.tan(fov * math.pi / 360) * 1.13
    end
    local scale = 256 * (height / 240) * coeff
    local cx = (sx - width * 0.5) / scale
    local cy = (height * 0.5 - sy) / scale
    local dx, dy, dz = fx + rx * cx + ux * cy, fy + uy * cy, fz + rz * cx + uz * cy
    local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
    return px, py, pz, dx / dl, dy / dl, dz / dl
end

function forge.update_mouse_aim(m)
    forge.mouseAim = nil
    if not forge.mouse_aim_on or not forge.open or m == nil then return nil end
    if not forge.mouse_driving() then return nil end
    if collision_find_surface_on_ray == nil then return nil end
    local sx, sy, width, height = forge.pointer()
    if sx == nil then return nil end
    local ox, oy, oz, dx, dy, dz = forge.screen_ray(sx, sy, width, height)
    if ox == nil then return nil end
    local reach = forge.MOUSE_REACH
    for _ = 1, 4 do
        local info = collision_find_surface_on_ray(ox, oy, oz, dx * reach, dy * reach, dz * reach)
        if info == nil or info.surface == nil or info.surface.normal == nil then return nil end
        local hx, hy, hz = info.hitPos.x, info.hitPos.y, info.hitPos.z
        local surface = info.surface

        if forge.held ~= nil and surface.object ~= nil and surface.object == forge.held then
            ox, oy, oz = hx + dx * 4, hy + dy * 4, hz + dz * 4
        else
            local n = surface.normal
            local nx, ny, nz = n.x or 0, n.y or 0, n.z or 0

            if nx * dx + ny * dy + nz * dz > 0 then nx, ny, nz = -nx, -ny, -nz end
            local lift = 0
            if ny > 0.5 then lift = math.max(0, forge.height - forge.MOUSE_LIFT_FROM) end
            local cell = ((OF.spawner or {}).BUILD_CELL) or 200
            local half = cell * 0.5
            local px, py, pz = hx + nx * half, hy + ny * half, hz + nz * half

            local bx, by, bz = hx - nx * half, hy - ny * half, hz - nz * half
            forge.mouseAim = {
                x = hx + nx * 2, y = hy + ny * 2 + lift, z = hz + nz * 2,
                nx = nx, ny = ny, nz = nz,
                cx = forge.cell_at(forge.cell_of(px)),
                cy = math.floor(py / cell) * cell,
                cz = forge.cell_at(forge.cell_of(pz)),
                hx = forge.cell_at(forge.cell_of(bx)),
                hy = math.floor(by / cell) * cell,
                hz = forge.cell_at(forge.cell_of(bz)),
            }
            return forge.mouseAim
        end
    end
    return nil
end

function forge.mouse_buttons(m, input, lHeld, rHeld)
    if m == nil or not forge.mouse_aim_on or not forge.mouse_driving() then return false end
    local did = false
    local wheel = tonumber(OF.util.optional("djui_hud_get_mouse_scroll_y", 0)) or 0
    local pressed = math.floor(tonumber(OF.util.optional("djui_hud_get_mouse_buttons_pressed", 0)) or 0)
    local down = math.floor(tonumber(OF.util.optional("djui_hud_get_mouse_buttons_down", 0)) or 0)
    local building = forge.build_live() and forge.held == nil

    if forge.held == nil and forge.path_mouse(m, wheel, pressed) then
        if R_MOUSE_BUTTON ~= nil and OF.util.has_flag(down, R_MOUSE_BUTTON) then
            OF.input.take(m, A_BUTTON)
        end
        return true
    end
    if wheel ~= 0 then

        local step = wheel > 0 and -1 or 1
        if building then
            if lHeld and rHeld then OF.util.report(forge.set_brush(forge.brush + (step > 0 and 1 or -1)))
            elseif lHeld then OF.util.report(forge.build_material_by(step))
            elseif rHeld then OF.util.report(forge.build_turn_by(step))
            else OF.util.report(forge.build_cycle_by(step)) end
        elseif forge.held == nil then
            forge.step_inventory(step)
        end
        did = true
    end

    local middle = forge.mouse_aim_mode == "pointer" and forge.orbit.clicked
        or (forge.mouse_aim_mode ~= "pointer" and M_MOUSE_BUTTON ~= nil
            and OF.util.has_flag(pressed, M_MOUSE_BUTTON))
    if middle then
        if building then
            OF.util.report(forge.build_flip_toggle())
        elseif forge.held == nil then
            local ok, what = forge.eyedrop()
            if not ok then OF.util.report(false, what)
            else OF.notify.show("@ is in slot @", "good", 3, what, forge.slot) end
        end
        did = true
    end
    if building and R_MOUSE_BUTTON ~= nil then
        if OF.util.has_flag(pressed, R_MOUSE_BUTTON) then
            OF.util.report(forge.build_take())
            did = true
        end

        if OF.util.has_flag(down, R_MOUSE_BUTTON) then OF.input.take(m, A_BUTTON) end
    end
    return did
end

function forge.cursor_hidden()
    if forge.wheelOpen or forge.toolWheelOpen then return true end
    if OF.util.asks(OF.emotes, "showing") and OF.emotes.showing() then return true end
    local spray = OF.spray
    if spray ~= nil and type(spray.wheel) == "table" and (spray.wheel.phase or 0) > 0 then
        return true
    end
    return false
end

function forge.draw_pointer()
    if not (forge.mouse_aim_on and forge.mouse_driving()) then return false end
    local x, y = forge.pointer()
    if x == nil then return false end
    local gold = OF.util.gold()
    OF.util.rect(x - 9, y - 1, 7, 3, gold.r, gold.g, gold.b, 230)
    OF.util.rect(x + 3, y - 1, 7, 3, gold.r, gold.g, gold.b, 230)
    OF.util.rect(x - 1, y - 9, 3, 7, gold.r, gold.g, gold.b, 230)
    OF.util.rect(x - 1, y + 3, 3, 7, gold.r, gold.g, gold.b, 230)
    return true
end

local shelfOpen = false

local EMPTY_CHORDS = {
    { mod = L_TRIG, mod2 = R_TRIG, button = B_BUTTON, legend = "L+R+B: put it back",
      run = function()

          local ok, placed, wanted, short, kind = forge.redo()
          if not ok then
              OF.util.report(false, placed)
          elseif kind == "delete" then

              OF.notify.show("Took @ object(s) down again", "good", 3, placed)
          elseif short ~= nil then
              OF.notify.show(short, "warn", 5)
          else
              OF.notify.show("Put back @ object(s)", "good", 3, placed)
          end
      end },

    { mod = L_TRIG, mod2 = R_TRIG, button = Z_TRIG, legend = "L+R+Z: mark a box",
      run = function() OF.util.report(forge.select_toggle()) end },
    { mod = L_TRIG, button = Z_TRIG, legend = "L+Z: one to the left",
      run = function()
          shelfOpen = true
          forge.step_inventory(-1)
      end },

    { mod = L_TRIG, button = B_BUTTON, legend = "L+B: take back the last",
      run = function()

          local ok, what, taken, kind, short = forge.undo()
          if not ok then
              OF.util.report(false, what)
          elseif kind == "restore" then
              if short ~= nil then
                  OF.notify.show(short, "warn", 5)
              else
                  OF.notify.show("Brought @ object(s) back", "good", 3, taken)
              end
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
      run = function()
          shelfOpen = true
          forge.step_inventory(1)
      end },
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

    if not lHeld and not rHeld then shelfOpen = false end

    if rHeld or lHeld then

        OF.input.lock_movement(m)
    end

    local both = lHeld and rHeld

    if lHeld and not both then

        local by = STEP
        if stickY > STICK_DEAD then
            forge.height = forge.height + by
        elseif stickY < -STICK_DEAD then
            forge.height = forge.height - by
        end
    end

    if rHeld and not both and math.abs(stickY) > STICK_DEAD then
        local by = STEP * (stickY > 0 and 1 or -1)
        forge.distance = OF.util.clamp(forge.distance + by,
            MIN_DISTANCE, MAX_DISTANCE)
    end
    if rHeld and not both and math.abs(stickX) > STICK_DEAD then
        local by = STEP * (stickX > 0 and 1 or -1)
        forge.sideways = OF.util.clamp(forge.sideways + by,
            -MAX_DISTANCE, MAX_DISTANCE)
    end

    return lHeld, rHeld, rx, ry, stickX, stickY
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
    forge.mouse_release()
    if not OF.util.asks(OF.input, "holds_mouse") then return false end
    if not OF.input.holds_mouse("forge") then return false end
    return OF.input.hold_mouse("forge", false)
end

local buildStick = { x = 0, y = 0, sector = 0, variant = 0, lFrames = 0 }

forge.WHEEL_DEAD = 40
forge.WHEEL_HOLD = 12
forge.wheelOpen = false

function forge.wheel_sector(rx, ry)
    rx, ry = tonumber(rx) or 0, tonumber(ry) or 0
    if math.sqrt(rx * rx + ry * ry) < forge.WHEEL_DEAD then return 0 end
    local count = #forge.SHAPE_FAMILIES

    local a = math.atan(rx, ry)
    local sector = math.floor(a / (2 * math.pi) * count + 0.5) % count
    return sector + 1
end

function forge.build_family_point(f)
    if forge.shape_family(forge.build_shape()) == f then return true end
    return forge.build_family_pick(f)
end

local function build_stick(rHeld, lHeld, rx, ry, sx, sy)
    sx, sy = tonumber(sx) or 0, tonumber(sy) or 0
    local both = rHeld and lHeld
    local wantX, wantY = 0, 0
    if rHeld and not lHeld then
        if math.abs(rx) > STICK_DEAD then wantX = rx > 0 and 1 or -1 end
        if math.abs(ry) > STICK_DEAD then wantY = ry > 0 and 1 or -1 end
    end

    if wantX ~= 0 and wantX ~= buildStick.x then
        OF.util.report(forge.build_turn_by(wantX))
    elseif wantX == 0 and wantY ~= 0 and wantY ~= buildStick.y then
        OF.util.report(forge.build_flip_toggle())
    end
    buildStick.x, buildStick.y = wantX, wantY

    local sector, variant = 0, 0
    if both then
        buildStick.lFrames = buildStick.lFrames + 1
        if buildStick.lFrames >= forge.WHEEL_HOLD then

            if not forge.wheelOpen and OF.sounds ~= nil then OF.sounds.ui("wheel_open", OF.sounds.OPEN) end
            forge.wheelOpen = true
        end
    else
        buildStick.lFrames = 0
        forge.wheelOpen = false
    end
    if forge.wheelOpen then
        sector = forge.wheel_sector(sx, sy)
        if sector ~= 0 and sector ~= buildStick.sector then
            local before = forge.build_shape()
            OF.util.report(forge.build_family_point(sector))
            if forge.build_shape() ~= before and OF.sounds ~= nil then OF.sounds.ui("wheel_tick", OF.sounds.MOVE) end
        end
        if math.abs(rx) > forge.WHEEL_DEAD then variant = rx > 0 and 1 or -1 end
        if variant ~= 0 and variant ~= buildStick.variant then
            local before = forge.build_shape()
            OF.util.report(forge.build_shape_by(variant))
            if forge.build_shape() ~= before and OF.sounds ~= nil then OF.sounds.ui("wheel_tick", OF.sounds.MOVE) end
        end

        forge.kitTouched = get_global_timer ~= nil and get_global_timer() or 0
    end
    buildStick.sector, buildStick.variant = sector, variant
end

function forge.build_keys(m, input, rHeld, lHeld, rx, ry)
    local took = false
    local function edge(button, run)
        if input.pressed(button) then
            OF.util.report(run())
            OF.input.take(m, button)
            took = true
        end
    end

    if rHeld and lHeld then

        if forge.wheelOpen then
            if math.abs(rx) > STICK_DEAD or math.abs(ry) > STICK_DEAD then return false end

            edge(L_CBUTTONS, function() return forge.build_shape_by(-1) end)
            edge(R_CBUTTONS, function() return forge.build_shape_by(1) end)
            edge(U_CBUTTONS, function() return forge.build_family_by(-1) end)
            edge(D_CBUTTONS, function() return forge.build_family_by(1) end)
            return took
        end
        edge(L_CBUTTONS, function()
            local ok, what = forge.pick_block(m)
            if ok then OF.notify.show("Picked @", "good", 2, OF.lang.t(what or "")) return true end
            return ok, what
        end)
        edge(R_CBUTTONS, function()
            local ok, what = forge.reshape_block(m, 1)
            if ok then return true end
            return ok, what
        end)
        edge(U_CBUTTONS, function()
            local ok, why = forge.sym_next(m)
            if ok then OF.notify.show("Symmetry: @", "info", 2, OF.lang.t(forge.sym_name())) end
            return ok, why
        end)
        edge(D_CBUTTONS, function()
            local ok, why = forge.build_tool_next()
            if ok then OF.notify.show("B: @", "info", 2, OF.lang.t(forge.build_tool_name())) end
            return ok, why
        end)
        return took
    end
    if math.abs(rx) > STICK_DEAD or math.abs(ry) > STICK_DEAD then return false end
    if rHeld == lHeld then return false end
    if rHeld then
        edge(L_CBUTTONS, function() return forge.build_turn_by(-1) end)
        edge(R_CBUTTONS, function() return forge.build_turn_by(1) end)
        edge(U_CBUTTONS, forge.build_flip_toggle)
        edge(D_CBUTTONS, forge.build_flip_toggle)
    else
        edge(L_CBUTTONS, function() return forge.build_shape_by(-1) end)
        edge(R_CBUTTONS, function() return forge.build_shape_by(1) end)
        edge(U_CBUTTONS, function() return forge.build_family_by(-1) end)
        edge(D_CBUTTONS, function() return forge.build_family_by(1) end)

    end
    return took
end

forge.bHeldOver = false

function forge.hold_b_over(m, input)
    if m == nil or input == nil then return false end
    if input.pressed(B_BUTTON) then forge.bHeldOver = true end
    if not forge.bHeldOver then return false end
    if not input.held(B_BUTTON) then
        forge.bHeldOver = false
        return false
    end
    OF.input.take(m, B_BUTTON)
    return true
end

function forge.screen_over()
    return OF.util.menu_has_screen() == true
end

function forge.claims_b()
    if forge.bHeldOver then return true end
    return forge.open == true and not forge.screen_over()
end

local function on_before_mario_update(m)
    if m.playerIndex ~= 0 then return end
    if not forge.open or forge.screen_over() then
        release_controls()

        shelfOpen = false
        forge.wheelOpen = false
        forge.toolWheelOpen = false
        forge.mouseAim = nil
        forge.bHeldOver = false
        return
    end

    OF.input.poll(m)
    local input = OF.input
    forge.hold_b_over(m, input)

    if forge.tool_wheel_update(m, input) then
        OF.input.claim_camera(m)
        return
    end

    if forge.stretchHold ~= nil then forge.stretch_hold(m, input) end

    local lHeld, rHeld, rx, ry, sx, sy = cursor_chords(m, input)

    forge.mouse_hold_update()
    forge.update_mouse_aim(m)
    forge.mouse_buttons(m, input, lHeld, rHeld)

    if forge.held == nil and forge.path_input(m, input) then return end

    if forge.held == nil and forge.move_input(m, input) then return end

    if forge.held == nil then

        hold_camera(m, lHeld, rHeld, forge.group_count() > 0
            or (forge.build_live() and (rHeld or lHeld)))

        carry_group(m)
        if forge.select_live() then
            if rHeld and forge.group_count() > 0
                and math.abs(rx) > STICK_DEAD then

                OF.util.report(forge.group_turn(rx > 0 and 1 or -1,
                    0.5 * OF.input.forge_scale()))
            end

            local xBit = X_BUTTON or 0x0040

            if OF.util.has_flag(m.controller.buttonPressed or 0, xBit)
                and OF.util.has_flag(input.down, L_TRIG) and OF.util.has_flag(input.down, R_TRIG) then
                forge.delete_said()
                OF.input.take(m, xBit)
                return
            end
            if forge.marks() >= 2 and forge.group_count() == 0
                and OF.util.has_flag(m.controller.buttonPressed or 0, xBit) then
                OF.util.report(forge.box_fill(OF.util.has_flag(input.down, R_TRIG)))
                OF.input.take(m, xBit)
                return
            end

            if input.pressed(B_BUTTON)
                and not OF.util.has_flag(input.down, L_TRIG) then
                if OF.util.has_flag(input.down, R_TRIG) then
                    OF.util.report(forge.select_clear())
                else
                    OF.util.report(forge.select_act(m))
                end
                OF.input.take(m, B_BUTTON)
                return
            end

            if input.pressed(Z_TRIG)
                and OF.util.has_flag(input.down, L_TRIG)
                and not OF.util.has_flag(input.down, R_TRIG) then
                local ok, copied = forge.copy_selection()
                if not ok then
                    OF.util.report(false, copied)
                else
                    OF.notify.show("Copied @ - R+Z puts the copy down",
                        "good", 4, copied)
                end
                OF.input.take(m, Z_TRIG)
                return
            end
            if input.pressed(Z_TRIG)
                and OF.util.has_flag(input.down, R_TRIG)
                and not OF.util.has_flag(input.down, L_TRIG) then
                local ok, placed = forge.paste(m)
                if not ok then
                    OF.util.report(false, placed)
                else
                    OF.notify.show("The copy is down - @ placed", "good", 3,
                        placed)
                end
                OF.input.take(m, Z_TRIG)
                return
            end
        end

        if forge.build_live() then
            build_stick(rHeld, lHeld, rx, ry, sx, sy)
            forge.build_keys(m, input, rHeld, lHeld, rx, ry)

            if forge.tool_x(m, input) then return end
        else
            forge.wheelOpen = false
        end

        if forge.build_live() and input.pressed(Z_TRIG)
            and OF.util.has_flag(input.down, L_TRIG) ~= OF.util.has_flag(input.down, R_TRIG) then
            local step = OF.util.has_flag(input.down, R_TRIG) and 1 or -1
            OF.util.report(forge.build_material_by(step))
            OF.input.take(m, Z_TRIG)
            return
        end

        if forge.build_live() and input.pressed(B_BUTTON)
            and not OF.util.has_flag(input.down, L_TRIG) then
            if OF.util.has_flag(input.down, R_TRIG) then
                OF.util.report(forge.build_take())
            else
                OF.util.report(forge.build_place())
            end
            OF.input.take(m, B_BUTTON)
            return
        end

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

hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update, OF.LOCAL_MARIO)

hook_event(HOOK_ON_LEVEL_INIT, function()

    release_controls()
    forge.placed = {}
    forge.held = nil
    forge.heldKey = nil

    forge.forget_moved()

    forget_redo()
    forget_history()

    forge.publish_sizes()
    forge.publish_reach()

    forge.publish_moved()
end)

local PREVIEW_SEGMENTS = 20
local PREVIEW_RADIUS = 55

local PREVIEW_DROP = 40

local GUIDE_NAMES = { "Off", "Jump arcs" }
forge.guide = 1

local GUIDE_FALLBACK = 220

local jumpFrom = nil
local jumpPeak = nil
local jumpWas = nil
local bestApex = nil

function forge.guide_on()
    return (forge.guide or 1) > 1
end

function forge.set_guide(step)
    if type(step) ~= "number" then return false, "No such setting." end
    if GUIDE_NAMES[step] == nil then return false, "No such setting." end
    forge.guide = step
    return true
end

function forge.jump_apex()
    if bestApex ~= nil and bestApex > 0 then return bestApex, true end
    return GUIDE_FALLBACK, false
end

function forge.forget_jumps()
    jumpFrom, jumpPeak, jumpWas, bestApex = nil, nil, nil, nil
end

local function watch_the_jump(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if m.pos == nil then return end
    local action = m.action

    if action == ACT_JUMP and jumpWas ~= ACT_JUMP then
        jumpFrom, jumpPeak = m.pos.y, m.pos.y
    end
    jumpWas = action

    if jumpFrom == nil then return end
    if m.pos.y > (jumpPeak or m.pos.y) then jumpPeak = m.pos.y end

    if (action & ACT_FLAG_AIR) ~= 0 then return end
    local reached = (jumpPeak or jumpFrom) - jumpFrom
    if reached > (bestApex or 0) then bestApex = reached end
    jumpFrom, jumpPeak = nil, nil
end

hook_event(HOOK_MARIO_UPDATE, watch_the_jump, OF.LOCAL_MARIO)

hook_event(HOOK_ON_LEVEL_INIT, forge.forget_jumps)

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

function forge.draw_build_extras(m, cx, cy, cz, gold)
    if forge.brush_cells == nil then return 0 end
    local drawn = 0
    local cell = ((OF.spawner or {}).BUILD_CELL) or 200
    local half = cell * 0.5
    local aim = forge.mouseAim
    local nx, ny, nz = 0, 1, 0
    if aim ~= nil and m == gMarioStates[0] then nx, ny, nz = aim.nx, aim.ny, aim.nz end
    local function square(x, y, z, r, g, b, a)
        local p = { { x - half, y, z - half }, { x + half, y, z - half },
                    { x + half, y, z + half }, { x - half, y, z + half } }
        for i = 1, 4 do
            local q, w = p[i], p[i % 4 + 1]
            OF.util.world_line({ x = q[1], y = q[2], z = q[3] }, { x = w[1], y = w[2], z = w[3] },
                2, r, g, b, a)
            drawn = drawn + 1
        end
    end
    local cells = forge.build_tool == "lay" and forge.brush_cells(cx, cy, cz, nx, ny, nz)
        or { { x = cx, y = cy, z = cz } }
    for _, c in ipairs(cells) do
        if c.x ~= cx or c.y ~= cy or c.z ~= cz then square(c.x, c.y, c.z, gold.r, gold.g, gold.b, 140) end
        for _, img in ipairs(forge.sym_images(c.x, c.z)) do
            square(img.x, c.y, img.z, 120, 220, 255, 150)
        end
    end
    if forge.sym_on() then
        local s, reach = forge.sym, 1600
        if s.mode == "x" or s.mode == "xz" then
            OF.util.world_line({ x = s.x, y = cy, z = cz - reach }, { x = s.x, y = cy, z = cz + reach },
                2, 120, 220, 255, 170)
            drawn = drawn + 1
        end
        if s.mode == "z" or s.mode == "xz" then
            OF.util.world_line({ x = cx - reach, y = cy, z = s.z }, { x = cx + reach, y = cy, z = s.z },
                2, 120, 220, 255, 170)
            drawn = drawn + 1
        end
    end
    return drawn
end

function forge.ghost_line(a, b, r, g, bl, alpha)
    OF.util.world_line(a, b, 5, r * 0.2, g * 0.2, bl * 0.2, alpha * 0.55)
    OF.util.world_line(a, b, 3, r, g, bl, alpha)
end

function forge.ghost_alpha()
    local now = get_global_timer ~= nil and get_global_timer() or 0
    return 190 + 55 * (0.5 + 0.5 * math.sin(now * 2 * math.pi / 45))
end

local fullCache = { key = nil, at = -1000, full = false }
forge.FULL_CACHE_FRAMES = 3
function forge.cursor_full(cx, cy, cz)
    if forge.build_tool ~= nil and forge.build_tool ~= "lay" then return false end
    if type(forge.cell_here) ~= "function" then return false end
    local now = get_global_timer ~= nil and get_global_timer() or 0
    local key = tostring(cx) .. ":" .. tostring(cy) .. ":" .. tostring(cz)
    if fullCache.key ~= key or now - fullCache.at >= forge.FULL_CACHE_FRAMES then
        fullCache.key, fullCache.at = key, now
        fullCache.full = forge.cell_here(cx, cy, cz) ~= nil
    end
    return fullCache.full
end

function forge.forget_full_cache()
    fullCache.key, fullCache.at, fullCache.full = nil, -1000, false
end

local function draw_landing_spot()
    local m = gMarioStates[0]
    if m == nil then return end

    local x, y, z = carry_spot(m)
    local gold = OF.util.gold()
    local radius = PREVIEW_RADIUS * (SIZES[forge.size] or 1.0)

    if forge.build_live() then
        local cx, cy, cz = forge.cell_cursor(m)
        if cx ~= nil then
            x, y, z = cx, cy, cz
            radius = ((OF.spawner or {}).BUILD_CELL or 200) * 0.5

            local walk = forge.cell_walk ~= nil and forge.cell_walk(m, cx, cy, cz) or nil
            local c = walk ~= nil and forge.REACH_COLOURS[walk] or nil
            local lr, lg, lb = gold.r, gold.g, gold.b
            if c ~= nil then lr, lg, lb = c[1], c[2], c[3] end

            local full = forge.cursor_full(cx, cy, cz)
            if full then
                local bad = forge.REACH_COLOURS.out
                lr, lg, lb = bad[1], bad[2], bad[3]
            end
            local breath = forge.ghost_alpha()
            local guide = forge.build_guide(m)
            if guide ~= nil then
                for _, seg in ipairs(guide) do forge.ghost_line(seg[1], seg[2], lr, lg, lb, breath) end
            end
            if full then
                local half = radius
                forge.ghost_line({ x = cx - half, y = cy + 200, z = cz - half },
                    { x = cx + half, y = cy + 200, z = cz + half }, lr, lg, lb, breath)
                forge.ghost_line({ x = cx - half, y = cy + 200, z = cz + half },
                    { x = cx + half, y = cy + 200, z = cz - half }, lr, lg, lb, breath)
            end
            forge.draw_build_extras(m, cx, cy, cz, gold)

            OF.util.world_ring({ x = cx, y = cy, z = cz }, radius, PREVIEW_SEGMENTS, 3,
                lr, lg, lb, 210, "edge")
            return
        end
    end

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

local SELECT_MARK_RADIUS = 30
local SELECT_PIVOT_RADIUS = 70

local SELECT_WEDGE_HALF = 0x1800

local function draw_wire_box(box, size, gold, alpha)
    local cx = (box.minX + box.maxX) * 0.5
    local cz = (box.minZ + box.maxZ) * 0.5
    local hx = (box.maxX - box.minX) * 0.5
    local hz = (box.maxZ - box.minZ) * 0.5

    local corners = {
        { x = -hx, z = -hz }, { x = hx, z = -hz },
        { x = hx, z = hz }, { x = -hx, z = hz },
    }
    OF.util.world_outline({ x = cx, y = box.minY, z = cz }, corners, size,
        gold.r, gold.g, gold.b, alpha)
    OF.util.world_outline({ x = cx, y = box.maxY, z = cz }, corners, size,
        gold.r, gold.g, gold.b, alpha)

    for _, corner in ipairs(corners) do
        OF.util.world_line(
            { x = cx + corner.x, y = box.minY, z = cz + corner.z },
            { x = cx + corner.x, y = box.maxY, z = cz + corner.z },
            size, gold.r, gold.g, gold.b, math.floor(alpha * 0.7))
    end
end

local function draw_selection_box()
    if not forge.select_live() then return end
    local gold = OF.util.gold()

    local box = forge.selection()
    if box ~= nil then
        draw_wire_box(box, 2, gold, 150)
    else

        local first = forge.mark_at(1)
        if first ~= nil then
            OF.util.world_ring(first, SELECT_MARK_RADIUS, 12, 2,
                gold.r, gold.g, gold.b, 200)
        end
    end

    local frame = forge.group_frame()
    if frame == nil or frame.minX == nil then return end

    draw_wire_box(frame, 4, gold, 235)
    local pivot = { x = frame.x, y = frame.y, z = frame.z }
    OF.util.world_ring(pivot, SELECT_PIVOT_RADIUS, 16, 3,
        gold.r, gold.g, gold.b, 215)
    OF.util.world_wedge(pivot, SELECT_PIVOT_RADIUS * 1.6, frame.yaw,
        SELECT_WEDGE_HALF, 10, 3, gold.r, gold.g, gold.b, 175)
end

local ARC = { speed = 32, step = 3, frames = 90, refresh = 5,
              screen = { x = 0, y = 0, z = 0 }, at = { x = 0, y = 0, z = 0 } }
forge.JUMP_ARCS = {
    { name = "jump", up = 42, per = 0.25, keep = 0.8, cap = 32, gravity = 4 },
    { name = "double", up = 52, per = 0.25, keep = 0.8, cap = 32, gravity = 4 },
    { name = "triple", up = 69, per = 0, keep = 0.8, cap = 32, gravity = 4 },
    { name = "long jump", up = 30, per = 0, keep = 1.5, top = 48, cap = 48, gravity = 2 },
    { name = "backflip", up = 62, per = 0, back = 16, cap = 32, gravity = 4 },
}
ARC.cache = { ticks = ARC.refresh, list = nil }

function forge.engine_running_apex()
    local vy, y, apex = 42 + ARC.speed * 0.25, 0, 0
    while vy > 0 do
        y = y + vy
        vy = vy - 4
        if y > apex then apex = y end
    end
    return apex
end

function forge.arc_gravity_scale()
    local apex, measured = forge.jump_apex()
    local engine = forge.engine_running_apex()
    if not measured or apex <= engine then return 1 end
    return engine / apex
end

function forge.jump_arcs(x, y, z, yaw)
    local fx, fz = sins(yaw or 0), coss(yaw or 0)
    local scale = forge.arc_gravity_scale()
    local out = {}
    for _, arc in ipairs(forge.JUMP_ARCS) do
        local speed = ARC.speed
        local vy = arc.up + speed * arc.per
        local fwd
        if arc.back ~= nil then
            fwd = -arc.back
        else
            fwd = math.min(speed * arc.keep, arc.top or 999)
        end
        local px, py, pz = x, y + 2, z
        local points = { { x = px, y = py, z = pz } }
        local apex, landed = py, false
        for frame = 1, ARC.frames do

            if fwd >= 0 then
                fwd = math.max(0, fwd - 0.35) + 1.5
                if fwd > arc.cap then fwd = fwd - 1 end
                if fwd > arc.cap + 1 then fwd = arc.cap + 1 end
            else
                fwd = math.min(0, fwd + 0.35)
                if fwd < -16 then fwd = fwd + 2 end
            end
            local nx, ny, nz = px + fx * fwd, py + vy, pz + fz * fwd
            vy = math.max(vy - arc.gravity * scale, -75)

            if collision_find_surface_on_ray ~= nil and (frame % ARC.step == 0 or vy < 0) then
                local last = points[#points]
                local info = collision_find_surface_on_ray(last.x, last.y, last.z,
                    nx - last.x, ny - last.y, nz - last.z)
                if info ~= nil and info.surface ~= nil and frame > 1 then
                    table.insert(points, { x = info.hitPos.x, y = info.hitPos.y, z = info.hitPos.z })
                    landed = true
                    break
                end
            end
            px, py, pz = nx, ny, nz
            if py > apex then apex = py end
            if frame % ARC.step == 0 then table.insert(points, { x = px, y = py, z = pz }) end
            if py < y - 600 then break end
        end
        table.insert(out, { name = arc.name, points = points, apex = apex - (y + 2),
                            landed = landed })
    end
    return out
end

local function draw_jump_guide(gold)
    if not forge.guide_on() then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end

    local arcCache = ARC.cache
    arcCache.ticks = arcCache.ticks + 1
    if arcCache.list == nil or arcCache.ticks >= ARC.refresh then
        arcCache.ticks = 0
        arcCache.list = forge.jump_arcs(m.pos.x, m.pos.y, m.pos.z,
            m.faceAngle ~= nil and m.faceAngle.y or 0)
    end
    local drawn = 0
    for k, arc in ipairs(arcCache.list) do

        local alpha = math.max(90, 220 - (k - 1) * 30)
        for i = 2, #arc.points do
            OF.util.world_line(arc.points[i - 1], arc.points[i], 2,
                gold.r, gold.g, gold.b, alpha)
            drawn = drawn + 1
        end

        local top = nil
        for _, p in ipairs(arc.points) do
            if top == nil or p.y > top.y then top = p end
        end
        if top ~= nil and OF.util.world_screen ~= nil and OF.util.world_label ~= nil then
            ARC.at.x, ARC.at.y, ARC.at.z = top.x, top.y + 30, top.z
            if OF.util.world_screen(ARC.at, ARC.screen) then
                OF.util.world_label(ARC.screen.x, ARC.screen.y,
                    OF.lang.fill("@ @", OF.lang.t(arc.name), tostring(math.floor(arc.apex))),
                    0.45, 255, 255, 255, alpha)
            end
        end
    end
    return drawn
end

hook_event(HOOK_ON_LEVEL_INIT, function() ARC.cache.list = nil end)

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

local LOW_HEADROOM = 15

local HEADROOM_EVERY = 8
local headroomShown, headroomAt, headroomCount, headroomLimit = nil, 0, -1, -1
local headroomTick = 0

local function headroom_shown(placed)
    headroomTick = headroomTick + 1
    local limit = nil
    if headroomShown == nil or placed ~= headroomCount
        or limit ~= headroomLimit
        or headroomTick - headroomAt >= HEADROOM_EVERY then
        headroomShown = forge.headroom()
        headroomAt = headroomTick
        headroomCount = placed
        headroomLimit = limit
    end
    return headroomShown
end

local STATUS_GAP = "   "
local function status_gap(parts)
    table.insert(parts, { text = STATUS_GAP, r = 190, g = 190, b = 190 })
end

local function status_segments()
    local parts = {}

    local placed = forge.count()

    table.insert(parts, { text = OF.lang.fill("@ placed", placed),
        r = 235, g = 235, b = 235 })

    local free = headroom_shown(placed)
    if free ~= nil then
        status_gap(parts)
        local r, g, b = 190, 230, 190
        if free <= 0 then
            r, g, b = 255, 120, 110
        elseif free <= LOW_HEADROOM then
            r, g, b = 255, 200, 120
        end
        table.insert(parts, { text = OF.lang.fill("@ left", free),
            r = r, g = g, b = b })
    end

    local deleted = forge.restorable_count()
    if deleted > 0 then
        status_gap(parts)
        table.insert(parts, { text = OF.lang.fill("L+B brings @ back", deleted),
            r = 255, g = 190, b = 190 })
    end
    local waiting = forge.undone_count()
    if waiting > 0 then
        status_gap(parts)
        table.insert(parts, { text = OF.lang.fill("@ to put back", waiting),
            r = 200, g = 210, b = 240 })
    end
    local moved = forge.borrowed_count()
    if moved > 0 then
        status_gap(parts)
        table.insert(parts, {
            text = OF.lang.fill("@ of the level's moved", moved),
            r = 255, g = 210, b = 150 })
    end

    if forge.select_live() then
        local gold = OF.util.gold()
        local held = forge.group_count()
        local said
        if held > 0 then
            said = OF.lang.fill("@ in hand", held)
        elseif forge.marks() >= 2 then
            said = OF.lang.fill("@ in the box", forge.selected_count())
        elseif forge.marks() == 1 then
            said = OF.lang.t("one corner down")
        else
            said = OF.lang.t("no box yet")
        end
        status_gap(parts)
        table.insert(parts, { text = said, r = gold.r, g = gold.g, b = gold.b })

        local copied = forge.clipboard_count()
        if copied > 0 then
            status_gap(parts)
            table.insert(parts, { text = OF.lang.fill("@ copied", copied),
                r = 200, g = 210, b = 240 })
        end
    end

    return parts
end
forge.status_segments = status_segments

forge.LEGEND_PAD = 6
forge.LEGEND_EDGE = 16
forge.LEGEND_INSET = 4

function forge.legend_items(line)
    local out = {}
    if type(line) ~= "string" or line == "" then return out end
    local s = line:gsub("%s%s%s+", "\31")
    for piece in s:gmatch("[^\31]+") do
        piece = piece:match("^%s*(.-)%s*$")
        if piece ~= "" then out[#out + 1] = piece end
    end
    return out
end

function forge.legend_lines(title, chords, segments)
    local out = { title = {}, items = {}, status = segments or {} }
    if type(title) == "string" and title ~= "" then
        local mode, rest = title:match("^(.-)%s+%-%s+(.+)$")
        if mode ~= nil then
            out.title[1] = mode
            for _, item in ipairs(forge.legend_items(rest)) do out.items[#out.items + 1] = item end
        else
            out.title[1] = title
        end
    end
    for k = 1, 4 do
        local line = chords ~= nil and chords[k] or nil
        if type(line) == "table" and type(line.text) == "string" then
            for _, item in ipairs(forge.legend_items(line.text)) do
                out.items[#out.items + 1] = item
            end
        end
    end

    if forge.legend_kbm() then
        out.kbm = true
        for i, item in ipairs(out.items) do out.items[i] = forge.kbm_words(item) end

        if forge.build_live() and forge.held == nil then
            out.items[#out.items + 1] = OF.lang.t("wheel: shape")
        end
        if forge.mouse_aim_mode == "pointer" then
            out.items[#out.items + 1] = OF.lang.t("middle drag: look around")
        end
    end

    local kept, seen = {}, {}
    for _, item in ipairs(out.items) do
        if not seen[item] then
            seen[item] = true
            kept[#kept + 1] = item
        end
    end
    out.items = kept
    return out
end

forge.KBM_WORDS = {
    { "L+R+X", "both Shifts+I" },
    { "L+X", "left Shift+I" },
    { "R+X", "right Shift+I" },
    { "hold L+R", "hold both Shifts" },
    { "L+R+C", "both Shifts+arrows" },
    { "L+R+B", "both Shifts+click" },
    { "L+R+Z", "both Shifts+{Z}" },
    { "L+right stick", "left Shift+arrows" },
    { "R+right stick", "right Shift+arrows" },
    { "L+Z / R+Z", "left / right Shift+{Z}" },
    { "L+stick", "left Shift+WASD" },
    { "R+stick", "right Shift+WASD" },
    { "L+B", "left Shift+click" },
    { "L+Z", "left Shift+{Z}" },
    { "R+Z", "right Shift+{Z}" },
    { "up or down: upside down", "middle click: upside down" },
}

function forge.z_word()
    local input = OF.input
    if input ~= nil and type(input.button_said) == "function" then
        local word = input.button_said("Z", "kbm")
        if word ~= nil then return word end
    end
    return "K"
end

function forge.kbm_words(text)
    if type(text) ~= "string" then return text end
    local out = text
    if forge.build_live() and out:find("R+B", 1, true) == 1 then
        out = "right click" .. out:sub(4)
    end
    for _, pair in ipairs(forge.KBM_WORDS) do
        local at = out:find(pair[1], 1, true)
        while at ~= nil do
            out = out:sub(1, at - 1) .. pair[2] .. out:sub(at + #pair[1])
            at = out:find(pair[1], at + #pair[2], true)
        end
    end
    if out:find("R+B", 1, true) == 1 then out = "right Shift+click" .. out:sub(4) end
    if out:find("B:", 1, true) == 1 then out = "click:" .. out:sub(3) end
    if out:find("Z:", 1, true) == 1 then out = "{Z}:" .. out:sub(3) end
    if out:find("X:", 1, true) == 1 then out = "I:" .. out:sub(3) end
    if out:find("{Z}", 1, true) ~= nil then
        local z = forge.z_word()
        out = out:gsub("{Z}", function() return z end)
    end
    return out
end

function forge.legend_kbm()
    return OF.util.asks(OF.input, "device") and OF.input.device() == "mouse"
end

forge.CARD = {
    pad = 24,
    gap = 12,
    row = 26,
    rule = 10,
    maxW = 520,
    edge = 24,
}

function forge.card_split(text)
    text = tostring(text or "")
    local sentence = OF.hud ~= nil and OF.hud.sentence or function(t) return t end
    local key, rest = text:match("^(.-):%s+(.+)$")
    if key ~= nil and key ~= "" and #key <= 28 then return key, sentence(rest) end
    return nil, sentence(text)
end

function forge.card_device()
    return string.upper(OF.lang.t(forge.legend_kbm() and "Keyboard & mouse" or "Controller"))
end

function forge.card_layout(spec)
    local hud = OF.hud
    local C = forge.CARD
    local keyW, textW = 0, 0
    for _, r in ipairs(spec.rows or {}) do
        if r.key ~= nil then keyW = math.max(keyW, hud.ink_width(r.key, "body")) end
    end
    for _, r in ipairs(spec.rows or {}) do
        local w = hud.ink_width(r.text or "", "rowSmall")
        if r.key == nil then w = w - keyW - C.gap end
        textW = math.max(textW, w)
    end
    local footW = 0
    for _, seg in ipairs(spec.foot or {}) do footW = footW + (hud.measure(seg.text or "", "caption")) end
    local headW = hud.ink_width(spec.title or "", "heading") + C.gap * 2
        + hud.ink_width(spec.tag or "", "caption")
    local inner = math.max(headW, footW, keyW + (keyW > 0 and C.gap or 0) + textW)
    local w = math.min(C.maxW, math.ceil(inner + C.pad * 2))
    local _, _, capH = hud.cap("heading", 1, "A")
    local _, _, capB = hud.cap("body", 1, "A")
    local _, _, capC = hud.cap("caption", 1, "A")
    local h = (OF.hud.CARD_HEAD or (C.pad + capH)) + C.rule * 2 + 1
        + #(spec.rows or {}) * C.row - (C.row - capB)
        + ((spec.foot ~= nil and #spec.foot > 0) and (C.rule * 2 + 1 + capC) or 0)
        + C.pad
    return { w = w, h = math.ceil(h), keyW = keyW, capH = capH, capB = capB, capC = capC }
end

function forge.draw_card(spec, x, y, k, laid)
    local hud = OF.hud
    local C = forge.CARD
    laid = laid or forge.card_layout(spec)
    k = hud.clamp01(k or 1)
    local a = 255 * k
    local w, h = laid.w, laid.h
    hud.plate(x, y, w, h, { alpha = k })
    hud.rect(x + 2, y, w - 4, 3, "gold", a)
    local left, right = x + C.pad, x + w - C.pad
    local base
    if type(hud.card_header) == "function" then
        base = hud.card_header(x, y, w, spec.title or "", spec.tag, a, "ink")
    else
        base = y + C.pad + laid.capH
        hud.text_base(spec.tag or "", right, base, "caption", "mute", a, "right")
        hud.text_base(spec.title or "", left, base, "heading", "ink", a, "left")
    end
    local rule = base + C.rule
    hud.rect(left, rule, w - C.pad * 2, 1, "edge", 40 * k)
    base = rule + 1 + C.rule + laid.capB
    local textX = left + laid.keyW + (laid.keyW > 0 and C.gap or 0)
    local _, bodyBase = hud.cap("rowSmall", 1, "A")
    for i, r in ipairs(spec.rows or {}) do
        if r.key ~= nil then
            hud.text_base(r.key, left, base, "body", r.dim and "mute" or "ink", a, "left")
        end
        local from = r.key ~= nil and textX or left
        hud.name(r.text or "", from, base - bodyBase, "rowSmall", r.dim and "mute" or "ink2", a,
            "left", right - from, { key = (spec.id or "card") .. i })
        base = base + C.row
    end
    if spec.foot ~= nil and #spec.foot > 0 then
        rule = base - C.row + C.rule + (C.row - laid.capB) / 2
        hud.rect(left, rule, w - C.pad * 2, 1, "edge", 40 * k)
        base = rule + 1 + C.rule + laid.capC
        local fx = left
        local _, capBase = hud.cap("caption", 1, "A")
        for _, seg in ipairs(spec.foot) do
            local tone = { seg.r or 200, seg.g or 200, seg.b or 200 }
            fx = fx + (hud.text(seg.text or "", fx, base - capBase, "caption", tone, a) or 0)
        end
    end
    return x, y, w, h
end

function forge.draw_legend(lines)
    if lines == nil then return false end
    if OF.util.menu_has_screen() or OF.hud == nil then return false end
    if forge.wheelOpen then return false end
    local hud = OF.hud
    local sw, sh = hud.screen()
    local rows = {}
    for _, t in ipairs(lines.items or {}) do
        local key, text = forge.card_split(t)
        rows[#rows + 1] = { key = key, text = text }
    end
    if #rows == 0 and #(lines.title or {}) == 0 then return false end
    local spec = { id = "legend", title = lines.title[1] or OF.lang.t("Forge"),
        tag = forge.card_device(), rows = rows, foot = lines.status }
    local laid = forge.card_layout(spec)
    local x = sw - forge.CARD.edge - laid.w
    local y = math.floor((sh - laid.h) / 2)
    forge.draw_card(spec, x, y, 1, laid)
    return true, x, y, laid.w, laid.h
end

local function select_legend()
    return OF.lang.fill("B: @", OF.lang.t(forge.select_verb()))
        .. "   " .. OF.lang.t("R+B: drop the box")
        .. "   " .. OF.lang.t("L+Z: copy")
        .. "   " .. OF.lang.t("R+Z: put the copy down")
        .. "   " .. OF.lang.t("L+R+Z: done")
end

forge.HELP_CARD = {
    { "Place a block", "B", "left click" },
    { "Take one out", "R+B", "right click" },
    { "Undo", "L+B", "L-Shift + click" },
    { "Redo", "L+R+B", "both Shifts + click" },
    { "Texture back / next", "L+Z / R+Z", "L-Shift + wheel" },
    { "Cursor up / down", "L + left stick", "L-Shift + W / S" },
    { "Cursor in, out, sideways", "R + left stick", "R-Shift + WASD" },
    { "Turn / upside down", "R + right stick", "R-Shift + arrows" },
    { "Shape wheel", "hold L+R", "hold both Shifts" },
    { "Pick a family", "left stick", "WASD" },
    { "Pick a shape", "right stick", "arrows or wheel" },
    { "Copy, reshape, mirror, tool", "tap L+R, then C", "both Shifts + arrow" },
    { "Select: mark a box", "L+R+Z", "both Shifts + {Z}" },
    { "Tool wheel", "hold L, press X", "hold L-Shift, press I" },
}

function forge.help_card_lines()
    local out = {}
    for _, row in ipairs(forge.HELP_CARD) do
        local keys = OF.lang.t(row[3])
        if keys:find("{Z}", 1, true) ~= nil then
            local z = forge.z_word()
            keys = keys:gsub("{Z}", function() return z end)
        end
        out[#out + 1] = { what = OF.lang.t(row[1]), pad = OF.lang.t(row[2]), keys = keys }
    end
    return out
end

function forge.help_card_spec()
    local kbm = forge.legend_kbm()
    local rows = {}
    for _, line in ipairs(forge.help_card_lines()) do
        rows[#rows + 1] = { key = kbm and line.keys or line.pad, text = line.what }
    end
    return { id = "controls", title = OF.lang.t("Controls"), tag = forge.card_device(), rows = rows }
end

function forge.draw_help_card(width, height, layout, k)
    local spec = forge.help_card_spec()
    local laid = forge.card_layout(spec)
    k = k or 1
    local x = forge.CARD.edge - (1 - k) * 16
    local y = math.floor((height - laid.h) / 2)
    forge.draw_card(spec, x, y, k, laid)
    return { x, y, laid.w, laid.h }
end

function forge.help_card_width()
    if OF.hud == nil then return 0 end
    return forge.card_layout(forge.help_card_spec()).w
end

do

local WL = {
    linger = 45,
    plateH = 44,
    gap = 14,
    platePad = 14,
    icon = 26,
    iconGap = 10,
    middleW = 188, middleH = 132,
    hubPic = 40,
    rowH = 40, rowGap = 10, pic = 26,
    rowTop = 22,
    edge = 16,
    openFrames = 6, fadeFrames = 9,
}
forge.WHEEL = WL
forge.WHEEL_PLATE_H = WL.plateH
forge.WHEEL_ROW_H = WL.rowH
forge.WHEEL_GAP = WL.gap

forge.FAMILY_ICON = { Openings = "arch" }
function forge.family_icon(f)
    local family = forge.SHAPE_FAMILIES[f]
    if family == nil then return "cube" end
    return forge.FAMILY_ICON[family.name] or family.shapes[1] or "cube"
end

function forge.wheel_shown()
    if not forge.build_live() or forge.held ~= nil then return false end
    if forge.wheelOpen then return true end
    local now = get_global_timer ~= nil and get_global_timer() or 0
    return now - (forge.kitTouched or -1000) < WL.linger
end

function forge.wheel_ink_w(text, token)
    local hud = OF.hud
    if hud ~= nil and type(hud.ink_width) == "function" then return hud.ink_width(text, token) end
    return OF.util.width(text, 0.6)
end

function forge.wheel_plate_w()
    local widest = 0
    for _, family in ipairs(forge.SHAPE_FAMILIES) do
        widest = math.max(widest, forge.wheel_ink_w(OF.lang.t(family.name), "body"))
    end
    return math.max(150, math.ceil(WL.platePad * 2 + WL.icon + WL.iconGap + widest))
end

function forge.material_name(material)
    material = material or forge.build_material()
    local index = forge.build_index(material, "cube")
    local entry = build_entry(index or forge.build_pick)
    if entry == nil then return "" end
    if index ~= nil then return entry.name end
    local noun = forge.shape_name(forge.shape_of(entry))
    local name = tostring(entry.name or "")
    local cut = name:lower():find(" " .. noun:lower(), 1, true)
    return cut ~= nil and name:sub(1, cut - 1) or name
end

function forge.wheel_near(a, b, gap)
    return a[1] < b[1] + b[3] + gap and b[1] < a[1] + a[3] + gap
        and a[2] < b[2] + b[4] + gap and b[2] < a[2] + a[4] + gap
end

function forge.wheel_ring_boxes(cx, cy, r, w, h)
    local count = #forge.SHAPE_FAMILIES
    local step = 2 * math.pi / math.max(count, 1)
    local boxes = {}
    for f = 1, count do
        local a = (f - 1) * step
        boxes[f] = { cx + math.sin(a) * r - w * 0.5, cy - math.cos(a) * r - h * 0.5, w, h }
    end
    return boxes
end

function forge.wheel_radius_needed(w, h)
    local middle = { -WL.middleW * 0.5, -WL.middleH * 0.5, WL.middleW, WL.middleH }
    for r = 120, 640, 2 do
        local boxes = forge.wheel_ring_boxes(0, 0, r, w, h)
        local clear = true
        for i = 1, #boxes do
            if forge.wheel_near(boxes[i], middle, WL.gap) then clear = false break end
            for j = i + 1, #boxes do
                if forge.wheel_near(boxes[i], boxes[j], WL.gap) then clear = false break end
            end
            if not clear then break end
        end
        if clear then return r end
    end
    return 640
end

function forge.wheel_layout(width, height, reserve)
    local w, h = forge.wheel_plate_w(), WL.plateH

    local r = math.max(forge.wheel_radius_needed(w, h), 0.30 * math.min(width, height))
    local rowsH = 2 * WL.rowH + WL.rowGap

    local tall = (height - WL.edge * 2 - h - WL.rowTop - rowsH) * 0.5
    local wide = width * 0.5 - w * 0.5 - WL.edge
    r = math.max(80, math.min(r, tall, wide))
    local total = 2 * r + h + WL.rowTop + rowsH
    local cy = (height - total) * 0.5 + r + h * 0.5
    local cx = width * 0.5
    reserve = reserve or 0
    if reserve > 0 then

        local want = reserve + WL.gap + r + w * 0.5
        cx = math.min(math.max(cx, want), width - WL.edge - r - w * 0.5)
    end
    return { rx = r, ry = r, r = r, plates = forge.wheel_ring_boxes(cx, cy, r, w, h), cx = cx, cy = cy,
             plateW = w, rowLeft = reserve > 0 and (reserve + WL.gap) or 0,
             middle = { cx - WL.middleW * 0.5, cy - WL.middleH * 0.5, WL.middleW, WL.middleH },
             rowsY = cy + r + h * 0.5 + WL.rowTop }
end

forge.SHAPE_PICTURE_PREFIX = "of_shp_"
function forge.shape_picture_name(shape, flipped)
    local tag = type(shape) == "string" and shape ~= "" and shape or "cube"
    if flipped then
        local up = "u" .. tag
        local ST = OF.stretch
        if ST ~= nil and type(ST.SHAPES) == "table" then
            for _, s in pairs(ST.SHAPES) do
                if s.tag == up then return forge.SHAPE_PICTURE_PREFIX .. up end
            end
        end
    end
    return forge.SHAPE_PICTURE_PREFIX .. tag
end

function forge.shape_picture_info(shape, flipped)
    if OF.panel == nil or type(OF.panel.texture_info) ~= "function" then return nil end
    local info = OF.panel.texture_info(forge.shape_picture_name(shape, flipped))
    if info == nil and flipped then info = OF.panel.texture_info(forge.shape_picture_name(shape, false)) end
    return info
end

function forge.material_texture(material)
    material = material or forge.build_material()
    local entry = material ~= nil and OF.util.asks(OF.spawner, "build_find")
        and OF.spawner.build_find("blk" .. material) or nil
    local name = forge.picture_name(entry)
    if name == nil or OF.panel == nil or type(OF.panel.texture_info) ~= "function" then
        return nil
    end
    return OF.panel.texture_info(name)
end

function forge.draw_shape_picture(shape, x, y, size, info, alpha, flipped)
    alpha = math.max(0, math.min(255, math.floor((alpha or 255) + 0.5)))
    local hud = OF.hud
    local textured = info ~= nil and type(djui_hud_render_texture) == "function"
        and (tonumber(info.width) or 0) > 0 and (tonumber(info.height) or 0) > 0
    local sr, sg, sb = 6, 7, 12
    if hud ~= nil then sr, sg, sb = hud.colour("shade") end
    djui_hud_set_color(sr, sg, sb, alpha)
    djui_hud_render_rect(x - 1, y - 1, size + 2, size + 2)
    if textured then
        djui_hud_set_color(255, 255, 255, alpha)
        djui_hud_render_texture(info, x, y, size / info.width, size / info.height)
    else
        djui_hud_set_color(176, 166, 150, alpha)
        djui_hud_render_rect(x, y, size, size)
    end
    local picture = type(djui_hud_render_texture) == "function" and forge.shape_picture_info(shape, flipped) or nil
    if picture == nil then return false end
    local restore = djui_hud_get_filter ~= nil and djui_hud_get_filter() or nil
    if djui_hud_set_filter ~= nil and FILTER_LINEAR ~= nil then djui_hud_set_filter(FILTER_LINEAR) end
    djui_hud_set_color(255, 255, 255, math.min(255, alpha * 2))
    djui_hud_render_texture(picture, x, y, size / picture.width, size / picture.height)
    if djui_hud_set_filter ~= nil and restore ~= nil then djui_hud_set_filter(restore) end
    return true
end

function forge.wheel_rows(layout, width)
    local family = forge.SHAPE_FAMILIES[forge.shape_family(forge.build_shape()) or 0]
    if family == nil then return {} end
    local material = forge.build_material()
    local shape = forge.build_shape()
    local items, lines = {}, {}
    local line = { total = 0 }
    lines[1] = line

    local lo = math.max(WL.edge, layout.rowLeft or 0)
    local hi = width - WL.edge
    local room = hi - lo
    for _, variant in ipairs(family.shapes) do
        local word = OF.lang.t(forge.shape_name(variant))
        local w = math.ceil(WL.platePad + WL.pic + WL.iconGap + forge.wheel_ink_w(word, "body") + WL.platePad)
        if line.total > 0 and line.total + w > room then
            line = { total = 0 }
            lines[#lines + 1] = line
        end
        local item = { shape = variant, word = word, w = w, here = variant == shape,
                       open = forge.build_index(material, variant) ~= nil }
        table.insert(line, item)
        line.total = line.total + w + WL.rowGap
        items[#items + 1] = item
    end
    local mid = layout.cx or width * 0.5
    for k, l in ipairs(lines) do
        local x = mid - (l.total - WL.rowGap) * 0.5
        x = math.max(lo, math.min(x, hi - (l.total - WL.rowGap)))
        for _, item in ipairs(l) do
            item.x, item.y = x, layout.rowsY + (k - 1) * (WL.rowH + WL.rowGap)
            x = x + item.w + WL.rowGap
        end
    end
    return items
end

local wheelLook = { wasOpen = false, openedAt = -1000, family = nil, familyAt = -1000 }
forge.wheelLook = wheelLook

function forge.wheel_motion(now)
    local fade = 1
    if not forge.wheelOpen then
        local left = WL.linger - (now - (forge.kitTouched or -1000))
        fade = math.max(0, math.min(1, left / WL.fadeFrames))
    end
    local open = 1
    if forge.wheelOpen then open = math.max(0, math.min(1, (now - wheelLook.openedAt) / WL.openFrames)) end
    return open, fade
end

function forge.wheel_icon_label(hud, shape, word, cx, cy, pic, token, tone, info, a)
    local lw = hud.ink_width(word, token)
    local left = cx - (pic + WL.iconGap + lw) * 0.5
    forge.draw_shape_picture(shape, left, cy - pic * 0.5, pic, info, a)
    hud.text_mid(word, left + pic + WL.iconGap, cy, token, tone, a, "left")
end

function forge.draw_shape_wheel()
    if not forge.wheel_shown() then return false end
    local hud = OF.hud
    if hud == nil then return false end
    local width, height = hud.screen()
    local now = get_global_timer ~= nil and get_global_timer() or 0
    if forge.wheelOpen and not wheelLook.wasOpen then wheelLook.openedAt = now end
    wheelLook.wasOpen = forge.wheelOpen == true
    local open, fade = forge.wheel_motion(now)
    local k = hud.ease.out_cubic(open)

    local reserve = 0
    if forge.wheelOpen then reserve = forge.CARD.edge + forge.help_card_width() end
    local layout = forge.wheel_layout(width, height, reserve)
    local cx, cy = layout.cx, layout.cy
    local accent = "gold"
    local shape = forge.build_shape()
    local inHand = forge.shape_family(shape)
    if inHand ~= wheelLook.family then wheelLook.family, wheelLook.familyAt = inHand, now end
    local pop = math.min(1, (now - wheelLook.familyAt) / 4)
    local a = 255 * fade
    local info = forge.material_texture()
    hud.wheel_chrome({ cx = cx, cy = cy, rx = layout.r, ry = layout.r,
        count = #forge.SHAPE_FAMILIES, selected = inHand, fade = fade, open = open,
        accent = accent, hubRadius = WL.middleH * 0.5, wash = forge.wheelOpen == true })
    for f, family in ipairs(forge.SHAPE_FAMILIES) do
        local p = layout.plates[f]
        local fam = forge.family_open(f)
        local here = f == inHand

        local mx = cx + (p[1] + p[3] * 0.5 - cx) * (0.72 + 0.28 * k)
        local my = cy + (p[2] + p[4] * 0.5 - cy) * (0.72 + 0.28 * k)
        hud.wheel_slot(mx, my, p[3], p[4], here and pop or 0, fade, accent, not fam)
        local tone = here and accent or (fam and "ink" or "mute")
        forge.wheel_icon_label(hud, forge.family_icon(f), OF.lang.t(family.name), mx, my, WL.icon, "body", tone,
            info, a * (fam and 1 or 0.55))
    end

    local said = OF.lang.t(forge.shape_name(shape))
    local texture = OF.lang.t(forge.material_name())
    local turned = OF.lang.t(forge.build_turn_name())
    if forge.build_flip and forge.build_flippable() then
        turned = OF.lang.fill("@, upside down", turned)
    end
    local room = WL.middleW - 24
    local hx, hy = hud.wheel_hub(cx, cy, WL.middleW, WL.middleH, fade, true, accent)
    local hTop, hBase, capH = hud.cap("heading", 1, "A")
    local cTop, cBase, capC = hud.cap("caption", 1, "A")
    local stack = WL.hubPic + 10 + capH + 9 + capC + 7 + capC
    local top = cy - stack * 0.5 + 1
    forge.draw_shape_picture(shape, cx - WL.hubPic * 0.5, top, WL.hubPic, info, a,
        forge.build_flip == true and forge.build_flippable() == true)
    local lineY = top + WL.hubPic + 10 + capH * 0.5
    local function centred(text, token, tone, mid, t, bse, key)
        local w = math.min(room, hud.ink_width(text, token))
        hud.name(text, cx - w * 0.5, mid - (t + bse) * 0.5, token, tone, a, "left", room, { key = key })
    end
    centred(said, "heading", accent, lineY, hTop, hBase, "forge-hub-shape")
    lineY = lineY + capH * 0.5 + 9 + capC * 0.5
    centred(texture, "caption", "ink2", lineY, cTop, cBase, "forge-hub-texture")
    lineY = lineY + capC + 7
    centred(turned, "caption", "mute", lineY, cTop, cBase, "forge-hub-turn")

    for _, w in ipairs(forge.wheel_rows(layout, width)) do
        local mx, my = w.x + w.w * 0.5, w.y + WL.rowH * 0.5
        hud.wheel_slot(mx, my, w.w, WL.rowH, w.here and 1 or 0, fade, accent, not w.open)
        local tone = w.here and accent or (w.open and "ink" or "mute")
        forge.wheel_icon_label(hud, w.shape, w.word, mx, my, WL.pic, "body", tone, info, a * (w.open and 1 or 0.55))
    end

    if forge.wheelOpen then forge.draw_help_card(width, height, layout, k * fade) end
    return true
end
end

do
forge.TOOLS = {
    { key = "build",  name = "Build",        says = "blocks on the grid",            icon = "cube" },
    { key = "things", name = "Things",       says = "objects from the shelves" },
    { key = "move",   name = "Move & paths", says = "movers and their path points" },
    { key = "box",    name = "Select",       says = "mark, fill, fill hollow, drop" },
    { key = "paint",  name = "Paint",        says = "the texture in hand onto blocks", icon = "plate" },
}
forge.toolPick = "things"
forge.toolWheelOpen = false
forge.toolTouched = -1000
forge.TOOL_DEAD = 40

function forge.tool_index(key)
    for i, t in ipairs(forge.TOOLS) do if t.key == key then return i end end
    return nil
end

local PAINTS = { paint = true, surface = true }

function forge.current_tool()
    if forge.select_live() then return "box" end
    if forge.path_object() ~= nil then return "move" end
    if forge.build_live() then
        return PAINTS[forge.build_tool] and "paint" or "build"
    end
    return forge.toolPick == "move" and "move" or "things"
end

function forge.set_tool(key)
    if not OF.perms.can("spawn_object") then return false, "Your rank cannot do that." end
    if forge.tool_index(key) == nil then return false end
    if (key == "build" or key == "paint") and forge.build_count() == 0 then
        return false, "This build has no blocks to build with."
    end
    if key ~= "box" and forge.select_on then
        forge.select_on = false
        forge.selectFromBuild = false
        forge.clear_selection()
    end
    if key ~= "move" and forge.path ~= nil then forge.path = nil end
    if key == "build" or key == "paint" then
        if not forge.build_on then
            forge.drop()
            forge.build_on = true
        end
        if key == "paint" and not PAINTS[forge.build_tool] then forge.build_tool = "paint" end
        if key == "build" and PAINTS[forge.build_tool] then forge.build_tool = "lay" end
    elseif key == "box" then
        if not forge.select_on then
            forge.drop()
            forge.selectFromBuild = forge.build_on == true
            forge.build_on = false
            forge.select_on = true
        end
    else
        forge.build_on = false
        forge.toolPick = key
    end
    return true
end

function forge.tool_step(step)
    local at = forge.tool_index(forge.current_tool()) or 1
    local n = #forge.TOOLS

    for k = 1, n do
        local key = forge.TOOLS[(at - 1 + step * k) % n + 1].key
        if forge.set_tool(key) then return true end
    end
    return false
end

function forge.tool_sector(x, y)
    x, y = tonumber(x) or 0, tonumber(y) or 0
    if math.sqrt(x * x + y * y) < forge.TOOL_DEAD then return 0 end
    local count = #forge.TOOLS
    local a = math.atan(x, y)
    return math.floor(a / (2 * math.pi) * count + 0.5) % count + 1
end

local toolStick = { sector = 0 }

local function now_frame()
    return get_global_timer ~= nil and get_global_timer() or 0
end

function forge.tool_wheel_update(m, input)
    if m == nil or input == nil then return false end
    local l = OF.util.has_flag(input.down, L_TRIG)
    local r = OF.util.has_flag(input.down, R_TRIG)
    local xBit = X_BUTTON or 0x0040
    local xPressed = OF.util.has_flag(m.controller.buttonPressed or 0, xBit)
    if not forge.toolWheelOpen then
        if not (l and not r and xPressed and forge.held == nil) then return false end
        forge.toolWheelOpen = true
        toolStick.sector = forge.tool_sector(m.controller.stickX, m.controller.stickY)
        if OF.sounds ~= nil then OF.sounds.ui("wheel_open", OF.sounds.OPEN) end
        OF.input.take(m, xBit)
        forge.toolTouched = now_frame()
        OF.input.lock_movement(m)
        return true
    end
    if not l then
        forge.toolWheelOpen = false
        forge.toolTouched = now_frame()
        return false
    end
    local sector = forge.tool_sector(m.controller.stickX, m.controller.stickY)
    OF.input.lock_movement(m)
    local before = forge.current_tool()
    if sector ~= 0 and sector ~= toolStick.sector then
        OF.util.report(forge.set_tool(forge.TOOLS[sector].key))
    end
    toolStick.sector = sector
    if xPressed then
        OF.util.report(forge.tool_step(1))
        OF.input.take(m, xBit)
    end
    if input.pressed(R_CBUTTONS) then forge.tool_step(1) end
    if input.pressed(L_CBUTTONS) then forge.tool_step(-1) end
    for _, button in ipairs({ B_BUTTON, Z_TRIG, R_CBUTTONS, L_CBUTTONS, U_CBUTTONS, D_CBUTTONS }) do
        OF.input.take(m, button)
    end
    if forge.current_tool() ~= before and OF.sounds ~= nil then OF.sounds.ui("wheel_tick", OF.sounds.MOVE) end
    forge.toolTouched = now_frame()
    return true
end

forge.MOVER_KINDS = { "block", "log", "logwide" }
forge.MOVER_KIND_NAMES = { block = "the block in hand, moving", log = "a rolling log",
    logwide = "a wide rolling log" }
forge.moverKind = "log"
function forge.mover_kind_by(step)
    local kinds = {}
    for _, k in ipairs(forge.MOVER_KINDS) do
        if k ~= "block" or forge.build_count() > 0 then kinds[#kinds + 1] = k end
    end
    local at = 1
    for i, k in ipairs(kinds) do if k == forge.moverKind then at = i end end
    forge.moverKind = kinds[(at - 1 + step) % #kinds + 1]
    OF.sounds.ui("move", OF.sounds.MOVE)
    return true
end

function forge.mover_kind_name()
    return forge.MOVER_KIND_NAMES[forge.moverKind] or ""
end

function forge.move_input(m, input)
    if forge.current_tool() ~= "move" or forge.path_object() ~= nil then return false end
    local l = OF.util.has_flag(input.down, L_TRIG)
    local r = OF.util.has_flag(input.down, R_TRIG)
    if input.pressed(Z_TRIG) and (l ~= r) then
        OF.util.report(forge.mover_kind_by(r and 1 or -1))
        OF.input.take(m, Z_TRIG)
        return true
    end
    if input.pressed(B_BUTTON) and not l then
        if r then
            OF.util.report(forge.path_begin(m))
        else
            OF.util.report(forge.mover_place(forge.moverKind))
        end
        OF.input.take(m, B_BUTTON)
        return true
    end
    return false
end

function forge.tool_x(m, input)
    local xBit = X_BUTTON or 0x0040
    if not OF.util.has_flag(m.controller.buttonPressed or 0, xBit) then return false end
    if OF.util.has_flag(input.down, L_TRIG) then return false end
    local tool = forge.current_tool()
    if tool == "build" then
        local ok, why = forge.set_brush(forge.brush + 1)
        if ok then OF.notify.show("Brush: @", "info", 2, forge.brush_name()) else OF.util.report(ok, why) end
    elseif tool == "paint" then
        forge.build_tool = forge.build_tool == "surface" and "paint" or "surface"
        OF.notify.show("B: @", "info", 2, OF.lang.t(forge.build_tool_name()))
        OF.sounds.ui("move", OF.sounds.MOVE)
    else
        return false
    end
    OF.input.take(m, xBit)
    return true
end

forge.TOOLS_LINE = "L+X: tools"
function forge.move_legend()
    return OF.lang.fill("Move & paths  -  B: put down @   R+B: edit the path you aim at",
            OF.lang.t(forge.mover_kind_name())),
        OF.lang.t("L+Z / R+Z: what B puts down   L+B: take back the last   L+R+B: put it back")
end

function forge.tool_wheel_shown()
    return forge.open == true and forge.toolWheelOpen == true
end

function forge.tool_plate_w()
    local WL = forge.WHEEL
    local widest = 0
    for _, t in ipairs(forge.TOOLS) do
        widest = math.max(widest, forge.wheel_ink_w(OF.lang.t(t.name), "body"))
    end
    return math.max(150, math.ceil(WL.platePad * 2 + WL.icon + WL.iconGap + widest))
end

function forge.tool_wheel_layout(width, height)
    local WL = forge.WHEEL
    local w, h = forge.tool_plate_w(), WL.plateH
    local count = #forge.TOOLS
    local function ring(r)
        local boxes = {}
        for i = 1, count do
            local a = (i - 1) * 2 * math.pi / count
            boxes[i] = { width * 0.5 + math.sin(a) * r - w * 0.5, height * 0.5 - math.cos(a) * r - h * 0.5, w, h }
        end
        return boxes
    end
    local middle = { width * 0.5 - WL.middleW * 0.5, height * 0.5 - WL.middleH * 0.5, WL.middleW, WL.middleH }
    local r = 120
    for tryR = 120, 640, 2 do
        r = tryR
        local boxes = ring(r)
        local clear = true
        for i = 1, count do
            if forge.wheel_near(boxes[i], middle, WL.gap) then clear = false end
            for j = i + 1, count do
                if forge.wheel_near(boxes[i], boxes[j], WL.gap) then clear = false end
            end
        end
        if clear then break end
    end
    return { cx = width * 0.5, cy = height * 0.5, r = r, plates = ring(r), plateW = w }
end

forge.toolLook = { openedAt = -1000, wasOpen = false }

function forge.draw_tool_wheel()
    if not forge.tool_wheel_shown() then
        forge.toolLook.wasOpen = false
        return false
    end
    local hud = OF.hud
    if hud == nil then return false end
    local WL = forge.WHEEL
    local width, height = hud.screen()
    local now = now_frame()
    local look = forge.toolLook
    if not look.wasOpen then look.openedAt = now end
    look.wasOpen = true
    local open = math.max(0, math.min(1, (now - look.openedAt) / WL.openFrames))
    local k = hud.ease.out_cubic(open)
    local layout = forge.tool_wheel_layout(width, height)
    local cx, cy = layout.cx, layout.cy
    local accent = "gold"
    local here = forge.tool_index(forge.current_tool()) or 1
    local info = forge.material_texture()
    hud.wheel_chrome({ cx = cx, cy = cy, rx = layout.r, ry = layout.r,
        count = #forge.TOOLS, selected = here, fade = 1, open = open,
        accent = accent, hubRadius = WL.middleH * 0.5, wash = true })
    for i, t in ipairs(forge.TOOLS) do
        local p = layout.plates[i]
        local mx = cx + (p[1] + p[3] * 0.5 - cx) * (0.72 + 0.28 * k)
        local my = cy + (p[2] + p[4] * 0.5 - cy) * (0.72 + 0.28 * k)
        local usable = (t.key ~= "build" and t.key ~= "paint") or forge.build_count() > 0
        hud.wheel_slot(mx, my, p[3], p[4], i == here and 1 or 0, 1, accent, not usable)
        local tone = i == here and accent or (usable and "ink" or "mute")
        local word = OF.lang.t(t.name)
        if t.icon ~= nil then
            forge.wheel_icon_label(hud, t.icon == "cube" and forge.build_shape() or t.icon, word,
                mx, my, WL.icon, "body", tone, info, 255 * (usable and 1 or 0.55))
        else
            hud.text_mid(word, mx, my, "body", tone, 255, "center")
        end
    end

    hud.wheel_hub(cx, cy, WL.middleW, WL.middleH, 1, true, accent)
    local tool = forge.TOOLS[here]
    local hT, hB, capH = hud.cap("heading", 1, "A")
    local cT, cB, capC = hud.cap("caption", 1, "A")
    local room = WL.middleW - 24
    local lineY = cy - (capH + 10 + capC) * 0.5 + capH * 0.5
    local name = OF.lang.t(tool.name)
    local nameW = math.min(room, hud.ink_width(name, "heading"))
    hud.name(name, cx - nameW * 0.5, lineY - (hT + hB) * 0.5, "heading", accent, 255, "left", room,
        { key = "forge-tool-hub" })
    lineY = lineY + capH * 0.5 + 10 + capC * 0.5
    local says = OF.lang.t(tool.says)
    local saysW = math.min(room, hud.ink_width(says, "caption"))
    hud.name(says, cx - saysW * 0.5, lineY - (cT + cB) * 0.5, "caption", "ink2", 255, "left", room,
        { key = "forge-tool-says" })
    return true
end
end

local function render()
    if not forge.open then return end
    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    draw_warp_sparkles()

    forge.draw_tracks(true)

    draw_jump_guide(OF.util.gold())

    draw_selection_box()

    local text
    local under = nil
    local turning = nil
    local build4 = nil
    if forge.path_object() ~= nil and forge.held == nil then

        local line, below = forge.path_legend()
        text = line
        under = { text = below }
    elseif forge.select_live() and forge.held == nil then

        text = OF.lang.fill("Select  -  B: @",
            OF.lang.t(forge.select_verb()))

        if forge.marks() >= 2 and forge.group_count() == 0 and forge.build_place_key() ~= nil then
            text = text .. "   " .. OF.lang.t("X: fill the box")
                .. "   " .. OF.lang.t("R+X: fill only its faces")
        end
        if forge.delete_count() > 0 then
            text = text .. "   " .. OF.lang.t("L+R+X: delete what is in it")
        end
        under = { text = select_legend() }
    elseif forge.build_live() and forge.held == nil then

        text = OF.lang.fill("Build  -  B: lay a @   R+B: take one out",
            forge.build_said())

        under = { text = OF.lang.t("L+B: take back the last   L+R+B: put it back   "
            .. "L+Z / R+Z: texture") }
        turning = { text = OF.lang.t(forge.build_flippable()
            and "R+right stick: turn it   up or down: upside down   hold L+R: shape wheel"
            or "R+right stick: turn it   hold L+R: shape wheel") }

        local tool = forge.build_tool ~= "lay" and OF.lang.t(forge.build_tool_name()) or nil
        if tool ~= nil then
            text = OF.lang.fill(forge.current_tool() == "paint" and "Paint  -  B: @" or "Build  -  B: @", tool)
        end
        build4 = { text = OF.lang.t("L+R+C: left pick, right reshape, up mirror, down tool") }

        if forge.current_tool() == "paint" then
            text = text .. "   " .. OF.lang.t("X: one block or a whole surface")
        else
            text = text .. "   " .. OF.lang.fill("X: brush @", forge.brush_name())
        end
    elseif forge.held == nil and forge.current_tool() == "move" then

        local line, below = forge.move_legend()
        text = line
        under = { text = below }
    elseif forge.held == nil and forge.in_hand() ~= nil
        and forge.aimed_at() ~= nil then

        text = OF.lang.t("Things  -  B: pick up what the ring is round")
        under = { text = empty_legend() }
    elseif forge.held == nil and forge.in_hand() ~= nil then

        text = OF.lang.fill("Things  -  B: another @",
            OF.lang.t(forge.kind_name() or ""))

        under = { text = empty_legend() }
    elseif forge.held == nil then

        text = OF.lang.t("Things  -  B: pick up")
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

    local toolsLine = forge.held == nil and { text = OF.lang.t(forge.TOOLS_LINE) } or nil
    forge.legendNow = forge.legend_lines(text, { under, turning, build4, toolsLine }, status_segments())
    forge.draw_legend(forge.legendNow)

    forge.draw_shape_wheel()
    forge.draw_tool_wheel()
    if not forge.cursor_hidden() then forge.draw_pointer() end

    if forge.held ~= nil then return end

    local barHidden = forge.wheelOpen == true

    if not forge.cursor_hidden() then draw_landing_spot() end

    forge.draw_paths()
    if barHidden then return end

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local cell, gap = 46, 6
    local total = BAR_SLOTS * cell + (BAR_SLOTS - 1) * gap
    local left = (screenWidth - total) * 0.5
    local top = screenHeight - cell - 26

    local shown = shelfOpen and BAR_PAGES or 1
    local blockTop = top - (shown - 1) * (cell + gap)

    for row = 1, shown do

        local page = shelfOpen and row or forge.inventory
        local rowTop = blockTop + (row - 1) * (cell + gap)
        local here = (page == forge.inventory)
        local slots = forge.bars[page] or {}

        for i = 1, BAR_SLOTS do
            local x = left + (i - 1) * (cell + gap)
            local mine = here and (i == forge.slot)
            local filled = slots[i] ~= nil

            local alpha = 110
            if mine then alpha = 255 elseif here then alpha = 165 end
            OF.util.plate(x, rowTop, cell, cell, {
                alpha = alpha,
                accent = mine and OF.util.gold() or nil,
            })

            local label = tostring(i)
            local width = OF.util.width(label, 0.5)
            local lit = filled and 255 or 140
            if not here then lit = math.floor(lit * 0.7) end
            OF.util.text(label, x + cell - width - 5, rowTop + cell - 16, 0.5,
                lit, lit, lit, here and 220 or 150)
        end

        local mark = here and (tostring(page) .. "/" .. tostring(BAR_PAGES))
            or tostring(page)
        OF.util.text(mark, left - OF.util.width(mark, 0.5) - 10,
            rowTop + cell - 16, 0.5, 255, 255, 255, here and 200 or 120)
    end

    local name = forge.slot_name(forge.slot)
    if name ~= nil then
        local said = OF.lang.t(name)
        local width = OF.util.width(said, 0.6)
        OF.util.text(said, (screenWidth - width) * 0.5, blockTop - 20, 0.6,
            255, 255, 255, 235)
    end
end

hook_event(HOOK_ON_HUD_RENDER, render)

forge.CATEGORIES = {

    { name = "Enemies", keys = {

        "goomba", "bobomb", "koopa", "bully", "chillbully",
        "chuckya", "spiny", "pokey", "spindrift", "blizzard", "scuttlebug",
        "heaveho", "moneybag", "montymole", "whomp", "thwomp",
        "chainchomp", "piranha", "firepiranha" } },

    { name = "Bosses", keys = {
        "kingbobomb", "whompking", "bigbully", "bigchill", "wiggler",
        "bowser", "finalbowser", "bowserbomb" } },

    { name = "Fliers and ghosts", keys = {
        "amp", "homingamp", "bulletbill", "swoop", "flyguy", "lakitu",
        "snufit", "klepto", "boo", "mrI", "bookend", "piano", "chair" } },

    { name = "In the water", keys = {
        "unagi", "bubba", "skeeter", "bub", "clam" } },

    { name = "Friends and scenery", keys = {
        "mips", "yoshi", "penguin", "tree", "cannon", "soundspot" } },

    { name = "Coins and pickups", keys = {
        "coin", "bluecoin", "redcoin", "coins", "1up", "1upwalk", "heart",
        "wingcap" } },

    { name = "Things to carry", keys = {
        "box", "smallbox", "exclam", "metalbox", "shell", "waterbomb",
        "bowling",

        "ball" } },

    { name = "Fire and hazards", keys = {
        "fire", "firespitter", "flamejet", "fireball", "firebar", "firebridge",
        "lavaplat", "toxbox", "tweester", "snowvent" } },

    { name = "Crushers and traps", keys = {
        "grindel", "grindelh", "spindel", "boulder", "pillar", "trapdoor",
        "fallwall", "risewall", "squishplat", "donut" } },

    { name = "Platforms", keys = {
        "stage",

        "onoff",

        "triblock",
        "checkplat", "floatplat", "raft", "kickboard", "tumbling", "logroll",
        "logwide", "rockblock", "sinkplat", "tugplat", "tiltplat",
        "meshplat",

        "trampoline" } },

    { name = "Lifts", keys = {
        "elevator", "arrowlift", "towerlift", "rrlift", "checkers", "ferris",
        "cageplat", "ttclift",

        "warppipe" } },

    { name = "Clockwork", keys = {
        "seesaw", "swingplat", "octaplat", "hexring", "ttccog",
        "ttcgear", "ttcsolid", "ttctread", "ttcpend", "ttcbar", "ttcpit",
        "ttcspin" } },

    { name = "Switches and posts", keys = {
        "purpleswitch", "capswitch", "blueswitch", "pole", "woodpost" } },

    { name = "Training courses", hidden = true, keys = { "logic" } },

    { name = "Shell Racer track", hidden = true, keys = {
        "racestart", "racegate", "racefinish", "racebox", "raceboost",
        "racecoin", "racerespawn", "raceout" } },
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

    stage       = "something to stand on that you shape yourself - it can sit still, turn or lift",
    trampoline  = "throws whoever lands on it back up into the air",
    warppipe    = "the game's pipe - pick a level or another pipe for it to lead to",
    onoff       = "one switch for the level: red blocks stand on ON, blue on OFF",
    triblock    = "a pink wedge at a wall's foot - run into it flat out to run up the wall",

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
    montymole   = "a hole with a mole in it that pops up and throws rocks",
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
    bowser      = "the whole fight anywhere - bombs are what hurt him",
    finalbowser = "the last fight - three bombs, shockwaves, and the Grand Star",

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
    bub         = "a fish that bites - it goes into water only",
    clam        = "it waits open, then shuts on whoever swims through",

    mips        = "catch him and carry him - he runs only in the castle",
    yoshi       = "he stays where you put him - talk to him for lives",
    penguin     = "you can pick her up and carry her about",
    tree        = "scenery with a hitbox, and nothing more than that",
    cannon      = "walk into it, aim, and fire yourself across the level",
    soundspot   = "a pad that plays a game sound whenever somebody steps on it",

    coin        = "worth one, and it stays exactly where you put it",
    bluecoin    = "worth five, and it hops away before it fades",
    redcoin     = "worth two, and it counts if the level has a red star",
    coins       = "eight coins in a shape, for one press",
    ["1up"]     = "an extra life for whoever touches it",
    ["1upwalk"] = "an extra life that runs away when you go for it",
    heart       = "spin through it and it gives your health back",
    wingcap     = "pick it up and fly - it stays until somebody takes it",

    box         = "smash it, and it bursts into coins",
    smallbox    = "holdable and throwable, and it breaks into a coin",
    exclam      = "hit it from below for what is inside",
    metalbox    = "heavy - push it about, and it holds a switch down",
    shell       = "ride it, and it carries you over water and lava",
    waterbomb   = "falls, bounces twice and bursts on the third landing",
    bowling     = "rolls off and keeps going - six make a hillside",
    ball        = "kick it, or land on top to roll it - A jumps, X gets off",

    fire        = "a flame that bounces along and then burns out",
    firespitter = "a small ball that stays put and spits flames at you",
    bowserbomb  = "bursts on touch - throw Bowser into one to hurt him",
    flamejet    = "an invisible jet that fires at anybody who comes near",
    fireball    = "an invisible vent, and what you see is what it throws",
    snowvent    = "an invisible vent that sends snow mounds sliding out",
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
    kickboard   = "punch it to rock it, then jump-kick its top to fell it",
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
    ttccog      = "Which cog",
    ttcgear     = "Which gear",
    ttcsolid    = "Which block",
    ttctread    = "Which treadmill",
    octaplat    = "Which platform",
    boulder     = "What a wall does to it",
    risewall    = "Where it starts",
    cageplat    = "How far it settles",
    capswitch   = "Which cap",
    exclam      = "What is inside",
    onoff       = "What it is, switch or block",
    soundspot   = "Which sound",
}

forge.VARIANT_HELP = {

    stage       = "press to change what it looks like and how it moves",
    trampoline  = "press to change how hard it throws you",
    tree        = "press to change which one you get",
    soundspot   = "press to change the sound it plays",
    thwomp      = "press to change how far it rises before each drop",
    tweester    = "press to change how far away it will start chasing",
    firepiranha = "press to change its size - the bigger one takes a hit",
    coins       = "press to change the shape the eight land in",
    seesaw      = "press to change the plank, and what it is made of",
    ttccog      = "press to change its shape",
    ttcgear     = "press to change which of the three it is",
    ttcsolid    = "press to change its shape",
    ttctread    = "press to change its size and which way it runs",
    octaplat    = "press to change its look and how fast it spins",
    boulder     = "press to change what it does when it meets a wall",
    risewall    = "press to change where in its cycle it starts",
    cageplat    = "press to change how far down it settles",
    capswitch   = "press to change which cap it switches on",
    exclam      = "press to change what comes out when it is hit",
    onoff       = "press to change between the switch and the two blocks",
}

forge.RECENT_TEXTURES = 8
forge.recentTextures = {}

function forge.remember_texture(material)
    if material == nil then return end
    local list = forge.recentTextures
    for i = #list, 1, -1 do
        if list[i] == material then table.remove(list, i) end
    end
    table.insert(list, 1, material)
    while #list > forge.RECENT_TEXTURES do table.remove(list) end
end

function forge.choose_texture(material)
    local index = forge.build_index(material, forge.build_shape())
        or forge.build_index(material, "cube")
    if index == nil then return false, "This build has no blocks to build with." end
    local ok, why = forge.choose_block(index)
    if ok then forge.remember_texture(material) end
    return ok, why
end

local function texture_cell(panel, entry, material, inHand)
    local count = forge.shape_count(material)
    return {
        name = OF.lang.t(entry.name),
        help = count > 1 and OF.lang.fill("@ shapes", tostring(count)) or OF.lang.t("cube only"),
        texture = forge.picture_name(entry),
        shape = forge.build_shape(),
        here = material == inHand,
        material = material,
        action = function()
            OF.util.report(forge.choose_texture(material))
            panel.close()
        end,
    }
end
forge.texture_cell = texture_cell

function forge.grid_rows(panel, rows, cells, keyBase, help)
    local per = panel.grid_columns()
    for start = 1, #cells, per do
        local chunk = {}
        for i = start, math.min(#cells, start + per - 1) do chunk[#chunk + 1] = cells[i] end
        table.insert(rows, panel.with_key(panel.grid_row(chunk, per, help, "spawn_object"),
            keyBase .. ":" .. tostring(math.floor((start - 1) / per) + 1)))
    end
end

function forge.inventory_first(panel, rows)
    table.insert(rows, panel.with_right(panel.header_row(OF.lang.t("Inventory")),
        OF.lang.fill("@ of @", tostring(forge.inventory), tostring(forge.inventory_count()))))
    local function press(index)
        return function()
            if forge.build_on == true then forge.build_toggle() end
            OF.util.report(forge.choose_slot(index))
            panel.close()
        end
    end

    local cells = {}
    for i = 1, forge.slot_count() do
        local name = forge.slot_name(i)
        cells[i] = {
            name = tostring(i) .. " " .. (name ~= nil and OF.lang.t(name) or OF.lang.t("empty")),
            help = OF.lang.t("picks this slot - what is in it is what B puts down"),
            here = i == forge.slot,
            action = press(i),
        }
    end
    table.insert(rows, panel.with_key(panel.grid_row(cells, #cells,
        OF.lang.t("picks this slot - what is in it is what B puts down"), "spawn_object"), "inv:slots"))

    table.insert(rows, panel.with_key(panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t("Next inventory"), 255, 255, 255, function()
            OF.util.report(forge.select_inventory(forge.inventory + 1))
        end), OF.lang.t("shows the next of the three bars here")), "inv:next"))
end

function forge.build_blocks_rows(panel, rows)

    forge.inventory_first(panel, rows)

    local shelves = {}
    for _, shelf in ipairs((OF.spawner or {}).BUILD_SHELVES or {}) do
        local first = OF.spawner.build_find(shelf.keys[1])
        if first ~= nil and forge.shape_of(first) == "cube" then
            table.insert(shelves, shelf)
        end
    end
    local inHand = forge.build_material()

    local recent = {}
    if #shelves > 1 then
        for _, material in ipairs(forge.recentTextures) do
            local entry = OF.spawner.build_find("blk" .. material)
            if entry ~= nil then table.insert(recent, entry) end
        end
    end
    local gridHelp = OF.lang.t("left and right walk the blocks; A takes one in the shape in hand")
    if #recent > 0 then
        table.insert(rows, panel.with_right(
            panel.header_row(OF.lang.t("Picked last")), tostring(#recent)))

        local cells = {}
        for _, entry in ipairs(recent) do
            cells[#cells + 1] = texture_cell(panel, entry, forge.material_of(entry), inHand)
        end
        forge.grid_rows(panel, rows, cells, "recent", gridHelp)
    end
    for _, shelf in ipairs(shelves) do
        if #shelves > 1 then
            table.insert(rows, panel.with_right(
                panel.header_row(OF.lang.t(shelf.name)), tostring(#shelf.keys)))
        end
        local cells = {}
        for _, key in ipairs(shelf.keys) do
            local entry = OF.spawner.build_find(key)
            local material = forge.material_of(entry)
            if entry ~= nil and material ~= nil then
                cells[#cells + 1] = texture_cell(panel, entry, material, inHand)
            end
        end
        forge.grid_rows(panel, rows, cells, "shelf:" .. tostring(shelf.name), gridHelp)
    end

    local decorRows = {}
    for index, entry in ipairs((OF.spawner or {}).BUILD_LIST or {}) do
        if entry.decor ~= nil then table.insert(decorRows, { index = index, entry = entry }) end
    end
    if #decorRows > 0 then
        table.insert(rows, panel.with_right(panel.header_row(OF.lang.t("Decor")),
            tostring(#decorRows)))
        local gold = OF.util.gold()
        for _, d in ipairs(decorRows) do
            local here = forge.build_pick == d.index and forge.prefabPick == nil
            table.insert(rows, panel.with_key(panel.with_help(
                panel.gated_row("spawn_object", OF.lang.t(d.entry.name),
                    here and gold.r or 255, here and gold.g or 255, here and gold.b or 255,
                    function()
                        OF.util.report(forge.choose_block(d.index))
                        panel.close()
                    end),
                OF.lang.t("one object - B lays it, R+right stick turns it")),
                "decor:" .. d.entry.key))
        end
    end

    local prefabs = forge.prefab_list()
    if #prefabs > 0 then
        table.insert(rows, panel.with_right(panel.header_row(OF.lang.t("Prefabs")),
            tostring(#prefabs)))
        local gold = OF.util.gold()
        for index, prefab in ipairs(prefabs) do
            local here = forge.prefabPick == index
            table.insert(rows, panel.with_right(panel.with_help(
                panel.gated_row("spawn_object", OF.lang.t(prefab.name),
                    here and gold.r or 255, here and gold.g or 255, here and gold.b or 255,
                    function()
                        OF.util.report(forge.prefab_choose(index))
                        panel.close()
                    end),
                OF.lang.t("B lays the whole build at the cursor - R+right stick turns it")),
                OF.lang.fill("@ blocks", tostring(#prefab.pieces))))
        end
        table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
            OF.lang.t("Save the marked box as a prefab"), 255, 255, 255, function()
                OF.util.report(forge.prefab_capture())
            end), OF.lang.t("your blocks inside the box, kept for tools/prefabs.py")))
    end
    table.insert(rows, panel.back_row())
    return rows
end

function forge.build_pick_page(panel)
    local rows = {}

    if forge.pick_blocks == true and forge.build_count() > 0 then
        return forge.build_blocks_rows(panel, rows)
    end

    forge.inventory_first(panel, rows)

    local shown = {}
    for _, shelf in ipairs(forge.CATEGORIES) do
        local entries = {}
        if shelf.hidden then
            for _, key in ipairs(shelf.keys) do shown[key] = true end
        end
        for _, key in ipairs(shelf.hidden and {} or shelf.keys) do
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

            if forge.build_on == true then forge.build_toggle() end

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

    if entry.pipe and forge.pipe_pick_begin ~= nil then
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("spawn_object", "  " .. OF.lang.t("Leads to..."),
                180, 210, 255, function()
                    if OF.util.report(forge.pipe_pick_begin(nil)) then panel.go("groups") end
                end),
            forge.pipe_dest_name(forge.pipeNext)),
            OF.lang.t("opens Travel to pick the level the next pipe leads to")))
    end
end

function forge.row_block_picture(panel, row)
    return panel.with_right_picture(row, forge.build_swatch(), forge.build_shape(),
        forge.build_flip == true and forge.build_flippable() == true)
end

function forge.build_page(panel)
    local rows = {}

    table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
        OF.lang.t(forge.open and "Forge is on - switch it off"
            or "Switch forge on"),
        255, 255, 255, function() OF.util.report(forge.toggle()) end),
        OF.lang.t("gives B to the hand; L+X in game opens the tools")))

    local notice = OF.util.mode_notice("forge")
    if notice ~= nil then table.insert(rows, panel.label_row(notice)) end

    if forge.held ~= nil then
        table.insert(rows, panel.label_row(
            OF.lang.t("Holding something. Close this to place it.")))
    end

    if forge.build_count() > 0 then
        table.insert(rows, panel.with_help(forge.row_block_picture(panel, panel.with_right(
            panel.gated_row("spawn_object", OF.lang.t("Block in hand"),
                255, 255, 255, function()
                    OF.util.report(forge.build_cycle_by(1))
                end),
            OF.lang.t(forge.build_name() or ""))),
            OF.lang.t("the next shape a press; hold L+R in game for the wheel")))

        table.insert(rows, panel.with_help(forge.row_block_picture(panel, panel.with_right(
            panel.gated_row("spawn_object", OF.lang.t("Put down the block in hand, moving"),
                255, 255, 255, function() OF.util.report(forge.mover_place("block")) end),
            OF.lang.t(forge.build_name() or ""))),
            OF.lang.t("at B's cell, on a path six cells ahead and back")))
    end

    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object",
            OF.lang.t("Things to place..."), 255, 255, 255,
            function()
                forge.pick_blocks = false
                panel.go("forgepick")
            end),
        tostring(#OF.spawner.LIST)),
        OF.lang.t("opens the shelves of everything there is to place")))

    if forge.build_count() > 0 then
        table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
            OF.lang.t("Choose a block..."), 255, 255, 255, function()
                if not forge.build_on then
                    local ok, why = forge.build_toggle()
                    if not ok then OF.util.report(ok, why) return end
                end
                forge.pick_blocks = true
                panel.go("forgepick")
            end),
            OF.lang.t("opens the shelves of blocks to build with")))
    end

    table.insert(rows, panel.with_help(panel.row(OF.lang.t("Level..."),
        255, 255, 255, function() panel.go("forgelevel") end),
        OF.lang.t("saving builds, the signposts players leave, and clearing")))
    table.insert(rows, panel.with_help(panel.row(OF.lang.t("Who builds..."),
        255, 255, 255, function() panel.go("forgerules") end),
        OF.lang.t("who may build, and how much space there is")))
    table.insert(rows, panel.with_help(panel.row(OF.lang.t("More..."),
        255, 255, 255, function() panel.go("forgemore") end),
        OF.lang.t("the box, paths, the tracks, inventories, your pad")))

    table.insert(rows, panel.back_row("fun"))
    return rows
end

function forge.level_page(panel)
    local rows = {}

    forge.keep_rows(panel, rows)

    if OF.util.asks(OF.sign, "build_posts_page") then
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("chat", OF.lang.t("Signposts players leave..."),
                255, 255, 255, function() panel.go("signposts") end),
            #OF.sign.posts() > 0
                and OF.lang.fill("@ up", tostring(#OF.sign.posts())) or ""),
            OF.lang.t("a board left where somebody stood, picked or written")))
    end

    table.insert(rows, panel.with_help(panel.with_right(panel.with_tone(panel.row(
        OF.lang.t("Clearing..."), 255, 200, 140, function() panel.go("forgeclearing") end),
        "danger"), tostring(#forge.placed)),
        OF.lang.t("your pieces, this level, a player's, every level, or all of it")))

    table.insert(rows, panel.back_row())
    return rows
end

function forge.rules_page(panel)
    local rows = {}
    local perms = OF.perms

    if OF.util.asks(perms, "required") and OF.util.asks(perms, "tiers_in_use") then
        local said = OF.lang.fill("@ and up", OF.lang.t(perms.tier_name(perms.required("spawn_object"))))
        if OF.util.is_host() and OF.util.asks(OF.find, "jump") then
            table.insert(rows, panel.with_help(panel.with_right(
                panel.row(OF.lang.t("Who may build..."), 255, 255, 255, function()
                    OF.find.jump("perms", "perm:spawn_object")
                end), said),
                OF.lang.t("opens the Forge's row on Ranks and permissions, where it is set")))
        else
            table.insert(rows, panel.with_right(panel.label_row(OF.lang.t("Who may build")), said))
        end
    end

    if OF.util.asks(OF.spawner, "room_text") then
        table.insert(rows, panel.with_right(
            panel.label_row(OF.lang.t("Space to build")),
            OF.spawner.room_text()))
    end

    if OF.spawner ~= nil and OF.spawner.RESERVE ~= nil then
        table.insert(rows, panel.with_right(
            panel.label_row(OF.lang.t("Kept back for the level's own")),
            tostring(OF.spawner.RESERVE)))
    end
    table.insert(rows, panel.with_right(
        panel.label_row(OF.lang.t("Levels that can keep a build")),
        OF.lang.fill("@ of @", tostring(#forge.keep_list()), tostring(forge.KEEP_LEVELS))))
    table.insert(rows, panel.with_right(
        panel.label_row(OF.lang.t("Pieces a kept build holds")),
        OF.lang.fill("about @", tostring(forge.KEEP_ROOM_GUESS))))

    table.insert(rows, panel.back_row())
    return rows
end

function forge.box_rows(panel, rows)

    local marking = forge.select_on == true
    local markRow = panel.gated_row("spawn_object",
        panel.tick(marking, OF.lang.t("Select - mark a box")),
        marking and 140 or 200, marking and 255 or 200, marking and 160 or 200,
        function() OF.util.report(forge.select_toggle()) end)

    markRow.mine = true
    table.insert(rows, panel.with_help(markRow,
        OF.lang.t("B marks two corners and then picks up everything inside")))
    if forge.marks() > 0 then
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("spawn_object", OF.lang.t("Drop the box"),
                255, 200, 140,
                function() OF.util.report(forge.select_clear()) end),
            tostring(forge.selected_count())),

            OF.lang.t("forgets the corners and leaves any build where it stands")))
    end

    if forge.marks() >= 2 and forge.build_count() > 0 then
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("spawn_object", OF.lang.t("Fill the box"), 255, 255, 255,
                function() OF.util.report(forge.box_fill(false)) end),
            OF.lang.t(forge.build_name() or "")),
            OF.lang.t("the block in hand in every cell; X in game")))
        table.insert(rows, panel.with_help(
            panel.gated_row("spawn_object", OF.lang.t("Fill the box, hollow"), 255, 255, 255,
                function() OF.util.report(forge.box_fill(true)) end),
            OF.lang.t("only the six faces; R+X in game")))
    end

    if forge.delete_count() > 0 then
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("spawn_object", OF.lang.t("Delete what is in the box"),
                255, 170, 150,
                function() forge.delete_said() end),
            tostring(forge.delete_count())),
            OF.lang.t("your pieces inside it, on one undo; L+R+X in game")))
    end
    if forge.clipboard_count() > 0 then
        table.insert(rows, panel.with_help(panel.with_right(
            panel.gated_row("spawn_object", OF.lang.t("Forget the copy"),
                255, 200, 140,
                function() OF.util.report(forge.forget_copy()) end),
            tostring(forge.clipboard_count())),
            OF.lang.t("empties what L+Z took, so R+Z stops offering it")))
    end
end

function forge.delete_said()
    local ok, taken = forge.delete_selection()
    if not ok then
        OF.util.report(false, taken)
        return false
    end

    OF.notify.show("Deleted @ - L+B brings them back", "warn", 4, taken)
    return true
end

function forge.inventory_rows(panel, rows)
    table.insert(rows, panel.header_row(OF.lang.t("Inventories")))

    local invRow = panel.with_right(panel.gated_row("spawn_object",
        OF.lang.t("Inventory"),
        255, 255, 255, function()
            OF.util.report(forge.select_inventory(forge.inventory + 1))
        end), OF.lang.fill("@ of @", tostring(forge.inventory),
            tostring(forge.inventory_count())))

    invRow.mine = true
    table.insert(rows, panel.with_help(panel.with_slider(invRow,
        forge.inventory - 1, forge.inventory_count() - 1, function(wanted)
            OF.util.report(forge.select_inventory(wanted + 1))
        end), OF.lang.t("which of the three bars the six rows below show")))

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
                function() OF.util.report(forge.choose_slot(index)) end),
            name ~= nil and OF.lang.t(name) or OF.lang.t("empty")),
            OF.lang.t("picks this slot - what is in it is what B puts down")))
    end
    if forge.in_hand() ~= nil then
        table.insert(rows, panel.with_help(panel.gated_row("spawn_object",
            OF.lang.t("Empty this slot"), 255, 200, 140,
            function() OF.util.report(forge.forget_kind()) end),
            OF.lang.t("forgets the kind in the slot you have picked")))
    end

    table.insert(rows, panel.with_help(panel.confirm_row("forgebar",
        OF.lang.t("Empty this inventory"), 255, 140, 90,
        function() OF.util.report(forge.clear_bar()) end),
        OF.lang.t("clears the six slots on screen and leaves the rest")))
    table.insert(rows, panel.with_help(panel.confirm_row("forgebars",
        OF.lang.t("Empty every inventory"), 255, 140, 90,
        function() OF.util.report(forge.clear_bars()) end),
        OF.lang.t("clears all eighteen slots, not only the six shown")))
end

function forge.pad_rows(panel, rows)
    table.insert(rows, panel.header_row(OF.lang.t("Your pad - yours only")))

    local aimRow = panel.gated_row("spawn_object",
        panel.tick(forge.mouse_aim_on, OF.lang.t("Aim with the mouse")),
        255, 255, 255, function()
            OF.util.report(forge.set_mouse_aim(not forge.mouse_aim_on))
        end)
    aimRow.mine = true
    table.insert(rows, panel.with_help(aimRow,
        OF.lang.t("the pointer places and builds; the wheel steps the shape")))

    local aimMode = panel.gated_row("spawn_object", "  " .. OF.lang.t("Mouse aims with"),
        255, 255, 255, function()
            OF.util.report(forge.set_mouse_aim_mode(
                forge.mouse_aim_mode == "pointer" and "crosshair" or "pointer"))
        end)
    aimMode.mine = true
    table.insert(rows, panel.with_help(panel.with_right(aimMode,
        OF.lang.t(forge.MOUSE_AIM_NAMES[forge.mouse_aim_mode] or "")),
        OF.lang.t("the view holds while you point, and a middle drag turns it - or the mouse turns the view")))

    if not OF.util.asks(OF.input, "step_forge_scale") then return end
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

function forge.next_block_rows(panel, rows)
    if forge.build_count() == 0 then return end
    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("The next block")),
        "how the block B lays is turned, mirrored and painted"))
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object", OF.lang.t("Turn the next block"),
            255, 255, 255, function()
                OF.util.report(forge.build_turn_by(1))
            end),
        OF.lang.t(forge.build_turn_name())),
        OF.lang.t("a quarter turn a press; R+right stick turns it in game")))
    table.insert(rows, panel.with_help(
        panel.gated_row("spawn_object",
            panel.tick(forge.build_flip, OF.lang.t("Upside down")),
            255, 255, 255, function()
                OF.util.report(forge.build_flip_toggle())
            end),
        OF.lang.t("slopes, corners and slabs only, for overhangs and ceilings")))
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object", OF.lang.t("Symmetry"),
            255, 255, 255, function()
                OF.util.report(forge.sym_next())
            end),
        OF.lang.t(forge.sym_name())),
        OF.lang.t("mirror planes on the aimed cell; B and R+B mirrored")))
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object", OF.lang.t("Brush"),
            255, 255, 255, function()
                OF.util.report(forge.set_brush(forge.brush + 1))
            end),
        forge.brush_name()),
        OF.lang.t("cells B lays at once, on the face aimed at")))
    table.insert(rows, panel.with_help(panel.with_right(
        panel.gated_row("spawn_object", OF.lang.t("B does"),
            255, 255, 255, function()
                OF.util.report(forge.build_tool_next())
            end),
        OF.lang.t(forge.build_tool_name())),
        OF.lang.t("lay, or paint the texture onto blocks keeping their shape")))
end

forge.MORE_SHUT = { "The next block", "Moving platforms", "Tracks",
    "Inventories", "Your pad - yours only" }

function forge.more_page(panel)
    local rows = {}

    local reachRow = panel.gated_row("spawn_object",
        panel.tick(forge.guide_on(), OF.lang.t("Show the jump's reach")),
        255, 255, 255, function()
            OF.util.report(forge.set_guide(forge.guide_on() and 1 or 2))
        end)
    reachRow.mine = true
    table.insert(rows, panel.with_help(reachRow,
        OF.lang.t("five jumps drawn as they fly from where you stand")))

    forge.pipe_rows(panel, rows)

    forge.box_rows(panel, rows)
    forge.next_block_rows(panel, rows)

    forge.mover_rows(panel, rows)

    forge.track_rows(panel, rows)

    forge.inventory_rows(panel, rows)
    forge.pad_rows(panel, rows)

    for _, r in ipairs(rows) do
        if r.heading and r.help == nil then
            local said = forge.MORE_HEADING_HELP[OF.util.plain(tostring(r.text))]
            if said ~= nil then r.help = OF.lang.t(said) end
        end
    end
    table.insert(rows, panel.back_row())
    return rows
end

forge.MORE_HEADING_HELP = {
    ["Moving platforms"] = "blocks and logs on paths; the Move & paths tool in game",
    ["Tracks"] = "speedrun tracks and Shell Racer tracks, laid ring by ring",
    ["Inventories"] = "three bars of six slots; the Things tool steps them",
    ["Your pad - yours only"] = "how your mouse aims and your stick turns, on this machine",
}

function forge.menu_rows(panel)
    local out = {}
    for _, build in ipairs({ forge.build_page, forge.level_page, forge.rules_page,
            forge.more_page, forge.clear_page, forge.kept_page }) do
        for _, row in ipairs(build(panel)) do out[#out + 1] = row end
    end
    return out
end

local barLoaded = false
hook_event(HOOK_ON_LEVEL_INIT, function()
    if barLoaded then return end
    barLoaded = true
    forge.load_bar()
end)
