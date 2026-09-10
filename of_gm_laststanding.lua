OF = OF or {}

local START_LIVES = 3
local RESPAWN_GRACE = 90

local LIFE_STOPS = {
    three = 3, one = 1, two = 2, five = 5,
}

local function lives_wanted()
    return LIFE_STOPS[OF.gamemodes.option_now("lives") or "three"] or START_LIVES
end

local FALL_DROP = 1200

local FALL_FRAMES = 30

local ROLE_ALIVE = "alive"
local ROLE_OUT = "out"
local lives = 0
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

local function put_out(reason)
    OF.gamemodes.set_role(0, ROLE_OUT)

    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    OF.notify.show(reason, "bad", 6)
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)

    OF.notify.show("D-pad left watches the best of them - hold L to look further",
        "info", 7)
end

local mode = {
    key = "laststanding",

    resultsBy = "survival",
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

    maps = OF.gamemodes.ARENA_SET,

    room = { sweep = { "cannons" }, rules = { waterheal = 1 } },
    defaultLimit = 300,
    music = SEQ_LEVEL_BOSS_KOOPA,

    teams = true,

    lensRole = ROLE_OUT,

    options = {
        { key = "lives", name = "How many lives each",
          help = "how long it takes to put somebody out, which is most of "
              .. "how long a round lasts",
          choices = {
              { key = "three", name = "three lives",
                help = "the round this mode has always played - a life is "
                    .. "something you can spend badly and come back from" },
              { key = "one", name = "one life",
                help = "sudden death: the first clean exchange settles it, and "
                    .. "nobody is out for long" },
              { key = "two", name = "two lives",
                help = "one mistake forgiven rather than two, for a lobby that "
                    .. "found three a long wait" },
              { key = "five", name = "five lives",
                help = "a war of attrition for a small lobby, where three ends "
                    .. "before anybody has warmed up" },
          } },
    },
}

function mode.setup(players, options)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_ALIVE)
    end

    OF.util.report(OF.rules.lend_many({
        { key = "interactions", value = PLAYER_INTERACTIONS_PVP },
        { key = "nametags", value = 1 },
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

    OF.notify.show("@ live(s). Last one standing wins.", "warn", 6, lives)
end

function mode.cleanup()

    if seated and OF.util.asks(OF.spectate, "stop") then
        OF.spectate.stop()
    end
    seated = false

    OF.rules.give_back("interactions", "laststanding")
    OF.rules.give_back("nametags", "laststanding")
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
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)

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
            OF.notify.show("You went down - @ live(s) left", "warn", 4, lives)
        end
    elseif wentOver and not wasDead and grace <= 0 then
        if spend_life() then
            put_out("You went off the stage - that was your last life")
        else
            OF.notify.show("You went off the stage - @ live(s) left",
                "warn", 4, lives)
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
        OF.gamemodes.finish("@ is the last one standing.", alive[1].np.name,
            alive[1].np.name)
    elseif #alive == 0 then
        OF.gamemodes.finish("Everyone went down at once.")
    end
end

function mode.terms()
    local said = LIFE_STOPS[OF.gamemodes.option_showing(mode.key, "lives")
        or "three"] or START_LIVES

    return OF.lang.fill("last one standing on @ live(s) - most lives left",
        tostring(said))
end

function mode.on_timeout()

    local best, names = OF.gamemodes.best_of(contenders(),
        function(entry) return gPlayerSyncTable[entry.localIndex].ofScore or 0 end)
    if best == nil then
        OF.gamemodes.finish("Nobody survived.")
    elseif #names > 1 then
        OF.gamemodes.finish("Time - a draw at @ each.", nil, best)
    else
        OF.gamemodes.finish("@ survived with @ live(s).", names[1], names[1], best)
    end
end

function mode.standing(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_OUT then return "OUT" end
    if not OF.util.can_play(localIndex) then return "AWAY" end
    return nil
end

function mode.hud()
    local text
    local r, g, b = 255, 255, 255
    if am_out() then

        local watching = OF.util.asks(OF.spectate, "is_active")
            and OF.spectate.is_active()
        text = watching and "Out - L / R watch somebody else"
            or "Out - D-pad left to watch"
        r, g, b = 255, 140, 140
    else
        text = lives .. " live(s)   -   " .. #contenders() .. " still in"
        if grace > 0 then text = text .. "   (safe)" end
    end

    OF.util.banner(text, 1.0, r, g, b, 255)

    local board = {}
    for _, entry in ipairs(contenders()) do
        table.insert(board, { name = entry.np.name, localIndex = entry.localIndex,
                              score = lives_of(entry.localIndex) })
    end

    table.sort(board, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end)
    for _, entry in ipairs(board) do entry.right = tostring(entry.score) end

    OF.util.board(djui_hud_get_screen_width() * 0.03,
        djui_hud_get_screen_height() * 0.24,
        OF.lang.t("Still in"), board, { column = 130 })
end

local HIT_MULTIPLIER = 2

hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim, interaction)

    if victim == nil or victim.playerIndex ~= 0 then return end
    if attacker == nil or attacker.marioObj == nil then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.my_role() ~= ROLE_ALIVE then return end

    if grace > 0 then return end

    if OF.util.has_flag(victim.flags or 0, MARIO_METAL_CAP) then return end

    local dealt = tonumber(attacker.marioObj.oDamageOrCoinValue) or 0
    if dealt <= 0 then return end
    if not OF.util.has_flag(victim.flags or 0, MARIO_CAP_ON_HEAD) then
        dealt = dealt + math.floor((dealt + 1) / 2)
    end

    local extra = 4 * dealt * (HIT_MULTIPLIER - 1)
    victim.hurtCounter = math.min(255, (victim.hurtCounter or 0) + extra)
end)

function mode.scenery()
    if grace > 0 then grace = grace - 1 end
end

OF.gamemodes.register(mode)
