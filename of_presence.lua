OF = OF or {}
OF.presence = OF.presence or {}

local presence = OF.presence

local REFRESH_FRAMES = 15
local sinceRefresh = 0

local utilAsks = nil

local function asks(from, name)
    local fn = utilAsks
    if fn == nil then
        fn = OF.util.asks
        utilAsks = fn
    end
    return fn(from, name)
end

local MAX_DESCRIPTION = 19
local JOIN = " - "
local LIST_CLOCK_AFTER = 60 * 30

local function secret_roles()
    if not asks(OF.gamemodes, "current") then return false end
    local mode = OF.gamemodes.current()
    return mode ~= nil and mode.secretRoles == true
end

local function joined(...)
    local parts = {}
    for _, part in ipairs({ ... }) do
        if part ~= nil and part ~= "" then table.insert(parts, tostring(part)) end
    end
    return table.concat(parts, JOIN)
end

function presence.compose(side, role, score)
    local full = joined(side, role, score)
    if #full <= MAX_DESCRIPTION then return full end

    local withoutScore = joined(side, role)
    if #withoutScore <= MAX_DESCRIPTION then return withoutScore end

    local roleOnly = joined(role)
    if #roleOnly <= MAX_DESCRIPTION then return roleOnly end
    return string.sub(roleOnly, 1, MAX_DESCRIPTION)
end

function presence.describe(localIndex)

    if asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex) then
        return "jailed", 255, 120, 120
    end
    if asks(OF.spectate, "is_spectating") and OF.spectate.is_spectating(localIndex) then
        return "watching", 170, 170, 255
    end
    if asks(OF.mute, "is_muted") and OF.mute.is_muted(localIndex) then
        return "muted", 255, 180, 90
    end
    if asks(OF.idle, "is_idle") and OF.idle.is_idle(localIndex) then

        local text = nil
        local since = asks(OF.idle, "away_for") and OF.idle.away_for(localIndex)
        if since ~= nil and since >= LIST_CLOCK_AFTER then
            text = asks(OF.idle, "away_text") and OF.idle.away_text(localIndex)
        end
        if text == nil or text == "" then text = "away" end
        return text, 170, 170, 170
    end

    if asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running() then
        local role = OF.gamemodes.role(localIndex)
        local side = asks(OF.teams, "in_play") and OF.teams.in_play()
            and OF.teams.name_of(localIndex) or ""
        if role ~= nil and role ~= "" then
            local score = gPlayerSyncTable[localIndex].ofScore
            if score ~= nil and score <= 0 then score = nil end

            if localIndex ~= 0 and secret_roles() then
                role = "playing"
                score = nil
            end
            local text = presence.compose(side, role, score)

            if side ~= "" then
                local r, g, b = OF.teams.color_of(localIndex)
                return text, r, g, b
            end

            local gold = OF.util.gold()
            return text, gold.r, gold.g, gold.b
        end
        return "sitting this one out", 150, 150, 150
    end

    if asks(OF.speedrun, "is_excluded") and OF.speedrun.is_excluded(localIndex) then
        return "not racing", 150, 150, 150
    end

    if OF.perms == nil or OF.perms.tier == nil then return nil end
    local tier = OF.perms.tier(localIndex)
    if tier ~= nil and tier ~= OF.TIER.NORMAL then
        local r, g, b = 200, 200, 200
        if asks(OF.perms, "tier_color") then r, g, b = OF.perms.tier_color(tier) end
        return OF.perms.tier_name(tier), r, g, b
    end
    return "", 200, 200, 200
end

function presence.lobby_line()
    if asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running() then
        local mode = OF.gamemodes.current()
        local text = mode ~= nil and mode.name or "a round"
        local place = asks(OF.arena, "find")
            and OF.arena.find(gGlobalSyncTable.ofArenaPlace) or nil
        if place ~= nil then text = text .. " in " .. place.name end

        local left = OF.gamemodes.time_left()
        if left ~= nil then text = text .. "  -  " .. left .. "s left" end
        return text
    end

    if asks(OF.rounds, "is_running") and OF.rounds.is_running() then
        local next = gGlobalSyncTable.ofQueueNext
        if next ~= nil and next ~= "" then return "Between rounds - next: " .. next end
        return "Between rounds"
    end

    if asks(OF.speedrun, "state") and OF.speedrun.state() ~= OF.speedrun.OFF then
        return "A speedrun is on"
    end

    return "Free play"
end

function presence.location(localIndex)
    if not (asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running()) then
        return nil
    end
    local role = OF.gamemodes.role(localIndex)
    if role == nil or role == "" then return nil end
    local mode = OF.gamemodes.current()
    if mode == nil then return nil end

    local name = OF.lang.t(mode.name)

    if localIndex ~= 0 and secret_roles() then return name end
    if not asks(OF.gamemodes, "standing") then return name end
    local standing = OF.gamemodes.standing(localIndex)
    if standing == nil or standing == "" then return name end
    return name .. "  " .. OF.lang.t(standing)
end

local wrote = {}

local CLEARED = ""
local function refresh()
    sinceRefresh = sinceRefresh + 1
    if sinceRefresh < REFRESH_FRAMES then return end
    sinceRefresh = 0

    for _, entry in ipairs(OF.util.connected_players()) do
        local index = entry.localIndex
        local text, r, g, b = presence.describe(index)
        network_player_set_description(entry.np, text or CLEARED,
            r or 200, g or 200, b or 200, 255)

        local where = presence.location(index)
        if where ~= nil then
            wrote[index] = where
            network_player_set_override_location(entry.np, where)
        elseif wrote[index] ~= nil then
            wrote[index] = nil
            network_player_set_override_location(entry.np, CLEARED)
        end
    end
end

hook_event(HOOK_UPDATE, refresh)

local toldAboutBindings = false

local function report_bindings()
    if toldAboutBindings then return end
    local missing = OF.util.missing_bindings()

    if #missing == 0 then return end
    toldAboutBindings = true
    OF.util.chat("\\#ffb060\\Your Coop DX is missing "
        .. #missing .. " call(s) this mod uses. Everything else still works.")
    for _, name in ipairs(missing) do
        djui_chat_message_create("  \\#808080\\" .. name)
    end
end

hook_event(HOOK_ON_SYNC_VALID, report_bindings)
