OF = OF or {}

OF.PARTY_ARENAS = OF.PARTY_ARENAS or {
    "bowser1", "bowser2", "bowser3", "the_plate",
}

local ROLE_UP = "up"
local ROLE_OUT = "out"
local ROLE_ACROSS = "across"
local AT_KEY = "ofGlassAt"
local LEVEL_KEY = "ofGlassLevel"
local AREA_KEY = "ofGlassArea"
local STATE_KEY = "ofGlassState"
local ROW_KEY = "ofGlassRow"
local FELL_KEY = "ofGlassFell"
local SLAB = { xLo = -255, xHi = 256, zLo = -153, zHi = 154, top = 26 }

local PANE_GEO = "of_glass_pane_geo"
local PANE_DEPTH = 360
local PANE_WIDTH = 360

local SIDE_GAP = 160

local ROW_GAP = 240

local DECK_DEPTH = 600
local DECK_WIDTH = 2 * PANE_WIDTH + SIDE_GAP

local LIFT = 900
local HEADROOM = 400

local OUT_DROP = 400

local STAND_SLACK = 30

local TOUCH_SLACK = 12

local REACH = 20000

local ROWS_STOPS = { eighteen = 18, twelve = 12, eight = 8, twentyfour = 24 }
local ROWS_DEFAULT = "auto"
local ROWS_AUTO_MIN = 4
local ROWS_AUTO_MAX = 18

local function rows_for_players(players)
    local n = math.floor(tonumber(players) or 2)
    return math.max(ROWS_AUTO_MIN, math.min(ROWS_AUTO_MAX, n + 2))
end
OF.gm_glassbridge_rows_for = rows_for_players

local function rows_of_choice(key, players)
    if key == nil or key == "auto" then return rows_for_players(players) end
    return ROWS_STOPS[key] or rows_for_players(players)
end

local GLINT_EVERY = 90
local GLINT_FRAMES = 10

local SURVEY_STEP = 300

local SET_DOWN_SPREAD = 200

local myBridge = nil
local builtFor = nil

local goneHere = {}
local stoodOn = nil
local myRow = 0

hook_event(HOOK_ON_LEVEL_INIT, function()
    myBridge = nil
    builtFor = nil
end)
local out = false

local mode_cause = nil
local frame = 0

local hostNoRoom = false
local hostKnown = 0
local hostBroken = {}

local paneModelAsked = false
local paneModel = nil

