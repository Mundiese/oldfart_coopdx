OF = OF or {}
OF.hud = OF.hud or {}

local hud = OF.hud

hud.MENU = {
    width = 900, height = 620,
    pad = 20,
    header = 68, tabs = 44, crumb = 34, footer = 46,
    row = 32,
    gap = 20,
    listShare = 0.60,
    valueRoom = 216,
    armFrames = 150,

    feedFrames = 150,

    feedLines = 6,
    feedLineH = 32,
    feedGap = 4,
    feedAgeRoom = 64,
    glowPeriod = 120,
    shinePeriod = 180, shineFrames = 18,
}

hud.ACTIONS = hud.ACTIONS or {}
hud.ACTIONS.menuChoose = { pad = "A", mouse = "left", key = "L" }
hud.ACTIONS.menuBack   = { pad = "B", mouse = "right", key = "," }
hud.ACTIONS.menuTabL   = { pad = "L", key = "LShift" }
hud.ACTIONS.menuTabR   = { pad = "R", key = "RShift" }
hud.ACTIONS.menuScroll = { pad = "STICK", mouse = "scroll", key = "WASD" }
hud.ACTIONS.menuClose  = { pad = "START", key = "Space" }

hud.SOUND_CUES = {
    move = "MOVE", step = "MOVE", choose = "PICK", arm = "PICK", confirm = "PICK",
    toggle = "TICK", back = "BACK", disarm = "BACK", tab = "TAB",
    open = "OPEN", close = "CLOSE", denied = "DENIED",
}

hud.UI_CUES = {
    move = "move", step = "slider_step", choose = "select", arm = "arm", confirm = "confirm",
    toggle = "toggle_on", back = "back", disarm = "back", tab = "tab",
    open = "open", close = "close", denied = "error",
}

function hud.sound(cue)
    local sounds = OF.sounds
    if sounds == nil or type(sounds.ui) ~= "function" then return nil end
    local name = hud.UI_CUES[cue] or cue
    local word = hud.SOUND_CUES[cue]
    local classic = word ~= nil and sounds[word] or nil
    if not sounds.ui(name, classic) then return nil end
    return name
end

function hud.menu_text_mid(text, x, cy, token, c, alpha, align, mult)
    text = tostring(text or "")
    if text == "" then return 0 end
    if type(hud.text_mid) == "function" then
        return (hud.text_mid(text, x, cy, token, c, alpha, align, mult)) or 0
    end
    local _, h = hud.measure(text, token, mult)
    return (hud.text(text, x, cy - (h or 0) / 2, token, c, alpha, align, mult)) or 0
end

function hud.menu_digits_mid(text, x, cy, token, c, alpha, align)
    if type(hud.digits_mid) == "function" then
        return hud.digits_mid(text, x, cy, token, c, alpha, align)
    end
    local _, h = hud.measure("0", token)
    return hud.digits(text, x, cy - (h or 0) / 2, token, c, alpha, align)
end

function hud.menu_name_colour(c)
    if type(c) ~= "table" or type(hud.readable) ~= "function" then return c end
    local r, g, b = hud.readable(c[1], c[2], c[3])
    if type(r) == "table" then return r end
    if r == nil then return c end
    return { r, g, b }
end

function hud.menu_marquee(text, token, room, frame)
    text = tostring(text or "")
    local w = hud.measure(text, token)
    if w <= room then return text, 0 end
    local panel = OF.panel
    if panel == nil or type(panel.marquee) ~= "function" then
        return hud.fit(text, token, room), 0
    end
    local t = type(token) == "table" and token or hud.TYPE[token or "row"] or hud.TYPE.row
    local face = t.face == "board" and _G["FONT_ALIASED"] or nil
    if face == nil and OF.util ~= nil and type(OF.util.hud_face) == "function" then
        face = OF.util.hud_face(text)
    end
    return OF.util.in_font(face, function()
        return panel.marquee(text, t.scale or 0.85, room, frame or 0)
    end)
end

