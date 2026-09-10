OF = OF or {}
OF.roommods = OF.roommods or {}

local roommods = OF.roommods

local SIZE_CAP = 35 * 1048576

function roommods.tags(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for token in string.gmatch(text, "[^ ]+") do
        table.insert(out, token)
    end
    return out
end

function roommods.shared(a, b)
    local out = {}
    if a == nil or b == nil then return out end
    local inB = {}
    for _, tag in ipairs(b) do inB[tag] = true end
    local already = {}
    for _, tag in ipairs(a) do
        if inB[tag] and not already[tag] then
            already[tag] = true
            table.insert(out, tag)
        end
    end
    return out
end

function roommods.engine_sees(a, b)
    if a == nil or b == nil then return false end
    if #a == 0 or #b == 0 then return false end
    for index, atag in ipairs(a) do
        if index == 1 then
            for _, btag in ipairs(b) do
                if atag == btag then return true end
            end
        elseif atag == b[1] then
            return true
        end
    end
    return false
end

local function marked_wip(name)
    if type(name) ~= "string" then return false end
    local lower = string.lower(name)
    return string.find(lower, "(wip)", 1, true) ~= nil
        or string.find(lower, "[wip]", 1, true) ~= nil
end

local function size_text(bytes)
    if type(bytes) ~= "number" or bytes <= 0 then return nil end
    if bytes >= 1048576 then
        return string.format("%.1f MB", bytes / 1048576)
    end
    return string.format("%.0f KB", bytes / 1024)
end

roommods.size_text = size_text

function roommods.list()
    local mods = gActiveMods
    if not OF.is_object(mods) then return nil end

    local own = OF.own_mod and OF.own_mod() or nil
    local out = {}
    for index = 0, 63 do
        local mod = mods[index]
        if OF.is_object(mod) and type(mod.name) == "string" then
            local category = mod.category
            if type(category) ~= "string" or category == "" then category = nil end
            table.insert(out, {
                index = index,
                name = OF.util.plain(mod.name),
                category = category,
                tags = roommods.tags(mod.incompatible),
                declared = type(mod.incompatible) == "string" and mod.incompatible or nil,
                files = type(mod.fileCount) == "number" and mod.fileCount or nil,
                bytes = type(mod.size) == "number" and mod.size or nil,

                pausable = mod.pausable ~= false,
                quiet = mod.ignoreScriptWarnings == true,
                off = mod.enabled == false,
                wip = marked_wip(mod.name),
                ours = own ~= nil and mod == own,
            })
        end
    end
    return out
end

function roommods.clashes(list)
    list = list or roommods.list()
    local out = {}
    if list == nil then return out end

    for i = 1, #list do
        for j = i + 1, #list do
            local a, b = list[i], list[j]
            local tags = roommods.shared(a.tags, b.tags)
            if #tags > 0 then
                table.insert(out, {
                    a = a, b = b, tags = tags,
                    seen = roommods.engine_sees(a.tags, b.tags),
                    mine = a.ours or b.ours,
                })
            end
        end
    end

    local function rank(clash)
        return (clash.mine and "0" or "1")
            .. (clash.seen and "1" or "0")
            .. clash.a.name .. "\1" .. clash.b.name
    end
    table.sort(out, function(x, y) return rank(x) < rank(y) end)
    return out
end

function roommods.notices(list)
    list = list or roommods.list()
    local out = {}
    if list == nil then return out end

    local function say(tone, text) table.insert(out, { tone = tone, text = text }) end

    for _, entry in ipairs(list) do
        if not entry.pausable then
            say("warn", entry.name
                .. " turns off pausing - alone in the lobby, this game will not pause.")
        end
    end

    local counted, order = {}, {}
    for _, entry in ipairs(list) do
        if counted[entry.name] == nil then
            counted[entry.name] = 0
            table.insert(order, entry.name)
        end
        counted[entry.name] = counted[entry.name] + 1
    end
    for _, name in ipairs(order) do
        if counted[name] > 1 then
            say("warn", counted[name] .. " copies of " .. name
                .. " are loaded at once - they will overwrite each other.")
        end
    end

    for _, entry in ipairs(list) do

        if entry.off then
            if entry.bytes ~= nil and entry.bytes >= SIZE_CAP then
                say("warn", entry.name .. " is over the 35 MB limit, so the game switched it off.")
            else
                say("warn", entry.name .. " is in the lobby's list but the game has it switched off.")
            end
        end
        if entry.quiet then
            say("info", entry.name
                .. " has its warnings silenced - if it goes wrong, nothing on screen will say so.")
        end
    end

    if OF.util.is_host() then
        local total, temporary = 0, 0
        for _, entry in ipairs(list) do
            if entry.bytes ~= nil then
                total = total + entry.bytes
                if entry.wip then temporary = temporary + entry.bytes end
            end
        end
        local all = size_text(total)
        if all ~= nil then
            say("info", "A joining player is sent up to " .. all .. " of mods.")
        end
        local again = size_text(temporary)
        if again ~= nil then

            say("info", again
                .. " of that is marked (wip): it is never saved on their machine, so it is sent again on every join.")
        end
    end

    local untagged = 0
    for _, entry in ipairs(list) do
        if #entry.tags == 0 then untagged = untagged + 1 end
    end
    if untagged > 0 then
        say("info", untagged
            .. " of them declare no tags, so nothing in this lobby can ever be ruled out against them.")
    end

    return out
end

local CHAT_PANEL = {
    label_row  = function(text) return { text = text } end,
    header_row = function(text) return { text = text, heading = true } end,
    with_right = function(built, right)
        if built ~= nil then built.right = right end
        return built
    end,

    back_row   = function() return { text = "", exit = true } end,
}

function roommods.lines()
    local out = {}
    for _, built in ipairs(roommods.build_page(CHAT_PANEL)) do
        if not built.exit then
            local text = tostring(built.text)
            if built.right ~= nil and built.right ~= "" then
                text = text .. "  -  " .. built.right
            end
            table.insert(out, { text = text, heading = built.heading == true })
        end
    end
    return out
end

function roommods.build_page(panel)
    local rows = {}
    local list = roommods.list()

    if list == nil then
        table.insert(rows, panel.label_row("This build cannot be asked what else is loaded."))
        table.insert(rows, panel.label_row("Nothing is wrong - the game is older than the answer."))
        table.insert(rows, panel.back_row("control"))
        return rows
    end

    local host = OF.util.is_host()
    table.insert(rows, panel.with_help(
        panel.label_row(#list .. " mod(s) are running in this lobby."),
        "everything the host has on, this one included"))
    table.insert(rows, panel.with_help(panel.label_row(host
        and "They are this machine's own, and every joiner is sent them."
        or "They came from the host. Only these are running here."),
        "a lobby runs one set of mods and the host owns it"))

    local ours = nil
    for _, entry in ipairs(list) do
        if entry.ours then ours = entry end
    end
    if ours ~= nil and ours.declared ~= nil then
        table.insert(rows, panel.with_help(
            panel.label_row("This mod declares: " .. ours.declared),
            "Read back off this mod's own header, so the two cannot drift."))
    end

    local clashes = roommods.clashes(list)

    table.insert(rows, panel.header_row("Do two of them want the same thing?"))
    if #clashes == 0 then
        table.insert(rows, panel.with_help(
            panel.label_row("No two of them declare the same thing."),
            "nothing here is fighting anything else for the same job"))
    end

    local blind = 0
    for _, clash in ipairs(clashes) do
        if not clash.seen then blind = blind + 1 end
        table.insert(rows, panel.with_right(
            panel.label_row(clash.a.name .. " + " .. clash.b.name,
                255, clash.seen and 200 or 140, clash.seen and 120 or 90),
            table.concat(clash.tags, " ")))
        if not clash.seen then
            table.insert(rows, panel.with_help(panel.label_row(
                "   the game's own check calls these two compatible"),
                "It compares the first tag of each list and no others."))
        end
    end

    if blind > 0 then

        table.insert(rows, panel.with_help(panel.label_row(
            "The game compares two tag lists by the first tag of each only."),
            "Which is why the clash above went unreported by the game."))
        table.insert(rows, panel.with_help(panel.label_row(
            "A shared tag that is not first in either list is invisible to it."),
            "Reorder a mod's tags and the game sees the clash too."))
    end

    local notices = roommods.notices(list)
    if #notices > 0 then
        table.insert(rows, panel.header_row("Worth knowing"))
        for _, notice in ipairs(notices) do
            local said = notice.tone == "warn"
                and panel.label_row(notice.text, 255, 200, 120)
                or panel.label_row(notice.text)
            table.insert(rows, panel.with_help(said,
                notice.tone == "warn"
                    and "Worth a look before the next player joins."
                    or "a fact about this lobby's mods, not a fault"))
        end
    end

    table.insert(rows, panel.header_row("What is loaded"))
    if not host then

        table.insert(rows, panel.with_help(panel.label_row(
            "Categories are not sent to a joining player, so these are the tags instead."),
            "The right-hand column means one thing here and another on the host."))
    end

    for _, entry in ipairs(list) do
        local what = entry.category
        if what == nil and #entry.tags > 0 then what = table.concat(entry.tags, " ") end
        table.insert(rows, panel.with_help(panel.with_right(
            panel.label_row(entry.name .. (entry.ours and "   (this mod)" or ""),
                255, 255, 255),
            what or ""),
            "what the game files this mod under, and what it declares"))

        local detail = {}
        if entry.files ~= nil then table.insert(detail, entry.files .. " file(s)") end
        local size = size_text(entry.bytes)
        if size ~= nil then table.insert(detail, size) end
        if entry.wip then table.insert(detail, "(wip)") end
        if entry.off then table.insert(detail, "switched off") end
        if #detail > 0 then
            table.insert(rows, panel.with_help(
                panel.label_row("   " .. table.concat(detail, ", ")),
                "what a joining player has to download for it"))
        end
    end

    for _, r in ipairs(rows) do
        if r.action == nil and r.heading ~= true
            and r.help ~= nil and r.help ~= "" then
            r.walk = true
        end
    end

    table.insert(rows, panel.back_row("control"))
    return rows
end
