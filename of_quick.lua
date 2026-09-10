OF = OF or {}
OF.quick = OF.quick or {}

local quick = OF.quick

quick.SHOWN = 6

quick.KEPT = 12

local STORE_KEY = "of_quick"
local STORE_LIMIT = 1000
local STORE_MARK = "2 "
quick.list = quick.list or {}

quick.MOVED = {
    arena = {
        sweep = {
            ["Bosses"] = true, ["Hazards"] = true, ["Enemies"] = true,
            ["In flight"] = true, ["Spawners"] = true, ["Bystanders"] = true,
            ["Currents"] = true, ["Cannons"] = true, ["Pickups"] = true,
            ["Sweep this level without moving"] = true,
            ["Stop sweeping (reload to bring them back)"] = true,
        },
    },

    rules = {
        rules = {
            ["The stopwatch"] = "The course clock",

            ["Room size"] = "Lobby size",
        },
    },

    control = {
        order = {
            ["Lift every mute and sentence"] = true,
            ["What just happened..."] = "Reports...",
            ["What just happened"] = "Reports...",
        },

        roomrules = {
            ["Rapid fire - your own buttons..."] =
                "Controls editor - the pad and the camera...",
        },
    },

    room = {
        roomrules = {

            ["Lobby rules..."] = "How the game plays...",
            ["Harsh rules - make it worse on purpose..."] =
                "What a mistake costs - make it worse on purpose...",
            ["The course's own enemies..."] = true,

            ["Controls editor - the pad and the camera..."] = true,
        },
        chance = {
            ["Randomizer..."] = true,

            ["Chaos"] = "Chaos...",
            ["Chaos..."] = true,
            ["The Green Demon"] = true,
        },
        looksound = {
            ["Music"] = true,
            ["Visuals - how the room looks..."] = "Visuals - how the lobby looks...",
        },

        room = {

            ["The rules of the room..."] = "What the lobby changes...",
            ["The rules of the lobby..."] = "What the lobby changes...",
        },
    },

    roomrules = {
        roomrules = {
            ["Lobby rules..."] = "How the game plays...",
            ["Harsh rules - make it worse on purpose..."] =
                "What a mistake costs - make it worse on purpose...",
        },
    },

    harsh = {
        harsh = { ["Turn every harsh rule off"] = "Turn every harsh setting off" },
    },

    vision = {
        looksound = {
            ["How everybody is drawn"] = true,
        },
    },

    enemies = {
        roomrules = { ["Clear the level out..."] = true },
    },

    looksound = {
        looksound = {
            ["Visuals - how the room looks..."] = "Visuals - how the lobby looks...",
            ["Music"] = "Music...",

            ["How everybody is drawn"] = "How everybody is drawn...",
            ["How everybody is drawn..."] = "How players look...",
        },
    },

    perms = {
        perms = {
            ["Build the room's picture"] = "Build the lobby's picture",
            ["Change the lobby's rules"] = "Change how the game plays",
        },
    },
    permladder = {
        permladder = {
            ["Build the room's picture"] = "Build the lobby's picture",
            ["Change the lobby's rules"] = "Change how the game plays",
        },
    },

    rando = {
        rando = {
            ["What the room hears"] = "What the lobby hears",
        },
    },

    speedrun = {
        speedrun = {
            ["Bingo - deal the room a card..."] = "Bingo - deal the lobby a card...",
            ["Bingo - the room's card..."] = "Bingo - the lobby's card...",

            ["Who is taking part"] = "Who is taking part...",
        },
    },
    together = {
        together = { ["Tie the room into pairs"] = "Tie the lobby into pairs" },
    },

    forge = {
        forge = {
            ["   1   -   empty"] = "   1",
            ["   2   -   empty"] = "   2",
            ["   3   -   empty"] = "   3",
            ["   4   -   empty"] = "   4",
            ["   5   -   empty"] = "   5",
            ["   6   -   empty"] = "   6",
        },
    },

    order = {
        order = { ["Somebody's rank..."] = "Promote or demote somebody..." },
    },

    powerups = {
        powerups = { ["Coins"] = "Hand them coins" },
        doto = { ["Play them a fanfare"] = true },
    },

    cheats = {
        powerups = {
            ["The spinning triple jump"] = "The winged triple jump",
            ["Wings"] = "Wing Cap",
            ["Ghost"] = "Vanish Cap",
            ["Metal body"] = "Metal Cap",
        },

        cheats = {
            ["Gravity"] = "Low gravity",
            ["Giants"] = "Giant",
            ["Everybody's gravity"] = "Low gravity",
            ["Everybody is giant"] = "Giant",
            ["Everybody is tiny"] = "Tiny",
        },
    },

    hats = {
        players = {
            ["Emotes - say something without typing..."] = true,
        },

        hats = { ["Caps..."] = "Caps you wear..." },
    },
    costumes = {
        costumes = { ["Caps..."] = "Caps you become..." },
    },
    controls = {
        forge = {
            ["Reach and turn sensitivity"] = true,
            ["Invert up and down when turning (this only, not the camera)"] = true,
            ["Hold the camera still"] = true,
        },
        controls = {
            ["...and stop me dead, rather than letting me slide on"] =
                "Stop me dead, rather than letting me slide on",
        },

        roomrules = {
            ["Rapid fire - your own buttons..."] =
                "Controls editor - the pad and the camera...",
        },
    },
}

