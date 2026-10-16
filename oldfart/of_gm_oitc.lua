OF = OF or {}

local ROLE_ALIVE = "alive"
local ROLE_OUT = "out"
local START_LIVES = 3
local LIFE_STOPS = { three = 3, one = 1, two = 2, five = 5 }

local FULL_HEALTH = 0x880
local PROTECT_FRAMES = 60

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

local function lives_wanted()
    return LIFE_STOPS[OF.gamemodes.option_now("lives") or "three"]
        or START_LIVES
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

local function kills_of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    local kills = row ~= nil and row.ofOitcKills or 0
    if type(kills) ~= "number" then return 0 end
    return kills
end

local lives = 0

local startLives = nil
local outCause = nil
local myRounds = 0
local respawnPending = false
local boltWas = 0
local lastClickFrame = -9999
local seenKillSeq = 0
local seated = false

local emptyFor = 0
local REFILL_FRAMES = 20 * 30

local SURV = { key = "ofOitcPts", pts = nil, seen = {}, heard = 0 }

local mode = {
    key = "oitc",

    tagRule = "shooter",

    noLeaderMark = true,
    name = "One in the Chamber",
    blurb = "one round, no reload - land a kill and you get another",
    how = "One round in the rifle and no reload.\n"
        .. "Land a kill - rifle or fists - and get one more round.\n"
        .. "Twenty seconds empty and the round comes back.\n"
        .. "Three lives. Go down a third time and you watch.\n"
        .. "Last player alive wins.\n"
        .. "On the clock, most lives left; ties go to most kills.\n"
        .. "Kills and outlasting both score; the best score wins.",
    aims = { [ROLE_ALIVE] = "One round. Land a kill and get another." },
    minPlayers = 2,

    maps = "surveyed",

    roomsOut = {
        { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },
        { level = LEVEL_BITDW, area = 1 }, { level = LEVEL_BITFS, area = 1 },

        { level = LEVEL_RR, area = 1 }, { level = LEVEL_TTC, area = 1 },
        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_LLL, area = 2 },

        { level = LEVEL_TTM, area = 1 }, { level = LEVEL_THI, area = 2 },

        { level = LEVEL_SSL, area = 2 }, { level = LEVEL_COTMC, area = 1 },

        { level = LEVEL_CASTLE_GROUNDS, area = 1 },
    },

    spreadOpening = true,
    surveyKeys = { "points" },

    openCourses = true,
    room = { sweep = { "cannons" },
             rules = { bubble = 0, interactions = PLAYER_INTERACTIONS_PVP } },

    cheatsGiven = { sniper = function() return 2 end },
    roundKills = true,
    resultsBy = "survival",

    saysOut = true,
    lensRole = ROLE_OUT,
    defaultLimit = 180,
    music = SEQ_LEVEL_BOSS_KOOPA,
    teams = false,
    options = {
        { key = "lives", name = "Lives",
          help = "how long it takes to put somebody out",
          choices = {
              { key = "three", name = "three lives",
                help = "the usual round" },
              { key = "one", name = "one life",
                help = "sudden death - the first kill settles it" },
              { key = "two", name = "two lives",
                help = "one mistake forgiven rather than two" },
              { key = "five", name = "five lives",
                help = "a longer war of attrition for a small lobby" },
          } },

        { key = "scoring", name = "Winner",
          help = "the last one standing, or the highest score",
          choices = {
              { key = "last", name = "last one standing",
                help = "on the clock, the most lives left" },
              { key = "survive", name = "highest score",
                help = "a kill is two points, outlasting a player one" },
          } },

        { key = "medals", name = "Medals",
          help = "Excellent and Humiliation, told to the two players involved",
          choices = {
              { key = "on", name = "on",
                help = "two kills in three seconds; a kill with the fists" },
              { key = "off", name = "off",
                help = "a kill is a kill, nothing more said" },
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
        { key = "killcam", name = "Kill cam",
          help = "the seconds before you went down, from their side",
          choices = {
              { key = "on", name = "on",
                help = "no extra wait - it plays through the death" },
              { key = "off", name = "off",
                help = "you watch yourself fall, as before" },
          } },
    },
}

function mode.pauseControls()
    return OF.shooter.kit_controls(mode)
end

function mode.setup(players)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_ALIVE)
    end
