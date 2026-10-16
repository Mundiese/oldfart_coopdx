OF = OF or {}

local AT_KEY    = "ofBankAt"
local LEVEL_KEY = "ofBankLevel"
local AREA_KEY  = "ofBankArea"
local HELD_KEY  = "ofBankHeld"
local ROLE_RUNNING = "running"
local BANK_RADIUS = 300

local TARGET_COINS = 100

local RAIN_STOPS = {
    steady = {},
    thin = { coins = 2, max = 16 },
    heavy = { coins = 10, max = 70 },
}

local function rain_wanted()
    return RAIN_STOPS[OF.gamemodes.option_now("rain") or "steady"]
        or RAIN_STOPS.steady
end

local held = 0

local streak = { kind = nil, award = 0 }
local grace = 0

local othersBanked = nil

local ours = {}

local sinceRain = 0

local drop_pocket = nil

local function pack_board(target, pos)
    if pos == nil then return string.format("%.0f", target) end
    return string.format("%.0f %.0f %.0f %.0f", target, pos.x, pos.y, pos.z)
end

local function bank()
    local text = gGlobalSyncTable[AT_KEY]
    if type(text) ~= "string" or text == "" then return nil end
    local x, y, z = text:match(
        "^%-?[%d%.]+ (%-?[%d%.]+) (%-?[%d%.]+) (%-?[%d%.]+)$")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if x == nil or y == nil or z == nil then return nil end
    return {
        x = x, y = y, z = z,
        level = gGlobalSyncTable[LEVEL_KEY],
        area = gGlobalSyncTable[AREA_KEY],
    }
end

local WORTH_STOPS = { flat = 1.0, rich = 1.5, double = 2.0 }
local WORTH_DEFAULT = "flat"
local function deposit_worth(held)
    local said = WORTH_STOPS[
        OF.gamemodes.option_now("worth") or WORTH_DEFAULT]
        or WORTH_STOPS[WORTH_DEFAULT]

    return math.max(1, math.ceil(held * said))
end

local function banked(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return (row ~= nil and row.ofScore) or 0
end

local function carrying(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local value = row ~= nil and row[HELD_KEY] or 0
    if type(value) ~= "number" or value < 0 then return 0 end
    return value
end

local function target_coins()
    local text = gGlobalSyncTable[AT_KEY]
    if type(text) ~= "string" then return TARGET_COINS end
    local value = tonumber(text:match("^(%-?[%d%.]+)"))
    if type(value) ~= "number" or value <= 0 then return TARGET_COINS end
    return math.floor(value)
end

local function runners()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RUNNING)) do
        if OF.util.can_play(entry.localIndex) then table.insert(list, entry) end
    end
    return list
end

local function hold_the_coin_star()
    if not OF.util.asks(OF.rules, "lend") then return end
    OF.util.report(OF.rules.lend("coinstar", "bank", OF.rules.WIRE_MAX))
end

local function let_the_coin_star_go()
    if not OF.util.asks(OF.rules, "give_back") then return end
    OF.rules.give_back("coinstar", "bank")
end

local function hold_the_fighting()
    if not OF.util.asks(OF.rules, "lend") then return end
    OF.util.report(OF.rules.lend("interactions", "bank",
        PLAYER_INTERACTIONS_PVP))
end

local function let_the_fighting_go()
    if not OF.util.asks(OF.rules, "give_back") then return end
    OF.rules.give_back("interactions", "bank")
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

OF.gm_bank_sweep_keys = sweep_keys

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

