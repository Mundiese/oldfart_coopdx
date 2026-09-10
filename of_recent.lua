OF = OF or {}
OF.recent = OF.recent or {}

local recent = OF.recent

recent.PACKET = "report"
recent.MAX = 8

recent.list = recent.list or {}

recent.SPOKE = 6
recent.spoke = recent.spoke or {}

local frames = 0

local function clock()
    local seconds = math.floor(frames / 30)
    return string.format("%02.0f:%02.0f", math.floor(seconds / 60) % 100, seconds % 60)
end

function recent.note(localIndex, what, kind)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return false end

    table.insert(recent.list, 1, {
        id = OF.util.player_id(localIndex),
        name = np.name,
        what = what,
        kind = kind,
        time = clock(),
    })
    while #recent.list > recent.MAX do table.remove(recent.list) end
    return true
end

function recent.last()
    return recent.list[1]
end

function recent.said(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil then return false end

    table.insert(recent.spoke, 1, {
        id = OF.util.player_id(localIndex),
        name = np.name,
        time = clock(),
    })
    while #recent.spoke > recent.SPOKE do table.remove(recent.spoke) end
    return true
end

function recent.target()
    local entry = recent.last()
    if entry ~= nil then return entry, true end

    local spoke = recent.spoke[1]
    if spoke == nil then return nil, false end
    return { id = spoke.id, name = spoke.name, time = spoke.time,
             what = "last to speak" }, false
end

function recent.reports()
    local out = {}
    for _, entry in ipairs(recent.list) do
        if entry.kind == "report" then table.insert(out, entry) end
    end
    return out
end

function recent.report_count()
    return #recent.reports()
end

function recent.forget()
    recent.list = {}
    recent.spoke = {}
end

function recent.index_of(entry)
    if entry == nil or entry.id == nil then return nil end
    for _, player in ipairs(OF.util.connected_players()) do
        if OF.util.player_id(player.localIndex) == entry.id then
            return player.localIndex
        end
    end
    return nil
end

hook_event(HOOK_UPDATE, function() frames = frames + 1 end)

function recent.mute_last()
    local entry = recent.target()
    if entry == nil then return false, "Nothing has happened yet." end
    local localIndex = recent.index_of(entry)
    if localIndex == nil then return false, entry.name .. " has left." end
    if not OF.perms.can("mute") then return false, "Your rank cannot do that.", "mute" end
    return OF.mute.set(localIndex, true)
end

function recent.jail_last(sentenceKey)
    local entry = recent.target()
    if entry == nil then return false, "Nothing has happened yet." end
    local localIndex = recent.index_of(entry)
    if localIndex == nil then return false, entry.name .. " has left." end
    if not OF.perms.can("jail") then return false, "Your rank cannot do that.", "jail" end
    return OF.jail.punish(localIndex, sentenceKey or "cooldown", nil)
end

function recent.ban_last()
    local entry = recent.last()
    if entry == nil then
        if recent.spoke[1] ~= nil then
            return false, "Nothing has been flagged. Open them in the player list to ban."
        end
        return false, "Nothing has happened yet."
    end
    if not OF.perms.can("ban") then return false, "Your rank cannot do that.", "ban" end

    local localIndex = recent.index_of(entry)
    if localIndex == nil then return OF.jail.ban_absent(entry.id, entry.name) end
    return OF.jail.ban(localIndex)
end

function recent.clear_last()
    local entry = recent.target()
    if entry == nil then return false, "Nothing has happened yet." end

    local localIndex = recent.index_of(entry)
    if localIndex ~= nil then return OF.jail.clear_player(localIndex) end

    if not OF.perms.can("ban") then return false, "Your rank cannot do that.", "ban" end
    if not OF.jail.is_banned(entry.id) then
        return false, entry.name .. " has left, and nothing is on them."
    end
    return OF.jail.unban(entry.id)
end

local REPORT_COOLDOWN = 30 * 30

local reportedAt = {}

function recent.may_report(localIndex)
    local at = reportedAt[localIndex]
    return at == nil or (frames - at) >= REPORT_COOLDOWN
end

function recent.mark_reported(localIndex)
    reportedAt[localIndex] = frames
end

function recent.land_report(reporter, target)
    local who = gNetworkPlayers[reporter]
    local them = gNetworkPlayers[target]
    local name = OF.util.plain(who ~= nil and who.name or "somebody")
    local about = OF.util.plain(them ~= nil and them.name or "somebody")

    recent.note(target, OF.lang.fill("reported by @", name), "report")
    OF.notify.show("@ says @ is bothering them", "warn", 8, name, about)
    OF.chatlog.add_system(OF.lang.fill("@ reported @", name, about))
    return true
end

function recent.ask_report(localIndex)
    local np = gNetworkPlayers[localIndex]
    if np == nil or not np.connected then return false, "That player has left." end
    if localIndex == 0 then return false, "That one is you." end

    if OF.util.is_host() then

        recent.land_report(0, localIndex)
        OF.util.chat(OF.lang.t("On your own list."))
        return true
    end

    if not recent.may_report(0) then
        return false, "You have already told the host. Give them a moment."
    end
    if not OF.util.send_to_host({
        ofp = recent.PACKET,
        who = network_global_index_from_local(localIndex),
    }) then
        return false, "There is nobody to tell yet."
    end
    recent.mark_reported(0)
    OF.util.chat(OF.lang.t("The host has been told. Nothing was done to them."))
    return true
end

local function on_packet_receive(data)
    if data == nil or data.ofp ~= recent.PACKET then return end
    if not OF.util.is_host() then return end

    local asker, askerGlobal = OF.util.asked_by(data)
    if asker == nil then return end

    local target = OF.util.local_from_global(data.who)
    if target == nil then return end
    if target == asker then return end

    if not recent.may_report(asker) then
        OF.notify.send_to(askerGlobal,
            "You have already told the host. Give them a moment.", "info", 5)
        return
    end
    recent.mark_reported(asker)
    recent.land_report(asker, target)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)

