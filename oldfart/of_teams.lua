OF = OF or {}
OF.teams = OF.teams or {}

local teams = OF.teams

teams.NONE = ""
teams.LIST = {
    { key = "red",  name = "Red",  r = 255, g = 75,  b = 62,  body = { r = 230, g = 32, b = 30 } },
    { key = "blue", name = "Blue", r = 60,  g = 120, b = 255, body = { r = 30, g = 80, b = 230 } },
}

function teams.find(key)
    for _, team in ipairs(teams.LIST) do
        if team.key == key then return team end
    end
    return nil
end

function teams.of(localIndex)
    local row = gPlayerSyncTable[localIndex]
    if row == nil then return teams.NONE end
    return row.ofTeam or teams.NONE
end

function teams.side_name(key)
    local team = teams.find(key)
    if team == nil then return "" end
    local modes = OF.gamemodes
    local mode = modes ~= nil and modes.current ~= nil and modes.current() or nil
    local names = mode ~= nil and mode.sideNames or nil
    if type(names) == "table" and type(names[key]) == "string" and names[key] ~= "" then
        return names[key]
    end
    return team.name
end

function teams.name_of(localIndex)
    local team = teams.find(teams.of(localIndex))
    if team == nil then return "" end
    return teams.side_name(team.key)
end

function teams.color_of(localIndex)
    local team = teams.find(teams.of(localIndex))
    if team == nil then return 255, 255, 255 end
    return team.r, team.g, team.b
end

function teams.same(aIndex, bIndex)
    local a = teams.of(aIndex)
    if a == teams.NONE then return false end
    return a == teams.of(bIndex)
end

function teams.members(key)
    local list = {}
    for _, entry in ipairs(OF.gamemodes.participants()) do
        if teams.of(entry.localIndex) == key then table.insert(list, entry) end
    end
    return list
end

function teams.in_play()
    return gGlobalSyncTable.ofTeamsOn == true
end

teams.MIN_PER_SIDE = 2