end

local function register_chamber()
    OF.shooter.set_stands_down(function()
        if myRounds > 0 then return false end
        local now = now_frame()
        if now ~= lastClickFrame then
            lastClickFrame = now

            OF.gamemodes.round_sound(SOUND_MENU_CLICK_FILE_SELECT)
        end
        return true
    end)
end

function mode.on_start()
    register_chamber()
    lives = lives_wanted()
    myRounds = 1
    emptyFor = 0
    respawnPending = false
    boltWas = 0
    lastClickFrame = -9999
    seenKillSeq = OF.shooter.kill_seq()
    seated = false
    SURV.pts, SURV.seen, SURV.heard = nil, {}, 0
    if OF.gamemodes.role(0) == ROLE_ALIVE then
        OF.util.publish_row(0, "ofScore", lives)
        OF.util.publish_row(0, "ofOitcKills", 0)
    end
    startLives = lives
    outCause = nil

end

function mode.late_join(localIndex)
    OF.gamemodes.set_role(localIndex, ROLE_ALIVE)
    return ROLE_ALIVE
end

function mode.pin()
    OF.shooter.publish_ffa_points(ROLE_ALIVE)
end

function mode.death_place()
    return OF.shooter.ffa_respawn_point()
end

local function am_out()
    return OF.gamemodes.role(0) == ROLE_OUT
end

local function survivors_score()
    return OF.gamemodes.option_is("scoring", "survive")
end

local function read_points(text)
    local list = {}
    if type(text) ~= "string" then return list end
    for g, n in text:gmatch("(%d+):(%d+)") do list[tonumber(g)] = tonumber(n) end
    return list
end

local function points_of(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return 0 end
    return read_points(gGlobalSyncTable[SURV.key])[np.globalIndex] or 0
end

local function host_pay_survivors()
    if not survivors_score() then return end
    if SURV.pts == nil then

        local standing = gGlobalSyncTable[SURV.key]
        SURV.pts = read_points(standing)
        if type(standing) == "string" and standing ~= "" then
            for _, entry in ipairs(OF.gamemodes.with_role(ROLE_OUT)) do
                local g = entry.np and entry.np.globalIndex
                if g ~= nil then SURV.seen[g] = true end
            end
        end
    end
    local changed = false
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_OUT)) do
        local g = entry.np and entry.np.globalIndex
        if g ~= nil and not SURV.seen[g] then
            SURV.seen[g] = true
            for _, still in ipairs(contenders()) do
                local sg = still.np and still.np.globalIndex
                if sg ~= nil then
                    SURV.pts[sg] = (SURV.pts[sg] or 0) + 1
                    changed = true
                end
            end
        end
    end
    if changed then
        local out = {}
        for g, n in pairs(SURV.pts) do table.insert(out, { g, n }) end
        table.sort(out, function(a, b) return a[1] < b[1] end)
        for i, pair in ipairs(out) do out[i] = pair[1] .. ":" .. pair[2] end
        OF.util.publish(SURV.key, table.concat(out, " "))
    end
end

local function watch_toggle(m)
    if not OF.util.asks(OF.spectate, "start") then return end
    if OF.util.menu_has_screen() then return end
    OF.input.poll(m)
    if not OF.util.asks(OF.input, "pressed") or not OF.input.pressed(L_JPAD) then
        return
    end
    if OF.spectate.is_active() then
        OF.spectate.stop()
        seated = false
        return
    end
    local best = nil
    for _, entry in ipairs(contenders()) do
        if entry.localIndex ~= 0 then best = entry; break end
    end
    if best == nil then
        OF.util.report(false, "There is nobody left to watch.")
        return
    end
    seated = OF.spectate.start(network_global_index_from_local(best.localIndex))
        == true
