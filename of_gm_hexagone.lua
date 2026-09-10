OF = OF or {}

local ROLE_ON = "on"
local ROLE_OUT = "out"
local AT_KEY = "ofHexAt"
local LEVEL_KEY = "ofHexLevel"
local AREA_KEY = "ofHexArea"
local GONE_KEY = "ofHexGone"
local TILE_SCALE = 1.5
local TILE_X = 766
local TILE_Z = 460
local TILE_TOP = 26

local REACH = 20000

local RADIUS = 3

local BASE_LIFT = 300
local LAYER_DROP = 900

local HEADROOM = 400

local OUT_BELOW = 70

local FUSE_FRAMES = 45

local FUSE_STOPS = {
    usual  = FUSE_FRAMES,
    snap   = 30,
    steady = 75,
    slow   = 120,
}
local FUSE_DEFAULT = "usual"
local function fuse_frames()
    local said = FUSE_STOPS[OF.gamemodes.option_now("fuse") or FUSE_DEFAULT]
    return said or FUSE_STOPS[FUSE_DEFAULT]
end

function OF.gm_hexagone_fuse()
    return fuse_frames()
end

local ON_BELOW = 60
local ON_ABOVE = 320

local MIN_LAYERS = 2
local MAX_LAYERS = 6
local DEFAULT_LAYERS = 4

local CELLS = {}
local CELL_OF = {}
for dz = -RADIUS, RADIUS do
    for dx = -RADIUS, RADIUS do
        if math.abs(dx) + math.abs(dz) <= RADIUS then
            table.insert(CELLS, { dx = dx, dz = dz })
            CELL_OF[dz] = CELL_OF[dz] or {}
            CELL_OF[dz][dx] = #CELLS
        end
    end
end
local CELL_COUNT = #CELLS

local ALIVE = "."
local LIT = "o"
local GONE = "x"
local hostFuse = nil
local hostGone = nil

local myTiles = nil
local builtFor = nil

local stoodOn = nil

local pulse = 0

local hostNoRoom = false

local AWAY_FRAMES = 90
local hostAway = 0

local hostLayers = nil

local mode = {
    key = "hexagone",
    resultsBy = "survival",
    name = "Last Tile",
    blurb = "the floor goes out under your feet - be the last one on it",
    how = "A stack of tile floors is built above the room.\n"
        .. "Step on a tile and its fuse starts running.\n"
        .. "Fall through the bottom layer and you are out.\n"
        .. "Arrive part way through and you watch instead.\n"
        .. "Last player still on a tile wins.",
    minPlayers = 2,

    pinsOnPlayers = true,

    maps = OF.gamemodes.TILE_ARENAS,

    saysOut = true,

    room = { sweep = { "cannons" } },
    defaultLimit = 240,
    teams = false,
    music = SEQ_EVENT_BOSS,
    target = { name = "layers",
               asks = "How many layers the floor has",
               default = DEFAULT_LAYERS,
               min = MIN_LAYERS, max = MAX_LAYERS, step = 1 },

    options = {
        { key = "fuse", name = "How long a tile lasts",
          help = "the gap between a floor you can read on the way and one you "
              .. "can only run across",
          choices = {
              { key = "usual", name = "a second and a half",
                help = "the round this mode has always played - long enough to "
                    .. "cross a tile, short enough that standing still is never "
                    .. "the answer" },
              { key = "snap", name = "one second",
                help = "a tile and a quarter at a dead run, which is as short "
                    .. "as this can go before the floor leaves under your feet" },
              { key = "steady", name = "two and a half seconds",
                help = "for a lobby meeting the stack for the first time, or a "
                    .. "tall one where the reading matters more than the running" },
              { key = "slow", name = "four seconds",
                help = "the widest this goes - a floor that outlasts a crowd, "
                    .. "so a big lobby burns it down together rather than each "
                    .. "on their own" },
          } },
    },
}

local function on_the_floor()
    return OF.gamemodes.with_role(ROLE_ON)
