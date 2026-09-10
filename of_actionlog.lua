OF = OF or {}
OF.actionlog = OF.actionlog or {}

local actionlog = OF.actionlog

local MOST = 240

local MOST_REFUSED = 4

actionlog.entries = actionlog.entries or {}

function actionlog.count()
    return #actionlog.entries
end

actionlog.BY_THE_ROOM = "the lobby"
actionlog.ROOM_RANK = "itself"
local function now_frame()
    return get_global_timer and get_global_timer() or 0
end

actionlog.KIND_MENU = "menu"
actionlog.KIND_ACTION = "action"
actionlog.KIND_ROOM = "room"
actionlog.KIND_MINE = "mine"
actionlog.KIND_STOPS = {
    actionlog.KIND_MENU, actionlog.KIND_ACTION, actionlog.KIND_ROOM,
    actionlog.KIND_MINE }

function actionlog.kind_name(kind)
    if kind == actionlog.KIND_MENU then return OF.lang.t("menu presses") end
    if kind == actionlog.KIND_ACTION then return OF.lang.t("what was done") end
    if kind == actionlog.KIND_ROOM then return OF.lang.t("the lobby itself") end
    if kind == actionlog.KIND_MINE then
        return OF.lang.t("done to themselves")
    end
    return OF.lang.t("everything")
end

local A_MINUTE = 30 * 60
actionlog.WHEN_STOPS = { A_MINUTE, 10 * A_MINUTE, 60 * A_MINUTE }

function actionlog.next_stop(stops, current)
    if current == nil or current == "" then return stops[1] end
    for index, value in ipairs(stops) do
        if value == current then return stops[index + 1] end
    end
    return nil
end

function actionlog.when_name(within)
    if within == A_MINUTE then return OF.lang.t("the last minute") end
    if within == 10 * A_MINUTE then return OF.lang.t("the last ten minutes") end
    if within == 60 * A_MINUTE then return OF.lang.t("the last hour") end
    return OF.lang.t("the whole session")
end

local LINE_CUT = 46
local CHANGE_CUT = 28
local LEAST_SENTENCE = 12

local VALUE_CUT = 20
local function short_value(value)
    if value == nil then return nil end
    value = OF.util.plain(tostring(value))
    if value == "" then return nil end
    return OF.util.shorten(value, VALUE_CUT)
end

local behalfName, behalfFrame = nil, -9999

function actionlog.behalf(name)
    if name == nil or name == "" then return false end
    behalfName, behalfFrame = OF.util.plain(tostring(name)), now_frame()
    return true
end

local function rank_of(name)
    if name == nil or name == "" then return "" end
    local needle = string.lower(OF.util.plain(name))
    for _, entry in ipairs(OF.util.connected_players()) do
        if string.lower(OF.util.plain(entry.np.name)) == needle then
            return OF.perms.tier_name(OF.perms.tier(entry.localIndex))
        end
    end
    return ""
end

function actionlog.record(what, who, change)
    if what == nil or what == "" then return false end

    local kind, was, now, case = nil, nil, nil, nil
    if type(change) == "table" then
        kind = change.kind
        was, now = change.was, change.now
        case = change.case
    elseif type(change) == "string" and change ~= "" then
        kind = change
    end

    local stamp = "--:--"
    if OF.util.asks(OF.chatlog, "stamp") then stamp = OF.chatlog.stamp() end

    if who == nil and behalfName ~= nil and now_frame() == behalfFrame then
        who, behalfName = behalfName, nil
    end
    local plain = OF.util.plain(tostring(who or OF.lang.t("the host")))

    local rank
    local byTheRoom = false
    if who == nil then
        rank = "host"
    elseif plain == OF.lang.t(actionlog.BY_THE_ROOM) then
        rank = actionlog.ROOM_RANK
        byTheRoom = true
    else
        rank = rank_of(plain)
    end

    if kind == nil then
        kind = byTheRoom and actionlog.KIND_ROOM or actionlog.KIND_ACTION
    end
    table.insert(actionlog.entries, {
        time = stamp,
        who = plain,
        rank = rank,

        what = OF.util.plain(tostring(what)),

        kind = kind,
        was = short_value(was),
        now = short_value(now),

        case = short_value(case),

        at = now_frame(),
    })

    while #actionlog.entries > MOST do
        local held, busiest, most = {}, nil, 0
        for _, entry in ipairs(actionlog.entries) do
            local count = (held[entry.who] or 0) + 1
            held[entry.who] = count
            if count > most then most, busiest = count, entry.who end
        end
        for index, entry in ipairs(actionlog.entries) do
            if entry.who == busiest then
                table.remove(actionlog.entries, index)
                break
            end
        end
    end
    return true