local function rows_option()
    return rows_of_choice(OF.gamemodes.option_now("rows") or ROWS_DEFAULT,
        #OF.gamemodes.still_here())
end

local function hint_on()
    return OF.gamemodes.option_is("hint", "shimmer")
end

local mode = {
    key = "glassbridge",
    resultsBy = "survival",
    name = "Glass Bridge",
    blurb = "two panes to a row, one holds - get across before the clock",
    how = "A bridge of glass, two panes to every row.\n"
        .. "One pane holds. The other shatters and drops you.\n"
        .. "A broken pane stays broken - watch who goes first.\n"
        .. "Fall and you are out. Nobody can push anybody.\n"
        .. "Be on the far end when the clock runs out.",
    minPlayers = 2,

    pinsOnPlayers = false,

    maps = OF.PARTY_ARENAS,
    saysOut = true,

    room = { sweep = { "cannons" },
             rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    defaultLimit = 240,

    target = { name = "time to cross", asks = "Time to cross",
               clock = true,
               help = "auto: a minute and ten seconds a row",
               default = 240, min = 60, max = 600, step = 30 },

    out_cause = function() return mode_cause end,
    teams = false,

    music = SEQ_LEVEL_SPOOKY,
    lensRole = ROLE_OUT,
    aims = {
        [ROLE_UP] = "Pick a pane, one row at a time, and reach the far end.",
        [ROLE_OUT] = "You fell - watch the rest cross.",
        [ROLE_ACROSS] = "You are across - watch the rest.",
    },
    options = {
        { key = "rows", name = "Bridge length",
          help = "how many rows of two panes lie between the ends",
          choices = {
              { key = "auto", name = "for the lobby",
                help = "four rows for two players, and one more for each player" },
              { key = "eighteen", name = "eighteen rows",
                help = "the bridge from the show" },
              { key = "twelve", name = "twelve rows",
                help = "a shorter crossing for a smaller lobby" },
              { key = "eight", name = "eight rows",
                help = "a quick one, over in a couple of minutes" },
              { key = "twentyfour", name = "twenty-four rows",
                help = "for a full lobby with a long clock" },
          } },
        { key = "hint", name = "Hint",
          help = "whether the pane that holds ever gives itself away",
          choices = {
              { key = "off", name = "off",
                help = "the two panes of a row look exactly alike" },
              { key = "shimmer", name = "shimmer",
                help = "the pane that holds glints now and then" },
          } },
    },
}

local function in_the_round_room(localIndex)
    local np = gNetworkPlayers[localIndex or 0]
    if np == nil then return false end
    if gGlobalSyncTable[LEVEL_KEY] ~= np.currLevelNum then return false end
    if gGlobalSyncTable[AREA_KEY] ~= np.currAreaIndex then return false end
    return true
end

local PANE_SX = PANE_DEPTH / (SLAB.xHi - SLAB.xLo)
local PANE_SZ = PANE_WIDTH / (SLAB.zHi - SLAB.zLo)
local DECK_SX = DECK_DEPTH / (SLAB.xHi - SLAB.xLo)
local DECK_SZ = DECK_WIDTH / (SLAB.zHi - SLAB.zLo)

local function bridge_length(rows)
    return 2 * DECK_DEPTH + rows * PANE_DEPTH + (rows + 1) * ROW_GAP
end

local function published_bridge()
    local packed = gGlobalSyncTable[AT_KEY]
    if type(packed) ~= "string" then return nil end
    local x, y, z, top, rows, seed = string.match(packed,
        "^(%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%d+) (%d+)$")
    if x == nil then return nil end
    rows = tonumber(rows)
    if rows < 1 or rows > 40 then return nil end
    x, z, top = tonumber(x), tonumber(z), tonumber(top)
    local startX = x - bridge_length(rows) * 0.5 + DECK_DEPTH * 0.5
    return { x = x, y = tonumber(y), z = z, top = top, rows = rows,
             seed = tonumber(seed), startX = startX,

             firstRow = startX + DECK_DEPTH * 0.5 + ROW_GAP,
             endX = startX + bridge_length(rows) - DECK_DEPTH,
             packed = packed }
end

OF.gm_glassbridge_published = published_bridge

local function bridge()
    if not in_the_round_room(0) then return nil end
    return published_bridge()
end

local function row_x(at, row)
    if row <= 0 then return at.startX end
    if row > at.rows then return at.endX end
    return at.firstRow + PANE_DEPTH * 0.5 + (row - 1) * (PANE_DEPTH + ROW_GAP)
end

local function side_z(at, side)
    local off = PANE_WIDTH * 0.5 + SIDE_GAP * 0.5
    if side == 1 then return at.z - off end
    return at.z + off
end

local function roll(seed)
    return (seed * 1103515245 + 12345) % 2147483648
end

local function safe_side(seed, row)
    local value = roll((seed + row * 7919) % 2147483648)
    value = roll(value)
    return (math.floor(value / 65536) % 2) + 1
end

local function trap_side(seed, row)
    return 3 - safe_side(seed, row)
end

OF.gm_glassbridge_safe_side = safe_side

local function published_state(rows)
    local packed = gGlobalSyncTable[STATE_KEY]
    local state = { known = 0, broken = {} }
    if type(packed) ~= "string" then return state end
    local known, bits = string.match(packed, "^(%d+) ([01]*)$")
    if known == nil then return state end
    state.known = tonumber(known)
    for row = 1, math.min(#bits, rows or #bits) do
        if bits:sub(row, row) == "1" then state.broken[row] = true end
    end
    return state
end

local function row_known(state, row)
    return row <= state.known or state.broken[row] == true
end

local function on_bridge()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_UP)) do
        if OF.util.can_play(entry.localIndex)
            and in_the_round_room(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function standing_on(at, x, z)
    local function inside(cx, cz, sx, sz)
        return x >= cx + SLAB.xLo * sx and x <= cx + SLAB.xHi * sx
           and z >= cz + SLAB.zLo * sz and z <= cz + SLAB.zHi * sz
    end
    if inside(at.startX, at.z, DECK_SX, DECK_SZ) then return 0, nil end
    if inside(at.endX, at.z, DECK_SX, DECK_SZ) then return at.rows + 1, nil end
    local row = math.floor((x - at.firstRow) / (PANE_DEPTH + ROW_GAP)) + 1
    if row < 1 or row > at.rows then return nil end
    for side = 1, 2 do
        if inside(row_x(at, row), side_z(at, side), PANE_SX, PANE_SZ) then
            return row, side
        end
    end
    return nil
end

OF.gm_glassbridge_standing_on = standing_on

local function pane_model()
    if paneModelAsked then return paneModel end
    paneModelAsked = true
    if not OF.util.optional("mod_file_exists", false,
        "actors/" .. PANE_GEO .. ".bin") then return nil end
    local id = OF.util.optional("smlua_model_util_get_id", nil, PANE_GEO)
    if type(id) ~= "number" or id == E_MODEL_ERROR_MODEL then return nil end
    paneModel = id
    return paneModel
end

function OF.gm_glassbridge_forget_model()
    paneModelAsked, paneModel = false, nil
end

local function spawn_slab(model, x, y, z, sx, sz)
    return OF.slots.spawn_non_sync(
        id_bhvStaticCheckeredPlatform, model, x, y, z, function(o)
            o.oCollisionDistance = REACH
            OF.util.optional("obj_scale_xyz", nil, o, sx, 1, sz)
        end, true)
end

local function tear_down()
    if myBridge ~= nil then
        for key, object in pairs(myBridge) do
            if OF.util.alive(object) then
                OF.util.optional("obj_mark_for_deletion", nil, object)
            end
            myBridge[key] = nil
        end
    end
    myBridge = nil
    builtFor = nil
end

local function pane_key(row, side) return row * 2 + side end

local function build(at)
    myBridge = {}
    builtFor = at.packed
    local y = at.top - SLAB.top
    local deck = E_MODEL_CHECKERBOARD_PLATFORM
    myBridge.start = spawn_slab(deck, at.startX, y, at.z, DECK_SX, DECK_SZ)
    myBridge.finish = spawn_slab(deck, at.endX, y, at.z, DECK_SX, DECK_SZ)
    local glass = pane_model() or E_MODEL_CHECKERBOARD_PLATFORM
    for row = 1, at.rows do
        for side = 1, 2 do
            if not (goneHere[row] and side == trap_side(at.seed, row)) then
                myBridge[pane_key(row, side)] = spawn_slab(glass, row_x(at, row),
                    y, side_z(at, side), PANE_SX, PANE_SZ)
            end
        end
    end
end

local function shatter(at, row)
    if goneHere[row] then return end
    goneHere[row] = true
    if myBridge == nil then return end
    local key = pane_key(row, trap_side(at.seed, row))
    local pane = myBridge[key]
    if OF.util.alive(pane) then

        OF.gamemodes.round_sound_throttled("glass", 3,
            SOUND_GENERAL_WALL_EXPLOSION, pane)
        OF.util.optional("obj_mark_for_deletion", nil, pane)
    end
    myBridge[key] = nil
end

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    frame = frame + 1

    local at = bridge()
    if at == nil or not OF.util.round_screen() then
        if builtFor ~= nil then tear_down() end
        return
    end
    if builtFor ~= at.packed then

        if builtFor ~= nil then goneHere = {} end
        tear_down()
        build(at)
    end
    local state = published_state(at.rows)
    for row = 1, at.rows do
        if state.broken[row] and not goneHere[row] then shatter(at, row) end
    end
end

local function am(role) return OF.gamemodes.role(0) == role end

local function stand_me_up(at)
    if stoodOn == at.packed then return end
    stoodOn = at.packed
    if not am(ROLE_UP) then return end

    myRow = 0
    OF.util.publish_row(0, ROW_KEY, 0)
    if not OF.util.asks(OF.net, "snap_to") then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    local seat = np.globalIndex % MAX_PLAYERS
    local across = ((seat % 4) - 1.5) * (DECK_WIDTH / 5)
    local along = (math.floor(seat / 4) - 1.5) * (DECK_DEPTH / 5)
    OF.net.snap_to(at.startX + along, at.top + 60, at.z + across, 0x4000)
    OF.util.camera_behind_soon()
end

local function set_back(at)
    if not OF.util.asks(OF.net, "snap_to") then return end

    if myRow <= 0 then
        OF.net.snap_to(at.startX, at.top + 60, at.z, 0x4000)
    else
        OF.net.snap_to(row_x(at, myRow), at.top + 60,
            side_z(at, safe_side(at.seed, myRow)), 0x4000)
    end
    OF.util.camera_behind_soon()
end

local function set_me_down(at)
    if not OF.util.asks(OF.net, "snap_to") then return end
    local np = gNetworkPlayers[0]
    local angle = 0
    if np ~= nil then angle = (np.globalIndex % MAX_PLAYERS) / MAX_PLAYERS * 2 * math.pi end
    local x = at.x + math.cos(angle) * SET_DOWN_SPREAD
    local z = at.z + math.sin(angle) * SET_DOWN_SPREAD

    local yaw = math.floor(math.atan(at.x - x, at.z - z) * 32768 / math.pi) % 65536
    OF.net.snap_to(x, at.y + 60, z, yaw)
    OF.util.camera_behind_soon()
end

local function go_out(at, broke)
    if out or not am(ROLE_UP) then return end
    out = true
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    set_me_down(at)

    mode_cause = broke and OF.lang.t("The glass broke") or OF.lang.t("Off the bridge")

end

local function arrive(at)
    OF.gamemodes.set_role(0, ROLE_ACROSS)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.gamemodes.cue("good", nil, "gbacross")

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("objective", OF.lang.t("ACROSS"), nil, { quiet = true })
    end
end

function mode.update()
    local at = bridge()
    if at == nil then
        stoodOn = nil
        return
    end
    stand_me_up(at)

    local m = gMarioStates[0]
    if m == nil or m.pos == nil or am(ROLE_OUT) then return end

    if m.pos.y < at.top - OUT_DROP then

        if am(ROLE_ACROSS) then set_me_down(at) return end
        go_out(at, goneHere[myRow + 1] == true)
        return
    end
    if not am(ROLE_UP) then return end

    local air = OF.util.has_flag(m.action, ACT_FLAG_AIR)
    local rise = m.pos.y - at.top
    local touching = (not air and math.abs(rise) <= STAND_SLACK)
        or (air and rise >= -STAND_SLACK and rise <= TOUCH_SLACK)
    if not touching then return end
    local row, side = standing_on(at, m.pos.x, m.pos.z)
    if row == nil or row == 0 then return end

    if row > myRow + 1 then
        set_back(at)

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("medal", OF.lang.t("ONE ROW AT A TIME"), nil, { tone = "bad", quiet = true })
        end
        return
    end

    if row == at.rows + 1 then
        arrive(at)
        return
    end

    if side == trap_side(at.seed, row) then
        OF.util.publish_row(0, FELL_KEY, row)
        shatter(at, row)
        return
    end

    if row > myRow then
        myRow = row
        OF.util.publish_row(0, ROW_KEY, row)

        OF.gamemodes.cue("good", nil, "gbrow")
    end
end

local function publish_state(rows)
    local bits = {}
    for row = 1, rows do bits[row] = hostBroken[row] and "1" or "0" end
    OF.util.publish(STATE_KEY, string.format("%.0f", hostKnown) .. " "
        .. table.concat(bits))
end

mode.target.auto = function(n)
    local rows = rows_of_choice(OF.gamemodes.option_now("rows") or ROWS_DEFAULT, n)
    local most = rows > ROWS_AUTO_MAX and 300 or 240
    return OF.util.clamp(60 + 10 * rows, 90, most)
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_UP)
    end
    if OF.util.asks(OF.util, "seed_random") then OF.util.seed_random() end
    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", OF.util.clamp(
            OF.gamemodes.auto_target(mode, players, { target = (options ~= nil
                and options.target) or OF.gamemodes.target_for(mode.key) }),
            mode.target.min, mode.target.max))
    end
