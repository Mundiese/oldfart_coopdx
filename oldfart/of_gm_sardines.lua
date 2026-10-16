OF = OF or {}

local function catch_range()
    return (OF.hunt ~= nil and OF.hunt.CATCH_RANGE) or 170
end

local SCATTER_STOPS = { twenty = 20, ten = 10, forty = 40 }

local DEFAULT_SECONDS = 4 * 60

local ROLE_SEEKER = (OF.hunt ~= nil and OF.hunt.ROLE_SEEKER) or "a seeker"
local ROLE_HIDDEN = (OF.hunt ~= nil and OF.hunt.ROLE_HIDER) or "a hider"
local wasHidden = false

local headToHead = nil

local function scatter_seconds()
    local said = OF.gamemodes.option_now("scatter")
    return SCATTER_STOPS[said] or SCATTER_STOPS.twenty
end

local function scatter_seconds_showing()
    local said = OF.gamemodes.option_showing("sardines", "scatter")
    return SCATTER_STOPS[said] or SCATTER_STOPS.twenty
end

local function head_start_left()
    local elapsed = OF.gamemodes.since_start()
    if type(elapsed) ~= "number" then return 0 end
    local left = scatter_seconds() - elapsed
    if left <= 0 then return 0 end
    return math.ceil(left)
end

local WHERE = {}
for _, row in ipairs(OF.gm_hideseek_WHERE or {}) do
    if row.key ~= "castle" then table.insert(WHERE, row) end
end
if #WHERE == 0 then
    WHERE[1] = { key = "whole", name = "The whole game",
        help = "every course and the castle, starting on the grounds" }
end
local WHERE_BY_KEY = {}
for _, row in ipairs(WHERE) do WHERE_BY_KEY[row.key] = row end

local function where()
    local said = OF.util.asks(OF.gamemodes, "option_showing")
        and OF.gamemodes.option_showing("sardines", "where") or nil
    return WHERE_BY_KEY[said or ""] or WHERE[1]
end

local function hidden_players()
    return OF.gamemodes.with_role(ROLE_HIDDEN)
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
    key = "sardines",
    name = "Sardines",
    blurb = "one hides, the rest look - find them and you hide too, silently",
    how = "A course or the whole game, picked below. Doors open.\n"
        .. "One of you hides. Everybody else seeks after the count.\n"
        .. "How long that head start is is set below.\n"
        .. "Find the hider and join them - squeeze in, stay quiet.\n"
        .. "The tin grows every time somebody finds it.\n"
        .. "The last seeker left alone, with everybody in, loses.",
    aims = {
        [ROLE_HIDDEN] = "Stay hidden and quiet. You are already in.",
        [ROLE_SEEKER] = "Find the tin. Being found is the reward - "
            .. "whoever is still looking alone loses.",
    },

    minPlayers = 2,

    maps = "own",

    startPlace = setmetatable({}, { __index = function(_, field)
        local row = where()
        if row.level ~= nil then
            if field == "level" then return row.level end
            if field == "area" then return 1 end
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
                    value = { level = row.level, area = 1, act = 1, name = row.name } })
            end
        end
        return out
    end,

    realActs = true,
    noCopy = true,

    wingCap = true,

    cheatsGiven = OF.gamemodes.water_rule("hide", { speedo = 1 }),
    seekerMetal = true,
    noWhereabouts = true,
    allActs = true,
    openGates = true,
    clockStopped = true,

    noNametags = true,

    marking = { players = false },

    room = { rules = { interactions = 0 } },

    noDozing = true,

    teams = false,
    defaultLimit = DEFAULT_SECONDS,
    target = { name = "seconds on the clock",
               asks = "How long the round runs before the buzzer",
               clock = true,
               default = DEFAULT_SECONDS,
               min = 60, max = 480, step = 30 },

    caps = { tiebreak = false },

    lastWord = "LAST SEEKER",
    roleBanner = false,
    options = {
        { key = "where", name = "Where",
          help = "everywhere, or one course",
          choices = WHERE },
        { key = "scatter", name = "How long the hider gets",
          help = "how long seekers are held before they are let go",
          choices = {
              { key = "twenty", name = "twenty seconds",
                help = "long enough to get well away" },
              { key = "ten", name = "ten seconds",
                help = "found in the first place anybody thinks to look" },
              { key = "forty", name = "forty seconds",
                help = "far enough to reach the far side of the castle" },
          } },
    },
}

mode.target.auto = function()
    return where().key == "whole" and 360 or 180
end

function mode.setup(players, options)
    if OF.util.asks(OF.rules, "lend_many") then
        local wants = {}
        if mode.noWhereabouts == true then
            table.insert(wants, { key = "whereabouts", value = 0 })
        end
        if mode.allActs == true then
            table.insert(wants, { key = "allstars", value = 1 })
        end
        if mode.openGates == true then
            table.insert(wants, { key = "gates", value = 1 })
        end
        if mode.clockStopped == true then
            table.insert(wants, { key = "clock", value = 4 })
        end
        if #wants > 0 then
            OF.util.report(OF.rules.lend_many(wants, "sardines"))
        end
    end

    if options == nil or tonumber(options.limit) == nil then

        OF.util.publish("ofGmLimit", OF.util.clamp(
            OF.gamemodes.auto_target(mode, players, options
                or { target = OF.gamemodes.target_for(mode.key) or DEFAULT_SECONDS }),
            mode.target.min, mode.target.max))
    end

    local it = OF.gamemodes.deal_it(players, 1, false)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex,
            it[entry.localIndex] and ROLE_HIDDEN or ROLE_SEEKER)
    end
