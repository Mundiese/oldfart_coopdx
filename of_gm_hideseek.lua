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

local METAL = MODEL_STATE_METAL or 0x200

local CONVERT_GRACE = 3 * 30

local RESCUE_HOLD = 2 * 30

local NEAR_RANGE = 5 * CATCH_RANGE

local WARNING_HZ = 0.5
local WARNING_RED = { g = 120, b = 120 }

local EXIT_HOLD = 2

local LIFE_FLOOR = 1

local SEEKER_COLOUR = { key = "seeker", r = 168, g = 176, b = 198 }

local ROLE_SEEKER = "a seeker"
local ROLE_HIDER  = "a hider"
local ROLE_OUT = "out"
local graceFrames = 0

local wasDead = false

local thawFrames = 0
local thawingFrames = 0

local lastHiders = nil

local wasHiding = nil

local function am_seeker()
    return OF.gamemodes.role(0) == ROLE_SEEKER
end

local function whole_game()
    local now = OF.gamemodes.current()
    return now ~= nil and now.wholeGame == true
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

local function free_in_play()
    local list = {}
    for _, entry in ipairs(hiders_in_play()) do
        if not (rescue() and frozen(entry.localIndex)) then
            table.insert(list, entry)
        end
    end
    return list
end

local function seekers_wanted(count)
    if OF.gamemodes.option_is("seekers", "one") then return 1 end
    local share = SEEKER_SHARES[OF.gamemodes.option_now("seekers") or "quarter"]
        or SEEKER_SHARE
    return math.max(1, math.floor(count / share))
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

local function warning_seconds()
    if OF.util.asks(OF.gamemodes, "since_start") then
        return OF.gamemodes.since_start()
    end
    return OF.gamemodes.elapsed()
end

function OF.gm_hideseek_exit_locked()
    if not whole_game() then return false end
    if not OF.gamemodes.is_running() then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if OF.gamemodes.role(0) ~= ROLE_HIDER then return false end
    if not OF.util.can_play(0) then return false end
    if OF.gamemodes.is_out(0) then return false end
    if disperse_left() > 0 then return false end
    return seeker_in_my_level()
end

local mode = {
    key = "hideseek",
    name = "Hide and Seek",
    blurb = "the whole castle - some of you seek, and they are metal",

    aims = {
        ["a seeker"] = "Hunt them down - find every hider before the clock.",
        ["a hider"]  = "Stay hidden until the clock runs out.",

        ["out"]      = "You were found - watch the rest of it.",
    },

    how = "The whole castle. Everybody starts on the grounds.\n"
        .. "Every door is open and the moat is out for the round.\n"
        .. "How many of you seek is set below. They wear metal.\n"
        .. "Seekers are held while the hiders scatter.\n"
        .. "A catch is an attack - punch, kick, dive, slide, pound.\n"
        .. "On a pole or in water, a touch is enough.\n"
        .. "What being found costs a hider is set below.\n"
        .. "Every catch puts the clock back to the round's length.\n"
        .. "Seekers win by finding everybody.",
    minPlayers = 2,

    defaultLimit = ROUND_SECONDS,

    target = { name = "seconds on the clock",
               asks = "How many seconds a catch puts the clock back",
               default = ROUND_SECONDS,
               min = 60, max = 480, step = 30 },

    options = {
        { key = "seekers", name = "How many of you seek",
          help = "the share of the lobby that is looking, dealt when the "
              .. "round starts",
          choices = {
              { key = "quarter", name = "one in four",
                help = "the share this mode has always used - one seeker "
                    .. "for every four playing, and four for sixteen" },
              { key = "third", name = "one in three",
                help = "a faster hunt, and the one to reach for when the "
                    .. "castle is emptying out slowly" },
              { key = "half", name = "one in two",
                help = "half the lobby is looking, so a hiding place has "
                    .. "to be good rather than merely far away" },
              { key = "one", name = "one, however many are playing",
                help = "one seeker against the whole castle - the long game, "
                    .. "and every catch makes it shorter" },
          } },
        { key = "scatter", name = "How long the hiders get",
          help = "the seekers are held, and cannot see out, for this long "
              .. "while everybody else runs",
          choices = {
              { key = "twenty", name = "twenty seconds",
                help = "long enough to get out of the grounds and into a "
                    .. "course, which is what the castle asks for" },
              { key = "ten", name = "ten seconds",
                help = "you will be found in the first place you reach, so "
                    .. "take the nearest door and keep going" },
              { key = "forty", name = "forty seconds",
                help = "far enough to reach the far side of the castle, and "
                    .. "the clock is running the whole time" },
              { key = "sixty", name = "a minute",
                help = "the widest this goes - the clock runs throughout, so "
                    .. "a short round is half over before anybody looks" },
          } },
        { key = "caught", name = "A hider who is found",
          help = "what being caught costs you, which is the difference "
              .. "between a hunt that grows and one that thins out",
          choices = {
              { key = "seeks", name = "seeks with them",
                help = "the hunt accelerates - every catch is one fewer to "
                    .. "find and one more looking for the rest" },
              { key = "out", name = "is out, and the last one hiding wins",
                help = "the hunt never grows, so the seekers earn every "
                    .. "catch - and the last hider left takes the round" },
              { key = "freeze", name = "is frozen until a hider frees them",
                help = "a catch is a question for everybody else - go back "
                    .. "for them, or stay hidden and leave them there" },
          } },
    },

    noNametags = true,

    room = { rules = { interactions = 0 } },

    wholeGame = true,

    noDozing = true,

    maps = "own",

    startPlace = { level = LEVEL_CASTLE_GROUNDS, area = 1, act = 0 },

    saysOut = true,

    inertStarsAndCaps = true,

    capsUnlocked = true,

    enemiesBack = 10,

    teams = false,

    stallRole = ROLE_HIDER,

    lensRole = ROLE_SEEKER,

    noWhereabouts = true,

    allActs = true,

    openGates = true,

    castleOpen = true,

    clockStopped = true,

    cheatsGiven = { fins = 1 },
}

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
    lastHiders = nil
    wasHiding = nil
    thawFrames = 0
    thawingFrames = 0
    OF.util.publish_row(0, "ofHsFresh", nil)

    OF.util.publish_row(0, "ofHsFrozen", nil)

    roundSecs = gGlobalSyncTable.ofGmLimit

    local held = math.floor(scatter_frames() / 30)
    if am_seeker() then
        OF.notify.show("You are seeking. You are held for @ seconds.", "warn", 6,
            tostring(held))
    else
        OF.notify.show("Hide! The seekers are held for @ seconds.", "good", 6,
            tostring(held))
    end
