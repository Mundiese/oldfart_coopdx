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

local roundFor = nil

function tags.in_a_round(localIndex)
    if roundKnown and roundFor == localIndex then return roundNow end
    if not asks(OF.lockdown, "menu_stands_down") then return false end

    local ok, result = pcall(OF.lockdown.menu_stands_down, localIndex)
    return ok and result == true
end

function tags.state(localIndex)
    if type(localIndex) ~= "number" then return nil end
    if tags.in_a_round(localIndex) then return nil end

    if asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return nil
    end

    if asks(OF.charselect, "in_menu") and OF.charselect.in_menu(localIndex) then
        return "in the menu"
    end

    if asks(OF.idle, "in_menu") and OF.idle.in_menu(localIndex) then
        return tags.MENU_MARK
    end
    if asks(OF.idle, "is_idle") and OF.idle.is_idle(localIndex) then
        return "away"
    end
    if asks(OF.mute, "is_muted") and OF.mute.is_muted(localIndex) then
        return "muted"
    end
    return nil
end

tags.MENU_MARK = "+"
function tags.compose(name, word)
    if type(name) ~= "string" or name == "" then return nil end
    if type(word) ~= "string" or word == "" then return nil end
    local full = name .. " (" .. word .. ")"
    if word == tags.MENU_MARK then full = name .. " " .. word end
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
    if not tags.in_a_round(localIndex) then return nil end
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
    if tags.in_a_round(localIndex) then return nil end
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
            and OF.util.same_world(entry.localIndex)
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

        return "nothing while Name tags is none"
    end
    if not tags.reaching() then
        return "something else is drawing the name tags"
    end
    return nil
end

local CLOSE_BY = 1600

local function standing_still(m)
    if m == nil then return false end
    local action = tonumber(m.action)
    if action == nil then return false end
    return math.floor(action / 64) % 8 == ACT_GROUP_STATIONARY
end

local function close_by(playerIndex)
    if playerIndex == 0 then return true end
    local mine, theirs = gMarioStates[0], gMarioStates[playerIndex]
    if mine == nil or theirs == nil then return false end
    if mine.pos == nil or theirs.pos == nil then return false end
    local dx = (tonumber(theirs.pos.x) or 0) - (tonumber(mine.pos.x) or 0)
    local dy = (tonumber(theirs.pos.y) or 0) - (tonumber(mine.pos.y) or 0)
    local dz = (tonumber(theirs.pos.z) or 0) - (tonumber(mine.pos.z) or 0)
    return dx * dx + dy * dy + dz * dz <= CLOSE_BY * CLOSE_BY
end

local function carrying(playerIndex, m)
    if m == nil then return nil end
    local held = m.heldObj
    if held == nil then return nil end

    for i = 0, MAX_PLAYERS - 1 do
        local other = gMarioStates[i]
        if other ~= nil and other.marioObj == held then
            local np = gNetworkPlayers[i]
            if np ~= nil and type(np.name) == "string" and np.name ~= "" then
                return np.name
            end
            return nil
        end
    end

    local spawner = OF.spawner
    local list = spawner ~= nil and spawner.LIST or nil
    if type(list) ~= "table" then return nil end
    for _, entry in ipairs(list) do
        if entry.bhv ~= nil and type(entry.name) == "string" then
            local yes = obj_has_behavior_id(held, entry.bhv)
            if yes ~= nil and yes ~= 0 and yes ~= false then return entry.name end
        end
    end
    return nil
end

function tags.shaped(playerIndex)
    if type(playerIndex) ~= "number" then return nil end
    if tags.in_a_round(playerIndex) then return nil end
    if not asks(OF.rules, "tag_shape") then return nil end

    local shape = OF.rules.tag_shape()
    if type(shape) ~= "number" or shape < 2 then return nil end

    local m = gMarioStates[playerIndex]
    if shape == 2 then
        if standing_still(m) then return nil end
        return { name = "" }
    end
    if shape == 3 then
        if close_by(playerIndex) then return nil end
        return { name = "" }
    end

    local cargo = carrying(playerIndex, m)
    if cargo == nil then return nil end
    return cargo
end

local composedFor = { plain = {}, ranked = {} }

local function composed(bucket, playerIndex, name, word)
    local compose = tags.compose
    local held = bucket[playerIndex]
    if held ~= nil and held.fn == compose
        and held.name == name and held.word == word then
        return held.drawn
    end
    local full = compose(name, word)
    if held == nil then
        held = {}
        bucket[playerIndex] = held
    end
    held.fn, held.name, held.word, held.drawn = compose, name, word, full
    return full
end

