OF = OF or {}
OF.gamemodes = OF.gamemodes or {}

local modes = OF.gamemodes

modes.OFF       = 0
modes.COUNTDOWN = 1
modes.ACTIVE    = 2
modes.RESULTS   = 3

modes.LOBBY     = 5

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

function modes.round_to(value, step)
    step = step or 1
    return math.floor(value / step + 0.5) * step
end
function modes.auto_target(mode, players, options)
    local fallback = mode ~= nil and mode.target ~= nil and mode.target.default or 0
    local given = math.floor(tonumber(options ~= nil and options.target or fallback) or fallback)
    if mode == nil or mode.target == nil or type(mode.target.auto) ~= "function" then
        return given
    end
    if modes.targetChoice[mode.key] ~= nil then return given end
    if options ~= nil and options.targetNamed then return given end
    local n = #(players or {})
    local teams = OF.teams ~= nil and type(OF.teams.in_play) == "function"
        and OF.teams.in_play() == true
    local value = mode.target.auto(math.max(1, n), teams, teams and math.ceil(n / 2) or n)
    if type(value) ~= "number" then return given end
    return math.floor(value)
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

function modes.set_target_auto(key)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local mode = modes.BY_KEY[key]
    if mode == nil or mode.target == nil then return false, "No such game mode." end
    modes.targetChoice[key] = nil
    return true
end

function modes.target_is_auto(key)
    local mode = modes.BY_KEY[key]
    return mode ~= nil and mode.target ~= nil and type(mode.target.auto) == "function"
        and modes.targetChoice[key] == nil
end

function modes.target_auto_now(mode)
    if mode == nil or mode.target == nil or type(mode.target.auto) ~= "function" then return nil end
    local n = math.max(1, #modes.participants())
    local teams = false
    if mode.teams and modes.sides_wanted(mode) then
        local need = OF.util.asks(OF.teams, "min_room") and OF.teams.min_room(mode) or 4
        teams = n >= need
    end
    local ok, value = pcall(mode.target.auto, n, teams, teams and math.ceil(n / 2) or n)
    if not ok or type(value) ~= "number" then return nil end
    return math.floor(value)
end

function modes.target_is_clock(mode)
    if mode == nil or mode.target == nil then return false end
    if mode.target.clock ~= nil then return mode.target.clock == true end
    return mode.target.name == "seconds on the clock"
end

function modes.target_value_text(mode, value)
    if value == nil then return "" end
    if modes.target_is_clock(mode) then return modes.clock(value) end
    return tostring(value)
end

function modes.target_text(mode)
    if mode == nil or mode.target == nil then return "" end
    if modes.target_is_auto(mode.key) then
        local now = modes.target_auto_now(mode)
        if now ~= nil then
            return OF.lang.fill("auto (@)", modes.target_value_text(mode, now))
        end
        return OF.lang.t("auto")
    end
    return modes.target_value_text(mode, modes.target_for(mode.key))
end

function modes.target_help(mode)
    if mode == nil or mode.target == nil then return "" end
    if type(mode.target.help) == "string" and mode.target.help ~= "" then return mode.target.help end
    if type(mode.target.auto) == "function" then
        return "auto fits it to the lobby - press to pick a number, and round again for auto"
    end
    return "what the round plays to - press to step it"
end

function modes.step_target(key)
    local mode = modes.BY_KEY[key]
    if mode == nil or mode.target == nil then return false end
    local step = mode.target.step or 1
    local low, high = mode.target.min or step, mode.target.max or 999
    local hasAuto = type(mode.target.auto) == "function"
    if hasAuto and modes.targetChoice[key] == nil then
        return modes.set_target(key, low)
    end
    local next = (modes.target_for(key) or mode.target.default) + step
    if next > high then
        if hasAuto then return modes.set_target_auto(key) end
        next = low
    end
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
function modes.place_option(mode)
    if mode == nil or type(mode.placeOption) ~= "string" then return nil end
    return modes.option_entry(mode, mode.placeOption)
end

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

function modes.shown_by(mode, rule)
    if rule == nil or mode == nil then return true end
    local function pick(optKey) return modes.option_pick(mode.key, optKey) end
    if type(rule) == "function" then
        local ok, shown = pcall(rule, pick)
        return not ok or shown ~= false
    end
    if type(rule) ~= "table" then return true end
    for optKey, want in pairs(rule) do
        local now = pick(optKey)
        if type(want) == "table" then
            local any = false
            for _, value in ipairs(want) do
                if value == now then any = true end
            end
            if not any then return false end
        elseif now ~= want then
            return false
        end
    end
    return true
end

function modes.option_shown(mode, option)
    return option == nil or modes.shown_by(mode, option.shownIf)
end

function modes.target_shown(mode)
    return mode ~= nil and mode.target ~= nil and modes.shown_by(mode, mode.target.shownIf)
end

function modes.preset_matches(mode, preset)
    if mode == nil or type(preset) ~= "table" then return false end
    local sets = preset.sets or {}
    for _, option in ipairs(modes.options_of(mode)) do
        local want = sets[option.key] or option.choices[1].key
        if option.key ~= mode.placeOption and modes.option_pick(mode.key, option.key) ~= want then
            return false
        end
    end
    if mode.target ~= nil then
        local want = sets.target
        local chosen = modes.targetChoice[mode.key]
        if want == nil or want == "auto" then

            if chosen ~= nil and (type(mode.target.auto) == "function"
                or chosen ~= mode.target.default) then
                return false
            end
        elseif chosen ~= tonumber(want) then
            return false
        end
    end
    return true
end

function modes.preset_now(key)
    local mode = modes.BY_KEY[key]
    if mode == nil or type(mode.presets) ~= "table" then return nil end
    for _, preset in ipairs(mode.presets) do
        if modes.preset_matches(mode, preset) then return preset end
    end
    return nil
end

function modes.apply_preset(key, presetKey)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    local mode = modes.BY_KEY[key]
    if mode == nil or type(mode.presets) ~= "table" then return false, "No such game mode." end
    local preset = nil
    for _, entry in ipairs(mode.presets) do
        if entry.key == presetKey then preset = entry end
    end
    if preset == nil then return false, "No such way to play it." end
    local sets = preset.sets or {}
    for _, option in ipairs(modes.options_of(mode)) do
        if option.key ~= mode.placeOption then
            local ok, why = modes.set_option(key, option.key, sets[option.key] or option.choices[1].key)
            if not ok then return false, why end
        end
    end
    if mode.target ~= nil then
        if sets.target == nil or sets.target == "auto" then
            modes.targetChoice[key] = nil
        else
            local ok, why = modes.set_target(key, sets.target)
            if not ok then return false, why end
        end
    end
    return true
end

function modes.step_preset(key)
    local mode = modes.BY_KEY[key]
    if mode == nil or type(mode.presets) ~= "table" or #mode.presets == 0 then
        return false, "No such game mode."
    end
    local now = modes.preset_now(key)
    local nextIndex = 1
    for index, preset in ipairs(mode.presets) do
        if preset == now then nextIndex = index % #mode.presets + 1 end
    end
    return modes.apply_preset(key, mode.presets[nextIndex].key)
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

        track = tonumber(entry.track),
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

modes.NO_ROUND_HERE = {}

function modes.round_refused_here(level)
    if level == nil then return nil end
    return modes.NO_ROUND_HERE[level]
end

modes.LEVEL_DRESS = {}
if LEVEL_SA ~= nil then modes.LEVEL_DRESS[LEVEL_SA] = "water=5,softland=1" end
if LEVEL_COTMC ~= nil then modes.LEVEL_DRESS[LEVEL_COTMC] = "water=5,softland=1" end

function modes.level_dress(level)
    if level == nil then return nil end
    return modes.LEVEL_DRESS[level]
end

function modes.fold_dress(base, extra)
    base = type(base) == "string" and base or ""
    if type(extra) ~= "string" or extra == "" then return base end
    local have = {}
    for piece in string.gmatch(base, "[^,]+") do have[piece] = true end
    local out = base
    for piece in string.gmatch(extra, "[^,]+") do
        if not have[piece] then
            out = (out == "") and piece or (out .. "," .. piece)
            have[piece] = true
        end
    end
    return out
end

function modes.round_level_for(mode, arenaKey, place, np)
    if arenaKey ~= nil and arenaKey ~= "" then
        local room = OF.util.asks(OF.arena, "find") and OF.arena.find(arenaKey) or nil
        return type(room) == "table" and room.level or nil
    end
    if type(place) == "table" and place.level ~= nil then return place.level end
    if mode == nil or modes.owns_its_place(mode) then return nil end
    np = np or (gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil)
    if np == nil then return nil end
    local here = np.currLevelNum
    if here == nil or here == 0 then return nil end
    return here
end

modes.LEVELS_OFF = { LEVEL_JRB, LEVEL_DDD }
modes.LEVELS_OFF_KEPT_BY = { prophunt = true, hideseek = true }

function modes.level_off(modeKey, level)
    if level == nil or modeKey == nil then return false end
    if modes.LEVELS_OFF_KEPT_BY[modeKey] then return false end
    for _, out in ipairs(modes.LEVELS_OFF) do
        if out ~= nil and out == level then return true end
    end
    return false
end

function modes.room_out(modeKey, level, area, arenaKey)
    if modes.level_off(modeKey, level) then return true end
    local mode = modeKey ~= nil and modes.BY_KEY ~= nil and modes.BY_KEY[modeKey]
        or nil
    if mode == nil or type(mode.roomsOut) ~= "table" then return false end
    for _, out in ipairs(mode.roomsOut) do
        if type(out) == "string" then
            if arenaKey ~= nil and out == arenaKey then return true end
            if level ~= nil and arenaKey == nil
                and OF.util.asks(OF.arena, "find") then
                local row = OF.arena.find(out)
                if row ~= nil and row.level ~= nil and row.level == level
                    and (row.area or 1) == (area or 1) then
                    return true
                end
            end
        elseif type(out) == "table" and level ~= nil
            and out.level == level and (out.area or 1) == (area or 1) then
            return true
        end
    end
    return false
end

function modes.course_levels(modeKey)
    local out = {}
    if OF.LEVELS == nil then return out end

    local mode = modeKey ~= nil and modes.BY_KEY ~= nil and modes.BY_KEY[modeKey] or nil
    local extra = {}
    for _, room in ipairs((mode ~= nil and mode.levelsIn) or {}) do
        if type(room) == "table" and room.level ~= nil then
            extra[tostring(room.level) .. ":" .. tostring(room.area or 1)] = true
        end
    end
    for _, entry in ipairs(OF.LEVELS) do
        if (entry.group == "Courses"
                or extra[tostring(entry.level) .. ":" .. tostring(entry.area or 1)])
            and modes.round_refused_here(entry.level) == nil
            and not modes.room_out(modeKey, entry.level, entry.area or 1) then
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

function modes.plays_open(modeKey)
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil
    if mode == nil or mode.openCourses ~= true then return false end
    if modes.owns_its_place(mode) then return false end
    return not modes.sides_wanted(mode)
end

function modes.nowhere_to_play(modeKey)
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil

    if mode ~= nil and type(mode.studioTracksOnly) == "string"
        and #modes.offered_places(modeKey) == 0 then
        return OF.lang.t(mode.studioTracksOnly)
    end
    if mode == nil or modes.owns_its_place(mode) then return nil end
    if modes.maps_of(mode) ~= "surveyed" then return nil end
    if #modes.offered_places(modeKey) > 0 then return nil end
    return OF.lang.t("Nowhere has been surveyed for this yet.")
end

function modes.open_need(players)
    local count = math.max(1, math.min(tonumber(players) or MAX_PLAYERS,
        MAX_PLAYERS))
    return count + math.ceil(count / 2)
end

function modes.open_players()
    if not OF.util.asks(OF.util, "connected_players") then return MAX_PLAYERS end
    return math.max(1, #OF.util.connected_players())
end

function modes.course_ground(level, area)
    local byLevel = OF.COURSE_GROUND ~= nil and OF.COURSE_GROUND[level] or nil
    local packed = byLevel ~= nil and byLevel[area or 1] or nil
    if type(packed) ~= "string" then return {} end
    return modes.unpack_points(packed)
end

function modes.open_levels(players, modeKey)
    local out = {}
    if OF.LEVELS == nil then return out end
    local need = modes.open_need(players or modes.open_players())
    for _, entry in ipairs(OF.LEVELS) do
        local area = entry.area or 1
        if modes.round_refused_here(entry.level) == nil
            and not modes.room_out(modeKey, entry.level, area)
            and #modes.course_ground(entry.level, area) >= need then
            table.insert(out, {
                level = entry.level, area = area,
                act = entry.act or 1, name = entry.name,
            })
        end
    end
    return out
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

function modes.is_destination(level, area)
    if OF.LEVELS == nil then return true end
    for _, entry in ipairs(OF.LEVELS) do
        if entry.level == level and (entry.area or 1) == (area or 1) then
            return true
        end
    end
    return false
end

function modes.forge_track_levels(modeKey)
    local mode = modeKey ~= nil and modes.BY_KEY[modeKey] or nil
    if mode == nil or mode.forgeTracks ~= true then return {} end
    if not OF.util.asks(OF.forge, "racer_levels") then return {} end

    local venue = {}
    if OF.util.asks(OF.util, "venue_destinations") then
        for _, v in ipairs(OF.util.venue_destinations()) do
            venue[tostring(v.level) .. ":" .. tostring(v.area or 1)] = true
        end
    end

    local out = {}
    for _, e in ipairs(OF.forge.racer_levels()) do
        local inVenue = venue[tostring(e.level) .. ":" .. tostring(e.area)]
        if modes.round_refused_here(e.level) == nil
            and (inVenue or modes.is_destination(e.level, e.area)) then
            local name = OF.util.asks(OF.util, "level_name") and OF.util.level_name(e.level, e.area)
                or tostring(e.level)
            table.insert(out, { level = e.level, area = e.area, act = 1,
                name = tostring(name) .. " - " .. tostring(e.name or e.track),
                forgeTrack = e.key, track = e.track })
        end
    end
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return out
end

function modes.surveyed_levels(modeKey)
    local mode = modes.BY_KEY[modeKey]

    if mode == nil or mode.studioTracksOnly ~= nil then return {} end
    local wanted = mode.surveyKeys
    if type(wanted) ~= "table" or #wanted == 0 then return {} end

    local takenOut = {}
    for _, room in ipairs(mode.surveyOut or {}) do
        if type(room) == "table" and room.level ~= nil then
            takenOut[tostring(room.level) .. ":"
                .. tostring(room.area or 1)] = true
        end
    end

    local rooms = {}
    for _, source in ipairs({ modes.SURVEYED, modes.SURVEY_SUGGESTED or {} }) do
        for level, areas in pairs(source) do
            rooms[level] = rooms[level] or {}
            for area in pairs(areas) do
                rooms[level][area] = modes.survey_set(level, area)
            end
        end
    end
    local out = {}
    for level, areas in pairs(rooms) do
        for area, keys in pairs(areas) do

            if type(keys) == "table"
                and modes.round_refused_here(level) == nil
                and modes.is_destination(level, area)
                and not modes.level_off(modeKey, level)
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

function modes.studio_race_venue(place)
    if place == nil or place.venue ~= true then return false end
    local layouts = OF.venues ~= nil and OF.venues.LAYOUTS or nil
    local layout = type(layouts) == "table" and layouts[place.key] or nil
    if type(layout) ~= "table" then return false end
    for _, row in ipairs(type(layout.markers) == "table" and layout.markers or {}) do
        if type(row) == "table" and row[1] == 1 then return true end
    end
    for _, row in ipairs(type(layout.objects) == "table" and layout.objects or {}) do
        if type(row) == "table" and row[1] == "racestart" then return true end
    end
    return false
end

function modes.venue_offerable(place)
    if place == nil or place.venue ~= true then return true end
    local layouts = OF.venues ~= nil and OF.venues.LAYOUTS or nil
    local layout = type(layouts) == "table" and layouts[place.key] or nil
    if type(layout) ~= "table" or layout.faults ~= 0 then return false end

    if OF.util.asks(OF.venues, "standable") and not OF.venues.standable(place.key) then return false end
    return true
end

local function kept_off(place, modeKey)
    if modeKey == nil or place == nil then return false end
    if not modes.venue_offerable(place) then return true end
    for _, key in ipairs(place.notFor or {}) do
        if key == modeKey then return true end
    end

    if type(place.onlyFor) == "table" then
        for _, key in ipairs(place.onlyFor) do
            if key == modeKey then return false end
        end
        return true
    end

    if modes.venue_by_family(place) then
        return not modes.venue_fits(place, modeKey)
    end
    return false
end

modes.VENUE_FAMILIES = {
    shooter = { "shooter", "oitc", "rocketarena", "wanted", "assassins", "laststanding",
        "crown", "coinrush", "greendemon", "bank", "murder", "bounty" },
    objective = { "ctf", "oneflag", "domination", "koth", "football", "volleyball",
        "copsandrobbers" },
    knockoff = { "sumo", "smash", "bumperballs", "chompfever", "logroll", "megarampage",
        "hotpotato", "deflect" },
    race = { "shellrace", "shellbattle", "downhill", "line", "flood" },
    hide = { "hideseek", "sardines", "prophunt", "manhunt", "zombies", "rabbitchase",
        "hideballoon" },
    party = { "bombsaway", "bombxing", "booksquirm", "lavaleave", "hotrope", "blizzard",
        "blast", "glassbridge", "turf", "spots", "simon", "frenzy", "blastgrid",
        "bombsort", "flyguy", "lakitu", "hexheat", "hexagone" },
    course = { "onoffclimb", "silverfive", "course" },
}

modes.NO_VENUE = { football = true, volleyball = true }

function modes.venue_family_of(modeKey)
    local mode = modes.BY_KEY[modeKey]
    if mode ~= nil and type(mode.venueFamily) == "string" then return mode.venueFamily end
    for family, keys in pairs(modes.VENUE_FAMILIES) do
        for _, key in ipairs(keys) do
            if key == modeKey then return family end
        end
    end
    return nil
end

function modes.venue_by_family(place)
    return type(place) == "table" and place.venue == true
        and type(place.onlyFor) ~= "table" and type(place.notFor) == "table"
end

function modes.venue_fits(place, modeKey)
    if not modes.venue_by_family(place) then return false end
    local mode = modes.BY_KEY[modeKey]
    if mode == nil or modes.NO_VENUE[modeKey] then return false end
    if modes.venue_family_of(modeKey) ~= (place.family or "shooter") then return false end
    local kind = modes.maps_of(mode)
    if kind == "own" or kind == "none" then return false end
    local layouts = OF.venues ~= nil and OF.venues.LAYOUTS or nil
    local layout = type(layouts) == "table" and layouts[place.key] or nil
    local survey = type(layout) == "table" and type(layout.survey) == "table"
        and layout.survey or {}
    for _, name in ipairs(type(mode.surveyKeys) == "table" and mode.surveyKeys or {}) do
        if name ~= "points" then
            local rows = survey[name]
            if type(rows) ~= "table" or #rows == 0 then return false end
        end
    end
    return true
end

function modes.offered_to_nobody(place)
    if type(place) ~= "table" or place.level == nil then return false end
    if not OF.util.asks(OF.arena, "find") then return false end
    for _, row in ipairs(OF.arena.PLACES or {}) do

        local level = row.level
        if level ~= nil and level == place.level
            and (row.area or 1) == (place.area or 1)
            and type(row.onlyFor) == "table" and #row.onlyFor == 0 then
            return true
        end
    end
    return false
end

function modes.venue_names(place, modeKey)
    if place == nil or modeKey == nil or place.venue ~= true then return false end

    if modes.venue_by_family(place) then
        return modes.venue_fits(place, modeKey) and not kept_off(place, modeKey)
    end
    if type(place.onlyFor) ~= "table" then return false end
    for _, key in ipairs(place.onlyFor) do
        if key == modeKey then return true end
    end
    return false
end

function modes.rooms_for(modeKey)
    local mode = modes.BY_KEY[modeKey]
    local kind, keys = modes.maps_of(mode)
    if kind == "own" or kind == "none" then return {} end
    if not OF.util.asks(OF.arena, "find") then return {} end
    local studioOnly = mode ~= nil and mode.studioTracksOnly ~= nil

    if kind == "surveyed" and (keys == nil or #keys == 0) then keys = {} end

    local wanted = nil
    if keys ~= nil then
        wanted = {}
        for _, key in ipairs(keys) do wanted[key] = true end
    end

    local out = {}
    for _, place in ipairs(OF.arena.PLACES or {}) do

        if (wanted == nil or wanted[place.key] or modes.venue_names(place, modeKey))
            and modes.round_refused_here(place.level) == nil
            and not kept_off(place, modeKey)
            and not modes.room_out(modeKey, place.level, place.area or 1,
                place.key)
            and (not studioOnly or modes.studio_race_venue(place)) then
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

    if modes.offered_to_nobody(place) then return false end

    for _, room in ipairs((OF.arena and OF.arena.PLACES) or {}) do
        if room.venue == true and room.level == place.level
            and not modes.venue_offerable(room) then
            return false
        end
    end

    if modes.takes_any_level(modeKey) then
        return not modes.room_out(modeKey, place.level, place.area or 1)
    end

    if modes.takes_main_courses(modeKey) then
        for _, entry in ipairs(modes.course_levels(modeKey)) do
            if entry.level == place.level
                and (entry.area or 1) == (place.area or 1) then
                return true
            end
        end
    end

    local list = nil
    if modes.plays_open(modeKey) then
        list = modes.open_levels(nil, modeKey)
    elseif modes.maps_of(mode) == "surveyed" then
        list = modes.surveyed_levels(modeKey)
    end
    for _, entry in ipairs(list or {}) do
        if entry.level == place.level
            and (entry.area or 1) == (place.area or 1) then
            return true
        end
    end

    for _, entry in ipairs(modes.forge_track_levels(modeKey)) do
        if entry.level == place.level and (entry.area or 1) == (place.area or 1) then
            return true
        end
    end

    return modes.open_pick_kept(modeKey, place)
end

function modes.open_pick_kept(modeKey, place)
    if place == nil or place.level == nil or not modes.plays_open(modeKey) then
        return false
    end
    local held = modes.levelChoice
    if held == nil or held.level ~= place.level
        or (held.area or 1) ~= (place.area or 1) then
        return false
    end
    for _, entry in ipairs(modes.open_levels(1, modeKey)) do
        if entry.level == place.level
            and (entry.area or 1) == (place.area or 1) then
            return true
        end
    end
    return false
end

function modes.open_pick_outgrown(modeKey, place)
    if not modes.open_pick_kept(modeKey, place) then return false end
    for _, entry in ipairs(modes.open_levels(nil, modeKey)) do
        if entry.level == place.level
            and (entry.area or 1) == (place.area or 1) then
            return false
        end
    end
    return true
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

    if modes.plays_open(modeKey) then
        for _, entry in ipairs(modes.open_levels(nil, modeKey)) do
            table.insert(out, { what = "level", value = entry,
                level = entry.level, area = entry.area or 1 })
        end
    elseif kind == "surveyed" then
        for _, entry in ipairs(modes.surveyed_levels(modeKey)) do
            table.insert(out, { what = "level", value = entry,
                level = entry.level, area = entry.area or 1 })
        end
    end

    if modes.takes_main_courses(modeKey) then
        for _, entry in ipairs(modes.course_levels(modeKey)) do
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

    for _, entry in ipairs(modes.forge_track_levels(modeKey)) do
        table.insert(out, { what = "level", value = entry,
            level = entry.level, area = entry.area or 1, track = entry.track })
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
        local lead = OF.util.is_host() and modes.startingLead or nil
        np = gNetworkPlayers[lead or 0]
        if np ~= nil and not np.connected then np = gNetworkPlayers[0] end
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

    if modes.attach_mutators ~= nil then modes.attach_mutators(mode) end
end

modes.WATER_RULES = {
    hide = { fins = 1, drysuit = 1 },
    chase = { fins = 1 },
}

function modes.water_rule(kind, given)
    local out = {}
    for key, rung in pairs(given or {}) do out[key] = rung end
    for key, rung in pairs(modes.WATER_RULES[kind] or {}) do
        if out[key] == nil then out[key] = rung end
    end
    return out
end

do
    local bubblesHeld = {}

    function modes.quiet_bubbles(m, quiet)
        if m == nil or m.marioObj == nil then return false end
        local seat = m.playerIndex or 0
        local active = ACTIVE_PARTICLE_BUBBLE or 0x20
        local flags = m.marioObj.oActiveParticleFlags or 0
        if quiet then
            if not OF.util.has_flag(flags, active) then
                m.marioObj.oActiveParticleFlags = flags + active
            end
            local particle = PARTICLE_BUBBLE or 0x20
            local own = m.particleFlags or 0
            if OF.util.has_flag(own, particle) then
                m.particleFlags = own - particle
            end
            bubblesHeld[seat] = true
            return true
        end
        if bubblesHeld[seat] then
            bubblesHeld[seat] = nil
            if OF.util.has_flag(flags, active) then
                m.marioObj.oActiveParticleFlags = flags - active
            end
        end
        return false
    end
end

modes.GROUPS = {

    { name = "Catch somebody",
      help = "one role hunts, and being caught is what changes who you are",
      keys = { "murder", "hotpotato", "manhunt",
               "copsandrobbers",

               "megarampage",

               "lakitu" } },

    { name = "Hide from them",
      help = "one side hides, the other looks - being found is being caught",
      keys = { "hideseek", "prophunt", "hideballoon",
               "sardines",

               "zombies" } },

    { name = "Fight it out",
      help = "putting somebody down is the whole mechanic - these want a ring",

      keys = { "laststanding", "sumo", "bumperballs", "smash",
               "assassins",

               "wanted" } },

    { name = "Take a shot",
      help = "one shot, one throw or one fist decides it",
      keys = { "shooter", "oitc", "rocketarena",

               "snd",

               "bounty",

               "shellbattle",

               "blastgrid",

               "bombsort" } },

    { name = "Hold your ground",
      help = "a place or a thing, and the clock runs for as long as it is yours",
      keys = { "koth", "domination", "crown", "turf" } },

    { name = "Something to carry",
      help = "something has to be moved, and where it ends up is the point",

      keys = { "coinrush", "bank", "football",

               "rabbitchase",

               "volleyball",

               "ctf", "oneflag" } },

    { name = "Get to the end",
      help = "there is an end, and getting there is the whole round",
      keys = { "line", "bossrush", "shellrace",

               "silverfive",

               "onoffclimb",

               "downhill" } },

    { name = "Dodge what is loose in it",
      help = "something loose moves on its own, and it is not a player",
      keys = { "chompfever", "lavaleave", "bombsaway", "hotrope",
               "booksquirm", "greendemon",

               "blizzard",

               "bombxing" } },

    { name = "Answer the call",
      help = "one moment decides it - a call, a count, a flash or a step",

      keys = { "simon", "glassbridge", "deflect", "frenzy" } },
    { name = "The round is the enemy",
      help = "nobody is hunting you - the level, the music or the caller is",

      keys = { "spots", "flood", "hexagone", "hexheat", "logroll",
               "blast",

               "flyguy",

               "firesweep" } },
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

modes.MUTATOR_SPEED = {
    key = "speed", name = "Movement speed",
    help = "how fast everybody moves on foot, this round",
    choices = {
        { key = "normal", name = "normal",
          help = "the usual speed" },
        { key = "fast", name = "brisk", mods = "quick=1",
          help = "a little quicker on foot" },
        { key = "faster", name = "fast", mods = "quick=2",
          help = "clearly quicker - still steerable" },
    },
}

modes.MUTATOR_JUMP = {
    key = "jump", name = "Jump height",
    help = "how high everybody in the lobby jumps, this round",
    choices = {
        { key = "normal", name = "normal",
          help = "the usual jumps" },

        { key = "high", name = "high",
          help = "every jump is the triple jump's own height, from standing" },
    },
}

modes.MUTATOR_GRAV = {
    key = "grav", name = "Gravity",
    help = "how the lobby comes back down, this round",
    choices = {
        { key = "normal", name = "normal",
          help = "the usual gravity" },

        { key = "low", name = "low", mods = "lowgrav=2",
          help = "floaty - you come down slowly" },
        { key = "heavy", name = "heavy", mods = "lowgrav=4",
          help = "you come down faster and jump a little shorter" },
    },
}

do

    local function jump_grant_triples()
        if modes.option_now("jump") == "high" then return 1 end
        return nil
    end

    local MUTATOR_FAMILIES = { ["Take a shot"] = true, ["Fight it out"] = true,
                                ["Hold your ground"] = true }

    local MUTATOR_EXCLUDE = { rocketarena = true }

    MUTATOR_EXCLUDE.shellbattle = true

    MUTATOR_EXCLUDE.bombsort = true

    MUTATOR_EXCLUDE.smash = true

    MUTATOR_EXCLUDE.snd = true
    MUTATOR_EXCLUDE.blastgrid = true
    MUTATOR_EXCLUDE.bumperballs = true
    modes.MUTATOR_EXCLUDE = MUTATOR_EXCLUDE

    local function in_mutator_family(modeKey)
        for _, group in ipairs(modes.GROUPS) do
            if MUTATOR_FAMILIES[group.name] then
                for _, key in ipairs(group.keys) do
                    if key == modeKey then return true end
                end
            end
        end
        return false
    end

    function modes.attach_mutators(mode)
        if mode == nil or mode.key == nil then return end
        if MUTATOR_EXCLUDE[mode.key] then return end
        if not in_mutator_family(mode.key) then return end

        mode.options = mode.options or {}
        table.insert(mode.options, modes.mutator_for(mode, modes.MUTATOR_SPEED))
        table.insert(mode.options, modes.mutator_for(mode, modes.MUTATOR_GRAV))
        table.insert(mode.options, modes.mutator_for(mode, modes.MUTATOR_JUMP))

        mode.cheatsGiven = mode.cheatsGiven or {}
        mode.cheatsGiven.triples = jump_grant_triples
    end

    function modes.mutator_for(mode, option)
        local out = type(mode.mutatorsOut) == "table" and mode.mutatorsOut[option.key] or nil
        if type(out) ~= "table" or #out == 0 then return option end
        local gone = {}
        for _, key in ipairs(out) do gone[key] = true end
        local copy = { key = option.key, name = option.name, help = option.help, choices = {} }
        for index, choice in ipairs(option.choices) do
            if index == 1 or not gone[choice.key] then table.insert(copy.choices, choice) end
        end
        return copy
    end
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
    local raw = gGlobalSyncTable.ofGmState or modes.OFF

    if modes.goneEarly ~= nil and raw == modes.COUNTDOWN
        and modes.goneEarly == OF.packet_round() then
        return modes.ACTIVE
    end
    return raw
end

function modes.current()
    local key = gGlobalSyncTable.ofGmKey
    if key == nil or key == "" then return nil end
    return modes.BY_KEY[key]
end

function modes.is_running()
    local state = modes.state()
    return state == modes.COUNTDOWN or state == modes.ACTIVE
end

function modes.announce_held()
    if not modes.is_running() then return nil end
    local mode = modes.current()
    if mode == nil or mode.noAnnounce ~= true then return nil end
    return OF.lang.fill("Announcements are off during @.", OF.lang.t(mode.name or ""))
end

function modes.is_waiting()
    return modes.state() == modes.LOBBY
end

function modes.blind_now()
    local mode = modes.current()
    if mode == nil or type(mode.blind) ~= "function" then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    if not OF.util.can_play(0) then return false end
    local ok, blind = pcall(mode.blind)
    return ok and blind == true
end

function modes.draw_blind()
    if not modes.blind_now() then return false end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    if OF.util.asks(OF.hunt, "draw_curtain") then
        OF.hunt.draw_curtain()
    else

        local screenWidth, screenHeight = djui_hud_get_screen_width(), djui_hud_get_screen_height()
        OF.util.rect(0, 0, screenWidth + 2, screenHeight + 2, 0, 0, 0, 255)
    end
    return true

end

function modes.is_open()
    local state = modes.state()
    return state == modes.LOBBY or state == modes.COUNTDOWN or state == modes.ACTIVE
end

function modes.is_over()
    local state = modes.state()
    return state == modes.MOMENT or state == modes.RESULTS
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

    return OF.util.can_play(localIndex, OF.speedrun and OF.speedrun.KIND_MODE or nil)
end

modes.AFK_OUT = {
    line = { why = "On red you hold still for at most three seconds. A minute "
                .. "of it is somebody who has stopped playing, and the round "
                .. "waits for every runner who could still reach the pole." },
    shellrace = { why = "A lap race. There is no reason to stand still in one, "
                     .. "and the round waits for everybody still running it." },
    downhill = { why = "A run down a slide. Nobody stands still on one, and the "
                    .. "round waits for every rider who still has a run to do." },

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
        if modes.role(entry.localIndex) == modes.WAITING then

        elseif modes.can_play(entry.localIndex) or modes.is_out(entry.localIndex) then
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

function modes.landed(list)
    local out = {}
    for _, entry in ipairs(list or {}) do
        local li = entry.localIndex
        local np = li ~= nil and gNetworkPlayers[li] or nil
        if np ~= nil and np.connected ~= false then
            local fresh
            if li == 0 then
                fresh = np.currAreaSyncValid == true
            else
                fresh = np.currPositionValid == true
            end
            if fresh then table.insert(out, entry) end
        end
    end
    return out
end

function modes.still_loading_for(mode)
    if modes.pins_on_players(mode) then return modes.still_loading() end
    local np = gNetworkPlayers[0]
    if np ~= nil and np.currAreaSyncValid == false then return 1 end
    return 0
end

function modes.reason_sitting_out(localIndex)

    if OF.util.asks(OF.speedrun, "muted_out") and OF.speedrun.muted_out(localIndex) then
        return "muted"
    end
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
    OF.util.chat(OF.lang.t(
        "In the lobby but not in the count:"), "mode", { more = true })
    for _, entry in ipairs(out) do
        OF.util.chat(OF.lang.fill("@ - @",
            OF.util.chat_name(entry.name), OF.lang.t(entry.why)), "mode", { more = true })
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

do
local function by_score(a, b) return a.score > b.score end

function modes.score_board(role, score_of, format)
    local board = {}
    for _, entry in ipairs(modes.with_role(role)) do
        table.insert(board, { name = entry.np.name, score = score_of(entry.localIndex),
                              localIndex = entry.localIndex })
    end
    table.sort(board, by_score)
    for _, entry in ipairs(board) do entry.right = format(entry.score, entry) end
    return board
end
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

function modes.on_board(i)
    local np = gNetworkPlayers[i]
    if np == nil or not np.connected then return false end
    local role = modes.role(i)
    if role == "" then return false end
    return role == modes.WAITING or modes.can_play(i) or modes.is_out(i)
        or (OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(i)) == true
end

function modes.board_roster()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        if modes.on_board(entry.localIndex) then table.insert(list, entry) end
    end
    return list
end

modes.WAITING = "waiting for the next round"
modes.SEAT_SECONDS = 120

modes.heldSeats = {}

local SEATS_MAX = 16

local KEEP_HOLDER = "roundkeeps"
modes.CLOCK_STOPPED_STOP = 4

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

local function split_score(recipients, amount)
    local n = #recipients
    local given = {}
    if n == 0 or type(amount) ~= "number" or amount <= 0 then return given end
    local share = math.floor(amount / n)
    local remainder = amount - share * n
    for i, mateIndex in ipairs(recipients) do
        local paid = share + (i <= remainder and 1 or 0)
        if paid > 0 then given[mateIndex] = paid end
    end
    return given
end

do
    local PAID_KEY = "ofGmPaid"
    local PAID_MAX = 999999

    modes.escrow = modes.escrow or { stamp = nil, owed = {} }
    modes.paid = modes.paid or { stamp = nil, taken = 0 }

    local function global_of(localIndex)
        if localIndex == nil then return nil end
        local np = gNetworkPlayers[localIndex]
        if np == nil then return nil end
        local g = np.globalIndex
        if type(g) ~= "number" then return nil end
        if g < 0 or g >= MAX_PLAYERS then return nil end
        return g
    end

    local function publish_escrow()
        if not OF.util.is_host() then return false end
        local stamp = modes.escrow.stamp
        if stamp == nil then
            OF.util.publish(PAID_KEY, nil)
            return true
        end
        local who = {}
        for g in pairs(modes.escrow.owed) do table.insert(who, g) end
        table.sort(who)
        local parts = { stamp }
        for _, g in ipairs(who) do
            local owed = modes.escrow.owed[g]
            if owed ~= nil and owed > 0 then
                table.insert(parts, tostring(g) .. ":" .. tostring(owed))
            end
        end
        OF.util.publish(PAID_KEY, table.concat(parts, ";"))
        return true
    end

    function modes.pay_escrow(globalIndex, amount)
        if not OF.util.is_host() then return false end
        if type(globalIndex) ~= "number" then return false end
        if type(amount) ~= "number" or amount <= 0 then return false end

        if modes.escrow.stamp == nil then
            modes.escrow.stamp = tostring(math.floor(clock_elapsed()))
            modes.escrow.owed = {}
        end

        local owed = (modes.escrow.owed[globalIndex] or 0) + math.floor(amount)
        if owed > PAID_MAX then owed = PAID_MAX end
        modes.escrow.owed[globalIndex] = owed
        return publish_escrow()
    end

    function modes.drop_escrow(globalIndex)
        if not OF.util.is_host() then return false end
        if type(globalIndex) ~= "number" then return false end
        if modes.escrow.owed[globalIndex] == nil then return false end
        modes.escrow.owed[globalIndex] = nil
        return publish_escrow()
    end

    function modes.forget_escrow()
        modes.paid.stamp = nil
        modes.paid.taken = 0
        if not OF.util.is_host() then return false end
        modes.escrow.stamp = nil
        modes.escrow.owed = {}
        OF.util.publish(PAID_KEY, nil)
        return true
    end

    local function take_my_share()
        local packed = gGlobalSyncTable[PAID_KEY]
        if type(packed) ~= "string" or packed == "" then return false end

        local me = global_of(0)
        if me == nil then return false end

        local stamp = string.match(packed, "^([^;]*)")
        if stamp == nil or stamp == "" then return false end

        local owed = 0
        for who, amount in string.gmatch(packed, ";(%d+):(%d+)") do
            if tonumber(who) == me then owed = tonumber(amount) or 0 end
        end

        if modes.paid.stamp ~= stamp then
            modes.paid.stamp = stamp
            modes.paid.taken = 0
        end

        local delta = owed - modes.paid.taken
        if delta <= 0 then return false end
        modes.paid.taken = owed

        local row = gPlayerSyncTable[0]
        local current = (row ~= nil and row.ofScore) or 0
        OF.util.publish_row(0, "ofScore", current + delta)
        return true
    end

    modes.take_my_share = take_my_share
    modes.global_of = global_of

    function modes.owed_to(globalIndex)
        if type(globalIndex) ~= "number" then return 0 end
        local packed = gGlobalSyncTable[PAID_KEY]
        if type(packed) ~= "string" or packed == "" then return 0 end
        for who, amount in string.gmatch(packed, ";(%d+):(%d+)") do
            if tonumber(who) == globalIndex then return tonumber(amount) or 0 end
        end
        return 0
    end

    hook_on_sync_table_change(gGlobalSyncTable, PAID_KEY, 0,
        function()
            if OF.util.asks(OF.guard, "repair") and OF.guard.repair(PAID_KEY) then
                return
            end
            take_my_share()
        end)
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
    local name = np ~= nil and OF.util.name_safe(np.name or "") or nil
    if name == nil or name == "" then name = OF.lang.t("Somebody") end

    local row = gPlayerSyncTable[localIndex]
    local score = (row ~= nil and row.ofScore) or 0
    local team = OF.util.asks(OF.teams, "of") and OF.teams.of(localIndex) or ""
    local mode = modes.BY_KEY[key]
    local mayBank = true
    if mode ~= nil and mode.may_bank ~= nil then
        local ok, answer = pcall(mode.may_bank, localIndex)
        if not OF.util.report(ok, answer) then answer = true end
        if answer == false then mayBank = false end
    end

    if not mayBank then
        role = "out"
        score = 0
    end

    if team ~= "" and score > 0 and OF.util.asks(OF.teams, "in_play")
        and OF.teams.in_play() and OF.util.asks(OF.teams, "members") then
        local mates = {}
        for _, entry in ipairs(OF.teams.members(team)) do
            if entry.localIndex ~= localIndex then
                table.insert(mates, entry.localIndex)
            end
        end
        table.sort(mates)

        if #mates > 0 then
            local given = split_score(mates, score)

            local paid = 0
            for mateIndex, share in pairs(given) do
                local mateGlobal = modes.global_of(mateIndex)
                if mateGlobal ~= nil and modes.pay_escrow(mateGlobal, share) then
                    paid = paid + share
                end
            end

            if paid > 0 then
                OF.notify.send_all("@ left - their @ points go to their team",
                    "warn", 5, name, tostring(paid))
                score = score - paid
            end
        end
    end

    modes.heldSeats[id] = {
        name = name,
        role = role,
        key = key,
        at = clock_elapsed(),
        team = team,
        score = score,
    }

    if mayBank then
        OF.notify.send_all("@ dropped out - the round is holding their place",
            "warn", 5, modes.heldSeats[id].name)
    else
        OF.notify.send_all("@ dropped out - their round is already lost, not held",
            "warn", 5, modes.heldSeats[id].name)
    end
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

    if seat.team ~= nil and seat.team ~= "" and OF.util.asks(OF.teams, "set_here") then
        OF.teams.set_here(localIndex, seat.team)
    end

    if seat.score ~= nil and seat.score > 0 then
        local backGlobal = modes.global_of(localIndex)
        if backGlobal ~= nil then modes.pay_escrow(backGlobal, seat.score) end
    end

    local np = gNetworkPlayers[localIndex]
    if np ~= nil then
        OF.notify.send_to(np.globalIndex, "Welcome back - you are @ again",
            "good", 6, seat.role)
    end
    OF.notify.send_all("@ is back, and so is their round", "good", 5, seat.name)

    local mode = modes.current()
    if mode ~= nil and mode.rejoin ~= nil then
        local ok, err = pcall(mode.rejoin, localIndex)
        OF.util.report(ok, err)
    end

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

    local leaving = modes.global_of(localIndex)
    modes.bank_seat(localIndex)
    if leaving ~= nil then modes.drop_escrow(leaving) end

    seatIds[localIndex] = nil

    if modes.claimsJudged ~= nil then modes.claimsJudged[localIndex] = nil end
end

local function on_player_connected(m)
    modes.forget_participants()

    if not OF.util.is_host() then return end
    if m == nil or m.playerIndex == 0 then return end

    modes.remember_seat_id(m.playerIndex)

    modes.admit_late(m.playerIndex)
end

function modes.admit_late(localIndex)
    if not OF.util.is_host() then return false end
    if not modes.is_running() then return false end

    local mode = modes.current()
    if mode == nil then return false end

    if localIndex == nil or not modes.can_play(localIndex) then return false end

    if OF.teams ~= nil then OF.teams.add_late(localIndex) end

    if modes.redeem_seat(localIndex) then return true end

    local role = nil
    if mode.late_join ~= nil and not modes.refuses_latecomers(mode.key) then
        role = mode.late_join(localIndex)
    end
    if role == nil or role == "" then role = modes.WAITING end
    modes.set_role(localIndex, role)

    local np = gNetworkPlayers[localIndex]
    if np == nil then return true end

    OF.notify.send_to(np.globalIndex, "@ - you are @", "info", 6, mode.name, role)
    return true
end

function modes.back_in(localIndex, old, new)
    if old ~= true or new == true then return false end
    if not modes.is_running() then return false end
    if modes.role(localIndex) ~= "" then return false end
    if localIndex == 0 then modes.note_round_seen(false) end
    if OF.util.is_host() then modes.admit_late(localIndex) end
    return true
end

hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_player_disconnected)

for i = 0, MAX_PLAYERS - 1 do
    for _, key in ipairs({ "ofNoRace", "ofSpectating" }) do
        hook_on_sync_table_change(gPlayerSyncTable[i], key, i, function(_, old, new)
            if i == 0 and OF.util.asks(OF.guard, "repair_mine") then
                OF.guard.repair_mine(key)
            end
            modes.forget_participants()
            if key == "ofNoRace" then modes.back_in(i, old, new) end
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
    if s == nil then return "" end
    local role = s.ofRole
    if role == nil then return "" end
    return role
end

function modes.set_role(localIndex, role)
    if not OF.util.is_host() then
        if localIndex ~= 0 then return false end
        local state = modes.state()
        if state == modes.COUNTDOWN or state == modes.LOBBY then return false end
    end
    OF.util.publish_row(localIndex, "ofRole", role)
    return true
end

function modes.my_role()
    return modes.role(0)
end

local rotation = 0

local lastWinner = nil

local lastDeal = {}

modes.dealHistory = {}

function modes.last_deal()
    return lastDeal
end

function modes.forget_rotation()
    rotation = 0
    lastWinner = nil
    lastDeal = {}
    modes.dealHistory = {}
end

function modes.last_winner()
    return lastWinner
end

modes.PAIR_FROM = 6
function modes.fair_minority(players, wanted)
    players = math.floor(tonumber(players) or 0)
    wanted = math.max(1, math.floor(tonumber(wanted) or 1))
    if players >= modes.PAIR_FROM and wanted < 2 then wanted = 2 end
    return math.max(1, math.min(wanted, players - 1))
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

    modes.pick_fair(players, count, picked, taken, modes.deal_history("it"), rotation)

    rotation = rotation + 1
    return picked
end

do
    local drawState = nil
    modes.deal_draw = function()
        if drawState == nil then
            local seed = 48271
            if type(get_time) == "function" then
                local ok, now = pcall(get_time)
                if ok and type(now) == "number" then seed = math.floor(now * 1000) end
            end
            drawState = seed % 2147483647
            if drawState <= 0 then drawState = 1 end
        end
        drawState = (drawState * 48271) % 2147483647
        return drawState / 2147483647
    end
end
function modes.pick_fair(players, count, picked, taken, history, start)
    local total = #players
    local candidates = {}
    for place = 0, total - 1 do
        local entry = players[((start + place) % total) + 1]
        if entry ~= nil and not picked[entry.localIndex] then
            candidates[#candidates + 1] = { entry = entry, place = place,
                key = modes.deal_key(entry), draw = modes.deal_draw() }
        end
    end
    table.sort(candidates, function(a, b)
        local ca, cb = history.count[a.key] or 0, history.count[b.key] or 0
        if ca ~= cb then return ca < cb end
        local la, lb = history.last[a.key] or -1, history.last[b.key] or -1
        if la ~= lb then return la < lb end
        if a.draw ~= b.draw then return a.draw < b.draw end
        return a.place < b.place
    end)
    for _, one in ipairs(candidates) do
        if taken >= count then break end
        picked[one.entry.localIndex] = true
        taken = taken + 1
    end

    history.number = history.number + 1
    for _, entry in ipairs(players) do
        if picked[entry.localIndex] then
            local key = modes.deal_key(entry)
            history.count[key] = (history.count[key] or 0) + 1
            history.last[key] = history.number
        end
    end
    return picked
end

function modes.deal_history(job)
    job = job or "it"
    local history = modes.dealHistory[job]
    if history == nil then
        history = { count = {}, last = {}, number = 0, rotation = 0 }
        modes.dealHistory[job] = history
    end
    return history
end

function modes.deal_fair(players, count, job)
    local picked = {}
    local total = #players
    if total == 0 then return picked end
    count = math.max(1, math.min(math.floor(count or 1), total))
    local history = modes.deal_history(job or "job")
    modes.pick_fair(players, count, picked, 0, history, history.rotation % total)
    history.rotation = history.rotation + 1
    return picked
end

function modes.deal_key(entry)
    local id = entry.localIndex ~= nil and OF.util.player_id(entry.localIndex)
    if id ~= nil and id ~= false then return id end
    local np = entry.np
    return "g" .. tostring(np ~= nil and np.globalIndex or entry.localIndex)
end

function modes.dealt_count(key, job)
    return modes.deal_history(job).count[key] or 0
end

modes.forgedRoles = modes.forgedRoles or 0

local ROLE_GRACE_FRAMES = 90
local roleGraceLeft = nil

local function put_the_role_back(localIndex)
    modes.set_role(localIndex, "")
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
    hook_on_sync_table_change(gPlayerSyncTable[i], "ofRole", i,
        function(_, oldRole, newRole)
        if modes.repair_role(i) then return end

        if oldRole ~= newRole then modes.hear_role(i, oldRole, newRole) end
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

function modes.reset_options()
    local moved = modes.arenaChoice ~= nil or modes.levelChoice ~= nil
    modes.arenaChoice, modes.levelChoice = nil, nil
    return moved
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

modes.RELAY_FRESH = 30
local function seen_now(index, np)
    if index == 0 then return true end
    if np.currPositionValid then return true end
    local at = modes.relayedAt ~= nil and modes.relayedAt[index] or nil
    if at == nil or get_global_timer == nil then return false end
    return get_global_timer() - at <= modes.RELAY_FRESH
end
modes.seen_now = seen_now

function modes.distance(aIndex, bIndex)
    local na, nb = gNetworkPlayers[aIndex], gNetworkPlayers[bIndex]
    if na == nil or nb == nil then return nil end
    if na.currLevelNum ~= nb.currLevelNum then return nil end
    if na.currAreaIndex ~= nb.currAreaIndex then return nil end
    if not seen_now(aIndex, na) or not seen_now(bIndex, nb) then return nil end

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

        ACT_FORWARD_ROLLOUT, ACT_BACKWARD_ROLLOUT,
    }

    for index = 1, 12 do
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

modes.CANNOT_ATTACK = {}
do
    local CANNOT_ATTACK = modes.CANNOT_ATTACK
    local named = {
        ACT_FLYING, ACT_SHOT_FROM_CANNON, ACT_FLYING_TRIPLE_JUMP,
        ACT_BUTT_SLIDE, ACT_STOMACH_SLIDE, ACT_HOLD_BUTT_SLIDE,
        ACT_HOLD_STOMACH_SLIDE, ACT_BUTT_SLIDE_AIR, ACT_HOLD_BUTT_SLIDE_AIR,
        ACT_CROUCH_SLIDE,
        ACT_START_HANGING, ACT_HANGING, ACT_HANG_MOVING, ACT_LEDGE_GRAB,
        ACT_LEDGE_CLIMB_SLOW_1, ACT_LEDGE_CLIMB_SLOW_2, ACT_LEDGE_CLIMB_FAST,
        ACT_RIDING_SHELL_GROUND, ACT_RIDING_SHELL_JUMP, ACT_RIDING_SHELL_FALL,
    }
    for index = 1, 20 do
        if named[index] ~= nil then CANNOT_ATTACK[named[index]] = true end
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

do
local function tag_kind(m)
    if m == nil then return nil end
    local action = m.action or 0
    if TAG_MOVES[action] then return "attack" end
    if ON_A_POLE[action] or modes.CANNOT_ATTACK[action] then return "contact" end
    if feet_are_wet(m) then return "contact" end
    return nil
end
modes.tag_kind = tag_kind

local function tag_move_now(m)
    return tag_kind(m) ~= nil
end

modes.TAG_GRACE = 10
modes.tagSeenAt = {}
local tagFrame = 0

function modes.note_tag_moves()
    tagFrame = tagFrame + 1
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected and tag_move_now(gMarioStates[i]) then
            modes.tagSeenAt[i] = tagFrame
        end
    end
end

function modes.tag_move(taggerLocal)
    local m = gMarioStates[taggerLocal]
    if m == nil then return false end
    if tag_move_now(m) then return true end
    local seen = modes.tagSeenAt[taggerLocal]
    return seen ~= nil and tagFrame - seen <= modes.TAG_GRACE
end

modes.CLAIM_SLACK = 2.5
function modes.tag_lands(taggerLocal, targetLocal, reach, distance)
    if taggerLocal == nil or targetLocal == nil or taggerLocal == targetLocal then
        return false
    end
    if taggerLocal ~= 0 and targetLocal ~= 0 then return false end
    local nt, ng = gNetworkPlayers[taggerLocal], gNetworkPlayers[targetLocal]
    if nt == nil or ng == nil then return false end
    if nt.currActNum ~= ng.currActNum then return false end
    if distance == nil then
        if targetLocal == 0 then
            distance = modes.distance(0, taggerLocal)
        else
            distance = modes.distance(targetLocal, 0)
        end
    end
    if distance == nil or reach == nil then return false end
    if distance < reach and modes.tag_move(taggerLocal) then return true end
    if targetLocal == 0 and distance < reach * modes.CLAIM_SLACK
        and modes.hit_claimed(taggerLocal) then
        return true
    end
    return false
end

modes.PACKET_HIT = "gmhit"
modes.HIT_CLAIM_FRAMES = 15
modes.hitClaimAt = {}
local claimSentAt = {}

function modes.send_hit_claim(victimLocal)
    if type(victimLocal) ~= "number" or victimLocal <= 0 then return false end
    local np = gNetworkPlayers[victimLocal]
    local me = gNetworkPlayers[0]
    if np == nil or not np.connected or me == nil then return false end

    local last = claimSentAt[victimLocal]
    if last ~= nil and tagFrame - last < 5 then return false end
    claimSentAt[victimLocal] = tagFrame

    return OF.util.send_to_player(victimLocal, OF.packet_stamp({
        ofp = modes.PACKET_HIT, g = me.globalIndex, v = np.globalIndex })) == true
end

function modes.receive_hit_claim(data)
    if type(data) ~= "table" or data.ofp ~= modes.PACKET_HIT then return false end
    local me = gNetworkPlayers[0]
    if me == nil or tonumber(data.v) ~= me.globalIndex then return false end
    local li = OF.util.local_from_global(tonumber(data.g) or -1)
    if li == nil or li <= 0 then return false end
    modes.hitClaimAt[li] = tagFrame
    return true
end

function modes.hit_claimed(attackerLocal)
    local at = modes.hitClaimAt[attackerLocal]
    return at ~= nil and tagFrame - at <= modes.HIT_CLAIM_FRAMES
end

function modes.forget_hit_claims()
    modes.hitClaimAt = {}
    claimSentAt = {}
    modes.tagSeenAt = {}
    if modes.forget_contact_tags ~= nil then modes.forget_contact_tags() end
end

function modes.note_engine_hit(attackerLocal)
    if type(attackerLocal) ~= "number" or attackerLocal <= 0 then return false end
    modes.hitClaimAt[attackerLocal] = tagFrame
    return true
end
end

function modes.untaggable(localIndex)
    local m = gMarioStates[localIndex or 0]
    if m == nil or ACT_IN_CANNON == nil then return false end
    return m.action == ACT_IN_CANNON
end

local hostPhaseTimer = 0

local REPIN_FRAMES = 30
local repinIn = nil

modes.lobbyState = { held = nil, forced = nil }

function modes.room_moving()
    if not OF.util.is_host() then return false end
    if modes.state() ~= modes.ACTIVE then return false end

    if OF.util.asks(OF.speedrun, "is_running") and OF.speedrun.is_running() then return false end
    repinIn = -1
    return true
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    if repinIn == -1 then repinIn = REPIN_FRAMES end
end)

local OVERTIME_MAX = 60 * 30

modes.OVERTIME_MAX = OVERTIME_MAX

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

modes.tiebreakOff = {}

function modes.tiebreak_on(key)
    return modes.tiebreakOff[key] ~= true
end

function modes.tie_row_shown(mode)
    if mode == nil or not modes.caps(mode).tiebreak then return false end
    if type(mode.catchers) == "table" then return false end
    return true
end

modes.MAPVOTE_ACTION = "modemapvote"
modes.SIDES_ACTION = "modesides"
modes.TIEBREAK_ACTION = "modetiebreak"
hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.asks(OF.net, "register_cohost_action") then return end
    OF.net.register_cohost_action(modes.MAPVOTE_ACTION, "speedrun", function(_, key)
        key = tostring(key or "")
        if modes.BY_KEY == nil or modes.BY_KEY[key] == nil then
            return false, "No such game mode."
        end
        local ok, why = OF.mapvote.set_wanted(key, not OF.mapvote.wanted(key))
        if not ok then return false, why end
        return true, nil, key .. "=" .. (OF.mapvote.wanted(key) and "on" or "off")
    end, function(value)
        local key, on = string.match(value, "^([%w_]+)=(%a+)$")
        if key ~= nil then OF.mapvote.wantVote[key] = (on == "on") or nil end
    end)
    OF.net.register_cohost_action(modes.SIDES_ACTION, "speedrun", function()
        local ok, why = modes.set_sides(not modes.wantSides)
        if not ok then return false, why end
        return true, nil, modes.wantSides and "on" or "off"
    end, function(value) modes.wantSides = value == "on" end)
    OF.net.register_cohost_action(modes.TIEBREAK_ACTION, "speedrun", function(_, key)
        key = tostring(key or "")
        if modes.BY_KEY == nil or modes.BY_KEY[key] == nil then
            return false, "No such game mode."
        end
        local ok, why = modes.set_tiebreak(not modes.tiebreak_on(key), key)
        if not ok then return false, why end
        return true, nil, key .. "=" .. (modes.tiebreak_on(key) and "on" or "off")
    end, function(value)
        local key, on = string.match(value, "^([%w_]+)=(%a+)$")
        if key ~= nil then modes.tiebreakOff[key] = (on ~= "on") or nil end
    end)
end)

function modes.set_tiebreak(on, key)
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end
    if not OF.util.is_host() then
        return false, "Only the host decides how a level round ends."
    end
    if key == nil then
        local running = modes.current()
        key = running ~= nil and running.key
            or (OF.panel ~= nil and OF.panel.modeKey) or nil
    end
    if key == nil or modes.BY_KEY[key] == nil then return false, "No such game mode." end
    modes.tiebreakOff[key] = (on ~= true) or nil
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
modes.LAST_OUT   = "Nobody made it - @ won by going out last."
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
            table.insert(parties, { key = "t:" .. team.key, name = OF.teams.side_name(team.key),
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

    local mode = modes.current()
    if mode == nil or not modes.caps(mode).tiebreak then return nil end
    if not modes.tiebreak_on(mode.key) then return nil end
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
local lobbyArenaWas = nil

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

function modes.start_toast(mode)
    if mode == nil or not OF.util.is_host() then return 0 end
    if not OF.util.asks(OF.notify, "send_to") then return 0 end
    if OF.util.asks(OF.notify, "hushes") and OF.notify.hushes("info") then
        return 0
    end
    local scope, act = OF.roundscope, OF.roundact
    local told = 0
    for i = 0, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected then
            local hears = true
            if OF.util.asks(scope, "inside") or OF.util.asks(act, "watches") then
                hears = (OF.util.asks(scope, "inside") and scope.inside(i))
                    or (OF.util.asks(act, "watches") and act.watches(i))
                    or false
            end
            if hears and OF.notify.send_to(np.globalIndex, "@ - @", "info", 6,
                mode.name, mode.blurb) then
                told = told + 1
            end
        end
    end
    return told
end

do
local function seat_is_away(entry)
    local row = gPlayerSyncTable[entry.localIndex]
    return row ~= nil and row.ofIdle == true
end

function modes.deal_list(players)
    local kept, away = {}, {}
    for _, entry in ipairs(players or {}) do
        if seat_is_away(entry) then
            away[#away + 1] = entry
        else
            kept[#kept + 1] = entry
        end
    end
    return kept, away
end

function modes.seat_the_away(away)
    for _, entry in ipairs(away or {}) do
        modes.set_role(entry.localIndex, modes.WAITING)
    end
    if #(away or {}) > 0 then modes.forget_participants() end
end

function modes.drop_the_away()
    if not OF.util.is_host() then return 0 end
    local state = modes.state()
    if state ~= modes.ACTIVE and state ~= modes.COUNTDOWN then return 0 end
    local dropped = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        local li = entry.localIndex
        local role = modes.role(li)
        local np = entry.np or gNetworkPlayers[li]
        local dealt = role ~= nil and role ~= "" and role ~= modes.WAITING
            and not modes.OUT_ROLES[role]
        if dealt and seat_is_away(entry) then
            modes.set_role(li, modes.WAITING)
            modes.forget_participants()
            dropped = dropped + 1
            if OF.util.asks(OF.notify, "send_all") and np ~= nil and np.name ~= nil then
                OF.notify.send_all("@ is away - out of this round.", "info", 4, np.name)
            end
        end
    end
    return dropped
end
end

function modes.deal_round(mode, players, options, arenaKey, askedLimit)
    options = options or {}
    local away
    players, away = modes.deal_list(players)
    if mode.setup ~= nil then mode.setup(players, options) end
    modes.seat_the_away(away)

    if askedLimit == nil then
        OF.util.publish("ofGmLimit",
            modes.scale_clock(gGlobalSyncTable.ofGmLimit, arenaKey, mode))
    end

    OF.util.publish("ofGmSecs", gGlobalSyncTable.ofGmLimit or 0)
end

function modes.start_busy(askerLocal)
    if askerLocal == nil or not modes.is_open() then return nil end
    return OF.lang.t("A round is running - stop it first.")
end

function modes.start_round(key, options, askerLocal)
    if OF.wireWatch then OF.wire_mark("a round started") end
    if not OF.perms.can("speedrun") then
        return false, "Your rank cannot do that.", "speedrun"
    end

    local mode = modes.BY_KEY[key]
    if mode == nil then return false, "No such game mode." end

    if OF.util.asks(OF.mapvote, "running") and OF.mapvote.running()
        and not (type(options) == "table" and options.voted == true) then
        return false, OF.lang.t("The lobby is voting for the map.")
    end

    local busy = modes.start_busy(askerLocal)
    if busy ~= nil then return false, busy end

    local players = modes.participants()
    if #players < 1 then

        modes.say_who_is_sitting_out()
        return false, OF.lang.fill("That mode needs at least @ players.", mode.minPlayers or 2)
    end

    if mode.playable_here ~= nil then
        local asked, able, why = modes.as_anchor(mode.playable_here)
        if asked and not able then
            return false, why or OF.lang.t("That mode cannot be played here.")
        end
    end
    local nowhere = modes.nowhere_to_play(key)
    if nowhere ~= nil then return false, nowhere end

    if mode.studioTracksOnly ~= nil and options ~= nil
        and ((options.place ~= nil and not modes.accepts_level(key, options.place))
            or (options.arena ~= nil and options.arena ~= ""
                and not modes.accepts_arena(key, options.arena))) then
        return false, OF.lang.t(mode.studioTracksOnly)
    end

    if not OF.util.is_host() then
        if not ask_host("start", key) then
            return false, "No host to ask yet - try again in a second."
        end
        return true, "asked"
    end

    options = options or {}

    modes.roundMods = options.mods or mode.mods or ""
    if options.mods == nil and type(mode.options) == "table" then
        for _, option in ipairs(mode.options) do
            local picked = modes.option_pick(mode.key, option.key)
            for _, choice in ipairs(option.choices or {}) do
                if choice.key == picked and type(choice.mods) == "string"
                    and choice.mods ~= "" then
                    if modes.roundMods == "" then
                        modes.roundMods = choice.mods
                    else
                        modes.roundMods = modes.roundMods .. "," .. choice.mods
                    end
                end
            end
        end
    end

    if modes.is_open() or modes.is_over() then
        modes.stop(true)
    end

    if OF.util.asks(OF.mapvote, "takes_over")
        and OF.mapvote.takes_over(key, options) then
        return true, OF.lang.t("The lobby is voting for the map.")
    end

    modes.forget_participants()
    players = modes.participants()

    local waits = #players < (mode.minPlayers or 2)

    if waits then modes.say_who_is_sitting_out() end

    local arenaKey = options.arena
    if arenaKey == nil or arenaKey == "" then arenaKey = modes.arenaChoice end

    lobbyArenaWas = {
        clear = gGlobalSyncTable.ofArenaClear == true,
        place = gGlobalSyncTable.ofArenaPlace or "",
        keys = OF.util.asks(OF.arena, "armed_set") and OF.arena.armed_set() or {},
    }

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

    if place ~= nil and modes.open_pick_outgrown(key, place) then
        OF.notify.show("@ is small for this many players - everybody still gets a place.",
            "info", 6, OF.lang.t(place.name or "there"))
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
    elseif OF.arena ~= nil then

        OF.arena.close()
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

    modes.roundMods = modes.fold_dress(modes.roundMods,
        modes.level_dress(modes.round_level_for(mode, arenaKey, place,
            modes.anchor_np())))

    if place == nil and (arenaKey == nil or arenaKey == "") then
        place = modes.lead_room(mode)
    end

    if place ~= nil and arenaKey == nil and OF.util.asks(OF.net, "warp_the_round") then
        local moved, why = OF.net.warp_the_round(place.level, place.area or 1,
            place.act or 1, place.lead)
        if not moved then
            OF.notify.show("Could not send the lobby there: @", "warn", 6,
                why or OF.lang.t("no"))
        end
    end

    for i = 0, MAX_PLAYERS - 1 do
        modes.set_role(i, "")
    end

    if options.target ~= nil then options.targetNamed = true end
    if options.target == nil then options.target = modes.target_for(key) end

    OF.util.publish("ofGmKey", key)

    OF.util.publish(modes.OPTS_KEY, modes.pack_options(key))

    local askedLimit = tonumber(options.limit)
    OF.util.publish("ofGmLimit", askedLimit or mode.defaultLimit or 0)

    OF.util.publish("ofGmSeed", OF.util.random_int(1, 999999))
    OF.util.publish("ofGmElapsed", 0)

    OF.util.publish("ofGmCount", (not waits) and math.ceil(COUNTDOWN_FRAMES / 30) or nil)
    OF.util.publish("ofGmWinner", "")
    modes.publish_final(true)
    OF.util.publish("ofGmState", waits and modes.LOBBY or modes.COUNTDOWN)
    hostPhaseTimer = 0

    modes.overtimeFrames = 0

    modes.forget_nowin()

    modes.forget_settle()

    goHoldFrames = 0

    forget_ledger()

    repinIn = nil

    OF.util.publish("ofGmPlace", nil)

    if OF.teams ~= nil then
        OF.teams.begin((modes.sides_wanted(mode) and not waits) and mode or nil,
            (modes.deal_list(players)))
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

    if not mode.clockRuns and OF.util.asks(OF.rules, "lend") then
        OF.util.report(OF.rules.lend("clock", KEEP_HOLDER, modes.CLOCK_STOPPED_STOP))
    end

    if mode.allActs == true and OF.util.asks(OF.rules, "lend") then
        OF.util.report(OF.rules.lend("allstars", KEEP_HOLDER, 1))
    end

    modes.lobbyState.held = { options = options, arenaKey = arenaKey,
                   askedLimit = askedLimit, place = place, opened = waits }
    modes.lobbyState.forced = nil
    if not waits then

        if not OF.util.report(pcall(modes.deal_round, mode, players, options,
            arenaKey, askedLimit)) then
            if OF.record_fault ~= nil then OF.record_fault("mode " .. tostring(key) .. ".setup", "dealing the round failed") end

            modes.stop(true)
            return false
        end
    else
        modes.lend_lobby_rules(mode)
    end

    if mode.music ~= nil then OF.music.take_over(mode.music) end

    if not waits then modes.start_toast(mode) end

    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("started @", OF.lang.t(mode.name)))
    end
    OF.actionlog.by_hand(OF.util.presser(askerLocal),
        OF.lang.fill("started the round: @", OF.lang.t(mode.name)))
    return true
end

modes.startingLead = nil

modes.voteLead = nil

modes.seriesLead = nil

function modes.series_lead()
    if modes.seriesLead == nil then return nil end
    local running = modes.nonstop()
        or (OF.util.asks(OF.rounds, "is_running") and OF.rounds.is_running())
    if not running then return nil end
    local li = OF.util.local_from_global(modes.seriesLead)
    if li == nil or not OF.net.may_lead(li) then return nil end
    return li
end

function modes.start(key, options, askerLocal)
    if not OF.util.is_host() or not OF.util.asks(OF.net, "pick_lead") then
        return modes.start_round(key, options, askerLocal)
    end
    local voted = type(options) == "table" and options.voted == true
    local lead = nil
    if askerLocal == nil and voted and modes.voteLead ~= nil then
        local was = OF.util.local_from_global(modes.voteLead)
        if was ~= nil and OF.net.may_lead(was) then lead = was end
    end
    if lead == nil and askerLocal == nil then lead = modes.series_lead() end
    if lead == nil then lead = OF.net.pick_lead(askerLocal) end
    local outer = modes.startingLead
    modes.startingLead = lead
    local result = table.pack(pcall(modes.start_round, key, options, askerLocal))
    modes.startingLead = outer
    if not result[1] then error(result[2], 0) end
    if result[2] == true then
        if modes.state() ~= modes.OFF then
            OF.net.set_round_lead(lead)
            modes.voteLead = nil
        elseif lead ~= nil and gNetworkPlayers[lead] ~= nil then

            modes.voteLead = gNetworkPlayers[lead].globalIndex
        end
    end
    return table.unpack(result, 2, result.n)
end

function modes.lead_room(mode)
    if not OF.util.is_host() then return nil end
    local lead = modes.startingLead
    if lead == nil or lead == 0 then return nil end
    if mode == nil or mode.wholeGame or modes.owns_its_place(mode)
        or not modes.publishes_place(mode) then
        return nil
    end
    local np = gNetworkPlayers[lead]
    if np == nil or not np.connected or np.currLevelNum == nil or np.currLevelNum == 0 then
        return nil
    end

    local away = false
    for _, entry in ipairs(OF.util.connected_players()) do
        local other = entry.np
        if entry.localIndex ~= lead and OF.net.may_lead(entry.localIndex)
            and (other.currLevelNum ~= np.currLevelNum
                or other.currAreaIndex ~= np.currAreaIndex) then
            away = true
        end
    end
    if not away then return nil end
    return { level = np.currLevelNum, area = np.currAreaIndex or 1,
             act = np.currActNum or 1, lead = lead }
end

function modes.round_need(mode)
    mode = mode or modes.current()
    local need = (mode ~= nil and mode.minPlayers) or 2
    if modes.lobbyState.forced ~= nil and modes.lobbyState.forced < need then need = modes.lobbyState.forced end
    return math.max(1, need)
end

function modes.in_series()
    if modes.nonstop() then return true end
    return OF.util.asks(OF.rounds, "is_running") and OF.rounds.is_running() == true
end

function modes.waits_again()
    if modes.in_series() then return true end
    local held = modes.lobbyState.held
    return held ~= nil and held.opened == true
end

function modes.lobby_count()
    return #modes.participants()
end

function modes.lobby_place(mode)
    if modes.round_place() ~= nil then return false end
    if not modes.publishes_place(mode) then return false end
    local held = modes.lobbyState.held or {}
    local place = held.place
    if place ~= nil and (held.arenaKey == nil or held.arenaKey == "") then
        return modes.publish_place(place.level, place.area or 1, place.act or 1)
    end
    local np = modes.anchor_np()
    if np == nil or np.currLevelNum == nil or np.currLevelNum == 0 then return false end
    return modes.publish_place(np.currLevelNum, np.currAreaIndex, np.currActNum)
end

function modes.lobby_tick(mode)
    if not OF.util.is_host() or not modes.is_waiting() then return false end
    mode = mode or modes.current()
    if mode == nil then return false end
    modes.lobby_place(mode)
    local count = modes.lobby_count()
    if count >= (mode.minPlayers or 2) then
        return modes.lobby_go(mode, nil)
    end
    return false
end

function modes.lobby_go(mode, forcedOn)
    if not OF.util.is_host() then return false end
    mode = mode or modes.current()
    if mode == nil then return false end
    modes.forget_participants()
    local players = modes.participants()
    local held = modes.lobbyState.held or {}
    modes.lobbyState.forced = forcedOn
    for i = 0, MAX_PLAYERS - 1 do
        modes.set_role(i, "")
    end
    OF.util.publish("ofGmLimit", held.askedLimit or mode.defaultLimit or 0)
    OF.util.publish("ofGmSeed", OF.util.random_int(1, 999999))
    OF.util.publish("ofGmElapsed", 0)
    OF.util.publish("ofGmCount", math.ceil(COUNTDOWN_FRAMES / 30))
    OF.util.publish("ofGmWinner", "")
    modes.publish_final(true)
    OF.util.publish("ofGmPlace", nil)
    OF.util.publish("ofGmState", modes.COUNTDOWN)
    hostPhaseTimer = 0
    modes.overtimeFrames = 0
    modes.forget_nowin()
    modes.forget_settle()
    goHoldFrames = 0
    forget_ledger()
    repinIn = nil
    modes.go_pin_reset()
    if OF.teams ~= nil then
        OF.teams.begin(modes.sides_wanted(mode) and mode or nil, (modes.deal_list(players)))
    end

    local dealt = OF.util.report(pcall(modes.deal_round, mode, players,
        held.options or {}, held.arenaKey, held.askedLimit))
    if not dealt then
        modes.abandon(modes.NO_CONTEST)
        return false
    end

    modes.start_toast(mode)
    local place = held.place
    if place ~= nil and (held.arenaKey == nil or held.arenaKey == "")
        and OF.util.asks(OF.net, "warp_the_round") then
        local moved, why = OF.net.warp_the_round(place.level, place.area or 1,
            place.act or 1, place.lead)
        if not moved then
            OF.notify.show("Could not send the lobby there: @", "warn", 6,
                why or OF.lang.t("no"))
        end
    end
    return true
end

function modes.back_to_lobby(mode)
    if not OF.util.is_host() then return false end
    mode = mode or modes.current()
    if mode == nil then return false end
    modes.lobbyState.forced = nil
    for i = 0, MAX_PLAYERS - 1 do
        modes.set_role(i, "")
    end
    OF.util.publish("ofGmCount", nil)
    OF.util.publish("ofGmElapsed", 0)
    OF.util.publish("ofGmWinner", "")
    modes.publish_final(true)
    OF.util.publish("ofGmState", modes.LOBBY)

    OF.notify.send_all("Too few players for @ - waiting for more",
        "warn", 6, mode.name)
    hostPhaseTimer = 0
    modes.overtimeFrames = 0
    modes.forget_nowin()
    modes.forget_settle()
    goHoldFrames = 0
    forget_ledger()
    repinIn = nil
    modes.go_pin_reset()
    if OF.teams ~= nil then OF.teams.begin(nil, {}) end
    return true
end

function modes.lobby_rules_of(mode)
    local given = mode ~= nil and mode.lobbyRules or nil
    if type(given) == "function" then given = given(mode) end
    local list = {}
    if type(given) ~= "table" then return list end
    for key, value in pairs(given) do
        if type(key) == "string" then
            list[#list + 1] = { key = key, value = value }
        elseif type(value) == "table" and value.key ~= nil then
            list[#list + 1] = { key = value.key, value = value.value }
        end
    end
    table.sort(list, function(a, b) return tostring(a.key) < tostring(b.key) end)
    return list
end

function modes.lend_lobby_rules(mode)
    if not OF.util.is_host() then return false end
    local list = modes.lobby_rules_of(mode)
    if #list == 0 or not OF.util.asks(OF.rules, "lend_many") then return false end
    return OF.util.report(OF.rules.lend_many(list, mode.key))
end

function modes.lobby_line(mode)
    mode = mode or modes.current()
    return OF.lang.fill("Waiting for players - @",
        tostring(modes.lobby_count()) .. "/" .. tostring((mode ~= nil and mode.minPlayers) or 2))
end

function modes.lobby_join_row(panel)
    if not modes.is_waiting() then return nil end
    if not (OF.util.asks(OF.outseat, "sitting_out") and OF.outseat.sitting_out()) then
        return nil
    end
    local mode = modes.current()
    if mode == nil then return nil end
    local row = panel.row(OF.lang.fill("Join @", OF.lang.t(mode.name)) .. "  "
        .. tostring(modes.lobby_count()) .. "/" .. tostring(mode.minPlayers or 2),
        140, 255, 160, function()
            if OF.util.report(OF.outseat.set_sitting_out(false)) then panel.close() end
        end)
    if OF.util.asks(panel, "with_pulse") then row = panel.with_pulse(row, true) end
    return panel.with_help(row, "a round is waiting for players - this stops you sitting rounds out")
end

function modes.may_force(localIndex)
    localIndex = localIndex or 0
    if OF.util.asks(OF.net, "is_round_lead") and OF.net.is_round_lead(localIndex) then
        return true
    end
    if localIndex == 0 then return OF.perms.can("speedrun") end
    return OF.perms.tier(localIndex) >= OF.perms.required("speedrun", localIndex)
end

function modes.force_countdown(askerLocal)
    if not modes.is_waiting() then return false, "No round is waiting for players." end
    local asker = askerLocal or 0
    if not modes.may_force(asker) then
        return false, "Only the round's lead can start it now."
    end
    if not OF.util.is_host() then
        if not OF.util.send_to_host({ ofp = modes.PACKET_ASK, go = "force" }) then
            return false, "No host to ask yet - try again in a second."
        end
        return true, "asked"
    end
    local count = modes.lobby_count()
    if count < 1 then return false, "Nobody is taking part yet." end
    local mode = modes.current()
    if not modes.lobby_go(mode, count) then return false, "That would not start." end
    if asker ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(asker, OF.lang.fill("started @ now",
            OF.lang.t(mode ~= nil and mode.name or "the round")))
    end
    OF.actionlog.by_hand(OF.util.presser(asker), OF.lang.t("started the waiting round now"))
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

modes.FINAL_KEYS = { "ofGmFinal", "ofGmFinal2" }
modes.FINAL_WIDTH = 200

function modes.pack_final()
    local parts = {}
    for _, entry in ipairs(modes.played()) do
        local row = gPlayerSyncTable[entry.localIndex]
        local np = entry.np
        if row ~= nil and np ~= nil then
            local out = modes.OUT_ROLES[modes.role(entry.localIndex)] == true
            local time = tonumber(row.ofGmTime) or 0
            local score = tonumber(row.ofScore) or 0
            if not OF.finite(time) then time = 0 end
            if not OF.finite(score) then score = 0 end
            parts[#parts + 1] = string.format("%.0f.%.0f.%.0f.%.0f;", np.globalIndex, out and 1 or 0,
                math.floor(time * 10 + 0.5), math.floor(score))
        end
    end
    return OF.util.chunk_parts(parts, modes.FINAL_WIDTH) or {}
end

function modes.publish_final(clear)
    local chunks = clear and {} or modes.pack_final()
    for index, key in ipairs(modes.FINAL_KEYS) do
        OF.util.publish(key, chunks[index])
    end
end

do
local finalText, finalRead = nil, {}

function modes.final_of(localIndex)
    if not modes.is_over() then return nil end
    local text = OF.util.joined(modes.FINAL_KEYS)
    if text == "" then return nil end
    if text ~= finalText then
        finalText, finalRead = text, {}
        for gi, out, time, score in string.gmatch(text, "(%d+)%.(%d)%.(%-?%d+)%.(%-?%d+);") do
            finalRead[tonumber(gi)] = { out = out == "1", time = tonumber(time) / 10,
                score = tonumber(score) }
        end
    end
    local np = gNetworkPlayers[localIndex]
    if np == nil then return nil end
    return finalRead[np.globalIndex]
end
end

local function end_round(text, winner, a, b, why)
    if not OF.util.is_host() then return false end

    if modes.is_waiting() then return false end

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

    modes.publish_final(false)
    OF.util.publish("ofGmWinner", pack_result({
        text or "", tostring(a or ""), tostring(b or ""), who,
        (why ~= nil and why.rung) or "",
        (why ~= nil and why.name) or "",
        (why ~= nil and why.figures) or "" }))

    OF.util.publish("ofGmState", modes.MOMENT)
    hostPhaseTimer = 0
    return true
end

modes.finishHold = nil
function modes.finish_grace()
    local slowest = 0
    for _, entry in ipairs(modes.participants()) do
        local np = gNetworkPlayers[entry.localIndex]
        local ping = np ~= nil and tonumber(np.ping) or 0
        if entry.localIndex ~= 0 and ping > slowest then slowest = ping end
    end
    return math.min(15, math.floor(slowest / 1000 * 30 / 2))
end

function modes.finish_held()
    local mode = modes.current()
    if mode == nil or mode.resultsBy ~= "survival" then return false end
    if not OF.util.is_host() or modes.state() ~= modes.ACTIVE then return false end
    local grace = modes.finish_grace()
    if grace <= 0 then return false end
    local now = get_global_timer ~= nil and get_global_timer() or 0
    local hold = modes.finishHold
    if hold == nil or now - hold.last > 1 then
        modes.finishHold = { at = now, last = now }
        return true
    end
    hold.last = now
    return now - hold.at < grace
end

function modes.finish(text, winner, a, b)
    if modes.finish_held() then return end
    modes.finishHold = nil

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

    OF.stats.record_round(winner)

    if OF.util.asks(OF.standings, "record") then OF.standings.record() end
end

function modes.abandon(text, a, b)

    return end_round(text, nil, a, b)
end

local WINNER_NAME_LETTERS = 20

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
        (parts[2] ~= "" and OF.util.shorten(parts[2], WINNER_NAME_LETTERS) or nil),
        (parts[3] ~= "" and OF.util.shorten(parts[3], WINNER_NAME_LETTERS) or nil))
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
    return modes.won(0)
end

function modes.won(localIndex)
    localIndex = localIndex or 0
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
        return OF.teams.of(localIndex) == side
    end

    local np = gNetworkPlayers[localIndex]
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

    if lobbyArenaWas ~= nil then
        local was = lobbyArenaWas
        lobbyArenaWas = nil
        if OF.arena ~= nil and OF.util.asks(OF.arena, "arm") then
            local wanted = {}
            for _, option in ipairs(OF.arena.OPTIONS or {}) do
                if was.keys[option.key] then table.insert(wanted, option.key) end
            end
            OF.arena.arm(was.clear, wanted, was.place)
        end
    end

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

    local list = modes.plays_open(key) and modes.open_levels(nil, key)
        or modes.surveyed_levels(key)
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
        modes.seriesLead = nil
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

    local armer = askerLocal ~= nil and gNetworkPlayers[askerLocal] or nil
    modes.seriesLead = armer ~= nil and armer.globalIndex or nil
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

    if OF.util.asks(OF.rounds, "race_holds") and OF.rounds.race_holds() then
        nonstopFrames = 0
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
        OF.notify.send_all("Waiting for more players to start @", "info", 6,
            mode ~= nil and OF.lang.t(mode.name) or OF.lang.t("the next round"))
    end
end

modes.FAULT_BUDGET = 90
modes.FAULTED = "Stopped - this round's mode kept failing."
modes.faults = { streak = 0, total = 0, last = nil }

function modes.call(mode, name, ...)
    local fn = mode ~= nil and mode[name] or nil
    if type(fn) ~= "function" then return true end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return true, a, b, c end
    local label = "mode " .. tostring(mode.key) .. "." .. tostring(name)
    modes.faults.total = modes.faults.total + 1
    modes.faults.last = label
    if OF.record_fault ~= nil then OF.record_fault(label, a) end
    return false, a
end

modes.ROUND_CEILING_FREE = 30 * 60 * 30
modes.CEILING_SAID = "This round has run far past its time - ending it."
function modes.round_ceiling()
    local limit = tonumber(gGlobalSyncTable.ofGmLimit) or 0
    if limit <= 0 then return modes.ROUND_CEILING_FREE end
    return math.max(limit * 3, limit + 5 * 60) * 30
end

function modes.past_ceiling(frames)
    return (frames or 0) >= modes.round_ceiling()
end

function modes.clear_round_keys(mode)
    if mode == nil or type(mode.roundKeys) ~= "table" then return 0 end
    if not OF.util.is_host() then return 0 end
    local cleared = 0
    for _, key in ipairs(mode.roundKeys) do
        if gGlobalSyncTable[key] ~= nil then
            OF.util.publish(key, nil)
            cleared = cleared + 1
        end
    end
    return cleared
end

function modes.host_step(mode)
    if modes.call(mode, "host_update") then
        modes.faults.streak = 0
        return false
    end
    modes.faults.streak = modes.faults.streak + 1
    if modes.faults.streak < modes.FAULT_BUDGET then return false end
    modes.faults.streak = 0
    modes.abandon(modes.FAULTED)
    return true
end

local function host_update()
    if not OF.util.is_host() then return end
    local state = modes.state()
    if state == modes.OFF then return end

    local mode = modes.current()
    if mode == nil then return end

    hostPhaseTimer = hostPhaseTimer + 1

    modes.expire_seats()

    if modes.is_waiting() then
        modes.lobby_tick(mode)
        return
    end

    modes.drop_the_away()

    if state == modes.COUNTDOWN then

        if modes.waits_again() and modes.lobby_count() < modes.round_need(mode) then
            modes.back_to_lobby(mode)
            return
        end

        local held = false
        local waiting = 0
        if hostPhaseTimer >= COUNTDOWN_FRAMES then
            waiting = modes.still_loading_for(mode)
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

        if not held and hostPhaseTimer >= COUNTDOWN_FRAMES and not modes.go_pin(mode) then
            held = true
            if waiting < 1 then waiting = 1 end
        end

        local seconds = math.max(1,
            math.ceil((COUNTDOWN_FRAMES - hostPhaseTimer) / 30))
        if held then seconds = -waiting end
        if gGlobalSyncTable.ofGmCount ~= seconds then
            OF.util.publish("ofGmCount", seconds)
        end

        if not held and hostPhaseTimer >= COUNTDOWN_FRAMES then

            local mode = modes.current()
            modes.go_pin_reset()

            local np = modes.anchor_np()
            if np ~= nil and modes.publishes_place(mode) then
                modes.publish_place(np.currLevelNum, np.currAreaIndex,
                    np.currActNum)
            end

            OF.util.publish("ofGmState", modes.ACTIVE)
            OF.util.publish("ofGmElapsed", 0)
            OF.util.publish("ofGmCount", nil)

            OF.util.tell_all(OF.packet_stamp({ ofp = modes.PACKET_GO }))
            hostPhaseTimer = 0

            goHoldFrames = 0
        end

    elseif state == modes.ACTIVE then

        if hostPhaseTimer % 30 == 0 then
            local second = math.floor(hostPhaseTimer / 30)
            OF.util.publish("ofGmElapsed", second)

            sample_standing(second)

            if second == 1 and OF.util.asks(OF.teams, "say_held_note") then
                OF.teams.say_held_note()
            end
        end

        if repinIn ~= nil and repinIn > 0 then
            repinIn = repinIn - 1
            if repinIn == 0 then
                repinIn = nil
                modes.pin_round(mode)
                local np = modes.anchor_np()
                if np ~= nil and modes.publishes_place(mode) then
                    modes.publish_place(np.currLevelNum, np.currAreaIndex,
                        np.currActNum)
                end
            end
        end

        local playing = modes.still_here()
        if #playing < modes.round_need(mode) then

            if modes.in_series() then
                modes.back_to_lobby(mode)
                return
            end
            if #playing == 1 then
                modes.abandon(modes.FORFEIT, playing[1].np.name)
            else
                modes.abandon(modes.NO_CONTEST)
            end
            return
        end

        modes.room_by_watch(mode)
        if modes.host_step(mode) then return end

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

            if mode.on_timeout == nil or not modes.call(mode, "on_timeout") then
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

        if modes.past_ceiling(hostPhaseTimer) then
            OF.notify.send_all(modes.CEILING_SAID, "warn", 5)
            modes.finish(modes.TIME_UP)
            return
        end

        local limit = gGlobalSyncTable.ofGmLimit or 0
        if limit > 0 and hostPhaseTimer >= limit * 30 then

            if mode.symmetric and mode.overtime ~= nil and mode.overtime() then
                modes.overtimeFrames = (modes.overtimeFrames or 0) + 1
                if modes.overtimeFrames < OVERTIME_MAX then

                    return
                end
            end
            modes.overtimeFrames = 0

            if mode.on_timeout == nil or not modes.call(mode, "on_timeout") then

                modes.finish(modes.TIME_UP)
            end
        end

    elseif state == modes.MOMENT then

        local held = 0
        if OF.util.asks(OF.replay, "extra_frames") then
            held = OF.replay.extra_frames()
        end
        if hostPhaseTimer >= MOMENT_FRAMES + held then
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
            "warn", 8, np.name)
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

    if modes.state() == modes.LOBBY then
        local waiting = modes.current()
        if waiting ~= nil and waiting.lobby_update ~= nil and OF.util.can_play(0) then
            modes.call(waiting, "lobby_update")
        end
        return
    end
    if modes.state() ~= modes.ACTIVE then return end

    local role = modes.my_role()
    if role == "" or role == modes.WAITING then return end

    if not OF.util.can_play(0) then return end

    local mode = modes.current()

    if mode ~= nil then modes.call(mode, "update") end
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

        if not modes.refuses_latecomers() then return false end
        if not modes.is_running() then return false end
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

    modes.lobby_step(m)

    if OF.util.asks(OF.input, "shooter_keys") then OF.input.shooter_keys(m) end

    if not modes.is_running() then return end

    modes.dismount_refused_shell(m)

    lens_update(m)

    modes.rejoin_update()

    modes.remember_standing(m)

    modes.ring_wall(m)

    modes.walk_on_from_door(m)

    modes.settle_tower(m)
    modes.settle_muster(m)
    modes.settle_opening(m)

    modes.settle_respawn(m)

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
        and OF.util.can_play(0) and role ~= modes.WAITING then
        OF.util.keep_awake(m)
    end

    modes.settle_ghost()

    if mode ~= nil and mode.before_mario_update ~= nil then mode.before_mario_update(m) end
end

local lastMode = nil

local roomCameFrom = nil

modes.MY_ROUND_KEYS = { "ofScore", "ofGmTime", "ofHpGrab", "ofSplits",

                        "ofFsHits",

                        "ofCrownTo", "ofCrownGave", "ofCrownDied",

                        "ofSpotsClaim",

                        "ofMhDied", "ofMhCard",

                        "ofRollAim",

                        "ofSmashPct", "ofSmashKOs", "ofSmashFall",

                        "ofSmashGrab", "ofSmashUse", "ofSmashShare" }

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

    modes.clear_round_keys(mode)

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
    elseif modes.is_open() then

        lastMode = modes.current()
    end

    if state ~= modes.ACTIVE and state ~= modes.LOBBY and modes.roundLevel ~= nil then
        modes.forget_hold()
    end
end

function modes.lobby_step(m)
    if not modes.is_waiting() then
        modes.lobbyState.saidKey, modes.lobbyState.saidCount, modes.lobbyState.wasIn = nil, nil, false
        return false
    end
    local mode = modes.current()
    if mode == nil then return false end
    if OF.util.can_play(0) then
        if not modes.lobbyState.wasIn and roomCameFrom == nil and modes.roundLevel ~= nil then
            local here = gNetworkPlayers[0]
            if here ~= nil and here.currLevelNum ~= nil and here.currLevelNum ~= 0
                and not modes.holds_level(here.currLevelNum) then
                roomCameFrom = { level = here.currLevelNum,
                                 area = here.currAreaIndex or 1,
                                 act = here.currActNum or 1 }
            end
        end
        modes.lobbyState.wasIn = true

        local moved = modes.rejoin_update()
        modes.remember_standing(m)
        return moved
    end
    modes.lobbyState.wasIn = false
    if roomCameFrom ~= nil and OF.util.asks(OF.outseat, "in_round_room")
        and OF.outseat.in_round_room() == false then
        roomCameFrom = nil
    end
    if not (OF.util.asks(OF.speedrun, "is_excluded") and OF.speedrun.is_excluded(0)) then
        return false
    end
    local count = modes.lobby_count()
    if modes.lobbyState.saidKey == mode.key and count <= (modes.lobbyState.saidCount or 0) then return false end
    modes.lobbyState.saidKey, modes.lobbyState.saidCount = mode.key, count
    return modes.say_lobby_invite(mode, count)
end

function modes.say_lobby_invite(mode, count)
    mode = mode or modes.current()
    if mode == nil then return false end
    local who = OF.util.asks(OF.net, "round_lead") and OF.net.round_lead() or nil
    if who == nil then
        local first = modes.participants()[1]
        who = first ~= nil and first.localIndex or nil
    end
    local np = who ~= nil and gNetworkPlayers[who] or nil
    if np == nil or not np.connected then return false end

    local colour = network_get_player_text_color_string(who) or ""
    OF.util.chat(OF.util.chat_name(colour .. tostring(np.name)) .. " "
        .. OF.lang.fill("is waiting in @ - @", OF.lang.t(mode.name),
            tostring(count or modes.lobby_count()) .. "/" .. tostring(mode.minPlayers or 2)),
        "mode")
    return true
end

function modes.lobby_way_back()
    if not modes.is_waiting() then return nil end
    local back = roomCameFrom
    if back == nil then return nil end
    if OF.util.asks(OF.outseat, "in_round_room")
        and OF.outseat.in_round_room(back.level) ~= false then
        return nil
    end
    roomCameFrom = nil
    return { level = back.level, area = back.area or 1 }
end

modes.winnerOwed = false
function modes.say_the_winner(winner)
    modes.winnerOwed = false

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

        if OF.util.asks(OF.emotes, "owe_win_dance") then
            OF.emotes.owe_win_dance()
        end
    end

    if OF.util.asks(OF.celebrate, "star_over") then
        for _, localIndex in ipairs(modes.winners()) do
            OF.celebrate.star_over(localIndex)
        end
    end

end

function modes.settle_winner()
    if not modes.winnerOwed then return false end
    if modes.state() ~= modes.RESULTS then
        modes.winnerOwed = false
        return false
    end
    local winner = modes.winner_line()
    if winner == "" then return false end
    modes.say_the_winner(winner)
    return true
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

    if newVal == modes.COUNTDOWN or newVal == modes.LOBBY then
        modes.note_round_seen(true)
    end
    modes.hear_the_state(oldVal, newVal)

    modes.forget_stillness()

    modes.forget_void()

    modes.forget_escrow()

    if newVal == modes.COUNTDOWN or newVal == modes.OFF or newVal == modes.LOBBY then
        clear_my_round_row()
        OF.util.legend_forget()

        modes.liveAt = nil

        modes.forget_seats()
    end

    if newVal == modes.COUNTDOWN or newVal == modes.LOBBY then
        modes.note_round_seen(true)
    end
    if newVal == modes.OFF then
        modes.note_round_seen(false)

        if OF.util.asks(OF.util, "coin_lead_sweep") then OF.util.coin_lead_sweep() end
        if OF.util.asks(OF.net, "lead_settle") then OF.net.lead_settle() end

        modes.lead_forget()
    end

    modes.forget_still_counts()

    local reopened = (oldVal == modes.LOBBY or oldVal == modes.ACTIVE
        or oldVal == modes.COUNTDOWN) and roomCameFrom ~= nil
    if newVal == modes.COUNTDOWN or newVal == modes.LOBBY then
        modes.forget_health_claim()

        if newVal == modes.COUNTDOWN and modes.hears_round()
            and OF.util.asks(OF.notify, "clear_for_card") then
            OF.notify.clear_for_card()
        end

        local here = gNetworkPlayers[0]
        if reopened then

        elseif here ~= nil and here.currLevelNum ~= nil and here.currLevelNum ~= 0
            and OF.util.can_play(0) then
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

        modes.sound_go()

        modes.goFrames = GO_FRAMES

        if OF.util.asks(OF.music, "fanfare") and modes.hears_round() then
            OF.music.fanfare("start")
        end
        if mode ~= nil and mode.on_start ~= nil then

            if OF.util.asks(OF.roundscope, "outside_the_round")
                and OF.roundscope.outside_the_round()
                and OF.util.asks(OF.notify, "hush") then
                OF.notify.hush(true)
                local ok, err = pcall(mode.on_start)
                OF.notify.hush(false)
                if not ok then error(err, 0) end
            elseif OF.util.asks(OF.notify, "hush_start") then

                OF.notify.hush_start(true)
                local ok, err = pcall(mode.on_start)
                OF.notify.hush_start(false)
                if not ok then error(err, 0) end
            else
                mode.on_start()
            end
        end
    elseif newVal == modes.RESULTS then

        if modes.hears_round() then
            play_transition(WARP_TRANSITION_FADE_FROM_STAR, 24, 0, 0, 0)
        end

        local winner = modes.winner_line()
        if winner ~= "" then
            modes.say_the_winner(winner)
        else
            modes.winnerOwed = true
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

    if newVal == modes.LOBBY then
        if oldVal == modes.ACTIVE or oldVal == modes.COUNTDOWN then
            hand_the_round_back(false)
            lastMode = modes.current()
            if OF.util.asks(OF.util, "coin_lead_sweep") then OF.util.coin_lead_sweep() end
            modes.lead_forget()
        end
        modes.adopt_place()
    end
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.guard, "remember") then return end
    if OF.guard.owned ~= nil and OF.guard.owned.ofGmState then return end
    if gGlobalSyncTable.ofGmState ~= nil then return end
    OF.guard.remember("ofGmState", nil)
end)

modes.PACKET_GO = "gmgo"
modes.goneEarly = nil
function modes.hear_go(data)
    if not OF.util.from_host(data) then return false end
    if (gGlobalSyncTable.ofGmState or modes.OFF) ~= modes.COUNTDOWN then return false end
    if modes.goneEarly ~= nil then return false end
    modes.goneEarly = OF.packet_round()
    on_state_changed(nil, modes.COUNTDOWN, modes.ACTIVE)
    return true
end
OF.packet_kind(modes.PACKET_GO, { round = true }, modes.hear_go)

hook_on_sync_table_change(gGlobalSyncTable, "ofGmState", 0,
    function(tag, oldVal, newVal)
        if OF.util.asks(OF.guard, "repair") and OF.guard.repair("ofGmState") then
            return
        end
        if modes.goneEarly ~= nil then
            local early = modes.goneEarly
            modes.goneEarly = nil

            if oldVal == modes.COUNTDOWN and newVal == modes.ACTIVE
                and early == OF.packet_round() then
                return
            end
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

        if not modes.is_open() then return end
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

    if on and OF.util.asks(OF.outseat, "plays_free") and OF.outseat.plays_free() then
        on = false
    end

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

    if not modes.is_running() then
        if modes.is_waiting() and modes.roundLevel ~= nil then
            modes.mark_died_inside()
        end
        return
    end

    modes.mark_died_inside()

    if not OF.util.can_play(0) then return end
    modes.give_full_health()
end)

modes.OPENING = {
    snd = { heal = true, gather = false, grace = true, safe = false,
        sides = true,
        why = "Two sides on their own spawns, and each round puts them back "
           .. "there behind its own three-second count. Grace, so the first "
           .. "shot cannot land before anybody has moved." },
    firesweep = { heal = true, gather = true, grace = false, safe = true,
        why = "Nobody can touch anybody, and the first row comes three seconds "
           .. "after GO, which is the opening's grace already. Safe: a row "
           .. "stuns and costs three stars, and nothing else in the ring may hurt." },

    oneflag = { heal = true, gather = false, grace = true, safe = false,
        sides = true,
        why = "Capture the Flag's opening: the sides ring their two bases, and the "
           .. "flag at the defenders' base. Grace, so a run at the "
           .. "flag cannot be decided on the start frame." },

    rabbitchase = { heal = true, gather = true, grace = true, safe = true,
        why = "A gathered ring so the first rabbit is "
           .. "not a free point for whoever spawned beside it, grace so a "
           .. "punch cannot land before GO. Safe: a punch drops a penguin or "
           .. "nudges a rival, never kills." },
    bombsort = { heal = true, gather = false, grace = true, safe = true,
        why = "Every player is put on a ring round the middle by the mode "
           .. "itself (`place_me`), facing it, so nobody starts on a pen or "
           .. "on the first Bob-omb. Grace so a punch cannot land before GO. "
           .. "Safe: a blast throws you back, it never kills." },
    onoffclimb = { heal = true, gather = false, grace = false, safe = true,
        why = "Everybody is put round the foot of the spiral by the mode itself "
           .. "(`place_me`). Nobody can touch anybody - the round writes "
           .. "interactions to none - so a grace would stop nothing. Safe: a "
           .. "fall off a step is a walk back to the bottom, never a death." },
    lakitu = { heal = true, gather = false, grace = false, safe = true,
        why = "Every runner is put on a ring round the middle by the mode "
           .. "itself (`place_me`) and the Lakitu rides above them. Nobody "
           .. "can touch anybody - the round writes interactions to none - so "
           .. "a grace would stop nothing. Safe: a Spiny throws you back and "
           .. "pays the thrower, it never costs a life of the game's." },
    flyguy = { heal = true, gather = false, grace = false, safe = true,
        why = "Every player is put on a ring halfway out on the trampoline by "
           .. "the mode itself (`place_me`). Nobody can touch anybody - the "
           .. "round writes interactions to none - so a grace would stop "
           .. "nothing. Safe: a fall costs one of three falls, never a life "
           .. "of the game's." },
    megarampage = { heal = true, gather = false, grace = false, safe = true,
        why = "Every player is put on a ring halfway out by the mode itself "
           .. "(`place_me`), and the first giant only grows three seconds "
           .. "after GO, so nothing is decided by where anybody spawned. "
           .. "Nobody can touch anybody but the giant's feet, and a crush is "
           .. "the mode's own - a grace would stop nothing. Safe: flattened is "
           .. "a point to the giant, never a death." },

    bank = { heal = true, gather = false, grace = false, safe = true,
        why = "Collection. The coins are already spread over the room and the "
           .. "bank is pinned where the round lands, so nothing is decided in "
           .. "the first three seconds - and dying is only a walk back." },
    bossrush = { heal = true, gather = false, grace = false, safe = false,
        healAt = true,
        why = "Every runner walks into their own copy of their own boss arena, "
           .. "so there is nobody to gather to and nobody to be shoved by. The "
           .. "meter is handed back after each boss instead." },

    shooter = { heal = true, gather = false, grace = true, safe = true,
        why = "One shot kills. Everybody opens on a spawn point of their "
           .. "own, spread over the course, healed and graced, and the round "
           .. "starts when the count does." },
    bounty = { heal = true, gather = false, grace = true, safe = true,
        why = "Team Deathmatch's opening: each side opens round its own "
           .. "point, healed and graced, so the first shot is a decision "
           .. "rather than whoever stood nearest at the count." },
    coinrush = { heal = true, gather = false, grace = false, safe = true,
        why = "Collection. The rain falls over the whole room, so there is no "
           .. "start line to share, and nobody is carrying anything worth "
           .. "robbing in the first three seconds." },

    crown = { heal = true, gather = true, grace = false, safe = false,
        why = "The ball is dealt before GO and taken by punching whoever "
           .. "carries it. No grace: three seconds nobody can hit the first "
           .. "carrier is three free seconds of score for one player, and the "
           .. "gather already puts every hunter a few steps from them." },
    football = { heal = true, gather = false, grace = true, safe = true,
        sides = true,
        why = "Two sides, two halves: each side opens in its own half "
           .. "(`side_place`), every player on a spot of the side's formation "
           .. "(`side_slot`), where a kickoff starts, turned to the other goal "
           .. "with the camera behind them. The grace is the gather's window: "
           .. "the spots are dealt the frame the pitch is pinned. Safe all round "
           .. "(nobody should be able to die - health held full "
           .. "whatever the pitch or a lobby rule does); a pit or a hazard on "
           .. "a host-made pitch still sends you back to your spot." },

    volleyball = { heal = true, gather = false, grace = true, safe = true,
        sides = true,
        why = "Two sides, two halves of a court with a net between them: each "
           .. "side opens in its own half (`side_place`), every player on a "
           .. "spot of the side's rows (`side_slot`), facing the net. Safe all "
           .. "round, as Football: nobody can be hurt on a court." },
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
    glassbridge = { heal = true, gather = false, grace = false, safe = true,
        why = "Everybody starts on the near end of the bridge, which is a place "
           .. "the mode puts them rather than a ring anybody is gathered into. "
           .. "No grace, because nothing here is a swing. Safe all round: what "
           .. "takes you is a pane that breaks, and a death on the way down "
           .. "would take the fall away from the step it belongs to." },
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
           .. "short walk from it, which is a fairer opening than the scatter it "
           .. "replaces rather than a worse one. A level somebody surveyed keeps "
           .. "its own hill either way (`gamemodes.surveyed`), so there the ring "
           .. "is only a shared start line." },
    oitc = { heal = true, gather = false, grace = true, safe = true,
        why = "One round each and no reload - Deathmatch's opening: a spawn "
           .. "point each, spread over the course, and the grace." },

    rocketarena = { heal = true, gather = false, grace = true, safe = false,
        why = "Deathmatch's opening - a spawn point each, and the grace - "
           .. "but never safe: a rocket's damage is the meter itself." },
    blastgrid = { heal = true, gather = false, grace = false, safe = true,
        why = "Every player is put on a start cell of their own when the field "
           .. "stands - a gather would pile the lobby into the blocks. No "
           .. "grace: nothing can reach anybody before the first fuse burns "
           .. "down. Safe: a flame is the only thing that ends anybody, judged "
           .. "by the round, and the meter is held full." },
    shellbattle = { heal = true, gather = false, grace = false, safe = true,
        why = "Every rider is put on a point of their own at GO, facing the "
           .. "middle, already on the shell - so no gather. No grace: nobody "
           .. "holds a bomb at GO and the fighting rule is never borrowed. "
           .. "Safe, because the ride treats lava and water as road and a "
           .. "fall is a Lakitu and a balloon, never a death." },
    silverfive = { heal = true, gather = true, grace = false, safe = true,
        why = "A race to stars of your own - gathered, so nobody starts on top "
           .. "of their first five. Nobody can touch anybody - the round writes "
           .. "interactions to none - so a grace would stop nothing. Safe: a "
           .. "fall costs time, never the round." },
    wanted = { heal = true, gather = true, grace = true, safe = true,
        why = "A gathered ring so the first name is "
           .. "not a free point for whoever spawned beside it, grace so a "
           .. "punch cannot land before GO. Safe: a punch is a point, never a "
           .. "kill." },
    copsandrobbers = { heal = true, gather = false, grace = true, safe = true,
        sides = true,
        why = "Two sides starting apart, Capture the Flag's reason; grace so "
           .. "a cop landing beside a robber cannot hold them before anybody "
           .. "moved. Safe: a touch is a hold here, never a kill." },
    assassins = { heal = true, gather = true, grace = true, safe = false,
        why = "A brawl in one arena, Sumo and Bounty's opening: the grace "
           .. "stops the opening scrum spending a contract nobody has "
           .. "worked out yet. Never safe - being hit is the whole round." },
    greendemon = { heal = true, gather = false, grace = false, safe = true,
        why = "The 1-UPs are loose from GO and wake three seconds later, so "
           .. "nobody is caught on the start frame whatever the warp did. "
           .. "Nobody can touch anybody, so there is no swing to grace "
           .. "against, and the meter is held because a 1-UP is the only "
           .. "thing that puts anybody out." },
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
           .. "round for Octagon Heat's reason - falling is how this round ends "
           .. "anybody, and a death on the way down would take the fall away "
           .. "from the thing it belongs to." },
    manhunt = { heal = true, gather = false, grace = false, safe = false,
        why = "The Runner is meant to have distance the moment they can move, "
           .. "and the Hunters are already held blind for fifteen seconds or "
           .. "more - which is a grace, and a longer one than this. Not safe: a "
           .. "Runner's death is the game's own, a respawn with a full meter." },
    murder = { heal = true, gather = false, grace = false, safe = false,
        why = "A line-up would put the murderer within reach of the lobby at "
           .. "nought seconds, and the kill is a distance rather than a swing, "
           .. "so the grace could not stop it. The one mode where both would "
           .. "be worse than nothing." },
    downhill = { heal = true, gather = true, grace = false, safe = true,
        why = "Everybody starts at the top of the slide - the gather is the top. "
           .. "No grace: nobody can touch anybody's score. Safe, because the ride "
           .. "is immune to lava and water and a fall comes back at the top." },
    shellrace = { heal = true, gather = true, grace = false, safe = true,
        why = "A race, so everybody has to start from the same place - and the "
           .. "gather is pole position, where the mode lays its four-column "
           .. "grid. No grace: the fighting rule is never borrowed and items "
           .. "only fly after GO. Safe, because the ride is immune to lava "
           .. "and water anyway and a fall is a Lakitu, never a death." },

    booksquirm = { heal = true, gather = true, grace = false, safe = true,
        why = "Everybody is put in the same box, so the gather is the box - "
           .. "and it is built over the point the host walked. No grace, "
           .. "because nobody can touch anybody: the fighting rule is never "
           .. "borrowed here. Safe, because the only things that take "
           .. "anybody out of this round are a block and the open side, and "
           .. "a round decided by a hazard is not this round." },
    frenzy = { heal = true, gather = true, grace = false, safe = true,
        why = "Everybody starts on the host and the first word puts each "
           .. "player on their own slot round the middle, so the gather is "
           .. "only the walk-in. Safe, because nothing in this round may "
           .. "touch health - a hit is a lost microgame, never a wedge - and "
           .. "no grace, because nobody can touch anybody." },
    simon = { heal = true, gather = true, grace = true, safe = false,
        why = "Every call is judged against the whole lobby at once, so the "
           .. "lobby has to start the call from one place - the call that says "
           .. "get away from everybody is a different instruction if you "
           .. "already are." },
    spots = { heal = true, gather = true, grace = true, safe = false,
        why = "The other half of the same report. The circles are laid on the "
           .. "centre of mass so that nobody starts inside one, and a gather "
           .. "keeps that: the ring of circles is drawn well out round the "
           .. "gathered pile and the pile is a tight one, so every player starts "
           .. "the same walk from every circle and none of them starts in one. "
           .. "A surveyed centre is unchanged." },
    smash = { heal = true, gather = true, grace = true, safe = false,
        why = "A brawl on a stage whose edge is the whole ending, so the "
           .. "opening scrum must not be able to throw somebody off it before "
           .. "anybody has moved. The meter is handed back because this round "
           .. "never spends it - the percentage is the damage." },
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

    bumperballs = { heal = true, gather = true, grace = true, safe = true,
        why = "Solid bodies and no attack, so the only force in the round is "
           .. "somebody's own weight - and there is no window here at all: "
           .. "the shore counts the frame it is crossed. A pile shoving each "
           .. "other on frame one would put somebody in the sea before "
           .. "anybody had chosen anything, and three seconds of nobody being "
           .. "able to push is exactly what stops it. Safe, because falling is "
           .. "how this round ends anybody and a drowning on the way down "
           .. "would take the loss away from the sea it belongs to." },
    bombxing = { heal = true, gather = true, grace = false, safe = true,
        why = "Nobody can touch anybody - the round writes interactions to "
           .. "none - so a grace would stop nothing. The first Bob-ombs walk in "
           .. "from the edge with a fuse of three seconds at the least, which "
           .. "is the opening's breath. Safe: a blast is the only thing that "
           .. "puts anybody out, and the round holds health full." },

    blizzard = { heal = true, gather = true, grace = true, safe = true,
        why = "Nobody can touch anybody - the round writes interactions to "
           .. "none - and what puts you out is a snowball, which is the "
           .. "mode's own test. So the grace is the mode's as well as ours: "
           .. "everybody flickers for the opening seconds and the mode judges "
           .. "no snowball while they do, so a gathered pile is never hit as "
           .. "one by the first throws. Safe: a snowball is the only thing "
           .. "that puts anybody out, and the round holds health full so "
           .. "nothing else takes the loss away from it." },
    bombsaway = { heal = true, gather = true, grace = false, safe = true,
        why = "Nobody can touch anybody - the round writes interactions to "
           .. "none - so there is no swing for a grace to stop and a grace "
           .. "would be a lie about what takes you. What takes you is a shell, "
           .. "and a shell is aimed at the ground rather than at a player, so "
           .. "a gathered pile is denser ground rather than a target. Safe, "
           .. "for Octagon Heat's reason: the blast and the shore are how this "
           .. "round ends anybody, and a drowning would take the loss away "
           .. "from the thing it belongs to." },
    deflect = { heal = true, gather = true, grace = false, safe = true,
        why = "Nobody can touch anybody, so nothing here is a swing at a "
           .. "person and a grace would stop nothing: the flame is sent from "
           .. "the middle and hangs there for three seconds, telegraphed, "
           .. "before it moves, which is the opening's own grace already. "
           .. "Safe, because the flame and the edge are how this round takes "
           .. "a life - a burn in the lava would take it away from them." },
    chompfever = { heal = true, gather = true, grace = false, safe = true,
        why = "Nobody can touch anybody, so nothing here is a swing and a "
           .. "grace would stop nothing: what takes you is a Chain Chomp, "
           .. "which is this mode's own proximity test rather than damage. "
           .. "The pile a gather makes is a pile the first charge has to cross "
           .. "and the countdown has already let everybody out of. Safe, "
           .. "because touching the Chomp and stepping off are how this round "
           .. "ends anybody - a burn in the lava underneath would take the "
           .. "loss away from the edge it belongs to." },
    lavaleave = { heal = true, gather = true, grace = false, safe = true,
        why = "Nobody can touch anybody, so nothing here is a swing. The "
           .. "fireballs are loose on the rock from the first frame and a "
           .. "grace does not hold them off, because they are the mode's own "
           .. "test rather than damage - which is also why the gather is safe "
           .. "to take: the rock is pinned on the host and a gather is what "
           .. "puts everybody on it. Safe for the reason the other three are, "
           .. "and the lava under this one is the plainest case of it." },

    hotrope = { heal = true, gather = false, grace = true, safe = true,
        why = "Nobody can touch anybody, and what takes you is a rope - this "
           .. "mode's own angle test rather than damage - so the grace is the "
           .. "mode's as well as ours: everybody flickers for the opening "
           .. "seconds and the rope burns nobody while they do. The gather is "
           .. "off because the pinned point is the centre and the centre is "
           .. "where the rope is overhead longest. Safe, because the rope and "
           .. "the edge are how this round ends anybody, and a burn in a party "
           .. "arena's own floor would take the loss away from the rope it "
           .. "belongs to." },

    blast = { heal = true, gather = false, grace = false, safe = true,
        why = "A row of switches and a queue, and the round itself puts each "
           .. "player at one or the other as the turn goes round. A gather "
           .. "would be undone on the first turn and nobody can touch anybody, "
           .. "so both would be furniture. "
           .. "Safe is the one that earns its place: the round is decided by a "
           .. "press, and the four arenas all have a way down into lava, so "
           .. "without it a player can be bubbled out of a turn order they are "
           .. "still in for a reason the round does not own." },
    prophunt = { heal = true, gather = false, grace = false, safe = false,
        why = "Hide and Seek's opening, because it is Hide and Seek's hunt: a "
           .. "gather is a line-up and this round is the hiders spreading into "
           .. "the furniture, which the scatter already pays for. The catch is "
           .. "a close attack rather than a swing to be graced, and a hider "
           .. "keeps a person's body and can be hit - which is the mode's own "
           .. "promise on its page, so safe would be the framework taking it "
           .. "back." },

    hideballoon = { heal = true, gather = true, grace = true, safe = true,
        why = "Everybody has to walk and jump to place a balloon well, so a "
           .. "gather and a healed, graced start keep the hide phase about "
           .. "finding a spot rather than about whoever spawned readiest." },
    sardines = { heal = true, gather = false, grace = false, safe = true,
        why = "The hider is dealt before anybody can know where they will "
           .. "run, and the whole point is that the castle swallows that "
           .. "one person whole - gathering the lobby onto the host or "
           .. "racing the first three seconds decides nothing about a hunt "
           .. "this size. Hide and Seek's own row for the same reason." },
    turf = { heal = true, gather = true, grace = true, safe = false,
        why = "One shared floor rather than two bases to open on - King of "
           .. "the Hill's own reasoning applies whole: the grid is symmetric "
           .. "round the point the round measures, so the centre of mass IS "
           .. "the grid's own centre and gathering there is the fairest "
           .. "opening it has rather than a worse one. The grace holds off a "
           .. "ground pound landing on somebody who has not moved yet. Never "
           .. "safe - painting is the whole round, and there is nothing here "
           .. "for `safe` to protect." },
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
    modes.forget_tower()
end

modes.TOWER_TOP = {
    level = LEVEL_TOTWC, area = 1,
    x = 0, y = -2047, z = 10,
    radius = 700,
}

function modes.tower_spot(place, count)
    local top = modes.TOWER_TOP
    count = math.max(1, math.floor(tonumber(count) or 1))
    place = math.max(1, math.floor(tonumber(place) or 1))
    local angle = math.pi / 16 + 2 * math.pi * (place - 1) / count
    local x = top.x + math.sin(angle) * top.radius
    local z = top.z + math.cos(angle) * top.radius
    local yaw = atan2s ~= nil and atan2s(top.z - z, top.x - x) or 0
    local spot = { x = x, y = top.y, z = z, yaw = yaw }
    if OF.util.asks(OF.warp, "land_spot") then
        spot = OF.warp.land_spot(spot) or spot
    end
    return spot
end

do
local towerArrival = 0
local towerSettled = -1

function modes.forget_tower()
    towerSettled = -1
end

hook_event(HOOK_ON_LEVEL_INIT, function()
    towerArrival = towerArrival + 1
end)

local function tower_is_the_map()
    local mode = modes.current()
    if mode == nil then return false end
    if modes.owns_its_place(mode) or modes.maps_of(mode) == "own" then
        return false
    end
    local place = modes.round_place()
    if place ~= nil and place.level ~= LEVEL_TOTWC then return false end
    return true
end
modes.tower_is_the_map = tower_is_the_map

function modes.settle_tower(m)
    if m == nil or m.playerIndex ~= 0 or m.pos == nil then return false end
    if LEVEL_TOTWC == nil then return false end
    if towerSettled == towerArrival then return false end
    if not modes.is_running() then return false end
    local np = gNetworkPlayers[0]
    if np == nil or np.currLevelNum ~= LEVEL_TOTWC
        or np.currAreaIndex ~= modes.TOWER_TOP.area then
        return false
    end
    if np.currAreaSyncValid == false then return false end
    if not OF.util.can_play(0) then return false end
    if not tower_is_the_map() then return false end

    local order = {}
    for _, entry in ipairs(modes.participants()) do
        if entry.np ~= nil then table.insert(order, entry.np.globalIndex) end
    end
    table.sort(order)
    local mine = network_global_index_from_local(0)
    local place = #order + 1
    for index, globalIndex in ipairs(order) do
        if globalIndex == mine then place = index end
    end
    local spot = modes.tower_spot(place, math.max(#order, place))

    local floorY = OF.util.optional("find_floor_height", nil,
        spot.x, spot.y + 300, spot.z)
    if type(floorY) ~= "number" or math.abs(floorY - spot.y) > 200 then
        local top = modes.TOWER_TOP
        spot = { x = top.x, y = top.y, z = top.z + 200, yaw = spot.yaw }
    else
        spot.y = floorY
    end

    if not OF.util.asks(OF.doorways, "put_at") then return false end
    OF.doorways.put_at(m, spot.x, spot.y, spot.z)
    m.vel.x, m.vel.y, m.vel.z = 0, 0, 0
    m.forwardVel = 0
    m.peakHeight = spot.y
    if m.faceAngle ~= nil then m.faceAngle.y = spot.yaw end

    OF.util.camera_behind_soon()
    if ACT_IDLE ~= nil then set_mario_action(m, ACT_IDLE, 0) end
    towerSettled = towerArrival
    return true
end
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

function modes.round_seed()
    local seed = tonumber(gGlobalSyncTable.ofGmSeed)
    if seed == nil or seed < 0 then return 0 end
    return math.floor(seed)
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

    local n = #list
    if n > 1 then
        local turn = modes.round_seed() % n
        if turn > 0 then
            local turned = {}
            for i = 1, n do turned[i] = list[((i - 1 + turn) % n) + 1] end
            list = turned
        end
    end
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

    if mine == "red" or mine == "blue" then
        local zone, group = modes.team_split(mine, at, order, mode)
        if zone ~= nil then return zone, group, mine end
    end
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

do
local function host_plays()
    local hostLocal = OF.util.local_from_global(0)
    if hostLocal == nil then return false, nil end
    local scope = OF.roundscope
    if scope == nil or scope.dealt == nil then return true, hostLocal end
    return scope.dealt(hostLocal) == true, hostLocal
end
modes.muster_host_plays = host_plays

function modes.muster_anchor()
    local where = modes.round_place()
    local hostIn, hostLocal = host_plays()
    if where == nil then
        if hostIn then return 0, hostLocal end
        local best, bestLocal = nil, nil
        for _, entry in ipairs(modes.participants()) do
            local np = entry.np
            local globalIndex = np ~= nil and np.globalIndex or nil
            if globalIndex ~= nil and globalIndex ~= 0
                and np.currAreaSyncValid ~= false
                and (best == nil or globalIndex < best) then
                best, bestLocal = globalIndex, OF.util.local_from_global(globalIndex)
            end
        end
        return best, bestLocal
    end

    local function stands_there(globalIndex)
        local at = OF.util.local_from_global(globalIndex)
        local np = at ~= nil and gNetworkPlayers[at] or nil
        if np == nil then return nil end
        if np.currLevelNum ~= where.level then return nil end
        if np.currAreaIndex ~= where.area then return nil end
        if np.currAreaSyncValid == false then return nil end
        return at
    end

    local host = hostIn and stands_there(0) or nil
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

    if hnp.currActNum ~= np.currActNum or not modes.seen_now(anchor, hnp) then
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
        m.intendedYaw = m.faceAngle.y
    end

    OF.util.camera_behind_soon()

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
    local lookX, lookZ = at.x, at.z

    local mode = modes.current()
    if mode ~= nil and type(mode.side_slot) == "function" then
        local _, _, mine = modes.side_muster()
        local ok, spot = pcall(mode.side_slot, mine, place, count)
        if ok and type(spot) == "table" and type(spot.x) == "number"
            and type(spot.z) == "number" then
            x, z = spot.x, spot.z
            lookX, lookZ = spot.faceX or at.x, spot.faceZ or at.z
        elseif not ok then
            OF.util.report(false, spot)
        end
    end

    local floorY = OF.util.optional("find_floor_height", nil, x, at.y + 160, z)
    if type(floorY) ~= "number" or floorY < at.y - MUSTER_DROP then
        x, z = at.x, at.z
    end

    if not OF.util.asks(OF.doorways, "put_at") then return false end
    OF.doorways.put_at(m, x, at.y, z)

    if m.faceAngle ~= nil and atan2s ~= nil then
        m.faceAngle.y = atan2s(lookZ - z, lookX - x)
        m.intendedYaw = m.faceAngle.y
    end

    OF.util.camera_behind_soon()

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

        local want = math.min(GRACE_INVINC, math.ceil(modes.grace_left() * 30))
        if (m.invincTimer or 0) < want then
            m.invincTimer = want
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
    snd = { keep = {},
        why = "A run to a site against a rifle. Everything the lobby could "
           .. "lend is a way to a site the defenders cannot cover." },
    firesweep = { keep = {},
        why = "Rows of fire are jumped at a fixed height - every rule the lobby "
           .. "lends (gravity, jump height, speed) changes who clears them." },

    oneflag = { keep = {},
        why = "Capture the Flag's reason: one carry, stopped by standing in the "
           .. "way. A borrowed rule is a route no defender can stand on." },

    rabbitchase = { keep = {},
        why = "A chase across a course's ground. "
           .. "Every rule the lobby lends changes how a rabbit is run down." },
    bombsort = { keep = {},
        why = "Carrying and throwing on a flat floor - every rule the lobby "
           .. "lends (jumps, speed, gravity) changes how far a Bob-omb flies." },
    onoffclimb = { keep = {},
        why = "Jumps from step to step at a fixed rise - every rule the lobby "
           .. "lends (gravity, jump height) changes which steps can be reached." },
    lakitu = { keep = {},
        why = "Jumps up into a cloud at a fixed height - every rule the lobby "
           .. "lends (gravity, jump height) changes who can reach it." },
    flyguy = { keep = {},
        why = "The bounce is the engine's double and triple jump - every rule "
           .. "the lobby lends (gravity, jump height) changes how high it "
           .. "throws you and which Fly Guys you can reach." },
    megarampage = { keep = {},
        why = "A chase on a flat floor - every rule the lobby lends (speed, "
           .. "jumps, the size of a player) changes who the giant can reach." },

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

    shooter = { keep = {},
        why = "A death has to be a death rather than a float, so the round "
           .. "holds Bubble on death off and gives it back at the end. "
           .. "Everything else the lobby is playing under is left alone." },
    bounty = { keep = {},
        why = "Deathmatch's reason, and one more: a death has to be a death "
           .. "rather than a float, so Bubble on death is held off, and the "
           .. "water does not mend the meter, because a pool is not a place "
           .. "to wait out a fight over a tag. Both are given back at the end." },
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
    football = { keep = {},
        why = "The ball is the only thing anybody touches, and every rule the "
           .. "lobby lends changes how far somebody runs or jumps at it - "
           .. "CTF's and Domination's answer about the same two-sided shape." },
    volleyball = { keep = {},
        why = "The ball is the only thing anybody touches, and every rule the "
           .. "lobby lends changes how high somebody jumps at it - Football's "
           .. "answer about the same two-sided shape." },
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
    glassbridge = { keep = {},
        why = "Two panes over a drop, and the whole of the round is which one "
           .. "you chose. A knockback that throws somebody off the pane they "
           .. "chose decides a guess they already made, and bouncy bounds "
           .. "under the glass is a way of not falling when falling is the rule." },
    hideseek = { keep = {},
        why = "Hiding is not decided by the edge of the world. This is the one "
           .. "round played across the whole game rather than inside a "
           .. "measured level, but the original never offers a way back from "
           .. "stepping off it either - it uses the game's own death planes, "
           .. "the way every course does outside a round, and a hider who "
           .. "finds one is out rather than returned to be walked into." },
    hotpotato = { keep = {},
        why = "The fuse is the clock and the pass is a distance. A shove that "
           .. "throws further than the pass reaches turns a hand-off into a "
           .. "game of catch that nobody can be caught holding." },
    koth = { keep = {},
        why = "A circle to stand in, and every rule in this matrix is a way of "
           .. "moving somebody out of a circle they are standing in. There is "
           .. "nothing left for the lobby to lend that this round would "
           .. "survive." },
    oitc = { keep = {},
        why = "A death has to be a death, so Bubble on death is held off "
           .. "for the round and handed back after it." },
    rocketarena = { keep = {},
        why = "Death has to be a death, Deathmatch's ruling - the bubble is "
           .. "held off and handed back." },
    blastgrid = { keep = {},
        why = "The field is measured in cells against an ordinary run and "
           .. "jump: a lent speed, jump or gravity changes how far a player "
           .. "gets out of a cross before it burns." },
    shellbattle = { keep = {},
        why = "A battle ridden on a shell, with the ride's own speed and jump. "
           .. "Anything the lobby set about how a body moves, hits or falls "
           .. "would be a rule the shell does not read or an edge one rider "
           .. "has over the rest - Shell Racer's own answer." },
    silverfive = { keep = {},
        why = "A race of routes over a course's own points. "
           .. "Every rule the lobby lends changes the run being raced." },
    wanted = { keep = {},
        why = "A chase across a course's ground. "
           .. "Nothing the lobby set survives a punch thrown for a point." },
    copsandrobbers = { keep = {},
        why = "A chase across a course's ground, not its bounds." },
    assassins = { keep = {},
        why = "What is this lobby set to fight with - Sumo and Bounty's "
           .. "question. Nothing the lobby set survives a contract punch." },
    greendemon = { keep = {},
        why = "Nobody may touch anybody - a shove into a 1-UP would be a "
           .. "catch somebody else made for you - and the chase is measured "
           .. "against a vanilla run. Everything flattens to vanilla." },
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
    manhunt = { keep = {},
        why = "One runs with the whole game and the Hunters are held fifteen "
           .. "seconds or more behind. Nothing in the chase is measured off the "
           .. "edge of the world: the game's own death planes take a Runner who "
           .. "steps off it, and the game's own respawn brings them back." },
    murder = { keep = {},
        why = "A murderer lost in a crowd, and in the castle that crowd is "
           .. "spread over three levels. The kill is a knife at close range "
           .. "rather than a shove, so the edge of the world decides nothing "
           .. "here either way - and the original leaves it to the game's own "
           .. "death planes rather than bouncing anybody back in, the same as "
           .. "every other way to go out in this round." },
    downhill = { keep = {},
        why = "Tricks are the score and air is what they are made of: a borrowed "
           .. "jump, speed or gravity rule would be a trick nobody else can land." },
    shellrace = { keep = {},
        why = "A race ridden on a shell, with its own speed rules - coins, "
           .. "boosts and items. A ride that gains half again its speed off the "
           .. "world's edge is a time nobody else on the track can answer, and "
           .. "the fighting rule is never borrowed here in the first place." },
    booksquirm = { keep = {},
        why = "A floor four cells across with a row of blocks coming down on "
           .. "it. Anything that changes how far a step goes changes which "
           .. "cell is reachable, and the fighting rule is never borrowed "
           .. "here in the first place." },
    frenzy = { keep = {},
        why = "Every microgame is a few seconds of one move, one jump or one "
           .. "press, judged against the vanilla game's own numbers. A lobby "
           .. "rule that changes how far a jump goes changes which ! block "
           .. "can be reached." },
    simon = { keep = {},
        why = "Every call is judged against the whole lobby at once and half of "
           .. "them are about where the other players are. A lobby that can "
           .. "shove each other during GET TOGETHER is a call nobody can "
           .. "obey." },
    spots = { keep = {},
        why = "One circle too few when the music stops. Being pushed out of "
           .. "the circle you reached first is the single thing this round "
           .. "must never let a leftover lobby setting decide." },
    smash = { keep = {},
        why = "Every one of the three is written by this mode's own `setup`, "
           .. "which runs after the flattening and wins: fighting on, the "
           .. "game's own normal knockback because the percentage curve is "
           .. "multiplied onto it, and bubbling off because a bubbled player "
           .. "has not left the stage and a stock round would never end. "
           .. "Keeping any of the lobby's would be keeping a number this "
           .. "mode's whole curve is measured against." },
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

    bumperballs = { keep = {},
        why = "The round declares its own interactions - solid bodies that "
           .. "cannot damage - and that is the whole feel of it, so a "
           .. "lobby's dial has nothing left to lend. The knockback dial is "
           .. "the one that would decide the mode outright: every knock here "
           .. "is meant to be your own weight, and a session left at silly "
           .. "turns the first touch of the round into the sea." },
    bombxing = { keep = {},
        why = "Staying out of a blast is running, and a chaser's speed is set "
           .. "as a share of an ordinary run. Every rule the lobby lends "
           .. "changes the run the Bob-ombs were measured against." },
    blizzard = { keep = {},
        why = "Dodging is running and jumping on a slick floor, and every rule "
           .. "the lobby lends changes one of the two - a speed, a jump, a "
           .. "gravity. The throws are aimed at where a normal runner will be, "
           .. "so the round's own feet are part of the aim." },
    bombsaway = { keep = {},
        why = "Nobody can touch anybody - the round writes interactions to "
           .. "none - so two of the three could not reach it today. It "
           .. "flattens all three anyway, for Red Light, Green Light's reason: "
           .. "a mode that grows a way for players to touch each other next "
           .. "month would inherit the session's dial in silence. The bounce "
           .. "is live now, and it is a way back onto an island whose shore is "
           .. "the whole round." },
    deflect = { keep = {},
        why = "One open floor and one flame on it. A bounce off the world's "
           .. "edge is a way off the floor the flame cannot follow, and the "
           .. "other two cannot reach a round that writes interactions to "
           .. "none - flattened rather than excused, for Shell Shower's reason." },
    chompfever = { keep = {},
        why = "A platform over lava with a hazard loose on it, and the "
           .. "platform narrows all round. A bounce off the world's edge is a "
           .. "way back onto a floor that is being taken away, which is the "
           .. "one thing this round is about; the other two cannot reach a "
           .. "round that writes interactions to none, and are flattened "
           .. "rather than excused on those grounds." },
    lavaleave = { keep = {},
        why = "The rock is the floor and the fireballs are the round, and "
           .. "neither is decided by the edge of the world. A player put back "
           .. "into the level by the lobby's bouncy bounds has taken a route "
           .. "off the plateau that the plateau does not offer - and the other "
           .. "two are flattened for Shell Shower's reason rather than excused "
           .. "because nothing can reach them today." },

    hotrope = { keep = {},
        why = "One still floor with one hazard turning over it, and the "
           .. "hazard is answered by a jump. A bounce off the world's edge is "
           .. "a way back onto a floor whose edge is half the loss, and any "
           .. "dial that touches jump height would decide the round outright - "
           .. "the height of a jump is the whole of the skill here, which is "
           .. "the original's own one button. The third cannot reach a round "
           .. "that writes interactions to none, and is flattened for Bombs "
           .. "Away's reason rather than excused." },

    blast = { keep = {},
        why = "The round is standing on a switch in a row: a bounce or a "
           .. "knock would move somebody off the switch they chose or onto "
           .. "one they did not, so all three are flattened - Red Light, Green "
           .. "Light's argument, and since package E gave the round a body it "
           .. "is the reason rather than a precaution." },
    prophunt = { keep = {},

        why = "This is one course at a time, a measured place rather than the "
           .. "whole game, and a prop bounced back into the level has moved - "
           .. "which is the one thing a prop must not do." },

    hideballoon = { keep = {},
        why = "Hiding and hunting are both a walk across the course's own "
           .. "ground, not a physics puzzle - nothing the lobby could lend "
           .. "this round changes where a balloon is or how close somebody "
           .. "has walked to it." },
    sardines = { keep = {},
        why = "A find is a touch, not a race across the world's edge, and "
           .. "the whole castle is already the round's own arena - nothing "
           .. "the lobby could lend changes what standing next to somebody "
           .. "means." },
    turf = { keep = {},
        why = "A tile is painted by standing on it, and every rule in this "
           .. "matrix is a way of not being where you are standing. There is "
           .. "nothing left for the lobby to lend that this round would "
           .. "survive - the same answer King of the Hill and Domination give "
           .. "about the same shape." },
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

function modes.refuses_shell_rides(localIndex)
    if not modes.is_running() then return false end
    local mode = modes.current()
    if mode == nil or mode.shellRides == true then return false end
    if not OF.util.asks(OF.roundscope, "inside") then return false end
    return OF.roundscope.inside(localIndex or 0) == true
end

hook_event(HOOK_ALLOW_INTERACT, function(m, _, interactType)
    if m == nil or m.playerIndex ~= 0 then return end
    if interactType ~= INTERACT_KOOPA_SHELL then return end
    if modes.refuses_shell_rides(0) then return false end
end)

function modes.is_vanilla_shell_ride(action)
    if action == nil then return false end
    return (ACT_RIDING_SHELL_GROUND ~= nil and action == ACT_RIDING_SHELL_GROUND)
        or (ACT_RIDING_SHELL_JUMP ~= nil and action == ACT_RIDING_SHELL_JUMP)
        or (ACT_RIDING_SHELL_FALL ~= nil and action == ACT_RIDING_SHELL_FALL)
end

function modes.dismount_refused_shell(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if not modes.is_vanilla_shell_ride(m.action) then return false end
    if not modes.refuses_shell_rides(0) then return false end
    if type(mario_stop_riding_object) == "function" then
        mario_stop_riding_object(m)
    end
    set_mario_action(m, ACT_FREEFALL, 0)
    return true
end

function modes.refuses_player_solidity()
    if not modes.is_running() then return false end
    local mode = modes.current()
    return mode ~= nil and mode.unsolidInAFight == true
end

function modes.sides_pass_through(a, b)
    if a == nil or b == nil or a == b then return false end
    if not modes.is_running() then return false end
    local mode = modes.current()
    if mode == nil or mode.solidAcrossSides ~= true then return false end

    if modes.is_out(a) or modes.is_out(b) then return true end
    local roleA = modes.role(a)
    return roleA ~= "" and roleA == modes.role(b)
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
    if m == nil or interactType ~= INTERACT_PLAYER then return end

    if modes.sides_pass_through(m.playerIndex, player_of_object(o)) then return false end
    if m.playerIndex ~= 0 then return end
    if modes.refuses_player_solidity() then return false end

    if not modes.is_running() or not modes.refuses_latecomers() then return end
    if modes.left_out_of_this_round(0) then return false end
    if modes.left_out_of_this_round(player_of_object(o)) then return false end
end)
end

modes.tokens = modes.tokens or {}

function modes.show_token(name, model, at, spin, behaviour, animate)
    if name == nil or at == nil then return nil end

    local m = gMarioStates[0]
    if m == nil or m.marioObj == nil then return nil end

    if modes.state() ~= modes.OFF and not modes.hears_round() then
        modes.hide_token(name)
        return nil
    end

    local token = modes.tokens[name]
    if token == nil or token.activeFlags == 0 then
        token = OF.slots.spawn_non_sync(
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
    if animate then
        if not OF.util.has_flag(token.header.gfx.node.flags or 0, GRAPH_RENDER_BILLBOARD) then
            OF.util.optional("obj_set_billboard", nil, token)
        end
        token.oAnimState = ((token.oAnimState or 0) + 1) % 0x10000
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
    if index == 0 then
        local anchor = modes.round_anchor()
        if anchor ~= nil then index = anchor end
    end
    local m = gMarioStates[index]
    local np = gNetworkPlayers[index]
    if m == nil or np == nil or m.pos == nil then return nil end
    return {
        x = m.pos.x, y = m.pos.y, z = m.pos.z,
        level = np.currLevelNum, area = np.currAreaIndex,
    }
end

function modes.round_anchor()
    if not OF.util.is_host() then return nil end

    if modes.inAnchorView then return nil end
    if modes.state() == modes.OFF then
        local starting = modes.startingLead
        if starting ~= nil and starting ~= 0 then return starting end
        return nil
    end
    local scope = OF.roundscope
    if scope == nil or scope.dealt == nil then return nil end
    local lead = OF.util.asks(OF.net, "round_lead") and OF.net.round_lead() or nil
    if lead ~= nil and scope.dealt(lead) == true then
        if lead == 0 then return nil end
        return lead
    end
    if scope.dealt(0) == true then return nil end
    local best, bestGlobal = nil, nil
    for i = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected and scope.dealt(i) == true then
            if bestGlobal == nil or np.globalIndex < bestGlobal then
                best, bestGlobal = i, np.globalIndex
            end
        end
    end
    return best
end

do
modes.CAM_WALLS_HOLDER = "gamemodes-walls"
local camWallsLent = false

function modes.settle_cam_walls()
    local scope = OF.roundscope
    local want = modes.state() ~= modes.OFF and scope ~= nil
        and scope.about ~= nil and scope.about(0) == true
    if want == camWallsLent then return false end
    local util = OF.util
    if want then
        util.lend_setting("cam.collision", modes.CAM_WALLS_HOLDER,
            "camera_config_is_collision_enabled", "camera_config_enable_collisions", true)
        util.lend_setting("cam.romhackCollision", modes.CAM_WALLS_HOLDER,
            "camera_romhack_get_collisions", "camera_romhack_set_collisions", 1)
    else
        util.return_setting("cam.collision", modes.CAM_WALLS_HOLDER)
        util.return_setting("cam.romhackCollision", modes.CAM_WALLS_HOLDER)
    end
    camWallsLent = want
    return true
end
end

modes.PACKET_TAG = "gmtag"
function modes.hand_tag(aLocal, vLocal)
    local mode = modes.current()
    if mode == nil or type(mode.on_tag) ~= "function" then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    if aLocal == nil or vLocal == nil or aLocal == vLocal then return false end
    local ok = pcall(mode.on_tag, aLocal, vLocal)
    return ok
end

function modes.on_pvp_attack(attacker, victim)
    if attacker == nil or victim == nil then return false end

    if victim.playerIndex == 0 and attacker.playerIndex ~= nil
        and attacker.playerIndex ~= 0 and modes.state() == modes.ACTIVE then
        modes.note_engine_hit(attacker.playerIndex)
    end
    local mode = modes.current()
    if mode == nil or type(mode.on_tag) ~= "function" then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    local a, v = attacker.playerIndex, victim.playerIndex
    if a == nil or v == nil or a == v then return false end

    if a ~= 0 and v ~= 0 then return false end
    if OF.util.is_host() then return modes.hand_tag(a, v) end
    local na, nv = gNetworkPlayers[a], gNetworkPlayers[v]
    if na == nil or nv == nil then return false end
    return OF.util.send_to_host(OF.packet_stamp({
        ofp = modes.PACKET_TAG, a = na.globalIndex, v = nv.globalIndex })) == true
end

modes.PACKET_CLAIM = "gmclaim"
modes.PACKET_CLAIM_ACK = "gmclack"
modes.CLAIM_RESEND = 20
modes.CLAIM_TRIES = 4
modes.claimsOut = {}
modes.claimSeq = 0
modes.claimsJudged = {}

modes.NEAR = "near"
modes.NEAR_EVERY = 10
modes.NEAR_FRESH = 20
modes.NEAR_SLACK = 2.5
modes.nearAt = {}
modes.nearSaidAt = nil

function modes.say_near()
    if OF.util.is_host() then return false end
    local now = get_global_timer ~= nil and get_global_timer() or 0
    if modes.nearSaidAt ~= nil and now - modes.nearSaidAt < modes.NEAR_EVERY then return false end
    modes.nearSaidAt = now
    return modes.claim(modes.NEAR)
end

function modes.near_fresh(localIndex)
    local at = modes.nearAt[localIndex]
    if at == nil or localIndex == 0 then return false end
    local now = get_global_timer ~= nil and get_global_timer() or 0
    return now - at <= modes.NEAR_FRESH
end

function modes.reach_for(localIndex, reach)
    if modes.near_fresh(localIndex) then return reach * modes.NEAR_SLACK end
    return reach
end

function modes.claim(what)
    if type(what) ~= "string" or what == "" then return false end
    local mode = modes.current()
    if mode == nil or (type(mode.on_claim) ~= "function" and what ~= modes.NEAR) then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    if OF.util.is_host() then
        local ok, said = pcall(mode.on_claim, 0, what)
        return ok and said == true
    end
    local me = gNetworkPlayers[0]
    if me == nil then return false end

    if what == modes.NEAR then
        return OF.util.send_to_host(OF.packet_stamp({ ofp = modes.PACKET_CLAIM,
            g = me.globalIndex, w = what })) == true
    end
    modes.claimSeq = modes.claimSeq + 1
    local data = OF.packet_stamp({ ofp = modes.PACKET_CLAIM, g = me.globalIndex,
        w = what, n = modes.claimSeq })
    modes.claimsOut[modes.claimSeq] = { data = data, wait = 0, tries = 1 }
    return OF.util.send_to_host(data) == true
end

function modes.claim_frame()
    local sent = 0
    if next(modes.claimsOut) == nil then return 0 end
    if OF.util.is_host() or modes.state() ~= modes.ACTIVE then
        modes.claimsOut = {}
        return 0
    end
    local hostLocal = OF.util.local_from_global(0)
    local np = hostLocal ~= nil and gNetworkPlayers[hostLocal] or nil
    local gap = math.max(modes.CLAIM_RESEND,
        math.ceil((np ~= nil and tonumber(np.ping) or 0) / 1000 * 30 * 1.5))
    for n, out in pairs(modes.claimsOut) do
        if out.data.r ~= OF.packet_round() then
            modes.claimsOut[n] = nil
        else
            out.wait = out.wait + 1
            if out.wait >= gap then
                if out.tries >= modes.CLAIM_TRIES then
                    modes.claimsOut[n] = nil
                else
                    out.wait, out.tries = 0, out.tries + 1
                    OF.util.send_to_host(out.data)
                    sent = sent + 1
                end
            end
        end
    end
    return sent
end

function modes.receive_claim_ack(data)
    if not OF.util.from_host(data) then return false end
    local n = tonumber(data.n)
    if n == nil or modes.claimsOut[n] == nil then return false end
    modes.claimsOut[n] = nil
    return true
end

function modes.forget_claims()
    modes.claimsOut = {}
    modes.claimsJudged = {}
    modes.nearAt = {}
end

function modes.receive_claim(data, sender)
    if type(data) ~= "table" or data.ofp ~= modes.PACKET_CLAIM then return false end
    if not OF.util.is_host() then return false end
    local li = sender
    if type(li) ~= "number" or li <= 0 or type(data.w) ~= "string" then return false end
    local n = tonumber(data.n)
    local judged = modes.claimsJudged[li]
    if n ~= nil and judged ~= nil and judged[n] ~= nil then
        OF.util.send_to_player(li, { ofp = modes.PACKET_CLAIM_ACK, n = n })
        return judged[n]
    end
    local mode = modes.current()
    if modes.state() ~= modes.ACTIVE or mode == nil then return false end
    local ok, said = true, true
    if data.w == modes.NEAR then
        modes.nearAt[li] = get_global_timer ~= nil and get_global_timer() or 0
    elseif type(mode.on_claim) == "function" then
        ok, said = pcall(mode.on_claim, li, data.w)
    else
        return false
    end
    local answer = ok and said == true
    if n ~= nil then
        if judged == nil then
            judged = {}
            modes.claimsJudged[li] = judged
        end
        judged[n] = answer
        OF.util.send_to_player(li, { ofp = modes.PACKET_CLAIM_ACK, n = n })
    end
    return answer
end

function modes.receive_tag(data, sender)
    if type(data) ~= "table" or data.ofp ~= modes.PACKET_TAG then return false end
    if not OF.util.is_host() then return false end
    local a = OF.util.local_from_global(tonumber(data.a) or -1)
    local v = OF.util.local_from_global(tonumber(data.v) or -1)
    if a == nil or v == nil then return false end
    if type(sender) ~= "number" or (sender ~= a and sender ~= v) then return false end
    return modes.hand_tag(a, v)
end

hook_event(HOOK_ON_PVP_ATTACK, function(attacker, victim)
    modes.on_pvp_attack(attacker, victim)
end)

modes.CONTACT_REACH = 150
modes.CONTACT_EVERY = 15
do
local contactSaidAt = {}
function modes.forget_contact_tags()
    contactSaidAt = {}
end
function modes.contact_tags()
    local mode = modes.current()
    if mode == nil or type(mode.on_tag) ~= "function" then return 0 end
    if modes.state() ~= modes.ACTIVE then return 0 end
    if not OF.util.can_play(0) then return 0 end
    local reach = tonumber(mode.tagReach) or modes.CONTACT_REACH
    local now = get_global_timer ~= nil and get_global_timer() or 0
    local told = 0
    for i = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected and modes.tag_kind(gMarioStates[i]) == "contact"
            and modes.tag_lands(i, 0, reach)
            and (contactSaidAt[i] == nil or now - contactSaidAt[i] >= modes.CONTACT_EVERY) then
            contactSaidAt[i] = now
            if OF.util.is_host() then
                modes.hand_tag(i, 0)
            else
                local me = gNetworkPlayers[0]
                OF.util.send_to_host(OF.packet_stamp({ ofp = modes.PACKET_TAG,
                    a = np.globalIndex, v = me.globalIndex }))
            end
            told = told + 1
        end
    end
    return told
end
end

modes.RING_FREE = { sumo = true, bumperballs = true, koth = true }
modes.RING_WALLED = { chompfever = true, bombxing = true, bombsaway = true,
                      hotrope = true, lavaleave = true, firesweep = true }

modes.RING_WALL_INSET = 5

modes.WALK_ON_DOORS = { hideseek = true, prophunt = true, sardines = true, manhunt = true }

function modes.walk_on_from_door(m)
    if m == nil or m.playerIndex ~= 0 or ACT_WARP_DOOR_SPAWN == nil then return false end
    if m.action ~= ACT_WARP_DOOR_SPAWN or (m.actionState or 0) < 1 then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    local mode = modes.current()
    if mode == nil or not modes.WALK_ON_DOORS[mode.key] then return false end
    if ACT_IDLE == nil then return false end
    set_mario_action(m, ACT_IDLE, 0)
    return true
end

function modes.arena_ring()
    local mode = modes.current()
    if mode == nil or modes.RING_FREE[mode.key] then return nil end
    if type(mode.arenaRing) == "function" then
        local ok, at = pcall(mode.arenaRing)
        if ok and type(at) == "table" and type(at.x) == "number"
            and type(at.z) == "number" and type(at.r) == "number" then
            return at
        end
        return nil
    end
    if modes.RING_WALLED[mode.key] and OF.ring ~= nil
        and type(OF.ring.at) == "function" and type(OF.ring.radius) == "function" then
        local at = OF.ring.at()
        if at == nil then return nil end
        at.r = OF.ring.radius()
        return at
    end
    return nil
end

function modes.ring_wall(m)
    if m == nil or m.playerIndex ~= 0 then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    local scope = OF.roundscope
    if scope == nil or scope.dealt == nil or scope.dealt(0) ~= true then return false end
    if modes.is_out(0) then return false end
    local at = modes.arena_ring()
    if at == nil then return false end
    local np = gNetworkPlayers[0]
    if np == nil then return false end
    if at.level ~= nil and np.currLevelNum ~= at.level then return false end
    if at.area ~= nil and np.currAreaIndex ~= at.area then return false end
    return OF.util.wall_in(m, at.x, at.z, math.max(0, at.r - modes.RING_WALL_INSET))
end

function modes.as_anchor(fn, ...)
    local anchor = modes.round_anchor()
    if anchor == nil then return pcall(fn, ...) end

    local realM, realN, realP = gMarioStates, gNetworkPlayers, gPlayerSyncTable
    local function view(real)
        return setmetatable({}, { __index = function(_, i)
            if i == 0 then return real[anchor] end
            if i == anchor then return real[0] end
            return real[i]
        end })
    end
    gMarioStates, gNetworkPlayers = view(realM), view(realN)
    if realP ~= nil then gPlayerSyncTable = view(realP) end
    modes.inAnchorView = true
    OF.util.viewSwapped = true
    local result = table.pack(pcall(fn, ...))
    modes.inAnchorView = false
    OF.util.viewSwapped = nil
    gMarioStates, gNetworkPlayers, gPlayerSyncTable = realM, realN, realP
    return table.unpack(result, 1, result.n)
end

function modes.anchor_np()
    local anchor = modes.round_anchor()
    return gNetworkPlayers[anchor or 0]
end

do
modes.ROOM_BY_KEY = "ofGmRoomBy"
modes.PACKET_LEAD_RUN = "gmlrun"
modes.PACKET_LEAD_SAYS = "gmlsays"
modes.PACKET_LEAD_HAND = "gmlhand"
modes.LEAD_PIN_WAIT = 150

modes.LEAD_PART_BYTES = 2000
modes.LEAD_PART_PAIRS = 60
modes.ROOM_WATCH_EVERY = 30

local ask = nil
local askSerial = 0
local goPin = nil
local job = nil
local watchTick = 0

local function lead_same_room(a, b)
    return a ~= nil and b ~= nil and a.currLevelNum == b.currLevelNum
        and a.currAreaIndex == b.currAreaIndex and a.currActNum == b.currActNum
end

function modes.room_by_global()
    local g = gGlobalSyncTable[modes.ROOM_BY_KEY]
    if type(g) ~= "number" then return nil end
    return g
end

function modes.asks_the_room()
    local g = modes.room_by_global()
    if g == nil then return OF.util.is_host() end
    if OF.util.is_host() then return false end
    local me = gNetworkPlayers[0]
    return me ~= nil and me.globalIndex == g
end

function modes.room_by_lead()
    return OF.util.is_host() and modes.room_by_global() ~= nil
end

function modes.lead_for_pin(mode)
    if not OF.util.is_host() then return nil end
    if mode == nil or type(mode.leadPin) ~= "table" then return nil end
    local lead = OF.util.asks(OF.net, "round_lead") and OF.net.round_lead() or nil
    if lead == nil or lead == 0 then return nil end
    local scope = OF.roundscope
    if scope == nil or scope.dealt == nil or scope.dealt(lead) ~= true then return nil end
    local np = gNetworkPlayers[lead]
    if np == nil or not np.connected then return nil end
    if lead_same_room(np, gNetworkPlayers[0]) then return nil end
    return lead
end

local function set_room_by(g)
    if gGlobalSyncTable[modes.ROOM_BY_KEY] ~= g then
        OF.util.publish(modes.ROOM_BY_KEY, g)
    end
end

function modes.pin_round(mode)
    if not OF.util.is_host() then return "done" end
    if mode == nil or (mode.pin == nil and mode.leadPin == nil) then return "done" end
    local lead = modes.lead_for_pin(mode)
    if lead ~= nil and mode.pin == nil then

        ask = nil
        set_room_by(gNetworkPlayers[lead].globalIndex)
        return "done"
    end
    if lead ~= nil then
        askSerial = askSerial % 30000 + 1
        local g = gNetworkPlayers[lead].globalIndex
        ask = { serial = askSerial, lead = g, key = mode.key, frames = 0,
                done = false, parts = {} }
        set_room_by(g)
        local data = { ofp = modes.PACKET_LEAD_RUN, s = askSerial, mk = mode.key }
        local lp = mode.leadPin
        if type(lp.give) == "function" then
            local ok, ctx = pcall(lp.give)
            if ok and type(ctx) == "table" then
                for k, v in pairs(ctx) do data["c_" .. tostring(k)] = v end
            end
        end

        OF.util.report(OF.util.send_to_player(lead, data))
        return "asked"
    end
    ask = nil
    set_room_by(nil)
    if mode.pin ~= nil then OF.util.report(modes.as_anchor(mode.pin)) end
    return "done"
end

function modes.go_pin(mode)
    if mode == nil or (mode.pin == nil and mode.leadPin == nil) then return true end
    if goPin == nil then
        goPin = modes.pin_round(mode)
        return goPin == "done"
    end
    if goPin == "done" then return true end
    if ask == nil or ask.done then
        goPin = "done"
        return true
    end
    ask.frames = ask.frames + 1
    if ask.frames <= modes.LEAD_PIN_WAIT then return false end
    ask = nil
    set_room_by(nil)
    OF.util.report(modes.as_anchor(mode.pin))
    goPin = "done"
    return true
end

function modes.go_pin_reset()
    goPin = nil
end

function modes.lead_pin_state()
    if ask == nil then return nil end
    return { serial = ask.serial, lead = ask.lead, key = ask.key,
             done = ask.done, frames = ask.frames }
end

function modes.lead_forget()
    ask, job, goPin = nil, nil, nil
    if OF.util.is_host() and gGlobalSyncTable[modes.ROOM_BY_KEY] ~= nil then
        OF.util.publish(modes.ROOM_BY_KEY, nil)
    end
end

local function run_held(fn, ...)
    local util = OF.util
    local outer = util.publishHeld
    local held = {}
    util.publishHeld = held
    local result = table.pack(pcall(fn, ...))
    util.publishHeld = outer
    return held, result
end

local function value_size(v)
    if type(v) == "string" then return #v + 3 end
    return 10
end

local function says_part(parts, serial, key, tag)
    local part = { ofp = modes.PACKET_LEAD_SAYS, s = serial, mk = key, t = tag }
    parts[#parts + 1] = part
    return part
end

function modes.lead_send(serial, key, held, facts, tag)
    local parts = {}
    local cur, bytes, n = says_part(parts, serial, key, tag), 60, 0
    for _, entry in ipairs(held or {}) do
        local size = #tostring(entry.key) + value_size(entry.value) + 12
        if n > 0 and (bytes + size > modes.LEAD_PART_BYTES
            or n * 2 >= modes.LEAD_PART_PAIRS) then
            cur, bytes, n = says_part(parts, serial, key, tag), 60, 0
        end
        n = n + 1
        cur.n = n
        cur["k" .. n] = entry.key
        if entry.value == nil or entry.value == "" then
            cur["z" .. n] = 1
        else
            cur["v" .. n] = entry.value
        end
        bytes = bytes + size
    end
    for k, v in pairs(facts or {}) do
        if v ~= nil and v ~= "" then
            local size = #tostring(k) + value_size(v) + 8
            if bytes + size > modes.LEAD_PART_BYTES then
                cur, bytes = says_part(parts, serial, key, tag), 60
            end
            cur["f_" .. tostring(k)] = v
            bytes = bytes + size
        end
    end
    local sent = true
    for index, part in ipairs(parts) do
        part.p, part.pn = index, #parts
        if OF.util.send_to_host(part) ~= true then sent = false end
    end
    return sent, #parts
end

function modes.receive_lead_run(data)
    if type(data) ~= "table" or data.ofp ~= modes.PACKET_LEAD_RUN then return false end
    if OF.util.is_host() or not OF.util.from_host(data) then return false end
    if not (OF.util.asks(OF.net, "is_round_lead") and OF.net.is_round_lead(0)) then
        return false
    end
    local mode = modes.current()
    if mode == nil or mode.key ~= data.mk or type(mode.leadPin) ~= "table" then
        return false
    end
    if modes.state() == modes.OFF then return false end
    local ctx = {}
    for k, v in pairs(data) do
        if type(k) == "string" and k:sub(1, 2) == "c_" then ctx[k:sub(3)] = v end
    end
    job = { serial = tonumber(data.s) or 0, key = mode.key, frames = 0,
            ctx = ctx, started = false, held = {} }
    modes.lead_job_frame()
    return true
end

function modes.lead_job_frame()
    if job == nil then return false end
    local mode = modes.current()
    if mode == nil or mode.key ~= job.key or modes.state() == modes.OFF
        or type(mode.leadPin) ~= "table" then
        job = nil
        return false
    end
    job.frames = job.frames + 1
    if job.frames > modes.LEAD_PIN_WAIT then
        job = nil
        return false
    end
    local me = gNetworkPlayers[0]
    if me == nil or me.currAreaSyncValid ~= true then return false end
    local lp = mode.leadPin
    local finished = true
    local held, result
    if not job.started then
        job.started = true
        if type(lp.given) == "function" then pcall(lp.given, job.ctx) end
        held, result = run_held(lp.run or mode.pin)
        if type(lp.step) == "function" then finished = false end
    else
        held, result = run_held(lp.step)
        finished = (not result[1]) or result[2] == true
    end
    for _, entry in ipairs(held) do job.held[#job.held + 1] = entry end

    if not result[1] then finished = true end
    if not finished then return false end
    local facts = nil
    if type(lp.facts) == "function" then
        local ok, f = pcall(lp.facts)
        if ok and type(f) == "table" then facts = f end
    end
    modes.lead_send(job.serial, job.key, job.held, facts)
    job = nil
    return true
end

function modes.room_publish(fn, ...)
    if OF.util.is_host() or not modes.asks_the_room() then return fn(...) end
    local mode = modes.current()
    if mode == nil then return nil end
    local held, result = run_held(fn, ...)
    if #held > 0 then modes.lead_send(0, mode.key, held, nil) end
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

function modes.lead_tell(tag, facts)
    if OF.util.is_host() or not modes.asks_the_room() then return false end
    local mode = modes.current()
    if mode == nil then return false end
    return modes.lead_send(0, mode.key, {}, facts, tag) == true
end

local function allowed_keys(mode)
    local set = {}
    local lp = mode ~= nil and mode.leadPin or nil
    local list = type(lp) == "table" and lp.keys or nil

    if type(list) == "function" then list = list() end
    for _, key in ipairs(type(list) == "table" and list or {}) do
        set[key] = true
    end
    return set
end

local function facts_of(data, into)
    for k, v in pairs(data) do
        if type(k) == "string" and k:sub(1, 2) == "f_" then into[k:sub(3)] = v end
    end
    return into
end

local function publish_part(mode, data, allowed)
    local count = 0
    for i = 1, math.min(tonumber(data.n) or 0, modes.LEAD_PART_PAIRS) do
        local k = data["k" .. i]
        if type(k) == "string" and allowed[k] then
            local v = data["v" .. i]
            if data["z" .. i] ~= nil then v = nil end
            OF.util.publish(k, v)
            count = count + 1
        end
    end
    return count
end

function modes.receive_lead_says(data, sender)
    if type(data) ~= "table" or data.ofp ~= modes.PACKET_LEAD_SAYS then return 0 end
    if not OF.util.is_host() then return 0 end
    if type(sender) ~= "number" or sender <= 0 then return 0 end
    local np = gNetworkPlayers[sender]
    if np == nil or not np.connected then return 0 end
    local mode = modes.current()
    if mode == nil or mode.key ~= data.mk or type(mode.leadPin) ~= "table" then return 0 end
    if modes.state() == modes.OFF then return 0 end
    if modes.room_by_global() ~= np.globalIndex then return 0 end
    local lp = mode.leadPin
    local allowed = allowed_keys(mode)
    local serial = tonumber(data.s) or 0
    if serial == 0 then
        local count = publish_part(mode, data, allowed)
        if type(data.t) == "string" and type(lp.heard) == "function" then
            pcall(lp.heard, data.t, facts_of(data, {}))
        end
        return count
    end
    if ask == nil or ask.done or ask.serial ~= serial or ask.lead ~= np.globalIndex then
        return 0
    end
    local p, pn = tonumber(data.p) or 1, tonumber(data.pn) or 1
    if p < 1 or p > pn or pn > 16 then return 0 end
    ask.parts[p] = data
    for i = 1, pn do
        if ask.parts[i] == nil then return 0 end
    end
    local count, facts = 0, {}
    for i = 1, pn do
        count = count + publish_part(mode, ask.parts[i], allowed)
        facts_of(ask.parts[i], facts)
    end
    ask.done = true
    ask.parts = {}
    if type(lp.take) == "function" then
        pcall(lp.take, facts)
    end
    return count
end

function modes.hand_to_room(tag, fields)
    if not OF.util.is_host() then return false end
    local g = modes.room_by_global()
    local mode = modes.current()
    if g == nil or mode == nil then return false end
    local li = OF.util.local_from_global(g)
    if li == nil or li <= 0 then return false end
    local data = { ofp = modes.PACKET_LEAD_HAND, mk = mode.key, t = tag }
    for k, v in pairs(fields or {}) do data["f_" .. tostring(k)] = v end
    return OF.util.send_to_player(li, data) == true
end

function modes.receive_lead_hand(data)
    if type(data) ~= "table" or data.ofp ~= modes.PACKET_LEAD_HAND then return false end
    if OF.util.is_host() or not OF.util.from_host(data) then return false end
    if not modes.asks_the_room() then return false end
    local mode = modes.current()
    if mode == nil or mode.key ~= data.mk or type(mode.leadPin) ~= "table" then return false end
    if type(mode.leadPin.handed) ~= "function" then return false end
    local ok = pcall(mode.leadPin.handed, data.t, facts_of(data, {}))
    return ok
end

function modes.room_by_watch(mode)
    if not OF.util.is_host() then return false end
    watchTick = watchTick + 1
    if watchTick < modes.ROOM_WATCH_EVERY then return false end
    watchTick = 0
    local g = modes.room_by_global()
    if g == nil or mode == nil then return false end
    local lead = OF.util.asks(OF.net, "round_lead") and OF.net.round_lead() or nil
    local leadG = lead ~= nil and gNetworkPlayers[lead] ~= nil
        and gNetworkPlayers[lead].globalIndex or nil
    if leadG == g then return false end

    if type(mode.leadPin) == "table" and mode.leadPin.handover == "repin" then
        modes.pin_round(mode)
        return true
    end
    local np = lead ~= nil and gNetworkPlayers[lead] or nil
    if np ~= nil and lead ~= 0 and not lead_same_room(np, gNetworkPlayers[0]) then
        set_room_by(leadG)
    else
        set_room_by(nil)
    end
    return true
end
end

do
modes.PACKET_RELAY = "gmrelay"
modes.RELAY_EVERY = 3

modes.WIRE_MAX_RATE = 10
local relayTick = 0
modes.relayedAt = {}

local function same_room(a, b)
    return a ~= nil and b ~= nil
        and a.currLevelNum == b.currLevelNum
        and a.currAreaIndex == b.currAreaIndex
        and a.currActNum == b.currActNum
end

function modes.relay_wanted()
    if OF.util.is_host() then return nil end
    if modes.state() == modes.OFF then return nil end
    local scope = OF.roundscope
    if scope == nil or scope.dealt == nil or scope.dealt(0) ~= true then return nil end
    local me = gNetworkPlayers[0]
    local hostLocal = OF.util.local_from_global(0)
    if me == nil or hostLocal == nil or hostLocal <= 0 then return nil end
    if not me.currAreaSyncValid then return nil end
    if same_room(me, gNetworkPlayers[hostLocal]) then return nil end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end
    return {
        ofp = modes.PACKET_RELAY,
        g = me.globalIndex,
        x = math.floor(m.pos.x), y = math.floor(m.pos.y), z = math.floor(m.pos.z),
        yaw = m.faceAngle ~= nil and m.faceAngle.y or 0,
        a = m.action or 0,
        v = math.floor((m.forwardVel or 0) * 10) / 10,
    }, hostLocal
end

function modes.relay_frame()

    if OF.util.is_host() then return false end
    relayTick = relayTick + 1
    if relayTick < modes.RELAY_EVERY then return false end
    relayTick = 0
    local data = modes.relay_wanted()
    if data == nil then return false end

    return OF.util.send_to_host(data, true) == true
end

modes.PACKET_STREAM = "gmstream"
modes.streams = {}
modes.streamSeq = {}
modes.streamSeen = {}

function modes.forget_streams()
    modes.streams = {}
    modes.streamSeen = {}
end

function modes.stream_send(key, value)
    if not OF.util.is_host() then return false end
    local parts = type(value) == "table" and value or { value }
    if value == "" then parts = {} end
    local joined = (value ~= nil and #parts > 0) and table.concat(parts) or nil
    modes.streams[key] = joined
    modes.streamSeq[key] = (modes.streamSeq[key] or 0) + 1
    local seq = modes.streamSeq[key]
    local scope = OF.roundscope
    local sent = 0
    for i = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected
            and (joined == nil or scope == nil or scope.about == nil or scope.about(i)) then
            local data = OF.packet_stamp({ ofp = modes.PACKET_STREAM, k = key,
                n = joined ~= nil and #parts or 0, s = seq })
            if joined ~= nil then
                for index, part in ipairs(parts) do data["t" .. index] = part end
            end
            if OF.util.send_to_player(i, data, joined ~= nil) then sent = sent + 1 end
        end
    end
    return true, sent
end

function modes.stream_read(key)
    return modes.streams[key]
end

function modes.stream_receive(data)
    if type(data) ~= "table" or data.ofp ~= modes.PACKET_STREAM then return false end
    if type(data.k) ~= "string" then return false end
    if not OF.util.from_host(data) then return false end

    local seq = tonumber(data.s)
    local seen = modes.streamSeen[data.k]
    if seq ~= nil and seen ~= nil and seq <= seen and seen - seq < 1000 then
        return false
    end
    local n = tonumber(data.n) or 0
    local parts = {}
    for index = 1, n do
        local part = data["t" .. index]
        if type(part) ~= "string" then return false end
        parts[index] = part
    end
    if seq ~= nil then modes.streamSeen[data.k] = seq end
    if n <= 0 then
        modes.streams[data.k] = nil
        return true
    end
    modes.streams[data.k] = table.concat(parts)
    return true
end

function modes.relay_receive(data, sender)
    if type(data) ~= "table" or data.ofp ~= modes.PACKET_RELAY then return false end
    if not OF.util.is_host() then return false end
    local li = sender
    if type(li) ~= "number" or li <= 0 then return false end
    local np = gNetworkPlayers[li]
    if np == nil or not np.connected then return false end
    if same_room(np, gNetworkPlayers[0]) then return false end
    local scope = OF.roundscope
    if scope == nil or scope.dealt == nil or scope.dealt(li) ~= true then return false end
    local m = gMarioStates[li]
    if m == nil or m.pos == nil then return false end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if x == nil or y == nil or z == nil then return false end
    m.pos.x, m.pos.y, m.pos.z = x, y, z
    if m.faceAngle ~= nil and tonumber(data.yaw) ~= nil then
        m.faceAngle.y = math.floor(tonumber(data.yaw))
    end
    if tonumber(data.a) ~= nil then m.action = math.floor(tonumber(data.a)) end
    if tonumber(data.v) ~= nil then m.forwardVel = tonumber(data.v) end
    modes.relayedAt[li] = get_global_timer ~= nil and get_global_timer() or 0
    return true
end
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

            island = { x = 4406, y = 3072, z = 1215, yaw = 359, noSpawn = true },

            floodStart = { x = -4599, y = 0, z = 5598, yaw = 89 },
            floodGoal  = { x = 3101, y = 4293, z = -4715, yaw = 10 },
        },
    },

    [LEVEL_BITDW] = {
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

    [LEVEL_BITFS] = {
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

    [LEVEL_BITS] = {
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

            lineStart  = { x = 4638, y = -4607, z = 3077, yaw = 287 },
            lineFinish = { x = -1231, y = 2560, z = -2479, yaw = 82 },
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
        [2] = {
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

            cvrCell = { x = -1526, y = 97, z = 615, yaw = 147 },
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

            floodStart = { x = 6000, y = 51, z = 3500, yaw = 235 },

            floodGoal  = { x = -2050, y = 1200, z = -580, yaw = 277 },
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

            musicalSpot = { x = 3140, y = 1075, z = -3515, yaw = 13 },
            floodStart = { x = 3071, y = 256, z = 4843, yaw = 153 },
            floodGoal  = { x = 63, y = 3584, z = 211, yaw = 196 },
        },
    },
}

modes.SURVEY_SUGGESTED = {

    [LEVEL_CCM] = {
        [1] = {
            ctfRed  = { x = 2825, y = -4607, z = 5550, yaw = 158, conf = "medium",
                src = "decomp floor search, bottom snowfield north end, on measured floor" },
            ctfBlue = { x = 4800, y = -4607, z = 700, yaw = 338, conf = "medium",
                src = "decomp floor search, bottom snowfield south end, on measured floor" },
        },
    },

    [LEVEL_CASTLE_COURTYARD] = {
        [1] = {
            ctfRed  = { x = -2980, y = 20, z = 330, yaw = 90, conf = "high",
                src = "macro_wooden_signpost (-3180, 20, 330), on measured floor" },
            ctfBlue = { x = 2980, y = 20, z = 330, yaw = 270, conf = "high",
                src = "macro_wooden_signpost (3180, 20, 330), on measured floor" },
            points = {
                { x = -2980, y = 20, z = 330, yaw = 90, conf = "high",
                    src = "macro_wooden_signpost (-3180, 20, 330), on measured floor" },
                { x = 2980, y = 20, z = 330, yaw = 270, conf = "high",
                    src = "macro_wooden_signpost (3180, 20, 330), on measured floor" },
                { x = 0, y = 0, z = -3400, yaw = 0, conf = "high",
                    src = "on the mirror line, 200 before macro_wooden_signpost (300, 0, -3600), on measured floor" },
            },
            musicalSpot = { x = -14, y = 0, z = -201, yaw = 179, conf = "high",
                src = "MARIO_POS" },
        },
    },
}

function modes.survey_set(level, area)
    local host = modes.SURVEYED[level] ~= nil and modes.SURVEYED[level][area] or nil
    local ours = modes.SURVEY_SUGGESTED ~= nil
        and modes.SURVEY_SUGGESTED[level] ~= nil
        and modes.SURVEY_SUGGESTED[level][area] or nil
    if host == nil and ours == nil then return nil end
    local set = {}
    for key, value in pairs(host or {}) do set[key] = value end
    for key, value in pairs(ours or {}) do set[key] = value end
    return set
end

function modes.survey_source(level, area, key)
    local ours = modes.SURVEY_SUGGESTED ~= nil
        and modes.SURVEY_SUGGESTED[level] ~= nil
        and modes.SURVEY_SUGGESTED[level][area] or nil
    if ours ~= nil and ours[key] ~= nil then return "suggested" end
    local host = modes.SURVEYED[level] ~= nil and modes.SURVEYED[level][area] or nil
    if host ~= nil and host[key] ~= nil then return "host" end
    return nil
end

function modes.venue_survey(place)
    if type(place) ~= "table" or not OF.util.asks(OF.venues, "survey_for") then
        return nil
    end
    return OF.venues.survey_for(place.level, place.area)
end

function modes.surveyed(place, key)
    if type(place) ~= "table" or key == nil then return nil end
    local set = modes.venue_survey(place)
    if set == nil then set = modes.survey_set(place.level, place.area) end
    if set == nil then return nil end
    local found = set[key]
    if found == nil or found.noSpawn then return nil end

    if OF.util.asks(OF.warp, "land_spot") then
        return OF.warp.land_spot({ x = found.x, y = found.y, z = found.z,
            yaw = found.yaw })
    end
    return { x = found.x, y = found.y, z = found.z, yaw = found.yaw }
end

function modes.surveyed_list(place, key, want)
    if type(place) ~= "table" or key == nil then return nil end
    local out = {}
    local set = modes.venue_survey(place)
        or modes.survey_set(place.level, place.area)
    local found = set ~= nil and set[key] or nil
    if type(found) == "table" then
        for _, spot in ipairs(found) do

            if not spot.noSpawn then
                local one = { x = spot.x, y = spot.y, z = spot.z, yaw = spot.yaw }
                if OF.util.asks(OF.warp, "land_spot") then
                    one = OF.warp.land_spot(one)
                end
                out[#out + 1] = one
            end
        end
    end
    if type(want) == "number" and #out < want then
        local more = modes.derived_spots(place, want - #out, out)
        for _, spot in ipairs(more or {}) do table.insert(out, spot) end
        local current = modes.current()
        if #out < want and current ~= nil and current.openCourses == true then
            out = modes.fill_round(out, want)
        end
    end
    if out[1] == nil then return nil end
    return out
end

do
    local DERIVE = {
        DROP = 400,
        LIFT = 100,
        FLAT = 0.8,
        WADE = 100,
        HEADROOM = 200,
        WALL_CLEAR = 80,
        SPACING = 300,
        MOST = 800,
        FILL_GAP = 200,
        FILL_RADII = { 400, 250 },

        LISTS = { "OBJ_LIST_DESTRUCTIVE", "OBJ_LIST_GENACTOR", "OBJ_LIST_PUSHABLE",
                  "OBJ_LIST_LEVEL", "OBJ_LIST_DEFAULT", "OBJ_LIST_SURFACE",
                  "OBJ_LIST_POLELIKE", "OBJ_LIST_SPAWNER" },
    }

    local derivedSeen = {}

    local function derived_candidates()
        local list = {}
        local np = gNetworkPlayers[0]
        if np ~= nil then
            for _, spot in ipairs(modes.course_ground(np.currLevelNum,
                    np.currAreaIndex)) do
                local one = { x = spot.x, y = spot.y, z = spot.z }
                if OF.util.asks(OF.warp, "land_spot") then
                    one = OF.warp.land_spot(one)
                end
                table.insert(list, one)
            end
        end
        local m = gMarioStates[0]
        local area = m ~= nil and m.area or nil
        local info = area ~= nil and area.objectSpawnInfos or nil
        while info ~= nil and #list < DERIVE.MOST do
            local at = info.startPos
            if at ~= nil then
                local one = { x = at.x, y = at.y, z = at.z }
                if OF.util.asks(OF.warp, "land_spot") then
                    one = OF.warp.land_spot(one)
                end
                table.insert(list, one)
            end
            info = info.next
        end
        local first = OF.util.binding("obj_get_first")
        local nextOf = OF.util.binding("obj_get_next")
        if first == nil or nextOf == nil then return list end
        local ours = COOP_OBJ_FLAG_LUA or 0x2
        for _, name in ipairs(DERIVE.LISTS) do
            local listId = _G[name]
            local o = listId ~= nil and first(listId) or nil
            while o ~= nil and #list < DERIVE.MOST do
                if o.activeFlags ~= 0 and not OF.util.has_flag(o.coopFlags, ours) then
                    if o.setHome ~= nil and o.setHome ~= 0 then
                        table.insert(list, { x = o.oHomeX, y = o.oHomeY, z = o.oHomeZ })
                    else
                        table.insert(list, { x = o.oPosX, y = o.oPosY, z = o.oPosZ })
                    end
                end
                o = nextOf(o)
            end
        end
        return list
    end

    local function derived_ground(spot)
        local findFloor = OF.util.binding("find_floor")
        if findFloor == nil or type(spot.y) ~= "number" then return nil, "no floor query" end
        local ok, height, floor = pcall(findFloor, spot.x, spot.y + DERIVE.LIFT, spot.z)
        if not ok or floor == nil or type(height) ~= "number" then return nil, "void" end
        local np = gNetworkPlayers[0]
        if np ~= nil and modes.kept_out(np.currLevelNum, spot.x, height, spot.z) then
            return nil, "kept out"
        end
        if spot.y - height > DERIVE.DROP then return nil, "in the air" end
        if floor.object ~= nil then return nil, "a platform" end
        if OF.util.asks(OF.ground, "leanable") and not OF.ground.leanable(floor.type) then
            return nil, "hazard floor"
        end
        if floor.normal == nil or (floor.normal.y or 0) < DERIVE.FLAT then
            return nil, "a slope"
        end
        local water = OF.util.optional("find_water_level", nil, spot.x, spot.z)
        if type(water) == "number" and water > height + DERIVE.WADE then
            return nil, "under water"
        end
        local ceiling = OF.util.optional("find_ceil_height", nil, spot.x, height + 80, spot.z)
        if type(ceiling) == "number" and ceiling - height < DERIVE.HEADROOM then
            return nil, "no headroom"
        end

        if collision_find_surface_on_ray ~= nil then
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local info = collision_find_surface_on_ray(spot.x, height + 60, spot.z,
                    d[1] * DERIVE.WALL_CLEAR, 0, d[2] * DERIVE.WALL_CLEAR)
                local surf = info ~= nil and info.surface or nil
                if surf ~= nil and surf.normal ~= nil and math.abs(surf.normal.y or 0) < 0.3 then
                    return nil, "against a wall"
                end
            end
        end
        return { x = spot.x, y = height, z = spot.z, yaw = 0 }
    end

    modes.DERIVE_KEEP_OUT = {
        [LEVEL_CASTLE_GROUNDS or -1] = { below = -400,
            circles = { { x = 2384, z = 1961, r = 450 } } },
    }
    function modes.kept_out(level, x, y, z)
        local rule = level ~= nil and modes.DERIVE_KEEP_OUT[level] or nil
        if rule == nil then return false end
        if rule.below ~= nil and type(y) == "number" and y < rule.below then return true end
        for _, c in ipairs(rule.circles or {}) do
            if (x - c.x) ^ 2 + (z - c.z) ^ 2 <= c.r * c.r then return true end
        end
        return false
    end

    modes.WAYS_OUT = { "id_bhvCannonClosed", "id_bhvCannon", "id_bhvDoor", "id_bhvDoorWarp",
        "id_bhvStarDoor", "id_bhvWarpPipe", "id_bhvWarp", "id_bhvFadingWarp",
        "id_bhvSwimmingWarp", "id_bhvInstantActiveWarp", "id_bhvCastleFloorTrap",
        "id_bhvSpinAirborneWarp", "id_bhvAirborneWarp", "id_bhvDeathWarp" }
    local WAY_OUT_CLEAR = 400
    function modes.ways_out_here()
        local holes = {}
        local first = OF.util.binding("obj_get_first_with_behavior_id")
        local nextOf = OF.util.binding("obj_get_next_with_same_behavior_id")
        if first == nil or nextOf == nil then return holes end
        for _, name in ipairs(modes.WAYS_OUT) do
            local id = _G[name]
            local o = id ~= nil and first(id) or nil
            while o ~= nil do
                if o.activeFlags ~= 0 then
                    holes[#holes + 1] = { x = o.oPosX, z = o.oPosZ }
                end
                o = nextOf(o)
            end
        end
        return holes
    end
    function modes.near_way_out(holes, x, z)
        for _, h in ipairs(holes or {}) do
            if (x - h.x) ^ 2 + (z - h.z) ^ 2 <= WAY_OUT_CLEAR * WAY_OUT_CLEAR then return true end
        end
        return false
    end

    local function derived_gap(a, b)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return dx * dx + dy * dy + dz * dz
    end

    function modes.derived_spots(place, want, seeds)
        if type(place) ~= "table" then return nil, nil end
        local key = tostring(place.level) .. ":" .. tostring(place.area)
        if not modes.in_place_room({ x = 0, level = place.level, area = place.area }) then
            return nil, derivedSeen[key]
        end

        local ground = {}
        local cells = {}
        local holes = modes.ways_out_here()
        for _, spot in ipairs(derived_candidates()) do
            local stood = derived_ground(spot)
            if stood ~= nil and modes.near_way_out(holes, stood.x, stood.z) then stood = nil end
            if stood ~= nil then
                local cell = math.floor(stood.x / 100) .. ":" .. math.floor(stood.y / 100)
                    .. ":" .. math.floor(stood.z / 100)
                if not cells[cell] then
                    cells[cell] = true
                    table.insert(ground, stood)
                end
            end
        end

        local seeded = 0
        local near = {}
        for _, seed in ipairs(seeds or {}) do
            if type(seed) == "table" and type(seed.x) == "number" then
                seeded = seeded + 1
                for index, spot in ipairs(ground) do
                    local gap = derived_gap(spot, seed)
                    if near[index] == nil or gap < near[index] then near[index] = gap end
                end
            end
        end
        local opening = seeded == 0
        if opening and ground[1] ~= nil then

            local cx, cz = 0, 0
            for _, spot in ipairs(ground) do cx, cz = cx + spot.x, cz + spot.z end
            cx, cz = cx / #ground, cz / #ground
            for index, spot in ipairs(ground) do
                near[index] = (spot.x - cx) ^ 2 + (spot.z - cz) ^ 2
            end
        end
        local floorGap = DERIVE.SPACING * DERIVE.SPACING
        local picks, gaps = {}, {}
        while true do
            local at = nil
            for index = 1, #ground do
                if near[index] ~= nil and (at == nil or near[index] > near[at]) then
                    at = index
                end
            end
            if at == nil then break end
            if opening and picks[1] == nil then

                gaps[1] = math.huge
            else
                if near[at] < floorGap then break end

                gaps[#picks + 1] = math.sqrt(near[at])
            end
            local pick = ground[at]
            table.insert(picks, pick)
            near[at] = nil
            for index = 1, #ground do
                if near[index] ~= nil then
                    local gap = derived_gap(ground[index], pick)
                    if (opening and #picks == 1) or gap < near[index] then
                        near[index] = gap
                    end
                end
            end
        end

        derivedSeen[key] = { found = #ground, room = #picks, gaps = gaps,
                             seeded = seeded }
        local out = {}
        for index = 1, math.min(want or 0, #picks) do
            local pick = picks[index]
            out[index] = { x = pick.x, y = pick.y, z = pick.z, yaw = pick.yaw }
        end
        local rating = derivedSeen[key]
        return out, { found = rating.found, room = rating.room, seeded = seeded,
                      gaps = { table.unpack(gaps) } }
    end

    function modes.fill_round(list, want)
        local out = {}
        for index, spot in ipairs(list or {}) do out[index] = spot end
        if type(want) ~= "number" then return out end
        local clear = DERIVE.FILL_GAP * DERIVE.FILL_GAP
        for _, radius in ipairs(DERIVE.FILL_RADII) do
            local anchor = 1
            while #out < want and out[anchor] ~= nil do
                local from = out[anchor]
                for bearing = 0, 7 do
                    if #out >= want then break end
                    local angle = bearing * math.pi / 4
                    local stood = derived_ground({
                        x = from.x + radius * math.cos(angle), y = from.y,
                        z = from.z + radius * math.sin(angle) })
                    local free = stood ~= nil
                    for _, taken in ipairs(out) do
                        if free and derived_gap(stood, taken) < clear then
                            free = false
                        end
                    end
                    if free then table.insert(out, stood) end
                end
                anchor = anchor + 1
            end
        end
        return out
    end
end

do

    local POINT_LOW = -32768
    local POINT_SPAN = 65535
    local DIGITS = 64

    local ALPHABET =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local VALUE_OF = {}
    for index = 1, #ALPHABET do
        VALUE_OF[ALPHABET:sub(index, index)] = index - 1
    end

    local function pack_axis(value, out)
        local whole = math.floor(OF.util.clamp(
            (tonumber(value) or 0) - POINT_LOW, 0, POINT_SPAN) + 0.5)
        local d1 = math.floor(whole / (DIGITS * DIGITS)) % DIGITS
        local d2 = math.floor(whole / DIGITS) % DIGITS
        local d3 = whole % DIGITS
        table.insert(out, ALPHABET:sub(d1 + 1, d1 + 1))
        table.insert(out, ALPHABET:sub(d2 + 1, d2 + 1))
        table.insert(out, ALPHABET:sub(d3 + 1, d3 + 1))
    end

    function modes.pack_points(list)
        if type(list) ~= "table" then return "" end
        local out = {}
        for _, spot in ipairs(list) do
            if type(spot) == "table" and type(spot.x) == "number"
                and type(spot.y) == "number" and type(spot.z) == "number" then
                pack_axis(spot.x, out)
                pack_axis(spot.y, out)
                pack_axis(spot.z, out)
            end
        end
        return table.concat(out)
    end

    local function unpack_axis(str, at)
        local d1 = VALUE_OF[str:sub(at, at)]
        local d2 = VALUE_OF[str:sub(at + 1, at + 1)]
        local d3 = VALUE_OF[str:sub(at + 2, at + 2)]
        if d1 == nil or d2 == nil or d3 == nil then return nil end
        return (d1 * DIGITS * DIGITS + d2 * DIGITS + d3) + POINT_LOW
    end

    function modes.unpack_points(str)
        local out = {}
        if type(str) ~= "string" then return out end
        local at = 1
        while at + 8 <= #str do
            local x = unpack_axis(str, at)
            local y = unpack_axis(str, at + 3)
            local z = unpack_axis(str, at + 6)
            if x == nil or y == nil or z == nil then break end
            table.insert(out, { x = x, y = y, z = z })
            at = at + 9
        end
        return out
    end
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

modes.BOBOMB_ANIMS = "bobomb_seg8_anims_0802396C"
modes.BOBOMB_WALK, modes.BOBOMB_CARRIED = 0, 1

function modes.pose_bobomb(token, anim, rate)
    if token == nil then return nil end
    local flag = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE or 1
    if not OF.util.has_flag(token.oFlags or 0, flag) then
        token.oFlags = (token.oFlags or 0) + flag
    end
    if token.oAnimations == nil then
        local anims = gObjectAnimations ~= nil and gObjectAnimations[modes.BOBOMB_ANIMS] or nil
        if anims ~= nil then
            token.oAnimations = anims
            OF.util.optional("obj_scale", nil, token, 1.0)
        end
    end
    if token.oAnimations ~= nil then
        OF.util.optional("obj_init_animation_with_accel_and_sound", nil,
            token, anim or modes.BOBOMB_WALK, rate or 1.0)
    end
    token.oFaceAnglePitch = 0
    token.oFaceAngleRoll = 0
    return token
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

        modes.hear_the_count(newVal)
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

        modes.hear_the_clock(left_after(newVal))
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
        return modes.release()
    end

    if left > modes.LOUD_SECONDS then return nil end
    return modes.round_sound(modes.count_sound(left))
end

do

    function modes.hears_round()
        if modes.state() == modes.OFF then return false end
        local scope, act = OF.roundscope, OF.roundact
        local asked = false
        if OF.util.asks(scope, "inside") then
            asked = true
            if scope.inside(0) then return true end
        end
        if OF.util.asks(act, "watches") then
            asked = true
            if act.watches(0) then return true end
        end
        return not asked
    end

    function modes.round_sound(sound)
        if sound == nil then return nil end
        if not modes.hears_round() then return nil end
        OF.sounds.play(sound)
        return sound
    end

    function modes.round_sound_from(obj, sound)
        if sound == nil then return nil end
        if not modes.hears_round() then return nil end

        if OF.util.asks(OF.sounds, "play_from") then
            OF.sounds.play_from(obj, sound)
        else
            OF.sounds.play(sound)
        end
        return sound
    end

    modes.soundFrame = 0
    local soundLast = {}

    function modes.round_sound_throttled(key, gap, sound, obj)
        if sound == nil or key == nil then return nil end
        local last = soundLast[key]
        if last ~= nil and modes.soundFrame - last < (gap or 15) then return nil end
        local played
        if obj ~= nil then
            played = modes.round_sound_from(obj, sound)
        else
            played = modes.round_sound(sound)
        end
        if played ~= nil then soundLast[key] = modes.soundFrame end
        return played
    end

    modes.CLIMB_SECONDS = 3
    function modes.count_sound(seconds)
        if type(seconds) ~= "number" or seconds < 1 then return nil end
        seconds = math.floor(seconds)
        if seconds > modes.CLIMB_SECONDS then return OF.sounds.COUNT end
        if SOUND_MENU_COLLECT_RED_COIN == nil then return OF.sounds.COUNT end

        local rung = 8 - seconds + 1
        return SOUND_MENU_COLLECT_RED_COIN + ((8 - rung) << 16)
    end

    local heldCount = nil

    modes.LAND_FRAMES = 15
    local sinceLanded = 999
    function modes.ears_settling()
        if sinceLanded < modes.LAND_FRAMES then return true end
        local np = gNetworkPlayers[0]
        if np ~= nil and np.currAreaSyncValid == false then return true end
        local net = OF.net
        if net ~= nil and (net.pendingWarp ~= nil or net.pendingTarget ~= nil
            or net.pendingPos ~= nil) then
            return true
        end
        return false
    end

    function modes.hear_the_count(seconds)
        if modes.state() == modes.OFF or modes.ears_settling() then
            heldCount = seconds
            return nil
        end
        heldCount = nil

        local played = modes.round_sound(modes.count_sound(seconds))
        if played == nil then heldCount = seconds end
        return played
    end

    function modes.hear_the_held_count()
        if sinceLanded < 999 then sinceLanded = sinceLanded + 1 end
        if heldCount == nil or modes.state() ~= modes.COUNTDOWN then return nil end
        if modes.ears_settling() then return nil end
        local now = tonumber(gGlobalSyncTable.ofGmCount)
        heldCount = nil
        if now == nil or now < 1 then return nil end
        local played = modes.round_sound(modes.count_sound(now))

        if played == nil then heldCount = now end
        return played
    end

    function modes.landed_now()
        sinceLanded = 0
    end
    hook_event(HOOK_ON_LEVEL_INIT, function() modes.landed_now() end)
    hook_event(HOOK_UPDATE, function() modes.hear_the_held_count() end)

    function modes.sound_go()
        local a = modes.round_sound(OF.sounds.GO)
        local b = modes.round_sound(OF.sounds.SHOT)
        return a or b
    end

    local released = false
    function modes.release()
        if released then return nil end
        if not modes.is_running() then return nil end
        released = true
        return modes.round_sound(OF.sounds.SHOT)
    end

    local clockLeft = nil
    local finished = false

    function modes.clock_sound(left)
        if type(left) ~= "number" or left < 1 then return nil end
        if left > modes.URGENT_SECONDS then return nil end
        if left <= modes.LOUD_SECONDS then return OF.sounds.CLOCK_LAST end
        return OF.sounds.CLOCK
    end

    function modes.hear_the_clock(left)
        if modes.state() ~= modes.ACTIVE or not modes.has_deadline() then
            clockLeft = nil
            return nil
        end
        clockLeft = left
        if left == nil or left > 0 or finished then return nil end
        finished = true
        return modes.round_sound(OF.sounds.FINISH)
    end

    function modes.hear_the_end(oldState, newState)
        if oldState ~= modes.ACTIVE then return nil end
        if newState ~= modes.MOMENT and newState ~= modes.RESULTS then return nil end
        if finished then return nil end
        finished = true
        return modes.round_sound(OF.sounds.FINISH)
    end

    modes.CUE_GAP = 15
    modes.CUES = {
        hazard = "WARN", good = "GOT_ONE", bad = "CAUGHT",
        out = "POOF", chime = "CHIME",
    }
    function modes.cue(kind, obj, key, left)
        if kind == "tick" then return modes.tick_down(left) end
        local name = modes.CUES[kind]
        if name == nil then return nil end
        local sound = OF.sounds[name]
        if sound == nil then return nil end
        return modes.round_sound_throttled(key or ("cue:" .. kind),
            modes.CUE_GAP, sound, obj)
    end

    function modes.tick_down(left)
        if modes.state() ~= modes.ACTIVE then return nil end
        return modes.round_sound(modes.clock_sound(left))
    end

    function modes.round_sounds_update()
        modes.soundFrame = modes.soundFrame + 1
        if modes.state() ~= modes.ACTIVE then return nil end
        if not modes.has_deadline() then return nil end
        return modes.round_sound(modes.clock_sound(clockLeft))
    end

    modes.OUT_GAP = 10
    modes.CHIME_GAP = 45
    modes.TAGGER_RANGE = 1200

    local function in_my_room(localIndex)
        local here, there = gNetworkPlayers[0], gNetworkPlayers[localIndex]
        if here == nil or there == nil or not there.connected then return false end
        return there.currLevelNum == here.currLevelNum
            and there.currAreaIndex == here.currAreaIndex
            and there.currActNum == here.currActNum
    end

    function modes.catcher_of(victim)
        local mode = modes.current()
        if mode == nil or type(mode.catchers) ~= "table" then return nil end
        local best, bestDistance = nil, modes.TAGGER_RANGE
        for i = 0, MAX_PLAYERS - 1 do
            if i ~= victim and mode.catchers[modes.role(i)] == true
                and in_my_room(i) then
                local distance = modes.distance(i, victim)
                if distance ~= nil and distance <= bestDistance then
                    best, bestDistance = i, distance
                end
            end
        end
        return best
    end

    function modes.is_catch(oldRole, newRole)
        if oldRole == nil or oldRole == "" or oldRole == modes.WAITING then
            return false
        end
        if modes.OUT_ROLES[oldRole] == true then return false end
        if modes.OUT_ROLES[newRole] == true then return true end
        local mode = modes.current()
        local catchers = mode ~= nil and mode.catchers or nil
        return type(catchers) == "table" and catchers[newRole] == true
            and catchers[oldRole] ~= true
    end

    function modes.hear_role(localIndex, oldRole, newRole)
        if not modes.is_running() then return nil end
        if not modes.is_catch(oldRole, newRole) then return nil end
        if not modes.hears_round() then return nil end
        local played = {}
        local m = gMarioStates[localIndex]
        if m ~= nil and in_my_room(localIndex) then
            played.where = modes.round_sound_throttled("out" .. localIndex,
                modes.OUT_GAP, OF.sounds.POOF, m.marioObj)
        end
        local tagger = modes.catcher_of(localIndex)
        if localIndex == 0 then
            played.mine = modes.round_sound(OF.sounds.CAUGHT)
        elseif tagger == 0 then
            played.mine = modes.round_sound(OF.sounds.GOT_ONE)
        else
            local mode = modes.current()
            if mode ~= nil and mode.catchChime == true then
                played.chime = modes.round_sound_throttled("chime",
                    modes.CHIME_GAP, OF.sounds.CHIME)
            end
        end
        return played
    end

    local sideSeen = nil
    function modes.hear_sides(red, blue)
        if modes.state() ~= modes.ACTIVE or type(red) ~= "number"
            or type(blue) ~= "number" then
            sideSeen = nil
            return nil
        end
        local was = sideSeen
        sideSeen = { red = red, blue = blue }
        if was == nil then return nil end
        local scored = nil
        if red > was.red then scored = "red" elseif blue > was.blue then scored = "blue" end
        if scored == nil then return nil end
        local mine = OF.util.asks(OF.teams, "of") and OF.teams.of(0) or ""
        if mine == scored then return modes.round_sound(OF.sounds.GOT_ONE) end
        if mine ~= nil and mine ~= "" then return modes.round_sound(OF.sounds.CAUGHT) end
        return modes.round_sound(OF.sounds.CHIME)
    end

    function modes.forget_round_sounds()
        released = false
        clockLeft = nil
        finished = false
        soundLast = {}
        sideSeen = nil
    end

    function modes.hear_the_state(oldState, newState)
        if newState == modes.OFF or newState == modes.COUNTDOWN then modes.forget_streams() end
        modes.hear_the_end(oldState, newState)
        modes.forget_round_sounds()

        if modes.forget_watch ~= nil then modes.forget_watch() end

        modes.forget_hit_claims()

        if newState == modes.OFF or newState == modes.COUNTDOWN then modes.forget_claims() end
        local held = heldCount
        heldCount = nil
        if newState == modes.COUNTDOWN and held ~= nil
            and gGlobalSyncTable.ofGmCount == held then

            if modes.ears_settling() then
                heldCount = held
                return nil
            end
            return modes.round_sound(modes.count_sound(held))
        end
        return nil
    end
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

modes.INTRO = { since = nil, last = nil }

local function intro_age()
    local now = OF.hud.now()
    local st = modes.INTRO
    if st.last == nil or now - st.last > 2 then st.since = now end
    st.last = now
    return now - (st.since or now)
end

function modes.rules_hint()
    return { { "pause", OF.lang.t("Controls & rules") } }
end

function modes.intro_card(mode, seconds)
    local rules = modes.rules_for(mode)
    local aim = modes.aim_line()
    local role = modes.my_role()

    local card = { name = OF.lang.t(mode.name), rules = {}, tone = "accent" }
    if role ~= "" then card.round = OF.lang.fill("You are @", OF.lang.t(role)) end
    local blurb = (rules ~= nil and rules ~= "") and OF.lang.t(rules) or nil
    if aim ~= nil and aim ~= "" and aim ~= rules then
        card.objective = OF.lang.t(aim)
        if blurb ~= nil then table.insert(card.rules, blurb) end
    else
        card.objective = blurb or ""
    end
    local terms = modes.terms()
    if #terms > 0 then table.insert(card.rules, table.concat(terms, "   -   ")) end
    local total = math.ceil(COUNTDOWN_FRAMES / 30)
    if type(seconds) == "number" and seconds >= 1 then
        card.left = OF.util.clamp((seconds - countdownPhase / 30) / total, 0, 1)
        card.count = { n = seconds, frac = OF.util.clamp(countdownPhase / 30, 0, 1) }

        card.hints = modes.rules_hint()
    end
    return card
end

local function render_countdown()

    local seconds = gGlobalSyncTable.ofGmCount
        or math.ceil(COUNTDOWN_FRAMES / 30)
    local mode = modes.current()

    if type(seconds) == "number" and seconds >= 1 then
        if seconds ~= countdownDigit then
            countdownDigit = seconds
            countdownPhase = 0
        else
            countdownPhase = countdownPhase + 1
        end
    end

    if mode ~= nil then
        local age = intro_age()
        local card = modes.intro_card(mode, seconds)
        card.below = modes.countdown_controls_room(mode)
        if OF.hud.intro_card(card, age) then
            modes.countdown_controls(mode, age)
        end
        return
    end
    if type(seconds) ~= "number" or seconds < 1 then return end
    modes.draw_count_digit(seconds, countdownPhase)
end

modes.countdownControls = nil

local cdList = { key = nil, set = nil, list = nil }
function modes.countdown_list(mode)
    local P = OF.pause
    local set = OF.util.asks(OF.hud, "glyph_set") and OF.hud.glyph_set() or nil
    local key = mode ~= nil and mode.key or nil
    if cdList.list == nil or cdList.key ~= key or cdList.set ~= set then
        cdList.key, cdList.set, cdList.list = key, set, P.mode_controls(mode)
    end
    return cdList.list
end
function modes.countdown_controls_room(mode)
    local H, P = OF.hud, OF.pause
    if H == nil or P == nil or not OF.util.asks(P, "controls_height") then return nil end
    local list = modes.countdown_list(mode)
    if type(list) ~= "table" or #list == 0 then return nil end
    return P.controls_height(#list, 2, list, 620) + P.MODE.gap
end
function modes.countdown_controls(mode, age)
    modes.countdownControls = nil
    local H, P = OF.hud, OF.pause
    if H == nil or P == nil or not OF.util.asks(P, "draw_controls") then return nil end
    local card = H.state ~= nil and H.state.intro or nil
    if card == nil then return nil end
    local list = modes.countdown_list(mode)
    if type(list) ~= "table" or #list == 0 then return nil end
    local _, sh = H.screen()
    local gap = P.MODE.gap
    local y = card.y + card.h + gap
    local cols, ch = 2, P.controls_height(#list, 2, list, card.w)
    while cols < 4 and y + ch > sh - H.MARGIN and cols < #list do
        cols = cols + 1
        ch = P.controls_height(#list, cols, list, card.w)
    end
    local foot = sh - H.MARGIN - ch
    if y > foot then y = foot end
    if y < card.y + card.h + gap / 2 then return nil end
    local k = H.ease.out_cubic(H.progress(age or 0, 12, H.MOTION.base))
    P.draw_controls(card.x, y, card.w, list, k, cols)
    modes.countdownControls = { x = card.x, y = y, w = card.w, h = ch, count = #list, cols = cols }
    return modes.countdownControls
end

function modes.draw_count_digit(seconds, phase, cardBottom)
    if type(seconds) ~= "number" or seconds < 1 then return false end
    return OF.hud.countdown(seconds, OF.util.clamp((phase or 0) / 30, 0, 1))
end

function modes.draw_count_title(title)
    if type(title) ~= "string" or title == "" then return nil end
    local H = OF.hud
    local sw, sh = H.screen()
    local _, cy = H.countdown_centre()
    local _, _, capH = H.cap("title", 1, title)
    local plateH = capH + H.S.s4 * 2
    local plateW = H.ink_width(title, "title") + H.S.s6 * 2
    local top = cy - H.COUNT_RING - 24 - plateH
    H.plate(sw / 2 - plateW / 2, top, plateW, plateH, { strip = "gold" })
    H.text_mid(title, sw / 2, top + plateH / 2, "title", "gold", 255, "center")
    return top + plateH
end

local function render_go()
    if (modes.goFrames or 0) <= 0 then return end
    modes.goFrames = modes.goFrames - 1
    OF.hud.go(GO_FRAMES - 1 - modes.goFrames)
end

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

local STANDING_NAME_ROOM = 120

local STANDING_GAP = "   -   "
function modes.standing_line()
    local mode = modes.current()
    if mode == nil then return "" end
    if mode.resultsBy == "survival" then return "" end

    if mode.placesOnBoard then return "" end

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

        local face = OF.util.title_face(line.text)
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

function modes.strip_lines(withAim, chipSaysWaiting)
    local lines = {}

    if gGlobalSyncTable.ofGmState == modes.LOBBY then
        local waiting = modes.current()
        if not chipSaysWaiting then
            table.insert(lines, { text = modes.lobby_line(waiting),
                r = 230, g = 190, b = 120 })
        end
    end

    local count = gGlobalSyncTable.ofGmCount
    if gGlobalSyncTable.ofGmState == modes.COUNTDOWN
        and type(count) == "number" and count <= 0 then
        local waiting = math.max(1, -count)
        local text
        if not modes.pins_on_players(modes.current()) then
            text = OF.lang.t("Waiting for the host to finish loading")
        else
            text = OF.lang.plural(waiting, "Waiting for @ player to finish loading",
                "Waiting for @ players to finish loading")
        end
        table.insert(lines, { text = text, r = 230, g = 190, b = 120 })
    end

    local current = modes.current()
    if withAim and not (current ~= nil and current.aimInLine == true)
        and modes.paused() then
        local aim = modes.aim_line()
        if aim ~= "" then
            table.insert(lines, { text = OF.lang.t(aim),
                r = 200, g = 200, b = 200 })
        end
    end

    local standing, leading = "", false
    if modes.paused() then standing, leading = modes.standing_line() end
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

modes.CLUSTER_SEEN = {}

function modes.side_cluster(score_of, target)
    if not (OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()) then return nil end
    if type(score_of) ~= "function" then return nil end
    local mine = OF.teams.of(0)
    local other = mine == "blue" and "red" or "blue"
    if mine ~= "red" and mine ~= "blue" then mine, other = "red", "blue" end
    local now = OF.hud.now()
    local out = {}
    for index, key in ipairs({ mine, other }) do
        local team = OF.teams.find(key)
        local ok, score = pcall(score_of, key)
        score = (ok and tonumber(score)) or 0
        local seen = modes.CLUSTER_SEEN[key]
        if seen == nil or score < seen.score then
            seen = { score = score, at = nil }
            modes.CLUSTER_SEEN[key] = seen
        elseif score > seen.score then
            seen.score, seen.at = score, now
        end
        local side = {
            label = string.upper(OF.lang.t(OF.teams.side_name(key))),
            score = score,
            target = tonumber(target),
            colour = team ~= nil and { team.r, team.g, team.b } or OF.hud.C.ink,

            key = key,
            shape = (OF.hud.TEAM_GLYPH ~= nil and OF.hud.TEAM_GLYPH[key])
                or (key == "red" and "circle" or "square"),
        }
        local flash = seen.at ~= nil and (now - seen.at) or nil
        if index == 1 then out.left, out.leftFlash = side, flash
        else out.right, out.rightFlash = side, flash end
    end
    return out
end

function modes.waiting_header(mode)
    mode = mode or modes.current()
    if mode == nil then return nil end
    return OF.hud.header(OF.lang.t(mode.name), modes.lobby_line(mode), modes.rules_hint(),
        function(h, w) return OF.util.hud_claim(h, 6, w) end)
end

do

modes.STATE_PRIO = { out = 20, watching = 10 }

modes.BANNER_RULES = { leadGap = 90, quiet = 150, resultAt = 30, mvpAt = 45 }

function modes.state_word(id, text, opts)
    local H = OF.hud
    if id == nil or H == nil or type(H.state_line) ~= "function" then return false end
    return H.state_line(id, text, opts) == true
end

function modes.state_case(text)
    if type(text) ~= "string" or text == "" then return text end
    local lower = string.lower(text)
    return string.upper(string.sub(lower, 1, 1)) .. string.sub(lower, 2)
end

function modes.ask_state_words(mode)
    if mode == nil or type(mode.state_word) ~= "function" then return 0 end
    local ok, text, opts = pcall(mode.state_word, modes.my_role())
    if not ok or text == nil then return 0 end
    if type(text) == "table" then
        local count = 0
        for index, entry in ipairs(text) do
            if type(entry) == "table"
                and modes.state_word(entry.id or ("mode" .. index), entry.text, entry) then
                count = count + 1
            end
        end
        return count
    end
    if type(opts) ~= "table" then opts = {} end
    return modes.state_word(opts.id or "mode", text, opts) and 1 or 0
end

function modes.framework_states()
    if modes.state() ~= modes.ACTIVE then return end
    local P = modes.STATE_PRIO
    local mode = modes.current()
    local role = modes.role(0)
    if modes.OUT_ROLES[role] == true then
        local word = mode ~= nil and type(mode.outWord) == "string" and mode.outWord or "Out"
        modes.state_word("out", modes.state_case(OF.lang.t(word)),
            { prio = P.out, tone = "mute", colour = true })
    elseif role == "" and not OF.util.can_play(0)
        and not (OF.util.asks(OF.outseat, "sitting_out") and OF.outseat.sitting_out()) then
        modes.state_word("out", OF.lang.t("Sitting out"), { prio = P.out, tone = "mute", colour = true })
    end
    local S = OF.spectate
    if S ~= nil and S.target ~= nil and network_local_index_from_global ~= nil then
        local who = network_local_index_from_global(S.target)
        local np = who ~= nil and gNetworkPlayers[who] or nil
        if np ~= nil and np.connected and who ~= 0 then
            modes.state_word("watching", OF.lang.fill("Watching @",
                OF.util.shorten(OF.util.name_safe(np.name or ""), 12)), { prio = P.watching })
        end
    end
end

modes.stateLineY = nil

modes.stateLineFault = nil

function modes.draw_state_line()
    local H = OF.hud
    if H == nil or type(H.state_line_draw) ~= "function" then return nil end
    local y = modes.stateLineY
    modes.stateLineY = nil
    modes.framework_states()
    modes.ask_state_words(modes.current())
    local bottom = nil

    if y ~= nil then
        local ok, drawn = pcall(H.state_line_draw, y)
        if ok then
            bottom = drawn
        else
            modes.stateLineFault = drawn
        end
    end
    if type(H.banner_draw) == "function" then H.banner_draw() end
    return bottom
end

function modes.round_target(mode)
    mode = mode or modes.current()
    if mode == nil or type(mode.target_now) ~= "function" then return nil end
    local ok, value = pcall(mode.target_now)
    value = ok and tonumber(value) or nil
    if value ~= nil and value > 0 then return value end
    return nil
end

function modes.side_still_in(key)
    local count = 0
    for _, entry in ipairs(modes.played()) do
        if OF.teams.of(entry.localIndex) == key
            and modes.OUT_ROLES[modes.role(entry.localIndex)] ~= true then
            count = count + 1
        end
    end
    return count
end

function modes.live_role_count()
    local first, count = nil, 0
    for _, entry in ipairs(modes.played()) do
        local role = modes.role(entry.localIndex)
        if role ~= "" and role ~= modes.WAITING and modes.OUT_ROLES[role] ~= true then
            if first == nil then
                first, count = role, 1
            elseif role ~= first then
                return 2
            end
        end
    end
    return count
end

modes.FFA_CLUSTER = {}
function modes.ffa_cluster(mode)
    local out = modes.FFA_CLUSTER
    local board = modes.podium()
    local me, rank = nil, nil
    for index, row in ipairs(board) do
        if row.localIndex == 0 then me, rank = row, index end
    end
    local function plate(row, label)
        return { label = label or OF.util.shorten(OF.util.name_safe(row.name or ""), 14),
            score = row.score or 0, localIndex = row.localIndex }
    end
    if me ~= nil then
        out.you = plate(me, OF.hud.ordinal(rank))
        out.leader = board[rank == 1 and 2 or 1] ~= nil and plate(board[rank == 1 and 2 or 1]) or nil
    elseif #board > 0 then

        out.you = plate(board[1], OF.hud.ordinal(1))
        out.leader = board[2] ~= nil and plate(board[2]) or nil
    else
        out.you = { label = OF.lang.t("YOU"), score = tonumber(gPlayerSyncTable[0].ofScore) or 0,
            localIndex = 0 }
        out.leader = nil
    end
    local top, second = board[1], board[2]
    out.leaderIndex = nil
    if top ~= nil and (second == nil or (top.score or 0) > (second.score or 0)) then
        out.leaderIndex = top.localIndex
    end
    out.target = modes.round_target(mode)
    out.left, out.right = nil, nil
    return out
end

function modes.default_cluster(mode)
    if mode == nil or mode.cluster == false then return nil end

    if type(mode.catchers) == "table" then return nil end
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        if mode.resultsBy == "survival" then
            return modes.side_cluster(modes.side_still_in, nil)
        end
        local score_of = type(mode.side_score) == "function" and mode.side_score or OF.teams.score
        return modes.side_cluster(score_of, modes.round_target(mode))
    end
    if mode.resultsBy == "splits" or mode.countsUp or mode.placesOnBoard then return nil end
    if modes.live_role_count() >= 2 then return nil end
    if mode.resultsBy == "survival" then
        local still = 0
        for _, entry in ipairs(modes.played()) do
            if modes.OUT_ROLES[modes.role(entry.localIndex)] ~= true then still = still + 1 end
        end
        local out = modes.FFA_CLUSTER
        out.you = { label = OF.lang.t("STILL IN"), score = still }
        out.leader, out.leaderIndex, out.target, out.left, out.right = nil, nil, nil, nil, nil
        return out
    end
    if mode.target == nil and mode.keepsScore ~= true then return nil end
    if mode.target ~= nil and mode.target.clock == true and mode.keepsScore ~= true then return nil end
    return modes.ffa_cluster(mode)
end

function modes.cluster_for(mode)
    if mode == nil then return nil end
    if type(mode.cluster) == "function" then
        local ok, got = pcall(mode.cluster)
        if ok and type(got) == "table" then return got end
    end
    return modes.default_cluster(mode)
end

function modes.roles_differ(mode)
    mode = mode or modes.current()
    if mode ~= nil and mode.rolesDiffer ~= nil then return mode.rolesDiffer == true end
    return modes.live_role_count() >= 2
end

function modes.role_noun(role, mode)
    mode = mode or modes.current()
    if type(role) ~= "string" or role == "" then return "" end
    local said = nil
    if mode ~= nil and type(mode.roleNoun) == "table" then
        said = mode.roleNoun[role]
    elseif mode ~= nil and type(mode.roleNoun) == "function" then
        local ok, noun = pcall(mode.roleNoun, role)
        if ok then said = noun end
    end
    if type(said) == "string" and said ~= "" then return OF.lang.t(said) end
    local word = OF.lang.t(role)
    word = string.gsub(word, "^[Aa]n? ", "")
    word = string.gsub(word, "^[Tt]he ", "")
    return string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
end

function modes.role_badge_word()
    local role = modes.my_role()
    if role == "" or role == modes.WAITING or modes.OUT_ROLES[role] == true then return nil end
    if not modes.roles_differ() then return nil end
    local noun = modes.role_noun(role)
    if noun == "" then return nil end
    return noun
end

function modes.finish_word(mode)
    if mode ~= nil and type(mode.finishWord) == "string" and mode.finishWord ~= "" then
        return OF.lang.t(mode.finishWord)
    end
    if mode ~= nil and (mode.countsUp or mode.resultsBy == "splits") then return OF.lang.t("FINISHED") end
    return OF.lang.t("FINISH!")
end

local function side_word(key)
    return string.upper(OF.lang.t(OF.teams.side_name(key)))
end

function modes.score_sub(red, blue)
    return side_word("red") .. " " .. tostring(red or 0) .. " - " .. tostring(blue or 0)
        .. " " .. side_word("blue")
end

modes.WATCH = {}

function modes.role_banner(mode, old, new)
    local H = OF.hud
    if old == nil or old == "" or old == modes.WAITING or old == new then return nil end
    if modes.OUT_ROLES[old] == true then return nil end
    if modes.OUT_ROLES[new] == true then
        local cause = nil
        if mode ~= nil and type(mode.out_cause) == "function" then
            local ok, said = pcall(mode.out_cause)
            if ok and type(said) == "string" and said ~= "" then cause = OF.lang.t(said) end
        end
        local word = mode ~= nil and type(mode.outWord) == "string" and OF.lang.t(mode.outWord) or nil
        return H.banner("out", word, cause)
    end
    if new == "" or new == modes.WAITING then return nil end
    if mode ~= nil and (mode.roleBanner == false
        or (mode.resultsBy == "survival" and mode.sideRoles ~= true)) then
        return nil
    end
    return H.banner("role", OF.lang.fill("YOU ARE @", string.upper(modes.role_noun(new, mode))))
end

function modes.watch_sides(mode, st, now, early)
    local H = OF.hud
    local W = modes.WATCH
    local R = modes.BANNER_RULES
    local L, Rt = st.left, st.right
    local mine = OF.teams.of(0)
    local onSide = mine == "red" or mine == "blue"
    local function side_of(key)
        if not onSide then return nil end
        return key == mine and "us" or "them"
    end
    if mode.resultsBy == "survival" then return end
    W.scores = W.scores or {}
    local red = L.key == "red" and L.score or Rt.score
    local blue = L.key == "blue" and L.score or Rt.score
    for _, s in ipairs({ L, Rt }) do
        local was = W.scores[s.key]
        if was ~= nil and (s.score or 0) > was and type(mode.pointBanner) == "string" then
            H.banner("point", OF.lang.t(mode.pointBanner), modes.score_sub(red, blue),
                { side = side_of(s.key) })
        end
        W.scores[s.key] = s.score or 0
    end
    local leader = nil
    if (L.score or 0) > (Rt.score or 0) then leader = L.key
    elseif (Rt.score or 0) > (L.score or 0) then leader = Rt.key end
    if leader ~= nil then
        if W.lead ~= nil and leader ~= W.lead and not early
            and now - (W.leadAt or -100000) >= R.leadGap then
            local side = side_of(leader)
            local word = (side == "us" and OF.lang.t("WE LEAD"))
                or (side == "them" and OF.lang.t("THEY LEAD"))
                or OF.lang.fill("@ LEADS", side_word(leader))
            H.banner("lead", word, modes.score_sub(red, blue), { side = side })
            W.leadAt = now
        end
        W.lead = leader
    end
    local target = tonumber(L.target) or tonumber(Rt.target)
    if target ~= nil and target > 1 and not mode.noMatchPoint then
        W.said = W.said or {}
        for _, s in ipairs({ L, Rt }) do
            local other = s == L and Rt or L
            if (s.score or 0) == target - 1 and (other.score or 0) < target then
                st.match = s.key
                if not W.said["mp:" .. s.key] then
                    W.said["mp:" .. s.key] = true
                    H.banner("matchpoint", nil, OF.lang.fill("@ needs 1",
                        modes.state_case(side_word(s.key))), { tone = s.colour })
                end
            end
        end
    end
end

function modes.watch_ffa(mode, st, now, early)
    local H = OF.hud
    local W = modes.WATCH
    local R = modes.BANNER_RULES
    local leader = st.leaderIndex
    if leader ~= nil then
        if W.lead ~= nil and leader ~= W.lead and not early
            and now - (W.leadAt or -100000) >= R.leadGap then
            local np = gNetworkPlayers[leader]
            local word = leader == 0 and OF.lang.t("YOU LEAD")
                or OF.lang.fill("@ LEADS", OF.util.shorten(OF.util.name_safe(np ~= nil and np.name or ""), 12))
            H.banner("lead", word, nil, { side = leader == 0 and "us" or "them" })
            W.leadAt = now
            W.swapAt = now
        end
        W.lead = leader
    end
    if W.swapAt ~= nil then st.leadSwap = now - W.swapAt end
    local target = tonumber(st.target)
    if leader ~= nil and target ~= nil and target > 1 and not mode.noMatchPoint then
        local top = leader == 0 and st.you or st.leader
        if leader ~= 0 and st.you ~= nil and st.you.localIndex == leader then top = st.you end
        if top ~= nil and (top.score or 0) == target - 1 then
            W.said = W.said or {}
            if not W.said["mp:" .. leader] then
                W.said["mp:" .. leader] = true
                local np = gNetworkPlayers[leader]
                H.banner("matchpoint", nil, leader == 0 and OF.lang.t("You need 1")
                    or OF.lang.fill("@ needs 1", OF.util.shorten(OF.util.name_safe(np ~= nil and np.name or ""), 12)))
            end
        end
    end
end

function modes.watch_side_switch(mode)
    local W = modes.WATCH
    local side = OF.util.asks(OF.teams, "of") and OF.teams.of(0) or nil
    if side ~= "red" and side ~= "blue" then
        W.side, W.job = nil, nil
        return nil
    end
    local job = nil
    if type(mode.side_job) == "function" then
        local ok, said = pcall(mode.side_job, 0)
        if ok and type(said) == "string" and said ~= "" then job = said end
    end
    local said = nil
    if W.side ~= nil and (side ~= W.side or (job ~= nil and W.job ~= nil and job ~= W.job)) then
        local sub = job ~= nil and OF.lang.fill("You @ now", OF.lang.t(job))
            or OF.lang.fill("You are @ now", OF.lang.t(OF.teams.side_name(side)))
        said = OF.hud.banner("sideswitch", nil, sub)
    end
    W.side, W.job = side, job
    return said
end

function modes.watch_last(mode)
    local H = OF.hud
    local W = modes.WATCH
    local played = modes.played()
    if mode.resultsBy == "survival" and type(mode.catchers) ~= "table" then
        local still, names = 0, {}
        for _, entry in ipairs(played) do
            if modes.OUT_ROLES[modes.role(entry.localIndex)] ~= true then
                still = still + 1
                names[#names + 1] = OF.util.shorten(OF.util.name_safe(entry.np.name or ""), 12)
            end
        end
        if W.still ~= nil and W.still > 2 and still == 2 then
            local marked = not OF.util.asks(OF.markers, "players_marked") or OF.markers.players_marked()
            H.banner("eliminated", OF.lang.t(mode.lastTwoWord or "LAST 2"),
                marked and table.concat(names, " - ") or nil)
        end
        W.still = still
    elseif type(mode.catchers) == "table" then
        local prey = 0
        for _, entry in ipairs(played) do
            local role = modes.role(entry.localIndex)
            if role ~= "" and role ~= modes.WAITING and modes.OUT_ROLES[role] ~= true
                and mode.catchers[role] ~= true then
                prey = prey + 1
            end
        end
        if W.prey ~= nil and W.prey > 1 and prey == 1 then
            H.banner("eliminated", OF.lang.t(mode.lastWord or "LAST ONE"))
        end
        W.prey = prey
    end
end

function modes.watch_banners(mode, st, now)
    local H = OF.hud
    if mode == nil or H == nil or type(H.banner) ~= "function" then return end
    local W = modes.WATCH

    if W.key ~= mode.key or W.startAt == nil then
        for name in pairs(W) do W[name] = nil end
        W.key, W.startAt = mode.key, now
    end
    local early = now - W.startAt < modes.BANNER_RULES.quiet

    if modes.overtime_seconds() ~= nil then
        if not W.overtime then
            W.overtime = true
            H.banner("overtime", mode.overtimeWord and OF.lang.t(mode.overtimeWord) or nil,
                mode.overtimeSub and OF.lang.t(mode.overtimeSub) or nil)
        end
    end
    local role = modes.role(0)
    if W.role ~= nil and role ~= W.role then modes.role_banner(mode, W.role, role) end
    W.role = role
    modes.watch_side_switch(mode)
    if st.left ~= nil and st.right ~= nil and st.left.key ~= nil and st.right.key ~= nil then
        modes.watch_sides(mode, st, now, early)
    elseif st.you ~= nil and mode.resultsBy ~= "survival" then
        modes.watch_ffa(mode, st, now, early)
    end
    modes.watch_last(mode)
end

function modes.forget_watch()
    for name in pairs(modes.WATCH) do modes.WATCH[name] = nil end
end

function modes.ending_banners(kind, word, sub, age)
    local H = OF.hud
    if H == nil or type(H.banner) ~= "function" then return false end
    local E = modes.ENDING
    if E.finishFor ~= E.since then
        E.finishFor, E.resultFor = E.since, nil

        local now = type(H.now) == "function" and H.now() or 0
        H.banner("finish", modes.finish_word(modes.current()), nil, { now = now - 1 })
    end
    local R = modes.BANNER_RULES
    if kind ~= nil and age >= R.resultAt and E.resultFor ~= E.since then
        E.resultFor = E.since
        local band = ({ win = "win", loss = "lose", draw = "draw", roundend = "roundend" })[kind] or "draw"
        local quiet = band == "win" and modes.i_won()
            and OF.util.asks(OF.celebrate, "showing") and OF.celebrate.showing() == true
        H.banner(band, word, sub, { hold = MOMENT_FRAMES - R.resultAt, quiet = quiet })
    end
    return true
end
end

local function render_bar(waiting)
    local mode = modes.current()
    if mode == nil then return end
    local H = OF.hud

    if waiting then
        modes.waiting_header(mode)
        H.feed_draw(nil, math.max(H.MARGIN, OF.util.counters_bottom(select(2, H.screen())) + 8))
        H.callout_draw()
        return
    end
    local st = {}
    local over = modes.overtime_seconds()
    if over ~= nil then
        st.overtime = true
    elseif mode.countsUp then
        st.timer, st.countUp = modes.elapsed(), true
    else
        st.timer = modes.time_left()
    end

    if over == nil and type(mode.clock_face) == "function" then
        local ok, face = pcall(mode.clock_face)
        if ok and type(face) == "table" then
            st.timer, st.countUp = tonumber(face.timer), nil
            st.clockText, st.clockTone, st.clockTint = face.text, face.tone, face.tint
        end
    end

    local sides = modes.cluster_for(mode)
    if sides ~= nil then
        st.left, st.right, st.you, st.leader, st.target =
            sides.left, sides.right, sides.you, sides.leader, sides.target
        st.leftFlash, st.rightFlash = sides.leftFlash, sides.rightFlash
        st.match, st.leaderIndex = sides.match, sides.leaderIndex
    end

    modes.watch_banners(mode, st, H.now())
    local L = H.cluster_layout(st)
    local wide = L.chipW
    if st.left ~= nil then wide = L.chipW + 2 * (L.sideW + H.SIDE_GAP)
    elseif st.you ~= nil then wide = L.chipW + 2 * (L.ffaW + H.SIDE_GAP) end
    local tall = H.CHIP_H + ((st.left ~= nil and ((st.left.target or 0) > 0
        or (st.right.target or 0) > 0)) and 14 or 0)
        + ((st.you ~= nil and (st.target or 0) > 0) and 8 or 0)

    local gap = 6
    local lineH = type(H.state_line_height) == "function" and H.state_line_height() or 0
    st.top = OF.util.hud_claim(tall + gap + lineH, 0, wide)
    local bottom = H.top_cluster(st)
    modes.stateLineY = math.max(st.top + tall, bottom or 0) + gap

    local over = modes.overtime_seconds()
    if over ~= nil then
        local left = 1 - math.min(1, (over * 30) / OVERTIME_MAX)
        local barW = L.chipW - 16
        H.rect(L.chipX + 8, st.top + H.CHIP_H - 5, barW, 2, H.C.plate, 180)
        H.rect(L.chipX + 8, st.top + H.CHIP_H - 5, barW * left, 2, "warn", 255)
        modes.overtimeLeft = left
    else
        modes.overtimeLeft = nil
    end

    local noun = modes.role_badge_word()
    if noun ~= nil then

        local sw = H.screen()
        local room = (sw - wide) / 2 - H.MARGIN - H.S.s4 - (H.S.s3 * 2 + 3)
        H.role_badge(H.fit(noun, "body", math.max(60, room)), "accent")
    end

    local unders = modes.strip_lines(true, false)
    if #unders > 0 then
        local head = table.remove(unders, 1)
        local opts = { accent = OF.GOLD, exact = modes.paused() }
        if #unders > 0 then opts.under = unders end
        OF.util.banner(head.text, head.scale, head.r, head.g, head.b, 255, opts)
    end

    local _, sh = H.screen()
    H.feed_draw(nil, math.max(H.MARGIN, OF.util.counters_bottom(sh) + 8))
    H.callout_draw()
end

do
    local function by_score_then_name(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end

    local podiumRow = {}
    local podiumScore = {}

    function modes.podium()

        local played = modes.played()
        local any = false
        for index, entry in ipairs(played) do
            local final = modes.final_of(entry.localIndex)
            local score = final ~= nil and final.score
                or gPlayerSyncTable[entry.localIndex].ofScore or 0
            if score > 0 then any = true end
            podiumScore[index] = score
        end
        if not any then return {} end

        local list = {}
        for index, entry in ipairs(played) do
            local localIndex = entry.localIndex
            local row = podiumRow[localIndex]
            if row == nil then
                row = {}
                podiumRow[localIndex] = row
            end
            row.localIndex = localIndex
            row.name = entry.np.name
            row.score = podiumScore[index]
            list[index] = row
        end

        table.sort(list, by_score_then_name)
        return list
    end
end

do
local function by_lasted(a, b)
    if a.lasted ~= b.lasted then return a.lasted > b.lasted end

    local aHome = a.home or math.huge
    local bHome = b.home or math.huge
    if aHome ~= bHome then return aHome < bHome end
    return a.name < b.name
end

function modes.survival_board()
    local board = {}
    local any = false

    for _, entry in ipairs(modes.played()) do
        local role = modes.role(entry.localIndex)
        local time = gPlayerSyncTable[entry.localIndex].ofGmTime or 0
        local out = modes.OUT_ROLES[role] == true

        local final = modes.final_of(entry.localIndex)
        if final ~= nil then time, out = final.time, final.out end
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

    table.sort(board, by_lasted)
    return board
end
end

modes.OUT_ROLES = { out = true }

do
local function no_column() return "" end
local function splits_column(entry) return entry.right end
local function survival_column(entry)

    if entry.home ~= nil then return modes.clock(entry.home) end

    if not entry.out then return OF.lang.t("winner") end
    return modes.clock(entry.lasted)
end
local function score_column(entry) return tostring(entry.score) end

function modes.finishing_order()
    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        return {}, no_column
    end

    local mode = modes.current()
    if mode ~= nil and mode.resultsBy == "splits" and mode.board ~= nil then

        return mode.board(), splits_column
    end
    if mode ~= nil and mode.resultsBy == "survival" then
        return modes.survival_board(), survival_column
    end
    return modes.podium(), score_column
end
end

modes.ENDING = { since = nil, last = nil, resultsAt = nil }

modes.MVP_FRAMES = 45

modes.MVP_AT = 0.62

function modes.ending_age()
    local now = OF.hud.now()
    local st = modes.ENDING
    if st.last == nil or now - st.last > 2 then
        st.since, st.resultsAt = now, nil
    end
    st.last = now
    return now - st.since
end

function modes.results_age()
    modes.ending_age()
    local st = modes.ENDING
    local now = OF.hud.now()
    if st.resultsAt == nil then st.resultsAt = now end
    return now - st.resultsAt
end

modes.RESULTS_HEADLINE_AT = 0.32

local function render_moment()
    local mode = modes.current()
    local text = nil
    local kind = "draw"
    local word = nil

    local role = modes.my_role()
    local played = role ~= "" and role ~= modes.WAITING
    if mode ~= nil and mode.resultsBy == "survival" and played then
        if modes.survived(0) then
            kind, word = "win", OF.lang.t("YOU WON")
        else
            kind, word = "loss", OF.lang.t("YOU ARE OUT")
        end
        text = modes.winner_line()
    else
        text = modes.winner_line()
        if played then
            if modes.won(0) then kind = "win"
            elseif #modes.winners() > 0 or modes.winning_side() ~= nil then kind = "loss" end
        end
    end
    local age = modes.ending_age()
    local sub = text or ""
    local decided = modes.decided_line()
    if decided ~= "" then sub = (sub ~= "" and (sub .. " - ") or "") .. decided end

    if (text == nil or text == "") and word == nil then
        kind = nil
    elseif not played then
        kind, word = "roundend", OF.lang.t("ROUND OVER")
    end

    modes.ending_banners(kind, word, sub, age)
    OF.hud.banner_draw()

    if age >= modes.BANNER_RULES.mvpAt then
        local board, right = modes.finishing_order()
        local top = board[1]
        if top ~= nil then
            OF.hud.cue_once("mvp" .. tostring(modes.ENDING.since), "mvp")
            OF.hud.mvp({ name = top.name, stat = right(top) }, age - modes.BANNER_RULES.mvpAt,
                { y = modes.MVP_AT })
        end
    end
end

local RESULT_ROWS = {}

local RESULT_BOARD = { podium = true, columns = { "" } }

function modes.board_sub()
    local H = OF.hud
    if H ~= nil and type(H.band_area) == "function" and H.band_area() ~= nil then return "" end
    return modes.winner_line()
end

modes.TEAM_RESULT_SIDES = {}
function modes.team_sides()
    local sides = modes.TEAM_RESULT_SIDES
    for index = #sides, 1, -1 do sides[index] = nil end
    local winner = modes.winning_side()
    for index = 1, modes.side_lists() do
        local rows, title, colour = modes.side_list(index)
        local side = { label = title, rows = {} }
        if type(colour) == "table" and colour.r ~= nil then
            side.colour = { colour.r, colour.g, colour.b }
            if colour.key ~= nil and OF.util.asks(OF.teams, "score") then
                side.score = OF.teams.score(colour.key)
                side.winner = winner ~= nil and colour.key == winner
            end
        end
        for j, row in ipairs(rows or {}) do
            side.rows[j] = { name = row.name, score = row.right or "", out = row.out,
                you = row.localIndex == 0 }
        end
        sides[#sides + 1] = side
    end
    return sides
end

function modes.team_results(left, age)
    local mode = modes.current()
    local sides = modes.team_sides()
    if #sides == 0 then return 0 end

    local won = false
    for _, side in ipairs(sides) do if side.winner then won = true end end
    local _, _, _, _, xs = OF.hud.team_board(sides, {
        title = mode ~= nil and OF.lang.t(mode.name) or "",
        sub = won and "" or modes.board_sub(),
        key = "teams" .. tostring(modes.ENDING.resultsAt),
        minX = left,
    }, age)
    modes.sideResultsX = xs or {}
    return #sides
end

local function render_results()
    local H = OF.hud
    local screenWidth = djui_hud_get_screen_width()

    local left = 0
    if OF.util.asks(OF.standings, "results_board") then
        local title, standing, sx, sy = OF.standings.results_board()
        if title ~= nil then
            local bx, _, bw = OF.util.board_box(sx, sy, title, standing, nil)
            left = bx + bw + 16
        end
    end

    local board, right = modes.finishing_order()
    local shown = modes.results_age()
    H.banner_draw()

    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        modes.team_results(left, shown)
        return
    end
    if #board == 0 then return end

    local rows = RESULT_ROWS
    local count = #board
    for place = 1, count do
        local entry = board[place]
        local row = rows[place]
        if row == nil then
            row = {}
            rows[place] = row
        end
        row.name = entry.name
        row.score = right(entry)
        row.you = entry.localIndex == 0
        row.out = false
        row.localIndex = entry.localIndex
    end
    for place = #rows, count + 1, -1 do rows[place] = nil end
    local mode = modes.current()
    RESULT_BOARD.title = mode ~= nil and OF.lang.t(mode.name) or ""
    RESULT_BOARD.sub = modes.board_sub()
    RESULT_BOARD.minX = left

    RESULT_BOARD.reveal = "up"
    RESULT_BOARD.key = "results" .. tostring(modes.ENDING.resultsAt)
    H.scoreboard(rows, RESULT_BOARD, shown)
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
        local width, height = OF.util.round_title_size(line.text, scale)
        local y = OF.util.hud_claim_low(height, 5)

        y = math.min(y, OF.util.camera_icon_top(djui_hud_get_screen_height())
            - height - 9)
        OF.util.plate(screenWidth - width - 26, y - 5, width + 16, height + 10)
        OF.util.round_title(line.text, screenWidth - width - 18, y, scale,
            line.r, line.g, line.b, 255)
    end
end

local function render_strip()
    if modes.state() == modes.ACTIVE then return end

    local lines = modes.strip_lines(false)
    if #lines == 0 then return end

    local head = table.remove(lines, 1)
    local opts = { accent = OF.GOLD, exact = modes.paused() }
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

    local now = get_global_timer ~= nil and get_global_timer() or 0
    if modes.role(0) == "out" and modes.outSaidAt ~= nil and now - modes.outSaidAt <= 1 then return end

    return
end

function modes.out_banner(word, offer)
    modes.outSaidAt = get_global_timer ~= nil and get_global_timer() or 0
    return modes.state_word("out", modes.state_case(OF.lang.t(word or "Out")),
        { prio = modes.STATE_PRIO.out, tone = "mute", colour = true })
end

function modes.away_banner(text)
    return OF.util.round_line(OF.lang.t(text), "line", "dim")
end

do
local SIDE_X, SIDE_Y = 0.03, 0.24
local sideOpts = { scale = 0.85, columns = 1 }
local sideRows = {}
local sideLists = {}
local sideTitles = {}
local sideColours = {}
local listCount = 0

local function list_rows(index)
    local rows = sideRows[index]
    if rows == nil then
        rows = {}
        sideRows[index] = rows
    end
    return rows
end

local function put_row(rows, count, entry, right)
    local row = rows[count]
    if row == nil then
        row = {}
        rows[count] = row
    end
    row.localIndex = entry.localIndex
    row.name = entry.np.name
    row.right = right
    row.score = gPlayerSyncTable[entry.localIndex].ofScore or 0
    row.place = nil
    row.out = false
    return row
end

local function trim(rows, count)
    for index = #rows, count + 1, -1 do rows[index] = nil end
end

local role_groups, role_heading

local function by_standing(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.name < b.name
end

local function by_in_then_score(a, b)
    if a.out ~= b.out then return not a.out end
    return by_standing(a, b)
end

local groupPool, groups = {}, {}
local function by_size(a, b)
    if a.count ~= b.count then return a.count < b.count end
    return a.role < b.role
end
function role_groups(played)
    for index = #groups, 1, -1 do groups[index] = nil end
    for _, entry in ipairs(played) do
        local role = modes.role(entry.localIndex)
        if role ~= "" and modes.OUT_ROLES[role] ~= true then
            local found = nil
            for _, group in ipairs(groups) do
                if group.role == role then found = group end
            end
            if found == nil then
                found = groupPool[#groups + 1]
                if found == nil then
                    found = {}
                    groupPool[#groups + 1] = found
                end
                found.role, found.count = role, 0
                groups[#groups + 1] = found
            end
            found.count = found.count + 1
        end
    end
    table.sort(groups, by_size)
    return groups
end

function role_heading(role)

    local playing = modes.current()
    if playing ~= nil and type(playing.sideTitle) == "function" then
        local said = playing.sideTitle(role)
        if type(said) == "string" and said ~= "" then return OF.lang.t(said) end
    end
    local word = OF.lang.t(role)
    return word:sub(1, 1):upper() .. word:sub(2)
end

local OUT_GREY = { grey = true }

local function add_list(title, rows, colour)
    listCount = listCount + 1
    sideLists[listCount] = rows
    sideTitles[listCount] = title
    sideColours[listCount] = colour or false
end

function modes.role_paint(mode, localIndex)
    if mode == nil or type(mode.paint) ~= "function" or localIndex == nil then
        return nil
    end
    local ok, colour = pcall(mode.paint, localIndex)
    if not ok or type(colour) ~= "table" or colour.r == nil then return nil end
    return colour
end

function modes.side_lists()
    listCount = 0
    local mode = modes.current()
    if mode == nil then return 0 end
    if mode.sideBoard == false and not modes.is_waiting() then return 0 end

    local waiting = modes.is_waiting()

    local played = waiting and modes.participants()
        or (modes.is_running() and modes.board_roster() or modes.played())
    if #played == 0 then return 0 end

    if waiting then
        local rows = list_rows(1)
        local count = 0
        for _, entry in ipairs(played) do
            count = count + 1
            put_row(rows, count, entry, "")
        end
        trim(rows, count)
        table.sort(rows, by_standing)
        add_list(OF.lang.fill("Waiting (@)", tostring(count) .. "/"
            .. tostring(mode.minPlayers or 2)), rows)
        return listCount
    end

    if type(mode.sidePlain) == "function" then
        local ok, plain = pcall(mode.sidePlain)
        if ok and plain == true then
            local rows = list_rows(1)
            local count = 0
            for _, entry in ipairs(played) do
                count = count + 1
                put_row(rows, count, entry, nil)
            end
            trim(rows, count)
            table.sort(rows, function(a, b) return a.name < b.name end)
            add_list(OF.lang.fill("Players (@)", count), rows)
            return listCount
        end
    end

    if OF.util.asks(OF.teams, "in_play") and OF.teams.in_play() then
        for sideIndex, team in ipairs(OF.teams.LIST) do
            local rows = list_rows(sideIndex)
            local count = 0
            for _, entry in ipairs(played) do
                if OF.teams.of(entry.localIndex) == team.key then
                    count = count + 1
                    put_row(rows, count, entry, modes.standing(entry.localIndex) or "")
                end
            end
            trim(rows, count)
            table.sort(rows, by_standing)
            if count > 0 then

                local heading = nil
                if type(mode.sideHeading) == "function" then
                    local ok, said = pcall(mode.sideHeading, team.key, count)
                    if ok and type(said) == "string" and said ~= "" then heading = said end
                end
                add_list(heading or OF.lang.fill("@ (@)", OF.lang.t(OF.teams.side_name(team.key)), count),
                    rows, team)
            end
        end
        return listCount
    end

    local groups = waiting and {} or role_groups(played)
    if #groups >= 2 and (mode.resultsBy ~= "survival" or mode.sideRoles == true) then
        for index, group in ipairs(groups) do
            local rows = list_rows(index)
            local count = 0
            for _, entry in ipairs(played) do
                if modes.role(entry.localIndex) == group.role then
                    count = count + 1
                    put_row(rows, count, entry, modes.standing(entry.localIndex) or "")
                end
            end
            trim(rows, count)
            table.sort(rows, by_standing)

            local same = true
            for index = 2, count do
                if rows[index].right ~= rows[1].right then same = false end
            end
            if same then
                for index = 1, count do rows[index].right = nil end
            end

            add_list(OF.lang.fill("@ (@)", role_heading(group.role), count), rows,
                modes.role_paint(mode, rows[1] and rows[1].localIndex))
        end
        local outRows = list_rows(#groups + 1)
        local outCount = 0
        for _, entry in ipairs(played) do
            if modes.OUT_ROLES[modes.role(entry.localIndex)] == true then
                outCount = outCount + 1
                put_row(outRows, outCount, entry, nil).out = true
            end
        end
        trim(outRows, outCount)
        if outCount > 0 then
            table.sort(outRows, by_standing)
            add_list(OF.lang.fill("Out (@)", outCount), outRows, OUT_GREY)
        end
        return listCount
    end

    if mode.resultsBy == "survival" and not waiting then
        local rows = list_rows(1)
        local count, inCount = 0, 0
        for _, entry in ipairs(played) do
            count = count + 1
            local out = modes.OUT_ROLES[modes.role(entry.localIndex)] == true
            local row = put_row(rows, count, entry,
                out and OF.lang.t("out") or modes.standing(entry.localIndex))
            row.out = out
            if not out then inCount = inCount + 1 end
        end
        trim(rows, count)
        table.sort(rows, by_in_then_score)
        add_list(OF.lang.fill("Still in: @ of @", inCount, count), rows, OUT_GREY)
        return listCount
    end

    local rows = list_rows(1)
    local count = 0
    for _, entry in ipairs(played) do
        count = count + 1
        put_row(rows, count, entry, modes.standing(entry.localIndex) or "")
    end
    trim(rows, count)
    table.sort(rows, by_standing)
    for place, row in ipairs(rows) do row.place = place end

    local heading = mode.boardTitle or (mode.target ~= nil and mode.target.unit) or "Standings"
    add_list(waiting and OF.lang.fill("Waiting (@)", count) or OF.lang.t(heading), rows)
    return listCount
end

modes.SIDE_BOARD_ROWS = 4
local cappedRows = {}
function modes.board_cap(rows, most, into)
    if rows == nil or #rows <= most then return rows end
    local mine = nil
    for index, row in ipairs(rows) do
        if row.localIndex == 0 then mine = index end
    end

    local out = into or cappedRows
    for index = #out, 1, -1 do out[index] = nil end
    for index = 1, most do out[index] = rows[index] end
    if mine ~= nil and mine > most then out[most] = rows[mine] end
    return out
end

modes.cappedSides = {}

function modes.side_list(index)
    return sideLists[index], sideTitles[index], sideColours[index] or nil
end

local rowColour, rowList = nil, nil
local function side_colour() return rowColour.r, rowColour.g, rowColour.b end
local function out_colour(index)
    local row = rowList ~= nil and rowList[index] or nil
    if row ~= nil and row.out then return 150, 150, 150 end
    return OF.util.name_colour()
end

modes.sideEnd = nil

function modes.side_bottom()
    return modes.sideEnd
end

function modes.side_board()
    modes.sideEnd = nil

    if OF.util.asks(OF.scoreboard, "showing") and OF.scoreboard.showing() then
        return false
    end

    if modes.blind_now() then return false end
    local live = modes.state() == modes.ACTIVE and not modes.paused()
    local lists = modes.side_lists()
    if lists == 0 then return false end

    if live then
        for index = 1, lists do
            local into = modes.cappedSides[index] or {}
            modes.cappedSides[index] = into
            sideLists[index] = modes.board_cap(sideLists[index], modes.SIDE_BOARD_ROWS, into)
        end
    end

    local x = djui_hud_get_screen_width() * SIDE_X
    local y = djui_hud_get_screen_height() * SIDE_Y
    local total = 0
    for index = 1, lists do total = total + #sideLists[index] end

    local playing = modes.current()
    sideOpts.wide = playing ~= nil and tonumber(playing.boardWide) or nil
    local from = y
    for _ = 1, 2 do
        sideOpts.scale, sideOpts.columns = OF.util.board_fit(total + lists, lists,
            y - 5, OF.util.board_bottom() - 18 * lists)
        local widest = 0
        for index = 1, lists do
            widest = math.max(widest, select(9, OF.util.board_measure(y,
                sideTitles[index], sideLists[index], sideOpts)))
        end
        local moved = OF.util.board_top(x, from, widest)
        if moved == y then break end
        y = moved
    end

    for index = 1, lists do
        local colour = sideColours[index]
        if colour == OUT_GREY then
            rowList = sideLists[index]
            sideOpts.colour, sideOpts.titleColour = out_colour, nil
        elseif colour then
            rowColour = colour
            sideOpts.colour, sideOpts.titleColour = side_colour, colour
        else
            sideOpts.colour, sideOpts.titleColour = nil, nil
        end
        y = OF.util.board(x, y, sideTitles[index], sideLists[index], sideOpts) + 8
    end
    sideOpts.colour, sideOpts.titleColour = nil, nil
    modes.sideEnd = y
    return true
end
end

function modes.start_early_chip()
    if not modes.is_waiting() or not modes.may_force(0) then return false end
    local util = OF.util
    local H = OF.hud
    local sw = H.screen()
    local left, bottom = nil, nil
    local boxes = util.boardBoxes or {}
    for index = 1, util.boardBoxCount or 0, 4 do
        local x0, y1 = boxes[index], boxes[index + 3]
        if x0 ~= nil and y1 ~= nil and x0 < sw / 2 and (bottom == nil or y1 > bottom) then
            left, bottom = x0, y1
        end
    end
    if bottom == nil then return false end
    local text = OF.lang.t("Start it early: Game modes")
    local w = H.ink_width(text, "caption") + H.S.s3 * 2
    local h = 18
    local x, y = left, bottom + 6
    H.plate(x, y, w, h)
    H.text_mid(text, x + w / 2 + 1, y + h / 2, "caption", "ink2", 255, "center")
    return true, x, y, w, h
end

local function render()
    local state = modes.state()

    modes.draw_blind()
    if OF.util.menu_has_screen() then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    render_nonstop()

    if state == modes.OFF then return end

    if OF.util.asks(OF.roundscope, "render_outsider")
        and OF.roundscope.render_outsider() then
        return
    end

    if state ~= modes.LOBBY then render_strip() end
    render_out()

    if state == modes.LOBBY then

        render_bar(true)
        local boards = OF.util.boardsDrawn or 0
        local replaying = OF.util.asks(OF.replay, "playing") and OF.replay.playing() ~= nil
        if not replaying then pcall(modes.side_board) end
        if (OF.util.boardsDrawn or 0) > boards then
            modes.start_early_chip()
        end
    elseif state == modes.COUNTDOWN then
        render_countdown()
    elseif state == modes.ACTIVE then
        render_bar(false)
        local mode = modes.current()
        local boards = OF.util.boardsDrawn or 0

        local replaying = OF.util.asks(OF.replay, "playing")
            and OF.replay.playing() ~= nil
        if mode ~= nil and mode.hud ~= nil and not replaying then mode.hud() end

        modes.render_respawn_wait()

        if (OF.util.boardsDrawn or 0) == boards and not replaying then
            modes.side_board()
        end

        modes.draw_state_line()

        render_go()
    elseif state == modes.MOMENT then
        render_moment()
    elseif state == modes.RESULTS then
        render_results()
    end

    if OF.util.asks(OF.replay, "hud") then OF.replay.hud() end
end

modes.PODIUM_HOLDER = "ending"
modes.PODIUM_BITS = {}
for _, name in ipairs({ "HUD_DISPLAY_FLAG_LIVES", "HUD_DISPLAY_FLAG_COIN_COUNT",
    "HUD_DISPLAY_FLAG_STAR_COUNT", "HUD_DISPLAY_FLAG_CAMERA_AND_POWER",
    "HUD_DISPLAY_FLAG_CAMERA", "HUD_DISPLAY_FLAG_POWER",
    "HUD_DISPLAY_FLAG_TIMER", "HUD_DISPLAY_FLAG_KEYS" }) do
    local value = _G[name]
    if type(value) == "number" then table.insert(modes.PODIUM_BITS, value) end
end
modes.podiumHeld = false

function modes.ending_shown()
    local state = modes.state()
    if (state == modes.MOMENT or state == modes.RESULTS) and modes.hears_round() then
        return true
    end
    local run = OF.speedrun
    return run ~= nil and run.RESULTS ~= nil
        and gGlobalSyncTable.ofRunState == run.RESULTS
end

function modes.hold_the_ending_hud()
    local wanted = modes.ending_shown()
    if not wanted and not modes.podiumHeld then return false end
    modes.podiumHeld = wanted
    for _, bit in ipairs(modes.PODIUM_BITS) do
        OF.util.hud_hide(bit, modes.PODIUM_HOLDER, wanted)
    end
    return wanted
end

local function scenery_update()

    modes.settle_stillness()

    modes.settle_ending()

    modes.settle_winner()

    modes.settle_role_grace()

    modes.relay_frame()

    modes.lead_job_frame()

    modes.note_tag_moves()
    modes.contact_tags()

    modes.claim_frame()

    modes.settle_cam_walls()

    modes.round_sounds_update()
    modes.hold_the_ending_hud()
    if modes.state() == modes.OFF then return end

    if modes.state() == modes.LOBBY then return end
    local mode = modes.current()
    if mode ~= nil and mode.scenery ~= nil then mode.scenery() end
end

hook_event(HOOK_UPDATE, register_with_of_net)
hook_event(HOOK_UPDATE, host_update)

hook_event(HOOK_UPDATE, nonstop_update)
hook_event(HOOK_UPDATE, local_update)
hook_event(HOOK_UPDATE, scenery_update)

function modes.may_leave_level()

    if modes.is_waiting() then
        if modes.strandedFrom then return true end
        local waiting = modes.current()
        if waiting ~= nil and waiting.wholeGame then return true end
        return not OF.util.can_play(0)
    end
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

local function warp_back(held, level, area)
    if level == nil or level == held.level then
        return OF.net.warp_local(held.level, area, held.act, also_list(held))
    end
    local also = { held.level }
    for other in pairs(held.also or {}) do
        if other ~= level then table.insert(also, other) end
    end
    local went = OF.net.warp_local(level, area, held.act, also)
    modes.hold_here(held.level, held.area, held.act, also_list(held))
    return went
end

local REJOIN_GRACE = 90
local REJOIN_TRIES = 4

local insideBefore = false

local returnTo = nil

local heldOutFor = 0
local rejoinTries = 0

modes.strandedFrom = false

local throwBack = nil

local throwBackLevel = nil

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
        local level = throwBackLevel or held.level
        throwBack, throwBackLevel = nil, nil

        if returnTo ~= nil then returnTo.warped = true end
        if warp_back(held, level, area) then
            heldOutFor = 0
            return true
        end

        if returnTo ~= nil and returnTo.landing then returnTo = nil end
        if returnTo ~= nil then returnTo.warped = nil end

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
            "Type /sitout to sit rounds out.",
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

    if not modes.is_running() then return nil end

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

do

modes.FLANK_KEYS = { red = "flankRed", blue = "flankBlue" }

modes.FLANK_FRESH = 1200

modes.FLANK_ZONES = {
    snd = { take = false,
        why = "Nobody comes back inside a round: every round starts each side "
           .. "at its own spawn, and a flank would be a second home the bomb "
           .. "sites were never measured from." },
    ctf = { take = true,
        why = "The base captures nothing - a capture needs the enemy flag in "
           .. "hand and your own at home - so coming back at the flank is a "
           .. "second way into the fight, and the flag stays on its stand." },
    oneflag = { take = true,
        why = "The bases are where the flag stands and where it is carried to, "
           .. "not a thing to stand on; a flank spawn is a second road to the "
           .. "defenders' base." },
    shooter = { take = true,
        why = "Team Deathmatch: two spawn sides keep a winning side from "
           .. "camping the one place the other comes back to." },
    rocketarena = { take = true,
        why = "Deathmatch's team spawns, so Deathmatch's reason." },
    bounty = { take = true,
        why = "Kill Confirmed is Team Deathmatch with tags: two spawn sides "
           .. "keep a winning side from camping the one place the other "
           .. "comes back to, and its tags with it." },

    domination = { take = false,
        why = "The sides open on points one and two, as the originals "
           .. "do (each side near its home flag, never split), "
           .. "and a death comes back only to a point the side holds - a "
           .. "flank would be a place to arrive from that no point pays for." },
    football = { take = false,
        why = "A kickoff formation in the side's own half; a flank is not "
           .. "on the pitch." },
    volleyball = { take = false,
        why = "Rows on the side's own half of the court, as Football." },
    copsandrobbers = { take = false,
        why = "The sides are roles: the cops start at the cell they guard." },
    line = { take = false, why = "No sides: one shared start line." },
    flood = { take = false, why = "No sides: one shared start at the bottom." },
    downhill = { take = false, why = "No sides: one shared start at the top." },
    shellrace = { take = false, why = "No sides: one shared start grid." },
}

function modes.flank_capable(key)
    local row = key ~= nil and modes.FLANK_ZONES[key] or nil
    return row ~= nil and row.take == true
end

local function a_place(at)
    return type(at) == "table" and type(at.x) == "number"
        and type(at.y) == "number" and type(at.z) == "number"
end

function modes.team_home(side, mode)
    mode = mode or modes.current()
    if mode == nil then return nil end
    local fn = mode.team_home
    if type(fn) ~= "function" then fn = mode.side_place end
    if type(fn) ~= "function" then return nil end
    local ok, at = pcall(fn, side)
    if not ok then
        OF.util.report(false, at)
        return nil
    end
    if not a_place(at) then return nil end
    return at
end

function modes.flank_zone(side, home, mode)
    mode = mode or modes.current()
    if mode == nil or not modes.flank_capable(mode.key) then return nil end
    local key = modes.FLANK_KEYS[side]
    if key == nil then return nil end
    local place = nil
    if type(home) == "table" and type(home.level) == "number" then
        place = { level = home.level,
                  area = type(home.area) == "number" and home.area or 1 }
    else
        place = modes.round_place() or modes.here_place(0)
    end
    if place == nil then return nil end
    local list = modes.surveyed_list(place, key)
    local first = list ~= nil and list[1] or nil
    if not a_place(first) then return nil end
    return { x = first.x, y = first.y, z = first.z, yaw = first.yaw,
             level = type(home) == "table" and home.level or nil,
             area = type(home) == "table" and home.area or nil,
             flank = true }
end

function modes.team_spawns(side, mode)
    local home = modes.team_home(side, mode)
    if home == nil then return nil end
    local flank = modes.flank_zone(side, home, mode)
    if flank == nil then return { home } end
    return { home, flank }
end

function modes.team_respawn(side, from, mode)
    local zones = modes.team_spawns(side, mode)
    if zones == nil then return nil end
    if zones[2] == nil then return zones[1] end
    local open = {}
    for _, zone in ipairs(zones) do
        local fresh = false
        if a_place(from) then
            local dx, dy, dz = from.x - zone.x, from.y - zone.y, from.z - zone.z
            fresh = dx * dx + dy * dy + dz * dz
                < modes.FLANK_FRESH * modes.FLANK_FRESH
        end
        if not fresh then table.insert(open, zone) end
    end
    if open[1] == nil then return zones[1] end
    if open[2] == nil then return open[1] end

    return modes.pick_spawn(open, modes.spawn_context(side, from, mode))
end

function modes.team_split(side, home, order, mode)
    if home == nil then return nil end
    local flank = modes.flank_zone(side, home, mode)
    if flank == nil then return nil end
    if order == nil then
        order = {}
        for _, entry in ipairs(modes.participants()) do
            if entry.np ~= nil and OF.util.asks(OF.teams, "of")
                and OF.teams.of(entry.localIndex) == side then
                table.insert(order, entry.np.globalIndex)
            end
        end
        table.sort(order)
    end
    local zones = { home, flank }
    local groups = { {}, {} }
    local turn = modes.round_seed() % 2
    local np = gNetworkPlayers[0]
    local mine = np ~= nil and np.globalIndex or nil
    local myZone = nil
    for index, globalIndex in ipairs(order) do
        local zone = ((index - 1 + turn) % 2) + 1
        table.insert(groups[zone], globalIndex)
        if globalIndex == mine then myZone = zone end
    end
    if myZone == nil then return nil end
    return zones[myZone], groups[myZone]
end
end

do

modes.SPAWN_SCORE = {
    base = 1000,

    enemy = 1600, enemyRadius = 3000,

    sight = 900, sightRange = 6000, sightHeight = 700,

    ally = 250, allyRadius = 2000, allyCount = 3,

    death = 600, deathRadius = 1500,

    objective = 600, objectiveRange = 8000,
}

local sp = { W = modes.SPAWN_SCORE, respawn = { hold = 0, protect = 0 },
             swings = {}, phase = 0 }

function sp.spot_ok(at)
    return type(at) == "table" and type(at.x) == "number"
        and type(at.y) == "number" and type(at.z) == "number"
end

function sp.gap_sq(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

function modes.spawn_seen(eye, spot)
    local dx, dy, dz = spot.x - eye.x, spot.y - eye.y, spot.z - eye.z
    if dx * dx + dy * dy + dz * dz > sp.W.sightRange * sp.W.sightRange then return false end
    local hit = OF.util.optional("collision_find_surface_on_ray", nil,
        eye.x, eye.y + 120, eye.z, dx, dy - 20, dz)
    if hit == nil then return math.abs(dy) <= sp.W.sightHeight end

    return hit.surface == nil
end

function modes.spawn_bodies(side, room)
    local enemies, allies = {}, {}
    local teamed = side ~= nil and OF.util.asks(OF.teams, "of")
    for _, entry in ipairs(modes.participants()) do
        local li = entry.localIndex
        local m = gMarioStates[li]
        local np = entry.np or gNetworkPlayers[li]
        if li ~= 0 and m ~= nil and m.pos ~= nil and np ~= nil
            and (room == nil or room.level == nil or np.currLevelNum == room.level)
            and (room == nil or room.area == nil or np.currAreaIndex == room.area)
            and (type(m.health) ~= "number" or m.health > 0xff)
            and OF.util.optional("is_player_active", 1, m) ~= 0 then
            local at = { x = m.pos.x, y = m.pos.y, z = m.pos.z }
            if not teamed then
                table.insert(enemies, at)
            else
                local theirs = OF.teams.of(li)
                if theirs == side then
                    table.insert(allies, at)
                elseif theirs == "red" or theirs == "blue" then
                    table.insert(enemies, at)
                end
            end
        end
    end
    return enemies, allies
end

function modes.spawn_context(side, from, mode, room)
    mode = mode or modes.current()
    if room == nil and sp.spot_ok(from) then
        room = { level = from.level, area = from.area }
    end
    local enemies, allies = modes.spawn_bodies(side, room)
    local focus = nil
    if mode ~= nil and type(mode.spawn_focus) == "function" then
        local ok, at = pcall(mode.spawn_focus, side)
        if ok and sp.spot_ok(at) then focus = at end
    end
    return { side = side, from = sp.spot_ok(from) and from or nil,
             enemies = enemies, allies = allies, focus = focus }
end

function modes.spawn_score(spot, ctx)
    if not sp.spot_ok(spot) then return -math.huge end
    ctx = ctx or {}
    local score = sp.W.base
    for _, eye in ipairs(ctx.enemies or {}) do
        local d = math.sqrt(sp.gap_sq(eye, spot))
        if d < sp.W.enemyRadius then
            score = score - sp.W.enemy * (1 - d / sp.W.enemyRadius)
        end
        if d < sp.W.sightRange and modes.spawn_seen(eye, spot) then
            score = score - sp.W.sight * (1 - d / sp.W.sightRange)
        end
    end
    local near = 0
    for _, mate in ipairs(ctx.allies or {}) do
        local d = math.sqrt(sp.gap_sq(mate, spot))
        if d < sp.W.allyRadius and near < sp.W.allyCount then
            near = near + 1
            score = score + sp.W.ally * (1 - d / sp.W.allyRadius)
        end
    end
    if ctx.from ~= nil and not ctx.noDeath then
        local d = math.sqrt(sp.gap_sq(ctx.from, spot))
        if d < sp.W.deathRadius then
            score = score - sp.W.death * (1 - d / sp.W.deathRadius)
        end
    end
    if ctx.focus ~= nil then
        local d = math.sqrt(sp.gap_sq(ctx.focus, spot))
        if d < sp.W.objectiveRange then
            score = score + sp.W.objective * (1 - d / sp.W.objectiveRange)
        end
    end
    return score
end

function modes.rank_spawns(list, ctx, tie)
    local ranked = {}
    for index, spot in ipairs(list or {}) do
        if sp.spot_ok(spot) then
            local gap = math.huge
            for _, eye in ipairs((ctx or {}).enemies or {}) do
                local g = sp.gap_sq(eye, spot)
                if g < gap then gap = g end
            end
            local second = gap
            if type(tie) == "function" then second = tie(spot) end
            table.insert(ranked, { spot = spot, score = modes.spawn_score(spot, ctx),
                                   second = second, at = index })
        end
    end
    table.sort(ranked, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.second ~= b.second then return a.second > b.second end
        return a.at < b.at
    end)
    return ranked
end

function modes.pick_spawn(list, ctx, tie)
    local ranked = modes.rank_spawns(list, ctx, tie)
    return ranked[1] and ranked[1].spot or nil
end

modes.SPAWN_RULES = {
    snd = { family = "rounds", wait = 0, protect = 0,
        why = "Counter-Strike and Call of Duty: no respawn inside a round; "
           .. "everybody starts the next one at the side's spawn." },
    ctf = { family = "flag", wait = 3, protect = 45,
        why = "Halo: Capture the Flag respawns slower than Slayer so an "
           .. "attack can land; Mario Kart's 1.5 s of protection at the base." },
    oneflag = { family = "flag", wait = 3, protect = 45,
        why = "Capture the Flag's numbers: the defence gets the time to "
           .. "stop a run, and the base cannot be camped." },
    domination = { family = "zones", wait = 0, protect = 30,
        why = "Call of Duty: quick respawn near a held flag; one second of "
           .. "protection because a held point can be under attack." },
    shooter = { family = "slayer", wait = 0, protect = 0, own = true,
        why = "Slayer respawns at once (Halo 2: 5 s with the death); the "
           .. "mode's own 2 s protection, broken by firing - Unreal's and Knock Out's." },
    rocketarena = { family = "slayer", wait = 0, protect = 0, own = true,
        why = "Deathmatch's numbers: the mode's own 2 s protection." },
    bounty = { family = "slayer", wait = 0, protect = 0, own = true,
        why = "Call of Duty's Kill Confirmed respawns at once; Deathmatch's "
           .. "kit gives the 2 s protection, broken by firing." },
    oitc = { family = "slayer", wait = 0, protect = 0, own = true,
        why = "Deathmatch's numbers: the mode's own 2 s protection." },
    smash = { family = "stage", wait = 0, protect = 0, own = true,
        why = "Knock Out's revival: back on the stage at once, on the lane's own "
           .. "spawn row (an arena's origin), with the mode's own three "
           .. "seconds of respawn invincibility (RESPAWN_GRACE)." },
    hideballoon = { family = "ffa", wait = 0, protect = 0,
        why = "Nobody fights for a spawn: the free-for-all points only keep "
           .. "a respawn away from the others." },
    shellbattle = { family = "battle", wait = 0, protect = 0, own = true,
        why = "Mario Kart Battle: Lakitu's carry and the mode's own frames "
           .. "of protection after it." },
    football = { family = "formation", wait = 0, protect = 0,
        why = "A kickoff formation; nobody is shot at." },
    volleyball = { family = "formation", wait = 0, protect = 0,
        why = "Rows on the court; nobody is shot at." },
    copsandrobbers = { family = "roles", wait = 0, protect = 0,
        why = "The sides are roles: a caught robber goes to the cell, not to "
           .. "a spawn, and the cops start at the cell they guard." },
    line = { family = "race", wait = 0, protect = 0,
        why = "Red Light comes back to its start line; nothing to protect." },
    downhill = { family = "race", wait = 0, protect = 0,
        why = "A race comes back to its line; nothing to protect." },
    flood = { family = "race", wait = 0, protect = 0,
        why = "A climb comes back to its start; nothing to protect." },
    shellrace = { family = "race", wait = 0, protect = 0,
        why = "A race comes back to its grid; nothing to protect." },
}

function modes.spawn_rule(key)
    return key ~= nil and modes.SPAWN_RULES[key] or nil
end

for _, action in ipairs({ ACT_PUNCHING, ACT_MOVE_PUNCHING, ACT_JUMP_KICK,
        ACT_DIVE, ACT_SLIDE_KICK, ACT_SLIDE_KICK_SLIDE, ACT_GROUND_POUND }) do
    if action ~= nil then sp.swings[action] = true end
end

function modes.note_respawn()
    sp.respawn.hold, sp.respawn.protect = 0, 0
    if not modes.is_running() or modes.state() ~= modes.ACTIVE then return false end
    if not OF.util.can_play(0) then return false end
    local mode = modes.current()
    local rule = mode ~= nil and modes.spawn_rule(mode.key) or nil
    if rule == nil or rule.own then return false end
    sp.respawn.hold = math.max(0, math.floor((rule.wait or 0) * 30))
    sp.respawn.protect = math.max(0, math.floor(rule.protect or 0))
    return sp.respawn.hold > 0 or sp.respawn.protect > 0
end

function modes.respawn_left()
    return sp.respawn.hold, sp.respawn.protect
end

function modes.forget_respawn()
    sp.respawn.hold, sp.respawn.protect = 0, 0
end

function modes.settle_respawn(m)
    if m == nil then return false end
    if sp.respawn.hold <= 0 and sp.respawn.protect <= 0 then return false end
    if modes.state() ~= modes.ACTIVE or not OF.util.can_play(0) then
        modes.forget_respawn()
        return false
    end
    if sp.respawn.hold > 0 then
        sp.respawn.hold = sp.respawn.hold - 1
        OF.input.hold(m)
        if (m.invincTimer or 0) < 2 then m.invincTimer = 2 end
        m.hurtCounter = 0
        return true
    end
    if sp.swings[m.action or 0] then
        sp.respawn.protect = 0
        m.invincTimer = 0
        return false
    end
    sp.respawn.protect = sp.respawn.protect - 1
    if (m.invincTimer or 0) < 2 then m.invincTimer = 2 end
    return true
end

function modes.render_respawn_wait()
    if sp.respawn.hold <= 0 then sp.digit = nil return false end
    local seconds = math.ceil(sp.respawn.hold / 30)
    if seconds ~= sp.digit then sp.digit, sp.phase = seconds, 0
    else sp.phase = sp.phase + 1 end
    return modes.draw_count_digit(seconds, sp.phase, nil)
end
end

local HELD_BY_SOMETHING_ELSE = ACT_FLAG_INTANGIBLE or 0x00001000

local IN_THE_AIR = ACT_FLAG_AIR or 0x00000800

local function could_be_left_here(m)
    if m == nil or m.pos == nil then return false end
    if OF.util.has_flag(m.action or 0, HELD_BY_SOMETHING_ELSE) then return false end
    if OF.util.has_flag(m.action or 0, IN_THE_AIR) then return false end
    if ACT_BUBBLED ~= nil and m.action == ACT_BUBBLED then return false end

    if m.floor == nil then return false end

    if SURFACE_BURNING ~= nil and m.floor.type == SURFACE_BURNING then return false end
    return true
end

function modes.may_be_remembered(m)
    return could_be_left_here(m)
end

local eject = {}
do

local entering = nil

eject.PAINTING_LO = SURFACE_PAINTING_WARP_D3 or 0xD3
eject.PAINTING_HI = eject.PAINTING_LO + 0x2C
eject.WARP_FLOOR = SURFACE_WARP or 0x32

eject.LOOK_UP_FLOOR = SURFACE_LOOK_UP_WARP or 0x2F

eject.DOOR_ACTIONS = {}
eject.SWALLOWED = {}
for _, row in ipairs({
    { ACT_PULLING_DOOR, "door" }, { ACT_PUSHING_DOOR, "door" },
    { ACT_ENTERING_STAR_DOOR, "door" }, { ACT_UNLOCKING_KEY_DOOR, "door" },
    { ACT_UNLOCKING_STAR_DOOR, "door" },
    { ACT_DISAPPEARED, "swallow" }, { ACT_TELEPORT_FADE_OUT, "swallow" },
}) do
    if row[1] ~= nil then
        if row[2] == "door" then eject.DOOR_ACTIONS[row[1]] = true
        else eject.SWALLOWED[row[1]] = true end
    end
end

eject.DOOR_OUT = 200
eject.PAINTING_OUT = 300
eject.HOLE_RISE = 300

eject.LAUNCH_UP = 24
eject.LAUNCH_FORWARD = 16

eject.WARP_GRACE = 30

eject.OBJ_NEAR = 800

eject.FULL_HEALTH = 0x880

eject.LOOP_FRAMES = 60
eject.landedAt = nil

function eject.has_bhv(o, id)
    if o == nil or id == nil or type(obj_has_behavior_id) ~= "function" then return false end
    return obj_has_behavior_id(o, id) ~= 0
end

function eject.door_near(m)
    if m == nil or m.marioObj == nil or m.pos == nil then return nil end
    for _, id in ipairs({ id_bhvDoor, id_bhvDoorWarp, id_bhvStarDoor }) do
        if id ~= nil then
            local o = OF.util.optional("obj_get_nearest_object_with_behavior_id", nil, m.marioObj, id)
            if o ~= nil and type(o.oPosX) == "number" then
                local dx, dz = m.pos.x - o.oPosX, m.pos.z - (o.oPosZ or 0)
                if dx * dx + dz * dz <= 400 * 400 then return o end
            end
        end
    end
    return nil
end

function eject.is_door(o)
    return eject.has_bhv(o, id_bhvDoor) or eject.has_bhv(o, id_bhvDoorWarp)
        or eject.has_bhv(o, id_bhvStarDoor)
end

eject.exiting = false
function eject.instead_of_saving(m, action)
    if not eject.exiting or m == nil or m.playerIndex ~= 0 then return nil end
    if action == ACT_EXIT_AIRBORNE then return nil end
    eject.exiting = false
    if action == ACT_EXIT_LAND_SAVE_DIALOG then return ACT_IDLE end
    return nil
end
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, function(m, action)
    return eject.instead_of_saving(m, action)
end)

function eject.read(m, np)
    if m == nil or m.pos == nil then return nil end
    local level, area = np.currLevelNum, np.currAreaIndex or 1
    local action = m.action or 0
    local yaw = m.faceAngle ~= nil and (m.faceAngle.y or 0) or 0

    local floorType = m.floor ~= nil and m.floor.type or nil
    if type(floorType) == "number" then
        if floorType >= eject.PAINTING_LO and floorType <= eject.PAINTING_HI then
            return { kind = "painting", level = level, area = area,
                     x = m.pos.x, y = m.pos.y, z = m.pos.z, yaw = yaw }
        end
        if floorType == eject.WARP_FLOOR or floorType == eject.LOOK_UP_FLOOR then
            return { kind = floorType == eject.WARP_FLOOR and "hole" or "lookup",
                     level = level, area = area,
                     x = m.pos.x, y = m.pos.y, z = m.pos.z, yaw = yaw }
        end
    end

    local o = m.usedObj
    if o == nil or type(o.oPosX) ~= "number" then return nil end
    if not (eject.DOOR_ACTIONS[action] or eject.SWALLOWED[action]) then return nil end
    local dx, dz = m.pos.x - o.oPosX, m.pos.z - (o.oPosZ or 0)
    if dx * dx + dz * dz > eject.OBJ_NEAR * eject.OBJ_NEAR then return nil end
    local kind
    if eject.is_door(o) or eject.DOOR_ACTIONS[action] then
        kind = "door"
    elseif eject.has_bhv(o, id_bhvWarpPipe) then
        kind = "pipe"
    else
        kind = "warp"
    end
    return { kind = kind, level = level, area = area,
             x = o.oPosX, y = o.oPosY or m.pos.y, z = o.oPosZ or m.pos.z,
             objYaw = o.oFaceAngleYaw or o.oMoveAngleYaw or 0,
             marioX = m.pos.x, marioZ = m.pos.z, yaw = yaw }
end

function eject.note(m, np)
    local now = eject.read(m, np)
    if now ~= nil then

        if entering ~= nil and entering.kind == "painting" and now.kind ~= "painting" then
            return
        end

        if entering ~= nil and entering.kind == now.kind then
            now.fromX, now.fromZ = entering.fromX, entering.fromZ
        else
            now.fromX, now.fromZ = now.marioX or now.x, now.marioZ or now.z
        end
        entering = now
        return
    end
    if could_be_left_here(m) then entering = nil end
end

function eject.take()
    local was = entering
    entering = nil
    return was
end

function eject.forget() entering = nil end

function eject.unit(x, z)
    local len = math.sqrt(x * x + z * z)
    if len < 1 then return nil end
    return x / len, z / len
end

function eject.at_edge(place, entrance, near)
    place.x, place.y, place.z = near.x, near.y, near.z
    local ax, az = eject.unit(near.x - entrance.x, near.z - entrance.z)
    if ax ~= nil then
        place.yaw = atan2s(az, ax) % 0x10000
    else
        place.yaw = ((near.yaw or 0) + 0x8000) % 0x10000
    end
    place.how = "stand"
    return place
end

function eject.land(m, how)
    if how == "launch" and ACT_EXIT_AIRBORNE ~= nil and ACT_EXIT_LAND_SAVE_DIALOG ~= nil then

        m.faceAngle.y = ((m.faceAngle.y or 0) + 0x8000) % 0x10000
        if m.faceAngle.y >= 0x8000 then m.faceAngle.y = m.faceAngle.y - 0x10000 end
        eject.exiting = true
        set_mario_action(m, ACT_EXIT_AIRBORNE, 0)
    elseif how == "launch" then
        set_mario_action(m, ACT_FREEFALL, 0)
        m.vel.y = eject.LAUNCH_UP
        OF.util.optional("mario_set_forward_vel", nil, m, eject.LAUNCH_FORWARD)
    elseif how == "pipe" and ACT_EMERGE_FROM_PIPE ~= nil then
        set_mario_action(m, ACT_EMERGE_FROM_PIPE, 0)
    elseif how == "door" and ACT_WARP_DOOR_SPAWN ~= nil and eject.door_near(m) ~= nil
        and (not OF.util.asks(OF.warp, "door_draws_at")
            or OF.warp.door_draws_at(eject.door_near(m), m.pos.x, m.pos.y, m.pos.z)) then

        m.usedObj = eject.door_near(m)
        set_mario_action(m, ACT_WARP_DOOR_SPAWN, 1)
    else
        set_mario_action(m, ACT_IDLE, 0)
        OF.util.optional("mario_set_forward_vel", nil, m, 0)
    end
    m.skipWarpInteractionsTimer = eject.WARP_GRACE
    m.health = eject.FULL_HEALTH
    m.hurtCounter = 0
    m.healCounter = 0
end
end

modes.CASTLE_WAYS_OUT = {}
do
    local function out(from, area, to, how, spot)
        if type(from) ~= "number" or type(to) ~= "number" then return end
        table.insert(modes.CASTLE_WAYS_OUT,
            { from = from, area = area, to = to, how = how, spot = spot })
    end
    local C, G, Y = LEVEL_CASTLE, LEVEL_CASTLE_GROUNDS, LEVEL_CASTLE_COURTYARD

    out(C, 1, LEVEL_BOB, "painting")
    out(C, 1, LEVEL_CCM, "painting")
    out(C, 1, LEVEL_WF, "painting")
    out(C, 1, LEVEL_JRB, "painting")
    out(C, 1, LEVEL_PSS, "warp")
    out(C, 1, LEVEL_BITDW, "warp", { x = -4664, y = 717, z = -3475, yaw = 0x2000 })
    out(C, 1, LEVEL_SA, "warp")
    out(C, 1, LEVEL_TOTWC, "lookup")

    out(C, 2, LEVEL_WDW, "painting")
    out(C, 2, LEVEL_THI, "painting")
    out(C, 2, LEVEL_TTM, "painting")
    out(C, 2, LEVEL_TTC, "painting")
    out(C, 2, LEVEL_SL, "painting")
    out(C, 2, LEVEL_RR, "hole")
    out(C, 2, LEVEL_WMOTR, "warp")
    out(C, 2, LEVEL_BITS, "warp")

    out(C, 3, LEVEL_LLL, "painting")
    out(C, 3, LEVEL_SSL, "painting")
    out(C, 3, LEVEL_HMC, "hole")
    out(C, 3, LEVEL_DDD, "painting")
    out(C, 3, LEVEL_BITFS, "warp")

    out(G, 1, LEVEL_VCUTM, "warp")

    out(Y, 1, LEVEL_BBH, "cage")
end

function modes.castle_way_out(from, area, to)
    for _, row in ipairs(modes.CASTLE_WAYS_OUT) do
        if row.from == from and row.area == area and row.to == to then return row end
    end
    return nil
end

function modes.eject_place(entrance, spot, to)
    if type(entrance) ~= "table" or entrance.level == nil then return nil end
    local near = nil
    if spot ~= nil and spot.level == entrance.level and spot.area == entrance.area then
        near = spot
    end
    local place = { level = entrance.level, area = entrance.area, landing = true }

    local row = modes.castle_way_out(entrance.level, entrance.area, to)
    if row ~= nil and row.spot ~= nil then
        place.x, place.y, place.z = row.spot.x, row.spot.y, row.spot.z
        place.yaw = row.spot.yaw % 0x10000
        place.how = "stand"
        return place
    end

    if entrance.kind == "painting" then

        if near ~= nil and math.abs((entrance.y or 0) - near.y) > eject.HOLE_RISE then
            return eject.at_edge(place, entrance, near)
        end

        local nx, nz
        if near ~= nil then nx, nz = eject.unit(near.x - entrance.x, near.z - entrance.z) end
        if nx == nil then nx, nz = -sins(entrance.yaw or 0), -coss(entrance.yaw or 0) end
        place.x = entrance.x + nx * eject.PAINTING_OUT
        place.z = entrance.z + nz * eject.PAINTING_OUT
        place.y = entrance.y
        place.yaw = atan2s(nz, nx) % 0x10000
        place.how = "launch"
        return place
    end

    if entrance.kind == "door" then

        local yaw = entrance.objYaw or 0
        local nx, nz = sins(yaw), coss(yaw)
        local fx, fz = entrance.fromX, entrance.fromZ
        if near ~= nil then fx, fz = near.x, near.z end
        local side = 1
        if fx ~= nil and fz ~= nil
            and ((fx - entrance.x) * nx + (fz - entrance.z) * nz) < 0 then
            side = -1
        end
        nx, nz = nx * side, nz * side
        place.x = entrance.x + nx * eject.DOOR_OUT
        place.z = entrance.z + nz * eject.DOOR_OUT
        place.y = near ~= nil and near.y or entrance.y
        place.yaw = atan2s(nz, nx) % 0x10000
        place.how = "door"
        return place
    end

    if entrance.kind == "pipe" then

        place.x, place.y, place.z = entrance.x, entrance.y, entrance.z
        place.yaw = (entrance.yaw or 0) % 0x10000
        place.how = "pipe"
        return place
    end

    if near == nil then return nil end
    return eject.at_edge(place, entrance, near)
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

        if returnTo.landing and not returnTo.landed then return false end
        local want = returnTo
        returnTo = nil
        eject.forget()
        if want.level ~= nil and np.currLevelNum ~= want.level then return true end
        if want.landing and np.currAreaIndex == want.area
            and OF.util.asks(OF.doorways, "put_at") then

            local yaw = want.yaw or 0
            if yaw >= 0x8000 then yaw = yaw - 0x10000 end
            m.faceAngle.y = yaw
            OF.doorways.put_at(m, want.x, want.y, want.z)
            eject.land(m, want.how)
            eject.landedAt = OF.util.optional("get_global_timer", 0) or 0
            if m.marioObj.header ~= nil and m.marioObj.header.gfx ~= nil
                and m.marioObj.header.gfx.angle ~= nil then
                m.marioObj.header.gfx.angle.y = yaw
            end
            return true
        end
        if np.currAreaIndex == want.area
            and OF.util.asks(OF.doorways, "put_at") then

            OF.doorways.put_at(m, want.x, want.y, want.z)
            if want.yaw ~= nil and m.faceAngle ~= nil then
                local yaw = want.yaw
                if yaw >= 0x8000 then yaw = yaw - 0x10000 end
                m.faceAngle.y = yaw
                if m.marioObj ~= nil and m.marioObj.header ~= nil
                    and m.marioObj.header.gfx ~= nil and m.marioObj.header.gfx.angle ~= nil then
                    m.marioObj.header.gfx.angle.y = yaw
                end
            end
        end
        return true
    end

    eject.note(m, np)
    if not could_be_left_here(m) then return false end

    if diedInside then modes.note_respawn() end
    diedInside = false
    diedAt = nil

    stoodAt = {
        level = np.currLevelNum, area = np.currAreaIndex,
        x = m.pos.x, y = m.pos.y, z = m.pos.z,
        yaw = m.faceAngle ~= nil and ((m.faceAngle.y or 0) % 0x10000) or nil,
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

modes.INTERIORS = {}
do
    local function interior(level, area, how)
        if type(level) ~= "number" then return end
        modes.INTERIORS[level] = modes.INTERIORS[level] or {}
        modes.INTERIORS[level][area] = how or true
    end
    interior(LEVEL_JRB, 2)
    interior(LEVEL_SSL, 2)
    interior(LEVEL_SL, 2)
    interior(LEVEL_THI, 3, "door")
    interior(LEVEL_LLL, 2)
end

function modes.interior_by_door(level, area)
    local rooms = modes.INTERIORS[level or -1]
    return rooms ~= nil and rooms[area or 1] == "door"
end

function modes.leaves_interior(level, area)
    local held = modes.roundLevel
    if held == nil or level ~= held.level then return false end
    local rooms = modes.INTERIORS[held.level]
    if rooms == nil or rooms[held.area or 1] == nil then return false end
    if modes.one_space(held.level) then return false end
    return area ~= nil and area ~= (held.area or 1)
end

function modes.one_space(level)
    if level == nil then return false end
    local now = modes.current()
    return now ~= nil and type(now.oneSpace) == "table"
        and now.oneSpace[level] == true
end

function modes.owe_passage(area, spot)
    if modes.roundLevel == nil or area == nil then return false end
    throwBack = area
    throwBackLevel = nil
    returnTo = spot ~= nil and {
        area = area, x = spot.x, y = spot.y, z = spot.z,
    } or nil
    return true
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
    throwBackLevel = nil
    eject.forget()
    eject.landedAt = nil
end

function modes.holding()
    return modes.roundLevel
end

hook_event(HOOK_ON_WARP, function(warpType, levelNum, areaIdx, nodeId, warpArg)
    local held = modes.roundLevel
    if held == nil then return end

    if returnTo ~= nil and returnTo.warped and modes.holds_level(levelNum) then
        returnTo.landed = true
    end
    if modes.may_leave_level() then return end

    if modes.leaves_interior(levelNum, areaIdx) then
        OF.notify.show("You are in a round - back you go.", "warn", 4)
        if not diedInside then escapes = escapes + 1 end
        settledFor = 0
        local spot = modes.return_spot(held.level)
        returnTo = (spot ~= nil and spot.area == held.area) and {
            area = spot.area, x = spot.x, y = spot.y, z = spot.z,
        } or nil

        if modes.interior_by_door(held.level, held.area) then returnTo = nil end
        throwBack = held.area
        throwBackLevel = nil
        return
    end
    if modes.holds_level(levelNum) then return end

    OF.notify.show("You are in a round - back you go.", "warn", 4)

    local entrance = eject.take()
    if entrance ~= nil and eject.landedAt ~= nil
        and (OF.util.optional("get_global_timer", 0) or 0) - eject.landedAt > eject.LOOP_FRAMES then
        escapes = 0
    end
    if not diedInside then escapes = escapes + 1 end
    settledFor = 0

    if not diedInside and entrance ~= nil and escapes <= ESCAPES_BEFORE_GIVING_UP then
        local place = modes.eject_place(entrance, stoodAt, levelNum)
        if place ~= nil and modes.holds_level(place.level) then
            returnTo = place
            throwBack = place.area
            throwBackLevel = place.level
            return
        end
    end

    local spot = modes.return_spot(held.level)

    if spot == nil and not diedInside and stoodAt ~= nil
        and stoodAt.level ~= held.level and modes.holds_level(stoodAt.level)
        and escapes <= ESCAPES_BEFORE_GIVING_UP then
        returnTo = {
            level = stoodAt.level, area = stoodAt.area, landing = true, how = "stand",
            x = stoodAt.x, y = stoodAt.y, z = stoodAt.z,
            yaw = ((stoodAt.yaw or 0) + 0x8000) % 0x10000,
        }
        throwBack = stoodAt.area
        throwBackLevel = stoodAt.level
        return
    end
    returnTo = spot and {
        area = spot.area, x = spot.x, y = spot.y, z = spot.z,
        yaw = spot.yaw ~= nil and ((spot.yaw + 0x8000) % 0x10000) or nil,
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
    OF.notify.show("Type /sitout to sit rounds out, then leave.",
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
    local nowhere = modes.nowhere_to_play(mode.key)
    if nowhere ~= nil then return false, nowhere end
    return true
end

function modes.can_open_here(mode)
    if mode == nil then return false, "No such game mode." end

    local busy = modes.start_busy(0)
    if busy ~= nil then return false, busy end
    if #modes.participants() < 1 then
        return false, OF.lang.fill("needs @ players", mode.minPlayers or 2)
    end
    if mode.playable_here ~= nil then
        local able, why = mode.playable_here()
        if not able then return false, why or OF.lang.t("not here") end
    end
    local nowhere = modes.nowhere_to_play(mode.key)
    if nowhere ~= nil then return false, nowhere end
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
        "what this round is, and the press that starts it") }

    local sides = OF.util.asks(OF.teams, "in_play") and OF.teams.in_play()
    local blurb = (sides and mode.blurbTeams) or mode.blurb
    if blurb ~= nil and blurb ~= "" then
        table.insert(rows, panel.label_row(OF.lang.t(blurb)))
    end

    local startAt = #rows + 1

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("Maps")),
        "the arena or the level this one runs in"))

    if modes.owns_its_place(mode) and modes.place_option(mode) ~= nil then
        local choice = modes.option_choice(key, mode.placeOption)

        local placeHelp = modes.place_option(mode).help
        if type(placeHelp) ~= "string" or placeHelp == "" then placeHelp = "where this one is played" end
        table.insert(rows, panel.with_key(panel.with_help(panel.with_right(
            panel.gated_row("speedrun", OF.lang.t("Pick where..."),
                255, 255, 255, function()
                    modes.placeDoor = "gamemode"
                    panel.go("playin")
                end),
            OF.lang.t(choice ~= nil and choice.name or "")),
            placeHelp), "gamemode:where"))
    elseif modes.owns_its_place(mode) then
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

    if not modes.owns_its_place(mode) or type(mode.votePlaces) == "function" then

        table.insert(rows, panel.with_key(panel.with_help(
            panel.host_row("speedrun",
            panel.tick(OF.util.asks(OF.mapvote, "wanted")
                and OF.mapvote.wanted(key) or false,
                OF.lang.t("Vote for the map")),
            255, 220, 120, function()
                if not OF.util.asks(OF.mapvote, "set_wanted") then return end

                local ok, why, feature = OF.mapvote.set_wanted(key,
                    not OF.mapvote.wanted(key))
                OF.util.report(ok, why, feature)
            end, panel.ask_host(modes.MAPVOTE_ACTION, key)),
            "the lobby jumps into one of three paintings to choose"),
            "gamemode:mapvote"))
    end

    local settings = {}

    local sidesFact = nil
    if mode.teams then
        local minRoom = OF.util.asks(OF.teams, "min_room")
            and OF.teams.min_room(mode) or 4
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
                end, panel.ask_host(modes.SIDES_ACTION)),

                OF.lang.fill("with sides: @", modes.sides_effect(mode))),
                "gamemode:sides"))
        end
    else
        sidesFact = OF.lang.t("No sides - everybody for themselves")
    end

    if type(mode.presets) == "table" and #mode.presets > 0 then
        local now = modes.preset_now(key)
        table.insert(settings, panel.with_key(panel.with_help(panel.with_right(
            panel.gated_row("speedrun", OF.lang.t("Play it as"),
                255, 220, 120, function()
                    local ok, why, feature = modes.step_preset(key)
                    OF.util.report(ok, why, feature)
                end),
            now ~= nil and OF.lang.t(now.name) or OF.lang.t("custom")),
            OF.lang.t(now ~= nil and now.help or "a named way to play it - each press sets its rows")),
            "gamemode:preset"))
    end

    if mode.target ~= nil and modes.target_shown(mode) then
        table.insert(settings, panel.with_key(panel.with_help(panel.with_right(
            panel.gated_row("speedrun", modes.target_asks(mode),
                255, 220, 120, function()
                    modes.step_target(key)
                end),
            modes.target_text(mode)),
            modes.target_help(mode)),
            "gamemode:target"))
    end

    if modes.tie_row_shown(mode) then
        table.insert(settings, panel.with_key(panel.with_help(panel.with_right(
            panel.host_row("speedrun", OF.lang.t("A tied round"),
            255, 220, 120, function()
                OF.util.report(modes.set_tiebreak(not modes.tiebreak_on(key), key))
            end, panel.ask_host(modes.TIEBREAK_ACTION, key)),
            modes.tiebreak_on(key) and OF.lang.t("settled")
                or OF.lang.t("left as a draw")),
            "time in front, then who got in front first - a draw when "
                .. "both are level"),
            "gamemode:tiebreak"))
    end

    local options = modes.options_of(mode)

    local mine = type(mode.build_rows) == "function" and mode.build_rows(panel) or {}
    for _, option in ipairs(options) do
        local optKey = option.key
        local choice = modes.option_choice(key, optKey)

        if optKey ~= mode.placeOption and modes.option_shown(mode, option) then
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

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("The session's board")),
        "who is winning this one so far, and how much of it the lobby has played"))

    local board = OF.util.asks(OF.stats, "mode_board")
        and OF.stats.mode_board(key) or nil

    if board == nil then

        table.insert(rows, panel.label_row(
            OF.lang.t("The host keeps this board - ask them.")))
    elseif #board == 0 then

        table.insert(rows, panel.label_row(
            OF.lang.fill("No rounds of @ have been played this session.",
                OF.lang.t(mode.name))))
        table.insert(rows, panel.label_row(
            OF.lang.t("The board fills as the lobby plays it.")))
    else
        local shown = 0
        for place, entry in ipairs(board) do
            if place > OF.stats.MODE_BOARD_ROWS then break end
            shown = place

            table.insert(rows, panel.with_right(
                panel.label_row(tostring(place) .. ". "
                    .. tostring(entry.name or "")),
                OF.lang.fill("@ win(s) in @ round(s)",
                    entry.wins, entry.rounds)))
        end

        if #board > shown then
            table.insert(rows, panel.label_row(OF.lang.fill(
                "And @ more have played it this session.",
                tostring(#board - shown))))
        end
    end

    local plays = {}
    if mode.how ~= nil and mode.how ~= "" then
        for line in string.gmatch(mode.how, "[^\n]+") do
            table.insert(plays, panel.label_row(OF.input.button_text(OF.lang.t(line))))
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

    local caps = modes.caps(mode)
    if caps.overtime then
        table.insert(plays, panel.label_row(
            OF.lang.t("Runs overtime while the side behind can still score")))
    end

    if not caps.tiebreak and mode.resultsBy == "splits" then
        table.insert(plays, panel.label_row(
            OF.lang.t("A race - the clock decides it, never a draw")))
    end

    table.insert(rows, panel.with_help(
        panel.header_row(OF.lang.t("How it plays")),
        "what this mode does, in the words its own author wrote"))
    for _, built in ipairs(plays) do
        table.insert(rows, built)
    end

    local able, why = modes.can_open_here(mode)
    if not able then

        local cannot = panel.label_row(short_reason(why))
        cannot.walk = true
        table.insert(rows, panel.rest_row(panel.with_help(cannot,
            "cannot start as the lobby stands - the reason is on the row")))
    else

        table.insert(rows, panel.rest_row(panel.with_help(panel.with_tone(panel.gated_row("speedrun",
            OF.lang.fill("Start @", OF.lang.t(mode.name)),
            140, 255, 160, function()

                if OF.util.report(modes.start(key, nil, 0)) then panel.close() end
            end), "go"),
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

    local placeOption = mode ~= nil and modes.place_option(mode) or nil
    if placeOption ~= nil then
        table.insert(rows, panel.header_row(OF.lang.fill("@ is played in",
            OF.lang.t(mode.name))))
        local picked = modes.option_pick(key, placeOption.key)
        for _, choice in ipairs(placeOption.choices) do
            local on = choice.key == picked
            table.insert(rows, panel.with_key(panel.with_help(
                panel.gated_row("speedrun", panel.tick(on, OF.lang.t(choice.name)),
                    255, 255, 255, function()
                        local ok, why, feature = modes.set_option(key,
                            placeOption.key, choice.key)
                        OF.util.report(ok, why, feature)
                        panel.go(modes.placeDoor)
                    end), OF.lang.t(choice.help or "")),
                "placeopt:" .. placeOption.key .. ":" .. choice.key))
        end
        table.insert(rows, panel.back_row())
        return rows
    end
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
            and modes.levelChoice.track == tonumber(entry.track)
        local built = panel.with_key(panel.with_help(
            panel.gated_row("warp_lobby",
                panel.tick(on, entry.name), 255, 255, 255, function()
                    if on then
                        modes.set_level(nil)
                    else
                        modes.set_level(entry)
                    end
                    panel.go(modes.placeDoor)
                end), why), "playin:lv" .. tostring(entry.level)
                    .. "a" .. tostring(entry.area or 1)
                    .. (entry.track ~= nil and ("t" .. tostring(entry.track)) or ""))

        built.mapCard = { name = entry.name, level = entry.level, area = entry.area, on = on }
        return built
    end

    local function wide_rows()
        local players = modes.open_players()
        table.insert(rows, panel.header_row(OF.lang.t(
            "Courses big enough for everybody here")))
        local why = OF.lang.t(
            "a course whose own ground holds everybody here, a place each")
        for _, entry in ipairs(modes.open_levels(players, key)) do
            table.insert(rows, level_row(entry, why))
        end

        local held = modes.levelChoice
        if held ~= nil and modes.open_pick_outgrown(key, held) then
            table.insert(rows, level_row(held, OF.lang.t(
                "picked before more joined - small for everybody, still a place each")))
        end
    end
    local wideUnderDoor = modes.plays_open(key) and modes.takes_any_level(key)
    if modes.plays_open(key) and not wideUnderDoor then
        wide_rows()
    elseif kind == "surveyed" then
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
                for _, entry in ipairs(modes.course_levels(key)) do
                    if entry.level == held.level
                        and (entry.area or 1) == (held.area or 1) then
                        drawn = true
                    end
                end
            end
            if wideUnderDoor then
                for _, entry in ipairs(modes.open_levels(nil, key)) do
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

    if wideUnderDoor then wide_rows() end
    if modes.takes_main_courses(key) then
        local courses = modes.course_levels(key)
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

    if mode ~= nil and type(mode.roomsNote) == "string"
        and mode.roomsNote ~= "" then
        table.insert(rows, panel.label_row(OF.lang.t(mode.roomsNote)))
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
            local built = panel.with_key(panel.with_help(
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
                why), "playin:" .. placeKey)

            built.mapCard = { name = place.name, level = place.level, area = place.area, on = on }
            table.insert(rows, built)
        end
    end

    local forged = modes.forge_track_levels(key)
    if #forged > 0 then
        table.insert(rows, panel.header_row(OF.lang.t("Forge tracks")))
        local why = OF.lang.t("a track built in the Forge, kept with this level's build")
        for _, entry in ipairs(forged) do
            local best = OF.util.asks(OF.forge, "racer_best")
                and OF.forge.racer_best(OF.forge.racer_best_key(entry.forgeTrack, entry.track)) or nil
            local row = level_row(entry, why)
            if best ~= nil then
                row = panel.with_right(row, OF.lang.fill("best @",
                    OF.forge.racer_best_text(best)))
            end
            table.insert(rows, row)
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
    snd = { join = "play",
        why = "A latecomer joins the thinner side and watches until the next "
           .. "round deals them in - nobody arrives in the middle of a round." },
    firesweep = { join = "play",
        why = "A latecomer starts on nought stars like a player just hit "
           .. "twice, and nothing in the ring has grown for anybody else." },

    oneflag = { join = "play",
        why = "Put on the thinner side first; nobody carries anything at the "
           .. "start, so an arrival is as far from scoring as everybody else." },

    rabbitchase = { join = "play",
        why = "A latecomer chases from nought - the ledger's entry for their "
           .. "seat starts at nought, never at the last occupant's catches." },
    bombsort = { join = "play",
        why = "A latecomer sorts from nought - the ledger's entry for their "
           .. "seat starts at nought." },
    onoffclimb = { join = "play",
        why = "A latecomer climbs from the floor - their row starts at step "
           .. "nought, and the switch is theirs like everybody's." },
    lakitu = { join = "play",
        why = "A latecomer runs from nought points - the ledger's entry for "
           .. "their seat starts at nought - and may take the cloud like anybody." },
    flyguy = { join = "play",
        why = "A latecomer bounces from nought with three falls - the "
           .. "ledger's entry for their seat starts at nought." },
    megarampage = { join = "play",
        why = "A latecomer runs from nought and joins the turns still to come "
           .. "- the ledger's entry for their seat starts at nought." },

    bank = { join = "play",
        why = "The coins are spread over the room and the bank is where the "
           .. "round left it, so an arrival starts on nought like everybody "
           .. "did and has less time to spend it in." },
    bossrush = { join = "play",
        why = "A latecomer is put on the stage the round has reached, in a "
           .. "copy of it that is theirs alone, and every boss they did not "
           .. "fight is a split they will never have." },
    shooter = { join = "play",
        why = "The score is kills and everybody respawns anyway, so a "
           .. "latecomer walks into the same round everybody else is in - "
           .. "behind on the count and with every minute left to spend." },
    bounty = { join = "play",
        why = "Everybody respawns and the score is the side's confirms, so a "
           .. "latecomer joins the thinner side and walks into the same fight "
           .. "- nothing banked to arrive in front of." },
    coinrush = { join = "play",
        why = "The rain falls for everybody and the tally starts at nought on "
           .. "the machine that arrived, so a late start is a shorter round "
           .. "rather than a better one." },
    crown = { join = "play",
        why = "They arrive as a hunter with no crown, which is the side of "
           .. "this round that is behind by definition." },
    football = { join = "play",
        why = "The score is the side's and the ball is published, so an "
           .. "arrival is one more player on the thinner side from their "
           .. "first frame - nothing is theirs to catch up on." },
    volleyball = { join = "play",
        why = "The score is the side's and the ball is published, so an "
           .. "arrival is one more player on the thinner side from their "
           .. "first frame - Football's reason." },
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
    glassbridge = { join = "watch",
        why = "The queue was dealt when the round went live and the glass behind "
           .. "the leader is already known, so an arrival would be dropped at "
           .. "the back of a line with nothing left to learn. They watch this "
           .. "one and step first in a later one." },
    hideseek = { join = "play",
        why = "They arrive as a seeker, and a seeker who has not been looking "
           .. "is the side of this round with the least in hand." },
    hotpotato = { join = "watch",
        why = "Out is out here, and the fuse is on whoever is nearest when it "
           .. "runs down. Somebody who walks in at four seconds has dodged the "
           .. "whole round without dodging anything." },
    koth = { join = "watch",
        why = "A latecomer became a new player of a "
           .. "round that was down to one against one and kept it from "
           .. "ending without ever reaching the hill. They watch this one." },
    oitc = { join = "play",
        why = "They arrive alive on the one round everybody starts with." },
    rocketarena = { join = "play",
        why = "The score is kills and everybody respawns - Deathmatch's reason." },
    blastgrid = { join = "watch",
        why = "Every start cell was dealt at the opening and the field is "
           .. "built round them; an arrival has no cell and has outlasted no "
           .. "blast." },
    shellbattle = { join = "play",
        why = "Points and a respawn, so an arrival starts on nought with a "
           .. "full set of balloons - a Lakitu drops them on the point "
           .. "furthest from everybody, and nobody is a lap behind in a "
           .. "battle." },
    silverfive = { join = "play",
        why = "A latecomer gets five silver stars of their own and starts on "
           .. "nought gold - nobody else's race is touched." },
    wanted = { join = "play",
        why = "A latecomer hunts the next name and joins the poster's "
           .. "rotation, having been wanted the least." },
    copsandrobbers = { join = "play",
        why = "Arrives a robber; the dealt cops stay exactly as dealt." },
    assassins = { join = "play",
        why = "A late arrival is spliced into an edge of the ring and both "
           .. "neighbours are re-dealt the same instant." },
    greendemon = { join = "watch",
        why = "The 1-UPs are already loose and a pack may have grown. "
           .. "Somebody walking in fresh with none of them after them is "
           .. "the round handed to whoever joined last." },
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
        why = "They arrive as a Hunter, never as the Runner, and the Runner's "
           .. "head start has already been spent." },
    murder = { join = "play",
        why = "They arrive innocent and are told nothing, which is what every "
           .. "innocent is told - and one more person to read is the mode "
           .. "getting harder for the murderer rather than easier." },
    downhill = { join = "play",
        why = "Every rider's coins are their own and each run is timed on its own; "
           .. "an arrival starts at the top and simply has fewer runs left." },
    shellrace = { join = "watch",
        why = "A race has a grid. Somebody who walks in mid-race would start "
           .. "a lap behind for ever and in everybody's way, so they watch - "
           .. "ghosted, free to look round - and the next race deals them in." },

    booksquirm = { join = "watch",
        why = "A box that holds sixteen and a row that lands every couple of "
           .. "seconds. Somebody who walks in halfway is standing wherever "
           .. "they were put with a row already on its way down, which is an "
           .. "arrival put out by the first thing that happens to them." },
    frenzy = { join = "play",
        why = "Dealt in by the mode itself: in a points round they play from "
           .. "the next word with nothing, which is the honest penalty; in a "
           .. "round with lives they come in as a ghost and play for fun, "
           .. "because four lives against somebody's two is not a fair seat." },
    simon = { join = "play",
        why = "Every call is judged fresh against the whole lobby, so the call "
           .. "after they arrive is the first one they can fail and the ones "
           .. "before it are already counted against everybody else." },
    spots = { join = "watch",
        why = "The number of circles was laid against the number of players at "
           .. "the start. One more body chasing the same circles changes who "
           .. "goes out, for everybody who was already here." },
    smash = { join = "play",
        why = "A latecomer arrives on nought percent, which in this round is "
           .. "the strongest anybody ever is - there is no banked score to "
           .. "walk in front of, only fewer seconds to use it in. On stocks "
           .. "they are dealt the round's own number, so they arrive behind on "
           .. "time and level on lives." },
    sumo = { join = "watch",
        why = "The ring is pinned where the round started and out is out. A "
           .. "body that arrives inside it can shove a survivor over the edge "
           .. "without ever having survived anything itself." },
    zombies = { join = "play",
        why = "They arrive infected, for the reason the mode's own file gives: "
           .. "a stream of clean arrivals would keep alive a round that cannot "
           .. "end while one survivor is left." },

    bumperballs = { join = "watch",
        why = "The island narrows all round and there is no way back off the "
           .. "shore. A body dropped onto what is left of it can shove a "
           .. "survivor into the sea without ever having survived anything "
           .. "itself, which is Sumo's objection on a smaller island." },
    bombxing = { join = "watch",
        why = "The number of Bob-ombs grows with the clock, and everybody "
           .. "still up has outlasted every one so far. An arrival has "
           .. "outlasted none of them." },
    blizzard = { join = "watch",
        why = "The throw rate follows the players still up, and everybody "
           .. "still up has dodged every throw so far. An arrival has dodged "
           .. "none of it." },
    bombsaway = { join = "watch",
        why = "The island never narrows here, so the arrival's own chances are "
           .. "not the objection - the shelling is. Every player still "
           .. "standing has spent the whole round under the same fall rate, "
           .. "and somebody who walks in at ten seconds has dodged all of it "
           .. "without dodging anything." },
    deflect = { join = "watch",
        why = "The flame only gets faster, and everybody still up has earned "
           .. "the speed it is at by parrying their way to it. An arrival "
           .. "dropped in could be chosen on their first frame by a flame "
           .. "already past anything they have seen." },
    chompfever = { join = "watch",
        why = "The platform narrows as the round runs and again each time "
           .. "somebody goes out, and the Chomps do not thin with it. An "
           .. "arrival is put down on whatever floor is left, among a hazard "
           .. "that has been getting closer for minutes, which is a fall with "
           .. "their name on it rather than a late start." },
    lavaleave = { join = "watch",
        why = "The fireballs split and never stop splitting, so the round only "
           .. "ever gets more crowded. Somebody dropped onto the rock late is "
           .. "dropped into the worst of it with no idea which way anything is "
           .. "moving, and the survivors earned that crowd by outlasting the "
           .. "quiet half nobody can join for." },

    hotrope = { join = "watch",
        why = "The rope never stops climbing, so every player still up has "
           .. "answered a slower rope than the next turn will be. Somebody "
           .. "dropped onto the floor late is handed the fastest rope in the "
           .. "round with no sight of how it got there, and the survivors "
           .. "earned it by riding the slow half nobody can join for." },

    blast = { join = "watch",
        why = "The draw is one position in a turn order of however many are "
           .. "still in, so every player left has already survived a longer "
           .. "row than the next one will be. An arrival dealt into a short "
           .. "row is handed the best odds in the match for having missed it, "
           .. "and the cycle they walked into was dealt without them." },
    prophunt = { join = "play",
        why = "They arrive as a seeker and never as a prop, which is "
           .. "`hunt.late_join`'s own judgement rather than this mode's - a "
           .. "joiner handed a disguise would be handed one in a round whose "
           .. "hiding is already over. A seeker who has not been looking is "
           .. "the side of this round with the least in hand." },

    hideballoon = { join = "play",
        why = "A latecomer gets the same auto-lock everybody else gets at "
           .. "the hide deadline - a balloon at wherever they land - and "
           .. "full hunting rights for whatever is left of the clock." },
    sardines = { join = "play",
        why = "They arrive seeking - the hider was dealt before they could "
           .. "know where to run, so a latecomer is exactly the side of "
           .. "this round with the least in hand. Hide and Seek's own row, "
           .. "same reason." },
    turf = { join = "play",
        why = "The tiles are held rather than won, so an arrival owns none of "
           .. "them and the board is published, so their first frame draws the "
           .. "same grid as everyone else's - Domination's own reason for the "
           .. "same shape." },
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
    snd = { out = "ghost",
        why = "A death is out until the next round: a ghost who watches his "
           .. "own side and comes back with everybody at the next count." },
    firesweep = { out = "none",
        why = "Nobody is put out: a row stuns you and costs three stars." },

    oneflag = { out = "none",
        why = "A death drops the flag where you stood; both sides keep every "
           .. "player they started with." },

    rabbitchase = { out = "none",
        why = "A catch is a point and a punch drops a penguin - nobody is ever "
           .. "put out of Rabbit Chase." },
    bombsort = { out = "none",
        why = "A blast throws you back and a wrong pen costs a point - nobody "
           .. "is ever put out of Bomb Sort." },
    onoffclimb = { out = "none",
        why = "Nobody is put out of Spiral to the Star: a fall is a walk back to the "
           .. "bottom of the spiral." },
    lakitu = { out = "none",
        why = "Nobody is put out of Lakitu's Cloud: a Spiny throws you back and "
           .. "pays the thrower, and the cloud only ever changes hands." },
    flyguy = { out = "ghost",
        why = "Three falls and you are out: the framework's ghost, free to "
           .. "watch the trampoline - your stomps still count at the clock." },
    megarampage = { out = "none",
        why = "Flattened is a point to the giant and a few seconds as a "
           .. "pancake - nobody is ever put out of Mega Rampage." },

    bank = { out = "none",
        why = "Nobody is out of a collecting round. A death is a walk back to "
           .. "the coins, and the bank is where it always was." },
    bossrush = { out = "none",
        why = "A runner who cannot beat a boss is conceded the stage and moved "
           .. "to the next one - the course would rather carry everybody than "
           .. "leave anybody behind it." },
    shooter = { out = "none",
        why = "A death is a respawn rather than an exit - the bubble is held "
           .. "off and the round puts you back, so there is no state to be in "
           .. "but playing." },
    bounty = { out = "none",
        why = "A death is a respawn rather than an exit: it drops a tag and "
           .. "puts you back at your side's point, so there is no state to be "
           .. "in but playing." },
    coinrush = { out = "none",
        why = "The rain falls on everybody until the clock runs out. A round "
           .. "nobody can lose has nobody to put out." },
    crown = { out = "none",
        why = "Losing the crown is losing a lead, not losing the round: the "
           .. "player it was punched off is a hunter again a frame later. "
           .. "With the knockout on, a cut player floats as a ghost." },
    football = { out = "none",
        why = "Nobody can hit anybody and a death is a walk back from your "
           .. "own half, so nobody is ever out of a match." },
    volleyball = { out = "none",
        why = "Nobody can hit anybody and nobody can fall off a court: a "
           .. "point lost is the side's, never a player's." },
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
    glassbridge = { out = "watch",
        why = "The out player is set down on the floor under the glass, and "
           .. "the seat is the spectator camera. Not a ghost: a ghost that "
           .. "could reach the bridge would walk the good panes ahead of the "
           .. "people still choosing, and the glass is made of not knowing." },
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
    smash = { out = "ghost",
        why = "Stocks spent is the earliest anybody goes out here and the round "
           .. "can run for minutes after it. The fists are off for a ghost in "
           .. "both directions, which is the whole of what being out has to "
           .. "mean in a round decided by hitting people - and the mode puts "
           .. "them in the spectator seat besides, so watching the finish is "
           .. "the default rather than a row somebody has to find." },
    oitc = { out = "ghost",
        why = "Lives run out and you watch the rest - Last One Standing's "
           .. "seat on D-pad left." },
    rocketarena = { out = "none",
        why = "A death is a respawn, never an exit - Deathmatch's answer." },
    blastgrid = { out = "ghost",
        why = "Out players take turns on the wall, four at a time, throwing "
           .. "Bob-ombs in (the series' revenge); the rest are ghosts waiting "
           .. "their turn, free to move and unable to block a corridor." },
    shellbattle = { out = "ghost",
        why = "Nobody is out on the default rule - an emptied rider loses "
           .. "half their points and comes back. With \"When you run out\" "
           .. "set to out, the out ride on as Bob-omb ghosts: a body that "
           .. "cannot be hurt and is free to move, and the mode lets one "
           .. "touch pop a living rider's balloon (MK64's rule)." },
    silverfive = { out = "none",
        why = "A race nobody is put out of: a fall costs the run back, never "
           .. "a seat." },
    wanted = { out = "none",
        why = "A punch is a point to the puncher, never a seat - nobody is "
           .. "ever put out of Wanted!." },
    copsandrobbers = { out = "none",
        why = "A held robber is in the cell, still in the round - the cell "
           .. "is the mode's own thing, not the framework's out seat." },
    assassins = { out = "ghost",
        why = "Out is the earliest anybody goes and the ring plays on for "
           .. "minutes - Last One Standing's shape." },
    greendemon = { out = "ghost",
        why = "Caught is the earliest anybody goes out and the chase can "
           .. "run for minutes after it. A ghost cannot be caught and "
           .. "cannot block anybody, so what is left is to watch." },
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
        why = "The Runner being tagged is the ending and a death is only a "
           .. "respawn. A Hunter is never out, and a hunt whose Runner leaves "
           .. "is abandoned rather than survived." },
    murder = { out = "watch",
        why = "The dead are muted because this round is made of who knows "
           .. "what, and a body that can walk is the same channel with no words "
           .. "in it - a ghost standing next to the murderer says it just as "
           .. "clearly. So the framework guarantees nothing here and the mode "
           .. "keeps the decision about what a dead innocent is allowed to be." },
    downhill = { out = "none",
        why = "Nobody is put out: a crash costs a combo and a fall comes back at "
           .. "the top, so coins are the only thing anybody can lose." },
    shellrace = { out = "none",
        why = "Nobody is ever put out: a hit costs speed and coins and a fall "
           .. "is a Lakitu back onto the road, so the race is the only thing "
           .. "anybody can lose." },

    booksquirm = { out = "ghost",
        why = "You misread one square and the rest of them are still reading "
           .. "the same rows. Watching somebody find the cell that caught you "
           .. "is most of what is left of the round, and it is better watched "
           .. "from beside them than from a camera." },
    frenzy = { out = "ghost",
        why = "Out of lives and the games keep coming - and with ghost play "
           .. "on, they keep coming to you too, drawn grey and counted for "
           .. "nothing. A body among the others is what that needs." },
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

    bumperballs = { out = "ghost",
        why = "In the sea, and the round above the water goes on for minutes. "
           .. "A ghost cannot push or be pushed - the ghost pair is what "
           .. "`resolve_player_collision` refuses - so the island is safe from "
           .. "them and they get to walk the shore they were knocked off, "
           .. "which is the best seat there is on a round about an edge." },
    bombxing = { out = "ghost",
        why = "A chaser picks the nearest player still up, so a body left "
           .. "standing would draw nothing and shelter nobody. A ghost watches "
           .. "the rest dodge." },
    blizzard = { out = "ghost",
        why = "A hit player is out of the throwers' picks at once, and a body "
           .. "standing about would be a decoy the snowballs never aim at - "
           .. "the round writes interactions to none anyway. A ghost watches "
           .. "the rest dodge." },
    bombsaway = { out = "ghost",
        why = "The island never narrows, so being out here lasts the longest "
           .. "of the four. Nothing a body could do from the water reaches the "
           .. "people still on the island - the round writes interactions to "
           .. "none anyway - and watching the shelling from under it is a "
           .. "better view of this round than a camera above it." },
    deflect = { out = "ghost",
        why = "Taken by the flame, and it carries on after whoever is left. "
           .. "A ghost is never chosen and cannot stand between the flame and "
           .. "anybody, so walking the arena costs the round nothing and is "
           .. "the closest seat there is to the next parry." },
    chompfever = { out = "ghost",
        why = "Touched the Chomp or stepped off, and the platform carries on "
           .. "narrowing for whoever is left. A ghost cannot be charged at and "
           .. "cannot stand in the way of a charge, so walking the lava "
           .. "underneath costs the round nothing and is where the whole of it "
           .. "is visible at once." },
    lavaleave = { out = "ghost",
        why = "Off the rock, and the fireballs go on splitting above it for as "
           .. "long as anybody is still up there. A ghost is not something a "
           .. "fireball can be steered into and is not something anybody can "
           .. "be steered into, which is the whole of what being out has to "
           .. "mean in a round where the hazard is the only thing moving." },

    hotrope = { out = "ghost",
        why = "Missed the jump, and the rope goes on turning for whoever is "
           .. "left. A ghost is not something a rope can be steered into and "
           .. "is not something anybody can be steered into, which is the "
           .. "whole of what being out has to mean in a round where one "
           .. "hazard reaches everybody in turn." },

    blast = { out = "ghost",
        why = "Found the live detonator, and the row goes round without you "
           .. "for as many cycles as there are players left - which is most of "
           .. "the match for the first one out. There is nothing a ghost "
           .. "cannot do here that a body could, because the round is a press "
           .. "rather than a place, so the body is purely the way back into "
           .. "the lobby while it finishes." },
    prophunt = { out = "watch",
        why = "Only under the stop that puts a found prop out at all, and the "
           .. "framework guarantees no body for it: a prop that has been found "
           .. "and can still walk is a walk to wherever the next one is "
           .. "standing, with a seeker only having to follow. This round is "
           .. "made of information, so what a found hider keeps is left to the "
           .. "hunt that dealt the roles." },

    hideballoon = { out = "none",
        why = "Nobody is ever eliminated - finding balloons is the whole "
           .. "round, for everybody, the whole time." },
    sardines = { out = "none",
        why = "Being found is joining the tin, not leaving the round - you "
           .. "keep your body and wait it out, silently, still part of it. "
           .. "The only player the round ever calls done is the clock's "
           .. "own loser, and the round ends there rather than benching "
           .. "them." },
    turf = { out = "none",
        why = "The tiles are held rather than won and a death only takes you "
           .. "off the floor for a walk back, so nobody ever stops being on a "
           .. "side - King of the Hill's and Domination's own answer about "
           .. "the same shape." },
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

function modes.speedrun_stop_row(panel)
    local run = OF.speedrun
    if not (OF.util.asks(run, "state") and OF.util.asks(run, "stop")) then return nil end
    if run.state() == run.OFF then return nil end

    local built = panel.gated_row("end_round",
        OF.lang.t("Stop the speedrun"), 255, 140, 90,
        function()
            run.stop(false, 0)
            panel.close()
        end)
    if OF.util.asks(panel, "with_tone") then built = panel.with_tone(built, "danger") end
    return panel.with_help(built, "ends the speedrun only - a game mode round keeps going")
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

    if modes.is_open() then
        local mode = modes.current()

        local runningRow = panel.label_row(OF.lang.fill("Running: @",
            OF.lang.t(mode and mode.name or "a round")))
        if modes.is_waiting() then
            runningRow = panel.label_row(OF.lang.fill("@ - @",
                OF.lang.t(mode and mode.name or "a round"), modes.lobby_line(mode)))
        end
        if OF.util.asks(panel, "with_pulse") then
            runningRow = panel.with_pulse(runningRow, true)
        end
        table.insert(rows, runningRow)

        if modes.is_waiting() then
            local join = modes.lobby_join_row(panel)
            if join ~= nil then table.insert(rows, join) end
            if modes.may_force(0) then
                table.insert(rows, panel.with_help(panel.row(
                    OF.lang.t("Start the countdown now"), 140, 255, 160,
                    function()
                        if OF.util.report(modes.force_countdown(0)) then panel.close() end
                    end),
                    "plays it with whoever is waiting - nobody else is waited for"))
            end
        end
        table.insert(rows, panel.with_help(panel.gated_row("end_round",
            OF.lang.t("Stop the round"), 255, 140, 90,
            function()

                if not OF.util.report(modes.stop(false, 0)) then return end
                panel.close()
            end),
            "ends it now - the lobby is handed back everything the round borrowed"))
        local speedStop = modes.speedrun_stop_row(panel)
        if speedStop ~= nil then table.insert(rows, speedStop) end

        if OF.util.asks(OF.net, "move_round_here") and OF.net.is_round_lead(0)
            and mode ~= nil and not mode.wholeGame and modes.publishes_place(mode)
            and not modes.owns_its_place(mode) then
            table.insert(rows, panel.with_help(panel.gated_row("round_move",
                OF.lang.t("Move the round here"), 255, 255, 255,
                function()
                    if OF.util.report(OF.net.move_round_here()) then panel.close() end
                end),
                "you lead this round - everybody playing it is sent to where you stand"))
        end
        table.insert(rows, nonstop_row(panel))

        local who = OF.util.asks(OF.whoplays, "list_door") and OF.whoplays.list_door(panel)
        if who then table.insert(rows, who) end
    else

        if modes.nonstop() then
            table.insert(rows, nonstop_row(panel))
            local who = OF.util.asks(OF.whoplays, "list_door") and OF.whoplays.list_door(panel)
            if who then table.insert(rows, who) end
        end
        local speedStop = modes.speedrun_stop_row(panel)
        if speedStop ~= nil then table.insert(rows, speedStop) end
        wantModes = true
    end

    if OF.util.asks(OF.rounds, "build_page") then
        local queued = OF.util.asks(OF.rounds, "count") and OF.rounds.count() or 0
        local queueRuns = OF.util.asks(OF.rounds, "is_running")
            and OF.rounds.is_running() or false

        local queueRow = panel.with_tone(panel.gated_row("speedrun",
            queueRuns
                and OF.lang.fill("Round queue: running, @ to go", queued)
                or OF.lang.fill("Round queue (@ lined up)...", queued),
            255, 255, 255, function() panel.go("queue") end), "key")

        if OF.util.asks(panel, "live") then
            queueRow = panel.with_pulse(queueRow,
                panel.live("queue", "rotation", "tournament", "session"))
        elseif queueRow ~= nil and queueRuns then
            queueRow.pulse = true
        end
        table.insert(rows, panel.with_help(queueRow,
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

do
    OF.packet_kind(modes.PACKET_RELAY, { fields = { g = "gi?", x = "finite", y = "finite",
        z = "finite", yaw = "int?", a = "int?", v = "finite?" } },
        function(data) modes.relay_receive(data, OF.util.asked_by(data)) end)
    OF.packet_kind(modes.PACKET_HIT, { round = true, fields = { g = "gi", v = "gi" } },
        modes.receive_hit_claim)
    OF.packet_kind(modes.PACKET_STREAM, { round = true, fields = { k = "str", n = "int", s = "int?" } },
        modes.stream_receive)
    OF.packet_kind(modes.PACKET_TAG, { round = true, fields = { a = "gi", v = "gi" } },
        function(data) modes.receive_tag(data, OF.util.asked_by(data)) end)
    OF.packet_kind(modes.PACKET_CLAIM, { round = true, fields = { g = "gi?", w = "str", n = "int?" } },
        function(data) modes.receive_claim(data, OF.util.asked_by(data)) end)
    OF.packet_kind(modes.PACKET_CLAIM_ACK, { fields = { n = "int" } }, modes.receive_claim_ack)
end

local function on_packet_receive(data)
    if data == nil then return end

    if data.ofp == OF.util.PACKET_RAIN then
        if OF.util.from_host(data) then OF.util.receive_rain(data) end
        return
    end

    if data.ofp == modes.PACKET_LEAD_RUN then
        modes.receive_lead_run(data)
        return
    end
    if data.ofp == modes.PACKET_LEAD_HAND then
        modes.receive_lead_hand(data)
        return
    end
    if data.ofp == modes.PACKET_LEAD_SAYS then
        modes.receive_lead_says(data, OF.util.asked_by(data))
        return
    end
    if data.ofp ~= modes.PACKET_ASK then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end

    if data.go == "force" then
        local ok, why = modes.force_countdown(asker)
        if not ok then
            OF.notify.send_to(askerGlobal, why or "That would not start.", "bad", 5)
        end
        return
    end

    local wanted = data.go == "stop" and "end_round" or "speedrun"
    if OF.perms.tier(asker) < OF.perms.required(wanted, asker) then
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

function modes.ready()
    return true
end
