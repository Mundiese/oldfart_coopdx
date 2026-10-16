OF = OF or {}

local ROLE_PAINT = "painting"
local HALF = 1400

local TILE_STOPS = { ordinary = 220, close = 170, wide = 280 }
local TILE_DEFAULT = "ordinary"
local function tile_size()
    return TILE_STOPS[OF.gamemodes.option_now("size") or TILE_DEFAULT]
        or TILE_STOPS[TILE_DEFAULT]
end

local function grid_n(tile)
    return 2 * math.floor(HALF / tile) + 1
end

local STOREY = 700
local FLOOR_PROBE_UP = 500

local PAINT_RANGE = 4000
local PAINT_RANGE_SQ = PAINT_RANGE * PAINT_RANGE
local EMPTY_RANGE = 900
local EMPTY_RANGE_SQ = EMPTY_RANGE * EMPTY_RANGE

local FILL_UNIT = 100
local FILL_RANGE = 4000
local FILL_RANGE_SQ = FILL_RANGE * FILL_RANGE
local FILL_CAP = 289
local FILL_LIFT = 3
local FILL_GEOS = { [1] = "of_turf_red_geo", [2] = "of_turf_blue_geo" }
local FILL_TOKEN = { [1] = "turffillR", [2] = "turffillB" }

local EMPTY_LINE = 2
local PAINT_LINE = 5
local GREY = { r = 150, g = 150, b = 150 }

local RING_SIZE = 9

local LEVEL_KEY = "ofGridLevel"
local AREA_KEY  = "ofGridArea"
local AT_KEY    = "ofGridAt"
local LOST_KEY  = "ofTurfLost"
local PAINT_KEY = "ofTurfPaint"
local WIRE_CHUNK = 160
local WIRE_KEYS = { "ofTurfBoard", "ofTurfBoard2" }

local LOST_GRACE = 5 * 30

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local DIGIT_VALUE = {}
for index = 1, #DIGITS do DIGIT_VALUE[DIGITS:sub(index, index)] = index - 1 end

local function to36(value)
    value = math.max(0, math.floor(value))
    local hi = math.floor(value / 36) % 36
    local lo = value % 36
    return DIGITS:sub(hi + 1, hi + 1) .. DIGITS:sub(lo + 1, lo + 1)
end

local function from36(token)
    if type(token) ~= "string" or #token ~= 2 then return nil end
    local hi = DIGIT_VALUE[token:sub(1, 1)]
    local lo = DIGIT_VALUE[token:sub(2, 2)]
    if hi == nil or lo == nil then return nil end
    return hi * 36 + lo
end

local HEX = "0123456789abcdef"
local HEX_LETTER = {}
for at = 1, #HEX do HEX_LETTER[at] = HEX:sub(at, at) end
local wireParts = {}

local function wire_text(board, total)
    local count = 0
    for index = 0, total - 1, 2 do
        local hi = board[index] or 0
        local lo = board[index + 1] or 0
        count = count + 1
        wireParts[count] = HEX_LETTER[hi * 4 + lo + 1]
    end
    return table.concat(wireParts, "", 1, count)
end

local function wire_chunk(text, index)
    local from = (index - 1) * WIRE_CHUNK + 1
    return text:sub(from, from + WIRE_CHUNK - 1)
end
OF.gm_turf_wire = { text = wire_text, chunk = wire_chunk, width = WIRE_CHUNK, hex = HEX }
local HEX_VALUE = {}
for index = 1, #HEX do HEX_VALUE[HEX:sub(index, index)] = index - 1 end

local boardText, boardTotal, boardShared = nil, nil, nil

local function unpack_board(total)
    local text = OF.util.joined(WIRE_KEYS)
    if boardShared ~= nil and text == boardText and total == boardTotal then
        return boardShared
    end
    local board = {}
    for index = 0, total - 1 do board[index] = 0 end
    boardText, boardTotal, boardShared = text, total, board
    if type(text) ~= "string" or text == "" then return board end
    for at = 1, #text do
        local value = HEX_VALUE[text:sub(at, at)]
        if value == nil then break end
        local hiIndex = (at - 1) * 2
        local loIndex = hiIndex + 1
        if hiIndex < total then board[hiIndex] = math.floor(value / 4) end
        if loIndex < total then board[loIndex] = value % 4 end
    end
    return board
end

