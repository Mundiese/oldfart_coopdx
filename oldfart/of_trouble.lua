OF = OF or {}
OF.trouble = OF.trouble or {}

local trouble = OF.trouble

trouble.PACKET_REFUSED = "ofNo"
trouble.STUCK_SECONDS = 20

local MOVED = 40

local PUSHED = 20

local stuckSeconds = {}
local lastAt = {}
local toldStuck = {}
local toldThem = {}
local unreachedSeconds = {}
local toldUnreached = {}

local function forget(localIndex)
    stuckSeconds[localIndex] = nil
    lastAt[localIndex] = nil
    toldStuck[localIndex] = nil
    toldThem[localIndex] = nil
    unreachedSeconds[localIndex] = nil
    toldUnreached[localIndex] = nil
end

local function trying(m)
    if m == nil then return false end
    local c = m.controller
    if c == nil then return false end
    if (tonumber(c.buttonDown) or 0) ~= 0 then return true end
    return (tonumber(c.stickMag) or 0) > PUSHED
end

local function held_by_something(localIndex)
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex) then
        return true
    end
    if OF.util.asks(OF.idle, "is_idle") and OF.idle.is_idle(localIndex) then
        return true
    end
    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return true
    end
    return false
end

function trouble.stuck_for(localIndex)
    if not OF.util.is_host() then return nil end
    if localIndex == nil then return nil end
    local seconds = stuckSeconds[localIndex]
    if seconds == nil or seconds <= 0 then return nil end
    return seconds
end

function trouble.is_stuck(localIndex)
    local seconds = trouble.stuck_for(localIndex)
    return seconds ~= nil and seconds >= trouble.STUCK_SECONDS
end

local function say_stuck(localIndex, seconds)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return end
    local name = OF.util.plain(np.name)
    if name == "" then return end

    if not toldStuck[localIndex] then
        toldStuck[localIndex] = true

        if OF.util.asks(OF.actionlog, "auto") then
            OF.actionlog.auto(OF.lang.fill("@ looks stuck", name))
        end
    end

    if not toldThem[localIndex] then
        toldThem[localIndex] = true
        if trouble.would("stuck", "@ would have been told about /unstick", name) then
            OF.notify.send_to(network_global_index_from_local(localIndex),
                "Stuck? Type /unstick and the level reloads around you", "info", 8)
        end
    end
end

local function watch_stuck()
    if not OF.util.is_host() then return end

    for i = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        local m = gMarioStates[i]
        if np == nil or not np.connected or m == nil
            or not np.currPositionValid or held_by_something(i) then

            forget(i)
        else
            local was = lastAt[i]
            lastAt[i] = { x = m.pos.x, y = m.pos.y, z = m.pos.z }

            local moved = was == nil
                or math.abs(m.pos.x - was.x) > MOVED
                or math.abs(m.pos.y - was.y) > MOVED
                or math.abs(m.pos.z - was.z) > MOVED

            if moved or not trying(m) then

                stuckSeconds[i] = 0
                toldStuck[i] = nil
                toldThem[i] = nil
            else
                stuckSeconds[i] = (stuckSeconds[i] or 0) + 1
                if stuckSeconds[i] >= trouble.STUCK_SECONDS then
                    say_stuck(i, stuckSeconds[i])
                end
            end
        end
    end
end

trouble.UNREACHABLE_SECONDS = 15

function trouble.unreachable_for(localIndex)
    if not OF.util.is_host() then return nil end
    if localIndex == nil then return nil end
    local seconds = unreachedSeconds[localIndex]
    if seconds == nil or seconds <= 0 then return nil end
    return seconds
end

function trouble.out_of_reach(localIndex)
    local seconds = trouble.unreachable_for(localIndex)
    return seconds ~= nil and seconds >= trouble.UNREACHABLE_SECONDS
end