end

local function highest_floor_under(x, z, footY, rows)
    local from = footY + LIFT
    local highest = footY
    local half = bridge_length(rows) * 0.5
    local lanes = { z, side_z({ z = z }, 1), side_z({ z = z }, 2) }
    local along = -half
    while along <= half do
        for _, lane in ipairs(lanes) do
            local here = OF.util.optional("find_floor_height", nil, x + along, from, lane)
            if type(here) == "number" and here > gLevelValues.floorLowerLimit
                and here > highest then
                highest = here
            end
        end
        along = along + SURVEY_STEP
    end
    return highest
end

function mode.pin()
    local np = gNetworkPlayers[0]
    local m = gMarioStates[0]
    if np == nil or m == nil or m.pos == nil then return end

    local sumX, sumZ, count, lowest = 0, 0, 0, nil

    for _, entry in ipairs(OF.gamemodes.landed(OF.gamemodes.participants())) do
        local other = gMarioStates[entry.localIndex]
        if other ~= nil and other.pos ~= nil then
            sumX = sumX + other.pos.x
            sumZ = sumZ + other.pos.z
            count = count + 1
            if lowest == nil or other.pos.y < lowest then lowest = other.pos.y end
        end
    end
    if count == 0 then sumX, sumZ, count, lowest = m.pos.x, m.pos.z, 1, m.pos.y end
    local x = math.floor(sumX / count + 0.5)
    local z = math.floor(sumZ / count + 0.5)

    local footY = OF.util.optional("find_floor_height", nil, x, lowest or m.pos.y, z)
    if type(footY) ~= "number" or footY <= gLevelValues.floorLowerLimit then
        footY = lowest or m.pos.y
    end
    footY = math.floor(footY + 0.5)
    local rows = rows_option()
    local highest = math.floor(highest_floor_under(x, z, footY, rows) + 0.5)
    local top = highest + LIFT

    local ceilY = OF.util.optional("find_ceil_height", nil, x, footY + 100, z)
    if type(ceilY) == "number" and ceilY < top + HEADROOM then
        hostNoRoom = true
        return
    end

    OF.util.publish(LEVEL_KEY, np.currLevelNum)
    OF.util.publish(AREA_KEY, np.currAreaIndex)
    hostKnown, hostBroken = 0, {}
    publish_state(rows)
    OF.util.publish(AT_KEY, string.format("%.0f %.0f %.0f %.0f %.0f %.0f",
        x, footY, z, top, rows, math.random(1, 1073741823)))
