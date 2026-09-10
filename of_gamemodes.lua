OF = OF or {}
OF.gamemodes = OF.gamemodes or {}

local modes = OF.gamemodes

modes.OFF       = 0
modes.COUNTDOWN = 1
modes.ACTIVE    = 2
modes.RESULTS   = 3

modes.MOMENT    = 4

local COUNTDOWN_FRAMES = 5 * 30

local RESULTS_FRAMES   = 3 * 30

local GO_HOLD_MAX = 10 * 30

local goHoldFrames = 0

local MOMENT_FRAMES    = 3 * 30

modes.LIST = {}
modes.BY_KEY = {}

modes.arenaChoice = nil

function modes.cycle_arena()
    if OF.arena == nil then return end
    local places = OF.arena.PLACES
    if modes.arenaChoice == nil then
        modes.arenaChoice = places[1].key
        return
    end
    for index, place in ipairs(places) do
        if place.key == modes.arenaChoice then
            local nextPlace = places[index + 1]
            modes.arenaChoice = nextPlace ~= nil and nextPlace.key or nil
            return
        end
    end
    modes.arenaChoice = nil
end

local engine_cycle_arena = modes.cycle_arena

function modes.cycle_arena()
    engine_cycle_arena()
    if modes.arenaChoice ~= nil then modes.levelChoice = nil end
end

function modes.arena_label()
    if modes.arenaChoice == nil then return "where we are" end
    if OF.arena == nil then return "where we are" end
    return OF.arena.name_of(modes.arenaChoice) or "where we are"
end

modes.levelChoice = nil

modes.targetChoice = {}

local function sentence_case(text)
    if type(text) ~= "string" or text == "" then return text end
    return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

function modes.target_asks(mode)
    if mode == nil or mode.target == nil then return nil end
    local asks = mode.target.asks
    if asks ~= nil and asks ~= "" then return OF.lang.t(asks) end
    return sentence_case(OF.lang.t(mode.target.name))
end

function modes.target_for(key)
    local mode = modes.BY_KEY[key]
    if mode == nil or mode.target == nil then return nil end
    local chosen = modes.targetChoice[key]
    if type(chosen) == "number" then return chosen end
    return mode.target.default
end

function modes.set_target(key, value)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local mode = modes.BY_KEY[key]
    if mode == nil then return false, "No such game mode." end
    if mode.target == nil then
        return false, OF.lang.fill("@ has no target to change.", OF.lang.t(mode.name))
    end

    value = math.floor(tonumber(value) or 0)
    local low, high = mode.target.min or 1, mode.target.max or 999
    if value < low or value > high then

        return false, OF.lang.fill("@ takes @.", OF.lang.t(mode.name),
            OF.lang.fill("@ to @", tostring(low), tostring(high)))
    end

    modes.targetChoice[key] = value
    return true
end

function modes.step_target(key)
    local mode = modes.BY_KEY[key]
    if mode == nil or mode.target == nil then return false end
    local step = mode.target.step or 1
    local next = (modes.target_for(key) or mode.target.default) + step
    if next > (mode.target.max or 999) then next = mode.target.min or step end
    return modes.set_target(key, next)
end

function modes.with_target()
    local list = {}
    for _, mode in ipairs(modes.LIST) do
        if mode.target ~= nil then table.insert(list, mode) end
    end
    return list
end

modes.optionChoice = {}

modes.OPTS_KEY = "ofGmOpts"
function modes.options_of(mode)
    if mode == nil or type(mode.options) ~= "table" then return {} end
    return mode.options
end

function modes.option_entry(mode, optKey)
    for _, option in ipairs(modes.options_of(mode)) do
        if option.key == optKey then return option end
    end
    return nil
end

function modes.option_pick(modeKey, optKey)
    local mode = modes.BY_KEY[modeKey]
    local option = modes.option_entry(mode, optKey)
    if option == nil then return nil end
    local chosen = modes.optionChoice[modeKey] ~= nil
        and modes.optionChoice[modeKey][optKey] or nil
    for _, choice in ipairs(option.choices) do
        if choice.key == chosen then return chosen end
    end
    return option.choices[1].key
end

function modes.option_choice(modeKey, optKey)
    local mode = modes.BY_KEY[modeKey]
    local option = modes.option_entry(mode, optKey)
    if option == nil then return nil end
    local picked = modes.option_pick(modeKey, optKey)
    for _, choice in ipairs(option.choices) do
        if choice.key == picked then return choice end
    end
    return option.choices[1]
end

function modes.set_option(modeKey, optKey, value)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local mode = modes.BY_KEY[modeKey]
    if mode == nil then return false, "No such game mode." end
    local option = modes.option_entry(mode, optKey)
    if option == nil then
        return false, OF.lang.fill("@ has no such setting.", OF.lang.t(mode.name))
    end
    for _, choice in ipairs(option.choices) do
        if choice.key == value then
            modes.optionChoice[modeKey] = modes.optionChoice[modeKey] or {}
            modes.optionChoice[modeKey][optKey] = value
            return true
        end
    end
    return false, OF.lang.fill("@ cannot be played that way.",
        OF.lang.t(option.name))
end

function modes.step_option(modeKey, optKey)
    local mode = modes.BY_KEY[modeKey]
    local option = modes.option_entry(mode, optKey)
    if option == nil then return false end
    local picked = modes.option_pick(modeKey, optKey)
    for index, choice in ipairs(option.choices) do
        if choice.key == picked then
            local next = option.choices[index + 1] or option.choices[1]
            return modes.set_option(modeKey, optKey, next.key)
        end
    end
    return modes.set_option(modeKey, optKey, option.choices[1].key)
end

function modes.with_options()
    local list = {}
    for _, mode in ipairs(modes.LIST) do
        if #modes.options_of(mode) > 0 then table.insert(list, mode) end
    end
    return list
end

function modes.pack_options(modeKey)
    local mode = modes.BY_KEY[modeKey]
    local pieces = {}
    for _, option in ipairs(modes.options_of(mode)) do
        local picked = modes.option_pick(modeKey, option.key)
        if picked ~= option.choices[1].key then
            table.insert(pieces, option.key .. "=" .. picked)
        end
    end
    return table.concat(pieces, ";")
end

local optsRaw = nil
local optsParsed = {}

local function parsed_options()
    local text = gGlobalSyncTable[modes.OPTS_KEY]
    if type(text) ~= "string" then text = "" end
    if text ~= optsRaw then
        optsRaw = text
        optsParsed = {}
        for piece in string.gmatch(text, "[^;]+") do
            local name, value = string.match(piece, "^([^=]+)=(.+)$")
            if name ~= nil then optsParsed[name] = value end
        end
    end
    return optsParsed
end

function modes.option_now(optKey)
    local mode = modes.current()
    local option = modes.option_entry(mode, optKey)
    if option == nil then return nil end
    local said = parsed_options()[optKey]
    for _, choice in ipairs(option.choices) do
        if choice.key == said then return said end
    end
    return option.choices[1].key
end

function modes.option_is(optKey, value)
    return modes.option_now(optKey) == value
end

function modes.option_showing(modeKey, optKey)
    local current = modes.current()
    if current ~= nil and current.key == modeKey
        and modes.state() ~= modes.OFF then
        local said = modes.option_now(optKey)
        if said ~= nil then return said end
    end
    return modes.option_pick(modeKey, optKey)
end

function modes.set_level(entry)
    if entry == nil then
        modes.levelChoice = nil
        return true
    end
    if entry.level == nil then return false end
    modes.levelChoice = {
        level = entry.level,
        area = entry.area or 1,
        act = entry.act or 1,
        name = entry.name or "somewhere",
    }
    modes.arenaChoice = nil
    return true
end

function modes.find_level(text)
    local needle = string.lower(text or "")
    if needle == "" then return nil end
    if not OF.util.asks(OF.util, "level_groups") then return nil end

    local best = nil
    for _, group in ipairs(OF.util.level_groups()) do
        for _, entry in ipairs(OF.util.levels_in_group(group)) do
            local name = string.lower(entry.name or "")
            if name == needle then return entry end

            if string.find(name, needle, 1, true) ~= nil then
                if best == nil or #name < #(best.name or "") then best = entry end
            end
        end
    end
    return best
end

function modes.level_label()
    if modes.levelChoice == nil then return "where we are" end
    return modes.levelChoice.name
end

modes.MAP_KINDS = { "arenas", "anywhere", "own", "surveyed", "none" }

local KIND_WORDS = {}
for _, kind in ipairs(modes.MAP_KINDS) do KIND_WORDS[kind] = true end

modes.ARENA_SET = {
    "bowser1", "bowser2", "bowser3",

    "desert_cage", "ice_donut", "the_plate",
    "wmotr", "aquarium", "cotmc", "tower",
}

modes.TILE_ARENAS = {
    "bowser1", "bowser2", "bowser3",
    "desert_cage", "ice_donut", "the_plate",
    "wmotr", "tower",
}

modes.NO_ROUND_HERE = {
    [LEVEL_TOTWC] = "one climb and a lot of air - no round shape holds here",
}

function modes.round_refused_here(level)
    if level == nil then return nil end
    return modes.NO_ROUND_HERE[level]
end

function modes.course_levels()
    local out = {}
    if OF.LEVELS == nil then return out end
    for _, entry in ipairs(OF.LEVELS) do
        if entry.group == "Courses"
            and modes.round_refused_here(entry.level) == nil then
            table.insert(out, {
                level = entry.level, area = entry.area or 1,
                act = entry.act or 1, name = entry.name,
            })
        end
    end
    return out
end

function modes.takes_main_courses(modeKey)
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil
    if mode == nil then return false end
    if modes.owns_its_place(mode) then return false end
    return mode.mainCourses == true
end

function modes.owns_its_place(mode)
    if mode == nil then return false end
    return mode.startPlace ~= nil or mode.wholeGame == true
        or mode.noArena == true
end

function modes.maps_of(mode)
    if mode == nil then return "anywhere", nil end
    local declared = mode.maps
    if type(declared) == "table" then

        local lead = declared[1]
        if type(lead) == "string" and KIND_WORDS[lead] then
            local keys = {}
            for index = 2, #declared do
                table.insert(keys, declared[index])
            end
            return lead, keys
        end
        return "arenas", declared
    end
    if declared == "own" then return "own", nil end
    if declared == "arenas" then return "arenas", nil end
    if declared == "surveyed" then return "surveyed", nil end
    if declared == "none" then return "none", nil end
    return "anywhere", nil
end

function modes.surveyed_levels(modeKey)
    local mode = modes.BY_KEY[modeKey]
    if mode == nil then return {} end
    local wanted = mode.surveyKeys
    if type(wanted) ~= "table" or #wanted == 0 then return {} end

    local takenOut = {}
    for _, room in ipairs(mode.surveyOut or {}) do
        if type(room) == "table" and room.level ~= nil then
            takenOut[tostring(room.level) .. ":"
                .. tostring(room.area or 1)] = true
        end
    end

    local out = {}
    for level, areas in pairs(modes.SURVEYED) do
        for area, keys in pairs(areas) do

            if type(keys) == "table"
                and modes.round_refused_here(level) == nil
                and not takenOut[tostring(level) .. ":" .. tostring(area)] then
                local all = true
                for _, key in ipairs(wanted) do
                    local held = keys[key]
                    if key == "points" then
                        if type(held) ~= "table" or #held < 3 then all = false end
                    elseif type(held) ~= "table" then
                        all = false
                    end
                end
                if all then
                    table.insert(out, {
                        level = level, area = area, act = 1,

                        name = OF.util.level_name(level, area)
                            or ("Level " .. tostring(level)),
                    })
                end
            end
        end
    end

    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.area < b.area
    end)
    return out
end

local function kept_off(place, modeKey)
    if modeKey == nil or place == nil then return false end
    for _, key in ipairs(place.notFor or {}) do
        if key == modeKey then return true end
    end
    return false
end

