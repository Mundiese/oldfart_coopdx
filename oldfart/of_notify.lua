OF = OF or {}
OF.notify = OF.notify or {}

local notify = OF.notify

notify.PACKET = "note"
notify.KINDS = {
    good  = { r = 120, g = 255, b = 140, icon = "+",  sound = SOUND_MENU_MESSAGE_APPEAR },
    info  = { r = 255, g = 255, b = 255, icon = "i",  sound = SOUND_MENU_MESSAGE_APPEAR },
    warn  = { r = 255, g = 200, b = 90,  icon = "!",  sound = SOUND_MENU_MESSAGE_APPEAR },
    bad   = { r = 255, g = 100, b = 100, icon = "x",  sound = SOUND_MENU_CAMERA_BUZZ },
    star  = { r = 255, g = 215, b = 90,  icon = "*",  sound = SOUND_MENU_STAR_SOUND,
              voice = { "yahoo", "yippee", "herewego", "okey" },

              buzz = { 10, 60 } },
    crit  = { r = 255, g = 60,  b = 60,  icon = "!!", sound = SOUND_MENU_CAMERA_BUZZ,
              voice = { "doh", "mamamia", "gameover" },

              buzz = { 25, 90 } },
    quiet = { r = 170, g = 170, b = 170, icon = "-" },
}

function notify.buzz(kind)
    local entry = notify.KINDS[kind]
    if entry == nil or entry.buzz == nil then return false end

    local m = gMarioStates[0]
    if m == nil then return false end

    OF.util.optional("queue_rumble_data_mario", nil, m,
        entry.buzz[1], entry.buzz[2])
    return true
end

local MAX_TOASTS = 4
local SLIDE_FRAMES = 12
local FADE_FRAMES = 20

notify.WIDTH_BUDGET = 678
local TOAST_SCALE = 0.9

local function fit_toast(text)
    if OF.util.drawn_width(text, TOAST_SCALE) <= notify.WIDTH_BUDGET then
        return text
    end

    local plain = OF.util.plain(text)
    if plain == text then
        return OF.util.fit(text, TOAST_SCALE, notify.WIDTH_BUDGET)
    end

    local most = #plain
    while most > 4 and OF.util.width(string.sub(plain, 1, most), TOAST_SCALE)
        > notify.WIDTH_BUDGET do
        most = most - 1
    end
    return OF.util.shorten(text, most)
end

local READ_BASE = 1.6
local READ_PER_CHARACTER = 1 / 12
local READ_MIN, READ_MAX = 2.5, 10

function notify.duration_for(message, seconds)
    if seconds ~= nil then return seconds end
    local letters = #OF.util.plain(tostring(message or ""))
    return OF.util.clamp(READ_BASE + letters * READ_PER_CHARACTER,
        READ_MIN, READ_MAX)
end

notify.toasts = {}

notify.hushed = 0

function notify.hush(on)
    if on then
        notify.hushed = notify.hushed + 1
    elseif notify.hushed > 0 then
        notify.hushed = notify.hushed - 1
    end
    return notify.hushed > 0
end

function notify.hushes(kind)
    if notify.hushed <= 0 then return false end
    return kind ~= "bad" and kind ~= "crit"
end

notify.startHushed = 0
notify.startSaid = 0

function notify.hush_start(on)
    if on then
        notify.startHushed = notify.startHushed + 1
    elseif notify.startHushed > 0 then
        notify.startHushed = notify.startHushed - 1
    end
    return notify.startHushed > 0
end

notify.CARD_LINES = {
    ["@ - @"] = true,
    ["@ had nothing picked - playing @, where the lobby is."] = true,
    ["@ had nothing picked - playing @, the first on its list."] = true,
    ["@ - swept clear for a fight"] = true,
    ["Taking you to the round"] = true,
}

function notify.clear_for_card()
    local gone = 0
    for index = #notify.toasts, 1, -1 do
        local toast = notify.toasts[index]
        if toast.template ~= nil and notify.CARD_LINES[toast.template] then
            table.remove(notify.toasts, index)
            gone = gone + 1
        end
    end
    notify.cardSaid = notify.cardSaid + gone
    return gone
end

function notify.start_hushes(kind, message)
    if notify.startHushed > 0 and kind ~= "bad" and kind ~= "crit" then return true end
    return notify.on_the_card(kind, message)
end

notify.cardSaid = 0
function notify.on_the_card(kind, message)
    if message == nil or not notify.CARD_LINES[message] then return false end
    if kind == "bad" or kind == "crit" then return false end
    local modes = OF.gamemodes
    if modes == nil or not OF.util.asks(modes, "state") or modes.COUNTDOWN == nil then return false end
    if modes.state() ~= modes.COUNTDOWN then return false end
    return OF.util.asks(modes, "hears_round") and modes.hears_round() == true
end

notify.FEED_KEEPS_TOAST = { crit = true }
notify.FEED_ROUND_ENDS = {
    ["Round over: the menu is back for everybody"] = true,
    ["Race over: the menu is back for everybody"] = true,
    ["@ has won @ in a row"] = true,
    ["@ ends @"] = true,
    ["@'s run of @ is over"] = true,
}

notify.FEED_TONES = {
    ["You are now @"] = "rank",
    ["@ is now @"] = "rank",
    ["@ has run out - they are @ again."] = "rank",
}
notify.FEED_KIND_TONES = { good = "give", warn = "lasting", bad = "danger" }

