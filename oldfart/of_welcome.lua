OF = OF or {}
OF.welcome = OF.welcome or {}

local welcome = OF.welcome

welcome.banner = nil

welcome.ready = false
welcome.readyTimer = 0

local BANNER_MIN_SCALE = 0.6

function welcome.show_banner(segments, subtitle, force)
    if not OF.settings.showBanner and not force then return end

    local skip = welcome.banner ~= nil
    local duration = math.floor(OF.settings.bannerSeconds * 30)
    welcome.banner = {
        segments = segments,
        subtitle = subtitle,
        timer = skip and welcome.intro_frames(duration) or 0,
        skipIntro = skip,
        duration = duration,

        greeting = force ~= true,
    }
end

local LINE_KEY = "welcome_line"
local LINE_SYNC = "ofWelcome"
welcome.LINE_MAX = 120

welcome.DRAW_MAX = 110

welcome.DEFAULT_LINE =
    "Welcome {player.name} and welcome to {host.name}'s lobby!"
local storedLine = mod_storage_load(LINE_KEY, "")

function welcome.custom_line()
    local table_ = gGlobalSyncTable
    local said = table_ ~= nil and table_[LINE_SYNC] or nil
    if type(said) == "string" and said ~= "" then return said end
    if OF.util.is_host() and storedLine ~= "" then return storedLine end

    return OF.lang.t(welcome.DEFAULT_LINE)
end

welcome.HOLES = {
    { name = "player.name", what = "whoever the greeting is about" },
    { name = "host.name",   what = "whoever is hosting" },
}

function welcome.hole_list()
    local out = {}
    for _, hole in ipairs(welcome.HOLES) do
        table.insert(out, "{" .. hole.name .. "}")
    end
    return table.concat(out, " ")
end

function welcome.say_unknown_hole(unknown)
    if unknown == nil or unknown == "" then return end
    if not OF.util.asks(OF.notify, "show") then return end
    OF.notify.show("@ is not a placeholder - this mod fills @", "warn", 6,
        unknown, welcome.hole_list())
end

function welcome.names(localIndex)
    local np = gNetworkPlayers[localIndex or 0]
    local who = (np ~= nil and np.name ~= nil and np.name ~= "")
        and OF.util.plain(np.name) or OF.lang.t("Player")

    local hostName = OF.lang.t("the host")
    local hostLocal = network_local_index_from_global(0)
    local hostNp = hostLocal ~= nil and gNetworkPlayers[hostLocal] or nil
    if hostNp ~= nil and hostNp.name ~= nil and hostNp.name ~= "" then
        hostName = OF.util.plain(hostNp.name)
    end
    return who, hostName
end