function modes.rooms_for(modeKey)
    local mode = modes.BY_KEY[modeKey]
    local kind, keys = modes.maps_of(mode)
    if kind == "own" or kind == "none" then return {} end
    if kind == "surveyed" and (keys == nil or #keys == 0) then return {} end
    if not OF.util.asks(OF.arena, "find") then return {} end

    local wanted = nil
    if keys ~= nil then
        wanted = {}
        for _, key in ipairs(keys) do wanted[key] = true end
    end

    local out = {}
    for _, place in ipairs(OF.arena.PLACES or {}) do

        if (wanted == nil or wanted[place.key])
            and modes.round_refused_here(place.level) == nil
            and not kept_off(place, modeKey) then
            table.insert(out, place)
        end
    end
    return out
end

function modes.takes_any_level(modeKey)
    return (modes.maps_of(modes.BY_KEY[modeKey])) == "anywhere"
end

function modes.accepts_arena(modeKey, arenaKey)
    if arenaKey == nil or arenaKey == "" then return true end
    if modeKey == nil or modes.BY_KEY[modeKey] == nil then return true end
    for _, room in ipairs(modes.rooms_for(modeKey)) do
        if room.key == arenaKey then return true end
    end
    return false
end

function modes.accepts_level(modeKey, place)
    if place == nil or place.level == nil then return true end

    if modes.round_refused_here(place.level) ~= nil then return false end
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil
    if mode == nil then return true end
    if modes.takes_any_level(modeKey) then return true end

    if modes.takes_main_courses(modeKey) then
        for _, entry in ipairs(modes.course_levels()) do
            if entry.level == place.level
                and (entry.area or 1) == (place.area or 1) then
                return true
            end
        end
    end
    if modes.maps_of(mode) ~= "surveyed" then return false end
    for _, entry in ipairs(modes.surveyed_levels(modeKey)) do
        if entry.level == place.level
            and (entry.area or 1) == (place.area or 1) then
            return true
        end
    end
    return false
end

function modes.place_for(modeKey)
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil
    local arenaKey = modes.arenaChoice
    local place = modes.levelChoice
    if arenaKey == "" then arenaKey = nil end
    if place ~= nil and place.level == nil then place = nil end

    if mode == nil then
        if arenaKey ~= nil then return "arena", arenaKey end
        if place ~= nil then return "level", place end
        return nil
    end

    if modes.owns_its_place(mode) then return nil end

    if arenaKey ~= nil then
        if modes.accepts_arena(modeKey, arenaKey) then return "arena", arenaKey end
        return nil
    end

    if place ~= nil then
        if modes.accepts_level(modeKey, place) then return "level", place end
        return nil
    end

    return nil
end

function modes.place_label(modeKey)
    local what, value = modes.place_for(modeKey)
    if what == nil then what, value = modes.default_place(modeKey) end
    if what == "level" then
        return (value ~= nil and value.name) or "where we are"
    end
    if what == "arena" then
        if OF.arena == nil then return "where we are" end
        return OF.arena.name_of(value) or "where we are"
    end
    return "where we are"
end

function modes.place_adrift(modeKey)
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil
    if mode == nil then return nil end
    if modes.place_for(modeKey) ~= nil then return nil end
    if modes.arenaChoice ~= nil and modes.arenaChoice ~= "" then
        return modes.arena_label()
    end
    if modes.levelChoice ~= nil then return modes.level_label() end
    return nil
end

function modes.offered_places(modeKey)
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil
    if mode == nil then return {} end
    local kind = modes.maps_of(mode)

    local out = {}
    if kind == "surveyed" then
        for _, entry in ipairs(modes.surveyed_levels(modeKey)) do
            table.insert(out, { what = "level", value = entry,
                level = entry.level, area = entry.area or 1 })
        end
    end

    if modes.takes_main_courses(modeKey) then
        for _, entry in ipairs(modes.course_levels()) do
            table.insert(out, { what = "level", value = entry,
                level = entry.level, area = entry.area or 1 })
        end
    end

    for _, room in ipairs(modes.rooms_for(modeKey)) do
        local missing = OF.util.asks(OF.arena, "custom_missing")
            and OF.arena.custom_missing(room) or nil
        if missing == nil and room.level ~= nil then
            table.insert(out, { what = "arena", value = room.key,
                level = room.level, area = room.area or 1 })
        end
    end
    return out
end

function modes.default_place(modeKey)
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil
    if mode == nil then return nil end
    if modes.owns_its_place(mode) then return nil end
    if modes.maps_of(mode) == "anywhere" then return nil end

    local offered = {}
    for _, entry in ipairs(modes.offered_places(modeKey)) do

        if not (mode.noSweep == true and entry.what == "arena") then
            table.insert(offered, entry)
        end
    end
    if #offered == 0 then return nil end

    local np = nil
    if gNetworkPlayers ~= nil then
        for seat = 0, MAX_PLAYERS - 1 do
            local other = gNetworkPlayers[seat]
            if np == nil and other ~= nil and other.connected
                and OF.util.is_host_player(seat) then
                np = other
            end
        end
        np = np or gNetworkPlayers[0]
    end
    local hereLevel = np ~= nil and np.currLevelNum or nil
    local hereArea = np ~= nil and np.currAreaIndex or nil
    if hereLevel ~= nil and hereLevel ~= 0 then
        for _, entry in ipairs(offered) do
            if entry.level == hereLevel and entry.area == hereArea then
                return entry.what, entry.value, true
            end
        end
    end

    return offered[1].what, offered[1].value, false
end

modes.placeDoor = "gamemodes"
function modes.place_door()
    local page = modes.placeDoor
    if page == nil or page == "" then return "gamemodes" end
    return page
end

function modes.register(mode)
    table.insert(modes.LIST, mode)
    modes.BY_KEY[mode.key] = mode
end

modes.GROUPS = {

    { name = "Catch somebody",
      help = "one role hunts, and being caught is what changes who you are",
      keys = { "hideseek", "zombies", "murder",
               "hotpotato", "manhunt" } },

    { name = "Fight it out",
      help = "putting somebody down is the whole mechanic - these want a ring",
      keys = { "laststanding", "sumo", "bounty" } },

    { name = "Hold your ground",
      help = "a place or a thing, and the clock runs for as long as it is yours",
      keys = { "koth", "domination", "crown" } },

    { name = "Something to carry",
      help = "something has to be moved, and where it ends up is the point",
      keys = { "coinrush", "bank", "ctf" } },

    { name = "Get to the end",
      help = "there is an end, and getting to it first is the whole round",
      keys = { "line", "secretrun", "bossrush", "shellrace", "meltdown" } },

    { name = "The round is the enemy",
      help = "nobody is hunting you - the level, the music or the caller is",

      keys = { "spots", "simon", "flood", "hexagone", "hexheat", "logroll" } },
}

modes.UNGROUPED = "Everything else"
function modes.grouped()
    local where = {}
    for index, group in ipairs(modes.GROUPS) do
        for _, key in ipairs(group.keys) do where[key] = index end
    end

    local buckets = {}
    for index = 1, #modes.GROUPS do buckets[index] = {} end
    local rest = {}

    for _, mode in ipairs(modes.LIST) do
        local index = where[mode.key]
        if index == nil then
            table.insert(rest, mode)
        else
            table.insert(buckets[index], mode)
        end
    end

    local out = {}
    for index, group in ipairs(modes.GROUPS) do
        if #buckets[index] > 0 then

            table.insert(out, { name = group.name, help = group.help,
                                modes = buckets[index] })
        end
    end
    if #rest > 0 then
        table.insert(out, { name = modes.UNGROUPED,
                            help = "registered after the families were written, "
                                .. "and nobody has sorted them yet",
                            modes = rest })
    end
    return out
end

function modes.rules_for(mode)
    if mode == nil then return nil end
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
        and mode.blurbTeams ~= nil and mode.blurbTeams ~= "" then
        return mode.blurbTeams
    end
    return mode.blurb
end

function modes.terms()
    local mode = modes.current()
    local list = {}
    if mode == nil then return list end

    if type(mode.terms) == "function" then
        local ok, extra = pcall(mode.terms)
        if ok and type(extra) == "string" and extra ~= "" then
            table.insert(list, extra)
        end
    end

    local limit = gGlobalSyncTable.ofGmLimit or 0
    if limit > 0 and not mode.countsUp then
        table.insert(list, modes.clock(limit))
    end

    return list
end

function modes.state()
    return gGlobalSyncTable.ofGmState or modes.OFF
end

function modes.current()
    local key = gGlobalSyncTable.ofGmKey
    if key == nil or key == "" then return nil end
    return modes.BY_KEY[key]
end

function modes.is_running()
    return modes.state() == modes.COUNTDOWN or modes.state() == modes.ACTIVE
end

function modes.is_over()
    return modes.state() == modes.MOMENT or modes.state() == modes.RESULTS
end

function modes.time_left()
    local limit = gGlobalSyncTable.ofGmLimit or 0
    if limit <= 0 then return nil end
    local elapsed = gGlobalSyncTable.ofGmElapsed or 0
    return math.max(0, limit - elapsed)
end

function modes.round_seconds(fallback)
    local secs = gGlobalSyncTable.ofGmSecs
    if type(secs) == "number" and secs > 0 then return secs end
    if type(fallback) == "number" and fallback > 0 then return fallback end
    return nil
end

function modes.scale_clock(seconds, arenaKey, mode)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return 0 end

    local scale = 1
    if OF.util.asks(OF.arena, "clock_of") then
        scale = scale * (tonumber(OF.arena.clock_of(arenaKey)) or 1)
    end
    if OF.util.asks(OF.rules, "step_setting") then
        scale = scale * (tonumber(OF.rules.step_setting("roundlen", "scale", 1)) or 1)
    end

    if scale <= 0 then
        if type(mode) == "table" and mode.countsUp then return seconds end
        return 0
    end
    return math.max(1, math.floor(seconds * scale + 0.5))
end

function modes.overtime_seconds()
    if modes.state() ~= modes.ACTIVE then return nil end
    local limit = gGlobalSyncTable.ofGmLimit or 0
    if limit <= 0 then return nil end
    local elapsed = gGlobalSyncTable.ofGmElapsed or 0
    if elapsed <= limit then return nil end
    return elapsed - limit
end

function modes.elapsed()
    return gGlobalSyncTable.ofGmElapsed or 0
end

function modes.since_start()
    if modes.liveAt == nil then return modes.elapsed() end
    local seconds = clock_elapsed() - modes.liveAt
    if seconds < 0 then return modes.elapsed() end
    return seconds
end

modes.ORIGIN_SLACK = 1.0

function modes.clock(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%.0f:%02.0f", math.floor(seconds / 60), seconds % 60)
end

function modes.can_play(localIndex)
    return OF.util.can_play(localIndex)
end

modes.AFK_OUT = {
    line = { why = "On red you hold still for at most three seconds. A minute "
                .. "of it is somebody who has stopped playing, and the round "
                .. "waits for every runner who could still reach the pole." },
    meltdown = { why = "The floor is going out from under everybody. Standing "
                    .. "still for a minute is not a way through it, and the "
                    .. "round is open until nobody is left who could get "
                    .. "home." },
    shellrace = { why = "A lap race. There is no reason to stand still in one, "
                     .. "and the round waits for everybody still running it." },
}

do

local AFK_STILL_FRAMES = 60 * 30

local AFK_MOVED = 8

local stillAt = {}
local stillFor = {}

function modes.forget_still_counts()
    stillAt = {}
    stillFor = {}
end

local function watches_stillness()
    if not modes.is_running() then return false end
    local mode = modes.current()
    return mode ~= nil and modes.AFK_OUT[mode.key] ~= nil
end

function modes.settle_stillness()
    if not watches_stillness() then
        if next(stillFor) ~= nil then modes.forget_still_counts() end
        return
    end
    if modes.state() ~= modes.ACTIVE then return end
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local m = gMarioStates[li]
        if m ~= nil and m.pos ~= nil then
            local was = stillAt[li]
            if was == nil
                or math.abs(m.pos.x - was.x) > AFK_MOVED
                or math.abs(m.pos.y - was.y) > AFK_MOVED
                or math.abs(m.pos.z - was.z) > AFK_MOVED then
                stillAt[li] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
                stillFor[li] = 0
            else
                stillFor[li] = (stillFor[li] or 0) + 1
            end
        end
    end
end

function modes.gone_still(localIndex)
    if localIndex == nil then return false end
    if not watches_stillness() then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    return (stillFor[localIndex] or 0) >= AFK_STILL_FRAMES
end

function modes.still_seconds(localIndex)
    return math.floor((stillFor[localIndex] or 0) / 30)
end

function modes.set_still_frames(localIndex, frames)
    stillFor[localIndex] = frames
end

end

function modes.in_contention(localIndex)
    if modes.gone_still(localIndex) then return false end
    if OF.util.can_play(localIndex) then return true end
    return OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex)
end

local participantCache = nil
local participantFrame = nil

function modes.forget_participants()
    participantCache = nil
    participantFrame = nil
end

function modes.participants()
    local now = (get_global_timer ~= nil) and get_global_timer() or nil
    if participantCache ~= nil and now ~= nil and now == participantFrame then
        return participantCache
    end

    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if modes.can_play(entry.localIndex) then
            table.insert(list, entry)
        end
    end

    participantCache = list
    participantFrame = now
    return list
end

function modes.still_here()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if modes.can_play(entry.localIndex) or modes.is_out(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

function modes.still_loading()
    local waiting = 0
    for _, entry in ipairs(modes.participants()) do
        if entry.np ~= nil and entry.np.currAreaSyncValid == false then
            waiting = waiting + 1
        end
    end
    return waiting
end

function modes.pins_on_players(mode)
    if mode == nil then return false end
    return mode.pinsOnPlayers == true
end

function modes.still_loading_for(mode)
    if modes.pins_on_players(mode) then return modes.still_loading() end
    local np = gNetworkPlayers[0]
    if np ~= nil and np.currAreaSyncValid == false then return 1 end
    return 0
end

function modes.reason_sitting_out(localIndex)
    if OF.util.asks(OF.speedrun, "is_excluded")
        and OF.speedrun.is_excluded(localIndex) then
        return "sitting rounds out"
    end
    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return "watching somebody"
    end
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex) then
        return "in jail"
    end

    if OF.util.asks(OF.idle, "left_out") and OF.idle.left_out(localIndex) then
        return "away from the keyboard"
    end

    return "not taking part"
end

function modes.sitting_out()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if not modes.can_play(entry.localIndex) then
            table.insert(list, {
                localIndex = entry.localIndex,
                name = entry.np ~= nil and entry.np.name or "",
                why = modes.reason_sitting_out(entry.localIndex),
            })
        end
    end
    return list
end

function modes.say_who_is_sitting_out()
    local out = modes.sitting_out()
    if #out == 0 then return 0 end
    djui_chat_message_create("  \\#808080\\" .. OF.lang.t(
        "In the lobby but not in the count:"))
    for _, entry in ipairs(out) do
        djui_chat_message_create("  \\#808080\\" .. OF.lang.fill("@ - @",
            OF.util.plain(entry.name), OF.lang.t(entry.why)))
    end
    return #out
end

function modes.standing(localIndex)
    if not modes.is_running() then return nil end
    local role = modes.role(localIndex)
    if role == nil or role == "" then return nil end
    if role == modes.WAITING then return "WAIT" end

    local mode = modes.current()
    if mode ~= nil and mode.standing ~= nil then
        local said = mode.standing(localIndex)
        if said ~= nil and said ~= "" then return said end
    end

    local row = gPlayerSyncTable[localIndex]
    local score = row ~= nil and row.ofScore or 0
    if type(score) ~= "number" or score <= 0 then return nil end
    if mode ~= nil and mode.scoreIsTime then return tostring(score) .. "s" end
    return tostring(score)
end

function modes.score_board(role, score_of, format)
    local board = {}
    for _, entry in ipairs(modes.with_role(role)) do
        table.insert(board, { name = entry.np.name, score = score_of(entry.localIndex),
                              localIndex = entry.localIndex })
    end
    table.sort(board, function(a, b) return a.score > b.score end)
    for _, entry in ipairs(board) do entry.right = format(entry.score, entry) end
    return board
end

function modes.best_of(entries, valueOf, lowerWins, breakerOf)
    local bestValue, names, tied = nil, {}, {}
    for _, entry in ipairs(entries or {}) do
        local value = valueOf(entry)
        if type(value) == "number" then
            local better = bestValue == nil
                or (lowerWins and value < bestValue)
                or (not lowerWins and value > bestValue)
            if better then
                bestValue = value
                names = { entry.np.name }
                tied = { entry }
            elseif value == bestValue then
                table.insert(names, entry.np.name)
                table.insert(tied, entry)
            end
        end
    end

    if breakerOf ~= nil and #tied > 1 then
        local bestRung, kept = nil, {}
        for _, entry in ipairs(tied) do
            local rung = breakerOf(entry)
            if type(rung) == "number" then
                if bestRung == nil or rung > bestRung then
                    bestRung = rung
                    kept = { entry.np.name }
                elseif rung == bestRung then
                    table.insert(kept, entry.np.name)
                end
            end
        end

        if #kept > 0 and #kept < #names then names = kept end
    end

    table.sort(names)
    return bestValue, names
end

function modes.with_role(role)
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if modes.role(entry.localIndex) == role then
            table.insert(list, entry)
        end
    end
    return list
end

function modes.roles_dealt()
    local seen, list = {}, {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local role = modes.role(entry.localIndex)
        if role ~= nil and role ~= "" and seen[role] == nil then
            seen[role] = true
            table.insert(list, role)
        end
    end
    table.sort(list)
    return list
end

function modes.role_is_gone(role)
    for _, entry in ipairs(OF.util.connected_players()) do
        if modes.role(entry.localIndex) == role
            and modes.can_play(entry.localIndex) then
            return false
        end
    end
    return true
end

function modes.contending(role)
    local list = {}
    for _, entry in ipairs(modes.with_role(role)) do
        if modes.in_contention(entry.localIndex) then
            table.insert(list, entry)
        end
    end
    return list
end

function modes.race_over(home, out, wanted)
    if type(home) ~= "number" or home <= 0 then return false end
    if type(out) == "number" and out <= 0 then return true end
    return type(wanted) == "number" and home >= wanted
end

function modes.played()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local role = modes.role(entry.localIndex)
        if role ~= "" and role ~= modes.WAITING then
            table.insert(list, entry)
        end
    end
    return list
end

modes.WAITING = "waiting for the next round"
modes.SEAT_SECONDS = 120

modes.heldSeats = {}

local SEATS_MAX = 16

local KEEP_HOLDER = "roundkeeps"
local seatIds = {}

function modes.held_seat(id)
    if type(id) ~= "string" then return nil end
    return modes.heldSeats[id]
end

function modes.seats_held()
    local held = 0
    for _ in pairs(modes.heldSeats) do held = held + 1 end
    return held
end

function modes.forget_seats()
    modes.heldSeats = {}
end

function modes.remember_seat_id(localIndex)
    if not OF.util.is_host() then return nil end
    if localIndex == nil or localIndex == 0 then return nil end
    local id = OF.util.player_id(localIndex)
    seatIds[localIndex] = id
    return id
end

function modes.seat_id(localIndex)
    return seatIds[localIndex]
end

function modes.bank_seat(localIndex)
    if not OF.util.is_host() then return nil end
    if localIndex == nil or localIndex == 0 then return nil end
    if not modes.is_running() then return nil end

    local key = gGlobalSyncTable.ofGmKey
    if key == nil or key == "" then return nil end

    local role = modes.role(localIndex)
    if role == "" or role == modes.WAITING then return nil end

    local id = seatIds[localIndex]
    if type(id) ~= "string" or id == "" then return nil end

    if modes.heldSeats[id] ~= nil then return nil end
    if modes.seats_held() >= SEATS_MAX then return nil end

    local np = gNetworkPlayers[localIndex]
    local name = np ~= nil and OF.util.plain(np.name or "") or nil
    if name == nil or name == "" then name = OF.lang.t("Somebody") end

    modes.heldSeats[id] = {
        name = name,
        role = role,
        key = key,
        at = clock_elapsed(),
    }

    OF.notify.send_all("@ dropped out - the round is holding their place",
        "warn", 5, modes.heldSeats[id].name)
    return id
end

function modes.redeem_seat(localIndex)
    if not OF.util.is_host() then return false end
    if localIndex == nil or localIndex == 0 then return false end
    if not modes.is_running() then return false end

    local id = seatIds[localIndex]
    local seat = modes.held_seat(id)
    if seat == nil then return false end

    if seat.key ~= gGlobalSyncTable.ofGmKey then
        modes.heldSeats[id] = nil
        return false
    end

    modes.heldSeats[id] = nil
    modes.set_role(localIndex, seat.role)

    local np = gNetworkPlayers[localIndex]
    if np ~= nil then
        OF.notify.send_to(np.globalIndex, "Welcome back - you are @ again",
            "good", 6, seat.role)
    end
    OF.notify.send_all("@ is back, and so is their round", "good", 5, seat.name)
    return true
end

function modes.expire_seats()
    local now = clock_elapsed()
    local gone = {}
    for id, seat in pairs(modes.heldSeats) do
        if now - (seat.at or now) >= modes.SEAT_SECONDS then
            table.insert(gone, id)
        end
    end
    for _, id in ipairs(gone) do
        local seat = modes.heldSeats[id]
        modes.heldSeats[id] = nil

        OF.notify.send_all("@ is not coming back - their place is released",
            "info", 5, seat.name)
    end
    return #gone
end

local function on_player_disconnected(m)
    modes.forget_participants()
    if m == nil then return end
    local localIndex = m.playerIndex
    if localIndex == nil or localIndex == 0 then return end
    modes.bank_seat(localIndex)

    seatIds[localIndex] = nil
end

local function on_player_connected(m)
    modes.forget_participants()

    if not OF.util.is_host() then return end
    if m == nil or m.playerIndex == 0 then return end

    modes.remember_seat_id(m.playerIndex)

    if not modes.is_running() then return end

    local mode = modes.current()
    if mode == nil then return end

    local localIndex = m.playerIndex
    if not modes.can_play(localIndex) then return end

    if OF.teams ~= nil then OF.teams.add_late(localIndex) end

    if modes.redeem_seat(localIndex) then return end

    local role = nil
    if mode.late_join ~= nil and not modes.refuses_latecomers(mode.key) then
        role = mode.late_join(localIndex)
    end
    if role == nil or role == "" then role = modes.WAITING end
    modes.set_role(localIndex, role)

    local np = gNetworkPlayers[localIndex]
    if np == nil then return end

    OF.notify.send_to(np.globalIndex, "@ - you are @", "info", 6, mode.name, role)
end

hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_player_disconnected)

for i = 0, MAX_PLAYERS - 1 do
    for _, key in ipairs({ "ofNoRace", "ofSpectating" }) do
        hook_on_sync_table_change(gPlayerSyncTable[i], key, i, function()
            if i == 0 and OF.util.asks(OF.guard, "repair_mine") then
                OF.guard.repair_mine(key)
            end
            modes.forget_participants()
        end)
    end
end

for i = 1, MAX_PLAYERS - 1 do
    hook_on_sync_table_change(gPlayerSyncTable[i], "ofJailed", i,
        function(tag, oldVal, newVal)
            if OF.util.asks(OF.jail, "repair_row") then
                OF.jail.repair_row(i)
            end
            if newVal ~= oldVal then modes.forget_participants() end
        end)
end

function modes.role(localIndex)
    local s = gPlayerSyncTable[localIndex]
    if s == nil or s.ofRole == nil then return "" end
    return s.ofRole
end

function modes.set_role(localIndex, role)
    OF.util.publish_row(localIndex, "ofRole", role)
end

function modes.my_role()
    return modes.role(0)
end

local rotation = 0

local lastWinner = nil

local lastDeal = {}

function modes.last_deal()
    return lastDeal
end

function modes.forget_rotation()
    rotation = 0
    lastWinner = nil
    lastDeal = {}
end

function modes.last_winner()
    return lastWinner
end

function modes.deal_it(players, count, toWinner)
    local picked = {}
    local total = #players
    if total == 0 then return picked end

    lastDeal = {}
    for _, entry in ipairs(players) do
        table.insert(lastDeal, entry.localIndex)
    end

    count = math.max(1, math.min(math.floor(count or 1), total))

    local taken = 0
    if toWinner and lastWinner ~= nil then
        for _, entry in ipairs(players) do
            if entry.np ~= nil and entry.np.globalIndex == lastWinner then
                picked[entry.localIndex] = true
                taken = 1
                break
            end
        end
    end

    local step = 0
    while taken < count and step < total do
        local entry = players[((rotation + step) % total) + 1]
        if entry ~= nil and not picked[entry.localIndex] then
            picked[entry.localIndex] = true
            taken = taken + 1
        end
        step = step + 1
    end

    rotation = rotation + 1
    return picked
end

modes.forgedRoles = modes.forgedRoles or 0

local ROLE_GRACE_FRAMES = 90
local roleGraceLeft = nil

local function put_the_role_back(localIndex)
    OF.util.publish_row(localIndex, "ofRole", "")
    modes.forgedRoles = modes.forgedRoles + 1
    OF.guard.note(OF.lang.t("a role handed out with no round running"))
end

function modes.settle_role_grace()
    if roleGraceLeft == nil then return end

    if modes.state() ~= modes.OFF then
        roleGraceLeft = nil
        return
    end
    roleGraceLeft = roleGraceLeft - 1
    if roleGraceLeft > 0 then return end
    roleGraceLeft = nil

    if OF.util.is_host() then return end
    local row = gPlayerSyncTable[0]
    if row == nil then return end
    local role = row.ofRole
    if role == nil or role == "" then return end
    put_the_role_back(0)
end

function modes.forget_role_grace()
    roleGraceLeft = nil
end

function modes.repair_role(localIndex)
    if modes.state() ~= modes.OFF then return false end
    if localIndex ~= 0 and not OF.util.is_host() then return false end

    local row = gPlayerSyncTable[localIndex]
    if row == nil then return false end
    local role = row.ofRole
    if role == nil or role == "" then return false end

    if localIndex == 0 and not OF.util.is_host() then
        roleGraceLeft = ROLE_GRACE_FRAMES
        return false
    end

    put_the_role_back(localIndex)
    return true
end

for i = 0, MAX_PLAYERS - 1 do
    hook_on_sync_table_change(gPlayerSyncTable[i], "ofRole", i, function()
        modes.repair_role(i)
    end)
end

function modes.marked_place()
    local mode = modes.current()
    if mode == nil or mode.place == nil then return nil end
    if not modes.is_running() then return nil end
    return mode.place()
end

function modes.may_attack(attacker, victim)
    if not modes.is_running() then return true end
    if attacker ~= nil
        and modes.left_out_of_this_round(attacker.playerIndex) then
        return false
    end
    if victim ~= nil
        and modes.left_out_of_this_round(victim.playerIndex) then
        return false
    end
    local mode = modes.current()
    if mode == nil or mode.may_attack == nil then return true end
    return mode.may_attack(attacker, victim) ~= false
end

function modes.marked_player(localIndex)
    local mode = modes.current()
    if mode == nil or mode.marked_player == nil then return nil end
    if not modes.is_running() then return nil end
    return mode.marked_player(localIndex)
end

function modes.marker_occluded(kind)
    local mode = modes.current()
    if mode == nil or mode.marker_occluded == nil then return nil end
    if not modes.is_running() then return nil end
    return mode.marker_occluded(kind)
end

local function local_state_seen_by(np)
    if np == nil then return nil end
    local was = OF.util.optional("lag_compensation_get_local_state", nil, np)
    if was == nil or was.pos == nil then return nil end
    return was
end

modes.local_state_seen_by = local_state_seen_by

function modes.distance(aIndex, bIndex)
    local na, nb = gNetworkPlayers[aIndex], gNetworkPlayers[bIndex]
    if na == nil or nb == nil then return nil end
    if na.currLevelNum ~= nb.currLevelNum then return nil end
    if na.currAreaIndex ~= nb.currAreaIndex then return nil end
    if not nb.currPositionValid then return nil end

    local ma, mb = gMarioStates[aIndex], gMarioStates[bIndex]
    if ma == nil or mb == nil then return nil end

    if aIndex == 0 and bIndex ~= 0 then
        ma = local_state_seen_by(nb) or ma
    end

    local dx = ma.pos.x - mb.pos.x
    local dy = ma.pos.y - mb.pos.y
    local dz = ma.pos.z - mb.pos.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local TAG_MOVES = {}
do
    local named = {
        ACT_JUMP_KICK,
        ACT_GROUND_POUND, ACT_GROUND_POUND_LAND,
        ACT_PUNCHING, ACT_MOVE_PUNCHING, ACT_WATER_PUNCH,
        ACT_DIVE, ACT_DIVE_SLIDE,
        ACT_SLIDE_KICK, ACT_SLIDE_KICK_SLIDE,
    }

    for index = 1, 10 do
        if named[index] ~= nil then TAG_MOVES[named[index]] = true end
    end
end

local ON_A_POLE = {}
do
    local named = {
        ACT_HOLDING_POLE, ACT_CLIMBING_POLE, ACT_GRAB_POLE_SLOW,
        ACT_GRAB_POLE_FAST, ACT_TOP_OF_POLE, ACT_TOP_OF_POLE_TRANSITION,
    }
    for index = 1, 6 do
        if named[index] ~= nil then ON_A_POLE[named[index]] = true end
    end
end

modes.TAG_MOVES = TAG_MOVES
modes.ON_A_POLE = ON_A_POLE

local function feet_are_wet(m)
    if m == nil then return false end
    if OF.util.asks(OF.cheats, "hover_wet") then return OF.cheats.hover_wet(m) end
    if ACT_FLAG_SWIMMING == nil then return false end
    return OF.util.has_flag(m.action or 0, ACT_FLAG_SWIMMING)
end

function modes.tag_move(taggerLocal)
    local m = gMarioStates[taggerLocal]
    if m == nil then return false end
    local action = m.action or 0
    if TAG_MOVES[action] then return true end
    if ON_A_POLE[action] then return true end
    return feet_are_wet(m)
end

local hostPhaseTimer = 0

local REPIN_FRAMES = 30
local repinIn = nil

function modes.room_moving()
    if not OF.util.is_host() then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    repinIn = -1
    return true
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    if repinIn == -1 then repinIn = REPIN_FRAMES end
end)

local OVERTIME_MAX = 60 * 30

local NOWIN_FRAMES = 20

local nowinFrames = 0

function modes.nowin_frames()
    if not OF.util.is_host() then return 0 end
    return nowinFrames
end

function modes.forget_nowin()
    nowinFrames = 0
end

local SETTLE_FRAMES = 30

local settleFrames = 0

function modes.settle_frames()
    if not OF.util.is_host() then return 0 end
    return settleFrames
end

function modes.forget_settle()
    settleFrames = 0
end

local function cap_can_draw(mode)

    return mode.resultsBy ~= "splits"
end

modes.CAP_DEFAULTS = {

    { "symmetric", function(mode) return mode.symmetric == true end },

    { "teamCount", function(mode) return modes.can_have_sides(mode) and 2 or 1 end },

    { "hasObjective", function(mode) return mode.target ~= nil end },
    { "canDraw", cap_can_draw },

    { "overtime", function(mode)
        return mode.symmetric == true and mode.overtime ~= nil
    end },

    { "tiebreak", cap_can_draw },
}

function modes.caps(mode)
    local out = {}
    for _, entry in ipairs(modes.CAP_DEFAULTS) do
        local name, derive = entry[1], entry[2]
        local declared = nil
        if type(mode) == "table" and type(mode.caps) == "table" then
            declared = mode.caps[name]
        end
        if declared ~= nil then
            out[name] = declared
        elseif type(mode) == "table" then
            out[name] = derive(mode)
        else
            out[name] = false
        end
    end
    return out
end

modes.OVERTIME = 5

function modes.phase()
    local state = modes.state()
    if state == modes.ACTIVE and modes.overtime_seconds() ~= nil then
        return modes.OVERTIME
    end
    return state
end

modes.LADDER = {
    { key = "lead",   name = "time in front" },
    { key = "first",  name = "getting in front first", lower = true },
}

function modes.rung_name(key)
    for _, rung in ipairs(modes.LADDER) do
        if rung.key == key then return rung.name end
    end
    return ""
end

modes.tiebreakOn = true

function modes.set_tiebreak(on)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then
        return false, "Only the host decides how a level round ends."
    end
    modes.tiebreakOn = (on == true)
    return true
end

modes.wantSides = false

function modes.set_sides(on)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then
        return false, "Only the host decides whether a round has sides."
    end
    modes.wantSides = (on == true)
    return true
end

function modes.sides_wanted(mode)
    if not modes.can_have_sides(mode) then return false end

    if OF.util.asks(OF.teams, "by_nature") and OF.teams.by_nature(mode) then
        return true
    end
    return modes.wantSides == true
end

function modes.can_have_sides(mode)
    if type(mode) ~= "table" then return false end
    return mode.teams ~= nil and mode.teams ~= false
end

function modes.sides_effect(mode)
    if not modes.can_have_sides(mode) then return nil end
    local said = mode.blurbTeams
    if type(said) ~= "string" or said == "" then return nil end
    return said
end

function modes.sides_capable()
    local out = {}
    for _, mode in ipairs(modes.LIST) do
        if modes.can_have_sides(mode) then table.insert(out, mode) end
    end
    return out
end

local ledger = nil
local ledgerSecond = -1

local ledgerSaw = false

local function forget_ledger()
    ledger = nil
    ledgerSecond = -1
    ledgerSaw = false
end

modes.forget_ledger = forget_ledger

local function standing_now(mode)
    if type(mode) == "table" and mode.standing ~= nil then
        local ok, list = pcall(mode.standing)
        if ok and type(list) == "table" and #list > 0 then return list end
    end

    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        local list = {}
        for _, team in ipairs(OF.teams.LIST) do
            table.insert(list, { key = "t:" .. team.key,
                                 score = OF.teams.score(team.key) })
        end
        return list
    end

    local list = {}
    for _, entry in ipairs(modes.played()) do
        local row = gPlayerSyncTable[entry.localIndex]
        table.insert(list, { key = entry.localIndex,
                             score = (row ~= nil and row.ofScore) or 0 })
    end
    return list
end

local function sample_standing(second)
    if not OF.util.is_host() then return end
    if second == ledgerSecond then return end
    ledgerSecond = second
    if ledger == nil then ledger = {} end

    local list = standing_now(modes.current())

    local best, leader, tied = nil, nil, false
    for _, entry in ipairs(list) do
        if type(entry.score) == "number" then
            local held = ledger[entry.key]
            if held == nil then
                held = { lead = 0, first = nil }
                ledger[entry.key] = held
            end
            if best == nil or entry.score > best then
                best, leader, tied = entry.score, entry.key, false
            elseif entry.score == best then
                tied = true
            end
        end
    end

    if leader == nil or tied then return end
    local held = ledger[leader]
    held.lead = held.lead + 1
    ledgerSaw = true
    if held.first == nil then held.first = second end
end

local function rung_value(key, party)
    if key == "lead" then
        local held = ledger ~= nil and ledger[party.key] or nil
        return held ~= nil and held.lead or 0
    end
    if key == "first" then
        local held = ledger ~= nil and ledger[party.key] or nil

        return held ~= nil and held.first or nil
    end

    return nil
end

local function climb(rung, parties)
    local best, kept, runnerUp = nil, {}, nil
    for _, party in ipairs(parties) do
        local value = rung_value(rung.key, party)
        if type(value) == "number" then
            local better = best == nil
                or (rung.lower and value < best)
                or (not rung.lower and value > best)
            if better then
                if best ~= nil then runnerUp = best end
                best, kept = value, { party }
            elseif value == best then
                table.insert(kept, party)
            elseif runnerUp == nil
                or (rung.lower and value < runnerUp)
                or (not rung.lower and value > runnerUp) then
                runnerUp = value
            end
        end
    end

    if #kept ~= 1 then return nil end
    return kept[1], best, runnerUp
end

function modes.same_job()
    local mode = modes.current()
    if mode ~= nil and modes.caps(mode).symmetric then return true end

    local seen = nil
    for _, entry in ipairs(modes.played()) do
        local role = modes.role(entry.localIndex)
        if role ~= "" and role ~= modes.WAITING then
            if seen == nil then
                seen = role
            elseif role ~= seen then
                return false
            end
        end
    end
    return true
end

modes.TIME_UP = "Time!"
modes.LAST_OUT   = "Nobody made it - @ lasted longest."
modes.FORFEIT    = "Forfeit - @ is the only one left."
modes.NO_CONTEST = "No contest - nobody was left to finish it."
modes.ENDINGS = {
    [modes.TIME_UP]    = { name = "time",         draw = true },
    [modes.LAST_OUT]   = { name = "last one out", draw = false },
    [modes.FORFEIT]    = { name = "forfeit",      draw = false },
    [modes.NO_CONTEST] = { name = "no contest",   draw = false },
}

function modes.ending_of(text)
    if type(text) ~= "string" then return nil end
    local ending = modes.ENDINGS[text]
    return ending ~= nil and ending.name or nil
end

function modes.is_draw(text)
    if type(text) ~= "string" then return false end

    local ending = modes.ENDINGS[text]
    if ending ~= nil then return ending.draw end

    return string.find(string.lower(text), "%f[%a]draw%f[%A]") ~= nil
end

local function tied_parties()
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        local best, kept = nil, {}
        for _, team in ipairs(OF.teams.LIST) do
            local score = OF.teams.score(team.key)
            if best == nil or score > best then
                best, kept = score, { team }
            elseif score == best then
                table.insert(kept, team)
            end
        end
        if #kept < 2 then return {} end
        local parties = {}
        for _, team in ipairs(kept) do
            table.insert(parties, { key = "t:" .. team.key, name = team.name,
                                    team = team.key })
        end
        return parties
    end

    local played = modes.played()
    local _, names = modes.best_of(played, function(entry)
        local row = gPlayerSyncTable[entry.localIndex]
        return (row ~= nil and row.ofScore) or 0
    end)
    if #names < 2 then return {} end

    local parties = {}
    for _, entry in ipairs(played) do
        for _, name in ipairs(names) do
            if entry.np.name == name then
                table.insert(parties, { key = entry.localIndex,
                                        name = entry.np.name })
            end
        end
    end
    return parties
end

function modes.settle_draw()
    if not OF.util.is_host() then return nil end
    if not modes.tiebreakOn then return nil end

    local mode = modes.current()
    if mode == nil or not modes.caps(mode).tiebreak then return nil end
    if not modes.same_job() then return nil end

    if not ledgerSaw then return nil end

    local parties = tied_parties()
    if #parties < 2 then return nil end

    for _, rung in ipairs(modes.LADDER) do
        local won, best, runnerUp = climb(rung, parties)
        if won ~= nil then
            local figures = tostring(best)
            if runnerUp ~= nil then
                figures = figures .. "-" .. tostring(runnerUp)
            end
            local winner = won.name
            if won.team ~= nil then winner = { team = won.team } end
            return winner, rung.key, won.name, figures
        end
    end
    return nil
end

modes.PACKET_ASK = "gmask"
local function ask_host(go, key)
    local packet = { ofp = modes.PACKET_ASK, go = go }

    if key ~= nil and key ~= "" then packet.key = key end

    local what, chosen = modes.place_for(key)
    if what == "arena" then
        packet.arena = chosen
    elseif what == "level" then
        packet.lvl = chosen.level
        packet.ar = chosen.area or 1
        packet.act = chosen.act or 1
    end
    return OF.util.send_to_host(packet)
end

