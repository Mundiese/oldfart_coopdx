OF = OF or {}
OF.rando = OF.rando or {}
local rando = OF.rando

local STORE = "ofRando"
local held = nil

local drawSeed = nil

local function step_of(state)
    return (1103515245 * state + 12345) % 2147483648
end

local function stream_for(key)
    local mixed = 0
    for index = 1, #key do
        mixed = (mixed * 131 + string.byte(key, index)) % 2147483648
    end
    local state = (rando.draw_seed() * 1103515 + mixed) % 2147483648

    state = step_of(state)
    return function(bound)
        if bound == nil or bound < 1 then return 1 end
        state = step_of(state)
        return (state % bound) + 1
    end
end

local function deal_order(list, draw)
    for index = #list, 2, -1 do
        local pick = draw(index)
        list[index], list[pick] = list[pick], list[index]
    end
    return list
end

local function stream_over(seed, key)
    if type(seed) ~= "number" or seed <= 0 then return nil end

    local mixed = 0
    for index = 1, #key do
        mixed = (mixed * 131 + string.byte(key, index)) % 2147483648
    end

    local state = (seed * 1103515 + mixed) % 2147483648
    state = step_of(state)
    return function(bound)
        if bound == nil or bound < 1 then return 1 end
        state = step_of(state)
        return (state % bound) + 1
    end
end

local function room_stream_for(key)
    return stream_over(rando.room_seed(), key)
end

local function here()
    local np = gNetworkPlayers and gNetworkPlayers[0]
    if np == nil then return nil, nil end
    return np.currLevelNum, np.currAreaIndex
end

local function level_now()
    local current = rawget(_G, "gCurrLevelNum")
    if type(current) == "number" and current > 0 then return current end
    return (here())
end

function rando.THREE_STOPS(offName)
    return {
        { value = "keep",  name = offName },
        { value = "level", name = "Drawn for each level" },
        { value = "entry", name = "Drawn on every entry" },
    }
end

rando.OLD_STOPS = {
    sky = { drawn = "level" },
    hour = { drawn = "level" },
    texshuffle = { on = "level", off = "keep" },
    music = { courses = "level", any = "level" },
    instruments = { drawn = "level", off = "keep" },
}

rando.ENTRY_KEY = "ofRandoEntries"
local entries = {}
local layerCache = {}
local lastLevel = nil

function rando.shared_entries()
    local out = {}
    local text = gGlobalSyncTable ~= nil and gGlobalSyncTable[rando.ENTRY_KEY] or nil
    if type(text) ~= "string" then return out end
    for level, n in text:gmatch("(%-?%d+):(%d+)") do
        out[tonumber(level)] = tonumber(n)
    end
    return out
end