end

function actionlog.auto(what, was, now, case)
    if not OF.util.is_host() then return false end
    return actionlog.record(what, actionlog.BY_THE_ROOM,
        { kind = actionlog.KIND_ROOM, was = was, now = now, case = case })
end

function actionlog.by_hand(who, what, was, now)
    if who == nil or who == "" then return false end
    if not OF.util.is_host() then return false end
    return actionlog.record(what, who, { was = was, now = now })
end

local PACKET_LOG = "ofLogUse"
local RATE_FRAMES = 30
local lastSent = -9999
local lastLine = nil

local function rows_of_page(page)
    local panel = OF.panel
    if panel == nil or panel.PAGES == nil then return nil end
    local def = panel.PAGES[page]
    if def == nil or def.build == nil then return nil end
    local wasPage, wasRows = panel.page, panel.rows
    local ok, rows = pcall(def.build)
    panel.page, panel.rows = wasPage, wasRows
    if not ok or type(rows) ~= "table" then return nil end
    return rows
end

local reading = false

local TICK = "^%[([Xx%s%-])%]%s*"
local function tick_free_key(built)
    local key = OF.panel.stable_key(built)
    if key == nil then return nil end
    return (string.gsub(key, TICK, ""))
end

local function value_of(built)
    local value = OF.panel.row_value(built)
    if value == nil then return nil end
    local box = string.match(value, TICK)
    if box == "X" or box == "x" then return OF.lang.t("on") end
    if box == " " then return OF.lang.t("off") end
    if box == "-" then return OF.lang.t("some") end
    return value
end