local COIN_HUD_HOLD = "bank"
local mode = {

    lobbyRules = function() return { interactions = PLAYER_INTERACTIONS_PVP,
        coinstar = OF.rules.WIRE_MAX } end,
    key = "bank",
    name = "The Bank",
    blurb = "coins are a loan until you carry them home",
    blurbTeams = "carry them home - the side that banks the most wins",
    how = "Coins are everywhere and more rain down as you play.\n"
        .. "None of them are yours until you carry them home.\n"
        .. "Carry them to the flag. Banked is safe for good.\n"
        .. "A punch bursts a quarter of your pocket out.\n"
        .. "Nothing here can kill you - a hit only costs coins.\n"
        .. "The one carrying the most is the one worth hitting.\n"
        .. "The level is cleared, and no coin star is coming.\n"
        .. "First to the target wins; on the clock, the most.",
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3", "desert_cage", "ice_donut", "the_plate", "aquarium" },

    room = { rules = { cannons = 0 } },

    defaultLimit = 180,

    music = SEQ_LEVEL_SLIDE,
    teams = true,
    boardTitle = "Banked",

    target = { auto = function(n, teams, side)
                   local worth = WORTH_STOPS[OF.gamemodes.option_showing("bank", "worth") or WORTH_DEFAULT]
                       or 1
                   if teams then return math.floor(OF.gamemodes.round_to(250 * worth, 10)) end
                   return math.floor(OF.util.clamp(OF.gamemodes.round_to(800 / n * worth, 10), 50, 300))
               end,
               name = "coins to bank",
               asks = "How many banked coins win the round",
               default = TARGET_COINS,
               min = 10, max = 300, step = 10 },

    options = {
        { key = "rain", name = "How hard it rains",
          help = "how many coins fall at a time, and how many lie there",
          choices = {
              { key = "steady", name = "normal",
                help = "five a burst, forty down" },
              { key = "thin", name = "a thin drizzle",
                help = "two a burst, sixteen down; a pocket is slow to fill" },
              { key = "heavy", name = "a downpour",
                help = "ten a burst, seventy down; pockets fill on the way" },
          } },

        { key = "spill", name = "What a hit costs",
          help = "how much of an unbanked pocket a punch knocks out",
          choices = {
              { key = "quarter", name = "a quarter of the pocket",
                help = "a quarter goes; enough that a big pocket is a decision" },
              { key = "none", name = "nothing at all",
                help = "your pocket stays yours; the walk home is safe" },
              { key = "half", name = "half of it",
                help = "half a pocket goes; the walk home is a gamble" },
              { key = "lot", name = "the lot",
                help = "one punch and the walk was for nothing; bank early" },
          } },

        { key = "worth", name = "What a deposit is worth",
          help = "a multiplier on every deposit; the auto goal grows with it",
          choices = {
              { key = "flat", name = "x1",
                help = "one coin banked is one coin scored" },
              { key = "rich", name = "x1.5",
                help = "the walk home pays for itself; a big pocket is worth it" },
              { key = "double", name = "x2",
                help = "holding pays: two banked late beat four one at a time" },
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

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "heist", name = "Heist", help = "a hit takes the lot; a deposit pays double",
      sets = { spill = "lot", worth = "double" } },
    { key = "chaos", name = "Chaos", help = "a downpour, black coins, Coin Fever and streaks",
      sets = { rain = "heavy", black = "on", fever = "on", streak = "on" } },
}

function mode.setup(players, options)

    if options ~= nil then options.target = OF.gamemodes.auto_target(mode, players, options) end
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_RUNNING)
    end

    OF.util.publish(AT_KEY, pack_board(math.floor(tonumber(options ~= nil
        and options.target) or TARGET_COINS), nil))

    hold_the_fighting()
    hold_the_coin_star()
end

function mode.pin()
    local here = OF.gamemodes.here_place(0)
    if here == nil then return end
    OF.util.publish(LEVEL_KEY, here.level)
    OF.util.publish(AREA_KEY, here.area)

    OF.util.publish(AT_KEY, pack_board(target_coins(), here))

    sweep_the_level()
end

function mode.late_join(localIndex)
    return ROLE_RUNNING
end

function mode.on_start()
    held = 0
    streak.kind, streak.award = nil, 0
    grace = 0
    ours = {}
    sinceRain = 0
    othersBanked = nil
    OF.util.publish_row(0, HELD_KEY, 0)
    OF.util.publish_row(0, "ofScore", 0)
end

local function step_the_grace()
    if grace > 0 then grace = grace - 1 end
end

local MILESTONES = 4
local function milestone(score, whole)
    if type(score) ~= "number" or type(whole) ~= "number" or whole <= 0 then
        return 0
    end
    local step = math.floor(score * MILESTONES / whole)
    if step < 0 then return 0 end
    if step > MILESTONES - 1 then return MILESTONES - 1 end
    return step
end

local function hear_the_deposits()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        othersBanked = nil
        return
    end
    if OF.teams.in_play() then
        OF.gamemodes.hear_sides(OF.teams.score("red"), OF.teams.score("blue"))
        return
    end
    local target = target_coins()
    local first = othersBanked == nil
    othersBanked = othersBanked or {}
    local passed = false
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_RUNNING)) do
        local np = gNetworkPlayers[entry.localIndex]
        if entry.localIndex ~= 0 and np ~= nil then
            local step = milestone(banked(entry.localIndex), target)
            local was = othersBanked[np.globalIndex]
            if not first and step > (was or 0) then passed = true end
            othersBanked[np.globalIndex] = step
        end
    end
    if passed then OF.gamemodes.cue("chime") end
