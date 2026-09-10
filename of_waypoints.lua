OF = OF or {}
OF.waypoints = OF.waypoints or {}

local waypoints = OF.waypoints

local WP_PREFIX = "wp_"
local FIELD_SEPARATOR = "|"
waypoints.MAX = 32

local function pack(point)
    return table.concat({
        tostring(math.floor(point.level)),
        tostring(math.floor(point.area)),
        tostring(math.floor(point.act)),
        string.format("%.1f", point.x),
        string.format("%.1f", point.y),
        string.format("%.1f", point.z),
        tostring(math.floor(point.angle)),
        point.name,
    }, FIELD_SEPARATOR)
end

local function unpack_point(packed)
    if packed == nil then return nil end
    local fields = {}

    local rest = packed
    for _ = 1, 7 do
        local sep = string.find(rest, FIELD_SEPARATOR, 1, true)
        if sep == nil then return nil end
        table.insert(fields, string.sub(rest, 1, sep - 1))
        rest = string.sub(rest, sep + 1)
    end

    local point = {
        level = tonumber(fields[1]),
        area = tonumber(fields[2]),
        act = tonumber(fields[3]),
        x = tonumber(fields[4]),
        y = tonumber(fields[5]),
        z = tonumber(fields[6]),
        angle = tonumber(fields[7]),
        name = rest,
    }
    if point.level == nil or point.x == nil then return nil end
    return point
end

function waypoints.place_of(point)
    if point == nil then return "" end
    return OF.util.level_name(point.level, point.area)
end

function waypoints.is_here(point)
    local np = gNetworkPlayers[0]
    if np == nil or point == nil then return false end
    return np.currLevelNum == point.level and np.currAreaIndex == point.area
end

