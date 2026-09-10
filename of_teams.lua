OF = OF or {}
OF.teams = OF.teams or {}

local teams = OF.teams

teams.NONE = ""
teams.LIST = {
    { key = "red",  name = "Red",  r = 255, g = 90,  b = 90 },
    { key = "blue", name = "Blue", r = 110, g = 160, b = 255 },
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

function teams.name_of(localIndex)
    local team = teams.find(teams.of(localIndex))
    if team == nil then return "" end
    return team.name
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

function teams.min_room()
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

    local packed = OF.util.joined(OF.stats.TOP_KEYS)
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

    for place, entry in ipairs(order) do
        local side = ((step_of(place, snaked) + turn) % 2) + 1
        OF.util.publish_row(entry.localIndex, "ofTeam", teams.LIST[side].key)
    end
    return true
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

function teams.begin(mode, players)
    if not OF.util.is_host() then return teams.in_play() end
    if mode == nil or not mode.teams then
        wipe()
        return false
    end
    if #players < teams.min_room() then

        wipe()

        if OF.util.asks(OF.notify, "send_all") then
            OF.notify.send_all("Sides need @ players - playing it as a free-for-all.",
                "info", 6, teams.min_room())
        end
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

function teams.score_banner(red, blue)
    local plain = OF.lang.fill("RED @   -   BLUE @", red, blue)
    local redTeam, blueTeam = teams.find("red"), teams.find("blue")
    if redTeam == nil or blueTeam == nil then return plain, nil end

    return plain, {
        { text = OF.lang.fill("RED @", red),
          r = redTeam.r, g = redTeam.g, b = redTeam.b },
        { text = "   -   ", r = 220, g = 220, b = 220 },
        { text = OF.lang.fill("BLUE @", blue),
          r = blueTeam.r, g = blueTeam.g, b = blueTeam.b },
    }
end

function teams.result_text(red, blue)
    local winner, r, b = teams.leader(red, blue)
    if winner == nil then
        return "A draw, " .. r .. " each."
    end
    return winner.name .. " wins it, " .. math.max(r, b)
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

function teams.assign_roles(players, redRole, blueRole)
    for _, entry in ipairs(players) do
        OF.gamemodes.set_role(entry.localIndex, teams.role_for(entry.localIndex, redRole, blueRole))
    end
end

function teams.role_for(localIndex, redRole, blueRole)
    if teams.of(localIndex) == "red" then return redRole end
    return blueRole
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
        if #players < teams.min_room() then return false end
        teams.balance(players)
        return true
    end

    local gone = teams.hollow()
    if gone == nil then return false end
    OF.gamemodes.abandon("@ have nobody left in the lobby.", gone.name)
    return true
end

function teams.survival_text(team)
    if team == false then return "Both sides went down at once." end
    if team == nil then return "" end
    return team.name .. " takes it - the last side standing."
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
        return "team:" .. key, team
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

local ARROW_ABOVE = 250
local ARROW_LENGTH = 150
local ARROW_WIDTH = 4
local ARROW_ALPHA = 220

local function beside_me(localIndex)
    local me = gNetworkPlayers[0]
    local np = gNetworkPlayers[localIndex]
    if me == nil or np == nil or not np.connected then return false end
    return np.currLevelNum == me.currLevelNum
        and np.currAreaIndex == me.currAreaIndex
end

local function draw_sides()
    if not teams.in_play() then return false end
    if not teams.colours_on() then return false end
    if djui_hud_world_pos_to_screen_pos == nil then return false end

    local drawn = 0
    for _, entry in ipairs(OF.gamemodes.participants()) do
        local li = entry.localIndex
        local team = teams.find(teams.of(li))

        local m = team ~= nil and gMarioStates[li] or nil

        if m ~= nil and m.pos ~= nil and beside_me(li) then
            OF.util.world_arrow(
                { x = m.pos.x, y = m.pos.y + ARROW_ABOVE, z = m.pos.z },
                ARROW_LENGTH, ARROW_WIDTH, team.r, team.g, team.b, ARROW_ALPHA)
            drawn = drawn + 1
        end
    end
    return drawn > 0
end

function teams.draw_sides()
    return draw_sides()
end

hook_event(HOOK_ON_HUD_RENDER, function()

    if OF.util.menu_has_screen() then return end
    draw_sides()
end)

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
    return false
end)
