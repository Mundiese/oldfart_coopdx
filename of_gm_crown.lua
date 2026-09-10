OF = OF or {}

local ROLE_HUNT = "on the hunt"
local TARGET_SECONDS = 60
local GRACE_FRAMES = 15

local CLAIM_WAIT = 30

local CROWN_KEY = "ofCrown"
local TARGET_KEY = "ofCrownTarget"
local STREAK_KEY = "ofCrownStreak"
local BOUNTY_SHARE = 0.5
local BOUNTY_CAP = 20

local GAVE_TO = "ofCrownTo"
local GAVE_SEQ = "ofCrownGave"
local DIED_SEQ = "ofCrownDied"
local held = 0
local grace = 0

local claimOut = 0
local gaveSeq = 0
local seenGave = {}

local diedSeq = 0
local diedClaimed = false
local seenDied = {}

local streak = 0

local function bounty_seconds()
    local said = gGlobalSyncTable[STREAK_KEY]
    if type(said) ~= "number" or said <= 0 then return 0 end
    return math.floor(math.min(said, BOUNTY_CAP) * BOUNTY_SHARE)
end

local function wearer_global()
    local value = gGlobalSyncTable[CROWN_KEY]
    if type(value) ~= "number" then return -1 end
    return value
end

local function wearer_local()
    local target = wearer_global()
    if target < 0 then return nil end
    return OF.util.local_from_global(target)
end

local function am_wearer()
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex == wearer_global()
end

local function place_crown()
    local wearer = wearer_local()
    local m = wearer ~= nil and gMarioStates[wearer] or nil
    local np = wearer ~= nil and gNetworkPlayers[wearer] or nil
    if m == nil or np == nil or m.pos == nil then
        OF.gamemodes.hide_token("crown")
        return
    end
    OF.gamemodes.mark_place("crown", E_MODEL_BOWLING_BALL,
        { x = m.pos.x, y = m.pos.y + 150, z = m.pos.z,
          level = np.currLevelNum, area = np.currAreaIndex }, 0x0400)
end

function OF.gm_crown_object()
    return OF.gamemodes.tokens["crown"]
end

local function target_seconds()
    local value = gGlobalSyncTable[TARGET_KEY]
    if type(value) ~= "number" or value <= 0 then return TARGET_SECONDS end
    return value
end

local function score_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil or row.ofScore == nil then return 0 end
    return row.ofScore
end

