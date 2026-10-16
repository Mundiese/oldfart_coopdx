OF = OF or {}

OF.ring = OF.ring or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local SIDE = 4
local CELLS = SIDE * SIDE

local DECK_LIFT = 700

local STAND_LIFT = 60

local ROW_HEIGHT = 4

local FOOT_REACH = 40

local REACH = 20000

local PLACE_GRACE = 1.0

local FIRST_HOLD = 2.5

local FALL_SHARE = 0.8

local SET_DOWN_GAP = 40

local SQUISH_REACH = 150

local PROBE_LIFT = 1500
local PROBE_LIMIT = 700
local PROBE_STEPS = 12
local PROBE_SETTLE = 3
local PROBE_PATIENCE = 90

local PROBE_LEAST = 40

local PROBE_SQUARE = 0.15

local RUN_SPEED = 32
local READ_SHARE = 1.25
local FPS = 30

local OPEN_PER_ROW = 1

local PACE_STOPS = {
    drift  = { open = 2.7, climb = 0.010 },
    even   = { open = 2.7, climb = 0.000 },
    press  = { open = 2.4, climb = 0.030 },
}
local PACE_DEFAULT = "drift"
local function pace_stop()
    local said = OF.gamemodes.option_now("pace") or "auto"
    if said == "auto" then
        said = #OF.gamemodes.participants() >= 9 and "press" or PACE_DEFAULT
    end
    return PACE_STOPS[said] or PACE_STOPS[PACE_DEFAULT]
end

