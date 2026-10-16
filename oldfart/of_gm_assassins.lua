OF = OF or {}

local PENALTY_HOLD = 5 * 30

local HEARTBEAT_RANGE = 1200

local PULSE_SLOW = 60
local PULSE_FAST = 15

local ROLE_HUNTING = "hunting"
local ROLE_OUT = "out"
local myTarget = nil
local myHunter = nil

local myContracts = 0

local penaltyFrames = 0
local lastCause = nil

local pulseTimer = 0

local ring = {}

local PENALTY_STOPS = { five = 5 * 30, three = 3 * 30, ten = 10 * 30 }

local function penalty_hold()
    local said = OF.gamemodes.option_now("penalty")
    return PENALTY_STOPS[said] or PENALTY_HOLD
end

local function heartbeat_on()
    return OF.gamemodes.option_now("heartbeat") ~= "off"
end

local PACKET_ASSIGN = "ofAssassinsAssign"
local function name_of(globalIndex)
    local li = OF.util.local_from_global(globalIndex)
    local np = li ~= nil and gNetworkPlayers[li] or nil
    return (np ~= nil and np.name) or "somebody"
end

local function new_target(globalIndex)
    local had = myTarget
    myTarget = globalIndex
    if had ~= nil and had ~= globalIndex and OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("objective", OF.lang.t("NEW TARGET"), name_of(globalIndex), { side = "us" })
    end
end

local function tell_player(globalIndex, fields)
    if globalIndex == nil then return end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return end
    if li == 0 then
        if fields.t ~= nil then
            new_target(fields.t)
        end
        if fields.h ~= nil then myHunter = fields.h end
        return
    end

    if not OF.util.is_host() then return end
    fields.ofp = PACKET_ASSIGN
    OF.util.send_to_player(li, fields)
end

local function ring_position(globalIndex)
    for k, gi in ipairs(ring) do
        if gi == globalIndex then return k end
    end
    return nil
end

local function deal_the_ring()
    local n = #ring
    for k = 1, n do
        local gi = ring[k]
        local targetGI = ring[(k % n) + 1]
        local hunterGI = ring[((k - 2) % n) + 1]
        tell_player(gi, { t = targetGI, h = hunterGI })
    end
end

local function remove_from_ring(globalIndex)
    local pos = ring_position(globalIndex)
    if pos == nil then return end
    local n = #ring
    if n <= 2 then
        table.remove(ring, pos)
        return
    end
    local predPos = ((pos - 2) % n) + 1
    local succPos = (pos % n) + 1
    local predGI = ring[predPos]
    local succGI = ring[succPos]
    table.remove(ring, pos)
    tell_player(predGI, { t = succGI })
    tell_player(succGI, { h = predGI })
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= PACKET_ASSIGN then return end
    if data.from ~= 0 then return end
    if OF.util.asks(OF.pass, "settled") and OF.pass.settled()
        and not OF.pass.is_mine(data.pk) then
        return
    end
    if type(data.t) == "number" then
        new_target(data.t)
    end
    if type(data.h) == "number" then myHunter = data.h end
end)

local function contenders()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNTING)) do
        if OF.gamemodes.in_contention(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local PACKET_OUT = "asout"
local creditedFor = {}

local function i_am_out(bySelfDefence, attackerLocal)
    local anp = attackerLocal ~= nil and gNetworkPlayers[attackerLocal] or nil
    local me = gNetworkPlayers[0]
    if anp ~= nil and me ~= nil and attackerLocal ~= 0 then
        OF.util.send_to_player(attackerLocal, OF.packet_stamp({ ofp = PACKET_OUT,
            g = anp.globalIndex, v = me.globalIndex, s = bySelfDefence and 1 or 0 }))
    end
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    lastCause = bySelfDefence and "Your target got you first" or "Your hunter found you"
    myTarget = nil
    myHunter = nil
end

local function contract_completed(bySelfDefence)
    myContracts = myContracts + 1
    OF.util.publish_row(0, "ofScore", myContracts)

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("medal", bySelfDefence and OF.lang.t("SELF-DEFENCE") or OF.lang.t("CONTRACT"),
            nil, { tone = "good" })
    end

    OF.gamemodes.cue("good")
end

local function on_pvp_attack(attacker, victim, interaction)
    if attacker == nil or victim == nil then return end
    if not OF.gamemodes.is_running() then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "assassins" then return end

    local attackerIndex = attacker.playerIndex
    local victimIndex = victim.playerIndex
    if attackerIndex == nil or victimIndex == nil then return end
    if attackerIndex == victimIndex then return end

    if victimIndex == 0 and OF.gamemodes.role(0) == ROLE_HUNTING then
        local anp = gNetworkPlayers[attackerIndex]
        local attackerGI = anp ~= nil and anp.globalIndex or nil
        if attackerGI ~= nil then
            if attackerGI == myHunter then
                i_am_out(false, attackerIndex)
            elseif attackerGI == myTarget then
                i_am_out(true, attackerIndex)
            end
        end
    end

    if attackerIndex == 0 and OF.gamemodes.role(0) == ROLE_HUNTING then
        local vnp = gNetworkPlayers[victimIndex]
        local victimGI = vnp ~= nil and vnp.globalIndex or nil
        if victimGI ~= nil and OF.gamemodes.role(victimIndex) == ROLE_HUNTING then
            if victimGI == myTarget or victimGI == myHunter then

                local _ = victimGI
            else
                penaltyFrames = penalty_hold()

                OF.gamemodes.cue("bad")
            end
        end
    end
end

hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)