end

mode.leadPin = {
    keys = { LEVEL_KEY, AREA_KEY, AT_KEY, STATE_KEY },
    facts = function()
        local said = { noroom = hostNoRoom and 1 or nil }
        hostNoRoom = false
        return said
    end,
    take = function(facts)
        hostNoRoom = facts.noroom ~= nil
        hostKnown, hostBroken = 0, {}
    end,
}

function mode.on_start()
    goneHere = {}
    stoodOn = nil
    myRow = 0
    out = false
    frame = 0
    mode_cause = nil
    OF.util.publish_row(0, ROW_KEY, 0)
    OF.util.publish_row(0, FELL_KEY, 0)
end

function mode.late_join(localIndex)
    return ROLE_OUT
end

function mode.terms()
    local at = OF.gamemodes.state() ~= OF.gamemodes.OFF and published_bridge() or nil
    local rows = at ~= nil and at.rows or rows_of_choice(
        OF.gamemodes.option_showing(mode.key, "rows") or ROWS_DEFAULT,
        #OF.util.connected_players())
    return OF.lang.fill("across in time - @ rows, everybody at once", tostring(rows))
end

function mode.standing(localIndex)
    local role = OF.gamemodes.role(localIndex)
    if role == ROLE_OUT then return "OUT" end
    if role == ROLE_ACROSS then return "SAFE" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return "UP"
end

local function names_of(list)
    local names = {}
    for _, entry in ipairs(list) do
        if entry.np ~= nil and entry.np.name ~= nil then table.insert(names, entry.np.name) end
    end
    return names
end

local function crossed(prefix)
    local across = OF.gamemodes.with_role(ROLE_ACROSS)
    if #across == 0 then
        OF.gamemodes.finish(prefix .. "Nobody made it across.")
        return
    end
    local names = names_of(across)
    OF.gamemodes.finish(prefix .. "Across: @", { names = names }, tostring(#names))
end

local function merge(at)
    local changed = false
    for _, entry in ipairs(OF.gamemodes.participants()) do
        local row = gPlayerSyncTable[entry.localIndex]
        if row ~= nil then
            local stood = tonumber(row[ROW_KEY]) or 0
            if stood > hostKnown and stood <= at.rows then
                hostKnown = stood
                changed = true
            end
            local fell = tonumber(row[FELL_KEY]) or 0
            if fell >= 1 and fell <= at.rows and not hostBroken[fell] then
                hostBroken[fell] = true
                changed = true
            end
        end
    end
    if changed then publish_state(at.rows) end
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hostNoRoom then
        hostNoRoom = false
        OF.gamemodes.abandon("There is not enough air over this floor for a bridge.")
        return
    end
    local at = published_bridge()
    if at == nil then return end

    merge(at)

    if #on_bridge() == 0 then
        if #OF.gamemodes.with_role(ROLE_UP) > 0
            and #OF.gamemodes.with_role(ROLE_ACROSS) == 0 then
            OF.gamemodes.abandon(OF.gamemodes.NO_CONTEST)
        else
            crossed("")
        end
        return
    end
end

function mode.on_timeout()
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_UP)) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_OUT)
    end
    crossed("Time - ")