local function tag_for(playerIndex, np)
    if tags.in_a_round(playerIndex) then

        return tags.side_name(playerIndex, np.name)
    end

    local ranked = tags.rank_name(playerIndex, np.name)

    if not tags.on() then return ranked end
    local word = tags.state(playerIndex)
    if word == nil then return ranked end

    if ranked == nil then
        return composed(composedFor.plain, playerIndex, np.name, word)
    end

    return composed(composedFor.ranked, playerIndex, ranked, word)
        or composed(composedFor.plain, playerIndex, np.name, word)
        or ranked
end

function tags.answer_for(playerIndex)
    local np = gNetworkPlayers[playerIndex]
    if np == nil then return nil end
    local answer = tags.shaped(playerIndex)
    if answer == nil then answer = tag_for(playerIndex, np) end
    if type(answer) == "table" then return answer.name end
    return answer
end

hook_event(HOOK_ON_NAMETAGS_RENDER, function(playerIndex)

    heard = true

    local np = gNetworkPlayers[playerIndex]
    if np == nil then return end

    if asks(OF.cheats, "drawn_invisible") and OF.cheats.drawn_invisible(playerIndex) then
        return { name = "" }
    end

    if playerIndex ~= 0 and asks(OF.util, "same_world") and not OF.util.same_world(playerIndex) then
        return { name = "" }
    end

    roundKnown = false
    roundNow = tags.in_a_round(playerIndex)
    roundFor = playerIndex
    roundKnown = true

    local answer = tags.shaped(playerIndex)
    if answer == nil then answer = tag_for(playerIndex, np) end
    roundKnown = false
    return answer
end)

tags.RULE_BY_KEY = {
    hideseek = "none", sardines = "none", prophunt = "none", zombies = "none",
    shooter = "shooter", rocketarena = "shooter", oitc = "shooter", snd = "shooter",
    manhunt = "hunt", copsandrobbers = "hunt", hotpotato = "hunt", rabbitchase = "hunt",
    wanted = "hunt", deflect = "hunt",

    murder = "ffa", assassins = "ffa",
}

tags.TEAM_RANGE = 8000
tags.SIGHT_RANGE = 4000
tags.SPECTATOR_RANGE = 8000
tags.THROUGH_WALL = 0.5
tags.NEAR_FADE = { 150, 350 }
tags.FAR_FADE_SHARE = 0.2
tags.SCALE = { least = 0.55, most = 1.0, from = 800 }
tags.COVERED = 0.7
tags.HEAD = 200
tags.GLYPH_SIZE = 9

local NO_TAG_ACTIONS = {}
for _, name in ipairs({ "ACT_START_CROUCHING", "ACT_CROUCHING", "ACT_STOP_CROUCHING",
    "ACT_START_CRAWLING", "ACT_CRAWLING", "ACT_STOP_CRAWLING", "ACT_IN_CANNON", "ACT_DISAPPEARED" }) do
    local value = _G[name]
    if type(value) == "number" then NO_TAG_ACTIONS[value] = true end
end
tags.NO_TAG_ACTIONS = NO_TAG_ACTIONS

tags.HEAD_ABOVE = 100
tags.HEAD_FRESH = 1
function tags.head_point(m)
    if m == nil or m.pos == nil then return nil end
    local k = 1
    local obj = m.marioObj
    local gfx = obj ~= nil and obj.header ~= nil and obj.header.gfx or nil
    if gfx ~= nil and gfx.scale ~= nil and type(gfx.scale.y) == "number" and gfx.scale.y > 0 then
        k = gfx.scale.y
    end
    local body = m.marioBodyState
    local stamp = body ~= nil and body.updateHeadPosTime or nil
    if type(stamp) == "number" and body.headPos ~= nil
        and math.abs((get_global_timer() or 0) - stamp) <= tags.HEAD_FRESH then
        return body.headPos.x, body.headPos.y + tags.HEAD_ABOVE * k, body.headPos.z
    end
    return m.pos.x, m.pos.y + tags.HEAD * k, m.pos.z
end

local function current_round()
    local modes = OF.gamemodes
    if modes == nil or modes.is_running == nil or not modes.is_running() then return nil end
    return modes.current ~= nil and modes.current() or nil
end

function tags.round_rule(mode)
    mode = mode or current_round()
    if mode == nil then return nil end
    if type(mode.tagRule) == "string" then return mode.tagRule end
    if mode.noNametags then return "none" end
    if asks(OF.markers, "players_marked") and not OF.markers.players_marked(mode) then return "none" end
    local said = tags.RULE_BY_KEY[mode.key]
    if said ~= nil then return said end
    if asks(OF.teams, "in_play") and OF.teams.in_play() then return "team" end
    return "ffa"
end