end

local function alive_players()
    local list = {}
    for _, entry in ipairs(on_the_floor()) do
        if OF.gamemodes.in_contention(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function grid()
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    if gGlobalSyncTable[LEVEL_KEY] ~= np.currLevelNum then return nil end
    if gGlobalSyncTable[AREA_KEY] ~= np.currAreaIndex then return nil end

    local packed = gGlobalSyncTable[AT_KEY]
    if type(packed) ~= "string" then return nil end
    local x, y, z, layers = string.match(packed,
        "^(%-?%d+) (%-?%d+) (%-?%d+) (%d+)$")
    if x == nil then return nil end
    layers = tonumber(layers)
    if layers < MIN_LAYERS or layers > MAX_LAYERS then return nil end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z),
             layers = layers, packed = packed }
end

local function layer_top(at, layer)
    return at.y + BASE_LIFT + (layer - 1) * LAYER_DROP
end

local function cell_pos(at, cell)
    local spot = CELLS[cell]
    if spot == nil then return nil end
    return at.x + spot.dx * TILE_X, at.z + spot.dz * TILE_Z
end

local function cell_at(at, x, z)
    local dx = math.floor((x - at.x) / TILE_X + 0.5)
    local dz = math.floor((z - at.z) / TILE_Z + 0.5)
    local row = CELL_OF[dz]
    if row == nil then return nil end
    return row[dx]
end

local function layer_at(at, y)
    for layer = at.layers, 1, -1 do
        local top = layer_top(at, layer)
        if y >= top - ON_BELOW and y <= top + ON_ABOVE then return layer end
    end
    return nil
end

local function layer_shown(at, y)
    local standing = layer_at(at, y)
    if standing ~= nil then return standing end
    for index = at.layers, 1, -1 do
        if layer_top(at, index) <= y then return index end
    end
    return 1
end

local function gone_rows(at)
    local rows = {}
    local text = gGlobalSyncTable[GONE_KEY]
    if type(text) ~= "string" then text = "" end
    local layer = 0
    for part in string.gmatch(text, "[^|]+") do
        layer = layer + 1
        rows[layer] = part
    end
    for index = 1, at.layers do
        if rows[index] == nil or #rows[index] ~= CELL_COUNT then
            rows[index] = string.rep(ALIVE, CELL_COUNT)
        end
    end
    return rows
end

local function is_gone(rows, layer, cell)
    local row = rows[layer]
    if row == nil then return false end
    return string.sub(row, cell, cell) == GONE
end

local function is_lit(rows, layer, cell)
    local row = rows[layer]
    if row == nil then return false end
    return string.sub(row, cell, cell) == LIT
end

local function nearest_alive(at, rows, layer, wanted)
    local wx, wz = cell_pos(at, wanted)
    if wx == nil then return nil end
    local best, bestAway = nil, nil
    for cell = 1, CELL_COUNT do
        if not is_gone(rows, layer, cell) then
            local cx, cz = cell_pos(at, cell)
            if cx ~= nil then
                local away = (cx - wx) * (cx - wx) + (cz - wz) * (cz - wz)
                if bestAway == nil or away < bestAway then
                    best, bestAway = cell, away
                end
            end
        end
    end
    return best
end

local function tiles_left(at)
    local rows = gone_rows(at)
    local count = 0
    for layer = 1, at.layers do
        for cell = 1, CELL_COUNT do
            if not is_gone(rows, layer, cell) then count = count + 1 end
        end
    end
    return count
end

local function height_wanted(layers)
    return BASE_LIFT + (layers - 1) * LAYER_DROP + TILE_TOP + HEADROOM
end

local function layers_asked()
    local want = OF.gamemodes.target_for(mode.key) or DEFAULT_LAYERS
    return OF.util.clamp(math.floor(want), MIN_LAYERS, MAX_LAYERS)
end

