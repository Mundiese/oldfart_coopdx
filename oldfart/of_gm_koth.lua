OF = OF or {}

local ROLE_HUNT = "on the hunt"
local HILL_STOPS = { ordinary = 550, tight = 300, wide = 900, huge = 1400 }
local HILL_DEFAULT = "ordinary"
local BIG_HILLS = { wide = true, huge = true }
local function hill_size()
    local pick = OF.gamemodes.option_now("size") or HILL_DEFAULT
    if BIG_HILLS[pick] and not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then
        pick = HILL_DEFAULT
    end
    return HILL_STOPS[pick] or HILL_STOPS[HILL_DEFAULT]
end

local SHRINK_STOPS = { stays = false, closes = true }
local SHRINK_DEFAULT = "stays"
local MOVE_STOPS = { stays = false, moves = true }
local MOVE_DEFAULT = "stays"
local function hill_moves()
    local stop = MOVE_STOPS[OF.gamemodes.option_now("moves") or MOVE_DEFAULT]
    if stop == nil then return MOVE_STOPS[MOVE_DEFAULT] end
    return stop
end

local MOVE_SECONDS = 60

local MOVE_WARN_SECONDS = 3

local function hill_slot()
    local gone = OF.gamemodes.elapsed()
    if type(gone) ~= "number" or gone < 0 then gone = 0 end
    return math.floor(gone / MOVE_SECONDS) % 3 + 1
end

local function hill_points()
    local text = gGlobalSyncTable.ofHillPts
    if type(text) ~= "string" or text == "" then return nil end
    local list = OF.gamemodes.unpack_points(text)
    if list[3] == nil then return nil end
    return list
end

local MOVE_REACHES = { 900, 700, 500, 350 }
local MOVE_STOREY = 700

local function floor_under(x, z, from)
    local found = OF.util.optional("find_floor_height", nil, x, from + 400, z)
    if type(found) ~= "number" then return nil end
    if math.abs(found - from) > MOVE_STOREY then return nil end
    return found
end

local function two_more(cx, cy, cz, reach, probe)
    local turn = math.random() * 2 * math.pi
    local list = {}
    for step = 1, 2 do
        local angle = turn + (step - 1) * math.pi
        local x = cx + math.cos(angle) * reach
        local z = cz + math.sin(angle) * reach
        local y = cy
        if probe then
            y = floor_under(x, z, cy)
            if y == nil then return nil end
        end
        list[step] = { x = x, y = y, z = z }
    end
    return list
end

