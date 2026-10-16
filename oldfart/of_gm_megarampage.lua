OF = OF or {}

local ROLE_RUNNING = "running"
local PLACES = {
    empty = { x = 0, y = 0, z = 0 },
}
local PLACE_ORDER = { "empty" }

local WARN = 3
local GIANT = 20
local BREATH = 2

local PER_GIANT = 4

local RING_BASE, RING_PER, RING_MOST = 1500, 60, 2400

local OUTSIDE_FOR = 3

local SCALE = 3
local CRUSH_RADIUS = 37 * SCALE + 37
local CRUSH_LOW, CRUSH_HIGH = -40, 80 * SCALE

local STOMP_ABOVE = 160 + 60

local PANCAKE = 50
local SAFE_AFTER = 3

local CLAIM_SLACK = 450
local CLAIM_ACTION = "mrclaim"
local AT_KEY = "ofMrAt"
local BIG_KEY = "ofMrBig"
local GOT_KEY = "ofMrGot"
local ROUND_KEYS = { "ofMrAt", "ofMrBig", "ofMrGot" }

local hostWent = {}
local hostSerial = 0
local hostTurn = nil
local hostGot = {}
local hostNoRoom = false

local grownFor = nil
local flatAt = -99
local outsideAt = nil
local seenGot = -1
local placed = false
local gate = nil
local seenSerial = nil

local grewSaid, shrankSaid = nil, nil

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function to36(n, width)
    n = math.floor(n)
    if n < 0 then n = 0 end
    local out = ""
    for _ = 1, width do
        local d = n % 36
        out = string.sub(DIGITS, d + 1, d + 1) .. out
        n = math.floor(n / 36)
    end
    return out
end

local function from36(text)
    return tonumber(text, 36) or 0
end

local function giants_for(players)
    return math.max(1, math.ceil(math.max(players or 0, 1) / PER_GIANT))
end

local function ring_for(players)
    return math.min(RING_BASE + RING_PER * math.max(players or 0, 0), RING_MOST)
end

local function points_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return math.floor((row ~= nil and tonumber(row.ofScore)) or 0)
end

local function runners()
    return OF.gamemodes.with_role(ROLE_RUNNING)
end

local function field()
    local at = gGlobalSyncTable[AT_KEY]
    if type(at) ~= "string" then return nil end
    local key, _, _, r = string.match(at, "^(%S+) (%-?%d+) (%-?%d+) (%d+)$")
    local place = key ~= nil and PLACES[key] or nil
    if place == nil then return nil end
    return { x = place.x, y = place.y, z = place.z, r = tonumber(r) or RING_BASE }
end

local function arena_ring()
    local f = field()
    if f == nil then return nil end
    local at = gGlobalSyncTable[AT_KEY]
    local _, level, area = string.match(at, "^(%S+) (%-?%d+) (%-?%d+)")
    return { x = f.x, y = f.y, z = f.z, r = f.r,
             level = tonumber(level), area = tonumber(area) }
end

local function here_ok(localIndex)
    local at = gGlobalSyncTable[AT_KEY]
    local np = gNetworkPlayers[localIndex or 0]
    if type(at) ~= "string" or np == nil then return false end
    local _, level, area = string.match(at, "^(%S+) (%-?%d+) (%-?%d+)")
    return level ~= nil and np.currLevelNum == tonumber(level)
        and np.currAreaIndex == tonumber(area)
end

local function turn()
    local text = gGlobalSyncTable[BIG_KEY]
    if type(text) ~= "string" then return nil end
    local serial, grow, finish, list = string.match(text, "^(%d+) (%d+) (%d+) ([%d%.]*)$")
    if serial == nil then return nil end
    local giants, count = {}, 0
    for g in string.gmatch(list, "%d+") do
        giants[tonumber(g)] = true
        count = count + 1
    end
    return { serial = tonumber(serial), grow = tonumber(grow) / 10,
             finish = tonumber(finish) / 10, giants = giants, count = count }
end

local function is_giant(tn, globalIndex)
    return tn ~= nil and globalIndex ~= nil and tn.giants[globalIndex] == true
end

local function rampage(tn, t)
    return tn ~= nil and t >= tn.grow and t < tn.finish
end

