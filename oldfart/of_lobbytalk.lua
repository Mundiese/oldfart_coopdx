OF = OF or {}
OF.lobbytalk = OF.lobbytalk or {}

local talk = OF.lobbytalk

talk.PACKET_ASK = "ltAsk"
talk.PACKET_LINE = "ltLine"
talk.POLL_KEY = "ofPoll"
talk.RTV_KEY = "ofRtv"
talk.READY_KEY = "ofReady"
talk.CLOCK_KEY = "ofCountdown"
local FIELD = "|"
talk.TEXT_MAX = 160

talk.QUESTION_MAX = 48
talk.ANSWER_MAX = 18
talk.ANSWERS_MIN = 2
talk.ANSWERS_MAX = 6
talk.POLL_SECONDS = 30
talk.READY_SECONDS = 20
talk.RESULT_SECONDS = 6

talk.POLL_ROOM_WAIT = 20
talk.POLL_ASKER_WAIT = 120

talk.ROLL_WAIT = 90
talk.NUMBER_WAIT = 5
talk.CLOCK_MIN = 3
talk.CLOCK_MAX = 3600

talk.LINE_GAP = 0.6

talk.dicePool = 1

talk.starFeedOn = true

function talk.reset_options()
    if not OF.util.is_host() then return false end
    local moved = talk.starFeedOn ~= true or talk.dicePool ~= 1
    talk.starFeedOn, talk.dicePool = true, 1
    return moved
end

talk.FEED_GAP = 0.5
talk.FEED_QUEUE = 4

talk.FEED_REPEAT = 2

talk.STAR_GAP = 2

local function now()
    if clock_elapsed ~= nil then return clock_elapsed() end
    return 0
end

