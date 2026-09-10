OF = OF or {}

local ROLE_RUNNER = "the runner"
local ROLE_HUNTER = "hunting"
local RUNNER_KEY = "ofMhRunner"
local DIED_KEY = "ofMhDied"
local GOAL_X     = "ofHillX"
local GOAL_Y     = "ofHillY"
local GOAL_Z     = "ofHillZ"
local GOAL_LEVEL = "ofHillLevel"
local GOAL_AREA  = "ofHillArea"
local LIFE_STOPS = {
    three = 3,
    one   = 1,
    two   = 2,
    five  = 5,
}
local LIVES_DEFAULT = "three"
local HEAD_STOPS = {
    ten    = 10,
    five   = 5,
    twenty = 20,
    thirty = 30,
}

local HEAD_DEFAULT = "ten"
local function head_start_frames()
    local said = HEAD_STOPS[OF.gamemodes.option_now("head") or HEAD_DEFAULT]
    return (said or HEAD_STOPS[HEAD_DEFAULT]) * 30
end

local GOAL_HERE = { level = LEVEL_BITS, area = 1,
    x = 351, y = 6652, z = -6030 }

local RAMP_STOPS = {
    even  = { 1 / 3, 2 / 3 },
    late  = { 1 / 2, 3 / 4 },
    early = { 1 / 5, 2 / 5 },
}
local RAMP_DEFAULT = "even"
local HINT_MAX = 1 + #RAMP_STOPS[RAMP_DEFAULT]

local SECTORS = { 0x4000, 0x2000, 0x1000 }

local QUIET_REACH = 800

local BAND_EDGES = { 1600, 2800, 4500 }
local BAND_WORDS = { "close", "somewhere near", "a long way off",
    "right across the level" }

local NO_CLOCK_RUNG = 60

local seenSpent = 0

local wasDead = false

local seenHint = 0

local tookTheGrandStar = false

local lastHitter = nil

local function runner_global()
    local value = gGlobalSyncTable[RUNNER_KEY]
    if type(value) ~= "number" then return -1 end
    return value
end

local function runner_local()
    local target = runner_global()
    if target < 0 then return nil end
    return OF.util.local_from_global(target)
end

local function am_runner()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex == runner_global()
        and OF.gamemodes.role(0) == ROLE_RUNNER
end

local function lives_allowed()
    local said = LIFE_STOPS[OF.gamemodes.option_now("lives") or LIVES_DEFAULT]
    return said or LIFE_STOPS[LIVES_DEFAULT]
end