local function at_load(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

local WALL_KICK = ACT_WALL_KICK_AIR or 0x03000886
local FREEFALL = ACT_FREEFALL or 0x0100088C
local SQUISHED = ACT_SQUISHED or 0x00020339

local CONTINUE = -1

local knownCell = nil
local knownTop = nil

local probe, probeAt = nil, nil
local probeFor = 0
local noBlock = false
local noRoom = false

local floorCells = {}
local rowBlocks = {}
local rowBlocksFor = 0
local builtFor = nil
local marks = {}

hook_event(HOOK_ON_LEVEL_INIT, function()
    for i in pairs(floorCells) do floorCells[i] = nil end
    marks = {}
    builtFor = nil
end)

local footing = nil

local placed = false
local rowsLived = 0

local rowHeard = {}

local function block_mesh()
    if gGlobalObjectCollisionData == nil then return nil end
    return gGlobalObjectCollisionData.metal_box_seg8_collision_08024C28
end

local function floor_frames(cell)
    if type(cell) ~= "number" or cell <= 0 then return nil end
    return math.ceil(READ_SHARE * (SIDE - 1) * math.sqrt(2) * cell / RUN_SPEED)
end

local function floor_seconds(cell)
    local frames = floor_frames(cell)
    if frames == nil then return nil end
    return frames / FPS / FALL_SHARE
end

local function rate_at(t, cell)
    t = (type(t) == "number" and t or 0) - FIRST_HOLD
    local least = floor_seconds(cell)
    if least == nil then return nil end
    local stop = pace_stop()
    local top = 1 / least
    local rate = 1 / stop.open + stop.climb * math.max(t or 0, 0)
    if rate > top then return top end
    return rate
end

local function rows_by(t, cell)
    local least = floor_seconds(cell)
    if least == nil then return 0 end
    if type(t) ~= "number" then return 0 end
    t = t - FIRST_HOLD
    if t <= 0 then return 0 end

    local stop = pace_stop()
    local rate = 1 / stop.open
    local top = 1 / least
    if rate > top then rate = top end

    if stop.climb <= 0 then return rate * t end

    local turn = (top - rate) / stop.climb
    if t <= turn then
        return rate * t + stop.climb * t * t * 0.5
    end
    return rate * turn + stop.climb * turn * turn * 0.5 + top * (t - turn)
end

local function row_now(cell)
    local fallen = rows_by(OF.gamemodes.since_start(), cell)
    local done = math.floor(fallen)
    return done + 1, fallen - done, done
end

local function gaps_at(index)
    return OPEN_PER_ROW
end

local function roll(seed)
    return (seed * 1103515245 + 12345) % 2147483648
end

local holes, holesAt, holeState = {}, nil, 0

local function hole_of(at, index)

    local seed = OF.gamemodes.round_seed()
    local key = math.floor(at.x) .. ":" .. math.floor(at.z) .. ":" .. seed
    if holesAt ~= key then
        holes, holesAt = {}, key
        holeState = (math.floor(at.x) + math.floor(at.z) * 7919 + seed * 104729)
            % 2147483648
    end
    if index < 1 then return nil end
    for row = #holes + 1, index do

        holeState = roll(holeState)
        local pick = math.floor(holeState / 65536)
        local before = holes[row - 1]
        if before == nil then
            holes[row] = (pick % CELLS) + 1
        else

            holes[row] = ((before - 1) + 1 + (pick % (CELLS - 1))) % CELLS + 1
        end
    end
    return holes[index]
end

local function open_cells(at, index)
    local open = {}
    if at == nil then return open end
    local cell = hole_of(at, index)
    if cell ~= nil then open[cell] = true end
    return open
end

local function cell_index(col, row)
    return (row - 1) * SIDE + col
end

local function corner(at, cell)
    return math.floor(at.x - SIDE * cell * 0.5),
           math.floor(at.z - SIDE * cell * 0.5)
end

local function cell_centre(at, cell, col, row)
    local left, near = corner(at, cell)
    return left + math.floor((col - 0.5) * cell),
           near + math.floor((row - 0.5) * cell)
end

local function deck_y(at)
    return at.y + DECK_LIFT
end

local function floor_origin(at)
    return deck_y(at) - (knownTop or 0)
end

local function on_the_floor(at, cell, x, z)
    local left, near = corner(at, cell)
    return x >= left and x <= left + SIDE * cell
        and z >= near and z <= near + SIDE * cell
end

local function drop(object)
    if object ~= nil and object.activeFlags ~= 0 then
        OF.util.optional("obj_mark_for_deletion", nil, object)
    end
end

local function tear_down()
    for index, block in pairs(floorCells) do
        drop(block)
        floorCells[index] = nil
    end
    for index, block in pairs(rowBlocks) do
        drop(block)
        rowBlocks[index] = nil
    end
    floorCells, rowBlocks = {}, {}
    rowBlocksFor = 0
    for key, ring in pairs(marks) do
        drop(ring)
        marks[key] = nil
    end
    marks = {}
    builtFor = nil
end

local function solid(x, y, z)
    return OF.util.optional("spawn_non_sync_object", nil,
        id_bhvStaticCheckeredPlatform, E_MODEL_METAL_BOX, x, y, z,
        function(o)
            o.oCollisionDistance = REACH

            o.oFaceAngleYaw = 0
            o.oFaceAnglePitch = 0
            o.oFaceAngleRoll = 0
        end)
end

local function shape_of(at, cell)
    if at == nil or cell == nil then return nil end
    return table.concat({ at.level or 0, at.area or 0,
        math.floor(at.x + 0.5), math.floor(at.y + 0.5),
        math.floor(at.z + 0.5), cell }, ":")
end

local function build(at, cell)
    local shape = shape_of(at, cell)
    if shape == nil then return end
    if shape == builtFor then return end
    tear_down()
    builtFor = shape

    local base = floor_origin(at)
    for row = 1, SIDE do
        for col = 1, SIDE do
            local x, z = cell_centre(at, cell, col, row)
            floorCells[cell_index(col, row)] = solid(x, base, z)
        end
    end

end

local function pool_for(count)
    if count == rowBlocksFor then return end
    for index, block in pairs(rowBlocks) do
        drop(block)
        rowBlocks[index] = nil
    end
    rowBlocks = {}
    rowBlocksFor = count
    for index = 1, count do
        rowBlocks[index] = solid(0, -20000, 0)
    end
end

local MARK_LIFT = 3

local MARK_SHARE = 0.35
local MARK_RADIUS = 120

local function ring_at(x, y, z, scale)
    return OF.slots.spawn_non_sync(
        id_bhvStaticObject, E_MODEL_WATER_RING, x, y, z,
        function(o)
            o.oOpacity = 255
            o.oFaceAngleYaw = 0
            o.oFaceAnglePitch = 0
            o.oFaceAngleRoll = 0
            OF.util.optional("obj_scale", nil, o, scale)
        end)
end

local function place_mark(key, x, y, z, scale)
    local ring = marks[key]
    if ring == nil or not OF.util.alive(ring) then
        ring = ring_at(x, y, z, scale)
        marks[key] = ring
        if ring == nil then return end
    end
    ring.oPosX, ring.oPosY, ring.oPosZ = x, y, z
    ring.oOpacity = 255
end

local function mark_gap(at, cell, open, y)
    local scale = cell * MARK_SHARE / MARK_RADIUS
    for row = 1, SIDE do
        for col = 1, SIDE do
            if open[cell_index(col, row)] then
                local x, z = cell_centre(at, cell, col, row)
                place_mark("floor", x, deck_y(at) + MARK_LIFT, z, scale)

                place_mark("row", x, y + (knownTop or cell) - cell * 0.5, z,
                    scale)
                return
            end
        end
    end
end

local function fall_of(phase)
    if phase >= FALL_SHARE then return 1.0 end
    return phase / FALL_SHARE
end

local function row_rest(at, cell)
    return floor_origin(at) + cell + SET_DOWN_GAP
end

local function row_clear(at, cell)
    local _, phase = row_now(cell)
    return SET_DOWN_GAP + ROW_HEIGHT * cell * (1 - fall_of(phase))
end

local function drive(at, cell)
    local base = floor_origin(at)
    local index, phase = row_now(cell)
    local open = open_cells(at, index)

    local blocks = CELLS - gaps_at(index)
    pool_for(blocks)

    local y = row_rest(at, cell) + ROW_HEIGHT * cell * (1 - fall_of(phase))
    local at_block = 0
    for row = 1, SIDE do
        for col = 1, SIDE do
            if not open[cell_index(col, row)] then
                at_block = at_block + 1
                local block = rowBlocks[at_block]
                if block ~= nil and OF.util.alive(block) then
                    local x, z = cell_centre(at, cell, col, row)
                    block.oPosX, block.oPosY, block.oPosZ = x, y, z

                    block.collisionData = block_mesh()
                    block.oCollisionDistance = REACH
                end
            end
        end
    end

    for _, block in pairs(floorCells) do
        if block ~= nil and OF.util.alive(block) then
            block.collisionData = block_mesh()
            block.oCollisionDistance = REACH
        end
    end

    mark_gap(at, cell, open, y)
end

local function lay_probe(at)
    if block_mesh() == nil then
        noBlock = true
        return
    end
    local ground = OF.util.optional("find_floor_height", nil,
        at.x, at.y + 100, at.z)
    if type(ground) ~= "number" then ground = at.y end
    probeAt = { x = at.x, y = ground + PROBE_LIFT, z = at.z, ground = ground }
    probeFor = 0
    probe = solid(probeAt.x, probeAt.y, probeAt.z)
    if probe == nil then noBlock = true end
end

local function measure()
    if probe == nil or probeAt == nil then return true end
    probeFor = probeFor + 1

    local mesh = block_mesh()
    if mesh ~= nil and OF.util.alive(probe) then
        probe.collisionData = mesh
        probe.oCollisionDistance = REACH
    end
    if probeFor < PROBE_SETTLE then return false end

    local from = probeAt.y + PROBE_LIMIT

    local line = probeAt.ground + PROBE_LIFT * 0.5
    local function block_here(here)
        return type(here) == "number" and here > line
    end

    local top = OF.util.optional("find_floor_height", nil,
        probeAt.x, from, probeAt.z)
    if not block_here(top) then
        if probeFor < PROBE_PATIENCE then return false end
        noBlock = true
        return true
    end

    local function reach(dx, dz)
        local near, far = 0, PROBE_LIMIT
        for _ = 1, PROBE_STEPS do
            local mid = (near + far) * 0.5
            local here = OF.util.optional("find_floor_height", nil,
                probeAt.x + dx * mid, from, probeAt.z + dz * mid)
            if block_here(here) then near = mid else far = mid end
        end
        return near
    end

    local alongX = math.min(reach(1, 0), reach(-1, 0))
    local alongZ = math.min(reach(0, 1), reach(0, -1))

    drop(probe)
    probe = nil

    if alongX < PROBE_LEAST or alongZ < PROBE_LEAST then
        noBlock = true
        return true
    end

    local wide, narrow = math.max(alongX, alongZ), math.min(alongX, alongZ)
    if wide - narrow > wide * PROBE_SQUARE then
        noBlock = true
        return true
    end

    knownCell = math.floor(narrow * 2)
    knownTop = top - probeAt.y
    return true
end

function OF.gm_booksquirm_forget()
    knownCell, knownTop = nil, nil
    holes, holesAt, holeState = {}, nil, 0
    probe, probeAt, probeFor = nil, nil, 0
end

local ROLE_OUT = "out"
local mode = {
    key = "booksquirm",
    resultsBy = "survival",
    name = "Gap Dash",
    blurb = "rows of blocks fall - stand where the shadow is not",

    how = "A floor four cells by four, high over the arena.\n"
        .. "Rows of blocks fall onto it with gaps in them.\n"
        .. "Every block throws a square shadow as it comes.\n"
        .. "Read the floor: one cell has no shadow on it.\n"
        .. "Be standing in that cell when the row sets down.\n"
        .. "The row that sets down on you crushes you: out.\n"
        .. "It then despawns, and the next row starts to fall.\n"
        .. "The floor never moves and the box never grows.\n"
        .. "Jumping works. Wall kicks and wall jumps do not.\n"
        .. "Walk off the edge and you are set back on at once.\n"
        .. "Every row leaves one cell open, never the last one.\n"
        .. "Nobody can push anybody: all sixteen fit in one cell.\n"
        .. "Your camera stays as you have it.\n"
        .. "In the original the scramble was half of it;\n"
        .. "here it is only the reading.",
    minPlayers = 2,

    maps = OF.PARTY_ARENAS,

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 120,
    saysOut = true,
    lensRole = ROLE_OUT,

    music = SEQ_LEVEL_SLIDE,

    options = {

        { key = "pace", name = "Row pace",
          help = "rows always leave time to reach a gap",
          choices = {
              { key = "auto", name = "auto",
                help = "a little faster up to eight players, much faster from nine" },
              { key = "drift", name = "speeding up",
                help = "the gaps do the work and the pace stops it dragging" },
              { key = "even", name = "steady",
                help = "nothing but the gaps closing up decides it" },
              { key = "press", name = "racing",
                help = "reaction as well as reading, and rounds end short" },
          } },
    },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, OF.ring.ROLE_IN)
    end
    if options == nil then return end
end

function mode.pin()
    OF.ring.pin()

    local at = OF.ring.at()
    if at == nil then return end

    local ceilY = OF.util.optional("find_ceil_height", nil,
        at.x, at.y + 100, at.z)
    if type(ceilY) == "number"
        and ceilY - at.y < DECK_LIFT + 400 then
        noRoom = true
    end
end

mode.leadPin = {

    keys = function() return OF.ring.PLACE_KEYS end,
    facts = function()
        local said = { noroom = noRoom and 1 or nil }

        noRoom = false
        return said
    end,
    take = function(facts)
        OF.ring.host_half()
        noRoom = facts.noroom ~= nil
    end,
    heard = function(tag)
        if tag == "noblock" then noBlock = true end
    end,
}

function mode.on_start()
    OF.ring.on_start()
    placed = false
    footing = nil
    rowsLived = 0
    rowHeard = {}
    noRoom = false
    noBlock = false
    tear_down()
end

local function stand_me_up(at, cell)
    if placed then return end
    if not OF.util.asks(OF.net, "snap_to") then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end

    local index, phase = row_now(cell)
    if phase >= FALL_SHARE then return end

    local turn = OF.gamemodes.round_seed()
    local seat = ((np.globalIndex + turn) % CELLS)

    if OF.gamemodes.since_start() >= PLACE_GRACE then
        local open = open_cells(at, index)
        local free = {}
        for cell_index_ = 1, CELLS do
            if open[cell_index_] then table.insert(free, cell_index_) end
        end
        if #free > 0 then seat = free[((np.globalIndex + turn) % #free) + 1] - 1 end
    end
    local col = (seat % SIDE) + 1
    local row = math.floor(seat / SIDE) + 1
    local x, z = cell_centre(at, cell, col, row)

    OF.net.snap_to(x, deck_y(at) + STAND_LIFT, z, 0)

    OF.util.camera_behind_soon()
    placed = true
end

local function in_the_box()
    if knownCell == nil or builtFor == nil then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if OF.ring.am_out() then return false end
    return true
end

local function no_wall_kick(m)
    if m == nil or m.playerIndex ~= 0 then return CONTINUE end
    if not in_the_box() then return CONTINUE end
    if m.vel ~= nil and (m.vel.y or 0) > 0 then m.vel.y = 0 end
    OF.util.optional("set_mario_action", nil, m, FREEFALL, 0)
    return 1
end

at_load("hook_mario_action", WALL_KICK, { every_frame = no_wall_kick })

local function remember_footing(m, at, cell)
    if m == nil or m.pos == nil then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_AIR) then return false end
    if OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING) then return false end
    local deck = deck_y(at)
    if m.pos.y > deck + FOOT_REACH then return false end
    if m.pos.y < deck - FOOT_REACH then return false end
    if not on_the_floor(at, cell, m.pos.x, m.pos.z) then return false end
    footing = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
    return true