function modes.start(key, options, askerLocal)
    if OF.wireWatch then OF.wire_mark("a round started") end
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    local mode = modes.BY_KEY[key]
    if mode == nil then return false, "No such game mode." end

    local players = modes.participants()
    if #players < (mode.minPlayers or 2) then

        modes.say_who_is_sitting_out()
        return false, OF.lang.fill("That mode needs at least @ players.", mode.minPlayers or 2)
    end

    if mode.playable_here ~= nil then
        local able, why = mode.playable_here()
        if not able then
            return false, why or OF.lang.t("That mode cannot be played here.")
        end
    end

    if not OF.util.is_host() then
        if not ask_host("start", key) then
            return false, "No host to ask yet - try again in a second."
        end
        return true, "asked"
    end

    options = options or {}

    modes.roundMods = options.mods or mode.mods or ""
    if modes.is_running() or modes.is_over() then
        modes.stop(true)
    end

    if OF.util.asks(OF.speedrun, "state") and OF.speedrun.state() ~= OF.speedrun.OFF then
        OF.speedrun.stop(true)
    end

    modes.forget_participants()
    players = modes.participants()

    local arenaKey = options.arena
    if arenaKey == nil or arenaKey == "" then arenaKey = modes.arenaChoice end

    if mode.noArena or mode.noSweep == true then
        if arenaKey ~= nil and arenaKey ~= "" then
            if mode.noArena then
                OF.notify.show("@ needs its own levels - playing without an arena.",
                    "info", 6, OF.lang.t(mode.name))
            else
                OF.notify.show("@ plays the level as it stands - no arena sweep.",
                    "info", 6, OF.lang.t(mode.name))
            end
        end
        arenaKey = nil
        if OF.arena ~= nil then OF.arena.close() end
    end

    if arenaKey ~= nil and arenaKey ~= "" and not modes.owns_its_place(mode)
        and not modes.accepts_arena(key, arenaKey) then
        OF.notify.show("@ does not go to @ - starting where the lobby is.",
            "info", 6, OF.lang.t(mode.name),
            OF.util.asks(OF.arena, "name_of")
                and (OF.arena.name_of(arenaKey) or arenaKey) or arenaKey)
        arenaKey = nil
    end

    local place = options.place or modes.levelChoice
    if place ~= nil and mode.noArena then
        OF.notify.show("@ needs its own levels - playing where it wants.",
            "info", 6, OF.lang.t(mode.name))
        place = nil
    end

    if place ~= nil and not modes.owns_its_place(mode)
        and not modes.accepts_level(key, place) then
        OF.notify.show("@ does not go to @ - starting where the lobby is.",
            "info", 6, OF.lang.t(mode.name),
            OF.lang.t(place.name or "there"))
        place = nil
    end

    if (arenaKey == nil or arenaKey == "") and place == nil then
        local what, chosen, standing = modes.default_place(key)
        if what == "arena" then
            arenaKey = chosen
        elseif what == "level" then
            place = { level = chosen.level, area = chosen.area or 1,
                      act = chosen.act or 1, name = chosen.name }
        end
        if what ~= nil then
            local named = what == "arena"
                and (OF.util.asks(OF.arena, "name_of")
                    and (OF.arena.name_of(chosen) or chosen) or chosen)
                or OF.lang.t(chosen.name or "there")
            if standing then
                OF.notify.show("@ had nothing picked - playing @, where the lobby is.",
                    "info", 6, OF.lang.t(mode.name), named)
            else
                OF.notify.show("@ had nothing picked - playing @, the first on its list.",
                    "info", 6, OF.lang.t(mode.name), named)
            end
        end
    end

    if arenaKey ~= nil and arenaKey ~= "" and OF.arena ~= nil then

        local opened, why = OF.arena.open(arenaKey, true, true, true)
        if not opened then
            OF.notify.show("Arena: @", "warn", 6,
                why or OF.lang.t("could not open it."))
        end

        local room = OF.util.asks(OF.arena, "find") and OF.arena.find(arenaKey)
        local dress = type(room) == "table" and room.mods or nil
        if type(dress) == "string" and dress ~= "" then
            if modes.roundMods == nil or modes.roundMods == "" then
                modes.roundMods = dress
            else
                modes.roundMods = modes.roundMods .. "," .. dress
            end
        end
    end

    if mode.startPlace ~= nil then
        if place ~= nil or (arenaKey ~= nil and arenaKey ~= "") then
            OF.notify.show("@ is played across the whole game - starting where it starts.",
                "info", 6, OF.lang.t(mode.name))
        end
        if arenaKey ~= nil and arenaKey ~= "" and OF.arena ~= nil then
            OF.arena.close()
        end
        arenaKey = nil
        place = { level = mode.startPlace.level,
                  area = mode.startPlace.area or 1,
                  act = mode.startPlace.act or 1 }
    end

    if place ~= nil and arenaKey == nil and OF.util.asks(OF.net, "warp_the_round") then
        local moved, why = OF.net.warp_the_round(place.level, place.area or 1, place.act or 1)
        if not moved then
            OF.notify.show("Could not send the lobby there: @", "warn", 6,
                why or OF.lang.t("no"))
        end
    end

    for i = 0, MAX_PLAYERS - 1 do
        modes.set_role(i, "")
    end

    if options.target == nil then options.target = modes.target_for(key) end

    OF.util.publish("ofGmKey", key)

    OF.util.publish(modes.OPTS_KEY, modes.pack_options(key))

    local askedLimit = tonumber(options.limit)
    OF.util.publish("ofGmLimit", askedLimit or mode.defaultLimit or 0)
    OF.util.publish("ofGmElapsed", 0)
    OF.util.publish("ofGmCount", math.ceil(COUNTDOWN_FRAMES / 30))
    OF.util.publish("ofGmWinner", "")
    OF.util.publish("ofGmState", modes.COUNTDOWN)
    hostPhaseTimer = 0

    modes.overtimeFrames = 0

    modes.forget_nowin()

    modes.forget_settle()

    goHoldFrames = 0

    forget_ledger()

    repinIn = nil

    modes.forget_claims()

    OF.util.publish("ofGmPlace", nil)

    if OF.teams ~= nil then
        OF.teams.begin(modes.sides_wanted(mode) and mode or nil, players)
    end

    local heldForRound = {}
    if OF.util.asks(OF.rules, "lobby_value") then
        for _, ruleKey in ipairs(modes.ROUND_RULE_KEYS) do
            if modes.keeps_rule(mode.key, ruleKey) then
                heldForRound[ruleKey] = OF.rules.lobby_value(ruleKey)
            end
        end
    end

    if OF.util.asks(OF.lockdown, "arm") then OF.lockdown.arm() end

    local putBack = {}
    for _, ruleKey in ipairs(modes.ROUND_RULE_KEYS) do
        local wanted = heldForRound[ruleKey]
        if wanted ~= nil and OF.util.asks(OF.rules, "lend_many")
            and OF.rules.value(ruleKey) ~= wanted then
            table.insert(putBack, { key = ruleKey, value = wanted })
        end
    end
    if #putBack > 0 then
        OF.util.report(OF.rules.lend_many(putBack, KEEP_HOLDER))
    end

    modes.take_the_room(mode)

    if mode.noNametags and OF.util.asks(OF.rules, "lend") then
        OF.util.report(OF.rules.lend("nametags", KEEP_HOLDER, 0))
    end

    if mode.setup ~= nil then mode.setup(players, options) end

    if askedLimit == nil then
        OF.util.publish("ofGmLimit",
            modes.scale_clock(gGlobalSyncTable.ofGmLimit, arenaKey, mode))
    end

    OF.util.publish("ofGmSecs", gGlobalSyncTable.ofGmLimit or 0)

    if mode.music ~= nil then OF.music.take_over(mode.music) end

    OF.notify.send_all("@ - @", "info", 6, mode.name, mode.blurb)

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("started @", OF.lang.t(mode.name)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("started the round: @", OF.lang.t(mode.name)))
    return true
end

local WINNER_FIELD = "\31"
local PACK_MAX = 256

local function pack_result(parts)
    local packed = table.concat(parts, WINNER_FIELD)
    if #packed <= PACK_MAX then return packed end

    for i = 5, #parts do parts[i] = "" end
    packed = table.concat(parts, WINNER_FIELD)
    if #packed <= PACK_MAX then return packed end

    local room = PACK_MAX - (#packed - #parts[2])
    if room > 4 then
        parts[2] = parts[2]:sub(1, room - 3) .. "..."
    else
        parts[2] = ""
    end
    return table.concat(parts, WINNER_FIELD)
end

local function end_round(text, winner, a, b, why)
    if not OF.util.is_host() then return false end

    if modes.state() ~= modes.ACTIVE then return false end

    local who = ""
    if type(winner) == "table" and winner.team ~= nil then
        who = "t:" .. tostring(winner.team)
    elseif type(winner) == "table" and winner.names ~= nil then

        local found = {}
        for _, name in ipairs(winner.names) do
            local at, several = nil, false
            for i = 0, MAX_PLAYERS - 1 do
                local np = gNetworkPlayers[i]
                if np ~= nil and np.connected and np.name == name then
                    if at ~= nil then several = true end
                    at = i
                end
            end
            if at ~= nil and not several then
                table.insert(found, tostring(gNetworkPlayers[at].globalIndex))
            end
        end
        who = table.concat(found, ",")
    elseif type(winner) == "string" and winner ~= "" then

        local found, several = nil, false
        for i = 0, MAX_PLAYERS - 1 do
            local np = gNetworkPlayers[i]
            if np ~= nil and np.connected and np.name == winner then
                if found ~= nil then several = true end
                found = i
            end
        end
        if found ~= nil and not several then
            who = tostring(gNetworkPlayers[found].globalIndex)
        end
    end

    local wonBy = tonumber(who)
    if wonBy ~= nil then lastWinner = wonBy end

    OF.util.publish("ofGmWinner", pack_result({
        text or "", tostring(a or ""), tostring(b or ""), who,
        (why ~= nil and why.rung) or "",
        (why ~= nil and why.name) or "",
        (why ~= nil and why.figures) or "" }))

    OF.util.publish("ofGmState", modes.MOMENT)
    hostPhaseTimer = 0
    return true
end

local GRACE_FRAMES = 10

local pending = nil

local function already_claimed(name)
    for _, held in ipairs(pending.names) do
        if held == name then return true end
    end
    return false
end

function modes.claim_win(text, winner, a, b)
    if not OF.util.is_host() then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    if type(winner) ~= "string" or winner == "" then

        modes.finish(text, winner, a, b)
        return true
    end

    if pending ~= nil then
        if already_claimed(winner) then return false end
        table.insert(pending.names, winner)
        return true
    end

    pending = { text = text, names = { winner }, b = b, left = GRACE_FRAMES }
    return true
end

function modes.forget_claims()
    pending = nil
end

function modes.claim_pending()
    return pending ~= nil and #pending.names or 0
end

local function settle_claims()
    if pending == nil then return end
    if modes.state() ~= modes.ACTIVE then
        pending = nil
        return
    end
    pending.left = pending.left - 1
    if pending.left > 0 then return end

    local held = pending
    pending = nil
    if #held.names == 1 then
        modes.finish(held.text, held.names[1], held.names[1], held.b)
        return
    end
    modes.finish(held.text, { names = held.names },
        OF.util.list_of(held.names), held.b)
end

function modes.finish(text, winner, a, b)

    if OF.wireWatch then OF.wire_mark("a round ended") end

    local why = nil
    if (winner == nil or winner == "") and modes.is_draw(text) then
        local won, rung, name, figures = modes.settle_draw()
        if won ~= nil then
            winner = won
            why = { rung = rung, name = name, figures = figures }
        end
    end

    if not end_round(text, winner, a, b, why) then return end

    modes.forget_claims()

    OF.stats.record_round(winner)

    if OF.util.asks(OF.standings, "record") then OF.standings.record() end
end

function modes.abandon(text, a, b)

    return end_round(text, nil, a, b)
end

function modes.winner_line()
    local packed = gGlobalSyncTable.ofGmWinner or ""
    if packed == "" then return "" end

    local parts = {}
    for piece in string.gmatch(packed .. WINNER_FIELD, "([^" .. WINNER_FIELD .. "]*)"
        .. WINNER_FIELD) do
        table.insert(parts, piece)
    end
    if parts[1] == nil or parts[1] == "" then return "" end

    return OF.lang.fill(parts[1],
        (parts[2] ~= "" and parts[2] or nil),
        (parts[3] ~= "" and parts[3] or nil))
end

function modes.ending_now()
    local packed = gGlobalSyncTable.ofGmWinner or ""
    if packed == "" then return nil end
    return modes.ending_of(packed:match("^([^" .. WINNER_FIELD .. "]*)"))
end

function modes.decided_line()
    local packed = gGlobalSyncTable.ofGmWinner or ""
    if packed == "" then return "" end

    local parts = {}
    for piece in string.gmatch(packed .. WINNER_FIELD, "([^" .. WINNER_FIELD .. "]*)"
        .. WINNER_FIELD) do
        table.insert(parts, piece)
    end
    local rung, name, figures = parts[5], parts[6], parts[7]
    if rung == nil or rung == "" or name == nil or name == "" then return "" end

    local on = OF.lang.t(modes.rung_name(rung))
    if on == "" then return "" end
    if figures ~= nil and figures ~= "" then on = on .. " (" .. figures .. ")" end
    return OF.lang.fill("@ takes it on @", name, on)
end

function modes.i_won()
    local packed = gGlobalSyncTable.ofGmWinner or ""
    if packed == "" then return false end

    local parts = {}
    for piece in string.gmatch(packed .. WINNER_FIELD, "([^" .. WINNER_FIELD .. "]*)"
        .. WINNER_FIELD) do
        table.insert(parts, piece)
    end
    local who = parts[4]
    if who == nil or who == "" then return false end

    local side = who:match("^t:(.+)$")
    if side ~= nil then
        if not OF.util.asks(OF.teams, "of") then return false end
        return OF.teams.of(0) == side
    end

    local np = gNetworkPlayers[0]
    if np == nil then return false end

    local mine = tostring(np.globalIndex)
    for piece in (who .. ","):gmatch("([^,]*),") do
        if piece == mine then return true end
    end
    return false
end

function modes.winners()
    local packed = gGlobalSyncTable.ofGmWinner or ""
    if packed == "" then return {} end

    local parts = {}
    for piece in string.gmatch(packed .. WINNER_FIELD, "([^" .. WINNER_FIELD .. "]*)"
        .. WINNER_FIELD) do
        table.insert(parts, piece)
    end
    local who = parts[4]
    if who == nil or who == "" or who:match("^t:") then return {} end

    local list = {}
    for piece in (who .. ","):gmatch("([^,]*),") do
        local globalIndex = tonumber(piece)
        if globalIndex ~= nil then
            local localIndex = OF.util.local_from_global(globalIndex)

            if localIndex ~= nil then table.insert(list, localIndex) end
        end
    end
    return list
end

function modes.winning_side()
    local packed = gGlobalSyncTable.ofGmWinner or ""
    if packed == "" then return nil end

    local parts = {}
    for piece in string.gmatch(packed .. WINNER_FIELD, "([^" .. WINNER_FIELD .. "]*)"
        .. WINNER_FIELD) do
        table.insert(parts, piece)
    end
    local who = parts[4]
    if who == nil or who == "" then return nil end
    return who:match("^t:(.+)$")
end

function modes.team_winner(team)
    if team == nil or team == false then return nil end
    return { team = team.key }
end

function modes.round_mods()
    if modes.state() == modes.OFF then return "" end
    return modes.roundMods or ""
end

function modes.stop(quiet, askerLocal)
    if OF.wireWatch then OF.wire_mark("a round was stopped") end

    if not OF.perms.can("end_round") then return false end
    if modes.state() == modes.OFF then return false end

    if not OF.util.is_host() then
        return ask_host("stop", nil)
    end

    OF.util.publish("ofGmState", modes.OFF)
    OF.util.publish("ofGmCount", nil)
    OF.util.publish("ofGmKey", "")

    OF.util.publish("ofGmPlace", nil)

    OF.util.publish(modes.OPTS_KEY, nil)

    OF.util.publish("ofGmSecs", nil)

    modes.hand_the_room_back()

    if OF.arena ~= nil then OF.arena.close() end

    if OF.teams ~= nil then OF.teams.clear_all() end

    if OF.util.asks(OF.lockdown, "lift") then OF.lockdown.lift() end

    for i = 0, MAX_PLAYERS - 1 do
        modes.set_role(i, "")
    end

    if quiet then return true end

    if modes.nonstop() then
        OF.util.publish(modes.NONSTOP_KEY, false)
        OF.util.publish(modes.NONSTOP_NEXT, nil)
    end

    OF.notify.send_all("The round was stopped", "warn")

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal, OF.lang.t("stopped the round"))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.t("stopped the round"))
    return true
end

local NONSTOP_FRAMES = 5 * 30

local NONSTOP_RETRY_FRAMES = 5 * 30

modes.NONSTOP_KEY = "ofGmNonstop"
modes.NONSTOP_NEXT = "ofGmNextIn"
modes.NONSTOP_COMMAND = "nonstop"
modes.ROTATION = {}

local rotateAt = {}

function modes.rotation_for(key)
    local mode = modes.BY_KEY[key]
    if mode == nil then return {} end
    if mode.startPlace ~= nil or mode.wholeGame == true or mode.noArena == true then
        return {}
    end

    local allowed = {}
    for _, room in ipairs(modes.rooms_for(key)) do allowed[room.key] = true end

    local list = {}
    local seen = {}
    local function take(placeKey)
        if type(placeKey) ~= "string" or seen[placeKey] then return end
        if not allowed[placeKey] then return end
        if not OF.util.asks(OF.arena, "find") then return end
        if OF.arena.find(placeKey) == nil then return end
        seen[placeKey] = true
        table.insert(list, placeKey)
    end

    local hand = modes.ROTATION[key]
    if type(hand) == "table" then
        for _, placeKey in ipairs(hand) do take(placeKey) end
        if #list > 0 then return list end
    end

    if OF.util.asks(OF.arena, "for_mode") then
        for _, placeKey in ipairs(OF.arena.for_mode(key)) do take(placeKey) end
    end

    if #list == 0 and OF.arena ~= nil then
        for _, place in ipairs(OF.arena.PLACES or {}) do take(place.key) end
    end
    return list
end

function modes.next_place(key)
    local list = modes.rotation_for(key)
    if #list == 0 then return nil end
    local at = (rotateAt[key] or 0) + 1
    if at > #list then at = 1 end
    rotateAt[key] = at
    return list[at]
end

local rotateLevelAt = {}

function modes.next_level(key)
    local mode = modes.BY_KEY[key]
    if mode == nil or modes.maps_of(mode) ~= "surveyed" then return nil end
    local list = modes.surveyed_levels(key)
    if #list == 0 then return nil end
    local at = (rotateLevelAt[key] or 0) + 1
    if at > #list then at = 1 end
    rotateLevelAt[key] = at
    return list[at]
end

function modes.nonstop()
    return gGlobalSyncTable[modes.NONSTOP_KEY] == true
end

function modes.nonstop_seconds()
    local left = gGlobalSyncTable[modes.NONSTOP_NEXT]
    if type(left) ~= "number" then return nil end
    return left
end

local nonstopKey = nil
local nonstopFrames = 0
local nonstopWaiting = false

function modes.nonstop_mode()
    return nonstopKey
end

function modes.set_nonstop(on, askerLocal)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then
        if not ask_host("nonstop", on == true and "on" or "off") then
            return false, "No host to ask yet - try again in a second."
        end
        return true, "asked"
    end

    if on ~= true then
        OF.util.publish(modes.NONSTOP_KEY, false)
        OF.util.publish(modes.NONSTOP_NEXT, nil)
        nonstopFrames = 0
        nonstopWaiting = false
        OF.notify.send_all("The rounds stop rotating", "warn", 5)
        if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
            OF.notify.credit_named(askerLocal,
                OF.lang.t("stopped the rotation"))
        end
        OF.actionlog.by_hand(OF.util.presser(askerLocal),
            OF.lang.t("stopped the rotation"))
        return true
    end

    local mode = modes.current()
    if mode == nil then
        return false, "Start a round first - this keeps the one you are playing going."
    end
    nonstopKey = mode.key
    nonstopFrames = 0
    nonstopWaiting = false
    OF.util.publish(modes.NONSTOP_KEY, true)
    OF.notify.send_all("@ keeps going - a new map after every round", "good", 6,
        OF.lang.t(mode.name))
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("kept @ rotating", OF.lang.t(mode.name)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("set the rounds to keep rotating: @",
            OF.lang.t(mode.name)))
    return true
end

function modes.nonstop_note_mode()
    if not OF.util.is_host() then return end
    local mode = modes.current()
    if mode ~= nil then nonstopKey = mode.key end
end

local function nonstop_start()
    local mode = modes.BY_KEY[nonstopKey or ""]
    if mode == nil then return false end

    if not modes.can_start_here(mode) then return false end

    local wasArena, wasLevel = modes.arenaChoice, modes.levelChoice
    local placeKey = modes.next_place(mode.key)
    if placeKey ~= nil then
        modes.arenaChoice = placeKey
        modes.levelChoice = nil
    else

        local entry = modes.next_level(mode.key)
        if entry ~= nil then
            modes.levelChoice = {
                level = entry.level, area = entry.area or 1,
                act = entry.act or 1, name = entry.name or "somewhere",
            }
            modes.arenaChoice = nil
        end
    end

    local went = modes.start(mode.key) == true
    modes.arenaChoice, modes.levelChoice = wasArena, wasLevel
    return went
end

local function nonstop_update()
    if not OF.util.is_host() then return end

    if not modes.nonstop() then
        if gGlobalSyncTable[modes.NONSTOP_NEXT] ~= nil then
            OF.util.publish(modes.NONSTOP_NEXT, nil)
        end
        nonstopFrames = 0
        nonstopWaiting = false
        return
    end

    if modes.state() ~= modes.OFF then
        modes.nonstop_note_mode()
        nonstopFrames = 0
        nonstopWaiting = false
        if gGlobalSyncTable[modes.NONSTOP_NEXT] ~= nil then
            OF.util.publish(modes.NONSTOP_NEXT, nil)
        end
        return
    end

    nonstopFrames = nonstopFrames + 1

    local wait = nonstopWaiting and NONSTOP_RETRY_FRAMES or NONSTOP_FRAMES

    if not nonstopWaiting then
        local left = math.max(0, math.ceil((wait - nonstopFrames) / 30))
        if gGlobalSyncTable[modes.NONSTOP_NEXT] ~= left then
            OF.util.publish(modes.NONSTOP_NEXT, left)
        end
    end

    if nonstopFrames < wait then return end
    nonstopFrames = 0

    if nonstop_start() then
        nonstopWaiting = false
        return
    end

    if not nonstopWaiting then
        nonstopWaiting = true
        OF.util.publish(modes.NONSTOP_NEXT, nil)
        local mode = modes.BY_KEY[nonstopKey or ""]
        OF.notify.send_all("Waiting for enough players for @", "info", 6,
            mode ~= nil and OF.lang.t(mode.name) or OF.lang.t("the next round"))
    end
end

local function host_update()
    if not OF.util.is_host() then return end
    local state = modes.state()
    if state == modes.OFF then return end

    local mode = modes.current()
    if mode == nil then return end

    hostPhaseTimer = hostPhaseTimer + 1

    modes.expire_seats()

    if state == modes.COUNTDOWN then

        local held = false
        if hostPhaseTimer >= COUNTDOWN_FRAMES then
            local waiting = modes.still_loading_for(mode)
            if waiting > 0 then
                if goHoldFrames < GO_HOLD_MAX then
                    goHoldFrames = goHoldFrames + 1
                    held = true
                elseif goHoldFrames == GO_HOLD_MAX then

                    goHoldFrames = GO_HOLD_MAX + 1
                    OF.notify.send_all(
                        "Somebody is still loading - starting anyway.",
                        "warn", 5)
                end
            end
        end

        local seconds = math.max(1,
            math.ceil((COUNTDOWN_FRAMES - hostPhaseTimer) / 30))
        if held then seconds = 0 end
        if gGlobalSyncTable.ofGmCount ~= seconds then
            OF.util.publish("ofGmCount", seconds)
        end

        if not held and hostPhaseTimer >= COUNTDOWN_FRAMES then

            local mode = modes.current()
            if mode ~= nil and mode.pin ~= nil then
                OF.util.report(pcall(mode.pin))
            end

            local np = gNetworkPlayers[0]
            if np ~= nil and modes.publishes_place(mode) then
                modes.publish_place(np.currLevelNum, np.currAreaIndex,
                    np.currActNum)
            end

            OF.util.publish("ofGmState", modes.ACTIVE)
            OF.util.publish("ofGmElapsed", 0)
            OF.util.publish("ofGmCount", nil)
            hostPhaseTimer = 0

            goHoldFrames = 0
        end

    elseif state == modes.ACTIVE then

        if hostPhaseTimer % 30 == 0 then
            local second = math.floor(hostPhaseTimer / 30)
            OF.util.publish("ofGmElapsed", second)

            sample_standing(second)
        end

        if repinIn ~= nil and repinIn > 0 then
            repinIn = repinIn - 1
            if repinIn == 0 then
                repinIn = nil
                if mode.pin ~= nil then OF.util.report(pcall(mode.pin)) end
                local np = gNetworkPlayers[0]
                if np ~= nil and modes.publishes_place(mode) then
                    modes.publish_place(np.currLevelNum, np.currAreaIndex,
                        np.currActNum)
                end
            end
        end

        local playing = modes.still_here()
        if #playing < (mode.minPlayers or 2) then
            if #playing == 1 then
                modes.abandon(modes.FORFEIT, playing[1].np.name)
            else
                modes.abandon(modes.NO_CONTEST)
            end
            return
        end

        if mode.host_update ~= nil then mode.host_update() end

        settle_claims()

        if mode.still_winnable ~= nil then
            local ok, answer = pcall(mode.still_winnable)

            if not OF.util.report(ok, answer) then answer = true end
            if answer == false then
                nowinFrames = nowinFrames + 1
            else
                nowinFrames = 0
            end
        else
            nowinFrames = 0
        end

        if nowinFrames >= NOWIN_FRAMES then
            nowinFrames = 0

            OF.notify.send_all("Nothing left to win - settling it now.",
                "warn", 5)

            if mode.on_timeout ~= nil then
                mode.on_timeout()
            else
                modes.finish(modes.TIME_UP)
            end
            return
        end

        local stillIn = 0
        for _, entry in ipairs(playing) do
            if not modes.is_out(entry.localIndex) then stillIn = stillIn + 1 end
        end

        if stillIn == 0 then
            settleFrames = settleFrames + 1
        else
            settleFrames = 0
        end

        if settleFrames >= SETTLE_FRAMES then
            settleFrames = 0
            local board = modes.survival_board()
            local first = board[1]
            if first ~= nil and type(first.name) == "string"
                and first.name ~= "" then
                modes.finish(modes.LAST_OUT, first.name, first.name)
            else

                modes.abandon(modes.NO_CONTEST)
            end
            return
        end

        local limit = gGlobalSyncTable.ofGmLimit or 0
        if limit > 0 and hostPhaseTimer >= limit * 30 then

            if mode.symmetric and mode.overtime ~= nil and mode.overtime() then
                modes.overtimeFrames = (modes.overtimeFrames or 0) + 1
                if modes.overtimeFrames < OVERTIME_MAX then

                    if modes.overtimeFrames == 1 then
                        OF.notify.send_all("Overtime!", "warn", 4)
                    end
                    return
                end
            end
            modes.overtimeFrames = 0

            if mode.on_timeout ~= nil then
                mode.on_timeout()
            else

                modes.finish(modes.TIME_UP)
            end
        end

    elseif state == modes.MOMENT then
        if hostPhaseTimer >= MOMENT_FRAMES then
            OF.util.publish("ofGmState", modes.RESULTS)
            hostPhaseTimer = 0
        end

    elseif state == modes.RESULTS then
        if hostPhaseTimer >= RESULTS_FRAMES then

            modes.stop(true)
        end
    end