local function lives_spent(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local value = row ~= nil and row[DIED_KEY] or 0
    if type(value) ~= "number" or value < 0 then return 0 end
    return math.floor(value)
end

local function lives_left(localIndex)
    return math.max(0, lives_allowed() - lives_spent(localIndex))
end

function OF.gm_manhunt_lives(localIndex)
    local at = localIndex or 0
    return lives_left(at), lives_allowed(), lives_spent(at)
end

local function head_start_left()
    return math.max(0, math.floor(head_start_frames() / 30)
        - OF.gamemodes.elapsed())
end

local function goal()
    local x = gGlobalSyncTable[GOAL_X]
    if type(x) ~= "number" then return nil end
    return {
        x = x,
        y = gGlobalSyncTable[GOAL_Y] or 0,
        z = gGlobalSyncTable[GOAL_Z] or 0,
        level = gGlobalSyncTable[GOAL_LEVEL],
        area = gGlobalSyncTable[GOAL_AREA],
    }
end

local function place()
    local at = goal()
    if at == nil then return nil end
    if not OF.gamemodes.in_place_room(at) then return nil end
    at.label = "the goal"
    local gold = OF.util.gold()
    at.r, at.g, at.b = gold.r, gold.g, gold.b
    return at
end

function OF.gm_manhunt_goal()
    return OF.gamemodes.tokens["mhgoal"]
end

local function ramp_now()
    return RAMP_STOPS[OF.gamemodes.option_now("compass") or RAMP_DEFAULT]
        or RAMP_STOPS[RAMP_DEFAULT]
end

local function ramp_span()
    local limit = gGlobalSyncTable.ofGmLimit or 0
    local span = limit - math.floor(head_start_frames() / 30)
    if limit <= 0 or span <= 0 then return NO_CLOCK_RUNG * HINT_MAX end
    return span
end

local function hint_level()
    if not OF.gamemodes.is_running() then return 0 end
    if head_start_left() > 0 then return 0 end

    local since = OF.gamemodes.elapsed() - math.floor(head_start_frames() / 30)
    local ramp = ramp_now()
    local span = ramp_span()
    for rung = HINT_MAX, 2, -1 do
        local share = ramp[rung - 1]
        if share ~= nil and since >= span * share then return rung end
    end
    return 1
end

function OF.gm_manhunt_hint()
    return hint_level()
end

function OF.gm_manhunt_head()
    return math.floor(head_start_frames() / 30)
end

function OF.gm_manhunt_ramp()
    return ramp_now(), ramp_span(), HINT_MAX
end

local function seen_line(level)
    if level >= HINT_MAX then
        return OF.lang.t("THEY HAVE YOU NARROWED DOWN"), 255, 96, 96
    elseif level >= 2 then
        return OF.lang.t("They have your range as well"), 255, 170, 90
    end
    return OF.lang.t("They have a direction"), 235, 210, 120
end

local CLIMB_BAND = 150

local function climb_line(at, exact)
    local m = gMarioStates[0]
    if at == nil or m == nil or m.pos == nil then return nil end
    local up = (tonumber(at.y) or 0) - (tonumber(m.pos.y) or 0)
    if math.abs(up) < CLIMB_BAND then return OF.lang.t("level with you") end
    if not exact then
        if up > 0 then return OF.lang.t("above you") end
        return OF.lang.t("below you")
    end
    if up > 0 then
        return OF.lang.fill("@ above you", string.format("%.0f", up))
    end
    return OF.lang.fill("@ below you", string.format("%.0f", -up))
end

local function climb_sign(at)
    local m = gMarioStates[0]
    if at == nil or m == nil or m.pos == nil then return 0 end
    local up = (tonumber(at.y) or 0) - (tonumber(m.pos.y) or 0)
    if up >= CLIMB_BAND then return 1 end
    if up <= -CLIMB_BAND then return -1 end
    return 0
end

local function flat_distance_to(at)
    local m = gMarioStates[0]
    if at == nil or m == nil or m.pos == nil then return nil end
    local dx = (tonumber(at.x) or 0) - (tonumber(m.pos.x) or 0)
    local dz = (tonumber(at.z) or 0) - (tonumber(m.pos.z) or 0)
    return math.sqrt(dx * dx + dz * dz)
end

local function distance_band(distance, level)
    local step = 1
    if level < 2 then step = 2 end
    local low = 0
    for i = step, #BAND_EDGES, step do
        if (distance or 0) < BAND_EDGES[i] then
            return BAND_WORDS[i], low, BAND_EDGES[i]
        end
        low = BAND_EDGES[i]
    end
    return BAND_WORDS[#BAND_WORDS], low, nil
end

local function wrap_ticks(ticks)
    local folded = (ticks or 0) % 0x10000
    if folded >= 0x8000 then folded = folded - 0x10000 end
    return folded
end

local function sector_width(level)
    local index = math.max(1, math.min(math.floor(level or 1), #SECTORS))
    return SECTORS[index]
end

local function sector_of(ticks, level)
    local width = sector_width(level)
    local centre = math.floor(wrap_ticks(ticks) / width + 0.5) * width
    return wrap_ticks(centre), width / 2
end

function OF.gm_manhunt_sector(ticks, level)
    return sector_of(ticks, level)
end

function OF.gm_manhunt_band(distance, level)
    return distance_band(distance, level)
end

function OF.gm_manhunt_quiet()
    return QUIET_REACH
end

local function world_bearing_to(at)
    if at == nil then return nil end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end
    return OF.util.optional("atan2s", nil,
        (tonumber(at.z) or 0) - m.pos.z, (tonumber(at.x) or 0) - m.pos.x)
end

local function camera_bearing()
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end
    if gLakituState == nil or gLakituState.pos == nil then return nil end
    return OF.util.optional("atan2s", nil,
        m.pos.z - gLakituState.pos.z, m.pos.x - gLakituState.pos.x)
end

local function bearing_to(at)
    local toTarget = world_bearing_to(at)
    local toCamera = camera_bearing()
    if toTarget == nil or toCamera == nil then return nil end
    return toTarget - toCamera
end

local function draw_needle(cx, cy, radius, ticks, r, g, b, alpha, climb, spread)
    if djui_hud_render_line == nil or djui_hud_set_color == nil then
        return false
    end

    local angle = ticks * math.pi / 0x8000
    local tipX = cx + math.sin(angle) * radius
    local tipY = cy - math.cos(angle) * radius
    local dx, dy = tipX - cx, tipY - cy
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return false end

    djui_hud_set_color(OF.util.byte(r), OF.util.byte(g), OF.util.byte(b),
        OF.util.byte(alpha))
    djui_hud_render_line(cx, cy, tipX, tipY, 4)

    local barb = length * 0.35
    local ux, uy = dx / length, dy / length
    for _, turn in ipairs({ 0.6, -0.6 }) do
        local cosT, sinT = math.cos(turn), math.sin(turn)
        local bx = -ux * cosT + uy * sinT
        local by = -uy * cosT - ux * sinT
        djui_hud_render_line(tipX, tipY, tipX + bx * barb, tipY + by * barb, 4)
    end

    if spread ~= nil and spread > 0 then
        djui_hud_set_color(OF.util.byte(r), OF.util.byte(g), OF.util.byte(b),
            OF.util.byte(alpha * 0.45))
        for _, side in ipairs({ -1, 1 }) do
            local edge = angle + side * spread * math.pi / 0x8000
            djui_hud_render_line(cx, cy,
                cx + math.sin(edge) * radius * 0.82,
                cy - math.cos(edge) * radius * 0.82, 2)
        end
        djui_hud_set_color(OF.util.byte(r), OF.util.byte(g), OF.util.byte(b),
            OF.util.byte(alpha))
    end

    if climb ~= nil and climb ~= 0 then
        local markX = cx + radius * 1.15
        local markY = cy
        local reach = radius * 0.30
        local tip = markY - reach * climb
        for _, side in ipairs({ -1, 1 }) do
            djui_hud_render_line(markX, tip,
                markX + reach * 0.7 * side, tip + reach * climb, 4)
        end
    end

    djui_hud_set_rotation(0, 0, 0)
    return true
end

local mode = {
    key = "manhunt",
    name = "Manhunt",
    blurb = "one runs the whole game, everybody else hunts",

    aims = {
        ["the runner"] = "Beat the game before they stop you.",
        ["hunting"]    = "Stop the runner beating the game.",
    },

    how = "One runner has the castle and has to beat the game.\n"
        .. "The rest hunt, held still while the runner gets away.\n"
        .. "A hunter's compass sharpens on them, never to a point.\n"
        .. "The runner wins on the Grand Star at Bowser in the Sky.\n"
        .. "Take their last life, or run the clock out, to win.\n"
        .. "The runner is mortal - out of lives, they hunt too.",
    minPlayers = 2,

    maps = "own",
    wholeGame = true,

    startPlace = { level = LEVEL_CASTLE_GROUNDS, area = 1, act = 0 },

    fightsBosses = true,

    room = {},

    music = SEQ_LEVEL_BOSS_KOOPA_FINAL,

    defaultLimit = 900,

    teams = false,

    options = {
        { key = "head", name = "How long the runner gets",
          help = "the hunters cannot move for this long, and the compass "
              .. "starts counting when it ends",
          choices = {
              { key = "ten", name = "ten seconds",
                help = "the length this mode has always run - out of sight of "
                    .. "the spawn, and no further" },
              { key = "five", name = "five seconds",

                help = "an arena, where ten seconds is most of the way to "
                    .. "anywhere worth standing" },
              { key = "twenty", name = "twenty seconds",
                help = "a whole course to cross, and twenty seconds of it "
                    .. "spent before anybody may follow" },
              { key = "thirty", name = "thirty seconds",
                help = "the widest this goes - the round's clock is running "
                    .. "throughout, so the hunt itself is half a minute shorter" },
          } },
        { key = "compass", name = "How the compass sharpens",
          help = "how quickly the hunters' wedge narrows onto the runner - it "
              .. "never closes on him",
          choices = {
              { key = "even", name = "a rung every third",
                help = "the pace this mode has always kept - a quarter of the "
                    .. "rose, then an eighth, then a sixteenth" },
              { key = "late", name = "vague, then all at once",
                help = "half the round on the widest wedge, so the runner is "
                    .. "hunted by guesswork until very late" },
              { key = "early", name = "sharp early, then a chase",
                help = "the wedge halves a fifth of the way in and again "
                    .. "before halfway - short rounds, and loud ones" },
          } },

        { key = "lives", name = "How many lives the runner gets",
          help = "how many deaths it takes to run the runner out - out of "
              .. "lives they stop running and join the hunt",
          choices = {
              { key = "three", name = "three lives",
                help = "the lobby-sized number - one bad jump in Hazy Maze "
                    .. "Cave is not the whole round, and the clock still "
                    .. "decides most of them" },
              { key = "one", name = "one life",
                help = "the format this mode is named after - the runner has "
                    .. "one and the hunters have as many as they like" },
              { key = "two", name = "two lives",
                help = "one mistake forgiven and no more" },
              { key = "five", name = "five lives",
                help = "a long chase, for a lobby that would rather be caught "
                    .. "than run out of clock" },
          } },
    },

}

function mode.place()
    local at = goal()
    if at == nil then return nil end
    if not OF.gamemodes.in_place_room(at) then return nil end
    at.label = "the way out"
    local gold = OF.util.gold()
    at.r, at.g, at.b = gold.r, gold.g, gold.b
    return at
end

function OF.gm_manhunt_goal()
    return OF.gamemodes.tokens["mhgoal"]
end

function mode.terms()

    local said = LIFE_STOPS[OF.gamemodes.option_showing(mode.key, "lives")
        or LIVES_DEFAULT] or LIFE_STOPS[LIVES_DEFAULT]

    if said == 1 then
        return OF.lang.t("the Grand Star, or the runner's one life")
    end
    return OF.lang.fill("the Grand Star, or the runner's @ lives",
        tostring(said))
end

function mode.marked_player(localIndex)
    if runner_local() ~= localIndex then return nil end
    if hint_level() < HINT_MAX then return nil end
    if OF.gamemodes.role(0) ~= ROLE_HUNTER then return nil end
    return "runner", 255, 90, 90
end

function mode.marker_occluded(kind)
    if kind == "runner" then return true end
    return nil
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_RUNNER then

        return tostring(lives_left(localIndex)) .. "/"
            .. tostring(lives_allowed())
    end
    return "HUNT"
end

local function publish_goal()
    OF.util.publish(GOAL_LEVEL, GOAL_HERE.level)
    OF.util.publish(GOAL_AREA, GOAL_HERE.area)
    OF.util.publish(GOAL_X, GOAL_HERE.x)
    OF.util.publish(GOAL_Y, GOAL_HERE.y)
    OF.util.publish(GOAL_Z, GOAL_HERE.z)
end

function mode.setup(players, options)

    local it = OF.gamemodes.deal_it(players, 1, false)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex,
            it[entry.localIndex] and ROLE_RUNNER or ROLE_HUNTER)
        if it[entry.localIndex] and entry.np ~= nil then
            OF.util.publish(RUNNER_KEY, entry.np.globalIndex)
        end
    end

    publish_goal()

    OF.util.report(OF.rules.lend("interactions", "manhunt",
        PLAYER_INTERACTIONS_PVP))
end

function mode.late_join(localIndex)
    return ROLE_HUNTER
end

function mode.on_start()
    seenSpent = 0
    seenHint = 0
    wasDead = false
    lastHitter = nil

    if am_runner() then

        OF.notify.show("You are the runner - @ lives, and a game to beat",
            "warn", 6, tostring(lives_allowed()))
    else

        OF.notify.show("Held for @s - then hunt the runner down",
            "info", 6, tostring(math.floor(head_start_frames() / 30)))
    end
end

function mode.cleanup()

    OF.rules.give_back("interactions", "manhunt")

    seenSpent = 0
    seenHint = 0
    wasDead = false
    lastHitter = nil

    OF.util.publish_row(0, DIED_KEY, 0)

    if OF.util.is_host() then
        OF.util.publish(RUNNER_KEY, -1)

        OF.util.publish(GOAL_LEVEL, nil)
        OF.util.publish(GOAL_AREA, nil)
        OF.util.publish(GOAL_X, nil)
        OF.util.publish(GOAL_Y, nil)
        OF.util.publish(GOAL_Z, nil)

        if OF.util.asks(OF.net, "undo_warp") and OF.net.can_undo() then
            OF.util.report(OF.net.undo_warp())
        end
    end
end

function mode.before_mario_update(m)
    if OF.gamemodes.role(0) ~= ROLE_HUNTER then return end
    if head_start_left() <= 0 then return end
    OF.input.hold(m)
end

function mode.update()

    if am_runner() and OF.gamemodes.state() == OF.gamemodes.ACTIVE
        and (gPlayerSyncTable[0].ofGmTime or 0) <= 0
        and tookTheGrandStar then
        tookTheGrandStar = false
        OF.util.publish_row(0, "ofGmTime",
            math.max(0.001, OF.gamemodes.since_start()))
    end

    local rung = hint_level()
    if rung > seenHint then
        seenHint = rung
        if am_runner() then

            local line = seen_line(rung)
            OF.notify.show(line, "bad", 4)
        elseif rung >= HINT_MAX then
            OF.notify.show("The wedge is as narrow as it gets", "good", 4)
        elseif rung >= 2 then
            OF.notify.show("The wedge has halved, and the range with it",
                "info", 3)
        else
            OF.notify.show("The compass is live - a quarter of the rose",
                "info", 3)
        end
        OF.sounds.play(OF.sounds.TICK)
    elseif rung < seenHint then

        seenHint = rung
    end

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE and am_runner()
        and OF.util.can_play(0) then
        local me = gMarioStates[0]
        local dead = me ~= nil and (me.health or 0x880) <= 0xFF
        if dead and not wasDead then
            wasDead = true
            local gone = lives_spent(0) + 1
            OF.util.publish_row(0, DIED_KEY, gone)
            if gone >= lives_allowed() then

                OF.gamemodes.set_role(0, ROLE_HUNTER)
                OF.notify.show("Out of lives - you are hunting now", "bad", 6)
            end
        elseif not dead then
            wasDead = false
        end
    end

    local runner = runner_local()
    local gone = runner ~= nil and lives_spent(runner) or 0
    if gone <= seenSpent then
        seenSpent = gone
        return
    end
    seenSpent = gone

    local left = math.max(0, lives_allowed() - gone)
    local mine = runner == 0
    if left <= 0 then

        if not mine then
            OF.notify.show("The runner is out of lives", "good", 4)
        end
    elseif mine then
        OF.notify.show("They got you - @ of @ lives left", "bad", 4,
            tostring(left), tostring(lives_allowed()))
    else
        OF.notify.show("The runner is down - @ of @ lives left", "good", 3,
            tostring(left), tostring(lives_allowed()))
    end
    OF.sounds.play(OF.sounds.TICK)
end

local function on_pvp_attack(attacker, victim, interaction)
    if not OF.util.is_host() then return end
    if victim == nil or attacker == nil then return end
    if not OF.gamemodes.is_running() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "manhunt" then return end

    local victimIndex = victim.playerIndex
    local hitterIndex = attacker.playerIndex
    if victimIndex == nil or hitterIndex == nil then return end
    if victimIndex == hitterIndex then return end
    if OF.gamemodes.role(victimIndex) ~= ROLE_RUNNER then return end
    if OF.gamemodes.role(hitterIndex) ~= ROLE_HUNTER then return end

    local np = gNetworkPlayers[hitterIndex]
    if np == nil or not np.connected then return end

    lastHitter = np.globalIndex

end

hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)

hook_event(HOOK_ON_INTERACT, function(m, obj, interactType, interacted)
    if m == nil or m.playerIndex ~= 0 then return end
    if interacted ~= true then return end
    if interactType ~= INTERACT_STAR_OR_KEY then return end
    if not OF.gamemodes.is_running() then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "manhunt" then return end
    if not am_runner() then return end
    if id_bhvGrandStar == nil then return end
    if OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvGrandStar) == 0 then
        return
    end
    tookTheGrandStar = true
end)

local function hunters_win(reason)

    local ranAway = runner_local()
    local names = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNTER)) do
        if entry.localIndex ~= ranAway
            and entry.np ~= nil and entry.np.name ~= nil then
            table.insert(names, entry.np.name)
        end
    end

    local who = lastHitter ~= nil and OF.util.local_from_global(lastHitter) or nil
    local np = who ~= nil and gNetworkPlayers[who] or nil

    if #names == 0 then

        OF.gamemodes.finish(reason)
        return
    end

    if np == nil then
        OF.gamemodes.finish(reason, { names = names })
        return
    end
    OF.gamemodes.finish("@ ran the runner down.", { names = names }, np.name)