local function can_wear()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if OF.util.can_play(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local droppedAt = nil

local function next_wearer(playing)
    if playing[1] == nil then return nil end
    if droppedAt ~= nil then
        local best, bestAt = nil, nil
        for _, entry in ipairs(playing) do
            local distance = OF.gamemodes.distance_to_place(droppedAt,
                entry.localIndex)
            if distance ~= nil and (bestAt == nil or distance < bestAt) then
                best, bestAt = entry, distance
            end
        end
        if best ~= nil then return best end
    end
    return playing[math.random(#playing)]
end

local function lowest_scorer(playing, exclude)
    local best, bestScore, bestGlobal = nil, nil, nil
    for _, entry in ipairs(playing) do
        if entry.localIndex ~= exclude and entry.np ~= nil then
            local score = score_of(entry.localIndex)
            local global = entry.np.globalIndex
            if type(global) == "number"
                and (bestScore == nil or score < bestScore
                     or (score == bestScore and global < bestGlobal)) then
                best, bestScore, bestGlobal = entry, score, global
            end
        end
    end
    return best
end

function OF.gm_crown_dropped_at(spot)
    if spot ~= nil then droppedAt = spot end
    return droppedAt
end

local mode = {
    target = { name = "seconds carrying it",
               asks = "How many seconds it must be carried",
               default = 60,
               min = 20, max = 240, step = 20 },
    key = "crown",

    name = "Oddball",
    blurb = "carry it the longest - everyone else wants it",

    blurbTeams = "carry it the longest - your side keeps the seconds, so pass it on",

    aims = { [ROLE_HUNT] = "Hit whoever is carrying the ball and it is yours." },
    how = "One carries the ball, scoring a second a second.\n"
        .. "Hit the carrier and it is yours, clock and all.\n"
        .. "Taking it off a long carrier pays up to ten seconds.\n"
        .. "First to the target wins; on the clock, the most.",
    minPlayers = 2,

    maps = OF.gamemodes.ARENA_SET,

    room = { sweep = { "cannons" }, rules = { waterheal = 1, knockback = 1 } },

    unsolidInAFight = true,

    music = SEQ_LEVEL_BOSS_KOOPA,
    defaultLimit = 300,

    teams = true,

    scoreIsTime = true,
}

function mode.marked_player(localIndex)
    if wearer_local() ~= localIndex then return nil end
    return "the ball", 255, 215, 0
end

function mode.terms()
    return OF.lang.fill("first to @s carrying it",
        tostring(math.floor(target_seconds())))
end

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_HUNT)
    end

    OF.util.publish(TARGET_KEY, options.target or TARGET_SECONDS)

    OF.util.report(OF.rules.lend("interactions", "crown",
        PLAYER_INTERACTIONS_PVP))

    if #players > 0 then
        local first = nil
        local it = OF.gamemodes.deal_it(players, 1, false)
        for _, entry in ipairs(players) do
            if it[entry.localIndex] and entry.np ~= nil then first = entry end
        end
        if first == nil then first = players[1] end
        if first ~= nil and first.np ~= nil then
            OF.util.publish(CROWN_KEY, first.np.globalIndex)
        end
    end
    OF.util.publish(STREAK_KEY, 0)
end

function mode.late_join(localIndex)
    return ROLE_HUNT
end

function mode.on_start()
    held = 0
    grace = 0
    claimOut = 0
    gaveSeq = 0

    diedSeq = 0

    diedClaimed = false
    seenDied = {}
    streak = 0
    droppedAt = nil
    if am_wearer() then
        OF.notify.show("You have the ball - keep it!", "warn", 6)
    else
        OF.notify.show("Take the ball off whoever is carrying it", "info", 6)
    end
end

function mode.cleanup()

    OF.rules.give_back("interactions", "crown")
    held = 0
    grace = 0
    claimOut = 0
    gaveSeq = 0
    seenGave = {}

    diedClaimed = false
    seenDied = {}

    droppedAt = nil
    streak = 0
    if OF.util.is_host() then
        OF.util.publish(CROWN_KEY, -1)
        OF.util.publish(TARGET_KEY, nil)
        OF.util.publish(STREAK_KEY, nil)
    end
end

local FULL_HEALTH = 0x880

local function hold_the_meter()
    if OF.gamemodes.role(0) ~= ROLE_HUNT then return end
    if not OF.util.can_play(0) then return end
    local m = gMarioStates[0]
    if m == nil then return end
    if (m.health or 0) < FULL_HEALTH then m.health = FULL_HEALTH end
    m.hurtCounter = 0
    if m.pos ~= nil then m.peakHeight = m.pos.y end
end

local function step_the_waits()
    if grace > 0 then grace = grace - 1 end
    if claimOut > 0 then claimOut = claimOut - 1 end
end

function mode.update()

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then hold_the_meter() end
    if not am_wearer() then return end
    if OF.gamemodes.role(0) ~= ROLE_HUNT then return end

    held = held + 1

    if held % 30 == 0 then
        OF.util.publish_row(0, "ofScore", math.floor(held / 30))
    end
end

local function on_pvp_attack(attacker, victim, interaction)
    if victim == nil or attacker == nil then return end
    if victim.playerIndex ~= 0 then return end
    if not OF.gamemodes.is_running() then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "crown" then return end
    if not am_wearer() then return end
    if grace > 0 then return end

    if claimOut > 0 then return end
    if OF.gamemodes.role(0) ~= ROLE_HUNT then return end

    local takerLocal = attacker.playerIndex
    if takerLocal == nil or takerLocal == 0 then return end
    if OF.gamemodes.role(takerLocal) ~= ROLE_HUNT then return end

    local np = gNetworkPlayers[takerLocal]
    if np == nil or not np.connected then return end

    grace = GRACE_FRAMES
    claimOut = CLAIM_WAIT
    gaveSeq = gaveSeq + 1
    OF.util.publish_row(0, GAVE_TO, np.globalIndex)
    OF.util.publish_row(0, GAVE_SEQ, gaveSeq)
end

hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not OF.gamemodes.is_running() then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "crown" then return end
    if not am_wearer() then return end
    if diedClaimed then return end
    if OF.gamemodes.role(0) ~= ROLE_HUNT then return end

    if not OF.util.can_play(0) then return end

    diedClaimed = true
    diedSeq = diedSeq + 1
    OF.util.publish_row(0, DIED_SEQ, diedSeq)
end)

function mode.host_update()
    local playing = can_wear()

    local wearer = wearer_local()
    local stillIn = false
    for _, entry in ipairs(playing) do
        if entry.localIndex == wearer then stillIn = true end
    end

    if stillIn and wearer ~= nil then
        local m = gMarioStates[wearer]
        local np = gNetworkPlayers[wearer]
        if m ~= nil and m.pos ~= nil and np ~= nil then
            droppedAt = { x = m.pos.x, y = m.pos.y, z = m.pos.z,
                          level = np.currLevelNum, area = np.currAreaIndex }
        end
    end

    streak = streak + 1
    if streak == 1 or streak % 30 == 0 then
        OF.util.publish(STREAK_KEY, math.floor(streak / 30))
    end

    local pick = (not stillIn) and next_wearer(playing) or nil
    if pick ~= nil then
        streak = 0
        OF.util.publish(CROWN_KEY, pick.np.globalIndex)
        OF.notify.send_all("The ball was dropped - @ has it now", "warn", 4,
            OF.util.plain(pick.np.name))
        wearer = pick.localIndex
    end

    local movedOnDeath = false
    if wearer ~= nil then
        local row = gPlayerSyncTable[wearer]
        local said = row ~= nil and row[DIED_SEQ] or 0
        if type(said) ~= "number" then said = 0 end
        if seenDied[wearer] == nil then
            seenDied[wearer] = said
        elseif said > seenDied[wearer] then
            seenDied[wearer] = said
            local poorest = lowest_scorer(playing, wearer)

            if poorest ~= nil then
                local np = gNetworkPlayers[wearer]
                streak = 0
                movedOnDeath = true
                OF.util.publish(CROWN_KEY, poorest.np.globalIndex)
                OF.notify.send_all("@ died with the ball - @ has it now",
                    "warn", 4,
                    OF.util.plain(np ~= nil and np.name or ""),
                    OF.util.plain(poorest.np.name))
                wearer = poorest.localIndex
            end
        end
    end

    if wearer ~= nil and not movedOnDeath then
        local row = gPlayerSyncTable[wearer]
        local said = row ~= nil and row[GAVE_SEQ] or 0
        if type(said) ~= "number" then said = 0 end

        if seenGave[wearer] == nil then
            seenGave[wearer] = said
        elseif said > seenGave[wearer] then
            seenGave[wearer] = said
            local toGlobal = row[GAVE_TO]
            local toLocal = type(toGlobal) == "number"
                and OF.util.local_from_global(toGlobal) or nil

            if toLocal ~= nil and toLocal ~= wearer
                and OF.gamemodes.role(toLocal) == ROLE_HUNT then

                streak = 0
                OF.util.publish(CROWN_KEY, toGlobal)
            end
        end
    end

    local target = target_seconds()

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

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if score_of(entry.localIndex) >= target then
            OF.gamemodes.finish("@ carried the ball longest.", entry.np.name, entry.np.name)
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
        function(entry) return score_of(entry.localIndex) end)
    if bestScore == nil or bestScore <= 0 then
        OF.gamemodes.finish("Nobody held the ball.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, bestScore)
    else
        OF.gamemodes.finish("@ wins with @ seconds.", names[1], names[1], bestScore)
    end
end

hook_on_sync_table_change(gGlobalSyncTable, CROWN_KEY, 0, function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair(CROWN_KEY) then return end

    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "crown" then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end

    claimOut = 0

    if newVal == np.globalIndex then

        grace = GRACE_FRAMES

        diedClaimed = false

        local bounty = bounty_seconds()
        if bounty > 0 then
            held = held + bounty * 30
            OF.util.publish_row(0, "ofScore", math.floor(held / 30))
            OF.notify.show("The ball is yours - and @ seconds with it!",
                "good", 4, tostring(bounty))
        else
            OF.notify.show("The ball is yours!", "good", 3)
        end
        OF.sounds.play(OF.sounds.TICK)
    elseif oldVal == np.globalIndex then
        OF.notify.show("They took the ball", "bad", 3)
    end
end)

function mode.hud()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local target = target_seconds()

    local wearer = wearer_local()
    local wm = wearer ~= nil and gMarioStates[wearer] or nil
    if wm ~= nil and wm.pos ~= nil then
        OF.util.world_arrow({ x = wm.pos.x, y = wm.pos.y + 270, z = wm.pos.z },
            200, 5, 255, 215, 0, 230)
    end

    local bounty = bounty_seconds()
    if bounty > 0 then
        if am_wearer() then
            OF.util.banner(OF.lang.fill("THE BALL IS HEAVY - worth @s to take off you",
                tostring(bounty)), 0.90, 255, 140, 60)
        else
            OF.util.banner(OF.lang.fill("Take it and you take @s with it",
                tostring(bounty)), 0.90, 255, 200, 90)
        end
    end

    local text, r, g, b
    if am_wearer() then
        text = OF.lang.fill("YOU HAVE THE BALL   -   @ / @s",
            math.floor(held / 30), target)
        r, g, b = 255, 215, 0
    else
        local wearer = wearer_local()
        if wearer == nil then
            text = OF.lang.t("Nobody has the ball")
            r, g, b = 200, 200, 200
        else
            local distance = OF.gamemodes.distance(0, wearer)
            local name = OF.util.plain(gNetworkPlayers[wearer].name)
            if distance == nil then
                text = OF.lang.fill("@ has the ball - somewhere else", name)
                r, g, b = 200, 160, 160
            else
                text = OF.lang.fill("@ has the ball - @ away", name,
                    math.floor(distance))
                r, g, b = 230, 230, 230
            end
        end
    end

    OF.util.banner(text, 0.95, r, g, b)

    local board = OF.gamemodes.score_board(ROLE_HUNT, score_of,
        function(s) return s .. "s" end)
    OF.util.board(screenWidth * 0.03, screenHeight * 0.24,
        OF.lang.t("Ball time"), board, { column = 130 })
end

function mode.scenery()
    step_the_waits()
    place_crown()
end

OF.gamemodes.register(mode)