function tags.round_health(mode)
    if mode == nil then return false end
    if mode.tagHealth ~= nil then return mode.tagHealth == true end
    return type(mode.lobbyRules) == "table" and mode.lobbyRules.health == 1
end

local function viewer_watching()
    if asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(0) then return true end
    local modes = OF.gamemodes
    return modes ~= nil and modes.is_out ~= nil and modes.is_out(0) == true
end

function tags.reach(rule, localIndex, watching)
    if watching then return tags.SPECTATOR_RANGE, 1 end
    if rule == nil or rule == "none" then return nil end
    local teamsOn = asks(OF.teams, "in_play") and OF.teams.in_play()
    local mate = teamsOn and OF.teams.same(0, localIndex)
    if rule == "team" then
        if mate then return tags.TEAM_RANGE, tags.THROUGH_WALL end
        return tags.SIGHT_RANGE, 0
    end
    if rule == "shooter" then
        if mate then return tags.TEAM_RANGE, tags.THROUGH_WALL end
        return nil
    end
    if rule == "ffa" or rule == "hunt" then return tags.SIGHT_RANGE, 0 end
    return nil
end

function tags.round_tone(rule, localIndex, mode)
    local hud = OF.hud
    local modes = OF.gamemodes
    if modes ~= nil and modes.is_out ~= nil and modes.is_out(localIndex) then return "out", "cross" end
    if mode ~= nil and type(mode.tag_tone) == "function" then
        local ok, tone, glyph = pcall(mode.tag_tone, localIndex)
        if ok and tone ~= nil then return tone, glyph end
    end
    if rule == "ffa" then return "neutral", nil end
    if asks(OF.teams, "in_play") and OF.teams.in_play() then
        local key = OF.teams.of(localIndex)

        local shapes = hud ~= nil and hud.TEAM_GLYPH or { red = "circle", blue = "square" }
        if key == "red" then return "red", shapes.red end
        if key == "blue" then return "blue", shapes.blue end
    end
    if rule == "hunt" and mode ~= nil and type(mode.paint) == "function" then
        local ok, colour = pcall(mode.paint, localIndex)
        if ok and type(colour) == "table" and colour.r ~= nil then return { colour.r, colour.g, colour.b }, nil end
    end
    if hud ~= nil then return "neutral", nil end
    return { 240, 240, 240 }, nil
end

local function tag_name(np, tone)
    local name = np ~= nil and np.name or ""
    if tone == "neutral" and asks(OF.util, "name_safe") then return OF.util.name_safe(name) end
    if asks(OF.util, "plain") then name = OF.util.plain(name) end
    return name
end

function tags.plays_in_round(i)
    local modes = OF.gamemodes
    if modes ~= nil and modes.is_out ~= nil and modes.is_out(i) then return false end
    if modes ~= nil and modes.role ~= nil and modes.role(i) == modes.WAITING then return false end
    if asks(OF.util, "can_play") and not OF.util.can_play(i) then return false end
    return true
end

local tagScreen = { x = 0, y = 0, z = 0 }
local tagWorld = { x = 0, y = 0, z = 0 }
tags.lastRound = {}

function tags.FARTHEST_FIRST(a, b) return a.distance > b.distance end

