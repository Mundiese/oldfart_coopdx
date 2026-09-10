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

local hostGrace = {}

local iAmTheMurderer = false
local cooldown = 0

local PACKET_HERE = "ofMurderHere"
local PULSE_EVERY = 30
local SILENCE_LIMIT = 5 * 30

local pulseIn = 0

local silence = 0

local mode = {
    key = "murder",
    resultsBy = "survival",
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

    maps = OF.gamemodes.ARENA_SET,

    mainCourses = true,

    room = { sweep = { "cannons" } },
    defaultLimit = 300,

    target = { name = "seconds on the clock",
               asks = "How many seconds the round runs",
               default = 300, min = 120, max = 600, step = 30 },
    music = SEQ_LEVEL_SPOOKY,

    teams = false,

    options = {

        { key = "killers", name = "How many of you are the murderer",
          help = "one against a full lobby is a round nobody can win, and "
              .. "three in a small one is a bloodbath - this is the share",
          choices = {
              { key = "six", name = "one in six",
                help = "one up to eleven players, two from twelve - the "
                    .. "share this mode has always dealt" },
              { key = "four", name = "one in four",
                help = "two from eight and three from twelve, so a big "
                    .. "lobby empties fast and the accusations start early" },
              { key = "ten", name = "one in ten",
                help = "one on their own in any lobby this game can hold - "
                    .. "the hardest job in the mode and the quietest round" },
          } },

        { key = "wait", name = "How long between kills",
          help = "the murderer's whole risk is being somewhere a body turns "
              .. "up - this is how long the lobby has to notice one",
          choices = {
              { key = "five", name = "five seconds",
                help = "the wait this mode has always held itself to" },
              { key = "ten", name = "ten seconds",
                help = "long enough that a murderer has to walk away and be "
                    .. "somewhere else before they can go again" },
              { key = "twenty", name = "twenty seconds",
                help = "a lobby of eight lasts most of the clock, so the "
                    .. "accusation decides it rather than the body count" },
              { key = "two", name = "two seconds",
                help = "how this played before there was a press at all - a "
                    .. "group standing together can be emptied in one walk" },
          } },

    },
}

local function alive()
    return OF.gamemodes.with_role(ROLE_PLAYING)
end

function mode.holds_the_secret()
    return iAmTheMurderer
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

local function tell_the_murderer(players)
    if not OF.util.is_host() then return false end
    if #players == 0 then return false end

    local it = OF.gamemodes.deal_it(players, OF.murder.wanted(#players), false)

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
    return sent
end

local function i_died()
    OF.gamemodes.set_role(0, ROLE_DEAD)
    OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())
    OF.notify.show("You were murdered", "bad", 6)
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
end

local wrong_name_out

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
        if data.g == true then wrong_name_out() else i_died() end
    end
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

local function aimed_at(swimming)
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
                and (swimming
                    or math.abs(them.pos.y - m.pos.y) < KILL_HEIGHT)
                and (bestGap == nil or gap < bestGap)
                and pointed_at(m, them) then
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

    if not swimming
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
    OF.sounds.play(OF.sounds.DENIED)
end

local function metal_water_dead_end(m)
    if m == nil or m.pos == nil then return end
    if not OF.util.has_flag(m.action or 0, ACT_FLAG_METAL_WATER) then return end
    if refuseIn > 0 or cooldown > 0 then return end

    if aimed_at(true) == nil then return end
    refuse("Not while you are metal")
end

local BODY_MODEL = E_MODEL_BOO

local BODY_SPIN = 0x100

local BODY_HEARD = 3600

local bodies = {}
local seenAlive = {}

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
                        OF.sounds.play(SOUND_OBJ_BOO_LAUGH_SHORT)
                    end
                end
            end
        end
    end

    for who, spot in pairs(bodies) do
        OF.gamemodes.mark_place("murderbody" .. tostring(who), BODY_MODEL,
            spot, BODY_SPIN)
    end
end

local function forget_the_bodies()
    bodies = {}
    seenAlive = {}
    swingWas = false
    swingArgWas = nil
    refuseIn = 0

    opening = 0
end

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

local revealSent = false

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
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)
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
                OF.util.plain(asker.name), OF.util.plain(victim.name))

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

            OF.gamemodes.finish("@ named the murderer - it was @.",
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
                    OF.util.plain(np.name))
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
            revealed = them.globalIndex
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
            OF.util.chat("\\#ff6060\\" .. OF.lang.t(
                "There is no round to name anybody in."))
            return true
        end
        if am_dead() then
            OF.util.chat("\\#ff6060\\" .. OF.lang.t(
                "The dead do not get a say."))
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
            OF.util.chat("\\#ff6060\\" .. OF.lang.t(
                "Nobody in this lobby answers to that."))
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

local function hold_the_name_tags()
    if not OF.util.asks(OF.rules, "lend") then return end
    OF.util.report(OF.rules.lend("nametags", mode.key, 1))
end

local function let_the_name_tags_go()
    if not OF.util.asks(OF.rules, "give_back") then return end
    OF.rules.give_back("nametags", mode.key)
end

