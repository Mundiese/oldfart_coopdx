OF = OF or {}

local AT_KEY    = "ofBankAt"
local LEVEL_KEY = "ofBankLevel"
local AREA_KEY  = "ofBankArea"
local HELD_KEY  = "ofBankHeld"
local ROLE_RUNNING = "running"
local BANK_RADIUS = 300

local TARGET_COINS = 100

local held = 0
local grace = 0

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

    maps = OF.gamemodes.ARENA_SET,

    room = { rules = { cannons = 0 } },

    defaultLimit = 180,

    music = SEQ_LEVEL_SLIDE,
    teams = true,
    target = { name = "coins to bank",
               asks = "How many banked coins win the round",
               default = TARGET_COINS,
               min = 10, max = 100, step = 10 },
}

function mode.setup(players, options)
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
    grace = 0
    ours = {}
    sinceRain = 0
    OF.util.publish_row(0, HELD_KEY, 0)
    OF.util.publish_row(0, "ofScore", 0)
end

local function step_the_grace()
    if grace > 0 then grace = grace - 1 end
end

function mode.scenery()
    step_the_grace()
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

    held = held + OF.util.coin_worth(obj)
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
    OF.notify.show("Out of the round - @ coin(s) left on the floor",
        "warn", 5, tostring(lost))
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
    OF.notify.show("Robbed - @ coin(s) on the floor", "bad", 4, tostring(lose))
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
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
    OF.util.coin_rain(ours, playing)
end
function mode.update()

    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if not OF.util.can_play(0) then return end
    if held <= 0 then return end

    if OF.gamemodes.at_place(bank(), BANK_RADIUS) then
        OF.util.publish_row(0, "ofScore", banked(0) + held)
        OF.notify.show("Banked @ - safe for good", "good", 4, tostring(held))
        OF.sounds.play(SOUND_MENU_COLLECT_SECRET)
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
            OF.gamemodes.finish("@ banked @.", entry.np.name, entry.np.name,
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
        OF.gamemodes.finish("@ banked @.", names[1], names[1], tostring(best))
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
    OF.util.coin_sweep(ours)
    ours = {}
    held = 0
    grace = 0
    sinceRain = 0

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

function mode.hud()

    OF.util.hud_hide(HUD_DISPLAY_FLAG_COIN_COUNT, COIN_HUD_HOLD, true)

    local at = bank()
    local distance = at ~= nil and OF.gamemodes.distance_to_place(at) or nil

    local text
    local r, g, b = 255, 255, 255
    if held <= 0 then
        text = OF.lang.fill("@ banked of @   -   nothing to lose",
            tostring(banked(0)), tostring(target_coins()))
        r, g, b = 200, 220, 255
    elseif distance == nil then
        text = OF.lang.fill("Carrying @   -   the bank is in another area",
            tostring(held))
        r, g, b = 255, 160, 160
    elseif distance <= BANK_RADIUS then
        text = OF.lang.fill("@ banked of @", tostring(banked(0)),
            tostring(target_coins()))
        r, g, b = 140, 255, 160
    else

        text = OF.lang.fill("Carrying @   -   @", tostring(held),
            OF.lang.fill("@ units home   -   @ banked",
                string.format("%.0f", distance - BANK_RADIUS),
                tostring(banked(0))))
        r, g, b = 255, 215, 120
    end

    local fatEntry, fatHeld = fattest()
    local under = nil
    if fatEntry ~= nil and fatEntry.localIndex == 0 then
        under = { text = OF.lang.fill(
            "You are carrying the most - @ coin(s) for whoever lands a hit",
            tostring(fatHeld)), scale = 0.8 }
    elseif fatEntry ~= nil then
        under = { text = OF.lang.fill("@ is carrying the most - @ coin(s)",
            OF.util.plain(fatEntry.np.name), tostring(fatHeld)), scale = 0.8 }
    end

    OF.util.banner(text, 1.0, r, g, b, 255, { under = under })

    local board = OF.gamemodes.score_board(ROLE_RUNNING, banked,
        function(score, entry)
            local pocket = carrying(entry.localIndex)
            if pocket <= 0 then return tostring(score) end
            return OF.lang.fill("@ +@", tostring(score), tostring(pocket))
        end)
    OF.util.board(djui_hud_get_screen_width() * 0.03,
        djui_hud_get_screen_height() * 0.24,
        OF.lang.t("Banked"), board, { width = 190, column = 120 })
end

OF.gamemodes.register(mode)