local function count_board(board, total)
    local red, blue = 0, 0
    for index = 0, total - 1 do
        local state = board[index]
        if state == 1 then red = red + 1
        elseif state == 2 then blue = blue + 1 end
    end
    return red, blue
end

local function tile_counts()
    local total = grid_n(tile_size())
    total = total * total
    return count_board(unpack_board(total), total)
end

local centreText, centreLevel, centreArea, centreKept = nil, nil, nil, nil

local function centre()
    local text = gGlobalSyncTable[AT_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    local level, area = gGlobalSyncTable[LEVEL_KEY], gGlobalSyncTable[AREA_KEY]
    if centreKept ~= nil and text == centreText and level == centreLevel
        and area == centreArea then
        return centreKept
    end
    local x, y, z = string.match(text,
        "^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if x == nil or y == nil or z == nil then return nil end
    centreText, centreLevel, centreArea = text, level, area
    centreKept = { x = x, y = y, z = z, level = level, area = area }
    return centreKept
end

local function cell_of(x, z, spot, tile, n)
    local half = (n - 1) / 2
    local col = math.floor((x - spot.x) / tile + 0.5) + half
    local row = math.floor((z - spot.z) / tile + 0.5) + half
    if col < 0 or col >= n or row < 0 or row >= n then return nil, nil end
    return col, row
end

local function cell_pos(spot, tile, n, col, row)
    local half = (n - 1) / 2
    return spot.x + (col - half) * tile, spot.z + (row - half) * tile
end

local recent = {}
local recentSet = {}
local wasAction = nil

local heardTurf = { idx = nil, state = nil }

local function push_recent(idx)
    if recentSet[idx] then return false end
    table.insert(recent, idx)
    recentSet[idx] = true
    if #recent > RING_SIZE then
        local dropped = table.remove(recent, 1)
        recentSet[dropped] = nil
    end
    return true
end

local function publish_recent()
    local parts = {}
    for _, idx in ipairs(recent) do parts[#parts + 1] = to36(idx) end
    OF.util.publish_row(0, PAINT_KEY, table.concat(parts))
end

local hostBoard = {}
local lostFrames = 0

local pushing = { red = false, blue = false }

local function sides_on()
    return OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
end

local tileAt = { x = 0, y = 0, z = 0 }
local tileCorners = { { x = 0, z = 0 }, { x = 0, z = 0 },
                      { x = 0, z = 0 }, { x = 0, z = 0 } }

local function draw_tile(x, y, z, size, width, colour)
    local half = size * 0.5
    local corners = tileCorners
    corners[1].x, corners[1].z = -half, -half
    corners[2].x, corners[2].z = half, -half
    corners[3].x, corners[3].z = half, half
    corners[4].x, corners[4].z = -half, half
    local at = tileAt
    at.x, at.y, at.z = x, y, z

    OF.util.world_outline(at, corners, width,
        colour.r, colour.g, colour.b, 255)
end

local function draw_grid(spot, tile, n, board, red, blue)
    local m = gMarioStates[0]
    local px = (m ~= nil and m.pos ~= nil) and m.pos.x or spot.x
    local pz = (m ~= nil and m.pos ~= nil) and m.pos.z or spot.z
    local half = (n - 1) / 2

    for row = 0, n - 1 do
        local z = spot.z + (row - half) * tile
        local dz = z - pz
        for col = 0, n - 1 do
            local x = spot.x + (col - half) * tile
            local dx = x - px
            local away = dx * dx + dz * dz
            local state = board[row * n + col] or 0

            if state == 1 or state == 2 then
                if away <= PAINT_RANGE_SQ then
                    draw_tile(x, spot.y, z, tile, PAINT_LINE,
                        state == 1 and red or blue)
                end
            elseif away <= EMPTY_RANGE_SQ then
                local under = OF.util.optional("find_floor_height", nil,
                    x, spot.y + FLOOR_PROBE_UP, z)
                if type(under) == "number"
                    and math.abs(under - spot.y) <= STOREY then
                    draw_tile(x, under, z, tile, EMPTY_LINE, GREY)
                end
            end
        end
    end
end

local fillAsked = false
local fillModels = nil

local function fill_models()
    if fillAsked then return fillModels end
    fillAsked = true
    local found = {}
    for state, geo in pairs(FILL_GEOS) do
        if not OF.util.optional("mod_file_exists", false,
            "actors/" .. geo .. ".bin") then return nil end
        local id = OF.util.optional("smlua_model_util_get_id", nil, geo)
        if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then return nil end
        found[state] = id
    end
    fillModels = found
    return fillModels
end

local fillShown = { [1] = 0, [2] = 0 }

local function hide_fills(state, from)
    for slot = from, fillShown[state] do
        OF.gamemodes.hide_token(FILL_TOKEN[state] .. slot)
    end
    fillShown[state] = math.min(fillShown[state], from - 1)
end

local function hide_all_fills()
    hide_fills(1, 1)
    hide_fills(2, 1)
end

local function place_fills()
    local used = { [1] = 0, [2] = 0 }
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return used end
    local spot = centre()
    if spot == nil or not OF.gamemodes.in_place_room(spot, 0) then return used end
    local models = fill_models()
    local m = gMarioStates[0]
    if models == nil or m == nil or m.pos == nil then return used end

    local tile = tile_size()
    local n = grid_n(tile)
    local board = unpack_board(n * n)
    local half = (n - 1) / 2
    local near = {}
    for row = 0, n - 1 do
        local z = spot.z + (row - half) * tile
        local dz = z - m.pos.z
        for col = 0, n - 1 do
            local state = board[row * n + col]
            if state == 1 or state == 2 then
                local x = spot.x + (col - half) * tile
                local dx = x - m.pos.x
                local away = dx * dx + dz * dz
                if away <= FILL_RANGE_SQ then
                    near[#near + 1] = { x = x, z = z, state = state, away = away }
                end
            end
        end
    end
    if #near > FILL_CAP then
        table.sort(near, function(a, b) return a.away < b.away end)
    end

    local scale = tile / FILL_UNIT
    for index = 1, math.min(#near, FILL_CAP) do
        local one = near[index]
        local slot = used[one.state] + 1
        local token = OF.gamemodes.show_token(FILL_TOKEN[one.state] .. slot,
            models[one.state], { x = one.x, y = spot.y + FILL_LIFT, z = one.z })
        if token ~= nil then
            used[one.state] = slot
            OF.util.optional("obj_scale", nil, token, scale)
        end
    end
    for state = 1, 2 do
        if used[state] > fillShown[state] then fillShown[state] = used[state] end
    end
    return used
end

OF.gm_turf_centre = centre

OF.gm_turf_forget_fill = function()
    fillAsked = false
    fillModels = nil
end

local mode = {
    key = "turf",
    name = "Turf",
    blurb = "walk the floor to paint it your side's colour - most tiles at the buzzer wins",

    blurbTeams = "walk the floor to paint it your side's colour - most tiles at the buzzer wins",
    aims = { [ROLE_PAINT] = "Walk the floor - every tile you cross fills in your colour." },
    how = "An empty grid is drawn in lines over the floor.\n"
        .. "Walk a square and it fills in your side's colour.\n"
        .. "Walking one of theirs repaints it.\n"
        .. "A ground pound paints a patch of squares round you.\n"
        .. "Most squares painted at the buzzer wins.",

    minPlayers = 2,
    sidesFrom = 2,

    maps = { "bowser1", "bowser2", "bowser3", "aquarium", "the_plate", "desert_cage" },

    room = { sweep = { "cannons" } },
    music = SEQ_LEVEL_BOSS_KOOPA,

    defaultLimit = 120,

    teams = "always",

    symmetric = true,
    options = {

        { key = "size", name = "Tile size",
          help = "smaller tiles make a finer board",
          choices = {
              { key = "ordinary", name = "normal",
                help = "the usual grid - about a hundred and seventy tiles" },
              { key = "close", name = "fine",
                help = "smaller squares, more of them" },
              { key = "wide", name = "coarse",
                help = "bigger squares, fewer of them" },
          } },
    },
}

function mode.terms()

    local key = OF.gamemodes.option_showing(mode.key, "size") or TILE_DEFAULT
    local word = ({ ordinary = "normal", close = "fine", wide = "coarse" })[key] or "normal"
    return OF.lang.fill("@ tiles, most at the buzzer wins", OF.lang.t(word))
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_PAINT)
    end
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end

    OF.util.publish(LEVEL_KEY, here.level)
    OF.util.publish(AREA_KEY, here.area)

    local cy = here.y
    local under = OF.util.optional("find_floor_height", nil,
        here.x, here.y + FLOOR_PROBE_UP, here.z)
    if type(under) == "number" and math.abs(under - here.y) <= STOREY then
        cy = under
    end

    OF.util.publish(AT_KEY, string.format("%.0f %.0f %.0f", here.x, cy, here.z))
end

mode.leadPin = { keys = { LEVEL_KEY, AREA_KEY, AT_KEY } }

function mode.late_join(localIndex)
    return ROLE_PAINT
end

local lostSaid = false

function mode.on_start()
    hostBoard = {}
    lostFrames = 0
    pushing = { red = false, blue = false }
    recent, recentSet, wasAction = {}, {}, nil
    heardTurf = { idx = nil, state = nil }
    if OF.util.is_host() then OF.util.publish(LOST_KEY, 0) end
    lostSaid = false

end

function mode.cleanup()
    hide_all_fills()
    hostBoard = {}
    lostFrames = 0
    pushing = { red = false, blue = false }
    recent, recentSet, wasAction = {}, {}, nil
    heardTurf = { idx = nil, state = nil }

    if OF.util.is_host() then
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(LOST_KEY, nil)
        for _, key in ipairs(WIRE_KEYS) do OF.util.publish(key, nil) end
    end
    OF.util.publish_row(0, PAINT_KEY, nil)
end

local function lost_left()
    local value = gGlobalSyncTable[LOST_KEY]
    if type(value) ~= "number" or value < 0 then return 0 end
    return math.floor(value)
end

local PAINT_GAP = 10
function mode.hear_the_lost()
    if lost_left() > 0 then return OF.gamemodes.tick_down(lost_left()) end
    return nil
end

function mode.hear_the_floor(idx, total)
    local side = OF.teams.of(0)
    local mine = side == "red" and 1 or side == "blue" and 2 or nil
    if idx == nil or mine == nil then
        heardTurf.idx, heardTurf.state = nil, nil
        return nil
    end
    local state = unpack_board(total)[idx] or 0
    local played = nil
    if heardTurf.idx == idx and heardTurf.state == mine and state ~= mine
        and state ~= 0 then
        played = OF.gamemodes.cue("bad")
    end
    heardTurf.idx, heardTurf.state = idx, state
    return played
end

function mode.update()
    mode.hear_the_lost()
    local spot = centre()
    if spot == nil then return end
    if not OF.gamemodes.in_place_room(spot, 0) then return end

    local m = gMarioStates[0]
    if m == nil or m.pos == nil or m.action == nil then return end
    if OF.util.has_flag(m.action, ACT_FLAG_AIR) then return end

    local tile = tile_size()
    local n = grid_n(tile)
    local col, row = cell_of(m.pos.x, m.pos.z, spot, tile, n)
    mode.hear_the_floor(col ~= nil and row * n + col or nil, n * n)
    if col == nil then return end

    local idx = row * n + col
    if push_recent(idx) then
        publish_recent()
        local side = OF.teams.of(0)
        local mine = side == "red" and 1 or side == "blue" and 2 or nil
        if mine ~= nil and (unpack_board(n * n)[idx] or 0) ~= mine then
            OF.gamemodes.round_sound_throttled("turfpaint", PAINT_GAP, OF.sounds.TICK)
        end
    end
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.role(0) ~= ROLE_PAINT then return end

    local landing = _G["ACT_GROUND_POUND_LAND"]
    local isLanding = landing ~= nil and m.action == landing
        and wasAction ~= landing
    wasAction = m.action
    if not isLanding then return end
    if m.pos == nil then return end

    local spot = centre()
    if spot == nil then return end
    if not OF.gamemodes.in_place_room(spot, 0) then return end

    local tile = tile_size()
    local n = grid_n(tile)
    local col, row = cell_of(m.pos.x, m.pos.z, spot, tile, n)
    if col == nil then return end

    local changed = false

    for dRow = -1, 1 do
        for dCol = -1, 1 do
            local c, r = col + dCol, row + dRow
            if c >= 0 and c < n and r >= 0 and r < n then
                local ok = dRow == 0 and dCol == 0
                if not ok then
                    local x, z = cell_pos(spot, tile, n, c, r)
                    local under = OF.util.optional("find_floor_height", nil,
                        x, m.pos.y + FLOOR_PROBE_UP, z)
                    ok = type(under) == "number"
                        and math.abs(under - m.pos.y) <= STOREY
                end
                if ok and push_recent(r * n + c) then changed = true end
            end
        end
    end
    if changed then publish_recent() end
end

function mode.host_update()
    if not sides_on() then
        lostFrames = lostFrames + 1
        OF.util.publish(LOST_KEY,
            math.max(0, math.ceil((LOST_GRACE - lostFrames) / 30)))
        if lostFrames >= LOST_GRACE then
            lostFrames = 0
            OF.util.publish(LOST_KEY, 0)
            OF.gamemodes.abandon("Turf lost its sides.")
        end
        return
    end
    if lostFrames > 0 then
        lostFrames = 0
        OF.util.publish(LOST_KEY, 0)
    end

    local spot = centre()
    if spot == nil then return end
    local tile = tile_size()
    local n = grid_n(tile)
    local total = n * n

    pushing = { red = false, blue = false }

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_PAINT)) do
        if OF.gamemodes.can_play(entry.localIndex) then
            local side = OF.teams.of(entry.localIndex)
            if side == "red" or side == "blue" then
                local row = gPlayerSyncTable[entry.localIndex]
                local text = row ~= nil and row[PAINT_KEY] or nil
                if type(text) == "string" and text ~= "" then
                    local value = side == "red" and 1 or 2
                    for at = 1, #text - 1, 2 do
                        local idx = from36(text:sub(at, at + 1))
                        if idx ~= nil and idx >= 0 and idx < total
                            and hostBoard[idx] ~= value then
                            hostBoard[idx] = value
                            pushing[side] = true
                        end
                    end
                end
            end
        end
    end

    local text = wire_text(hostBoard, total)
    for index, key in ipairs(WIRE_KEYS) do
        OF.util.publish(key, wire_chunk(text, index))
    end
end

function mode.overtime()
    if not sides_on() then return false end
    local red, blue = tile_counts()
    return red == blue
end

function mode.on_timeout()
    if not sides_on() then
        OF.gamemodes.abandon("Nobody had a side to paint for.")
        return
    end
    local red, blue = tile_counts()
    if red == blue then
        OF.gamemodes.finish("Time - a draw at @ tiles each.", nil, red)
        return
    end
    local winner = OF.teams.find(red > blue and "red" or "blue")
    OF.gamemodes.finish(OF.teams.result_text(red, blue),
        OF.gamemodes.team_winner(winner))
end

function mode.standing(localIndex)
    local side = OF.teams.of(localIndex)
    if side ~= "red" and side ~= "blue" then return nil end
    local red, blue = tile_counts()
    return string.format("%.0f", side == "red" and red or blue)
end

local function grid_spot()
    local spot = centre()
    if spot == nil then return nil end
    return { x = spot.x, y = spot.y, z = spot.z, label = "the grid" }
end

function mode.scenery()
    local used = place_fills()
    hide_fills(1, used[1] + 1)
    hide_fills(2, used[2] + 1)
end

function mode.hud()
    local spot = centre()
    if spot == nil then return end
    local tile = tile_size()
    local n = grid_n(tile)
    local total = n * n
    local board = unpack_board(total)
    local red = OF.teams.find("red")
    local blue = OF.teams.find("blue")
    if red == nil or blue == nil then return end

    if OF.gamemodes.in_place_room(spot, 0) then
        draw_grid(spot, tile, n, board, red, blue)
    end

    local left = lost_left()
    if left > 0 then
        if not lostSaid and OF.util.asks(OF.hud, "banner") then
            lostSaid = true
            OF.hud.banner("roundstate", OF.lang.t("NO SIDES LEFT"),
                OF.lang.fill("Ending in @", string.format("%.0f", left)), { hold = left * 30 })
        end
    else
        lostSaid = false
    end
end

function mode.cluster()
    local spot = centre()
    if spot == nil then return nil end
    local tile = tile_size()
    local n = grid_n(tile)
    local total = n * n
    local redCount, blueCount = count_board(unpack_board(total), total)
    return OF.gamemodes.side_cluster(function(key)
        return key == "red" and redCount or blueCount
    end, nil)
end

local gridTarget = { id = "grid", label = "Grid", tone = "target",
    priority = 60, compass = "offscreen" }
local gridList = { gridTarget }
function mode.targets(viewer)
    local _ = viewer
    local spot = grid_spot()
    if spot == nil or not OF.gamemodes.in_place_room(spot) then return nil end
    gridTarget.pos = spot
    return gridList
end

OF.gamemodes.register(mode)