local function watch_reach()
    if not OF.util.is_host() then return end
    if not OF.util.asks(OF.pass, "unreachable") then return end

    local out = {}
    for _, localIndex in ipairs(OF.pass.unreachable()) do out[localIndex] = true end

    for i = 1, MAX_PLAYERS - 1 do
        local np = gNetworkPlayers[i]
        if np == nil or not np.connected or not out[i] then
            unreachedSeconds[i] = 0
            toldUnreached[i] = nil
        else
            unreachedSeconds[i] = (unreachedSeconds[i] or 0) + 1
            if unreachedSeconds[i] >= trouble.UNREACHABLE_SECONDS and not toldUnreached[i] then
                toldUnreached[i] = true
                local name = OF.util.plain(np.name)
                if name ~= "" then

                    OF.notify.show("@ has not finished saying hello", "warn", 7, name)
                    if OF.util.asks(OF.actionlog, "auto") then
                        OF.actionlog.auto(OF.lang.fill("@ is out of reach", name))
                    end
                end
            end
        end
    end
end

trouble.STILL_ON_SECONDS = 300

trouble.STANDING = {
    {
        key = "hold",
        on = function()
            if not OF.util.asks(OF.lockdown, "held_by_host") then return false end
            if not OF.lockdown.held_by_host() then return false end

            return true
        end,
        said = "The lobby is being held - nobody but you can do anything",
        toast = "The lobby has been held @ now",
        where = "Control, the row under Moderation",
    },
    {
        key = "quiet",
        on = function()
            return OF.util.asks(OF.mute, "quiet_on") and OF.mute.quiet_on()
        end,
        said = "Quiet mode is on - most of the lobby cannot talk",
        toast = "Quiet mode has been on @ now",
        where = "Control, Moderation, Muted players says which rank",
    },
}

local standingSince = {}
local toldStanding = {}

function trouble.standing_for(key)
    if not OF.util.is_host() then return nil end
    local since = standingSince[key]
    if since == nil then return nil end
    return since
end

function trouble.left_on(key)
    local seconds = trouble.standing_for(key)
    return seconds ~= nil and seconds >= trouble.STILL_ON_SECONDS
end

local function watch_standing()
    if not OF.util.is_host() then
        standingSince = {}
        toldStanding = {}
        return
    end

    for _, entry in ipairs(trouble.STANDING) do
        if entry.on() then
            standingSince[entry.key] = (standingSince[entry.key] or 0) + 1
            if standingSince[entry.key] >= trouble.STILL_ON_SECONDS
                and not toldStanding[entry.key] then
                toldStanding[entry.key] = true

                OF.notify.show(entry.toast, "warn", 7,
                    OF.lang.fill("@ minutes",
                        math.floor(standingSince[entry.key] / 60)))
            end
        else
            standingSince[entry.key] = nil
            toldStanding[entry.key] = nil
        end
    end
end

trouble.MOST_REFUSALS = 40

local REFUSE_RATE = 30
local lastRefusedAt = -9999

trouble.refusals = trouble.refusals or {}

local function now_frame()
    return OF.util.optional("get_global_timer", 0) or 0
end

function trouble.note(feature, name)
    if feature == nil or feature == "" then return false end
    name = OF.util.plain(tostring(name or "?"))

    for index, entry in ipairs(trouble.refusals) do
        if entry.feature == feature and entry.name == name then
            entry.count = entry.count + 1
            entry.at = now_frame()
            table.remove(trouble.refusals, index)
            table.insert(trouble.refusals, 1, entry)
            return true
        end
    end

    table.insert(trouble.refusals, 1,
        { feature = feature, name = name, count = 1, at = now_frame() })
    while #trouble.refusals > trouble.MOST_REFUSALS do
        table.remove(trouble.refusals)
    end
    return true
end

function trouble.refused(feature)
    if feature == nil or feature == "" then return false end

    local frame = now_frame()
    if frame - lastRefusedAt < REFUSE_RATE then return false end
    lastRefusedAt = frame

    local np = gNetworkPlayers[0]
    local name = np ~= nil and OF.util.plain(np.name) or "somebody"
    if OF.util.is_host() then return trouble.note(feature, name) end
    return OF.util.send_to_host({ ofp = trouble.PACKET_REFUSED,
        f = tostring(feature) })
end

trouble.OFF = "off"
trouble.OBSERVE = "observe"
trouble.ON = "on"
trouble.MODES = { trouble.OFF, trouble.OBSERVE, trouble.ON }

local MODE_NAMES = {
    [trouble.OFF] = "Off",
    [trouble.OBSERVE] = "Just tell me",
    [trouble.ON] = "On",
}

function trouble.mode_name(mode)
    return MODE_NAMES[mode] or MODE_NAMES[trouble.ON]
