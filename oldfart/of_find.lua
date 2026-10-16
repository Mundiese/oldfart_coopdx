OF = OF or {}
OF.find = OF.find or {}

local find = OF.find

find.SHOWN = 12

find.KEPT = 6

find.STALE = 900

local STORE_KEY = "of_find"
local STORE_LIMIT = 900

find.ALIASES = {
    ["knockback"]      = "kb shove push punch bump hit force melee",
    ["fighting"]       = "pvp fight attack damage friendly fire",
    ["players touch"]  = "collide collision solid ghost clip pass",
    ["name tag"]       = "nametag label name over head",
    ["bubble"]         = "death die respawn",
    ["moon"]           = "fly flight jump cheat",
    ["speed"]          = "fast slow quick run",

    ["ban"]            = "block remove out",
    ["kick"]           = "boot remove out disconnect",

    ["disconnect"]     = "kick boot eject remove out throw drop",

    ["emote"]          = "dance taunt gesture pose celebrate",

    ["god mode"]       = "invincible invulnerable immortal untouchable",

    ["invisible"]      = "invisibility hidden hide unseen",

    ["how close you can see"] = "zoom fov camera distance view far near",

    ["reset everything"] = "vanilla default undo revert restore normal start over fresh",

    ["gather"]         = "summon bring call fetch pull everyone here",
    ["mute"]           = "silence quiet shut gag chat",
    ["jail"]           = "prison cell timeout punish",
    ["rank"]           = "role tier permission trust admin vip promote",
    ["permission"]     = "rank role allow deny gate",
    ["spectate"]       = "watch follow camera observe",
    ["waypoint"]       = "bookmark place saved spot warp",

    ["doorway"]        = "portal gate link pair entrance exit walk through door",

    ["blast"]          = "explosive explode explosion boom punch kick fist",
    ["travel"]         = "warp teleport tp send move go level course",
    ["level"]          = "map course stage world warp",
    ["arena"]          = "map room stage battle field",

    ["sweep"]          = "clear clean wipe empty remove delete purge npc",
    ["costume"]        = "skin model character dress look face",
    ["theme"]          = "colour color palette style accent",
    ["music"]          = "song track sound audio tune",

    ["star"]           = "power star collect shine",
    ["coin"]           = "money cash currency",
    ["round"]          = "match game queue plan",

    ["game mode"]      = "minigame party",

    ["seek"]           = "seekers hunt hunter finder",
    ["hider"]          = "caught catch tagged hiding headstart",
    ["murderer"]       = "killer imposter suspect innocent",

    ["circle"]         = "chairs seats musical",
    ["lives"]          = "stock",

    ["call length"]    = "simon prompt reaction calls instruction",
    ["call pace"]      = "tighten faster quicker",
    ["round ends when"] = "runners home finish",
    ["fuse"]           = "bomb explode countdown",

    ["grapple"]        = "hookshot longshot claw",
    ["suction jar"]    = "gust vacuum hoover",
    ["capture the flag"] = "ctf",
    ["king of the hill"] = "koth",

    ["win the round"]  = "target goal limit score",
    ["modifier"]       = "mutator chaos rule twist",
    ["powerup"]        = "item cap pickup buff",
    ["vote"]           = "poll ballot ask room choose",
    ["sign"]           = "message board announce banner motd welcome",
    ["shortcut"]       = "favourite favorite quick recent often",
    ["hide"]           = "invisible vanish cloak",
    ["size"]           = "scale big small giant tiny",
    ["timer"]          = "clock countdown stopwatch time",
    ["sound"]          = "audio volume noise music",

    ["entrances lead"] = "shuffle randomize randomise randomizer scramble "
        .. "castle painting paintings seed entrance rearrange",

    ["one death"]      = "linked chained shared sharing",

    ["everybody"]      = "everyone",
    ["mark"]           = "marker markers label labels",

    ["lobby"]          = "room",
}

find.PAGE_ALIASES = {
    rules      = "settings server options lobby pvp fighting",

    perms      = "rank role admin trust permission promote demote",

    order      = "moderation admin discipline punish away afk idle gone",

    filter     = "censor swear profanity language words blocked",

    record     = "stats statistics history seen joined played record",
    client     = "personal me myself own local",

    practice   = "checkpoint savepoint training",
    place      = "position move menu panel window layout size",
    controls   = "buttons pad input binding key",

    moves      = "rapid repeat autofire turbo input",

    lens       = "camera cam lens fisheye view angle horizon mirror lakitu",

    room       = "silly toys extras play fun",
    travel     = "warp teleport level map course go",
    quick      = "favourite favorite recent shortcut often",
    find       = "search look up where",

    chance     = "dice luck surprise twist",
    rando      = "random randomize randomise randomizer shuffle scramble seed "
        .. "run setup roll draw session evening plan schedule night",

    active     = "on enabled running switched what is active",
    chatlog    = "chat said history messages",

    together   = "pact share health bar together rope tie carry pair partner",
    actionlog  = "audit who did what history moderation",

    roomrules  = "lobby settings changes",

    ["roommods"] = "what else is loaded",
    autorules  = "what the mod does on its own",
    save       = "file star editor progress",

    shapes     = "appearance avatar shape shapes look drawn silhouette "
        .. "nametag name tag flat paper stretched",

    doto       = "punish action do zap crowd control powerup mischief",

    warp       = "gravity scale size upside down ceiling flip stretch squash "
        .. "bigger smaller wide tall deep world physics",
    enemies    = "goomba koopa bobomb monster mob behaviour behavior respawn "
        .. "aggro course difficulty dress",
    harsh      = "hard difficulty challenge punishing lava coins damage "
        .. "hardcore permadeath",

    doorways   = "portal portals gun shoot link pair teleport opening "
        .. "warp door momentum",
}

