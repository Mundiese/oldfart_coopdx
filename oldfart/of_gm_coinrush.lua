OF = OF or {}

local ROLE_COLLECTING = "collecting"
local collected = 0

local streak = { kind = nil, award = 0 }

local DROP_SHARE = 0.25

local DROP_MAX_LOW = 2
local DROP_MAX_HIGH = 8

local RAIN_STOPS = {
    steady = {},
    thin = { coins = 2, max = 16 },
    heavy = { coins = 10, max = 70 },
    none = { coins = 0 },
}

local function rain_wanted()
    return RAIN_STOPS[OF.gamemodes.option_now("rain") or "steady"]
        or RAIN_STOPS.steady
end

local DROP_IMMUNE = 60

local SPILL_STOPS = { quarter = 0.25, none = 0, half = 0.5, lot = 1.0 }
local SPILL_DEFAULT = "quarter"
local function spill_share()
    local said = SPILL_STOPS[OF.gamemodes.option_now("spill") or SPILL_DEFAULT]
    if said == nil then return SPILL_STOPS[SPILL_DEFAULT] end
    return said
end

function OF.gm_coinrush_drop(carrying)
    if type(carrying) ~= "number" or carrying < 1 then return 0 end
    local share = spill_share()

    if share <= 0 then return 0 end
    local ceiling = OF.util.random_int(DROP_MAX_LOW, DROP_MAX_HIGH)
    return math.floor(OF.util.clamp(
        math.ceil(carrying * share), 1, math.min(ceiling, carrying)))
end

function OF.gm_coinrush_drop_grace()
    return DROP_IMMUNE
end

function OF.gm_coinrush_drop_ends()
    return DROP_MAX_LOW, DROP_MAX_HIGH
end

local TARGET_COINS = 150

local TARGET_KEY = "ofRushTarget"
local POOL_KEY = "ofRushPool"
local POOL_EACH = 5

local sinceRain = 0
local immune = 0
local lastHurt = 0

local wasAhead = false

local sinceScore = 0
local lastRoomTotal = 0
local wentDry = false

local poolSaid = false

local ours = {}

local poolTotal, poolLeft = nil, nil

local function score_of(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil or s.ofScore == nil then return 0 end
    return s.ofScore
end

local function target_coins()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return TARGET_COINS end
    return value
end

local function hold_the_coin_star()
    if not OF.util.asks(OF.rules, "lend") then return end
    OF.util.report(OF.rules.lend("coinstar", "coinrush", OF.rules.WIRE_MAX))
end

local function let_the_coin_star_go()
    if not OF.util.asks(OF.rules, "give_back") then return end
    OF.rules.give_back("coinstar", "coinrush")
end

local SWEEP_SPARED = { pickups = true, cannons = true }

local function sweep_keys()
    local keys = {}
    for _, option in ipairs(OF.util.asks(OF.arena, "OPTIONS")
        and OF.arena.OPTIONS or {}) do
        if not SWEEP_SPARED[option.key] then table.insert(keys, option.key) end
    end
    return keys
end

OF.gm_coinrush_sweep_keys = sweep_keys

local sweptRound = false

local function sweep_the_level()
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.arena, "arm") then return end

    if gGlobalSyncTable.ofArenaClear == true then return end
    OF.arena.arm(true, sweep_keys(), nil)
    sweptRound = true
end

local function give_the_level_back()
    if not OF.util.is_host() then return end
    if not sweptRound then return end
    sweptRound = false
    if OF.util.asks(OF.arena, "close") then OF.arena.close() end
end

local function leader()
    local best, bestScore, bestIndex = nil, 0, nil
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_COLLECTING)) do
        local score = score_of(entry.localIndex)
        local np = gNetworkPlayers[entry.localIndex]
        if type(score) == "number" and score > 0 and np ~= nil then
            if score > bestScore
                or (score == bestScore and bestIndex ~= nil
                    and np.globalIndex < bestIndex) then
                best, bestScore, bestIndex = entry, score, np.globalIndex
            end
        end
    end
    if best == nil then return nil end
    return best, bestScore
end

local function leader_place()
    local entry = leader()
    if entry == nil then return nil end
    local m = gMarioStates[entry.localIndex]
    local np = gNetworkPlayers[entry.localIndex]
    if m == nil or np == nil or m.pos == nil then return nil end
    return { x = m.pos.x, y = m.pos.y + 170, z = m.pos.z,
             level = np.currLevelNum, area = np.currAreaIndex }, entry, m
end

local function muster_place()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return nil end
    local sumX, sumY, sumZ, count = 0, 0, 0, 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_COLLECTING)) do
        local m = gMarioStates[entry.localIndex]
        if m ~= nil and m.pos ~= nil
            and OF.gamemodes.in_place_room(here, entry.localIndex) then
            sumX, sumY, sumZ = sumX + m.pos.x, sumY + m.pos.y, sumZ + m.pos.z
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return { x = sumX / count, y = sumY / count + 400, z = sumZ / count,
             level = here.level, area = here.area }