end

function trouble.is_mode(mode)
    return mode ~= nil and MODE_NAMES[mode] ~= nil
end

trouble.rules = trouble.rules or {}

local ruleCount = 0
local sessionMode = {}
local observedCount = {}
local observedAt = {}

trouble.TELL_RATE = 300

function trouble.automatic(def)
    if def == nil or type(def) ~= "table" then return false end
    if def.key == nil or def.key == "" then return false end
    if trouble.rules[def.key] ~= nil then return false end

    ruleCount = ruleCount + 1
    def.order = ruleCount
    if not trouble.is_mode(def.default) then def.default = trouble.ON end
    trouble.rules[def.key] = def
    return true
end

function trouble.mode(key)
    local def = trouble.rules[key]
    if def == nil then return trouble.ON end
    if def.get ~= nil then
        local mode = def.get()
        if trouble.is_mode(mode) then return mode end
        return def.default
    end
    return sessionMode[key] or def.default
end

function trouble.set_mode(key, mode)
    local def = trouble.rules[key]
    if def == nil then return false end
    if not trouble.is_mode(mode) then return false end

    local was = trouble.mode(key)
    local ok = true
    if def.set ~= nil then
        ok = def.set(mode) ~= false
    else
        sessionMode[key] = mode
    end

    if ok and mode ~= was then
        observedCount[key] = nil
        observedAt[key] = nil
    end
    return ok
end

trouble.CYCLE_ACTION = "rulecycle"
trouble.SEND_ACTION = "rulesend"
trouble.hostModes = {}

