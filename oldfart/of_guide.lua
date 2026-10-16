OF = OF or {}
OF.guide = OF.guide or {}

local guide = OF.guide

guide.TABS = {
    { name = "Players", text = "who is here, ranks, mutes, jail, costumes, hats" },
    { name = "Travel",  text = "send anybody anywhere, waypoints, arenas" },

    { name = "Modes",   text = "speedruns, @ game modes, teams, the round queue, bingo",
                        count = function()
                            local list = OF.gamemodes ~= nil and OF.gamemodes.LIST or nil
                            return list ~= nil and #list or 0
                        end },

    { name = "Fun",     text = "lobby rules, cheats, music, the save file, forge, powerups" },
    { name = "Control", text = "the log, ranks, bans, the sign, the big levers" },

    { name = "Menu Settings",
                        text = "your colours, your buttons, where the menu sits - nobody else sees it" },
}

function guide.tab_text(tab)
    if tab == nil then return "" end
    if tab.count == nil then return OF.lang.t(tab.text) end
    return OF.lang.fill(tab.text, tab.count())
end

function guide.lines()
    local list = {}
    for _, tab in ipairs(guide.TABS) do
        table.insert(list, tab.name .. ": " .. guide.tab_text(tab))
    end
    return list
end

guide.DOORS = {
    { command = "search", text = "where anything in the menu is, and it takes you there" },
    { command = "ofdiag", text = "why this machine is not doing what it should" },
    { command = "oflog", needs = "jail", text = "who has been using the menu" },
    { command = "vote", text = "ask the lobby anything, in your own words" },
}

function guide.doors()
    local registered = {}
    for _, entry in ipairs(OF.COMMANDS or {}) do registered[entry.name] = true end

    local out = {}
    for _, door in ipairs(guide.DOORS) do

        local mayUse = door.needs == nil
            or (OF.util.asks(OF.perms, "can") and OF.perms.can(door.needs))
        if registered[door.command] and mayUse then
            table.insert(out, {
                name = "/" .. door.command
                    .. (door.arg ~= nil and (" " .. door.arg) or ""),
                text = door.text,
            })
        end
    end
    return out
end

guide.GROUPS = {
    { name = "Finding your way",
      commands = { "search", "mm", "modmenu", "menu", "ofdiag",

                   "discord", "dc", "download", "dl" } },
    { name = "Who is here, and keeping order",
      commands = { "oflog", "report", "accuse", "mute", "unmute", "quiet",
                   "jail", "unjail", "unban", "appeal",

                   "filter" } },

    { name = "Getting players places",
      commands = { "go", "teleport", "unstick",

                   "wpload", "wpsave",

                   "door",

                   "track" } },

    { name = "Rounds",

      commands = { "randomizer", "nonstop", "nominate", "vote", "yes", "no",
                   "sitout",

                   "readycheck", "ready", "notready", "timeleft",
                   "next" } },
    { name = "The lobby itself",
      help = "words that say something to everybody at once",
      commands = { "say", "tell", "rules" } },

    { name = "What you look like",
      commands = { "pet" } },

    { name = "Talking to the lobby",
      commands = { "t", "w", "r", "poll", "pick", "roll", "countdown",
                   "announce" } },
}

guide.ALIASES = {
    { short = "v",          full = "vote" },
    { short = "y",          full = "yes" },
    { short = "n",          full = "no" },
    { short = "s",          full = "search" },
    { short = "f",          full = "search" },
    { short = "u",          full = "unstick" },
    { short = "find",       full = "search" },
    { short = "wps",        full = "wpsave" },

    { short = "wpl",        full = "wpload" },

    { short = "tp",         full = "teleport" },
    { short = "notme",      full = "appeal" },
    { short = "rando",      full = "randomizer" },

    { short = "randomize",  full = "randomizer" },
}

function guide.run(name, msg)
    local entry = OF.command(name)
    if entry == nil or entry.fn == nil then
        OF.util.chat(OF.lang.fill(
            "/@ did not load on this machine - /ofdiag says what else did not.",
            name), "warn")
        return true
    end
    return entry.fn(msg)
end

function guide.alias_for(name)
    for _, pair in ipairs(guide.ALIASES) do
        if pair.full == name then return pair.short end
    end
    return nil
end

