OF = OF or {}

local CATCH_RANGE = 170
local HEAD_START = 20 * 30

local SCATTER_FRAMES = {
    twenty = HEAD_START, ten = 10 * 30, forty = 40 * 30, sixty = 60 * 30,
}

local SEEKER_SHARE = 4

local SEEKER_SHARES = { quarter = SEEKER_SHARE, third = 3, half = 2 }

local ROUND_SECONDS = 3 * 60

local roundSecs = nil

local CONVERT_GRACE = 3 * 30

local RESCUE_HOLD = 2 * 30

local NEAR_RANGE = 5 * CATCH_RANGE

local WARNING_HZ = 0.5
local WARNING_RED = { g = 120, b = 120 }

local EXIT_HOLD = 2

local LIFE_FLOOR = 1

local SIDE_KEY = { [ "a hider" ]  = { team = "blue", key = "hider" } }
local sideColours = {}

local ROLE_SEEKER = "a seeker"
local ROLE_HIDER  = "a hider"
local ROLE_OUT = "out"
local graceFrames = 0

local wasDead = false

local thawFrames = 0

local heardHs = { frozen = {}, near = false }
local thawingFrames = 0

local lastHiders = nil

local function am_seeker()
    return OF.gamemodes.role(0) == ROLE_SEEKER
end

local CATCH_BONUS = 30

local WHERE = {
    { key = "whole", name = "The whole game",
      help = "every course and the castle, starting on the grounds" },
    { key = "castle", name = "The castle",
      help = "grounds, inside, courtyard - paintings send you back" },
    { key = "bob", name = "Bob-omb Battlefield", level = LEVEL_BOB },
    { key = "wf", name = "Whomp's Fortress", level = LEVEL_WF },
    { key = "jrb", name = "Jolly Roger Bay", level = LEVEL_JRB },
    { key = "ccm", name = "Cool, Cool Mountain", level = LEVEL_CCM },
    { key = "bbh", name = "Big Boo's Haunt", level = LEVEL_BBH },
    { key = "hmc", name = "Hazy Maze Cave", level = LEVEL_HMC },
    { key = "lll", name = "Lethal Lava Land", level = LEVEL_LLL },
    { key = "ssl", name = "Shifting Sand Land", level = LEVEL_SSL },
    { key = "ddd", name = "Dire, Dire Docks", level = LEVEL_DDD },
    { key = "sl", name = "Snowman's Land", level = LEVEL_SL },
    { key = "wdw", name = "Wet-Dry World", level = LEVEL_WDW },
    { key = "ttm", name = "Tall, Tall Mountain", level = LEVEL_TTM },

    { key = "thi", name = "Tiny-Huge Island", level = LEVEL_THI, area = 2 },
    { key = "ttc", name = "Tick Tock Clock", level = LEVEL_TTC },
    { key = "rr", name = "Rainbow Ride", level = LEVEL_RR },
    { key = "cotmc", name = "Cavern of the Metal Cap", level = LEVEL_COTMC },
    { key = "bitdw", name = "Bowser in the Dark World", level = LEVEL_BITDW },
    { key = "bitfs", name = "Bowser in the Fire Sea", level = LEVEL_BITFS },
    { key = "bits", name = "Bowser in the Sky", level = LEVEL_BITS },
}
local WHERE_BY_KEY = {}
for _, row in ipairs(WHERE) do
    if row.level ~= nil and row.help == nil then
        row.help = "the whole course, every area - the way out is closed"
    end
    WHERE_BY_KEY[row.key] = row
end

local function where()
    local said = OF.util.asks(OF.gamemodes, "option_showing")
        and OF.gamemodes.option_showing("hideseek", "where") or nil
    return WHERE_BY_KEY[said or ""] or WHERE[1]
end

function OF.gm_hideseek_where()
    return where()
end
OF.gm_hideseek_WHERE = WHERE