end

local STILL_RADIUS = 300

local STILL_SHOWN  = 50 * 30

modes.CAMPING_ACTIONS = {}
do
    local list = { ACT_IN_CANNON, ACT_VERTICAL_WIND, ACT_BUBBLED,
                   ACT_START_SLEEPING, ACT_SLEEPING }
    for i = 1, 5 do
        if list[i] ~= nil then modes.CAMPING_ACTIONS[list[i]] = true end
    end
end

local CAMPING_FREEZE = 2

local stillFrames = 0
local stillAt = nil
local stillSaid = 0

local function stop_showing()
    stillFrames = 0
    stillAt = nil
    stillSaid = 0
    local row = gPlayerSyncTable[0]
    if row ~= nil and row.ofStill ~= nil then
        OF.util.publish_row(0, "ofStill", nil)
    end
end

modes.forget_stillness = stop_showing

function modes.still_frames()
    return stillFrames
end

function modes.is_showing(localIndex)
    local row = gPlayerSyncTable[localIndex or 0]
    return row ~= nil and row.ofStill == true
end

function modes.is_camping(m)
    m = m or gMarioStates[0]
    if m == nil then return false end
    if (m.freeze or 0) >= CAMPING_FREEZE then return true end
    return modes.CAMPING_ACTIONS[m.action or 0] == true
end

local function stall_update()
    local mode = modes.current()

    if mode == nil or mode.stallRole == nil
        or modes.my_role() ~= mode.stallRole then
        stop_showing()
        return
    end

    local here = modes.here_place(0)
    if here == nil then return end

    local sameRoom = modes.in_place_room(stillAt)
    local gone = modes.distance_to_place(stillAt)
    if not sameRoom
        or ((gone == nil or gone > STILL_RADIUS) and not modes.is_camping()) then

        stop_showing()
        stillAt = here
        return
    end

    stillFrames = stillFrames + 1

    if stillFrames >= STILL_SHOWN and stillSaid < 3 then
        stillSaid = 3
        OF.util.publish_row(0, "ofStill", true)
    end
end

local VOID_FRAMES = 3 * 30

modes.VOID_FRAMES = VOID_FRAMES

local OUTSIDE_ACTION = "gmoutside"
local voidFrames = 0
local voidTold = false

modes.outsideSeen = modes.outsideSeen or 0

local function forget_void()
    voidFrames = 0
    voidTold = false
end

modes.forget_void = forget_void

function modes.void_frames()
    return voidFrames
end

function modes.outside_seen()
    return modes.outsideSeen
end

function modes.forget_outside_seen()
    modes.outsideSeen = 0
end

local function nothing_underneath()
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return false end
    local under = OF.util.optional("find_floor_height", nil,
        m.pos.x, m.pos.y, m.pos.z)
    if type(under) ~= "number" then return false end

    local void = -11000

    if OF.is_object(gLevelValues)
        and type(gLevelValues.floorLowerLimit) == "number" then
        void = gLevelValues.floorLowerLimit
    end
    return under <= void
end

local function void_update()
    local mode = modes.current()

    if mode == nil or mode.stallRole == nil
        or modes.my_role() ~= mode.stallRole then
        forget_void()
        return
    end

    if not nothing_underneath() then
        forget_void()
        return
    end

    voidFrames = voidFrames + 1
    if voidFrames < VOID_FRAMES then return end

    if voidTold then return end
    voidTold = true
    OF.util.report(OF.net.host_does(OUTSIDE_ACTION))
end

local netRegistered = false

local function register_with_of_net()
    if netRegistered then return end
    if OF.net == nil then return end
    netRegistered = true

    if OF.util.asks(OF.net, "on_arrival") then
        OF.net.on_arrival("round clock origin", modes.settle_round_origin)
    end

    if not OF.util.asks(OF.net, "register_action") then return end

    OF.net.register_action(OUTSIDE_ACTION, "round_move", function(fromLocal)

        if not OF.util.is_host() then return false, "Only the host." end
        local np = gNetworkPlayers[fromLocal]
        if np == nil then return false, "Nobody is there." end
        modes.outsideSeen = modes.outsideSeen + 1

        OF.notify.show("@ is outside the level - nobody can reach them",
            "warn", 8, OF.util.plain(np.name))
        return true
    end)
end

local lensHeld = false

function modes.lens_out()
    return lensHeld
end

local function drop_lens()
    if not lensHeld then return end
    lensHeld = false
    if OF.util.asks(OF.modifiers, "lens_fov") then OF.modifiers.lens_fov(false) end
end

modes.drop_lens = drop_lens

local function lens_update(m)
    local mode = modes.current()
    if mode == nil or mode.lensRole == nil
        or modes.state() ~= modes.ACTIVE
        or modes.my_role() ~= mode.lensRole
        or not OF.util.can_play(0) then
        drop_lens()
        return
    end

    if OF.util.menu_has_screen() then
        drop_lens()
        return
    end
    if OF.util.asks(OF.forge, "open") and OF.forge.open then
        drop_lens()
        return
    end

    local down = OF.util.has_flag(m.controller ~= nil and m.controller.buttonDown or 0,
        L_TRIG)
    if not down then
        drop_lens()
        return
    end

    if not lensHeld then
        lensHeld = true

        if OF.util.asks(OF.modifiers, "lens_fov") then OF.modifiers.lens_fov(true) end
    end

    OF.input.hold(m)
end

modes.lens_update = lens_update

local function local_update()
    if modes.state() ~= modes.ACTIVE then return end

    local role = modes.my_role()
    if role == "" or role == modes.WAITING then return end

    if not OF.util.can_play(0) then return end

    local mode = modes.current()
    if mode ~= nil and mode.update ~= nil then mode.update() end
    stall_update()
    void_update()
end

local waitingGhost = false

do
    local sawTheRound = false

    function modes.in_this_round()
        return sawTheRound
    end

    function modes.note_round_seen(seen)
        sawTheRound = seen == true
    end

    function modes.left_out_of_this_round(localIndex)
        if localIndex == nil then return false end
        if not modes.is_running() then return false end

        if not modes.refuses_latecomers() then return false end
        if localIndex == 0 then return not sawTheRound end
        return modes.role(localIndex) == modes.WAITING
    end
end

local function sitting_rounds_out()
    return OF.util.asks(OF.speedrun, "is_excluded")
        and OF.speedrun.is_excluded(0)
end

local function on_before_mario_update(m)
    if m.playerIndex ~= 0 then return end

    modes.settle_health(m)

    if not modes.is_running() then return end

    lens_update(m)

    modes.rejoin_update()

    modes.remember_standing(m)

    modes.settle_muster(m)
    modes.settle_opening(m)

    local mode = modes.current()

    if modes.state() == modes.COUNTDOWN
        and OF.util.can_play(0)
        and not (mode ~= nil and mode.roamOnCountdown) then
        OF.input.hold(m)
    end

    local role = modes.my_role()
    if modes.state() == modes.ACTIVE
        and (role == "" or role == modes.WAITING)
        and not sitting_rounds_out()
        and not modes.left_out_of_this_round(0) then
        waitingGhost = true
        modes.set_ghost(true)
    elseif waitingGhost then
        waitingGhost = false
        modes.set_ghost(false)
    end

    if mode ~= nil and mode.noDozing == true and modes.state() == modes.ACTIVE
        and (m.action == ACT_START_SLEEPING or m.action == ACT_SLEEPING
             or m.action == ACT_WAKING_UP) then
        set_mario_action(m, ACT_IDLE, 0)
    end

    modes.settle_ghost()

    if mode ~= nil and mode.before_mario_update ~= nil then mode.before_mario_update(m) end
end

local lastMode = nil

local roomCameFrom = nil

modes.MY_ROUND_KEYS = { "ofScore", "ofGmTime", "ofHpGrab", "ofSplits",

                        "ofCrownTo", "ofCrownGave", "ofCrownDied",

                        "ofSpotsClaim",

                        "ofMhDied",

                        "ofRollAim" }

local function clear_my_round_row()
    for _, key in ipairs(modes.MY_ROUND_KEYS) do
        OF.util.publish_row(0, key, OF.util.PLAYER_ROW_DEFAULTS[key])
    end
end

modes.clear_my_round_row = clear_my_round_row

local GO_FRAMES = 30
modes.goFrames = 0

local PLACE_KEY = "ofGmPlace"
local function pack_place(level, area, act, also)
    local names = {}
    for _, other in ipairs(also or {}) do
        table.insert(names, tostring(other))
    end
    return table.concat({
        tostring(level), tostring(area or 1), tostring(act or 1),
        table.concat(names, ","),
    }, "|")
end

function modes.round_place()
    local packed = gGlobalSyncTable[PLACE_KEY]
    if type(packed) ~= "string" or packed == "" then return nil end
    local fields = {}
    for field in string.gmatch(packed .. "|", "([^|]*)|") do
        table.insert(fields, field)
    end
    local level = tonumber(fields[1])
    if level == nil then return nil end
    local also = {}
    for name in string.gmatch(fields[4] or "", "[^,]+") do
        local other = tonumber(name)
        if other ~= nil then table.insert(also, other) end
    end
    return {
        level = level,
        area = tonumber(fields[2]) or 1,
        act = tonumber(fields[3]) or 1,
        also = also,
    }
end

function modes.publish_place(level, area, act, also)
    if not OF.util.is_host() then return false end
    if level == nil then return false end
    OF.util.publish(PLACE_KEY, pack_place(level, area, act, also))
    return modes.hold_here(level, area, act, also)
end

function modes.publishes_place(mode)
    if mode == nil then return true end
    return not (mode.wholeGame == true or mode.holdsPerRunner == true)
end

function modes.adopt_place()
    local place = modes.round_place()
    if place == nil then return false end
    return modes.hold_here(place.level, place.area, place.act, place.also)
end

local function hand_the_round_back(alsoTheRoom)
    local mode = lastMode
    lastMode = nil

    if mode ~= nil and mode.cleanup ~= nil then
        OF.util.report(pcall(mode.cleanup))
    end

    if OF.util.asks(OF.net, "forget_pending_warp") then
        OF.net.forget_pending_warp()
    end

    if not alsoTheRoom then return end

    local cameFrom = roomCameFrom
    roomCameFrom = nil
    if cameFrom ~= nil and mode ~= nil and modes.publishes_place(mode)
        and not modes.owns_its_place(mode) then
        local np = gNetworkPlayers[0]
        if np ~= nil and np.currLevelNum ~= cameFrom.level then
            OF.net.warp_local(cameFrom.level, cameFrom.area, cameFrom.act)
        end
    end

    if OF.util.asks(OF.lockdown, "settle_rules") then
        OF.lockdown.settle_rules()
    end

    if OF.util.asks(OF.modifiers, "resync") then OF.modifiers.resync() end
end

function modes.settle_ending()
    local state = modes.state()

    if lastMode ~= nil then
        if state == modes.OFF then
            hand_the_round_back(true)
        else
            local now = modes.current()
            if now ~= nil and now ~= lastMode then
                hand_the_round_back(false)
                lastMode = now
            end
        end
    elseif modes.is_running() then

        lastMode = modes.current()
    end

    if state ~= modes.ACTIVE and modes.roundLevel ~= nil then
        modes.forget_hold()
    end
end

local function on_state_changed(tag, oldVal, newVal)

    if newVal == oldVal then return end

    local mode = modes.current()
    if mode ~= nil and newVal ~= modes.OFF then

        if lastMode ~= nil and lastMode ~= mode then
            hand_the_round_back(false)
        end
        lastMode = mode
    end

    modes.reset_countdown_pulse()

    modes.forget_the_hold()

    modes.forget_stillness()

    modes.forget_void()

    if newVal == modes.COUNTDOWN or newVal == modes.OFF then
        clear_my_round_row()

        modes.liveAt = nil

        modes.forget_seats()
    end

    if newVal == modes.COUNTDOWN then modes.note_round_seen(true) end
    if newVal == modes.OFF then modes.note_round_seen(false) end

    modes.forget_still_counts()

    if newVal == modes.COUNTDOWN then
        modes.forget_health_claim()

        local here = gNetworkPlayers[0]
        if here ~= nil and here.currLevelNum ~= nil and here.currLevelNum ~= 0 then
            roomCameFrom = { level = here.currLevelNum,
                             area = here.currAreaIndex or 1,
                             act = here.currActNum or 1 }
        else
            roomCameFrom = nil
        end

        local opening = modes.opening()
        if opening ~= nil and opening.heal then modes.give_full_health() end

        modes.forget_muster()
    end

    if newVal == modes.ACTIVE then

        modes.liveAt = clock_elapsed()

        local live = modes.current()
        if not modes.adopt_place() and modes.publishes_place(live) then
            local np = gNetworkPlayers[0]
            if np ~= nil then
                modes.hold_here(np.currLevelNum, np.currAreaIndex, np.currActNum)
            end
        end

        OF.sounds.play(OF.sounds.GO)

        modes.goFrames = GO_FRAMES

        if OF.util.asks(OF.music, "fanfare") then OF.music.fanfare("start") end
        if mode ~= nil and mode.on_start ~= nil then mode.on_start() end
    elseif newVal == modes.RESULTS then

        play_transition(WARP_TRANSITION_FADE_FROM_STAR, 24, 0, 0, 0)

        local winner = modes.winner_line()
        if winner ~= "" then

            if OF.util.asks(OF.chatlog, "add_notice") then
                OF.chatlog.add_notice(winner)
            end

            local decided = modes.decided_line()
            if decided ~= "" and OF.util.asks(OF.chatlog, "add_notice") then
                OF.chatlog.add_notice(decided)
            end

            if modes.i_won() then
                local side = modes.winning_side()
                local colour = nil
                if side ~= nil and OF.util.asks(OF.teams, "find") then
                    local team = OF.teams.find(side)
                    if team ~= nil then
                        colour = { r = team.r, g = team.g, b = team.b }
                    end
                end
                if side ~= nil and OF.util.asks(OF.celebrate, "team_win") then
                    OF.celebrate.team_win(colour)
                else
                    OF.celebrate.win()
                end
            end

            if OF.util.asks(OF.celebrate, "star_over") then
                for _, localIndex in ipairs(modes.winners()) do
                    OF.celebrate.star_over(localIndex)
                end
            end
        end

        local mode = modes.current()
        if mode ~= nil and mode.print_board ~= nil then mode.print_board() end
    elseif newVal == modes.OFF then
        hand_the_round_back(true)
    end

    if newVal ~= modes.ACTIVE then
        modes.set_ghost(false)

        waitingGhost = false

        modes.forget_ghost()

        drop_lens()

        modes.drop_tokens()

        modes.forget_hold()
    end
end

hook_on_sync_table_change(gGlobalSyncTable, "ofGmState", 0,
    function(tag, oldVal, newVal)
        if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofGmState") then
            return
        end
        on_state_changed(tag, oldVal, newVal)
    end)

hook_on_sync_table_change(gGlobalSyncTable, PLACE_KEY, 0,
    function(tag, oldVal, newVal)
        if OF.util.asks(OF.guard, "repair") and OF.guard.repair(PLACE_KEY) then
            return
        end

        if newVal == oldVal then return end
        if newVal == nil or newVal == "" then return end
        if not modes.is_running() then return end
        modes.adopt_place()
    end)

local function settle_round_origin()
    if not modes.is_running() then return false end

    local elapsed = gGlobalSyncTable.ofGmElapsed
    if type(elapsed) ~= "number" then return false end
    if elapsed < 0 then return false end

    modes.liveAt = clock_elapsed() - elapsed
    return true
end

modes.settle_round_origin = settle_round_origin

local ghosting = false

function modes.is_ghost()
    return ghosting
end

function modes.set_ghost(on)
    if gMarioStates[0] == nil then return false end

    if on then
        ghosting = true
        return OF.util.intangible("ghost", true)
    end

    if not ghosting then return false end
    ghosting = false
    OF.util.intangible("ghost", false)
    return true
end

hook_event(HOOK_ALLOW_HAZARD_SURFACE, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not modes.is_running() then return end
    if not modes.is_ghost() then return end
    return false
end)

local FULL_HEALTH = 0x880

local ONE_WEDGE = 0x100

local HEALTH_CLAIM_FRAMES = 300

local healthOwed = 0

function modes.give_full_health()
    healthOwed = HEALTH_CLAIM_FRAMES
    return true
end

function modes.owes_health()
    return healthOwed > 0
end

function modes.forget_health_claim()
    healthOwed = 0
end

function modes.settle_health(m)
    if healthOwed <= 0 then return end
    healthOwed = healthOwed - 1
    if m == nil then return end

    local health = m.health or 0
    if health < ONE_WEDGE then return end

    if health >= FULL_HEALTH and (m.hurtCounter or 0) == 0 then
        healthOwed = 0
        return
    end

    m.health = FULL_HEALTH
    m.hurtCounter = 0
    m.healCounter = 0
end

hook_event(HOOK_ON_DEATH, function(m)
    if m == nil or m.playerIndex ~= 0 then return end
    if not modes.is_running() then return end

    modes.mark_died_inside()

    if not OF.util.can_play(0) then return end
    modes.give_full_health()
end)

modes.OPENING = {
    bank = { heal = true, gather = false, grace = false, safe = true,
        why = "Collection. The coins are already spread over the room and the "
           .. "bank is pinned where the round lands, so nothing is decided in "
           .. "the first three seconds - and dying is only a walk back." },
    bossrush = { heal = true, gather = false, grace = false, safe = false,
        healAt = true,
        why = "Every runner walks into their own copy of their own boss arena, "
           .. "so there is nobody to gather to and nobody to be shoved by. The "
           .. "meter is handed back after each boss instead." },
    bounty = { heal = true, gather = true, grace = true, safe = true,
        why = "A brawl in one room that pins no geometry. A knockdown is the "
           .. "whole score, so the opening scrum must not pay the first swing "
           .. "- and nobody dies here by design." },
    coinrush = { heal = true, gather = false, grace = false, safe = true,
        why = "Collection. The rain falls over the whole room, so there is no "
           .. "start line to share, and nobody is carrying anything worth "
           .. "robbing in the first three seconds." },
    crown = { heal = true, gather = true, grace = true, safe = false,
        why = "The crown is dealt before GO and taken by punching whoever "
           .. "wears it, so the first wearer needs the run the mode assumes "
           .. "they get." },
    ctf = { heal = true, gather = false, grace = true, safe = false,
        sides = true,
        why = "Two sides, two bases, so the gather is two rings rather than "
           .. "one - gathering the whole room onto the host would put both "
           .. "flags in one place, which is why `gather` is false and `sides` "
           .. "is not. The grace stands, because a base rush that lands on the "
           .. "start frame is the same fault." },
    domination = { heal = true, gather = false, grace = true, safe = false,
        sides = true,
        why = "A gather onto the host would collapse the triangle onto one "
           .. "player, which is why `gather` is false. With two sides there are "
           .. "two rings instead: red opens on point one and blue on point two, "
           .. "and point three belongs to nobody because it is the one both "
           .. "have to walk to." },
    flood = { heal = true, gather = false, grace = true, safe = false,
        sides = true,
        why = "The host walked a start at the bottom of every course this is "
           .. "played in, and the round opens on it. One ring rather than two, "
           .. "because the mode has no sides and every climber shares the one "
           .. "bottom - which is the same shape Red Light, Green Light's start "
           .. "line has. Not gathered onto the host: the water starts below "
           .. "the lowest player, so a ring drawn round whoever happens to be "
           .. "hosting would take the mode's own measurement off one person's "
           .. "feet, wherever they were standing. Where nothing was walked - "
           .. "the three arenas, a round played where the lobby already "
           .. "stands - `side_place` answers nil and the opening is what it "
           .. "has always been." },
    hexagone = { heal = true, gather = false, grace = true, safe = false,
        why = "The tile stack is built above the room and everybody is dropped "
           .. "onto it; a gather would put the whole lobby on one tile and "
           .. "take the floor out from under all of them at once." },
    hexheat = { heal = true, gather = false, grace = false, safe = true,
        why = "Everybody starts in the middle of the board, which is a place "
           .. "the mode puts them rather than a ring anybody is gathered into "
           .. "- and gathering them onto the host would put the whole lobby on "
           .. "one platform with six about to sink. No grace, because nothing "
           .. "here is a swing: what takes you is a floor going away. Safe all "
           .. "round, and that is the point - dying is not how this round ends "
           .. "anybody, falling is, and a death on the way down would take the "
           .. "fall away from the thing it belongs to." },
    hideseek = { heal = true, gather = false, grace = false, safe = false,
        why = "Hiding is the mode and a gather is a line-up. A catch is a "
           .. "distance rather than a swing, so a grace would look like "
           .. "protection and stop nothing." },
    hotpotato = { heal = true, gather = true, grace = false, safe = false,
        why = "No geometry, and a round that starts with the lobby spread over "
           .. "a level is a round of running. The pass is a distance though, "
           .. "so a grace would be a lie - the fuse is this mode's own clock." },
    koth = { heal = true, gather = true, grace = true, safe = false,
        why = "Reported from play: this mode and Musical Spots did not gather "
           .. "at all - \"koth und musical spots gathern nicht richtig bzw. "
           .. "garnicht\". The row that refused it said a gather onto the host "
           .. "would draw the circle round one player, and that reason was "
           .. "written when there was no gather to reason about: with one, the "
           .. "centre of mass IS the ring's centre and every player is the same "
           .. "260 units from it, which is a fairer opening than the scatter it "
           .. "replaces rather than a worse one. A level somebody surveyed keeps "
           .. "its own hill either way (`gamemodes.surveyed`), so there the ring "
           .. "is only a shared start line." },
    laststanding = { heal = true, gather = true, grace = true, safe = false,
        why = "Three lives, fists on, no geometry at all: punched off a ledge "
           .. "on the start frame is a third of a round for nothing. Never "
           .. "safe - losing lives is the mode." },
    line = { heal = true, gather = false, grace = false, safe = false,
        sides = true,
        why = "A run needs a start line everybody shares, and gathering onto "
           .. "the *host* would hand them the finish - which is why `gather` is "
           .. "false and stays false. `sides` here is one ring rather than two: "
           .. "the mode has no sides, so every runner shares the one place the "
           .. "host walked to. Nobody can touch anybody in it either: the light "
           .. "is the whole hazard." },
    logroll = { heal = true, gather = false, grace = false, safe = true,
        why = "The mode sets everybody down itself - fifteen along the crest in "
           .. "one row and the sixteenth on his podium - so a ring round the "
           .. "host would be a place the round takes away again on the frame "
           .. "after it, and this is one of the modes that measures its own "
           .. "geometry off where the lobby is standing. No grace, because "
           .. "nothing here is a swing: the round writes interactions to nought "
           .. "and what takes you is a surface turning under your feet. Safe all "
           .. "round for Hexagon Heat's reason - falling is how this round ends "
           .. "anybody, and a death on the way down would take the fall away "
           .. "from the thing it belongs to." },
    meltdown = { heal = true, gather = true, grace = true, safe = true,
        why = "A time trial, so everybody has to start from the same place - "
           .. "the gather is the start line, on the point the host walked. "
           .. "Grace, because the pile is gathered into whatever fighting rule "
           .. "the lobby already had on and a knockdown on the start frame is "
           .. "ground lost in a run measured on a clock. Safe, because the "
           .. "metal never runs out and the lava throws rather than burns, so "
           .. "a held meter takes nothing away from a round nobody can be put "
           .. "out of - and a race decided by a hazard is not a race." },
    manhunt = { heal = true, gather = false, grace = false, safe = false,
        why = "The runner is meant to have distance the moment they can move, "
           .. "and the hunters are already held for ten seconds - which is a "
           .. "grace, and a longer one than this." },
    murder = { heal = true, gather = false, grace = false, safe = false,
        why = "A line-up would put the murderer within reach of the lobby at "
           .. "nought seconds, and the kill is a distance rather than a swing, "
           .. "so the grace could not stop it. The one mode where both would "
           .. "be worse than nothing." },
    secretrun = { heal = true, gather = false, grace = false, safe = false,
        healAt = true,
        why = "Five secret courses, one runner each, own copy of each: nobody "
           .. "to gather to and nobody to be shoved by. A course cleared hands "
           .. "the meter back instead." },
    shellrace = { heal = true, gather = true, grace = false, safe = true,
        why = "A race, so everybody has to start from the same place - and the "
           .. "gather is the start line, on the point the host walked. No "
           .. "grace, because nobody can touch anybody: the fighting rule is "
           .. "never borrowed here. Safe, because the ride is immune to lava "
           .. "and water anyway and a race decided by a hazard is not a "
           .. "race." },
    simon = { heal = true, gather = true, grace = true, safe = false,
        why = "Every call is judged against the whole lobby at once, so the "
           .. "lobby has to start the call from one place - the call that says "
           .. "get away from everybody is a different instruction if you "
           .. "already are." },
    spots = { heal = true, gather = true, grace = true, safe = false,
        why = "The other half of the same report. The circles are laid on the "
           .. "centre of mass so that nobody starts inside one, and a gather "
           .. "keeps that: the ring of circles is drawn at 900 units round the "
           .. "gathered pile and the pile is 260 wide, so every player starts "
           .. "the same walk from every circle and none of them starts in one. "
           .. "A surveyed centre is unchanged." },
    sumo = { heal = true, gather = true, grace = true, safe = false,
        why = "The round the report is about. The ring is pinned where the "
           .. "host stands, so gathering to the host is gathering into the "
           .. "ring - and three seconds of nobody being able to shove is what "
           .. "stops one player kicking the pile out on frame one." },
    zombies = { heal = true, gather = false, grace = false, safe = false,
        why = "The infected are already held for fifteen seconds while the "
           .. "survivors scatter, which is this mode's own opening. A catch is "
           .. "a radius rather than a swing, so a grace would stop nothing "
           .. "anyway." },
}

