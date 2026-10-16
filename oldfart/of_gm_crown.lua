OF = OF or {}

local ROLE_HUNT = "on the hunt"
local ROLE_OUT = "out"
local CUT_STOPS = { never = nil, thirty = 30, twenty = 20 }

local cutsDone = 0

local TARGET_SECONDS = 60
local GRACE_FRAMES = 15

local CLAIM_WAIT = 30

local TARGET_KEY = "ofCrownTarget"
local BOUNTY_SHARE = 0.5
local BOUNTY_CAP = 20

local GAVE_TO = "ofCrownTo"
local GAVE_SEQ = "ofCrownGave"
local DIED_SEQ = "ofCrownDied"
local CROWNS_PER_GROUP = 5
local MAX_CROWNS = 3

local CROWN_KEYS = { "ofCrown", "ofCrown2", "ofCrown3" }
local STREAK_KEYS = { "ofCrownStreak", "ofCrownStreak2", "ofCrownStreak3" }

local NEED_KEYS = { "ofCrownNeed", "ofCrownNeed2", "ofCrownNeed3" }

local ACTIVE_KEY = "ofCrownActive"
local SHINE_DROP_SECONDS = 5

local SHINE_FLOOR_SECONDS = 10

local held = 0
local grace = 0

local heardCrown = { near = false }

local claimOut = 0
local gaveSeq = 0

local seenGave = { {}, {}, {} }

local diedSeq = 0
local diedClaimed = false
local seenDied = { {}, {}, {} }

local streak = { 0, 0, 0 }

local function active_count()
    local said = gGlobalSyncTable[ACTIVE_KEY]
    if type(said) ~= "number" or said < 1 then return 1 end
    return math.min(MAX_CROWNS, math.floor(said))
end

local function bounty_seconds(slot)
    local said = gGlobalSyncTable[STREAK_KEYS[slot]]
    if type(said) ~= "number" or said <= 0 then return 0 end
    return math.floor(math.min(said, BOUNTY_CAP) * BOUNTY_SHARE)
end

local function need_seconds(slot)
    local said = gGlobalSyncTable[NEED_KEYS[slot]]
    if type(said) ~= "number" or said <= 0 then return nil end
    return said
end

local function held_seconds(slot)
    local said = gGlobalSyncTable[STREAK_KEYS[slot]]
    if type(said) ~= "number" or said < 0 then return 0 end
    return said
end

local function wearer_global(slot)
    local value = gGlobalSyncTable[CROWN_KEYS[slot]]
    if type(value) ~= "number" then return -1 end
    return value
end

local function wearer_local(slot)
    local target = wearer_global(slot)
    if target < 0 then return nil end
    return OF.util.local_from_global(target)
end

local function already_carrying(globalIndex, exceptSlot)
    for slot = 1, active_count() do
        if slot ~= exceptSlot and wearer_global(slot) == globalIndex then
            return true
        end
    end
    return false
end

local CARRY_STOPS = { even = 1.0, quicker = 1.15 }
local CARRY_DEFAULT = "even"
local WALK_TARGET = 32

local function carry_speed()
    local stop = CARRY_STOPS[OF.gamemodes.option_now("carry") or CARRY_DEFAULT]
    if stop == nil then return CARRY_STOPS[CARRY_DEFAULT] end
    return stop
end

OF.gm_crown_carry_speed = carry_speed

local function am_wearer(slot)
    local np = gNetworkPlayers[0]
    return np ~= nil and np.globalIndex == wearer_global(slot)
end

local function my_slot()
    for slot = 1, active_count() do
        if am_wearer(slot) then return slot end
    end
    return nil
end

local function crowns_for(numPlayers, several)
    if not several then return 1 end
    return math.max(1, math.min(MAX_CROWNS,
        math.floor((numPlayers or 0) / CROWNS_PER_GROUP)))
end

local function crown_count(numPlayers)
    return crowns_for(numPlayers, OF.gamemodes.option_now("balls") == "several")