function OF.gm_single_level_rooms_out(own)
    local cache, cachedAt = nil, nil
    local function list()
        local places = OF.arena ~= nil and OF.arena.PLACES or {}
        local stamp = #(OF.LEVELS or {}) * 10000 + #places
        if cache ~= nil and cachedAt == stamp then return cache end
        local out = {}
        for _, row in ipairs(own or {}) do out[#out + 1] = row end
        local gameLevel = {}
        for _, entry in ipairs(OF.LEVELS or {}) do
            if entry.custom ~= true and entry.level ~= nil then gameLevel[entry.level] = true end
            if entry.group == "Courses" and (entry.area or 1) > 1 then
                out[#out + 1] = { level = entry.level, area = entry.area }
            end
        end
        for _, place in ipairs(places) do
            if place.key ~= nil and place.level ~= nil and gameLevel[place.level] then
                out[#out + 1] = place.key
            end
        end
        cache, cachedAt = out, stamp
        return out
    end
    return setmetatable({}, {
        __index = function(_, i) return list()[i] end,
        __len = function() return #list() end,
    })
end

local function whole_game()
    local now = OF.gamemodes.current()
    return now ~= nil and now.wholeGame == true
end

local function hideseek_round()
    local now = OF.gamemodes.current()
    return now ~= nil and now.key == "hideseek"
end

local function caught_just_now(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return row ~= nil and row.ofHsFresh == true
end

local function hiders()
    return OF.gamemodes.with_role(ROLE_HIDER)
end

local function hiders_in_play()
    local list = {}
    for _, entry in ipairs(hiders()) do
        if OF.gamemodes.in_contention(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

local function rescue()
    return OF.gamemodes.option_is("caught", "freeze")
end

local function frozen(localIndex)
    local row = gPlayerSyncTable[localIndex]
    return row ~= nil and row.ofHsFrozen == true
end

local function free_hiders()
    local list = {}
    for _, entry in ipairs(hiders()) do
        if not (rescue() and frozen(entry.localIndex)) then
            table.insert(list, entry)
        end
    end
    return list
end

local function free_hider_count()
    local count = 0
    for _, entry in ipairs(hiders()) do
        if not (rescue() and frozen(entry.localIndex)) then
            count = count + 1
        end
    end
    return count
end

local function free_in_play()
    local list = {}
    for _, entry in ipairs(hiders_in_play()) do
        if not (rescue() and frozen(entry.localIndex)) then
            table.insert(list, entry)
        end
    end
    return list
end

local SEEKER_PAIR_FROM = 5

local function seekers_wanted(count)
    if OF.gamemodes.option_is("seekers", "one") then return 1 end
    local share = SEEKER_SHARES[OF.gamemodes.option_now("seekers") or "quarter"]
        or SEEKER_SHARE

    local wanted = math.floor(count / share)
    if count >= SEEKER_PAIR_FROM and wanted < 2 then wanted = 2 end
    return OF.gamemodes.fair_minority(count, wanted)
end

local function elimination()
    return OF.gamemodes.option_is("caught", "out")
end

local function round_seconds()
    local live = OF.gamemodes.round_seconds()
    if live ~= nil then return live end
    if type(roundSecs) == "number" and roundSecs > 0 then return roundSecs end
    return ROUND_SECONDS
end

local function scatter_frames()
    local want = SCATTER_FRAMES[OF.gamemodes.option_now("scatter") or "twenty"]
        or HEAD_START
    local half = math.floor(round_seconds() * 30 / 2)
    if half > 0 and want > half then return half end
    return want
end

local function disperse_left()
    local elapsed = gGlobalSyncTable.ofGmElapsed or 0
    return math.max(0, math.floor(scatter_frames() / 30) - elapsed)
end

function OF.gm_hideseek_disperse_left()
    return disperse_left()
end

local function seeker_in_my_level()
    local mine = gNetworkPlayers[0]
    if mine == nil or mine.currLevelNum == nil then return false end
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SEEKER)) do
        local index = entry.localIndex
        if index ~= 0 and OF.gamemodes.in_contention(index) then
            local np = gNetworkPlayers[index]
            if np ~= nil and np.currLevelNum == mine.currLevelNum then
                return true
            end
        end
    end
    return false
end

local function seeker_near()
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SEEKER)) do
        local index = entry.localIndex
        if index ~= 0 and OF.util.can_play(index)
            and not caught_just_now(index) then
            local distance = OF.gamemodes.distance(0, index)
            if distance ~= nil and distance < NEAR_RANGE then return true end
        end
    end
    return false
end

function OF.gm_hideseek_warning_tint(seconds)
    local wave = 0.5 - 0.5 * math.cos((seconds or 0) * 2 * math.pi * WARNING_HZ)
    return 255,
        255 - (255 - WARNING_RED.g) * wave,
        255 - (255 - WARNING_RED.b) * wave
end

local function in_a_course(level)
    if level == nil then return false end
    if OF.util.asks(OF.roundact, "is_hub") then return not OF.roundact.is_hub(level) end
    return level ~= LEVEL_CASTLE and level ~= LEVEL_CASTLE_GROUNDS
        and level ~= LEVEL_CASTLE_COURTYARD
end

function OF.gm_hideseek_exit_locked()
    if not whole_game() then return false end
    if not OF.gamemodes.is_running() then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if OF.gamemodes.role(0) ~= ROLE_HIDER then return false end
    if not OF.util.can_play(0) then return false end
    if OF.gamemodes.is_out(0) then return false end
    if disperse_left() > 0 then return false end
    local np = gNetworkPlayers[0]
    if np == nil or not in_a_course(np.currLevelNum) then return false end
    return seeker_in_my_level()
end

local mode = {

    lobbyRules = function(now)
        local wants = {}
        if now.noWhereabouts == true then wants.whereabouts = 0 end
        if now.allActs == true then wants.allstars = 1 end
        if now.openGates == true then wants.gates = 1 end
        if now.clockStopped == true then wants.clock = 4 end
        return wants
    end,
    key = "hideseek",

    catchers = { [ROLE_SEEKER] = true },
    catchChime = true,
    name = "Hide and Seek",
    blurb = "the whole castle - the metal seekers hunt the hiders in blue",

    seekerMetal = true,

    aims = {
        ["a seeker"] = "Hunt them down - find every hider before the clock.",
        ["a hider"]  = "Stay hidden until the clock runs out.",

        ["out"]      = "You were found - watch the rest of it.",
    },

    how = "The whole game, the castle, or one course - set below.\n"
        .. "Every door is open; the way out of one place is closed.\n"
        .. "How many seek is set below. Seekers metal, hiders blue.\n"
        .. "Seekers are held while the hiders scatter.\n"
        .. "A catch is an attack - punch, kick, dive, slide, pound.\n"
        .. "On a pole or in water, a touch is enough.\n"
        .. "What being found costs a hider is set below.\n"
        .. "A catch resets the clock; in one place it adds 30 s.\n"
        .. "Seekers win by finding everybody.",
    minPlayers = 2,

    defaultLimit = ROUND_SECONDS,

    target = { name = "seconds on the clock",
               asks = "Round length",
               help = "whole game: each catch sets the clock back to it",
               clock = true,
               default = ROUND_SECONDS,
               min = 60, max = 480, step = 30 },

    caps = { tiebreak = false },

    outWord = "FOUND",
    lastWord = "LAST HIDER",

    options = {
        { key = "where", name = "Where",
          help = "everywhere, the castle, or one course",
          choices = WHERE },
        { key = "seekers", name = "How many of you seek",
          help = "the share of the lobby that is looking",
          choices = {
              { key = "quarter", name = "one in four",
                help = "one seeker for every four playing; the usual share" },
              { key = "third", name = "one in three",
                help = "a faster hunt, for a castle that empties slowly" },
              { key = "half", name = "one in two",
                help = "half the lobby is looking; far is no longer enough" },
              { key = "one", name = "one, however many are playing",
                help = "one seeker against the whole castle; the long game" },
          } },
        { key = "scatter", name = "How long the hiders get",
          help = "how long the seekers are held, and cannot see out",
          choices = {
              { key = "twenty", name = "twenty seconds",
                help = "long enough to get out of the grounds and into a course" },
              { key = "ten", name = "ten seconds",
                help = "you are found in the first place you reach" },
              { key = "forty", name = "forty seconds",
                help = "far enough to reach the far side of the castle" },
              { key = "sixty", name = "a minute",
                help = "the widest this goes; the clock runs throughout" },
          } },
        { key = "caught", name = "A hider who is found",
          help = "what being caught costs you",
          choices = {
              { key = "seeks", name = "seeks with them",
                help = "the caught join the hunt, so it grows as it goes" },
              { key = "out", name = "is out, and the last one hiding wins",
                help = "the caught are out; the hunt never grows" },
              { key = "freeze", name = "is frozen until a hider frees them",
                help = "the caught stand there until somebody comes back" },
          } },

        { key = "wallmaster", name = "Wallmaster",
          help = "a hand falls on a hider who stands still too long",
          choices = {
              { key = "off", name = "off",
                help = "a hider may stand in one spot all round" },
              { key = "on", name = "on",
                help = "10 s still: a shadow; 1.5 s more and back you go" },
          } },
    },

    noNametags = true,

    marking = { players = false },

    room = { rules = { interactions = 0 } },

    noDozing = true,

    maps = "own",

    startPlace = setmetatable({}, { __index = function(_, field)
        local row = where()
        if row.level ~= nil then
            if field == "level" then return row.level end
            if field == "area" then return row.area or 1 end
            if field == "act" then return 1 end
            return nil
        end
        if field == "level" then return LEVEL_CASTLE_GROUNDS end
        if field == "area" then return 1 end
        if field == "act" then return 0 end
        return nil
    end }),

    placeOption = "where",

    votePlaces = function()
        local out = {}
        for _, row in ipairs(WHERE) do
            if row.level ~= nil then
                table.insert(out, { what = "level", option = "where", choice = row.key,
                    value = { level = row.level, area = row.area or 1, act = 1, name = row.name } })
            end
        end
        return out
    end,

    realActs = true,
    noCopy = true,

    saysOut = true,

    inertStarsAndCaps = true,

    noWaterBombs = true,

    capsUnlocked = true,

    wingCap = true,

    enemiesBack = 10,

    teams = false,

    stallRole = ROLE_HIDER,

    lensRole = ROLE_SEEKER,

    noWhereabouts = true,

    allActs = true,

    openGates = true,

    castleOpen = true,

    clockStopped = true,

    cheatsGiven = OF.gamemodes.water_rule("hide", { speedo = 1 }),
}

local function seekers_win(text)
    local names = {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_SEEKER)) do
        local np = entry.np
        if np ~= nil and np.name ~= nil then names[#names + 1] = np.name end
    end
    if #names == 0 then
        OF.gamemodes.finish(text)
        return
    end
    OF.gamemodes.finish(text, { names = names })
end
mode.seekers_win = seekers_win

function mode.setup(players, options)

    local now = OF.gamemodes.current()

    if now ~= nil and OF.util.asks(OF.rules, "lend_many") then
        local wants = {}
        if now.noWhereabouts == true then
            table.insert(wants, { key = "whereabouts", value = 0 })
        end
        if now.allActs == true then
            table.insert(wants, { key = "allstars", value = 1 })
        end

        if now.openGates == true then
            table.insert(wants, { key = "gates", value = 1 })
        end
        if now.clockStopped == true then
            table.insert(wants, { key = "clock", value = 4 })
        end
        if #wants > 0 then
            OF.util.report(OF.rules.lend_many(wants, "hideseek"))
        end
    end

    if options == nil or tonumber(options.limit) == nil then
        OF.util.publish("ofGmLimit", OF.util.clamp(
            math.floor(tonumber(options ~= nil and options.target)
                or OF.gamemodes.target_for(mode.key) or ROUND_SECONDS),
            mode.target.min, mode.target.max))
    end
    roundSecs = gGlobalSyncTable.ofGmLimit

    local it = OF.gamemodes.deal_it(players, seekers_wanted(#players), true)

    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex,
            it[entry.localIndex] and ROLE_SEEKER or ROLE_HIDER)
    end
end

function mode.late_join(localIndex)

    return ROLE_SEEKER
end

function mode.on_start()
    graceFrames = 0
    wasDead = false
    heardHs = { frozen = {}, near = false }
    lastHiders = nil
    thawFrames = 0
    thawingFrames = 0
    OF.util.publish_row(0, "ofHsFresh", nil)

    OF.util.publish_row(0, "ofHsFrozen", nil)

    roundSecs = gGlobalSyncTable.ofGmLimit

    lastCause = nil
    releaseSaid = false
end

local CAUGHT_LINE = "Caught by @"
local WENT_DOWN_LINE = "Went down near a seeker"
local lastCause = nil
local releaseSaid = false

local roleCluster = { left = {}, right = {} }
local function role_cluster(leftLabel, leftCount, leftTone, rightLabel, rightCount, rightTone)
    local H = OF.hud
    if H == nil or H.C == nil then return nil end
    local L, R = roleCluster.left, roleCluster.right
    L.label, L.score, L.colour, L.shape = string.upper(OF.lang.t(leftLabel)), leftCount,
        H.C[leftTone] or H.C.ink, "down"
    R.label, R.score, R.colour, R.shape = string.upper(OF.lang.t(rightLabel)), rightCount,
        H.C[rightTone] or H.C.ink, "circle"
    roleCluster.target, roleCluster.you, roleCluster.leader = nil, nil, nil
    return roleCluster
end
mode.role_cluster = role_cluster

function mode.cluster()
    if OF.gamemodes.is_waiting() then return nil end
    return role_cluster("Seek", #OF.gamemodes.with_role(ROLE_SEEKER), "hunter",
        "Hide", free_hider_count(), "runner")
end

function mode.out_cause()
    return lastCause
end

mode.presets = {
    { key = "classic", name = "Classic", help = "the usual round", sets = {} },
    { key = "infection", name = "Infection",
      help = "one seeker; everybody found joins the hunt",
      sets = { seekers = "one", caught = "seeks" } },
    { key = "freeze", name = "Freeze Tag",
      help = "half the lobby seeks; the found stand frozen until freed",
      sets = { seekers = "half", caught = "freeze" } },
}

local function found(text, who)
    if rescue() then

        thawFrames = 0
        OF.util.publish_row(0, "ofHsFrozen", true)
    elseif elimination() then
        OF.gamemodes.set_role(0, ROLE_OUT)
        OF.util.publish_row(0, "ofGmTime", OF.gamemodes.since_start())

        OF.gamemodes.set_ghost(true)
    else
        OF.gamemodes.set_role(0, ROLE_SEEKER)
        graceFrames = CONVERT_GRACE
        OF.util.publish_row(0, "ofHsFresh", true)
    end
    lastCause = who ~= nil and OF.lang.fill(text, who) or OF.lang.t(text)
    if rescue() and OF.util.asks(OF.hud, "banner") then

        OF.hud.banner("out", OF.lang.t("FROZEN"), lastCause, { quiet = true })
    end

end

local function hider_within(wantFrozen)
    for _, entry in ipairs(OF.gamemodes.participants()) do
        if entry.localIndex ~= 0
            and OF.gamemodes.role(entry.localIndex) == ROLE_HIDER
            and frozen(entry.localIndex) == (wantFrozen == true) then
            local distance = OF.gamemodes.distance(0, entry.localIndex)
            if distance ~= nil and distance < CATCH_RANGE then return entry end
        end
    end
    return nil
end

local function catch_point(localIndex)
    local mode = OF.gamemodes.current()
    if mode == nil or type(mode.catch_point) ~= "function" then return nil end
    local ok, x, y, z, reach = pcall(mode.catch_point, localIndex)
    if not ok or type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return nil
    end
    return x, y, z, (type(reach) == "number" and reach > 0) and reach or CATCH_RANGE
end

local function reach_to(hiderLocal, seekerLocal)
    local distance = OF.gamemodes.distance(hiderLocal, seekerLocal)
    if distance == nil then return nil, nil end
    local best, reach = distance, CATCH_RANGE
    local x, y, z, r = catch_point(hiderLocal)
    local sm = gMarioStates[seekerLocal]
    if x ~= nil and sm ~= nil and sm.pos ~= nil then
        local dx, dy, dz = sm.pos.x - x, sm.pos.y - y, sm.pos.z - z
        local d = math.sqrt(dx * dx + dy * dy + dz * dz)

        if d / r < best / reach then best, reach = d, r end
    end
    return best, reach
end
OF.gm_hideseek_reach_to = reach_to

local function catcher()
    if OF.util.asks(OF.gamemodes, "untaggable") and OF.gamemodes.untaggable(0) then
        return nil
    end
    for _, entry in ipairs(OF.gamemodes.participants()) do
        if OF.gamemodes.role(entry.localIndex) == ROLE_SEEKER
            and not caught_just_now(entry.localIndex) then

            local distance, reach = reach_to(0, entry.localIndex)
            if distance ~= nil
                and OF.gamemodes.tag_lands(entry.localIndex, 0, reach, distance) then
                return entry
            end
        end
    end
    return nil
end

local function claim_hits()
    if OF.gamemodes.role(0) ~= ROLE_SEEKER then return 0 end
    if not OF.util.asks(OF.gamemodes, "send_hit_claim") then return 0 end
    local m = gMarioStates[0]
    if m == nil then return 0 end
    if not OF.gamemodes.tag_move(0) then return 0 end
    local sent = 0
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HIDER)) do
        local li = entry.localIndex
        if li ~= 0 then
            local distance, reach = reach_to(li, 0)
            if distance ~= nil and distance < reach
                and OF.gamemodes.send_hit_claim(li) then
                sent = sent + 1
            end
        end
    end
    return sent