local function trim(text)
    return (string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1"))
end

function talk.clean(text, most)
    local plain = trim(OF.util.plain(tostring(text or "")))
    plain = string.gsub(plain, "|", "/")
    if most ~= nil and #plain > most then return nil end
    return plain
end

local function name_of(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return "?" end
    return OF.util.plain(np.name)
end

local function chat_named(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return "?" end
    return OF.util.chat_name(np.name)
end
local function toast_named(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return "?" end
    return OF.util.name_safe(np.name)
end

local splitKept, splitCount = {}, 0
local SPLIT_PATTERN = "([^" .. FIELD .. "]*)" .. FIELD
local function split(text)
    text = text or ""
    local kept = splitKept[text]
    if kept ~= nil then return kept end
    local out = {}
    for piece in string.gmatch(text .. FIELD, SPLIT_PATTERN) do
        out[#out + 1] = piece
    end
    if splitCount >= 64 then splitKept, splitCount = {}, 0 end
    splitKept[text] = out
    splitCount = splitCount + 1
    return out
end
talk.split_wire = split

function talk.voters()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local away = OF.util.asks(OF.vote, "is_away") and OF.vote.is_away(entry.localIndex)
        if not away then list[#list + 1] = entry end
    end
    return list
end

local function is_staff(localIndex)
    if OF.util.is_host_player(localIndex) then return true end
    return OF.perms.tier(localIndex) >= OF.perms.required("message", localIndex)
end

local function may(localIndex, feature)
    if OF.util.is_host_player(localIndex) then return true end
    return OF.perms.tier(localIndex) >= OF.perms.required(feature)
end

local function jailed(localIndex)
    return OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex)
end

function talk.may_say(localIndex, text)
    if OF.util.asks(OF.mute, "may_talk") and not OF.mute.may_talk(localIndex) then
        return false, "The lobby is quiet - you cannot talk right now."
    end
    if OF.util.asks(OF.mute, "is_muted") and OF.mute.is_muted(localIndex) then
        return false, "You are muted in this lobby."
    end

    local modes = OF.gamemodes
    if modes ~= nil and modes.state() == modes.ACTIVE then
        local mode = modes.current()
        if mode ~= nil and mode.key == "murder" and modes.role(localIndex) == "out" then
            return false, "The dead say nothing until the round ends"
        end
    end
    if text ~= nil and OF.util.asks(OF.filter, "blocks") then
        local word = OF.filter.blocks(text)
        local hold = word ~= nil
        if hold and OF.util.asks(OF.trouble, "would") then
            hold = OF.trouble.would("filter", "would have hidden a line from @ ('@')",
                name_of(localIndex), OF.util.plain(word))
        end
        if hold then
            return false, OF.lang.fill("Nobody saw that - '@' is on the lobby filter",
                OF.util.plain(word))
        end
    end
    return true
end

function talk.side_of(localIndex)
    local modes = OF.gamemodes
    if modes == nil or modes.state() == modes.OFF then
        return nil, "Team chat works while a round with sides or roles is on."
    end
    if not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then
        return nil, "This round has no sides - team chat is for rounds that do."
    end
    local side = OF.teams.of(localIndex)
    if side == nil or side == "" then
        return nil, "You are not on a side this round."
    end
    return side
end

local FFA = "Everybody plays for themselves in this round - no team chat."
local SIDES = "This round's teams are its sides - /t works when they are dealt."
local SECRET = "This round keeps its roles secret - no team chat in it."
local ALONE = "Everybody in this round has the same job - no side to talk to."
talk.ROLE_CHAT = {

    oneflag = { why = FFA },
    turf = { why = FFA },
    rocketarena = { why = FFA },
    blastgrid = { why = FFA },
    shellbattle = { why = FFA },
    assassins = { secret = true, why = SECRET },
    bank = { why = FFA },
    booksquirm = { why = FFA },
    bounty = { why = FFA },
    coinrush = { why = FFA },
    shooter = { why = FFA },
    bossrush = { why = ALONE },
    chompfever = { why = FFA },
    copsandrobbers = { ch = { cop = "cops", robber = "robbers" } },
    crown = { why = FFA },
    ctf = { why = FFA },

    football = { why = FFA },

    volleyball = { why = FFA },
    deflect = { why = FFA },
    domination = { why = FFA },
    flood = { why = ALONE },
    glassbridge = { why = ALONE },
    hexagone = { why = FFA },
    hexheat = { why = FFA },
    hideseek = { ch = { ["a hider"] = "hiders", ["a seeker"] = "seekers", out = "out" } },
    hotpotato = { why = FFA },
    hotrope = { why = FFA },
    koth = { why = FFA },
    laststanding = { why = FFA },
    lavaleave = { why = FFA },
    line = { why = ALONE },
    logroll = { why = FFA },
    manhunt = { ch = { hunting = "hunters", ["the runner"] = "runners" } },
    blast = { why = FFA },
    bombsaway = { why = FFA },
    blizzard = { why = FFA },
    bombxing = { why = FFA },
    bumperballs = { why = FFA },
    murder = { secret = true, why = SECRET },
    oitc = { why = FFA },
    prophunt = { ch = { ["a hider"] = "hiders", ["a seeker"] = "seekers", out = "out" } },
    greendemon = { why = FFA },
    shellrace = { why = FFA },
    downhill = { why = FFA },
    simon = { why = FFA },
    smash = { why = FFA },
    spots = { why = FFA },
    silverfive = { why = FFA },
    wanted = { why = FFA },
    rabbitchase = { why = FFA },
    bombsort = { why = FFA },
    frenzy = { why = FFA },
    flyguy = { why = FFA },
    firesweep = { why = FFA },
    snd = { why = FFA },
    lakitu = { why = FFA },
    onoffclimb = { why = FFA },
    megarampage = { why = FFA },
    sumo = { why = FFA },
    zombies = { ch = { infected = "infected", surviving = "survivors" } },
    hideballoon = { why = FFA },
    sardines = { ch = { ["a hider"] = "the tin", ["a seeker"] = "seekers" } },
}

local function role_rule()
    local modes = OF.gamemodes
    if modes == nil or modes.state() == modes.OFF then return nil end
    local mode = modes.current()
    if mode == nil then return nil end
    return talk.ROLE_CHAT[mode.key], mode
end

function talk.channel_of(localIndex)
    local rule, mode = role_rule()
    if rule ~= nil and rule.secret then return nil, rule.why or SECRET end
    local sidesOn = OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
    local side, why = talk.side_of(localIndex)
    if side ~= nil then
        local team = OF.teams.find(side)
        if team ~= nil then
            return "side:" .. side, OF.lang.fill("@ side", OF.teams.side_name(team.key)), team.r, team.g, team.b
        end
        return "side:" .. side, OF.lang.fill("@ side", side), 220, 220, 220
    end
    if sidesOn or rule == nil then return nil, why end
    if rule.ch == nil then

        if mode ~= nil and mode.teams then return nil, SIDES end
        return nil, rule.why or FFA
    end
    local ch = rule.ch[OF.gamemodes.role(localIndex)]
    if ch == nil then return nil, "You are not on a side this round." end
    return "role:" .. ch, ch, 120, 210, 255
end

local lastLine = {}
local rollWait = {}
local pollAskerWait = {}

local function ask(fields)
    if OF.util.is_host() then
        return talk.request(0, network_global_index_from_local(0), fields)
    end
    fields.ofp = talk.PACKET_ASK
    if not OF.util.send_to_host(fields) then
        return false, "There is no host to ask yet."
    end
    return true
end

talk.CHANNEL_ROLE = {
    t = { opts = { bare = true } }, w = { opts = { bare = true } },
    wb = { opts = { bare = true } },
    kf = { role = "mode" }, r = { role = "warn" },
}

local function deliver(localIndex, line, fromGlobal, channel)
    local how = talk.CHANNEL_ROLE[channel or ""] or {}
    line = OF.util.chat_line(line, how.role, how.opts)
    if localIndex == 0 then
        talk.show_line(line, fromGlobal, channel)
        return true
    end
    if not OF.util.is_host() then return false end
    return OF.util.send_to_player(localIndex, {
        ofp = talk.PACKET_LINE, t = line, f = fromGlobal, c = channel })
end

talk.lastWhisperFrom = nil
function talk.show_line(line, fromGlobal, channel)
    if type(line) ~= "string" or line == "" then return false end
    djui_chat_message_create(line)
    if channel == "w" and type(fromGlobal) == "number"
        and fromGlobal ~= network_global_index_from_local(0) then
        talk.lastWhisperFrom = fromGlobal
        if OF.util.asks(OF.sounds, "play") then OF.sounds.play(OF.sounds.TICK) end
    end
    if OF.util.asks(OF.chatlog, "add_notice") then
        OF.chatlog.add_notice(OF.util.plain(line))
    end
    return true
end

local function host_keeps(line)
    if OF.util.asks(OF.chatlog, "add_notice") then

        OF.chatlog.add_notice(OF.util.plain((string.gsub(line, "[\1\2]", ""))))
    end
end

local function too_fast(askerGlobal)
    local at = now()
    local last = lastLine[askerGlobal]
    if last ~= nil and at - last < talk.LINE_GAP then return true end
    lastLine[askerGlobal] = at
    return false
end

local function say_team(asker, askerGlobal, text)
    local key, label, r, g, b = talk.channel_of(asker)
    if key == nil then return false, label end
    local members = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if talk.channel_of(entry.localIndex) == key then
            members[#members + 1] = entry.localIndex
        end
    end
    if #members < 2 then return false, "Nobody else is on your side right now." end
    local line = "[" .. label .. "] "
        .. chat_named(asker) .. ": " .. text
    local hostHeard = false
    for _, localIndex in ipairs(members) do
        deliver(localIndex, line, askerGlobal, "t")
        if localIndex == 0 then hostHeard = true end
    end
    local hostPlays = OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(0)
    if not hostHeard and not hostPlays then host_keeps(line) end
    return true, #members
end

local function say_whisper(asker, askerGlobal, toGlobal, text)
    local target = OF.util.local_from_global(tonumber(toGlobal))
    if target == nil or gNetworkPlayers[target] == nil
        or not gNetworkPlayers[target].connected then
        return false, "They have left the lobby."
    end
    if target == asker then return false, "That is you." end
    local to = "[" .. OF.lang.fill("from @", chat_named(asker))
        .. "] " .. text
    local back = "[" .. OF.lang.fill("to @", chat_named(target))
        .. "] " .. text
    deliver(target, to, askerGlobal, "w")
    deliver(asker, back, nil, "wb")
    if target ~= 0 and asker ~= 0 then
        host_keeps(OF.lang.fill("[@ to @] ", name_of(asker), name_of(target)) .. text)
    end
    return true
end

talk.KILL_FEED = {
    hideseek = { "@ tagged @", at = "of_gm_hideseek.lua" },
    prophunt = { "@ found @", at = "of_gm_hideseek.lua" },
    sardines = { "@ found @", at = "of_gm_sardines.lua" },
    shooter = { "@ fragged @", self = "@ blew themselves up", at = "of_gm_shooter.lua" },
    oitc = { "@ fragged @", self = "@ blew themselves up", at = "of_gm_shooter.lua" },
    rocketarena = { "@ rocketed @", at = "of_gm_rocketarena.lua" },
    zombies = { "@ infected @", at = "of_gm_zombies.lua" },

    copsandrobbers = { "@ busted @", "@ freed everybody", at = "of_gm_copsandrobbers.lua" },
    bounty = { "@ fragged @", self = "@ blew themselves up", at = "of_gm_shooter.lua" },
    snd = { "@ fragged @", self = "@ blew themselves up", at = "of_gm_shooter.lua" },
    manhunt = { "@ tagged @, the Runner", at = "of_gm_manhunt.lua" },
}

function talk.feed(actorLocal, victimLocal, kind)
    if type(actorLocal) ~= "number" or type(victimLocal) ~= "number" then return false end
    if actorLocal == victimLocal then return false end
    return talk.feed_globals(network_global_index_from_local(actorLocal),
        network_global_index_from_local(victimLocal), kind)
end

function talk.feed_self(globalIndex)
    return talk.feed_globals(globalIndex, globalIndex, "s")
end

function talk.feed_globals(actorGlobal, victimGlobal, kind)
    if type(actorGlobal) ~= "number" or type(victimGlobal) ~= "number" then return false end
    if actorGlobal == victimGlobal and kind ~= "s" then return false end
    local fields = { w = "kf", a = actorGlobal, v = victimGlobal, k = kind or 1 }
    if OF.util.is_host() then
        return talk.request(0, network_global_index_from_local(0), fields)
    end
    fields.ofp = talk.PACKET_ASK
    return OF.util.send_to_host(fields) == true
end

local function playing(localIndex)
    return OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(localIndex)
end

function talk.feed_hears(localIndex)
    if playing(localIndex) then return true end
    local modes = OF.gamemodes
    if modes == nil or modes.state() == modes.OFF then return false end
    return OF.util.asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(localIndex) == true
end

local feedQueue = {}
local feedDropped = 0
local feedLastAt = nil
local feedSeen = {}

local function send_feed(line)
    for _, entry in ipairs(OF.util.connected_players()) do
        if talk.feed_hears(entry.localIndex) then
            deliver(entry.localIndex, line, nil, "kf")
        end
    end
end

local function feed_line(asker, askerGlobal, data)
    local modes = OF.gamemodes
    if modes == nil or modes.state() ~= modes.ACTIVE then return false end
    local mode = modes.current()
    local row = mode ~= nil and talk.KILL_FEED[mode.key] or nil
    if row == nil then return false end
    local a, v = tonumber(data.a), tonumber(data.v)
    if a == nil or v == nil then return false end

    local template
    if a == v then
        template = data.k == "s" and row.self or nil
    else
        template = row[tonumber(data.k) or 1]
    end
    if type(template) ~= "string" then return false end

    if askerGlobal ~= a and askerGlobal ~= v and asker ~= 0 then return false end
    local aLocal, vLocal = OF.util.local_from_global(a), OF.util.local_from_global(v)
    if aLocal == nil or vLocal == nil then return false end
    if not playing(aLocal) or not playing(vLocal) then return false end
    local at = now()
    local key = tostring(a) .. ":" .. tostring(v) .. ":" .. template
    if feedSeen[key] ~= nil and at - feedSeen[key] < talk.FEED_REPEAT then return false end
    feedSeen[key] = at
    if #feedQueue >= talk.FEED_QUEUE then
        feedDropped = feedDropped + 1
        return true
    end

    feedQueue[#feedQueue + 1] = OF.lang.fill(template, name_of(aLocal), name_of(vLocal))
    return true
end

function talk.pump_feed(at)
    if not OF.util.is_host() then return false end
    at = at or now()
    if feedLastAt ~= nil and at - feedLastAt < talk.FEED_GAP then return false end
    local line = table.remove(feedQueue, 1)
    if line == nil then
        if feedDropped <= 0 then return false end
        line = OF.lang.fill("another @ in that burst", feedDropped)
        feedDropped = 0
    end
    feedLastAt = at
    send_feed(line)
    return true
end

local function drop_feed()
    feedQueue, feedDropped, feedLastAt, feedSeen = {}, 0, nil, {}
end

local starWait = {}
local starSaid = {}

talk.CASTLE_PLACES = {}
local function castle_place(level, area, name)
    if level ~= nil then
        talk.CASTLE_PLACES[level] = talk.CASTLE_PLACES[level] or {}
        talk.CASTLE_PLACES[level][area] = name
    end
end
castle_place(LEVEL_CASTLE, 1, "the castle's main hall")
castle_place(LEVEL_CASTLE, 2, "the castle upstairs")
castle_place(LEVEL_CASTLE, 3, "the castle basement")
castle_place(LEVEL_CASTLE_COURTYARD, 1, "the castle courtyard")
castle_place(LEVEL_CASTLE_GROUNDS, 1, "the castle grounds")

local function place_of(course, level, area)
    for _, entry in ipairs(OF.COURSES or {}) do
        if entry.num == course then return entry.name end
    end
    local castle = talk.CASTLE_PLACES[level]
    if castle ~= nil then
        local named = castle[area] or castle[1]

        if area ~= nil and castle[area] == nil and level == LEVEL_CASTLE then
            named = "the castle"
        end
        return OF.lang.t(named)
    end
    return OF.util.level_name(level, area)
end
talk.place_of = place_of

local function star_line(asker, askerGlobal, data)
    if not talk.starFeedOn then return false end
    if playing(asker) then return false end
    local course, level, star = tonumber(data.c), tonumber(data.l), tonumber(data.s)
    if course == nil or level == nil or star == nil then return false end

    local area = tonumber(data.a)
    if area ~= nil and (area ~= math.floor(area) or area < 1 or area > 7) then area = nil end
    if course ~= math.floor(course) or star ~= math.floor(star) then return false end
    if course < 0 or course > 25 or star < 1 or star > 7 then return false end
    local at = now()
    if starWait[askerGlobal] ~= nil and at - starWait[askerGlobal] < talk.STAR_GAP then
        return false
    end

    local said = tostring(askerGlobal) .. ":" .. tostring(level) .. ":"
        .. tostring(course) .. ":" .. tostring(star)
    if starSaid[said] then return false end
    starSaid[said] = true
    starWait[askerGlobal] = at
    local name = OF.util.asks(OF.ledger, "star_name") and OF.ledger.star_name(course, star)
        or OF.lang.fill("Star @", star)
    talk.say_star(talk.star_text(asker, name, place_of(course, level, area)))
    return true
end

function talk.star_text(takerIndex, starName, placeName)
    local np = gNetworkPlayers[takerIndex]
    local taker = np ~= nil and OF.util.chat_name(np.name) or "?"
    return OF.lang.fill("@ got @", taker,
        OF.lang.fill("@ in @", tostring(starName or ""), tostring(placeName or "")))
end

function talk.say_star(line)
    for _, entry in ipairs(OF.util.connected_players()) do
        if not playing(entry.localIndex) then
            deliver(entry.localIndex, line, nil, "sf")
        end
    end
end

function talk.bonus_star_line(taker, starName, placeName)
    if not OF.util.is_host() then return false end
    if not talk.starFeedOn then return false end
    if playing(taker) then return false end
    talk.say_star(talk.star_text(taker, starName, placeName))
    return true
end

talk.starsBefore = nil
talk.starsBeforeCourse = nil
function talk.note_stars_before(m)
    if m == nil or m.playerIndex ~= 0 or save_file_get_star_flags == nil then return end
    local np = gNetworkPlayers[0]
    if np == nil then return end
    local course = np.currCourseNum or 0
    local file = OF.util.asks(OF.ledger, "file_index") and OF.ledger.file_index() or 0
    talk.starsBefore = save_file_get_star_flags(file, course - 1)
    talk.starsBeforeCourse = course
end

function talk.had_star(course, index)
    if type(talk.starsBefore) ~= "number" or talk.starsBeforeCourse ~= course then
        return false
    end
    return OF.util.has_flag(talk.starsBefore, 2 ^ index)
end

function talk.took_a_star(m, obj, interactType, interacted)
    if m == nil or m.playerIndex ~= 0 then return false end
    if interactType ~= INTERACT_STAR_OR_KEY then return false end
    if interacted == false then return false end
    if playing(0) then return false end
    if OF.util.optional("obj_has_behavior_id", 0, obj, id_bhvBowserKey) ~= 0 then

        talk.causeAt.key = now()
        return false
    end
    local index = OF.util.star_act_index(obj)
    local np = gNetworkPlayers[0]
    if index == nil or np == nil then return false end

    if talk.had_star(np.currCourseNum, index) then return false end
    return ask({ w = "star", c = np.currCourseNum, l = np.currLevelNum,
        a = np.currAreaIndex, s = index + 1 }) == true
end

talk.PROGRESS = {
    { flag = "SAVE_FLAG_HAVE_WING_CAP", line = "The red switch was pressed - wing caps are out" },
    { flag = "SAVE_FLAG_HAVE_METAL_CAP", line = "The green switch was pressed - metal caps are out" },
    { flag = "SAVE_FLAG_HAVE_VANISH_CAP", line = "The blue switch was pressed - vanish caps are out" },
    { flag = "SAVE_FLAG_HAVE_KEY_1", line = "The first Bowser key was won" },
    { flag = "SAVE_FLAG_HAVE_KEY_2", line = "The second Bowser key was won" },
    { flag = "SAVE_FLAG_UNLOCKED_BASEMENT_DOOR", line = "The basement door was unlocked" },
    { flag = "SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR", line = "The upstairs door was unlocked" },
    { flag = "SAVE_FLAG_MOAT_DRAINED", line = "The castle moat was drained" },
    { flag = "SAVE_FLAG_UNLOCKED_PSS_DOOR", line = "The slide's star door opened" },
    { flag = "SAVE_FLAG_UNLOCKED_WF_DOOR", line = "Whomp's Fortress's star door opened" },
    { flag = "SAVE_FLAG_UNLOCKED_JRB_DOOR", line = "Jolly Roger Bay's star door opened" },
    { flag = "SAVE_FLAG_UNLOCKED_CCM_DOOR", line = "Cool, Cool Mountain's star door opened" },
    { flag = "SAVE_FLAG_UNLOCKED_BITDW_DOOR", line = "The 8-star door to Bowser opened" },
    { flag = "SAVE_FLAG_UNLOCKED_BITFS_DOOR", line = "The 30-star door to Bowser opened" },
    { flag = "SAVE_FLAG_UNLOCKED_50_STAR_DOOR", line = "The 50-star door opened" },
}
talk.PROGRESS_BURST = 2
talk.progressWas = nil
talk.progressSaid = {}

talk.PROGRESS_WAIT = 2
talk.CLAIM_WINDOW = 3
talk.PROGRESS_CAUSE = {
    SAVE_FLAG_HAVE_WING_CAP = "cap", SAVE_FLAG_HAVE_METAL_CAP = "cap",
    SAVE_FLAG_HAVE_VANISH_CAP = "cap",
    SAVE_FLAG_HAVE_KEY_1 = "key", SAVE_FLAG_HAVE_KEY_2 = "key",
    SAVE_FLAG_UNLOCKED_BASEMENT_DOOR = "door", SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR = "door",
    SAVE_FLAG_UNLOCKED_PSS_DOOR = "door", SAVE_FLAG_UNLOCKED_WF_DOOR = "door",
    SAVE_FLAG_UNLOCKED_JRB_DOOR = "door", SAVE_FLAG_UNLOCKED_CCM_DOOR = "door",
    SAVE_FLAG_UNLOCKED_BITDW_DOOR = "door", SAVE_FLAG_UNLOCKED_BITFS_DOOR = "door",
    SAVE_FLAG_UNLOCKED_50_STAR_DOOR = "door",
}
talk.progressPending = {}
talk.progressBy = {}
talk.causeAt = {}
talk.ownFlags = nil

function talk.progress_claim(asker, index)
    index = tonumber(index)
    local row = index ~= nil and talk.PROGRESS[math.floor(index)] or nil
    if row == nil or talk.PROGRESS_CAUSE[row.flag] == nil then return false end
    if talk.progressSaid[row.flag] and talk.progressPending[row.flag] == nil then return false end
    talk.progressBy[row.flag] = { li = asker, at = now() }
    return true
end

function talk.say_progress()
    local said = false
    for _, row in ipairs(talk.PROGRESS) do
        local since = talk.progressPending[row.flag]
        if since ~= nil then
            local by = talk.progressBy[row.flag]
            if by ~= nil and by.at < since - talk.CLAIM_WINDOW then by = nil end
            if by ~= nil or now() - since >= talk.PROGRESS_WAIT then
                talk.progressPending[row.flag] = nil
                talk.progressBy[row.flag] = nil
                local line = OF.lang.t(row.line)
                local np = by ~= nil and gNetworkPlayers[by.li] or nil
                if np ~= nil and np.connected then
                    line = OF.lang.fill("@, by @", line, OF.util.chat_name(np.name))
                end
                if talk.starFeedOn then
                    for _, entry in ipairs(OF.util.connected_players()) do
                        if not playing(entry.localIndex) then
                            deliver(entry.localIndex, line, nil, "sf")
                        end
                    end
                    said = true
                end
            end
        end
    end
    return said
end

function talk.cause_frame(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    local at = now()
    if m.action ~= nil and (m.action == ACT_UNLOCKING_KEY_DOOR or m.action == ACT_UNLOCKING_STAR_DOOR) then
        talk.causeAt.door = at
    end
    local floor = m.floor
    local on = floor ~= nil and floor.object or nil
    if on ~= nil and id_bhvCapSwitch ~= nil
        and OF.util.optional("obj_has_behavior_id", 0, on, id_bhvCapSwitch) ~= 0 then
        talk.causeAt.cap = at
    end
    if save_file_get_flags == nil then return false end
    local flags = save_file_get_flags()
    if type(flags) ~= "number" then return false end
    local was = talk.ownFlags
    talk.ownFlags = flags
    if was == nil or was == flags then return false end
    local claimed = false
    for index, row in ipairs(talk.PROGRESS) do
        local bit = _G[row.flag]
        local cause = talk.PROGRESS_CAUSE[row.flag]
        local when = cause ~= nil and talk.causeAt[cause] or nil
        if type(bit) == "number" and when ~= nil and at - when <= talk.CLAIM_WINDOW
            and OF.util.has_flag(flags, bit) and not OF.util.has_flag(was, bit) then
            ask({ w = "prog", f = index })
            claimed = true
        end
    end
    return claimed
end

function talk.watch_progress()
    if not OF.util.is_host() or save_file_get_flags == nil then return false end
    if OF.util.asks(OF.lockdown, "round_or_run") and OF.lockdown.round_or_run() then
        talk.progressWas = nil
        talk.progressPending = {}
        return false
    end
    local flags = save_file_get_flags()
    if type(flags) ~= "number" then return false end
    local was = talk.progressWas
    talk.progressWas = flags
    if was ~= nil and was ~= flags then
        local fresh = {}
        for _, row in ipairs(talk.PROGRESS) do
            local bit = _G[row.flag]
            if type(bit) == "number" and OF.util.has_flag(flags, bit)
                and not OF.util.has_flag(was, bit) then
                fresh[#fresh + 1] = row
            end
        end
        if #fresh > 0 and #fresh <= talk.PROGRESS_BURST and talk.starFeedOn then
            for _, row in ipairs(fresh) do
                if not talk.progressSaid[row.flag] then
                    talk.progressSaid[row.flag] = true
                    talk.progressPending[row.flag] = now()
                end
            end
        end
    end
    return talk.say_progress()
end

local poll = nil
local pollSerial = 0
local pollRoomWait = 0

local pollRaw, pollParsed = nil, nil
function talk.poll()
    local text = gGlobalSyncTable[talk.POLL_KEY]
    if text ~= pollRaw then
        pollRaw = text
        pollParsed = talk.read_poll(text)
    end
    return pollParsed
end

function talk.read_poll(text)
    if type(text) ~= "string" or text == "" then return nil end
    local parts = split(text)
    local id, left = tonumber(parts[1]), tonumber(parts[2])
    if id == nil or left == nil or #parts < 6 then return nil end
    local counts = {}
    for n in string.gmatch(parts[3] or "", "%d+") do counts[#counts + 1] = tonumber(n) end
    local out = { id = id, left = left, counts = counts, question = parts[4],
                  answers = {} }
    for i = 5, #parts do out.answers[#out.answers + 1] = parts[i] end
    if #out.answers < talk.ANSWERS_MIN then return nil end
    for i = 1, #out.answers do out.counts[i] = out.counts[i] or 0 end
    return out
end

local function poll_counts()
    local counts = {}
    for i = 1, #poll.answers do counts[i] = 0 end
    for g, n in pairs(poll.picks) do
        if OF.util.local_from_global(g) ~= nil and counts[n] ~= nil then
            counts[n] = counts[n] + 1
        end
    end
    return counts
end

local function publish_poll()
    if poll == nil then
        OF.util.publish(talk.POLL_KEY, nil)
        return
    end
    local counts = poll_counts()
    local pieces = { tostring(poll.id), tostring(poll.left), table.concat(counts, ","),
                     poll.question }
    for _, answer in ipairs(poll.answers) do pieces[#pieces + 1] = answer end
    OF.util.publish(talk.POLL_KEY, table.concat(pieces, FIELD))
end

function talk.parse_poll(text)
    local parts = {}
    for piece in string.gmatch((text or "") .. FIELD, "([^" .. FIELD .. "]*)" .. FIELD) do
        parts[#parts + 1] = trim(piece)
    end
    local question = talk.clean(table.remove(parts, 1) or "")
    if question == nil or question == "" then
        return nil, "Ask it like this: /poll Which arena? | Bowser 1 | Bowser 3"
    end
    if #question > talk.QUESTION_MAX then
        return nil, OF.lang.fill("Keep the question to @ letters.", talk.QUESTION_MAX)
    end
    local answers = {}
    for _, piece in ipairs(parts) do
        local answer = talk.clean(piece)
        if answer ~= nil and answer ~= "" then
            if #answer > talk.ANSWER_MAX then
                return nil, OF.lang.fill("Keep each answer to @ letters.", talk.ANSWER_MAX)
            end
            answers[#answers + 1] = answer
        end
    end
    if #answers < talk.ANSWERS_MIN or #answers > talk.ANSWERS_MAX then
        return nil, OF.lang.fill("A poll takes @ answers, split by |.",
            talk.ANSWERS_MIN .. "-" .. talk.ANSWERS_MAX)
    end
    return question, answers
end

local function start_poll(asker, askerGlobal, question, answers)

    if not OF.util.is_host() then return false end
    if not may(asker, "vote") then
        return false, "Your rank cannot start a poll."
    end
    if jailed(asker) then return false, "Not from jail." end
    local ok, why = talk.may_say(asker, question .. " " .. table.concat(answers, " "))
    if not ok then return false, why end
    if poll ~= nil and poll.left > 0 then
        return false, "A poll is already up - one at a time."
    end
    if OF.util.asks(OF.vote, "is_open") and OF.vote.is_open() then
        return false, "A vote is up - one question at a time."
    end
    if pollRoomWait > 0 then
        return false, OF.lang.fill("The lobby was just asked - another poll in @s.",
            math.ceil(pollRoomWait))
    end
    local mine = pollAskerWait[askerGlobal]
    if mine ~= nil and mine > 0 and not OF.util.is_host_player(asker) then
        return false, OF.lang.fill("You asked the last one - your next poll in @s.",
            math.ceil(mine))
    end
    pollSerial = pollSerial + 1
    poll = { id = pollSerial, asker = askerGlobal, question = question,
             answers = answers, picks = {}, left = talk.POLL_SECONDS }
    pollAskerWait[askerGlobal] = talk.POLL_ASKER_WAIT
    publish_poll()
    OF.notify.send_all("@ asks the lobby - /pick a number", "info", 5, toast_named(asker))
    return true
end

local function close_poll()
    if poll == nil or poll.left <= 0 then return end
    local counts = poll_counts()
    local best, answered = 0, 0
    for _, n in ipairs(counts) do
        answered = answered + n
        if n > best then best = n end
    end
    if answered == 0 then
        OF.notify.send_all("Nobody answered the poll.", "info", 4)
    else
        local top = {}
        for i, n in ipairs(counts) do
            if n == best then top[#top + 1] = poll.answers[i] end
        end
        if #top == 1 then
            OF.notify.send_all("The lobby picked @ (@)", "good", 6, top[1],
                OF.lang.fill("@ of @", best, answered))
        else
            OF.notify.send_all("The poll is level: @", "info", 6,
                table.concat(top, " / "))
        end
    end
    if OF.util.asks(OF.chatlog, "add_system") then
        OF.chatlog.add_system("poll: " .. poll.question .. " - " .. table.concat(counts, "/"))
    end
    poll.left = 0
    poll.shown = talk.RESULT_SECONDS
    pollRoomWait = talk.POLL_ROOM_WAIT
    publish_poll()
end

local function pick(asker, askerGlobal, id, n)
    if poll == nil or poll.left <= 0 then return false, "There is no poll up." end
    if tonumber(id) ~= poll.id then return false, "That poll has closed." end
    n = math.floor(tonumber(n) or 0)
    if n < 1 or n > #poll.answers then
        return false, OF.lang.fill("Pick a number from 1 to @.", #poll.answers)
    end
    poll.picks[askerGlobal] = n
    publish_poll()

    local waiting = 0
    for _, entry in ipairs(talk.voters()) do
        if poll.picks[network_global_index_from_local(entry.localIndex)] == nil then
            waiting = waiting + 1
        end
    end
    if waiting == 0 then close_poll() end
    return true
end

local function cancel_poll(asker, askerGlobal)
    if poll == nil or poll.left <= 0 then return false, "There is no poll up." end
    if poll.asker ~= askerGlobal and not may(asker, "mute") then
        return false, "Only whoever asked it, or a moderator, can take it down."
    end
    poll = nil
    publish_poll()
    OF.notify.send_all("The poll was taken down.", "info", 4)
    return true
end

talk.ENDMODE_SECONDS = 30
talk.ENDMODE_WAIT = 60

talk.ENDMODE_KEY = "ofRtv"
local endYes = {}
local endLeft = 0
local endWait = 0

function talk.endmode()
    local parts = split(gGlobalSyncTable[talk.ENDMODE_KEY] or "")
    return { left = tonumber(parts[1]) or 0, count = tonumber(parts[2]) or 0,
             need = tonumber(parts[3]) or 0, wait = tonumber(parts[4]) or 0 }
end

function talk.endmode_voters()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if playing(entry.localIndex) then list[#list + 1] = entry end
    end
    return list
end

function talk.endmode_need()
    return math.floor(#talk.endmode_voters() / 2) + 1
end

local function end_count()
    local n = 0
    for g in pairs(endYes) do
        local i = OF.util.local_from_global(g)
        if i ~= nil and playing(i) then n = n + 1 end
    end
    return n
end

local function publish_endmode()
    local value = nil
    if endLeft > 0 or endWait > 0 then
        value = table.concat({ tostring(endLeft), tostring(endLeft > 0 and end_count() or 0),
            tostring(talk.endmode_need()), tostring(endWait) }, FIELD)
    end
    if gGlobalSyncTable[talk.ENDMODE_KEY] ~= value then
        OF.util.publish(talk.ENDMODE_KEY, value)
    end
end

local function tell_players(message, kind, seconds, value, second)
    for _, entry in ipairs(talk.endmode_voters()) do
        OF.notify.send_to(network_global_index_from_local(entry.localIndex),
            message, kind, seconds, value, second)
    end
end

function talk.end_as_timeout()
    local modes = OF.gamemodes
    local mode = modes.current()
    if mode ~= nil and mode.on_timeout ~= nil then mode.on_timeout() end
    if modes.state() == modes.ACTIVE then modes.finish(modes.TIME_UP) end
end

local function endmode_passes()
    endYes, endLeft, endWait = {}, 0, 0
    publish_endmode()
    tell_players("The players voted to end the round.", "info", 4)
    if OF.util.asks(OF.chatlog, "add_system") then
        OF.chatlog.add_system("the round's players voted to end the round")
    end
    talk.end_as_timeout()
    return true
end

local function endmode_fails()
    endYes, endLeft, endWait = {}, 0, talk.ENDMODE_WAIT
    publish_endmode()
    tell_players("Not enough votes - the round goes on.", "info", 4)
end

local function vote_endmode(asker, askerGlobal)
    local modes = OF.gamemodes
    if modes == nil or modes.state() ~= modes.ACTIVE then
        if OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running() then
            return false, "/vote endmode ends game-mode rounds, not runs."
        end
        return false, "Nothing is being played - there is no round to end."
    end
    if not playing(asker) then
        return false, "Only the round's players vote on ending it."
    end
    if endLeft <= 0 then
        if endWait > 0 then
            return false, OF.lang.fill("The players just said no - ask again in @s.", endWait)
        end
        endYes, endLeft = {}, talk.ENDMODE_SECONDS
    elseif endYes[askerGlobal] then
        return false, "You already voted to end this round."
    end
    endYes[askerGlobal] = true
    local count, need = end_count(), talk.endmode_need()
    publish_endmode()
    if count >= need then return endmode_passes() end
    tell_players("@ wants to end the round - /vote endmode to agree (@ more)", "info", 4,
        toast_named(asker), need - count)
    return true
end

local function endmode_second()
    if endLeft > 0 then
        endLeft = endLeft - 1
        if endLeft <= 0 then endLeft = 0; endmode_fails() end
    elseif endWait > 0 then
        endWait = endWait - 1
    end
    publish_endmode()
end

local function endmode_drop()
    endYes, endLeft, endWait = {}, 0, 0
end

local ready = nil
local readySerial = 0

function talk.ready()
    local parts = split(gGlobalSyncTable[talk.READY_KEY] or "")
    local id = tonumber(parts[1])
    if id == nil then return nil end
    return { id = id, left = tonumber(parts[2]) or 0, yes = tonumber(parts[3]) or 0,
             no = tonumber(parts[4]) or 0, waiting = tonumber(parts[5]) or 0 }
end

local function ready_tally()
    local yes, no, waiting, notReady = 0, 0, 0, {}
    for _, entry in ipairs(talk.voters()) do
        local answer = ready.answers[network_global_index_from_local(entry.localIndex)]
        if answer == true then yes = yes + 1
        elseif answer == false then no = no + 1; notReady[#notReady + 1] = entry.localIndex
        else waiting = waiting + 1; notReady[#notReady + 1] = entry.localIndex end
    end
    return yes, no, waiting, notReady
end

local function publish_ready()
    if ready == nil then
        OF.util.publish(talk.READY_KEY, nil)
        return
    end
    local yes, no, waiting = ready_tally()
    OF.util.publish(talk.READY_KEY, table.concat({ tostring(ready.id), tostring(ready.left),
        tostring(yes), tostring(no), tostring(waiting) }, FIELD))
end

local function close_ready()
    if ready == nil or ready.left <= 0 then return end
    local yes, no, waiting, notReady = ready_tally()
    ready.left = 0
    ready.shown = talk.RESULT_SECONDS
    publish_ready()
    OF.notify.send_all("Ready check: @ ready", "info", 5,
        OF.lang.fill("@ of @", yes, yes + no + waiting))

    if #notReady > 0 then
        local names = {}
        for _, i in ipairs(notReady) do names[#names + 1] = chat_named(i) end
        local line = OF.lang.fill("Not ready: @", table.concat(names, ", "))
        local askerLocal = OF.util.local_from_global(ready.asker)
        if askerLocal ~= nil then deliver(askerLocal, line, nil, "r") end
        if askerLocal ~= 0 then deliver(0, line, nil, "r") end
        for _, i in ipairs(notReady) do
            OF.notify.send_to(network_global_index_from_local(i),
                "Not ready? /sitout sits you out of the next round.", "info", 6)
        end
    end
end

local function start_ready(asker, askerGlobal)
    if not may(asker, "message") then
        return false, "Your rank cannot start a ready check."
    end
    if OF.util.asks(OF.gamemodes, "state") and OF.gamemodes.state() ~= OF.gamemodes.OFF then
        return false, "A round is on - ask who is ready before the next one."
    end
    if ready ~= nil and ready.left > 0 then return false, "A ready check is already up." end
    readySerial = readySerial + 1
    ready = { id = readySerial, asker = askerGlobal, answers = {},
              left = talk.READY_SECONDS }
    ready.answers[askerGlobal] = true
    publish_ready()
    OF.notify.send_all("Ready? /ready or /notready", "info", 6)
    return true
end

local function answer_ready(asker, askerGlobal, id, yes)
    if ready == nil or ready.left <= 0 then return false, "There is no ready check up." end
    if tonumber(id) ~= ready.id then return false, "That ready check has closed." end
    ready.answers[askerGlobal] = (yes == true)
    publish_ready()
    local _, _, waiting = ready_tally()
    if waiting == 0 then close_ready() end
    return true
end

function talk.roll_key(asker)
    if not OF.util.asks(OF.powerups, "roll") then return nil end
    for _ = 1, 12 do
        local key = OF.powerups.roll(talk.dicePool, network_global_index_from_local(asker))
        local entry = key ~= nil and OF.powerups.find(key) or nil
        if entry ~= nil and not entry.carry then return key, entry end
    end
    return nil
end

local function roll_dice(asker, askerGlobal, sides)
    local id = OF.util.player_id(asker) or tostring(askerGlobal)
    sides = math.floor(tonumber(sides) or 0)
    if sides > 0 then

        local ok, why = talk.may_say(asker)
        if not ok then return false, why end
        if sides < 2 or sides > 1000 then return false, "Roll a number from 2 to 1000." end
        local wait = rollWait["n" .. id]
        if wait ~= nil and now() < wait then return false, "Give the dice a moment." end
        rollWait["n" .. id] = now() + talk.NUMBER_WAIT
        local got = math.random(sides)
        local line = OF.lang.fill("@ rolled @", chat_named(asker),
            OF.lang.fill("@ (1-@)", got, sides))
        for _, entry in ipairs(OF.util.connected_players()) do
            deliver(entry.localIndex, line, askerGlobal, "d")
        end
        return true
    end

    if jailed(asker) then return false, "Not from jail." end
    if OF.util.asks(OF.lockdown, "menu_stands_down") and OF.lockdown.menu_stands_down(asker) then
        return false, "Not while you are in a round or a run."
    end
    local wait = rollWait[id]
    if wait ~= nil and now() < wait then
        return false, OF.lang.fill("Your next roll in @s.", math.ceil(wait - now()))
    end
    local key, entry = talk.roll_key(asker)
    if key == nil then return false, "The dice have nothing to give." end
    local opts = OF.powerups.settings(key)
    opts.fv = 0
    local ok, why = OF.powerups.give(askerGlobal, key, opts, name_of(asker))
    if not ok then return false, why or "The dice missed." end
    rollWait[id] = now() + talk.ROLL_WAIT
    OF.notify.send_all("@ rolled the dice: @", "info", 5, toast_named(asker), entry.name)
    return true
end

local clock = nil

function talk.countdown()
    local parts = split(gGlobalSyncTable[talk.CLOCK_KEY] or "")
    local left = tonumber(parts[1])
    if left == nil then return nil end
    return { left = left, text = parts[2] or "" }
end

function talk.parse_seconds(text)
    text = string.lower(trim(text))
    local m, s = string.match(text, "^(%d+)m(%d+)s?$")
    if m ~= nil then return tonumber(m) * 60 + tonumber(s) end
    local n, unit = string.match(text, "^(%d+)([ms]?)$")
    if n == nil then return nil end
    if unit == "m" then return tonumber(n) * 60 end
    return tonumber(n)
end

local function publish_clock()
    if clock == nil then
        OF.util.publish(talk.CLOCK_KEY, nil)
        return
    end
    OF.util.publish(talk.CLOCK_KEY, tostring(clock.left) .. FIELD .. clock.text)
end

local function start_clock(asker, askerGlobal, seconds, text)
    if not may(asker, "message") then
        return false, "Your rank cannot start a countdown."
    end
    if jailed(asker) then return false, "Not from jail." end
    if seconds == 0 then
        if clock == nil then return false, "There is no countdown running." end
        clock = nil
        publish_clock()
        OF.notify.send_all("The countdown was stopped.", "info", 4)
        return true
    end
    seconds = math.floor(tonumber(seconds) or -1)
    if seconds < talk.CLOCK_MIN or seconds > talk.CLOCK_MAX then
        return false, "A countdown runs from 3 seconds to 60 minutes."
    end
    text = talk.clean(text or "", 40)
    if text == nil then return false, "Keep the words to 40 letters." end
    if text ~= "" then
        local ok, why = talk.may_say(asker, text)
        if not ok then return false, why end
    end
    clock = { left = seconds, text = text }
    publish_clock()
    return true
end

talk.ANNOUNCE_MOST = 5
talk.ANNOUNCE_LEN = 100
talk.announceLines = {}
talk.announceEvery = 10
local announceNext = 1
local announceLeft = nil

local function announce(asker, askerGlobal, op, text)
    if not OF.util.is_host() then return false end
    if not may(asker, "message") then
        return false, "Your rank cannot set the lobby's announcements."
    end
    if op == "clear" then
        talk.announceLines = {}
        announceNext, announceLeft = 1, nil
        return true
    end
    if op == "list" then
        local here = OF.util.local_from_global(askerGlobal)
        if here == nil then return false end
        if #talk.announceLines == 0 then
            deliver(here, OF.lang.t("No announcements. /announce <words> adds one."), nil, "n")
        end
        for i, line in ipairs(talk.announceLines) do
            deliver(here, i .. ". " .. line, nil, "n")
        end
        deliver(here, OF.lang.fill("One every @ minutes.", talk.announceEvery), nil, "n")
        return true
    end
    if op == "every" then
        local minutes = math.floor(tonumber(text) or 0)
        if minutes < 1 or minutes > 60 then return false, "Every 1 to 60 minutes." end
        talk.announceEvery = minutes
        announceLeft = minutes * 60
        return true
    end
    text = talk.clean(text or "", talk.ANNOUNCE_LEN)
    if text == nil then
        return false, OF.lang.fill("Keep an announcement to @ letters.", talk.ANNOUNCE_LEN)
    end
    if text == "" then return false, "/announce <words> adds a line." end
    if #talk.announceLines >= talk.ANNOUNCE_MOST then
        return false, "Five lines at most - /announce clear starts again."
    end
    table.insert(talk.announceLines, text)
    if announceLeft == nil then announceLeft = talk.announceEvery * 60 end
    return true
end

function talk.announce_now()
    if not OF.util.is_host() then return false end
    local count = #talk.announceLines
    if count == 0 then return false end
    if announceNext > count then announceNext = 1 end
    local line = talk.announceLines[announceNext]
    announceNext = announceNext % count + 1
    for _, entry in ipairs(OF.util.connected_players()) do
        local busy = OF.util.asks(OF.lockdown, "menu_stands_down")
            and OF.lockdown.round_or_run() and OF.lockdown.menu_stands_down(entry.localIndex)
        if not busy then
            OF.notify.send_to(network_global_index_from_local(entry.localIndex), "@", "info", 8, line)
        end
    end
    return true
end

local lastRound = nil

function talk.forget()
    talk.myPick, talk.myReady = {}, {}
    talk.lastWhisperFrom = nil
    if not OF.util.is_host() then return end

    lastRound = nil
    poll, ready, clock = nil, nil, nil
    lastLine, rollWait, pollAskerWait = {}, {}, {}
    endmode_drop()
    starWait, starSaid = {}, {}
    talk.progressWas, talk.progressSaid = nil, {}
    drop_feed()
    pollRoomWait = 0
    talk.announceLines, talk.announceEvery = {}, 10
    announceNext = 1
    announceLeft = nil
    OF.util.publish(talk.POLL_KEY, nil)
    OF.util.publish(talk.READY_KEY, nil)
    OF.util.publish(talk.CLOCK_KEY, nil)
    OF.util.publish(talk.ENDMODE_KEY, nil)
end

function talk.request(asker, askerGlobal, data)
    if not OF.util.is_host() then return false end
    if type(data) ~= "table" then return false end
    local w = data.w
    if w == "t" or w == "w" then
        if not may(asker, "chat") then
            return false, "The lobby is quiet - you cannot talk right now."
        end
        local text = talk.clean(data.t, talk.TEXT_MAX)
        if text == nil then return false, "That is too long for one line." end
        if text == "" then return false, "Say something after the command." end
        local ok, why = talk.may_say(asker, text)
        if not ok then return false, why end
        if too_fast(askerGlobal) then return false, "Slow down a little." end
        if w == "t" then return say_team(asker, askerGlobal, text) end
        return say_whisper(asker, askerGlobal, data.to, text)
    elseif w == "kf" then

        return feed_line(asker, askerGlobal, data)
    elseif w == "star" then
        return star_line(asker, askerGlobal, data)
    elseif w == "prog" then
        return talk.progress_claim(asker, data.f)
    elseif w == "poll" then
        local question, answers = talk.parse_poll(data.t)
        if question == nil then return false, answers end
        return start_poll(asker, askerGlobal, question, answers)
    elseif w == "pick" then
        return pick(asker, askerGlobal, data.id, data.n)
    elseif w == "unpoll" then
        return cancel_poll(asker, askerGlobal)
    elseif w == "endmode" then
        return vote_endmode(asker, askerGlobal)
    elseif w == "check" then
        return start_ready(asker, askerGlobal)
    elseif w == "ready" then
        return answer_ready(asker, askerGlobal, data.id, data.y == 1)
    elseif w == "roll" then
        return roll_dice(asker, askerGlobal, data.n)
    elseif w == "clock" then
        return start_clock(asker, askerGlobal, tonumber(data.n), data.t)
    elseif w == "ann" then
        return announce(asker, askerGlobal, data.op, data.t)
    end
    return false
end

local function host_request(data)
    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end
    local ok, why = talk.request(asker, askerGlobal, data)
    if not ok and why ~= nil then OF.util.tell_asker(askerGlobal, OF.lang.t(why)) end
end

local function line_arrives(data)
    if not OF.util.from_host(data) then return end
    talk.show_line(data.t, tonumber(data.f), data.c)
end

local function on_packet(data)
    if type(data) ~= "table" then return end
    if data.ofp == talk.PACKET_ASK then
        host_request(data)
    elseif data.ofp == talk.PACKET_LINE then
        line_arrives(data)
    end
end

local lastSecond = nil

function talk.second()
    if not OF.util.is_host() then return end

    local modes = OF.gamemodes
    local round = modes ~= nil and (tostring(modes.state()) .. ":" .. tostring(gGlobalSyncTable.ofGmKey)) or nil
    if round ~= lastRound then
        lastRound = round
        endmode_drop()
        drop_feed()
    end
    endmode_second()

    if pollRoomWait > 0 then pollRoomWait = pollRoomWait - 1 end
    for g, left in pairs(pollAskerWait) do
        if left <= 1 then pollAskerWait[g] = nil else pollAskerWait[g] = left - 1 end
    end
    if poll ~= nil then
        if poll.left > 0 then
            poll.left = poll.left - 1
            if poll.left <= 0 then poll.left = 1; close_poll() else publish_poll() end
        else
            poll.shown = (poll.shown or 0) - 1
            if poll.shown <= 0 then poll = nil; publish_poll() end
        end
    end

    if ready ~= nil then
        if ready.left > 0 then
            ready.left = ready.left - 1
            if ready.left <= 0 then ready.left = 1; close_ready() else publish_ready() end
        else
            ready.shown = (ready.shown or 0) - 1
            if ready.shown <= 0 then ready = nil; publish_ready() end
        end
    end

    if announceLeft ~= nil and #talk.announceLines > 0 then
        announceLeft = announceLeft - 1
        if announceLeft <= 0 then
            announceLeft = talk.announceEvery * 60
            talk.announce_now()
        end
    end

    if clock ~= nil then
        clock.left = clock.left - 1
        if clock.left <= 0 then
            local said = clock.text
            clock = nil
            publish_clock()
            if said ~= "" then
                OF.notify.send_all("@ - time!", "good", 5, said)
            else
                OF.notify.send_all("The countdown is over.", "good", 5)
            end
        else
            publish_clock()
        end
    end
end

local function host_update()
    if not OF.util.is_host() then return end
    talk.pump_feed()
    talk.watch_progress()
    local at = now()
    if lastSecond == nil then lastSecond = at end
    local steps = 0
    while at - lastSecond >= 1 and steps < 5 do
        lastSecond = lastSecond + 1
        steps = steps + 1
        talk.second()
    end
    if at - lastSecond >= 1 then lastSecond = at end
end

local function on_leave(m)
    if m == nil or not OF.util.is_host() then return end
    local g = network_global_index_from_local(m.playerIndex)
    endYes[g] = nil
    lastLine[g] = nil
    starWait[g] = nil
    if poll ~= nil then poll.picks[g] = nil end
    if ready ~= nil then ready.answers[g] = nil end
end

function talk.stands_down()
    return OF.util.asks(OF.lockdown, "round_or_run") and OF.lockdown.round_or_run()
        and OF.util.asks(OF.lockdown, "menu_stands_down") and OF.lockdown.menu_stands_down()
end

talk.myPick = {}
talk.myReady = {}

function talk.poll_lines()
    local p = talk.poll()
    if p == nil then return nil end
    local top
    if p.left > 0 then
        top = p.question .. "   " .. p.left .. "s"
    else
        top = OF.lang.fill("Poll: @", p.question)
    end
    local unders = {}
    local gold = OF.util.gold()
    for i, answer in ipairs(p.answers) do
        local mark = talk.myPick[p.id] == i and "> " or ""
        unders[#unders + 1] = { text = mark .. i .. ". " .. answer .. "   " .. (p.counts[i] or 0),
            scale = 0.7, r = gold.r, g = gold.g, b = gold.b }
    end
    if p.left > 0 then
        unders[#unders + 1] = { text = OF.lang.t("/pick 1, /pick 2 ...   or on the menu"),
            scale = 0.6 }
    end
    return top, unders
end

local function render()
    if OF.util.menu_has_screen() then return end
    if talk.stands_down() then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local c = talk.countdown()
    if c ~= nil then
        local line = OF.util.asks(OF.gamemodes, "clock") and OF.gamemodes.clock(c.left) or tostring(c.left)
        if c.text ~= "" then line = c.text .. "   " .. line end
        OF.util.banner(line, 1.0, 255, 255, 255, 255, { accent = OF.GOLD })
    end

    local top, unders = talk.poll_lines()
    if top ~= nil then
        OF.util.banner(top, 0.85, 255, 255, 255, 255, { accent = OF.GOLD, under = unders })
    end

    local r = talk.ready()
    if r ~= nil then
        local line = OF.lang.fill("Ready check   @", OF.lang.fill("@ of @ ready", r.yes,
            r.yes + r.no + r.waiting))
        local hint = r.left > 0 and (talk.myReady[r.id] == nil
            and OF.lang.t("/ready   or   /notready")
            or (talk.myReady[r.id] and OF.lang.t("You are ready") or OF.lang.t("You are not ready")))
            or OF.lang.t("the check is over")
        OF.util.banner(line, 0.85, 255, 255, 255, 255, { accent = OF.GOLD,
            under = { text = hint, scale = 0.7 } })
    end
end

local lastHeard = nil
local function chime()
    local c = talk.countdown()
    local left = c ~= nil and c.left or nil
    if left ~= lastHeard then
        if left == 10 and not talk.stands_down() and OF.util.asks(OF.sounds, "play") then
            OF.sounds.play(OF.sounds.WARN)
        elseif left == nil and lastHeard ~= nil and lastHeard <= 2
            and not talk.stands_down() and OF.util.asks(OF.sounds, "play") then
            OF.sounds.play(OF.sounds.GO)
        end
        lastHeard = left
    end
end

local function said(ok, why)
    if ok then return true end
    if why ~= nil then OF.util.report(false, why) end
    return true
end

function talk.split_name(msg)
    local words = {}
    for word in string.gmatch(msg or "", "%S+") do words[#words + 1] = word end
    for n = #words - 1, 1, -1 do
        local name = table.concat(words, " ", 1, n)
        for _, entry in ipairs(OF.util.connected_players()) do
            if string.lower(OF.util.plain(entry.np.name)) == string.lower(name) then
                return entry.localIndex, table.concat(words, " ", n + 1)
            end
        end
    end
    if #words >= 2 then
        local target = OF.util.find_player_by_name(words[1])
        if target ~= nil then return target, table.concat(words, " ", 2) end
    end
    return nil
end

function talk.chat_team(msg)
    local key, why = talk.channel_of(0)
    if key == nil then return said(false, why) end
    return said(ask({ w = "t", t = msg }))
end

function talk.chat_whisper(msg)
    if trim(msg) == "" or trim(msg) == "help" then
        OF.util.chat(OF.lang.t("/w <name> <words> - only they see it. /r answers the last whisper."))
        OF.util.chat(OF.lang.t(
            "The host's chat log keeps a copy, like every other line in the lobby."), nil, { more = true })
        return true
    end
    local target, text = talk.split_name(msg)
    if target == nil then
        return said(false, "Whisper to whom? /w <name> <words>")
    end
    return said(ask({ w = "w", t = text, to = network_global_index_from_local(target) }))
end

function talk.chat_reply(msg)
    if talk.lastWhisperFrom == nil
        or OF.util.local_from_global(talk.lastWhisperFrom) == nil then
        return said(false, "Nobody has whispered to you.")
    end
    return said(ask({ w = "w", t = msg, to = talk.lastWhisperFrom }))
end

function talk.chat_poll(msg)
    msg = trim(msg)
    local p = talk.poll()
    if msg == "" then
        if p == nil or p.left <= 0 then
            OF.util.chat(OF.lang.t("/poll Which arena? | Bowser 1 | Bowser 3 - two to six answers."))
            return true
        end
        OF.util.chat(p.question .. "  " .. p.left .. "s")
        for i, answer in ipairs(p.answers) do
            OF.util.chat(i .. ". " .. answer .. "  " .. (p.counts[i] or 0), nil, { more = true })
        end
        return true
    end
    if string.lower(msg) == "cancel" then return said(ask({ w = "unpoll" })) end
    if string.match(msg, "^%d$") then return talk.chat_pick(msg) end
    local question, answers = talk.parse_poll(msg)
    if question == nil then return said(false, answers) end
    return said(ask({ w = "poll", t = msg }))
end

function talk.chat_pick(msg)
    local p = talk.poll()
    if p == nil or p.left <= 0 then return said(false, "There is no poll up.") end
    local n = tonumber(trim(msg))
    if n == nil or n < 1 or n > #p.answers then
        return said(false, OF.lang.fill("Pick a number from 1 to @.", #p.answers))
    end
    talk.myPick[p.id] = n
    return said(ask({ w = "pick", id = p.id, n = n }))
end

function talk.chat_endmode()
    return said(ask({ w = "endmode" }))
end

function talk.chat_readycheck()
    return said(ask({ w = "check" }))
end

function talk.answer_ready(yes)
    local r = talk.ready()
    if r == nil or r.left <= 0 then return false, "There is no ready check up." end
    talk.myReady[r.id] = yes
    return ask({ w = "ready", id = r.id, y = yes and 1 or 0 })
end

function talk.chat_roll(msg)
    msg = trim(msg)
    local sides = 0
    if msg ~= "" then
        sides = tonumber(string.match(msg, "^d?(%d+)$") or "")
        if sides == nil then return said(false, "/roll for the dice, or /roll 20 for a number.") end
    end
    return said(ask({ w = "roll", n = sides }))
end

function talk.chat_announce(msg)
    msg = trim(msg)
    local word, rest = string.match(msg, "^(%S*)%s*(.*)$")
    word = string.lower(word or "")
    if msg == "" or word == "list" then return said(ask({ w = "ann", op = "list" })) end
    if word == "clear" then return said(ask({ w = "ann", op = "clear" })) end
    if word == "every" then return said(ask({ w = "ann", op = "every", t = rest })) end
    return said(ask({ w = "ann", op = "add", t = msg }))
end

function talk.chat_countdown(msg)
    msg = trim(msg)
    if string.lower(msg) == "stop" then return said(ask({ w = "clock", n = 0 })) end
    local first, rest = string.match(msg, "^(%S+)%s*(.*)$")
    local seconds = first ~= nil and talk.parse_seconds(first) or nil
    if seconds == nil then
        return said(false, "/countdown 90 Race starts - or 5m, or 1m30. /countdown stop ends it.")
    end
    return said(ask({ w = "clock", n = seconds, t = rest }))
end

function talk.time_left_text()
    local modes = OF.gamemodes
    if modes == nil or modes.state() == modes.OFF then
        if OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running() then
            return OF.lang.t("A run is on - it ends when somebody finishes.")
        end
        return OF.lang.t("No round is being played.")
    end
    local left = modes.time_left()
    if left == nil then return OF.lang.t("This round has no clock - it ends when it is won.") end
    return OF.lang.fill("@ left in this round.", modes.clock(left))
end

function talk.next_text()
    local queued = gGlobalSyncTable.ofQueueNext
    if gGlobalSyncTable.ofQueueOn == true and type(queued) == "string" and queued ~= "" then
        if OF.util.asks(OF.rounds, "localize") then queued = OF.rounds.localize(queued) end
        return OF.lang.fill("Next: @", queued)
    end
    if OF.util.asks(OF.playlist, "is_on") and OF.playlist.is_on() then
        return OF.lang.t("Next: the lobby picks when this one ends.")
    end
    return OF.lang.t("Nothing is lined up - the host picks the next round.")
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet)
hook_event(HOOK_UPDATE, function()
    host_update()
    chime()
end)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_leave)
hook_event(HOOK_ON_HUD_RENDER, render)
hook_event(HOOK_ON_INTERACT, function(m, obj, interactType, interacted)
    talk.took_a_star(m, obj, interactType, interacted)
end)
hook_event(HOOK_BEFORE_MARIO_UPDATE, talk.note_stars_before)
hook_event(HOOK_MARIO_UPDATE, talk.cause_frame)

hook_chat_command("t", "<words> - only your own side or role sees it, in a round that has them",
    function(msg) return talk.chat_team(msg or "") end)
hook_chat_command("w", "<name> <words> - whisper to one player",
    function(msg) return talk.chat_whisper(msg or "") end)
hook_chat_command("r", "<words> - answer the last whisper",
    function(msg) return talk.chat_reply(msg or "") end)
hook_chat_command("poll", "<question> | <answer> | <answer> - ask the lobby, two to six answers",
    function(msg) return talk.chat_poll(msg or "") end)
hook_chat_command("pick", "<number> - answer the poll",
    function(msg) return talk.chat_pick(msg or "") end)
hook_chat_command("readycheck", "- ask the lobby who is ready",
    function() return talk.chat_readycheck() end)
hook_chat_command("ready", "- answer the ready check: ready",
    function() return said(talk.answer_ready(true)) end)
hook_chat_command("notready", "- answer the ready check: not yet",
    function() return said(talk.answer_ready(false)) end)
hook_chat_command("roll", "- the dice put a random powerup on you, or /roll 20 for a number",
    function(msg) return talk.chat_roll(msg or "") end)
hook_chat_command("countdown", "<seconds> <words> - a clock on every screen, or stop",
    function(msg) return talk.chat_countdown(msg or "") end)
hook_chat_command("announce", "<words> - a line that comes round as a toast; list, clear, every <minutes>",
    function(msg) return talk.chat_announce(msg or "") end)
hook_chat_command("timeleft", "- what is left of this round",
    function() OF.util.chat(talk.time_left_text()); return true end)
hook_chat_command("next", "- what plays after this round",
    function() OF.util.chat(talk.next_text()); return true end)

hook_event(HOOK_ON_MODS_LOADED, function()
    local panel = OF.panel
    if panel == nil or type(panel.PAGES) ~= "table" then return end
    if panel.PAGES.lobbytalk ~= nil then return end
    panel.PAGES.lobbytalk = {
        title = "Talk to the lobby", tab = "players", up = "players",
        build = function() return talk.build_page(panel) end,
    }
end)

function talk.summary()
    local p = talk.poll()
    if p ~= nil and p.left > 0 then return OF.lang.t("a poll is up") end
    local r = talk.ready()
    if r ~= nil and r.left > 0 then return OF.lang.t("asking who is ready") end
    if talk.countdown() ~= nil then return OF.lang.t("a clock is running") end
    return ""
end

function talk.endmode_rows(panel)
    local rows = {}
    local e = talk.endmode()
    if e.left <= 0 then return rows end
    local right = OF.lang.fill("@ of @", e.count, e.need)
    if playing(0) then
        rows[#rows + 1] = panel.with_help(panel.with_right(panel.row(
            OF.lang.t("Agree to end this round"), 255, 255, 255,
            function() talk.chat_endmode() end), right),
            OF.lang.fill("the round's players are voting - @s left", e.left))
    else
        rows[#rows + 1] = panel.with_right(panel.label_row(
            OF.lang.t("The players are voting to end the round")), right)
    end
    return rows
end

local DICE_STOPS = { "anything", "only kind ones", "only mean ones" }

function talk.dice_rows(panel)
    local rows = {}
    rows[1] = panel.with_help(panel.row(OF.lang.t("Roll the dice"), 160, 220, 255,
        function() talk.chat_roll("") end),
        OF.lang.t("one random powerup on you, once every minute and a half; not in a round"))
    rows[2] = panel.with_help(panel.with_right(panel.host_row("settings",
        OF.lang.t("What the dice give"), 255, 255, 255, function()
            talk.dicePool = talk.dicePool % #DICE_STOPS + 1
        end, panel.ask_host(panel.DICE_ACTION)), OF.lang.t(DICE_STOPS[talk.dicePool] or DICE_STOPS[1])),
        OF.lang.t("press to go round the three"))
    return rows
end

function talk.build_page(panel)
    local rows = {}
    local function add(r, help) rows[#rows + 1] = panel.with_help(r, help) end

    local p = talk.poll()
    if p ~= nil and p.left > 0 then
        rows[#rows + 1] = panel.header_row(OF.lang.t("Poll"))
        rows[#rows + 1] = panel.label_row(OF.lang.fill("@   (@s left)", p.question, p.left))
        for i, answer in ipairs(p.answers) do
            local n = i
            add(panel.with_right(panel.row(panel.tick(talk.myPick[p.id] == i, answer),
                255, 255, 255, function() talk.chat_pick(tostring(n)) end),
                tostring(p.counts[i] or 0)), OF.lang.t("your answer - you can change it"))
        end
        add(panel.row(OF.lang.t("Take the poll down"), 255, 200, 120,
            function() said(ask({ w = "unpoll" })) end),
            OF.lang.t("whoever asked it, or a moderator"))
    end

    local r = talk.ready()
    rows[#rows + 1] = panel.header_row(OF.lang.t("Ready check"))
    if r ~= nil and r.left > 0 then

        add(panel.with_tone(panel.row(panel.tick(talk.myReady[r.id] == true, OF.lang.t("I am ready")),
            120, 255, 120, function() said(talk.answer_ready(true)) end), "go"),
            OF.lang.fill("@ of @ ready", r.yes, r.yes + r.no + r.waiting))
        add(panel.row(panel.tick(talk.myReady[r.id] == false, OF.lang.t("Not yet")),
            255, 200, 120, function() said(talk.answer_ready(false)) end),
            OF.lang.t("whoever asked is told who is not ready"))
    else
        add(panel.gated_row("message", OF.lang.t("Ask who is ready"), 255, 255, 255,
            function() talk.chat_readycheck() end),
            OF.lang.t("everybody answers ready or not yet, between rounds"))
    end

    rows[#rows + 1] = panel.header_row(OF.lang.t("Round"))

    if OF.util.asks(OF.vote, "round_rows") then
        for _, r in ipairs(OF.vote.round_rows(panel)) do rows[#rows + 1] = r end
    end
    rows[#rows + 1] = panel.label_row(talk.time_left_text())
    rows[#rows + 1] = panel.label_row(talk.next_text())

    rows[#rows + 1] = panel.header_row(OF.lang.t("Clock"))
    local c = talk.countdown()
    if c ~= nil then
        add(panel.gated_row("message", OF.lang.t("Stop the countdown"), 255, 200, 120,
            function() talk.chat_countdown("stop") end),
            OF.lang.t("takes the clock off every screen"))
    else
        add(panel.gated_row("message", OF.lang.t("Count down one minute"), 255, 255, 255,
            function() talk.chat_countdown("60") end),
            OF.lang.t("/countdown 5m Race starts puts words and any length on it"))
    end

    rows[#rows + 1] = panel.header_row(OF.lang.t("In chat"))
    if p == nil or p.left <= 0 then
        rows[#rows + 1] = panel.label_row(OF.lang.t(
            "/poll Which one? | A | B - starts a poll"))
    end
    rows[#rows + 1] = panel.label_row(OF.lang.t("/vote endmode - the round's players vote to end it"))
    rows[#rows + 1] = panel.label_row(OF.lang.t("/t words - only your own side or role, in a round"))
    rows[#rows + 1] = panel.label_row(OF.lang.t("/w name words - one player; /r answers the last one"))
    rows[#rows + 1] = panel.label_row(OF.lang.fill("/announce words - comes round every @ minutes",
        talk.announceEvery))

    add(panel.host_row("settings", panel.tick(talk.starFeedOn, OF.lang.t("Star feed in chat")),
        255, 255, 255, function() talk.starFeedOn = not talk.starFeedOn end,
        panel.ask_host(panel.STAR_FEED_ACTION)),
        OF.lang.t("a line when somebody outside a round gets a star"))

    rows[#rows + 1] = panel.back_row("players")
    return rows
end