end

local function crown_token_key(slot)
    if slot == 1 then return "crown" end
    return "crown" .. slot
end

local function place_crown()
    for slot = 1, active_count() do
        local key = crown_token_key(slot)
        local wearer = wearer_local(slot)
        local m = wearer ~= nil and gMarioStates[wearer] or nil
        local np = wearer ~= nil and gNetworkPlayers[wearer] or nil
        if m == nil or np == nil or m.pos == nil then
            OF.gamemodes.hide_token(key)
        else
            OF.gamemodes.mark_place(key, E_MODEL_BOWLING_BALL,
                { x = m.pos.x, y = m.pos.y + 150, z = m.pos.z,
                  level = np.currLevelNum, area = np.currAreaIndex }, 0x0400)
        end
    end
end

function OF.gm_crown_object(slot)
    return OF.gamemodes.tokens[crown_token_key(slot or 1)]
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

local function can_wear(slot)
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if OF.util.can_play(entry.localIndex) and entry.np ~= nil
            and not already_carrying(entry.np.globalIndex, slot) then
            table.insert(list, entry)
        end
    end
    return list
end

local droppedAt = { nil, nil, nil }

local function next_wearer(playing, slot)
    if playing[1] == nil then return nil end
    local at = droppedAt[slot]
    if at ~= nil then
        local best, bestAt = nil, nil
        for _, entry in ipairs(playing) do
            local distance = OF.gamemodes.distance_to_place(at, entry.localIndex)
            if distance ~= nil and (bestAt == nil or distance < bestAt) then
                best, bestAt = entry, distance
            end
        end
        if best ~= nil then return best end
    end

    local picked = OF.gamemodes.deal_fair(playing, 1, "crown")
    for _, entry in ipairs(playing) do
        if picked[entry.localIndex] then return entry end
    end
    return playing[1]
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

local function cut_seconds()
    if OF.teams.in_play() then return nil end
    return CUT_STOPS[OF.gamemodes.option_now("cut") or "never"]
end

local function still_in()
    local list = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if OF.util.can_play(entry.localIndex) then table.insert(list, entry) end
    end
    return list
end

local function cut_pick(list, count)
    local carrying = {}
    for slot = 1, count do
        local w = wearer_local(slot)
        if w ~= nil then carrying[w] = true end
    end
    local pool = {}
    for _, entry in ipairs(list) do
        if not carrying[entry.localIndex] then table.insert(pool, entry) end
    end
    if #pool == 0 then pool = list end

    local function distance_to_ball(localIndex)
        local best = nil
        for slot = 1, count do
            local w = wearer_local(slot)
            if w ~= nil and w ~= localIndex then
                local d = OF.gamemodes.distance(w, localIndex)
                if d ~= nil and (best == nil or d < best) then best = d end
            end
        end
        return best
    end

    local pick, pickScore, pickFar, pickGlobal = nil, nil, nil, nil
    for _, entry in ipairs(pool) do
        if entry.np ~= nil and type(entry.np.globalIndex) == "number" then
            local score = score_of(entry.localIndex)
            local far = distance_to_ball(entry.localIndex) or math.huge
            local global = entry.np.globalIndex
            local worse = pick == nil or score < pickScore
                or (score == pickScore and far > pickFar)
                or (score == pickScore and far == pickFar and global < pickGlobal)
            if worse then
                pick, pickScore, pickFar, pickGlobal = entry, score, far, global
            end
        end
    end
    return pick
end

local function knockout_step(count)
    local every = cut_seconds()
    if every == nil then return false end
    local due = math.floor(OF.gamemodes.since_start() / every)
    if due > cutsDone then
        cutsDone = due
        local list = still_in()
        if #list > 1 then
            local pick = cut_pick(list, count)
            if pick ~= nil then
                OF.gamemodes.set_role(pick.localIndex, ROLE_OUT)
                OF.notify.send_all("@ is cut - lowest on the clock", "warn", 4,
                    pick.np.name)
            end
        end
    end
    local list = still_in()
    if #list == 1 and list[1].np ~= nil then
        OF.gamemodes.finish("@ won through every cut.", list[1].np.name,
            list[1].np.name)
        return true
    end
    return false