local function hear_out(data)
    local me = gNetworkPlayers[0]
    if me == nil or data.g ~= me.globalIndex then return false end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "assassins" then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if OF.gamemodes.role(0) ~= ROLE_HUNTING then return false end
    if creditedFor[data.v] then return false end
    creditedFor[data.v] = true
    contract_completed(data.s == 1)
    return true
end
OF.packet_kind(PACKET_OUT, { round = true, fields = { g = "gi", v = "gi", s = "int" } },
    hear_out)

local function heartbeat_strength()

    if not heartbeat_on() then return 0 end
    if myHunter == nil then return 0 end
    local li = OF.util.local_from_global(myHunter)
    if li == nil then return 0 end
    local dist = OF.gamemodes.distance(0, li)
    if dist == nil or dist > HEARTBEAT_RANGE then return 0 end
    return 1 - math.min(1, dist / HEARTBEAT_RANGE)
end

local function heartbeat_tick()
    if not heartbeat_on() then pulseTimer = 0; return end
    local strength = heartbeat_strength()
    if strength <= 0 then pulseTimer = 0; return end
    local interval = math.floor(PULSE_SLOW - (PULSE_SLOW - PULSE_FAST) * strength)
    pulseTimer = pulseTimer + 1
    if pulseTimer >= interval then
        pulseTimer = 0

        OF.gamemodes.round_sound(SOUND_GENERAL_BIG_CLOCK)
    end
end