end

local function open_spot(at, cell, index)
    local open = open_cells(at, index)
    for row = 1, SIDE do
        for col = 1, SIDE do
            if open[cell_index(col, row)] then
                local x, z = cell_centre(at, cell, col, row)
                return { x = x, y = deck_y(at), z = z }
            end
        end
    end
    return nil
end

local HANGING = {}
for _, name in ipairs({ "ACT_LEDGE_GRAB", "ACT_LEDGE_CLIMB_SLOW_1",
    "ACT_LEDGE_CLIMB_SLOW_2", "ACT_LEDGE_CLIMB_DOWN", "ACT_LEDGE_CLIMB_FAST",
    "ACT_HANGING", "ACT_HANG_MOVING", "ACT_START_HANGING" }) do
    if type(_G[name]) == "number" then HANGING[_G[name]] = true end
end
OF.gm_booksquirm_hanging = HANGING

local function put_me_back(m, back)
    if m == nil or m.pos == nil or back == nil then return false end

    if HANGING[m.action or 0] then
        OF.util.optional("set_mario_action", nil, m, ACT_FREEFALL, 0)
    end
    m.pos.x, m.pos.y, m.pos.z = back.x, back.y, back.z
    if m.vel ~= nil then m.vel.x, m.vel.y, m.vel.z = 0, 0, 0 end
    m.forwardVel = 0
    m.peakHeight = back.y
    local obj = m.marioObj
    if obj ~= nil then
        obj.oPosX, obj.oPosY, obj.oPosZ = back.x, back.y, back.z
        obj.oVelX, obj.oVelY, obj.oVelZ = 0, 0, 0
        if obj.header ~= nil and obj.header.gfx ~= nil
            and obj.header.gfx.pos ~= nil then
            obj.header.gfx.pos.x = back.x
            obj.header.gfx.pos.y = back.y
            obj.header.gfx.pos.z = back.z
        end
        OF.util.skip_interpolation(obj)
    end
    return true