function recent.standing_lines()
    local lines = {}
    local muted = {}

    for _, player in ipairs(OF.util.connected_players()) do
        local localIndex = player.localIndex
        local name = OF.util.plain(player.np.name)

        if OF.util.asks(OF.mute, "is_muted") and OF.mute.is_muted(localIndex) then
            table.insert(muted, name)
        end

        local sentence = OF.util.asks(OF.jail, "sentence_of")
            and OF.jail.sentence_of(localIndex) or nil
        if sentence ~= nil then

            local left = OF.util.asks(OF.jail, "time_left")
                and OF.jail.time_left(localIndex) or nil
            local line = OF.lang.fill("@ is @", name, sentence.short)
            if left ~= nil then
                line = line .. " (" .. OF.jail.left_text(left) .. " left)"
            end
            table.insert(lines, line)
        end
    end

    if #muted > 0 then
        table.insert(lines, OF.lang.fill("Muted: @", table.concat(muted, ", ")))
    end
    return lines
end

local function add_standing(panel, rows)
    local standing = recent.standing_lines()
    if #standing == 0 then return false end

    table.insert(rows, panel.header_row("Still on the lobby"))
    for _, line in ipairs(standing) do
        table.insert(rows, panel.label_row("   " .. line))
    end
    return true
end

local function said(panel, text, help, r, g, b)
    local built = panel.label_row(text, r, g, b)
    built.walk = true
    return panel.with_help(built, help)
end

function recent.build_reports_page(panel)
    local rows = {}
    local list = recent.reports()

    if #list == 0 then
        table.insert(rows, said(panel,
            "Nobody has asked you to look at anybody.",
            "a report lands here the moment somebody sends one"))

        table.insert(rows, said(panel,
            "   Anybody can type /report <name>, muted or not.",
            "a muted player still has a way to reach you"))
    end

    for _, entry in ipairs(list) do
        local localIndex = recent.index_of(entry)
        local name = OF.util.plain(entry.name or "?")
        if localIndex == nil then

            table.insert(rows, panel.with_help(panel.with_right(
                panel.label_row("   " .. name .. " - " .. tostring(entry.what)),
                entry.time),
                "they have left - a ban still lands if they come back"))
            table.insert(rows, panel.gated_confirm_row("ban",
                "reportban" .. tostring(entry.id),
                OF.lang.fill("Ban @", name), 255, 110, 110, function()
                    OF.util.report(OF.jail.ban_absent(entry.id, entry.name))
                end))
        else
            table.insert(rows, panel.with_help(panel.with_right(
                panel.gated_row("mute", name .. " - " .. tostring(entry.what),
                    255, 200, 120, function()
                        panel.selected = network_global_index_from_local(localIndex)
                        panel.go("player")
                    end),
                entry.time),
                "opens them - mute, jail, ban and their record are all on that page"))
        end
    end

    add_standing(panel, rows)

    table.insert(rows, panel.back_row())
    return rows
end

hook_chat_command("report",
    "- tell the host somebody is bothering you - works while you are muted",
    function(msg)
        if msg == nil or msg == "" then
            OF.util.chat(OF.lang.t("Say who: /report [their name]."))
            return true
        end
        local target = OF.util.named_player(msg)
        if target == nil then return true end
        OF.util.report(recent.ask_report(target))
        return true
    end)