function guide.ungrouped()
    local claimed = {}
    for _, group in ipairs(guide.GROUPS) do
        for _, name in ipairs(group.commands) do claimed[name] = true end
    end
    for _, pair in ipairs(guide.ALIASES) do claimed[pair.short] = true end

    local out = {}
    for _, entry in ipairs(OF.COMMANDS or {}) do
        if not claimed[entry.name] then table.insert(out, entry.name) end
    end
    table.sort(out)
    return out
end

local function nearness(word, name)
    local score, at = 0, 1
    for i = 1, #word do
        local found = string.find(name, string.sub(word, i, i), at, true)
        if found ~= nil then score = score + 1 at = found + 1 end
    end
    return score
end

function guide.nearest(word)
    word = string.lower(OF.util.plain(tostring(word or "")))
    if #word < 2 then return nil end

    local best, bestScore = nil, 0
    for _, entry in ipairs(OF.COMMANDS or {}) do
        local score = nearness(word, string.lower(entry.name))

        if string.sub(string.lower(entry.name), 1, #word) == word then
            score = score + #word
        end
        if score > bestScore then best, bestScore = entry.name, score end
    end

    if best ~= nil and bestScore >= math.max(2, math.ceil(#word / 2)) then
        return best
    end
    return nil
end

function guide.search(word)
    local needle = string.lower(word or "")
    local found = {}
    if needle == "" then return found end

    for _, entry in ipairs(OF.COMMANDS or {}) do
        local haystack = string.lower(entry.name .. " " .. (entry.description or ""))
        if string.find(haystack, needle, 1, true) then table.insert(found, entry) end
    end
    return found
end

local function said(entry)
    local text = tostring(entry.description or "")

    text = string.gsub(text, "^%s*%[[^%]]*%]%s*", "", 1)

    local takes = ""
    while true do
        local found = string.match(text, "^%s*(<[^>]*>)")
            or string.match(text, "^%s*(%[[^%]]*%])")
        if found == nil then break end
        takes = takes .. " " .. found

        text = string.sub(text, string.find(text, found, 1, true) + #found)
    end

    local was
    repeat
        was = text
        text = string.gsub(text, "^%s*%-%s*", "", 1)
    until text == was
    text = string.gsub(text, "^%s+", "")

    local name = "/" .. entry.name .. takes
    if text == "" then return name, nil end
    return name, text
end

function guide.build_page(panel)
    local rows = {}

    local function listing(text, r, g, b, help)
        local built = panel.label_row(text, r, g, b)
        built.walk = true
        if help ~= nil and help ~= "" then
            built = panel.with_help(built, OF.lang.t(help))
        end
        return built
    end

    for _, group in ipairs(guide.GROUPS) do
        local listed = {}
        for _, name in ipairs(group.commands) do
            local entry = OF.command(name)
            if entry ~= nil then table.insert(listed, entry) end
        end

        if #listed > 0 then

            table.insert(rows, panel.with_help(
                panel.header_row(OF.lang.t(group.name)), group.help))
            for _, entry in ipairs(listed) do
                local word, does = said(entry)
                table.insert(rows, listing(word, 220, 220, 220, does))
            end
        end
    end

    local shorts = {}
    for _, pair in ipairs(guide.ALIASES) do
        if OF.command(pair.short) ~= nil and OF.command(pair.full) ~= nil then
            table.insert(shorts, { word = "/" .. pair.short,
                does = OF.lang.fill("the same as /@", pair.full) })
        end
    end
    if #shorts > 0 then
        table.insert(rows, panel.with_help(
            panel.header_row(OF.lang.t("The short ones")),
            "another spelling of a word already listed above - nothing new, "
            .. "and mostly quicker to type"))
        for _, pair in ipairs(shorts) do
            table.insert(rows, listing(pair.word, 220, 220, 220, pair.does))
        end
    end

    local left = guide.ungrouped()
    if #left > 0 then
        table.insert(rows, panel.header_row(OF.lang.t("Filed nowhere yet")))
        for _, name in ipairs(left) do
            table.insert(rows, listing("/" .. name, 255, 200, 120,
                "No group claims this one - the suite fails on it."))
        end
    end

    table.insert(rows, panel.back_row())
    return rows
end

hook_chat_command("v", "- short for /vote", function(msg)
    return guide.run("vote", msg) end)
hook_chat_command("y", "- short for /yes", function(msg)
    return guide.run("yes", msg) end)
hook_chat_command("n", "- short for /no", function(msg)
    return guide.run("no", msg) end)