local function layers_now()
    local packed = gGlobalSyncTable[AT_KEY]
    if type(packed) == "string" then
        local built = tonumber(string.match(packed,
            "^%-?%d+ %-?%d+ %-?%d+ (%d+)$"))
        if built ~= nil then return built end
        local asked = tonumber(string.match(packed, "^(%d+)$"))
        if asked ~= nil then return asked end
    end
    return layers_asked()
end

local function layers_that_fit(footY, ceilY, wanted)
    local room = ceilY - footY
    for layers = (wanted or layers_asked()), MIN_LAYERS, -1 do
        if height_wanted(layers) <= room then return layers end
    end
    return 0
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_ON)
    end

    hostLayers = OF.util.clamp(math.floor(tonumber(options ~= nil
        and options.target) or OF.gamemodes.target_for(mode.key)
        or DEFAULT_LAYERS), MIN_LAYERS, MAX_LAYERS)
    OF.util.publish(AT_KEY, tostring(hostLayers))
end

local function highest_floor_under(x, z, footY)
    local from = footY + BASE_LIFT + LAYER_DROP
    local highest = footY
    local at = { x = x, z = z }
    for cell = 1, CELL_COUNT do
        local cx, cz = cell_pos(at, cell)
        if cx ~= nil then
            local found = OF.util.optional("find_floor_height", nil, cx, from, cz)
            if type(found) == "number" and found > gLevelValues.floorLowerLimit
                and found > highest then
                highest = found
            end
        end
    end
    return highest
end

function mode.pin()
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil or m.pos == nil then return end

    local sumX, sumZ, count = 0, 0, 0
    local lowest = nil
    for _, entry in ipairs(OF.gamemodes.participants()) do
        local other = gMarioStates[entry.localIndex]
        if other ~= nil and other.pos ~= nil then
            sumX = sumX + other.pos.x
            sumZ = sumZ + other.pos.z
            count = count + 1
            if lowest == nil or other.pos.y < lowest then lowest = other.pos.y end
        end
    end
    if count == 0 then
        sumX, sumZ, count, lowest = m.pos.x, m.pos.z, 1, m.pos.y
    end

    local x = math.floor(sumX / count + 0.5)
    local z = math.floor(sumZ / count + 0.5)

    local footY = OF.util.optional("find_floor_height", nil, x, lowest or m.pos.y, z)
    if type(footY) ~= "number" or footY <= gLevelValues.floorLowerLimit then
        footY = math.floor((lowest or m.pos.y) + 0.5)
    end
    footY = math.floor(footY + 0.5)

    footY = math.floor(highest_floor_under(x, z, footY) + 0.5)

    local layers = hostLayers or layers_asked()
    local ceilY = OF.util.optional("find_ceil_height", nil, x, footY + 100, z)
    if type(ceilY) == "number" then
        local fits = layers_that_fit(footY, ceilY, layers)
        if fits < MIN_LAYERS then
            hostNoRoom = true
            return
        end
        if fits < layers then
            OF.notify.send_all("Only @ layers fit in here", "warn", 6, tostring(fits))
            layers = fits
        end
    end

    hostFuse = {}
    hostGone = {}
    for layer = 1, layers do
        hostFuse[layer] = {}
        hostGone[layer] = {}
    end

    OF.util.publish(GONE_KEY, string.rep(string.rep(ALIVE, CELL_COUNT) .. "|",
        layers - 1) .. string.rep(ALIVE, CELL_COUNT))

    OF.util.publish(AT_KEY, string.format("%.0f %.0f %.0f %.0f",
        x, footY, z, layers))
    OF.util.publish(LEVEL_KEY, np.currLevelNum)
    OF.util.publish(AREA_KEY, np.currAreaIndex)
end

function mode.on_start()
    stoodOn = nil

    pulse = 0
end

function mode.late_join(localIndex)
    return ROLE_OUT
end

