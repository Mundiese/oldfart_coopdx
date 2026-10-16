OF = OF or {}

local ROLE_PLAYING = "playing"
local ROLE_DEAD = "out"
local KILL_RANGE = 200

local KILL_COOLDOWN = 5 * 30

local HOST_REACH = KILL_RANGE * 5

OF.murder = OF.murder or {}

local WAITS = { five = 5, ten = 10, twenty = 20, two = 2 }

function OF.murder.cooldown_frames(way)
    local said = way or OF.gamemodes.option_now("wait")
    return (WAITS[said] or (KILL_COOLDOWN / 30)) * 30
end

local function host_grace()
    return math.floor(OF.murder.cooldown_frames() / 2)
end

local function haste_on()
    return OF.gamemodes.option_now("clock") == "haste"
end

local HASTE_PER_DEATH = 30

local hostGrace = {}

local iAmTheMurderer = false
local cooldown = 0

local iAmTheSheriff = false

local sheriffSpent = false

local sheriffHeldB = false

local SHERIFF_DOWN_ACTION = "murdersheriffdown"
local PACKET_HERE = "ofMurderHere"
local PULSE_EVERY = 30
local SILENCE_LIMIT = 5 * 30

local pulseIn = 0

local silence = 0

local mode = {

    key = "murder",

    noAnnounce = true,
    resultsBy = "survival",

    outVanishes = true,
    sidePlain = function()
        if not OF.gamemodes.is_running() then return false end
        return OF.util.asks(OF.roundscope, "dealt") and OF.roundscope.dealt(0)
            and not OF.gamemodes.is_out(0)
    end,
    name = "Murder Mystery",
    blurb = "one of you is the murderer - nobody is told who",

    how = "One of you is the murderer. Nobody is told who.\n"
        .. "They kill by punching, close and face on.\n"
        .. "Nobody else can kill anybody at all.\n"
        .. "There is a wait between one kill and the next.\n"
        .. "Every body stays where it fell, for anybody to find.\n"
        .. "Alive? Type /accuse and Tab to name them.\n"
        .. "One name each. Get it wrong and it kills you.\n"
        .. "The murderer wins by emptying the lobby.\n"
        .. "On the clock, whoever is left walks out.",
    minPlayers = 3,

    saysOut = true,

    maps = { "cotmc" },
    levelsIn = {
        { level = LEVEL_CASTLE, area = 1 }, { level = LEVEL_CASTLE, area = 2 },
        { level = LEVEL_CASTLE, area = 3 },
    },

    roomsOut = {
        { level = LEVEL_CCM, area = 2 }, { level = LEVEL_TTM, area = 2 },
        { level = LEVEL_JRB, area = 2 }, { level = LEVEL_DDD, area = 1 },
        { level = LEVEL_RR, area = 1 },

        { level = LEVEL_SL, area = 2 }, { level = LEVEL_THI, area = 3 },

        { level = LEVEL_CCM, area = 1 }, { level = LEVEL_JRB, area = 1 },
        { level = LEVEL_LLL, area = 1 }, { level = LEVEL_LLL, area = 2 },
        { level = LEVEL_SSL, area = 1 }, { level = LEVEL_SSL, area = 2 },
        { level = LEVEL_WDW, area = 1 }, { level = LEVEL_TTM, area = 1 },
        { level = LEVEL_THI, area = 2 }, { level = LEVEL_TTC, area = 1 },
    },

    mainCourses = true,

    room = { sweep = { "cannons" } },

    unsolidInAFight = true,

    mods = "fog=2",
    defaultLimit = 300,

    target = { name = "seconds on the clock",
               asks = "How many seconds the round runs",
               clock = true,
               default = 300, min = 120, max = 600, step = 30 },

    caps = { tiebreak = false },

    outWord = "MURDERED",
    music = SEQ_LEVEL_SPOOKY,

    teams = false,

    options = {

        { key = "killers", name = "How many of you are the murderer",
          help = "the share of the lobby that is murdering",
          choices = {
              { key = "six", name = "one in six",
                help = "one up to eleven, two from twelve; the usual share" },
              { key = "four", name = "one in four",
                help = "two from eight, three from twelve; a big lobby empties" },
              { key = "ten", name = "one in ten",
                help = "one on their own, whatever the lobby holds" },
          } },

        { key = "wait", name = "How long between kills",
          help = "how long the lobby has to notice a body",
          choices = {
              { key = "five", name = "five seconds",
                help = "the usual wait" },
              { key = "ten", name = "ten seconds",
                help = "long enough to walk away and be somewhere else" },
              { key = "twenty", name = "twenty seconds",
                help = "a lobby of eight lasts most of the clock" },
              { key = "two", name = "two seconds",
                help = "a group standing together can be emptied in one walk" },
          } },

        { key = "sheriff", name = "Is there a sheriff",
          help = "one innocent gets a secret shot at the murderer",
          choices = {
              { key = "off", name = "no sheriff",
                help = "no second secret role" },
              { key = "one", name = "one sheriff",
                help = "exactly one, whatever the lobby holds" },
              { key = "eight", name = "one in eight",
                help = "TTT's own detective share - two of them at sixteen" },
          } },

        { key = "clock", name = "How the clock runs",
          help = "a fixed round, or one every death adds to",
          choices = {
              { key = "fixed", name = "fixed",
                help = "the clock runs down as set" },
              { key = "haste", name = "haste",
                help = "every death adds thirty seconds" },
          } },

        { key = "missing", name = "Announcing the dead",
          help = "say who is out at once, or only once a body is found",
          choices = {
              { key = "off", name = "announced at once",
                help = "the count drops the moment somebody dies" },
              { key = "on", name = "missing until found",
                help = "the lobby's own count waits for a body to be found" },
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

local function alive()
    return OF.gamemodes.with_role(ROLE_PLAYING)
end

function mode.holds_the_secret()
    return iAmTheMurderer
end

function mode.holds_the_sheriff()
    return iAmTheSheriff
end

local function am_dead()
    return OF.gamemodes.role(0) == ROLE_DEAD
end

local function shut_out_of_the_round()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if am_dead() then return false end
    if OF.gamemodes.role(0) ~= ROLE_PLAYING then return true end
    return not OF.util.can_play(0)
end

local function still_hunting()
    return iAmTheMurderer and not am_dead() and OF.util.can_play(0)
end

local function pulse()
    if OF.util.is_host() then

        silence = 0
        return
    end
    OF.util.send_anonymous({ ofp = PACKET_HERE })
end

local PACKET_ROLE = "ofMurderRole"
local murderMates = ""
local SHARES = { six = 6, four = 4, ten = 10 }

function OF.murder.wanted(count, way)
    local said = way or OF.gamemodes.option_now("killers")
    local per = SHARES[said] or SHARES.six
    return math.max(1, math.floor((count or 0) / per))
end

function OF.murder.mates()
    return murderMates
end
function OF.murder.count()
    if murderMates == "" then return 0 end
    local n = 0
    for _ in string.gmatch(murderMates, "[^,]+") do n = n + 1 end
    return n
end

local function accomplices()
    local set = {}
    for piece in string.gmatch(murderMates, "[^,]+") do
        local n = tonumber(piece)
        if n ~= nil then set[n] = true end
    end
    return set
end

local SHERIFF_SHARES = { eight = 8 }

function OF.murder.sheriffs_wanted(count, way)
    local said = way or OF.gamemodes.option_now("sheriff")
    if said == "one" then return 1 end
    local per = SHERIFF_SHARES[said]
    if per == nil then return 0 end
    return math.max(1, math.floor((count or 0) / per))
end

local PACKET_SHERIFF = "ofMurderSheriff"
local killersDealt = 0

local function tell_the_murderer(players)
    if not OF.util.is_host() then return false end
    if #players == 0 then return false end

    local it = OF.gamemodes.deal_it(players, OF.murder.wanted(#players), false)
    killersDealt = 0
    for _, entry in ipairs(players) do
        if it[entry.localIndex] then killersDealt = killersDealt + 1 end
    end

    local picked = {}
    for _, entry in ipairs(players) do
        if it[entry.localIndex] then table.insert(picked, entry) end
    end
    if #picked == 0 then return false end

    local mates = {}
    for _, entry in ipairs(picked) do
        local np = entry.np
        if np ~= nil then table.insert(mates, tostring(np.globalIndex)) end
    end
    local together = table.concat(mates, ",")

    local sent = false
    for _, entry in ipairs(picked) do
        if entry.localIndex == 0 then

            iAmTheMurderer = true
            murderMates = together
            sent = true
        elseif OF.util.send_to_player(entry.localIndex,
            { ofp = PACKET_ROLE, k = true, w = together }) then
            sent = true
        end
    end

    local wantSheriffs = OF.murder.sheriffs_wanted(#players)
    if wantSheriffs > 0 then

        local pool = {}
        for _, entry in ipairs(players) do
            if not it[entry.localIndex] then table.insert(pool, entry) end
        end
        local guards = OF.gamemodes.deal_fair(pool, wantSheriffs, "sheriff")
        for _, entry in ipairs(pool) do
            if guards[entry.localIndex] then
                if entry.localIndex == 0 then

                    iAmTheSheriff = true
                else
                    OF.util.send_to_player(entry.localIndex,
                        { ofp = PACKET_SHERIFF })
                end
            end
        end
    end

    return sent
end

local sheriff_leaves_the_gun

local function i_died()
    OF.gamemodes.set_role(0, ROLE_DEAD)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

    sheriff_leaves_the_gun()
end

local wrong_name_out

local sheriff_victim_out

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end

    if data.ofp == PACKET_HERE then
        if OF.util.is_host() then silence = 0 end
        return
    end

    if data.ofp ~= PACKET_ROLE then return end
    if data.from ~= 0 then return end

    if OF.util.asks(OF.pass, "settled") and OF.pass.settled()
        and not OF.pass.is_mine(data.pk) then
        return
    end
    if data.k == true then
        iAmTheMurderer = true

        if type(data.w) == "string" then murderMates = data.w end
    end

    if data.d == true then
        if data.g == true then wrong_name_out()
        elseif data.s == true then sheriff_victim_out()
        else i_died() end
    end
end)

OF.murder.PACKET_STRIKE = "ofMurderStrike"
function OF.murder.strike(victimGlobal)
    local victim = OF.util.local_from_global(tonumber(victimGlobal) or -1)
    if victim == nil then return false, "Nobody is there." end
    if victim == 0 then return false, "Not yourself." end
    local me = gNetworkPlayers[0]
    if me == nil then return false, "Nobody is there." end
    return OF.util.send_to_player(victim,
        { ofp = OF.murder.PACKET_STRIKE, g = me.globalIndex })
end

function OF.murder.struck(attackerGlobal)
    if OF.gamemodes.current() ~= mode then return false, "No round." end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false, "No round." end
    if OF.gamemodes.role(0) ~= ROLE_PLAYING then return false, "Already out." end
    local attacker = OF.util.local_from_global(tonumber(attackerGlobal) or -1)
    if attacker == nil or attacker == 0 then return false, "Nobody is there." end
    if OF.gamemodes.role(attacker) ~= ROLE_PLAYING then
        return false, "They are out."
    end
    local reach = OF.gamemodes.distance(0, attacker)
    if reach == nil then return false, "They are somewhere else." end
    if reach > HOST_REACH then return false, "Too far away." end
    i_died()
    return true
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if type(data) ~= "table" or data.ofp ~= OF.murder.PACKET_STRIKE then return end
    OF.murder.struck(data.g)
end)

local registered = false

local function register_the_kill()
    if registered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    registered = true
    OF.net.register_action("murderkill", "round_move",
        function(fromLocal, victimGlobal)

            if not OF.util.is_host() then return false, "Only the host." end
            local victim = OF.util.local_from_global(tonumber(victimGlobal))
            if victim == nil then return false, "Nobody is there." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
                return false, "No round."
            end

            if OF.gamemodes.role(victim) ~= ROLE_PLAYING then
                return false, "They are already out."
            end
            if victim == fromLocal then return false, "Not yourself." end

            local asker = gNetworkPlayers[fromLocal]
            if asker == nil then return false, "Nobody is there." end

            local reach = OF.gamemodes.distance(fromLocal, victim)
            if reach == nil then return false, "They are somewhere else." end
            if reach > HOST_REACH then return false, "Too far away." end

            local who = asker.globalIndex
            if (hostGrace[who] or 0) > 0 then return false, "Not yet." end
            hostGrace[who] = host_grace()

            if victim == 0 then
                i_died()
                return true
            end
            return OF.util.send_to_player(victim,
                { ofp = PACKET_ROLE, d = true })
        end)
end

hook_event(HOOK_UPDATE, function() register_the_kill() end)

local KILL_CONE = 0x2000

local KILL_HEIGHT = 160

local function is_a_swing(action)
    return action == ACT_PUNCHING or action == ACT_MOVE_PUNCHING
        or action == ACT_WATER_PUNCH
end

local function off_angle(m, them)
    local toward = atan2s(them.pos.z - m.pos.z, them.pos.x - m.pos.x)
    local off = toward - m.faceAngle.y
    while off > 32767 do off = off - 65536 end
    while off < -32768 do off = off + 65536 end
    return math.abs(off)
end

local function pointed_at(m, them)
    return off_angle(m, them) <= KILL_CONE
end

local function reach_to(localIndex)
    local na, nb = gNetworkPlayers[0], gNetworkPlayers[localIndex]
    if na == nil or nb == nil then return nil end
    if na.currLevelNum ~= nb.currLevelNum then return nil end
    if na.currAreaIndex ~= nb.currAreaIndex then return nil end
    if not nb.currPositionValid then return nil end

    local ma, mb = gMarioStates[0], gMarioStates[localIndex]
    if ma == nil or mb == nil or ma.pos == nil or mb.pos == nil then
        return nil
    end
    local dx = ma.pos.x - mb.pos.x
    local dy = ma.pos.y - mb.pos.y
    local dz = ma.pos.z - mb.pos.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function floats(them)
    if them == nil then return false end
    local action = them.action or 0
    if OF.gamemodes.ON_A_POLE ~= nil and OF.gamemodes.ON_A_POLE[action] then
        return true
    end
    if OF.util.has_flag(action, ACT_FLAG_SWIMMING or 0x2000)
        or OF.util.has_flag(action, ACT_FLAG_HANGING or 0x200000)
        or OF.util.has_flag(action, ACT_FLAG_METAL_WATER or 0x4000) then
        return true
    end
    if OF.util.asks(OF.cheats, "hover_wet") and OF.cheats.hover_wet(them) then
        return true
    end
    return false
end

local function cannot_swing(m)
    if m == nil then return false end
    local action = m.action or 0
    if OF.gamemodes.ON_A_POLE ~= nil and OF.gamemodes.ON_A_POLE[action] then
        return true
    end
    return OF.util.has_flag(action, ACT_FLAG_HANGING or 0x200000)
        or OF.util.has_flag(action, ACT_FLAG_METAL_WATER or 0x4000)
end

local function aimed_at(swimming, touch)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end

    local ours = accomplices()

    local best, bestGap = nil, nil
    for _, entry in ipairs(alive()) do
        local them = gMarioStates[entry.localIndex]
        if entry.localIndex ~= 0 and entry.np ~= nil
            and not ours[entry.np.globalIndex]
            and them ~= nil and them.pos ~= nil then
            local gap = reach_to(entry.localIndex)
            if gap ~= nil and gap < KILL_RANGE
                and (swimming or touch or floats(them)
                    or math.abs(them.pos.y - m.pos.y) < KILL_HEIGHT)
                and (bestGap == nil or gap < bestGap)
                and (touch or pointed_at(m, them)) then
                best, bestGap = entry, gap
            end
        end
    end
    return best
end

local NOTICE_RANGE = KILL_RANGE * 3

local NOTICE_CONE = 0x4000

local function why_nothing(swimming)
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end

    local best, bestGap = nil, nil
    for _, entry in ipairs(OF.util.connected_players()) do
        local them = gMarioStates[entry.localIndex]
        if entry.localIndex ~= 0 and entry.np ~= nil
            and them ~= nil and them.pos ~= nil then
            local gap = reach_to(entry.localIndex)
            if gap ~= nil and gap < NOTICE_RANGE
                and (bestGap == nil or gap < bestGap)
                and off_angle(m, them) <= NOTICE_CONE then
                best, bestGap = entry, gap
            end
        end
    end
    if best == nil then return nil end

    local them = gMarioStates[best.localIndex]

    if accomplices()[best.np.globalIndex] then
        return "They are on your side"
    end

    local role = OF.gamemodes.role(best.localIndex)
    if role == ROLE_DEAD then return "They are already out" end
    if role ~= ROLE_PLAYING then
        return "This round is not dealing them in"
    end

    if not swimming and not floats(them)
        and math.abs(them.pos.y - m.pos.y) >= KILL_HEIGHT then
        return "Get level with them first"
    end

    if off_angle(m, them) > KILL_CONE then return "Face them square on" end
    if bestGap >= KILL_RANGE then return "Too far - get closer" end
    return nil
end

local swingWas = false

local PUNCH_AGAIN = { [3] = true, [6] = true }

local swingArgWas = nil

local refuseIn = 0
local REFUSE_QUIET = 45

local OPENING_FRAMES = 10 * 30
local opening = 0

local function refuse(text, value)
    if refuseIn > 0 then return end
    refuseIn = REFUSE_QUIET
    OF.notify.show(text, "bad", 3, value)
    OF.gamemodes.cue("bad")
end

local BODY_MODEL = E_MODEL_BOO

local BODY_SPIN = 0x100

local BODY_HEARD = 3600

local GUN_MODEL = E_MODEL_METAL_BOX
local GUN_SPIN = 0x100

local bodies = {}
local seenAlive = {}

local foundProgress = {}

function mode.scenery()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if not OF.util.can_play(0) then
        swingWas = false
        swingArgWas = nil
    end

    if opening > 0 then opening = opening - 1 end

    for _, entry in ipairs(OF.util.connected_players()) do
        local np = entry.np
        if np ~= nil then
            local who = np.globalIndex
            local role = OF.gamemodes.role(entry.localIndex)
            if role == ROLE_PLAYING then
                seenAlive[who] = true
            elseif role == ROLE_DEAD and seenAlive[who] and bodies[who] == nil then

                local spot = OF.gamemodes.here_place(entry.localIndex)
                if spot ~= nil then
                    seenAlive[who] = nil
                    bodies[who] = spot

                    local gap = OF.gamemodes.distance(0, entry.localIndex)
                    if entry.localIndex ~= 0 and gap ~= nil
                        and gap <= BODY_HEARD then
                        local bm = gMarioStates[entry.localIndex]
                        OF.gamemodes.round_sound_from(bm ~= nil and bm.marioObj or nil,
                            SOUND_OBJ_BOO_LAUGH_SHORT)
                    end
                end
            end
        end
    end

    for who, spot in pairs(bodies) do
        OF.gamemodes.mark_place("murderbody" .. tostring(who), BODY_MODEL,
            spot, BODY_SPIN)
    end

    local gunGlobal = tonumber(gGlobalSyncTable.ofMurderGun)
    if gunGlobal ~= nil and bodies[gunGlobal] ~= nil then
        OF.gamemodes.mark_place("murdergun", GUN_MODEL, bodies[gunGlobal],
            GUN_SPIN)
    else
        OF.gamemodes.hide_token("murdergun")
    end
end

local function forget_the_bodies()
    bodies = {}
    seenAlive = {}
    swingWas = false
    swingArgWas = nil
    refuseIn = 0

    opening = 0
    foundProgress = {}

    if OF.util.is_host() then
        OF.util.publish("ofMurderFound", "")
        OF.util.publish("ofMurderGun", "")
    end
    sheriffHeldB = false
end

local function missing_on()
    return OF.gamemodes.option_now("missing") == "on"
end

local FOUND_RANGE = 150
local FOUND_HOLD = 30

local function is_confirmed(globalIndex)
    local found = gGlobalSyncTable.ofMurderFound
    if type(found) ~= "string" or found == "" then return false end
    for piece in string.gmatch(found, "[^,]+") do
        if tonumber(piece) == globalIndex then return true end
    end
    return false
end

local function update_the_search()
    if not missing_on() then return end
    if am_dead() or not OF.util.can_play(0) then return end

    for who, spot in pairs(bodies) do
        if is_confirmed(who) then
            foundProgress[who] = nil
        else
            local gap = OF.gamemodes.distance_to_place(spot)
            if gap ~= nil and gap <= FOUND_RANGE then
                local at = (foundProgress[who] or 0) + 1
                if at >= FOUND_HOLD then
                    foundProgress[who] = nil
                    OF.util.report(OF.net.host_does("murderfound", who))
                else
                    foundProgress[who] = at
                end
            else
                foundProgress[who] = nil
            end
        end
    end
end

local function confirmed_count()
    if not missing_on() then return #alive() end
    local found = gGlobalSyncTable.ofMurderFound
    local gone = 0
    if type(found) == "string" and found ~= "" then
        for _ in string.gmatch(found, "[^,]+") do gone = gone + 1 end
    end
    return math.max(#alive(), #OF.gamemodes.still_here() - gone)
end

local searchRegistered = false

local function register_the_search()
    if searchRegistered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    searchRegistered = true

    OF.net.register_action("murderfound", "round_move",
        function(fromLocal, victimGlobal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
                return false, "No round."
            end
            local who = tonumber(victimGlobal)
            if who == nil then return false, "There is nothing there." end

            if is_confirmed(who) then return true end

            local victimLocal = OF.util.local_from_global(who)
            if victimLocal == nil
                or OF.gamemodes.role(victimLocal) ~= ROLE_DEAD then
                return false, "There is nothing there."
            end
            if OF.gamemodes.role(fromLocal) ~= ROLE_PLAYING then
                return false, "The dead do not get a say."
            end
            local spot = bodies[who]
            if spot == nil then return false, "There is nothing there." end
            if not OF.gamemodes.at_place(spot, FOUND_RANGE * 2, fromLocal) then
                return false, "Too far away."
            end

            local found = gGlobalSyncTable.ofMurderFound
            found = (type(found) == "string" and found ~= "")
                and (found .. "," .. tostring(who)) or tostring(who)
            OF.util.publish("ofMurderFound", found)

            local finder = gNetworkPlayers[fromLocal]
            local victimNp = gNetworkPlayers[victimLocal]
            if finder == nil or victimNp == nil then return true end
            local ago = math.max(0, math.floor(OF.gamemodes.since_start()
                - (gPlayerSyncTable[victimLocal].ofGmTime or 0)))

            local desc = string.format("%s - about %.0fs ago",
                OF.util.plain(victimNp.name), ago)
            OF.notify.send_all("@ found a body: @", "warn", 6,
                finder.name, desc)
            return true
        end)
end

hook_event(HOOK_UPDATE, function() register_the_search() end)

local PACKET_NAMED = "ofMurderNamed"
local ACCUSE_ACTION  = "murderaccuse"
local CAUGHT_ACTION  = "murdercaught"
local CLEARED_ACTION = "murderwrong"
local REVEAL_ACTION  = "murderwasme"
local ANSWER_WINDOW = 5 * 30

local accusing = {}
local named = {}

local spent = {}

local outOfIt = {}

local function stamp(localIndex)
    local id = OF.util.player_id(localIndex)
    if id ~= nil then return id end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    return "seat" .. tostring(np.globalIndex)
end

local holding = false

local function give_the_voices_back()
    holding = false
    if OF.util.asks(OF.mute, "round_release") then OF.mute.round_release() end
end

local revealed = nil

local revealedSet = {}

local revealSent = nil
local REVEAL_EVERY = 15

local REVEAL_WAIT = 60
local revealWaitFrom = nil

local REVEAL_AT = 3

local function accuser_of(globalIndex)
    local entry = named[globalIndex]
    return entry ~= nil and entry.by or nil
end

local function forget_accusation(accusedGlobal)
    local entry = named[accusedGlobal]
    if entry == nil then return nil end
    named[accusedGlobal] = nil
    accusing[entry.by] = nil
    return entry.by
end

local function answer_being_named(byGlobal)

    if iAmTheMurderer and byGlobal ~= nil and accomplices()[byGlobal] then
        OF.util.report(OF.net.host_does(CLEARED_ACTION))
        return
    end
    if iAmTheMurderer then
        OF.util.report(OF.net.host_does(CAUGHT_ACTION))
    else
        OF.util.report(OF.net.host_does(CLEARED_ACTION))
    end
end

function wrong_name_out()
    OF.gamemodes.set_role(0, ROLE_DEAD)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.notify.show("Wrong name. You are out of it.", "bad", 6)

    sheriff_leaves_the_gun()
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end
    if data.ofp ~= PACKET_NAMED then return end

    if not OF.util.from_host_effect(data) then

        if OF.util.asks(OF.guard, "note") then
            OF.guard.note(OF.lang.t("an accusation that did not come from the host"))
        end
        return
    end

    local by = nil
    if OF.util.from_host(data) then by = tonumber(data.by) end

    answer_being_named(by)
end)

local accusationRegistered = false

local function register_the_accusation()
    if accusationRegistered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    accusationRegistered = true

    OF.net.register_action(ACCUSE_ACTION, "round_move",
        function(fromLocal, targetGlobal)

            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
                return false, "No round."
            end

            local asker = gNetworkPlayers[fromLocal]
            if asker == nil then return false, "Nobody is there." end

            if OF.gamemodes.role(fromLocal) ~= ROLE_PLAYING then
                return false, "The dead do not get a say."
            end

            local mine = stamp(fromLocal)
            if mine ~= nil and spent[mine] then
                return false, "You have named somebody already this round."
            end

            local target = OF.util.local_from_global(tonumber(targetGlobal))
            if target == nil then return false, "Nobody is there." end
            if target == fromLocal then return false, "Not yourself." end

            if OF.gamemodes.role(target) ~= ROLE_PLAYING then
                return false, "They are already out."
            end

            local who = asker.globalIndex
            local victim = gNetworkPlayers[target]
            if victim == nil then return false, "Nobody is there." end
            local at = victim.globalIndex

            if accusing[who] ~= nil then return false, "Wait for an answer." end
            if named[at] ~= nil then return false, "Somebody named them already." end

            accusing[who] = at

            named[at] = { by = who, id = mine, left = ANSWER_WINDOW }

            if target ~= 0
                and not OF.util.send_to_player(target,
                    { ofp = PACKET_NAMED, by = who }) then
                forget_accusation(at)
                return false, "They are somewhere else."
            end

            if mine ~= nil then spent[mine] = true end

            OF.notify.send_all("@ names @", "warn", 5,
                asker.name, victim.name)

            if target == 0 then answer_being_named(who) end
            return true
        end)

    OF.net.register_action(CAUGHT_ACTION, "round_move",
        function(fromLocal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
                return false, "No round."
            end
            local them = gNetworkPlayers[fromLocal]
            if them == nil then return false, "Nobody is there." end

            local by = accuser_of(them.globalIndex)
            if by == nil then return false, "Nobody named you." end
            forget_accusation(them.globalIndex)

            local winner = OF.util.local_from_global(by)
            local np = winner ~= nil and gNetworkPlayers[winner] or nil
            if np == nil then return false, "Nobody is there." end

            OF.gamemodes.finish("@ named the murderer, @ - the innocents won.",
                np.name, np.name, them.name)
            return true
        end)

    OF.net.register_action(CLEARED_ACTION, "round_move",
        function(fromLocal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
                return false, "No round."
            end
            local them = gNetworkPlayers[fromLocal]
            if them == nil then return false, "Nobody is there." end
            local by = accuser_of(them.globalIndex)
            if by == nil then return false, "Nobody named you." end
            forget_accusation(them.globalIndex)

            local loser = OF.util.local_from_global(by)
            if loser == nil then return false, "Nobody is there." end
            local np = gNetworkPlayers[loser]
            if np == nil then return false, "Nobody is there." end

            if OF.gamemodes.role(loser) == ROLE_PLAYING then
                OF.notify.send_all("@ named the wrong person", "bad", 5,
                    np.name)
                if loser == 0 then
                    wrong_name_out()
                else

                    OF.util.report(OF.util.send_to_player(loser,
                        { ofp = PACKET_ROLE, d = true, g = true }))
                end
            end
            return true
        end)

    OF.net.register_action(REVEAL_ACTION, "round_move",
        function(fromLocal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            local them = gNetworkPlayers[fromLocal]
            if them == nil then return false, "Nobody is there." end
            if revealed == nil then revealed = them.globalIndex end
            revealedSet[them.globalIndex] = true
            return true
        end)
end

local deadNotice = 0

local function on_chat_message(m, message)
    if m == nil then return end
    if OF.gamemodes.current() ~= mode then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if OF.gamemodes.role(m.playerIndex) ~= ROLE_DEAD then return end

    if m.playerIndex == 0 and deadNotice <= 0 then
        deadNotice = 90
        OF.notify.show("The dead say nothing until the round ends", "bad", 4)
    end
    local np = gNetworkPlayers[m.playerIndex]

    if not (OF.util.asks(OF.mute, "is_muted") and OF.mute.is_muted(m.playerIndex))
        and OF.util.asks(OF.chatlog, "add_system") then

        OF.chatlog.add_system("said this while dead: " .. tostring(message),
            OF.util.plain(np ~= nil and np.name or "?"))
    end
    return false
end

hook_event(HOOK_ON_CHAT_MESSAGE, on_chat_message)

hook_event(HOOK_UPDATE, function()
    if deadNotice > 0 then deadNotice = deadNotice - 1 end
    register_the_accusation()

    if holding and OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
        give_the_voices_back()
    end
end)

local ACCUSE_PROSE =
    "name the murderer. One name each, and a wrong one puts you out"
hook_chat_command("accuse",

    "- name the murderer. One name each, and a wrong one puts you out",
    function(msg)
        if OF.gamemodes.current() ~= mode
            or OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
            OF.util.chat(OF.lang.t(
                "There is no round to name anybody in."), "mode")
            return true
        end
        if am_dead() then
            OF.util.chat(OF.lang.t(
                "The dead do not get a say."), "mode")
            return true
        end

        local typed = string.gsub(tostring(msg or ""), "^%s+", "")
        typed = string.gsub(typed, "%s+$", "")
        if typed == "" then

            OF.util.chat(OF.lang.t(
                "Type a name after it - press Tab and it fills itself in."))
            return true
        end

        local who = OF.util.find_player_by_name(typed)
        local np = who ~= nil and gNetworkPlayers[who] or nil
        if np == nil then
            OF.util.chat(OF.lang.t(
                "Nobody in this lobby answers to that."), "mode")
            return true
        end

        OF.util.report(OF.net.host_does(ACCUSE_ACTION, np.globalIndex))
        return true
    end)

local offeredNames = ""
local function nameable_now()
    local names = {}
    for _, entry in ipairs(alive()) do
        if entry.localIndex ~= 0 and entry.np ~= nil then
            local name = OF.util.plain(entry.np.name or "")
            if name ~= "" then table.insert(names, name) end
        end
    end
    table.sort(names)
    return names
end

local function describe_the_round()

    if not OF.util.asks(OF.util, "describe") then return end

    local live = OF.gamemodes.current() == mode
        and OF.gamemodes.state() == OF.gamemodes.ACTIVE
        and not am_dead()
    local names = live and nameable_now() or {}
    local now = table.concat(names, "|")
    if now == offeredNames then return end

    if #names == 0 then

        OF.util.optional("update_chat_command_description", nil,
            "accuse", "- " .. ACCUSE_PROSE)
        offeredNames = ""
        return
    end

    if OF.util.describe("accuse", names, ACCUSE_PROSE) then
        offeredNames = now
    end
end

local describeIn = 0

hook_event(HOOK_UPDATE, function()
    if describeIn > 0 then
        describeIn = describeIn - 1
        return
    end
    describeIn = 15
    describe_the_round()
end)

local SHERIFF_HOST_REACH = 20000

local PICKUP_RANGE = 150

local PACKET_SHERIFF_CHECK = "ofMurderSheriffCheck"
local SHERIFF_SHOT_ACTION   = "murdersheriffshot"
local SHERIFF_CAUGHT_ACTION = "murdersheriffcaught"
local SHERIFF_MISS_ACTION   = "murdersheriffmiss"
local SHERIFF_PICKUP_ACTION = "murdersheriffpickup"
local SHERIFF_ANSWER_WINDOW = 5 * 30

local sheriffCaseFor = {}

local function answer_sheriff_shot()
    if iAmTheMurderer then
        OF.util.report(OF.net.host_does(SHERIFF_CAUGHT_ACTION))
    else
        OF.util.report(OF.net.host_does(SHERIFF_MISS_ACTION))
    end
end

sheriff_victim_out = function()
    OF.gamemodes.set_role(0, ROLE_DEAD)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.notify.show("The sheriff got you. Wrong call.", "bad", 6)

end

local function sheriff_backfire_out()
    OF.gamemodes.set_role(0, ROLE_DEAD)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    iAmTheSheriff = false
    OF.notify.show(
        "Wrong call. You go down too - the gun is on the floor.", "bad", 6)

end

function sheriff_leaves_the_gun()
    if not iAmTheSheriff then return end
    iAmTheSheriff = false
    OF.util.report(OF.net.host_does(SHERIFF_DOWN_ACTION))
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil then return end

    if data.ofp == PACKET_SHERIFF then
        if data.from ~= 0 then return end
        if OF.util.asks(OF.pass, "settled") and OF.pass.settled()
            and not OF.pass.is_mine(data.pk) then
            return
        end
        if data.bf == true then
            sheriff_backfire_out()
        else
            iAmTheSheriff = true
            sheriffSpent = false
            OF.notify.show(
                "You are the sheriff. Nobody was told. One shot.",
                "warn", 8)
        end
        return
    end

    if data.ofp == PACKET_SHERIFF_CHECK then

        if not OF.util.from_host_effect(data) then return end
        answer_sheriff_shot()
        return
    end
end)

local sheriffRegistered = false

local function register_the_sheriff()
    if sheriffRegistered then return end
    if not OF.util.asks(OF.net, "register_action") then return end
    sheriffRegistered = true

    OF.net.register_action(SHERIFF_SHOT_ACTION, "panel",
        function(fromLocal, targetGlobal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
                return false, "No round."
            end
            local target = OF.util.local_from_global(tonumber(targetGlobal))
            if target == nil then return false, "Nobody is there." end
            if target == fromLocal then return false, "Not yourself." end
            if OF.gamemodes.role(target) ~= ROLE_PLAYING then
                return false, "They are already out."
            end
            local shooter = gNetworkPlayers[fromLocal]
            if shooter == nil then return false, "Nobody is there." end

            local reach = OF.gamemodes.distance(fromLocal, target)
            if reach == nil then return false, "They are somewhere else." end
            if reach > SHERIFF_HOST_REACH then return false, "Too far away." end

            local at = gNetworkPlayers[target]
            if at == nil then return false, "Nobody is there." end
            if sheriffCaseFor[at.globalIndex] ~= nil then
                return false, "Somebody already fired at them."
            end
            sheriffCaseFor[at.globalIndex] =
                { by = shooter.globalIndex, left = SHERIFF_ANSWER_WINDOW }

            if target == 0 then
                answer_sheriff_shot()
            elseif not OF.util.send_to_player(target,
                { ofp = PACKET_SHERIFF_CHECK }) then
                sheriffCaseFor[at.globalIndex] = nil
                return false, "That did not reach them."
            end
            return true
        end)

    OF.net.register_action(SHERIFF_CAUGHT_ACTION, "round_move",
        function(fromLocal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            local them = gNetworkPlayers[fromLocal]
            if them == nil then return false, "Nobody is there." end
            if sheriffCaseFor[them.globalIndex] == nil then
                return false, "Nobody shot you."
            end
            sheriffCaseFor[them.globalIndex] = nil

            local names = {}
            for _, entry in ipairs(alive()) do
                if entry.np ~= nil
                    and entry.np.globalIndex ~= them.globalIndex then
                    table.insert(names, entry.np.name)
                end
            end
            if #names == 0 then
                OF.gamemodes.finish(
                    "The sheriff got the murderer, @ - the innocents won.", nil,
                    them.name)
            else
                OF.gamemodes.finish(
                    "The sheriff got the murderer, @ - the innocents won.",
                    { names = names }, them.name)
            end
            return true
        end)

    OF.net.register_action(SHERIFF_MISS_ACTION, "round_move",
        function(fromLocal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            local them = gNetworkPlayers[fromLocal]
            if them == nil then return false, "Nobody is there." end
            local case = sheriffCaseFor[them.globalIndex]
            if case == nil then return false, "Nobody shot you." end
            sheriffCaseFor[them.globalIndex] = nil

            if OF.gamemodes.role(fromLocal) == ROLE_PLAYING then
                if fromLocal == 0 then
                    sheriff_victim_out()
                else
                    OF.util.report(OF.util.send_to_player(fromLocal,
                        { ofp = PACKET_ROLE, d = true, s = true }))
                end
            end

            local shooterLocal = OF.util.local_from_global(case.by)
            if shooterLocal == 0 then
                sheriff_backfire_out()
            elseif shooterLocal ~= nil then
                OF.util.report(OF.util.send_to_player(shooterLocal,
                    { ofp = PACKET_SHERIFF, bf = true }))
            end

            OF.util.publish("ofMurderGun", tostring(case.by))
            return true
        end)

    OF.net.register_action(SHERIFF_PICKUP_ACTION, "round_move",
        function(fromLocal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then
                return false, "No round."
            end
            if OF.gamemodes.role(fromLocal) ~= ROLE_PLAYING then
                return false, "They are already out."
            end
            local gunGlobal = tonumber(gGlobalSyncTable.ofMurderGun)
            if gunGlobal == nil then return false, "It is already gone." end
            local spot = bodies[gunGlobal]
            if spot == nil then return false, "It is already gone." end
            if not OF.gamemodes.at_place(spot, PICKUP_RANGE, fromLocal) then
                return false, "Too far away."
            end

            OF.util.publish("ofMurderGun", "")
            if fromLocal == 0 then
                iAmTheSheriff = true
                sheriffSpent = false
                OF.notify.show(
                    "You picked it up. Nobody was told. One shot.",
                    "warn", 8)
            else
                OF.util.send_to_player(fromLocal, { ofp = PACKET_SHERIFF })
            end
            return true
        end)

    OF.net.register_action(SHERIFF_DOWN_ACTION, "round_move",
        function(fromLocal)
            if not OF.util.is_host() then return false, "Only the host." end
            if OF.gamemodes.current() ~= mode then return false, "No round." end
            local them = gNetworkPlayers[fromLocal]
            if them == nil then return false, "Nobody is there." end
            if OF.gamemodes.role(fromLocal) ~= ROLE_DEAD then
                return false, "Still in the round."
            end
            if tonumber(gGlobalSyncTable.ofMurderGun) ~= nil then
                return false, "Already down."
            end
            OF.util.publish("ofMurderGun", tostring(them.globalIndex))
            return true
        end)
end

hook_event(HOOK_UPDATE, function() register_the_sheriff() end)

local function sheriff_pickup_poll()
    if iAmTheMurderer or iAmTheSheriff then return end
    if am_dead() or not OF.util.can_play(0) then return end
    local gunGlobal = tonumber(gGlobalSyncTable.ofMurderGun)
    if gunGlobal == nil then return end
    local spot = bodies[gunGlobal]
    if spot == nil then return end
    local gap = OF.gamemodes.distance_to_place(spot)
    if gap == nil or gap > PICKUP_RANGE then return end
    OF.util.report(OF.net.host_does(SHERIFF_PICKUP_ACTION))
end

local function sheriff_input(m)
    if not iAmTheSheriff or sheriffSpent then return end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end
    if am_dead() or not OF.util.can_play(0) then return end
    if m == nil then return end
    local pad = m.controller
    if pad == nil then return end

    local aiming = OF.util.has_flag(pad.buttonDown, L_TRIG)

    local nowB
    if OF.util.asks(OF.input, "aim_held") then
        nowB = OF.input.aim_held(m, B_BUTTON)
    else
        nowB = OF.util.has_flag(pad.buttonDown, B_BUTTON)
    end
    local pressed = aiming and nowB and not sheriffHeldB
    sheriffHeldB = nowB
    if not pressed then return end

    sheriffSpent = true

    if not OF.util.asks(OF.util, "view_axis") then return end
    local ex, ey, ez, dx, dy, dz = OF.util.view_axis()
    if ex == nil then return end

    local hit, along = nil, nil
    if OF.util.asks(OF.cheats, "rifle_target") then
        hit, along = OF.cheats.rifle_target(ex, ey, ez, dx, dy, dz)
    end

    if OF.util.asks(OF.cheats, "show_a_shot") then

        local mx, my, muzzleZ = ex, ey, ez
        if OF.util.asks(OF.cheats, "muzzle_of") then
            mx, my, muzzleZ = OF.cheats.muzzle_of(m, ex, ey, ez)
        end
        local reach = along
        if reach == nil and OF.util.asks(OF.cheats, "shot_reaches") then
            reach = OF.cheats.shot_reaches(ex, ey, ez, dx, dy, dz, nil)
        end
        reach = reach or SHERIFF_HOST_REACH
        OF.cheats.show_a_shot(mx, my, muzzleZ,
            ex + dx * reach, ey + dy * reach, ez + dz * reach)
    end

    if hit == nil then
        OF.notify.show("Your one shot missed. It is spent.", "bad", 5)
        return
    end

    OF.util.report(OF.net.host_does(SHERIFF_SHOT_ACTION, hit.np.globalIndex))
    OF.notify.show("Shot fired. It is spent.", "bad", 4)
end

function OF.murder.sheriff_aims()
    if not iAmTheSheriff or sheriffSpent then return false end
    if OF.gamemodes.current() ~= mode then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    return not am_dead() and OF.util.can_play(0)
end

mode.target.auto = function(n)
    local k = math.max(1, OF.murder.wanted(n))
    local each = math.max(0, n - k) / k
    return OF.util.clamp(OF.gamemodes.round_to(90 + 20 * each, 30), 150, 300)
end

function mode.setup(players, options)

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_PLAYING)
    end

    if options == nil or tonumber(options.limit) == nil then

        local want = OF.util.clamp(OF.gamemodes.auto_target(mode, players,
            options or { target = OF.gamemodes.target_for(mode.key) }),
            mode.target.min, mode.target.max)
        OF.util.publish("ofGmLimit", want)
    end

    OF.util.report(tell_the_murderer(players))
end

function mode.on_start()
    cooldown = 0

    describe_the_round()

    pulseIn = 0
    silence = 0
    hostGrace = {}
    accusing = {}
    named = {}

    spent = {}
    outOfIt = {}

    give_the_voices_back()
    revealed = nil
    revealedSet = {}
    revealSent = nil
    revealWaitFrom = nil

    forget_the_bodies()

    opening = OPENING_FRAMES

    mode.reveal_role()
end

local aliveCluster = { you = { label = "ALIVE", score = 0 } }
function mode.cluster()
    if OF.gamemodes.is_waiting() then return nil end
    aliveCluster.you.label = string.upper(OF.lang.t("Alive"))
    aliveCluster.you.score = confirmed_count()
    return aliveCluster
end

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "mm2", name = "MM2 classic", help = "one sheriff, the dead announced",
      sets = { sheriff = "one" } },
    { key = "ttt", name = "TTT", help = "detectives, haste, the missing until found, a ten-second wait",
      sets = { sheriff = "eight", clock = "haste", missing = "on", wait = "ten" } },
    { key = "chaos", name = "Chaos", help = "one in four, two seconds between kills",
      sets = { killers = "four", wait = "two" } },
}

function mode.reveal_role()
    if not OF.util.asks(OF.hud, "banner") then return nil end
    if iAmTheMurderer then
        local others = {}
        if OF.murder.count() <= 1 then
            return OF.hud.banner("role", OF.lang.t("YOU ARE THE MURDERER"), nil, { tone = "bad" })
        end
        local me = gNetworkPlayers[0]
        for piece in string.gmatch(murderMates, "[^,]+") do
            local index = OF.util.local_from_global(tonumber(piece))
            local np = index ~= nil and gNetworkPlayers[index] or nil
            if np ~= nil and (me == nil or np.globalIndex ~= me.globalIndex) then
                table.insert(others, OF.util.short_name(np.name, 16))
            end
        end
        return OF.hud.banner("role", OF.lang.t("YOU ARE THE MURDERER"),
            #others > 0 and OF.lang.fill("With @", table.concat(others, ", ")) or nil,
            { tone = "bad" })
    end
    return OF.hud.banner("role", OF.lang.t("YOU ARE INNOCENT"), nil)
end

function mode.late_join(localIndex)
    local id = stamp(localIndex)
    if id ~= nil and outOfIt[id] then return ROLE_DEAD end
    return ROLE_PLAYING
end

function mode.update()
    if cooldown > 0 then cooldown = cooldown - 1 end
    if refuseIn > 0 then refuseIn = refuseIn - 1 end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    update_the_search()
    sheriff_pickup_poll()

    if still_hunting() then
        pulseIn = pulseIn - 1
        if pulseIn <= 0 then
            pulseIn = PULSE_EVERY
            pulse()
        end
    end

    if iAmTheMurderer then
        local left = OF.gamemodes.time_left()
        local now = OF.util.optional("get_global_timer", 0) or 0
        if left ~= nil and left <= REVEAL_AT
            and (revealSent == nil or now - revealSent >= REVEAL_EVERY) then
            revealSent = now
            OF.util.report(OF.net.host_does(REVEAL_ACTION))
        end
    end

    if am_dead() or not iAmTheMurderer then return end
    if not OF.util.can_play(0) then return end

    local m = gMarioStates[0]
    local action = (m ~= nil and m.action) or 0
    local nowSwinging = m ~= nil and is_a_swing(action)

    local arg = nowSwinging and m ~= nil and m.actionArg or nil
    local pressed = nowSwinging
        and (not swingWas
            or (arg ~= swingArgWas and PUNCH_AGAIN[arg] == true))
    swingWas = nowSwinging
    swingArgWas = arg

    local touched = nil
    if not pressed then
        if not cannot_swing(m) or cooldown > 0 then return end
        touched = aimed_at(true, true)
        if touched == nil then return end
    end

    local swimming = action == ACT_WATER_PUNCH
    local target = touched or aimed_at(swimming)
    if target == nil then

        local why = why_nothing(swimming)
        if why ~= nil then refuse(why) end
        return
    end

    if cooldown > 0 then
        refuse("Not yet - @s before you can again",
            string.format("%.0f", cooldown / 30))
        return
    end

    local answered, why = OF.murder.strike(target.np.globalIndex)
    if not OF.util.report(answered, why) then
        if why == nil or why == "" then refuse("That did not reach them") end
        return
    end
    cooldown = OF.murder.cooldown_frames()
    OF.notify.show("Done. Walk away.", "bad", 4)
end

function mode.host_update()

    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_DEAD)) do
        local id = stamp(entry.localIndex)

        if id ~= nil and not outOfIt[id] and haste_on() then
            OF.util.publish("ofGmLimit",
                (gGlobalSyncTable.ofGmLimit or 0) + HASTE_PER_DEATH)
        end
        if id ~= nil then outOfIt[id] = true end
        if OF.util.asks(OF.mute, "is_muted")
            and not OF.mute.is_muted(entry.localIndex)
            and OF.mute.round_silence(entry.localIndex) then
            holding = true
        end
    end

    for who, left in pairs(hostGrace) do
        if left > 1 then hostGrace[who] = left - 1 else hostGrace[who] = nil end
    end

    local expired = {}
    for at, entry in pairs(named) do
        entry.left = entry.left - 1
        if entry.left <= 0 then table.insert(expired, at) end
    end
    for _, at in ipairs(expired) do

        local entry = named[at]
        local mine = entry ~= nil and entry.id or nil
        local by = forget_accusation(at)
        if by ~= nil then
            if mine ~= nil then spent[mine] = nil end
            OF.notify.send_to(by, "No answer. Name somebody again.", "warn", 5)
        end
    end

    local expiredShots = {}
    for at, case in pairs(sheriffCaseFor) do
        case.left = case.left - 1
        if case.left <= 0 then table.insert(expiredShots, at) end
    end
    for _, at in ipairs(expiredShots) do sheriffCaseFor[at] = nil end

    silence = silence + 1
    if silence > SILENCE_LIMIT then
        OF.gamemodes.abandon("Nobody is hunting any more.")
        return
    end

    local left = alive()
    if #left <= 1 and #OF.gamemodes.still_here() > 1 then
        if #left == 1 then

            OF.gamemodes.finish("@ won.",
                left[1].np.name, left[1].np.name)
        else
            OF.gamemodes.finish("Nobody won.")
        end
    end
end

local function reveals_in()
    local n = 0
    for _ in pairs(revealedSet) do n = n + 1 end
    return n
end

function mode.waiting_for_reveal()

    if not OF.util.is_host() then return false end
    if reveals_in() >= math.max(1, killersDealt) then return false end
    local now = OF.util.optional("get_global_timer", 0) or 0
    if revealWaitFrom == nil then revealWaitFrom = now end
    return now - revealWaitFrom < REVEAL_WAIT
end

function mode.on_timeout()
    local left = alive()
    if #left == 0 then
        OF.gamemodes.finish("Nobody won.")
        return
    end

    if mode.waiting_for_reveal() then return end

    local names = {}
    local whoItWas = {}
    for _, entry in ipairs(left) do
        if entry.np ~= nil and entry.np.name ~= nil then
            if revealedSet[entry.np.globalIndex] then
                whoItWas[#whoItWas + 1] = entry.np.name
            else
                table.insert(names, entry.np.name)
            end
        end
    end

    local named = whoItWas[1]
    if named == nil and revealed ~= nil then
        local li = OF.util.local_from_global(revealed)
        local np = li ~= nil and gNetworkPlayers[li] or nil
        if np ~= nil and np.connected ~= false then named = np.name end
    end
    if #whoItWas > 1 then named = table.concat(whoItWas, " & ") end

    if #names == 0 then
        OF.gamemodes.finish("Time - nobody named them.")
        return
    end

    if named == nil then
        OF.gamemodes.finish(#names == 1 and "Time - 1 player won." or "Time - @ players won.",
            { names = names }, tostring(#names))
        return
    end

    if #names == 1 then
        OF.gamemodes.finish("Time - 1 player won. It was @.", { names = names }, named)
    else
        OF.gamemodes.finish("Time - @ players won. It was @.", { names = names },
            tostring(#names), named)
    end
end

function mode.terms()
    return OF.lang.t("name the murderer, or be alive at the end")
end

function mode.before_mario_update(m)
    if am_dead() then
        OF.gamemodes.set_ghost(true)
        return
    end
    sheriff_input(m)
end

function mode.cleanup()

    iAmTheMurderer = false

    murderMates = ""
    cooldown = 0

    iAmTheSheriff = false
    sheriffSpent = false

    sheriffCaseFor = {}

    pulseIn = 0
    silence = 0

    hostGrace = {}

    accusing = {}
    named = {}

    spent = {}
    outOfIt = {}

    give_the_voices_back()
    revealed = nil
    revealedSet = {}
    revealSent = nil
    revealWaitFrom = nil

    forget_the_bodies()

    describe_the_round()
end

function mode.hud()
    if am_dead() then

        OF.gamemodes.out_banner("You are dead")
        return
    end

    if iAmTheMurderer and OF.util.asks(OF.hud, "state_line") then
        if shut_out_of_the_round() then
            OF.hud.state_line("murderer", OF.lang.t("Tell the host"), { prio = 80, tone = "bad" })
        elseif cooldown > 0 then
            OF.hud.state_line("murderer", OF.lang.t("Wait"), { prio = 60, tone = "bad",
                figure = math.ceil(cooldown / 30) })
        else
            OF.hud.state_line("murderer", OF.lang.t("Ready"), { prio = 60, tone = "bad", colour = true })
        end
    end

    OF.util.legend(mode.controls_lines(), { dimLast = false })
end

function mode.controls_lines()
    if am_dead() then return {} end

    local lines = {}

    if OF.murder.sheriff_aims() then
        lines[#lines + 1] = OF.lang.t("Hold L - aim")
        lines[#lines + 1] = OF.lang.t("L + B - your one shot")
        lines[#lines + 1] = OF.lang.t("Without L: B punches")
    end
    lines[#lines + 1] = OF.lang.t("/accuse <name> - Tab fills it in")

    lines[#lines + 1] = OF.lang.t("A wrong name kills you")
    return lines
end

OF.gamemodes.register(mode)