end

local CAUGHT_LINES = {
    seeks  = "Caught by @ - you are seeking now",
    out    = "Caught by @ - you are out",
    freeze = "Caught by @ - frozen until a hider reaches you",
}

local WENT_DOWN_LINES = {
    seeks  = "You went down with a seeker here - you are seeking now",
    out    = "You went down with a seeker here - you are out",
    freeze = "You went down with a seeker here - frozen where you fell",
}

local function catch_line(lines)
    return lines[OF.gamemodes.option_now("caught") or "seeks"] or lines.seeks
end

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
    OF.notify.show(text, "bad", 5, who)
    OF.sounds.play(SOUND_MENU_CAMERA_BUZZ)

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

function mode.update()

    OF.gamemodes.count_the_hold(disperse_left())

    if whole_game() and OF.gamemodes.role(0) == ROLE_HIDER then
        local me = gMarioStates[0]
        local dead = me ~= nil and (me.health or 0x880) <= 0xFF
        if dead and not wasDead then
            wasDead = true

            if seeker_in_my_level() and not (rescue() and frozen(0)) then
                found(catch_line(WENT_DOWN_LINES))
                return
            end
        elseif not dead then
            wasDead = false
        end
    end

    if am_seeker() then return end
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
                    OF.notify.show("@ got you out - hide again", "good", 5,
                        OF.util.plain(saver.np.name))

                    OF.sounds.play(SOUND_MENU_COLLECT_SECRET)
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

    for _, entry in ipairs(OF.gamemodes.participants()) do
        if OF.gamemodes.role(entry.localIndex) == ROLE_SEEKER
            and not caught_just_now(entry.localIndex) then
            local distance = OF.gamemodes.distance(0, entry.localIndex)
            if distance ~= nil and distance < CATCH_RANGE
                and OF.gamemodes.tag_move(entry.localIndex) then
                found(catch_line(CAUGHT_LINES), OF.util.plain(entry.np.name))
                return
            end
        end
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
    if not whole_game() then return false end

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

    if whole_game() and OF.gamemodes.role(0) == ROLE_HIDER
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
    graceFrames = 0
    wasDead = false
    lastHiders = nil
    wasHiding = nil

    roundSecs = nil
    thawFrames = 0
    thawingFrames = 0
    OF.util.publish_row(0, "ofHsFresh", nil)

    OF.util.publish_row(0, "ofHsFrozen", nil)

    if whole_game() and OF.util.is_host()
        and OF.util.asks(OF.net, "undo_warp") and OF.net.can_undo() then
        OF.util.report(OF.net.undo_warp())
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
    local wanted = (gGlobalSyncTable.ofGmElapsed or 0) + round_seconds()
    if wanted <= limit then return false end
    OF.util.publish("ofGmLimit", wanted)
    return true