end

local function keep_me_on(m, at, cell)
    if m == nil or m.pos == nil then return false end

    if HANGING[m.action or 0] then
        return put_me_back(m, footing or open_spot(at, cell, row_now(cell)))
    end
    if on_the_floor(at, cell, m.pos.x, m.pos.z)
        and m.pos.y >= deck_y(at) - FOOT_REACH then
        remember_footing(m, at, cell)
        return false
    end

    return put_me_back(m, footing or open_spot(at, cell, row_now(cell)))
end

function mode.before_mario_update(m)
    local at = OF.ring.at()
    if at == nil then return end

    local np = gNetworkPlayers[0]
    local here = np ~= nil and np.currLevelNum == at.level and np.currAreaIndex == at.area
    if knownCell == nil and here then
        if probe == nil and probeAt == nil then
            lay_probe(at)
        else
            measure()
        end
        if noBlock and not OF.util.is_host() and OF.gamemodes.asks_the_room() then
            noBlock = false
            OF.gamemodes.lead_tell("noblock")
        end
    end

    if knownCell ~= nil and here and OF.util.round_screen() then build(at, knownCell) end

    if OF.ring.am_out() then
        OF.ring.watch_frame(m)
        return
    end

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE and knownCell ~= nil then
        stand_me_up(at, knownCell)
    end