function modes.opening(key)
    if key == nil then
        local mode = modes.current()
        if mode == nil then return nil end
        key = mode.key
    end
    if type(key) ~= "string" then return nil end
    return modes.OPENING[key]
end

local GRACE_SECONDS = 3

local GRACE_INVINC = 30

function modes.grace_left()
    local opening = modes.opening()
    if opening == nil or not opening.grace then return 0 end

    local state = modes.state()
    if state == modes.COUNTDOWN then return GRACE_SECONDS end
    if state ~= modes.ACTIVE then return 0 end
    if modes.liveAt == nil then return 0 end

    local left = GRACE_SECONDS - (clock_elapsed() - modes.liveAt)
    if left <= 0 then return 0 end
    return left
end

function modes.in_grace()
    return modes.grace_left() > 0
end

local MUSTER_RADIUS = 260

local MUSTER_AT = 3

local MUSTER_DROP = 400

local mustered = false

local musterWhy = nil

function modes.forget_muster()
    mustered = false
    musterWhy = nil
end

function modes.in_muster_window()
    local state = modes.state()
    if state == modes.COUNTDOWN then
        return (gGlobalSyncTable.ofGmCount or 99) <= MUSTER_AT
    end
    if state ~= modes.ACTIVE then return false end
    local opening = modes.opening()
    if opening == nil or not opening.grace then return false end
    return modes.in_grace()
end

function modes.muster_slot(globalIndex, others)
    local count = #(others or {})
    if count <= 0 then return nil end
    for place, other in ipairs(others) do
        if other == globalIndex then return place, count end
    end
    return nil
end

function modes.muster_order(anchorGlobal)
    local list = {}
    for _, entry in ipairs(modes.participants()) do
        local np = entry.np
        if np ~= nil and np.globalIndex ~= anchorGlobal then
            table.insert(list, np.globalIndex)
        end
    end
    table.sort(list)
    return list
end

function modes.side_muster()
    local mode = modes.current()
    if mode == nil or type(mode.side_place) ~= "function" then return nil end

    local mine = nil
    if OF.util.asks(OF.teams, "of") then
        mine = OF.teams.of(0)
        if mine == "" then mine = nil end
    end

    local at = mode.side_place(mine)
    if type(at) ~= "table" or type(at.x) ~= "number"
        or type(at.y) ~= "number" or type(at.z) ~= "number" then
        return nil
    end

    local order = {}
    for _, entry in ipairs(modes.participants()) do
        local np = entry.np
        local theirs = nil
        if OF.util.asks(OF.teams, "of") then
            theirs = OF.teams.of(entry.localIndex)
            if theirs == "" then theirs = nil end
        end
        if np ~= nil and theirs == mine then
            table.insert(order, np.globalIndex)
        end
    end
    table.sort(order)
    return at, order, mine
end

function modes.say_muster_missed()
    if musterWhy == nil then return false end
    local why = musterWhy
    musterWhy = nil
    if not OF.util.asks(OF.notify, "show") then return false end
    OF.notify.show(why, "warn", 5)
    return true
end

function modes.muster_anchor()
    local where = modes.round_place()
    if where == nil then return 0, OF.util.local_from_global(0) end

    local function stands_there(globalIndex)
        local at = OF.util.local_from_global(globalIndex)
        local np = at ~= nil and gNetworkPlayers[at] or nil
        if np == nil then return nil end
        if np.currLevelNum ~= where.level then return nil end
        if np.currAreaIndex ~= where.area then return nil end
        if np.currAreaSyncValid == false then return nil end
        return at
    end

    local host = stands_there(0)
    if host ~= nil then return 0, host end

    local best, bestLocal = nil, nil
    for _, entry in ipairs(modes.participants()) do
        local np = entry.np
        local globalIndex = np ~= nil and np.globalIndex or nil
        if globalIndex ~= nil and (best == nil or globalIndex < best) then
            local at = stands_there(globalIndex)
            if at ~= nil then best, bestLocal = globalIndex, at end
        end
    end
    return best, bestLocal
end

function modes.settle_muster(m)
    if mustered then return false end

    local opening = modes.opening()
    if opening == nil then return false end
    if not opening.gather and not opening.sides then return false end
    if not modes.in_muster_window() then

        if musterWhy ~= nil then mustered = true end
        modes.say_muster_missed()
        return false
    end
    if not OF.util.can_play(0) then return false end

    if opening.sides then return modes.settle_side_muster(m) end

    local anchorGlobal, anchor = modes.muster_anchor()
    if anchorGlobal == nil or anchor == nil then
        musterWhy = "The round had nowhere to gather everybody to."
        return false
    end

    if anchor == 0 then
        mustered = true
        return false
    end

    local hm, hnp = gMarioStates[anchor], gNetworkPlayers[anchor]
    local np = gNetworkPlayers[0]
    if hm == nil or hm.pos == nil or hnp == nil or np == nil then return false end
    if m == nil or m.pos == nil then return false end

    if np.currLevelNum ~= hnp.currLevelNum
        or np.currAreaIndex ~= hnp.currAreaIndex then
        musterWhy = "The round started before you landed, so you are not in the ring."
        return false
    end
    if np.currAreaSyncValid == false then
        musterWhy = "Your level was still loading when the round gathered."
        return false
    end

    if hnp.currAreaSyncValid == false then
        musterWhy = "The round gathered before the middle of it had landed."
        return false
    end

    local others = modes.muster_order(anchorGlobal)
    local place, count = modes.muster_slot(network_global_index_from_local(0),
        others)
    if place == nil then
        mustered = true
        modes.say_muster_missed()
        return false
    end

    local angle = (2 * math.pi * (place - 1)) / count
    local x = hm.pos.x + math.sin(angle) * MUSTER_RADIUS
    local z = hm.pos.z + math.cos(angle) * MUSTER_RADIUS

    local floorY = OF.util.optional("find_floor_height", nil,
        x, hm.pos.y + 160, z)
    if type(floorY) ~= "number" or floorY < hm.pos.y - MUSTER_DROP then
        x, z = hm.pos.x, hm.pos.z
    end

    if not OF.util.asks(OF.doorways, "put_at") then return false end
    OF.doorways.put_at(m, x, hm.pos.y, z)

    if m.faceAngle ~= nil and atan2s ~= nil then
        m.faceAngle.y = atan2s(hm.pos.z - z, hm.pos.x - x)
    end

    mustered = true
    return true
end

function modes.settle_side_muster(m)
    if m == nil or m.pos == nil then return false end

    local at, order = modes.side_muster()

    if at == nil then return false end

    local np = gNetworkPlayers[0]
    if np == nil then return false end

    if type(at.level) == "number" and np.currLevelNum ~= at.level then
        return false
    end
    if type(at.area) == "number" and np.currAreaIndex ~= at.area then
        return false
    end
    if np.currAreaSyncValid == false then return false end

    local place, count = modes.muster_slot(network_global_index_from_local(0),
        order)
    if place == nil then
        mustered = true
        return false
    end

    local angle = (2 * math.pi * (place - 1)) / count
    local x = at.x + math.sin(angle) * MUSTER_RADIUS
    local z = at.z + math.cos(angle) * MUSTER_RADIUS

    local floorY = OF.util.optional("find_floor_height", nil, x, at.y + 160, z)
    if type(floorY) ~= "number" or floorY < at.y - MUSTER_DROP then
        x, z = at.x, at.z
    end

    if not OF.util.asks(OF.doorways, "put_at") then return false end
    OF.doorways.put_at(m, x, at.y, z)

    if m.faceAngle ~= nil and atan2s ~= nil then
        m.faceAngle.y = atan2s(at.z - z, at.x - x)
    end

    mustered = true
    return true
end

function modes.settle_opening(m)
    if m == nil then return false end
    if not modes.is_running() then return false end
    if not OF.util.can_play(0) then return false end

    local opening = modes.opening()
    if opening == nil then return false end

    local did = false

    if opening.grace and modes.in_grace() then
        if (m.invincTimer or 0) < GRACE_INVINC then
            m.invincTimer = GRACE_INVINC
        end

        m.hurtCounter = 0
        did = true
    end

    if opening.safe then
        if (m.health or 0) < FULL_HEALTH then m.health = FULL_HEALTH end
        m.hurtCounter = 0

        if m.pos ~= nil then m.peakHeight = m.pos.y end
        did = true
    end

    return did
end

function modes.heal_checkpoint()
    local opening = modes.opening()
    if opening == nil or not opening.healAt then return false end
    return modes.give_full_health()
end

function modes.opening_line(modeKey)
    local row = modes.opening(modeKey)
    local opener, allRound = {}, {}
    if row ~= nil then
        if row.gather then
            table.insert(opener, OF.lang.t("everybody gathered first"))
        end

        if row.sides then
            table.insert(opener,
                OF.lang.t("everybody put where their round starts"))
        end
        if row.grace then
            table.insert(opener, OF.lang.fill(
                "@ seconds where nobody can be hit", tostring(GRACE_SECONDS)))
        end
        if row.safe then
            table.insert(allRound, OF.lang.t("no dying all round"))
        end
        if row.healAt then
            table.insert(allRound, OF.lang.t("healed at every checkpoint"))
        end
    end

    local said = #opener > 0
        and OF.lang.fill("Opens with: @", table.concat(opener, ", "))
        or OF.lang.t("Opens with: GO, and you are playing")
    if #allRound == 0 then return said end
    return said .. " - " .. table.concat(allRound, ", ")
end

modes.ROUND_RULE_KEYS = { "interactions", "knockback", "bounce" }

modes.ROUND_RULES = {
    bank = { keep = {},
        why = "The vault is one object in one room and a coin only counts once "
           .. "it is carried home, so the errand is a measured walk. A runner "
           .. "who crosses the room off its own edge at half again their speed "
           .. "is walking a shorter errand than anybody else." },
    bossrush = { keep = {},
        why = "Every runner is alone in their own copy of their own boss "
           .. "arena, so nothing the lobby says about two players touching can "
           .. "reach this round. The one thing that could is a bounce off the "
           .. "arena's edge mid-fight, which is the difference between a boss "
           .. "beaten and a boss outrun." },
    bounty = { keep = {},
        why = "A knockdown is the whole score, which is exactly why the lobby's "
           .. "dial does not come with it: the round is balanced on the game's "
           .. "own normal, and a lobby left at silly settles every tag on the "
           .. "first swing of the round." },
    coinrush = { keep = {},
        why = "Collection over the one room the rain is pinned to. A player "
           .. "who can cross it by bouncing off the world's edge is collecting "
           .. "faster than anybody who runs, and a shower nobody can outrun is "
           .. "the only thing this round has to be fair about." },
    crown = { keep = {},
        why = "The crown is taken with a fist and kept by staying out of "
           .. "reach. Both halves of that are measured in how far a hit throws "
           .. "and where the floor stops, so both belong to the round rather "
           .. "than to the session's settings." },
    ctf = { keep = {},
        why = "Two bases and a carry between them, defended by standing in the "
           .. "way. A flag runner who leaves the world and is turned back into "
           .. "it has taken a route no defender can stand on." },
    domination = { keep = {},
        why = "Three points held by standing on them. Everything the lobby "
           .. "could lend this round is a way of not being where you are "
           .. "standing, which is the one thing the scoring reads." },
    flood = { keep = {},
        why = "The water is a height and climbing above it is the whole round. "
           .. "A bounce off the world's edge is a way up that no ledge in the "
           .. "level offers, and the level's ledges are what everybody else is "
           .. "racing." },
    hexagone = { keep = {},
        why = "The floor is a stack of tiles taken away one at a time and "
           .. "everything under it is a fall. This round is about the floor "
           .. "rather than about the players, so the floor has to be the only "
           .. "thing in it that decides anybody." },
    hexheat = { keep = {},
        why = "Seven platforms over a drop, and the whole of the round is "
           .. "whether you were standing on the right one when the music "
           .. "stopped. A knockback that shoves somebody off the colour they "
           .. "reached decides a call that was already answered, and bouncy "
           .. "bounds under a board that sinks is a way of not falling when "
           .. "falling is the rule." },
    hideseek = { keep = { "bounce" },
        why = "Hiding is not decided by the edge of the world. This is the one "
           .. "round played across the whole game rather than inside a "
           .. "measured room, and out there the lobby's bouncy bounds is a "
           .. "comfort the host chose for the session: a hider who finds a way "
           .. "off the map and is put back is still hidden, where the flat "
           .. "setting kills them and respawns them in the open for every "
           .. "seeker to walk into." },
    hotpotato = { keep = {},
        why = "The fuse is the clock and the pass is a distance. A shove that "
           .. "throws further than the pass reaches turns a hand-off into a "
           .. "game of catch that nobody can be caught holding." },
    koth = { keep = {},
        why = "A circle to stand in, and every rule in this matrix is a way of "
           .. "moving somebody out of a circle they are standing in. There is "
           .. "nothing left for the lobby to lend that this round would "
           .. "survive." },
    laststanding = { keep = {},
        why = "Three lives, and the lives are spent by being thrown off "
           .. "something. The dial that decides how far a hit throws is the "
           .. "dial that decides how many rounds the session gets, which is "
           .. "not a decision a leftover lobby setting should be making." },
    line = { keep = {},
        why = "Nobody can touch anybody: the light is the whole hazard, so "
           .. "none of the three could reach this round today. It flattens "
           .. "them anyway rather than being excused on those grounds - a mode "
           .. "that grows a way for players to touch each other next month "
           .. "would inherit the lobby's dial in silence." },
    logroll = { keep = {},
        why = "One log over one arena, and the round writes interactions to "
           .. "nought itself so that fifteen can stand shoulder to shoulder "
           .. "along its crest. Bouncy bounds is a way back up that the log "
           .. "does not offer - the fall past the line under it is the whole of "
           .. "being out - and knockback is a shove in a round where the only "
           .. "thing allowed to move anybody is the surface they are standing "
           .. "on." },
    manhunt = { keep = { "bounce" },
        why = "One runs with the whole level and the hunters are held ten "
           .. "seconds behind. Nothing in the chase is measured off the edge "
           .. "of the world, and a runner who steps off it and is turned back "
           .. "in is a runner still being hunted rather than one who ended the "
           .. "round by dying to the scenery." },
    meltdown = { keep = {},
        why = "Every floor in the level burns and the throw off it is the "
           .. "movement the whole run is made of. Anything that changes what "
           .. "the floor does to somebody is the round's business and not the "
           .. "session's, and a bounce off the world's edge is a shortcut no "
           .. "line of the course offers." },
    murder = { keep = { "bounce" },
        why = "A murderer lost in a crowd, and in the castle that crowd is "
           .. "spread over three levels. The kill is a knife at close range "
           .. "rather than a shove, so the edge of the world decides nothing "
           .. "here - and an innocent who falls out of it hands the murderer a "
           .. "body they never earned, which is the one death this round "
           .. "cannot tell apart from a real one." },
    secretrun = { keep = {},
        why = "Five secret courses with one runner in each, so nothing between "
           .. "two players reaches this round at all. The courses are the "
           .. "hazard the times are measured against, and a course with a "
           .. "bounce at its edge is a different course." },
    shellrace = { keep = {},
        why = "A run to a flagpole ridden on a shell. A ride that gains half "
           .. "again its speed off the world's edge is a time nobody else on "
           .. "the course can answer, and the fighting rule is never borrowed "
           .. "here in the first place." },
    simon = { keep = {},
        why = "Every call is judged against the whole lobby at once and half of "
           .. "them are about where the other players are. A lobby that can "
           .. "shove each other during GET TOGETHER is a call nobody can "
           .. "obey." },
    spots = { keep = {},
        why = "One circle too few when the music stops. Being pushed out of "
           .. "the circle you reached first is the single thing this round "
           .. "must never let a leftover lobby setting decide." },
    sumo = { keep = {},
        why = "The ring is the mode and outside it is out. Every rule in this "
           .. "matrix is a way of leaving a ring, which is why this round "
           .. "takes all three at the game's own numbers and keeps none of the "
           .. "session's." },
    zombies = { keep = {},
        why = "The horde catches by radius rather than by swing, and the mode "
           .. "writes its own knockback in `setup` - which runs after this and "
           .. "wins. The row still answers for all three, because what a mode "
           .. "does not write for itself is exactly what this table is here to "
           .. "answer." },
}

function modes.round_rules(key)
    if type(key) ~= "string" then return nil end
    return modes.ROUND_RULES[key]
end

function modes.keeps_rule(modeKey, ruleKey)
    local row = modes.round_rules(modeKey)
    if row == nil or type(row.keep) ~= "table" then return false end
    for _, kept in ipairs(row.keep) do
        if kept == ruleKey then return true end
    end
    return false
end

function modes.kept_rules(modeKey)
    local out = {}
    for _, ruleKey in ipairs(modes.ROUND_RULE_KEYS) do
        if modes.keeps_rule(modeKey, ruleKey) then table.insert(out, ruleKey) end
    end
    return out
end

function modes.kept_rules_line(modeKey)
    local kept = modes.kept_rules(modeKey)
    if #kept == 0 then
        return OF.lang.t("The lobby's own settings are set aside for this round")
    end
    local names = {}
    for _, ruleKey in ipairs(kept) do

        local entry = OF.util.asks(OF.rules, "find") and OF.rules.find(ruleKey)
        table.insert(names, OF.lang.t(
            type(entry) == "table" and entry.name or ruleKey))
    end
    return OF.lang.fill("The lobby keeps: @", table.concat(names, ", "))
end

local ROOM_HOLDER = "round"
local roomRulesHeld = nil
local roomSweepWas = nil

function modes.room_wants(mode)
    local out = { rules = {}, sweep = {} }
    local room = type(mode) == "table" and mode.room or nil
    if type(room) ~= "table" then return out end

    if type(room.rules) == "table" and OF.util.asks(OF.rules, "find") then
        for _, entry in ipairs(OF.rules.LIST or {}) do
            local value = room.rules[entry.key]
            if value ~= nil then
                table.insert(out.rules, { key = entry.key, value = value })
            end
        end
    end

    if type(room.sweep) == "table" and OF.arena ~= nil then
        local asked = {}
        for _, key in ipairs(room.sweep) do asked[key] = true end
        for _, option in ipairs(OF.arena.OPTIONS or {}) do
            if asked[option.key] then table.insert(out.sweep, option.key) end
        end
    end

    return out
end

function modes.room_unknown()
    local bad = {}
    for _, mode in ipairs(modes.LIST or {}) do
        local room = type(mode.room) == "table" and mode.room or nil
        if room ~= nil then
            for key in pairs(type(room.rules) == "table" and room.rules or {}) do
                local entry = OF.util.asks(OF.rules, "find") and OF.rules.find(key)
                if type(entry) ~= "table" then
                    table.insert(bad, mode.key .. ".rules." .. tostring(key))
                end
            end
            for _, key in ipairs(type(room.sweep) == "table" and room.sweep or {}) do
                local known = OF.arena ~= nil and OF.arena.OPTION_BY_KEY or {}
                if known[key] == nil then
                    table.insert(bad, mode.key .. ".sweep." .. tostring(key))
                end
            end
        end
    end
    table.sort(bad)
    return bad
end

function modes.take_the_room(mode)
    if not OF.util.is_host() then return false end

    local wants = modes.room_wants(mode)
    if #wants.rules == 0 and #wants.sweep == 0 then return false end

    if #wants.rules > 0 and OF.util.asks(OF.rules, "lend_many") then
        roomRulesHeld = {}
        for _, want in ipairs(wants.rules) do
            table.insert(roomRulesHeld, want.key)
        end
        OF.util.report(OF.rules.lend_many(wants.rules, ROOM_HOLDER))
    end

    if #wants.sweep > 0 and OF.util.asks(OF.arena, "arm") then

        local armed = OF.arena.armed_set()
        roomSweepWas = {
            clear = gGlobalSyncTable.ofArenaClear == true,
            place = gGlobalSyncTable.ofArenaPlace or "",
            keys = {},
        }
        local asked = {}
        for _, key in ipairs(wants.sweep) do asked[key] = true end
        local wanted, grew = {}, false
        for _, option in ipairs(OF.arena.OPTIONS) do
            local on = armed[option.key] == true
            if on then roomSweepWas.keys[option.key] = true end
            if on or asked[option.key] then
                table.insert(wanted, option.key)
                if not on then grew = true end
            end
        end

        if grew then
            OF.arena.arm(true, wanted, roomSweepWas.place)
        end
    end

    return true
end

function modes.hand_the_room_back()
    if not OF.util.is_host() then return false end

    local gave = false

    if roomRulesHeld ~= nil then
        local held = roomRulesHeld

        roomRulesHeld = nil
        if OF.util.asks(OF.rules, "give_back") then
            for _, key in ipairs(held) do
                OF.util.report(OF.rules.give_back(key, ROOM_HOLDER))
            end
        end
        gave = true
    end

    if roomSweepWas ~= nil then
        local was = roomSweepWas
        roomSweepWas = nil
        if OF.util.asks(OF.arena, "arm") then
            local armed = OF.arena.armed_set()
            local wanted, moved = {}, false
            for _, option in ipairs(OF.arena.OPTIONS) do
                local back = was.keys[option.key] == true
                if back then table.insert(wanted, option.key) end
                if back ~= (armed[option.key] == true) then moved = true end
            end
            if moved or (gGlobalSyncTable.ofArenaClear == true) ~= was.clear then
                OF.arena.arm(was.clear, wanted, was.place)
            end
        end
        gave = true
    end

    return gave
end

function modes.refuses_shell_rides()
    if not modes.is_running() then return false end
    local mode = modes.current()
    return mode ~= nil and mode.noShellRide == true
end