function tags.round_list()
    local out = {}
    local mode = current_round()
    if mode == nil then return out end
    local rule = tags.round_rule(mode)

    if OF.rules ~= nil and OF.rules.tagsWhen == 0 then rule = "none" end
    local watching = viewer_watching()
    if (rule == nil or rule == "none") and not watching then return out end
    if not asks(OF.util, "connected_players") or not asks(OF.util, "world_screen") then return out end
    local lk = gLakituState
    local mine = gNetworkPlayers[0]
    if lk == nil or lk.pos == nil or mine == nil then return out end
    local hud = OF.hud
    local withHealth = tags.round_health(mode)
    for _, entry in ipairs(OF.util.connected_players()) do
        local i = entry.localIndex
        local np = entry.np
        local m = gMarioStates[i]
        if i ~= 0 and np ~= nil and m ~= nil and m.pos ~= nil
            and OF.util.same_world(i) and tags.plays_in_round(i)
            and not hidden_from_tags(i) and not NO_TAG_ACTIONS[m.action]
            and not (asks(OF.markers, "hidden") and OF.markers.hidden(i))
            and not (asks(OF.cheats, "drawn_invisible") and OF.cheats.drawn_invisible(i)) then
            local range, walls = tags.reach(rule, i, watching)
            if range ~= nil then
                local hx, hy, hz = tags.head_point(m)
                local dx, dy, dz = hx - lk.pos.x, hy - lk.pos.y, hz - lk.pos.z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                if dist <= range then
                    tagWorld.x, tagWorld.y, tagWorld.z = hx, hy, hz
                    if OF.util.world_screen(tagWorld, tagScreen) then
                        if asks(OF.markers, "want_sight") then OF.markers.want_sight(i) end
                        local seen = asks(OF.markers, "sight") and OF.markers.sight(i) or 1
                        local a = math.max(seen, walls)
                        local nf = tags.NEAR_FADE
                        a = a * math.max(0, math.min(1, (dist - nf[1]) / (nf[2] - nf[1])))
                        local farFrom = range * (1 - tags.FAR_FADE_SHARE)
                        if dist > farFrom then a = a * math.max(0, (range - dist) / (range - farFrom)) end
                        local tone, glyph = tags.round_tone(rule, i, mode)
                        if tone == "out" and hud ~= nil then a = a * hud.OUT_SHARE end
                        local S = tags.SCALE
                        local k = 1 - (dist - S.from) / math.max(1, range - S.from) * (S.most - S.least)
                        local scale = math.max(S.least, math.min(S.most, k))
                        if a > 0.02 then
                            local wedges = nil
                            if withHealth and OF.util.asks(OF.markers, "wedges") then
                                wedges = OF.markers.wedges(i)
                            end
                            out[#out + 1] = { index = i, x = tagScreen.x, y = tagScreen.y, scale = scale,
                                alpha = a, tone = tone, glyph = glyph, name = tag_name(np, tone), distance = dist,
                                wedges = wedges }
                        end
                    end
                end
            end
        end
    end

    table.sort(out, tags.FARTHEST_FIRST)
    for _, t in ipairs(out) do
        local w = 8 * #OF.util.plain(t.name) * t.scale + (t.glyph and (tags.GLYPH_SIZE + 4) or 0)
        t.w, t.h = w, 16 * t.scale
    end

    local kept = {}
    for i = 1, #out do
        local t = out[i]
        local covered = false
        for j = i + 1, #out do
            local n = out[j]
            local ox = math.max(0, math.min(t.x + t.w / 2, n.x + n.w / 2) - math.max(t.x - t.w / 2, n.x - n.w / 2))
            local oy = math.max(0, math.min(t.y, n.y) - math.max(t.y - t.h, n.y - n.h))
            if t.w * t.h > 0 and ox * oy / (t.w * t.h) > tags.COVERED then covered = true break end
        end
        if not covered then kept[#kept + 1] = t end
    end
    tags.lastRound = kept
    return kept
end

local function draw_round_tags()
    local hud = OF.hud
    if hud == nil or current_round() == nil then return end

    local modes = OF.gamemodes
    if modes ~= nil and type(modes.hears_round) == "function" and not modes.hears_round() then
        return
    end
    if hud.blocked() or OF.util.menu_has_screen() then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    local list = tags.round_list()
    for _, t in ipairs(list) do
        local a = 255 * t.alpha
        local mult = t.scale
        local w = hud.measure(OF.util.plain(t.name), "body", mult)
        local g = t.glyph and (tags.GLYPH_SIZE * mult + 4) or 0
        local left = t.x - (w + g) / 2
        if t.glyph then
            hud.draw_glyph(t.glyph, left + tags.GLYPH_SIZE * mult / 2, t.y, tags.GLYPH_SIZE * mult, t.tone, a)
        end
        local tx = left + g

        local top, base = hud.cap("body", mult, OF.util.plain(t.name))
        hud.outlined(t.name, tx, t.y - (top + base) / 2, "body", t.tone, a, "left", mult)
        if t.wedges ~= nil then

            local bw, bh = math.max(24, w + g), math.max(2, 4 * mult)
            local by = t.y + 10 * mult + 2
            local tone = t.wedges >= 5 and "good" or (t.wedges >= 3 and "warn" or "bad")
            hud.rect(left - 1, by - 1, bw + 2, bh + 2, hud.C.outline, a * 0.8)
            hud.rect(left, by, bw * t.wedges / 8, bh, tone, a)
        end
    end
end

local function engine_tags()
    if not asks(OF.rules, "hold_engine_tags") then return end
    OF.rules.hold_engine_tags(current_round() ~= nil)
end
tags.engine_tags = engine_tags

tags.render_behind = draw_round_tags
if HOOK_ON_HUD_RENDER_BEHIND ~= nil then
    hook_event(HOOK_ON_HUD_RENDER_BEHIND, draw_round_tags)
end
hook_event(HOOK_UPDATE, engine_tags)

function tags.build_row(panel)
    if panel == nil or panel.row == nil then return nil end

    local on = tags.on()

    local text = panel.tick(on,
        OF.lang.t("Who is away or muted, over their head"))
    local r, g, b = 255, 255, 255

    local help = OF.lang.t(
        "away, muted and typing, over a head, and + while their menu is open")

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