local MOVED = quick.MOVED

function quick.moved_to(page, key)
    local from = MOVED[page]
    if from == nil then return page, key end
    for to, keys in pairs(from) do
        local now = keys[key]
        if now ~= nil then
            if type(now) == "string" then return to, now end
            return to, key
        end
    end
    return page, key
end

function quick.settled(page, key)
    local seen = {}
    for _ = 1, 8 do
        local mark = tostring(page) .. "\0" .. tostring(key)
        if seen[mark] then break end
        seen[mark] = true
        local toPage, toKey = quick.moved_to(page, key)
        if toPage == page and toKey == key then break end
        page, key = toPage, toKey
    end
    return page, key
end

local loaded = false

local function ensure()
    if loaded then return end
    loaded = true
    quick.load()
end

local function same(entry, page, key, sel)
    return entry.page == page and entry.key == key and entry.sel == sel
end

function quick.identity(row)
    if row == nil then return nil end
    if row.key ~= nil and row.key ~= "" then return row.key end

    local text = OF.util.row_key(row.text or "")
    if text == "" then return nil end
    return text
end

local sinceAged = 0

function quick.remember(page, key, sel)
    if page == nil or key == nil or key == "" then return end
    ensure()

    for _, entry in ipairs(quick.list) do
        if same(entry, page, key, sel) then
            entry.count = entry.count + 1
            quick.save()
            return
        end
    end

    table.insert(quick.list, { page = page, key = key, sel = sel, count = 1 })
    local newest = #quick.list

    while #quick.list > quick.KEPT do
        local worst, at = nil, nil
        for index, entry in ipairs(quick.list) do
            if index ~= newest and (worst == nil or entry.count < worst) then
                worst, at = entry.count, index
            end
        end
        if at == nil then break end
        table.remove(quick.list, at)
        if at < newest then newest = newest - 1 end

        sinceAged = sinceAged + 1
        if sinceAged >= quick.KEPT then
            sinceAged = 0
            for _, entry in ipairs(quick.list) do
                if entry.count > 1 then
                    entry.count = math.floor(entry.count / 2)
                    if entry.count < 1 then entry.count = 1 end
                end
            end
        end
    end
    quick.save()
end

function quick.forget_all()
    quick.list = {}
    quick.save()
    return true
end

function quick.top()
    ensure()
    local order = {}
    for index, entry in ipairs(quick.list) do
        table.insert(order, { entry = entry, at = index })
    end
    table.sort(order, function(a, b)
        if a.entry.count ~= b.entry.count then
            return a.entry.count > b.entry.count
        end
        return a.at < b.at
    end)

    local out = {}
    for _, item in ipairs(order) do
        table.insert(out, item.entry)
        if #out >= quick.SHOWN then break end
    end
    return out
end

function quick.save()

    local order = {}
    for _, entry in ipairs(quick.list) do table.insert(order, entry) end
    table.sort(order, function(a, b) return a.count > b.count end)

    local text = STORE_MARK
    for _, entry in ipairs(order) do
        local key = tostring(entry.key)

        local sel = entry.sel ~= nil and tostring(entry.sel) or ""
        local record = entry.page .. " " .. entry.count .. " " .. #sel
            .. " " .. #key .. " " .. sel .. key
        if #text + #record > STORE_LIMIT then break end
        text = text .. record
    end
    OF.util.store(STORE_KEY, text)
end