local function what_changed(what, steady)

    if steady == true then return nil, nil end
    if reading then return nil, nil end

    local panel = OF.panel
    if panel == nil or not panel.open then return nil, nil end
    if not OF.util.asks(panel, "row_value") then return nil, nil end
    if not OF.util.asks(panel, "stable_key") then return nil, nil end

    local row = panel.rows ~= nil and panel.rows[panel.cursor] or nil
    if row == nil then return nil, nil end
    local said = OF.util.plain(tostring(row.confirming or row.text or ""))
    if said == "" or #said > #what then return nil, nil end
    if string.sub(what, -#said) ~= said then return nil, nil end

    local key = tick_free_key(row)
    local before = value_of(row)
    if key == nil or before == nil then return nil, nil end

    reading = true
    local rows = rows_of_page(panel.page)
    reading = false
    if rows == nil then return nil, nil end

    for _, built in ipairs(rows) do
        if tick_free_key(built) == key then
            local after = value_of(built)
            if after == nil or after == before then return nil, nil end
            if OF.util.asks(panel, "differing_part") then
                return panel.differing_part(before, after)
            end
            return before, after
        end
    end
    return nil, nil
end

function actionlog.report(what, steady, kind)
    if what == nil or what == "" then return false end
    what = tostring(what)

    if kind ~= actionlog.KIND_MINE then kind = actionlog.KIND_MENU end

    local frame = now_frame()
    if frame - lastSent < RATE_FRAMES and (steady == true or what == lastLine) then
        return false
    end
    lastSent, lastLine = frame, what

    local was, now = what_changed(what, steady)

    local np = gNetworkPlayers[0]
    local name = np ~= nil and OF.util.plain(np.name) or "somebody"
    if OF.util.is_host() then
        return actionlog.record(what, name,
            { kind = kind, was = was, now = now })
    end

    return OF.util.send_to_host({ ofp = PACKET_LOG, w = tostring(what),
        f = short_value(was), t = short_value(now),
        me = kind == actionlog.KIND_MINE or nil })
end

hook_event(HOOK_ON_PACKET_RECEIVE, function(data)
    if data == nil or data.ofp ~= PACKET_LOG then return end
    if not OF.util.is_host() then return end

    local li = OF.util.asked_by(data)
    if li == nil then return end
    local np = gNetworkPlayers[li]
    if np == nil then return end

    actionlog.record(tostring(data.w), OF.util.plain(np.name),
        { kind = data.me == true and actionlog.KIND_MINE
            or actionlog.KIND_MENU, was = data.f, now = data.t })
end)

function actionlog.clear()
    actionlog.entries = {}

    if actionlog.forget_room ~= nil then actionlog.forget_room() end
end

function actionlog.by(name)
    local needle = string.lower(tostring(name or ""))
    if needle == "" then return actionlog.entries end

    local found = {}
    for _, entry in ipairs(actionlog.entries) do
        if string.find(string.lower(entry.who), needle, 1, true) then
            table.insert(found, entry)
        end
    end
    return found
end

local SENTENCE_NEEDLE = 2

function actionlog.touching(name)
    local needle = string.lower(tostring(name or ""))
    if needle == "" then return actionlog.entries end
    if #needle < SENTENCE_NEEDLE then return actionlog.by(name) end

    local found = {}
    for _, entry in ipairs(actionlog.entries) do
        if string.find(string.lower(entry.who), needle, 1, true)
            or string.find(string.lower(entry.what), needle, 1, true)
            or (entry.case ~= nil and string.lower(entry.case) == needle) then
            table.insert(found, entry)
        end
    end
    return found
end

function actionlog.names()
    local seen, list = {}, {}
    for index = #actionlog.entries, 1, -1 do
        local who = actionlog.entries[index].who
        if not seen[who] then
            seen[who] = true
            table.insert(list, who)
        end
    end
    return list
end

function actionlog.people()
    local list = actionlog.names()
    local seen = {}
    for _, who in ipairs(list) do seen[string.lower(who)] = true end

    for _, entry in ipairs(OF.util.connected_players()) do
        local name = OF.util.plain(entry.np.name)
        local key = string.lower(name)
        if not seen[key] and #key >= SENTENCE_NEEDLE then
            for _, line in ipairs(actionlog.entries) do
                if string.find(string.lower(line.what), key, 1, true) then
                    seen[key] = true
                    table.insert(list, name)
                    break
                end
            end
        end
    end
    return list
end

function actionlog.filtered(who, kind, within)
    local found = actionlog.touching(who)
    local narrow = (kind ~= nil and kind ~= "")
    local recent = (within ~= nil and within > 0)
    if not narrow and not recent then return found end

    local frame = now_frame()
    local kept = {}
    for _, entry in ipairs(found) do

        local rightKind = (not narrow) or entry.kind == kind
        local rightWhen = (not recent) or entry.at == nil
            or (frame - entry.at) <= within
        if rightKind and rightWhen then
            kept[#kept + 1] = entry
        end
    end
    return kept
end

local WATCH_FRAMES = 60

local MOST_AT_ONCE = 4

local SAID_NEEDLE = 3

local watched = nil
local watchedRules = nil
local watchedAt = -9999
local watchedCount = 0

local function room_state()
    if not OF.util.asks(OF.fresh, "left_on") then return nil end
    local ok, left = pcall(OF.fresh.left_on)
    if not ok or type(left) ~= "table" then return nil end
    local state = {}
    for _, entry in ipairs(left) do
        if type(entry) == "table" and entry.name ~= nil then
            state[tostring(entry.name)] = tostring(entry.what or "")
        end
    end
    return state
end

local function rules_state()
    if not OF.util.asks(OF.rules, "wire_text") then return nil end
    local ok, text = pcall(OF.rules.wire_text)
    if not ok or type(text) ~= "string" then return nil end
    return text
end

local RULES_REGISTRY = "the lobby rules"
local function rules_moved(before, after)
    if not OF.util.asks(OF.rules, "parse_text") then return {} end
    if not OF.util.asks(OF.rules, "option_name") then return {} end
    if type(OF.rules.LIST) ~= "table" then return {} end

    local ok, was = pcall(OF.rules.parse_text, before)
    if not ok or type(was) ~= "table" then return {} end
    local now
    ok, now = pcall(OF.rules.parse_text, after)
    if not ok or type(now) ~= "table" then return {} end

    local moved = {}
    for _, entry in ipairs(OF.rules.LIST) do
        if entry.key ~= nil and was[entry.key] ~= now[entry.key] then

            local from, to = nil, nil
            if was[entry.key] ~= nil then
                from = OF.rules.option_name(entry, was[entry.key])
            end
            if now[entry.key] ~= nil then
                to = OF.rules.option_name(entry, now[entry.key])
            end

            local needles = { entry.name }
            if from ~= nil then needles[#needles + 1] = from end
            if to ~= nil then needles[#needles + 1] = to end
            moved[#moved + 1] = { name = entry.name, was = from, now = to,
                                  needles = needles }
        end
    end
    return moved
end

local function already_said(from, upTo, needles)
    from = math.max(1, math.min(from, #actionlog.entries) + 1)
    upTo = math.min(upTo, #actionlog.entries)
    for index = from, upTo do
        local entry = actionlog.entries[index]
        local said = string.lower(tostring(entry.what or "") .. " "
            .. tostring(entry.now or ""))
        for _, needle in ipairs(needles) do
            if type(needle) == "string" and #needle >= SAID_NEEDLE
                and string.find(said, string.lower(needle), 1, true) ~= nil then
                return true
            end
        end
    end
    return false
end

function actionlog.watch_room()
    if not OF.util.is_host() then return false end
    local frame = now_frame()
    if frame - watchedAt < WATCH_FRAMES then return false end
    watchedAt = frame

    local state = room_state()
    if state == nil then return false end
    local ruleText = rules_state()

    if watched == nil then
        watched, watchedRules, watchedCount = state, ruleText, #actionlog.entries
        return false
    end

    local names = {}
    for name in pairs(state) do names[#names + 1] = name end
    for name in pairs(watched) do
        if state[name] == nil then names[#names + 1] = name end
    end

    table.sort(names)

    local moved = {}
    for _, name in ipairs(names) do
        local was, now = watched[name] or "", state[name] or ""
        if was ~= now then
            local a, b = was, now
            if OF.util.asks(OF.panel, "differing_part") then
                a, b = OF.panel.differing_part(was, now)
            end
            moved[#moved + 1] = { name = name, was = was, now = now,
                                  needles = { name, a, b } }
        end
    end

    local fine = {}
    if ruleText ~= nil and watchedRules ~= nil and ruleText ~= watchedRules then
        fine = rules_moved(watchedRules, ruleText)
    end
    if #fine > 0 then
        for index = #moved, 1, -1 do
            if moved[index].name == RULES_REGISTRY then
                table.remove(moved, index)
            end
        end
        for _, change in ipairs(fine) do moved[#moved + 1] = change end
    end

    local upTo = #actionlog.entries
    local filed, more = 0, 0
    for _, change in ipairs(moved) do
        if already_said(watchedCount, upTo, change.needles) then

        elseif filed >= MOST_AT_ONCE then
            more = more + 1
        else
            filed = filed + 1
            actionlog.auto(OF.lang.fill("@ changed", change.name),
                change.was, change.now)
        end
    end
    if more > 0 then
        actionlog.auto(OF.lang.fill("and @ more settings moved", more))
    end

    watched, watchedRules, watchedCount = state, ruleText, #actionlog.entries
    return filed > 0 or more > 0
end

function actionlog.forget_room()
    watched, watchedRules, watchedAt, watchedCount = nil, nil, -9999, 0
end

function actionlog.refused_by_feature()
    local list = {}
    if not OF.util.asks(OF.trouble, "refusals") then return list end
    if type(OF.trouble.refusals) ~= "table" then return list end

    local held = {}
    for order, entry in ipairs(OF.trouble.refusals) do
        local key = entry.feature
        if type(key) == "string" and key ~= "" then
            local got = held[key]
            if got == nil then

                got = { feature = key, count = 0, names = {}, order = order }
                held[key] = got
                list[#list + 1] = got
            end
            got.count = got.count + (tonumber(entry.count) or 1)
            if entry.name ~= nil and entry.name ~= "" then
                got.names[#got.names + 1] = tostring(entry.name)
            end
        end
    end

    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.order < b.order
    end)
    return list
end

function actionlog.refused_help(entry)
    if entry == nil or #entry.names == 0 then
        return OF.lang.t("Somebody pressed this and their rank said no.")
    end
    if #entry.names == 1 then
        return OF.lang.fill("@ pressed this and their rank said no.",
            OF.util.shorten(entry.names[1], 14))
    end
    return OF.lang.fill("@ and @ other(s) pressed this and their rank said no.",
        OF.util.shorten(entry.names[1], 14), #entry.names - 1)
end

hook_chat_command("oflog", "- who has been using the menu, and what happened to a name",
    function(msg)
        if not OF.util.allowed("jail") then return true end
        msg = msg or ""
        local found = actionlog.touching(msg)

        local case = nil
        if msg ~= "" and OF.util.asks(OF.trouble, "case") then
            case = OF.trouble.case(msg)
        end
        if case ~= nil then
            local said = OF.lang.fill("Case @: @", case.code, case.kind)
                .. " - " .. case.name
            if case.detail ~= nil and case.detail ~= "" then
                said = said .. " (" .. case.detail .. ")"
            end

            OF.util.chat(OF.util.accent() .. said)
        end

        if #found == 0 then

            if case ~= nil then return true end

            if msg ~= "" and #actionlog.entries > 0 then
                OF.util.chat("\\#808080\\" .. OF.lang.fill(
                    "Nothing here mentions '@'.", msg))
            else
                OF.util.chat("\\#808080\\" .. OF.lang.t("Nothing recorded yet."))
            end
            return true
        end

        if msg ~= "" then
            OF.util.chat(OF.lang.fill("@ thing(s) by or about '@':",
                tostring(#found), msg))
        else
            OF.util.chat(OF.lang.fill("@ thing(s) done:", #found))
        end
        local from = math.max(1, #found - 11)
        for index = from, #found do
            local entry = found[index]

            local moved = ""
            if entry.was ~= nil or entry.now ~= nil then
                moved = "\\#808080\\  " .. tostring(entry.was or OF.lang.t("nothing"))
                    .. " -> " .. tostring(entry.now or OF.lang.t("nothing"))
            end

            local numbered = ""
            if OF.util.asks(OF.trouble, "case_suffix") then
                numbered = OF.trouble.case_suffix(entry.case)
            end
            djui_chat_message_create("  \\#808080\\" .. entry.time
                .. "\\#ffff00\\ " .. entry.who .. "\\#dcdcdc\\  "
                .. entry.what .. numbered .. moved)
        end
        return true
    end)

function actionlog.build_page(panel)
    local rows = {}

    local who = panel.logWho
    if who == "" then who = nil end
    local kind = panel.logKind
    local within = panel.logSince
    local found = actionlog.filtered(who, kind, within)
    local names = actionlog.people()

    local refused = actionlog.refused_by_feature()
    if #refused > 0 then
        local shown = math.min(#refused, MOST_REFUSED)
        table.insert(rows, panel.with_help(
            panel.header_row(OF.lang.t("Stopped by a rank")),
            OF.lang.fill(
                "@ thing(s) somebody pressed and their rank would not let them.",
                #refused)))
        for index = 1, shown do
            local entry = refused[index]

            local said = entry.feature
            if OF.util.asks(OF.perms, "LABELS") then
                said = OF.perms.LABELS[entry.feature] or entry.feature
            end

            table.insert(rows, panel.with_help(panel.with_right(
                panel.with_walk(panel.label_row(OF.lang.t(said), 255, 200, 120)),
                OF.lang.fill("@ time(s)", entry.count)),
                actionlog.refused_help(entry)))
        end

        local ladder = panel.host_row("settings",
            OF.lang.t("Set who may do these..."), 255, 255, 255,
            function() panel.go("perms") end)
        panel.with_help(ladder, OF.lang.t(
            "Opens the ladder, where the rung each of these wants is set."))
        table.insert(rows, ladder)
    end

    if #names > 0 then
        local person = panel.row(
            panel.tick(who ~= nil, OF.lang.t("One name only")),
            255, 200, 120, function()
                panel.logWho = actionlog.next_stop(names, panel.logWho)
                panel.scroll = 0
            end)

        panel.level_right(person, who ~= nil, who ~= nil
            and OF.util.shorten(who, 14) or nil)
        panel.with_help(person, OF.lang.t(
            "Step through every name this log holds, the lobby itself among them."))
        table.insert(rows, person)
    end

    local sort = panel.row(
        panel.tick(kind ~= nil and kind ~= "", OF.lang.t("One kind only")),
        255, 200, 120, function()
            panel.logKind = actionlog.next_stop(actionlog.KIND_STOPS, panel.logKind)
            panel.scroll = 0
        end)
    panel.level_right(sort, kind ~= nil and kind ~= "", actionlog.kind_name(kind))

    panel.with_help(sort, OF.lang.t(
        "narrow the list to one sort of line"))
    table.insert(rows, sort)

    local when = panel.row(
        panel.tick(within ~= nil and within > 0, OF.lang.t("Recent only")),
        255, 200, 120, function()
            panel.logSince = actionlog.next_stop(actionlog.WHEN_STOPS, panel.logSince)
            panel.scroll = 0
        end)
    panel.level_right(when, within ~= nil and within > 0, actionlog.when_name(within))
    panel.with_help(when, OF.lang.t(
        "drop everything older than the stretch of time on the right"))
    table.insert(rows, when)

    if #found ~= actionlog.count() then
        table.insert(rows, panel.with_help(panel.label_row(
            OF.lang.fill("@ of @ shown", #found, actionlog.count())),
            OF.lang.t("How much of the record the rows above are letting past.")))
    end

    if #found == 0 then

        local said = OF.lang.t("Nothing recorded yet.")
        if actionlog.count() > 0 then
            said = OF.lang.t("Nothing here matches. Widen it with the rows above.")
        end
        table.insert(rows, panel.with_help(panel.label_row(said),
            OF.lang.t("there is nothing to show under the rows above")))
    end

    for index = #found, 1, -1 do
        local entry = found[index]

        local said = OF.util.shorten(entry.who, 14)
        if entry.rank ~= nil and entry.rank ~= "" then
            said = said .. " (" .. entry.rank .. ")"
        end

        local pressed = entry.who

        local numbered = ""
        if entry.case ~= nil and OF.util.asks(OF.trouble, "case_suffix") then
            numbered = OF.trouble.case_suffix(entry.case)
        end
        local budget = LINE_CUT - #numbered
        if budget < LEAST_SENTENCE then budget = LEAST_SENTENCE end
        local sentence = entry.what
        if entry.was ~= nil or entry.now ~= nil then

            local change = OF.util.shorten(
                tostring(entry.was or OF.lang.t("nothing")) .. " -> "
                    .. tostring(entry.now or OF.lang.t("nothing")), CHANGE_CUT)
            local room = budget - #change - 2
            if room < LEAST_SENTENCE then room = LEAST_SENTENCE end

            sentence = OF.util.shorten(sentence, room) .. numbered
                .. "  " .. change
        else
            sentence = OF.util.shorten(sentence, budget) .. numbered
        end
        local line = panel.row(
            entry.time .. "  " .. said .. "  " .. sentence,
            220, 220, 220, function()
                panel.logWho = pressed
                panel.scroll = 0
            end)
        panel.with_help(line, OF.lang.t(
            "Press to read this name's lines on their own."))
        rows[#rows + 1] = line
    end

    if #names > 1 and who == nil then

        table.insert(rows, panel.header_row(OF.lang.t("Show one name only")))
        for _, name in ipairs(names) do
            table.insert(rows, panel.with_help(
                panel.row(name, 255, 255, 255, function()
                    panel.logWho = name
                    panel.scroll = 0
                end),
                OF.lang.t("Show only the lines this name is in.")))
        end
    end

    local clear = panel.host_row("jail", OF.lang.t("Clear the log"),
        255, 140, 90, function()
            actionlog.clear()
            panel.scroll = 0
        end)
    if clear.action ~= nil then
        clear = panel.confirm_row("clearactionlog", OF.lang.t("Clear the log"),
            255, 140, 90, function()
                actionlog.clear()
                panel.scroll = 0
            end)
    end
    panel.with_help(clear, OF.lang.t("throw the whole record away and start it empty"))
    table.insert(rows, clear)

    table.insert(rows, panel.back_row())
    return rows
end