hook_event(HOOK_ALLOW_INTERACT, function(m, _, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_KOOPA_SHELL then return end
    if modes.refuses_shell_rides() then return false end
end)

function modes.refuses_player_solidity()
    if not modes.is_running() then return false end
    local mode = modes.current()
    return mode ~= nil and mode.unsolidInAFight == true
end

do
local function player_of_object(o)
    if o == nil then return nil end
    for _, entry in ipairs(OF.util.connected_players()) do
        local other = gMarioStates[entry.localIndex]
        if other ~= nil and other.marioObj ~= nil and other.marioObj == o then
            return entry.localIndex
        end
    end
    return nil
end

hook_event(HOOK_ALLOW_INTERACT, function(m, o, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_PLAYER then return end
    if modes.refuses_player_solidity() then return false end

    if not modes.is_running() or not modes.refuses_latecomers() then return end
    if modes.left_out_of_this_round(0) then return false end
    if modes.left_out_of_this_round(player_of_object(o)) then return false end
end)
end

modes.tokens = modes.tokens or {}

function modes.show_token(name, model, at, spin, behaviour)
    if name == nil or at == nil then return nil end

    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return nil end

    local token = modes.tokens[name]
    if token == nil or token.activeFlags == 0 then
        token = OF.util.optional("spawn_non_sync_object", nil,
            behaviour or id_bhvStaticObject, model,
            at.x, at.y, at.z, nil)
        modes.tokens[name] = token

        if token ~= nil then
            token.oFaceAnglePitch = 0
            token.oFaceAngleYaw = 0
            token.oFaceAngleRoll = 0
        end
    end
    if token == nil then return nil end

    token.oPosX, token.oPosY, token.oPosZ = at.x, at.y, at.z

    if spin ~= nil then
        token.oFaceAngleYaw = (token.oFaceAngleYaw or 0) + spin
    end
    return token
end

function modes.hide_token(name)
    local token = modes.tokens[name]
    if token == nil then return false end
    if token.activeFlags ~= nil then token.activeFlags = 0 end
    modes.tokens[name] = nil
    return true
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    if modes.tokens == nil then return end
    for name in pairs(modes.tokens) do modes.tokens[name] = nil end
end)

function modes.drop_tokens()
    local any = false
    for name in pairs(modes.tokens) do
        if modes.hide_token(name) then any = true end
    end
    return any
end

function modes.here_place(localIndex)
    local index = localIndex or 0
    local m = gMarioStates[index]
    local np = gNetworkPlayers[index]
    if m == nil or np == nil or m.pos == nil then return nil end
    return {
        x = m.pos.x, y = m.pos.y, z = m.pos.z,
        level = np.currLevelNum, area = np.currAreaIndex,
    }
end

function modes.in_place_room(spot, localIndex)
    if type(spot) ~= "table" or spot.x == nil then return false end
    local np = gNetworkPlayers[localIndex or 0]
    if np == nil then return false end
    if spot.level ~= nil and np.currLevelNum ~= spot.level then return false end
    if spot.area ~= nil and np.currAreaIndex ~= spot.area then return false end
    return true
end

modes.SURVEYED = {

    [LEVEL_BBH] = {
        [1] = {
            ctfRed  = { x = 666, y = -204, z = 5304, yaw = 180 },
            ctfBlue = { x = 609, y = -204, z = -3020, yaw = 4 },
            points = {
                { x = 666, y = -204, z = 5304, yaw = 180 },
                { x = 609, y = -204, z = -3020, yaw = 4 },
                { x = -143, y = 1741, z = 810, yaw = 90 },
            },
            lineStart  = { x = 666, y = -204, z = 5304, yaw = 180 },
            lineFinish = { x = -143, y = 1741, z = 810, yaw = 90 },
            musicalSpot = { x = 666, y = -204, z = 5304, yaw = 180 },
            floodStart = { x = 678, y = -204, z = 4201, yaw = 181 },
            floodGoal  = { x = -346, y = 1741, z = 836, yaw = 96 },
        },
    },

    [LEVEL_BOB] = {
        [1] = {
            ctfRed  = { x = 3714, y = 768, z = 6216, yaw = 227 },
            ctfBlue = { x = -5967, y = 1024, z = -1388, yaw = 63 },
            points = {
                { x = 3714, y = 768, z = 6216, yaw = 227 },
                { x = -5967, y = 1024, z = -1388, yaw = 63 },
                { x = 2919, y = 4293, z = -5015, yaw = 312 },
            },
            lineStart  = { x = 3714, y = 768, z = 6216, yaw = 227 },

            lineFinish = { x = 2919, y = 4293, z = -5015, yaw = 312 },
            musicalSpot = { x = 2919, y = 4293, z = -5015, yaw = 312 },

            hill = { x = 3112, y = 4293, z = -5050, yaw = 301 },

            island = { x = 4406, y = 3072, z = 1215, yaw = 359 },

            floodStart = { x = -4599, y = 0, z = 5598, yaw = 89 },
            floodGoal  = { x = 3101, y = 4293, z = -4715, yaw = 10 },
        },
    },

    [LEVEL_BOWSER_1] = {
        [1] = {
            ctfRed  = { x = -7443, y = -3153, z = 3886, yaw = 90 },
            ctfBlue = { x = 3042, y = 1024, z = 454, yaw = 290 },
            points = {
                { x = -7443, y = -3153, z = 3886, yaw = 90 },
                { x = 3042, y = 1024, z = 454, yaw = 290 },
                { x = -2404, y = -1433, z = 3682, yaw = 90 },
            },
            lineStart  = { x = -7443, y = -3153, z = 3886, yaw = 90 },
            lineFinish = { x = 3042, y = 1024, z = 454, yaw = 290 },
            floodStart = { x = -7480, y = -3153, z = 3885, yaw = 88 },
            floodGoal  = { x = 5811, y = 2765, z = 4, yaw = 270 },
        },
    },

    [LEVEL_BOWSER_2] = {
        [1] = {
            ctfRed  = { x = 3629, y = -2764, z = 280, yaw = 90 },
            ctfBlue = { x = -1835, y = 1331, z = -471, yaw = 84 },
            points = {
                { x = 3629, y = -2764, z = 280, yaw = 90 },
                { x = -1835, y = 1331, z = -471, yaw = 84 },
                { x = 3731, y = 4403, z = 87, yaw = 269 },
            },
            lineStart  = { x = 3629, y = -2764, z = 280, yaw = 90 },
            lineFinish = { x = 3731, y = 4403, z = 87, yaw = 269 },
            floodStart = { x = -7519, y = -2764, z = 0, yaw = 90 },
            floodGoal  = { x = 4213, y = 4403, z = 102, yaw = 273 },
        },
    },

    [LEVEL_BOWSER_3] = {
        [1] = {
            floodStart = { x = -7039, y = -4812, z = 4, yaw = 90 },
            floodGoal  = { x = 346, y = 6447, z = -5316, yaw = 359 },
        },
    },

    [LEVEL_CASTLE_GROUNDS] = {
        [1] = {
            ctfRed  = { x = -6403, y = 331, z = -587, yaw = 51 },
            ctfBlue = { x = -1439, y = 260, z = 4625, yaw = 178 },
            points = {
                { x = -6403, y = 331, z = -587, yaw = 51 },
                { x = -1439, y = 260, z = 4625, yaw = 178 },
                { x = 3, y = 906, z = -1250, yaw = 356 },
            },
            lineStart  = { x = -6403, y = 331, z = -587, yaw = 51 },
            lineFinish = { x = 5590, y = 373, z = -1933, yaw = 326 },
            musicalSpot = { x = -1439, y = 260, z = 4625, yaw = 178 },
        },
    },

    [LEVEL_COTMC] = {
        [1] = {
            ctfRed  = { x = -4322, y = 20, z = -65, yaw = 81 },
            ctfBlue = { x = 286, y = 266, z = -5324, yaw = 359 },
            points = {
                { x = -4322, y = 20, z = -65, yaw = 81 },
                { x = 286, y = 266, z = -5324, yaw = 359 },
                { x = 379, y = 109, z = -1317, yaw = 188 },
            },
            lineStart  = { x = -4322, y = 20, z = -65, yaw = 81 },
            lineFinish = { x = 286, y = 266, z = -5324, yaw = 359 },
        },
    },

    [LEVEL_CCM] = {
        [1] = {
            ctfRed  = { x = -1475, y = 2560, z = -2203, yaw = 104 },
            ctfBlue = { x = -5446, y = -1740, z = 3619, yaw = 126 },
            points = {
                { x = -1475, y = 2560, z = -2203, yaw = 104 },
                { x = -5446, y = -1740, z = 3619, yaw = 126 },
                { x = 3013, y = -818, z = 601, yaw = 304 },
            },
            lineStart  = { x = -5446, y = -1740, z = 3619, yaw = 126 },
            lineFinish = { x = 4638, y = -4607, z = 3077, yaw = 287 },
            musicalSpot = { x = 4638, y = -4607, z = 3077, yaw = 287 },
            floodStart = { x = 4363, y = -4607, z = 3845, yaw = 228 },
            floodGoal  = { x = -1231, y = 2560, z = -2479, yaw = 82 },
        },

        [2] = {
            floodStart = { x = -6502, y = -5836, z = -6937, yaw = 6 },
            floodGoal  = { x = -5720, y = 6656, z = -6143, yaw = 90 },
        },
    },

    [LEVEL_DDD] = {
        [1] = {
            ctfRed  = { x = 1547, y = 110, z = 4273, yaw = 48 },
            ctfBlue = { x = 6295, y = 110, z = 4352, yaw = 272 },
            points = {
                { x = 1547, y = 110, z = 4273, yaw = 48 },
                { x = 6295, y = 110, z = 4352, yaw = 272 },
                { x = 3904, y = 571, z = 1231, yaw = 359 },
            },
            lineStart  = { x = 1547, y = 110, z = 4273, yaw = 48 },
            lineFinish = { x = 3899, y = 571, z = -1187, yaw = 358 },
        },
    },

    [LEVEL_HMC] = {
        [1] = {
            ctfRed  = { x = -7514, y = 2161, z = 7475, yaw = 134 },
            ctfBlue = { x = -2849, y = 1843, z = -6441, yaw = 232 },
            points = {
                { x = -7514, y = 2161, z = 7475, yaw = 134 },
                { x = -2849, y = 1843, z = -6441, yaw = 232 },
                { x = 6500, y = 0, z = 5128, yaw = 242 },
            },
            lineStart  = { x = -7514, y = 2161, z = 7475, yaw = 134 },
            lineFinish = { x = -2849, y = 1843, z = -6441, yaw = 232 },
            musicalSpot = { x = 6500, y = 0, z = 5128, yaw = 242 },
        },
    },

    [LEVEL_JRB] = {
        [1] = {
            ctfRed  = { x = -6388, y = 1126, z = 208, yaw = 49 },
            ctfBlue = { x = 1466, y = 1536, z = 6938, yaw = 233 },
            points = {
                { x = -6388, y = 1126, z = 208, yaw = 49 },
                { x = 1466, y = 1536, z = 6938, yaw = 233 },
                { x = 5606, y = -2966, z = -6761, yaw = 331 },
            },
            lineStart  = { x = -6388, y = 1126, z = 208, yaw = 49 },
            lineFinish = { x = 1466, y = 1536, z = 6938, yaw = 233 },
        },
    },

    [LEVEL_LLL] = {
        [1] = {
            ctfRed  = { x = 1111, y = 154, z = 6228, yaw = 214 },
            ctfBlue = { x = 3860, y = 307, z = -5658, yaw = 0 },
            points = {
                { x = 1111, y = 154, z = 6228, yaw = 214 },
                { x = -1, y = 768, z = -6758, yaw = 358 },
                { x = 6631, y = 154, z = -3057, yaw = 274 },
            },
            lineStart  = { x = 1111, y = 154, z = 6228, yaw = 214 },
            lineFinish = { x = 3860, y = 307, z = -5658, yaw = 0 },
        },

        [2] = {
            floodStart = { x = -1526, y = 97, z = 615, yaw = 147 },
            floodGoal  = { x = 2221, y = 3539, z = -1433, yaw = 219 },
        },
    },

    [LEVEL_PSS] = {
        [1] = {
            ctfRed  = { x = 4766, y = 6144, z = -5647, yaw = 271 },
            ctfBlue = { x = -6378, y = -4587, z = 4640, yaw = 182 },
            points = {
                { x = 4766, y = 6144, z = -5647, yaw = 271 },
                { x = -6378, y = -4587, z = 4640, yaw = 182 },
                { x = 1883, y = -1482, z = -471, yaw = 179 },
            },
            lineStart  = { x = 4766, y = 6144, z = -5647, yaw = 271 },
            lineFinish = { x = -6378, y = -4587, z = 4640, yaw = 182 },
            musicalSpot = { x = 4766, y = 6144, z = -5647, yaw = 271 },

            floodStart = { x = -6381, y = -4587, z = 4726, yaw = 183 },
            floodGoal  = { x = 4629, y = 6144, z = -5637, yaw = 270 },
        },
    },

    [LEVEL_RR] = {
        [1] = {
            ctfRed  = { x = -2517, y = -1782, z = 418, yaw = 109 },
            ctfBlue = { x = -1952, y = -4598, z = 6672, yaw = 120 },
            points = {
                { x = -2517, y = -1782, z = 418, yaw = 109 },
                { x = -1952, y = -4598, z = 6672, yaw = 120 },
                { x = 613, y = -1116, z = -3434, yaw = 2 },
            },
            lineStart  = { x = -1952, y = -4598, z = 6672, yaw = 120 },
            lineFinish = { x = 613, y = -1116, z = -3434, yaw = 2 },
            musicalSpot = { x = -4826, y = 3072, z = -5322, yaw = 51 },
            floodStart = { x = 2641, y = -1833, z = 2074, yaw = 310 },
            floodGoal  = { x = -1829, y = 3120, z = -180, yaw = 248 },
        },
    },

    [LEVEL_SSL] = {
        [1] = {
            ctfRed  = { x = 4169, y = 0, z = 6780, yaw = 207 },
            ctfBlue = { x = -6238, y = 0, z = -4239, yaw = 50 },
            points = {
                { x = 4169, y = 0, z = 6780, yaw = 207 },
                { x = -6238, y = 0, z = -4239, yaw = 50 },
                { x = -2142, y = 0, z = 2910, yaw = 134 },
            },
            lineStart  = { x = 4169, y = 0, z = 6780, yaw = 207 },
            lineFinish = { x = -6238, y = 0, z = -4239, yaw = 50 },

            floodStart = { x = 2, y = 0, z = 3544, yaw = 89 },
            floodGoal  = { x = 31, y = 4429, z = -942, yaw = 277 },
        },
    },

    [LEVEL_SL] = {
        [1] = {
            ctfRed  = { x = 2286, y = 1024, z = 4924, yaw = 192 },
            ctfBlue = { x = -4228, y = 1090, z = -4533, yaw = 39 },
            points = {
                { x = 2286, y = 1024, z = 4924, yaw = 192 },
                { x = -4228, y = 1090, z = -4533, yaw = 39 },
                { x = 2435, y = 1536, z = -2527, yaw = 326 },
            },
            lineStart  = { x = 2286, y = 1024, z = 4924, yaw = 192 },
            lineFinish = { x = -4228, y = 1090, z = -4533, yaw = 39 },
            musicalSpot = { x = 2286, y = 1024, z = 4924, yaw = 192 },

            floodStart = { x = 3183, y = 1024, z = 3551, yaw = 193 },
            floodGoal  = { x = -397, y = 4352, z = 732, yaw = 340 },
        },
    },

    [LEVEL_TTM] = {
        [1] = {
            ctfRed  = { x = 91, y = -4332, z = 5748, yaw = 146 },
            ctfBlue = { x = 2069, y = -1548, z = 2955, yaw = 350 },
            points = {
                { x = 91, y = -4332, z = 5748, yaw = 146 },
                { x = 2069, y = -1548, z = 2955, yaw = 350 },
                { x = 1104, y = 2309, z = 331, yaw = 1 },
            },
            lineStart  = { x = 91, y = -4332, z = 5748, yaw = 146 },
            lineFinish = { x = 1104, y = 2309, z = 331, yaw = 1 },
            musicalSpot = { x = -2778, y = -2154, z = 3004, yaw = 180 },
            floodStart = { x = 105, y = -4332, z = 5708, yaw = 118 },
            floodGoal  = { x = 1083, y = 2309, z = 277, yaw = 88 },
        },
    },

    [LEVEL_TTC] = {
        [1] = {
            ctfRed  = { x = 1311, y = -4822, z = 390, yaw = 253 },
            ctfBlue = { x = 1072, y = -19, z = 1095, yaw = 227 },
            points = {
                { x = 1311, y = -4822, z = 390, yaw = 253 },
                { x = 1072, y = -19, z = 1095, yaw = 227 },
                { x = -1286, y = -992, z = -950, yaw = 41 },
            },
            lineStart  = { x = 1311, y = -4822, z = 390, yaw = 253 },
            lineFinish = { x = 1072, y = -19, z = 1095, yaw = 227 },
            musicalSpot = { x = 1072, y = -19, z = 1095, yaw = 227 },
            floodStart = { x = 1413, y = -4822, z = 212, yaw = 198 },
            floodGoal  = { x = 33, y = 6011, z = -1286, yaw = 60 },
        },
    },

    [LEVEL_THI] = {
        [1] = {
            ctfRed  = { x = -6172, y = -2047, z = -4142, yaw = 9 },
            ctfBlue = { x = 6500, y = -2559, z = 4834, yaw = 231 },
            points = {
                { x = -6172, y = -2047, z = -4142, yaw = 9 },
                { x = 6500, y = -2559, z = 4834, yaw = 231 },
                { x = 1916, y = -2047, z = -5133, yaw = 83 },
            },
            lineStart  = { x = -6835, y = -2969, z = 6770, yaw = 100 },
            lineFinish = { x = 1916, y = -2047, z = -5133, yaw = 83 },
            musicalSpot = { x = -6835, y = -2969, z = 6770, yaw = 100 },
            floodStart = { x = 6497, y = -2559, z = 5009, yaw = 180 },
            floodGoal  = { x = 2581, y = 3226, z = -2652, yaw = 1 },
        },
    },

    [LEVEL_TOTWC] = {
        [1] = {
            musicalSpot = { x = 1, y = -1940, z = 9, yaw = 89 },
        },
    },

    [LEVEL_VCUTM] = {
        [1] = {
            ctfRed  = { x = -6037, y = -3276, z = 1240, yaw = 89 },
            ctfBlue = { x = 4507, y = 0, z = -5544, yaw = 270 },
            points = {
                { x = -6037, y = -3276, z = 1240, yaw = 89 },
                { x = 4507, y = 0, z = -5544, yaw = 270 },
                { x = -2096, y = -2457, z = -5639, yaw = 89 },
            },
            lineStart  = { x = -6037, y = -3276, z = 1240, yaw = 89 },
            lineFinish = { x = 4507, y = 0, z = -5544, yaw = 270 },
        },
    },

    [LEVEL_WDW] = {
        [1] = {
            ctfRed  = { x = 2172, y = 0, z = 3678, yaw = 232 },
            ctfBlue = { x = 58, y = 2304, z = -2532, yaw = 3 },
            points = {
                { x = 2172, y = 0, z = 3678, yaw = 232 },
                { x = 58, y = 2304, z = -2532, yaw = 3 },
                { x = -3271, y = 1152, z = 675, yaw = 119 },
            },
            lineStart  = { x = 2172, y = 0, z = 3678, yaw = 232 },
            lineFinish = { x = 58, y = 2304, z = -2532, yaw = 3 },
            musicalSpot = { x = 3479, y = 0, z = -1174, yaw = 318 },

            floodStart = { x = 2084, y = 0, z = 3636, yaw = 225 },
            floodGoal  = { x = -217, y = 3840, z = 65, yaw = 194 },
        },
    },

    [LEVEL_WF] = {
        [1] = {
            ctfRed  = { x = 3696, y = 256, z = 4899, yaw = 214 },
            ctfBlue = { x = 3140, y = 1075, z = -3515, yaw = 357 },
            points = {
                { x = 3696, y = 256, z = 4899, yaw = 214 },
                { x = 3140, y = 1075, z = -3515, yaw = 357 },
                { x = -1438, y = 2560, z = -1837, yaw = 41 },
            },
            lineStart  = { x = 3696, y = 256, z = 4899, yaw = 214 },
            lineFinish = { x = -1438, y = 2560, z = -1837, yaw = 41 },
            musicalSpot = { x = 1949, y = 922, z = 3102, yaw = 13 },
            floodStart = { x = 3071, y = 256, z = 4843, yaw = 153 },
            floodGoal  = { x = 63, y = 3584, z = 211, yaw = 196 },
        },
    },
}

function modes.surveyed(place, key)
    if type(place) ~= "table" or key == nil then return nil end
    local byLevel = modes.SURVEYED[place.level]
    if byLevel == nil then return nil end
    local set = byLevel[place.area]
    if set == nil then return nil end
    local found = set[key]
    if found == nil then return nil end

    if OF.util.asks(OF.warp, "land_spot") then
        return OF.warp.land_spot({ x = found.x, y = found.y, z = found.z,
            yaw = found.yaw })
    end
    return { x = found.x, y = found.y, z = found.z, yaw = found.yaw }
end

function modes.surveyed_list(place, key)
    if type(place) ~= "table" or key == nil then return nil end
    local byLevel = modes.SURVEYED[place.level]
    if byLevel == nil then return nil end
    local set = byLevel[place.area]
    if set == nil then return nil end
    local found = set[key]
    if type(found) ~= "table" or found[1] == nil then return nil end
    local out = {}
    for index, spot in ipairs(found) do

        local one = { x = spot.x, y = spot.y, z = spot.z, yaw = spot.yaw }
        if OF.util.asks(OF.warp, "land_spot") then
            one = OF.warp.land_spot(one)
        end
        out[index] = one
    end
    return out
end

modes.PLACE_HEIGHT = 600

function modes.distance_to_place(spot, localIndex)
    if not modes.in_place_room(spot, localIndex) then return nil end
    local m = gMarioStates[localIndex or 0]
    if m == nil or m.pos == nil then return nil end
    local dy = math.abs(m.pos.y - (spot.y or 0))
    if dy > (spot.height or modes.PLACE_HEIGHT) then return nil end
    local dx = m.pos.x - (spot.x or 0)
    local dz = m.pos.z - (spot.z or 0)
    return math.sqrt(dx * dx + dz * dz)
end

function modes.at_place(spot, radius, localIndex)
    local distance = modes.distance_to_place(spot, localIndex)
    if distance == nil then return false end
    return distance <= (radius or 0)
end

function modes.mark_place(name, model, spot, spin)
    if not modes.in_place_room(spot) then
        modes.hide_token(name)
        return nil
    end
    return modes.show_token(name, model, spot, spin)
end

function modes.flag_token(name, at, spin)
    local token = modes.show_token(name, E_MODEL_KOOPA_FLAG, at, spin,
        id_bhvKoopaFlag)
    if token ~= nil then
        token.oInteractType = 0
        token.oIntangibleTimer = -1
        token.oTimer = 0
    end
    return token
end

function modes.mark_flag(name, at, spin)
    if not modes.in_place_room(at) then
        modes.hide_token(name)
        return nil
    end
    return modes.flag_token(name, at, spin)
end

function modes.is_out(localIndex)
    if not modes.is_running() then return false end
    return modes.OUT_ROLES[modes.role(localIndex)] == true
end

function modes.survived(localIndex)
    return modes.OUT_ROLES[modes.role(localIndex)] ~= true
end

modes.URGENT_SECONDS = 10
modes.LOUD_SECONDS   = 5

function modes.has_deadline()
    local mode = modes.current()
    if mode == nil or mode.countsUp then return false end
    return (gGlobalSyncTable.ofGmLimit or 0) > 0
end

local function left_after(elapsed)
    local limit = gGlobalSyncTable.ofGmLimit or 0
    if limit <= 0 then return nil end
    return math.max(0, limit - (elapsed or 0))
end

hook_on_sync_table_change(gGlobalSyncTable, "ofGmCount", 0,
    function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofGmCount") then return end
        if newVal == oldVal then return end

        if type(newVal) ~= "number" or newVal < 1 then return end
        OF.sounds.play(OF.sounds.COUNT)
    end)

hook_on_sync_table_change(gGlobalSyncTable, "ofGmElapsed", 0,
    function(tag, oldVal, newVal)

    if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofGmElapsed") then return end
        if newVal == oldVal then return end

        if modes.is_running() and type(newVal) == "number"
            and modes.liveAt ~= nil then
            local mine = modes.since_start()
            local slack = modes.ORIGIN_SLACK
            if mine < newVal - slack or mine > newVal + slack then
                settle_round_origin()
            end
        end

        if modes.state() ~= modes.ACTIVE then return end
        if not modes.has_deadline() then return end

        local left = left_after(newVal)
        if left == nil or left < 1 or left > modes.LOUD_SECONDS then return end
        OF.sounds.play(OF.sounds.COUNT)
    end)

local holdSpoken = nil

function modes.forget_the_hold()
    holdSpoken = nil
end

function modes.count_the_hold(left)
    if type(left) ~= "number" then
        holdSpoken = nil
        return nil
    end
    left = math.floor(left)
    local was = holdSpoken
    holdSpoken = left

    if was == nil or left == was then return nil end
    if left <= 0 then

        if was <= 0 then return nil end
        OF.sounds.play(OF.sounds.GO)
        return OF.sounds.GO
    end

    if left > modes.LOUD_SECONDS then return nil end
    OF.sounds.play(OF.sounds.COUNT)
    return OF.sounds.COUNT
end

local countdownDigit = nil
local countdownPhase = 0

local PULSE_FROM = 3

function modes.reset_countdown_pulse()
    countdownDigit = nil
    countdownPhase = 0
end

function modes.countdown_pulse()
    return countdownDigit, countdownPhase
end

local DIGIT_SCALE = 1.5
local DIGIT_BIG = 2.1

local DIGIT_GAP = 10
local DIGIT_EDGE = 12

local function digit_geometry(text, seconds, phase, screenWidth, screenHeight,
                              cardBottom)
    local scale = DIGIT_SCALE
    local alpha = 255
    if type(seconds) == "number" and seconds <= PULSE_FROM then

        local t = OF.util.clamp(phase / 30, 0, 1)
        scale = DIGIT_BIG - (DIGIT_BIG - DIGIT_SCALE) * t
        alpha = 255 - 150 * t
    end

    local width = OF.util.width(text, scale)

    local y = screenHeight * 0.46
    if cardBottom ~= nil and cardBottom + DIGIT_GAP > y then
        local _, tall = OF.util.text_size(text, DIGIT_BIG)
        y = math.min(cardBottom + DIGIT_GAP,
                     math.max(y, screenHeight - tall - DIGIT_EDGE))
    end
    return (screenWidth - width) * 0.5, y, scale, alpha
end

local function render_countdown()

    local seconds = gGlobalSyncTable.ofGmCount
        or math.ceil(COUNTDOWN_FRAMES / 30)
    local mode = modes.current()

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local cardBottom = nil

    if mode ~= nil then

        local title = OF.lang.t(mode.name)

        local titleHeight = OF.util.in_font(FONT_MENU, function()
            local width, height = OF.util.text_size(title, 0.8)
            OF.util.plate((screenWidth - width) * 0.5 - 14,
                screenHeight * 0.30 - 8, width + 28, height + 16)
            OF.util.text(title, (screenWidth - width) * 0.5, screenHeight * 0.30,
                0.8, OF.util.gold().r, OF.util.gold().g, OF.util.gold().b, 255)
            return height
        end)

        local y = screenHeight * 0.30 + titleHeight + 12
        local rules = modes.rules_for(mode)
        if rules ~= nil and rules ~= "" then
            local blurb = OF.lang.t(rules)
            local blurbScale = 0.85
            local blurbWidth, blurbHeight = OF.util.text_size(blurb, blurbScale)
            OF.util.text(blurb, (screenWidth - blurbWidth) * 0.5, y,
                blurbScale, 200, 200, 200, 255)
            y = y + blurbHeight + 6
        end

        local terms = modes.terms()
        if #terms > 0 then
            local line = table.concat(terms, "   -   ")
            local termsScale = 0.75
            local termsWidth, termsHeight = OF.util.text_size(line, termsScale)
            OF.util.text(line, (screenWidth - termsWidth) * 0.5, y,
                termsScale, 150, 170, 200, 255)
            y = y + termsHeight + 6
        end

        local role = modes.my_role()
        if role ~= "" then

            local line = OF.lang.fill("You are @", OF.lang.t(role))
            local roleScale = 1.1

            local roleWidth, roleHeight = OF.util.text_size(line, roleScale)
            OF.util.text(line, (screenWidth - roleWidth) * 0.5, y,
                roleScale, 255, 255, 255, 255)
            y = y + roleHeight + 2
        end

        cardBottom = y

        local aim = modes.aim_line()
        if aim ~= nil and aim ~= "" and aim ~= rules then
            local aimText = OF.lang.t(aim)
            local aimScale = 0.8
            local aimWidth, aimHeight = OF.util.text_size(aimText, aimScale)
            OF.util.text(aimText, (screenWidth - aimWidth) * 0.5, y,
                aimScale, 235, 235, 235, 255)
            cardBottom = y + aimHeight
        end
    end

    if type(seconds) ~= "number" or seconds < 1 then return end

    local text = tostring(seconds)
    if seconds ~= countdownDigit then
        countdownDigit = seconds
        countdownPhase = 0
    else
        countdownPhase = countdownPhase + 1
    end

    OF.util.in_font(FONT_MENU, function()
        local x, y, scale, alpha = digit_geometry(text, seconds, countdownPhase,
            screenWidth, screenHeight, cardBottom)

        local from = nil
        if countdownPhase > 0 then
            local fx, fy, fs = digit_geometry(text, seconds, countdownPhase - 1,
                screenWidth, screenHeight, cardBottom)
            from = { x = fx, y = fy, scale = fs }
        end

        OF.util.text(text, x, y, scale, 255, 255, 255, alpha, from)
    end)
end

local function go_geometry(text, frames, screenWidth, screenHeight)

    local t = OF.util.clamp(1 - (frames / GO_FRAMES), 0, 1)

    local scale = 2.3 - 0.7 * t
    local alpha = math.floor(255 - 235 * t)
    local width = OF.util.width(text, scale)
    return (screenWidth - width) * 0.5, screenHeight * 0.44, scale, alpha
end

local function render_go()
    if (modes.goFrames or 0) <= 0 then return end
    modes.goFrames = modes.goFrames - 1

    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()

    local text = OF.lang.t("GO!")

    OF.util.in_font(FONT_MENU, function()
        local x, y, scale, alpha = go_geometry(text, modes.goFrames,
            screenWidth, screenHeight)

        local fx, fy, fs = go_geometry(text,
            math.min(modes.goFrames + 1, GO_FRAMES), screenWidth, screenHeight)

        local gold = OF.util.gold()
        OF.util.text(text, x, y, scale, gold.r, gold.g, gold.b, alpha,
            { x = fx, y = fy, scale = fs })
    end)
end

local AIM_SECONDS = 15
local AIM_REMINDER = 5

local aimRole = nil
local aimUntil = 0

function modes.aim_line()
    local mode = modes.current()
    if mode == nil then return "" end

    local role = modes.my_role()
    if mode.aims ~= nil and role ~= "" and mode.aims[role] ~= nil then
        return mode.aims[role]
    end

    if role == "" or role == modes.WAITING then return "" end
    return modes.rules_for(mode) or ""
end

function modes.aim_clock()
    if modes.state() ~= modes.ACTIVE then
        aimRole = nil
        aimUntil = 0
        return
    end

    local role = modes.my_role()
    if role ~= aimRole then
        local first = aimRole == nil
        aimRole = role
        local now = modes.elapsed() or 0
        local hold = now + (first and AIM_SECONDS or AIM_REMINDER)
        if hold > aimUntil then aimUntil = hold end
    end
end

function modes.aim_showing()
    if aimUntil <= 0 then return false end
    return (modes.elapsed() or 0) < aimUntil
end

local STANDING_NAME_ROOM = 120

local STANDING_GAP = "   -   "
function modes.standing_line()
    local mode = modes.current()
    if mode == nil then return "" end
    if mode.resultsBy == "survival" then return "" end

    local board = modes.finishing_order()
    if board == nil or #board < 2 then return "" end

    local place = nil
    for index, row in ipairs(board) do
        if row.localIndex == 0 then
            place = index
            break
        end
    end
    if place == nil then return "" end
    if not OF.util.asks(OF.stats, "ordinal") then return "" end

    if place == 1 then

        local gap = math.floor((board[1].score or 0) - (board[2].score or 0))
        return OF.lang.fill("@ of @", OF.stats.ordinal(place), tostring(#board))
            .. STANDING_GAP
            .. OF.lang.fill("@ ahead", tostring(gap)), true
    end

    local leader = board[1]
    local name = OF.util.fit_name(leader.name, 0.7, STANDING_NAME_ROOM)
    return OF.lang.fill("@ of @", OF.stats.ordinal(place), tostring(#board))
        .. STANDING_GAP
        .. OF.lang.fill("@ leads on @", name,
            tostring(math.floor(leader.score or 0))), false
end

function modes.paused()
    return OF.util.optional("is_game_paused", false) == true
end

local STRIP_SCALE = 0.7
local STRIP_PAUSED_SCALE = 0.95

local STRIP_MARGIN = 40

local function strip_fit(lines, wanted)
    local room = djui_hud_get_screen_width() - STRIP_MARGIN
    if room <= 0 then return STRIP_SCALE end

    local widest = 0
    for _, line in ipairs(lines) do

        local face = OF.util.hud_face(line.text)
        local width = OF.util.in_font(face, function()
            return OF.util.text_size(line.text, OF.util.hud_scale(face, 1.0))
        end)
        if width > widest then widest = width end
    end
    if widest <= 0 then return wanted end

    local fits = room / widest
    if fits >= wanted then return wanted end
    if fits < STRIP_SCALE then return STRIP_SCALE end
    return fits
end

function modes.strip_lines(withAim)
    local lines = {}

    if gGlobalSyncTable.ofGmState == modes.COUNTDOWN
        and gGlobalSyncTable.ofGmCount == 0 then
        table.insert(lines, {
            text = OF.lang.t("Waiting for somebody's level to finish loading"),
            r = 230, g = 190, b = 120 })
    end

    if withAim and (modes.aim_showing() or modes.paused()) then
        local aim = modes.aim_line()
        if aim ~= "" then
            table.insert(lines, { text = OF.lang.t(aim),
                r = 200, g = 200, b = 200 })
        end
    end

    local standing, leading = modes.standing_line()
    if standing ~= "" then
        local line = { text = standing, r = 225, g = 225, b = 225 }
        if leading then
            local gold = OF.util.gold()
            line.r, line.g, line.b = gold.r, gold.g, gold.b
        end
        table.insert(lines, line)
    end

    local scale = STRIP_SCALE
    if modes.paused() then scale = strip_fit(lines, STRIP_PAUSED_SCALE) end
    for _, line in ipairs(lines) do line.scale = scale end
    return lines, scale
end

local function render_bar()
    local mode = modes.current()
    if mode == nil then return end

    local left = OF.lang.t(mode.name)
    local role = modes.my_role()
    if role ~= "" then
        left = left .. "   -   " .. OF.lang.fill("you are @", OF.lang.t(role))
    end

    local right = ""
    local over = modes.overtime_seconds()
    if over ~= nil then

        right = OF.lang.t("OVERTIME") .. "  +" .. modes.clock(over)
    elseif mode.countsUp then
        right = modes.clock(modes.elapsed())
    else
        local seconds = modes.time_left()
        if seconds ~= nil then right = modes.clock(seconds) end
    end

    local text = left
    if right ~= "" then text = text .. "   -   " .. right end

    local r, g, b = 255, 255, 255
    local seconds = modes.time_left()
    if over ~= nil then

        local gold = OF.util.gold()
        r, g, b = gold.r, gold.g, gold.b
    elseif modes.has_deadline() and seconds ~= nil and seconds <= modes.URGENT_SECONDS then
        r, g, b = 255, 96, 96
    end

    local opts = { accent = OF.GOLD }
    local unders = modes.strip_lines(true)

    if #unders > 0 then opts.under = unders end

    OF.util.banner(text, 1.0, r, g, b, 255, opts)
end

function modes.podium()
    local list = {}
    local any = false

    for _, entry in ipairs(modes.played()) do
        local score = gPlayerSyncTable[entry.localIndex].ofScore or 0
        if score > 0 then any = true end
        table.insert(list, {
            localIndex = entry.localIndex,
            name = entry.np.name,
            score = score,
        })
    end
    if not any then return {} end

    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end)
    return list
end

function modes.survival_board()
    local board = {}
    local any = false

    for _, entry in ipairs(modes.played()) do
        local role = modes.role(entry.localIndex)
        local time = gPlayerSyncTable[entry.localIndex].ofGmTime or 0
        local out = modes.OUT_ROLES[role] == true
        if out and time > 0 then any = true end

        local home = nil
        if not out and time > 0 then
            home = time
            any = true
        end

        table.insert(board, {
            localIndex = entry.localIndex,
            name = entry.np.name,

            lasted = out and time or math.huge,
            home = home,
            out = out,
        })
    end

    if not any then return {} end

    table.sort(board, function(a, b)
        if a.lasted ~= b.lasted then return a.lasted > b.lasted end

        local aHome = a.home or math.huge
        local bHome = b.home or math.huge
        if aHome ~= bHome then return aHome < bHome end
        return a.name < b.name
    end)
    return board
end

modes.OUT_ROLES = { out = true }

function modes.finishing_order()
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        return {}, function() return "" end
    end

    local mode = modes.current()
    if mode ~= nil and mode.resultsBy == "splits" and mode.board ~= nil then

        return mode.board(), function(entry) return entry.right end
    end
    if mode ~= nil and mode.resultsBy == "survival" then
        return modes.survival_board(), function(entry)

            if entry.home ~= nil then return modes.clock(entry.home) end
            if not entry.out then return OF.lang.t("lasted it out") end
            return modes.clock(entry.lasted)
        end
    end
    return modes.podium(), function(entry) return tostring(entry.score) end
end

local function place_colour(place)
    if place == 1 then return OF.util.gold().r, OF.util.gold().g, OF.util.gold().b end
    if place == 2 then return 200, 200, 200 end
    if place == 3 then return 205, 140, 90 end
    return 235, 235, 235
end

local function render_moment()
    local mode = modes.current()
    local text, r, g, b

    if mode ~= nil and mode.resultsBy == "survival" then
        local role = modes.my_role()
        if role == "" or role == modes.WAITING then

            text = modes.winner_line()
            r, g, b = 230, 230, 230
        elseif modes.survived(0) then
            text = OF.lang.t("YOU SURVIVED")
            r, g, b = 90, 255, 90
        else
            text = OF.lang.t("YOU ARE OUT")
            r, g, b = 255, 60, 60
        end
    else
        text = modes.winner_line()
        r, g, b = OF.util.gold().r, OF.util.gold().g, OF.util.gold().b
    end

    if text == nil or text == "" then return end

    local scale = 1.6
    local width, height = OF.util.text_size(text, scale)
    local screenWidth = djui_hud_get_screen_width()
    local y = djui_hud_get_screen_height() * 0.42
    OF.util.text(text, (screenWidth - width) * 0.5, y, scale, r, g, b, 255)

    local decided = modes.decided_line()
    if decided ~= "" then
        local small = 0.9
        local dWidth = OF.util.text_size(decided, small)
        OF.util.text(decided, (screenWidth - dWidth) * 0.5,
            y + height + 6, small, 235, 235, 235, 255)
    end
end

local function render_results()

    local winner = modes.winner_line()

    local screenWidth = djui_hud_get_screen_width()
    local y = djui_hud_get_screen_height() * 0.32

    local bottom = OF.util.final_headline(winner, y)

    local decided = modes.decided_line()
    if decided ~= "" then
        local small = 1.0
        local dWidth, dHeight = OF.util.text_size(decided, small)
        bottom = bottom + 8
        OF.util.text(decided, (screenWidth - dWidth) * 0.5, bottom, small,
            235, 235, 235, 255)
        bottom = bottom + dHeight
    end

    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then return end

    local board, right = modes.finishing_order()
    if #board == 0 then return end

    local rowScale = 1.0
    local lineHeight = OF.util.line_height(rowScale) + 8
    local top = bottom + 26

    local shown = math.min(#board, OF.util.rows_that_fit(top, lineHeight))

    local widest = 0
    for place, entry in ipairs(board) do
        if place > shown then break end
        local lineWidth = OF.util.named_width(place .. ".  ",
            OF.util.shorten(entry.name, 14), "   " .. right(entry), rowScale)
        if lineWidth > widest then widest = lineWidth end
    end

    OF.util.plate((screenWidth - widest) * 0.5 - 16, top - 8,
        widest + 32, lineHeight * shown + 14)

    for place, entry in ipairs(board) do
        if place > shown then break end
        local r, g, b = place_colour(place)

        local prefix = place .. ".  "
        local shown = OF.util.shorten(entry.name, 14)
        local suffix = "   " .. right(entry)
        local lineWidth = OF.util.named_width(prefix, shown, suffix, rowScale)
        OF.util.text_named(prefix, shown, suffix, (screenWidth - lineWidth) * 0.5,
            top + (place - 1) * lineHeight, rowScale, r, g, b, 255)
    end
end

local function render_nonstop()
    if not modes.nonstop() then return end

    local lines = {}
    local left = modes.nonstop_seconds()
    if left ~= nil and modes.state() == modes.OFF then
        local gold = OF.util.gold()
        table.insert(lines, { text = OF.lang.fill("Next round in @", tostring(left)),
                              r = gold.r, g = gold.g, b = gold.b })
    end
    if OF.perms.can("speedrun") then
        table.insert(lines, { text = OF.lang.fill("/@ to stop the rotation",
            modes.NONSTOP_COMMAND), r = 200, g = 200, b = 200 })
    end
    if #lines == 0 then return end

    local scale = 0.7
    local screenWidth = djui_hud_get_screen_width()

    for at = #lines, 1, -1 do
        local line = lines[at]
        local width, height = OF.util.text_size(line.text, scale)
        local y = OF.util.hud_claim_low(height, 5)
        OF.util.plate(screenWidth - width - 26, y - 5, width + 16, height + 10)
        OF.util.text(line.text, screenWidth - width - 18, y, scale,
            line.r, line.g, line.b, 255)
    end
end

local function render_strip()
    if modes.state() == modes.ACTIVE then return end

    local lines = modes.strip_lines(false)
    if #lines == 0 then return end

    local head = table.remove(lines, 1)
    local opts = { accent = OF.GOLD }
    if #lines > 0 then opts.under = lines end
    OF.util.banner(head.text, head.scale, head.r, head.g, head.b, 255, opts)
end

local function render_out()
    if modes.state() ~= modes.ACTIVE then return end

    if OF.util.asks(OF.spectate, "is_active") and OF.spectate.is_active() then
        return
    end

    local mode = modes.current()
    if mode ~= nil and mode.saysOut == true then return end

    local word = nil
    if modes.role(0) == "out" then
        word = "You are out - the round plays on"
    elseif not OF.util.can_play(0) then
        word = "You are sitting this round out"
    end
    if word == nil then return end

    OF.util.banner_low(OF.lang.t(word), 0.9, 230, 230, 230, 255)
end

local function render()
    local state = modes.state()

    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    render_nonstop()

    if state == modes.OFF then return end

    render_strip()
    render_out()

    if state == modes.COUNTDOWN then
        render_countdown()
    elseif state == modes.ACTIVE then
        render_bar()
        local mode = modes.current()
        if mode ~= nil and mode.hud ~= nil then mode.hud() end

        render_go()
    elseif state == modes.MOMENT then
        render_moment()
    elseif state == modes.RESULTS then
        render_results()
    end
end

local function scenery_update()

    modes.aim_clock()

    modes.settle_stillness()

    modes.settle_ending()

    modes.settle_role_grace()
    if modes.state() == modes.OFF then return end
    local mode = modes.current()
    if mode ~= nil and mode.scenery ~= nil then mode.scenery() end
end

hook_event(HOOK_UPDATE, register_with_of_net)
hook_event(HOOK_UPDATE, host_update)

hook_event(HOOK_UPDATE, nonstop_update)
hook_event(HOOK_UPDATE, local_update)
hook_event(HOOK_UPDATE, scenery_update)

function modes.may_leave_level()
    if not modes.is_running() then return true end

    if modes.strandedFrom then return true end

    local playing = modes.current()
    if playing ~= nil and playing.wholeGame then return true end

    local role = modes.my_role()
    if role == "" or role == modes.WAITING then return true end
    if not OF.util.can_play(0) then return true end

    if modes.is_out(0) then return true end

    return false
end

modes.roundLevel = nil

local function also_list(held)
    local list = {}
    for other in pairs((held or {}).also or {}) do table.insert(list, other) end
    return list
end

local REJOIN_GRACE = 90
local REJOIN_TRIES = 4

local insideBefore = false

local returnTo = nil

local heldOutFor = 0
local rejoinTries = 0

modes.strandedFrom = false

local throwBack = nil

function modes.owed_throw_back()
    return throwBack
end

function modes.rejoin_update()
    local held = modes.roundLevel
    if held == nil or modes.strandedFrom then
        heldOutFor = 0
        return false
    end
    if modes.may_leave_level() then
        heldOutFor = 0
        return false
    end

    local np = gNetworkPlayers[0]

    if np == nil or np.currLevelNum == nil or np.currLevelNum == 0 then
        heldOutFor = 0
        return false
    end

    if throwBack ~= nil then
        local area = throwBack
        throwBack = nil
        if OF.net.warp_local(held.level, area, held.act, also_list(held)) then
            heldOutFor = 0
            return true
        end

        modes.hold_here(held.level, held.area, held.act, also_list(held))

        insideBefore = false
    end

    if modes.holds_level(np.currLevelNum) then
        heldOutFor = 0
        rejoinTries = 0

        insideBefore = true
        return false
    end

    heldOutFor = heldOutFor + 1

    local grace = insideBefore and 0 or REJOIN_GRACE
    if heldOutFor < grace then return false end
    heldOutFor = 0

    local aimed = held.area
    if insideBefore then
        insideBefore = false
        local spot = modes.return_spot(held.level)
        if spot ~= nil then
            aimed = spot.area
            returnTo = { area = spot.area, x = spot.x, y = spot.y, z = spot.z }
        end
    end

    rejoinTries = rejoinTries + 1
    if rejoinTries > REJOIN_TRIES then
        modes.strandedFrom = true
        OF.notify.show("The round's level will not let you in.", "bad", 6)

        OF.notify.show(
            "Modes tab, Who is taking part: untick yourself to sit out.",
            "info", 7)
        return false
    end

    if rejoinTries == 1 then
        OF.notify.show("Taking you to the round", "info", 4)
    end
    if OF.net.warp_local(held.level, aimed, held.act, also_list(held)) then
        return true
    end

    returnTo = nil
    if aimed ~= held.area then
        modes.hold_here(held.level, held.area, held.act, also_list(held))
        OF.net.warp_local(held.level, held.area, held.act, also_list(held))
    end
    return true
end

local stoodAt = nil

local escapes = 0
local settledFor = 0
local SETTLED = 90
local ESCAPES_BEFORE_GIVING_UP = 2

local diedInside = false

local diedAt = nil

function modes.mark_died_inside()
    diedInside = true

    diedAt = nil
    if stoodAt ~= nil then
        diedAt = { level = stoodAt.level, area = stoodAt.area,
                   x = stoodAt.x, y = stoodAt.y, z = stoodAt.z }
    else

        local m = gMarioStates[0]
        local np = gNetworkPlayers[0]
        if m ~= nil and m.pos ~= nil and np ~= nil then
            diedAt = { level = np.currLevelNum, area = np.currAreaIndex,
                       x = m.pos.x, y = m.pos.y, z = m.pos.z }
        end
    end
    return true
end

function modes.died_inside()
    return diedInside
end

function modes.died_at()
    if diedAt == nil then return nil end
    return { level = diedAt.level, area = diedAt.area,
             x = diedAt.x, y = diedAt.y, z = diedAt.z }
end

function modes.death_spot(level)
    if not diedInside then return nil end

    local mode = modes.current()
    if mode == nil or type(mode.death_place) ~= "function" then return nil end

    if not OF.util.can_play(0) then return nil end

    local ok, at = pcall(mode.death_place, modes.died_at())
    if not ok then
        OF.util.report(false, at)
        return nil
    end
    if type(at) ~= "table" then return nil end
    if type(at.x) ~= "number" or type(at.y) ~= "number"
        or type(at.z) ~= "number" then
        return nil
    end

    if at.level ~= nil and at.level ~= level then return nil end

    local held = modes.roundLevel
    local area = at.area
    if type(area) ~= "number" then
        area = held ~= nil and held.area or 1
    end
    return { area = area, x = at.x, y = at.y, z = at.z }
end

local HELD_BY_SOMETHING_ELSE = ACT_FLAG_INTANGIBLE or 0x00001000

local IN_THE_AIR = ACT_FLAG_AIR or 0x00000800

local function could_be_left_here(m)
    if m == nil or m.pos == nil then return false end
    if OF.util.has_flag(m.action or 0, HELD_BY_SOMETHING_ELSE) then return false end
    if OF.util.has_flag(m.action or 0, IN_THE_AIR) then return false end
    if ACT_BUBBLED ~= nil and m.action == ACT_BUBBLED then return false end

    if m.floor == nil then return false end
    return true
end

function modes.may_be_remembered(m)
    return could_be_left_here(m)
end

function modes.remember_standing(m)
    if modes.roundLevel == nil then
        stoodAt = nil
        settledFor = 0
        return false
    end

    local np = gNetworkPlayers[0]
    if np == nil or not modes.holds_level(np.currLevelNum) then
        settledFor = 0
        return false
    end

    if returnTo ~= nil then
        if m == nil or m.marioObj == nil then return false end
        local want = returnTo
        returnTo = nil
        if np.currAreaIndex == want.area
            and OF.util.asks(OF.doorways, "put_at") then

            OF.doorways.put_at(m, want.x, want.y, want.z)
        end
        return true
    end

    if not could_be_left_here(m) then return false end

    diedInside = false
    diedAt = nil

    stoodAt = {
        level = np.currLevelNum, area = np.currAreaIndex,
        x = m.pos.x, y = m.pos.y, z = m.pos.z,
    }

    settledFor = settledFor + 1
    if settledFor >= SETTLED then escapes = 0 end
    return true
end

function modes.return_spot(level)

    if diedInside then return modes.death_spot(level) end
    if stoodAt == nil then return nil end
    if stoodAt.level ~= level then return nil end
    if escapes > ESCAPES_BEFORE_GIVING_UP then return nil end
    return stoodAt
end

function modes.hold_here(level, area, act, alsoLevels)
    if level == nil then return false end

    local widened = alsoLevels
    if OF.util.asks(OF.lockdown, "castle_also") then
        local playing = modes.current()
        widened = OF.lockdown.castle_also(
            playing ~= nil and playing.key or nil, level, alsoLevels)
    end

    local also = {}
    for _, other in ipairs(widened or {}) do also[other] = true end

    local was = modes.roundLevel
    if was == nil or was.level ~= level then insideBefore = false end
    modes.roundLevel = {
        level = level, area = area or 1, act = act or 1, also = also,
    }
    return true
end

function modes.holds_level(level)
    local held = modes.roundLevel
    if held == nil then return true end
    if level == nil or level == held.level then return true end
    return held.also[level] == true
end

function modes.forget_hold()
    modes.roundLevel = nil

    stoodAt = nil
    returnTo = nil
    escapes = 0
    settledFor = 0

    diedInside = false
    diedAt = nil

    heldOutFor = 0
    rejoinTries = 0

    insideBefore = false
    modes.strandedFrom = false

    throwBack = nil
end

function modes.holding()
    return modes.roundLevel
end

hook_event(HOOK_ON_WARP, function(warpType, levelNum, areaIdx, nodeId, warpArg)
    local held = modes.roundLevel
    if held == nil then return end
    if modes.may_leave_level() then return end
    if modes.holds_level(levelNum) then return end

    OF.notify.show("You are in a round - back you go.", "warn", 4)

    if not diedInside then escapes = escapes + 1 end
    settledFor = 0
    local spot = modes.return_spot(held.level)
    returnTo = spot and {
        area = spot.area, x = spot.x, y = spot.y, z = spot.z,
    } or nil

    throwBack = spot and spot.area or held.area
end)

hook_event(HOOK_USE_ACT_SELECT, function()
    if modes.roundLevel == nil then return end
    if modes.may_leave_level() then return end
    return false
end)

hook_event(HOOK_ON_PAUSE_EXIT, function(usedExitToCastle)
    if modes.may_leave_level() then return end

    OF.notify.show("You are in a round - leaving would put you out of reach.",
        "bad", 6)
    OF.notify.show("Modes tab, Who is taking part: untick yourself, then leave.",
        "info", 7)
    return false
end)

hook_event(HOOK_BEFORE_MARIO_UPDATE, on_before_mario_update)
hook_event(HOOK_ON_HUD_RENDER, render)

local function short_reason(why)

    local text = OF.lang.t("not here")
    if why ~= nil then text = OF.lang.t(tostring(why)) end
    return text:match("^[^.]+") or text
end

function modes.can_start_here(mode)
    if mode == nil then return false, "No such game mode." end

    if #modes.participants() < (mode.minPlayers or 2) then
        return false, OF.lang.fill("needs @ players", mode.minPlayers or 2)
    end

    if mode.playable_here ~= nil then
        local able, why = mode.playable_here()
        if not able then return false, why or OF.lang.t("not here") end
    end
    return true
end

function modes.build_mode_page(panel)
    local key = panel.modeKey
    local mode = key ~= nil and modes.BY_KEY[key] or nil
    if mode == nil then
        return { panel.label_row(OF.lang.t("No such game mode.")),
                 panel.back_row("gamemodes") }
    end

    local rows = { panel.with_help(panel.header_row(OF.lang.t(mode.name)),
        mode.blurb ~= nil and mode.blurb ~= "" and mode.blurb
            or "what this round is, and the press that starts it") }

    local sides = OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
    local blurb = (sides and mode.blurbTeams) or mode.blurb
    if blurb ~= nil and blurb ~= "" then
        table.insert(rows, panel.label_row(OF.lang.t(blurb)))
    end

    local startAt = #rows + 1

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("Maps")),
        "the arena or the level this one runs in"))
    if modes.owns_its_place(mode) then
        table.insert(rows, panel.label_row(
            OF.lang.t("This one brings its own levels")))
    else
        table.insert(rows, panel.with_key(panel.with_help(panel.with_right(
            panel.gated_row("warp_lobby", OF.lang.t("Pick where..."),
                255, 255, 255, function()
                    modes.placeDoor = "gamemode"
                    panel.go("playin")
                end),
            modes.place_label(key)),
            modes.takes_any_level(key)
                and "the fight rooms, or any level in the game"
                or "the swept fight rooms - this one is a fight, so it wants a ring"),
            "gamemode:where"))
    end

    local settings = {}

    local sidesFact = nil
    if mode.teams then
        local minRoom = OF.util.asks(OF.teams, "min_room")
            and OF.teams.min_room() or 4
        if #modes.participants() < minRoom then
            sidesFact = OF.lang.fill(
                "Sides need @ players - this one plays as a free-for-all",
                tostring(minRoom))
        elseif OF.util.asks(OF.teams, "by_nature")
            and OF.teams.by_nature(mode) then

            sidesFact = OF.lang.t("Always two sides - it is a team game")
        else

            table.insert(settings, panel.with_key(panel.with_help(
                panel.host_row("speedrun",
                panel.tick(modes.wantSides, OF.lang.t("Teams")),
                255, 220, 120, function()

                    local ok, why, feature = modes.set_sides(not modes.wantSides)
                    OF.util.report(ok, why, feature)
                end),

                OF.lang.fill("With sides: @", modes.sides_effect(mode))),
                "gamemode:sides"))
        end
    else
        sidesFact = OF.lang.t("No sides - everybody for themselves")
    end

    local caps = modes.caps(mode)
    if caps.tiebreak then

        table.insert(settings, panel.with_key(panel.with_help(panel.with_right(
            panel.host_row("speedrun", OF.lang.t("A tied round"),
            255, 220, 120, function()

                OF.util.report(modes.set_tiebreak(not modes.tiebreakOn))
            end),
            modes.tiebreakOn and OF.lang.t("settled on the ladder")
                or OF.lang.t("left as a draw")),
            "time in front, then who got in front first, then rounds "
                .. "held - and a draw when all three are level"),
            "gamemode:tiebreak"))
    end

    if mode.target ~= nil then

        table.insert(settings, panel.with_key(panel.with_help(panel.with_right(
            panel.gated_row("speedrun", modes.target_asks(mode),
                255, 220, 120, function()
                    modes.step_target(key)
                end),
            tostring(modes.target_for(key))),
            "the number this round ends on - press to step it"),
            "gamemode:target"))
    end

    local options = modes.options_of(mode)

    local mine = type(mode.build_rows) == "function" and mode.build_rows(panel) or {}
    for _, option in ipairs(options) do
        local optKey = option.key
        local choice = modes.option_choice(key, optKey)
        table.insert(settings, panel.with_key(panel.with_help(panel.with_right(
            panel.gated_row("speedrun", OF.lang.t(option.name),
            255, 220, 120, function()

                local ok, why, feature = modes.step_option(key, optKey)
                OF.util.report(ok, why, feature)
            end),
            OF.lang.t(choice ~= nil and choice.name or "")),

            OF.lang.t((choice ~= nil and choice.help) or option.help or "")),
            "gamemode:" .. optKey))
    end
    for _, built in ipairs(mine) do
        table.insert(settings, built)
    end

    if #settings > 0 then
        table.insert(rows, panel.with_help(
            panel.header_row(OF.lang.t("Settings")),
            "what a host can change about this one before it starts"))
        for _, built in ipairs(settings) do
            table.insert(rows, built)
        end
    end

    local plays = {}
    if mode.how ~= nil and mode.how ~= "" then
        for line in string.gmatch(mode.how, "[^\n]+") do
            table.insert(plays, panel.label_row(OF.lang.t(line)))
        end
    end

    if mode.terms ~= nil then
        local ok, said = pcall(mode.terms)
        if ok and said ~= nil and said ~= "" then
            table.insert(plays, panel.label_row(
                OF.lang.fill("Ends on: @", said)))
        end
    end
    table.insert(plays, panel.label_row(OF.lang.fill("Needs @ player(s)",
        tostring(mode.minPlayers or 2))))
    if sidesFact ~= nil then
        table.insert(plays, panel.label_row(sidesFact))
    end

    table.insert(plays, panel.label_row(modes.opening_line(key)))

    table.insert(plays, panel.label_row(modes.kept_rules_line(key)))

    if caps.overtime then
        table.insert(plays, panel.label_row(
            OF.lang.t("Runs overtime while the side behind can still score")))
    end
    if not caps.tiebreak then
        table.insert(plays, panel.label_row(
            OF.lang.t("A race - the clock decides it, never a draw")))
    end

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("How it plays")),
        "what this mode does, in the words its own author wrote"))
    for _, built in ipairs(plays) do
        table.insert(rows, built)
    end

    local able, why = modes.can_start_here(mode)
    if not able then

        local cannot = panel.label_row(short_reason(why))
        cannot.walk = true
        table.insert(rows, panel.rest_row(panel.with_help(cannot,
            mode.blurb ~= nil and mode.blurb ~= "" and mode.blurb
                or "cannot start as the lobby stands - the reason is on the row")))
    else

        table.insert(rows, panel.rest_row(panel.with_help(panel.gated_row("speedrun",
            OF.lang.fill("Start @", OF.lang.t(mode.name)),
            140, 255, 160, function()

                if OF.util.report(modes.start(key, nil, 0)) then panel.close() end
            end),
            "warps everybody in, deals the roles and runs the countdown")))
    end

    if #rows > startAt then
        local last = table.remove(rows)
        table.insert(rows, startAt, last)
    end

    table.insert(rows, panel.back_row("gamemodes"))
    return rows