local function publish_got()
    local out = {}
    for g = 0, 15 do out[#out + 1] = to36(math.min(hostGot[g] or 0, 1295), 2) end
    OF.util.publish(GOT_KEY, table.concat(out))
end

local function got_of(globalIndex)
    local text = gGlobalSyncTable[GOT_KEY]
    if type(text) ~= "string" or globalIndex == nil then return 0 end
    local at = globalIndex * 2 + 1
    if #text < at + 1 then return 0 end
    return from36(string.sub(text, at, at + 1))
end

local function award(globalIndex, delta)
    if globalIndex == nil then return end
    hostGot[globalIndex] = math.max((hostGot[globalIndex] or 0) + delta, 0)
    publish_got()
end

local function next_turn(t)
    local still = {}
    for _, entry in ipairs(runners()) do
        if entry.np ~= nil and OF.util.can_play(entry.localIndex)
            and not hostWent[entry.np.globalIndex] then
            still[#still + 1] = entry
        end
    end
    if #still == 0 then return false end
    local picked = OF.gamemodes.deal_fair(still, math.min(giants_for(#runners()), #still), "mega")
    local list = {}
    for _, entry in ipairs(still) do
        if picked[entry.localIndex] then
            hostWent[entry.np.globalIndex] = true
            list[#list + 1] = tostring(entry.np.globalIndex)
        end
    end
    if #list == 0 then return false end
    hostSerial = hostSerial + 1
    hostTurn = { serial = hostSerial, grow = t + WARN, finish = t + WARN + GIANT, crushed = {} }
    OF.util.publish(BIG_KEY, string.format("%.0f %.0f %.0f %s", hostSerial,
        math.floor(hostTurn.grow * 10 + 0.5), math.floor(hostTurn.finish * 10 + 0.5),
        table.concat(list, ".")))
    return true
end

local function end_turn()
    local tn = turn()
    if hostTurn == nil or tn == nil then return end
    for _, entry in ipairs(runners()) do
        local g = entry.np ~= nil and entry.np.globalIndex or nil
        if g ~= nil and not is_giant(tn, g) and not hostTurn.crushed[g] then award(g, 1) end
    end
    hostTurn.ended = true
end

local function host_claim(fromLocal, giantText)
    if not OF.util.is_host() then return false, "Only the host." end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "megarampage"
        or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        return false, "No round."
    end
    local li = tonumber(fromLocal) or -1
    local np = gNetworkPlayers[li]
    local m = gMarioStates[li]
    local tn = turn()
    local giant = tonumber(giantText)
    local t = OF.gamemodes.since_start()
    if np == nil or m == nil or m.pos == nil or hostTurn == nil or tn == nil
        or not rampage(tn, t + 0.5) or not is_giant(tn, giant) or is_giant(tn, np.globalIndex) then
        return false, "No giant."
    end
    local gli = OF.util.local_from_global(giant)
    local gm = gli ~= nil and gMarioStates[gli] or nil
    if gm == nil or gm.pos == nil then return false, "No giant." end
    local dx, dz = m.pos.x - gm.pos.x, m.pos.z - gm.pos.z
    if dx * dx + dz * dz > (CRUSH_RADIUS + CLAIM_SLACK) ^ 2 then return false, "Not under it." end
    hostTurn.crushed[np.globalIndex] = true
    award(giant, 1)
    return true
end

local registered = false
local function register_claim()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action(CLAIM_ACTION, "round_move", host_claim)
end

local function my_global()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex or nil
end

local function giant_frame(tn, t)
    local mine = is_giant(tn, my_global())
    local on = mine and rampage(tn, t)
    if on and grownFor ~= tn.serial and OF.util.asks(OF.powerups, "mega_grow") then
        local frames = math.max(math.floor((tn.finish - t) * 30), 1)
        if OF.powerups.mega_grow(gMarioStates[0], frames, "mode") then
            grownFor = tn.serial
            OF.gamemodes.cue("good", nil, "mrgrow")
        end
    elseif not on and grownFor ~= nil then
        grownFor = nil
        if OF.util.asks(OF.powerups, "mega_shrink") then OF.powerups.mega_shrink() end
    end
end

local function under_the_giant(m, gm)
    if m == nil or gm == nil or m.pos == nil or gm.pos == nil then return false end
    local dx, dz = m.pos.x - gm.pos.x, m.pos.z - gm.pos.z
    if dx * dx + dz * dz >= CRUSH_RADIUS * CRUSH_RADIUS then return false end
    local dy = m.pos.y - gm.pos.y
    if dy > CRUSH_LOW and dy < CRUSH_HIGH then return true end
    local descending = gm.vel ~= nil and (gm.vel.y or 0) < 0
    return descending and dy <= CRUSH_LOW and -dy <= STOMP_ABOVE
end

local function crush_frame(tn, t)
    if not rampage(tn, t) or is_giant(tn, my_global()) then return end
    if t - flatAt < SAFE_AFTER then return end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    for g in pairs(tn.giants) do
        local li = OF.util.local_from_global(g)
        local gm = li ~= nil and li ~= 0 and gMarioStates[li] or nil
        if gm ~= nil and gm.pos ~= nil then
            if under_the_giant(m, gm) then
                flatAt = t
                m.squishTimer = PANCAKE
                m.forwardVel = 0
                m.vel.x, m.vel.z = 0, 0
                OF.gamemodes.cue("bad")

                if OF.util.asks(OF.hud, "banner") then
                    OF.hud.banner("out", OF.lang.t("FLATTENED"), nil, { quiet = true })
                end
                register_claim()
                if OF.util.asks(OF.net, "host_does") then OF.net.host_does(CLAIM_ACTION, g) end
                return
            end
        end
    end
end

local function ring_frame(f, t)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end
    local dx, dz = m.pos.x - f.x, m.pos.z - f.z
    if dx * dx + dz * dz <= f.r * f.r then
        outsideAt = nil
        return
    end
    outsideAt = outsideAt or t
    if t - outsideAt >= OUTSIDE_FOR then
        outsideAt = nil
        OF.net.snap_to(f.x, f.y + 10, f.z, nil)
        OF.util.camera_behind_soon()
    end
end

local mode = {
    key = "megarampage",
    name = "Mega Rampage",
    blurb = "one of you is giant for twenty seconds - everybody else runs",
    how = "One player grows to triple size for twenty seconds.\n"
        .. "Every runner the giant walks into is flattened: a point.\n"
        .. "Last a whole turn unflattened - a point to you.\n"
        .. "Then the giant shrinks and the next one grows.\n"
        .. "Everybody is giant once. Most points at the end wins.",
    aims = { [ROLE_RUNNING] = "Giant? Flatten them. Not giant? Keep away from the feet." },
    minPlayers = 2,
    maps = { "empty" },
    room = { rules = { interactions = PLAYER_INTERACTIONS_NONE } },
    defaultLimit = 120,
    music = SEQ_EVENT_POWERUP,
    teams = false,
    studio = { tint = { 170, 150, 140 } },

    keepsScore = true,
    boardTitle = "Points",
}

function mode.short_name(name)
    local plain = OF.util.plain(name or "")
    if #plain > 12 then plain = plain:sub(1, 11) .. "." end
    return plain
end
mode.giants_for = giants_for
mode.ring_for = ring_for
mode.turn = turn
mode.got_of = got_of
mode.host_claim = host_claim
mode.under_the_giant = under_the_giant
mode.PLACES = PLACES

function mode.sized_by_round(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    local tn = turn()
    if not is_giant(tn, np.globalIndex) then return false end
    local t = OF.gamemodes.since_start()
    return t >= tn.grow - 0.5 and t < tn.finish + 1
end

function mode.setup(players)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_RUNNING)
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

mode.arenaRing = arena_ring

function mode.pin()
    hostWent, hostSerial, hostTurn, hostGot = {}, 0, nil, {}
    local key = place_here()
    if key == nil then
        hostNoRoom = true
        return
    end
    hostNoRoom = false
    local np = gNetworkPlayers[0]
    OF.util.publish(AT_KEY, string.format("%s %.0f %.0f %.0f", key, np.currLevelNum,
        np.currAreaIndex, ring_for(#runners())))
    OF.util.publish(BIG_KEY, nil)
    publish_got()
end

local function place_me(f)
    if placed then return end
    local np = gNetworkPlayers[0]
    if np == nil or OF.gamemodes.role(0) ~= ROLE_RUNNING then return end
    placed = true
    local a = (np.globalIndex or 0) / 16 * 2 * math.pi
    local x, z = f.x + math.sin(a) * f.r * 0.5, f.z + math.cos(a) * f.r * 0.5
    local yaw = math.atan(f.x - x, f.z - z)
    OF.net.snap_to(x, f.y + 10, z, math.floor(yaw / math.pi * 32768) % 65536)
    OF.util.camera_behind_soon()
end

local function make_gate()
    return function(globalIndex) return is_giant(turn(), globalIndex) end
end

function mode.on_start()
    grownFor, flatAt, outsideAt, seenGot, placed, seenSerial = nil, -99, nil, -1, false, nil
    register_claim()
    if OF.powerups ~= nil then
        gate = make_gate()
        OF.powerups.megaGate = gate
    end
    grewSaid, shrankSaid = nil, nil

end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_RUNNING)
    local np = gNetworkPlayers[localIndex]
    if OF.util.is_host() and np ~= nil then
        hostGot[np.globalIndex] = 0
        hostWent[np.globalIndex] = nil
        publish_got()
    end
    return ROLE_RUNNING
end

function mode.scenery()
    local f = field()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE or f == nil or not here_ok(0) then return end
    if OF.gamemodes.role(0) ~= ROLE_RUNNING or not OF.util.can_play(0) then return end
    local t = OF.gamemodes.since_start()
    place_me(f)
    local tn = turn()
    if tn ~= nil and tn.serial ~= seenSerial then
        seenSerial = tn.serial

        OF.gamemodes.cue("hazard", nil, "mrturn")
    end
    giant_frame(tn, t)
    crush_frame(tn, t)
    ring_frame(f, t)
end

function mode.update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local g = my_global()
    if g == nil or OF.gamemodes.role(0) ~= ROLE_RUNNING then return end
    local got = got_of(g)
    if got ~= points_of(0) then
        if got > points_of(0) and seenGot >= 0 then OF.gamemodes.cue("good") end
        OF.util.publish_row(0, "ofScore", got)
    end
    seenGot = got

    local tn = turn()
    local t = OF.gamemodes.since_start()
    if is_giant(tn, g) and rampage(tn, t) then
        OF.gamemodes.cue("tick", nil, nil, math.ceil(tn.finish - t))
    end
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if hostNoRoom then
        OF.gamemodes.abandon("Mega Rampage is played in The Tiles.")
        return
    end
    local t = OF.gamemodes.since_start()
    if hostTurn == nil then
        if not next_turn(t) then OF.gamemodes.abandon("Nobody to grow.") end
        return
    end
    if not hostTurn.ended and t >= hostTurn.finish then end_turn() end
    if hostTurn.ended and t >= hostTurn.finish + BREATH then
        if not next_turn(t) then mode.on_timeout() end
    end
end

function mode.still_winnable()
    return #runners() >= 2
end

function mode.terms()
    return OF.lang.t("the most points once everybody has been giant")
end

function mode.on_timeout()
    local best, names = OF.gamemodes.best_of(runners(),
        function(entry) return entry.np ~= nil and got_of(entry.np.globalIndex) or 0 end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody scored.")
    elseif #names > 1 then
        OF.gamemodes.finish(OF.lang.fill("A draw at @ points.", tostring(best)))
    else
        OF.gamemodes.finish("@ won - the most points.", names[1], names[1])
    end
end

function mode.hud()
    local f = field()
    if f == nil then return end
    if not here_ok(0) then
        OF.gamemodes.away_banner("The giants are somewhere else")
        return
    end
    local tn = turn()
    local t = OF.gamemodes.since_start()
    local me = my_global()
    local names = {}
    if tn ~= nil then
        for g in pairs(tn.giants) do
            local li = OF.util.local_from_global(g)
            local np = li ~= nil and gNetworkPlayers[li] or nil
            if np ~= nil then names[#names + 1] = np.name end
        end
        table.sort(names)
    end
    local who = table.concat(names, ", ")

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    local banner = OF.util.asks(OF.hud, "banner") and OF.hud.banner or function() end
    if outsideAt ~= nil then
        state("back", OF.lang.t("Back in"), { prio = 85, tone = "warn", urgent = true,
            figure = math.max(0, math.ceil(OUTSIDE_FOR - (t - outsideAt))) })
    end
    if tn ~= nil and t < tn.grow then
        local left = math.max(0, math.ceil(tn.grow - t))
        if is_giant(tn, me) then
            state("grow", OF.lang.t("Grow in"), { prio = 70, tone = "target", figure = left })
        end
    elseif tn ~= nil and t < tn.finish then
        local left = math.max(0, math.ceil(tn.finish - t))
        if is_giant(tn, me) then
            if grewSaid ~= tn.serial then
                grewSaid = tn.serial
                banner("role", OF.lang.t("YOU ARE GIANT"), nil)
            end
            state("giant", OF.lang.t("Giant"), { prio = 70, tone = "target", figure = left })
        elseif who ~= "" then
            state("whois", OF.lang.fill("Giant @", mode.short_name(who)), { prio = 50, tone = "warn" })
        end
    elseif tn ~= nil and shrankSaid ~= tn.serial then
        shrankSaid = tn.serial
        banner("roundstate", OF.lang.t("GIANT SHRINKS"), nil)
    end
    local r, g, b = OF.util.round_tone("warn")
    OF.util.zone_ring(f, f.r, 48, 4, r, g, b, 200, "edge")

end

function mode.cleanup()
    if grownFor ~= nil and OF.util.asks(OF.powerups, "mega_shrink") then OF.powerups.mega_shrink() end
    if OF.powerups ~= nil and gate ~= nil and OF.powerups.megaGate == gate then
        OF.powerups.megaGate = nil
    end
    gate = nil
    if OF.util.is_host() then
        for _, key in ipairs(ROUND_KEYS) do OF.util.publish(key, nil) end
    end
    hostWent, hostSerial, hostTurn, hostGot, hostNoRoom = {}, 0, nil, {}, false
    grownFor, flatAt, outsideAt, seenGot, placed, seenSerial = nil, -99, nil, -1, false, nil
    return true
end

OF.gamemodes.register(mode)