function mode.setup(players, options)

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, ROLE_PLAYING)
    end

    if options == nil or tonumber(options.limit) == nil then
        local want = OF.util.clamp(math.floor(tonumber(options ~= nil
            and options.target) or OF.gamemodes.target_for(mode.key)
            or mode.target.default), mode.target.min, mode.target.max)
        OF.util.publish("ofGmLimit", want)
    end

    hold_the_name_tags()

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
    revealSent = false

    forget_the_bodies()

    opening = OPENING_FRAMES

    OF.notify.show("Alive? /accuse one name - Tab fills it in, wrong is out",
        "info", 8)

    if iAmTheMurderer then
        OF.notify.show("You are the murderer. Nobody was told.", "bad", 8)
    else
        OF.notify.show("One of you is the murderer. Stay together, or do not.",
            "warn", 8)
    end
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

    if still_hunting() then
        pulseIn = pulseIn - 1
        if pulseIn <= 0 then
            pulseIn = PULSE_EVERY
            pulse()
        end
    end

    if iAmTheMurderer and not revealSent then
        local left = OF.gamemodes.time_left()
        if left ~= nil and left <= REVEAL_AT then
            revealSent = true
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
    if not pressed then

        metal_water_dead_end(m)
        return
    end

    local swimming = action == ACT_WATER_PUNCH
    local target = aimed_at(swimming)
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

    local answered, why = OF.net.host_does("murderkill",
        target.np.globalIndex)
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

    silence = silence + 1
    if silence > SILENCE_LIMIT then
        OF.gamemodes.abandon("Nobody is hunting any more.")
        return
    end

    local left = alive()
    if #left <= 1 and #OF.gamemodes.still_here() > 1 then
        if #left == 1 then

            OF.gamemodes.finish("@ is the last one standing.",
                left[1].np.name, left[1].np.name)
        else
            OF.gamemodes.finish("Nobody made it out.")
        end
    end
end

function mode.on_timeout()
    local left = alive()
    if #left == 0 then
        OF.gamemodes.finish("Nobody made it out.")
        return
    end

    if revealed == nil then
        OF.gamemodes.finish("Time - @ survived.", nil, tostring(#left))
        return
    end

    local names = {}
    local whoItWas = nil
    for _, entry in ipairs(left) do
        if entry.np ~= nil and entry.np.name ~= nil then
            if entry.np.globalIndex == revealed then
                whoItWas = entry.np.name
            else
                table.insert(names, entry.np.name)
            end
        end
    end

    if #names == 0 then
        OF.gamemodes.finish("Time - nobody named them.")
        return
    end

    if whoItWas == nil then
        OF.gamemodes.finish("Time - @ got out alive.", { names = names },
            tostring(#names))
        return
    end

    OF.gamemodes.finish("Time - @ got out alive. It was @.",
        { names = names }, tostring(#names), whoItWas)
end

function mode.terms()
    return OF.lang.t("name the murderer, or be alive at the end")
end

function mode.before_mario_update(m)
    if not am_dead() then return end
    OF.gamemodes.set_ghost(true)
end

function mode.cleanup()

    iAmTheMurderer = false

    murderMates = ""
    cooldown = 0

    pulseIn = 0
    silence = 0

    hostGrace = {}

    accusing = {}
    named = {}

    spent = {}
    outOfIt = {}

    give_the_voices_back()

    let_the_name_tags_go()
    revealed = nil
    revealSent = false

    forget_the_bodies()

    describe_the_round()
end

function mode.hud()
    if am_dead() then
        OF.util.banner(OF.lang.t("You are dead - no more accusing"),
            1.0, 255, 140, 140, 255)
        return
    end

    local text = OF.lang.fill("@ still alive", tostring(#alive()))
    local r, g, b = 255, 255, 255
    if iAmTheMurderer then
        if shut_out_of_the_round() then

            text = OF.lang.t(
                "You are the murderer   -   the round left you out   -   tell the host")
        elseif cooldown > 0 then
            text = OF.lang.fill(
                "You are the murderer   -   @ left   -   @s until you can again",
                tostring(#alive()), string.format("%.0f", cooldown / 30))
        else

            text = OF.lang.fill(
                "You are the murderer   -   @ left   -   punch one, face on",
                tostring(#alive()))
        end
        r, g, b = 255, 160, 160
    end

    local card = nil
    if opening > 0 then
        card = { text = OF.lang.t(iAmTheMurderer
                and "Nobody was told. Do not let anybody watch."
                or "One of you is the murderer. Work out who."),
                 scale = 0.85, r = r, g = g, b = b }
    end
    OF.util.banner(text, 1.0, r, g, b, 255, { under = card })

    if iAmTheMurderer and OF.murder.count() > 1 then
        local others = {}
        local me = gNetworkPlayers[0]
        for piece in string.gmatch(murderMates, "[^,]+") do
            local index = OF.util.local_from_global(tonumber(piece))
            local np = index ~= nil and gNetworkPlayers[index] or nil
            if np ~= nil and (me == nil or np.globalIndex ~= me.globalIndex) then
                table.insert(others, OF.util.plain(np.name))
            end
        end
        if #others > 0 then
            OF.util.banner(OF.lang.fill("With you: @",
                table.concat(others, ", ")), 0.90, 255, 200, 200, 255)
        end
    end

    OF.util.banner(OF.lang.t(
        "Accuse with /accuse - Tab lists the names, one name each"),
        0.8, 200, 200, 210, 255)
end

OF.gamemodes.register(mode)