end

function modes.build_where_page(panel)
    local key = panel.modeKey
    local mode = key ~= nil and modes.BY_KEY[key] or nil
    local rows = {}

    if mode ~= nil and modes.owns_its_place(mode) then
        table.insert(rows, panel.label_row(
            OF.lang.fill("@ brings its own levels.", OF.lang.t(mode.name))))
        table.insert(rows, panel.back_row())
        return rows
    end

    table.insert(rows, panel.with_right(panel.label_row(
        mode ~= nil
            and OF.lang.fill("@ is played in", OF.lang.t(mode.name))
            or OF.lang.t("The next round is played in")),
        modes.place_label(key)))

    local adrift = modes.place_adrift(key)
    if adrift ~= nil then
        table.insert(rows, panel.label_row(OF.lang.fill(
            "@ was picked for another mode and this one does not go there.",
            OF.lang.t(adrift))))
    end

    local kind = modes.maps_of(mode)

    local function level_row(entry, why)
        local on = modes.levelChoice ~= nil
            and modes.levelChoice.level == entry.level
            and (modes.levelChoice.area or 1) == (entry.area or 1)
        return panel.with_key(panel.with_help(
            panel.gated_row("warp_lobby",
                panel.tick(on, entry.name), 255, 255, 255, function()
                    if on then
                        modes.set_level(nil)
                    else
                        modes.set_level(entry)
                    end
                    panel.go(modes.placeDoor)
                end), why), "playin:lv" .. tostring(entry.level)
                    .. "a" .. tostring(entry.area or 1))
    end

    if kind == "surveyed" then
        local walked = modes.surveyed_levels(key)
        if #walked == 0 then
            table.insert(rows, panel.label_row(
                OF.lang.t("Nowhere has been surveyed for this yet.")))
        else
            table.insert(rows, panel.header_row(
                OF.lang.t("The levels it has places in")))
        end

        local why = OF.lang.t(
            "a level he walked, with this mode's places written down in it")
        for _, entry in ipairs(walked) do
            table.insert(rows, level_row(entry, why))
        end
    end

    if modes.takes_any_level(key) then
        table.insert(rows, panel.header_row(OF.lang.t("Anywhere in the game")))

        local held = modes.levelChoice
        if held ~= nil and modes.accepts_level(key, held) then
            local drawn = false
            if modes.takes_main_courses(key) then
                for _, entry in ipairs(modes.course_levels()) do
                    if entry.level == held.level
                        and (entry.area or 1) == (held.area or 1) then
                        drawn = true
                    end
                end
            end
            if not drawn then
                table.insert(rows, panel.with_key(panel.with_help(
                    panel.gated_row("warp_lobby",
                        panel.tick(true, modes.level_label()),
                        255, 255, 255, function()
                            modes.set_level(nil)
                            panel.go(modes.placeDoor)
                        end),
                    "picked through the door below - press it to pick nothing"),
                    "playin:picked"))
            end
        end

        table.insert(rows, panel.with_key(panel.with_help(panel.with_right(
            panel.gated_row("warp_lobby", OF.lang.t("Pick a level..."),
                255, 255, 255, function()
                    panel.levelMode = "round"
                    panel.go("groups")
                end),
            modes.levelChoice ~= nil and modes.level_label() or ""),
            "every course, every secret and every place the lobby has marked"),
            "playin:level"))
    end

    if modes.takes_main_courses(key) then
        local courses = modes.course_levels()
        if #courses > 0 then
            table.insert(rows, panel.header_row(
                OF.lang.t("The main courses")))
        end

        local why = OF.lang.t("one of the fifteen courses, and this mode is at home in any of them")
        for _, entry in ipairs(courses) do
            table.insert(rows, level_row(entry, why))
        end
    end

    if kind == "none" then
        table.insert(rows, panel.label_row(
            OF.lang.t("Its own list of levels is still being built.")))
    end

    local rooms = modes.rooms_for(key)
    if #rooms > 0 then
        table.insert(rows, panel.header_row(OF.lang.t("The fight rooms")))
    end

    local suits = {}
    if OF.util.asks(OF.arena, "for_mode") and key ~= nil then
        for _, placeKey in ipairs(OF.arena.for_mode(key)) do suits[placeKey] = true end
    end

    for _, place in ipairs(rooms) do
        local placeKey = place.key

        local tried = OF.util.asks(OF.arena, "custom_missing")
            and OF.arena.custom_missing(place) or nil
        if tried ~= nil then

            local named = panel.label_row(place.name)
            named.walk = true
            table.insert(rows, panel.with_help(named,
                "a level you exported yourself, and this machine has not got it"))
        else
            local on = modes.arenaChoice == placeKey

            local why = place.blurb
            if suits[placeKey] and why ~= nil and why ~= "" then
                why = OF.lang.fill("@ - and it is one this mode suits", why)
            end
            table.insert(rows, panel.with_key(panel.with_help(
                panel.gated_row("warp_lobby", panel.tick(on, place.name),
                    255, 255, 255, function()
                        if modes.arenaChoice == placeKey then
                            modes.arenaChoice = nil
                        else
                            modes.arenaChoice = placeKey
                            modes.levelChoice = nil
                        end
                        panel.go(modes.placeDoor)
                    end),
                why), "playin:" .. placeKey))
        end
    end

    local picked = modes.place_for(key) ~= nil
    local hasDefault = modes.default_place(key) ~= nil
    local chooses = (not picked and hasDefault) and modes.place_label(key) or nil
    table.insert(rows, panel.header_row(OF.lang.t("Or nowhere in particular")))
    table.insert(rows, panel.with_key(panel.with_help(panel.with_right(
        panel.gated_row("warp_lobby",

        panel.tick(not picked,
            hasDefault and OF.lang.t("Let the mode choose")
                or OF.lang.t("Wherever the lobby is standing")),
        255, 255, 255, function()
            modes.arenaChoice = nil
            modes.levelChoice = nil
            panel.go(modes.placeDoor)
        end), chooses or ""),
        hasDefault

            and "the first place on this mode's own list, or the one the lobby is already standing in"
            or "no warp at all - the round starts in whatever level the lobby is in"),
        "playin:here"))

    table.insert(rows, panel.back_row())
    return rows
