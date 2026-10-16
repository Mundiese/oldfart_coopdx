OF = OF or {}

local ROLE_CLIMBING = "climbing"
local PLACES = {
    empty = { x = 0, y = 0, z = 0 },
}

local HEADROOM = 300

local PLACE_ORDER = { "empty" }

local RADIUS = 1350
local STEP_ALONG = 495
local RISE = 180
local RUN = 3

local BOX_SCALE = 4.0

local BOX_TALL = 200

local WIDE_FROM = 9
local WIDE_OUT = 210

local LANDING_SCALE = 1.75
local LANDING_TOP = 26 * LANDING_SCALE

local STEP_REACH = 260

local STAR_REACH = 220

local STEPS = { short = 16, tall = 24, towering = 32 }

local AT_KEY = "ofOcAt"
local BIT_KEY = "ofOcBit"
local ROUND_KEYS = { "ofOcAt", "ofOcBit" }
local CHANNEL = 1

local built = {}
local builtFor = nil
local hostNoRoom = false
local placed = false
local best = 0
local done = false

hook_event(HOOK_ON_LEVEL_INIT, function()
    built, builtFor = {}, nil
end)

local function steps_for(stop)
    return STEPS[stop or "tall"] or STEPS.tall
end

local function width_for(players)
    return (players or 0) >= WIDE_FROM and 2 or 1
end

local function field()
    local at = gGlobalSyncTable[AT_KEY]
    if type(at) ~= "string" then return nil end
    local key, _, _, n, w = string.match(at, "^(%S+) (%-?%d+) (%-?%d+) (%d+) (%d+)$")
    local place = key ~= nil and PLACES[key] or nil
    if place == nil then return nil end
    local steps = tonumber(n) or STEPS.tall

    local rise = RISE
    if place.ceiling ~= nil then
        rise = math.min(RISE, math.floor((place.ceiling - HEADROOM - place.y) / math.max(steps, 1)))
    end
    return { x = place.x, y = place.y, z = place.z, n = steps, rise = rise,
             w = tonumber(w) or 1, key = at }
end

local function here_ok(localIndex)
    local at = gGlobalSyncTable[AT_KEY]
    local np = gNetworkPlayers[localIndex or 0]
    if type(at) ~= "string" or np == nil then return false end
    local _, level, area = string.match(at, "^(%S+) (%-?%d+) (%-?%d+)")
    return level ~= nil and np.currLevelNum == tonumber(level)
        and np.currAreaIndex == tonumber(area)
end

local function step_at(f, i)
    local a = i * STEP_ALONG / RADIUS
    local x, z = f.x + math.sin(a) * RADIUS, f.z + math.cos(a) * RADIUS
    local top = f.y + i * (f.rise or RISE)
    local kind
    if (i - 1) % (RUN + 1) == 0 then
        kind = "landing"
    else
        kind = "block"
    end
    return { x = x, z = z, top = top, kind = kind, a = a }
end

local function star_at(f)
    local s = step_at(f, f.n)
    return { x = s.x, y = s.top + 120, z = s.z }
end

local function step_under(f, x, y, z)
    local bestStep = 0
    for i = 1, f.n do
        local s = step_at(f, i)
        local dx, dz = x - s.x, z - s.z
        local reach = STEP_REACH * (s.kind == "landing" and LANDING_SCALE or 1)
        if dx * dx + dz * dz < reach * reach * f.w and math.abs(y - s.top) < 60 then
            bestStep = i
        end
    end
    return bestStep
end

local function spawn_local(kind, model, x, y, z, params, scale)
    local bhv = kind == "landing" and OF.spawner.STAGE or OF.spawner.ONOFF
    if bhv == nil or model == nil then return nil end
    local o = OF.slots.spawn_non_sync(bhv, model, x, y, z,
        function(obj)
            obj.oBehParams = params
            obj.oBehParams2ndByte = (params >> 16) & 0xFF
        end)
    if o ~= nil then OF.util.optional("obj_scale", nil, o, scale or 1) end
    return o
end

local function clear_world()
    for _, o in ipairs(built) do
        if o ~= nil and o.activeFlags ~= 0 then OF.util.optional("obj_mark_for_deletion", nil, o) end
    end
    built, builtFor = {}, nil
end