end
OF.gm_hideseek_claim_hits = claim_hits

local function hear_the_freeze()
    local asked = 0
    for i = 0, MAX_PLAYERS - 1 do
        local now = rescue() and frozen(i)
        if now and not heardHs.frozen[i] then
            local m = gMarioStates[i]
            OF.gamemodes.cue("out", m ~= nil and m.marioObj or nil, "hsfrozen" .. i)
            if i == 0 then
                OF.gamemodes.cue("bad")
            elseif OF.gamemodes.catcher_of(i) == 0 then
                OF.gamemodes.cue("good")
            end
            asked = asked + 1
        end
        heardHs.frozen[i] = now
    end
    local near = OF.gamemodes.role(0) == ROLE_HIDER and OF.util.can_play(0)
        and disperse_left() <= 0 and not (rescue() and frozen(0))
        and seeker_near()
    if near and not heardHs.near then
        OF.gamemodes.cue("hazard")
        asked = asked + 1
    end
    heardHs.near = near
    return asked
end
OF.gm_hideseek_hear = hear_the_freeze

function mode.update()
    hear_the_freeze()

    OF.gamemodes.count_the_hold(disperse_left())

    if hideseek_round() and OF.gamemodes.role(0) == ROLE_HIDER then
        local me = gMarioStates[0]
        local dead = me ~= nil and (me.health or 0x880) <= 0xFF
        if dead and not wasDead then
            wasDead = true

            if seeker_in_my_level() and not (rescue() and frozen(0)) then
                found(WENT_DOWN_LINE)
                return
            end
        elseif not dead then
            wasDead = false
        end
    end

    if am_seeker() then
        if disperse_left() <= 0 then claim_hits() end
        return
    end
    if OF.gamemodes.role(0) ~= ROLE_HIDER then return end
    if disperse_left() > 0 then return end

    if rescue() then
        if frozen(0) then

            local saver = hider_within(false)

            if saver == nil then
                thawFrames = 0
            else
                thawFrames = thawFrames + 1
                if thawFrames >= RESCUE_HOLD then
                    thawFrames = 0
                    OF.util.publish_row(0, "ofHsFrozen", nil)
                    if OF.util.asks(OF.hud, "banner") then
                        OF.hud.banner("objective", OF.lang.t("FREED"), saver.np.name,
                            { side = "us" })
                    end

                    OF.gamemodes.cue("good")
                end
            end
            return
        end

        local reaching = hider_within(true)
        if reaching == nil then
            thawingFrames = 0
        elseif thawingFrames < RESCUE_HOLD then
            thawingFrames = thawingFrames + 1
        end
    end

    local taker = catcher()
    if taker ~= nil then
        found(CAUGHT_LINE, taker.np.name)

        if OF.util.asks(OF.lobbytalk, "feed") then
            OF.lobbytalk.feed(taker.localIndex, 0)
        end
        return
    end