notify.feedNotices = true

function notify.to_feed(message, kind)
    if notify.feedNotices == false then return false end
    if notify.FEED_KEEPS_TOAST[kind] then return false end
    if notify.FEED_ROUND_ENDS[message] then return true end
    if notify.line_held() then return false end

    local modes = OF.gamemodes
    if OF.util.asks(modes, "role") and (modes.role(0) or "") ~= "" then return false end

    if notify.feed_in_menu() then return true end
    if OF.util.asks(OF.util, "menu_has_screen") and OF.util.menu_has_screen() then
        local ok, side = pcall(notify.line_place, 300, 20)
        if ok and side == nil then return false end
    end
    return true
end

notify.ROUND_FEED_ICON = { good = "capture", bad = "kill", warn = "bomb", info = "score",
    rank = "score", quiet = "score" }

function notify.round_feed(kind)
    if notify.FEED_KEEPS_TOAST[kind] then return false end
    local modes = OF.gamemodes
    if modes == nil or not OF.util.asks(modes, "state") then return false end
    if modes.state() ~= modes.ACTIVE then return false end
    if not OF.util.asks(modes, "role") or (modes.role(0) or "") == "" then return false end

    if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside() == false then return false end
    local hud = OF.hud
    return hud ~= nil and type(hud.feed_push) == "function"
end

function notify.show(message, kind, seconds, value, second)
    if message == nil or message == "" then return end

    kind = notify.KINDS[kind] and kind or "info"
    if notify.hushes(kind) then return end
    if notify.start_hushes(kind, message) then

        if notify.startHushed > 0 then
            notify.startSaid = notify.startSaid + 1
        else
            notify.cardSaid = notify.cardSaid + 1
        end
        if kind ~= "quiet" and OF.util.asks(OF.chatlog, "add_notice") then
            OF.chatlog.add_notice(OF.lang.fill(message, value, second))
        end
        return
    end
    local entry = notify.KINDS[kind]
    local feed = notify.to_feed(message, kind)
    local roundFeed = not feed and notify.round_feed(kind)

    local text = fit_toast(OF.lang.fill(message, value, second))
    local duration = math.floor(notify.duration_for(text, seconds) * 30)

    for _, toast in ipairs(notify.toasts) do
        if toast.message == text and toast.kind == kind then
            toast.repeats = toast.repeats + 1
            toast.timer = 0
            if duration > toast.duration then toast.duration = duration end
            if toast.feed then

                local family = notify.line_family(text)
                local said = false
                for _, line in ipairs(notify.lines) do
                    if line.note and line.family == family then
                        line.what = OF.util.plain(OF.lang.fill("@  (x@)", text, toast.repeats))

                        line.born = notify.clock - math.min(line.timer or 0, 8)
                        line.cutCorner, line.cutBox = nil, nil
                        said = true
                    end
                end
                if not said then
                    notify.line_note(text, nil, notify.FEED_TONES[message]
                        or notify.FEED_KIND_TONES[kind],
                        notify.FEED_ROUND_ENDS[message] == true, kind == "quiet")
                end
            end

            return
        end
    end

    notify.buzz(kind)

    table.insert(notify.toasts, {
        message = text,

        template = message,
        kind = kind,
        repeats = 1,
        timer = 0,
        duration = duration,
        feed = feed or nil,
        roundFeed = roundFeed or nil,
    })
    if roundFeed then
        local tone = ({ good = "good", bad = "bad", warn = "warn" })[kind] or "ink"
        OF.hud.feed_push({ left = text, leftColour = tone,
            icon = notify.ROUND_FEED_ICON[kind] or "score" })
    end
    if feed then

        notify.line_note(text, nil, notify.FEED_TONES[message]
            or notify.FEED_KIND_TONES[kind], notify.FEED_ROUND_ENDS[message] == true,
            kind == "quiet")
    end

    if not feed and kind ~= "quiet" and OF.util.asks(OF.chatlog, "add_notice") then
        OF.chatlog.add_notice(text)
    end

    while #notify.toasts > MAX_TOASTS do
        local gone = 1
        for index, toast in ipairs(notify.toasts) do
            if toast.feed or toast.roundFeed then gone = index break end
        end
        table.remove(notify.toasts, gone)
    end

    OF.sounds.play(entry.sound)

    if entry.voice ~= nil and OF.util.asks(OF.sounds, "say_one_of") then
        OF.sounds.say_one_of(entry.voice)
    end
end

function notify.send_to(globalIndex, message, kind, seconds, value, second)
    if not OF.util.is_host() then return false end
    if globalIndex == network_global_index_from_local(0) then
        notify.show(message, kind, seconds, value, second)
        return true
    end
    local li = OF.util.local_from_global(globalIndex)
    if li == nil then return false end

    OF.util.send_to_player(li, {
        ofp = notify.PACKET,
        msg = message,
        val = value,
        val2 = second,
        kind = kind or "info",

        secs = seconds,
    })
    return true
end

notify.CREDIT_KEY = "ofWhoDid"
function notify.credits_on()
    return true
end

function notify.credit(askerLocal, what)
    notify.line_all(askerLocal, what)
    return true
end

function notify.credit_named(askerLocal, what)
    notify.line_all(askerLocal, what)
    return true