find.entries = nil
find.builtAt = nil
find.builtFor = nil

find.builds = 0

find.word = nil
find.results = nil

find.recent = find.recent or {}

find.cameFrom = nil

local indexing = false
local building = false

local loaded = false

local function ensure()
    if loaded then return end
    loaded = true
    find.load()
end

function find.remember_word(word)
    word = tostring(word or "")
    if word == "" then return end
    ensure()

    for index, had in ipairs(find.recent) do
        if had == word then table.remove(find.recent, index) break end
    end
    table.insert(find.recent, 1, word)

    while #find.recent > find.KEPT do
        table.remove(find.recent, #find.recent)
    end
    find.save()
end

function find.forget_words()
    find.recent = {}
    find.save()
    return true
end

function find.save()
    local text = ""
    for _, word in ipairs(find.recent) do
        local record = #word .. " " .. word
        if #text + #record > STORE_LIMIT then break end
        text = text .. record
    end
    OF.util.store(STORE_KEY, text)
end

function find.load()
    find.recent = {}
    if mod_storage_load == nil then return end
    local text = mod_storage_load(STORE_KEY, "")
    if text == nil or text == "" then return end

    local at = 1
    while at <= #text do
        local length, after = string.match(text, "^(%d+) ()", at)
        if length == nil then break end
        length = tonumber(length)
        local word = string.sub(text, after, after + length - 1)

        if #word < length then break end
        table.insert(find.recent, word)
        at = after + length
    end
end

local function stamp()
    local players = 0
    if OF.util.asks(OF.util, "connected_players") then
        players = #OF.util.connected_players()
    end

    local level, area = 0, 0
    local me = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    if me ~= nil then
        level = me.currLevelNum or 0
        area = me.currAreaIndex or 0
    end

    local tier = 0
    if OF.util.asks(OF.perms, "my_tier") then tier = OF.perms.my_tier() or 0 end

    local pages = 0
    if OF.panel ~= nil and type(OF.panel.PAGES) == "table" then
        for _ in pairs(OF.panel.PAGES) do pages = pages + 1 end
    end

    return table.concat({
        tostring(players), tostring(level), tostring(area), tostring(tier),
        tostring(pages),
        tostring(gGlobalSyncTable ~= nil and gGlobalSyncTable.ofGmState or ""),
        tostring(gGlobalSyncTable ~= nil and gGlobalSyncTable.ofGmMode or ""),
    }, "/")
end

find.SKIP_ROWS = {
    chatlog = true, actionlog = true, reports = true,
    search = true, quick = true, find = true, active = true,
}

function find.value_of(built)
    if built == nil then return nil end
    local text = OF.util.plain(tostring(built.text or ""))

    local tick = string.match(text, "^%[([xX%s%-])%]")
    if tick == "x" or tick == "X" then return OF.lang.t("on") end
    if tick == " " then return OF.lang.t("off") end
    if tick == "-" then return OF.lang.t("some") end

    local value = string.match(text, "^.-: (.*)$")
    if value ~= nil and value ~= "" then return value end

    local right = built.right
    if right ~= nil and right ~= "" then return OF.util.plain(tostring(right)) end
    return nil
end

local ALIAS_TAILS = { "", "s", "es", "d", "ed", "n", "ing" }

local function alias_reaches(lname, needle)
    local at = 1
    while true do
        local from, to = string.find(lname, needle, at, true)
        if from == nil then return false end
        local before = from > 1 and string.sub(lname, from - 1, from - 1) or ""
        if string.find(before, "%w") == nil then
            local rest = string.match(string.sub(lname, to + 1), "^%w*")
            for _, tail in ipairs(ALIAS_TAILS) do
                if rest == tail then return true end
            end
        end
        at = from + 1
    end
end
find.alias_reaches = alias_reaches

local function keywords_for(page, lname)
    local words = find.PAGE_ALIASES[page] or ""
    for needle, extra in pairs(find.ALIASES) do
        if alias_reaches(lname, needle) then
            words = words .. " " .. extra
        end
    end
    local squashed = string.gsub(lname, "[%s%p]", "")
    if squashed ~= "" and squashed ~= lname then
        words = words .. " " .. squashed
    end
    return string.lower(words)
end

local PROSE = 48

local function address(steps, keep)
    local parts = {}
    for _, step in ipairs(steps) do
        if step ~= "" and parts[#parts] ~= step then
            table.insert(parts, step)
        end
    end
    while keep ~= nil and #parts > keep do table.remove(parts, 1) end
    return table.concat(parts, " / ")
end

local function short_where(crumbs, heading, chose)
    return address({ #crumbs > 0 and crumbs[#crumbs] or "",
        chose or "", heading or "" }, 2)
end

local function long_where(crumbs, heading, chose)
    local steps = {}
    for _, crumb in ipairs(crumbs) do table.insert(steps, crumb) end
    table.insert(steps, chose or "")
    table.insert(steps, heading or "")
    return address(steps)
end

function find.row_name(built)
    if built == nil then return nil, nil end
    local rowKey = OF.panel.stable_key(built)

    local name = rowKey ~= nil
        and string.match(rowKey, "^%s*(.-)%s*$") or nil

    if built.key ~= nil and built.key ~= "" then
        local text = OF.util.plain(tostring(built.text or ""))
        text = string.gsub(text, "^%[[xX%s%-]%]%s*", "")
        local head = string.match(text, "^(.-): ")
        if head ~= nil and head ~= "" then text = head end
        if text ~= "" then name = text end
    end
    return name, rowKey
end

find.EXCLUDED = {

    heading = "a section title - what is under it is the destination",

    exit    = "the Back row",

    page    = "the whole page's rows are events, or copies of rows that live "
        .. "elsewhere - see find.SKIP_ROWS",

    unnamed = "a spacer - a row with no text at all",

    unpicked = "a page that reads a selection, drawn with none - its rows are "
        .. "indexed under each selection instead",

    prose   = "a sentence the cursor cannot rest on - the page explaining "
        .. "itself rather than a row to land on",

    twice   = "a second row on this page under a name already indexed",
    grid    = "a grid row - each of its cells is indexed by its own name, and "
        .. "the jump lands on the row with the cell picked (find.cells_of)",
}

local function refusal(built)
    return built.hostOnly == true or built.needs ~= nil
end

function find.why_skipped(pageKey, built, taken, sel)
    if built == nil then return "unnamed", nil end
    if find.SKIP_ROWS[pageKey] then return "page", nil end

    if built.shortcut == true then return "page", nil end
    if sel == nil and OF.panel ~= nil and OF.panel.PAGES ~= nil
        and find.selections_of(OF.panel.PAGES[pageKey]) ~= nil then
        return "unpicked", nil
    end
    if built.heading then return "heading", nil end
    if built.exit == true then return "exit", nil end
    if built.grid ~= nil then return "grid", nil end
    local name = find.row_name(built)
    if name == nil or name == "" then return "unnamed", nil end
    if #name > PROSE and built.action == nil and not refusal(built) then
        return "prose", name
    end
    if taken ~= nil and taken[name] == true then return "twice", name end
    return nil, name
end

local function sweep_of(def)
    local sweep = def ~= nil and def.selections or nil
    if type(sweep) ~= "table" then return nil end
    if type(sweep.held) ~= "function" or type(sweep.pick) ~= "function"
        or type(sweep.list) ~= "function" then
        return nil
    end
    return sweep
end
find.selections_of = sweep_of

find.AIMLESS = {

    aim        = "who a press on Do something to them goes to - it moves the "
        .. "aim line, the boxes and the rank, and never a row's name",

    levelMode  = "who a destination is for - it moves the aim line and not the "
        .. "list under it",

    pickMode   = "who the ticked page is acting for - the aim line again, and "
        .. "not the rows",

    banLength  = "how long the next ban runs - it writes the length into the "
        .. "ban row's label, which is why that row carries a key",
    rankLength = "how long a promotion lasts - the same shape as banLength, "
        .. "and the promote row carries a key for it",

    modReason  = "what a ban says on the tin - a right-hand column, never a "
        .. "row's name",

    opacity    = "how see-through the panel is drawn - a number in a column "
        .. "on one page",

    confirm    = "a press half made - both the open and the close clear it, so "
        .. "no index is built over one",

    permRankView = "which rank the ladder page is showing - every stop lists "
        .. "the same permissions, only the headers and the right column move",
}

function find.selection_name(sweep, sel)
    if sweep == nil or sel == nil then return nil end
    if type(sweep.name) ~= "function" then return nil end
    local ok, got = pcall(sweep.name, sel)
    if not ok or got == nil then return nil end
    got = string.match(OF.util.plain(tostring(got)), "^%s*(.-)%s*$")
    if got == "" then return nil end
    return got
end

function find.cells_of(built)
    local out = {}
    if built == nil or built.grid == nil then return out end
    local rowKey = OF.panel.stable_key(built)
    if rowKey == nil then return out end
    for col, cell in ipairs(built.grid.cells) do
        local name = string.match(OF.util.plain(tostring(cell.name or "")), "^%s*(.-)%s*$")
        if name ~= nil and name ~= "" then
            out[#out + 1] = { name = name, key = rowKey .. "#cell" .. tostring(col),
                pressable = cell.action ~= nil and built.action ~= nil }
        end
    end
    return out
end

local function index_page(out, key, def)
    local crumbs = OF.panel.trail(key)
    local title = OF.lang.t(def.title)

    table.insert(out, {
        kind = "page",
        page = key,
        name = title,
        lname = string.lower(title),
        value = nil,
        where = table.concat(crumbs, " / "),
        trail = table.concat(crumbs, " / "),
        words = keywords_for(key, string.lower(title)),
        pressable = true,

        prose = false,
    })

    if type(def.findAlso) == "function" then
        local ok, names = pcall(def.findAlso)
        if ok and type(names) == "table" then
            for _, extra in ipairs(names) do
                local name = OF.lang.t(tostring(extra))
                table.insert(out, {
                    kind = "page", page = key, name = name,
                    lname = string.lower(name), value = nil,
                    where = table.concat(crumbs, " / "),
                    trail = table.concat(crumbs, " / "),
                    words = keywords_for(key, string.lower(name)),
                    pressable = true, prose = false,
                })
            end
        end
    end

    if find.SKIP_ROWS[key] then return end
    if def.build == nil then return end

    local found, order = {}, {}

    local sweep = sweep_of(def)

    local function collect(sel)
        local wasPage, wasRows = OF.panel.page, OF.panel.rows
        local ok, rows = pcall(def.build)
        OF.panel.page, OF.panel.rows = wasPage, wasRows
        if not ok or type(rows) ~= "table" then return end

        local chose = find.selection_name(sweep, sel)

        local heading = nil
        for _, built in ipairs(rows) do
            if built.heading then

                heading = OF.util.plain(tostring(built.text or ""))
            elseif built.grid ~= nil then

                for _, cell in ipairs(find.cells_of(built)) do
                    if found[cell.name] == nil then
                        found[cell.name] = {
                            key = cell.key, value = nil,
                            where = short_where(crumbs, heading, chose),
                            trail = long_where(crumbs, heading, chose),
                            pressable = cell.pressable, prose = false,
                            sel = sel, heading = heading,
                        }
                        table.insert(order, cell.name)
                    end
                end
            else

                local why, name = find.why_skipped(key, built, nil, sel)
                if why == nil then

                    local at = found[name]
                    if at == nil then
                        local _, rowKey = find.row_name(built)
                        found[name] = {
                            key = rowKey,
                            value = find.value_of(built),
                            where = short_where(crumbs, heading, chose),
                            trail = long_where(crumbs, heading, chose),
                            pressable = built.action ~= nil,

                            prose = built.action == nil and built.walk ~= true
                                and not refusal(built),
                            sel = sel,

                            heading = heading,
                        }
                        table.insert(order, name)
                    end
                end
            end
        end
    end

    if sweep ~= nil then
        local okHeld, was = pcall(sweep.held)
        local okList, list = pcall(sweep.list)
        if okList and type(list) == "table" then
            for _, sel in ipairs(list) do
                if pcall(sweep.pick, sel) then collect(sel) end
            end
        end
        if okHeld then pcall(sweep.pick, was) end
    else
        collect(nil)
    end

    for _, name in ipairs(order) do
        local at = found[name]
        local lname = string.lower(name)
        table.insert(out, {
            kind = "row",
            page = key,
            key = at.key,

            sel = at.sel,
            name = name,
            lname = lname,
            value = at.value,
            where = at.where,
            trail = at.trail,
            words = keywords_for(key, lname),
            pressable = at.pressable,
            prose = at.prose,

            heading = at.heading,
        })
    end
end

function find.index()
    if not OF.util.asks(OF.panel, "trail") or type(OF.panel.PAGES) ~= "table" then
        return {}
    end

    local now = OF.util.optional("get_global_timer", 0) or 0
    local mark = stamp()
    local fresh = find.entries ~= nil
        and find.builtFor == mark
        and find.builtAt ~= nil
        and now >= find.builtAt
        and (now - find.builtAt) < find.STALE
    if fresh then return find.entries end

    if indexing then return find.entries or {} end
    indexing = true
    find.builds = find.builds + 1

    local out = {}

    for key, def in pairs(OF.panel.PAGES) do

        if key ~= "main" then
            local ok = pcall(index_page, out, key, def)
            if not ok then

                out = out
            end
        end
    end

    indexing = false
    find.entries = out
    find.builtAt = now
    find.builtFor = mark
    return out
end

function find.forget_index()
    find.entries = nil
    find.builtAt = nil
    find.builtFor = nil
    return true
end

local GUESS_SHORT = 4

local GUESS_FAR = 7

local function guess_allowance(word)
    if #word < GUESS_SHORT then return 0 end
    if #word < GUESS_FAR then return 1 end
    return 2
end

local function word_gap(a, b, cap)
    if a == b then return 0 end
    local la, lb = #a, #b
    if la > lb then a, b, la, lb = b, a, lb, la end
    if lb - la > cap then return cap + 1 end
    local prev = {}
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        local cur = { [0] = i }
        local best = i
        local ai = string.byte(a, i)
        for j = 1, lb do
            local step = prev[j - 1]
            if ai ~= string.byte(b, j) then step = step + 1 end
            local up = prev[j] + 1
            if up < step then step = up end
            local left = cur[j - 1] + 1
            if left < step then step = left end
            cur[j] = step
            if step < best then best = step end
        end
        if best > cap then return cap + 1 end
        prev = cur
    end
    return prev[lb]
end

local function guess_score(entry, word)
    local cap = guess_allowance(word)
    if cap == 0 then return 0 end
    local best = 0

    for had in string.gmatch(entry.lname, "[%w]+") do
        if #had >= GUESS_SHORT then
            local gap = word_gap(word, had, cap)
            if gap <= cap then
                local got = 30 - 8 * gap
                if got > best then best = got end
            end
        end
    end

    if entry.words ~= nil and entry.words ~= "" then
        for had in string.gmatch(entry.words, "[%w]+") do
            if #had >= GUESS_SHORT then
                local gap = word_gap(word, had, cap)
                if gap <= cap then
                    local got = 20 - 8 * gap
                    if got > best then best = got end
                end
            end
        end
    end

    return best
end

OF.find_word_gap = word_gap

local function score_word(entry, word, guess)
    local best = 0
    local name = entry.lname

    if name == word then
        best = 100
    elseif string.sub(name, 1, #word) == word then
        best = 70
    elseif string.find(name, "%f[%w]" .. word:gsub("(%W)", "%%%1")) ~= nil then

        best = 55
    elseif string.find(name, word, 1, true) ~= nil then
        best = 35
    end

    if best < 60 and entry.words ~= "" then
        for guess in string.gmatch(entry.words, "%S+") do
            if guess == word then

                local alias = entry.kind == "page" and 66 or 60
                if best < alias then best = alias end
            elseif string.sub(guess, 1, #word) == word then
                if best < 45 then best = 45 end
            end
        end
    end

    if best == 0 and string.find(string.lower(entry.where), word, 1, true) ~= nil then
        best = 12
    end

    if best == 0 and guess then best = guess_score(entry, word) end

    if best > 0 and entry.kind == "page" then best = best + 5 end
    return best
end

local PROSE_DIVISOR = 3

local function score_entry(entry, words, all, whole, guess)
    local total = 0
    for _, word in ipairs(words) do
        local got = score_word(entry, word, guess)
        if got == 0 and all then return 0 end
        total = total + got
    end
    if #words > 1 and whole ~= nil and entry.lname == whole then
        local exact = (entry.kind == "page" and 105 or 100) * #words
        if exact > total then total = exact end
    end
    if total > 0 and entry.prose == true then
        total = math.floor(total / PROSE_DIVISOR)
    end
    return total
end

function find.words_of(query)
    local words = {}
    for word in string.gmatch(string.lower(tostring(query or "")), "%S+") do
        table.insert(words, word)
    end
    return words
end

function find.match(query)
    local words = find.words_of(query)
    if #words == 0 then return {} end

    local entries = find.index()
    local out = {}

    local whole = table.concat(words, " ")

    local guessed = false
    for _, pass in ipairs({ { true, false }, { false, false },
                            { true, true }, { false, true } }) do
        out = {}
        for _, entry in ipairs(entries) do
            local score = score_entry(entry, words, pass[1], whole, pass[2])
            if score > 0 then
                table.insert(out, { entry = entry, score = score })
            end
        end
        if #out > 0 then
            guessed = pass[2]
            break
        end
    end

    table.sort(out, function(a, b)
        if a.score ~= b.score then return a.score > b.score end

        if (a.entry.kind == "page") ~= (b.entry.kind == "page") then
            return a.entry.kind == "page"
        end

        if #a.entry.lname ~= #b.entry.lname then
            return #a.entry.lname < #b.entry.lname
        end
        if a.entry.lname ~= b.entry.lname then
            return a.entry.lname < b.entry.lname
        end

        return tostring(a.entry.page) < tostring(b.entry.page)
    end)

    local ranked = {}
    for _, item in ipairs(out) do table.insert(ranked, item.entry) end

    return ranked, guessed
end

local function root_of(page)
    local tab = OF.panel.tab_of(page)
    for _, entry in ipairs(OF.panel.TABS or {}) do
        if entry.key == tab then return entry.page end
    end
    return "players"
end

function find.open()
    if not OF.util.asks(OF.panel, "go") then return false end
    local def = OF.panel.PAGES ~= nil and OF.panel.PAGES.find or nil
    if def == nil then return false end

    local from = OF.panel.page

    if from ~= nil and from ~= "find" and OF.panel.PAGES[from] ~= nil then
        if #OF.panel.trail(from) > 2 then from = root_of(from) end
        find.cameFrom = from
        def.up = from
    end

    OF.panel.go("find")
    return true
end

local function countless(key)
    return (string.gsub(tostring(key), "%(%d+[^()]*%)", "()"))
end
find.countless = countless

local function valueless(key)
    local head = string.match(tostring(key), "^(.-)%s%s+%S")
    if head == nil or head == "" then return nil end
    return head
end
find.valueless = valueless

function find.section_of(rows, at)
    if type(rows) ~= "table" then return nil end
    for index = at, 1, -1 do
        local built = rows[index]
        if type(built) == "table" and built.heading == true then
            local head = OF.panel.heading_of(built)
            if head == nil then head = tostring(built.text or "") end
            head = OF.util.plain(head)
            if head == "" then return nil end
            return head
        end
    end
    return nil
end

function find.row_at(rows, key, heading)
    if type(rows) ~= "table" or key == nil or key == "" then return nil end
    if heading ~= nil then heading = OF.util.plain(tostring(heading)) end
    local first, mine = nil, nil
    for index, built in ipairs(rows) do
        if not built.heading and built.exit ~= true
            and OF.panel.stable_key(built) == key then
            if first == nil then first = index end
            if heading ~= nil and mine == nil
                and find.section_of(rows, index) == heading then
                mine = index
            end
        end
    end
    if mine ~= nil then return mine end
    if first ~= nil then return first end

    local want = countless(key)
    if want ~= key then
        for index, built in ipairs(rows) do
            if not built.heading and built.exit ~= true then
                local had = OF.panel.stable_key(built)
                if had ~= nil and countless(had) == want then return index end
            end
        end
    end

    local stem = valueless(key)
    if stem ~= nil then
        local only, hits = nil, 0
        for index, built in ipairs(rows) do
            if not built.heading and built.exit ~= true then
                local had = OF.panel.stable_key(built)
                if had ~= nil and valueless(had) == stem then
                    hits = hits + 1
                    only = index
                end
            end
        end
        if hits == 1 then return only end
    end

    local best, at = nil, nil
    for index, built in ipairs(rows) do
        local plain = built.action == nil and built.altAction == nil
            and built.slider == nil
            and (built.right == nil or built.right == "")
        if plain and not built.heading and built.exit ~= true then
            local had = OF.panel.stable_key(built)
            if had ~= nil and #had > 0 and #had < #key
                and string.sub(key, 1, #had) == had
                and (best == nil or #had > #best) then
                best, at = had, index
            end
        end
    end
    return at
end

local function resting_at(rows, at)
    if type(OF.panel.is_stop) ~= "function" then return at end
    if OF.panel.is_stop(rows[at]) then return at end
    for index = at - 1, 1, -1 do
        local built = rows[index]

        if built.heading then
            if OF.panel.is_stop(built) then return index end
            return at
        end
        if built.exit ~= true and OF.panel.is_stop(built) then return index end
    end
    return at
end
find.resting_at = resting_at

find.GONE = "That row has gone since you searched - this is its page."
find.gone = nil

local function first_stop(rows)
    if OF.util.asks(OF.panel, "first_stop") then
        return OF.panel.first_stop(rows)
    end
    for index, built in ipairs(rows or {}) do
        if OF.panel.is_stop(built) then return index end
    end
    return nil
end

local function say_gone(key)
    find.gone = key
    if OF.util.asks(OF.notify, "show") then
        OF.notify.show(find.GONE, "warn")
    end
end

local function sole_selection(sweep, def, key)
    local okHeld, was = pcall(sweep.held)
    local okList, list = pcall(sweep.list)
    local only, hits = nil, 0
    if okList and type(list) == "table" and def.build ~= nil then
        for _, sel in ipairs(list) do
            if pcall(sweep.pick, sel) then
                local wasPage, wasRows = OF.panel.page, OF.panel.rows
                local ok, rows = pcall(def.build)
                OF.panel.page, OF.panel.rows = wasPage, wasRows
                if ok and type(rows) == "table"
                    and find.row_at(rows, key) ~= nil then
                    hits = hits + 1
                    only = sel
                end
            end
        end
    end
    if okHeld then pcall(sweep.pick, was) end
    if hits == 1 then return only end
    return nil
end

function find.jump(page, key, sel, heading)
    if not OF.util.asks(OF.panel, "go") then return false end
    if OF.panel.PAGES == nil or OF.panel.PAGES[page] == nil then return false end

    if OF.util.asks(OF.panel, "tab_is_open")
        and not OF.panel.tab_is_open(OF.panel.tab_of(page)) then
        OF.notify.show("That part of the menu is closed until the round ends",
            "warn", 4)
        return false
    end

    find.gone = nil

    local sweep = find.selections_of(OF.panel.PAGES[page])
    if sweep ~= nil and sel == nil and key ~= nil and key ~= "" then
        sel = sole_selection(sweep, OF.panel.PAGES[page], key)
    end
    if sel ~= nil and sweep ~= nil then pcall(sweep.pick, sel) end

    local blind = sweep ~= nil and sel == nil

    if type(OF.panel.folded) == "table" then
        local prefix = tostring(page) .. "\31"
        for folded in pairs(OF.panel.folded) do
            if type(folded) == "string"
                and string.sub(folded, 1, #prefix) == prefix then
                OF.panel.folded[folded] = nil
            end
        end
    end
    if type(OF.panel.foldSeen) == "table" then OF.panel.foldSeen[page] = true end

    local cellCol = nil
    if type(key) == "string" then
        local base, col = string.match(key, "^(.*)#cell(%d+)$")
        if base ~= nil then key, cellCol = base, tonumber(col) end
    end

    if key ~= nil and key ~= "" and not blind then
        OF.panel.landed = { page = page, key = key, heading = heading }
    else
        OF.panel.landed = nil
    end

    OF.panel.go(page)

    if key ~= nil and key ~= "" and not blind
        and type(OF.panel.rows) == "table" then

        local at = find.row_at(OF.panel.rows, key, heading)
        if at ~= nil then
            OF.panel.cursor = resting_at(OF.panel.rows, at)
            local landedOn = OF.panel.rows[OF.panel.cursor]
            if cellCol ~= nil and landedOn ~= nil and landedOn.grid ~= nil
                and OF.util.asks(OF.panel, "grid_select") then
                OF.panel.grid_select(landedOn, cellCol)
            end
        else

            local top = first_stop(OF.panel.rows)
            if top ~= nil then OF.panel.cursor = top end
            say_gone(key)
        end
    end
    return true
end

function find.run(query)
    local words = tostring(query or "")
    local results, guessed = find.match(words)
    find.word = words
    find.results = results
    find.guessed = guessed == true

    if #results > 0 and not find.guessed then find.remember_word(words) end
    find.open()
    return results
end

local VALUE_ROOM = 22

function find.result_label(entry)
    local name = entry.name
    local value = entry.value
    if entry.kind ~= "row" then return name end
    if value == nil or value == "" then return name end
    if string.lower(value) == entry.lname then return name end
    if #value > VALUE_ROOM then return name end
    return name .. ": " .. value
end

local function result_row(panel, entry, guess)
    local label = find.result_label(entry)

    local shade = entry.pressable and 255 or 150
    local built
    if guess then

        built = panel.row(label, shade, math.floor(shade * 0.86),
            math.floor(shade * 0.47), function()
                find.jump(entry.page, entry.key, entry.sel, entry.heading)
            end)
    else
        built = panel.row(label, shade, shade, shade, function()
            find.jump(entry.page, entry.key, entry.sel, entry.heading)
        end)
    end
    built = panel.with_right(built, entry.where)
    built = panel.with_help(built, entry.trail)

    built.match = find.word
    built.smallRight = true
    return panel.with_key(built, "find\31" .. tostring(entry.page)
        .. "\31" .. tostring(entry.sel or "")
        .. "\31" .. tostring(entry.key or entry.name))
end

local function said(panel, text, help, r, g, b)
    local built = panel.label_row(text, r, g, b)
    built.walk = true
    return panel.with_help(built, help)
end

local function build_empty(panel, rows)
    table.insert(rows, said(panel, OF.lang.t(
        "Type /search and a word in chat - the matches land here, pressable."),
        OF.lang.t("every row in the menu, by name, wherever it lives")))

    table.insert(rows, said(panel, OF.lang.t(
        "/s and /f are the same word, for when you are in a hurry."),
        OF.lang.t("three names, one search")))

    ensure()
    if #find.recent > 0 then
        table.insert(rows, panel.header_row(OF.lang.t("What you looked for")))

        for _, word in ipairs(find.recent) do
            local built = panel.row(word, 255, 220, 120, function()
                find.run(word)
            end)
            table.insert(rows, panel.with_help(built,
                OF.lang.t("search for this word again")))
        end
        table.insert(rows, panel.with_help(
            panel.row(OF.lang.t("Forget these"), 180, 180, 180,
                function() OF.util.report(find.forget_words()) end),
            OF.lang.t("drops the words above - only this machine ever had them")))
    end

    local function named(entry)
        local exact, only, agree = nil, nil, true
        for _, held in ipairs(find.entries or {}) do
            if held.kind == "row" and held.page == entry.page
                and held.key == entry.key and held.name ~= nil then
                if exact == nil and held.sel == entry.sel then
                    exact = held.name
                end
                if only == nil then only = held.name
                elseif only ~= held.name then agree = false end
            end
        end
        if exact ~= nil then return exact end
        if agree and only ~= nil then return only end
        return entry.key
    end

    if OF.util.asks(OF.quick, "top") then
        local top = OF.quick.top()
        if #top > 0 then
            table.insert(rows, panel.header_row(OF.lang.t("What you reach for")))
            for _, entry in ipairs(top) do
                local def = panel.PAGES[entry.page]
                if def ~= nil then

                    local where = OF.lang.t(def.title)
                    local chose = find.selection_name(
                        find.selections_of(def), entry.sel)
                    if chose ~= nil then where = where .. " / " .. chose end
                    local built = panel.row(named(entry), 255, 255, 255,
                        function()
                            find.jump(entry.page, entry.key, entry.sel)
                        end)
                    built = panel.with_right(built, where)

                    table.insert(rows, panel.with_help(built, table.concat(
                        panel.trail(entry.page), " / ")))
                end
            end
        end
    end
    return rows
end

local function page_rows(panel)
    local rows = {}
    if find.word == nil or find.word == "" then
        build_empty(panel, rows)
    else
        local results = find.results or {}
        if #results == 0 then
            table.insert(rows, panel.label_row(
                OF.lang.fill("Nothing matches '@'.", find.word)))
            table.insert(rows, panel.label_row(OF.lang.t(
                "Try a shorter word - half of one is usually enough.")))
            build_empty(panel, rows)
        else

            local guessing = find.guessed == true
            if guessing then
                table.insert(rows, panel.label_row(OF.lang.fill(
                    "Nothing matches '@' - these are guesses", find.word),
                    255, 220, 120))
            else
                table.insert(rows, panel.label_row(OF.lang.fill(
                    "@ in the menu match '@'", tostring(#results), find.word)))
            end

            local shown, groups, order = 0, {}, {}
            for _, entry in ipairs(results) do
                if shown >= find.SHOWN then break end
                local tab = OF.util.asks(panel, "tab_of") and panel.tab_of(entry.page) or 0
                if groups[tab] == nil then
                    groups[tab] = {}
                    order[#order + 1] = tab
                end
                table.insert(groups[tab], entry)
                shown = shown + 1
            end
            local tabByKey = {}
            for _, def in ipairs(panel.TABS or {}) do tabByKey[def.key] = def end
            for _, tab in ipairs(order) do
                local def = tabByKey[tab]
                if #order > 1 and def ~= nil and OF.util.asks(panel, "sub_header_row") then
                    table.insert(rows, panel.with_help(panel.sub_header_row(OF.lang.t(def.name)),
                        OF.lang.t("the matches on this tab")))
                end
                for _, entry in ipairs(groups[tab]) do
                    table.insert(rows, result_row(panel, entry, guessing))
                end
            end
            if #results > shown then
                table.insert(rows, panel.label_row(OF.lang.fill(
                    "@ more - a longer word narrows it.",
                    tostring(#results - shown))))
            end

            if OF.util.asks(OF.panel, "search") then

                table.insert(rows, panel.with_help(panel.row(
                    OF.lang.t("Show the rows themselves..."), 255, 220, 120,
                    function()
                        local word = find.word
                        if word == nil or word == "" then return end
                        pcall(OF.panel.search, word)
                        OF.panel.go("search")
                    end),
                    OF.lang.t(
                        "the same matches as real rows, pressable where they stand")))
            end
        end
    end

    table.insert(rows, panel.back_row("client"))
    return rows
end

function find.build_page(panel)
    if building then
        return { panel.label_row(OF.lang.t("Searching...")) }
    end
    building = true
    local ok, rows = pcall(page_rows, panel)
    building = false
    if not ok or type(rows) ~= "table" then
        return {
            panel.label_row(OF.lang.t("The search could not be drawn.")),
            panel.back_row("client"),
        }
    end
    return rows
end

function find.tab_root_row(panel)
    if panel == nil or panel.page == nil or panel.page == "find" then return nil end
    local roots = {}
    for _, tab in ipairs(panel.TABS or {}) do roots[tab.page] = true end
    if not roots[panel.page] then return nil end

    local built = panel.with_tone(panel.row(OF.lang.t("Find anything..."), 255, 220, 120,
        function() find.open() end), "key")
    built = panel.with_right(built, "/search")
    built = panel.with_help(built, OF.lang.t(
        "type /search and a word in chat - the matches land on a page you can press"))

    built.outside = true
    return panel.with_key(built, "findanything")
end

local function looking()
    return OF.panel ~= nil and OF.panel.open == true
end

function find.chat(msg)
    msg = msg or ""
    if OF.util.asks(OF.perms, "can") and not OF.perms.can("panel") then
        local said = OF.lang.t("Your rank cannot open the mod menu.")
        if OF.util.asks(OF.perms, "required")
            and OF.util.asks(OF.perms, "tier_name") then
            local needs = OF.perms.required("panel")
            if needs < OF.TIER.HOST then
                said = OF.lang.fill(
                    "The mod menu opens at @ - ask the host for it.",
                    OF.lang.t(OF.perms.tier_name(needs)))
            end
        end
        OF.util.chat(said, "warn")
        return true
    end

    if msg == "" then
        find.word = nil
        find.results = nil
        if not find.open() then
            OF.util.chat(OF.lang.t("The menu did not load."), "warn")
            return true
        end
        ensure()

        local said
        if #find.recent > 0 then
            said = looking()
                and OF.lang.t("What you looked for is in front of you.")
                or OF.lang.t("Open the menu - what you looked for is on it.")
        else
            said = OF.lang.t("Say what to look for: /search knockback")
        end
        OF.util.chat(said)
        return true
    end

    local results = find.run(msg)
    if #results == 0 then
        OF.util.chat(OF.lang.fill("Nothing in the menu matches '@'.", msg), "warn")
        OF.util.chat(OF.lang.t(
            "Try a shorter word - half of one is usually enough."), nil, { more = true })
        return true
    end

    if looking() then
        OF.util.chat(OF.lang.fill(
            "@ in the menu match '@' - they are in front of you.",
            tostring(#results), msg))
    else
        OF.util.chat(OF.lang.fill(
            "@ in the menu match '@' - open the mod menu to see them.",
            tostring(#results), msg))
    end
    return true
end

hook_chat_command("search", "<words> - find any row in the menu and go to it",
    function(msg) return find.chat(msg) end)
hook_chat_command("find", "<words> - find any row in the menu and go to it",
    function(msg) return find.chat(msg) end)
hook_chat_command("s", "<words> - find any row in the menu and go to it",
    function(msg) return find.chat(msg) end)
hook_chat_command("f", "<words> - find any row in the menu and go to it",
    function(msg) return find.chat(msg) end)

function find.ready()
    return true
end