local function build(f)
    if builtFor == f.key then return #built end
    clear_world()
    local S = OF.spawner
    for i = 1, f.n do
        local s = step_at(f, i)
        local outX, outZ = math.sin(s.a) * WIDE_OUT, math.cos(s.a) * WIDE_OUT
        if s.kind == "landing" then
            built[#built + 1] = spawn_local("landing", E_MODEL_CHECKERBOARD_PLATFORM,
                s.x, s.top - LANDING_TOP, s.z, 0, LANDING_SCALE)
        else
            local params = CHANNEL * 16777216 + S.ONOFF_RED * 65536
            for k = 1, f.w do

                local out = k - 1
                built[#built + 1] = spawn_local(s.kind, E_MODEL_EXCLAMATION_BOX,
                    s.x + outX * out, s.top - BOX_TALL, s.z + outZ * out, params, BOX_SCALE)
            end
        end
    end
    builtFor = f.key
    return #built
end

local mode = {
    key = "onoffclimb",
    name = "Spiral to the Star",
    blurb = "a spiral of blocks up to a star - first to the top",
    how = "A spiral of blocks climbs to a star.\n"
        .. "Jump from block to block; a landing every few steps.\n"
        .. "A fall is a walk back from wherever you land.\n"
        .. "First to the star wins; at the clock, the highest.",
    aims = { [ROLE_CLIMBING] = "Climb to the star - jump from block to block." },
    minPlayers = 2,

    maps = { "empty" },
    room = { rules = { interactions = PLAYER_INTERACTIONS_NONE } },

    defaultLimit = 180,
    music = SEQ_LEVEL_SNOW,
    teams = false,
    studio = { tint = { 220, 190, 200 } },
    options = {

        { key = "height", name = "Climb height",
          help = "how many steps to the star - the clock grows with it",
          choices = {
              { key = "tall", name = "twenty-four steps", help = "six runs, six landings - 3:00" },
              { key = "short", name = "sixteen steps", help = "a quick one - 2:00" },
              { key = "towering", name = "thirty-two steps", help = "a long way to fall - 4:00" },
          } },
    },
}
mode.step_at = step_at
mode.star_at = star_at
mode.step_under = step_under
mode.steps_for = steps_for
mode.width_for = width_for
mode.build = build
mode.field = field
mode.PLACES = PLACES
mode.CHANNEL = CHANNEL
mode.SIZE = { radius = RADIUS, along = STEP_ALONG, rise = RISE, landing = LANDING_SCALE }

mode.CLOCKS = { short = 120, tall = 180, towering = 240 }
function mode.clock_for(stop)
    return mode.CLOCKS[stop or "tall"] or mode.CLOCKS.tall
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_CLIMBING)
    end

    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", mode.clock_for(OF.gamemodes.option_now("height")))
    end
end

local function place_here()
    if not OF.util.asks(OF.arena, "find") then return nil end
    local np = gNetworkPlayers[0]
    if np == nil then return nil end
    for _, placeKey in ipairs(PLACE_ORDER) do
        local place = OF.arena.find(placeKey)
        if place ~= nil and place.level ~= nil and place.level == np.currLevelNum
            and (place.area or 1) == (np.currAreaIndex or 1) then
            return placeKey
        end
    end
    return nil
end

function mode.pin()
    local key = place_here()
    if key == nil then
        hostNoRoom = true
        return
    end
    hostNoRoom = false
    local np = gNetworkPlayers[0]
    local players = #OF.gamemodes.with_role(ROLE_CLIMBING)
    OF.util.publish(AT_KEY, string.format("%s %.0f %.0f %.0f %.0f", key, np.currLevelNum,
        np.currAreaIndex, steps_for(OF.gamemodes.option_now("height")), width_for(players)))

    OF.util.publish(BIT_KEY, 0)
end

function mode.start_spot(f, globalIndex)
    local first = step_at(f, 1)
    local gi = globalIndex or 0
    local a = first.a - 0.12 - (gi % 8) * 0.07
    local dist = math.max(200, RADIUS - 600 - math.floor(gi / 8) * 160)
    return f.x + math.sin(a) * dist, f.z + math.cos(a) * dist, first
end

