OF = OF or {}
OF.smashitems = OF.smashitems or {}
local items = OF.smashitems

OF.SLOT_NEEDS = OF.SLOT_NEEDS or {}
table.insert(OF.SLOT_NEEDS, function()
    return { E_MODEL_HEART, E_MODEL_RED_COIN, E_MODEL_EXCLAMATION_BOX,
             E_MODEL_MARIOS_METAL_CAP, E_MODEL_MARIOS_WING_CAP, E_MODEL_AMP,
             E_MODEL_BLACK_BOBOMB, E_MODEL_BLUE_COIN, E_MODEL_BREAKABLE_BOX_SMALL,
             E_MODEL_STAR, E_MODEL_METALLIC_BALL }
end)

items.LIST_KEY = "ofSmashItems"
items.GRAB_KEY = "ofSmashGrab"
items.USE_KEY = "ofSmashUse"
items.RATE = {
    l = { lo = 600, hi = 900 },
    m = { lo = 300, hi = 600 },
    h = { lo = 150, hi = 300 },
}

local spriteIds = {}
function items.sprite_model(geo)
    if geo == nil then return nil end
    local id = spriteIds[geo]
    if id == nil then
        id = false
        if OF.util.optional("mod_file_exists", false, "actors/" .. geo .. ".bin") then
            local got = OF.util.optional("smlua_model_util_get_id", nil, geo)
            if type(got) == "number" and got ~= E_MODEL_ERROR_MODEL then id = got end
        end
        spriteIds[geo] = id
    end
    return id or nil
end

function items.forget_sprites()
    spriteIds = {}
end

items.HAMMER_GEO = "of_hammer_geo"
items.HAMMER_SCALE = 1.9
items.HAMMER_STAND_IN_SCALE = 0.6
function items.hammer_model()
    local id = items.sprite_model(items.HAMMER_GEO)
    if id ~= nil then return id, items.HAMMER_SCALE end
    return E_MODEL_METALLIC_BALL, items.HAMMER_STAND_IN_SCALE
end

items.KINDS = {
    { key = "b", name = "Bob-omb", weight = 4 },
    { key = "h", name = "Heart", weight = 1, flat = true,
      model = function() return E_MODEL_HEART end, scale = 1.0, heal = 100 },
    { key = "t", name = "Tomato", weight = 2, flat = true, coinFrames = true,
      sprite = "of_smash_tomato_geo", spriteScale = 0.9,
      model = function() return E_MODEL_RED_COIN end, scale = 1.2, heal = 50 },
    { key = "p", name = "Quake Block", weight = 2,
      sprite = "of_smash_quake_geo", spriteScale = 0.9,
      model = function() return E_MODEL_EXCLAMATION_BOX end, scale = 0.5, anim = 3 },

    { key = "m", name = "Metal Cap", weight = 2,
      model = function() return E_MODEL_MARIOS_METAL_CAP end, scale = 1.6, frames = 450 },
    { key = "w", name = "Wing Cap", weight = 2,
      model = function() return E_MODEL_MARIOS_WING_CAP end, scale = 1.6, frames = 270 },
    { key = "l", name = "Lightning", weight = 1, flat = true,
      sprite = "of_smash_bolt_geo", spriteScale = 0.9,
      model = function() return E_MODEL_AMP end, scale = 0.6, frames = 300 },
    { key = "s", name = "Star", weight = 1,
      model = function() return E_MODEL_STAR end, scale = 0.8, frames = 240 },
    { key = "r", name = "Hammer", weight = 1,
      model = function() return (items.hammer_model()) end,
      scaleOf = function() return select(2, items.hammer_model()) end, frames = 240 },

    { key = "o", name = "Blue Coin", weight = 3, flat = true, coinFrames = true,
      model = function() return E_MODEL_BLUE_COIN end, scale = 1.2, heal = 15 },
    { key = "c", name = "Crate", weight = 2,
      model = function() return E_MODEL_BREAKABLE_BOX_SMALL end, scale = 1.0, crate = 2 },
}
items.BY_KEY = {}
for _, kind in ipairs(items.KINDS) do items.BY_KEY[kind.key] = kind end