end

local function caught_since(was)
    local now = {}
    for _, entry in ipairs(free_hiders()) do now[entry.localIndex] = true end
    if was == nil then return now end

    for localIndex in pairs(was) do
        if not now[localIndex] then
            local np = gNetworkPlayers[localIndex]
            local role = OF.gamemodes.role(localIndex)
            if np ~= nil and np.connected
                and (role == ROLE_SEEKER or role == ROLE_OUT
                     or (rescue() and frozen(localIndex))) then

                OF.stats.record(localIndex, "frozen", 1)
            end
        end
    end
    return now
end

function mode.host_update()

    wasHiding = caught_since(wasHiding)

    if whole_game() then

        local now = #free_hiders()
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
        OF.gamemodes.finish("Everyone was found - the seekers win.")
        return
    end

    local left = hiders_in_play()
    if #left == 0 then
        OF.gamemodes.abandon("Nobody left to find.")
        return
    end

    if rescue() and #free_in_play() == 0 then
        OF.gamemodes.finish("Everyone was frozen - the seekers win.")
        return
    end

    if elimination() and #left == 1
        and #OF.gamemodes.with_role(ROLE_OUT) > 0 then
        OF.gamemodes.finish("@ was never found.", left[1].np.name,
            left[1].np.name)
    end
end