function mode.terms()
    local frames = FUSE_STOPS[OF.gamemodes.option_showing(mode.key, "fuse")
        or FUSE_DEFAULT] or FUSE_STOPS[FUSE_DEFAULT]
    return OF.lang.fill("the last one on a tile - @ layers, @s a tile",
        tostring(layers_now()), string.format("%.1f", frames / 30))
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end

    local at = grid()
    local np = gNetworkPlayers[localIndex]
    local m = gMarioStates[localIndex]
    if at == nil or np == nil or m == nil or m.pos == nil then return nil end
    if gGlobalSyncTable[LEVEL_KEY] ~= np.currLevelNum then return nil end
    if gGlobalSyncTable[AREA_KEY] ~= np.currAreaIndex then return nil end

    return "L" .. tostring(layer_shown(at, m.pos.y))
end

local function build(at)
    myTiles = {}
    builtFor = at.packed

    local function ready(o)
        o.oCollisionDistance = REACH
        OF.util.optional("obj_scale_xyz", nil, o, TILE_SCALE, 1, TILE_SCALE)

        o.oFaceAngleYaw = 0
        o.oFaceAnglePitch = 0
        o.oFaceAngleRoll = 0
    end

    for layer = 1, at.layers do
        myTiles[layer] = {}
        local top = layer_top(at, layer)
        for cell = 1, CELL_COUNT do
            local x, z = cell_pos(at, cell)

            myTiles[layer][cell] = OF.util.optional("spawn_non_sync_object", nil,
                id_bhvStaticCheckeredPlatform, E_MODEL_CHECKERBOARD_PLATFORM,
                x, top - TILE_TOP, z, ready)
        end
    end
end

local function tear_down()
    if myTiles ~= nil then
        for _, row in pairs(myTiles) do
            for cell, tile in pairs(row) do
                if OF.util.alive(tile) then
                    OF.util.optional("obj_mark_for_deletion", nil, tile)
                end
                row[cell] = nil
            end
        end
    end
    myTiles = nil
    builtFor = nil
end

local function follow_the_wire(at)
    if myTiles == nil then return end
    local rows = gone_rows(at)
    for layer = 1, at.layers do
        local mine = myTiles[layer]
        if mine ~= nil then
            for cell = 1, CELL_COUNT do
                local tile = mine[cell]
                if tile ~= nil and is_gone(rows, layer, cell) then
                    if OF.util.alive(tile) then
                        OF.util.optional("obj_mark_for_deletion", nil, tile)
                    end
                    mine[cell] = nil
                end
            end
        end
    end
end

local function stand_me_up(at)
    if stoodOn == at.packed then return end

    if OF.gamemodes.role(0) ~= ROLE_ON then
        stoodOn = at.packed
        return
    end
    if not OF.util.asks(OF.net, "snap_to") then
        stoodOn = at.packed
        return
    end
    local np = gNetworkPlayers[0]
    if np == nil then return end

    local slot = 1 + math.floor(np.globalIndex * CELL_COUNT / MAX_PLAYERS) % CELL_COUNT

    local rows = gone_rows(at)
    local layer, cell = nil, nil
    for index = at.layers, 1, -1 do
        cell = nearest_alive(at, rows, index, slot)
        if cell ~= nil then
            layer = index
            break
        end
    end

    if layer == nil or cell == nil then
        stoodOn = at.packed
        return
    end

    local x, z = cell_pos(at, cell)
    if x == nil then return end

    OF.net.snap_to(x, layer_top(at, layer) + 100, z, nil)
    stoodOn = at.packed
end

local CAM_ABOVE_FLOOR = 125

local function keep_camera_up()
    if gLakituState == nil or gLakituState.pos == nil then return end

    if OF.util.asks(OF.camera, "active") and OF.camera.active() then return end
    if OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active() then
        return
    end

    if gLakituState.mode == (CAMERA_MODE_NEWCAM or 0x12) then return end

    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    local floor = tonumber(m.floorHeight)
    if floor == nil then return end

    local want = floor + CAM_ABOVE_FLOOR
    if (tonumber(gLakituState.pos.y) or 0) < want then
        gLakituState.pos.y = want
    end