items.LIFE = 900

items.BOMB_ON_LIST = 30

items.BOMB_MARK = 0x4F470100

items.REACH = 140
items.REACH_UP = 180

items.PICK_BUTTON = A_BUTTON or 0x8000

items.GRAB_SAMPLE = "sound/of_smash_grab.aiff"
items.GRAB_VOLUME = 1.0
local grabSample = nil

function items.grab_sound(m)
    if m == nil or m.pos == nil then return false end
    if grabSample == nil and type(audio_sample_load) == "function" then
        grabSample = audio_sample_load(items.GRAB_SAMPLE)
    end
    if grabSample == nil or type(audio_sample_play) ~= "function" then
        OF.util.optional("play_character_sound", nil, m, CHAR_SOUND_HRMM)
        return false
    end
    audio_sample_play(grabSample, { x = m.pos.x, y = m.pos.y, z = m.pos.z },
        items.GRAB_VOLUME)
    return true
end

items.BOMB_TOUCH = 110
items.BOMB_SAFE = 20

items.LIFT = 50
items.BOB = 12
items.SPIN = 0x300

items.SPREAD = 0.75

items.FLOOR_BELOW = 800
items.FLOOR_ABOVE = 1400

items.POW_REACH = 2500

items.HOVER_FALL = 12
items.HOVER_BOOST = 30
items.HOVER_BOOSTS = 3

items.LIGHTNING_DAMAGE = 1.5

items.HAMMER_BALL = 6

function items.crowd(n)
    n = math.max(1, tonumber(n) or 1)
    return math.sqrt(n / 4)
end

function items.cap(n)
    n = math.max(1, tonumber(n) or 1)
    return 2 + math.ceil(n / 3)
end

function items.wait_for(stop, n, roll)
    local rate = items.RATE[stop]
    if rate == nil then return nil end
    roll = tonumber(roll)
    if roll == nil then roll = OF.util.random_int(rate.lo, rate.hi) end
    return math.max(1, math.floor(roll / items.crowd(n)))
end

function items.pick(roll, noCrate)
    local total = 0
    for _, kind in ipairs(items.KINDS) do
        if not (noCrate and kind.crate) then total = total + kind.weight end
    end
    roll = tonumber(roll) or OF.util.random_int(1, total)
    for _, kind in ipairs(items.KINDS) do
        if not (noCrate and kind.crate) then
            if roll <= kind.weight then return kind.key end
            roll = roll - kind.weight
        end
    end
    return items.KINDS[1].key
end

function items.pack(list)
    local pieces = {}
    for _, it in ipairs(list or {}) do
        table.insert(pieces, string.format("%.0f,%s,%.0f,%.0f", it.serial, it.kind,
            math.floor(it.x), math.floor(it.z)))
    end
    return table.concat(pieces, ";")
end

