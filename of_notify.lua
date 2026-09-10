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

function notify.show(message, kind, seconds, value, second)
    if message == nil or message == "" then return end

    kind = notify.KINDS[kind] and kind or "info"
    local entry = notify.KINDS[kind]

    local text = fit_toast(OF.lang.fill(message, value, second))
    local duration = math.floor(notify.duration_for(text, seconds) * 30)

    for _, toast in ipairs(notify.toasts) do
        if toast.message == text and toast.kind == kind then
            toast.repeats = toast.repeats + 1
            toast.timer = 0
            if duration > toast.duration then toast.duration = duration end

            return
        end
    end

    notify.buzz(kind)

    table.insert(notify.toasts, {
        message = text,
        kind = kind,
        repeats = 1,
        timer = 0,
        duration = duration,
    })

    if kind ~= "quiet" and OF.util.asks(OF.chatlog, "add_notice") then
        OF.chatlog.add_notice(text)
    end

    while #notify.toasts > MAX_TOASTS do
        table.remove(notify.toasts, 1)
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
local CREDIT_FIELD = "|"
local CREDIT_NAME_MAX = 22
local CREDIT_WHAT_MAX = 46

local CREDIT_HOLD = 20

local pendingCredit = nil
local creditSerial = 0

local seenCredit = false

function notify.credits_on()
    if OF.settings == nil then return true end
    if OF.settings.showCredits == nil then return true end
    return OF.settings.showCredits == true
end

function notify.set_credits(value)
    OF.settings = OF.settings or {}
    OF.settings.showCredits = value and true or false
    OF.util.store_bool("set_showCredits", OF.settings.showCredits)
    return true
end

local function credit_name(localIndex)
    local np = gNetworkPlayers[localIndex]
    local name = np ~= nil and np.name or nil
    if name == nil or name == "" then return nil end
    name = string.gsub(tostring(name), "%" .. CREDIT_FIELD, "/")
    return OF.util.cut_coloured(name, CREDIT_NAME_MAX)
end

function notify.credit_pack(name, what, count, serial)
    return table.concat({ name, what, tostring(count), tostring(serial) },
        CREDIT_FIELD)
end

function notify.credit_parse(packed)
    if type(packed) ~= "string" or packed == "" then return nil end
    local parts = {}
    for piece in string.gmatch(packed .. CREDIT_FIELD,
        "([^%" .. CREDIT_FIELD .. "]*)%" .. CREDIT_FIELD) do
        table.insert(parts, piece)
    end
    if #parts < 4 then return nil end
    local name, what = parts[1], parts[2]
    if name == "" or what == "" then return nil end
    return { name = name, what = what,
        count = math.floor(tonumber(parts[3]) or 1),
        serial = math.floor(tonumber(parts[4]) or 0) }
end

function notify.credit_line(entry)
    if entry == nil then return nil end
    if (entry.count or 1) > 1 then
        return OF.lang.fill("@: @ settings", entry.name, entry.count)
    end
    return OF.lang.fill("@: @", entry.name, entry.what)
end

function notify.credit(askerLocal, what)
    if not OF.util.is_host() then return false end
    what = OF.util.plain(tostring(what or ""))
    what = string.gsub(what, "%" .. CREDIT_FIELD, "/")
    if what == "" then return false end

    if #what > CREDIT_WHAT_MAX then
        what = string.sub(what, 1, CREDIT_WHAT_MAX)
    end

    if askerLocal == nil then return false end
    local name = credit_name(askerLocal)
    if name == nil then return false end

    if pendingCredit ~= nil and pendingCredit.name == name then
        pendingCredit.count = pendingCredit.count + 1
        pendingCredit.what = what
        pendingCredit.waited = 0
        return true
    end

    if pendingCredit ~= nil then notify.flush_credit() end
    pendingCredit = { name = name, what = what, count = 1, waited = 0 }
    return true
end