end

function mode.scenery()
    OF.util.coin_fever_watch()
    step_the_grace()
    hear_the_deposits()
    OF.gamemodes.mark_flag("bank", bank())
    drop_pocket()
end

local function on_interact(m, obj, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_COIN then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.my_role() ~= ROLE_RUNNING then return end
    if not OF.util.can_play(0) then return end

    held = math.max(0, held + OF.util.coin_score(obj, streak))
    OF.util.publish_row(0, HELD_KEY, held)
end

hook_event(HOOK_ON_INTERACT, on_interact)

local function spill(count)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil or count <= 0 then return end
    for step = 1, count do
        local angle = step * (2 * math.pi / count)
        OF.util.coin_put(ours, m.pos.x + math.cos(angle) * 90, m.pos.y + 60,
            m.pos.z + math.sin(angle) * 90, OF.util.COIN_KINDS[1])
    end
end

drop_pocket = function()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.my_role() ~= ROLE_RUNNING then return end
    if held <= 0 or OF.util.can_play(0) then return end

    local lost = held
    held = 0
    OF.util.publish_row(0, HELD_KEY, 0)

    spill(lost)
end

local function on_pvp_attack(attacker, victim)
    if victim == nil or victim.playerIndex ~= 0 then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if grace > 0 or held <= 0 then return end
    grace = OF.gm_coinrush_drop_grace()

    local lose = OF.gm_coinrush_drop(held)
    held = held - lose
    OF.util.publish_row(0, HELD_KEY, held)

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("medal", "-" .. tostring(lose), nil, { tone = "bad" })
    end
    OF.gamemodes.cue("bad")
    spill(lose)
end

hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)

local function rain()
    local here = OF.gamemodes.here_place(0)
    local playing = {}
    for _, entry in ipairs(runners()) do
        if OF.gamemodes.in_place_room(here, entry.localIndex) then
            table.insert(playing, entry)
        end
    end
    OF.util.coin_rain(ours, playing, rain_wanted())
end
function mode.update()

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    if held <= 0 then return end

    if OF.gamemodes.at_place(bank(), BANK_RADIUS) then
        local worth = deposit_worth(held)
        OF.util.publish_row(0, "ofScore", banked(0) + worth)

        if OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("medal", "+" .. tostring(worth), nil, { tone = "good" })
        end

        if not OF.teams.in_play() then OF.gamemodes.cue("good") end
        held = 0
        OF.util.publish_row(0, HELD_KEY, 0)
    end
end