end

function mode.cleanup()
    tear_down()
    goneHere = {}
    OF.util.publish_row(0, ROW_KEY, 0)
    OF.util.publish_row(0, FELL_KEY, 0)
    if am(ROLE_OUT) or am(ROLE_ACROSS) then
        OF.gamemodes.set_role(0, ROLE_UP)
    end
    if OF.util.is_host() then
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
        OF.util.publish(STATE_KEY, nil)
    end
    hostNoRoom = false
    hostKnown, hostBroken = 0, {}
    stoodOn = nil
    myRow = 0
    out = false
end

local PANE_CORNERS = {
    { x = SLAB.xLo * PANE_SX, z = SLAB.zLo * PANE_SZ },
    { x = SLAB.xHi * PANE_SX, z = SLAB.zLo * PANE_SZ },
    { x = SLAB.xHi * PANE_SX, z = SLAB.zHi * PANE_SZ },
    { x = SLAB.xLo * PANE_SX, z = SLAB.zHi * PANE_SZ },
}
local paneAt = { x = 0, y = 0, z = 0 }

local function outline(at, row, side, size, r, g, b, alpha)
    paneAt.x, paneAt.y, paneAt.z = row_x(at, row), at.top + 2, side_z(at, side)
    return OF.util.world_outline(paneAt, PANE_CORNERS, size, r, g, b, alpha)
