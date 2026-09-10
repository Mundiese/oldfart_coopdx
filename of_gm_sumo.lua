OF = OF or {}

local AT_KEY    = "ofSumoAt"
local LEVEL_KEY = "ofSumoLevel"
local AREA_KEY  = "ofSumoArea"
local RING_KEY  = "ofSumoR"
local TARGET_KEY = "ofSumoTarget"
local ROLE_IN = "in"
local ROLE_OUT = "out"
local START_RADIUS = 1100
local FLOOR_RADIUS = 300
local SHRINK_EVERY = 30

local SHRINK_SCALE = 275
local SHRINK_LEAST = 4

local KNOCK_SHARE = 0.125

local OUT_WINDOWS = {
    three = 3 * 30, four = 4 * 30, six = 6 * 30, eight = 8 * 30, two = 2 * 30,
}

local function out_window()
    return OUT_WINDOWS[OF.gamemodes.option_now("window") or "three"]
        or (3 * 30)
end

local CLOCK_NAME = "sumoback"
local CLOCK_FPS = 30

local sinceShrink = 0

local seated = false

local knockedSeen = 0

local function pack_point(pos)
    if pos == nil then return "" end
    return string.format("%.0f %.0f %.0f", pos.x, pos.y, pos.z)
end

local function ring()
    local text = gGlobalSyncTable[AT_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    local x, y, z = text:match("^(%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if x == nil or y == nil or z == nil then return nil end
    return {
        x = x, y = y, z = z,
        level = gGlobalSyncTable[LEVEL_KEY],
        area = gGlobalSyncTable[AREA_KEY],
    }
end

local function radius()
    local value = gGlobalSyncTable[RING_KEY]
    if type(value) ~= "number" or value <= 0 then return START_RADIUS end
    return value
end

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function still_in()
    return OF.gamemodes.with_role(ROLE_IN)
end

local function pushable()
    local list = {}
    for _, entry in ipairs(still_in()) do
        if OF.gamemodes.in_contention(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function seconds_back(localIndex)
    local frames = OF.util.row_ticks(localIndex, CLOCK_NAME)
    if frames == nil then return nil end
    return math.ceil(frames / CLOCK_FPS)
end

local function most_urgent()
    local who, least = nil, nil
    for _, entry in ipairs(still_in()) do
        if entry.localIndex ~= 0 then
            local left = seconds_back(entry.localIndex)
            if left ~= nil and (least == nil or left < least
                or (left == least and entry.np.name < who.np.name)) then
                who, least = entry, left
            end
        end
    end
    if who == nil then return nil end
    return who, least
end

local function clock_frame()

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE
        or OF.gamemodes.role(0) ~= ROLE_IN
        or not OF.util.can_play(0) then
        OF.util.tick_row(CLOCK_NAME, nil)
        return
    end

    local at = ring()
    if at == nil then
        OF.util.tick_row(CLOCK_NAME, nil)
        return
    end

    local distance = OF.gamemodes.distance_to_place(at)
    if distance ~= nil and distance <= radius() then
        OF.util.tick_row(CLOCK_NAME, nil)
        return
    end

    if OF.util.row_ticks(0, CLOCK_NAME) ~= nil then return end

    OF.util.report(OF.util.tick_row(CLOCK_NAME, out_window() / CLOCK_FPS))
end

local function seat_rank(localIndex)
    local at = ring()

    local rank = -math.huge
    if at ~= nil then
        local distance = OF.gamemodes.distance_to_place(at, localIndex)
        if distance ~= nil then rank = radius() - distance end
    end
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        local mine = OF.teams.of(0)
        if mine ~= nil and mine ~= OF.teams.NONE
            and OF.teams.of(localIndex) == mine then
            rank = rank + radius() + 1
        end
    end
    return rank
end

local function best_seat()
    local best, bestRank, bestNear = nil, nil, nil

    for _, entry in ipairs(pushable()) do
        if entry.localIndex ~= 0 then
            local rank = seat_rank(entry.localIndex)

            local near = OF.gamemodes.distance(0, entry.localIndex) or math.huge
            if best == nil or rank > bestRank
                or (rank == bestRank and near < bestNear) then
                best, bestRank, bestNear = entry, rank, near
            end
        end
    end
    if best == nil then return nil end
    return network_global_index_from_local(best.localIndex)
end

local function watch_toggle(m)
    if not OF.util.asks(OF.spectate, "start") then return end
    if OF.util.menu_has_screen() then return end

    OF.input.poll(m)
    if not OF.input.pressed(L_JPAD) then return end

    if OF.spectate.is_active() then
        OF.spectate.stop()
        seated = false
        return
    end

    local seat = best_seat()
    if seat == nil then

        OF.util.report(false, "There is nobody left to watch.")
        return
    end
    seated = OF.spectate.start(seat) == true
end

local mode = {
    key = "sumo",
    resultsBy = "survival",
    name = "Sumo",
    blurb = "stay in the ring - it closes",

    blurbTeams = "stay in the ring - the last side with anybody inside wins",
    how = "Fists are on and the ring is drawn on the ground.\n"
        .. "Stay inside it. Knock the others out of it.\n"
        .. "It closes all round, and steps in at every knockout.\n"
        .. "Being thrown clear is survivable - get back in.\n"
        .. "Last one in the ring wins; in sides, the last side.",
    minPlayers = 2,

    maps = "arenas",

    saysOut = true,

    room = { sweep = { "cannons" }, rules = { waterheal = 1 } },
    defaultLimit = 300,
    music = SEQ_LEVEL_BOSS_KOOPA,
    teams = true,

    lensRole = ROLE_OUT,

    target = { name = "units wide at the start",
               asks = "How many units wide the ring starts",
               default = START_RADIUS,

               min = 400, max = 3200, step = 200 },
    options = {

        { key = "window", name = "How long you have to get back in",
          help = "a shove is a chance to get back rather than a verdict - "
              .. "this is how long that chance lasts",

          choices = {
              { key = "three", name = "three seconds",
                help = "a shove is a chance rather than a verdict - long "
                    .. "enough to ride the knockback out and still turn back" },
              { key = "two", name = "two seconds",
                help = "a clean shove is nearly the end of it - long enough to "
                    .. "turn and run, and no longer" },
              { key = "four", name = "four seconds",
                help = "long enough to turn round and run in from where a "
                    .. "shove leaves you" },
              { key = "six", name = "six seconds",
                help = "a fall off the arena is survivable, if the way back "
                    .. "up is short" },
              { key = "eight", name = "eight seconds",
                help = "the widest this goes - the ring is closing all the "
                    .. "while, so the way back keeps getting shorter" },
          } },
    },
}

local startRadius = START_RADIUS

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_IN)
    end
    startRadius = math.floor(tonumber(options ~= nil and options.target) or START_RADIUS)

    OF.util.publish(TARGET_KEY, startRadius)

    OF.util.report(OF.rules.lend("interactions", "sumo",
        PLAYER_INTERACTIONS_PVP))
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end
    OF.util.publish(LEVEL_KEY, here.level)
    OF.util.publish(AREA_KEY, here.area)
    OF.util.publish(AT_KEY, pack_point(here))
    OF.util.publish(RING_KEY, startRadius)
    sinceShrink = 0
end

function mode.on_start()
    knockedSeen = 0
    seated = false

    OF.util.tick_row(CLOCK_NAME, nil)
end

local FULL_HEALTH = 0x880

function mode.update()
    if am_out() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end

    local m = gMarioStates[0]
    if m ~= nil then
        if (m.health or 0) < FULL_HEALTH then m.health = FULL_HEALTH end
        m.hurtCounter = 0
        if m.pos ~= nil then m.peakHeight = m.pos.y end
    end

    local left = OF.util.row_ticks(0, CLOCK_NAME)
    if left == nil or left > 0 then return end

    OF.util.tick_row(CLOCK_NAME, nil)
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.notify.show("Out of the ring", "bad", 6)
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)

    OF.notify.show("D-pad left watches the best of them - hold L to look further",
        "info", 7)
end

function mode.before_mario_update(m)

    clock_frame()
    if not am_out() then return end
    OF.gamemodes.set_ghost(true)
    watch_toggle(m)
end

function mode.host_update()

    sinceShrink = sinceShrink + 1
    if sinceShrink >= SHRINK_EVERY then
        sinceShrink = 0
        local now = radius()
        if now > FLOOR_RADIUS then

            local rate = math.floor(startRadius / SHRINK_SCALE)
            if rate < SHRINK_LEAST then rate = SHRINK_LEAST end
            OF.util.publish(RING_KEY, math.max(FLOOR_RADIUS, now - rate))
        end
    end

    local knocked = #OF.gamemodes.with_role(ROLE_OUT)
    if knocked > knockedSeen then
        local now = radius()
        local closed = now
        for _ = knockedSeen + 1, knocked do
            closed = closed - (closed - FLOOR_RADIUS) * KNOCK_SHARE
        end
        knockedSeen = knocked

        closed = math.max(FLOOR_RADIUS, math.floor(closed))
        if closed < now then OF.util.publish(RING_KEY, closed) end
    end

    if OF.teams.in_play() then
        local side = OF.teams.last_side_standing(function(localIndex)
            return OF.gamemodes.role(localIndex) == ROLE_IN
        end)
        if side ~= nil then
            OF.gamemodes.finish(OF.teams.survival_text(side),
                OF.gamemodes.team_winner(side))
        end
        return
    end

    local inside = pushable()
    if #inside == 1 and #OF.gamemodes.still_here() > 1 then
        OF.gamemodes.finish("@ is the last one in the ring.", inside[1].np.name,
            inside[1].np.name)
        return
    end

    if #inside == 0 then

        if #still_in() > 0 then
            OF.gamemodes.abandon("Nobody left in the ring to push.")
        else
            OF.gamemodes.finish("Everybody went over the edge.")
        end
    end
end

function mode.on_timeout()

    local inside = pushable()
    if #inside == 1 then
        OF.gamemodes.finish("@ held the ring.", inside[1].np.name,
            inside[1].np.name)
    elseif #inside == 0 then
        OF.gamemodes.finish("Nobody was left in the ring.")
    else

        local names = {}
        for _, entry in ipairs(inside) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish("Time - @ still in the ring.",
            { names = names }, tostring(#inside))
    end
end

function mode.terms()
    local said = gGlobalSyncTable[TARGET_KEY]
    if type(said) ~= "number" or said <= 0 then said = startRadius end

    return OF.lang.fill("the last one in a @-wide ring, and it closes",
        string.format("%.0f", said))
end

function mode.cleanup()

    if seated and OF.util.asks(OF.spectate, "stop") then
        OF.spectate.stop()
    end
    seated = false

    OF.util.tick_row(CLOCK_NAME, nil)

    OF.rules.give_back("interactions", "sumo")

    if OF.util.is_host() then
        OF.util.publish(AT_KEY, "")
        OF.util.publish(RING_KEY, 0)
        OF.util.publish(LEVEL_KEY, 0)
        OF.util.publish(AREA_KEY, 1)
        OF.util.publish(TARGET_KEY, nil)
    end
    sinceShrink = 0
    knockedSeen = 0
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local at = ring()
    local r = radius()
    local distance = at ~= nil and OF.gamemodes.distance_to_place(at) or nil

    if at ~= nil and distance ~= nil then
        local ringR, ringG, ringB = 255, 230, 120
        if distance > r then ringR, ringG, ringB = 255, 120, 120 end
        OF.util.world_ring(at, r, 48, 4, ringR, ringG, ringB, 220)
    end

    for _, entry in ipairs(still_in()) do
        if entry.localIndex ~= 0
            and seconds_back(entry.localIndex) ~= nil

            and OF.gamemodes.distance(0, entry.localIndex) ~= nil then
            local em = gMarioStates[entry.localIndex]
            if em ~= nil and em.pos ~= nil then
                OF.util.world_arrow({ x = em.pos.x, y = em.pos.y + 260,
                                      z = em.pos.z }, 200, 5, 255, 90, 90, 230)
            end
        end
    end

    if am_out() then

        local watching = OF.util.asks(OF.spectate, "is_active")
            and OF.spectate.is_active()
        OF.util.banner(OF.lang.t(watching and "Out - L / R watch somebody else"
            or "Out - D-pad left to watch"), 1.0, 255, 140, 140, 255)
        return
    end

    if distance == nil then
        OF.util.banner(OF.lang.t("You are not in the ring's area"),
            1.0, 255, 160, 160, 255)
        return
    end

    local margin = r - distance
    local text = OF.lang.fill("Ring @   -   @ in",
        string.format("%.0f", r), tostring(#still_in()))
    local red, green, blue = 255, 255, 255

    if margin < 0 then

        local left = seconds_back(0)
        if left == nil then left = math.ceil(out_window() / CLOCK_FPS) end
        text = OF.lang.fill("OUT OF THE RING - @s to get back",
            tostring(math.max(1, left)))
        red, green, blue = 255, 90, 90
    elseif margin < 200 then
        text = OF.lang.fill("On the edge - @ units   -   @ in",
            string.format("%.0f", margin), tostring(#still_in()))
        red, green, blue = 255, 200, 120
    end

    local opts = nil
    local who, least = most_urgent()
    if who ~= nil then
        opts = { under = { text = OF.lang.fill("@ is out of the ring - @s",
            OF.util.plain(who.np.name), tostring(math.max(1, least))),
            scale = 0.8 } }
    end

    OF.util.banner(text, 1.0, red, green, blue, 255, opts)
end

OF.gamemodes.register(mode)