function mode.host_update()

    sinceRain = sinceRain + 1
    if sinceRain >= OF.util.COIN_EVERY then
        sinceRain = 0
        rain()
    end
    OF.util.coin_fever_host(OF.gamemodes.with_role(ROLE_RUNNING))

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

    for _, entry in ipairs(runners()) do
        if banked(entry.localIndex) >= target then
            OF.gamemodes.finish("@ won - @ banked.", entry.np.name, entry.np.name,
                tostring(banked(entry.localIndex)))
            return
        end
    end
end

function mode.on_timeout()
    if OF.teams.in_play() then
        OF.gamemodes.finish(OF.teams.result_text(),
            OF.gamemodes.team_winner(OF.teams.leader()))
        return
    end

    local best, names = OF.gamemodes.best_of(
        OF.gamemodes.with_role(ROLE_RUNNING),
        function(entry) return banked(entry.localIndex) end)
    if best == nil or best <= 0 then
        OF.gamemodes.finish("Nobody banked anything.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ banked.", nil, tostring(best))
    else
        OF.gamemodes.finish("@ won - @ banked.", names[1], names[1], tostring(best))
    end
end

function mode.terms()
    return OF.lang.fill("first to @ banked - the most on the clock",
        tostring(target_coins()))
end

function mode.cleanup()

    OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, COIN_HUD_HOLD, false)

    let_the_coin_star_go()
    let_the_fighting_go()
    OF.util.coin_fever_reset()
    OF.util.coin_sweep(ours)
    ours = {}
    held = 0
    grace = 0
    sinceRain = 0
    othersBanked = nil

    give_the_level_back()

    if OF.util.is_host() then
        OF.util.publish(AT_KEY, nil)
        OF.util.publish(LEVEL_KEY, nil)
        OF.util.publish(AREA_KEY, nil)
    end

    OF.util.publish_row(0, HELD_KEY, nil)
end

local function fattest()
    local bestEntry, bestHeld = nil, 0
    for _, entry in ipairs(runners()) do
        local pocket = carrying(entry.localIndex)
        if pocket > bestHeld then bestEntry, bestHeld = entry, pocket end
    end
    if bestEntry == nil then return nil, 0 end
    return bestEntry, bestHeld
end

function mode.draw_ring(at, distance)
    if at == nil or distance == nil then return false end

    if OF.util.asks(OF.markers, "ring") then return true end
    local inside = distance <= BANK_RADIUS
    local r, g, b = 255, 210, 80
    if inside then r, g, b = 140, 255, 160 end
    OF.util.zone_ring({ x = at.x, y = (at.y or 0) + 4, z = at.z }, BANK_RADIUS, 40,
        inside and 4 or 3, r, g, b, 220)
    return true
end

local bankTarget = { id = "bank", label = "Bank", tone = "target",
    ring = { radius = BANK_RADIUS } }
local bankList = { bankTarget }
function mode.targets(viewer)
    local _ = viewer
    local at = bank()
    if at == nil or OF.gamemodes.distance_to_place(at) == nil then return nil end
    bankTarget.pos = at
    bankTarget.priority = held > 0 and 95 or 40
    bankTarget.compass = held > 0 and "offscreen" or "never"
    return bankList
end

function mode.hud()

    OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, COIN_HUD_HOLD, true)

    local at = bank()
    local distance = at ~= nil and OF.gamemodes.distance_to_place(at) or nil
    mode.draw_ring(at, distance)

    if OF.util.asks(OF.hud, "state_line") and held > 0 then
        local fatEntry = fattest()
        if fatEntry ~= nil and fatEntry.localIndex == 0 then
            OF.hud.state_line("wanted", OF.lang.t("Most wanted"), { prio = 60, tone = "warn",
                figure = held })
        else
            OF.hud.state_line("carry", nil, { prio = 50,
                icons = { { icon = "coin", count = held } } })
        end
    end
    local _ = distance
end

function mode.milestone_of(score, whole)
    return milestone(score, whole)
end

mode.target_now = target_coins

OF.gamemodes.register(mode)
