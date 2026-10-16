OF = OF or {}
OF.laststanding = OF.laststanding or {}

local START_LIVES = 3
local RESPAWN_GRACE = 90

local LIFE_STOPS = {
    three = 3, one = 1, two = 2, five = 5,
}

local function lives_wanted()
    local said = OF.gamemodes.option_now("lives") or "auto"
    if said == "auto" then
        return #OF.gamemodes.participants() >= 9 and 2 or START_LIVES
    end
    return LIFE_STOPS[said] or START_LIVES
end

local FALL_DROP = 1200

local FALL_FRAMES = 30

local ROLE_ALIVE = "alive"
local ROLE_OUT = "out"
local lives = 0

local startLives = nil
local grace = 0
local wasDead = false

local groundY = nil
local fallFor = 0

local seated = false

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function alive_players()
    return OF.gamemodes.with_role(ROLE_ALIVE)
end

local function in_contention(localIndex)
    return OF.gamemodes.in_contention(localIndex)
end

local function contenders()
    local list = {}
    for _, entry in ipairs(alive_players()) do
        if in_contention(entry.localIndex) then table.insert(list, entry) end
    end
    return list
end

local function lives_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local score = row ~= nil and row.ofScore or 0
    if type(score) ~= "number" then return 0 end
    return score
end

local function seat_rank(localIndex)
    local rank = lives_of(localIndex)
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        local mine = OF.teams.of(0)
        if mine ~= nil and mine ~= OF.teams.NONE
            and OF.teams.of(localIndex) == mine then

            rank = rank + 1000
        end
    end
    return rank
end

local function best_seat()
    local best, bestRank, bestNear = nil, nil, nil
    for _, entry in ipairs(contenders()) do
        if entry.localIndex ~= 0 then
            local rank = seat_rank(entry.localIndex)

            local near = OF.gamemodes.distance(0, entry.localIndex) or math.huge
            if best == nil or rank > bestRank
                or (rank == bestRank and near < bestNear) then
                best, bestRank, bestNear = entry, rank, near
            end
        end
    end
    if best == nil then return nil end
    return network_global_index_from_local(best.localIndex)
end

local function watch_toggle(m)
    if not OF.util.asks(OF.spectate, "start") then return end
    if OF.util.menu_has_screen() then return end

    OF.input.poll(m)
    if not OF.input.pressed(L_JPAD) then return end

    if OF.spectate.is_active() then
        OF.spectate.stop()
        seated = false
        return
    end

    local seat = best_seat()
    if seat == nil then

        OF.util.report(false, "There is nobody left to watch.")
        return
    end
    seated = OF.spectate.start(seat) == true
end

local function lost_a_life()
    if not OF.util.asks(OF.hud, "banner") then return end

    OF.hud.banner("out", OF.lang.t("DOWN"),
        OF.lang.plural(lives, "1 life left", "@ lives left"), { quiet = true })
end

local lastCause = nil
local function put_out(reason)
    OF.gamemodes.set_role(0, ROLE_OUT)

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    lastCause = reason
end