local mode = {

    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP },
    key = "assassins",
    name = "Assassins",
    blurb = "everybody has a target, and a hunter",
    aims = { [ROLE_HUNTING] =
        "Hunt your one target. Only your hunter may hit you back." },

    how = "Everybody gets a private target.\n"
        .. "Nobody is told who has them.\n"
        .. "Hit your target: they are out and you inherit their target.\n"
        .. "Hit your own hunter back: allowed - that is self-defence.\n"
        .. "Hit anybody else and you are held for it.\n"
        .. "Your own heartbeat quickens when your hunter is close.\n"
        .. "Last two standing, or most contracts on the clock.",
    minPlayers = 3,

    maps = { "cotmc" },
    mainCourses = true,
    roomsOut = {
        { level = LEVEL_CCM, area = 2 }, { level = LEVEL_TTM, area = 2 },
        { level = LEVEL_JRB, area = 2 }, { level = LEVEL_DDD, area = 1 },
        { level = LEVEL_RR, area = 1 }, { level = LEVEL_SL, area = 2 },
        { level = LEVEL_THI, area = 3 },

        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_LLL, area = 2 },
        { level = LEVEL_THI, area = 2 }, { level = LEVEL_TTC, area = 1 },

        { level = LEVEL_SSL, area = 2 },

        { level = LEVEL_JRB, area = 1 }, { level = LEVEL_CCM, area = 1 },
        { level = LEVEL_WDW, area = 1 }, { level = LEVEL_TTM, area = 1 },
    },
    room = { sweep = { "cannons" } },

    defaultLimit = 240,

    target = { name = "seconds on the clock",
               asks = "How many seconds the round runs",
               clock = true,
               default = 240, min = 120, max = 600, step = 30 },
    music = SEQ_LEVEL_SPOOKY,

    teams = false,
    resultsBy = "survival",

    options = {

        { key = "penalty", name = "How long a wrong swing holds you",
          help = "the cost of hitting somebody who is not your contract",
          choices = {
              { key = "five", name = "five seconds", help = "the usual hold" },
              { key = "three", name = "three seconds", help = "forgiving" },
              { key = "ten", name = "ten seconds", help = "costly" },
          } },
        { key = "heartbeat", name = "Hunter warning",
          help = "a pulse that quickens as your hunter closes in",
          choices = {
              { key = "on", name = "on", help = "you feel your hunter coming" },
              { key = "off", name = "off", help = "no warning at all - a harder, quieter round" },
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

function mode.setup(players, options)

    local order = {}
    for _, entry in ipairs(players) do
        if entry.np ~= nil then table.insert(order, entry.np.globalIndex) end
    end
    for i = #order, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end
    ring = order

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_HUNTING)
    end

    deal_the_ring()

    OF.util.report(OF.rules.lend("interactions", "assassins",
        PLAYER_INTERACTIONS_PVP))
end

function mode.late_join(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    local n = #ring
    if n < 2 then
        table.insert(ring, np.globalIndex)
        deal_the_ring()
        return ROLE_HUNTING
    end
    local predGI = ring[1]
    local succGI = ring[2]
    table.insert(ring, 2, np.globalIndex)
    tell_player(predGI, { t = np.globalIndex })
    tell_player(np.globalIndex, { t = succGI, h = predGI })
    tell_player(succGI, { h = np.globalIndex })
    return ROLE_HUNTING
end

function mode.on_start()

    penaltyFrames = 0
    creditedFor = {}
    pulseTimer = 0
    myContracts = 0
    OF.util.publish_row(0, "ofScore", 0)
    lastCause = nil

end

function mode.out_cause() return lastCause end

function mode.update()
    if OF.gamemodes.role(0) ~= ROLE_HUNTING then return end
    if penaltyFrames > 0 then penaltyFrames = penaltyFrames - 1 end
    heartbeat_tick()
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if penaltyFrames > 0 then OF.input.hold(m) end
end

function mode.host_update()

    local k = 1
    while k <= #ring do
        local gi = ring[k]
        local li = OF.util.local_from_global(gi)
        local gone = (li == nil) or (OF.gamemodes.role(li) == ROLE_OUT)
        if gone then
            remove_from_ring(gi)
        else
            k = k + 1
        end
    end

    local alive = contenders()
    if #alive == 0 then
        OF.gamemodes.abandon("Nobody was left hunting.")
    elseif #alive == 1 then
        OF.gamemodes.finish("@ won.",
            alive[1].np.name, alive[1].np.name)
    elseif #alive == 2 then

        OF.gamemodes.finish("@ and @ won.",
            { names = { alive[1].np.name, alive[2].np.name } },
            alive[1].np.name, alive[2].np.name)
    end
end

function mode.on_timeout()
    local best, names = OF.gamemodes.best_of(OF.gamemodes.participants(),
        function(entry)
            local row = gPlayerSyncTable[entry.localIndex]
            return row ~= nil and row.ofScore or 0
        end)
    if best == nil or best == 0 then
        OF.gamemodes.finish("Time - nobody completed a contract.")
    elseif #names > 1 then
        OF.gamemodes.finish(best == 1 and "Time - a draw at 1 contract each."
            or "Time - a draw at @ contracts each.", nil, tostring(best))
    else
        OF.gamemodes.finish(best == 1 and "Time - @ won with 1 contract."
            or "Time - @ won with @ contracts.", names[1], names[1], tostring(best))
    end
end

function mode.terms()

    return OF.lang.t("the last two, or most contracts on the clock")
end

function mode.hud()
    if OF.gamemodes.role(0) ~= ROLE_HUNTING then return end
    if not OF.util.asks(OF.hud, "state_line") then return end
    local state = OF.hud.state_line
    if penaltyFrames > 0 then
        state("held", OF.lang.t("Held"), { prio = 80, tone = "bad",
            figure = math.ceil(penaltyFrames / 30) })
    end
    local strength = heartbeat_strength()
    if strength >= 0.66 then
        state("hunter", OF.lang.t("Hunter close"), { prio = 85, tone = "bad", urgent = true })
    elseif strength > 0 then
        state("hunter", OF.lang.t("Hunter near"), { prio = 70, tone = "warn" })
    end
    if myTarget ~= nil then
        state("target", OF.lang.fill("Target @", OF.util.short_name(name_of(myTarget), 12)),
            { prio = 50, tone = "target" })
    end
end

function mode.cleanup()
    OF.rules.give_back("interactions", "assassins")
    myTarget = nil
    myHunter = nil
    myContracts = 0
    penaltyFrames = 0
    creditedFor = {}
    pulseTimer = 0
    ring = {}
end

function mode.my_target() return myTarget end
function mode.my_hunter() return myHunter end
function mode.my_contracts() return myContracts end
function mode.penalty_left() return penaltyFrames end
function mode.ring_size() return #ring end

function mode.heartbeat_now() return heartbeat_strength() end
mode.hear_out = hear_out
mode.PACKET_OUT = PACKET_OUT

OF.gamemodes.register(mode)