end

local function hear_row(index, phase)
    if phase > 0 and not rowHeard["f" .. index] then
        rowHeard["f" .. index] = true
        if not OF.ring.am_out() and OF.util.can_play(0) then
            OF.gamemodes.cue("hazard", nil, "bkrow")
        end
    end
    if phase >= FALL_SHARE and not rowHeard["d" .. index] then
        rowHeard["d" .. index] = true
        OF.gamemodes.round_sound_throttled("bkland", 10, SOUND_OBJ_THWOMP, nil)
    end
end

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if not OF.util.round_screen() then
        tear_down()
        return
    end
    local at = OF.ring.at()
    if at == nil or knownCell == nil then return end
    drive(at, knownCell)
    hear_row(row_now(knownCell))
end

function mode.update()
    if OF.ring.am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    local at = OF.ring.at()
    if at == nil or knownCell == nil then return end

    local m = gMarioStates[0]
    if m ~= nil then
        if (m.health or 0) < 0x880 then m.health = 0x880 end
        m.hurtCounter = 0
        if m.pos ~= nil then m.peakHeight = m.pos.y end
    end

    if m == nil or m.pos == nil then return end
    if not placed then return end

    keep_me_on(m, at, knownCell)

    if OF.gamemodes.since_start() < PLACE_GRACE then

        m.squishTimer = 0
        return
    end

    if m.action == SQUISHED or (m.squishTimer or 0) ~= 0 then
        OF.ring.go_out("The row set down on you")
        return
    end

    local index, phase = row_now(knownCell)
    if phase < FALL_SHARE and index - 1 > rowsLived then
        rowsLived = index - 1
        OF.util.publish_row(0, "ofScore", rowsLived)
    end