function welcome.expand(template, who, hostName)
    local pieces, unknown, dropped = welcome.split(template, who, hostName)
    local out = {}
    for _, piece in ipairs(pieces) do out[#out + 1] = piece.say end
    local filled = table.concat(out)

    if dropped then
        filled = string.gsub(filled, "  +", " ")
        filled = string.gsub(filled, "^%s+", "")
        filled = string.gsub(filled, "%s+$", "")
    end
    return filled, unknown
end

function welcome.split(template, who, hostName)
    if type(template) ~= "string" or template == "" then return {}, nil end

    local named = { ["player.name"] = who, ["host.name"] = hostName }
    local values = {}
    if who ~= nil then values[#values + 1] = who end
    if hostName ~= nil then values[#values + 1] = hostName end

    local inTurn = { "player.name", "host.name" }

    local out, taken, unknown, dropped = {}, 0, nil, false
    local index, length = 1, #template

    local function literal(text)
        if text == "" then return end
        out[#out + 1] = { say = text }
    end

    while index <= length do
        local found = string.find(template, "[@{]", index)
        if found == nil then
            literal(string.sub(template, index))
            break
        end
        if found > index then
            literal(string.sub(template, index, found - 1))
        end

        if string.sub(template, found, found) == "@" then
            taken = taken + 1
            if values[taken] ~= nil then
                out[#out + 1] = { say = tostring(values[taken]),
                                  hole = inTurn[taken] }
            else
                literal("@")
            end
            index = found + 1
        else
            local close = string.find(template, "}", found + 1, true)
            if close == nil then

                unknown = unknown or string.sub(template, found)
                dropped = true
                index = length + 1
            else
                local name = string.lower(string.sub(template, found + 1, close - 1))
                if named[name] ~= nil then
                    out[#out + 1] = { say = tostring(named[name]), hole = name }
                else
                    unknown = unknown or string.sub(template, found, close)
                    dropped = true
                end
                index = close + 1
            end
        end
    end

    return out, unknown, dropped
end

function welcome.cut(text, most)
    text = string.sub(tostring(text or ""), 1, most)
    local open = nil
    for at = 1, #text do
        local ch = string.sub(text, at, at)
        if ch == "{" then open = at elseif ch == "}" then open = nil end
    end
    if open ~= nil then text = string.sub(text, 1, open - 1) end
    return text
end

function welcome.set_custom_line(text)
    if not OF.util.is_host() then
        return false, "Only the host writes the welcome message."
    end
    if not OF.perms.can("message") then
        return false, "Your rank cannot do that.", "message"
    end
    text = OF.util.storage_value(text or "")
    if #text > welcome.LINE_MAX then
        text = welcome.cut(text, welcome.LINE_MAX)
    end
    storedLine = text
    OF.util.store(LINE_KEY, text)
    OF.util.publish(LINE_SYNC, text)

    return true
end

function welcome.custom_text(localIndex)
    local template = welcome.custom_line()
    if template == "" then return nil end

    local who, hostName = welcome.names(localIndex)
    local filled = welcome.expand(template, who, hostName)
    return OF.util.shorten(filled, welcome.DRAW_MAX)
end

function welcome.custom_segments(localIndex)
    local template = welcome.custom_line()
    if template == "" then return nil end

    local np = gNetworkPlayers[localIndex or 0]
    local who = (np ~= nil and np.name ~= nil and np.name ~= "")
        and np.name or OF.lang.t("Player")
    local hostName = OF.lang.t("the host")
    local hostLocal = network_local_index_from_global(0)
    local hostNp = hostLocal ~= nil and gNetworkPlayers[hostLocal] or nil
    if hostNp ~= nil and hostNp.name ~= nil and hostNp.name ~= "" then
        hostName = hostNp.name
    end

    local pieces, _, dropped = welcome.split(template, who, hostName)
    if #pieces == 0 then return nil end

    if dropped then
        local last = nil
        for _, piece in ipairs(pieces) do
            if piece.hole == nil then
                piece.say = string.gsub(piece.say, "  +", " ")
                if last ~= nil and last.hole == nil then
                    piece.say = string.gsub(piece.say, "^ ", "")
                end
            end
            last = piece
        end
        for at = 1, #pieces do
            if pieces[at].hole ~= nil then break end
            pieces[at].say = string.gsub(pieces[at].say, "^%s+", "")
            if pieces[at].say ~= "" then break end
        end
        for at = #pieces, 1, -1 do
            if pieces[at].hole ~= nil then break end
            pieces[at].say = string.gsub(pieces[at].say, "%s+$", "")
            if pieces[at].say ~= "" then break end
        end
    end

    local out, used = {}, 0
    for _, piece in ipairs(pieces) do
        local plain = OF.util.plain(piece.say)
        if used + #plain > welcome.DRAW_MAX then
            local room = welcome.DRAW_MAX - used
            if room > 1 and piece.hole == nil then
                out[#out + 1] = { text = OF.util.shorten(piece.say, room),
                                  r = 255, g = 255, b = 255 }
            end
            break
        end
        used = used + #plain
        if piece.hole ~= nil then

            out[#out + 1] = { text = piece.say, r = 255, g = 255, b = 255,
                              raw = true,
                              who = piece.hole == "player.name" and (localIndex or 0) or nil }
        else
            out[#out + 1] = { text = piece.say, r = 255, g = 255, b = 255 }
        end
    end
    if #out == 0 then return nil end
    return out
end

function welcome.greeting_segments(localIndex)
    local np = gNetworkPlayers[localIndex]
    local name = "Player"
    local r, g, b = 255, 255, 255
    if np ~= nil and np.name ~= nil and np.name ~= "" then
        name = np.name

        r, g, b = OF.util.name_colour()
    end

    local brand = OF.BRAND
    if type(brand) ~= "table" or brand.r == nil then
        brand = { r = 255, g = 255, b = 0 }
    end

    local written = welcome.custom_segments(localIndex)
    if written ~= nil then return written end

    return {
        { text = OF.lang.t("Welcome "), r = 255, g = 255, b = 255 },
        { text = name,       r = r,   g = g,   b = b, raw = true, who = localIndex },
        { text = OF.lang.t(" to "),     r = 255, g = 255, b = 255 },
        { text = "old",      r = brand.r, g = brand.g, b = brand.b },
        { text = OF.lang.t("fart's lobby!"), r = 255, g = 255, b = 255 },
    }
end

welcome.rulesWait = 0

function welcome.opener_key()
    if OF.util.asks(OF.input, "opener_name") then
        return OF.input.opener_name()
    end
    return "/mm"
end

local opener_key = welcome.opener_key

function welcome.greet(localIndex, subtitle)
    welcome.show_banner(welcome.greeting_segments(localIndex), subtitle)
end

welcome.BANNER = { logo = 76, crest = 46, logoAlpha = 0.95, stackGap = 8, pad = 16, scale = 1.15,
    fadeFrames = 9, glintAt = 9, glintFrames = 9, introFrames = 18, inFrames = 15, outFrames = 12 }

function welcome.intro_frames(duration)
    return math.min(welcome.BANNER.introFrames, math.floor((duration or 0) / 3))
end

function welcome.badge_glint(age)
    local M = OF.hud ~= nil and OF.hud.MENU or nil
    if M == nil or M.shineFrames == nil then return nil end
    local L = welcome.BANNER
    local t = (age or 0) - L.glintAt
    if t < 0 or t >= L.glintFrames then return nil end
    return t * M.shineFrames / L.glintFrames
end

local GLINT_BASE, GLINT_BAND = 0.78, 0.24
local function draw_logo(H, cx, cy, size, k, glint)
    local x, y = cx - size / 2, cy - size / 2
    local logo = type(H.menu_logo_info) == "function" and H.menu_logo_info() or nil
    if logo and djui_hud_render_texture ~= nil then
        local sx, sy = size / logo.width, size / logo.height
        local dim = (glint ~= nil and djui_hud_render_texture_tile ~= nil) and GLINT_BASE or 1
        djui_hud_set_color(255, 255, 255, math.floor(255 * k * dim + 0.5))
        djui_hud_render_texture(logo, x, y, sx, sy)
        local M = H.MENU
        if dim < 1 and M ~= nil and M.shineFrames ~= nil then
            local p = OF.util.clamp(glint / M.shineFrames, 0, 1)
            local band = logo.width * GLINT_BAND
            local mid = -band + p * (logo.width + 2 * band)
            local from = math.max(0, math.floor(mid - band / 2))
            local to = math.min(logo.width, math.ceil(mid + band / 2))
            if to > from then
                local wide = to - from
                djui_hud_set_color(255, 255, 255, math.floor(255 * k + 0.5))
                djui_hud_render_texture_tile(logo, x + from * sx, y,
                    sx * logo.height / wide, sy, from, 0, wide, logo.height)
            end
        end
    else
        H.rect(x + 1, y + 1, size - 2, size - 2, H.MENU_BRAND, 255 * k)
        H.text_centred("O", x + size / 2, y + size / 2, "caption", H.C.keyInk, 255 * k)
    end
end

local function banner_ink(seg)
    if seg.who ~= nil and OF.util.asks(OF.panelskin, "player_ink") then
        local r, g, b = OF.panelskin.player_ink(seg.who)
        if r ~= nil then return r, g, b end
    end
    return seg.r, seg.g, seg.b
end
welcome.banner_ink = banner_ink

local function draw_greeting(segments, x, y, scale, alpha)
    for _, seg in ipairs(segments) do
        local r, g, bl = banner_ink(seg)
        if seg.raw then
            OF.util.text_raw(seg.text, x, y, scale, r, g, bl, alpha)
        else
            OF.util.text(seg.text, x, y, scale, r, g, bl, alpha)
        end
        x = x + OF.util.drawn_width(seg.text, scale)
    end
end

local function render_banner()
    local b = welcome.banner
    if b == nil then return end

    if OF.util == nil or type(OF.util.clamp) ~= "function" then return end
    local H = OF.hud
    if H == nil or type(H.plate) ~= "function" or type(H.ease) ~= "table" then return end

    b.timer = b.timer + 1
    if b.timer > b.duration then
        welcome.banner = nil
        return
    end

    if OF.util.menu_has_screen() then return end

    local L = welcome.BANNER
    local sw, sh = H.screen()
    local age = b.timer
    local intro = welcome.intro_frames(b.duration)

    local pAge = age - intro
    local landed = pAge >= 0
    local outT = H.ease.in_cubic(H.progress(age, b.duration - L.outFrames, L.outFrames))
    local logoK = OF.util.clamp(H.ease.out_cubic(age / L.fadeFrames), 0, 1) * (1 - outT)
    local inT = landed and H.ease.out_back(pAge / L.inFrames) or 0
    local k = landed and OF.util.clamp(H.ease.out_cubic(pAge / L.inFrames) * (1 - outT), 0, 1) or 0

    if landed and not b.heard then
        b.heard = true
        if OF.sounds ~= nil and type(OF.sounds.ui) == "function" then OF.sounds.ui("open", false) end
    end

    djui_hud_set_font(FONT_NORMAL)
    local scale = L.scale
    local textRoom = math.min(sw - 64, 980) - L.pad * 2
    local width = OF.util.segments_width(b.segments, scale)
    if width > textRoom and textRoom > 0 then
        scale = math.max(BANNER_MIN_SCALE, scale * (textRoom / width))
        width = OF.util.segments_width(b.segments, scale)
    end
    local lineH = OF.util.line_height(scale)

    local subScale = 0.7
    local subText, subName, subWidth = nil, nil, 0
    if type(b.subtitle) == "table" then
        subText, subName = b.subtitle.text or "", b.subtitle.name or ""
        subWidth = OF.util.named_width(subText, subName, "", subScale)
    elseif b.subtitle ~= nil and b.subtitle ~= "" then
        subText = b.subtitle
        subWidth = OF.util.width(b.subtitle, subScale)
    end
    local subH = subText ~= nil and OF.util.line_height(subScale) or 0

    local contentW = math.max(width, subWidth)
    local contentH = lineH + (subText ~= nil and (6 + subH) or 0)
    local w = L.pad * 2 + contentW
    local h = contentH + L.pad * 2

    local logoCy = sh * 0.13 - outT * 22
    local settle = b.skipIntro and 1 or H.ease.out_cubic(H.progress(age, intro, L.inFrames))
    local logoSize = L.logo + (L.crest - L.logo) * settle
    draw_logo(H, sw / 2, logoCy, logoSize, logoK * L.logoAlpha,
        (not b.skipIntro) and welcome.badge_glint(age) or nil)

    if not landed then return end

    local cy = logoCy + L.crest / 2 + L.stackGap + h / 2 - (1 - inT) * 26
    local x, y = (sw - w) / 2, cy - h / 2
    local openW = w * math.max(0, math.min(1.04, inT))
    H.plate(sw / 2 - openW / 2, y, openW, h, { alpha = k })
    H.rect(sw / 2 - openW / 2 + 2, y, math.max(0, openW - 4), 2, H.MENU_BRAND, 200 * k)

    local ck = k * H.ease.out_cubic(H.progress(pAge, 4, L.inFrames))
    local ca = math.floor(255 * ck)
    local tx = x + L.pad
    local ty = cy - contentH / 2
    djui_hud_set_font(FONT_NORMAL)
    draw_greeting(b.segments, tx, ty, scale, ca)
    ty = ty + lineH + 6

    if type(b.subtitle) == "table" then
        OF.util.text_named(subText, subName, "", tx, ty, subScale, 200, 200, 200, ca)
    elseif subText ~= nil then
        OF.util.text(subText, tx, ty, subScale, 200, 200, 200, ca)
    end
end

local function on_hud_render()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_NORMAL)
    render_banner()
end

welcome.SUB_MAX = 100

function welcome.something_on()
    if OF.util.asks(OF.gamemodes, "is_running") and OF.gamemodes.is_running() then
        return true
    end
    if OF.util.asks(OF.gamemodes, "is_waiting") and OF.gamemodes.is_waiting() then
        return true
    end
    if OF.util.asks(OF.rounds, "is_running") and OF.rounds.is_running() then
        return true
    end
    if OF.util.asks(OF.speedrun, "state") and OF.speedrun.OFF ~= nil
        and OF.speedrun.state() ~= OF.speedrun.OFF then
        return true
    end
    return false
end

function welcome.doing()
    if not welcome.something_on() then return nil end
    if not OF.util.asks(OF.presence, "lobby_line") then return nil end
    local said = OF.presence.lobby_line()
    if type(said) ~= "string" or said == "" then return nil end
    return OF.util.plain(said)
end

function welcome.arrival_line()

    local mayOpen = not (OF.util.asks(OF.perms, "can")
        and not OF.perms.can("panel"))
    if not mayOpen then

        return welcome.doing()
    end

    local opens = opener_key()

    local doing = welcome.doing()
    if doing ~= nil then

        local shape = "@.  @ opens the mod menu."
        local tail = OF.lang.fill(shape, "", opens)
        local room = welcome.SUB_MAX - #tail

        if room >= 12 then
            return OF.lang.fill(shape, OF.util.shorten(doing, room), opens)
        end
    end

    if opens == "/mm" then
        return OF.lang.t("Type /mm to open the mod menu")
    end
    return OF.lang.fill("Press @ or type /mm to open the mod menu", opens)
end

welcome.greetedSelf = false

function welcome.greet_self()
    welcome.greetedSelf = true
    welcome.ready = false
    welcome.readyTimer = 0

    welcome.greet(0, welcome.arrival_line())

    welcome.rulesWait = math.floor((OF.settings.bannerSeconds or 6) * 30) + 30
    if OF.util.is_host() then
        OF.ranks.refresh_all()
    end
end

local function on_player_connected(m)
    if m == nil then return end
    local i = m.playerIndex

    if i == 0 then

        welcome.publish_house()

        welcome.publish_line()
        welcome.greet_self()
        return
    end

    if OF.util.is_host() then
        OF.ranks.refresh(i)
        OF.mute.check_on_join(i)
        OF.jail.check_on_join(i)
    end

    if welcome.ready then
        welcome.greet(i)
        if OF.settings.announceJoins then

            OF.util.chat(OF.chatlog.presence_words("joined", gNetworkPlayers[i].name),
                OF.chatlog.PRESENCE.joined.role, { bare = true })
        end

        OF.chatlog.add_presence("joined", gNetworkPlayers[i].name,
            OF.util.asks(OF.actionlog, "auto")
                and OF.actionlog.BY_THE_ROOM or nil)

        if OF.util.is_host() and OF.util.asks(OF.perms, "tier")
            and OF.util.asks(OF.perms, "required")
            and OF.util.asks(OF.perms, "tier_name")
            and OF.util.asks(OF.notify, "show") then

            local needs = OF.perms.required("panel")

            local np = gNetworkPlayers[i]
            local who = tostring(OF.util.player_id(i) or np.name)
            if OF.perms.tier(i) < needs and needs < OF.TIER.HOST
                and welcome.menuTold[np.globalIndex] ~= who then
                welcome.menuTold[np.globalIndex] = who
                OF.notify.show("@ joined - the mod menu opens at @",
                    "info", 5,
                    OF.util.plain(np.name),
                    OF.lang.t(OF.perms.tier_name(needs)))
            end
        end
    end
end

welcome.menuTold = welcome.menuTold or {}

local function on_player_disconnected(m)
    if m == nil then return end
    local np = gNetworkPlayers[m.playerIndex]
    if np == nil then return end
    welcome.menuTold[np.globalIndex] = nil

    local dropped = OF.util.asks(OF.idle, "was_dropped")
        and OF.idle.was_dropped(m.playerIndex) == true
    local kind = dropped and "dropped" or "left"
    if OF.settings.announceJoins then

        OF.util.chat(OF.chatlog.presence_words(kind, np.name),
            OF.chatlog.PRESENCE[kind].role, { bare = true })
    end
    OF.chatlog.add_presence(kind, np.name,
        OF.util.asks(OF.actionlog, "auto")
            and OF.actionlog.BY_THE_ROOM or nil)
end

local JOIN_SETTLE = 60
local joinFrames = 0

local function on_update()

    if not welcome.greetedSelf then
        if OF.util.is_host() then

            welcome.greetedSelf = true
        else
            local me = gNetworkPlayers[0]
            if me ~= nil and me.connected then
                joinFrames = joinFrames + 1
                if joinFrames >= JOIN_SETTLE then welcome.greet_self() end
            else

                joinFrames = 0
            end
        end
    end

    if welcome.rulesWait > 0 then
        welcome.rulesWait = welcome.rulesWait - 1
        if welcome.rulesWait == 0 then

            if welcome.house_on() then
                welcome.say_house_rules()
            end
        end
    end
    if welcome.ready then return end
    welcome.readyTimer = welcome.readyTimer + 1
    if welcome.readyTimer > 90 then
        welcome.ready = true
    end
end

local HOUSE_SYNC = "ofHouse"
local HOUSE_FIELD = "\31"
welcome.HOUSE_LINES = 5
welcome.HOUSE_MAX = 40

local house = { on = false, lines = {} }
for i = 1, welcome.HOUSE_LINES do house.lines[i] = "" end

local function house_clean(text)
    text = OF.util.storage_value(text or "")
    text = string.gsub(text, HOUSE_FIELD, " ")
    if #text > welcome.HOUSE_MAX then text = welcome.cut(text, welcome.HOUSE_MAX) end
    return text
end

local function house_pack(state)
    local parts = { state.on and "1" or "0" }
    for i = 1, welcome.HOUSE_LINES do
        table.insert(parts, house_clean(state.lines[i]))
    end
    return table.concat(parts, HOUSE_FIELD)
end

local function house_parse(packed)
    local state = { on = false, lines = {} }
    for i = 1, welcome.HOUSE_LINES do state.lines[i] = "" end
    if type(packed) ~= "string" or packed == "" then return state end

    local parts = {}
    for piece in string.gmatch(packed .. HOUSE_FIELD, "([^" .. HOUSE_FIELD .. "]*)" .. HOUSE_FIELD) do
        table.insert(parts, piece)
    end
    state.on = parts[1] == "1"
    for i = 1, welcome.HOUSE_LINES do
        state.lines[i] = house_clean(parts[1 + i] or "")
    end
    return state
end

local RULE_PREFIX = "welcome_rule"
local RULES_ON_KEY = "welcome_rules_on"
local function house_remember()
    OF.util.store_bool(RULES_ON_KEY, house.on)
    for i = 1, welcome.HOUSE_LINES do
        OF.util.store(RULE_PREFIX .. i, house.lines[i])
    end
end

function welcome.house_restore()
    house.on = mod_storage_load_bool(RULES_ON_KEY, false)
    for i = 1, welcome.HOUSE_LINES do
        house.lines[i] = house_clean(mod_storage_load(RULE_PREFIX .. i, ""))
    end
end
welcome.house_restore()

function welcome.publish_house()
    if not OF.util.is_host() then return false end
    return OF.util.publish(HOUSE_SYNC, house_pack(house))
end

function welcome.publish_line()
    if not OF.util.is_host() then return false end
    if storedLine == nil or storedLine == "" then return false end
    return OF.util.publish(LINE_SYNC, storedLine)
end

function welcome.house_state()
    local table_ = gGlobalSyncTable
    local said = table_ ~= nil and table_[HOUSE_SYNC] or nil
    if type(said) == "string" and said ~= "" then return house_parse(said) end
    if OF.util.is_host() then return house_parse(house_pack(house)) end
    return house_parse(nil)
end

function welcome.house_lines()
    local state = welcome.house_state()
    local who, hostName = welcome.names(0)
    local out = {}
    for i = 1, welcome.HOUSE_LINES do
        if state.lines[i] ~= "" then
            local text = (welcome.expand(state.lines[i], who, hostName))
            if text ~= "" then table.insert(out, text) end
        end
    end
    return out
end

function welcome.house_on()
    local state = welcome.house_state()
    return state.on and #welcome.house_lines() > 0
end

local function house_apply(change)
    if not OF.util.is_host() then
        return false, "Only the host writes the house rules."
    end
    if not OF.perms.can("message") then
        return false, "Your rank cannot do that.", "message"
    end
    if change ~= nil then change(house) end
    house_remember()
    OF.util.publish(HOUSE_SYNC, house_pack(house))

    return true
end

function welcome.set_house_line(index, text)
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > welcome.HOUSE_LINES then
        return false, OF.lang.fill("The house rules have @ lines.",
            welcome.HOUSE_LINES)
    end
    local cleaned = house_clean(text)

    return house_apply(function(state) state.lines[index] = cleaned end)
end

function welcome.set_house_on(value)
    local ok, reason, feature =
        house_apply(function(state) state.on = value and true or false end)
    if ok and OF.util.asks(OF.notify, "show") then
        OF.notify.show(welcome.house_on()
            and "Rules on - @ line(s) shown on arrival"
            or "Rules off", "good", 4, tostring(#welcome.house_lines()))
    end
    return ok, reason, feature
end

function welcome.say_house_rules()
    local written = welcome.house_lines()
    if #written == 0 then return false, "There are no house rules to show." end
    for _, text in ipairs(written) do
        OF.util.chat(text, nil, { bare = true, keep = true })
    end
    return true
end

local HOST_ONLY = " (host only)"
local widgetIndexes = {}

local function welcome_widget(gated, name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then
        OF.util = OF.util or {}
        OF.util.missing = OF.util.missing or {}
        OF.util.missing[name] = true
        return
    end
    local ok, index = pcall(fn, ...)
    if gated and ok and type(index) == "number" then
        table.insert(widgetIndexes, { index = index, name = (select(1, ...)) })
    end
end

local namedAsHost = nil

function welcome.name_the_widgets()
    local host = OF.util.is_host()
    if namedAsHost == host then return false end
    local rename = _G["update_mod_menu_element_name"]
    if type(rename) ~= "function" then return false end
    namedAsHost = host
    for _, entry in ipairs(widgetIndexes) do
        if #entry.name + #HOST_ONLY < 64 then
            pcall(rename, entry.index, host and entry.name
                or (entry.name .. HOST_ONLY))
        end
    end
    return true
end

welcome_widget(true, "hook_mod_menu_inputbox", "Welcome message",
    storedLine ~= "" and storedLine or OF.lang.t(welcome.DEFAULT_LINE),
    welcome.LINE_MAX, function(index, value)
        OF.util.report(welcome.set_custom_line(value))
    end)

for i = 1, welcome.HOUSE_LINES do
    welcome_widget(true, "hook_mod_menu_inputbox", "Rule line " .. i,
        house.lines[i], welcome.HOUSE_MAX, function(index, value)
            OF.util.report(welcome.set_house_line(i, value))
        end)
end

welcome_widget(true, "hook_mod_menu_checkbox", "Show the rules on arrival",
    house.on, function(index, value)
        OF.util.report(welcome.set_house_on(value))
    end)

welcome_widget(false, "hook_mod_menu_button", "Show me the rules", function()
    OF.util.report(welcome.say_house_rules())
end)

hook_event(HOOK_UPDATE, welcome.name_the_widgets)

local function rules_help()
    OF.util.chat(OF.lang.fill("/rules shows the lobby's rules. @ line(s) to fill.",
        welcome.HOUSE_LINES))
    OF.util.chat(OF.lang.t("/rules 1 <text> writes a line, /rules 1 clears it"))
    OF.util.chat(OF.lang.t("/rules on and /rules off show them on arrival"))
    OF.util.chat(OF.lang.fill("Holes: @", welcome.hole_list()))
end

local function rules_listing()
    local state = welcome.house_state()
    if welcome.house_on() then
        OF.util.chat(OF.lang.t("The rules, shown on arrival:"))
    else
        OF.util.chat(OF.lang.t("The rules, written but not shown on arrival:"))
    end
    for i = 1, welcome.HOUSE_LINES do
        local text = state.lines[i]
        OF.util.chat(OF.lang.fill("Line @ - @", tostring(i),
            text ~= "" and text or OF.lang.t("empty")))
    end
end

hook_chat_command("rules",
    "- the lobby's rules; the host writes them with /rules 1 <text>",
    function(msg)
        local words = string.match(tostring(msg or ""), "^%s*(.-)%s*$")

        if words == "" then

            if #welcome.house_lines() == 0 then
                OF.util.chat(OF.lang.t("This lobby has not written any rules."))
                if OF.util.is_host() then rules_help() end
                return true
            end
            OF.util.report(welcome.say_house_rules())
            return true
        end

        local lowered = string.lower(words)
        if lowered == "help" then
            rules_help()
            return true
        end
        if lowered == "list" then
            rules_listing()
            return true
        end
        if lowered == "on" or lowered == "off" then
            OF.util.report(welcome.set_house_on(lowered == "on"))
            return true
        end
        if lowered == "clear" then
            local ok = true
            for i = 1, welcome.HOUSE_LINES do
                ok = welcome.set_house_line(i, "") and ok
            end
            if ok then ok = welcome.set_house_on(false) end
            if not ok then
                OF.util.report(false, "Only the host writes the house rules.")
            end
            return true
        end

        local number, rest = string.match(words, "^(%d+)%s*(.*)$")
        if number == nil then
            OF.util.chat(OF.lang.t("/rules help says what this takes."))
            return true
        end
        local ok, why, feature = welcome.set_house_line(tonumber(number), rest)
        OF.util.report(ok, why, feature)

        if ok then
            local _, unknown = welcome.expand(rest, "", "")
            welcome.say_unknown_hole(unknown)
        end
        return true
    end)

hook_event(HOOK_ON_HUD_RENDER, on_hud_render)
hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_player_disconnected)
hook_event(HOOK_UPDATE, on_update)

local DISCORD_LINK = "https://discord.gg/y66mkUjvY"
local DOWNLOAD_LINK = "https://github.com/Mundiese/oldfart_coopdx"
hook_chat_command("discord", "- the Discord link", function()
    OF.util.chat("Discord: " .. DISCORD_LINK)
    return true
end)
hook_chat_command("dc", "- the Discord link", function()
    OF.util.chat("Discord: " .. DISCORD_LINK)
    return true
end)
hook_chat_command("download", "- where to download this mod", function()
    OF.util.chat("Download: " .. DOWNLOAD_LINK)
    return true
end)
hook_chat_command("dl", "- where to download this mod", function()
    OF.util.chat("Download: " .. DOWNLOAD_LINK)
    return true
end)