end

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    pulse = pulse + 1

    local at = grid()
    if at == nil then

        if builtFor ~= nil then tear_down() end
        return
    end

    if builtFor ~= at.packed then
        tear_down()
        build(at)
    end

    follow_the_wire(at)
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    local at = grid()
    if at == nil then

        stoodOn = nil
        return
    end

    stand_me_up(at)

    keep_camera_up()

    if am_out() then return end

    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    if m.pos.y < layer_top(at, 1) - OUT_BELOW then
        OF.gamemodes.set_role(0, ROLE_OUT)
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
        OF.notify.show("Through the floor. You are out.", "bad", 5)
        OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
    end
end

function mode.before_mario_update(m)
    if not am_out() then return end
    OF.gamemodes.set_ghost(true)
end

local function burn(at)
    local changed = false

    for _, entry in ipairs(alive_players()) do
        local np = gNetworkPlayers[entry.localIndex]
        local m = gMarioStates[entry.localIndex]
        if np ~= nil and m ~= nil and m.pos ~= nil
            and np.currLevelNum == gGlobalSyncTable[LEVEL_KEY]
            and np.currAreaIndex == gGlobalSyncTable[AREA_KEY] then
            local layer = layer_at(at, m.pos.y)
            local cell = layer ~= nil and cell_at(at, m.pos.x, m.pos.z) or nil
            if layer ~= nil and cell ~= nil
                and hostFuse[layer] ~= nil
                and not hostGone[layer][cell]
                and hostFuse[layer][cell] == nil then
                hostFuse[layer][cell] = fuse_frames()
                changed = true
            end
        end
    end

    for layer = 1, at.layers do
        local fuses = hostFuse[layer]
        if fuses ~= nil then
            for cell, left in pairs(fuses) do
                if left <= 1 then
                    fuses[cell] = nil
                    hostGone[layer][cell] = true
                    changed = true
                else
                    fuses[cell] = left - 1
                end
            end
        end
    end

    if not changed then return end

    local parts = {}
    for layer = 1, at.layers do
        local row = {}
        for cell = 1, CELL_COUNT do
            if hostGone[layer][cell] then
                row[cell] = GONE
            elseif hostFuse[layer][cell] ~= nil then
                row[cell] = LIT
            else
                row[cell] = ALIVE
            end
        end
        parts[layer] = table.concat(row)
    end
    OF.util.publish(GONE_KEY, table.concat(parts, "|"))
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if hostNoRoom then
        hostNoRoom = false
        OF.gamemodes.abandon("There is no room above this floor for a stack.")
        return
    end

    if hostFuse == nil then return end

    local at = grid()
    if at == nil then
        hostAway = hostAway + 1
        if hostAway >= AWAY_FRAMES then
            hostAway = 0
            OF.gamemodes.abandon(
                "The host is not in the arena - the floor cannot burn.")
        end
        return
    end
    hostAway = 0
    burn(at)

    local left = alive_players()
    if #left <= 1 and #OF.gamemodes.still_here() > 1 then
        if #left == 1 then

            OF.gamemodes.finish("@ was the last one on the floor.",
                left[1].np.name, left[1].np.name)
        elseif #on_the_floor() > 0 then

            OF.gamemodes.abandon(OF.gamemodes.NO_CONTEST)
        else
            OF.gamemodes.finish("The floor took everybody.")
        end
    end
end

