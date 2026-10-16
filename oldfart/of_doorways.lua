OF = OF or {}
OF.doorways = OF.doorways or {}

local doorways = OF.doorways

doorways.KEY = "ofDoors"
local MINE_KEY = "ofDoorMine"
doorways.MINE_KEY = MINE_KEY

local STORE_KEY = "doorways"
local STORE_ROOMS = "doorwayrooms"
local CUSTOM_LEVEL_START = 50

doorways.MAX = 4

doorways.MINE_MAX = 2

local PAIR_COLOURS = {
    { r = 120, g = 190, b = 255 },
    { r = 255, g = 170, b =  90 },
    { r = 150, g = 255, b = 150 },
    { r = 235, g = 140, b = 255 },
}

local MINE_COLOURS = {
    { r = 255, g = 235, b = 110 },
    { r = 240, g = 240, b = 240 },
}

local MOMENTUM_STEPS = {
    { name = "you stop at the far end" },
    { name = "half your speed comes with you", carry = 0.5 },
    { name = "all of your speed comes with you", carry = 1 },
    { name = "your speed and your fall, both", carry = 1, fall = true },
    { name = "you come out twice as fast", carry = 2, fall = true },
    { name = "faster every trip", carry = 1, fall = true, chain = 0.4 },
    { name = "it reverses - you come out backwards", carry = -1 },
}

local SPEED_CAP = 96

local CHAIN_GAP = 90
local CHAIN_MOST = 3

local REACH_STEPS = {
    { name = "at your feet" },
    { name = "a short throw",         units = 1200 },
    { name = "across the room",       units = 4000 },
    { name = "as far as you can see", units = 12000 },
}

local WIDTH_STEPS = {
    { name = "narrow",    units =  90 },
    { name = "a doorway", units = 150 },
    { name = "wide",      units = 240 },
    { name = "a gate",    units = 360 },
}

local CHORD_STEPS = {
    { name = "off - the menu and chat only" },
    { name = "D-pad right draws it", draw = R_JPAD, held = "D-pad right" },
}

local FACE_STEPS = {
    { name = "the way you were looking" },
    { name = "the way you are moving", along = "speed" },
    { name = "along the doorway", along = "out" },
    { name = "back the way you came", along = "back" },
}

local SIGHT_STEPS = {
    { name = "the ring and its name", column = true, label = true },
    { name = "the ring, no name",     column = true },
    { name = "the name only",         label = true },
    { name = "hidden - the host only", hostOnly = true },
    { name = "who is on the other side", column = true, label = true,
      watch = true },
}

doorways.LADDERS = {
    { key = "carried", name = "What your speed does",

      help = "what you carry in is what you carry out, or none of it",
      steps = MOMENTUM_STEPS, plain = 1 },
    { key = "reach", name = "How far you can place one",
      help = "the menu rows only - the gun's own cursor has no end",
      steps = REACH_STEPS, plain = 1 },
    { key = "width", name = "How wide an opening is",
      help = "a gate nobody can miss, or a slot you have to aim at",
      steps = WIDTH_STEPS, plain = 2 },

    { key = "chord", name = "Drawing the gun",
      help = "the same press puts it away again; L and R are the openings",
      steps = CHORD_STEPS, plain = 2 },
    { key = "facing", name = "Which way you face",
      help = "your speed turns with you, so a doorway can bend a run",
      steps = FACE_STEPS, plain = 1 },
    { key = "sight", name = "What a doorway shows",
      help = "all the way down to one only the host can see",
      steps = SIGHT_STEPS, plain = 1 },
}

doorways.BY_KEY = {}
for _, ladder in ipairs(doorways.LADDERS) do
    doorways.BY_KEY[ladder.key] = ladder
end

function doorways.width()
    local ladder = doorways.BY_KEY.width
    local step = ladder.steps[doorways.step("width")] or ladder.steps[ladder.plain]
    return step.units
end

function doorways.look()
    local ladder = doorways.BY_KEY.sight
    local step = ladder.steps[doorways.step("sight")] or ladder.steps[ladder.plain]
    if step.hostOnly then
        if not OF.util.is_host() then return nil end
        return ladder.steps[ladder.plain]
    end
    return step
end

function doorways.own_look()
    local ladder = doorways.BY_KEY.sight
    local step = ladder.steps[doorways.step("sight")] or ladder.steps[ladder.plain]
    if step.hostOnly then return ladder.steps[ladder.plain] end
    return step
end

local BELOW = 60
local ABOVE = 200

local function apart()
    return doorways.width() * 3
end

local MARIO_HEIGHT = 160

local NO_FLOOR = -10000

doorways.NAME_MAX = 10

local FIELD = "~"
local ENTRY = ";"
local function pack_one(pair)
    return table.concat({
        string.format("%.0f", pair.level),
        string.format("%.0f", pair.area),
        string.format("%.0f", pair.ax),
        string.format("%.0f", pair.ay),
        string.format("%.0f", pair.az),
        string.format("%.0f", pair.bx),
        string.format("%.0f", pair.by),
        string.format("%.0f", pair.bz),
        pair.name,
    }, FIELD)
end

local function unpack_one(text)
    if type(text) ~= "string" or text == "" then return nil end
    local fields = {}
    local rest = text
    for _ = 1, 8 do
        local at = string.find(rest, FIELD, 1, true)
        if at == nil then return nil end
        table.insert(fields, string.sub(rest, 1, at - 1))
        rest = string.sub(rest, at + 1)
    end

    local pair = {
        level = tonumber(fields[1]), area = tonumber(fields[2]),
        ax = tonumber(fields[3]), ay = tonumber(fields[4]), az = tonumber(fields[5]),
        bx = tonumber(fields[6]), by = tonumber(fields[7]), bz = tonumber(fields[8]),
        name = rest,
    }
    if pair.level == nil or pair.area == nil or pair.name == "" then return nil end
    if pair.ax == nil or pair.ay == nil or pair.az == nil then return nil end
    if pair.bx == nil or pair.by == nil or pair.bz == nil then return nil end
    return pair
end

local function pack_all(armed, list, steps)
    steps = steps or doorways.steps()
    local header = { armed and "1" or "0" }
    for _, ladder in ipairs(doorways.LADDERS) do

        header[#header + 1] = string.format("%.0f",
            steps[ladder.key] or ladder.plain)
    end
    local parts = { table.concat(header, FIELD) }
    for _, pair in ipairs(list) do table.insert(parts, pack_one(pair)) end
    return table.concat(parts, ENTRY)
end

function doorways.header_width()
    return 1 + #doorways.LADDERS * 2
end