end

function OF.gm_hideseek_thawing()
    if thawingFrames <= 0 then return nil end
    return math.min(1, thawingFrames / RESCUE_HOLD)
end

local function hold_the_exit(m)
    if m == nil then return false end
    if not OF.gm_hideseek_exit_locked() then return false end
    if (m.skipWarpInteractionsTimer or 0) >= EXIT_HOLD then return false end
    m.skipWarpInteractionsTimer = EXIT_HOLD
    return true
end

local function hold_a_life(m)
    if m == nil then return false end

    if m.playerIndex ~= 0 then return false end
    if not hideseek_round() then return false end

    if type(m.numLives) ~= "number" then return false end
    if m.numLives >= LIFE_FLOOR then return false end
    m.numLives = LIFE_FLOOR
    return true
end

function OF.gm_hideseek_life_floor()
    return LIFE_FLOOR
end

function OF.gm_hideseek_hold_a_life(m)
    return hold_a_life(m)
end

if HOOK_ON_PAUSE_EXIT ~= nil then
hook_event(HOOK_ON_PAUSE_EXIT, function()
    if not OF.gm_hideseek_exit_locked() then return end

    return false
end)
end

function mode.before_mario_update(m)

    if hideseek_round() and OF.gamemodes.role(0) == ROLE_HIDER
        and m ~= nil and m.action == ACT_IDLE
        and (m.actionState or 0) >= 3 then
        m.actionState = 0
        m.actionTimer = 0
    end

    hold_the_exit(m)

    hold_a_life(m)

    if OF.gamemodes.role(0) == ROLE_OUT then
        OF.gamemodes.set_ghost(true)
    end

    if rescue() and frozen(0) then
        OF.input.hold(m)
    end

    if not am_seeker() then return end
    if disperse_left() <= 0 then return end

    OF.input.hold(m)