local function place_me(f)
    if placed then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    placed = true
    local x, z, first = mode.start_spot(f, np.globalIndex)
    local yaw = math.atan(first.x - x, first.z - z)
    OF.net.snap_to(x, f.y + 10, z, math.floor(yaw / math.pi * 32768) % 65536)
    OF.util.camera_behind_soon()
end

function mode.on_start()
    placed, best, done = false, 0, false
end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_CLIMBING)
    return ROLE_CLIMBING
end

function mode.scenery()
    local f = field()
    if OF.gamemodes.state() == OF.gamemodes.OFF or f == nil
        or not here_ok(0) or not OF.util.round_screen() then
        clear_world()
        return
    end
    build(f)
    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then place_me(f) end

    OF.gamemodes.show_token("ocstar", E_MODEL_STAR, star_at(f), 0x800)
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(0) ~= ROLE_CLIMBING or done then return end
    local f = field()
    local m = gMarioStates[0]
    if f == nil or m == nil or m.pos == nil or not here_ok(0) then return end
    local star = star_at(f)
    if (m.pos.x - star.x) ^ 2 + (m.pos.z - star.z) ^ 2 + (m.pos.y + 80 - star.y) ^ 2
        < STAR_REACH * STAR_REACH then
        done = true
        OF.util.publish_row(0, "ofScore", f.n + 1)
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
        OF.gamemodes.cue("good")

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("objective", OF.lang.t("TOP"), nil, { quiet = true })
        end
        return
    end
    local on = step_under(f, m.pos.x, m.pos.y, m.pos.z)
    if on > best then
        best = on
        OF.util.publish_row(0, "ofScore", best)
    end
end

local function points_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row.ofScore)) or 0)
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hostNoRoom then
        OF.gamemodes.abandon("Spiral to the Star is played in The Tiles.")
        return
    end
    local f = field()
    if f == nil then return end

    local first, firstAt = nil, nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_CLIMBING)) do
        if points_of(entry.localIndex) > f.n then
            local row = gPlayerSyncTable[entry.localIndex]
            local at = tonumber(row ~= nil and row.ofGmTime) or 0
            if first == nil or at < firstAt then first, firstAt = entry, at end
        end
    end
    if first ~= nil and first.np ~= nil then
        OF.gamemodes.finish("@ won - first to the star.", first.np.name, first.np.name)
    end
end

function mode.still_winnable()
    return #OF.gamemodes.with_role(ROLE_CLIMBING) >= 1
end

function mode.terms()
    return OF.lang.t("first to the star at the top")
end

function mode.on_timeout()
    local bestScore, names = OF.gamemodes.best_of(OF.gamemodes.with_role(ROLE_CLIMBING),
        function(entry) return points_of(entry.localIndex) end)
    if bestScore == nil or bestScore <= 0 then
        OF.gamemodes.finish("Nobody got off the floor.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("Time - a draw at step @.", tostring(bestScore)))
    else
        OF.gamemodes.finish("@ won - the highest climb.", names[1], names[1])
    end
end

function mode.hud()
    local f = field()
    if f == nil then return end
    if not here_ok(0) then
        OF.gamemodes.away_banner("The climb is somewhere else")
        return
    end

    if OF.gamemodes.role(0) == ROLE_CLIMBING and OF.util.asks(OF.hud, "state_line") then
        OF.hud.state_line("step", OF.lang.fill("Step @/@", tostring(math.min(best, f.n)),
            tostring(f.n)), { prio = 20, tone = "cold" })
    end
    local board = OF.gamemodes.score_board(ROLE_CLIMBING, points_of,
        function(score) return score > f.n and OF.lang.t("top") or tostring(score) end)

    if OF.util.asks(OF.gamemodes, "board_cap") then
        board = OF.gamemodes.board_cap(board, OF.gamemodes.SIDE_BOARD_ROWS or 4)
    end
    OF.util.board(djui_hud_get_screen_width() * 0.03,
        djui_hud_get_screen_height() * 0.24, OF.lang.t("Steps"), board,
        { width = 180, column = 120 })
end

function mode.cleanup()
    clear_world()
    if OF.util.is_host() then
        for _, key in ipairs(ROUND_KEYS) do OF.util.publish(key, nil) end
    end
    hostNoRoom, placed, best, done = false, false, 0, false
    return true
end

OF.gamemodes.register(mode)