local function modes_text(only)
    local parts = {}
    for _, def in ipairs(trouble.rule_list()) do
        if only == nil or only == def.key then
            parts[#parts + 1] = def.key .. "=" .. trouble.mode(def.key)
        end
    end
    return table.concat(parts, ",")
end

function trouble.take_modes(text)
    for key, mode in string.gmatch(tostring(text or ""), "([%w_]+)=([%w_]+)") do
        if trouble.is_mode(mode) then trouble.hostModes[key] = mode end
    end
    return true
end

function trouble.shown_mode(key)
    if not OF.util.is_host() and trouble.hostModes[key] ~= nil then
        return trouble.hostModes[key]
    end
    return trouble.mode(key)
end

hook_event(HOOK_ON_MODS_LOADED, function()
    if not OF.util.asks(OF.net, "register_cohost_action") then return end
    OF.net.register_cohost_action(trouble.CYCLE_ACTION, "settings", function(_, key)
        key = tostring(key or "")
        if trouble.rules[key] == nil then return false, "No such rule." end
        local ok = trouble.set_mode(key, trouble.next_mode(trouble.mode(key)))
        if not ok then return false, "That rule would not move." end
        return true, nil, modes_text(key)
    end, trouble.take_modes)
    OF.net.register_cohost_action(trouble.SEND_ACTION, "settings", function()
        return true, nil, modes_text()
    end, trouble.take_modes)
end)

function trouble.next_mode(mode)
    for index, value in ipairs(trouble.MODES) do
        if value == mode then
            return trouble.MODES[(index % #trouble.MODES) + 1]
        end
    end
    return trouble.MODES[1]
end

function trouble.rule_list()
    local list = {}
    for _, def in pairs(trouble.rules) do table.insert(list, def) end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

function trouble.rules_changed()
    local count = 0
    for key in pairs(trouble.rules) do
        if trouble.mode(key) ~= trouble.ON then count = count + 1 end
    end
    return count
end

function trouble.observed(key)
    return observedCount[key] or 0
end

function trouble.would(key, sentence, value, second)
    local mode = trouble.mode(key)
    if mode == trouble.ON then return true end
    if mode == trouble.OFF then return false end

    observedCount[key] = (observedCount[key] or 0) + 1
    if not OF.util.is_host() then return false end

    local frame = now_frame()
    if frame - (observedAt[key] or -9999) >= trouble.TELL_RATE then
        observedAt[key] = frame
        if sentence ~= nil and sentence ~= "" then

            OF.notify.show(sentence, "quiet", 6, value, second)
            if OF.util.asks(OF.actionlog, "auto") then
                OF.actionlog.auto(OF.lang.fill(sentence, value, second))
            end
        end
    end
    return false
end

trouble.automatic({
    key = "stuck",
    name = "Offer a stuck player the way out",
    help = "a player fighting the same wall for "
        .. string.format("%.0f", trouble.STUCK_SECONDS)
        .. " seconds is sent one line saying to type /unstick",
    default = trouble.ON,
})

local CASE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
trouble.CASE_LENGTH = 3

local CASE_SPACE = 1
for _ = 1, trouble.CASE_LENGTH do CASE_SPACE = CASE_SPACE * #CASE_ALPHABET end

trouble.MOST_CASES = 40

trouble.cases = trouble.cases or {}

local caseCounter = 0

local function case_code(n)
    local base = #CASE_ALPHABET
    local out = ""
    for _ = 1, trouble.CASE_LENGTH do
        local digit = n % base
        out = string.sub(CASE_ALPHABET, digit + 1, digit + 1) .. out
        n = math.floor(n / base)
    end
    return out
end

function trouble.open_case(kind, name, detail)
    if not OF.util.is_host() then return nil end
    if kind == nil or kind == "" then return nil end

    caseCounter = caseCounter + 1
    local code = case_code(caseCounter % CASE_SPACE)

    table.insert(trouble.cases, 1, {
        code = code,
        kind = OF.util.plain(tostring(kind)),
        name = OF.util.plain(tostring(name or "?")),
        detail = detail ~= nil and OF.util.plain(tostring(detail)) or nil,
        at = now_frame(),
    })
    while #trouble.cases > trouble.MOST_CASES do
        table.remove(trouble.cases)
    end
    return code
end

local CASE_FOLD = { I = "1", L = "1", O = "0" }

function trouble.case(code)
    if code == nil then return nil end
    code = string.upper(tostring(code))
    code = string.gsub(code, "[^0-9A-Z]", "")
    for from, to in pairs(CASE_FOLD) do
        code = string.gsub(code, from, to)
    end
    if #code ~= trouble.CASE_LENGTH then return nil end

    for _, entry in ipairs(trouble.cases) do
        if entry.code == code then return entry end
    end
    return nil
end

function trouble.case_suffix(code)
    if code == nil or code == "" then return "" end
    return " " .. OF.lang.fill("(case @)", tostring(code))
end

function trouble.case_count()
    return #trouble.cases
end

function trouble.why_not(localIndex)
    if localIndex == nil then return nil end
    if OF.util.asks(OF.jail, "is_jailed") and OF.jail.is_jailed(localIndex) then
        return "jailed"
    end
    if OF.util.asks(OF.spectate, "is_spectating")
        and OF.spectate.is_spectating(localIndex) then
        return "watching"
    end
    if OF.util.asks(OF.speedrun, "is_excluded")
        and OF.speedrun.is_excluded(localIndex) then
        return "sitting out"
    end

    if OF.util.asks(OF.idle, "left_out") and OF.idle.left_out(localIndex) then
        return "away from the keyboard"
    end
    return nil
end

function trouble.sidelined()
    local list = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local why = trouble.why_not(entry.localIndex)
        if why ~= nil then
            table.insert(list, {
                localIndex = entry.localIndex,
                name = OF.util.plain(entry.np.name),
                why = why,
                muted = OF.util.asks(OF.mute, "is_muted")
                    and OF.mute.is_muted(entry.localIndex) or false,
            })
        end
    end
    return list
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= trouble.PACKET_REFUSED then return end
    if not OF.util.is_host() then return end

    local li = OF.util.asked_by(data)
    if li == nil then return end
    local np = gNetworkPlayers[li]
    if np == nil then return end

    local feature = tostring(data.f or "")
    if OF.perms.DEFAULTS == nil or OF.perms.DEFAULTS[feature] == nil then return end

    trouble.note(feature, OF.util.plain(np.name))
end)

local frames = 0
hook_event(HOOK_UPDATE, function()
    frames = frames + 1
    if frames % 30 ~= 0 then return end
    watch_stuck()
    watch_reach()
    watch_standing()
end)

hook_event(HOOK_ON_PLAYER_DISCONNECTED, function(m)
    if m == nil then return end
    forget(m.playerIndex)
end)

hook_event(HOOK_ON_PLAYER_CONNECTED, function(m)
    if m == nil then return end
    forget(m.playerIndex)
end)