end

function notify.credit_waiting()
    return 0
end

function notify.forget_credits()

    notify.lastCredited = {}
    return true
end

notify.LINE_PACKET = "aline"
notify.LINE_ASK_PACKET = "alineask"
notify.LINE_SCALE = 0.70

notify.FEED_SECONDS = 6
notify.FEED_HOLD = 30
notify.LINES_MOST = 6
notify.lines = {}
notify.activity = {}

notify.clock = 0

local LINE_FADE_IN = 8
local LINE_FADE_OUT = 24

notify.LINE_WHAT_BUDGET = 360

notify.LINE_NOTE_BUDGET = 560

notify.LINE_ROW = 26
notify.LINE_GAP = 4
notify.LINE_PAD = 8
notify.LINE_NAME_ROOM = 150

notify.LINE_GLIDE = 0.35

notify.LINE_STRIP = { danger = "bad", lasting = "warn", rank = "warn", give = "good", go = "good" }

notify.LINE_KIND = { danger = "deny", lasting = "warn", rank = "warn", give = "done", go = "done" }

notify.LINE_TONES = {
    danger = { r = 255, g = 120, b = 90 },
    lasting = { r = 255, g = 205, b = 70 },
    give = { r = 130, g = 232, b = 150 },

    rank = { r = 255, g = 205, b = 70 },
    go = { r = 130, g = 232, b = 150 },
}

local LINE_DANGER_WORDS = { "^stopped ", "^cancelled ", "^cleared ",
    "^called .+ off", "^stood .+ down", "^lifted every ", "^took hold of " }

function notify.line_tone(what, tone)
    if notify.LINE_TONES[tone] ~= nil then return tone end
    local text = string.lower(OF.util.plain(tostring(what or "")))
    for _, pattern in ipairs(LINE_DANGER_WORDS) do
        if string.find(text, pattern) ~= nil then return "danger" end
    end
    return nil
end

function notify.line_held()
    local scope = OF.roundscope
    if OF.util.asks(scope, "inside") and scope.inside(0) then return true end
    local spectate, act = OF.spectate, OF.roundact
    return OF.util.asks(spectate, "is_spectating") and spectate.is_spectating(0) == true
        and OF.util.asks(act, "watches") and act.watches(0) == true
end

function notify.line_family(what)
    local text = OF.util.plain(tostring(what or ""))
    local head = string.match(text, "^(.-)%s+%-%s+.*$")
        or string.match(text, "^(.-):%s.*$")
    return string.lower(head or text)
end

function notify.marquee_frames(text, room)
    local hud = OF.hud
    if hud == nil or type(hud.measure) ~= "function" or type(room) ~= "number" then return 0 end
    local travel = hud.measure(tostring(text or ""), "rowSmall") - room
    if travel <= 0 then return 0 end
    local panel = OF.panel
    local pause = panel ~= nil and panel.MARQUEE_PAUSE or 45
    local speed = panel ~= nil and panel.MARQUEE_SPEED or 1
    return math.ceil(pause + travel / math.max(0.01, speed)) + notify.FEED_HOLD
end

notify.menuRoom = nil
notify.MENU_ROOM_GUESS = 300

local function corner_life()
    return notify.FEED_SECONDS * 30
end

local function box_life(line)
    local base = notify.FEED_SECONDS * 30
    local room = notify.menuRoom or notify.MENU_ROOM_GUESS
    local name = tostring(line.name or "")
    if name ~= "" and OF.hud ~= nil and type(OF.hud.measure) == "function" then
        room = room - OF.hud.measure(OF.util.plain(name), "rowSmall") - 6
    end
    local key = OF.util.plain(tostring(line.what or "")) .. "|" .. room
    if line.boxKey ~= key then
        line.boxKey = key
        line.boxNeed = notify.marquee_frames(OF.util.plain(tostring(line.what or "")), room)
    end
    if line.boxNeed <= 0 then return base end
    return math.max(base, LINE_FADE_IN + line.boxNeed + LINE_FADE_OUT)
end

local function line_age(line)
    return notify.clock - (line.born or notify.clock)
end

local function refresh(line)
    line.born = notify.clock - math.min(line_age(line), LINE_FADE_IN)
    line.cutCorner, line.cutBox = nil, nil
end

local function drop_line(line)
    for _, list in ipairs({ notify.lines, notify.activity }) do
        for index = #list, 1, -1 do
            if list[index] == line then table.remove(list, index) end
        end
    end
end

local function cap(list, most, field)
    local standing = 0
    for _, line in ipairs(list) do
        if line[field] == nil then standing = standing + 1 end
    end
    for _, line in ipairs(list) do
        if standing <= most then break end
        if line[field] == nil then
            line[field] = LINE_FADE_OUT
            standing = standing - 1
        end
    end
end

local function box_most()
    local hud = OF.hud
    return hud ~= nil and hud.MENU ~= nil and hud.MENU.feedLines or 5
end

local function post_line(line)
    drop_line(line)
    if line.born == nil then line.born = notify.clock end
    line.timer = line_age(line)
    table.insert(notify.lines, line)
    table.insert(notify.activity, line)
    cap(notify.lines, notify.LINES_MOST, "cutCorner")
    cap(notify.activity, box_most(), "cutBox")
end
notify.post_line = post_line