end

function mode.host_update()

    if noRoom then
        noRoom = false
        OF.gamemodes.abandon("There is no air over this floor for a box.")
        return
    end
    if noBlock then
        noBlock = false
        OF.gamemodes.abandon("This build has no metal block to measure.")
        return
    end

    local ending, last = OF.ring.verdict()
    if ending == OF.ring.LAST_ONE then
        OF.gamemodes.finish("@ won.",
            last.np.name, last.np.name)
    elseif ending == OF.ring.NOBODY_PUSHABLE then
        OF.gamemodes.abandon("Nobody left in the box.")
    elseif ending == OF.ring.RING_EMPTY then
        OF.gamemodes.finish("The last row took everybody.")
    end
end

function mode.on_timeout()

    local best, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(OF.ring.ROLE_IN),
        function(entry)
            local row = gPlayerSyncTable[entry.localIndex]
            if row == nil or type(row.ofScore) ~= "number" then return nil end
            return row.ofScore
        end,
        false)

    if best == nil then
        OF.gamemodes.finish("Time - nobody read a single row.")
    elseif #names > 1 then

        OF.gamemodes.finish(#names == 1 and "Time - 1 player won." or "Time - @ players won.",
            { names = names }, tostring(#names))
    else
        OF.gamemodes.finish("@ won - the most rows read.", names[1], names[1])
    end
end

function mode.cleanup()
    tear_down()
    drop(probe)
    probe, probeAt, probeFor = nil, nil, 0
    placed = false
    footing = nil
    rowsLived = 0
    rowHeard = {}
    OF.ring.let_go()
end

function mode.out_cause() return OF.ring.cause and OF.ring.cause() or nil end

function mode.terms()
    return OF.lang.fill("@ of @ cells open on every row",
        tostring(OPEN_PER_ROW), tostring(CELLS))
end

function mode.cell_pitch()
    return knownCell
end

function mode.deck_top()
    local at = OF.ring.at()
    if at == nil then return nil end
    return deck_y(at)
end

function mode.fall_frames(seconds)
    local gap = mode.row_gap(seconds)
    if gap == nil then return nil end
    return gap * FALL_SHARE
end

function mode.least_frames()
    return floor_frames(knownCell)
end

function mode.row_beat(seconds)
    if knownCell == nil then return nil end
    local fallen = rows_by(seconds, knownCell)
    local done = math.floor(fallen)
    local phase = fallen - done
    return done + 1, phase, phase >= FALL_SHARE
end

function mode.row_clear_at(seconds)
    local at = OF.ring.at()
    if at == nil or knownCell == nil then return nil end
    local fallen = rows_by(seconds, knownCell)
    local phase = fallen - math.floor(fallen)
    return SET_DOWN_GAP + ROW_HEIGHT * knownCell * (1 - fall_of(phase))
end

function mode.first_hold()
    return FIRST_HOLD
end

function mode.squish_reach()
    return SQUISH_REACH
end

function mode.set_down_gap()
    return SET_DOWN_GAP
end

function mode.row_underside()
    local at = OF.ring.at()
    if at == nil or knownCell == nil then return nil end
    return row_rest(at, knownCell) + (knownTop or 0) - knownCell
end

function mode.wall_kick_action()
    return WALL_KICK
end

function mode.refuse_wall_kick(m)
    return no_wall_kick(m)
end

function mode.row_at(seconds)
    if knownCell == nil then return nil end
    local fallen = rows_by(seconds, knownCell)
    local done = math.floor(fallen)
    return done + 1, fallen - done
end

function mode.gaps_for(index)
    return gaps_at(index)
end

function mode.row_gap(seconds)
    local rate = rate_at(seconds, knownCell)
    if rate == nil or rate <= 0 then return nil end
    return FPS / rate
end

function mode.open_for(index)
    local at = OF.ring.at()
    if at == nil then return nil end
    return open_cells(at, index)
end

function mode.cell_spot(col, row)
    local at = OF.ring.at()
    if at == nil or knownCell == nil then return nil end
    if col < 1 or col > SIDE or row < 1 or row > SIDE then return nil end
    local x, z = cell_centre(at, knownCell, col, row)
    return x, deck_y(at), z
end

function mode.footing()
    if footing == nil then return nil end
    return footing.x, footing.y, footing.z
end

function mode.foot_reach()
    return FOOT_REACH
end

function mode.floor_shape()
    return SIDE, CELLS, knownCell
end

function mode.gap_marks()
    return marks.floor, marks.row
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    if OF.ring.am_out() then
        OF.gamemodes.out_banner()
        return
    end

    if not OF.util.asks(OF.hud, "state_line") then return end
    if knownCell == nil then
        OF.hud.state_line("box", OF.lang.t("Waiting"), { prio = 20, tone = "mute" })
        return
    end
    OF.hud.state_line("row", OF.lang.t("Row"), { prio = 20, figure = row_now(knownCell) })
end

local HIDDEN = GRAPH_RENDER_INVISIBLE or 0x10

function mode.vanished(localIndex)
    if localIndex == nil or localIndex == 0 then return false end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= mode.key then return false end
    local state = OF.gamemodes.state()
    if state ~= OF.gamemodes.ACTIVE and state ~= OF.gamemodes.MOMENT
        and state ~= OF.gamemodes.RESULTS then
        return false
    end
    return OF.gamemodes.role(localIndex) == ROLE_OUT
end

function mode.hide_the_crushed(m)
    if m == nil or not mode.vanished(m.playerIndex) then return false end
    local obj = m.marioObj
    if obj == nil or obj.header == nil or obj.header.gfx == nil
        or obj.header.gfx.node == nil then
        return false
    end
    local node = obj.header.gfx.node
    node.flags = OF.util.add_flag(node.flags or 0, HIDDEN)
    return true
end

hook_event(HOOK_MARIO_UPDATE, mode.hide_the_crushed)

OF.gamemodes.register(mode)