end

function mode.cleanup()
    if OF.gm_hideseek_wall_forget ~= nil then OF.gm_hideseek_wall_forget() end
    graceFrames = 0
    wasDead = false
    heardHs = { frozen = {}, near = false }
    lastHiders = nil

    roundSecs = nil
    thawFrames = 0
    thawingFrames = 0
    OF.util.publish_row(0, "ofHsFresh", nil)

    OF.util.publish_row(0, "ofHsFrozen", nil)

    if whole_game() and OF.util.is_host()
        and OF.util.asks(OF.net, "undo_warp") and OF.net.can_undo() then
        OF.util.report(OF.net.undo_warp(true))
    end
end

function mode.terms()

    local showing = OF.gamemodes.option_showing(mode.key, "caught")
    if showing == "out" then
        return OF.lang.t("every hider found, one hider left, or the clock")
    end
    if showing == "freeze" then

        return OF.lang.t("every hider frozen at once, or the clock")
    end
    return OF.lang.t("every hider found, or the hiders beat the clock")
end

local function restart_clock()
    if not OF.util.is_host() then return false end
    local limit = gGlobalSyncTable.ofGmLimit or 0
    if limit <= 0 then return false end

    if not whole_game() then
        OF.util.publish("ofGmLimit", limit + CATCH_BONUS)
        return true
    end
    local wanted = (gGlobalSyncTable.ofGmElapsed or 0) + round_seconds()
    if wanted <= limit then return false end
    OF.util.publish("ofGmLimit", wanted)
    return true
end

function OF.gm_hideseek_restart_clock()
    return restart_clock()
end

function mode.host_update()

    if hideseek_round() then

        local now = free_hider_count()
        if lastHiders ~= nil and now < lastHiders and now > 0 then

            restart_clock()
            OF.notify.send_all("Found one.", "warn", 4)
        end
        lastHiders = now
    end

    if OF.gamemodes.role_is_gone(ROLE_SEEKER) then
        OF.gamemodes.abandon("Nobody is seeking any more.")
        return
    end

    if #hiders() == 0 then
        seekers_win("Everyone was found - the seekers win.")
        return
    end

    local left = hiders_in_play()
    if #left == 0 then
        OF.gamemodes.abandon("Nobody left to find.")
        return
    end

    if rescue() and #free_in_play() == 0 then
        seekers_win("Everyone was frozen - the seekers win.")
        return
    end

    if elimination() and #left == 1
        and #OF.gamemodes.with_role(ROLE_OUT) > 0 then
        OF.gamemodes.finish("@ won - never found.", left[1].np.name,
            left[1].np.name)
    end
end