function teams.min_room(mode)
    if type(mode) == "table" and type(mode.sidesFrom) == "number" then
        return math.max(#teams.LIST, math.floor(mode.sidesFrom))
    end
    return #teams.LIST * teams.MIN_PER_SIDE
end

function teams.share(count, players)
    if count == nil or count <= 0 then return 0 end
    return math.ceil(players / #teams.LIST) / count
end

teams.BASE_STRENGTH = 100

teams.FORM_SPREAD = 60

teams.FAIR_GAP = 25

local formSeen, formRates = nil, {}

local function form_rate(name)

    local packed = OF.util.joined(OF.stats.NIGHT_KEYS)
    if packed ~= formSeen then
        formSeen, formRates = packed, {}
        if OF.util.asks(OF.stats, "form_board") then
            for _, entry in ipairs(OF.stats.form_board()) do
                formRates[entry.name] = entry.rate
            end
        end
    end
    return formRates[name]
end

function teams.strength(localIndex)
    local out = teams.BASE_STRENGTH

    local np = gNetworkPlayers[localIndex]
    if np ~= nil then

        local rate = form_rate(OF.util.plain(np.name or ""))
        if rate ~= nil then
            out = out + (rate - 0.5) * teams.FORM_SPREAD
        end
    end
    return out
end

local function step_of(place, snaked)
    if snaked then return math.floor((place - 1) / 2) + (place - 1) end
    return place - 1
end

local function worth(total, count, heads)
    if count <= 0 then return 0 end
    return (total / count)
        - teams.BASE_STRENGTH * (teams.share(count, heads) - 1)
end

local function gap_of(order, snaked)
    local total, count = { 0, 0 }, { 0, 0 }
    for place, entry in ipairs(order) do
        local at = (step_of(place, snaked) % 2) + 1
        total[at] = total[at] + teams.strength(entry.localIndex)
        count[at] = count[at] + 1
    end
    local heads = #order
    return math.abs(worth(total[1], count[1], heads)
        - worth(total[2], count[2], heads))
end

function teams.balance(players)
    if not OF.util.is_host() then return false end

    local turn = (gGlobalSyncTable.ofTeamRound or 0) % 2
    OF.util.publish("ofTeamRound", (gGlobalSyncTable.ofTeamRound or 0) + 1)

    local plain, sorted = {}, {}
    for _, entry in ipairs(players) do
        table.insert(plain, entry)
        table.insert(sorted, entry)
    end
    table.sort(sorted, function(a, b)
        local first, second = teams.strength(a.localIndex), teams.strength(b.localIndex)
        if first ~= second then return first > second end
        return a.localIndex < b.localIndex
    end)

    local order, snaked = plain, false
    if gap_of(sorted, true) + teams.FAIR_GAP <= gap_of(plain, false) then
        order, snaked = sorted, true
    end

    local sides = {}
    for place = 1, #order do sides[place] = (step_of(place, snaked) % 2) + 1 end
    sides = teams.mix(order, sides)

    for place, entry in ipairs(order) do
        local side = ((sides[place] - 1 + turn) % 2) + 1
        OF.util.publish_row(entry.localIndex, "ofTeam", teams.LIST[side].key)
    end
    teams.remember_sides(order, sides)
    return true
end

teams.lastTogether = teams.lastTogether or {}

local function pair_key(a, b)
    if a > b then a, b = b, a end
    return a .. "|" .. b
end

local function id_of(entry)
    return OF.util.player_id(entry.localIndex)
        or ("g" .. tostring(entry.np ~= nil and entry.np.globalIndex or entry.localIndex))
end

function teams.remember_sides(order, sides)
    local together = {}
    for i = 1, #order do
        for j = i + 1, #order do
            if sides[i] == sides[j] then
                together[pair_key(id_of(order[i]), id_of(order[j]))] = true
            end
        end
    end
    teams.lastTogether = together
end

function teams.repeats(order, sides)
    local last, n = teams.lastTogether, 0
    for i = 1, #order do
        for j = i + 1, #order do
            if sides[i] == sides[j]
                and last[pair_key(id_of(order[i]), id_of(order[j]))] then
                n = n + 1
            end
        end
    end
    return n
end

local function split_gap(order, sides)
    local total, count = { 0, 0 }, { 0, 0 }
    for place, entry in ipairs(order) do
        local at = sides[place]
        total[at] = total[at] + teams.strength(entry.localIndex)
        count[at] = count[at] + 1
    end
    local heads = #order
    return math.abs(worth(total[1], count[1], heads)
        - worth(total[2], count[2], heads))
end

teams.MIX_PASSES = 4

function teams.mix(order, sides)
    local repeats = teams.repeats(order, sides)
    if repeats == 0 then return sides end
    local ceiling = split_gap(order, sides) + teams.FAIR_GAP
    for _ = 1, teams.MIX_PASSES do
        local improved = false
        for i = 1, #order do
            for j = i + 1, #order do
                if sides[i] ~= sides[j] then
                    sides[i], sides[j] = sides[j], sides[i]
                    local now = teams.repeats(order, sides)
                    if now < repeats and split_gap(order, sides) <= ceiling then
                        repeats = now
                        improved = true
                    else
                        sides[i], sides[j] = sides[j], sides[i]
                    end
                end
            end
        end
        if not improved or repeats == 0 then break end
    end
    return sides
end

local function wipe()
    for i = 0, MAX_PLAYERS - 1 do
        OF.util.publish_row(i, "ofTeam", teams.NONE)
    end
    OF.util.publish("ofTeamsOn", false)
end

function teams.set_here(localIndex, key)
    if not OF.util.is_host() then return false, "Only the host can do that." end
    if key ~= teams.NONE and teams.find(key) == nil then return false, "No such team." end
    OF.util.publish_row(localIndex, "ofTeam", key)
    return true
end

function teams.clear_all()
    if not OF.util.is_host() then return false end
    if teams.in_play() and OF.util.asks(OF.gamemodes, "is_running")
        and OF.gamemodes.is_running() then
        return false, "The round is being played in sides - stop it first."
    end
    wipe()
    return true
end

function teams.by_nature(mode)
    return mode ~= nil and mode.teams == "always"
end

teams.heldNote = nil
function teams.say_held_note()
    local need = teams.heldNote
    if need == nil then return false end
    teams.heldNote = nil
    if not OF.util.asks(OF.notify, "send_all") then return false end
    OF.notify.send_all("Sides need @ players - playing it as a free-for-all.",
        "info", 6, need)
    return true
end

function teams.begin(mode, players)
    if not OF.util.is_host() then return teams.in_play() end
    teams.heldNote = nil
    if mode == nil or not mode.teams then
        wipe()
        return false
    end
    if #players < teams.min_room(mode) then

        wipe()

        teams.heldNote = teams.min_room(mode)
        return false
    end

    OF.util.publish("ofTeamsOn", true)
    teams.balance(players)
    return true
end

teams.forged = teams.forged or 0

function teams.repair_row(localIndex)
    if teams.in_play() then return false end

    if localIndex ~= 0 and not OF.util.is_host() then return false end

    local row = gPlayerSyncTable[localIndex]
    if row == nil then return false end
    local side = row.ofTeam
    if side == nil or side == "" or side == teams.NONE then return false end

    OF.util.publish_row(localIndex, "ofTeam", teams.NONE)
    teams.forged = teams.forged + 1
    OF.guard.tell(OF.lang.t(
        "Somebody is handing out sides. Put back. /kick removes them."),
        "Somebody is handing out sides", 8)
    return true
end

for i = 0, MAX_PLAYERS - 1 do
    hook_on_sync_table_change(gPlayerSyncTable[i], "ofTeam", i, function()
        teams.repair_row(i)
    end)
end

function teams.score(key)
    local total = 0
    for _, entry in ipairs(teams.members(key)) do
        total = total + (gPlayerSyncTable[entry.localIndex].ofScore or 0)
    end
    return total
end

function teams.leader(red, blue)
    if red == nil then red = teams.score("red") end
    if blue == nil then blue = teams.score("blue") end
    if red == blue then return nil, red, blue end
    if red > blue then return teams.find("red"), red, blue end
    return teams.find("blue"), red, blue
end

function teams.result_text(red, blue)
    local winner, r, b = teams.leader(red, blue)
    if winner == nil then
        return "A draw, " .. r .. " each."
    end
    return teams.side_name(winner.key) .. " wins it, " .. math.max(r, b)
        .. " to " .. math.min(r, b) .. "."
end

function teams.last_side_standing(predicate)
    local alive = {}
    for _, team in ipairs(teams.LIST) do
        alive[team.key] = 0
        for _, entry in ipairs(teams.members(team.key)) do
            if predicate(entry.localIndex) then alive[team.key] = alive[team.key] + 1 end
        end
    end

    local standing = nil
    local count = 0
    for _, team in ipairs(teams.LIST) do
        if alive[team.key] > 0 then
            standing = team
            count = count + 1
        end
    end

    if count == 0 then return false end
    if count > 1 then return nil end
    return standing
end

local function gap_joining(key, localIndex)
    local total, count = {}, {}
    local heads = 1
    for _, team in ipairs(teams.LIST) do
        total[team.key], count[team.key] = 0, 0
        for _, entry in ipairs(teams.members(team.key)) do
            total[team.key] = total[team.key] + teams.strength(entry.localIndex)
            count[team.key] = count[team.key] + 1
            heads = heads + 1
        end
    end
    total[key] = total[key] + teams.strength(localIndex)
    count[key] = count[key] + 1

    local red, blue = teams.LIST[1].key, teams.LIST[2].key
    return math.abs(worth(total[red], count[red], heads)
        - worth(total[blue], count[blue], heads))
end

function teams.add_late(localIndex)
    if not teams.in_play() then return nil end
    if not OF.util.is_host() then return nil end

    local red, blue = teams.LIST[1], teams.LIST[2]
    local pick = red
    local redCount, blueCount = #teams.members(red.key), #teams.members(blue.key)

    if blueCount < redCount then
        pick = blue
    elseif blueCount == redCount then
        local joinRed = gap_joining(red.key, localIndex)
        local joinBlue = gap_joining(blue.key, localIndex)
        if math.abs(joinRed - joinBlue) >= teams.FAIR_GAP then
            if joinBlue < joinRed then pick = blue end
        elseif teams.score(blue.key) < teams.score(red.key) then
            pick = blue
        end
    end

    OF.util.publish_row(localIndex, "ofTeam", pick.key)
    OF.gamemodes.forget_participants()
    return pick.key
end

local function wearing(key)
    local count = 0
    for _, entry in ipairs(OF.util.connected_players()) do
        if teams.of(entry.localIndex) == key then count = count + 1 end
    end
    return count
end

function teams.hollow()
    if not teams.in_play() then return nil end
    local empty, filled = nil, 0
    for _, team in ipairs(teams.LIST) do
        if wearing(team.key) == 0 then empty = team else filled = filled + 1 end
    end
    if filled == 0 then return nil end
    return empty
end

function teams.left(localIndex)
    if not OF.util.is_host() then return false end
    if not teams.in_play() then return false end

    if not OF.util.asks(OF.gamemodes, "state") then return false end

    OF.util.forget_player_cache()
    OF.gamemodes.forget_participants()

    if OF.gamemodes.state() == OF.gamemodes.COUNTDOWN then
        local players = OF.gamemodes.participants()
        if #players < teams.min_room(OF.gamemodes.current()) then return false end
        teams.balance(players)
        return true
    end

    local gone = teams.hollow()
    if gone == nil then return false end

    if OF.util.asks(OF.gamemodes, "in_series") and OF.gamemodes.in_series()
        and OF.util.asks(OF.gamemodes, "back_to_lobby") then
        OF.gamemodes.back_to_lobby()
        return true
    end
    OF.gamemodes.abandon("@ have nobody left in the lobby.", teams.side_name(gone.key))
    return true
end

function teams.survival_text(team)
    if team == false then return "Both sides went down at once." end
    if team == nil then return "" end

    return teams.side_name(team.key) .. " won."
end

local PAINT_PARTS = { CAP, SHIRT }

local painted = {}

local function wanted_paint(localIndex)
    if OF.settings ~= nil and OF.settings.teamColours == false then return nil end

    if teams.in_play() then
        local key = teams.of(localIndex)
        if key == teams.NONE then return nil end
        local team = teams.find(key)
        if team == nil then return nil end
        return "team:" .. key, team.body or team
    end

    if localIndex == 0 then return nil end

    if OF.gamemodes == nil or OF.gamemodes.state() == OF.gamemodes.OFF then
        return nil
    end
    local mode = OF.gamemodes.current()
    if mode == nil or mode.paint == nil then return nil end
    local colour = mode.paint(localIndex)
    if colour == nil then return nil end
    return "role:" .. tostring(colour.key), colour
end

function teams.paint_wanted(localIndex)
    return (wanted_paint(localIndex))
end

function teams.painting_anybody()
    for _, entry in ipairs(OF.util.connected_players()) do
        if wanted_paint(entry.localIndex) ~= nil then return true end
    end
    return false
end

function teams.repaint(localIndex)
    if localIndex == nil then
        painted = {}
        return true
    end
    painted[localIndex] = nil
    return true
end

function teams.paint()
    for _, entry in ipairs(OF.util.connected_players()) do
        local localIndex = entry.localIndex
        local wanted, colour = wanted_paint(localIndex)
        if painted[localIndex] ~= wanted then
            local np = gNetworkPlayers[localIndex]
            if np ~= nil then
                if colour == nil then

                    if OF.util.asks(OF.charselect, "restore_palette") then
                        OF.charselect.restore_palette(np)
                    else
                        network_player_reset_override_palette(np)
                    end
                else
                    for _, part in ipairs(PAINT_PARTS) do
                        network_player_set_override_palette_color(np, part,
                            { r = colour.r, g = colour.g, b = colour.b })
                    end
                end
            end
            painted[localIndex] = wanted
        end
    end
end

hook_event(HOOK_UPDATE, teams.paint)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    painted[m.playerIndex] = nil

    teams.left(m.playerIndex)
end)

function teams.colours_on()
    return OF.settings == nil or OF.settings.teamColours ~= false
end

function teams.set_colours(value)
    if OF.settings == nil then return false end
    OF.settings.set_team_colours(value)
    return true
end

function teams.draw_sides()
    return false
end

local function seat_of_object(obj)
    if obj == nil then return nil end
    for i = 0, MAX_PLAYERS - 1 do
        local other = gMarioStates[i]
        if other ~= nil and other.marioObj == obj then return i end
    end
    return nil
end

hook_event(HOOK_ALLOW_INTERACT, function(m, obj, interactType)
    if interactType ~= INTERACT_PLAYER then return nil end

    if not teams.in_play() then return nil end
    if m == nil or m.playerIndex == nil then return nil end
    local other = seat_of_object(obj)
    if other == nil then return nil end
    if not teams.same(m.playerIndex, other) then return nil end
    return false
end)

hook_event(HOOK_ALLOW_PVP_ATTACK, function(attacker, victim)
    if attacker == nil or victim == nil then return end

    if not teams.in_play() then return end
    if not teams.same(attacker.playerIndex, victim.playerIndex) then return end

    local mode = OF.util.asks(OF.gamemodes, "current") and OF.gamemodes.current() or nil
    if mode ~= nil and type(mode.friendlyFire) == "function"
        and mode.friendlyFire() then
        return
    end
    return false
end)
