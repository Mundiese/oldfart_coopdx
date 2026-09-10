OF = OF or {}
OF.notes = OF.notes or {}

local notes = OF.notes

local PREFIX = "note_"
local NAME_PREFIX = "noten_"
function notes.get(playerId)
    if playerId == nil then return "" end
    return mod_storage_load(OF.util.storage_key(PREFIX, playerId), "")
end

function notes.of_player(localIndex)
    return notes.get(OF.util.player_id(localIndex))
end

function notes.has(localIndex)
    return notes.of_player(localIndex) ~= ""
end

function notes.set(localIndex, text)
    if not OF.perms.can("ban") then return false, "Your rank cannot do that.", "ban" end

    local playerId = OF.util.player_id(localIndex)
    if playerId == nil then return false, "That player has no stable id." end

    local np = gNetworkPlayers[localIndex]
    if text == nil or text == "" then
        mod_storage_remove(OF.util.storage_key(PREFIX, playerId))
        mod_storage_remove(OF.util.storage_key(NAME_PREFIX, playerId))

        OF.notify.show("Cleared the note on @.", "info", 4,
            OF.util.plain(np and np.name or playerId))
        return true
    end

    OF.util.store(OF.util.storage_key(PREFIX, playerId),
        OF.util.storage_value(text))
    if np ~= nil then
        OF.util.store(OF.util.storage_key(NAME_PREFIX, playerId),
            OF.util.storage_value(np.name))
    end
    OF.notify.show("Noted about @: @", "info", 5,
        OF.util.plain(np and np.name or playerId), OF.util.plain(text))
    return true
end

function notes.all()
    local list = {}
    local storage = mod_storage_load_all()
    if storage == nil then return list end

    local here = {}
    for _, entry in ipairs(OF.util.connected_players()) do
        local id = OF.util.player_id(entry.localIndex)
        if id ~= nil then here[id] = entry end
    end

    for key, value in pairs(storage) do
        local playerId = string.match(key, "^" .. PREFIX .. "(.+)$")
            if playerId ~= nil then playerId = OF.util.storage_unescape(playerId) end
        if playerId ~= nil then
            local seat = here[playerId]
            table.insert(list, {
                id = playerId,
                text = tostring(value),
                name = mod_storage_load(
                    OF.util.storage_key(NAME_PREFIX, playerId), playerId),
                here = seat ~= nil and seat.localIndex or nil,
                now = seat ~= nil and OF.util.plain(seat.np.name) or nil,
            })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local countMemo = {}

function notes.count()
    return OF.util.stored_count(countMemo, notes.all)
end

function notes.who(entry)
    if entry == nil then return "" end
    local name = OF.util.plain(entry.name or entry.id or "")
    if entry.now == nil or entry.now == name then return name end
    return OF.lang.fill("@ - here now as @", name, entry.now)
end

function notes.clear(playerId)
    if not OF.perms.can("ban") then return false end
    mod_storage_remove(OF.util.storage_key(PREFIX, playerId))
    mod_storage_remove(OF.util.storage_key(NAME_PREFIX, playerId))
    return true
end

hook_event(HOOK_ON_PLAYER_CONNECTED, function(m)
    if m == nil or m.playerIndex == 0 then return end
    if not OF.util.is_host() then return end

    local text = notes.of_player(m.playerIndex)
    if text == "" then return end

    local np = gNetworkPlayers[m.playerIndex]
    OF.notify.show("Note on @: @", "warn", 8,
        OF.util.plain(np.name), OF.util.plain(text))
    OF.chatlog.add_system("note on " .. np.name .. ": " .. text)
end)

local function said(panel, text, help)
    local built = panel.label_row(text)
    built.walk = true
    return panel.with_help(built, help)
end

function notes.build_page(panel)
    local rows = { said(panel, "Private to you. Players never see these.",
        "kept on this machine, and not sent anywhere") }
    local list = notes.all()

    if #list == 0 then
        table.insert(rows, said(panel, "Nothing written down yet.",
            "a note is written against one name at a time"))
        table.insert(rows, said(panel, "Open a player and use 'Write a note'.",
            "the Players list is the way to one"))
    else
        for _, entry in ipairs(list) do
            local id = entry.id
            table.insert(rows, panel.label_row(notes.who(entry) .. ": " .. entry.text))
            table.insert(rows, panel.confirm_row("delnote" .. id,
                "   Clear that note", 255, 140, 90, function()
                    notes.clear(id)
                end))
        end
    end

    table.insert(rows, panel.back_row("control"))
    return rows
end

function notes.note_row(panel, localIndex)
    local text = OF.settings.screenMessage or ""
    local existing = notes.of_player(localIndex)

    if existing ~= "" then
        return panel.gated_row("ban", "Note: " .. existing .. "   (click to clear)",
            255, 200, 120, function()
                OF.util.report(notes.set(localIndex, ""))
            end)
    end

    if text == "" then
        return panel.label_row("To note something, type it in the Mod Menu box first.")
    end

    return panel.gated_row("ban", "Write a note: \"" .. text .. "\"",
        255, 200, 120, function()
            OF.util.report(notes.set(localIndex, text))
        end)
end