local function moving_hill_points(centreX, centreY, centreZ, here)
    local surveyed = OF.gamemodes.surveyed_list(here, "points", 3)
    if surveyed ~= nil and #surveyed >= 3 then
        local set = {}
        for i = 1, 3 do set[i] = surveyed[i] end
        return OF.gamemodes.pack_points(set)
    end

    local list = { { x = centreX, y = centreY, z = centreZ } }
    local chosen = nil
    for _, reach in ipairs(MOVE_REACHES) do
        chosen = two_more(centreX, centreY, centreZ, reach, true)
        if chosen ~= nil then break end
    end
    if chosen == nil then
        chosen = two_more(centreX, centreY, centreZ, MOVE_REACHES[#MOVE_REACHES], false)
    end
    list[2] = chosen[1]
    list[3] = chosen[2]
    return OF.gamemodes.pack_points(list)
end

local HILL_FLOOR = HILL_STOPS.tight

local function hill_closes()
    local stop = SHRINK_STOPS[OF.gamemodes.option_now("shrink") or SHRINK_DEFAULT]
    if stop == nil then return SHRINK_STOPS[SHRINK_DEFAULT] end
    return stop
end

local function round_fraction()
    local whole = OF.gamemodes.round_seconds(300)
    if type(whole) ~= "number" or whole <= 0 then return 0 end
    local gone = OF.gamemodes.elapsed()
    if type(gone) ~= "number" or gone <= 0 then return 0 end
    if gone >= whole then return 1 end
    return gone / whole
end

local function hill_radius()
    local size = hill_size()
    if not hill_closes() then return size end
    return HILL_FLOOR + (size - HILL_FLOOR) * (1 - round_fraction())
end

OF.gm_koth_hill_floor = function() return HILL_FLOOR, HILL_STOPS end

OF.gm_koth_hill_radius = hill_radius

local TARGET_SECONDS = 45

local HILL_STOREY = 300

local HILL_AIR = 700

local FLOOR_PROBE_UP = 500
local NO_FLOOR_BELOW = -10000

local function target_seconds()
    local value = gGlobalSyncTable.ofHillTarget
    if type(value) ~= "number" or value <= 0 then return TARGET_SECONDS end
    return value
end

local snap = { frame = nil }

local function reset_snapshot() snap.frame = nil end

local held = 0
local wasInside = false
local contested = false
local wasContested = false

local pulse = 0

local hillSlotWas = nil
local warnedForSlot = nil

local moveIn = nil

local function hill_position()
    local x, y, z = gGlobalSyncTable.ofHillX or 0, gGlobalSyncTable.ofHillY or 0,
        gGlobalSyncTable.ofHillZ or 0

    if hill_moves() then
        local pts = hill_points()
        if pts ~= nil then
            local at = pts[hill_slot()]
            if at ~= nil then x, y, z = at.x, at.y, at.z end
        end
    end

    return {
        x = x, y = y, z = z,
        level = gGlobalSyncTable.ofHillLevel or 0,
        area = gGlobalSyncTable.ofHillArea or 1,

        height = HILL_AIR,
    }
end

local function hill_spot()
    if gGlobalSyncTable.ofHillX == nil then return nil end
    return hill_position()
end

local function place_hill_flag()
    OF.gamemodes.mark_flag("hill", hill_spot())
end

local function place()
    local spot = hill_spot()
    if not OF.gamemodes.in_place_room(spot) then return nil end
    spot.label = "the hill"
    return spot
end

local function standing_in_hill(localIndex, at)
    local spot = at or hill_spot()
    local distance = OF.gamemodes.distance_to_place(spot, localIndex)
    if distance == nil or distance >= hill_radius() then return false end
    local m = gMarioStates[localIndex or 0]
    if m == nil then return false end
    local floor = tonumber(m.floorHeight)
    if floor == nil then return false end
    return math.abs(floor - (spot.y or 0)) <= HILL_STOREY
end

local function score_of(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil or s.ofScore == nil then return 0 end
    return s.ofScore
end

local mode = {

    target = { auto = function(n, teams, side)
                   if teams then return OF.util.clamp(OF.gamemodes.round_to(22 * side, 15), 60, 180) end
                   return OF.util.clamp(OF.gamemodes.round_to(240 / n, 15), 30, 90)
               end,
               name = "seconds on the hill",
               asks = "How many seconds on the hill win the round",
               default = 45,
               min = 15, max = 180, step = 15 },
    key = "koth",
    name = "King of the Hill",

    boardTitle = "Hill time",
    overtimeSub = "The hill is contested",
    blurb = "hold the circle the longest",

    blurbTeams = "hold the circle - and stand in it to stop them holding it",

    aims = { [ROLE_HUNT] = "Stand inside the circle alone and the seconds add up." },
    how = "A flag is planted and a circle drawn round it.\n"
        .. "Stand inside alone and the seconds add up.\n"
        .. "Two inside, or both sides, and nobody scores.\n"
        .. "Whoever holds it is marked - knock them out.\n"
        .. "First to the target wins; on the clock, the most.",
    minPlayers = 2,

    pinsOnPlayers = false,

    maps = { "bowser1", "bowser2", "bowser3", "desert_cage", "ice_donut", "the_plate", "aquarium", "tower" },

    room = { sweep = { "cannons" }, rules = { interactions = PLAYER_INTERACTIONS_PVP } },
    music = SEQ_LEVEL_KOOPA_ROAD,

    defaultLimit = 240,

    teams = true,

    scoreIsTime = true,

    options = {

        { key = "size", name = "Hill size",
          help = "whether the circle is a scrum or a team fight",
          choices = {
              { key = "ordinary", name = "normal",
                help = "three or four fit and the rest are pushing" },
              { key = "tight", name = "small",
                help = "barely space for two; holding it is a fight" },
              { key = "wide", name = "large",
                help = "sides only: half a lobby fits; without sides, normal" },
              { key = "huge", name = "huge",
                help = "sides only: the circle is the arena; without sides, normal" },
          } },
        { key = "shrink", name = "Hill closes in",
          help = "whether the circle stays the size it started",
          choices = {
              { key = "stays", name = "no",
                help = "one circle, the same size from first to last" },
              { key = "closes", name = "yes",
                help = "the circle comes in to a scrum by the end" },
          } },
        { key = "moves", name = "Hill moves",
          help = "whether the circle stays put or relocates on a timer",
          choices = {
              { key = "stays", name = "no",
                help = "one hill, planted once, for the whole round" },
              { key = "moves", name = "every minute",
                help = "the hill relocates on a timer, with three seconds' warning" },
          } },

        { key = "replay", name = "Replay at the end",
          help = "the seconds before the round was decided, again",
          choices = {
              { key = "short", name = "the last three seconds",
                help = "played inside the ending - no extra wait" },
              { key = "long", name = "the last six seconds",
                help = "the ending waits three seconds more" },
              { key = "off", name = "no replay",
                help = "the winner's line over the world, as before" },
          } },
    },
}

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual hill", sets = {} },
    { key = "crazy", name = "Crazy King", help = "the hill moves every minute",
      sets = { moves = "moves" } },
    { key = "laststand", name = "Last Stand", help = "with sides: a huge hill that closes in",
      sets = { size = "huge", shrink = "closes" } },
}

function mode.terms()
    local seconds = tostring(math.floor(target_seconds()))
    local base
    if OF.gamemodes.option_showing(mode.key, "shrink") == "closes" then
        base = OF.lang.fill("first to @s on a hill that closes in", seconds)
    else
        base = OF.lang.fill("first to @s on the hill", seconds)
    end

    if OF.gamemodes.option_showing(mode.key, "moves") == "moves" then
        base = base .. " - moves every minute"
    end
    return base
end

function mode.setup(players, options)

    if options ~= nil then options.target = OF.gamemodes.auto_target(mode, players, options) end

    OF.util.publish("ofHillTarget", options.target or TARGET_SECONDS)

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_HUNT)
    end
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end

    local sumX, sumZ, count = 0, 0, 0
    for _, entry in ipairs(OF.gamemodes.landed(OF.gamemodes.with_role(ROLE_HUNT))) do
        local np = gNetworkPlayers[entry.localIndex]
        local m = gMarioStates[entry.localIndex]
        if np ~= nil and m ~= nil and m.pos ~= nil
            and np.currLevelNum == here.level
            and np.currAreaIndex == here.area then
            sumX = sumX + m.pos.x
            sumZ = sumZ + m.pos.z
            count = count + 1
        end
    end

    local centreX, centreY, centreZ = here.x, here.y, here.z
    if count > 0 then
        centreX = sumX / count
        centreZ = sumZ / count
    end

    local under = OF.util.optional("find_floor_height", nil,
        centreX, centreY + FLOOR_PROBE_UP, centreZ)
    if type(under) == "number" and under > NO_FLOOR_BELOW then
        centreY = under
    end

    local surveyed = OF.gamemodes.surveyed(here, "hill")
    if surveyed ~= nil then
        centreX, centreY, centreZ = surveyed.x, surveyed.y, surveyed.z
    end

    OF.util.publish("ofHillX", centreX)
    OF.util.publish("ofHillY", centreY)
    OF.util.publish("ofHillZ", centreZ)
    OF.util.publish("ofHillLevel", here.level)
    OF.util.publish("ofHillArea", here.area)

    if hill_moves() then
        OF.util.publish("ofHillPts",
            moving_hill_points(centreX, centreY, centreZ, here))
    else
        OF.util.publish("ofHillPts", nil)
    end
end

mode.leadPin = { keys = { "ofHillX", "ofHillY", "ofHillZ", "ofHillLevel",
                          "ofHillArea", "ofHillPts" } }

function mode.on_start()
    held = 0
    wasInside = false
    contested = false
    wasContested = false
    pulse = 0
    hillSlotWas = nil
    warnedForSlot = nil
    reset_snapshot()

end

function mode.cleanup()
    held = 0
    wasInside = false
    contested = false
    wasContested = false
    pulse = 0
    reset_snapshot()

    if OF.util.is_host() then
        OF.util.publish("ofHillTarget", nil)
        OF.util.publish("ofHillLevel", nil)
        OF.util.publish("ofHillArea", nil)
        OF.util.publish("ofHillX", nil)
        OF.util.publish("ofHillY", nil)
        OF.util.publish("ofHillZ", nil)
        OF.util.publish("ofHillPts", nil)
    end
    hillSlotWas = nil
    warnedForSlot = nil
end

local function bodies_in_hill()
    local counts = { red = 0, blue = 0, any = 0, list = {} }
    local spot = hill_spot()
    if spot == nil then return counts end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if OF.gamemodes.can_play(entry.localIndex) then

            if standing_in_hill(entry.localIndex, spot) then
                counts.any = counts.any + 1
                table.insert(counts.list, entry.localIndex)
                local side = OF.teams.of(entry.localIndex)
                if counts[side] ~= nil then counts[side] = counts[side] + 1 end
            end
        end
    end
    return counts
end

local function hill_state()
    local counts = bodies_in_hill()
    if not OF.teams.in_play() then
        return counts, counts.any >= 2, nil
    end
    if counts.red == 0 and counts.blue == 0 then return counts, false, nil end
    if counts.red > 0 and counts.blue > 0 then return counts, true, nil end
    return counts, false, counts.red > 0 and "red" or "blue"
end
mode.hill_state = hill_state
local CONTEST = { r = 255, g = 230, b = 120 }

local function snapshot()
    local frame = OF.util.optional("get_global_timer", 0) or 0
    if snap.frame == frame and snap.value ~= nil then return snap.value end

    local counts, deadlocked, side = hill_state()
    local value = { aim = nil, targets = {}, contested = deadlocked }
    local teams = OF.teams.in_play()
    local mine = OF.teams.of(0)
    local me = gMarioStates[0]

    local holders = {}
    if teams then
        if side ~= nil then
            for _, index in ipairs(counts.list) do
                if OF.teams.of(index) == side then table.insert(holders, index) end
            end
        end
    elseif counts.any == 1 then
        holders[1] = counts.list[1]
    end

    if #holders > 0 and not (teams and side == mine) and holders[1] ~= 0 then
        local best, bestD = nil, nil
        for _, index in ipairs(holders) do
            local m = gMarioStates[index]
            if m ~= nil and m.pos ~= nil and me ~= nil and me.pos ~= nil then
                local dx, dz = m.pos.x - me.pos.x, m.pos.z - me.pos.z
                local d = dx * dx + dz * dz
                if bestD == nil or d < bestD then best, bestD = index, d end
            end
        end
        value.aim = best
    end

    if deadlocked and standing_in_hill(0) then
        for _, index in ipairs(counts.list) do
            if index ~= 0 and (not teams or OF.teams.of(index) ~= mine) then
                table.insert(value.targets, index)
            end
        end
    end

    snap.frame, snap.value = frame, value
    return value
end

local function holder_colour(localIndex)
    if OF.teams.in_play() then
        local team = OF.teams.find(OF.teams.of(localIndex))
        if team ~= nil then return team.r, team.g, team.b end
    end

    local t = OF.hud ~= nil and OF.hud.C ~= nil and OF.hud.C.target or { 255, 210, 60 }
    return t[1], t[2], t[3]
end

local function holder_name(localIndex)
    local np = gNetworkPlayers[localIndex]
    return OF.util.short_name(np ~= nil and np.name or "?", 14)
end

local hillTarget = { id = "hill", label = "the hill", priority = 90,
    compass = "offscreen", ring = { radius = 0 } }
local targetList = {}
local holderTargets = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #targetList, 1, -1 do targetList[i] = nil end
    local spot = place()
    if spot == nil then return nil end
    local counts, deadlocked, holder = hill_state()
    local tone = "target"
    local team = holder ~= nil and OF.teams.find(holder) or nil
    if team ~= nil then
        tone = { team.r, team.g, team.b }
    elseif counts.any == 1 and counts.list[1] ~= nil then
        local r, g, b = holder_colour(counts.list[1])
        tone = { r, g, b }
    end
    hillTarget.pos = spot
    hillTarget.tone = tone
    hillTarget.ring.radius = hill_radius()
    hillTarget.contested = deadlocked == true
    targetList[1] = hillTarget

    local snap = snapshot()
    local people = {}
    if snap.aim ~= nil then people[1] = snap.aim end
    for _, index in ipairs(snap.targets) do people[#people + 1] = index end
    for n, index in ipairs(people) do
        local t = holderTargets[n] or {}
        holderTargets[n] = t
        local r, g, b = holder_colour(index)
        t.id = "holder:" .. tostring(index)
        t.player = index
        t.label = holder_name(index)
        t.tone = { r, g, b }

        t.priority = (index == snap.aim) and 75 or 65
        t.compass = "offscreen"
        t.overhead = index == snap.aim
        targetList[#targetList + 1] = t
    end
    return targetList
end

function mode.update()
    local inside = standing_in_hill(0)

    if inside ~= wasInside then
        wasInside = inside

        if inside then
            OF.gamemodes.cue("good")
        end
    end

    if not inside then
        contested = false
        wasContested = false
        return
    end

    do
        local _, deadlocked, holder = hill_state()
        contested = deadlocked or (OF.teams.in_play() and holder ~= OF.teams.of(0))

        if contested and not wasContested then
            OF.gamemodes.cue("hazard")
        end
        wasContested = contested
        if contested then return end
    end

    held = held + 1

    if held % 30 == 0 then
        OF.util.publish_row(0, "ofScore", math.floor(held / 30))
    end
end

function mode.host_update()
    local target = target_seconds()

    if OF.teams.in_play() then
        local red, blue = OF.teams.score("red"), OF.teams.score("blue")
        if red >= target or blue >= target then
            local winner = OF.teams.leader(red, blue)
            OF.gamemodes.finish(OF.teams.result_text(red, blue),
                OF.gamemodes.team_winner(winner))
        end
        return
    end

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if score_of(entry.localIndex) >= target then
            OF.gamemodes.finish("@ won the hill.", entry.np.name, entry.np.name)
            return
        end
    end
end

function mode.on_timeout()
    if OF.teams.in_play() then
        local winner = OF.teams.leader()
        OF.gamemodes.finish(OF.teams.result_text(), OF.gamemodes.team_winner(winner))
        return
    end

    local bestScore, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_HUNT),
        function(entry) return score_of(entry.localIndex) end,
        false,
        function(entry)
            return standing_in_hill(entry.localIndex) and 1 or 0
        end)
    if bestScore == nil or bestScore <= 0 then
        OF.gamemodes.finish("Nobody held the hill.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, bestScore)
    else
        OF.gamemodes.finish("@ wins with @ seconds.", names[1], names[1], bestScore)
    end
end

function mode.hud()
    pulse = pulse + 1

    local here = OF.gamemodes.in_place_room(hill_spot())

    local counts, deadlocked, holder = hill_state()
    if here then
        local gold = OF.util.gold()
        local ringR, ringG, ringB = gold.r, gold.g, gold.b
        local size, alpha = 3, 200
        if deadlocked then
            ringR, ringG, ringB = CONTEST.r, CONTEST.g, CONTEST.b
            size = 5

            alpha = 170 + math.floor(70 * (0.5 + 0.5 * math.sin(pulse * 0.12)))
        else
            local team = holder ~= nil and OF.teams.find(holder) or nil
            if team ~= nil then
                ringR, ringG, ringB = team.r, team.g, team.b
                size = 4
            elseif counts.any > 0 then

                local who = counts.list[1]
                if counts.any == 1 and who ~= nil then
                    ringR, ringG, ringB = holder_colour(who)
                else
                    ringR, ringG, ringB = 140, 255, 160
                end
                size = 4
            end
        end

        if not OF.util.asks(OF.markers, "ring") then
            OF.util.zone_ring(hill_spot(), hill_radius(), 40, size,
                ringR, ringG, ringB, alpha, "edge")
        end
    end

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    local close = standing_in_hill(0)
    local mine = OF.teams.of(0)
    if close and deadlocked then
        state("contested", OF.lang.t("Contested"), { prio = 70, tone = "warn", urgent = true })
    elseif close and (holder == nil or holder == mine) then
        state("on", OF.lang.t("On the hill"), { prio = 50, tone = "good" })
    elseif not OF.teams.in_play() and counts.any == 1 and counts.list[1] ~= 0 then
        state("holder", OF.lang.fill("@ holds it", OF.util.short_name(holder_name(counts.list[1]), 10)),
            { prio = 60, tone = "bad" })
    elseif holder ~= nil and holder ~= mine then
        state("holder", OF.lang.t("They hold it"), { prio = 60, tone = "bad" })
    end
    if moveIn ~= nil then
        state("moves", OF.lang.t("Hill moves"), { prio = 75, tone = "warn", figure = moveIn,
            urgent = true })
    end
end

local function check_hill_move()
    if not hill_moves() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hill_points() == nil then return end

    local gone = OF.gamemodes.elapsed()
    if type(gone) ~= "number" or gone < 0 then gone = 0 end
    local intoSlot = gone % MOVE_SECONDS
    local slot = hill_slot()

    if hillSlotWas == nil then
        hillSlotWas = slot
        return
    end

    moveIn = nil
    if slot ~= hillSlotWas then
        hillSlotWas = slot
        warnedForSlot = nil

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("objective", OF.lang.t("HILL MOVED"), nil)
        end

        OF.gamemodes.cue("hazard")
    elseif MOVE_SECONDS - intoSlot <= MOVE_WARN_SECONDS then

        OF.gamemodes.tick_down(math.ceil(MOVE_SECONDS - intoSlot))
        moveIn = math.ceil(MOVE_SECONDS - intoSlot)
        if warnedForSlot ~= slot then
            warnedForSlot = slot
        end
    end
end

function mode.scenery()
    place_hill_flag()
    check_hill_move()
end

mode.target_now = target_seconds

function mode.harmless_hit(attacker, victim)
    if victim == nil or victim.playerIndex ~= 0 then return false end
    if OF.gamemodes.current() ~= mode then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    victim.hurtCounter = 0
    return true
end
hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim) mode.harmless_hit(attacker, victim) end)

OF.gamemodes.register(mode)