function waypoints.distance_to(point)
    if not waypoints.is_here(point) then return nil end
    local m = gMarioStates[0]
    if m == nil or m.pos == nil then return nil end
    local dx = m.pos.x - (tonumber(point.x) or 0)
    local dy = m.pos.y - (tonumber(point.y) or 0)
    local dz = m.pos.z - (tonumber(point.z) or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function waypoints.describe(point)
    if point == nil then return "" end
    local text = waypoints.place_of(point)

    local act = math.floor(tonumber(point.act) or 1)
    if act > 1 then text = text .. ", " .. OF.lang.fill("act @", act) end

    local away = waypoints.distance_to(point)
    if away ~= nil then

        text = text .. ", " .. OF.lang.fill("@ away", string.format("%.0f", away))
    end
    return text
end

local LEVEL_CONSTANTS = {}
for name, value in pairs(_G) do
    if type(name) == "string" and type(value) == "number"
        and string.sub(name, 1, 6) == "LEVEL_" then
        if LEVEL_CONSTANTS[value] == nil then LEVEL_CONSTANTS[value] = name end
    end
end

function waypoints.numbers(point)
    if point == nil then return "" end
    local level = math.floor(tonumber(point.level) or 0)
    return string.format("%s %.0f %.0f  %.0f %.0f %.0f  %.0f",
        LEVEL_CONSTANTS[level] or string.format("%.0f", level),
        math.floor(tonumber(point.area) or 1),
        math.floor(tonumber(point.act) or 1),
        tonumber(point.x) or 0, tonumber(point.y) or 0, tonumber(point.z) or 0,
        math.floor(tonumber(point.angle) or 0))
end

function waypoints.list()
    local list = {}
    for slot = 1, waypoints.MAX do
        local packed = mod_storage_load(WP_PREFIX .. slot, "")
        if packed ~= nil and packed ~= "" then
            local point = unpack_point(packed)
            if point ~= nil then
                point.slot = slot
                table.insert(list, point)
            end
        end
    end
    return list
end

local function free_slot()
    for slot = 1, waypoints.MAX do
        local packed = mod_storage_load(WP_PREFIX .. slot, "")
        if packed == nil or packed == "" then return slot end
    end
    return nil
end

function waypoints.save_here(name)
    local m = gMarioStates[0]
    local np = gNetworkPlayers[0]
    if m == nil or np == nil then return nil end

    name = OF.util.plain(tostring(name or ""))

    name = string.gsub(name, "%" .. FIELD_SEPARATOR, "/")

    local slot = nil
    if name ~= "" then
        for _, existing in ipairs(waypoints.list()) do
            if existing.name == name then slot = existing.slot break end
        end
    end

    if slot == nil then slot = free_slot() end
    if slot == nil then

        local full = OF.lang.fill("All @ waypoint slots are full.", waypoints.MAX)
        if OF.util.asked_in_chat() then
            OF.util.chat("\\#ff6060\\" .. full)
        else
            OF.notify.show(full, "bad")
        end
        return nil
    end

    if name == "" then
        name = OF.util.level_name(np.currLevelNum) .. " " .. slot
    end

    local point = {
        level = np.currLevelNum,
        area = np.currAreaIndex,
        act = np.currActNum,
        x = m.pos.x, y = m.pos.y, z = m.pos.z,
        angle = m.faceAngle.y,
        name = name,
    }

    OF.util.store(WP_PREFIX .. slot, pack(point))
    point.slot = slot
    return point
end

function waypoints.delete(slot)
    return OF.util.clear(WP_PREFIX .. slot)
end

function waypoints.find_by_name(name)
    local needle = string.lower(name or "")
    if needle == "" then return nil end
    for _, point in ipairs(waypoints.list()) do
        if string.lower(point.name) == needle then return point end
    end
    for _, point in ipairs(waypoints.list()) do
        if string.sub(string.lower(point.name), 1, #needle) == needle then return point end
    end
    return nil
end

waypoints.PACKET = "wshr"
function waypoints.share_all(askerLocal)
    if not OF.perms.can("teleport_other") then
        return false, "Your rank cannot do that.", "teleport_other"
    end

    if not OF.util.is_host() then
        return false, "Only the host can share waypoints with the lobby."
    end

    local list = waypoints.list()
    if #list == 0 then return false, "There are no waypoints to share." end

    for _, point in ipairs(list) do
        OF.util.send_all({
            ofp = waypoints.PACKET,
            from = network_global_index_from_local(0),
            name = point.name,
            lvl = point.level, area = point.area, act = point.act,
            x = point.x, y = point.y, z = point.z, angle = point.angle,
        })
    end

    local who = OF.util.presser(askerLocal)
    if who ~= nil then
        OF.notify.send_all("@ shared @ waypoint(s)", "good", 5, who, #list)
    else
        OF.notify.send_all("The host shared @ waypoint(s)", "good", 5, #list)
    end
    if askerLocal ~= nil and OF.util.asks(OF.notify, "credit_named") then
        OF.notify.credit_named(askerLocal,
            OF.lang.fill("shared @ waypoint(s)", tostring(#list)))
    end
    OF.actionlog.by_hand(who,
        OF.lang.fill("shared @ waypoint(s) with the lobby", tostring(#list)))
    return true
end

local function receive(point)

    point.name = OF.util.plain(tostring(point.name or ""))
    if point.name == "" then return false end

    for _, existing in ipairs(waypoints.list()) do
        if existing.name == point.name then
            waypoints.delete(existing.slot)
            break
        end
    end

    local slot = free_slot()
    if slot == nil then return false end
    OF.util.store(WP_PREFIX .. slot, pack(point))
    return true
end

local function on_packet_receive(data)
    if data == nil or data.ofp ~= waypoints.PACKET then return end
    if not OF.util.from_host(data) then return end

    receive({
        level = data.lvl, area = data.area, act = data.act,
        x = data.x, y = data.y, z = data.z, angle = data.angle,
        name = data.name,
    })
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)

function waypoints.chat_load(msg)
    if not OF.perms.can("waypoint_use") then
        OF.util.chat("\\#ff6060\\" .. OF.lang.t("Your rank cannot use waypoints."))
        return true
    end

    local list = waypoints.list()
    if msg == nil or msg == "" then
        if #list == 0 then
            OF.util.chat(OF.lang.t("No waypoints saved. Use /wpsave [name]."))
            return true
        end
        OF.util.chat(OF.lang.t("Waypoints:"))
        for _, point in ipairs(list) do
            djui_chat_message_create("  " .. OF.util.accent() .. point.name
                .. "\\#808080\\ - " .. waypoints.describe(point))
        end
        return true
    end

    local wanted = string.match(msg, "^show%s+(.+)$")
    if wanted ~= nil or msg == "show" then
        if wanted == nil then
            if #list == 0 then
                OF.util.chat(OF.lang.t("No waypoints saved. Use /wpsave [name]."))
                return true
            end
            for _, point in ipairs(list) do
                djui_chat_message_create("  " .. OF.util.accent() .. point.name
                    .. "\\#808080\\  " .. waypoints.numbers(point))
            end
            return true
        end

        local found = waypoints.find_by_name(wanted)
        if found == nil then
            OF.util.chat("\\#ff6060\\"
                .. OF.lang.fill("No waypoint called '@'.", tostring(wanted)))
            return true
        end
        OF.util.chat(OF.util.accent() .. found.name
            .. "\\#dcdcdc\\  " .. waypoints.describe(found))
        djui_chat_message_create("  \\#808080\\" .. waypoints.numbers(found))
        return true
    end

    local point = waypoints.find_by_name(msg)
    if point == nil then
        OF.util.chat("\\#ff6060\\"
            .. OF.lang.fill("No waypoint called '@'.", tostring(msg)))
        return true
    end
    OF.net.teleport_to_position(point)
    return true
end

hook_chat_command("wpl",
    "- go to a saved waypoint, none to list them, or 'show <name>' for its numbers",
    function(msg) return waypoints.chat_load(msg) end)
hook_chat_command("wpload",
    "- go to a saved waypoint, none to list them, or 'show <name>' for its numbers",
    function(msg) return waypoints.chat_load(msg) end)

function waypoints.chat_save(msg)
    if not OF.perms.can("waypoint_save") then
        OF.util.chat("\\#ff6060\\" .. OF.lang.t("Your rank cannot save waypoints."))
        return true
    end

    local point = waypoints.save_here(msg)
    if point == nil then return true end
    OF.util.chat(OF.lang.t("Saved waypoint") .. " " .. OF.util.accent() .. point.name)
    return true
end

hook_chat_command("wpsave", "- save your position as a waypoint",
    function(msg) return waypoints.chat_save(msg) end)
hook_chat_command("wps", "- save your position as a waypoint",
    function(msg) return waypoints.chat_save(msg) end)