local function age_list(list, life, field, leftField)
    local before = 0
    local index = 1
    while index <= #list do
        local line = list[index]
        local left = life(line) - line_age(line)
        if left < before then left = before end
        if line[field] ~= nil then
            line[field] = line[field] - 1
            if line[field] < left then left = line[field] end
        end
        line[leftField] = left
        if left <= 0 then
            table.remove(list, index)
        else
            before = left
            index = index + 1
        end
    end
end

function notify.feed_tick()
    notify.clock = notify.clock + 1
    age_list(notify.lines, corner_life, "cutCorner", "left")
    age_list(notify.activity, box_life, "cutBox", "boxLeft")
    for _, line in ipairs(notify.lines) do line.timer = line_age(line) end
    for _, line in ipairs(notify.activity) do line.timer = line_age(line) end
end

function notify.lines_on()
    return OF.settings == nil or OF.settings.showCredits ~= false
end

function notify.set_lines_on(value)
    if OF.settings == nil then return false end
    OF.settings.showCredits = value == true
    if OF.util.asks(OF.util, "store_bool") then
        OF.util.store_bool("set_showCredits", value == true)
    end
    if value ~= true then notify.lines, notify.activity = {}, {} end
    return true
end

function notify.line_add(actorGlobal, name, what, tone, round, target, targetName)
    if what == nil or what == "" then return false end
    if not notify.lines_on() then return false end
    if notify.line_held() and round ~= true then return false end
    what = OF.util.plain(tostring(what))
    local family = notify.line_family(what)

    for index = #notify.lines, 1, -1 do
        local line = notify.lines[index]
        if line.note and line.family == family then drop_line(line) end
    end

    if actorGlobal == network_global_index_from_local(0) then
        for index = #notify.activity, 1, -1 do
            local line = notify.activity[index]
            if line.mine and line_age(line) < 90 then drop_line(line) end
        end
    end
    tone = notify.line_tone(what, tone)
    for _, line in ipairs(notify.lines) do
        if line.actor == actorGlobal and line.family == family
            and line.target == target then
            line.what, line.tone = what, tone

            refresh(line)
            post_line(line)
            return true
        end
    end
    local targetShown = nil
    if target ~= nil then
        local li = OF.util.local_from_global(target)
        local np = li ~= nil and gNetworkPlayers[li] or nil
        targetShown = (np ~= nil and np.name ~= nil and np.name ~= "") and np.name
            or (targetName ~= nil and targetName ~= "" and tostring(targetName) or nil)
    end
    post_line({
        actor = actorGlobal, name = name, what = what, tone = tone,
        family = family, round = round == true or nil,
        target = targetShown ~= nil and target or nil, targetName = targetShown,
    })

    if OF.util.asks(OF.chatlog, "add_notice") then
        OF.chatlog.add_notice(OF.util.plain(tostring(name or "")) .. ": " .. what
            .. (targetShown ~= nil and (" - " .. OF.util.plain(targetShown)) or ""))
    end
    return true
end

function notify.line_note(what, covers, tone, round, unlogged)
    if what == nil or what == "" then return false end
    if notify.line_held() and round ~= true then return false end

    what = tostring(what)
    local family = notify.line_family(covers ~= nil and covers or what)
    for _, line in ipairs(notify.lines) do
        if line.family == family then
            if line.note and OF.util.plain(line.what) == OF.util.plain(what) then
                refresh(line)
                return true
            end
            return false
        end
    end
    post_line({
        note = true, name = "", what = what, family = family,
        tone = notify.line_tone(what, tone), round = round == true or nil,
    })

    if unlogged ~= true and OF.util.asks(OF.chatlog, "add_notice") then
        OF.chatlog.add_notice(OF.util.plain(what))
    end
    return true
end

function notify.line_mine(text, kind, colour)
    if text == nil or text == "" then return false end
    if not notify.lines_on() then return false end
    if notify.line_held() then return false end
    local me = network_global_index_from_local(0)
    for _, line in ipairs(notify.activity) do
        if line.actor == me and not line.mine and line_age(line) < 90 then return false end
    end
    text = tostring(text)
    local family = notify.line_family(text)
    for _, line in ipairs(notify.activity) do
        if line.mine and line.family == family then
            line.what, line.kind, line.colour = text, kind, colour
            refresh(line)
            post_line(line)
            return line
        end
    end
    local np = gNetworkPlayers[0]
    local line = { mine = true, actor = me, name = np ~= nil and tostring(np.name or "") or "",
        what = text, kind = kind, colour = colour, family = family }
    post_line(line)
    return line
end

notify.lastCredited = {}
function notify.line_all(askerLocal, what, tone, round, target)
    if not OF.util.is_host() then return false end
    if what == nil or what == "" then return false end
    local np = askerLocal ~= nil and gNetworkPlayers[askerLocal] or nil
    if np == nil or not np.connected then return false end
    local actor = np.globalIndex
    if actor == nil then actor = network_global_index_from_local(askerLocal) end

    local targetName = nil
    if target ~= nil then
        if target == actor then return false end
        local tli = OF.util.local_from_global(target)
        local tnp = tli ~= nil and gNetworkPlayers[tli] or nil
        if tnp == nil then
            target = nil
        else
            targetName = OF.util.plain(tostring(tnp.name or ""))
        end
    end
    notify.lastCredited[actor] = get_global_timer and get_global_timer() or 0
    OF.util.tell_all({
        ofp = notify.LINE_PACKET,
        from = network_global_index_from_local(0),
        who = actor,
        n = OF.util.plain(tostring(np.name or "")),
        w = OF.util.plain(tostring(what)),
        t = tone,
        rd = round == true or nil,
        tg = target,
        tn = targetName,
    })
    notify.line_add(actor, np.name, what, tone, round, target, targetName)
    return true
