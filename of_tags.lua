OF = OF or {}
OF.tags = OF.tags or {}

local tags = OF.tags

local TAG_LIMIT = 63

local utilAsks = nil

local function asks(from, name)
    local fn = utilAsks
    if fn == nil then
        local util = OF.util
        fn = util ~= nil and util.asks or nil
        utilAsks = fn
    end
    if fn ~= nil then return fn(from, name) end
    return from ~= nil and from[name] ~= nil
end

function tags.on()
    return OF.settings == nil or OF.settings.overheadTags ~= false
end

function tags.set(value)
    if OF.settings == nil or OF.settings.set_overhead_tags == nil then
        return false, "The settings file is not loaded."
    end
    OF.settings.set_overhead_tags(value == true)
    return true
end

local roundNow = false
local roundKnown = false

function tags.in_a_round()
    if roundKnown then return roundNow end
    return asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running() == true
end

function tags.state(localIndex)
    if type(localIndex) ~= "number" then return nil end
    if tags.in_a_round() then return nil end

    if asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return nil
    end

    if asks(OF.charselect, "in_menu") and OF.charselect.in_menu(localIndex) then
        return "in the menu"
    end
    if asks(OF.idle, "is_idle") and OF.idle.is_idle(localIndex) then
        return "away"
    end
    if asks(OF.mute, "is_muted") and OF.mute.is_muted(localIndex) then
        return "muted"
    end
    return nil
end

function tags.compose(name, word)
    if type(name) ~= "string" or name == "" then return nil end
    if type(word) ~= "string" or word == "" then return nil end
    local full = name .. " (" .. word .. ")"
    if #full > TAG_LIMIT then return nil end
    return full
end

local TAG_FLOOR = 127

local function washed(value)
    value = tonumber(value)
    if value == nil then return 255 end
    if value < 0 then value = 0 end
    if value > 255 then value = 255 end

    return TAG_FLOOR + math.floor(value / 2)
end

function tags.side_colour(localIndex)
    if type(localIndex) ~= "number" then return nil end
    if not tags.in_a_round() then return nil end
    if not (asks(OF.teams, "in_play") and asks(OF.teams, "colours_on")
        and asks(OF.teams, "find") and asks(OF.teams, "of")) then
        return nil
    end
    if not OF.teams.in_play() then return nil end
    if not OF.teams.colours_on() then return nil end
    if asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return nil
    end

    local side = OF.teams.find(OF.teams.of(localIndex))
    if side == nil then return nil end
    return washed(side.r), washed(side.g), washed(side.b)
end

local sidedFor = {}

function tags.side_name(localIndex, name)
    if type(name) ~= "string" or name == "" then return nil end

    local r, g, b = tags.side_colour(localIndex)
    if r == nil then return nil end

    if not (asks(OF.util, "plain") and asks(OF.util, "colour_escape")) then
        return nil
    end

    local held = sidedFor[localIndex]
    if held ~= nil and held.name == name
        and held.r == r and held.g == g and held.b == b then
        return held.drawn
    end

    local text = nil
    local bare = OF.util.plain(name)
    if bare ~= "" then
        local full = OF.util.colour_escape(r, g, b) .. bare
        if #full <= TAG_LIMIT then text = full end
    end

    if held == nil then
        held = {}
        sidedFor[localIndex] = held
    end

    held.name, held.r, held.g, held.b, held.drawn = name, r, g, b, text
    return text
end

local RANK_FLOOR = OF.TIER ~= nil and OF.TIER.NORMAL or 10

function tags.rank_on()
    if not asks(OF.rules, "value") then return false end
    return OF.rules.value("ranktag") == 1
end

function tags.rank_colour(localIndex)
    if type(localIndex) ~= "number" then return nil end
    if tags.in_a_round() then return nil end
    if not tags.rank_on() then return nil end
    if not (asks(OF.perms, "tier") and asks(OF.perms, "tier_color")) then
        return nil
    end
    if asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return nil
    end

    local tier = OF.perms.tier(localIndex)
    if type(tier) ~= "number" or tier <= RANK_FLOOR then return nil end
    return OF.perms.tier_color(tier)
end

local rankedFor = {}