function mode.on_timeout()

    local left = free_in_play()
    if #left == 0 then
        seekers_win("The seekers win.")
    elseif #left == 1 then
        OF.gamemodes.finish("@ won - never found.", left[1].np.name, left[1].np.name)
    else

        local names = {}
        for _, entry in ipairs(left) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish("The hiders won - @ never found.", { names = names }, #left)
    end
end

local LIST_X = 0.03
local LIST_Y = 0.24

local STACKED = { scale = 0.85, columns = 1 }

local LIST_WIDTH = 190

local LIST_MARGIN = 8

local PLAIN_LIMIT = 256
local plainOf, plainCount, plainBy = {}, 0, nil

local function plain_name(name)
    local plain = OF.util.plain
    if type(name) ~= "string" then return plain(name) end
    if plain ~= plainBy or plainCount > PLAIN_LIMIT then
        plainOf, plainCount, plainBy = {}, 0, plain
    end
    local answer = plainOf[name]
    if answer == nil then
        answer = plain(name)
        if answer ~= nil then
            plainOf[name] = answer
            plainCount = plainCount + 1
        end
    end
    return answer
end

local sideRowPool = {}

local function side_rows(role)
    local rows = sideRowPool[role]
    if rows == nil then
        rows = {}
        sideRowPool[role] = rows
    end
    local count = 0
    for _, entry in ipairs(OF.gamemodes.with_role(role)) do
        if entry.np ~= nil then
            local name = plain_name(entry.np.name)

            local mark = nil
            if rescue() and role == ROLE_HIDER and frozen(entry.localIndex) then
                mark = OF.lang.t("frozen")
            end
            count = count + 1
            local row = rows[count]
            if row == nil then
                row = {}
                rows[count] = row
            end
            row.name, row.right, row.localIndex = name, mark, entry.localIndex
        end
    end
    for index = #rows, count + 1, -1 do rows[index] = nil end
    return rows
end

local function place_rank(place)
    if place.secret then return OF.util.secret_order() end
    return OF.util.level_order(place.level, place.area)
end

local function places_in_order(a, b)
    local ra, rb = place_rank(a), place_rank(b)
    if ra ~= rb then return ra < rb end

    if a.secret ~= b.secret then return a.secret == true end
    if a.level ~= b.level then return a.level < b.level end
    return (a.area or 0) < (b.area or 0)
end

local function whole_level_name(level)
    for _, entry in ipairs(OF.COURSES or {}) do
        if entry.level == level then return entry.name end
    end
    return OF.util.level_name(level, 1)
end

function OF.gm_hideseek_hiding_places()
    return OF.gm_hideseek_places_of(OF.gamemodes.with_role(ROLE_HIDER))
end

function OF.gm_hideseek_places_of(entries)
    local seen, list = {}, {}
    for _, entry in ipairs(entries or {}) do
        local np = gNetworkPlayers[entry.localIndex]
        if np ~= nil and np.currLevelNum ~= nil then
            local area = np.currAreaIndex
            local secret = OF.util.level_is_secret(np.currLevelNum, area)
            local sections = np.currLevelNum == LEVEL_CASTLE

            local key = secret and "secret"
                or (sections and (tostring(np.currLevelNum) .. ":" .. tostring(area)))
                or tostring(np.currLevelNum)
            if not seen[key] then
                seen[key] = true
                table.insert(list, { level = np.currLevelNum, area = sections and area or 1,
                                     secret = secret or nil, whole = (not sections) or nil,
                                     name = (not sections and not secret)
                                         and whole_level_name(np.currLevelNum) or nil })
            end
        end
    end

    table.sort(list, places_in_order)
    return list
end

local function draw_level_list(x, y, places, scale, title)
    if #places == 0 then return y end

    scale = scale or 0.85
    local lineHeight = OF.util.line_height(scale) + 4 * scale / 0.85
    local max = #places
    local shown = max

    local mine = gNetworkPlayers[0]
    local hereLevel = mine ~= nil and mine.currLevelNum or nil
    local hereArea = mine ~= nil and mine.currAreaIndex or nil

    local hereSecret = OF.util.level_is_secret(hereLevel, hereArea)

    local heading = OF.lang.t(title or "Hiding in")
    local names = {}
    local widest = OF.util.round_title_size(OF.util.plain(heading), scale)
    for row, place in ipairs(places) do
        if row > max then break end

        local namer = place.secret and OF.util.concealed_level_name
            or OF.util.level_name
        local ok, said = true, place.name
        if said == nil then ok, said = pcall(namer, place.level, place.area) end
        local name = (ok and type(said) == "string" and said ~= "") and said
            or OF.lang.t("Somewhere")
        names[row] = name
        local drawn = OF.util.round_board_size(OF.util.plain(name), scale)
        if drawn > widest then widest = drawn end
    end
    local width = math.max(LIST_WIDTH, widest + LIST_MARGIN * 2)

    OF.util.round_plate(x - LIST_MARGIN, y - 5, width,
        lineHeight * (shown + 1) + 10)
    OF.util.round_title(heading, x, y, scale,
        OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
    y = y + lineHeight

    for row, place in ipairs(places) do
        if row > max then break end

        local name = names[row]
        local here
        if place.secret then
            here = hereSecret
        else
            here = place.level == hereLevel and (place.whole or place.area == hereArea)
        end
        if here then
            OF.util.round_board(name, x, y, scale, 255, 235, 120, 255, true)
        else
            OF.util.round_board(name, x, y, scale, 190, 190, 200, 255, true)
        end
        y = y + lineHeight
    end
    return y
end

local function draw_the_curtain()
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    OF.util.rect(0, 0, screenWidth + 2, screenHeight + 2, 0, 0, 0, 255)
end

local function blind_number(left)
    left = math.floor(tonumber(left) or 0)
    if left <= 0 or not OF.util.asks(OF.hud, "countdown_at") then return nil end
    local cx, cy = OF.hud.countdown_centre()
    local frac = 0
    if OF.util.asks(OF.gamemodes, "since_start") then
        frac = OF.gamemodes.since_start() % 1
    end
    OF.hud.countdown_at(cx, cy, left, frac, OF.hud.COUNT_RING or 78, 1)
    if OF.hunt ~= nil then OF.hunt.blindShown = left end
    return left
end

function OF.gm_hideseek_blind(left)
    if not OF.gamemodes.is_running() then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if not am_seeker() then return false end
    if not OF.util.can_play(0) then return false end
    if type(left) ~= "number" then left = disperse_left() end
    return left > 0
end

function mode.hud()
    if OF.gm_hideseek_draw_wallmasters ~= nil then OF.gm_hideseek_draw_wallmasters() end

    local waiting = OF.gamemodes.is_waiting()
    local remaining = waiting and 0 or disperse_left()

    if OF.gm_hideseek_blind() then
        draw_the_curtain()
        blind_number(remaining)
    end

    if not waiting and remaining <= 0 and not releaseSaid and OF.gamemodes.is_running() then
        releaseSaid = true
        if OF.gamemodes.since_start() > 2 and OF.util.asks(OF.hud, "banner") then
            OF.hud.banner("objective", OF.lang.t("SEEKERS OUT"), nil)
        end
    end

    if OF.gamemodes.role(0) == ROLE_OUT then
        OF.gamemodes.out_banner()
        return
    end

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if remaining > 0 and not am_seeker() and not waiting then
        state("hide", OF.lang.t("Hide"), { prio = 70, figure = remaining, tone = "runner" })
    end
    if rescue() and frozen(0) then
        state("frozen", OF.lang.t("Frozen"), { prio = 80, tone = "cold", colour = true })
    end
    local thawing = OF.gm_hideseek_thawing()
    if thawing ~= nil then
        state("freeing", OF.lang.t("Freeing"), { prio = 75, tone = "good",
            figure = tostring(math.floor(thawing * 100)) .. "%" })
    end

    if OF.gm_hideseek_exit_locked() then
        state("shut", OF.lang.t("Course exit shut"), { prio = 20, tone = "dim" })
    end

    if OF.gamemodes.role(0) == ROLE_HIDER and OF.util.can_play(0)
        and disperse_left() <= 0 and seeker_near() then
        state("near", OF.lang.t("Seeker near"), { prio = 85, urgent = true, tone = "bad" })
    end

    if not whole_game() or waiting or OF.gm_hideseek_blind() then return end

    local x = djui_hud_get_screen_width() * LIST_X
    local y = djui_hud_get_screen_height() * LIST_Y
    local seeking = side_rows(ROLE_SEEKER)
    local hiding = side_rows(ROLE_HIDER)
    local out = side_rows(ROLE_OUT)
    local places = OF.gm_hideseek_hiding_places()

    local headings = 2 + (#out > 0 and 1 or 0) + (#places > 0 and 1 or 0)

    local from = y
    local scale, columns
    for _ = 1, 2 do
        scale, columns = OF.util.board_fit(#seeking + #hiding + #out
            + 2 * #places + 3, headings, y - 5, OF.util.board_bottom() - 18 * headings)
        STACKED.scale, STACKED.columns = scale, columns
        local widest = math.max(LIST_WIDTH,
            select(9, OF.util.board_measure(y, "", hiding, STACKED)),
            select(9, OF.util.board_measure(y, "", seeking, STACKED)))
        local moved = OF.util.board_top(x, from, widest)
        if moved == y then break end
        y = moved
    end

    y = OF.util.board(x, y, OF.lang.fill("Seeking (@)", #seeking), seeking, STACKED)
    y = OF.util.board(x, y + 8, OF.lang.fill("Hiding (@)", #hiding), hiding, STACKED)

    if #out > 0 then
        y = OF.util.board(x, y + 8, OF.lang.fill("Out (@)", #out), out, STACKED)
    end

    draw_level_list(x, y + 8, places, scale)
end

OF.hunt = OF.hunt or {}
function OF.hunt.side_colour(role)
    local side = SIDE_KEY[role or ""]
    if side == nil then return nil end
    local cached = sideColours[side.key]
    if cached ~= nil then return cached end
    local team = OF.util.asks(OF.teams, "find") and OF.teams.find(side.team) or nil
    if team == nil then return nil end
    cached = { key = side.key, r = team.r, g = team.g, b = team.b }
    sideColours[side.key] = cached
    return cached
end

function mode.sideTitle(role)
    if role == ROLE_SEEKER then return "Seeking" end
    if role == ROLE_HIDER then return "Hiding" end
    return nil
end

function mode.paint(localIndex)
    return OF.hunt.side_colour(OF.gamemodes.role(localIndex))
end

function OF.gm_hideseek_castle_round()
    local open = OF.gamemodes.is_running()
        or (OF.gamemodes.is_waiting ~= nil and OF.gamemodes.is_waiting())
    return open and whole_game()
end

hook_event(HOOK_USE_ACT_SELECT, function()
    if not OF.gm_hideseek_castle_round() then return end
    return false
end)

local popupsTaken = false

function OF.gm_hideseek_popups_taken()
    return popupsTaken
end

hook_event(HOOK_UPDATE, function()
    local wanted = OF.gm_hideseek_castle_round()
    if wanted == popupsTaken then return end
    if wanted then
        OF.util.optional("djui_set_popup_disabled_override", nil, true)
    else
        OF.util.optional("djui_reset_popup_disabled_override", nil)
    end
    popupsTaken = wanted
end)

local WALL_STILL = 10 * 30
local WALL_SHADOW = 45
local WALL_STILL_RADIUS = 100
local WALL_RING = 140
local wallAnchor, wallStill = {}, {}
local wallAt = { x = 0, y = 0, z = 0 }

local function wallmaster_on()
    return OF.gamemodes.option_now("wallmaster") == "on"
end

function OF.gm_hideseek_wallmaster(localIndex)
    return wallStill[localIndex] or 0
end

local function wall_reset(i)
    wallAnchor[i], wallStill[i] = nil, 0
end

function OF.gm_hideseek_wall_forget()
    for i = 0, MAX_PLAYERS - 1 do wall_reset(i) end
end

function OF.gm_hideseek_wallmaster_step()
    local on = wallmaster_on() and OF.gamemodes.state() == OF.gamemodes.ACTIVE
        and disperse_left() <= 0
    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        local np = gNetworkPlayers[i]
        if not on or m == nil or np == nil or not np.connected
            or OF.gamemodes.role(i) ~= ROLE_HIDER or not OF.util.can_play(i)
            or frozen(i) then
            wall_reset(i)
        else
            local a = wallAnchor[i]
            local dx = a ~= nil and (m.pos.x - a.x) or 0
            local dz = a ~= nil and (m.pos.z - a.z) or 0
            if a == nil or dx * dx + dz * dz > WALL_STILL_RADIUS * WALL_STILL_RADIUS then
                wallAnchor[i] = { x = m.pos.x, z = m.pos.z }
                wallStill[i] = 0
            else
                wallStill[i] = (wallStill[i] or 0) + 1
            end
            local still = wallStill[i]
            if still == WALL_STILL and i == 0 then

                OF.gamemodes.cue("hazard")
            end
            if still >= WALL_STILL + WALL_SHADOW and i == 0 then
                local start = m.spawnInfo ~= nil and m.spawnInfo.startPos or nil
                if start ~= nil then
                    OF.net.snap_to(start.x, start.y, start.z, nil)
                    if OF.util.asks(OF.hud, "banner") then
                        OF.hud.banner("objective", OF.lang.t("WALLMASTER"),
                            OF.lang.t("Back to the start"), { side = "them" })
                    end
                end
                wall_reset(i)
            end
        end
    end
end

local function draw_wallmasters()
    local still = wallStill[0] or 0
    if still >= WALL_STILL then
        local m = gMarioStates[0]
        local share = math.min(1, (still - WALL_STILL) / WALL_SHADOW)
        wallAt.x, wallAt.y, wallAt.z = m.pos.x, m.pos.y + 3, m.pos.z
        OF.util.zone_ring(wallAt, WALL_RING * (1.1 - share * 0.6), 24,
            3 + share * 5, 40, 20, 60, 220)
    end
end
OF.gm_hideseek_draw_wallmasters = draw_wallmasters

function mode.scenery()
    OF.gm_hideseek_wallmaster_step()
    if graceFrames > 0 then
        graceFrames = graceFrames - 1
        if graceFrames == 0 then OF.util.publish_row(0, "ofHsFresh", nil) end
    end
end

setmetatable(mode, { __index = function(_, field)
    if field == "wholeGame" then return where().key == "whole" end
    return nil
end })

function mode.blind() return OF.gm_hideseek_blind() == true end

OF.gamemodes.register(mode)

OF.hunt = OF.hunt or {}

do
    local hunt = OF.hunt

    hunt.ROLE_SEEKER = ROLE_SEEKER
    hunt.ROLE_HIDER = ROLE_HIDER
    hunt.ROLE_OUT = ROLE_OUT

    hunt.CATCH_RANGE = CATCH_RANGE

    hunt.CONVERT_GRACE = CONVERT_GRACE
    hunt.RESCUE_HOLD = RESCUE_HOLD

    hunt.seekers_wanted = seekers_wanted

    hunt.head_start_left = disperse_left

    hunt.catcher = catcher

    hunt.turn = found

    hunt.rescue_on = rescue
    hunt.frozen = frozen
    hunt.reach = hider_within

    hunt.hiders = hiders
    hunt.hiders_in_play = hiders_in_play
    hunt.free_hiders = free_hiders
    hunt.free_in_play = free_in_play

    hunt.elimination = elimination

    hunt.seeker_in_my_level = seeker_in_my_level
    hunt.seeker_near = seeker_near

    hunt.round_seconds = round_seconds

    hunt.setup = mode.setup
    hunt.on_start = mode.on_start
    hunt.late_join = mode.late_join
    hunt.update = mode.update
    hunt.before_mario_update = mode.before_mario_update
    hunt.host_update = mode.host_update
    hunt.on_timeout = mode.on_timeout
    hunt.cleanup = mode.cleanup

    hunt.hud = mode.hud

    hunt.blind = OF.gm_hideseek_blind

    hunt.draw_curtain = draw_the_curtain

    hunt.blind_number = blind_number

    hunt.role_cluster = role_cluster
    hunt.cluster = mode.cluster
    function hunt.curtain(left)
        if not OF.gm_hideseek_blind(left) then return false end
        draw_the_curtain()
        return true
    end

    function hunt.hiding_board(below, places, title)
        places = places or OF.gm_hideseek_hiding_places()
        if #places == 0 then return false end
        local x = djui_hud_get_screen_width() * LIST_X

        local y = OF.util.board_top(x, math.max(
            djui_hud_get_screen_height() * LIST_Y, tonumber(below) or 0),
            LIST_WIDTH)
        local scale = OF.util.board_fit(#places, 1, y - 5,
            OF.util.board_bottom() - 18)
        draw_level_list(x, y, places, scale, title)
        return true
    end
end

local METAL = MODEL_STATE_METAL or 0x200

function OF.hunt.wear_metal(m)
    if m == nil then return false end
    local now = OF.gamemodes.current()
    if now == nil or now.seekerMetal ~= true then return false end
    if not OF.gamemodes.is_running() then return false end
    if OF.gamemodes.role(m.playerIndex) ~= ROLE_SEEKER then return false end
    local body = m.marioBodyState
    if body == nil or type(body.modelState) ~= "number" then return false end
    if not OF.util.has_flag(body.modelState, METAL) then
        body.modelState = body.modelState + METAL
    end
    return true
end

hook_event(HOOK_MARIO_UPDATE, OF.hunt.wear_metal)

local RESPAWN_PERSIST = OBJ_FLAG_PERSISTENT_RESPAWN or 0x4000

local RESPAWN_KEEP = {}

for _, behaviourId in ipairs({
    id_bhvChuckya, id_bhvBreakableBox, id_bhvHeaveHo,
}) do

    if behaviourId ~= nil then table.insert(RESPAWN_KEEP, behaviourId) end
end

function OF.gm_hideseek_respawn_count()
    return #RESPAWN_KEEP
end

local function respawn_wanted(o)
    if o == nil then return false end
    for _, behaviourId in ipairs(RESPAWN_KEEP) do
        local yes = OF.util.optional("obj_has_behavior_id", 0, o, behaviourId)
        if yes ~= nil and yes ~= 0 and yes ~= false then return true end
    end
    return false
end

function OF.gm_hideseek_keep_respawning(o)
    if o == nil then return false end
    if not OF.gm_hideseek_castle_round() then return false end
    if not respawn_wanted(o) then return false end
    local flags = o.oFlags or 0
    if OF.util.has_flag(flags, RESPAWN_PERSIST) then return false end
    o.oFlags = flags + RESPAWN_PERSIST
    return true
end

if HOOK_ON_OBJECT_LOAD ~= nil then
hook_event(HOOK_ON_OBJECT_LOAD, function(o)
    OF.gm_hideseek_keep_respawning(o)
end)
end

local respawnArmed = false

function OF.gm_hideseek_respawn_armed()
    return respawnArmed
end

hook_event(HOOK_UPDATE, function()
    local wanted = OF.gm_hideseek_castle_round()
    if wanted == respawnArmed then return end
    respawnArmed = wanted
    if not wanted then return end
    for _, behaviourId in ipairs(RESPAWN_KEEP) do
        local object = obj_get_first_with_behavior_id(behaviourId)
        while object ~= nil do
            OF.gm_hideseek_keep_respawning(object)
            object = obj_get_next_with_same_behavior_id(object)
        end
    end
end)

local MIPS_ALIVE = (ACTIVE_FLAG_ACTIVE or 1) + (ACTIVE_FLAG_UNK8 or 0x100)
local MIPS_IDLE = MIPS_ACT_IDLE or 4
local MIPS_STAR_DONE = MIPS_STAR_STATUS_ALREADY_SPAWNED_STAR or 2

function OF.gm_hideseek_stand_mips(o)
    if o == nil then return false end
    if not OF.gm_hideseek_castle_round() then return false end
    o.activeFlags = MIPS_ALIVE
    o.oAction = MIPS_IDLE
    o.oMipsStarStatus = MIPS_STAR_DONE
    return true
end

if id_bhvMips ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvMips, OBJ_LIST_GENACTOR, false,
        OF.gm_hideseek_stand_mips)
end

local MOAT_LEVEL = LEVEL_CASTLE_GROUNDS
local MOAT_AREA = 1
local MOAT_REGIONS = { 1, 2 }
local MOAT_DRAINED = -800

local moatWas = nil

function OF.gm_hideseek_moat_borrowed()
    return moatWas ~= nil
end

local function in_the_moats_area()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if np == nil then return false end
    return np.currLevelNum == MOAT_LEVEL and np.currAreaIndex == MOAT_AREA
end

local function region_height(index)
    local height = OF.util.optional("get_environment_region", nil, index)
    if type(height) ~= "number" then return nil end

    local floor = nil
    if gLevelValues ~= nil then floor = gLevelValues.floorLowerLimit end
    if type(floor) == "number" and height == floor then return nil end
    return height
end

hook_event(HOOK_UPDATE, function()
    if not in_the_moats_area() then return end
    if OF.util.binding("set_environment_region") == nil then return end

    if OF.gm_hideseek_castle_round() then
        if moatWas == nil then
            local were = {}
            for _, index in ipairs(MOAT_REGIONS) do
                local height = region_height(index)
                if height == nil then return end
                were[index] = height
            end
            moatWas = were
        end

        for _, index in ipairs(MOAT_REGIONS) do
            if region_height(index) ~= MOAT_DRAINED then
                OF.util.optional("set_environment_region", nil, index,
                    MOAT_DRAINED)
            end
        end
    elseif moatWas ~= nil then
        local were = moatWas
        moatWas = nil
        for _, index in ipairs(MOAT_REGIONS) do
            OF.util.optional("set_environment_region", nil, index, were[index])
        end
    end
end)

local GRILL_OFF = 0
local grillWas = nil

function OF.gm_hideseek_grills_open()
    return grillWas ~= nil
end

function OF.gm_hideseek_moat_grill(o)
    if o == nil then return end
    if OF.gm_hideseek_castle_round() then
        if grillWas == nil and type(o.oCollisionDistance) == "number"
            and o.oCollisionDistance > 0 then
            grillWas = o.oCollisionDistance
        end
        if o.oCollisionDistance ~= GRILL_OFF then
            o.oCollisionDistance = GRILL_OFF
            OF.util.optional("cur_obj_hide", nil)
        end
    elseif grillWas ~= nil and o.oCollisionDistance == GRILL_OFF then
        o.oCollisionDistance = grillWas
        OF.util.optional("cur_obj_unhide", nil)
    end
end

if id_bhvMoatGrills ~= nil and type(hook_behavior) == "function" then
    hook_behavior(id_bhvMoatGrills, OBJ_LIST_SURFACE, false, nil,
        OF.gm_hideseek_moat_grill)
end