end

local function put_out(reason)
    OF.gamemodes.set_role(0, ROLE_OUT)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    outCause = reason
end

local function spend_life()
    lives = math.max(lives - 1, 0)
    OF.util.publish_row(0, "ofScore", lives)
    if lives <= 0 then
        put_out("You are out of lives")
        return true
    end

    if OF.util.asks(OF.hud, "banner") then
        OF.hud.banner("out", OF.lang.t("DOWN"),
            OF.lang.plural(lives, "1 life left", "@ lives left"), { quiet = true })
    end

    OF.gamemodes.cue("bad")
    return false
end

hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim, interaction)
    if attacker == nil or victim == nil then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if victim.playerIndex == 0 then
        victim.health = FULL_HEALTH
        victim.hurtCounter = 0
    end

    if attacker.playerIndex == 0 and OF.util.can_play(0) and not am_out() then
        local np = gNetworkPlayers[victim.playerIndex]
        if np ~= nil and np.connected and type(np.globalIndex) == "number" then
            OF.shooter.put_down(np.globalIndex, true)
        end
    end
end)

function mode.update()
    if am_out() then return end
    local m = gMarioStates[0]
    if m == nil then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    watch_toggle(m)
    if not OF.util.can_play(0) then return end

    if respawnPending then
        local group = OF.util.action_group(m.action)
        if group ~= OF.util.action_group(ACT_GROUP_CUTSCENE) then
            respawnPending = false
            m.invincTimer = PROTECT_FRAMES
            myRounds = 1
        end
    end

    local cold = 0
    if OF.util.asks(OF.cheats, "rifle_cooldown") then
        cold = OF.cheats.rifle_cooldown()
    end
    local fired = cold > 0 and boltWas <= 0
    boltWas = cold
    if fired then
        m.invincTimer = 0
        myRounds = math.max(myRounds - 1, 0)
    end

    local seq = OF.shooter.kill_seq()
    if seq > seenKillSeq then
        seenKillSeq = seq
        myRounds = myRounds + 1
        OF.util.publish_row(0, "ofOitcKills", kills_of(0) + 1)
    end

    if myRounds > 0 then
        emptyFor = 0
    else
        emptyFor = emptyFor + 1
        if emptyFor >= REFILL_FRAMES then
            emptyFor = 0
            myRounds = 1
            OF.gamemodes.round_sound(SOUND_MENU_CLICK_FILE_SELECT)

            if OF.util.asks(OF.hud, "banner") then
                OF.hud.banner("medal", OF.lang.t("RELOADED"), nil, { quiet = true })
            end
        end
    end
end

function OF.gm_oitc_refill_in()
    if myRounds > 0 then return nil end
    return REFILL_FRAMES - emptyFor
end

function mode.before_mario_update(m)
    if not am_out() then return end
    OF.gamemodes.set_ghost(true)
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    respawnPending = true
    spend_life()
end)

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    host_pay_survivors()
    local alive = contenders()

    if survivors_score() and #alive <= 1 and #OF.gamemodes.still_here() > 1 then
        mode.finish_on_score()
        return
    end
    if #alive == 1 and #OF.gamemodes.still_here() > 1 then
        OF.gamemodes.finish("@ won.", alive[1].np.name,
            alive[1].np.name)
    elseif #alive == 0 then
        OF.gamemodes.finish("Everyone went down at once.")
    end
end

function mode.still_winnable()
    return #contenders() >= 1
end

function mode.terms()
    local said = LIFE_STOPS[OF.gamemodes.option_showing(mode.key, "lives")
        or "three"] or START_LIVES
    if OF.gamemodes.option_showing(mode.key, "scoring") == "survive" then
        return OF.lang.plural(said, "one round, 1 life - highest score wins",
            "one round, @ lives - highest score wins")
    end
    return OF.lang.plural(said, "one round, 1 life - most lives left",
        "one round, @ lives - most lives left")
end