end

modes.LATE = {
    bank = { join = "play",
        why = "The coins are spread over the room and the bank is where the "
           .. "round left it, so an arrival starts on nought like everybody "
           .. "did and has less time to spend it in." },
    bossrush = { join = "play",
        why = "A latecomer is put on the stage the round has reached, in a "
           .. "copy of it that is theirs alone, and every boss they did not "
           .. "fight is a split they will never have." },
    bounty = { join = "play",
        why = "Nobody dies here and the score is knockdowns, so there is "
           .. "nothing banked to arrive in front of - only fewer seconds left "
           .. "to land one in." },
    coinrush = { join = "play",
        why = "The rain falls for everybody and the tally starts at nought on "
           .. "the machine that arrived, so a late start is a shorter round "
           .. "rather than a better one." },
    crown = { join = "play",
        why = "They arrive as a hunter with no crown, which is the side of "
           .. "this round that is behind by definition." },
    ctf = { join = "play",
        why = "They are put on a side before the mode is asked, and a fighter "
           .. "who has carried no flag is the weakest thing on it." },
    domination = { join = "play",
        why = "The three points are held rather than won, so an arrival owns "
           .. "none of them and the seconds they missed are already counted." },

    flood = { join = "watch",
        why = "Late enough in a round there is no hard part left to walk into. "
           .. "The arrival is landed at the surveyed start, which is a fixed "
           .. "point on the level floor, and the water only ever rises - so "
           .. "after enough minutes they are put down under a plate they can "
           .. "see coming and cannot climb into. A death with a delay on it." },
    hexagone = { join = "watch",
        why = "The floor is whatever is left of the floor. An arrival is "
           .. "dropped onto tiles other people spent the round not falling "
           .. "through, and this is the one mode that already said so in its "
           .. "own file - which is now belt and braces rather than a "
           .. "duplicate: this row is what the framework acts on, and the "
           .. "mode's own refusal still stands behind a row edited by "
           .. "mistake." },
    hexheat = { join = "watch",
        why = "The window shortens every call and never lengthens, so an "
           .. "arrival is dropped into a round already at its fastest with no "
           .. "idea which colour is which. They watch this one and play the "
           .. "next, which is a shorter wait here than in most: a board that "
           .. "has reached its floor is minutes from its last call." },
    hideseek = { join = "play",
        why = "They arrive as a seeker, and a seeker who has not been looking "
           .. "is the side of this round with the least in hand." },
    hotpotato = { join = "watch",
        why = "Out is out here, and the fuse is on whoever is nearest when it "
           .. "runs down. Somebody who walks in at four seconds has dodged the "
           .. "whole round without dodging anything." },
    koth = { join = "play",
        why = "The hill pays by the second and an arrival has banked none of "
           .. "them, so standing on it now only starts their clock." },
    laststanding = { join = "watch",
        why = "Three lives each. Walking in with all three against a lobby that "
           .. "is down to one is the round handed to whoever joined last." },
    line = { join = "watch",
        why = "Not about the arrival's chances, which the course does not care "
           .. "about, but about the round ending: it is over when nobody is "
           .. "left who could still reach the flagpole, so a stream of "
           .. "arrivals refills the list it is waiting on and the round never "
           .. "closes." },
    logroll = { join = "watch",
        why = "The log is already turning and the slots along its crest were "
           .. "dealt at GO. Somebody dropped onto a surface at full spin is not "
           .. "late for the round, they are a fall with their name on it - and "
           .. "the mode already says so in its own file, where `late_join` hands "
           .. "an arrival the out role rather than a place in the row." },
    manhunt = { join = "play",
        why = "They arrive as a hunter, never as the runner, and the runner's "
           .. "head start has already been spent." },
    meltdown = { join = "watch",
        why = "The same as Red Light, Green Light and for the same reason: the "
           .. "round waits for everybody who could still get home, and an "
           .. "arrival is one more of them. The floor going out from under "
           .. "them is not the objection - the round not ending is." },
    murder = { join = "play",
        why = "They arrive innocent and are told nothing, which is what every "
           .. "innocent is told - and one more person to read is the mode "
           .. "getting harder for the murderer rather than easier." },
    secretrun = { join = "play",
        why = "Their own copy of their own course, entered where the round has "
           .. "reached, and every course they did not clear is a split they "
           .. "will never have." },
    shellrace = { join = "watch",
        why = "A lap race that ends when nobody is left running it. Somebody "
           .. "who walks in has a whole circuit to go and the round has to "
           .. "wait out every one of them, so arrivals stretch a round rather "
           .. "than shorten it." },
    simon = { join = "play",
        why = "Every call is judged fresh against the whole lobby, so the call "
           .. "after they arrive is the first one they can fail and the ones "
           .. "before it are already counted against everybody else." },
    spots = { join = "watch",
        why = "The number of circles was laid against the number of players at "
           .. "the start. One more body chasing the same circles changes who "
           .. "goes out, for everybody who was already here." },
    sumo = { join = "watch",
        why = "The ring is pinned where the round started and out is out. A "
           .. "body that arrives inside it can shove a survivor over the edge "
           .. "without ever having survived anything itself." },
    zombies = { join = "play",
        why = "They arrive infected, for the reason the mode's own file gives: "
           .. "a stream of clean arrivals would keep alive a round that cannot "
           .. "end while one survivor is left." },
}

function modes.late(key)
    if key == nil then
        local mode = modes.current()
        if mode == nil then return nil end
        key = mode.key
    end
    if type(key) ~= "string" then return nil end
    return modes.LATE[key]
end

function modes.takes_latecomers(key)
    local row = modes.late(key)
    return row ~= nil and row.join == "play"
end

function modes.refuses_latecomers(key)
    local row = modes.late(key)
    return row ~= nil and row.join == "watch"
end

modes.WHEN_OUT = {
    bank = { out = "none",
        why = "Nobody is out of a collecting round. A death is a walk back to "
           .. "the coins, and the bank is where it always was." },
    bossrush = { out = "none",
        why = "A runner who cannot beat a boss is conceded the stage and moved "
           .. "to the next one - the course would rather carry everybody than "
           .. "leave anybody behind it." },
    bounty = { out = "none",
        why = "Knockdowns are the score and nobody dies here at all, so there "
           .. "is no state to be in but playing." },
    coinrush = { out = "none",
        why = "The rain falls on everybody until the clock runs out. A round "
           .. "nobody can lose has nobody to put out." },
    crown = { out = "none",
        why = "Losing the crown is losing a lead, not losing the round: the "
           .. "player it was punched off is a hunter again a frame later." },
    ctf = { out = "none",
        why = "Being put down costs a carry and a few seconds on the floor. "
           .. "Both sides keep every player they started with." },
    domination = { out = "none",
        why = "The points are held rather than won and a death only takes you "
           .. "off one of them, so nobody ever stops being on a side." },
    flood = { out = "ghost",
        why = "The water is the hazard and a ghost is refused it, so somebody "
           .. "the flood took can swim about in the level it is filling and "
           .. "watch it fill. Sitting in a camera above a rising tide is the "
           .. "same picture with the player taken out of it." },
    hexagone = { out = "ghost",
        why = "They went through the floor, which is as far from the round as "
           .. "this mod can put anybody - so the body is what brings them back "
           .. "into the lobby. Nothing they can do from under a burning stack "
           .. "reaches the people still on it." },
    hexheat = { out = "ghost",
        why = "The board is the whole of what there is to look at and it is "
           .. "shrinking. Walking the dead platforms is a better seat than any "
           .. "camera, and a ghost cannot stand on a colour to claim it." },
    hideseek = { out = "watch",
        why = "A found hider who can walk is a found hider who can walk to "
           .. "where the next one is hiding, and the seeker only has to notice "
           .. "them doing it. This round is made of information, so the "
           .. "framework guarantees no body here and leaves what a caught "
           .. "player keeps to the mode that dealt the roles." },
    hotpotato = { out = "ghost",
        why = "Already how this one plays and the row is where the reason "
           .. "lives: the bomb cannot be passed to somebody who cannot be "
           .. "touched, so an out player walking with the pack costs the round "
           .. "nothing and is the best view of it in the level." },
    koth = { out = "none",
        why = "The hill pays by the second to whoever is on it. A death is a "
           .. "walk back up." },
    laststanding = { out = "ghost",
        why = "Three lives spent is the earliest anybody goes out here and the "
           .. "round can run for minutes after it. The fists are off for a "
           .. "ghost in both directions, so the only thing they can still do "
           .. "is be there among them." },
    logroll = { out = "ghost",
        why = "They are off the log and set down under it, and the log is the "
           .. "whole of what there is to look at. A ghost cannot be shoved back "
           .. "onto it and cannot shove anybody off it, so walking about "
           .. "underneath is the best seat in the level and costs the round "
           .. "nothing." },
    line = { out = "ghost",
        why = "Moving on red is the one mistake this round punishes, and under "
           .. "the option that puts you out it costs the whole of it. A body "
           .. "that can walk back down the course is the difference between "
           .. "being out and being gone." },
    manhunt = { out = "none",
        why = "The runner being caught is the ending. A hunter is never out, "
           .. "and a hunt whose runner leaves is abandoned rather than "
           .. "survived." },
    meltdown = { out = "none",
        why = "Nobody is put out of this round any more. The metal never runs "
           .. "out, so the lava throws rather than burns, and the only thing a "
           .. "runner can lose is the clock. The row said `ghost` for as long "
           .. "as the mode had a fuel gauge - out of metal was out of the "
           .. "round - and PLAYTEST-0908 50 took the gauge away." },
    murder = { out = "watch",
        why = "The dead are muted because this round is made of who knows "
           .. "what, and a body that can walk is the same channel with no words "
           .. "in it - a ghost standing next to the murderer says it just as "
           .. "clearly. So the framework guarantees nothing here and the mode "
           .. "keeps the decision about what a dead innocent is allowed to be." },
    secretrun = { out = "none",
        why = "Every runner has their own copy of their own course, so there "
           .. "is nobody to be put out by and a stage nobody clears is "
           .. "conceded to the whole lobby." },
    shellrace = { out = "none",
        why = "The ride is immune to lava and water and nobody can touch "
           .. "anybody, so the clock is the only thing anybody can lose." },
    simon = { out = "ghost",
        why = "Caught out on a call and the calls carry on without you, "
           .. "sometimes for minutes. Watching the lobby try to do as it is "
           .. "told is most of the fun of this one, and it is better watched "
           .. "from among them than from a camera." },
    spots = { out = "ghost",
        why = "One circle fewer every round, so the last four are quick and "
           .. "the first player out waits through all of them. A ghost cannot "
           .. "stand in a circle or crowd one, which is the whole of what "
           .. "would have to be true for a body to matter here." },
    sumo = { out = "ghost",
        why = "Shoved out of the ring, and a ghost cannot shove or be shoved - "
           .. "the ghost pair is what `resolve_player_collision` refuses. So "
           .. "the ring is safe from them and they get to stand at the edge of "
           .. "it, which is where anybody knocked out of a bout wants to be." },
    zombies = { out = "none",
        why = "Being caught changes which side you are on and hands you the "
           .. "job of catching the rest. Nobody is ever out of this one, which "
           .. "is the whole reason it can run as long as it does." },
}

function modes.when_out(key)
    if key == nil then
        local mode = modes.current()
        if mode == nil then return nil end
        key = mode.key
    end
    if type(key) ~= "string" then return nil end
    return modes.WHEN_OUT[key]
end

function modes.ghosts(key)
    local row = modes.when_out(key)
    return row ~= nil and row.out == "ghost"
end

local ghosting = false

function modes.ghosting()
    return ghosting
end

function modes.forget_ghost()
    ghosting = false
end

function modes.settle_ghost()
    local want = modes.state() == modes.ACTIVE
        and modes.is_out(0)
        and modes.ghosts()
    if want then
        ghosting = true
        modes.set_ghost(true)
    elseif ghosting then
        ghosting = false
        modes.set_ghost(false)
    end
end

local function nonstop_row(panel)
    local on = modes.nonstop()
    return panel.with_help(panel.gated_row("speedrun",
        panel.tick(on, OF.lang.t("Keep the rounds coming")),
        255, 255, 255, function()

            OF.util.report(modes.set_nonstop(not on, 0))
        end),
        OF.lang.fill("five seconds after each round, the next map - stop it with /@",
            modes.NONSTOP_COMMAND))
end

function modes.build_page(panel)
    local rows = {}

    local wantModes = false

    if modes.is_running() then
        local mode = modes.current()
        table.insert(rows, panel.label_row(OF.lang.fill("Running: @",
            OF.lang.t(mode and mode.name or "a round"))))
        table.insert(rows, panel.with_help(panel.gated_row("end_round",
            OF.lang.t("Stop the round"), 255, 140, 90,
            function()

                if not OF.util.report(modes.stop(false, 0)) then return end
                panel.close()
            end),
            "ends it now - the lobby is handed back everything the round borrowed"))
        table.insert(rows, nonstop_row(panel))
    else

        if modes.nonstop() then
            table.insert(rows, nonstop_row(panel))
        end
        wantModes = true
    end

    if OF.util.asks(OF.rounds, "build_page") then
        local queued = OF.util.asks(OF.rounds, "count") and OF.rounds.count() or 0
        table.insert(rows, panel.with_help(panel.gated_row("speedrun",
            OF.util.asks(OF.rounds, "is_running") and OF.rounds.is_running()
                and OF.lang.fill("Round queue: running, @ to go", queued)
                or OF.lang.fill("Round queue (@ lined up)...", queued),
            255, 255, 255, function() panel.go("queue") end),
            "line up several rounds and the lobby plays them one after another"))
    end

    if wantModes then
        table.insert(rows, panel.label_row(
            OF.lang.t("Everybody joins unless they sat out.")))

        for _, key in ipairs(OF.EXPECTED_MODES or {}) do
            if modes.BY_KEY[key] == nil then

                local missing = panel.label_row(
                    OF.lang.fill("@ - did not load", key))
                missing.walk = true
                table.insert(rows, panel.with_help(missing,
                    "this build ships the mode and its file threw on the way in"))
            end
        end
    end

    if wantModes then
        for _, group in ipairs(modes.grouped()) do

            table.insert(rows, panel.with_help(
                panel.header_row(OF.lang.t(group.name)), group.help))
            for _, mode in ipairs(group.modes) do
                local key = mode.key

                local able, why = modes.can_start_here(mode)

                local row = panel.gated_row("speedrun",
                    OF.lang.t(mode.name) .. "...",
                    255, 255, 255, function()
                        panel.modeKey = key
                        panel.go("gamemode")
                    end)
                if not able then row = panel.with_right(row, short_reason(why)) end
                table.insert(rows, panel.with_help(row, mode.blurb))
            end
        end
    end

    table.insert(rows, panel.back_row())
    return rows
end

local function on_packet_receive(data)
    if data == nil then return end
    if data.ofp ~= modes.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end

    local wanted = data.go == "stop" and "end_round" or "speedrun"
    if OF.perms.tier(asker) < OF.perms.required(wanted) then
        OF.notify.send_to(askerGlobal, "Your rank cannot do that.", "bad", 5)
        return
    end

    if data.go == "stop" then
        if not modes.stop(false, asker) then
            OF.notify.send_to(askerGlobal, "Nothing running.", "warn", 4)
        end
        return
    end

    if data.go == "nonstop" then
        local ok, why = modes.set_nonstop(data.key == "on", asker)
        if not ok then
            OF.notify.send_to(askerGlobal, why or "That would not work.", "bad", 5)
        end
        return
    end

    if data.go ~= "start" then return end
    if type(data.key) ~= "string" then return end

    if type(data.arena) == "string" then
        modes.arenaChoice = data.arena
        modes.levelChoice = nil
    elseif type(data.lvl) == "number" then
        modes.set_level({ level = data.lvl, area = data.ar, act = data.act,
            name = OF.lang.t("their pick") })
    end

    local ok, reason = modes.start(data.key, nil, asker)
    if not ok then
        OF.notify.send_to(askerGlobal, reason or "That would not start.", "bad", 5)
        return
    end
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)

hook_chat_command("nonstop",
    "- stop the rounds rotating, or start them", function()

        return OF.util.report(modes.set_nonstop(not modes.nonstop(), 0))
    end)