end

local COIN_HUD_HOLD = "coinrush"
local mode = {

    lobbyRules = function() return { interactions = PLAYER_INTERACTIONS_PVP,
        coinstar = OF.rules.WIRE_MAX } end,
    key = "coinrush",
    name = "Coin Rush",
    blurb = "most coins before the clock - it rains more, and a hit spills yours",

    blurbTeams = "your side's coins are added up - most between you before the clock",
    how = "Coins rain down and each one you touch is a point.\n"
        .. "A punch spills a quarter of yours for anybody.\n"
        .. "Nothing here can kill you - a hit only costs coins.\n"
        .. "The level is cleared, and no coin star is coming.\n"
        .. "First to the target wins; on the clock, the most.\n"
        .. "In sides the coins are pooled across your side.",
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3", "desert_cage", "ice_donut", "the_plate", "aquarium", "tower" },

    room = { rules = { cannons = 0 } },

    defaultLimit = 120,

    music = SEQ_EVENT_POWERUP,

    teams = true,

    target = { auto = function(n, teams, side)
                   if teams then return 200 end
                   return OF.util.clamp(OF.gamemodes.round_to(600 / n, 10), 40, 300)
               end,
               name = "coins to win",
               asks = "How many coins take the round",
               default = TARGET_COINS,

               shownIf = { pool = "endless" },
               min = 50, max = 500, step = 50 },
    boardTitle = "Coins",

    options = {
        { key = "rain", name = "How hard it rains",
          help = "how many coins fall at a time, and how many lie there",
          choices = {
              { key = "steady", name = "normal",
                help = "five a burst, forty down" },
              { key = "thin", name = "a thin drizzle",
                help = "two a burst, sixteen down; a hit costs more" },
              { key = "heavy", name = "a downpour",
                help = "ten a burst, seventy down; the floor is never empty" },
              { key = "none", name = "not at all",
                help = "no rain - play the coins the course already has" },
          } },

        { key = "drop", name = "Where the coins end up",
          help = "whether a coin falls to the floor or hangs there",
          choices = {
              { key = "land", name = "they fall and land",
                help = "coins bounce down; the floor is where you look" },
              { key = "float", name = "they hang in the air",
                help = "coins hang where they fell; the round is climbed" },
          } },
        { key = "spill", name = "What a hit costs",
          help = "how much of a pocket a punch knocks out of them",
          choices = {
              { key = "quarter", name = "a quarter of it",
                help = "a quarter goes; it hurts and leaves you in the round" },
              { key = "none", name = "nothing at all",
                help = "a race, not a fight; a punch takes nothing" },
              { key = "half", name = "half of it",
                help = "a hit costs half; carrying a lead is a risk" },
              { key = "lot", name = "the lot",
                help = "one punch empties you; a round of ambushes" },
          } },

        { key = "pool", name = "How many coins fall in all",
          help = "a fixed pool ends the round once it is picked up",
          choices = {
              { key = "endless", name = "as many as the clock allows",
                help = "the rain keeps on until the buzzer" },
              { key = "pool", name = "five a player, then it ends",
                help = "the last coin of the pool picked up ends the round" },
          } },

        { key = "black", name = "Black coins",
          help = "one coin in ten is black and takes coins",
          choices = {
              { key = "off", name = "off",
                help = "every coin is worth what its colour says" },
              { key = "on", name = "on",
                help = "a black one takes 3 - and pays 3 during a Fever" },
          } },
        { key = "fever", name = "Coin Fever",
          help = "a calm lobby earns a spell of double coins",
          choices = {
              { key = "off", name = "off",
                help = "a coin is always worth the same" },
              { key = "on", name = "on",
                help = "everybody at full health 20 s: 15 s of double" },
          } },
        { key = "streak", name = "Same colour pays double",
          help = "the same colour again pays twice the last",
          choices = {
              { key = "off", name = "off",
                help = "every coin is worth its own colour" },
              { key = "on", name = "on",
                help = "up to 16 times a coin; a new colour starts over" },
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

    if options ~= nil then options.target = OF.gamemodes.auto_target(mode, players, options) end
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_COLLECTING)
    end

    OF.util.publish(TARGET_KEY, math.floor(tonumber(options ~= nil
        and options.target) or TARGET_COINS))

    OF.util.report(OF.rules.lend("interactions", "coinrush",
        PLAYER_INTERACTIONS_PVP))

    hold_the_coin_star()
end

function mode.on_start()

    collected = 0
    streak.kind, streak.award = nil, 0
    sinceRain = 0
    immune = 0
    lastHurt = gMarioStates[0] ~= nil and (gMarioStates[0].hurtCounter or 0) or 0
    wasAhead = false
    sinceScore = 0
    lastRoomTotal = 0
    wentDry = false
    poolSaid = false

end

function mode.pin()
    sweep_the_level()
end

function mode.late_join(localIndex)

    if localIndex == 0 then collected = 0 end
    return ROLE_COLLECTING
end

local function step_the_immunity()
    if immune > 0 then immune = immune - 1 end
end

local function room_total()
    local total = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_COLLECTING)) do
        total = total + score_of(entry.localIndex)
    end
    return total
end

local DRY_AFTER = 15 * 30

local function watch_for_drought()
    if wentDry then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.gamemodes.option_is("rain", "none") then return end

    local total = room_total()
    if total > lastRoomTotal then
        lastRoomTotal = total
        sinceScore = 0
        return
    end
    sinceScore = sinceScore + 1
    if sinceScore < DRY_AFTER then return end

    wentDry = true

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("objective", OF.lang.t("LIGHT RAIN"), OF.lang.t("The course ran dry"))
    end
end

function mode.scenery()
    OF.util.coin_fever_watch()
    watch_for_drought()
    step_the_immunity()
    local place = leader_place() or muster_place()
    if place == nil then
        OF.gamemodes.hide_token("rushlead")
        return
    end
    OF.gamemodes.mark_place("rushlead", E_MODEL_STAR, place, 0x0400)
end

function OF.gm_coinrush_marker()
    return OF.gamemodes.tokens["rushlead"]
end

local function sweep()
    OF.util.coin_sweep(ours)
    ours = {}
end

function mode.cleanup()

    OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, COIN_HUD_HOLD, false)

    let_the_coin_star_go()

    OF.rules.give_back("interactions", "coinrush")
    OF.util.coin_fever_reset()
    collected = 0
    sinceRain = 0
    immune = 0
    lastHurt = 0
    sinceScore = 0
    lastRoomTotal = 0
    wentDry = false
    poolTotal, poolLeft = nil, nil

    if OF.util.is_host() then
        OF.util.publish(TARGET_KEY, nil)
        OF.util.publish(POOL_KEY, nil)
    end
    sweep()

    give_the_level_back()