end

function mode.late_join(localIndex)
    return ROLE_SEEKER
end

function mode.on_start()
    headToHead = nil
    wasHidden = (OF.gamemodes.role(0) == ROLE_HIDDEN)

end

function mode.before_mario_update(m)
    if OF.gamemodes.role(0) ~= ROLE_SEEKER then return end
    if head_start_left() <= 0 then return end
    OF.input.hold(m)
end

function mode.update()

    OF.gamemodes.count_the_hold(head_start_left())
    if OF.gamemodes.role(0) ~= ROLE_SEEKER then return end
    if head_start_left() > 0 then return end

    local range = catch_range()
    for _, entry in ipairs(hidden_players()) do
        do

            if OF.gamemodes.tag_lands(0, entry.localIndex, range) then
                OF.gamemodes.set_role(0, ROLE_HIDDEN)

                if OF.util.asks(OF.hud, "banner") then
                    OF.hud.banner("role", OF.lang.t("FOUND IT"), OF.lang.t("You are in the tin"))
                end

                OF.gamemodes.cue("good")

                if OF.util.asks(OF.lobbytalk, "feed") then OF.lobbytalk.feed(0, entry.localIndex) end
                return
            end
        end
    end
end

function mode.host_update()
    if OF.gamemodes.state() ~= OF.gamemodes.ACTIVE then return end

    if OF.gamemodes.role_is_gone(ROLE_HIDDEN) then
        OF.gamemodes.abandon("Nobody was left to hide from.")
        return
    end

    if headToHead == nil then
        local hid = OF.gamemodes.with_role(ROLE_HIDDEN)
        local seeking = OF.gamemodes.contending(ROLE_SEEKER)
        headToHead = { on = #hid == 1 and #seeking == 1,
                 hider = hid[1] ~= nil and hid[1].np.globalIndex or nil }
    end

    local left = OF.gamemodes.contending(ROLE_SEEKER)
    if #left == 0 then
        local names = {}
        local finder = nil
        for _, entry in ipairs(hidden_players()) do
            table.insert(names, entry.np.name)
            if entry.np.globalIndex ~= headToHead.hider then finder = entry end
        end

        if headToHead.on and finder ~= nil then
            OF.gamemodes.finish("@ found the tin and won.", finder.np.name, finder.np.name)
            return
        end
        OF.gamemodes.finish("Everybody in the tin won.",
            { names = names })
        return
    end

    if #left == 1 and #hidden_players() > 1 then
        local loser = left[1]
        local names = {}
        for _, entry in ipairs(hidden_players()) do
            table.insert(names, entry.np.name)
        end
        OF.gamemodes.finish("Everybody in the tin won - @ was left looking.",
            { names = names }, loser.np.name)
        return
    end
end

function mode.still_winnable()
    return #OF.gamemodes.with_role(ROLE_HIDDEN) >= 1
        and #OF.gamemodes.contending(ROLE_SEEKER) >= 1
end

function mode.on_timeout()
    local names = {}
    for _, entry in ipairs(hidden_players()) do
        table.insert(names, entry.np.name)
    end

    if headToHead ~= nil and headToHead.on and #names == 1 then
        OF.gamemodes.finish("Time - @ won, never found.", { names = names }, names[1])
        return
    end
    OF.gamemodes.finish(#names == 1 and "Time - @ player in the tin won."
        or "Time - @ players in the tin won.", { names = names }, tostring(#names))
end

function mode.terms()
    return OF.lang.fill(
        "one hides - the last seeker left alone loses")
end

function mode.hud()
    local role = OF.gamemodes.role(0)
    local left = head_start_left()

    if OF.util.asks(OF.hunt, "curtain") and OF.hunt.curtain(left)
        and OF.util.asks(OF.hunt, "blind_number") then

        OF.hunt.blind_number(left)
        return
    end

    local state = OF.util.asks(OF.hud, "state_line") and OF.hud.state_line or function() end
    if role == ROLE_HIDDEN and left > 0 then
        state("hide", OF.lang.t("Hide"), { prio = 70, figure = left, tone = "runner" })
    elseif role == ROLE_HIDDEN then
        state("tin", OF.lang.t("In the tin"), { prio = 50, tone = "good" })
    elseif role == ROLE_SEEKER and left <= 0 then
        state("seeking", OF.lang.t("Seeking"), { prio = 20, tone = "hunter" })
    end

    if OF.util.asks(OF.hunt, "hiding_board") then
        local below = nil
        if OF.util.asks(OF.gamemodes, "side_board") then
            OF.gamemodes.side_board()
            if OF.util.asks(OF.gamemodes, "side_bottom") then
                below = OF.gamemodes.side_bottom()
            end
        end
        OF.hunt.hiding_board(below)
    end
end

function mode.cluster()
    if not OF.util.asks(OF.hunt, "role_cluster") or OF.gamemodes.is_waiting() then return nil end
    return OF.hunt.role_cluster("Seek", #OF.gamemodes.contending(ROLE_SEEKER), "hunter",
        "Tin", #hidden_players(), "runner")
end

function mode.cleanup()
    wasHidden = false

    if OF.util.is_host() and OF.util.asks(OF.net, "undo_warp")
        and OF.net.can_undo() then
        OF.util.report(OF.net.undo_warp(true))
    end
    return true
end

function mode.blind()
    return OF.util.asks(OF.hunt, "blind") and OF.hunt.blind(head_start_left()) == true
end

setmetatable(mode, { __index = function(_, field)
    if field == "wholeGame" then return where().key == "whole" end
    return nil
end })

OF.gamemodes.register(mode)