function tags.rank_name(localIndex, name)
    if type(name) ~= "string" or name == "" then return nil end

    local r, g, b = tags.rank_colour(localIndex)
    if r == nil then return nil end

    if not (asks(OF.util, "plain") and asks(OF.util, "colour_escape")) then
        return nil
    end

    local held = rankedFor[localIndex]
    if held ~= nil and held.name == name
        and held.r == r and held.g == g and held.b == b then
        return held.drawn
    end

    local text = nil
    local bare = OF.util.plain(name)
    if bare ~= "" then
        local full = OF.util.colour_escape(r, g, b) .. bare
        if #full <= TAG_LIMIT then text = full end
    end

    if held == nil then
        held = {}
        rankedFor[localIndex] = held
    end

    held.name, held.r, held.g, held.b, held.drawn = name, r, g, b, text
    return text
end

local QUIET_LIMIT = 900

local heard = false
local quiet = 0

local function ruled_off()
    if not asks(OF.rules, "value") then return false end
    if not asks(OF.util, "flag") then return false end
    return OF.util.flag(OF.rules.value("nametags")) == 0
end

local function hidden_from_tags(localIndex)
    if asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return true
    end
    if asks(OF.possess, "hides_from_world")
        and OF.possess.hides_from_world(localIndex) then
        return true
    end
    return false
end

local function somebody_to_tag()
    if tags.in_a_round() then return false end
    if not asks(OF.util, "connected_players") then return false end

    local mine = gNetworkPlayers[0]
    if mine == nil then return false end
    for _, entry in ipairs(OF.util.connected_players()) do
        if entry.localIndex ~= 0 and entry.np ~= nil
            and entry.np.currLevelNum == mine.currLevelNum
            and entry.np.currAreaIndex == mine.currAreaIndex
            and not hidden_from_tags(entry.localIndex) then
            return true
        end
    end
    return false
end

local function tag_expected()
    if not tags.on() then return false end
    if ruled_off() then return false end
    return somebody_to_tag()
end

local told = false

local function notice()
    if not ruled_off() then
        told = false
        return
    end
    if told then return end
    if not somebody_to_tag() then return end

    told = true
    if asks(OF.notify, "show") then
        OF.notify.show("Name tags are off in this lobby, so no names are drawn",
            "info", 6)
    end
end

local function watch()
    notice()

    if not tag_expected() then
        heard = false
        quiet = 0
        return
    end
    if heard then quiet = 0 else quiet = quiet + 1 end
    heard = false
end

hook_event(HOOK_UPDATE, watch)

function tags.reaching()
    return quiet < QUIET_LIMIT
end

function tags.quiet()
    return quiet
end

function tags.note()
    if not (asks(OF.rules, "value") and asks(OF.util, "flag")) then return nil end
    if OF.util.flag(OF.rules.value("nametags")) == 0 then
        return "nothing while Name tags is off"
    end
    if not tags.reaching() then
        return "something else is drawing the name tags"
    end
    return nil
end

local function tag_for(playerIndex, np)
    if tags.in_a_round() then return tags.side_name(playerIndex, np.name) end

    local ranked = tags.rank_name(playerIndex, np.name)

    if not tags.on() then return ranked end
    local word = tags.state(playerIndex)
    if word == nil then return ranked end

    if ranked == nil then return tags.compose(np.name, word) end

    return tags.compose(ranked, word)
        or tags.compose(np.name, word)
        or ranked
end

hook_event(HOOK_ON_NAMETAGS_RENDER, function(playerIndex)

    heard = true

    local np = gNetworkPlayers[playerIndex]
    if np == nil then return end

    roundKnown = false
    roundNow = tags.in_a_round()
    roundKnown = true
    local answer = tag_for(playerIndex, np)
    roundKnown = false
    return answer
end)

function tags.build_row(panel)
    if panel == nil or panel.row == nil then return nil end

    local on = tags.on()

    local text = panel.tick(on,
        OF.lang.t("Who is away or muted, over their head (not in a round)"))
    local r, g, b = 255, 255, 255

    local help = OF.lang.t(
        "away, muted and typing, over a head - a round's own marks replace it")

    if not on then
        r, g, b = 150, 150, 150
    else
        local note = tags.note()
        if note ~= nil then
            help = OF.lang.t(note)
            r, g, b = 150, 150, 150
        end
    end

    return panel.with_help(panel.row(text, r, g, b, function()
        OF.util.report(tags.set(not tags.on()))
    end), help)
end

function tags.ready()
    return true
end