end

notify.DEEDS = {
    jail = { "@ jailed @", "danger" },
    free = { "@ freed @", "give" },
    ban = { "@ banned @", "danger" },
    mute = { "@ muted @", "danger" },
    unmute = { "@ unmuted @", "give" },
    warn = { "@ warned @", "lasting" },
}

notify.deedBy = nil

function notify.acting(askerLocal, fn, ...)
    local was = notify.deedBy
    notify.deedBy = askerLocal
    local out = table.pack(pcall(fn, ...))
    notify.deedBy = was
    if not out[1] then error(out[2], 0) end
    return table.unpack(out, 2, out.n)
end

function notify.deed_take()
    local actor = notify.deedBy
    notify.deedBy = nil
    return actor
end

local function deed_name(name)
    return "\\#ffffff\\" .. tostring(name or "?")
end

function notify.deed_text(verb, actorName, targetName)
    local deed = notify.DEEDS[verb]
    if deed == nil then return nil end
    return OF.lang.fill(OF.lang.t(deed[1]), deed_name(actorName), deed_name(targetName))
end

function notify.deed_said(actorLocal, verb, targetLocal)
    notify.deedBy = actorLocal
    if actorLocal == nil or notify.DEEDS[verb] == nil then return false end
    if not OF.util.is_host() then return false end
    local actor, target = gNetworkPlayers[actorLocal], gNetworkPlayers[targetLocal]
    if actor == nil or target == nil then return false end
    local actorGlobal = network_global_index_from_local(actorLocal)

    notify.lastCredited[actorGlobal] = get_global_timer and get_global_timer() or 0
    local packet = {
        ofp = notify.LINE_PACKET,
        from = network_global_index_from_local(0),
        dv = verb,
        who = actorGlobal,
        n = OF.util.plain(tostring(actor.name or "")),
        at = network_global_index_from_local(targetLocal),
        an = OF.util.plain(tostring(target.name or "")),
    }
    OF.util.tell_all(packet)
    notify.deed_line(packet)
    return true
end

function notify.deed_line(data)
    local deed = notify.DEEDS[data.dv]
    if deed == nil then return false end
    local function named(global, fallback)
        local li = tonumber(global) ~= nil and OF.util.local_from_global(tonumber(global)) or nil
        local np = li ~= nil and gNetworkPlayers[li] or nil
        if np ~= nil and np.name ~= nil and np.name ~= "" then return np.name end
        return tostring(fallback or "?")
    end
    return notify.line_note(notify.deed_text(data.dv, named(data.who, data.n),
        named(data.at, data.an)), nil, deed[2], true)
end

notify.LINE_FEATURES = {
    ranks = true, jail = true, mute = true, ban = true, powerup_other = true,
    costume_other = true, possess_other = true, save_edit = true,
    settings = true, permissions = true,
}

function notify.line_feature(feature)
    if type(feature) ~= "string" or feature == "" then return false end
    if string.match(feature, "_self$") ~= nil then return false end
    if notify.LINE_FEATURES[feature] then return true end
    local perms = OF.perms
    return perms ~= nil and type(perms.DEFAULTS) == "table"
        and perms.DEFAULTS[feature] ~= nil
end

local CREDIT_COVERS = 30

local function host_takes_ask(askerLocal, feature, what, tone, target)
    if not notify.line_feature(feature) then return false end
    if not OF.util.asks(OF.perms, "tier") then return false end
    if OF.perms.tier(askerLocal) < OF.perms.required(feature, askerLocal) then
        return false
    end
    if target ~= nil and target ~= network_global_index_from_local(askerLocal) then
        local li = OF.util.local_from_global(target)
        if li == nil then return false end

        if OF.util.asks(OF.util, "may_act_on")
            and not OF.util.may_act_on(askerLocal, li) then
            return false
        end

        if OF.util.asks(OF.roundscope, "inside") and OF.roundscope.inside(li) then
            return false
        end
    end
    local np = gNetworkPlayers[askerLocal]
    local actor = np ~= nil and np.globalIndex or nil
    local now = get_global_timer and get_global_timer() or 0
    local credited = actor ~= nil and notify.lastCredited[actor] or nil
    if credited ~= nil and now - credited <= CREDIT_COVERS then
        return false
    end
    return notify.line_all(askerLocal, what, tone, nil, target)
end

function notify.line_ask(feature, what, tone, target)
    if feature == nil or what == nil or what == "" then return false end
    if OF.util.is_host() then
        return host_takes_ask(0, feature, what, tone, target)
    end
    if not notify.line_feature(feature) then return false end
    return OF.util.send_to_host({ ofp = notify.LINE_ASK_PACKET, f = feature,
        w = OF.util.plain(tostring(what)), t = tone, at = target })
end