mode.KILL_POINTS = 2
function mode.score_of(localIndex)
    return kills_of(localIndex) * mode.KILL_POINTS + points_of(localIndex)
end

function mode.finish_on_score()
    local best, names = OF.gamemodes.best_of(OF.gamemodes.played(),
        function(entry) return mode.score_of(entry.localIndex) end, false,
        function(entry)
            return kills_of(entry.localIndex) * 1000 + lives_of(entry.localIndex)
        end)
    if best == nil then
        OF.gamemodes.finish("Nobody won.")
    elseif #names > 1 then
        OF.gamemodes.finish(best == 1 and "A draw at 1 point each." or "A draw at @ points each.",
            nil, tostring(best))
    else
        OF.gamemodes.finish(best == 1 and "@ won with 1 point." or "@ won with @ points.",
            names[1], names[1], tostring(best))
    end
end

function mode.on_timeout()
    if survivors_score() then
        mode.finish_on_score()
        return
    end
    local best, names = OF.gamemodes.best_of(contenders(),
        function(entry) return lives_of(entry.localIndex) end, false,
        function(entry) return kills_of(entry.localIndex) end)
    if best == nil then
        OF.gamemodes.finish("Nobody won.")
    elseif #names > 1 then
        OF.gamemodes.finish(best == 1 and "Time - a draw at 1 life each." or "Time - a draw at @ lives each.",
            nil, tostring(best))
    else
        OF.gamemodes.finish(best == 1 and "@ won with 1 life." or "@ won with @ lives.",
            names[1], names[1], tostring(best))
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
    local refill = OF.gm_oitc_refill_in()
    if refill ~= nil then
        OF.hud.state_line("refill", OF.lang.t("Back in"), { prio = 70, tone = "warn",
            figure = math.ceil(refill / 30) })
    end
    OF.hud.state_line("lives", nil, { prio = 50, icons = mode.life_icons() })
end

function mode.life_icons()
    local items = {}
    local most = math.max(startLives or lives, lives)
    for i = 1, most do
        items[i] = { icon = "pip", tone = "ink", empty = i > lives }
    end
    return items
end

function mode.out_cause() return outCause end

local scoreOut = {}
function mode.cluster()
    if not survivors_score() or not OF.util.asks(OF.hud, "ordinal") then return nil end
    local rows = {}
    for _, entry in ipairs(OF.gamemodes.played()) do
        rows[#rows + 1] = { localIndex = entry.localIndex, name = entry.np.name,
            value = mode.score_of(entry.localIndex) }
    end
    if #rows == 0 then return nil end
    table.sort(rows, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.name < b.name
    end)
    local mine = 1
    for index, row in ipairs(rows) do
        if row.localIndex == 0 then mine = index end
    end
    local function plate(row, label)
        return { label = label or string.sub(OF.util.plain(row.name or ""), 1, 14),
            score = row.value, localIndex = row.localIndex }
    end
    scoreOut.you = plate(rows[mine], OF.hud.ordinal(mine))
    local other = rows[mine == 1 and 2 or 1]
    scoreOut.leader = other ~= nil and plate(other) or nil
    scoreOut.leaderIndex = nil
    if rows[2] == nil or rows[1].value > rows[2].value then scoreOut.leaderIndex = rows[1].localIndex end
    scoreOut.target, scoreOut.left, scoreOut.right = nil, nil, nil
    return scoreOut
end

function mode.cleanup()
    if seated and OF.util.asks(OF.spectate, "stop") then
        OF.spectate.stop()
    end
    seated = false

    OF.shooter.set_stands_down(nil)
    if OF.util.is_host() then
        OF.util.publish("ofShootAt", nil)
        OF.util.publish(SURV.key, nil)
    end
    SURV.pts, SURV.seen, SURV.heard = nil, {}, 0
    lives = 0
    myRounds = 0
    respawnPending = false
    boltWas = 0
    emptyFor = 0
    lastClickFrame = -9999
    OF.util.publish_row(0, "ofOitcKills", nil)
    return true
end

OF.gamemodes.register(mode)