local function pack_entries(counts)
    local levels = {}
    for level in pairs(counts) do levels[#levels + 1] = level end
    table.sort(levels)
    local parts = {}
    for _, level in ipairs(levels) do
        parts[#parts + 1] = tostring(level) .. ":" .. tostring(counts[level])
    end
    return table.concat(parts, ",")
end
rando.pack_entries = pack_entries

function rando.others_in(level)
    if gNetworkPlayers == nil then return false end
    for index = 1, (MAX_PLAYERS or 16) - 1 do
        local np = gNetworkPlayers[index]
        if np ~= nil and np.connected and np.currLevelNum == level then
            return true
        end
    end
    return false
end

local arrivedAt, sharedAtArrival = -9999, nil
local function clock()
    return OF.util.optional("get_global_timer", 0) or 0
end

function rando.count_entry(level)
    if type(level) ~= "number" then return 0 end
    layerCache = {}
    if level == lastLevel and entries[level] ~= nil then return entries[level] end
    lastLevel = level
    local n = rando.shared_entries()[level] or 0
    sharedAtArrival = n
    arrivedAt = clock()
    if not rando.others_in(level) then n = n + 1 end
    entries[level] = n
    return n
end

rando.ENTRY_SETTLE = 30
function rando.entry_tick()
    if lastLevel == nil or sharedAtArrival == nil then return false end
    if clock() - arrivedAt > rando.ENTRY_SETTLE then
        sharedAtArrival = nil
        return false
    end
    local now = rando.shared_entries()[lastLevel] or 0
    if now == sharedAtArrival or now == entries[lastLevel] then return false end
    sharedAtArrival = now
    entries[lastLevel] = now
    rando.layer_changed()
    return true
end

local seatLevel = {}
local seatsKnown = false

function rando.forget_entries()
    entries = {}
    layerCache = {}
    lastLevel = nil
    sharedAtArrival = nil
    seatLevel = {}
    seatsKnown = false
    if type(OF.util) == "table" and type(OF.util.is_host) == "function"
        and OF.util.is_host() and gGlobalSyncTable ~= nil
        and gGlobalSyncTable[rando.ENTRY_KEY] ~= nil
        and gGlobalSyncTable[rando.ENTRY_KEY] ~= "" then
        OF.util.publish(rando.ENTRY_KEY, "")
    end
end

function rando.watch_entries()
    if not OF.util.is_host() then return false end
    if not rando.draws_every_entry() then
        seatLevel, seatsKnown = {}, false
        return false
    end
    local now = {}
    for index = 0, (MAX_PLAYERS or 16) - 1 do
        local np = gNetworkPlayers[index]
        if np ~= nil and np.connected and type(np.currLevelNum) == "number"
            and np.currLevelNum > 0 then
            now[index] = np.currLevelNum
        end
    end
    if not seatsKnown then
        seatLevel, seatsKnown = now, true
        return false
    end
    local stayed = {}
    for index, level in pairs(now) do
        if seatLevel[index] == level then stayed[level] = true end
    end
    local counts, bumped = nil, {}
    for index, level in pairs(now) do
        if seatLevel[index] ~= level and not stayed[level] and not bumped[level] then
            counts = counts or rando.shared_entries()
            counts[level] = (counts[level] or 0) + 1
            bumped[level] = true
        end
    end
    seatLevel = now
    if counts == nil then return false end
    OF.util.publish(rando.ENTRY_KEY, pack_entries(counts))
    return true
end

local function high_draw(seed, key, bound)
    local mixed = 0
    for index = 1, #key do
        mixed = (mixed * 131 + string.byte(key, index)) % 2147483648
    end
    local state = step_of((seed * 1103515 + mixed) % 2147483648)
    state = step_of(state)
    return (state // 32768) % bound + 1
end

function rando.here_draw(key, bound)
    if type(bound) ~= "number" or bound < 1 then return nil end
    if rando.stands_down() then return nil end
    local level = level_now()
    if level == nil then return nil end
    local n = entries[level]
    if n == nil then

        n = rando.shared_entries()[level] or 0
        entries[level] = n
    end
    local memo = key .. ":" .. tostring(level) .. ":" .. n .. ":" .. bound
    local known = layerCache[memo]
    if known ~= nil then return known or nil end

    local answer = false
    if rando.view_on() then
        local choice = rando.view_choice_row(key)
        local seed = rando.room_seed()
        if choice ~= nil and seed ~= nil and choice.value ~= "keep" then
            local streamKey = key .. ":" .. tostring(level)
            if choice.value == "entry" then streamKey = streamKey .. ":" .. n end
            answer = high_draw(seed, streamKey, bound)
        end
    end
    layerCache[memo] = answer
    return answer or nil
end

rando.LAYER_OF = { night = "sky", sun = "hour", bank = "instruments" }

function rando.layer_level(modKey)
    local knobKey = rando.LAYER_OF[modKey]
    if knobKey == nil then return nil end
    if not OF.util.asks(OF.modifiers, "step_count") then return nil end
    local entry = OF.modifiers.BY_KEY ~= nil and OF.modifiers.BY_KEY[modKey] or nil
    if entry == nil then return nil end
    local steps = OF.modifiers.step_count(entry)
    local level = rando.here_draw(knobKey, steps)
    if level == nil or not rando.may_deal_mod(modKey, level) then return nil end
    return level
end

function rando.layer_seed()
    return rando.here_draw("texshuffle", 2147483000)
end

function rando.layer_track(base)
    local list = OF.music ~= nil and OF.music.SHUFFLED or nil
    if type(list) ~= "table" or #list == 0 then return nil end
    local known = false
    for _, seq in ipairs(list) do
        if seq == base then known = true end
    end
    if not known then return nil end
    local pick = rando.here_draw("music", #list)
    if pick == nil then return nil end
    return list[pick]
end

function rando.layer_changed()
    layerCache = {}
    if OF.util.asks(OF.modifiers, "sync_world") then OF.modifiers.sync_world() end
    if OF.util.asks(OF.music, "replay_level") then OF.music.replay_level() end
end

local POOL_BEHAVIOURS = {
    "id_bhvRedCoin", "id_bhvYellowCoin", "id_bhvOneCoin",
    "id_bhvHiddenBlueCoin", "id_bhv1Up",
}

local PROBE_UP = 300

local MAX_DROP = 1200

local STAR_LIFT = 60

local SCATTER_REACH = 350
rando.SCATTER_REACH = SCATTER_REACH

local SCATTER_TRIES = 4

local function gather_pool()
    local pool = {}
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return pool end
    if OF.util.binding("obj_get_next_with_same_behavior_id") == nil then return pool end

    for _, name in ipairs(POOL_BEHAVIOURS) do

        local id = _G[name]
        if type(id) == "number" then
            local object = obj_get_first_with_behavior_id(id)
            local seen = 0

            while object ~= nil and seen < 10000 do
                seen = seen + 1
                local x, y, z = object.oPosX, object.oPosY, object.oPosZ
                if type(x) == "number" and type(y) == "number"
                    and type(z) == "number" then
                    pool[#pool + 1] = { x = x, y = y, z = z }
                end
                object = obj_get_next_with_same_behavior_id(object)
            end
        end
    end
    return pool
end

local function standable(point)
    local floor = OF.util.optional("find_floor_height", nil,
        point.x, point.y + PROBE_UP, point.z)
    if type(floor) ~= "number" then return nil end

    if point.y - floor > MAX_DROP then return nil end
    if floor > point.y + PROBE_UP then return nil end
    return floor
end

local function vetted_pool()
    local out = {}
    for _, point in ipairs(gather_pool()) do
        local floor = standable(point)
        if floor ~= nil then
            out[#out + 1] = { x = point.x, y = math.max(point.y, floor + STAR_LIFT),
                              z = point.z }
        end
    end
    return out
end

local function scatter_from(point, draw)
    local landed = nil
    for _ = 1, SCATTER_TRIES do
        local dx = draw(SCATTER_REACH * 2 + 1) - SCATTER_REACH - 1
        local dz = draw(SCATTER_REACH * 2 + 1) - SCATTER_REACH - 1

        if landed == nil then
            local try = { x = point.x + dx, y = point.y, z = point.z + dz }
            local floor = standable(try)
            if floor ~= nil then
                landed = { x = try.x, y = floor + STAR_LIFT, z = try.z }
            end
        end
    end
    return landed or point
end

local placedAt = nil

local movedHere = {}

function rando.note_moved(object)
    if object == nil then return end
    movedHere[#movedHere + 1] = { obj = object, kind = "place",
        x = object.oPosX, y = object.oPosY, z = object.oPosZ,
        hx = object.oHomeX, hy = object.oHomeY, hz = object.oHomeZ }
end

function rando.note_dealt(object)
    if object == nil then return end
    movedHere[#movedHere + 1] = { obj = object, kind = "warp",
        params = object.oBehParams, second = object.oBehParams2ndByte }
end

function rando.undo_here()
    local back = 0
    for index = #movedHere, 1, -1 do
        local one = movedHere[index]
        local o = one.obj
        if o ~= nil and OF.util.alive(o) and (o.activeFlags or 0) ~= 0 then
            if one.kind == "place" then
                o.oPosX, o.oPosY, o.oPosZ = one.x, one.y, one.z
                o.oHomeX, o.oHomeY, o.oHomeZ = one.hx, one.hy, one.hz
            else
                o.oBehParams = one.params
                o.oBehParams2ndByte = one.second
            end
            back = back + 1
        end
    end
    movedHere = {}
    return back
end

function rando.forget_here()
    movedHere = {}
end

function rando.place_here(wantStars, wantCoins)
    local level, area = here()
    if level == nil then return 0 end
    if not wantStars and not wantCoins then return 0 end

    local pool = vetted_pool()
    if #pool == 0 then return 0 end

    local moved = 0

    local tag = tostring(level) .. ":" .. tostring(area)

    if wantStars and type(id_bhvStar) == "number"
        and OF.util.binding("obj_get_first_with_behavior_id") ~= nil then
        local draw = room_stream_for("star:" .. tag)
        if draw ~= nil then
            local star = obj_get_first_with_behavior_id(id_bhvStar)
            local seen = 0
            while star ~= nil and seen < 10000 do
                seen = seen + 1
                local point = pool[draw(#pool)]
                rando.note_moved(star)
                star.oPosX, star.oPosY, star.oPosZ = point.x, point.y, point.z

                star.oHomeX, star.oHomeY, star.oHomeZ = point.x, point.y, point.z
                moved = moved + 1
                star = obj_get_next_with_same_behavior_id(star)
            end
        end
    end

    if wantCoins then
        local draw = room_stream_for("coin:" .. tag)
        if draw ~= nil then
            local places = {}
            for index, point in ipairs(pool) do places[index] = point end
            deal_order(places, draw)

            local at = 0
            for _, name in ipairs(POOL_BEHAVIOURS) do
                local id = _G[name]
                if type(id) == "number" then
                    local object = obj_get_first_with_behavior_id(id)
                    local seen = 0
                    while object ~= nil and seen < 10000 do
                        seen = seen + 1
                        at = at + 1
                        local point = scatter_from(
                            places[((at - 1) % #places) + 1], draw)
                        rando.note_moved(object)
                        object.oPosX, object.oPosY, object.oPosZ =
                            point.x, point.y, point.z
                        object.oHomeX, object.oHomeY, object.oHomeZ =
                            point.x, point.y, point.z
                        moved = moved + 1
                        object = obj_get_next_with_same_behavior_id(object)
                    end
                end
            end
        end
    end

    placedAt = tag
    return moved
end

local doorsAt = nil

local pipesAt = nil

local function deal_warp_nodes(constant, streamKey)
    local level, area = here()
    if level == nil then return 0 end

    local id = _G[constant]
    if type(id) ~= "number" then return 0 end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return 0 end
    if OF.util.binding("obj_get_next_with_same_behavior_id") == nil then return 0 end

    local found, nodes = {}, {}
    local one = obj_get_first_with_behavior_id(id)
    local seen = 0

    while one ~= nil and seen < 10000 do
        seen = seen + 1
        local params = one.oBehParams
        if type(params) == "number" then
            found[#found + 1] = one

            nodes[#nodes + 1] = math.floor(params / 65536) % 256
        end
        one = obj_get_next_with_same_behavior_id(one)
    end

    if #found < 2 then return 0 end

    local draw = room_stream_for(streamKey .. ":" .. tostring(level)
        .. ":" .. tostring(area))
    if draw == nil then return 0 end
    deal_order(nodes, draw)

    for index, object in ipairs(found) do
        local params = object.oBehParams
        rando.note_dealt(object)
        local was = math.floor(params / 65536) % 256
        object.oBehParams = params - was * 65536 + nodes[index] * 65536

        object.oBehParams2ndByte = nodes[index]
    end

    return #found
end

function rando.shuffle_doors_here()
    local level, area = here()
    if level == nil then return 0 end
    local dealt = deal_warp_nodes("id_bhvDoorWarp", "door")
    if dealt > 0 then
        doorsAt = tostring(level) .. ":" .. tostring(area)
    end
    return dealt
end

function rando.shuffle_pipes_here()
    local level, area = here()
    if level == nil then return 0 end
    local dealt = deal_warp_nodes("id_bhvWarpPipe", "pipe")
    if dealt > 0 then
        pipesAt = tostring(level) .. ":" .. tostring(area)
    end
    return dealt
end

local boxesAt = nil

rando.BOX_FIRST_SHUFFLED = 3

rando.CAP_BOX_FLAGS = {
    [0] = SAVE_FLAG_HAVE_WING_CAP or 0x2,
    [1] = SAVE_FLAG_HAVE_METAL_CAP or 0x4,
    [2] = SAVE_FLAG_HAVE_VANISH_CAP or 0x8,
}

function rando.box_may_move(byte)
    if type(byte) ~= "number" then return false end
    if byte >= rando.BOX_FIRST_SHUFFLED then return true end
    local flag = rando.CAP_BOX_FLAGS[byte]
    if flag == nil then return false end
    if OF.util.binding("save_file_get_flags") == nil then return false end
    return OF.util.has_flag(save_file_get_flags() or 0, flag) == true
end

function rando.shuffle_boxes_here()
    local level, area = here()
    if level == nil then return 0 end
    local id = _G["id_bhvExclamationBox"]
    if type(id) ~= "number" then return 0 end
    if OF.util.binding("obj_get_first_with_behavior_id") == nil then return 0 end
    if OF.util.binding("obj_get_next_with_same_behavior_id") == nil then return 0 end

    local found = {}
    local one = obj_get_first_with_behavior_id(id)
    local seen = 0
    while one ~= nil and seen < 10000 do
        seen = seen + 1

        local byte = one.oBehParams2ndByte
        local forced = type(one.oBehParams) == "number"
            and math.floor(one.oBehParams / 16777216) % 256 ~= 0
        if rando.box_may_move(byte)
            or (forced and type(byte) == "number" and byte < 3) then
            found[#found + 1] = one
        end
        one = obj_get_next_with_same_behavior_id(one)
    end
    if #found < 2 then return 0 end

    table.sort(found, function(a, b)
        if a.oHomeX ~= b.oHomeX then return a.oHomeX < b.oHomeX end
        if a.oHomeZ ~= b.oHomeZ then return a.oHomeZ < b.oHomeZ end
        return a.oHomeY < b.oHomeY
    end)

    local draw = room_stream_for("box:" .. tostring(level) .. ":" .. tostring(area))
    if draw == nil then return 0 end
    local bytes = {}
    for index, box in ipairs(found) do bytes[index] = box.oBehParams2ndByte end
    deal_order(bytes, draw)

    for index, box in ipairs(found) do
        rando.note_dealt(box)
        local params = box.oBehParams
        if type(params) == "number" then
            local was = math.floor(params / 65536) % 256
            box.oBehParams = params - was * 65536 + bytes[index] * 65536
        end
        box.oBehParams2ndByte = bytes[index]
    end
    boxesAt = tostring(level) .. ":" .. tostring(area)
    return #found
end

rando.HAND_NEVER = { upsidedown = true, carousel = true, lava = true,
    invertwater = true }

rando.RULE_LIMITS = { oneway = 0, steep = 0, overhang = 0, shoulders = 0,
    gas = 2, sting = 6 }

function rando.may_deal_mod(key, level)
    if type(level) ~= "number" or level <= 0 then return true end
    return not rando.HAND_NEVER[key]
end

function rando.may_deal_rule(key, step)
    if type(step) ~= "number" or step <= 1 then return true end
    local limit = rando.RULE_LIMITS[key]
    if limit == nil then return true end
    return limit >= 2 and step <= limit
end

local function deal_rule(key, step)
    if not rando.may_deal_rule(key, step) then return false end
    return OF.rules.set_step(key, step)
end
rando.deal_rule = deal_rule

rando.SECTIONS = {

    { name = "The way in",    keys = { "entrances", "paintings",
                                       "exits", "doorways", "pipes", "castlenumbers" },
      help = "where the castle's paintings, doors and pipes come out" },

    { name = "The world",     keys = { "world", "enemies", "boxes", "sky", "hour",
                                       "texshuffle" },
      help = "what stands in it, lives in it, is in its boxes or overhead" },
    { name = "The save file", keys = { "stars", "doors", "caps" },
      help = "what the host's file says is done already - for real" },

    { name = "The soundtrack", keys = { "music", "instruments" },
      help = "the tracks and the instruments" },
}

rando.KNOBS = {
    {
        key = "stars",
        name = "Stars to begin with",
        blurb = "the host's real save file - there is no backup",
        choices = {
            { value = "keep", name = "Leave the file alone" },
            { value = "none", name = "Wipe to zero" },
            { value = "all",  name = "Every one" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.save, "set_all_stars") then return false end
            return OF.save.set_all_stars(value == "all")
        end,
    },
    {
        key = "doors",
        name = "Castle doors",
        blurb = "applied after the stars, which write these themselves",
        choices = {
            { value = "keep", name = "As the file has them" },
            { value = "open", name = "All unlocked" },
            { value = "shut", name = "All locked" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.save, "set_flags") then return false end
            return OF.save.set_flags(OF.save.DOOR_FLAGS, value == "open")
        end,
    },
    {
        key = "caps",
        name = "Cap switches",
        blurb = "the three coloured switches, on or off together",
        choices = {
            { value = "keep", name = "As the file has them" },
            { value = "on",   name = "All pressed" },
            { value = "off",  name = "All unpressed" },
        },
        apply = function(value)
            if value == "keep" then return true end
            if not OF.util.asks(OF.save, "set_flags") then return false end
            return OF.save.set_flags(OF.save.CAP_FLAGS, value == "on")
        end,
    },

    {
        key = "world",
        name = "Where the stars and coins stand",
        blurb = "stars take another authored spot; coins scatter near one",
        choices = {
            { value = "keep",  name = "As the game placed them" },
            { value = "stars", name = "Stars move",           stars = true },
            { value = "coins", name = "Stars and coins move", stars = true, coins = true },
        },

        apply = function(value, choice)
            if value == "keep" then return true end
            rando.place_here(choice.stars, choice.coins)
            return true
        end,
    },

    {
        key = "entrances",
        name = "Where the entrances lead",
        blurb = "a drawn castle number - every painting and door moves",
        choices = {
            { value = "keep",  name = "As the castle has them" },
            { value = "drawn", name = "A drawn castle" },

            { value = "off",   name = "Put the castle back" },

            { value = "never", name = "A castle that never settles" },
        },
        apply = function(value)
            if value == "keep" then return true end

            if value == "off" then
                if not OF.util.asks(OF.shuffle, "off") then return false end
                return OF.shuffle.off()
            end
            if not OF.util.asks(OF.shuffle, "roll") then return false end

            local shaped, whyNot = rando.publish_shape()
            if not shaped then return false, whyNot end

            local draw = stream_for("entrances")
            local ok, why = OF.shuffle.roll(draw(9000) + 999)
            if not ok then return ok, why end
            if value ~= "never" then return true end

            if not OF.util.asks(OF.shuffle, "drift") then return false end
            return OF.shuffle.drift(true)
        end,
    },

    {
        key = "doorways",
        name = "Where the castle's doors lead",
        blurb = "the castle's warp doors - no other level has one",
        choices = {
            { value = "keep",  name = "As the castle has them" },
            { value = "drawn", name = "Drawn, door by door" },
        },
        apply = function(value)
            if value == "keep" then return true end

            rando.shuffle_doors_here()
            return true
        end,
    },

    {
        key = "sky",
        name = "What the sky is",
        blurb = "one of the engine's skies, for each level or entry",
        layer = "night",
        choices = rando.THREE_STOPS("Each level's own"),
        apply = function() return true end,
    },

    {
        key = "music",
        name = "What the levels play",
        blurb = "a course theme drawn for each level, or for each entry",
        choices = rando.THREE_STOPS("As the game has it"),
        apply = function() return true end,
    },

    {
        key = "enemies",
        name = "What the level's enemies are",
        blurb = "one drawn creature all run; a dress, so courses still end",
        choices = {
            { value = "keep",   name = "The course's own" },
            { value = "dress",  name = "One drawn creature, everywhere" },
            { value = "temper", name = "A drawn creature, in a drawn temper",
              temper = true },
        },
        apply = function(value, choice)
            if value == "keep" then return true end
            if not OF.util.asks(OF.enemies, "set_step") then return false end
            local rows = OF.enemies.BY_KEY or {}

            local dress = rows.dress
            local steps = dress ~= nil and dress.steps or nil
            if steps == nil or #steps < 2 then return false end

            local draw = stream_for("enemies")

            if not OF.enemies.set_step("dress", draw(#steps - 1) + 1, true) then
                return false
            end
            if not choice.temper then return true end

            local temper = rows.temper
            local moods = temper ~= nil and temper.steps or nil
            if moods == nil or #moods < 2 then return true end

            OF.enemies.set_step("temper", draw(#moods), true)
            return true
        end,
    },

    {
        key = "boxes",
        name = "What the boxes are filled with",
        blurb = "each level's own boxes, contents shuffled among them",
        choices = {
            { value = "keep",  name = "Whatever the course put in them" },
            { value = "drawn", name = "Shuffled within each level" },
        },
        apply = function(value)
            if value == "keep" then return true end
            rando.shuffle_boxes_here()
            return true
        end,
    },

    {
        key = "pipes",
        name = "Where the pipes come out",
        blurb = "Tiny-Huge Island's warp pipes - the only level with two",
        choices = {
            { value = "keep",  name = "As the level has them" },
            { value = "drawn", name = "Drawn, pipe by pipe" },
        },
        apply = function(value)
            if value == "keep" then return true end

            rando.shuffle_pipes_here()
            return true
        end,
    },

    {
        key = "hour",
        name = "What hour it is",
        blurb = "where the light comes from, for each level or entry",
        layer = "sun",
        choices = rando.THREE_STOPS("Each level's own"),
        apply = function() return true end,
    },

    {
        key = "texshuffle",
        name = "Texture shuffle",
        blurb = "the game's textures swapped, for each level or entry",
        choices = rando.THREE_STOPS("As the game has them"),
        apply = function() return true end,
    },

    {
        key = "paintings",
        name = "What the paintings say",
        blurb = "a name under each painting - true, missing or a lie",
        choices = {
            { value = "keep",  name = "Where they lead", labels = 0 },
            { value = "blind", name = "Nothing",         labels = 1 },
            { value = "lies",  name = "A lie",           labels = 2 },
        },
        apply = function() return rando.shape_and_castle() end,
    },

    {
        key = "castlenumbers",
        name = "The castle's numbers",
        blurb = "door prices, gates, two kings, the coin star, the slide",
        rules = { "doorprice", "gates", "kingbob", "whomp", "coinstar", "slidestar" },
        choices = {
            { value = "keep",  name = "As the lobby has them" },
            { value = "drawn", name = "Drawn" },
        },
        apply = function(value, choice)
            if value == "keep" then return true end
            if not OF.util.asks(OF.rules, "set_step") then return false end
            local draw = stream_for("castlenumbers")
            local turned = 0
            for _, key in ipairs(rando.knob("castlenumbers").rules) do
                local entry = OF.rules.find(key)
                local steps = entry ~= nil and OF.rules.step_count(entry) or 0
                if steps >= 2 and deal_rule(key, draw(steps)) then
                    turned = turned + 1
                end
            end
            return turned > 0
        end,
    },

    {
        key = "instruments",
        name = "The instruments",
        blurb = "one drawn soundfont, drawn for each level or each entry",
        layer = "bank",
        choices = rando.THREE_STOPS("As each track has them"),
        apply = function() return true end,
    },

    {
        key = "exits",
        name = "Where a course lets you out",
        blurb = "back out of your painting, or out of a third one",
        choices = {
            { value = "keep",  name = "The painting you took", exits = 0 },
            { value = "third", name = "A third painting",      exits = 1 },
        },
        apply = function() return rando.shape_and_castle() end,
    },
}

function rando.castle_numbers()
    local out = {}
    if not OF.util.asks(OF.rules, "find") then return out end
    for _, key in ipairs(rando.knob("castlenumbers").rules) do
        local entry = OF.rules.find(key)
        if entry ~= nil then
            local now = OF.rules.value(key)
            local said = OF.util.asks(OF.rules, "option_name")
                and OF.rules.option_name(entry, now) or nil
            out[#out + 1] = { name = entry.name, value = said or tostring(now) }
        end
    end
    return out
end

function rando.publish_shape()
    if not OF.util.asks(OF.shuffle, "set_shape") then return false end

    local pool = 3
    if OF.util.asks(OF.shuffle, "pool_entries") and type(OF.shuffle.POOLS) == "table" then
        pool = #OF.shuffle.POOLS - 1
    end
    local labels = (rando.choice_row("paintings") or {}).labels or 0
    local exits = (rando.choice_row("exits") or {}).exits or 0
    return OF.shuffle.set_shape(pool, labels, exits)
end

function rando.shape_and_castle()
    local shaped, why = rando.publish_shape()
    if not shaped then return false, why end
    if not OF.util.asks(OF.shuffle, "is_on") or OF.shuffle.is_on() then return true end
    if not OF.util.asks(OF.shuffle, "roll") then return false end
    local draw = stream_for("entrances")
    return OF.shuffle.roll(draw(9000) + 999)
end

function rando.knob(key)
    for _, entry in ipairs(rando.KNOBS) do
        if entry.key == key then return entry end
    end
    return nil
end

function rando.default(key)
    local knob = rando.knob(key)
    if knob == nil then return nil end
    return knob.choices[1].value
end

function rando.choice(key)
    local knob = rando.knob(key)
    if knob == nil then return nil end

    local stored = OF.util.stored(STORE .. "." .. key, "")
    for _, choice in ipairs(knob.choices) do
        if choice.value == stored then return stored end
    end

    local old = rando.OLD_STOPS[key]
    if old ~= nil and old[stored] ~= nil then return old[stored] end
    return knob.choices[1].value
end

function rando.choice_row(key)
    local knob = rando.knob(key)
    if knob == nil then return nil end
    local want = rando.choice(key)
    for _, choice in ipairs(knob.choices) do
        if choice.value == want then return choice end
    end
    return knob.choices[1]
end

function rando.set(key, value)
    local knob = rando.knob(key)
    if knob == nil then return false, "No such setting." end
    for _, choice in ipairs(knob.choices) do
        if choice.value == value then
            layerCache = {}
            return OF.util.store(STORE .. "." .. key, value)
        end
    end
    return false, "No such setting."
end

function rando.cycle(key)
    local knob = rando.knob(key)
    if knob == nil then return false, "No such setting." end
    local want = rando.choice(key)
    local ok, why = nil, nil
    for index, choice in ipairs(knob.choices) do
        if choice.value == want then
            local nextOne = knob.choices[index + 1] or knob.choices[1]
            ok, why = rando.set(key, nextOne.value)
            break
        end
    end
    if ok == nil then ok, why = rando.set(key, knob.choices[1].value) end
    if ok then
        rando.apply_live(key)
        if rando.is_on() then rando.refresh_here() end
    end
    return ok, why
end

function rando.apply_live(key)
    if not rando.is_on() then return false end
    local knob = rando.knob(key)
    if knob == nil then return false end
    local choice = rando.choice_row(key)
    if choice == nil or choice.value == knob.choices[1].value then return false end
    if key == "world" or key == "doorways" or key == "pipes" or key == "boxes" then
        rando.settle_now()
        return true
    end
    if not OF.util.is_host() or held == nil then return false end
    if rando.PAGE_KEEPS[key] then return false end
    held.applied[key] = true
    return knob.apply(choice.value, choice) == true
end

function rando.reset()
    local any = false
    for _, knob in ipairs(rando.KNOBS) do
        if rando.set(knob.key, knob.choices[1].value) then any = true end
    end

    rando.forget_seed()

    OF.util.store(STORE .. ".room", "")
    rando.forget_entries()

    if OF.util.is_host() and gGlobalSyncTable[rando.VIEW_KEY] ~= nil then
        OF.util.publish(rando.VIEW_KEY, nil)
    end
    return any
end

rando.PAGE_KEEPS = {
    stars = true, doors = true, caps = true,
}

local APPLY_ORDER = {
    "stars", "doors", "caps",
    "music",
    "entrances", "doorways", "pipes", "world", "enemies", "boxes", "sky", "hour",
    "texshuffle", "instruments",
    "paintings", "exits", "castlenumbers",
}

local ON_KEY = STORE .. ".on"
function rando.is_on()
    return OF.util.stored(ON_KEY, "") == "1"
end

local function store_on(on)
    OF.util.store(ON_KEY, on and "1" or "")
    rando.forget_entries()
end

function rando.capture()
    local h = { applied = {} }
    if OF.util.asks(OF.save, "reading") then h.save = OF.save.reading() end
    if OF.util.asks(OF.rules, "snapshot") then h.rules = OF.rules.snapshot() end
    if OF.util.asks(OF.enemies, "text") then h.enemies = OF.enemies.text() end
    if OF.util.asks(OF.shuffle, "capture") then h.castle = OF.shuffle.capture() end
    return h
end

function rando.give_back(h)
    if type(h) ~= "table" or not OF.util.is_host() then return 0 end
    local a = h.applied or {}
    local function did(...)
        for _, key in ipairs({ ... }) do if a[key] then return true end end
        return false
    end
    local back = 0
    local function count(ok) if ok then back = back + 1 end end
    if did("stars", "doors", "caps") and h.save ~= nil
        and OF.util.asks(OF.save, "world_give_back") then
        count(OF.save.world_give_back(h.save))
    end
    if did("castlenumbers") and h.rules ~= nil
        and OF.util.asks(OF.rules, "publish_text") then
        count(OF.rules.publish_text(OF.rules.restore_text(h.rules)))
    end
    if did("enemies") and h.enemies ~= nil and OF.util.asks(OF.enemies, "put_text") then
        count(OF.enemies.put_text(h.enemies))
    end
    if did("entrances", "paintings", "exits")
        and h.castle ~= nil and OF.util.asks(OF.shuffle, "put_back") then
        count(OF.shuffle.put_back(h.castle))
    end
    return back
end

function rando.set_on(on)
    if on then
        if rando.is_on() and held ~= nil then return true end
        return rando.roll()
    end
    local back = 0
    if held ~= nil then back = rando.give_back(held) end
    held = nil

    rando.forget_seed()
    back = back + rando.undo_here()
    rando.forget_dealt()
    store_on(false)
    rando.publish_view()
    rando.layer_changed()
    return true, back
end

function rando.toggle()
    return rando.set_on(not rando.is_on())
end

function rando.roll()

    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false, "a round or a run owns where everybody is standing"
    end
    if not OF.util.is_host() then
        return false, OF.lang.t("The host sets up the run.")
    end

    if not OF.perms.can("chaos") then
        return false, OF.lang.t("That is above your rank.")
    end

    local opened = false
    if held == nil then
        held = rando.capture()
        handedOut = {}
        opened = true
    end

    local done, refused = 0, {}
    for _, key in ipairs(APPLY_ORDER) do
        local knob = rando.knob(key)
        if knob ~= nil then
            local choice = rando.choice_row(key)

            if choice ~= nil and choice.value ~= knob.choices[1].value then
                held.applied[key] = true
                local ok = knob.apply(choice.value, choice)
                if ok then
                    done = done + 1
                else
                    refused[#refused + 1] = knob.name
                end
            end
        end
    end

    if done == 0 and #refused == 0 then
        if opened then held = nil end
        return false, OF.lang.t("No row below is set - choose one, then tick the Randomizer.")
    end

    store_on(true)
    rando.settle_now()
    rando.publish_view()
    rando.layer_changed()
    if #refused > 0 then
        return false, OF.lang.fill("@ of the run could not be set up",
            table.concat(refused, ", "))
    end

    OF.actionlog.by_hand(OF.util.presser(0),
        OF.lang.fill("set up a seeded run: castle @, draw @",
            tostring(rando.seed()), tostring(rando.draw_seed())))
    return true
end

function rando.forget_seed()
    drawSeed = nil
    OF.util.store(STORE .. ".draw", "")
end

function rando.seed()
    if OF.util.asks(OF.shuffle, "seed") then return OF.shuffle.seed() end
    return 0
end

function rando.draw_seed()
    if drawSeed == nil then
        local kept = tonumber(OF.util.stored(STORE .. ".draw", ""))
        if type(kept) == "number" and kept > 0 then drawSeed = math.floor(kept) end
    end
    if drawSeed ~= nil and drawSeed > 0 then return drawSeed end
    local now = (OF.util.optional("get_time", 0) or 0)
        + math.floor(((OF.util.optional("get_global_timer", 0) or 0)) % 100000)
    drawSeed = (step_of(now) % 9000) + 1000
    OF.util.store(STORE .. ".draw", tostring(drawSeed))
    return drawSeed
end

function rando.room_seed()
    if OF.util.is_host() then return rando.draw_seed() end
    local text = gGlobalSyncTable[rando.VIEW_KEY]
    if type(text) ~= "string" then return nil end
    local tail = string.match(text, "%-(%w+)$")
    local seed = tail ~= nil and OF.rules.from36(tail) or nil
    if type(seed) ~= "number" or seed <= 0 then return nil end
    return seed
end

rando.ACTION = "rando"
rando.VIEW_KEY = "ofRandoView"
function rando.view_text()
    local out = rando.is_on() and "1" or "0"
    for _, knob in ipairs(rando.KNOBS) do
        local want, at = rando.choice(knob.key), 1
        for index, choice in ipairs(knob.choices) do
            if choice.value == want then at = index end
        end
        out = out .. OF.rules.to36(at, 1)
    end
    return out .. "-" .. OF.rules.to36(rando.draw_seed(), 3)
end

function rando.publish_view()
    if not OF.util.is_host() then return false end
    local text = rando.view_text()
    if gGlobalSyncTable[rando.VIEW_KEY] == text then return false end
    OF.util.publish(rando.VIEW_KEY, text)
    return true
end

local function viewed()
    local text = gGlobalSyncTable[rando.VIEW_KEY]
    if OF.util.is_host() or type(text) ~= "string" or #text < 1 then return nil end
    return text
end

function rando.view_on()
    if OF.util.is_host() then return rando.is_on() end
    local text = viewed()
    if text == nil then return false end
    return string.sub(text, 1, 1) == "1"
end

function rando.view_choice_row(key)
    local text = viewed()
    if text == nil then return rando.choice_row(key) end
    for index, knob in ipairs(rando.KNOBS) do
        if knob.key == key then
            local at = OF.rules.from36(string.sub(text, index + 1, index + 1)) or 1
            return knob.choices[at] or knob.choices[1]
        end
    end
    return nil
end

function rando.press(what, arg, askerLocal)
    if askerLocal == nil and not OF.perms.can("chaos") then
        return false, "Your rank cannot do that.", "chaos"
    end
    if not OF.util.is_host() then
        if OF.util.asks(OF.net, "host_does") then
            return OF.net.host_does(rando.ACTION, tonumber(arg) or 0, nil,
                tostring(what) .. ":" .. tostring(arg or ""))
        end
        return false, "No host to ask yet - try again in a second."
    end
    local ok, why
    if what == "toggle" then
        ok, why = rando.toggle()
    elseif what == "reset" then
        ok, why = rando.reset()
        if not ok then why = "Every setting is already its default." end
    elseif what == "cycle" then
        ok, why = rando.cycle(tostring(arg))
    else
        return false, "No such press."
    end
    rando.publish_view()
    return ok, why
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.asks(OF.net, "register_action") then return end
    OF.net.register_action(rando.ACTION, "chaos", function(fromLocal, _, _, z)
        if not OF.util.is_host() then return false, "Only the host." end
        local what, arg = string.match(tostring(z or ""), "^(%a+):(.*)$")
        if what == nil then return false, "No such press." end
        return rando.press(what, arg, fromLocal)
    end)
end)

function rando.refresh_here()
    rando.undo_here()
    rando.forget_dealt()
    if rando.view_on() then rando.settle_now() end
    rando.layer_changed()
    return true
end

local viewTicks = 0
local viewSeen = nil
hook_event(HOOK_UPDATE, function()
    if not OF.util.is_host() then
        local text = gGlobalSyncTable[rando.VIEW_KEY]
        if text ~= viewSeen then
            local wasOn = viewSeen ~= nil and string.sub(viewSeen, 1, 1) == "1"
            viewSeen = text
            if wasOn ~= rando.view_on() then rando.forget_entries() end
            rando.refresh_here()
        end
        return
    end
    viewTicks = viewTicks + 1
    if viewTicks < 60 then return end
    viewTicks = 0
    rando.publish_view()
end)

function rando.build_page(panel)
    local rows = {}

    rows[#rows + 1] = panel.label_row(OF.lang.t(
        "Everything here is drawn by the run. Chosen settings live on their own pages."))

    local on = rando.view_on()
    local r, g, b = 255, 255, 255
    if on then r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b end
    rows[#rows + 1] = panel.with_help(panel.gated_row("chaos",
        panel.tick(on, OF.lang.t("Randomizer")), r, g, b, function()
            OF.util.report(rando.press("toggle"))
        end),
        OF.lang.t("on sets up every ticked row below; off puts all of it back"))

    rows[#rows + 1] = panel.with_help(panel.gated_confirm_row("chaos", "randoreset",
        OF.lang.t("Reset this page"), 200, 200, 200,
        function() OF.util.report(rando.press("reset")) end),
        OF.lang.t("unticks every row here - what a run already did stays done"))

    local function knob_rows(knob)
        local choice = rando.view_choice_row(knob.key)
        local key = knob.key
        local drawn = choice ~= nil and choice ~= knob.choices[1]
        local built = panel.gated_row("chaos",
            panel.tick(drawn, OF.lang.t(knob.name)),
            255, 255, 255, function()
                OF.util.report(rando.press("cycle", key))
            end)

        built = panel.level_right(built, drawn,
            choice ~= nil and OF.lang.t(choice.name) or nil)
        if knob.blurb ~= nil then
            built = panel.with_help(built, OF.lang.t(knob.blurb))
        end
        rows[#rows + 1] = built

        if key == "castlenumbers" and drawn then
            for _, line in ipairs(rando.castle_numbers()) do
                rows[#rows + 1] = panel.with_help(panel.label_row(
                    OF.lang.fill("@: @", OF.lang.t(line.name), OF.lang.t(line.value))),
                    OF.lang.t("as the lobby rules have it now"))
            end
        end
    end

    local placed = {}
    for _, section in ipairs(rando.SECTIONS) do
        local mine = {}
        for _, key in ipairs(section.keys) do
            local knob = rando.knob(key)
            if knob ~= nil then table.insert(mine, knob) end
        end
        if #mine > 0 then

            rows[#rows + 1] = panel.with_help(
                panel.header_row(OF.lang.t(section.name)), section.help)
            for _, knob in ipairs(mine) do
                placed[knob.key] = true
                knob_rows(knob)
            end
        end
    end

    local rest = {}
    for _, knob in ipairs(rando.KNOBS) do
        if not placed[knob.key] then table.insert(rest, knob) end
    end
    if #rest > 0 then
        rows[#rows + 1] = panel.header_row(OF.lang.t("Everything else"))
        for _, knob in ipairs(rest) do knob_rows(knob) end
    end

    if OF.util.is_host() and OF.util.asks(OF.shuffle, "spoiler")
        and OF.shuffle.is_on() then
        rows[#rows + 1] = panel.header_row(OF.lang.t("Behind the paintings"))
        rows[#rows + 1] = panel.with_help(panel.row(
            panel.tick(rando.spoiling, OF.lang.t("Show where every entrance leads")),
            255, 255, 255, function() rando.spoiling = not rando.spoiling end),
            OF.lang.t("only on your screen - the lobby is not told"))
        if rando.spoiling then
            for _, line in ipairs(OF.shuffle.spoiler()) do
                rows[#rows + 1] = panel.label_row(OF.lang.fill("@ - @",
                    OF.lang.t(line.from), OF.lang.t(line.to)))
            end
        end
    end

    rows[#rows + 1] = panel.back_row("fun")
    return rows
end

rando.spoiling = false

function rando.chat(msg)
        local text = string.lower(tostring(msg or ""))

        local wantOn = (text == "start" or text == "go" or text == "roll")
        local wantOff = (text == "off" or text == "stop")
        if wantOn or wantOff then
            if wantOn and rando.view_on() then
                return true, OF.lang.t("The run is already on.")
            end
            if wantOff and not rando.view_on() then
                return true, OF.lang.t("The run is not on.")
            end
            OF.util.report(rando.press("toggle"))
            return true
        end

        return true, OF.lang.t("Say 'start' or 'off'.")
end

hook_chat_command("rando",
    "- set up the run on the Randomizer page with 'start', put it all back with 'off'",
    function(msg) return rando.chat(msg) end)
hook_chat_command("randomize",
    "- set up the run on the Randomizer page with 'start', put it all back with 'off'",
    function(msg) return rando.chat(msg) end)
hook_chat_command("randomizer",
    "- set up the run on the Randomizer page with 'start', put it all back with 'off'",
    function(msg) return rando.chat(msg) end)

local DOOR_FLOOR_SLACK = 150

local function door_ground(door, x, z)
    local y = OF.util.optional("find_floor_height", nil, x, door.oPosY + 100, z)
    if type(y) ~= "number" then return false end
    local bottom = -11000
    if gLevelValues ~= nil and type(gLevelValues.floorLowerLimit) == "number" then
        bottom = gLevelValues.floorLowerLimit
    end
    return y > bottom + 1 and math.abs(y - door.oPosY) <= DOOR_FLOOR_SLACK
end

local CASTLE_DOORWAYS = {
    [1] = { { y = 512, z = -1074, walk = 1 }, { y = -1074, z = 922, walk = -1 } },
    [2] = { { y = 512, z = 3021, walk = -1 } },
    [3] = { { y = -1074, z = 922, walk = 1 } },
}
rando.CASTLE_DOORWAYS = CASTLE_DOORWAYS

local function castle_walk(door)
    local np = gNetworkPlayers[0]
    if np == nil or LEVEL_CASTLE == nil or np.currLevelNum ~= LEVEL_CASTLE then
        return nil
    end
    local list = CASTLE_DOORWAYS[np.currAreaIndex]
    if list == nil then return nil end
    if math.abs((door.oPosX or 0) + 1023) > 200 then return nil end
    for _, one in ipairs(list) do
        if math.abs((door.oPosY or 0) - one.y) < 60
            and math.abs((door.oPosZ or 0) - one.z) < 60 then
            return one.walk
        end
    end
    return nil
end

function rando.door_side(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if ACT_WARP_DOOR_SPAWN == nil or m.action ~= ACT_WARP_DOOR_SPAWN then return false end
    if (m.actionState or 0) ~= 0 then return false end
    local doorways = rando.view_choice_row("doorways")
    if not rando.view_on() or doorways == nil or doorways.value == "keep" then return false end
    if rando.stands_down() then return false end
    local door = m.usedObj
    if door == nil or m.pos == nil then return false end
    local walk = castle_walk(door)
    if walk ~= nil then

        if (m.pos.z - door.oPosZ) * walk > 0 then return false end
        m.pos.x = door.oPosX
        m.pos.z = door.oPosZ + 300 * walk

        m.faceAngle.y = (walk > 0) and 0 or -32768

        local yaw = door.oMoveAngleYaw or door.oFaceAngleYaw or 0
        local front = math.cos(yaw * math.pi / 32768) * walk > 0
        local arg = m.actionArg or 0
        m.actionArg = arg - (arg % 4) + (front and 1 or 2)
        return true
    end
    if door_ground(door, m.pos.x, m.pos.z) then return false end
    local ox, oz = 2 * door.oPosX - m.pos.x, 2 * door.oPosZ - m.pos.z
    if not door_ground(door, ox, oz) then return false end
    m.pos.x, m.pos.z = ox, oz
    local yaw = (m.faceAngle.y or 0) + 0x8000
    if yaw > 32767 then yaw = yaw - 65536 end
    m.faceAngle.y = yaw
    local arg = m.actionArg or 0
    if arg % 2 == 1 then m.actionArg = arg - 1 else m.actionArg = arg + 1 end
    return true
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, rando.door_side, OF.LOCAL_MARIO)

local settle = 0
local SETTLE_FRAMES = 20

hook_event(HOOK_ON_LEVEL_INIT, function()
    settle = SETTLE_FRAMES
    placedAt = nil
    doorsAt = nil
    pipesAt = nil
    boxesAt = nil
    rando.forget_here()

    rando.count_entry(level_now())
    if rando.draws_every_entry() then rando.layer_changed() end
end)

hook_event(HOOK_UPDATE, function()
    rando.watch_entries()
    rando.entry_tick()
end)

function rando.draws_every_entry()
    if not rando.view_on() then return false end
    for _, knob in ipairs(rando.KNOBS) do
        local row = rando.view_choice_row(knob.key)
        if row ~= nil and row.value == "entry" then return true end
    end
    return false
end

function rando.settle_now()
    settle = 1
end

function rando.forget_dealt()
    placedAt = nil
    doorsAt = nil
    pipesAt = nil
    boxesAt = nil
end

function rando.stands_down()
    return OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() == true
end

local roundHeld = false

function rando.round_edge()
    local now = rando.stands_down()
    if now == roundHeld then return false end
    roundHeld = now
    if now then
        rando.undo_here()
        rando.forget_dealt()
    else
        rando.settle_now()
    end
    return true
end

hook_event(HOOK_UPDATE, function()
    rando.round_edge()
    if settle <= 0 then return end
    settle = settle - 1
    if settle > 0 then return end

    if not rando.view_on() then return end

    if rando.stands_down() then return end

    local level, area = here()
    if level == nil then return end
    local tag = tostring(level) .. ":" .. tostring(area)

    local choice = rando.view_choice_row("world")
    if choice ~= nil and choice.value ~= "keep" and placedAt ~= tag then
        rando.place_here(choice.stars, choice.coins)
    end

    local doorways = rando.view_choice_row("doorways")
    if doorways ~= nil and doorways.value ~= "keep" and doorsAt ~= tag then
        rando.shuffle_doors_here()
    end

    local pipes = rando.view_choice_row("pipes")
    if pipes ~= nil and pipes.value ~= "keep" and pipesAt ~= tag then
        rando.shuffle_pipes_here()
    end

    local boxes = rando.view_choice_row("boxes")
    if boxes ~= nil and boxes.value ~= "keep" and boxesAt ~= tag then
        rando.shuffle_boxes_here()
    end
end)

function rando.ready()
    return true
end