function notify.credit_named(askerLocal, what)
    if not OF.util.is_host() then return false end
    if askerLocal == nil then return false end
    if pendingCredit ~= nil and pendingCredit.name ~= credit_name(askerLocal) then
        notify.flush_credit()
    end
    pendingCredit = nil
    return notify.credit(askerLocal, what)
end

function notify.flush_credit()
    if pendingCredit == nil then return false end
    creditSerial = creditSerial + 1

    OF.util.publish(notify.CREDIT_KEY,
        notify.credit_pack(pendingCredit.name, pendingCredit.what,
            pendingCredit.count, creditSerial))
    pendingCredit = nil
    return true
end

function notify.credit_waiting()
    return pendingCredit ~= nil and pendingCredit.count or 0
end

function notify.forget_credits()
    pendingCredit = nil
    seenCredit = false
    return true
end

function notify.send_all(message, kind, seconds, value, second)
    if not OF.util.is_host() then return 0 end

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

hook_event(HOOK_UPDATE, function()
    if pendingCredit == nil then return end
    if not OF.util.is_host() then pendingCredit = nil return end
    pendingCredit.waited = pendingCredit.waited + 1
    if pendingCredit.waited >= CREDIT_HOLD then notify.flush_credit() end
end)

hook_on_sync_table_change(gGlobalSyncTable, notify.CREDIT_KEY, 0, function()
    if OF.util.asks(OF.guard, "repair") and OF.guard.repair(notify.CREDIT_KEY) then
        return
    end

    if not seenCredit then seenCredit = true return end

    if OF.util.asks(OF.guard, "putting_back") and OF.guard.putting_back() then
        return
    end
    if not notify.credits_on() then return end
    local line = notify.credit_line(
        notify.credit_parse(gGlobalSyncTable[notify.CREDIT_KEY]))
    if line == nil then return end

    notify.show(line, "quiet", 3)
end)

local function on_packet_receive(data)
    if data == nil or data.ofp ~= notify.PACKET then return end

    if not OF.util.from_host_effect(data) then return end
    notify.show(data.msg, data.kind, data.secs, data.val, data.val2)
end

local function paint_toast(item)
    local kind = item.kind
    local alpha = item.alpha
    local function faded(value)
        return math.floor(value * (alpha / 255))
    end

    OF.util.plate(item.left, item.top, item.boxWidth, item.rowHeight,
        { alpha = alpha, edge = kind })

    OF.util.text(kind.icon, item.x, item.textY, item.scale,
        kind.r, kind.g, kind.b, alpha)

    OF.util.draw_segments(
        OF.util.colour_runs(item.body,
            { r = 220, g = 220, b = 220 }),
        item.x + OF.util.width(kind.icon .. "  ", item.scale),
        item.textY, item.scale, alpha)

    local barWidth = math.floor(item.boxWidth * item.leftFraction)
    if barWidth > 0 then
        OF.util.rect(item.left, item.top + item.rowHeight - 2, barWidth, 2,
            kind.r, kind.g, kind.b, faded(170))
    end
end

local function paint_pile(pile)
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    for _, item in ipairs(pile) do paint_toast(item) end
end

local function render()
    if #notify.toasts == 0 then return end

    if OF.util == nil or type(OF.util.line_height) ~= "function" then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)

    local screenWidth = djui_hud_get_screen_width()
    local scale = 0.9
    local lineHeight = OF.util.line_height(scale)
    local rowHeight = lineHeight + 12

    local y = OF.util.hud_claim(lineHeight, 6)

    local pile = {}

    local index = 1
    while index <= #notify.toasts do
        local toast = notify.toasts[index]
        toast.timer = toast.timer + 1

        if toast.timer > toast.duration then
            table.remove(notify.toasts, index)
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

            local body = toast.message
            if (toast.repeats or 1) > 1 then
                body = OF.lang.fill("@  (x@)", toast.message, toast.repeats)
            end

            local text = kind.icon .. "  " .. body
            local width = OF.util.width(text, scale)
            local x = (screenWidth - width) * 0.5 + slide

            table.insert(pile, {
                kind = kind,
                body = body,
                alpha = alpha,
                scale = scale,
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