function mode.on_timeout()
    local left = alive_players()
    if #left == 0 then
        OF.gamemodes.finish("The floor took everybody.")
    else

        local names = {}
        for _, entry in ipairs(left) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish("Time - @ still up.", { names = names },
            tostring(#left))
    end
end

function mode.cleanup()

    tear_down()

    if am_out() then
        OF.gamemodes.set_ghost(false)
        OF.gamemodes.set_role(0, ROLE_ON)
    end

    if OF.util.is_host() then
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
        OF.util.publish(GONE_KEY, nil)
    end

    hostFuse = nil
    hostGone = nil
    stoodOn = nil

    hostNoRoom = false

    hostAway = 0
    hostLayers = nil
    pulse = 0
end

local TILE_MIN_X = -382
local TILE_MAX_X = 384
local TILE_MIN_Z = -229
local TILE_MAX_Z = 231

local MARK_CORNERS = {
    { x = TILE_MIN_X, z = TILE_MIN_Z },
    { x = TILE_MAX_X, z = TILE_MIN_Z },
    { x = TILE_MAX_X, z = TILE_MAX_Z },
    { x = TILE_MIN_X, z = TILE_MAX_Z },
}

local MARK_NEAR = 1600

local MARK_RANGE = 3200

local MARK_BURN = { r = 255, g = 120, b = 50 }
local MARK_HERE = { r = 160, g = 220, b = 255 }
local MARK_SAFE = { r = 110, g = 255, b = 150 }

local function nearest_safe(at, rows, layer, x, z)
    local best, bestAway = nil, nil
    for cell = 1, CELL_COUNT do
        if not is_gone(rows, layer, cell) and not is_lit(rows, layer, cell) then
            local cx, cz = cell_pos(at, cell)
            if cx ~= nil then
                local away = (cx - x) * (cx - x) + (cz - z) * (cz - z)
                if bestAway == nil or away < bestAway then
                    best, bestAway = cell, away
                end
            end
        end
    end
    return best
end

local function mark_cell(at, layer, cell, colour, size, alpha, x, z)
    local cx, cz = cell_pos(at, cell)
    if cx == nil then return false end
    local away = math.sqrt((cx - x) * (cx - x) + (cz - z) * (cz - z))
    if away > MARK_RANGE then return false end
    if away > MARK_NEAR and size > 2 then size = size - 1 end
    OF.util.world_outline({ x = cx, y = layer_top(at, layer) + 6, z = cz },
        MARK_CORNERS, size, colour.r, colour.g, colour.b, alpha)
    return true
end

local function draw_board(at)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end

    local layer = layer_shown(at, m.pos.y)
    local rows = gone_rows(at)
    local x, z = m.pos.x, m.pos.z
    local mine = cell_at(at, x, z)

    local beat = 190 + math.floor(65 * (0.5 + 0.5 * math.sin(pulse * 0.16)))

    for cell = 1, CELL_COUNT do
        if is_lit(rows, layer, cell) then
            mark_cell(at, layer, cell, MARK_BURN, 5, beat, x, z)
        end
    end

    if mine ~= nil and not is_gone(rows, layer, mine) then
        mark_cell(at, layer, mine, MARK_HERE, 3, 200, x, z)
    end

    if mine == nil or not is_lit(rows, layer, mine) then return end
    local safe = nearest_safe(at, rows, layer, x, z)
    if safe == nil then return end
    mark_cell(at, layer, safe, MARK_SAFE, 5, 235, x, z)
end

local function board_line(at)
    return OF.lang.fill("@ tiles left   -   @ still up",
        tostring(tiles_left(at)), tostring(#alive_players()))
end

function mode.hud()
    local at = grid()

    if am_out() then
        OF.util.banner(OF.lang.t("Out - watch the rest"),
            1.0, 255, 140, 140, 255)

        if at ~= nil then
            OF.util.banner(board_line(at), 0.9, 200, 200, 200, 255)
        end
        return
    end

    if at == nil then
        OF.util.banner(OF.lang.t("The floor is somewhere else"),
            1.0, 200, 200, 200, 255)
        return
    end

    local m = gMarioStates[0]
    local layer = m ~= nil and m.pos ~= nil and layer_at(at, m.pos.y) or nil

    local r, g, b = 160, 220, 255
    if layer == 1 then r, g, b = 255, 150, 120 end

    OF.util.banner(board_line(at), 1.0, r, g, b, 255)

    draw_board(at)
end

OF.gamemodes.register(mode)
