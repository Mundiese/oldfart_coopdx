OF = OF or {}

local ROLE_COLLECTING = "collecting"
local collected = 0

local DROP_SHARE = 0.25

local DROP_MAX_LOW = 2
local DROP_MAX_HIGH = 8

local DROP_IMMUNE = 60

function OF.gm_coinrush_drop(carrying)
    if type(carrying) ~= "number" or carrying < 1 then return 0 end
    local ceiling = OF.util.random_int(DROP_MAX_LOW, DROP_MAX_HIGH)
    return math.floor(OF.util.clamp(
        math.ceil(carrying * DROP_SHARE), 1, math.min(ceiling, carrying)))
end

function OF.gm_coinrush_drop_grace()
    return DROP_IMMUNE
end

function OF.gm_coinrush_drop_ends()
    return DROP_MAX_LOW, DROP_MAX_HIGH
end

local TARGET_COINS = 150

local TARGET_KEY = "ofRushTarget"
local sinceRain = 0
local immune = 0
local lastHurt = 0

local ours = {}

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

    maps = OF.gamemodes.ARENA_SET,

    room = { rules = { cannons = 0 } },

    defaultLimit = 120,

    music = SEQ_EVENT_POWERUP,

    teams = true,

    target = { name = "coins to win",
               asks = "How many coins take the round",
               default = TARGET_COINS,
               min = 50, max = 500, step = 50 },
}

function mode.setup(players, options)
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
    sinceRain = 0
    immune = 0
    lastHurt = gMarioStates[0] ~= nil and (gMarioStates[0].hurtCounter or 0) or 0
    OF.notify.show("Grab every coin you can - and hold on to them", "good", 5)
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

function mode.scenery()
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
    collected = 0
    sinceRain = 0
    immune = 0
    lastHurt = 0

    if OF.util.is_host() then OF.util.publish(TARGET_KEY, nil) end
    sweep()

    give_the_level_back()
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

function mode.hud()

    OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, COIN_HUD_HOLD, true)

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local mine = score_of(0)
    local target = target_coins()
    local scale = 1.1

    local text = OF.teams.in_play()
        and OF.lang.fill("@ coins", tostring(mine))
        or OF.lang.fill("@ / @ coins", tostring(mine), tostring(target))

    local unders = {}
    if OF.teams.in_play() then
        local plain, segments = OF.teams.score_banner(
            OF.teams.score("red"), OF.teams.score("blue"))
        table.insert(unders, { text = plain, segments = segments, scale = 0.85 })

        table.insert(unders, { text = OF.lang.fill("first side to @ coins",
            tostring(target)), scale = 0.8, r = 200, g = 200, b = 200 })
    end

    local place, ahead, leadMario = leader_place()
    local aheadScore = ahead ~= nil and score_of(ahead.localIndex) or 0
    if ahead ~= nil then
        if ahead.localIndex == 0 then
            table.insert(unders, { text = OF.lang.t(
                "You are ahead - everybody is running at you"),
                scale = 0.8, r = 255, g = 170, b = 80 })
        elseif ahead.np ~= nil then
            table.insert(unders, { text = OF.lang.fill(
                "@ is ahead with @ - a hit spills a quarter",
                ahead.np.name, tostring(aheadScore)),
                scale = 0.8, r = 255, g = 215, b = 120 })
        end
    end

    if not OF.teams.in_play() then
        local _, headScore = leader()

        if type(headScore) == "number" and headScore > 0 then
            local left = math.floor(target - headScore)

            if left > 0 then
                table.insert(unders, { text = OF.lang.fill(
                    "another @ coins and the round is over", tostring(left)),
                    scale = 0.8, r = 200, g = 200, b = 200 })
            end
        end
    end

    OF.util.banner(text, scale, 255, 220, 90, 255,
        { under = #unders > 0 and unders or nil })

    if ahead ~= nil and ahead.localIndex ~= 0 and leadMario ~= nil
        and OF.gamemodes.in_place_room(place) then
        OF.util.world_arrow({ x = leadMario.pos.x, y = leadMario.pos.y + 290,
            z = leadMario.pos.z }, 200, 5, 255, 215, 0, 230)
    end

    local board = OF.gamemodes.score_board(ROLE_COLLECTING, score_of, tostring)
    OF.util.board(screenWidth * 0.03, screenHeight * 0.24,
        OF.lang.t("Coins"), board, { width = 180, column = 120 })
end

local function on_interact(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_COIN then return end

    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.my_role() ~= ROLE_COLLECTING then return end

    collected = collected + OF.util.coin_worth(obj)
end

hook_event(HOOK_ON_INTERACT, on_interact)

local function rain()
    sinceRain = sinceRain + 1
    if sinceRain < OF.util.COIN_EVERY then return end
    sinceRain = 0

    local here = OF.gamemodes.here_place(0)
    local playing = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_COLLECTING)) do
        if OF.gamemodes.in_place_room(here, entry.localIndex) then
            table.insert(playing, entry)
        end
    end

    OF.util.coin_rain(ours, playing)
end

function mode.host_update()
    rain()

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
        OF.gamemodes.finish("@ gets there first with @ coins.",
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
    OF.notify.show("@ coins knocked loose - get them back", "bad", 3, dropped)
    OF.sounds.play(OF.sounds.WARN)
end

hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim, interaction)
    if victim == nil or victim.playerIndex ~= 0 then return end
    if attacker == nil or attacker.playerIndex == 0 then return end
    OF.gm_coinrush_robbed()
end)

OF.gamemodes.register(mode)