local function on_line_ask(asker, data)
    host_takes_ask(asker, tostring(data.f), tostring(data.w or ""),
        notify.LINE_TONES[data.t] ~= nil and data.t or nil,
        tonumber(data.at))
end

local function on_line_packet(data)
    if data.dv ~= nil then
        notify.deed_line(data)
        return
    end
    local actor = tonumber(data.who)
    local name = data.n
    local li = actor ~= nil and OF.util.local_from_global(actor) or nil
    if li ~= nil and gNetworkPlayers[li] ~= nil and gNetworkPlayers[li].name ~= nil then
        name = gNetworkPlayers[li].name
    end
    notify.line_add(actor, name, data.w,
        notify.LINE_TONES[data.t] ~= nil and data.t or nil, data.rd == true,
        tonumber(data.tg), data.tn ~= nil and tostring(data.tn) or nil)
end

function notify.line_place(stackWidth, stackHeight)
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local margin = 16

    local bottom = math.floor(screenHeight * 196 / 240)
    local top = bottom - stackHeight
    local function clear_of_menu(left)
        if not OF.util.menu_has_screen() then return true end
        if not OF.util.asks(OF.panel, "geometry") then return true end
        local ok, px, py, pw, ph = pcall(OF.panel.geometry)
        if not ok or px == nil then return true end
        local right = left + stackWidth
        return right <= px or left >= px + pw or bottom <= py or top >= py + ph
    end
    local rightLeft = screenWidth - margin - stackWidth
    if clear_of_menu(rightLeft) then return "right", screenWidth - margin, bottom end
    if clear_of_menu(margin) then return "left", margin, bottom end
    return nil
end

local function line_alpha(line, left)
    local fadeIn = math.min(1, line_age(line) / LINE_FADE_IN)
    local fadeOut = math.min(1, math.max(0, (left or 0) / LINE_FADE_OUT))
    return math.floor(255 * math.min(fadeIn, fadeOut))
end
notify.line_alpha = line_alpha

function notify.feed_in_menu()
    local panel = OF.panel
    if panel == nil or type(panel.is_open) ~= "function" or panel.is_open() ~= true then return false end
    return type(panel.skin_on) == "function" and panel.skin_on() == true
end

local function corner_words(line, hud)
    local name = tostring(line.name or "")

    if line.note and type(line.what) == "string" then
        local said = OF.util.say_buttons(line.what)
        if said ~= line.what then line = { name = line.name, note = true, what = said } end
    end
    local budget = line.note and notify.LINE_NOTE_BUDGET or notify.LINE_WHAT_BUDGET
    if line.note and OF.util.plain(line.what) ~= line.what
        and hud.measure(line.what, "rowSmall") <= budget then
        return line.what, true
    end
    return hud.fit((name == "" and "" or ": ") .. OF.util.plain(line.what), "rowSmall", budget), false
end

function notify.feed_entries(wordsRoom)
    if type(wordsRoom) == "number" then notify.menuRoom = wordsRoom end
    local out = {}
    for index = #notify.activity, 1, -1 do
        local line = notify.activity[index]
        out[#out + 1] = {
            kind = line.kind or notify.LINE_KIND[line.tone or ""] or "done",
            who = tostring(line.name or ""), colour = line.colour,
            text = OF.util.plain(tostring(line.what or "")),
            age = line_age(line), life = line_alpha(line, line.boxLeft) / 255,
            line = line,
        }
    end
    return out
end

local function render_lines()
    if OF.util == nil or type(OF.util.line_height) ~= "function" then return end

    notify.feed_tick()
    if #notify.lines == 0 then return end
    if notify.line_held() then

        local modes = OF.gamemodes
        local fresh = OF.util.asks(modes, "state")
            and (modes.state() == modes.COUNTDOWN or modes.state() == modes.ACTIVE)
        for index = #notify.lines, 1, -1 do
            local line = notify.lines[index]
            if not (line.round == true and not fresh) then drop_line(line) end
        end
        if #notify.lines == 0 then return end
    end

    if notify.feed_in_menu() then return end
    local hud = OF.hud
    if hud == nil or type(hud.plate) ~= "function" then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    local rowH, gap, pad, strip = notify.LINE_ROW, notify.LINE_GAP, notify.LINE_PAD, 3

    local built, widest = {}, 0
    for _, line in ipairs(notify.lines) do
        local name = tostring(line.name or "")
        local words, coloured = corner_words(line, hud)
        local plainWords = OF.util.plain(words)
        local nameW = name ~= "" and math.min(notify.LINE_NAME_ROOM,
            (hud.measure(OF.util.plain(name), "rowSmall"))) or 0
        local wordsW = (hud.measure(plainWords, "rowSmall"))
        local target = line.targetName
        local targetW = (target ~= nil and target ~= "")
            and (math.min(notify.LINE_NAME_ROOM, (hud.measure(OF.util.plain(target), "rowSmall"))) + pad) or 0
        local width = math.floor(strip + pad + nameW + wordsW + targetW + pad + 0.5)
        if width > widest then widest = width end
        table.insert(built, { line = line, name = name, words = words, coloured = coloured,
            nameW = nameW, width = width, target = targetW > 0 and target or nil,
            targetW = targetW })
    end
    local stackHeight = #built * rowH + (#built - 1) * gap
    local side, edge, bottom = notify.line_place(widest, stackHeight)
    if side == nil then return end

    local top = bottom - stackHeight
    for i, item in ipairs(built) do
        local line = item.line
        local a = line_alpha(line, line.left)

        local want = top + (i - 1) * (rowH + gap)
        if line.y == nil or math.abs(line.y - want) < 0.5 then line.y = want
        else line.y = line.y + (want - line.y) * notify.LINE_GLIDE end
        local y = math.floor(line.y + 0.5)
        local left = side == "right" and (edge - item.width) or edge
        hud.plate(left, y, item.width, rowH, { alpha = a / 255, tint = "gold",
            strip = notify.LINE_STRIP[line.tone or ""] or "gold" })
        local cy = y + rowH / 2
        local x = left + strip + pad

        if item.name ~= "" then
            hud.name_mid(item.name, x, cy, "rowSmall", "ink", a, "left",
                notify.LINE_NAME_ROOM, { key = "line-name" .. tostring(line.actor) })
            x = x + item.nameW
        end
        if item.coloured then
            hud.name_mid(item.words, x, cy, "rowSmall", "ink2", a, "left")
        else
            hud.text_mid(item.words, x, cy, "rowSmall", "ink2", a, "left")
        end
        if item.target ~= nil then
            hud.name_mid(item.target, left + item.width - pad, cy, "rowSmall", "ink", a, "right",
                notify.LINE_NAME_ROOM, { key = "line-target" .. tostring(line.target) })
        end
    end