local function pack_mine(list)
    local parts = {}
    for _, pair in ipairs(list) do parts[#parts + 1] = pack_one(pair) end
    return table.concat(parts, ENTRY)
end

local function short_name_of(level)
    if type(level) ~= "number" or level < CUSTOM_LEVEL_START then return "" end
    local info = OF.util.optional("smlua_level_util_get_info", nil, level)
    if info == nil then return "" end
    local short = tostring(info.shortName or "")
    if string.find(short, ENTRY, 1, true) ~= nil then return "" end
    return short
end

local function resolve_room(short)
    if short == nil or short == "" then return nil end
    local info = OF.util.optional("smlua_level_util_get_info_from_short_name",
        nil, short)
    if info == nil then return nil end
    local found = tonumber(info.levelNum)
    if found == nil or found < CUSTOM_LEVEL_START then return nil end
    return math.floor(found)
end

doorways.lost = 0

function doorways.restore(stored, rooms)
    doorways.lost = 0
    if type(stored) ~= "string" or stored == "" then return "" end

    local shorts = {}
    for piece in string.gmatch(tostring(rooms or "") .. ENTRY,
            "([^" .. ENTRY .. "]*)" .. ENTRY) do
        shorts[#shorts + 1] = piece
    end

    local parts, index = {}, 0
    for piece in string.gmatch(stored .. ENTRY,
            "([^" .. ENTRY .. "]*)" .. ENTRY) do
        if #parts == 0 then

            parts[1] = piece
        else
            index = index + 1
            local pair = unpack_one(piece)
            if pair == nil then
                doorways.lost = doorways.lost + 1
            elseif pair.level < CUSTOM_LEVEL_START then
                parts[#parts + 1] = piece
            else
                local found = resolve_room(shorts[index])
                if found == nil then
                    doorways.lost = doorways.lost + 1
                else
                    pair.level = found
                    parts[#parts + 1] = pack_one(pair)
                end
            end
        end
    end

    local packed = table.concat(parts, ENTRY)
    while #parts > 1 and #packed > OF.util.publish_limit() do
        table.remove(parts)
        doorways.lost = doorways.lost + 1
        packed = table.concat(parts, ENTRY)
    end
    return packed
end

local cachedFrom = nil
local cachedList = {}
local cachedArmed = true
local cachedSteps = {}

local function read_header(piece)
    local fields = {}
    for part in string.gmatch(piece .. FIELD, "([^" .. FIELD .. "]*)" .. FIELD) do
        fields[#fields + 1] = part
    end
    cachedArmed = (fields[1] or "1") ~= "0"
    for index, ladder in ipairs(doorways.LADDERS) do
        local want = tonumber(fields[index + 1])
        if type(want) ~= "number" or want < 1 or want > #ladder.steps then
            want = ladder.plain
        end
        cachedSteps[ladder.key] = math.floor(want)
    end
end

local function parse()
    local packed = gGlobalSyncTable[doorways.KEY]
    if type(packed) ~= "string" then packed = "" end
    if packed == cachedFrom then return end

    cachedFrom = packed
    cachedList = {}
    cachedArmed = true
    for _, ladder in ipairs(doorways.LADDERS) do
        cachedSteps[ladder.key] = ladder.plain
    end

    if packed == "" then return end

    local first = true
    for piece in string.gmatch(packed .. ENTRY, "([^" .. ENTRY .. "]*)" .. ENTRY) do
        if first then
            read_header(piece)
            first = false
        else
            local pair = unpack_one(piece)
            if pair ~= nil and #cachedList < doorways.MAX then
                pair.index = #cachedList + 1
                table.insert(cachedList, pair)
            end
        end
    end
end

local function rows()
    parse()
    return cachedList
end

function doorways.list()
    parse()
    local out = {}
    for index, pair in ipairs(cachedList) do
        out[index] = {
            index = pair.index, name = pair.name,
            level = pair.level, area = pair.area,
            ax = pair.ax, ay = pair.ay, az = pair.az,
            bx = pair.bx, by = pair.by, bz = pair.bz,
        }
    end
    return out
end

local cachedMineFrom = {}
local cachedMineOwn = {}
local cachedMineAll = {}

local function parse_one_mine(packed, localIndex)
    local out = {}
    if packed == "" then return out end
    for piece in string.gmatch(packed .. ENTRY, "([^" .. ENTRY .. "]*)" .. ENTRY) do
        local pair = unpack_one(piece)
        if pair ~= nil and #out < doorways.MINE_MAX then
            pair.index = #out + 1

            pair.mine = true
            pair.owner = localIndex
            pair.yours = (localIndex == 0)
            table.insert(out, pair)
        end
    end
    return out
end

local mineSeen = {}

local NO_ROWS = {}

local function parse_mine()
    local changed = false
    local seen = mineSeen
    for index in pairs(seen) do seen[index] = nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        local index = entry.localIndex
        seen[index] = true
        local row = gPlayerSyncTable ~= nil and gPlayerSyncTable[index] or nil
        local packed = row ~= nil and row[MINE_KEY] or nil
        if type(packed) ~= "string" then packed = "" end
        if packed ~= cachedMineFrom[index] then
            cachedMineFrom[index] = packed
            cachedMineOwn[index] = parse_one_mine(packed, index)
            changed = true
        end
    end

    for index in pairs(cachedMineFrom) do
        if not seen[index] then
            cachedMineFrom[index] = nil
            cachedMineOwn[index] = nil
            changed = true
        end
    end

    if not changed then return end

    cachedMineAll = {}
    for index = 0, MAX_PLAYERS - 1 do
        local list = cachedMineOwn[index]
        if list ~= nil then
            for _, pair in ipairs(list) do
                table.insert(cachedMineAll, pair)
            end
        end
    end
end

local function own_rows()
    parse_mine()
    return cachedMineAll
end

local function my_rows()
    parse_mine()
    return cachedMineOwn[0] or NO_ROWS
end

function doorways.own_list()
    local out = {}
    for index, pair in ipairs(my_rows()) do
        out[index] = {
            index = pair.index, name = pair.name, mine = true, yours = true,
            owner = pair.owner,
            level = pair.level, area = pair.area,
            ax = pair.ax, ay = pair.ay, az = pair.az,
            bx = pair.bx, by = pair.by, bz = pair.bz,
        }
    end
    return out
end

function doorways.all_own_list()
    local out = {}
    for index, pair in ipairs(own_rows()) do
        out[index] = {
            index = pair.index, name = pair.name, mine = true,
            yours = pair.yours, owner = pair.owner,
            level = pair.level, area = pair.area,
            ax = pair.ax, ay = pair.ay, az = pair.az,
            bx = pair.bx, by = pair.by, bz = pair.bz,
        }
    end
    return out
end

function doorways.armed()
    parse()
    return cachedArmed
end

function doorways.step(key)
    parse()
    local ladder = doorways.BY_KEY[key]
    if ladder == nil then return 1 end
    return cachedSteps[key] or ladder.plain
end

function doorways.steps()
    parse()
    local out = {}
    for _, ladder in ipairs(doorways.LADDERS) do
        out[ladder.key] = cachedSteps[ladder.key] or ladder.plain
    end
    return out
end

function doorways.step_name(key)
    local ladder = doorways.BY_KEY[key]
    if ladder == nil then return "" end
    local step = ladder.steps[doorways.step(key)] or ladder.steps[ladder.plain]
    return step.name
end

function doorways.held_for_round()
    if not OF.util.asks(OF.lockdown, "menu_stands_down") then return false end
    return OF.lockdown.menu_stands_down() == true
end

function doorways.live()
    return doorways.armed() and not doorways.held_for_round()
end

function doorways.colour(index)
    local entry = PAIR_COLOURS[((math.floor(index or 1) - 1) % #PAIR_COLOURS) + 1]
    return entry.r, entry.g, entry.b
end

function doorways.own_colour(index)
    local entry = MINE_COLOURS[((math.floor(index or 1) - 1) % #MINE_COLOURS) + 1]
    return entry.r, entry.g, entry.b
end

function doorways.pair_colour(pair)
    if pair == nil then return 255, 255, 255 end
    if pair.mine then return doorways.own_colour(pair.index) end
    return doorways.colour(pair.index)
end

function doorways.find_own(name)
    local needle = string.lower(tostring(name or ""))
    if needle == "" then return nil end
    for _, pair in ipairs(doorways.own_list()) do
        if string.lower(pair.name) == needle then return pair end
    end
    for _, pair in ipairs(doorways.own_list()) do
        if string.sub(string.lower(pair.name), 1, #needle) == needle then return pair end
    end
    return nil
end

function doorways.find(name)
    local needle = string.lower(tostring(name or ""))
    if needle == "" then return nil end
    for _, pair in ipairs(doorways.list()) do
        if string.lower(pair.name) == needle then return pair end
    end
    for _, pair in ipairs(doorways.list()) do
        if string.sub(string.lower(pair.name), 1, #needle) == needle then return pair end
    end
    return nil
end

function doorways.place_of(pair)
    if pair == nil then return "" end
    return OF.util.level_name(pair.level, pair.area)
end

function doorways.is_here(pair)
    local np = gNetworkPlayers[0]
    if np == nil or pair == nil then return false end
    return np.currLevelNum == pair.level and np.currAreaIndex == pair.area
end

function doorways.beyond(pair, x, y, z)
    if pair == nil then return 0 end

    local da = (x - pair.ax) ^ 2 + (y - pair.ay) ^ 2 + (z - pair.az) ^ 2
    local db = (x - pair.bx) ^ 2 + (y - pair.by) ^ 2 + (z - pair.bz) ^ 2
    local fx, fy, fz = pair.bx, pair.by, pair.bz
    if da > db then fx, fy, fz = pair.ax, pair.ay, pair.az end

    local reach = doorways.width()
    if type(reach) ~= "number" then return 0 end
    local me = gNetworkPlayers[0]
    if me == nil then return 0 end

    local count = 0
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        local m = gMarioStates[i]
        if np ~= nil and m ~= nil and m.pos ~= nil and np.connected
            and np.currLevelNum == pair.level
            and np.currAreaIndex == pair.area
            and OF.util.seen_here(i) then
            local ox, oy, oz = m.pos.x - fx, m.pos.y - fy, m.pos.z - fz
            if (ox * ox + oy * oy + oz * oz) <= reach * reach then
                count = count + 1
            end
        end
    end
    return count
end

function doorways.describe(pair)
    if pair == nil then return "" end
    local text = doorways.place_of(pair)
    if doorways.is_here(pair) then
        text = text .. ", " .. OF.lang.t("in this level")
    end
    return text
end

function doorways.may_change()
    if not OF.perms.can("waypoint_save") then
        return false, "Your rank cannot do that.", "waypoint_save"
    end
    if not OF.util.is_host() then
        return false, "Only the host can change the doorways."
    end
    return true
end

function doorways.may_change_own()
    if not OF.perms.can("doorway_own") then
        return false, "Your rank cannot place doorways of your own.", "doorway_own"
    end
    return true
end

function doorways.survey()
    if doorways.may_change() then return "room" end
    local ok, why, feature = doorways.may_change_own()
    if ok then return "mine" end
    return nil, why, feature
end

local function may_cross(pair)

    if doorways.held_for_round() then
        return false, "Not while a round is running."
    end

    if pair ~= nil and pair.mine and pair.yours then
        if not OF.perms.can("doorway_own") then
            return false, "Your rank cannot use doorways of your own."
        end
        return true
    end

    if not OF.perms.can("waypoint_use") then
        return false, "Your rank cannot use doorways."
    end
    return true
end

local function publish(armed, list, steps)
    local packed = pack_all(armed, list, steps)
    OF.util.publish(doorways.KEY, packed)
    OF.util.store(STORE_KEY, packed)

    local shorts, any = {}, false
    for _, pair in ipairs(list) do
        local short = short_name_of(pair.level)
        if short ~= "" then any = true end
        shorts[#shorts + 1] = short
    end
    if any then
        OF.util.store(STORE_ROOMS, table.concat(shorts, ENTRY))
    else
        OF.util.clear(STORE_ROOMS)
    end
end

local function publish_mine(list)
    return OF.util.publish_row(0, MINE_KEY, pack_mine(list))
end

local function survey_list(which)
    if which == "mine" then return doorways.own_list() end
    return doorways.list()
end

local function survey_max(which)
    if which == "mine" then return doorways.MINE_MAX end
    return doorways.MAX
end

local function survey_fits(which, list)
    local packed
    if which == "mine" then
        packed = pack_mine(list)
    else
        packed = pack_all(doorways.armed(), list)
    end
    return #packed <= OF.util.publish_limit()
end

local function survey_publish(which, list)
    if which == "mine" then return publish_mine(list) end
    return publish(doorways.armed(), list)
end

local function survey_full_why(which)
    if which == "mine" then
        return "You already have as many doorways of your own as you can carry."
    end
    return "This level already has as many doorways as it can hold."
end

function doorways.reset_options()
    if not OF.util.is_host() then return false end
    local steps, moved = doorways.steps(), false
    for _, ladder in ipairs(doorways.LADDERS) do
        if steps[ladder.key] ~= ladder.plain then moved = true end
        steps[ladder.key] = ladder.plain
    end
    if moved then publish(doorways.armed(), doorways.list(), steps) end
    return moved
end

function doorways.set_step(key, want)
    local ok, why, feature = doorways.may_change()
    if not ok then return false, why, feature end

    local ladder = doorways.BY_KEY[key]
    if ladder == nil then return false, "There is no such doorway setting." end

    want = math.floor(tonumber(want) or 0)
    if want < 1 then want = 1 end
    if want > #ladder.steps then want = #ladder.steps end

    local steps = doorways.steps()
    steps[key] = want
    publish(doorways.armed(), doorways.list(), steps)
    return true
end

function doorways.next_step(key)
    local ladder = doorways.BY_KEY[key]
    if ladder == nil then return false, "There is no such doorway setting." end
    local want = doorways.step(key) + 1
    if want > #ladder.steps then want = 1 end
    return doorways.set_step(key, want)
end

doorways.pending = nil

local function clean_name(name)

    local text = OF.util.plain(tostring(name or ""))
    text = string.gsub(text, "%" .. ENTRY, ",")
    text = string.match(text, "^%s*(.-)%s*$") or ""
    if #text > doorways.NAME_MAX then
        text = string.sub(text, 1, doorways.NAME_MAX)
    end
    return text
end

function doorways.suggested_name(which)
    local np = gNetworkPlayers[0]

    local number = #survey_list(which or doorways.survey() or "room") + 1
    local room = clean_name(np ~= nil and OF.util.level_name(np.currLevelNum)
        or "")
    local tail = " " .. number
    if room == "" then return "Door" .. tail end
    if #room + #tail > doorways.NAME_MAX then
        room = string.sub(room, 1, math.max(1, doorways.NAME_MAX - #tail))
    end
    return room .. tail
end

function doorways.landing(x, y, z)

    local floor = OF.util.optional("find_floor_height", nil, x, y + MARIO_HEIGHT, z)
    if type(floor) ~= "number" or floor <= NO_FLOOR then
        return nil, "That doorway has no floor at the other end."
    end

    local landY = y
    if landY < floor then landY = floor end

    local ceil = OF.util.optional("find_ceil_height", nil, x, floor + 10, z)
    if type(ceil) == "number" then
        if ceil - floor < MARIO_HEIGHT then
            return nil, "That doorway comes out inside a wall."
        end
        if landY > ceil - MARIO_HEIGHT then landY = ceil - MARIO_HEIGHT end
    end

    local water = OF.util.optional("find_water_level", nil, x, z)
    if type(water) == "number" and water > landY + MARIO_HEIGHT then
        return nil, "That doorway comes out under water."
    end

    return landY
end

local function too_close(which, skipName, x, y, z)
    local far = apart()
    local others = {}
    for _, pair in ipairs(doorways.all_own_list()) do
        if not pair.yours then table.insert(others, pair) end
    end
    local surveys = { { "room", doorways.list() }, { "mine", doorways.own_list() },
                      { "others", others } }
    for _, entry in ipairs(surveys) do
        for _, pair in ipairs(entry[2]) do
            if not (entry[1] == which and pair.name == skipName) then
                for _, end_ in ipairs({ { pair.ax, pair.ay, pair.az },
                                        { pair.bx, pair.by, pair.bz } }) do
                    local dx, dy, dz = x - end_[1], y - end_[2], z - end_[3]
                    if dx * dx + dy * dy + dz * dz < far * far then return true end
                end
            end
        end
    end
    return false
end

function doorways.place(name)
    local which, why, feature = doorways.survey()
    if which == nil then return false, why, feature end

    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or np == nil then return false, "Nothing to place from here." end

    name = clean_name(name)
    if name == "" then return false, "Give the doorway a name." end

    local list = survey_list(which)
    local existing = nil
    for index, pair in ipairs(list) do
        if pair.name == name then existing = index end
    end

    local pending = doorways.pending
    if pending ~= nil and (pending.name ~= name or (pending.survey or "room") ~= which) then
        pending = nil
    end

    if pending == nil then
        if existing == nil and #list >= survey_max(which) then
            return false, survey_full_why(which)
        end
        local _, landWhy = doorways.landing(m.pos.x, m.pos.y, m.pos.z)
        if landWhy ~= nil then return false, landWhy end
        if too_close(which, name, m.pos.x, m.pos.y, m.pos.z) then
            return false, "That is too close to a doorway already here."
        end
        doorways.pending = {
            name = name, level = np.currLevelNum, area = np.currAreaIndex,
            x = m.pos.x, y = m.pos.y, z = m.pos.z, survey = which,
        }
        return true, "One end is down. Walk to the other and place it again."
    end

    if pending.level ~= np.currLevelNum or pending.area ~= np.currAreaIndex then
        return false, "Both ends of a doorway have to be in the same level."
    end

    local dx = m.pos.x - pending.x
    local dy = m.pos.y - pending.y
    local dz = m.pos.z - pending.z
    local far = apart()
    if dx * dx + dy * dy + dz * dz < far * far then
        return false, "Those two ends are too close together to be a doorway."
    end

    local _, landWhy = doorways.landing(m.pos.x, m.pos.y, m.pos.z)
    if landWhy ~= nil then return false, landWhy end
    if too_close(which, name, m.pos.x, m.pos.y, m.pos.z) then
        return false, "That is too close to a doorway already here."
    end

    local pair = {
        name = name, level = pending.level, area = pending.area,
        ax = pending.x, ay = pending.y, az = pending.z,
        bx = m.pos.x, by = m.pos.y, bz = m.pos.z,
    }

    if existing ~= nil then list[existing] = pair else table.insert(list, pair) end

    if not survey_fits(which, list) then
        return false, "There is no room on the wire for another doorway."
    end

    survey_publish(which, list)
    doorways.pending = nil
    return true, "The doorway is open."
end

function doorways.aim_at(far)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil, nil, nil, "Nothing to place from here." end

    local aimed = far ~= nil

    if far == nil then
        local ladder = doorways.BY_KEY.reach
        local step = ladder.steps[doorways.step("reach")] or ladder.steps[ladder.plain]
        far = step.units
    end
    if far == nil then return m.pos.x, m.pos.y, m.pos.z end

    local eye = gLakituState
    if eye == nil or eye.pos == nil or eye.focus == nil then
        if aimed then return nil, nil, nil, "There is no camera to aim along." end
        return m.pos.x, m.pos.y, m.pos.z
    end

    local dx = eye.focus.x - eye.pos.x
    local dy = eye.focus.y - eye.pos.y
    local dz = eye.focus.z - eye.pos.z
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)

    if length < 1 then
        if aimed then return nil, nil, nil, "There is no camera to aim along." end
        return m.pos.x, m.pos.y, m.pos.z
    end
    dx, dy, dz = dx / length, dy / length, dz / length

    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        eye.pos.x, eye.pos.y, eye.pos.z, dx * far, dy * far, dz * far)
    if hit == nil or hit.surface == nil or hit.hitPos == nil then
        return nil, nil, nil, "Nothing in sight to put a doorway on."
    end

    local hx, hy, hz = hit.hitPos.x, hit.hitPos.y, hit.hitPos.z

    local pull = doorways.width() * 0.5
    local x = hx - dx * pull
    local y = hy - dy * pull
    local z = hz - dz * pull

    local floor = OF.util.optional("find_floor_height", nil, x, y + MARIO_HEIGHT, z)
    if type(floor) == "number" and floor > NO_FLOOR and y - floor < MARIO_HEIGHT then
        y = floor
    end
    return x, y, z
end

doorways.hand = nil

function doorways.hand_name(which)
    which = which or doorways.survey() or "room"
    local list = survey_list(which)
    local wanted = doorways.hand
    if wanted ~= nil then
        if doorways.pending ~= nil and doorways.pending.name == wanted
            and (doorways.pending.survey or "room") == which then
            return wanted
        end
        for _, pair in ipairs(list) do
            if pair.name == wanted and doorways.is_here(pair) then return wanted end
        end

        doorways.hand = nil
    end
    if doorways.pending ~= nil and (doorways.pending.survey or "room") == which then
        return doorways.pending.name
    end
    for _, pair in ipairs(list) do
        if doorways.is_here(pair) then return pair.name end
    end
    return doorways.suggested_name(which)
end

function doorways.step_hand()
    local which = doorways.survey() or "room"
    local here = {}
    for _, pair in ipairs(survey_list(which)) do
        if doorways.is_here(pair) then here[#here + 1] = pair.name end
    end
    if #here == 0 then return false end

    local now = doorways.hand_name(which)
    for index, name in ipairs(here) do
        if name == now then
            doorways.hand = here[index + 1]
            return true
        end
    end
    doorways.hand = here[1]
    return true
end

function doorways.put_end(which, name, far)

    local survey, why, feature = doorways.survey()
    if survey == nil then return false, why, feature end

    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or np == nil then return false, "Nothing to place from here." end

    if which ~= "a" and which ~= "b" then which = "a" end
    name = clean_name(name or "")
    if name == "" then name = doorways.hand_name(survey) end
    if name == "" then return false, "Give the doorway a name." end

    local x, y, z, aimWhy = doorways.aim_at(far)
    if x == nil then return false, aimWhy or "Nothing in sight to put a doorway on." end

    local landY, landWhy = doorways.landing(x, y, z)
    if landY == nil then return false, landWhy end
    y = landY

    local list = survey_list(survey)
    local existing = nil
    for index, pair in ipairs(list) do
        if pair.name == name then existing = index end
    end
    if too_close(survey, name, x, y, z) then
        return false, "That is too close to a doorway already here."
    end

    local far = apart()

    if existing ~= nil then
        local pair = list[existing]
        if pair.level ~= np.currLevelNum or pair.area ~= np.currAreaIndex then
            return false, "Both ends of a doorway have to be in the same level."
        end

        local ox, oy, oz = pair.bx, pair.by, pair.bz
        if which == "b" then ox, oy, oz = pair.ax, pair.ay, pair.az end
        local dx, dy, dz = x - ox, y - oy, z - oz
        if dx * dx + dy * dy + dz * dz < far * far then
            return false, "Those two ends are too close together to be a doorway."
        end

        local moved = {
            name = pair.name, level = pair.level, area = pair.area,
            ax = pair.ax, ay = pair.ay, az = pair.az,
            bx = pair.bx, by = pair.by, bz = pair.bz,
        }
        if which == "a" then
            moved.ax, moved.ay, moved.az = x, y, z
        else
            moved.bx, moved.by, moved.bz = x, y, z
        end
        list[existing] = moved

        if not survey_fits(survey, list) then
            return false, "There is no room on the wire to move that end."
        end

        survey_publish(survey, list)
        doorways.hand = name
        return true, "That end has moved."
    end

    local half = doorways.pending
    if half ~= nil and (half.name ~= name or (half.survey or "room") ~= survey) then
        half = nil
    end
    local halfWhich = nil
    if half ~= nil then halfWhich = half.which or "a" end

    if half == nil or halfWhich == which then
        if #list >= survey_max(survey) then
            return false, survey_full_why(survey)
        end
        doorways.pending = {
            name = name, level = np.currLevelNum, area = np.currAreaIndex,
            x = x, y = y, z = z, which = which, survey = survey,
        }
        doorways.hand = name
        return true, "One end is down. Put the other one down to open it."
    end

    if half.level ~= np.currLevelNum or half.area ~= np.currAreaIndex then
        return false, "Both ends of a doorway have to be in the same level."
    end

    local dx, dy, dz = x - half.x, y - half.y, z - half.z
    if dx * dx + dy * dy + dz * dz < far * far then
        return false, "Those two ends are too close together to be a doorway."
    end

    local pair = {
        name = name, level = half.level, area = half.area,
        ax = half.x, ay = half.y, az = half.z, bx = x, by = y, bz = z,
    }
    if which == "a" then
        pair.ax, pair.ay, pair.az = x, y, z
        pair.bx, pair.by, pair.bz = half.x, half.y, half.z
    end
    list[#list + 1] = pair

    if not survey_fits(survey, list) then
        return false, "There is no room on the wire for another doorway."
    end

    survey_publish(survey, list)
    doorways.pending = nil
    doorways.hand = name
    return true, "The doorway is open."
end

function doorways.remove(name)
    local ok, why, feature = doorways.may_change()
    if not ok then return false, why, feature end

    local wanted = doorways.find(name)
    if wanted == nil then return false, "There is no doorway by that name." end

    local kept = {}
    for _, pair in ipairs(doorways.list()) do
        if pair.name ~= wanted.name then table.insert(kept, pair) end
    end
    publish(doorways.armed(), kept)
    if doorways.pending ~= nil and doorways.pending.name == wanted.name
        and (doorways.pending.survey or "room") == "room" then
        doorways.pending = nil
    end
    return true
end

function doorways.remove_own(name)
    local ok, why, feature = doorways.may_change_own()
    if not ok then return false, why, feature end

    local wanted = doorways.find_own(name)
    if wanted == nil then return false, "You have no doorway by that name." end

    local kept = {}
    for _, pair in ipairs(doorways.own_list()) do
        if pair.name ~= wanted.name then table.insert(kept, pair) end
    end
    publish_mine(kept)
    if doorways.pending ~= nil and doorways.pending.name == wanted.name
        and doorways.pending.survey == "mine" then
        doorways.pending = nil
    end
    return true
end

function doorways.clear_own()
    local ok, why, feature = doorways.may_change_own()
    if not ok then return false, why, feature end
    publish_mine({})
    if doorways.pending ~= nil and doorways.pending.survey == "mine" then
        doorways.pending = nil
    end
    return true
end

function doorways.rename(from, to)
    local ok, why, feature = doorways.may_change()
    if not ok then return false, why, feature end

    to = clean_name(to)
    if to == "" then return false, "Give the doorway a name." end

    local wanted = doorways.find(from)

    if wanted == nil then
        local half = doorways.pending
        if half == nil
            or string.lower(half.name) ~= string.lower(tostring(from or "")) then
            return false, "There is no doorway by that name."
        end
        for _, pair in ipairs(doorways.list()) do
            if pair.name == to then
                return false, "There is already a doorway called that."
            end
        end

        doorways.pending = { name = to, level = half.level, area = half.area,
                             x = half.x, y = half.y, z = half.z,
                             which = half.which, survey = half.survey }
        if doorways.hand == half.name then doorways.hand = to end

        OF.actionlog.by_hand(OF.util.presser(0),
            OF.lang.fill("renamed a doorway: @", to), half.name, to)

        return true, OF.lang.fill("That doorway is called @ now.", to)
    end

    local list = doorways.list()
    for _, pair in ipairs(list) do
        if pair.name == to and pair.index ~= wanted.index then
            return false, "There is already a doorway called that."
        end
    end

    local edited = {}
    for _, pair in ipairs(list) do
        if pair.index == wanted.index then
            table.insert(edited, {
                level = pair.level, area = pair.area,
                ax = pair.ax, ay = pair.ay, az = pair.az,
                bx = pair.bx, by = pair.by, bz = pair.bz,
                name = to,
            })
        else
            table.insert(edited, pair)
        end
    end

    if #pack_all(doorways.armed(), edited) > OF.util.publish_limit() then
        return false, "There is no room on the wire for a name that long."
    end

    publish(doorways.armed(), edited)
    local half = doorways.pending
    if half ~= nil and half.name == wanted.name then

        doorways.pending = { name = to, level = half.level, area = half.area,
                             x = half.x, y = half.y, z = half.z,
                             which = half.which, survey = half.survey }
    end

    if doorways.hand == wanted.name then doorways.hand = to end

    OF.actionlog.by_hand(OF.util.presser(0),
        OF.lang.fill("renamed a doorway: @", to), wanted.name, to)
    return true, OF.lang.fill("That doorway is called @ now.", to)
end

function doorways.clear()
    local ok, why, feature = doorways.may_change()
    if not ok then return false, why, feature end
    publish(doorways.armed(), {})
    doorways.pending = nil
    return true
end

function doorways.set_armed(value)
    local ok, why, feature = doorways.may_change()
    if not ok then return false, why, feature end
    publish(value == true, doorways.list())
    return true
end

function doorways.own_anywhere()
    if gPlayerSyncTable == nil then return false end
    for _, entry in ipairs(OF.util.connected_players()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local packed = row ~= nil and row[MINE_KEY] or nil
        if type(packed) == "string" and packed ~= "" then return true end
    end
    return false
end

function doorways.put_armed(value)
    if not OF.util.is_host() then return false end
    value = value == true

    if #doorways.list() == 0 and not doorways.own_anywhere() then return false end
    if doorways.armed() == value then return false end
    publish(value, doorways.list())
    return true
end

local insideKeys = {}
local spareKeys = {}
local probeKeys = {}

local function forget_set(set)
    for key in pairs(set) do set[key] = nil end
end

local chainCount = 0
local chainAt = nil

local chainDoors = nil

local crossing = nil

local INTANGIBLE = ACT_FLAG_INTANGIBLE or 0x00001000

local function busy(m)
    if OF.util.has_flag(m.action or 0, INTANGIBLE) then return true end
    if ACT_BUBBLED ~= nil and m.action == ACT_BUBBLED then return true end

    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(0) then return true end
    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(0) then return true end
    return false
end

local function inside(x, y, z, ex, ey, ez, pad)
    local dx, dz = x - ex, z - ez
    local wide = doorways.width() + (pad or 0)
    if dx * dx + dz * dz > wide * wide then return false end
    return y > ey - BELOW and y < ey + ABOVE
end

local SHOULDER = 37
local BODY_AT = { 0, 80, 160 }

local function inside_body(x, y, z, ex, ey, ez)
    for _, up in ipairs(BODY_AT) do
        if inside(x, y + up, z, ex, ey, ez, SHOULDER) then return true end
    end
    return false
end

local function end_key(pair, x, y, z)
    return string.format("%s%.0f:%.0f:%.0f:%.0f:%.0f",
        pair.mine and ("m" .. (pair.owner or 0)) or "",
        pair.level, pair.area, x, y, z)
end

local function scan_ends(x, y, z, set, was)
    local newKey, newPair, tx, ty, tz, farKey = nil, nil, nil, nil, nil, nil
    for pass = 1, 2 do
        local list = (pass == 1) and rows() or own_rows()
        for _, pair in ipairs(list) do
            if doorways.is_here(pair) then

                if inside_body(x, y, z, pair.ax, pair.ay, pair.az) then
                    local key = end_key(pair, pair.ax, pair.ay, pair.az)
                    set[key] = true
                    if newKey == nil and (was == nil or not was[key]) then
                        newKey, newPair = key, pair
                        tx, ty, tz = pair.bx, pair.by, pair.bz
                        farKey = end_key(pair, pair.bx, pair.by, pair.bz)
                    end
                end
                if inside_body(x, y, z, pair.bx, pair.by, pair.bz) then
                    local key = end_key(pair, pair.bx, pair.by, pair.bz)
                    set[key] = true
                    if newKey == nil and (was == nil or not was[key]) then
                        newKey, newPair = key, pair
                        tx, ty, tz = pair.ax, pair.ay, pair.az
                        farKey = end_key(pair, pair.ax, pair.ay, pair.az)
                    end
                end
            end
        end
    end
    return newKey, newPair, tx, ty, tz, farKey
end

local lastX, lastY, lastZ = nil, nil, nil

local SWEEP_FAR = 1500
local SWEEP_MOST = 16
local sweepKeys = {}

local function sweep_travel(fromX, fromY, fromZ, x, y, z, was)
    if fromX == nil then return nil end
    local dx, dy, dz = x - fromX, y - fromY, z - fromZ
    local far = math.sqrt(dx * dx + dy * dy + dz * dz)
    local wide = doorways.width()
    if far <= wide or far > SWEEP_FAR then return nil end

    local steps = math.ceil(far / (wide * 0.5))
    if steps > SWEEP_MOST then steps = SWEEP_MOST end

    for i = 1, steps - 1 do
        local at = i / steps
        forget_set(sweepKeys)
        local key, pair, tx, ty, tz, farKey = scan_ends(
            fromX + dx * at, fromY + dy * at, fromZ + dz * at, sweepKeys, was)
        if key ~= nil then return key, pair, tx, ty, tz, farKey end
    end
    return nil
end

function doorways.end_at(x, y, z)
    forget_set(probeKeys)
    return scan_ends(x, y, z, probeKeys, nil)
end

local function refuse(why)

    OF.util.report(false, why)
end

local function say(ok, why, feature)
    if not OF.util.report(ok, why, feature) then return false end
    if type(why) == "string" and why ~= "" then
        OF.notify.show(why, "good", 4)
    end
    return true
end

local GUN_REACH = 0x8000

doorways.gun = { drawn = false, which = nil, at = nil }

local GUN_HOLDER = "doorwayGun"
local function can_stand_in_first_person(m)
    if m == nil or m.action == nil then return false end
    if ACT_FLAG_ALLOW_FIRST_PERSON == nil then return false end
    return OF.util.has_flag(m.action, ACT_FLAG_ALLOW_FIRST_PERSON)
end

local function real_camera_mode(mode)
    if type(mode) ~= "number" then return nil end
    if mode == CAMERA_MODE_NEWCAM or mode == CAMERA_MODE_NONE then return nil end
    return mode
end

local function write_lakitu_mode(mode)
    gLakituState.mode = mode
end

function doorways.key_taken_by(button)
    if button == nil then return nil end
    if OF.util.asks(OF.input, "opener") and OF.input.opener() == button then
        return "the menu"
    end
    if OF.util.asks(OF.input, "wheel_button")
        and OF.input.wheel_button() == button then
        return "the emote wheel"
    end
    return nil
end

function doorways.draw_key()
    local ladder = doorways.BY_KEY.chord
    local step = ladder.steps[doorways.step("chord")] or ladder.steps[ladder.plain]
    return step.draw, step.held, doorways.key_taken_by(step.draw)
end

function doorways.gun_switched_off()

    if doorways.held_for_round() then
        return true, "Not during a round - it owns the level."
    end

    local which, why, feature = doorways.survey()
    if which == nil then return true, why, feature end
    local key, _, taken = doorways.draw_key()
    if key ~= nil and taken ~= nil then
        return true, OF.lang.fill("That key belongs to @.", taken)
    end
    return false
end

function doorways.holster()
    local gun = doorways.gun
    if not gun.drawn then return false end
    gun.drawn = false
    gun.which = nil
    gun.at = nil

    local m = gMarioStates[0]
    local camera = m ~= nil and m.area ~= nil and m.area.camera or nil
    local was = gun.wasMode

    gun.wasMode = nil

    if m ~= nil and m.action == ACT_FIRST_PERSON then

        OF.util.optional("update_mario_sound_and_camera", nil, m)
        set_mario_action(m, ACT_IDLE, 0)
    elseif m ~= nil and can_stand_in_first_person(m) then

        set_mario_action(m, ACT_FIRST_PERSON, 0)
        OF.util.optional("update_mario_sound_and_camera", nil, m)
        set_mario_action(m, ACT_IDLE, 0)
    end

    if camera ~= nil and camera.mode == CAMERA_MODE_C_UP
        and type(was) == "number" and was ~= CAMERA_MODE_NEWCAM
        and was ~= CAMERA_MODE_C_UP and was ~= CAMERA_MODE_NONE then
        OF.util.optional("set_camera_mode", nil, camera, was, 1)
    end

    OF.util.return_free_cam(GUN_HOLDER)
    OF.util.leave_mode("gun")
    return true
end

function doorways.draw_gun()
    local gun = doorways.gun
    if gun.drawn then return false, "The doorway gun is already in your hand." end

    local off, offWhy, offFeature = doorways.gun_switched_off()
    if off then return false, offWhy, offFeature end

    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false, "Nothing to place from here." end
    if not can_stand_in_first_person(m) then
        return false, "Stand still on the ground to draw the doorway gun."
    end

    if OF.util.asks(OF.rules, "refuses_camera")
        and OF.rules.refuses_camera(CAMERA_MODE_C_UP) then
        return false, "The lobby's camera rule will not allow first person."
    end
    if OF.util.asks(OF.modifiers, "camera_mode_refused")
        and OF.modifiers.camera_mode_refused(CAMERA_MODE_C_UP) then
        return false, "A modifier has the camera locked."
    end

    if OF.util.asks(OF.cheats, "hover_takes")
        and (OF.cheats.hover_takes(L_TRIG) or OF.cheats.hover_takes(R_TRIG)) then
        return false, "Hover is on that trigger - switch it off to use the gun."
    end

    local mayHave, why = OF.util.enter_mode("gun")
    if not mayHave then return false, why end

    local camera = m.area ~= nil and m.area.camera or nil
    if camera == nil then
        OF.util.leave_mode("gun")
        return false, "There is no camera to aim along."
    end

    if OF.util.binding("update_mario_sound_and_camera") == nil then
        OF.util.leave_mode("gun")
        return false, "The gun cannot be put away again on this build."
    end

    local lent = OF.util.lend_free_cam(GUN_HOLDER)

    local standing = nil
    if gLakituState ~= nil and type(gLakituState.mode) == "number" then
        standing = gLakituState.mode
    elseif type(camera.mode) == "number" then
        standing = camera.mode
    end

    if standing == CAMERA_MODE_NEWCAM and lent == true and gLakituState ~= nil
        and OF.util.optional("camera_config_is_free_cam_enabled", nil) == false
    then

        local seed = CAMERA_MODE_CLOSE
        if real_camera_mode(camera.defMode) ~= nil then
            seed = camera.defMode
        end
        if real_camera_mode(gLakituState.defMode) ~= nil then
            seed = gLakituState.defMode
        end

        if pcall(write_lakitu_mode, seed)
            and type(gLakituState.mode) == "number" then
            standing = gLakituState.mode
        end
    end

    if type(standing) ~= "number" or standing == CAMERA_MODE_NEWCAM then
        OF.util.return_free_cam(GUN_HOLDER)
        OF.util.leave_mode("gun")
        return false, "The free camera will not stand down for the gun."
    end
    camera.mode = standing

    gun.wasMode = standing

    gun.drawn = true
    gun.which = nil
    gun.at = nil
    set_mario_action(m, ACT_FIRST_PERSON, 0)
    return true, "The doorway gun is in your hand. L is the first opening, R the second."
end

function doorways.toggle_gun()
    if doorways.gun.drawn then
        doorways.holster()
        return true, "The doorway gun is away."
    end
    return doorways.draw_gun()
end

function doorways.mode_live()
    return doorways.gun.drawn == true
end

function doorways.mode_suspend()
    if not doorways.gun.drawn then return false end
    doorways.holster()
    return true
end

function doorways.mode_resume()
    return doorways.draw_gun() == true
end

function doorways.fire(which)
    local gun = doorways.gun
    if not gun.drawn then return false, "The doorway gun is not in your hand." end
    if which ~= "a" and which ~= "b" then
        return false, "Hold L for the first opening or hold R for the second."
    end
    return doorways.put_end(which, nil, GUN_REACH)
end

local function aim_the_gun()
    local x, y, z = doorways.aim_at(GUN_REACH)
    if x == nil then
        doorways.gun.at = nil
        return
    end
    local at = doorways.gun.at
    if at == nil then
        at = { x = 0, y = 0, z = 0 }
        doorways.gun.at = at
    end
    at.x, at.y, at.z = x, y, z
end

local function pad(m)
    local gun = doorways.gun
    local draw = doorways.draw_key()
    if draw == nil then doorways.holster() return end

    if OF.panel ~= nil and OF.panel.open then doorways.holster() return end

    if OF.util.menu_has_screen() then doorways.holster() return end
    if OF.forge ~= nil and OF.forge.open then doorways.holster() return end
    if not OF.util.asks(OF.input, "poll") then doorways.holster() return end
    if OF.util.asks(OF.input, "blocked") and OF.input.blocked() then
        doorways.holster()
        return
    end

    if doorways.key_taken_by(draw) ~= nil then
        doorways.holster()
        return
    end

    if m.controller == nil then doorways.holster() return end
    local keyDown = OF.util.has_flag(m.controller.buttonDown or 0, draw)
    if not keyDown and not gun.drawn then return end

    if doorways.survey() == nil then
        doorways.holster()
        return
    end

    if gun.drawn and doorways.gun_switched_off() then
        doorways.holster()
        return
    end

    OF.input.poll(m)

    local pearlHold = OF.util.asks(OF.powerups, "PEARL_CHORD_HOLD")
        and OF.powerups.PEARL_CHORD_HOLD or nil
    local pearlPress = OF.util.asks(OF.powerups, "PEARL_CHORD_PRESS")
        and OF.powerups.PEARL_CHORD_PRESS or nil
    local theirs = pearlHold ~= nil and pearlPress == draw
        and OF.input.held(pearlHold)

    if OF.input.pressed(draw) and not theirs then
        say(doorways.toggle_gun())
        OF.input.take(m, draw)
        if not gun.drawn then return end
    end

    if not gun.drawn then return end

    if m.action ~= ACT_FIRST_PERSON then
        if not can_stand_in_first_person(m) then
            doorways.holster()
            return
        end
        set_mario_action(m, ACT_FIRST_PERSON, 0)
    end

    if OF.util.asks(OF.input, "claim_camera") then OF.input.claim_camera(m) end

    if OF.input.held(L_TRIG) then
        gun.which = "a"
    elseif OF.input.held(R_TRIG) then
        gun.which = "b"
    else
        gun.which = nil
    end

    aim_the_gun()

    local shot = OF.input.pressed(A_BUTTON) and A_BUTTON
        or (OF.input.pressed(B_BUTTON) and B_BUTTON or nil)
    if shot ~= nil then
        say(doorways.fire(gun.which))
    end
    OF.input.take(m, A_BUTTON)
    OF.input.take(m, B_BUTTON)
end

local function signed(angle)
    return ((math.floor(angle) + 0x8000) % 0x10000) - 0x8000
end

local function exit_yaw(m, pair, tx, ty, tz)
    local ladder = doorways.BY_KEY.facing
    local step = ladder.steps[doorways.step("facing")] or ladder.steps[ladder.plain]
    local along = step.along
    if along == nil or pair == nil then return nil end

    if along == "speed" then
        local vx, vz = m.vel.x or 0, m.vel.z or 0
        if vx * vx + vz * vz < 1 then return nil end
        return signed(atan2s(vz, vx))
    end

    local fx, fz = pair.ax, pair.az
    if tx == pair.ax and ty == pair.ay and tz == pair.az then
        fx, fz = pair.bx, pair.bz
    end

    local dx, dz = tx - fx, tz - fz
    if along == "back" then dx, dz = -dx, -dz end
    if dx * dx + dz * dz < 1 then return nil end
    return signed(atan2s(dz, dx))
end

local function on_before_mario_update(m)

    if m == nil or m.playerIndex ~= 0 or m.pos == nil then return end
    crossing = nil

    local fromX, fromY, fromZ = lastX, lastY, lastZ
    lastX, lastY, lastZ = m.pos.x, m.pos.y, m.pos.z

    pad(m)

    if not doorways.armed() then forget_set(insideKeys) return end

    forget_set(spareKeys)
    local key, pair, tx, ty, tz, farKey =
        scan_ends(m.pos.x, m.pos.y, m.pos.z, spareKeys, insideKeys)

    if key == nil then
        key, pair, tx, ty, tz, farKey =
            sweep_travel(fromX, fromY, fromZ, m.pos.x, m.pos.y, m.pos.z,
                         insideKeys)
    end
    insideKeys, spareKeys = spareKeys, insideKeys

    if key == nil then return end

    if busy(m) then return end

    local allowed, why = may_cross(pair)
    if not allowed then refuse(why) return end

    local landY, landWhy = doorways.landing(tx, ty, tz)
    if landY == nil then refuse(landWhy) return end

    crossing = { x = tx, y = landY, z = tz, key = farKey,
                 yaw = exit_yaw(m, pair, tx, ty, tz) }
end

local function carried(m, carry)
    if carry == nil then return 0, 0, 0, 0 end

    local vx = (m.vel.x or 0) * carry.h
    local vz = (m.vel.z or 0) * carry.h
    local vy = (m.vel.y or 0) * carry.v
    local fwd = (m.forwardVel or 0) * carry.h

    local flat = math.sqrt(vx * vx + vz * vz)
    if flat > SPEED_CAP then
        vx, vz = vx * SPEED_CAP / flat, vz * SPEED_CAP / flat
    end
    if vy > SPEED_CAP then vy = SPEED_CAP end
    if vy < -SPEED_CAP then vy = -SPEED_CAP end
    if fwd > SPEED_CAP then fwd = SPEED_CAP end
    if fwd < -SPEED_CAP then fwd = -SPEED_CAP end
    return vx, vy, vz, fwd
end

local function carry_now()
    local ladder = doorways.BY_KEY.carried
    local step = ladder.steps[doorways.step("carried")] or ladder.steps[ladder.plain]
    if step.carry == nil then return nil end
    local h = step.carry
    if step.chain ~= nil then h = h * (1 + step.chain * chainCount) end
    return { h = h, v = step.fall and 1 or 0 }
end

local function bump_chain()
    local now = OF.util.optional("get_global_timer", 0)
    if type(now) ~= "number" then now = 0 end

    local doors = cachedFrom
    if chainAt == nil or now - chainAt > CHAIN_GAP or now < chainAt
        or doors ~= chainDoors then
        chainCount = 0
    elseif chainCount < CHAIN_MOST then
        chainCount = chainCount + 1
    end
    chainAt = now
    chainDoors = doors
end

function doorways.chain()
    return chainCount
end

local function put_through(m, dest, carry)
    local obj = m.marioObj

    m.pos.x, m.pos.y, m.pos.z = dest.x, dest.y, dest.z

    local vx, vy, vz, fwd = carried(m, carry)

    if dest.yaw ~= nil then
        local turn = signed(dest.yaw - m.faceAngle.y)
        local flat = math.sqrt(vx * vx + vz * vz)
        if turn ~= 0 and flat > 0 then
            local heading = signed(atan2s(vz, vx) + turn)
            vx, vz = flat * sins(heading), flat * coss(heading)
        end
        m.faceAngle.y = dest.yaw
    end

    m.vel.x, m.vel.y, m.vel.z = vx, vy, vz
    m.forwardVel = fwd

    m.floorHeight = OF.util.optional("find_floor_height", m.pos.y,
        m.pos.x, m.pos.y + MARIO_HEIGHT, m.pos.z)
    m.ceilHeight = OF.util.optional("find_ceil_height", m.pos.y + MARIO_HEIGHT,
        m.pos.x, m.pos.y + 10, m.pos.z)
    m.waterLevel = OF.util.optional("find_water_level", NO_FLOOR,
        m.pos.x, m.pos.z)

    if type(m.floorHeight) == "number" and m.pos.y < m.floorHeight then
        m.pos.y = m.floorHeight
    end
    if type(m.ceilHeight) == "number"
        and m.pos.y > m.ceilHeight - MARIO_HEIGHT then
        m.pos.y = m.ceilHeight - MARIO_HEIGHT
    end

    m.peakHeight = m.pos.y
    m.quicksandDepth = 0

    if m.area ~= nil and m.area.camera ~= nil then
        OF.util.optional("soft_reset_camera", nil, m.area.camera)
    end

    if obj == nil then return end

    local gfx = obj.header ~= nil and obj.header.gfx or nil
    if gfx ~= nil then
        vec3f_copy(gfx.pos, m.pos)
        if gfx.angle ~= nil then gfx.angle.y = m.faceAngle.y end
    end

    obj.oPosX, obj.oPosY, obj.oPosZ = m.pos.x, m.pos.y, m.pos.z

    obj.oVelX, obj.oVelY, obj.oVelZ = m.vel.x, m.vel.y, m.vel.z

    local angle = (gfx ~= nil and gfx.angle ~= nil) and gfx.angle or m.faceAngle
    obj.oFaceAnglePitch, obj.oFaceAngleYaw, obj.oFaceAngleRoll =
        angle.x, angle.y, angle.z
    obj.oMoveAnglePitch, obj.oMoveAngleYaw, obj.oMoveAngleRoll =
        angle.x, angle.y, angle.z

    if m.angleVel ~= nil then
        obj.oAngleVelPitch, obj.oAngleVelYaw, obj.oAngleVelRoll =
            m.angleVel.x, m.angleVel.y, m.angleVel.z
    end

    OF.util.skip_interpolation(obj)
end

function doorways.put_at(m, x, y, z)
    if m == nil or m.pos == nil then return false end
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return false
    end
    put_through(m, { x = x, y = y, z = z })

    if m.playerIndex == 0 and m.pos ~= nil then
        lastX, lastY, lastZ = m.pos.x, m.pos.y, m.pos.z
    end
    return true
end

local function on_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    local dest = crossing
    if dest == nil then return end
    crossing = nil

    bump_chain()
    put_through(m, dest, carry_now())

    forget_set(insideKeys)
    scan_ends(m.pos.x, m.pos.y, m.pos.z, insideKeys, nil)

    lastX, lastY, lastZ = m.pos.x, m.pos.y, m.pos.z
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update, OF.LOCAL_MARIO)
hook_event(HOOK_MARIO_UPDATE, on_mario_update, OF.LOCAL_MARIO)

hook_event(HOOK_ON_LEVEL_INIT, function()
    forget_set(insideKeys)
    crossing = nil

    lastX, lastY, lastZ = nil, nil, nil

    doorways.holster()

    chainCount = 0
    chainAt = nil
    chainDoors = nil
end)

local COLUMN_TOP = 320
local MARK_SCALE = 0.42
local MARK_FADE = 9000

local world = { x = 0, y = 0, z = 0 }
local screen = { x = 0, y = 0, z = 0 }

local function project(x, y, z)
    world.x, world.y, world.z = x, y, z
    if not OF.util.world_screen(world, screen) then return nil end
    return screen.x, screen.y
end

doorways.RING_POINTS = 28
doorways.RING_TALL = 1.6
doorways.RING_INNER = 0.8

function doorways.ring_size(width)
    local rx = math.max(45, (tonumber(width) or doorways.width()) * 0.5)
    return rx, rx * doorways.RING_TALL
end

local function ring_point(x, y, z, rx, ry, t, scale, ux, uz)
    local c, s = math.cos(t), math.sin(t)
    return x + ux * rx * scale * c, y + ry + ry * scale * s, z + uz * rx * scale * c
end

local function ring_side(x, z)
    local cx, cz = x, z - 1
    if gLakituState ~= nil and gLakituState.pos ~= nil then
        cx, cz = gLakituState.pos.x, gLakituState.pos.z
    end
    local dx, dz = x - cx, z - cz
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 1 then return 1, 0 end
    return -dz / len, dx / len
end

function doorways.draw_ring(x, y, z, r, g, b, alpha, width)
    local rx, ry = doorways.ring_size(width)
    local ux, uz = ring_side(x, z)
    local n = doorways.RING_POINTS
    local drawn = 0
    for _, loop in ipairs({ { 1, 1 }, { doorways.RING_INNER, 0.35 } }) do
        local scale, fade = loop[1], loop[2]
        local px, py = nil, nil
        for i = 0, n do
            local t = (i / n) * math.pi * 2
            local sx, sy = project(ring_point(x, y, z, rx, ry, t, scale, ux, uz))
            if sx ~= nil and px ~= nil and i > 0 then
                local gap = math.sqrt((sx - px) ^ 2 + (sy - py) ^ 2)
                local size = math.max(3, math.min(12, gap * 1.1))

                OF.util.rect((sx + px) * 0.5 - size * 0.5, (sy + py) * 0.5 - size * 0.5,
                    size, size, r, g, b, math.floor(alpha * fade))
                drawn = drawn + 1
            end
            px, py = sx, sy
        end
    end
    local topX, topY = project(x, y + ry * 2, z)
    return topX, topY, drawn
end

local function seen(x, y, z)
    if gLakituState == nil or gLakituState.pos == nil then return true end
    if not OF.util.asks(OF.markers, "clear_line") then return true end
    return OF.markers.clear_line(gLakituState.pos.x, gLakituState.pos.y,
        gLakituState.pos.z, x, y + COLUMN_TOP * 0.5, z) == true
end

local function draw_end(pair, x, y, z, alpha, look)

    if project(x, y + COLUMN_TOP * 0.5, z) == nil then return end
    if not seen(x, y, z) then return end

    local r, g, b = doorways.pair_colour(pair)
    local topX, topY = nil, nil

    if look.column then
        topX, topY = doorways.draw_ring(x, y, z, r, g, b, alpha)
    else

        local _, ry = doorways.ring_size()
        topX, topY = project(x, y + ry * 2, z)
    end

    if topX == nil then return end
    if not look.label then return end

    local written = pair.name
    if look.watch then
        local waiting = doorways.beyond(pair, x, y, z)
        if waiting > 0 then
            written = pair.name .. " (" .. tostring(waiting) .. ")"
        end
    end

    local width, height = OF.util.text_size(written, MARK_SCALE)
    OF.util.plate(topX - width * 0.5 - 4, topY - height - 10,
        width + 8, height + 4, { alpha = alpha })
    OF.util.text(written, topX - width * 0.5, topY - height - 8,
        MARK_SCALE, r, g, b, alpha)
end

local function draw_one(pair, x, y, z, me, armed, look)
    local dx, dy, dz = x - me.pos.x, y - me.pos.y, z - me.pos.z
    local off = math.sqrt(dx * dx + dy * dy + dz * dz)
    local near = 1 - math.max(0, math.min(1, off / MARK_FADE))
    local alpha = math.floor((110 + 145 * near) * (armed and 1 or 0.34))
    if alpha > 0 then draw_end(pair, x, y, z, alpha, look) end
end

local function gun_colour()

    local which = doorways.survey() or "room"
    local list = survey_list(which)
    local name = doorways.hand_name(which)
    for _, pair in ipairs(list) do
        if pair.name == name then return doorways.pair_colour(pair) end
    end
    if which == "mine" then return doorways.own_colour(#list + 1) end
    return doorways.colour(#list + 1)
end

local function draw_cursor(at, r, g, b)
    local topX, topY = doorways.draw_ring(at.x, at.y, at.z, r, g, b, 230)
    return topX, topY
end

local function gun_legend()
    local gun = doorways.gun
    if gun.which == "a" then
        return "Placing the first opening - press A or B to fire"
    elseif gun.which == "b" then
        return "Placing the second opening - press A or B to fire"
    end
    return "Hold L for the first opening, hold R for the second"
end

function doorways.gun_view()
    local gun = doorways.gun
    if gun == nil or not gun.drawn then return nil end
    local r, g, b = gun_colour()

    local legend = OF.util.say_buttons(OF.lang.t(gun_legend()))
    if gun.at == nil then
        legend = OF.lang.t("Nothing in sight - the cursor has run off the map")
    end
    local screenAt = nil
    if gun.at ~= nil then
        local _, ry = doorways.ring_size()
        local sx, sy = project(gun.at.x, gun.at.y + ry * 2, gun.at.z)
        if sx ~= nil then screenAt = { x = sx, y = sy } end
    end
    return { which = gun.which, at = gun.at, r = r, g = g, b = b,
             name = doorways.hand_name(), legend = legend, screen = screenAt }
end

local function render_gun()
    local gun = doorways.gun
    if not gun.drawn then return false end

    local r, g, b = gun_colour()
    local topX, topY = nil, nil
    if gun.at ~= nil then topX, topY = draw_cursor(gun.at, r, g, b) end

    local width = OF.util.optional("djui_hud_get_screen_width", nil)
    local height = OF.util.optional("djui_hud_get_screen_height", nil)
    if type(width) ~= "number" or type(height) ~= "number" then return true end

    if topX ~= nil and gun.which ~= nil then
        doorways.gun_hud(doorways.gun_view(), width, height)
    else
        doorways.gun_hud(doorways.gun_view(), width, height, true)
    end
    return true
end

function doorways.gun_hud(view, width, height, noName)
    local H = OF.hud
    if view == nil or H == nil then return false end
    local tone = { view.r or 255, view.g or 255, view.b or 255 }
    if type(H.accent_lift) == "function" then tone = H.accent_lift(tone) end
    if not noName and view.screen ~= nil and view.which ~= nil and view.name ~= nil and view.name ~= "" then
        local tw = H.ink_width(view.name, "body")
        local _, _, capH = H.cap("body", 1, view.name)
        local w, h = tw + H.S.s3 * 2, capH + H.S.s2 * 2
        local x, y = math.floor(view.screen.x - w / 2), math.floor(view.screen.y - h - 6)
        H.plate(x, y, w, h, { alpha = 1, lit = true })
        H.rect(x, y + h - 2, w, 2, tone, 255)
        H.name_mid(view.name, view.screen.x, y + h / 2 - 1, "body", tone, 255, "center")
    end
    if view.legend ~= nil and view.legend ~= "" then
        local tw = H.ink_width(view.legend, "body")
        local _, _, capH = H.cap("body", 1, view.legend)
        local w, h = tw + H.S.s4 * 2 + 4, capH + H.S.s3 * 2
        local x, y = math.floor(width / 2 - w / 2), math.floor(height * 0.72)
        H.plate(x, y, w, h, { alpha = 1, strip = tone })
        H.text_mid(view.legend, width / 2 + 2, y + h / 2, "body", "ink", 255, "center")
    end
    return true
end

local function render()
    local me = gMarioStates[0]
    if me == nil or me.pos == nil then return end
    if OF.util.menu_has_screen() then return end

    local list = rows()

    local mine = own_rows()

    local drewGun = false
    if doorways.gun.drawn then
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_NORMAL)
        drewGun = render_gun()
    end

    if #list == 0 and #mine == 0 then return end

    local look = doorways.look()
    local ownLook = doorways.own_look()
    if look == nil and #mine == 0 then return end

    if not drewGun then
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_NORMAL)
    end

    local armed = doorways.live()

    if look ~= nil then
        for _, pair in ipairs(list) do
            if doorways.is_here(pair) then
                draw_one(pair, pair.ax, pair.ay, pair.az, me, armed, look)
                draw_one(pair, pair.bx, pair.by, pair.bz, me, armed, look)
            end
        end
    end

    for _, pair in ipairs(mine) do
        if doorways.is_here(pair) then
            draw_one(pair, pair.ax, pair.ay, pair.az, me, armed, ownLook)
            draw_one(pair, pair.bx, pair.by, pair.bz, me, armed, ownLook)
        end
    end
end

hook_event(HOOK_ON_HUD_RENDER, render)

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.is_host() then return end
    local stored = mod_storage_load(STORE_KEY, "")
    if stored == nil or stored == "" then return end

    local rooms = mod_storage_load(STORE_ROOMS, "")
    local packed = doorways.restore(stored, rooms)
    if packed ~= "" then OF.util.publish(doorways.KEY, packed) end
end)

hook_chat_command("door",
    "name <doorway> <new name> - rename a doorway, which no row can do",
    function(msg)
        local said = OF.util.plain(msg or "")
        local from, to = string.match(said, "^[Nn][Aa][Mm][Ee]%s+(%S+)%s+(.+)$")
        if from == nil then

            return true, OF.lang.t(
                "Say 'name', the doorway, then what to call it. The rest is on Travel, Waypoints.")
        end
        say(doorways.rename(from, to))
        return true
    end)

function doorways.build_page(panel)
    local rows = {}
    if panel == nil or panel.label_row == nil or panel.host_row == nil then
        return rows
    end

    local which = doorways.survey() or "room"
    local list = (which == "mine") and doorways.own_list() or doorways.list()
    local most = (which == "mine") and doorways.MINE_MAX or doorways.MAX
    local here = 0
    for _, pair in ipairs(list) do
        if doorways.is_here(pair) then here = here + 1 end
    end

    table.insert(rows, panel.with_help(panel.label_row(OF.lang.t(
        "Two openings in one level. Walk into either and you are at the other.")),
        OF.lang.t("both ends stand in the same level, and both work both ways")))

    if doorways.held_for_round() then
        table.insert(rows, panel.label_row(OF.lang.t(
            "A round has the lobby - nothing crosses until it ends.")))
    elseif not doorways.armed() then
        table.insert(rows, panel.label_row(OF.lang.t(
            "The doorways are closed. Nothing crosses until they are opened.")))
    end
    table.insert(rows, panel.with_help(panel.label_row(OF.lang.fill(
        (which == "mine") and "Your own doorways in this level: @ of @"
            or "Doorways in this level: @ of @",
        tostring(here), tostring(most))),
        OF.lang.t("the ceiling is per level, so another level starts empty")))

    if (doorways.lost or 0) > 0 then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "@ doorway(s) are gone: their level is not in this game.",
            tostring(doorways.lost))))
    end

    local looking = doorways.step("reach") > 1
    local first = looking and "+ Put the first end where you are looking"
        or "+ Put the first end at your feet"
    local second = looking and "+ Put the second end where you are looking"
        or "+ Put the second end at your feet"
    local function place_row(text, r, g, b, action)
        if doorways.survey() == "mine" and panel.gated_row ~= nil then
            return panel.gated_row("doorway_own", text, r, g, b, action)
        end
        return panel.host_row("waypoint_save", text, r, g, b, action)
    end

    local hand = doorways.hand_name(doorways.survey())
    table.insert(rows, panel.with_help(
        place_row(OF.lang.t(first), 120, 255, 120,
            function() say(doorways.put_end("a")) end),
        OF.lang.fill("the doorway being built or moved is '@'", hand)))
    table.insert(rows, panel.with_help(place_row(OF.lang.t(second),
        120, 255, 120, function() say(doorways.put_end("b")) end),
        OF.lang.fill("the other end of '@' - both ends make one crossing", hand)))

    if here > 0 and panel.with_right ~= nil then
        table.insert(rows, panel.with_right(
            place_row(OF.lang.t("Those two rows work on"), 255, 215, 0,
                function() doorways.step_hand() end),
            hand))
    end

    for _, ladder in ipairs(doorways.LADDERS) do
        local key = ladder.key
        local step = doorways.step(key)
        local built = panel.with_help(
            panel.host_row("waypoint_save",
                OF.lang.t(ladder.name) .. ": "
                    .. OF.lang.t(doorways.step_name(key)),
                255, 255, 255,
                function() OF.util.report(doorways.next_step(key)) end,
                panel.ask_host ~= nil and panel.ask_host(doorways.STEP_ACTION, key,
                    step % #ladder.steps + 1) or nil),
            OF.lang.t(ladder.help))
        if panel.with_slider ~= nil then
            built = panel.with_slider(built, step - 1, #ladder.steps - 1,
                function(wanted)
                    if OF.util.is_host() then
                        OF.util.report(doorways.set_step(key, wanted + 1))
                    else
                        OF.util.report(OF.net.cohost_does(doorways.STEP_ACTION,
                            key, wanted + 1))
                    end
                end)
        end
        table.insert(rows, built)
    end

    local _, held, takenBy = doorways.draw_key()
    if held ~= nil then
        table.insert(rows, panel.with_help(
            place_row(OF.lang.t(doorways.gun.drawn and "+ Put the doorway gun away"
                                                    or "+ Draw the doorway gun"),
                255, 215, 0, function() say(doorways.toggle_gun()) end),
            OF.lang.fill("the same on @, which puts it away again", held)))
        table.insert(rows, panel.with_help(panel.label_row(OF.util.say_buttons(OF.lang.t(
            "In hand: hold L for the first opening or hold R for the second, press A or B to fire"), true)),
            OF.lang.t("the gun places an end wherever you are aiming")))

        local notice = OF.util.mode_notice("gun")
        if notice ~= nil then table.insert(rows, panel.label_row(notice)) end

        if takenBy ~= nil then
            table.insert(rows, panel.label_row(OF.lang.fill(
                "@ belongs to @ - step the key above and the pad works too",
                held, OF.lang.t(takenBy))))
        end
    end
    table.insert(rows, panel.with_help(panel.label_row(OF.lang.t(
        "Rename one from chat: /door name <old> <new name>")),
        OF.lang.t("a menu row cannot take a typed name, so chat does it")))

    table.insert(rows, panel.back_row())
    return rows
end

doorways.STEP_ACTION = "doorstep"
doorways.ARM_ACTION = "doorarm"
doorways.GONE_ACTION = "doorgone"
hook_event(HOOK_ON_MODS_LOADED, function()
    if OF.util.asks(OF.net, "register_cohost_action") then
        OF.net.register_cohost_action(doorways.STEP_ACTION, "waypoint_save",
            function(_, key, want) return doorways.set_step(tostring(key), want) end)
        OF.net.register_cohost_action(doorways.ARM_ACTION, "waypoint_save",
            function(_, x) return doorways.set_armed(x == "on") end)
        OF.net.register_cohost_action(doorways.GONE_ACTION, "waypoint_save",
            function(_, _, _, z) return doorways.remove(tostring(z or "")) end)
    end
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.doorways == nil then
        panel.PAGES.doorways = {

            title = "The doorway gun", tab = "travel", up = "waypoints",
            build = function() return doorways.build_page(panel) end,
        }
    end
end)

function doorways.build_rows(panel)
    local rows = {}
    if panel == nil or panel.row == nil or panel.header_row == nil then
        return rows
    end

    local list = doorways.list()
    local mine = doorways.may_change()
    table.insert(rows, panel.header_row(OF.lang.t("Doorways")))

    local _, held = doorways.draw_key()
    local door = panel.row(OF.lang.t("The doorway gun - two openings, one walk..."),
        255, 255, 255, function() panel.go("doorways") end)
    if panel.with_right ~= nil then
        door = panel.with_right(door,
            held ~= nil and OF.lang.fill("@ draws it", held)
                or OF.lang.t("menu only"))
    end
    if panel.with_help ~= nil then
        door = panel.with_help(door, held ~= nil
            and OF.lang.fill(
                "@ draws it and puts it away - L and R are the two openings, A or B fires",
                held)
            or OF.lang.t("give it a key in here, and it aims where you look with the menu shut"))
    end
    table.insert(rows, door)

    if held ~= nil and panel.label_row ~= nil then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "On the pad: @ draws the gun, L or R picks the opening, A or B fires",
            held), 170, 190, 215))
    end

    if #list > 0 and panel.host_row ~= nil then
        local armed = doorways.armed()
        table.insert(rows, panel.with_help(panel.host_row("waypoint_save",
            panel.tick(armed, OF.lang.t("Doorways are open")),
            255, 215, 0, function()
                say(doorways.set_armed(not doorways.armed()))
            end, panel.ask_host ~= nil and panel.ask_host(doorways.ARM_ACTION,
                armed and "off" or "on") or nil),
            OF.lang.t("closed, every doorway stays placed and nothing crosses")))
    end

    if panel.host_row ~= nil then
        local pending = doorways.pending
        local text = OF.lang.t("+ Put a doorway end here")
        if pending ~= nil then
            text = OF.lang.fill("+ Finish the doorway '@' here", pending.name)
        end

        table.insert(rows, panel.with_help(panel.host_row("waypoint_save", text,
            120, 255, 120,
            function()
                say(doorways.place(doorways.pending ~= nil
                    and doorways.pending.name or doorways.suggested_name()))
            end), OF.lang.t(pending ~= nil
                and "the other end, where you stand - the two are joined from now on"
                or "one end where you stand - the next press here puts the other")))
    end

    for _, pair in ipairs(list) do
        local r, g, b = doorways.colour(pair.index)
        local name = pair.name
        local text = OF.lang.fill("Take away '@'", name)
            .. "   (" .. doorways.place_of(pair) .. ")"
        local press = function() say(doorways.remove(name)) end
        local built

        if not mine then
            built = panel.host_row("waypoint_save", text, r, g, b, press,
                panel.ask_host ~= nil and panel.ask_host(doorways.GONE_ACTION,
                    nil, nil, name) or nil)
        elseif panel.confirm_row ~= nil then
            built = panel.confirm_row("deldoor" .. name, text, r, g, b, press)
        else
            built = panel.row(text, r, g, b, press)
        end

        if panel.with_help ~= nil then
            built = panel.with_help(built,
                OF.lang.fill("rename it from chat: /door name @ <new name>",
                    name))
        end
        table.insert(rows, built)
    end

    local ownList = doorways.own_list()
    local ownAllowed = doorways.may_change_own()
    if (ownAllowed or #ownList > 0) and panel.gated_row ~= nil then
        if panel.sub_header_row ~= nil then
            table.insert(rows, panel.sub_header_row(OF.lang.t("Your own doorways")))
        end
        if panel.label_row ~= nil then
            table.insert(rows, panel.label_row(OF.lang.fill(
                "Everybody sees these and everybody walks through them - @ at a time",
                doorways.MINE_MAX), 170, 190, 215))
        end

        if doorways.survey() == "mine" then
            local half = doorways.pending
            local text = OF.lang.t("+ Put one of your own here")
            if half ~= nil and half.survey == "mine" then
                text = OF.lang.fill("+ Finish your doorway '@' here", half.name)
            end
            table.insert(rows, panel.gated_row("doorway_own", text,
                255, 235, 110, function()
                    local pending = doorways.pending
                    say(doorways.place(
                        (pending ~= nil and pending.survey == "mine")
                            and pending.name or doorways.suggested_name("mine")))
                end))
        end

        for _, pair in ipairs(ownList) do
            local r, g, b = doorways.own_colour(pair.index)
            local name = pair.name
            local text = OF.lang.fill("Take away your '@'", name)
                .. "   (" .. doorways.place_of(pair) .. ")"
            local press = function() say(doorways.remove_own(name)) end
            if panel.gated_confirm_row ~= nil then
                table.insert(rows, panel.gated_confirm_row("doorway_own",
                    "delowndoor" .. name, text, r, g, b, press))
            else
                table.insert(rows, panel.gated_row("doorway_own", text,
                    r, g, b, press))
            end
        end

        if #ownList > 1 and panel.gated_confirm_row ~= nil then
            table.insert(rows, panel.gated_confirm_row("doorway_own",
                "delownall", OF.lang.t("Take away all of your own doorways"),
                255, 160, 160, function() say(doorways.clear_own()) end))
        end
    end

    return rows
end