end

local LEAD_GAP = 90
local function hear_the_lead()
    local head = leader()
    local ahead = head ~= nil and head.localIndex == 0
    if ahead and not wasAhead then
        OF.gamemodes.round_sound_throttled("rushlead", LEAD_GAP, OF.sounds.WARN)
    end
    wasAhead = ahead
end

function mode.update()

    local m = gMarioStates[0]
    if m ~= nil then
        local hurt = m.hurtCounter or 0

        if hurt > lastHurt then OF.gm_coinrush_robbed() end
        lastHurt = hurt
    end

    if collected ~= score_of(0) then
        OF.util.publish_row(0, "ofScore", collected)
    end
    hear_the_lead()
end

function mode.terms()
    return OF.lang.fill("first to @ coins - the most on the clock",
        tostring(math.floor(target_coins())))
end

function mode.on_timeout()
    if OF.teams.in_play() then
        local winner = OF.teams.leader()
        OF.gamemodes.finish(OF.teams.result_text(), OF.gamemodes.team_winner(winner))
        return
    end

    local bestScore, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_COLLECTING),
        function(entry) return score_of(entry.localIndex) end)

    if bestScore == nil or bestScore <= 0 then
        OF.gamemodes.finish("Nobody found a coin.")
    elseif #names > 1 then

        OF.gamemodes.finish("Time - a draw at @ each.", nil, bestScore)
    else
        OF.gamemodes.finish("@ wins with @ coins.", names[1], names[1], bestScore)
    end
end

function mode.finish_pool()
    if OF.teams.in_play() then
        local winner = OF.teams.leader()
        OF.gamemodes.finish(OF.teams.result_text(), OF.gamemodes.team_winner(winner))
        return
    end
    local bestScore, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_COLLECTING),
        function(entry) return score_of(entry.localIndex) end)
    if bestScore == nil or bestScore <= 0 then
        OF.gamemodes.finish("The pool is gone and nobody kept a coin.")
    elseif #names > 1 then
        OF.gamemodes.finish("The pool is gone - a draw at @ each.", nil, bestScore)
    else
        OF.gamemodes.finish("The pool is gone - @ wins with @ coins.", names[1], names[1], bestScore)
    end
end