function hud.menu_wrap(text, token, room, most)
    local lines, line = {}, ""
    for word in string.gmatch(tostring(text or ""), "%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if line ~= "" and hud.measure(try, token) > room then
            lines[#lines + 1] = line
            line = word
            if most ~= nil and #lines >= most then break end
        else
            line = try
        end
    end
    if line ~= "" and (most == nil or #lines < most) then lines[#lines + 1] = line end
    return lines
end

function hud.menu_map_grid(cards, opts, age)
    if type(hud.map_grid) ~= "function" then return nil, opts ~= nil and opts.first or 0 end
    local blocked = hud.blocked
    hud.blocked = function() return false end
    local ok, rects, first = pcall(hud.map_grid, cards, opts, age)
    hud.blocked = blocked
    if not ok then return nil, opts ~= nil and opts.first or 0 end
    return rects, first
end

function hud.menu_window(x, y, w, h, k, accent, opacity)
    local sw, sh = hud.screen()
    k = hud.clamp01(k or 1)
    if k <= 0 then return end
    local body = hud.clamp01(opacity or 1)
    hud.rect(0, 0, sw, sh, hud.C.shade, 130 * k)

    for i = 3, 1, -1 do
        hud.rect(x - i * 3, y - i * 2 + 6, w + i * 6, h + i * 4, hud.C.shade, (26 + (3 - i) * 14) * k)
    end
    hud.plate(x, y, w, h, { alpha = k * (0.55 + 0.45 * body) })
    hud.rect(x + 2, y + 2, w - 4, hud.MENU.header - 2, hud.C.plateHi, 90 * k * body)
    hud.rect(x + 2, y, w - 4, 2, accent or "gold", 255 * k)
end

hud.menuLogo = nil
function hud.menu_logo_info()
    if hud.menuLogo == nil then
        hud.menuLogo = false
        if get_texture_info ~= nil then
            local ok, info = pcall(get_texture_info, "oflogo")
            if ok and type(info) == "table" and (tonumber(info.width) or 0) > 0
                and (tonumber(info.height) or 0) > 0 then
                hud.menuLogo = info
            end
        end
    end
    return hud.menuLogo or nil
end

hud.MENU_BRAND = { 255, 255, 0 }
hud.MENU_LOGO_GLOW = { 255, 214, 40 }

function hud.menu_glow(cx, cy, radius, colour, alpha, layers)
    layers = layers or 5
    local strips = 0
    local step = 2
    for i = 1, layers do
        local r = radius * (1 - (i - 1) / (layers + 1))
        local a = (alpha or 60) / layers
        local sy = -r
        while sy < r do
            local mid = sy + step / 2
            local half = math.sqrt(math.max(0, r * r - mid * mid))
            if half > 0.5 then
                hud.rect(cx - half, cy + sy, half * 2, step, colour, a)
                strips = strips + 1
            end
            sy = sy + step
        end
    end
    return strips
end

function hud.menu_logo(x, y, size, now, k)
    k = hud.clamp01(k or 1)
    hud.menu_logo_glow(x, y, size, now, k)
    local logo = hud.menu_logo_info()
    local drew = false
    if logo and djui_hud_render_texture ~= nil then
        local restore = djui_hud_get_filter ~= nil and djui_hud_get_filter() or nil
        if djui_hud_set_filter ~= nil and FILTER_LINEAR ~= nil then djui_hud_set_filter(FILTER_LINEAR) end
        djui_hud_set_color(255, 255, 255, math.floor(255 * k + 0.5))
        djui_hud_render_texture(logo, x, y, size / logo.width, size / logo.height)
        if djui_hud_set_filter ~= nil and restore ~= nil then djui_hud_set_filter(restore) end
        drew = true
    else
        hud.plate(x, y, size, size, { alpha = k, tint = "gold" })
        hud.rect(x + 3, y + 3, size - 6, size - 6, "gold", 255 * k)
        hud.text_centred("O", x + size / 2, y + size / 2, "heading", hud.C.keyInk, 255 * k)
    end
    hud.menu_logo_shine(x, y, size, now, k)
    return drew
end

function hud.menu_logo_glow(x, y, size, now, k)
    k = hud.clamp01(k or 1)
    local breath = hud.pulse(now or 0, hud.MENU.glowPeriod)
    return hud.menu_glow(x + size / 2, y + size / 2, size * 0.82 + breath * 3, hud.MENU_LOGO_GLOW,
        (55 + breath * 35) * k)
end

hud.menuShine = nil
function hud.menu_shine_info()
    if hud.menuShine == nil then
        hud.menuShine = false
        if get_texture_info ~= nil then
            local ok, info = pcall(get_texture_info, "oflogo_shine")
            if ok and type(info) == "table" and (tonumber(info.width) or 0) > 0
                and (tonumber(info.height) or 0) > 0 then
                hud.menuShine = info
            end
        end
    end
    return hud.menuShine or nil
end

function hud.menu_logo_shine(x, y, size, now, k)
    k = hud.clamp01(k or 1)
    local M = hud.MENU
    local info = hud.menu_shine_info()
    if info == nil or djui_hud_render_texture_tile == nil then return 0 end
    local phase = (now or 0) % M.shinePeriod
    if phase >= M.shineFrames then return 0 end

    local t = phase / M.shineFrames
    local texW, texH = info.width, info.height
    local s = size / texW
    local band = math.max(2, math.floor(texW * 0.14))
    local slices = 16
    local sliceH = texH / slices
    local reach = band + texH * 0.25
    local centre = -reach + t * (texW + reach * 2)
    local alpha = math.floor(110 * (1 - t * 0.5) * k)
    djui_hud_set_color(255, 255, 255, alpha)
    local drawn = 0
    for i = 0, slices - 1 do
        local rowMid = (i + 0.5) * sliceH
        local left = math.floor(centre - (rowMid - texH / 2) * 0.5)
        local from = math.max(0, left)
        local to = math.min(texW, left + band)
        if to > from then
            local tw = to - from
            djui_hud_render_texture_tile(info, x + from * s, y + i * sliceH * (size / texH),
                s * sliceH / tw, size / texH, from, i * sliceH, tw, sliceH)
            drawn = drawn + 1
        end
    end
    return drawn
end

function hud.menu_header(x, y, w, opts, k)
    opts = opts or {}
    k = hud.clamp01(k or 1)
    local M = hud.MENU
    local a = 255 * k
    local size = 40
    local cy = y + M.header / 2
    local lx = x + M.pad
    hud.menu_logo(lx, cy - size / 2, size, opts.now, k)
    local nx = lx + size + hud.S.s4
    local _, th = hud.measure("oldfart", "heading")
    local ty = cy - (th or 22) / 2 - 6
    local ow = hud.text("old", nx, ty, "heading", hud.MENU_BRAND, a) or 0
    hud.text("fart", nx + ow, ty, "heading", "ink", a)
    hud.text("MOD MENU", nx, ty + (th or 22) - 2, "caption", "mute", a)

    local rx = x + w - M.pad
    local badge = opts.badge or "PREVIEW"
    local tone = opts.badgeTone or "warn"
    local bw = hud.measure(badge, "caption") + hud.S.s3 * 2
    local bh = 20
    hud.plate(rx - bw, cy - bh - 2, bw, bh, { alpha = k, tint = tone })
    hud.menu_text_mid(badge, rx - bw / 2, cy - bh / 2 - 2, "caption", tone, a, "center")
    local version = "v" .. tostring(opts.version or "")
    hud.digits(version, rx, cy + 4, "caption", "ink2", a, "right")

    hud.rect(x + M.pad, y + M.header - 1, w - M.pad * 2, 1, hud.C.edge, 22 * k)
end

function hud.menu_tabs(x, y, w, tabs, st, k, set)
    k = hud.clamp01(k or 1)
    st = st or {}
    local M = hud.MENU
    local a = 255 * k
    local h = M.tabs
    local cy = y + h / 2
    local chip = 20
    local lw = hud.glyph_width("menuTabL", chip, set)
    local rw = hud.glyph_width("menuTabR", chip, set)
    local side = math.max(lw, rw) + hud.S.s4
    local chips = {
        { x = x + M.pad, y = cy - chip / 2, w = lw, h = chip, word = "tabPrev" },
        { x = x + w - M.pad - rw, y = cy - chip / 2, w = rw, h = chip, word = "tabNext" },
    }
    hud.glyph("menuTabL", chips[1].x, chips[1].y, chip, a, set)
    hud.glyph("menuTabR", chips[2].x, chips[2].y, chip, a, set)
    local left = x + M.pad + side
    local room = w - (M.pad + side) * 2
    local n = math.max(1, #tabs)
    local cell = room / n
    local cells = {}
    for i = 1, n do cells[i] = { x = left + (i - 1) * cell, y = y + 4, w = cell, h = h - 8 } end

    local ICON = 16
    local iconRoom = st.icon ~= nil and (ICON + hud.S.s2) or 0
    local function span(i)
        local tw = hud.measure(string.upper(tabs[i] or ""), "body") + iconRoom
        local cx = left + (i - 0.5) * cell
        return cx - tw / 2 - hud.S.s2, tw + hud.S.s4
    end
    local cur = st.current or 1
    local from = st.from or cur
    local t = hud.ease.out_cubic(hud.progress((st.now or 0) - (st.at or -1000), 0, hud.MOTION.fast))
    local fx, fw = span(from)
    local cx, cw = span(cur)
    local ux = fx + (cx - fx) * t
    local uw = fw + (cw - fw) * t + math.sin(t * math.pi) * 28
    ux = ux - math.sin(t * math.pi) * 14

    local bx = cells[from].x + (cells[cur].x - cells[from].x) * t
    hud.rect(bx + 4, y + 6, cell - 8, h - 12, hud.C.plateHi, 150 * k)
    for i, name in ipairs(tabs) do
        local on = i == cur
        local hover = st.hover == i and not on
        local closed = st.closed ~= nil and st.closed[i]
        local tone = on and "ink" or (hover and "ink2" or "mute")
        local ta = closed and a * 0.45 or a
        local word = string.upper(name)
        local mid = left + (i - 0.5) * cell
        if st.icon ~= nil then
            local tw = hud.measure(word, "body") + iconRoom
            local lx = mid - tw / 2
            st.icon(i, lx, cy, ICON, (on and 255 or 170) * k * (closed and 0.45 or 1))
            hud.menu_text_mid(word, lx + iconRoom, cy - 1, "body", tone, ta, "left")
        else
            hud.menu_text_mid(word, mid, cy - 1, "body", tone, ta, "center")
        end
    end
    hud.rect(ux, y + h - 9, uw, 3, st.accent or "gold", a)
    hud.rect(ux + 2, y + h - 6, uw - 4, 2, st.accent or "gold", 70 * k)
    hud.rect(x + M.pad, y + h - 1, w - M.pad * 2, 1, hud.C.edge, 22 * k)
    return cells, chips
end

function hud.menu_breadcrumb(x, y, w, crumbs, place, total, k, dx)
    k = hud.clamp01(k or 1)
    local M = hud.MENU
    local a = 255 * k
    local cy = y + M.crumb / 2
    local cx = x + M.pad + (dx or 0)
    local rects = {}
    for i, crumb in ipairs(crumbs or {}) do
        local last = i == #crumbs
        local word = string.upper(tostring(crumb))
        local cw = hud.menu_text_mid(word, cx, cy, "caption", last and "ink" or "mute", a)
        rects[i] = { x = cx - 4, y = y + 4, w = cw + 8, h = M.crumb - 8 }
        cx = cx + cw
        if not last then
            hud.arrow_glyph("right", cx + 8, cy, 8, "mute", a, "chevron")
            cx = cx + 18
        end
    end
    if total ~= nil and total > 0 then
        hud.menu_digits_mid(string.format("%.0f / %.0f", place or 1, total), x + w - M.pad, cy,
            "caption", "mute", a, "right")
    end
    return rects
end

function hud.menu_tag(word, right, cy, tone, a)
    local tw = hud.measure(word, "caption")
    local w, h = tw + hud.S.s3, 18
    local x = right - w
    hud.plate(x, cy - h / 2, w, h, { alpha = (a or 255) / 255, lit = true })
    hud.rect(x + 2, cy + h / 2 - 2, w - 4, 2, tone or "warn", a)
    hud.menu_text_mid(word, x + w / 2, cy - 1, "caption", tone or "warn", a, "center")
    return w
end

function hud.menu_arm_ring(cx, cy, radius, left, a, tone, seconds)
    left = hud.clamp01(left)
    hud.menu_glow(cx, cy, radius, hud.C.shade, a * 0.9, 2)
    hud.arc(cx, cy, radius, 1, 2, hud.C.mute, a * 0.35, 24)
    hud.arc(cx, cy, radius, left, 2, tone or "warn", a, 24)
    local word = seconds or string.format("%.0f", math.max(1, math.ceil(left * hud.MENU.armFrames / 30)))
    hud.menu_text_mid(word, cx, cy, "caption", tone or "warn", a, "center")
end

hud.MENU_MARK_WEIGHT = 2
function hud.menu_box_size(size)
    size = math.max(7, math.floor(size + 0.5))
    if size % 2 == 0 then size = size + 1 end
    return size
end

local checkRunsKept, checkRunsWeight = {}, nil
function hud.menu_check_runs(size)
    size = hud.menu_box_size(size)
    if checkRunsWeight ~= hud.MENU_MARK_WEIGHT then
        checkRunsKept, checkRunsWeight = {}, hud.MENU_MARK_WEIGHT
    end
    local kept = checkRunsKept[size]
    if kept == nil then
        kept = { hud.cut_check_runs(size) }
        checkRunsKept[size] = kept
    end
    return kept[1], kept[2], kept[3], kept[4]
end

function hud.cut_check_runs(size)
    local t = hud.MENU_MARK_WEIGHT
    local long = 2 * math.floor(size / 4)
    local short = 2 * math.floor(long / 5) + 1
    local w, h = short + long + t, long + 1
    local left, top = (size - w) / 2, (size - h) / 2
    local v = left + short
    local runs = {}
    for k = long, 0, -1 do
        local row = top + (long - k)
        local longFrom = v + k
        if k <= short then
            local shortFrom = v - k
            if shortFrom + t >= longFrom then
                runs[#runs + 1] = { shortFrom, row, longFrom + t - shortFrom }
            else
                runs[#runs + 1] = { shortFrom, row, t }
                runs[#runs + 1] = { longFrom, row, t }
            end
        else
            runs[#runs + 1] = { longFrom, row, t }
        end
    end
    return size, runs, w, h
end

local function channel(c)
    c = c / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end
function hud.luminance(c)
    local r, g, b = hud.colour(c)
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end
function hud.contrast(a, b)
    local la, lb = hud.luminance(a), hud.luminance(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

hud.ACCENT_FLOOR = 3.2

local liftWas = {}
function hud.accent_lift(c)
    local r, g, b = hud.colour(c)
    local ground = hud.C.plateHi
    local w = liftWas
    if w.r == r and w.g == g and w.b == b and w.ground == ground and w.floor == hud.ACCENT_FLOOR
        and w.g1 == ground[1] and w.g2 == ground[2] and w.g3 == ground[3] then
        return { w.or_, w.og, w.ob }
    end
    local out
    if hud.contrast({ r, g, b }, ground) >= hud.ACCENT_FLOOR then
        out = { r, g, b }
    else
        local lo, hi = 0, 1
        for _ = 1, 12 do
            local t = (lo + hi) / 2
            local try = { r + (255 - r) * t, g + (255 - g) * t, b + (255 - b) * t }
            if hud.contrast(try, ground) >= hud.ACCENT_FLOOR then hi = t else lo = t end
        end
        out = { math.floor(r + (255 - r) * hi + 0.5), math.floor(g + (255 - g) * hi + 0.5),
            math.floor(b + (255 - b) * hi + 0.5) }
    end
    liftWas = { r = r, g = g, b = b, ground = ground, floor = hud.ACCENT_FLOOR,
        g1 = ground[1], g2 = ground[2], g3 = ground[3], or_ = out[1], og = out[2], ob = out[3] }
    return out
end

function hud.mark_ink(fill)
    local dark, light = hud.contrast(fill, hud.C.keyInk), hud.contrast(fill, hud.C.ink)
    if math.max(dark, light) >= 4.5 then
        return dark >= light and hud.C.keyInk or hud.C.ink
    end

    if hud.contrast(fill, { 0, 0, 0 }) >= hud.contrast(fill, { 255, 255, 255 }) then return { 0, 0, 0 } end
    return { 255, 255, 255 }
end

function hud.menu_checkbox(x, y, size, state, alpha, accent)
    alpha = alpha or 255
    local fill = accent or { hud.colour("gold") }
    local mark = hud.mark_ink(fill)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    local runs, w
    size, runs, w = hud.menu_check_runs(size)
    if state == "on" or state == "some" then
        hud.rect(x, y, size, size, fill, alpha)
        if state == "some" then

            local t = hud.MENU_MARK_WEIGHT
            hud.rect(x + (size - w) / 2, y + math.floor((size - t) / 2), w, t, mark, alpha)
            return size
        end
        for _, run in ipairs(runs) do
            hud.rect(x + run[1], y + run[2], run[3], 1, mark, alpha)
        end
        return size
    end

    hud.rect(x, y, size, 1, hud.C.ink, alpha)
    hud.rect(x, y + size - 1, size, 1, hud.C.ink, alpha)
    hud.rect(x, y + 1, 1, size - 2, hud.C.ink, alpha)
    hud.rect(x + size - 1, y + 1, 1, size - 2, hud.C.ink, alpha)
    return size
end

function hud.menu_lock(cx, cy, a)
    hud.arc(cx, cy - 3, 4, 0.5, 2, "mute", a, 12)
    hud.line(cx - 4, cy - 3, cx - 4, cy, 2, "mute", a)
    hud.line(cx + 4, cy - 3, cx + 4, cy, 2, "mute", a)
    hud.rect(cx - 6, cy, 12, 8, "mute", a)
end

local function choice_slot(right, cy, text, tone, a, slot, index, count, digits)
    local left = right - slot
    hud.arrow_glyph("left", left + 6, cy, 10, "mute", a, "chevron")
    hud.arrow_glyph("right", right - 6, cy, 10, "mute", a, "chevron")
    local mid = left + slot / 2
    if digits then
        hud.menu_digits_mid(text, mid, cy - 1, "rowSmall", tone, a, "center")
    else
        local shown = hud.fit(text, "rowSmall", slot - 32)
        hud.menu_text_mid(shown, mid, cy - 1, "rowSmall", tone, a, "center")
    end
    if count ~= nil and count > 1 and count <= 12 then
        local gap = 7
        local px = mid - (count - 1) * gap / 2
        for i = 1, count do
            hud.rect(px + (i - 1) * gap - 1.5, cy + 10, 3, 3, i == index and "gold" or "mute",
                i == index and a or a * 0.5)
        end
    end
    return left
end

hud.MENU_VALUE_ROOM = {
    page = 96, toggle = 0, double = 150, slider = 200, stepper = 136,
    choice = 184, player = 204, entry = 204, disabled = 96,
}
function hud.menu_value_room(row)
    if row == nil then return 0 end
    if row.disabled ~= nil then

        if type(row.lockWord) == "string" then
            return math.max(hud.MENU_VALUE_ROOM.disabled, hud.measure(row.lockWord, "caption") + 32)
        end
        return hud.MENU_VALUE_ROOM.disabled
    end
    return hud.MENU_VALUE_ROOM[row.kind or ""] or hud.MENU.valueRoom
end

function hud.menu_row(x, y, w, row, st, k)
    st = st or {}
    k = hud.clamp01(k or 1)
    local M = hud.MENU
    local h = M.row
    local cy = y + h / 2
    local f = hud.clamp01(st.focus or 0)
    local a = 255 * k
    local accent = st.accent or "gold"
    local armed = st.armed ~= nil
    local off = row.disabled ~= nil

    if f > 0 then
        hud.plate(x, y + 1, w, h - 2, { alpha = f * k, lit = true,
            strip = armed and "warn" or accent, tint = armed and "warn" or accent })
    end
    if armed then
        local p = hud.pulse(st.now or 0, 20)
        hud.rect(x + 3, y + 2, (w - 6) * hud.clamp01(st.armed), 2, "warn", (120 + 100 * p) * k)
    end
    local slide = 4 * hud.ease.out_cubic(f)
    local lx = x + hud.S.s4 + slide
    local valueRoom = hud.menu_value_room(row)
    local room = w - hud.S.s4 * 2 - valueRoom - slide - (valueRoom > 0 and hud.S.s3 or 0)
    local name = tostring(row.name or "")
    if row.kind == "toggle" then
        local panel = OF.panel

        if panel ~= nil and type(panel.tick) == "function" then name = panel.tick(row.on == true, name) end
    end
    local tone = off and "mute" or ((f > 0.5 or armed) and "ink" or "ink2")

    if row.colour ~= nil and not off then tone = hud.menu_name_colour(row.colour) end
    if armed then tone = "warn" end
    if f > 0.5 and type(hud.name_mid) == "function" then

        hud.name_mid(name, lx, cy, "row", tone, a, "left", room, { key = "menurow" })
    else
        local shown, dx = name, 0
        if f > 0.5 then shown, dx = hud.menu_marquee(name, "row", room, st.since or 0)
        else shown = hud.fit(name, "row", room) end
        hud.menu_text_mid(shown, lx + (dx or 0), cy, "row", tone, a)
    end

    local right = x + w - hud.S.s4
    local kind = row.kind
    local va = off and a * 0.45 or a
    local vtone = f > 0.5 and "ink" or "ink2"
    if off then
        hud.menu_lock(right - 8, cy - 3, a)
        hud.menu_text_mid(row.lockWord or "LOCKED", right - 24, cy, "caption", "mute", a, "right")
    elseif kind == "page" then
        if row.count ~= nil then
            hud.menu_digits_mid(tostring(row.count), right - 20, cy, "caption", "mute", a, "right")
        end
        hud.arrow_glyph("right", right - 6, cy, 10, f > 0.5 and accent or "mute", a, "chevron")
    elseif kind == "slider" then
        local lo, hi = row.min or 0, row.max or 100
        local frac = hud.clamp01(((row.value or lo) - lo) / math.max(1e-6, hi - lo))
        local track = 120
        local tx = right - track
        hud.rect(tx, cy - 2, track, 4, hud.C.shade, 200 * k)
        hud.rect(tx, cy - 2, track * frac, 4, f > 0.5 and accent or "ink2", va)
        hud.diamond(tx + track * frac, cy, 10, f > 0.5 and accent or "ink", va)
        hud.menu_digits_mid(string.format("%.0f", row.value or lo), tx - hud.S.s3, cy - 1,
            "rowSmall", vtone, va, "right")
    elseif kind == "stepper" then
        choice_slot(right, cy, string.format("%.0f", row.value or 0), vtone, va, 120, nil, nil, true)
    elseif kind == "choice" then
        local opts = row.options or {}
        choice_slot(right, cy, tostring(opts[row.index or 1] or ""), vtone, va, 168, row.index, #opts)
    elseif kind == "player" then
        local p = row.player or {}
        local pc = hud.menu_name_colour(p.colour or hud.C.ink)
        local slot = 188
        local left = choice_slot(right, cy, "", vtone, va, slot)
        local nm = hud.fit(tostring(p.name or "-"), "rowSmall", slot - 52)
        local nw = hud.measure(nm, "rowSmall")
        local mid = left + slot / 2
        hud.diamond(mid - nw / 2 - 9, cy, 8, pc, va)
        hud.menu_text_mid(nm, mid + 6, cy - 1, "rowSmall", pc, va, "center")
    elseif kind == "entry" then
        local fw = 188
        local fx = right - fw
        local editing = row.editing == true
        hud.rect(fx, y + 5, fw, h - 10, hud.C.shade, 220 * k)
        hud.rect(fx, y + h - 6, fw, 1, editing and accent or "mute", a)
        local text = hud.fit(tostring(row.text or ""), "rowSmall", fw - 20)
        local tw = hud.menu_text_mid(text, fx + 8, cy - 1, "rowSmall", editing and "ink" or vtone, a)
        if editing and math.floor((st.now or 0) / 15) % 2 == 0 then
            hud.rect(fx + 10 + tw, y + 9, 2, h - 18, accent, a)
        end
    elseif kind == "double" then
        if armed then
            hud.menu_arm_ring(right - 10, cy, 10, st.armed, a)
            hud.menu_text_mid("PRESS AGAIN", right - 28, cy, "caption", "warn", a, "right")
        else
            local tw = hud.menu_tag("2x", right, cy, f > 0.5 and "warn" or "mute", a)
            hud.menu_text_mid("PRESS TWICE", right - tw - hud.S.s2, cy, "caption",
                f > 0.5 and "ink2" or "mute", a, "right")
        end
    end
    return { x = x, y = y, w = w, h = h }
end

function hud.menu_scrollbar(x, y, h, first, visible, total, k, accent)
    if total <= visible then return nil end
    k = hud.clamp01(k or 1)
    hud.rect(x, y, 4, h, hud.C.shade, 180 * k)
    local share = visible / total
    local th = math.max(24, h * share)
    local travel = h - th
    local at = hud.clamp01((first or 0) / math.max(1, total - visible))
    local ty = y + travel * at
    hud.rect(x, ty, 4, th, accent or "gold", 230 * k)
    hud.rect(x, ty, 4, 2, "ink", 120 * k)
    return { x = x - 6, y = y, w = 16, h = h }
end

function hud.menu_detail(x, y, w, h, row, k, dx)
    k = hud.clamp01(k or 1)
    local a = 255 * k
    hud.plate(x, y, w, h, { alpha = k * 0.9 })
    if row == nil then return y end
    local px = x + hud.S.s4 + (dx or 0)
    local room = w - hud.S.s4 * 2
    local cy = y + hud.S.s4
    local KIND = {
        page = "OPENS A PAGE", toggle = "ON OR OFF", slider = "SLIDER", stepper = "STEPPER",
        choice = "CHOICE", player = "PLAYER", entry = "TEXT", double = "PRESS TWICE TO CONFIRM",
    }
    local word = row.disabled ~= nil and "UNAVAILABLE" or (row.kindWord or KIND[row.kind] or "")
    hud.text(word, px, cy, "caption", row.disabled ~= nil and "mute" or (row.kind == "double" and "warn" or "info"), a)
    cy = cy + 18
    for _, line in ipairs(hud.menu_wrap(row.name, "row", room, 2)) do
        hud.text(line, px, cy, "row", row.colour or "ink", a)
        cy = cy + hud.ROW
    end

    if row.now ~= nil and row.now ~= "" then
        local nw = hud.text("NOW", px, cy + 3, "caption", "mute", a) or 0
        local shown, sx = hud.menu_marquee(tostring(row.now), "rowSmall", room - nw - 8, row.since or 0)
        hud.text(shown, px + nw + 8 + (sx or 0), cy, "rowSmall", "ink", a)
        cy = cy + hud.ROW
    end
    cy = cy + hud.S.s2
    hud.rect(px, cy, room, 1, hud.C.edge, 24 * k)
    cy = cy + hud.S.s3
    for _, line in ipairs(hud.menu_wrap(row.help or "", "caption", room, 6)) do
        hud.text(line, px, cy, "caption", "ink2", a)
        cy = cy + 16
    end
    if row.disabled ~= nil then
        cy = cy + hud.S.s2
        hud.text("WHY IT IS OFF", px, cy, "caption", "warn", a)
        cy = cy + 16
        for _, line in ipairs(hud.menu_wrap(row.disabled, "caption", room, 3)) do
            hud.text(line, px, cy, "caption", "ink", a)
            cy = cy + 16
        end
    end
    return cy
end

hud.MENU_FEED_KIND = {
    done  = { glyph = "!", tone = "good" },
    warn  = { glyph = "!", tone = "warn" },
    on    = { glyph = "+", tone = "info" },
    off   = { glyph = "-", tone = "mute" },
    text  = { glyph = "T", tone = "info" },
    deny  = { glyph = "x", tone = "bad" },
}

function hud.menu_feed_icon(kind, cx, cy, a)
    local look = hud.MENU_FEED_KIND[kind] or hud.MENU_FEED_KIND.done
    hud.menu_glow(cx, cy, 11, hud.C.shade, a, 2)
    hud.arc(cx, cy, 10, 1, 2, look.tone, a, 20)
    if kind == "done" then
        hud.line(cx - 5, cy, cx - 1, cy + 4, 2, look.tone, a)
        hud.line(cx - 1, cy + 4, cx + 5, cy - 4, 2, look.tone, a)
    else
        hud.menu_text_mid(look.glyph, cx, cy, "caption", look.tone, a, "center")
    end
end

function hud.menu_age_word(age)
    local s = math.floor((age or 0) / 30)
    if s < 1 then return "NOW" end
    return string.format("%.0fS AGO", s)
end

function hud.menu_feed_room(w)
    return w - 38 - hud.MENU.feedAgeRoom - 10
end

function hud.menu_feed(x, y, w, entries, now, k, most)
    k = hud.clamp01(k or 1)
    local M = hud.MENU
    most = math.min(most or M.feedLines, M.feedLines)
    local lineH, gap = M.feedLineH, M.feedGap
    local drawn = 0
    hud.text("ACTIVITY", x, y, "caption", "mute", 255 * k)
    y = y + 18
    local newest = entries[1]
    local function age_of(e) return e.age or (now - (e.at or now)) end
    local push = newest and hud.ease.out_cubic(hud.progress(age_of(newest), 0, hud.MOTION.fast)) or 1
    for i, e in ipairs(entries) do
        if drawn >= most then break end
        local age = age_of(e)
        if e.life ~= nil or age < M.feedFrames then
            local life = e.life
                or 1 - hud.ease.in_cubic(hud.progress(age, M.feedFrames - hud.MOTION.base, hud.MOTION.base))
            local arrive = hud.ease.out_cubic(hud.progress(age, 0, hud.MOTION.fast))

            local slot = (i - 1) - (i > 1 and (1 - push) or 0)
            local ly = y + slot * (lineH + gap)
            local lx = x + (1 - arrive) * 40
            local dim = 1 - math.min(0.45, (i - 1) * 0.12)
            local ak = k * life * arrive * dim
            local look = hud.MENU_FEED_KIND[e.kind or "done"] or hud.MENU_FEED_KIND.done
            hud.plate(lx, ly, w, lineH, { alpha = ak, strip = look.tone })
            local cy = ly + lineH / 2
            hud.menu_feed_icon(e.kind or "done", lx + 18, cy, 255 * ak)
            local tx = lx + 38
            local room = hud.menu_feed_room(w)
            local whoW = 0
            if e.who ~= nil and e.who ~= "" then
                whoW = hud.name_mid(e.who, tx, cy, "rowSmall",
                    hud.menu_name_colour(e.colour) or "ink", 255 * ak) or 0
                whoW = whoW + 6
            end
            local said, dx = hud.menu_marquee(e.text or "", "rowSmall", room - whoW, age)
            hud.text_mid(said, tx + whoW + (dx or 0), cy, "rowSmall", "ink", 255 * ak)

            hud.text_mid(hud.menu_age_word(age), lx + w - 10, cy, "caption", "mute",
                255 * ak, "right")
            drawn = drawn + 1
        end
    end
    return drawn
end

function hud.menu_chips(cx, cy, list, k)
    k = hud.clamp01(k or 1)
    local size = 22
    local set, fade, prev = hud.glyph_set()
    local rects = {}
    local function row(useSet, alpha, keep)
        local widths, total = {}, 0
        for i, item in ipairs(list) do
            local gw = hud.glyph_width(item[1], size, useSet)
            local lw = hud.measure(item[2], "caption")
            widths[i] = { gw, lw }
            total = total + gw + 6 + lw + (i < #list and hud.S.s6 or 0)
        end
        local x = cx - total / 2
        for i, item in ipairs(list) do
            local gw, lw = widths[i][1], widths[i][2]
            hud.glyph(item[1], x, cy - size / 2, size, alpha, useSet)
            hud.menu_text_mid(item[2], x + gw + 6, cy, "caption", "ink2", alpha)
            if keep then rects[#rects + 1] = { x = x - 4, y = cy - size / 2 - 4, w = gw + 6 + lw + 8, h = size + 8, word = item[3] } end
            x = x + gw + 6 + lw + hud.S.s6
        end
    end
    row(set, 255 * fade * k, true)
    if fade < 1 and prev ~= nil and prev ~= set then row(prev, 255 * (1 - fade) * k, false) end
    return rects
end