end

function notify.send_all(message, kind, seconds, value, second)
    if not OF.util.is_host() then return 0 end

    if notify.hushes(notify.KINDS[kind] and kind or "info") then return 0 end

    OF.util.tell_all({
        ofp = notify.PACKET,
        from = network_global_index_from_local(0),
        msg = message,
        val = value,
        val2 = second,
        kind = kind or "info",

        secs = seconds,
    })
    notify.show(message, kind, seconds, value, second)
    return 1
end

hook_on_sync_table_change(gGlobalSyncTable, notify.CREDIT_KEY, 0, function()
    if OF.util.asks(OF.guard, "repair") then OF.guard.repair(notify.CREDIT_KEY) end
end)

local function on_packet_receive(data)
    if data ~= nil and data.ofp == notify.LINE_ASK_PACKET then

        local asker = OF.util.asked_by(data)
        if asker ~= nil then on_line_ask(asker, data) end
        return
    end
    if data ~= nil and data.ofp == notify.LINE_PACKET then
        if OF.util.from_host_effect(data) then on_line_packet(data) end
        return
    end
    if data == nil or data.ofp ~= notify.PACKET then return end

    if not OF.util.from_host_effect(data) then return end
    notify.show(data.msg, data.kind, data.secs, data.val, data.val2)
end

local MEASURE_LIMIT = 512
local measured, measuredCount = {}, 0
local measuredBy, measuredWidth = nil, nil

local function width_now(text, scale)
    local getFont = djui_hud_get_font
    local util = OF.util
    if getFont == nil or type(text) ~= "string" or type(scale) ~= "number"
        or scale ~= scale then
        return util.width(text, scale)
    end
    local font = getFont()
    if font == nil or font ~= font then return util.width(text, scale) end
    if djui_hud_measure_text ~= measuredBy or util.width ~= measuredWidth
        or measuredCount > MEASURE_LIMIT then
        measured, measuredCount = {}, 0
        measuredBy, measuredWidth = djui_hud_measure_text, util.width
    end
    local byScale = measured[font]
    if byScale == nil then
        byScale = { whole = {} }
        measured[font] = byScale
    end
    local shelf = byScale
    if math.type(scale) == "integer" then shelf = byScale.whole end
    local byText = shelf[scale]
    if byText == nil then
        byText = {}
        shelf[scale] = byText
    end
    local answer = byText[text]
    if answer == nil then
        answer = util.width(text, scale)
        byText[text] = answer
        measuredCount = measuredCount + 1
    end
    return answer
end

local drawnFor = setmetatable({}, { __mode = "k" })

local function held_for(toast)
    local held = drawnFor[toast]
    if held == nil then
        held = {}
        drawnFor[toast] = held
    end
    return held
end

local function line_for(toast, icon, body)
    if type(toast) ~= "table" then return icon .. "  " .. body end
    local held = held_for(toast)
    if held.line == nil or held.icon ~= icon or held.body ~= body then
        held.icon, held.body, held.line = icon, body, icon .. "  " .. body
    end
    return held.line
end

local function runs_for(toast, body)
    local colourRuns = OF.util.colour_runs
    if type(toast) ~= "table" then
        return colourRuns(body, { r = 220, g = 220, b = 220 })
    end
    local held = held_for(toast)
    if held.runs == nil or held.runsFrom ~= body or held.runsBy ~= colourRuns then
        held.runsFrom, held.runsBy = body, colourRuns
        held.runs = colourRuns(body, { r = 220, g = 220, b = 220 })
    end
    return held.runs
end

notify.TOAST_STRIP = { good = "good", warn = "warn", bad = "bad", crit = "bad",
    star = "good", info = "gold", quiet = "gold", rank = "warn" }
function notify.themed()
    local hud = OF.hud
    return hud ~= nil and type(hud.plate) == "function" and type(hud.name_mid) == "function"
        and type(hud.measure) == "function"
end