end

function OF.gm_crown_knockout()
    return { pick = cut_pick, step = knockout_step, seconds = cut_seconds,
             cuts = function() return cutsDone end }
end

function OF.gm_crown_dropped_at(spot, slot)
    slot = slot or 1
    if spot ~= nil then droppedAt[slot] = spot end
    return droppedAt[slot]
end

local mode = {

    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP },

    boardTitle = "Ball time",
    outWord = "Cut",
    target = { auto = function(n, teams, side)
                   if teams then return 120 end
                   return OF.util.clamp(OF.gamemodes.round_to(400 / n, 20), 40, 120)
               end,
               name = "seconds carrying it",
               asks = "How many seconds it must be carried",
               default = 60,
               min = 20, max = 240, step = 20 },
    key = "crown",

    name = "Oddball",
    blurb = "carry it the longest - everybody else wants it",

    blurbTeams = "carry it the longest - your side keeps the seconds, so pass it on",

    aims = { [ROLE_HUNT] = "Hit whoever is carrying the ball and it is yours." },
    how = "One carries the ball, scoring a second a second.\n"
        .. "Hit the carrier and it is yours, clock and all.\n"
        .. "Taking it off a long carrier pays up to ten seconds.\n"
        .. "First to the target wins; on the clock, the most.",
    minPlayers = 2,

    maps = { "bowser3", "cotmc", "pyramid" },

    room = { sweep = { "cannons" }, rules = { waterheal = 1, knockback = 1 } },

    unsolidInAFight = true,

    music = SEQ_LEVEL_BOSS_KOOPA,
    defaultLimit = 300,

    teams = true,

    saysOut = true,

    scoreIsTime = true,

    options = {
        { key = "carry", name = "What carrying the ball does to you",
          help = "whether the ball moves the player holding it",
          choices = {
              { key = "even", name = "nothing",
                help = "the ball is weightless; cover decides the carry" },
              { key = "quicker", name = "quicker",
                help = "a body length over an arena; a carry is a chase" },
          } },

        { key = "win", name = "How it is won",
          help = "every carry added up, or one carry going the distance",
          choices = {
              { key = "seconds", name = "most seconds in total",
                help = "every second carrying it adds up; first to the target wins" },
              { key = "shine", name = "hold it out, unbroken",
                help = "one unbroken carry clears the bar; each drop shortens it" },
          } },

        { key = "balls", name = "How many balls",
          help = "one ball for the whole lobby, or several smaller fights",
          choices = {
              { key = "one", name = "one ball",
                help = "the whole lobby converges on a single carrier" },
              { key = "several", name = "one ball per five players",
                help = "three at sixteen, scored apart; nobody may hold two" },
          } },

        { key = "cut", name = "Knockout",
          help = "the lowest score is cut on a clock - for 5+ players",
          shownIf = function()
              local modes = OF.gamemodes
              return not (modes.wantSides == true and modes.BY_KEY.crown ~= nil
                  and modes.sides_wanted(modes.BY_KEY.crown))
          end,
          choices = {
              { key = "never", name = "nobody is cut",
                help = "first to the target wins" },
              { key = "thirty", name = "every thirty seconds",
                help = "the lowest is out; holding a ball at the cut saves you" },
              { key = "twenty", name = "every twenty seconds",
                help = "the same, faster - for a full lobby" },
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

local ballTargets = {}
local ballList = {}
function mode.targets(viewer)
    local _ = viewer
    for i = #ballList, 1, -1 do ballList[i] = nil end
    for slot = 1, active_count() do
        local wearer = wearer_local(slot)
        if wearer ~= nil and wearer ~= 0 then
            local t = ballTargets[slot] or { label = "Ball", tone = "target",
                priority = 85, compass = "offscreen" }
            ballTargets[slot] = t
            t.id = "ball:" .. tostring(slot)
            t.player = wearer
            ballList[#ballList + 1] = t
        end
    end
    return ballList
end

local TAKE_PROMPT_REACH = 260
function mode.prompt_now()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return nil end
    if my_slot() ~= nil or not OF.util.can_play(0) then return nil end
    for slot = 1, active_count() do
        local wearer = wearer_local(slot)
        if wearer ~= nil and wearer ~= 0 then
            local d = OF.gamemodes.distance(0, wearer)
            if d ~= nil and d <= TAKE_PROMPT_REACH then
                return "attack", "Take the ball"
            end
        end
    end
    return nil
end

function mode.may_attack(attacker, victim)
    if attacker == nil or victim == nil then return false end
    local function carrying(m)
        local np = gNetworkPlayers[m.playerIndex]
        return np ~= nil and already_carrying(np.globalIndex, nil)
    end
    return carrying(victim) and not carrying(attacker)
end

function mode.terms()
    if OF.gamemodes.option_showing(mode.key, "cut") ~= nil
        and OF.gamemodes.option_showing(mode.key, "cut") ~= "never" then
        return OF.lang.fill("first to @s, or the last one left",
            tostring(math.floor(target_seconds())))
    end
    local several = OF.gamemodes.option_showing(mode.key, "balls") == "several"
    local n = crowns_for(#OF.util.connected_players(), several)
    local ballWord = (n > 1) and (tostring(n) .. " balls") or "it"
    if OF.gamemodes.option_showing(mode.key, "win") == "shine" then
        return OF.lang.fill("hold @ for @s straight",
            ballWord, tostring(math.floor(target_seconds())))
    end
    return OF.lang.fill("first to @s carrying @",
        tostring(math.floor(target_seconds())), ballWord)
end

function mode.setup(players, options)

    if options ~= nil then options.target = OF.gamemodes.auto_target(mode, players, options) end
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_HUNT)
    end

    OF.util.publish(TARGET_KEY, options.target or TARGET_SECONDS)

    OF.util.report(OF.rules.lend("interactions", "crown",
        PLAYER_INTERACTIONS_PVP))

    local count = crown_count(#players)
    OF.util.publish(ACTIVE_KEY, count)

    if #players > 0 then
        local it = OF.gamemodes.deal_it(players, count, false)
        local slot = 1
        for _, entry in ipairs(players) do
            if slot > count then break end
            if it[entry.localIndex] and entry.np ~= nil then
                OF.util.publish(CROWN_KEYS[slot], entry.np.globalIndex)
                slot = slot + 1
            end
        end

        if slot <= count and players[1] ~= nil and players[1].np ~= nil then
            for s = slot, count do
                OF.util.publish(CROWN_KEYS[s], players[1].np.globalIndex)
            end
        end
    end

    local shineOn = OF.gamemodes.option_is("win", "shine")
    local startNeed = options.target or TARGET_SECONDS
    for slot = 1, MAX_CROWNS do
        OF.util.publish(STREAK_KEYS[slot], 0)
        OF.util.publish(NEED_KEYS[slot], (shineOn and slot <= count) and startNeed or nil)
    end
end

function mode.late_join(localIndex)
    return ROLE_HUNT
end

function mode.on_start()
    heardCrown = { near = false }
    cutsDone = 0
    held = 0
    grace = 0
    claimOut = 0
    gaveSeq = 0

    diedSeq = 0

    diedClaimed = false
    for slot = 1, MAX_CROWNS do
        seenDied[slot] = {}
        streak[slot] = 0
        droppedAt[slot] = nil
    end

end

function mode.cleanup()

    OF.rules.give_back("interactions", "crown")
    cutsDone = 0
    heardCrown = { near = false }
    held = 0
    grace = 0
    claimOut = 0
    gaveSeq = 0

    diedClaimed = false

    for slot = 1, MAX_CROWNS do
        seenGave[slot] = {}
        seenDied[slot] = {}
        droppedAt[slot] = nil
        streak[slot] = 0
    end
    if OF.util.is_host() then
        OF.util.publish(TARGET_KEY, nil)
        OF.util.publish(ACTIVE_KEY, nil)
        for slot = 1, MAX_CROWNS do
            OF.util.publish(CROWN_KEYS[slot], -1)
            OF.util.publish(STREAK_KEYS[slot], nil)
            OF.util.publish(NEED_KEYS[slot], nil)
        end
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

local CHASE_RANGE = 450
local function hear_the_chase()
    local near = false
    if my_slot() ~= nil and OF.gamemodes.role(0) == ROLE_HUNT then
        for i = 1, MAX_PLAYERS - 1 do
            if OF.gamemodes.role(i) == ROLE_HUNT and OF.util.can_play(i) then
                local distance = OF.gamemodes.distance(0, i)
                if distance ~= nil and distance <= CHASE_RANGE then near = true end
            end
        end
    end
    local warned = near and not heardCrown.near
    if warned then OF.gamemodes.cue("hazard") end
    heardCrown.near = near
    return warned
end

function mode.update()

    if OF.gamemodes.state() == OF.gamemodes.ACTIVE then hold_the_meter() end

    local every = cut_seconds()
    if every ~= nil and OF.gamemodes.role(0) == ROLE_HUNT then
        OF.gamemodes.tick_down(math.ceil(every - (OF.gamemodes.since_start() % every)))
    end
    hear_the_chase()
    if my_slot() == nil then return end
    if OF.gamemodes.role(0) ~= ROLE_HUNT then return end

    held = held + 1

    if held % 30 == 0 then
        OF.util.publish_row(0, "ofScore", math.floor(held / 30))
    end

    local rate = carry_speed()
    if rate > 1.0 then
        local m = gMarioStates[0]
        if m ~= nil then
            OF.util.speed_up(m, math.min(m.intendedMag or 0, WALK_TARGET) * rate)
        end
    end
end

local function on_pvp_attack(attacker, victim, interaction)
    if victim == nil or attacker == nil then return end
    if victim.playerIndex ~= 0 then return end
    if not OF.gamemodes.is_running() then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "crown" then return end
    if my_slot() == nil then return end
    if grace > 0 then return end

    if claimOut > 0 then return end
    if OF.gamemodes.role(0) ~= ROLE_HUNT then return end

    local takerLocal = attacker.playerIndex
    if takerLocal == nil or takerLocal == 0 then return end
    if OF.gamemodes.role(takerLocal) ~= ROLE_HUNT then return end

    local np = gNetworkPlayers[takerLocal]
    if np == nil or not np.connected then return end

    if already_carrying(np.globalIndex, nil) then return end

    grace = GRACE_FRAMES
    claimOut = CLAIM_WAIT
    gaveSeq = gaveSeq + 1

    OF.util.publish_row(0, GAVE_TO, np.globalIndex)
    OF.util.publish_row(0, GAVE_SEQ, gaveSeq .. ":" .. np.globalIndex)
end

function OF.gm_crown_read_gave(value)
    if type(value) == "number" then return value, nil end
    if type(value) ~= "string" then return 0, nil end
    local seq, to = string.match(value, "^(%d+):(%d+)$")
    if seq == nil then return 0, nil end
    return tonumber(seq), tonumber(to)
end

hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not OF.gamemodes.is_running() then return end
    local current = OF.gamemodes.current()
    if current == nil or current.key ~= "crown" then return end
    if my_slot() == nil then return end
    if diedClaimed then return end
    if OF.gamemodes.role(0) ~= ROLE_HUNT then return end

    if not OF.util.can_play(0) then return end

    diedClaimed = true
    diedSeq = diedSeq + 1
    OF.util.publish_row(0, DIED_SEQ, diedSeq)
end)

local function handed_over(slot)
    streak[slot] = 0
    local need = need_seconds(slot)
    if need ~= nil then
        OF.util.publish(NEED_KEYS[slot],
            math.max(SHINE_FLOOR_SECONDS, need - SHINE_DROP_SECONDS))
    end
end

function mode.host_update()
    local count = active_count()

    for slot = 1, count do
        local playing = can_wear(slot)

        local wearer = wearer_local(slot)
        local stillIn = false
        for _, entry in ipairs(playing) do
            if entry.localIndex == wearer then stillIn = true end
        end

        if stillIn and wearer ~= nil then
            local m = gMarioStates[wearer]
            local np = gNetworkPlayers[wearer]
            if m ~= nil and m.pos ~= nil and np ~= nil then
                droppedAt[slot] = { x = m.pos.x, y = m.pos.y, z = m.pos.z,
                    level = np.currLevelNum, area = np.currAreaIndex }
            end
        end

        streak[slot] = streak[slot] + 1
        if streak[slot] == 1 or streak[slot] % 30 == 0 then
            OF.util.publish(STREAK_KEYS[slot], math.floor(streak[slot] / 30))
        end

        local pick = (not stillIn) and next_wearer(playing, slot) or nil
        if pick ~= nil then
            handed_over(slot)
            OF.util.publish(CROWN_KEYS[slot], pick.np.globalIndex)
            OF.notify.send_all("The ball was dropped - @ has it now", "warn", 4,
                pick.np.name)
            wearer = pick.localIndex
        end

        local movedOnDeath = false
        if wearer ~= nil then
            local row = gPlayerSyncTable[wearer]
            local said = row ~= nil and row[DIED_SEQ] or 0
            if type(said) ~= "number" then said = 0 end
            if seenDied[slot][wearer] == nil then
                seenDied[slot][wearer] = said
            elseif said > seenDied[slot][wearer] then
                seenDied[slot][wearer] = said
                local poorest = lowest_scorer(playing, wearer)

                if poorest ~= nil then
                    local np = gNetworkPlayers[wearer]
                    handed_over(slot)
                    movedOnDeath = true
                    OF.util.publish(CROWN_KEYS[slot], poorest.np.globalIndex)
                    OF.notify.send_all("@ died with the ball - @ has it now",
                        "warn", 4,
                        (np ~= nil and np.name or ""),
                        poorest.np.name)
                    wearer = poorest.localIndex
                end
            end
        end

        if wearer ~= nil and not movedOnDeath then
            local row = gPlayerSyncTable[wearer]
            local said, toGlobal = OF.gm_crown_read_gave(row ~= nil and row[GAVE_SEQ] or 0)

            if seenGave[slot][wearer] == nil then
                seenGave[slot][wearer] = said
            elseif said > seenGave[slot][wearer] then
                seenGave[slot][wearer] = said
                local toLocal = type(toGlobal) == "number"
                    and OF.util.local_from_global(toGlobal) or nil

                if toLocal ~= nil and toLocal ~= wearer
                    and OF.gamemodes.role(toLocal) == ROLE_HUNT
                    and not already_carrying(toGlobal, slot) then
                    handed_over(slot)
                    OF.util.publish(CROWN_KEYS[slot], toGlobal)
                end
            end
        end
    end

    if knockout_step(count) then return end

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

    if OF.gamemodes.option_now("win") == "shine" then
        for slot = 1, count do
            local need = need_seconds(slot)
            local w = wearer_local(slot)
            if need ~= nil and w ~= nil and gNetworkPlayers[w] ~= nil
                and math.floor(streak[slot] / 30) >= need then
                OF.gamemodes.finish("@ won - the ball held unbroken.",
                    gNetworkPlayers[w].name, gNetworkPlayers[w].name)
                return
            end
        end
        return
    end

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HUNT)) do
        if score_of(entry.localIndex) >= target then
            OF.gamemodes.finish("@ won - the ball carried longest.", entry.np.name, entry.np.name)
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

local function make_crown_hook(slot)
    return function(tag, oldVal, newVal)

        if OF.util.asks(OF.guard, "repair")
            and OF.guard.repair(CROWN_KEYS[slot]) then return end

        local current = OF.gamemodes.current()
        if current == nil or current.key ~= "crown" then return end

        if slot > active_count() then return end
        local np = gNetworkPlayers[0]
        if np == nil then return end

        if newVal == np.globalIndex then

            claimOut = 0

            grace = GRACE_FRAMES

            diedClaimed = false

            local bounty = bounty_seconds(slot)
            if bounty > 0 then
                held = held + bounty * 30
                OF.util.publish_row(0, "ofScore", math.floor(held / 30))

                if OF.util.asks(OF.hud, "banner") then
                    OF.hud.banner("medal", "+" .. tostring(bounty) .. "s", nil, { tone = "good" })
                end
            end

            OF.gamemodes.cue("good")
        elseif oldVal == np.globalIndex then

            claimOut = 0

            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("objective", OF.lang.t("BALL TAKEN"), nil, { side = "them" })
            end
        end
    end
end

hook_on_sync_table_change(gGlobalSyncTable, CROWN_KEYS[1], 0, make_crown_hook(1))
hook_on_sync_table_change(gGlobalSyncTable, CROWN_KEYS[2], 0, make_crown_hook(2))
hook_on_sync_table_change(gGlobalSyncTable, CROWN_KEYS[3], 0, make_crown_hook(3))

function mode.hud()

    if OF.gamemodes.role(0) == ROLE_OUT then
        OF.gamemodes.out_banner("Cut")
        return
    end

    local target = target_seconds()
    local count = active_count()
    local mySlot = my_slot()

    local action, word = mode.prompt_now()
    if action ~= nil and OF.util.asks(OF.hud, "prompt") then
        OF.hud.prompt(action, OF.lang.t(word), nil, { id = "crown" })
    end

    if not OF.util.asks(OF.hud, "state_line") then return end
    local state = OF.hud.state_line
    if mySlot ~= nil then
        local fig
        if OF.gamemodes.option_now("win") == "shine" then
            fig = tostring(held_seconds(mySlot)) .. "/" .. tostring(need_seconds(mySlot) or target)
        else
            fig = math.floor(held / 30)
        end
        state("mine", OF.lang.t("You have it"), { prio = 60, tone = "target", figure = fig })
    else
        local nearest, nearestDist, any = nil, nil, false
        for slot = 1, count do
            local wearer = wearer_local(slot)
            if wearer ~= nil then
                any = true
                local distance = OF.gamemodes.distance(0, wearer)
                if distance ~= nil and (nearestDist == nil or distance < nearestDist) then
                    nearest, nearestDist = wearer, distance
                end
            end
        end
        if nearest ~= nil then
            state("theirs", OF.lang.fill("@ has it",
                OF.util.short_name(OF.util.plain(gNetworkPlayers[nearest].name), 10)),
                { prio = 50, tone = "warn" })
        elseif not any then
            state("free", OF.lang.t("Ball free"), { prio = 40, tone = "target" })
        end
    end
    local every = cut_seconds()
    if every ~= nil then
        local left = math.ceil(every - (OF.gamemodes.since_start() % every))
        if left <= 5 then
            state("cut", OF.lang.t("Cut in"), { prio = 70, tone = "bad", urgent = true, figure = left })
        end
    end
end

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "shine", name = "Keep Away", help = "one unbroken carry wins; the ball makes you quicker",
      sets = { win = "shine", carry = "quicker" } },
    { key = "elimination", name = "Elimination", help = "several balls, the lowest cut every thirty seconds",
      sets = { cut = "thirty", balls = "several" } },
}

function mode.scenery()
    step_the_waits()
    place_crown()
end

function mode.before_mario_update(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.role(0) == ROLE_OUT then OF.gamemodes.set_ghost(true) end
end

mode.target_now = target_seconds

mode.roundKeys = { "ofCrown", "ofCrown2", "ofCrown3" }
OF.gamemodes.register(mode)