function items.unpack(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for serial, kind, x, z in string.gmatch(text, "(%d+),(%a),(-?%d+),(-?%d+)") do
        if items.BY_KEY[kind] ~= nil then
            table.insert(out, { serial = tonumber(serial), kind = kind,
                                x = tonumber(x), z = tonumber(z) })
        end
    end
    return out
end

function items.standing()
    return items.unpack(gGlobalSyncTable[items.LIST_KEY])
end

local function api()
    return OF.gm_smash_api
end

local function option(key)
    return OF.gamemodes.option_now(key)
end

function items.floor_at(x, z, box)
    if box == nil then return nil end
    local y = OF.util.optional("find_floor_height", nil, x, box.y + items.FLOOR_ABOVE, z)
    if type(y) ~= "number" then return nil end
    if y < box.y - items.FLOOR_BELOW or y > box.y + items.FLOOR_ABOVE then return nil end
    return y
end

function items.spot(box, tries)
    local a = api()
    if box == nil or a == nil then return nil end

    if box.items ~= nil and #box.items > 0 then
        local at = box.items[OF.util.random_int(1, #box.items)]
        return at.x, box.z
    end
    local half = math.floor(a.RIM * items.SPREAD)

    local here = a.box() ~= nil
    for _ = 1, (tries or 8) do
        local x = box.x + OF.util.random_int(-half, half)
        local z = box.z or a.LINE_Z
        if not here or items.floor_at(x, z, box) ~= nil then return x, z end
    end
    return nil
end

local host = { list = {}, serial = 0, wait = nil, age = {}, seenGrab = {} }

local function fighters()
    local a = api()
    if a == nil then return {} end
    return OF.gamemodes.with_role(a.ROLE_FIGHT)
end

function items.bombs()
    local found = {}
    if id_bhvBobomb == nil then return found end
    local o = OF.util.optional("obj_get_first_with_behavior_id", nil, id_bhvBobomb)
    local guard = 0
    while o ~= nil and guard < 512 do
        guard = guard + 1
        local ok, params = pcall(function() return o.oBehParams end)
        if ok and type(params) == "number"
            and math.floor(params / 256) == math.floor(items.BOMB_MARK / 256) then
            table.insert(found, o)
        end
        o = OF.util.optional("obj_get_next_with_same_behavior_id", nil, o)
    end
    return found
end

items.toldBombs = 0
function items.room_bombs()
    if OF.util.asks(OF.gamemodes, "room_by_lead") and OF.gamemodes.room_by_lead() then
        return items.toldBombs
    end
    return #items.bombs()
end

local function publish_list()
    OF.util.publish(items.LIST_KEY, items.pack(host.list))
end

function items.host_step()
    local a = api()
    if a == nil then return false end
    local stop = option("i")
    if items.RATE[stop] == nil then
        if #host.list > 0 then
            host.list = {}
            publish_list()
        end
        return false
    end
    local changed = false

    local wire = gGlobalSyncTable[items.LIST_KEY]
    if type(wire) ~= "string" then wire = "" end
    if wire ~= items.pack(host.list) then host.list = items.unpack(wire) end

    for _, entry in ipairs(OF.util.connected_players()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local said = row ~= nil and row[items.GRAB_KEY] or 0
        if type(said) == "number" and said ~= (host.seenGrab[entry.localIndex] or 0) then
            host.seenGrab[entry.localIndex] = said
            for i = #host.list, 1, -1 do
                if host.list[i].serial == said then
                    local was = table.remove(host.list, i)
                    changed = true

                    local kind = items.BY_KEY[was.kind]
                    for k = 1, (kind ~= nil and kind.crate or 0) do
                        host.serial = host.serial % 255 + 1
                        table.insert(host.list, { serial = host.serial,
                            kind = items.pick(nil, true),
                            x = was.x + (k - 1.5) * 2 * items.REACH, z = was.z })
                        host.age[host.serial] = 0
                    end
                end
            end
        end
    end

    for i = #host.list, 1, -1 do
        local it = host.list[i]
        host.age[it.serial] = (host.age[it.serial] or 0) + 1
        local life = it.kind == "b" and items.BOMB_ON_LIST or items.LIFE
        if host.age[it.serial] > life then
            table.remove(host.list, i)
            host.age[it.serial] = nil
            changed = true
        end
    end

    local n = #fighters()
    if host.wait == nil then host.wait = items.wait_for(stop, n) end
    host.wait = host.wait - 1
    if host.wait <= 0 then
        host.wait = items.wait_for(stop, n)
        local live = 0
        for _, it in ipairs(host.list) do
            if it.kind ~= "b" then live = live + 1 end
        end
        live = live + items.room_bombs()
        local box = items.round_box()
        if live < items.cap(n) and box ~= nil then
            local x, z = items.spot(box)
            if x ~= nil then
                host.serial = host.serial % 255 + 1
                table.insert(host.list, { serial = host.serial, kind = items.pick(),
                                          x = x, z = z })
                host.age[host.serial] = 0
                changed = true
            end
        end
    end
    if changed then publish_list() end
    return changed
end

function items.round_box()
    local a = api()
    if a == nil then return nil end
    local mine = a.box()
    if mine ~= nil then return mine end
    for _, entry in ipairs(fighters()) do
        local box = entry.np ~= nil
            and items.box_of(entry.np.currLevelNum, entry.np.currAreaIndex) or nil
        if box ~= nil then return box end
    end
    return nil
end

function items.box_of(level, area)
    local a = api()
    if a == nil or not OF.util.asks(a, "stage_of") then return nil end
    return a.stage_of(level, area)
end

local pictures = {}
local taken = {}
local dropped = {}
local lastHolder = {}
local wasHeld = {}
local held = { kind = nil, left = 0 }
local useSeq = 0
local seenUse = {}
local clock = 0

local function drop_picture(serial)
    local p = pictures[serial]
    pictures[serial] = nil
    if p == nil then return end
    if OF.util.asks(OF.shooter, "still_ours")
        and OF.shooter.still_ours(p.obj, id_bhvStaticObject, p.model) then
        OF.util.optional("obj_mark_for_deletion", nil, p.obj)
    end
end

local function picture_alive(p)
    if p == nil then return false end
    if not OF.util.asks(OF.shooter, "still_ours") then
        return OF.util.alive(p.obj) and p.obj.activeFlags ~= 0
    end
    return OF.shooter.still_ours(p.obj, id_bhvStaticObject, p.model)
end

function items.draw()
    local a = api()
    local box = a ~= nil and a.box() or nil
    local wanted = {}
    if box ~= nil and option("i") ~= "n" then
        for _, it in ipairs(items.standing()) do
            local kind = items.BY_KEY[it.kind]
            if it.kind == "b" then
                if not dropped[it.serial] and OF.util.asks(OF.modifiers, "bomb_mine_to_drop")
                    and OF.modifiers.bomb_mine_to_drop() then
                    dropped[it.serial] = true
                    items.drop_bomb(it, box)
                end
            elseif not taken[it.serial] and kind ~= nil and kind.model ~= nil then
                local y = items.floor_at(it.x, it.z, box)
                if y ~= nil then
                    wanted[it.serial] = true
                    local p = pictures[it.serial]
                    local look = items.look_of(kind)
                    local model = look.model
                    if not picture_alive(p) and model ~= nil then
                        local obj = OF.slots.spawn_non_sync(id_bhvStaticObject, model,
                            it.x, y + items.LIFT, it.z, function(o)
                                if look.anim ~= nil then o.oAnimState = look.anim end
                                OF.util.optional("obj_scale", nil, o, look.scale)
                                if look.flat then OF.util.optional("obj_set_billboard", nil, o) end
                            end, true)
                        p = { obj = obj, model = model, kind = it.kind,
                              x = it.x, y = y, z = it.z }
                        pictures[it.serial] = p
                    end
                    if p ~= nil and p.obj ~= nil and OF.util.alive(p.obj) then
                        if look.flat then

                            OF.util.optional("obj_set_billboard", nil, p.obj)
                            if look.coinFrames then p.obj.oAnimState = clock % 8 end
                        else
                            p.obj.oFaceAngleYaw = (clock * items.SPIN) % 0x10000
                        end
                        p.obj.oPosY = y + items.LIFT + items.BOB * math.sin(clock / 10)
                    end
                end
            end
        end
    end
    for serial in pairs(pictures) do
        if not wanted[serial] then drop_picture(serial) end
    end
    return wanted
end

function items.look_of(kind)
    local sprite = items.sprite_model(kind.sprite)
    if sprite ~= nil then
        return { model = sprite, scale = kind.spriteScale or 1, flat = true }
    end
    local scale = kind.scale or 1
    if kind.scaleOf ~= nil then scale = kind.scaleOf() end
    return { model = kind.model ~= nil and kind.model() or nil, scale = scale,
             flat = kind.flat, coinFrames = kind.coinFrames, anim = kind.anim }
end

function items.drop_bomb(it, box)
    local y = items.floor_at(it.x, it.z, box)
    if y == nil then return nil end
    return OF.slots.spawn_sync(id_bhvBobomb, E_MODEL_BLACK_BOBOMB, it.x, y + 20, it.z,
        function(o)
            o.oBehParams = items.BOMB_MARK + (it.serial % 256)
        end)
end

function items.watch_bombs()
    for _, o in ipairs(items.bombs()) do
        local serial = (o.oBehParams or 0) % 256
        local isHeld = o.oHeldState == (HELD_HELD or 1)
        if isHeld then
            local np = gNetworkPlayers[o.heldByPlayerIndex or 0]
            if np ~= nil and type(np.globalIndex) == "number" then
                lastHolder[serial] = np.globalIndex
            end
        elseif not wasHeld[serial] and o.oAction == (BOBOMB_ACT_LAUNCHED or 1)
            and lastHolder[serial] == nil then
            local best, bestD = nil, 300 * 300
            for _, entry in ipairs(OF.util.connected_players()) do
                local m = gMarioStates[entry.localIndex]
                if m ~= nil and m.pos ~= nil then
                    local dx, dy, dz = m.pos.x - o.oPosX, m.pos.y - o.oPosY, m.pos.z - o.oPosZ
                    local d = dx * dx + dy * dy + dz * dz
                    if d < bestD and entry.np ~= nil then best, bestD = entry.np.globalIndex, d end
                end
            end
            lastHolder[serial] = best
        end
        wasHeld[serial] = isHeld
        if not isHeld and (o.oTimer or 0) > items.LIFE and o.oAction ~= (BOBOMB_ACT_LAUNCHED or 1) then
            OF.util.optional("obj_mark_for_deletion", nil, o)
        end
    end
end

function items.blame_of(explosion)
    if explosion == nil then return nil end
    local ok, parent = pcall(function() return explosion.parentObj end)
    if not ok or parent == nil then return nil end
    local ok2, params = pcall(function() return parent.oBehParams end)
    if not ok2 or type(params) ~= "number" then return nil end
    if math.floor(params / 256) ~= math.floor(items.BOMB_MARK / 256) then return nil end
    return lastHolder[params % 256]
end

local function my_global()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex or nil
end

local function announce(kind)
    OF.notify.show("@ picked up", "good", 3, kind.name)
    OF.gamemodes.cue("good", nil, "smashitem")
end

function items.apply(key)
    local a = api()
    local kind = items.BY_KEY[key]
    local m = gMarioStates[0]
    if a == nil or kind == nil or m == nil then return false end
    if kind.heal ~= nil then

        local off = kind.heal
        if a.on_hp() then off = kind.heal / 2.5 end
        a.set_percent(a.percent() - off)
    elseif key == "p" or key == "l" then
        useSeq = useSeq + 1
        OF.util.publish_row(0, items.USE_KEY, key .. ":" .. tostring(useSeq))
    elseif kind.crate ~= nil then
        OF.gamemodes.round_sound(SOUND_GENERAL_BREAK_BOX)
    elseif key == "m" or key == "w" or key == "s" or key == "r" then

        if held.kind ~= nil and items.end_held ~= nil then items.end_held(m) end
        held.kind, held.left = key, kind.frames
        if (key == "m" or key == "w") and OF.util.asks(OF.smashrules, "wear") then
            OF.smashrules.wear(m, key == "m" and MARIO_METAL_CAP or MARIO_WING_CAP)
        end
        if key == "w" then items.boostsLeft = items.HOVER_BOOSTS end
        if key == "s" then

            useSeq = useSeq + 1
            OF.util.publish_row(0, items.USE_KEY, key .. ":" .. tostring(useSeq))
        end
    end
    announce(kind)
    return true
end

function items.grab_with_a(m)
    if m == nil or m.controller == nil or m.pos == nil then return nil end
    if not OF.util.has_flag(m.controller.buttonPressed or 0, items.PICK_BUTTON) then return nil end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x800) or m.heldObj ~= nil then return nil end
    local what = nil
    if items.touch(m) ~= nil then
        what = "item"
        items.grab_sound(m)
    else
        for _, o in ipairs(items.bombs()) do
            if o.oHeldState == (HELD_FREE or 0) then
                local dx, dz = m.pos.x - o.oPosX, m.pos.z - o.oPosZ
                if dx * dx + dz * dz <= items.REACH * items.REACH
                    and math.abs(m.pos.y - o.oPosY) <= items.REACH_UP then
                    m.interactObj, m.usedObj = o, o
                    set_mario_action(m, ACT_PICKING_UP, 0)
                    if items.grab_sound(m) and MARIO_MARIO_SOUND_PLAYED ~= nil then
                        m.flags = (m.flags or 0) | MARIO_MARIO_SOUND_PLAYED
                    end
                    what = "bomb"
                    break
                end
            end
        end
    end
    if what ~= nil then
        m.controller.buttonPressed = m.controller.buttonPressed - items.PICK_BUTTON
    end
    return what
end

function items.touch(m)
    local a = api()
    if a == nil or m == nil or m.pos == nil then return nil end
    for serial, p in pairs(pictures) do
        if not taken[serial] then
            local dx, dz = m.pos.x - p.x, m.pos.z - p.z
            local dy = m.pos.y - (p.y + items.LIFT)
            if dx * dx + dz * dz <= items.REACH * items.REACH
                and math.abs(dy) <= items.REACH_UP then
                taken[serial] = true
                drop_picture(serial)
                OF.util.publish_row(0, items.GRAB_KEY, serial)
                items.apply(p.kind)
                return serial
            end
        end
    end
    return nil
end

local function end_held(m)
    local was = held.kind
    held.kind, held.left = nil, 0
    if was == nil or not OF.util.asks(OF.smashrules, "unwear") then return end
    if was == "m" and not OF.smashrules.metal_row() then
        OF.smashrules.unwear(m, MARIO_METAL_CAP)
    elseif was == "w" and not OF.smashrules.wing_row() then
        OF.smashrules.unwear(m, MARIO_WING_CAP)
    end
end

items.end_held = end_held

local powered = {}

function items.power_of(i)
    if i == 0 then
        if (held.kind == "s" or held.kind == "r") and held.left > 0 then return held.kind end
        return nil
    end
    local p = powered[i]
    if p ~= nil and p.left > 0 then return p.kind end
    return nil
end

local shrunk = 0

local function end_shrink()
    if shrunk <= 0 then return end
    shrunk = 0
    if OF.util.asks(OF.cheats, "end_timed_size") then OF.cheats.end_timed_size() end
end

function items.read_uses(m)
    local a = api()
    local me = my_global()
    for _, entry in ipairs(OF.util.connected_players()) do
        local who = entry.localIndex
        if who ~= 0 then
            local row = gPlayerSyncTable[who]

            local said = row ~= nil and row[items.USE_KEY] or ""
            if said == nil then said = "" end
            if type(said) == "string" then
                local first = seenUse[who] == nil
                if said ~= seenUse[who] then
                    seenUse[who] = said
                    local key = string.match(said, "^(%a):%d+$")
                    if not first and key == "s" then
                        powered[who] = { kind = key, left = items.BY_KEY[key].frames }
                    end
                    if not first and key ~= nil and a ~= nil and a.fighting() then
                        local user = gMarioStates[who]
                        local by = entry.np ~= nil and entry.np.globalIndex or nil
                        if key == "p" then items.pow_on_me(m, user, by)
                        elseif key == "l" then items.bolt_on_me(m) end
                    end
                end
            end
        end
    end
    return me
end

function items.pow_on_me(m, user, by)
    local a = api()
    if a == nil or m == nil or user == nil or user.pos == nil or m.pos == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_AIR or 0x00000800) then return false end
    local dx, dz = m.pos.x - user.pos.x, m.pos.z - user.pos.z
    if dx * dx + dz * dz > items.POW_REACH * items.POW_REACH then return false end
    OF.gamemodes.cue("hazard", nil, "smashpow")
    return a.take_hit({ pos = user.pos, faceAngle = { y = 0 }, flags = 0 }, "pow", nil, by) ~= nil
end

function items.hovering()
    if held.kind == "w" and held.left > 0 then return true end
    return OF.util.asks(OF.smashrules, "wing_row") and OF.smashrules.wing_row()
end

function items.hover_boost(m)
    if m == nil or m.controller == nil or m.vel == nil or not items.hovering() then return false end
    local act = m.action or 0
    if not OF.util.has_flag(act, ACT_FLAG_AIR or 0x800) then
        items.boostsLeft = items.HOVER_BOOSTS
        return false
    end
    if not OF.util.has_flag(m.controller.buttonPressed or 0, A_BUTTON) then return false end
    local moves = OF.util.asks(OF, "gm_smash_moveset") and OF.gm_smash_moveset() or nil
    if moves == nil or not moves.airJumpUsed or moves.helpless then return false end
    local a = api()
    if a ~= nil and a.hitstun() > 0 then return false end
    if (items.boostsLeft or 0) <= 0 then return false end
    items.boostsLeft = items.boostsLeft - 1
    m.vel.y = math.max(m.vel.y, items.HOVER_BOOST)
    m.controller.buttonPressed = m.controller.buttonPressed - A_BUTTON
    return true
end

function items.hover_fall(m)
    if m == nil or m.vel == nil or m.controller == nil or not items.hovering() then return false end
    local act = m.action or 0
    if not OF.util.has_flag(act, ACT_FLAG_AIR or 0x800) then return false end
    if (m.knockbackTimer or 0) ~= 0 or act == ACT_GROUND_POUND then return false end
    if OF.util.has_flag(act, ACT_FLAG_INTANGIBLE or 0x1000) then return false end
    local a = api()
    if a ~= nil and a.hitstun() > 0 then return false end
    if not OF.util.has_flag(m.controller.buttonDown or 0, A_BUTTON) then return false end
    if m.vel.y >= -items.HOVER_FALL then return false end
    m.vel.y = -items.HOVER_FALL
    return true
end

function items.bolt_on_me(m)
    if not OF.util.asks(OF.cheats, "timed_size") then return false end
    shrunk = items.BY_KEY.l.frames
    OF.cheats.timed_size(0.45, shrunk, "mode")
    OF.gamemodes.cue("hazard", nil, "smashbolt")
    return true
end

local function here(i)
    if i == 0 then return true end
    local np, me = gNetworkPlayers[i], gNetworkPlayers[0]
    if np == nil or me == nil or not np.connected then return false end

    return OF.util.same_world(i)
end

function items.draw_powers()
    for i = 0, (MAX_PLAYERS or 16) - 1 do
        local m = gMarioStates[i]
        if items.power_of(i) == "s" and m ~= nil and here(i) then
            m.particleFlags = OF.util.add_flag(m.particleFlags or 0,
                PARTICLE_SPARKLES or (1 << 3))
        end
    end
end

function items.hammer_swing(m)
    if held.kind ~= "r" or held.left <= 0 or m == nil then return false end
    local P = OF.powerups
    if not OF.util.asks(P, "fists_press") or not OF.util.asks(P, "throw_ball") then
        return false
    end
    if not P.fists_press(m) then return false end

    local a = api()
    if a ~= nil and OF.util.asks(a, "plain_b") and not a.plain_b(m) then
        return false
    end
    return P.throw_ball(m, items.HAMMER_BALL) == true
end

function items.hammer_on_me(m, ball, kind, thrower)
    local a = api()
    if a == nil or kind == nil or not kind.arc or ball == nil then return nil end
    if OF.gamemodes.current() ~= a.mode or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        return nil
    end
    local from = OF.util.optional("network_local_index_from_global", nil, thrower)
    if type(from) ~= "number" or OF.gamemodes.role(from) ~= a.ROLE_FIGHT then return nil end
    if not a.fighting() then return false end
    local yaw = tonumber(ball.oMoveAngleYaw) or 0
    return a.take_hit({ pos = { x = ball.oPosX or 0, y = ball.oPosY or 0, z = ball.oPosZ or 0 },
                        faceAngle = { y = yaw }, flags = 0 }, "hammer", nil, thrower) ~= nil
end

OF.powerups = OF.powerups or {}
OF.powerups.BALL_DOORS = OF.powerups.BALL_DOORS or {}
table.insert(OF.powerups.BALL_DOORS, items.hammer_on_me)

local part = {}
OF.gm_smash_parts = OF.gm_smash_parts or {}
table.insert(OF.gm_smash_parts, part)

local function add_moves()
    local a = api()
    if a == nil or a.MOVES == nil then return end
    a.MOVES.pow = a.MOVES.pow or { d = 8, bkb = 50, kbg = 40, angle = 80, away = true }
end

function part.host_update()
    add_moves()
    items.host_step()
    return nil
end

function part.scenery()
    add_moves()
    clock = clock + 1
    for i, p in pairs(powered) do
        p.left = p.left - 1
        if p.left <= 0 then powered[i] = nil end
    end
    items.draw_powers()
    items.draw()
    items.watch_bombs()
    local m = gMarioStates[0]
    items.read_uses(m)
    if shrunk > 0 then
        shrunk = shrunk - 1
        if shrunk <= 0 then end_shrink() end
    end
    return nil
end

function part.before_moveset(m)
    local a = api()
    if a == nil or not a.fighting() then return nil end
    items.hover_boost(m)
    if option("i") == "n" then return nil end
    items.grab_with_a(m)
    return nil
end

function part.update(m)
    local a = api()
    if a == nil or not a.fighting() then return nil end
    if held.kind ~= nil then
        held.left = held.left - 1
        if held.left <= 0 then end_held(m) end
    end
    items.hover_fall(m)
    items.hammer_swing(m)
    return nil
end

function part.taken_scale()
    if shrunk > 0 then return items.LIGHTNING_DAMAGE end
    return nil
end

function part.may_attack(attacker, victim)
    if victim ~= nil and items.power_of(victim.playerIndex) == "s" then return false end
    return nil
end

function part.blocks(kind)
    if items.power_of(0) ~= "s" then return nil end
    if type(kind) == "string" and string.match(kind, "throw$") then return nil end
    return true
end

function part.weight_scale()
    if shrunk > 0 then return 1.5 end
    return nil
end

function part.blame(explosion)
    return items.blame_of(explosion)
end

function part.under_line()
    if held.kind ~= nil and held.left > 0 then
        if held.kind == "w" then
            return OF.lang.fill("Wing Cap: hold A to float, @ lift(s) - @ s",
                tostring(items.boostsLeft or 0), tostring(math.ceil(held.left / 30)))
        end
        return OF.lang.fill("@ - @ s", OF.lang.t(items.BY_KEY[held.kind].name),
            tostring(math.ceil(held.left / 30)))
    end
    if shrunk > 0 then
        return OF.lang.fill("Struck by lightning - @ s", tostring(math.ceil(shrunk / 30)))
    end
    return nil
end

function part.stock_lost()
    local m = gMarioStates[0]
    end_held(m)
    end_shrink()
    return nil
end

local function forget()
    powered = {}
    items.boostsLeft = items.HOVER_BOOSTS
    for serial in pairs(pictures) do drop_picture(serial) end
    pictures, taken, dropped, lastHolder, wasHeld, seenUse = {}, {}, {}, {}, {}, {}
    host.list, host.serial, host.wait, host.age, host.seenGrab = {}, 0, nil, {}, {}
    clock = 0
end

function part.on_start()
    forget()
    held.kind, held.left = nil, 0
    shrunk = 0
    return nil
end

function part.cleanup()
    local m = gMarioStates[0]
    end_held(m)
    end_shrink()
    for _, o in ipairs(items.bombs()) do
        OF.util.optional("obj_mark_for_deletion", nil, o)
    end
    forget()
    if OF.util.is_host() and gGlobalSyncTable[items.LIST_KEY] ~= nil
        and gGlobalSyncTable[items.LIST_KEY] ~= "" then
        OF.util.publish(items.LIST_KEY, "")
    end
    return nil
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    pictures = {}
end)

function items.state()
    local n = 0
    for _ in pairs(pictures) do n = n + 1 end
    return { pictures = n, held = held.kind, left = held.left, shrunk = shrunk,
             hostList = host.list, hostWait = host.wait, taken = taken,
             lastHolder = lastHolder }
end

function items.ready()
    return items.host_step ~= nil and items.draw ~= nil and items.apply ~= nil
end