function mode.hud()

    OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, COIN_HUD_HOLD, true)

    local pool = tonumber(gGlobalSyncTable[POOL_KEY])
    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if pool ~= nil and pool <= 0 then
        state("pool", OF.lang.t("Pool empty"), { prio = 70, tone = "warn" })
        if not poolSaid and OF.util.asks(OF.hud, "banner") then
            poolSaid = true
            OF.hud.banner("roundstate", OF.lang.t("LAST COINS"), OF.lang.t("The last coin ends it"))
        end
    end
    local _, ahead = leader_place()
    if ahead ~= nil and ahead.localIndex == 0 then
        state("lead", OF.lang.t("You lead"), { prio = 60, tone = "target" })
    end
end

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "battle", name = "Coin Battle", help = "SMB3's battle: a fixed pool, a hit spills half",
      sets = { pool = "pool", spill = "half" } },
    { key = "sky", name = "Sky Coins", help = "coins hang in the air in a downpour",
      sets = { drop = "float", rain = "heavy" } },
    { key = "chaos", name = "Chaos", help = "black coins, Coin Fever and streaks",
      sets = { black = "on", fever = "on", streak = "on" } },
}

local function on_interact(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_COIN then return end

    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.my_role() ~= ROLE_COLLECTING then return end

    collected = math.max(0, collected + OF.util.coin_score(obj, streak))
end

hook_event(HOOK_ON_INTERACT, on_interact)

local function rain()
    sinceRain = sinceRain + 1
    if sinceRain < OF.util.COIN_EVERY then return end
    sinceRain = 0

    local wanted = rain_wanted()
    if OF.gamemodes.option_is("rain", "none") then
        if not wentDry then return end
        wanted = RAIN_STOPS.thin
    end

    if poolLeft ~= nil then
        if poolLeft <= 0 then return end
        local capped = {}
        for k, v in pairs(wanted) do capped[k] = v end
        capped.coins = math.min(wanted.coins or OF.util.COIN_BURST, poolLeft)
        wanted = capped
    end

    local here = OF.gamemodes.here_place(0)
    local playing = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_COLLECTING)) do
        if OF.gamemodes.in_place_room(here, entry.localIndex) then
            table.insert(playing, entry)
        end
    end

    local fell = OF.util.coin_rain(ours, playing, wanted)
    if poolLeft ~= nil and fell > 0 then
        poolLeft = math.max(0, poolLeft - fell)
        OF.util.publish(POOL_KEY, poolLeft)
    end
end

function mode.pool_spent()
    return poolLeft ~= nil and poolLeft <= 0 and OF.util.coin_live(ours) == 0
end

function mode.pool_for(count)
    return POOL_EACH * math.max(1, tonumber(count) or 1)
end

function mode.host_update()

    if poolTotal == nil and OF.gamemodes.option_now("pool") == "pool" then
        poolTotal = mode.pool_for(#OF.gamemodes.with_role(ROLE_COLLECTING))
        poolLeft = poolTotal
        OF.util.publish(POOL_KEY, poolLeft)
    end

    rain()
    OF.util.coin_fever_host(OF.gamemodes.with_role(ROLE_COLLECTING))

    if mode.pool_spent() then
        mode.finish_pool()
        return
    end

    local target = target_coins()

    if OF.teams.in_play() then
        for _, team in ipairs(OF.teams.LIST) do
            if OF.teams.score(team.key) >= target then
                OF.gamemodes.finish(OF.teams.result_text(),
                    OF.gamemodes.team_winner(team))
                return
            end
        end
        return
    end

    local best, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_COLLECTING),
        function(entry) return score_of(entry.localIndex) end)
    if type(best) ~= "number" or best < target then return end

    if #names > 1 then

        OF.gamemodes.finish("A draw at @ coins each.", nil, tostring(best))
    else
        OF.gamemodes.finish("@ won with @ coins.",
            names[1], names[1], tostring(best))
    end
end

function OF.gm_coinrush_robbed()
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.my_role() ~= ROLE_COLLECTING then return end
    if immune > 0 then return end
    if collected <= 0 then return end

    local lost = OF.gm_coinrush_drop(collected)
    immune = DROP_IMMUNE

    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return end

    local dropped = 0
    for _ = 1, lost do
        if OF.util.coin_put(ours, m.pos.x, m.pos.y + 60, m.pos.z) then
            dropped = dropped + 1
        end
    end
    if dropped == 0 then return end

    collected = collected - dropped

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("medal", "-" .. tostring(dropped), nil, { tone = "bad" })
    end
    OF.gamemodes.cue("bad")
end

hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim, interaction)
    if victim == nil or victim.playerIndex ~= 0 then return end
    if attacker == nil or attacker.playerIndex == 0 then return end
    OF.gm_coinrush_robbed()
end)

function mode.cluster()
    return OF.gamemodes.side_cluster(function(key) return OF.teams.score(key) end, target_coins())
end

mode.target_now = target_coins

OF.gamemodes.register(mode)