function mode.on_timeout()

    local left = free_in_play()
    if #left == 0 then
        OF.gamemodes.finish("The seekers win.")
    elseif #left == 1 then
        OF.gamemodes.finish("@ was never found.", left[1].np.name, left[1].np.name)
    else

        local names = {}
        for _, entry in ipairs(left) do
            if entry.np ~= nil and entry.np.name ~= nil then
                table.insert(names, entry.np.name)
            end
        end
        OF.gamemodes.finish("@ hiders survived.", { names = names }, #left)
    end
end

local LIST_X = 0.03
local LIST_Y = 0.24

local LIST_WIDTH = 190

local LIST_MARGIN = 8

local function side_rows(role)
    local rows = {}
    for _, entry in ipairs(OF.gamemodes.with_role(role)) do
        if entry.np ~= nil then
            local name = OF.util.plain(entry.np.name)

            local mark = nil
            if rescue() and role == ROLE_HIDER and frozen(entry.localIndex) then
                mark = OF.lang.t("frozen")
            end
            table.insert(rows, { name = name, right = mark,
                                 localIndex = entry.localIndex })
        end
    end
    return rows
end

function OF.gm_hideseek_hiding_places()
    local seen, list = {}, {}
    for _, entry in ipairs(OF.gamemodes.with_role(ROLE_HIDER)) do
        local np = gNetworkPlayers[entry.localIndex]
        if np ~= nil and np.currLevelNum ~= nil then
            local area = np.currAreaIndex
            local secret = OF.util.level_is_secret(np.currLevelNum, area)

            local key = secret and "secret"
                or (tostring(np.currLevelNum) .. ":" .. tostring(area))
            if not seen[key] then
                seen[key] = true
                table.insert(list, { level = np.currLevelNum, area = area,
                                     secret = secret or nil })
            end
        end
    end

    local function rank(place)
        if place.secret then return OF.util.secret_order() end
        return OF.util.level_order(place.level, place.area)
    end
    table.sort(list, function(a, b)
        local ra, rb = rank(a), rank(b)
        if ra ~= rb then return ra < rb end

        if a.secret ~= b.secret then return a.secret == true end
        if a.level ~= b.level then return a.level < b.level end
        return (a.area or 0) < (b.area or 0)
    end)
    return list
end

local function draw_level_list(x, y)
    local places = OF.gm_hideseek_hiding_places()
    if #places == 0 then return y end

    local scale = 0.85
    local lineHeight = OF.util.line_height(scale) + 4
    local max = OF.util.rows_that_fit(y + lineHeight, lineHeight)
    local shown = math.min(#places, max)

    local mine = gNetworkPlayers[0]
    local hereLevel = mine ~= nil and mine.currLevelNum or nil
    local hereArea = mine ~= nil and mine.currAreaIndex or nil

    local hereSecret = OF.util.level_is_secret(hereLevel, hereArea)

    local heading = OF.lang.t("Hiding in")
    local names = {}
    local widest = OF.util.drawn_width(heading, scale)
    for row, place in ipairs(places) do
        if row > max then break end

        local namer = place.secret and OF.util.concealed_level_name
            or OF.util.level_name
        local ok, said = pcall(namer, place.level, place.area)
        local name = (ok and type(said) == "string" and said ~= "") and said
            or OF.lang.t("Somewhere")
        names[row] = name
        local drawn = OF.util.drawn_width(name, scale)
        if drawn > widest then widest = drawn end
    end
    local width = math.max(LIST_WIDTH, widest + LIST_MARGIN * 2)

    OF.util.plate(x - LIST_MARGIN, y - 5, width,
        lineHeight * (shown + 1) + 10)
    OF.util.text(heading, x, y, scale,
        OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
    y = y + lineHeight

    for row, place in ipairs(places) do
        if row > max then break end

        local name = names[row]
        local here
        if place.secret then
            here = hereSecret
        else
            here = place.level == hereLevel and place.area == hereArea
        end
        if here then
            OF.util.text_raw(name, x, y, scale, 255, 235, 120, 255)
        else
            OF.util.text_raw(name, x, y, scale, 190, 190, 200, 255)
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

function OF.gm_hideseek_blind()
    if not OF.gamemodes.is_running() then return false end
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return false end
    if not am_seeker() then return false end
    if not OF.util.can_play(0) then return false end
    return disperse_left() > 0
end

function mode.hud()
    local remaining = disperse_left()

    if OF.gm_hideseek_blind() then draw_the_curtain() end

    if remaining > 0 then
        local text = am_seeker()
            and ("Held for " .. remaining .. "s")
            or ("Hide! " .. remaining .. "s")
        OF.util.banner(text, 1.3, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
    end

    local text = #free_hiders() .. " still hidden"
    OF.util.banner(text, 0.9, 230, 210, 255, 255)

    if rescue() and frozen(0) then
        OF.util.banner(OF.lang.t("Frozen - a hider can reach you"),
            1.0, 160, 210, 255, 255)
    end

    local thawing = OF.gm_hideseek_thawing()
    if thawing ~= nil then
        OF.util.banner(OF.lang.fill("Getting them out - @%",
            tostring(math.floor(thawing * 100))), 1.0, 160, 255, 200, 255)
    end

    if OF.gamemodes.role(0) == ROLE_OUT then
        OF.util.banner(OF.lang.t("You are out - watch the rest"),
            1.0, 255, 140, 140, 255)
    end

    if OF.gm_hideseek_exit_locked() then
        OF.util.banner(OF.lang.t("A seeker is in this level - the way out is shut"),
            0.8, 200, 200, 210, 255)
    end

    if OF.gamemodes.role(0) == ROLE_HIDER and OF.util.can_play(0)
        and disperse_left() <= 0 and seeker_near() then
        local r, g, b = OF.gm_hideseek_warning_tint(warning_seconds())
        OF.util.banner(OF.lang.t("A seeker is near"), 1.0, r, g, b, 255)
    end

    if not whole_game() then return end

    local x = djui_hud_get_screen_width() * LIST_X
    local y = djui_hud_get_screen_height() * LIST_Y
    local seeking = side_rows(ROLE_SEEKER)
    local hiding = side_rows(ROLE_HIDER)

    y = OF.util.board(x, y, OF.lang.fill("Seeking (@)", #seeking), seeking)
    y = OF.util.board(x, y + 8, OF.lang.fill("Hiding (@)", #hiding), hiding)

    local out = side_rows(ROLE_OUT)
    if #out > 0 then
        y = OF.util.board(x, y + 8, OF.lang.fill("Out (@)", #out), out)
    end

    draw_level_list(x, y + 8)
end

function mode.paint(localIndex)
    if OF.gamemodes.role(localIndex) == ROLE_SEEKER then return SEEKER_COLOUR end
    return nil
end

function OF.gm_hideseek_castle_round()
    return OF.gamemodes.is_running() and whole_game()
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

function mode.scenery()
    if graceFrames > 0 then
        graceFrames = graceFrames - 1
        if graceFrames == 0 then OF.util.publish_row(0, "ofHsFresh", nil) end
    end
end

OF.gamemodes.register(mode)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil then return end
    if not whole_game() then return end
    if not OF.gamemodes.is_running() then return end
    if OF.gamemodes.role(m.playerIndex) ~= ROLE_SEEKER then return end
    local body = m.marioBodyState
    if body == nil or type(body.modelState) ~= "number" then return end
    if not OF.util.has_flag(body.modelState, METAL) then
        body.modelState = body.modelState + METAL
    end
end)

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

    local floor = gLevelValues == nil and nil or gLevelValues.floorLowerLimit
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