end

function mode.host_update()

    local runner = runner_local()
    if runner == nil or not OF.util.can_play(runner) then
        OF.gamemodes.abandon("The runner is gone.")
        return
    end

    if lives_left(runner) <= 0 then

        OF.stats.record(runner, "frozen", 1)
        hunters_win("The runner is out of lives.")
        return
    end

    local np = gNetworkPlayers[runner]
    local said = gPlayerSyncTable[runner].ofGmTime or 0
    if said > 0 and np ~= nil and np.currLevelNum == LEVEL_BOWSER_3 then
        local name = np.name
        OF.gamemodes.finish("@ beat the game.", name, name)
    end
end

function mode.on_timeout()
    hunters_win("The runner never made it.")
end

function mode.hud()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local gold = OF.util.gold()
    local held = head_start_left()
    local runner = runner_local()
    local level = hint_level()
    local total = lives_allowed()
    local left = runner ~= nil and lives_left(runner) or total

    if held > 0 then
        local line = am_runner()
            and OF.lang.fill("RUN - @s before they come", tostring(held))
            or OF.lang.fill("HELD - @s", tostring(held))
        OF.util.banner(line, 1.3, gold.r, gold.g, gold.b, 255)
    end

    local aimAt, aimR, aimG, aimB, text
    if am_runner() then
        local at = goal()
        local here = gNetworkPlayers[0]
        if here ~= nil and here.currLevelNum == LEVEL_BOWSER_3 then

            text = OF.lang.t("Beat Bowser and the Grand Star is yours")
        elseif at ~= nil and OF.gamemodes.in_place_room(at) then
            aimAt = at
            aimR, aimG, aimB = gold.r, gold.g, gold.b
            local distance = OF.gamemodes.distance_to_place(at)
            if distance == nil then
                text = OF.lang.t("The pipe is on another floor of this level")
            else

                text = OF.lang.fill("@ to the pipe, @",
                    string.format("%.0f", distance),
                    climb_line(at, true) or OF.lang.t("level with you"))
            end
        else

            text = OF.lang.t("Bowser in the Sky, at the top of the castle")
        end
    elseif runner ~= nil and level > 0 then
        local rm = gMarioStates[runner]
        aimAt = rm ~= nil and rm.pos or nil
        aimR, aimG, aimB = 255, 90, 90

        local distance = OF.gamemodes.distance(0, runner)
        if distance == nil then

            aimAt = nil
            local np = gNetworkPlayers[runner]
            if np ~= nil and OF.util.asks(OF.util, "concealed_level_name") then
                text = OF.lang.fill("The runner is in @",
                    OF.util.concealed_level_name(np.currLevelNum, np.currAreaIndex))
            else
                text = OF.lang.t("The runner is somewhere else")
            end
        else

            local flat = flat_distance_to(aimAt) or 0
            local climb = climb_line(aimAt, false) or OF.lang.t("level with you")
            if flat < QUIET_REACH then

                aimAt = nil
                text = OF.lang.fill("The runner is within earshot, @", climb)
            else
                text = OF.lang.fill("The runner is @, @",
                    OF.lang.t(distance_band(flat, level)), climb)
            end
        end
    else
        text = OF.lang.t("Waiting for the hunt to begin")
    end

    if aimAt ~= nil then
        local ticks, spread
        if am_runner() then
            ticks = bearing_to(aimAt)
        else
            local world = world_bearing_to(aimAt)
            local camera = camera_bearing()
            if world ~= nil and camera ~= nil then
                local centre, half = sector_of(world, level)
                ticks = centre - camera
                spread = half
            end
        end
        if ticks ~= nil then
            draw_needle(screenWidth * 0.5, screenHeight * 0.80,
                screenHeight * 0.07, ticks, aimR, aimG, aimB, 235,
                climb_sign(aimAt), spread)
        end
    end

    OF.util.banner(text, 0.95, 235, 235, 235, 255)

    if am_runner() and level > 0 then
        local line, r2, g2, b2 = seen_line(level)
        OF.util.banner(line, 0.90, r2, g2, b2, 255)
    end

    local line = OF.lang.fill("@ / @ lives", tostring(left), tostring(total))
    local r, g, b = 235, 235, 235
    if left <= 1 then r, g, b = 255, 96, 96 end
    OF.util.banner(line, 0.90, r, g, b, 255)
end

function mode.scenery()
    OF.gamemodes.mark_place("mhgoal", E_MODEL_STAR, goal(), 0x0400)
end

OF.gamemodes.register(mode)
