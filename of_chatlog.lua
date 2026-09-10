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
    push({ name = name, message = message, r = r, g = g, b = b })
end

chatlog.stamp = timestamp

function chatlog.add_system(message, who)

    message = OF.util.plain(message)
    push({ name = "*", message = message, r = 160, g = 160, b = 160 })
    if OF.util.asks(OF.actionlog, "record") then
        OF.actionlog.record(message, who)
    end
end

function chatlog.add_notice(message)
    if message == nil or message == "" then return false end

    push({ name = "-", message = OF.util.plain(tostring(message)),
           r = 130, g = 130, b = 145 })
    return true
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