end

local function draw_glass(at, state)
    for row = 1, at.rows do
        local good = safe_side(at.seed, row)
        if row_known(state, row) then
            outline(at, row, good, 2, 200, 255, 210, 150)
        elseif hint_on() then
            local beat = (frame + row * 37) % GLINT_EVERY
            if beat < GLINT_FRAMES then
                local alpha = math.floor(90 * math.sin(math.pi * beat / GLINT_FRAMES))
                outline(at, row, good, 3, 235, 250, 255, alpha)
            end
        end
    end
end

OF.gm_glassbridge_draw_glass = draw_glass

function mode.hud()
    local at = bridge()
    if at == nil then
        OF.gamemodes.away_banner("The bridge is somewhere else")
        return
    end
    local state = published_state(at.rows)
    draw_glass(at, state)

    if am(ROLE_OUT) then
        OF.gamemodes.out_banner()
        return
    end

    if not OF.util.asks(OF.hud, "state_line") then return end
    if am(ROLE_ACROSS) then
        OF.hud.state_line("across", OF.lang.t("Across"), { prio = 50, tone = "good" })
        return
    end
    OF.hud.state_line("row", OF.lang.fill("Row @/@", tostring(myRow + 1), tostring(at.rows)),
        { prio = 20, tone = "cold" })
end

OF.gamemodes.register(mode)
