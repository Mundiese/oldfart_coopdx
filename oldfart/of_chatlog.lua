OF = OF or {}
OF.chatlog = OF.chatlog or {}

local chatlog = OF.chatlog

chatlog.MAX_ENTRIES = 300
chatlog.entries = chatlog.entries or {}

local uptimeFrames = 0

local function timestamp()
    local now = OF.util.optional("get_date_and_time", nil)
    if now ~= nil and type(now.hour) == "number" and type(now.minute) == "number" then

        return string.format("%02.0f:%02.0f", now.hour % 24, now.minute % 60)
    end
    local seconds = math.floor(uptimeFrames / 30)
    return string.format("%02.0f:%02.0f", math.floor(seconds / 60) % 100, seconds % 60)
end

local function push(entry)
    entry.time = timestamp()
    table.insert(chatlog.entries, entry)
    while #chatlog.entries > chatlog.MAX_ENTRIES do
        table.remove(chatlog.entries, 1)
    end
end

function chatlog.add_player(localIndex, message)
    local np = gNetworkPlayers[localIndex]
    local name = "?"
    local r, g, b = 255, 255, 255
    if np ~= nil then
        name = OF.util.plain(np.name)
        r, g, b = OF.util.name_colour()
    end

    push({ kind = "player", name = name, message = message, r = r, g = g, b = b,
           nameRaw = np ~= nil and OF.util.name_safe(np.name) or nil })
end

chatlog.stamp = timestamp

function chatlog.add_system(message, who)

    message = OF.util.plain(message)
    push({ kind = "system", name = "*", message = message, r = 160, g = 160, b = 160 })
    if OF.util.asks(OF.actionlog, "record") then
        OF.actionlog.record(message, who)
    end
end

function chatlog.add_notice(message)
    if message == nil or message == "" then return false end

    push({ kind = "notice", name = "-", message = OF.util.plain(tostring(message)),
           r = 130, g = 130, b = 145 })
    return true
end

chatlog.PRESENCE = {

    joined  = { line = "> @ joined", log = "@ joined", role = "joined",
                r = 160, g = 255, b = 160 },
    left    = { line = "> @ left", log = "@ left", role = "left",
                r = 255, g = 96, b = 96 },
    dropped = { line = "> @ has been coopnetted", log = "@ has been coopnetted",
                role = "left", r = 255, g = 96, b = 96 },
}

function chatlog.presence_words(kind, name)
    local said = chatlog.PRESENCE[kind]
    if said == nil then return nil end
    local marked = OF.util.chat_name(tostring(name or "?"))
    return (string.gsub(OF.lang.get(said.line), "@", function() return marked end, 1))
end
function chatlog.add_presence(kind, name, who)
    local said = chatlog.PRESENCE[kind]
    if said == nil then return false end
    local raw = tostring(name or "?")
    name = OF.util.plain(raw)
    push({ kind = kind, name = "", message = OF.lang.fill(said.line, name),
           r = said.r, g = said.g, b = said.b, nameRaw = OF.util.name_safe(raw) })
    if OF.util.asks(OF.actionlog, "record") then
        OF.actionlog.record(OF.lang.fill(said.log, name), who)
    end
    return true
end

function chatlog.who_of(entry)
    if entry == nil then return "" end
    local name = tostring(entry.name or "")
    if entry.kind ~= "player" and (entry.kind ~= nil or name == "*" or name == "-") then
        return ""
    end
    if name == "" then return "" end
    return name .. ":"
end

function chatlog.clear()
    chatlog.entries = {}
    chatlog.add_system("chat log cleared")
end

local function on_chat_message(m, message)
    if m ~= nil then
        chatlog.add_player(m.playerIndex, message)
    end

end

hook_event(HOOK_ON_CHAT_MESSAGE, on_chat_message)

hook_event(HOOK_UPDATE, function()
    uptimeFrames = uptimeFrames + 1
    if OF.util.asks(OF.actionlog, "watch_room") then OF.actionlog.watch_room() end
end)