local function paint_toast_themed(item)
    local hud = OF.hud
    local a = item.alpha
    local toast = item.toast
    local words = OF.util.plain(item.body)
    local pad, strip = 10, 3
    local w = math.floor(strip + pad + (hud.measure(words, "row") or 0) + pad + 0.5)
    local screenWidth = djui_hud_get_screen_width()
    local left = math.floor((screenWidth - w) * 0.5 + (item.x - (screenWidth - (item.boxWidth - 24)) * 0.5))
    local top, h = item.top, item.rowHeight
    local tone = notify.TOAST_STRIP[toast.kind] or "gold"
    hud.plate(left, top, w, h, { alpha = a / 255, tint = "gold", strip = tone })
    hud.name_mid(item.body, left + strip + pad, top + h / 2, "row", "ink", a, "left")
    local barWidth = math.floor(w * item.leftFraction)
    if barWidth > 0 then hud.rect(left, top + h - 2, barWidth, 2, tone, 170 * (a / 255)) end
    item.themed = { left = left, width = w }
end

local function paint_toast(item)
    if notify.themed() then return paint_toast_themed(item) end
    local kind = item.kind
    local alpha = item.alpha

    OF.util.plate(item.left, item.top, item.boxWidth, item.rowHeight,
        { alpha = alpha, edge = kind })

    OF.util.text(kind.icon, item.x, item.textY, item.scale,
        kind.r, kind.g, kind.b, alpha)

    OF.util.draw_segments(
        runs_for(item.toast, item.body),
        item.x + width_now(kind.icon .. "  ", item.scale),
        item.textY, item.scale, alpha)

    local barWidth = math.floor(item.boxWidth * item.leftFraction)
    if barWidth > 0 then
        OF.util.rect(item.left, item.top + item.rowHeight - 2, barWidth, 2,
            kind.r, kind.g, kind.b, math.floor(170 * (alpha / 255)))
    end
end

local function paint_pile(pile)
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    for _, item in ipairs(pile) do
        if item.face ~= nil then djui_hud_set_font(item.face) end
        paint_toast(item)
        if item.face ~= nil then djui_hud_set_font(FONT_NORMAL) end
    end
end

local function render()

    pcall(render_lines)
    if #notify.toasts == 0 then return end

    if OF.util == nil or type(OF.util.line_height) ~= "function" then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local screenWidth = djui_hud_get_screen_width()
    local scale = 0.9
    local lineHeight = OF.util.line_height(scale)
    local rowHeight = lineHeight + 12

    local drawn = false
    for _, toast in ipairs(notify.toasts) do
        if not toast.feed and not toast.roundFeed then drawn = true break end
    end
    if not drawn then
        local index = 1
        while index <= #notify.toasts do
            local toast = notify.toasts[index]
            toast.timer = toast.timer + 1
            if toast.timer > toast.duration then
                table.remove(notify.toasts, index)
            else
                index = index + 1
            end
        end
        return
    end
    local y = OF.util.hud_claim(lineHeight, 6)

    local pile = {}

    local index = 1
    while index <= #notify.toasts do
        local toast = notify.toasts[index]
        toast.timer = toast.timer + 1

        if toast.timer > toast.duration then
            table.remove(notify.toasts, index)
        elseif toast.feed or toast.roundFeed then
            index = index + 1
        else
            local kind = notify.KINDS[toast.kind] or notify.KINDS.info

            local alpha = 255
            if toast.timer > toast.duration - FADE_FRAMES then
                alpha = math.floor(255 * ((toast.duration - toast.timer) / FADE_FRAMES))
            end
            alpha = OF.util.clamp(alpha, 0, 255)

            local slide = 0
            if toast.timer < SLIDE_FRAMES then
                slide = (1 - toast.timer / SLIDE_FRAMES) * 60
            end

            local body = OF.util.say_buttons(toast.message)
            if (toast.repeats or 1) > 1 then
                body = OF.lang.fill("@  (x@)", body, toast.repeats)
            end

            local text = line_for(toast, kind.icon, body)

            local face = OF.util.round_screen ~= nil and OF.util.round_screen()
                and OF.util.title_face(text) or nil
            local at = face ~= nil and OF.util.hud_scale(face, scale) or scale
            if face ~= nil then djui_hud_set_font(face) end
            local width = width_now(text, at)
            if face ~= nil then djui_hud_set_font(FONT_NORMAL) end
            local x = (screenWidth - width) * 0.5 + slide

            table.insert(pile, {
                toast = toast,
                kind = kind,
                body = body,
                alpha = alpha,
                scale = at,
                face = face,
                x = x,
                textY = y + (rowHeight - lineHeight) * 0.5,
                left = x - 12,
                top = y,
                boxWidth = width + 24,
                rowHeight = rowHeight,
                leftFraction = OF.util.clamp(
                    1 - (toast.timer / math.max(1, toast.duration)), 0, 1),
            })

            y = y + rowHeight + 5
            OF.util.hud_push(rowHeight + 5)
            index = index + 1
        end
    end

    if #pile == 0 then return end

    if type(OF.util.menu_has_screen) == "function" and OF.util.menu_has_screen()
        and type(OF.util.above_menu) == "function"
        and OF.util.above_menu(function() paint_pile(pile) end) then
        return
    end
    paint_pile(pile)
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
hook_event(HOOK_ON_HUD_RENDER, render)