local mode = {

    lobbyRules = { interactions = PLAYER_INTERACTIONS_PVP, health = 1 },
    key = "laststanding",

    resultsBy = "survival",

    saysOut = true,
    name = "Last One Standing",

    blurb = "lives on the line, fists out",

    blurbTeams = "lives on the line, fists out - the last side with anybody left wins",
    how = "Fists are on and everybody has the same lives.\n"
        .. "Punches land twice as hard here as in the lobby.\n"
        .. "A fall costs one. Lose them all and you watch.\n"
        .. "Last player standing wins.\n"
        .. "In sides, the last side with anybody left.\n"
        .. "On the clock, whoever has the most lives left.",
    minPlayers = 2,

    maps = { "bowser1", "bowser2", "bowser3", "desert_cage", "ice_donut", "the_plate", "aquarium", "tower", "igloo", "volcano" },

    room = { sweep = { "cannons" }, rules = { waterheal = 1 } },

    defaultLimit = 240,
    music = SEQ_LEVEL_BOSS_KOOPA,

    teams = true,

    lensRole = ROLE_OUT,

    options = {
        { key = "lives", name = "How many lives each",
          help = "how long it takes to put somebody out",
          choices = {

              { key = "auto", name = "auto",
                help = "three lives up to eight players, two from nine" },
              { key = "one", name = "one life",
                help = "sudden death; the first clean exchange settles it" },
              { key = "two", name = "two lives",
                help = "one mistake forgiven rather than two" },
              { key = "three", name = "three lives",
                help = "a life is something you can spend badly and survive" },
              { key = "five", name = "five lives",
                help = "a war of attrition for a small lobby" },
          } },

        { key = "vamp", name = "Vampire",
          help = "what landing a hit does for you",
          choices = {
              { key = "off", name = "off",
                help = "a hit heals nothing" },
              { key = "on", name = "on",
                help = "a hit you land heals one health wedge" },
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

function mode.out_cause() return lastCause end
mode.boardTitle = "Still in"
function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_ALIVE)
    end

    OF.util.report(OF.rules.lend_many({
        { key = "interactions", value = PLAYER_INTERACTIONS_PVP },
        { key = "health", value = 1 },
    }, "laststanding"))
end

function mode.on_start()
    lives = lives_wanted()
    grace = RESPAWN_GRACE
    wasDead = false
    seated = false

    groundY = nil
    fallFor = 0

    if OF.gamemodes.role(0) == ROLE_ALIVE then
        OF.util.publish_row(0, "ofScore", lives)
    end
    startLives = lives
    lastCause = nil

end

function mode.cleanup()

    if seated and OF.util.asks(OF.spectate, "stop") then
        OF.spectate.stop()
    end
    seated = false

    OF.rules.give_back("interactions", "laststanding")
    OF.rules.give_back("health", "laststanding")
    lives = 0
    grace = 0
    wasDead = false
    groundY = nil
    fallFor = 0
end

local function spend_life()
    wasDead = true
    lives = lives - 1
    OF.util.publish_row(0, "ofScore", math.max(0, lives))
    grace = RESPAWN_GRACE
    fallFor = 0

    groundY = nil

    if lives <= 0 then return true end

    OF.gamemodes.cue("bad")

    OF.gamemodes.give_full_health()
    return false
end

local function in_the_bubble(m)
    return ACT_BUBBLED ~= nil and m ~= nil and m.action == ACT_BUBBLED
end

local function already_paid_for(m)
    return in_the_bubble(m) and groundY == nil
end

local function falling_off(m)
    if m == nil or m.pos == nil then return false end

    if in_the_bubble(m) then
        fallFor = 0
        return false
    end
    local floor = tonumber(m.floorHeight)
    if floor ~= nil and m.pos.y <= floor + 8 then
        groundY = m.pos.y
        fallFor = 0
        return false
    end
    if groundY == nil or m.pos.y >= groundY - FALL_DROP then
        fallFor = 0
        return false
    end
    fallFor = fallFor + 1
    return fallFor >= FALL_FRAMES
end

function mode.update()
    if am_out() then return end

    local m = gMarioStates[0]
    if m == nil then return end

    local dead = (m.health or 0x880) <= 0xFF
    local wentOver = falling_off(m)

    if dead and not wasDead and grace <= 0 and not already_paid_for(m) then
        if spend_life() then
            put_out("You went down - that was your last life")
        else
            lost_a_life()
        end
    elseif wentOver and not wasDead and grace <= 0 then
        if spend_life() then
            put_out("You went off the stage - that was your last life")
        else
            lost_a_life()
        end
    elseif not dead then
        wasDead = false
    end
end

function mode.before_mario_update(m)
    if not am_out() then return end
    OF.gamemodes.set_ghost(true)
    watch_toggle(m)
end

function mode.host_update()
    if OF.teams.in_play() then

        local side = OF.teams.last_side_standing(function(localIndex)
            return OF.gamemodes.role(localIndex) == ROLE_ALIVE
                and in_contention(localIndex)
        end)
        if side ~= nil then
            OF.gamemodes.finish(OF.teams.survival_text(side),
                OF.gamemodes.team_winner(side))
        end
        return
    end

    local alive = contenders()
    if #alive == 1 and #OF.gamemodes.still_here() > 1 then
        OF.gamemodes.finish("@ won.", alive[1].np.name,
            alive[1].np.name)
    elseif #alive == 0 then
        OF.gamemodes.finish("Everyone went down at once.")
    end
end

function mode.terms()
    local key = OF.gamemodes.option_showing(mode.key, "lives") or "auto"
    local said = key == "auto" and lives_wanted() or LIFE_STOPS[key] or START_LIVES

    return OF.lang.plural(said, "last one standing on 1 life - most lives left",
        "last one standing on @ lives - most lives left")
end

function mode.on_timeout()

    local best, names = OF.gamemodes.best_of(contenders(),
        function(entry) return gPlayerSyncTable[entry.localIndex].ofScore or 0 end)
    if best == nil then
        OF.gamemodes.finish("Nobody won.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, best)
    else
        OF.gamemodes.finish(best == 1 and "@ won with 1 life." or "@ won with @ lives.",
            names[1], names[1], best)
    end
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    if am_out() then

        OF.gamemodes.out_banner()
        return
    end

    if not OF.util.asks(OF.hud, "state_line") then return end
    local state = OF.hud.state_line
    if grace > 0 then
        state("safe", OF.lang.t("Safe"), { prio = 70, tone = "good" })
    end
    if lives == 1 then
        state("last", OF.lang.t("Last life"), { prio = 60, tone = "warn" })
    else
        state("lives", nil, { prio = 50, icons = mode.life_icons() })
    end
end

function mode.life_icons()
    local items = {}
    local most = math.max(startLives or lives, lives)
    for i = 1, most do
        items[#items + 1] = { icon = "heart", tone = "bad", empty = i > lives }
    end
    return items
end

local HIT_MULTIPLIER = 2

local WEDGE_HEAL = 0x100
local FULL_HEALTH = 0x880

function OF.laststanding.vampire_lands(mode, attacker)
    if attacker == nil or attacker.playerIndex ~= 0
        or attacker.marioObj == nil then
        return false
    end
    if OF.gamemodes.current() ~= mode then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if OF.gamemodes.option_now("vamp") ~= "on" then return false end
    local dealt = tonumber(attacker.marioObj.oDamageOrCoinValue) or 0
    if dealt <= 0 then return false end
    return dealt
end

hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim, interaction)
    if attacker == nil or attacker.marioObj == nil then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if victim ~= nil and victim.playerIndex == 0
        and OF.gamemodes.my_role() == ROLE_ALIVE

        and grace <= 0

        and not OF.util.has_flag(victim.flags or 0, MARIO_METAL_CAP) then
        local dealt = tonumber(attacker.marioObj.oDamageOrCoinValue) or 0
        if dealt > 0 then
            if not OF.util.has_flag(victim.flags or 0, MARIO_CAP_ON_HEAD) then
                dealt = dealt + math.floor((dealt + 1) / 2)
            end

            local times = HIT_MULTIPLIER
            local left = OF.gamemodes.time_left()
            if left ~= nil and left <= 60 then times = HIT_MULTIPLIER * 2 end
            local extra = 4 * dealt * (times - 1)
            victim.hurtCounter = math.min(255, (victim.hurtCounter or 0) + extra)
        end
    end

    if OF.gamemodes.my_role() == ROLE_ALIVE and grace <= 0
        and OF.laststanding.vampire_lands(mode, attacker) then
        local m = gMarioStates[0]
        if m ~= nil then
            m.health = math.min(FULL_HEALTH, (m.health or 0) + WEDGE_HEAL)
        end
    end
end)

function mode.scenery()
    if grace > 0 then grace = grace - 1 end
end

OF.gamemodes.register(mode)