function quick.load()
    quick.list = {}
    local text = mod_storage_load(STORE_KEY, "")
    if text == nil or text == "" then return end

    local marked = string.sub(text, 1, #STORE_MARK) == STORE_MARK
    local at = marked and (#STORE_MARK + 1) or 1
    while at <= #text do
        local page, count, selLength, length, after
        if marked then
            page, count, selLength, length, after =
                string.match(text, "^([%w_]+) (%d+) (%d+) (%d+) ()", at)
        else
            page, count, length, after =
                string.match(text, "^([%w_]+) (%d+) (%d+) ()", at)
            selLength = 0
        end
        if page == nil then break end
        selLength = tonumber(selLength)
        length = tonumber(length)
        local sel = string.sub(text, after, after + selLength - 1)
        after = after + selLength
        local key = string.sub(text, after, after + length - 1)

        if #sel < selLength or #key < length then break end

        if sel == "" then sel = nil elseif tonumber(sel) ~= nil then
            sel = tonumber(sel)
        end

        key = OF.util.row_key(key)

        page, key = quick.settled(page, key)

        local merged = false
        for _, entry in ipairs(quick.list) do
            if entry.page == page and entry.key == key and entry.sel == sel then
                entry.count = entry.count + tonumber(count)
                merged = true
                break
            end
        end
        if not merged then
            table.insert(quick.list,
                { page = page, key = key, sel = sel, count = tonumber(count) })
        end
        at = after + length
    end
end

local borrowing = false

function quick.rows(panel)
    if borrowing then return {} end
    borrowing = true

    local found = {}
    local was, wasRows = panel.page, panel.rows
    local wasCursor, wasScroll, wasTab = panel.cursor, panel.scroll, panel.tab

    for _, entry in ipairs(quick.top()) do
        if panel.PAGES[entry.page] ~= nil and entry.page ~= was then

            local sweep = OF.util.asks(OF.find, "selections_of")
                and OF.find.selections_of(panel.PAGES[entry.page]) or nil
            local heldSel, hadSel = nil, false
            if sweep ~= nil and entry.sel ~= nil then
                local fine, got = pcall(sweep.held)
                if fine then heldSel, hadSel = got, true end
                pcall(sweep.pick, entry.sel)
            end
            panel.page = entry.page
            local ok = pcall(panel.rebuild)
            local got = nil
            if ok and panel.rows ~= nil then
                for _, r in ipairs(panel.rows) do

                    if quick.identity(r) == entry.key then got = r break end
                end
            end

            if got == nil then
                local def = panel.PAGES[entry.page]
                local build = def ~= nil and def.build or nil
                if type(build) == "function" then
                    local fine, raw = pcall(build)
                    if fine and type(raw) == "table" then
                        for _, r in ipairs(raw) do
                            if quick.identity(r) == entry.key then got = r break end
                        end
                    end
                end
            end

            if got ~= nil then
                got.from = entry.page
                table.insert(found, got)
            end

            if hadSel then pcall(sweep.pick, heldSel) end
        end
    end

    panel.page, panel.rows = was, wasRows
    panel.cursor, panel.scroll, panel.tab = wasCursor, wasScroll, wasTab
    borrowing = false
    return found
end

function quick.build_page(panel)
    local rows = {}
    local found = quick.rows(panel)

    if #found == 0 then

        table.insert(rows, panel.label_row(OF.lang.t(
            "Nothing yet. Press something twice and it turns up here.")))
        if OF.util.asks(OF.find, "open") then
            table.insert(rows, panel.with_help(panel.with_right(
                panel.row(OF.lang.t("Find anything..."), 255, 220, 120,
                    function() OF.find.open() end),
                "/search"),

                OF.lang.t("every row in the menu, searched for a word you type")))
        else
            table.insert(rows, panel.label_row(OF.lang.t(
                "/find <word>  -  puts you on the row for it")))
        end
        table.insert(rows, panel.back_row("client"))
        return rows
    end

    table.insert(rows, panel.label_row(OF.lang.t("The rows you press most.")))

    for _, r in ipairs(found) do

        local shut = OF.util.asks(panel, "tab_is_open")
            and not panel.tab_is_open(panel.tab_of(r.from))
        local shutText = r.text
        if shut then
            shutText = tostring(r.text) .. "   "
                .. OF.lang.t("(until the round ends)")
        end

        local shortcut = {
            text = shutText, key = r.key,
            r = shut and 130 or r.r,
            g = shut and 130 or r.g,
            b = shut and 130 or r.b,
            right = r.right, help = r.help,
            action = (not shut) and r.action or nil,
            altAction = (not shut) and r.altAction or nil,

            altMine = (not shut) and r.altMine or nil,

            altBox = (not shut) and r.altBox or nil,
            altPad = (not shut) and r.altPad or nil,
            actionLabel = (not shut) and r.actionLabel or nil,
            altLabel = (not shut) and r.altLabel or nil,

            from = r.from,
            mine = (not shut) and r.mine or nil,
            ticks = (not shut) and r.ticks or nil,
            slider = (not shut) and r.slider or nil,
            denied = r.denied,
        }

        if shortcut.right == nil or shortcut.right == "" then
            local page = panel.PAGES[r.from]
            shortcut.right = page ~= nil and OF.lang.t(page.title) or ""
        end

        if shortcut.help == nil or shortcut.help == "" then
            shortcut.help = OF.lang.fill("A row you press often, kept here. It lives on @.",
                shortcut.right ~= "" and shortcut.right or OF.lang.t("another page"))
        end
        table.insert(rows, shortcut)
    end

    table.insert(rows, panel.with_help(
        panel.row(OF.lang.t("Forget these"), 255, 180, 90,
            function() OF.util.report(quick.forget_all()) end),
        OF.lang.t("Empties this page. The rows themselves stay where they live.")))
    table.insert(rows, panel.back_row("client"))
    return rows
end
