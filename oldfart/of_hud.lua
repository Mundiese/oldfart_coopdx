OF = OF or {}
OF.hud = OF.hud or {}

local hud = OF.hud

hud.C = {
    ink     = { 255, 255, 255 },
    ink2    = { 214, 218, 230 },
    mute    = { 150, 156, 172 },
    plate   = { 16, 18, 28 },
    plateHi = { 40, 46, 64 },
    shade   = { 6, 7, 12 },
    edge    = { 255, 255, 255 },

    accent  = { 255, 204, 64 },
    gold    = { 255, 204, 64 },

    red     = { 255, 75, 62 },
    blue    = { 60, 120, 255 },
    hunter  = { 255, 75, 62 },
    runner  = { 79, 200, 255 },
    target  = { 255, 210, 60 },
    neutral = { 240, 240, 240 },
    out     = { 140, 140, 140 },
    outline = { 20, 20, 20 },
    good    = { 110, 236, 140 },
    bad     = { 255, 92, 92 },
    warn    = { 255, 178, 56 },
    info    = { 140, 210, 255 },
    best    = { 255, 215, 64 },

    cold    = { 160, 210, 255 },

    silver  = { 200, 204, 214 },
    bronze  = { 214, 146, 96 },

    key     = { 232, 234, 242 },
    keyInk  = { 30, 32, 44 },
}

hud.BODY = {
    red  = { 230, 32, 30 },
    blue = { 30, 80, 230 },
}

hud.OUT_SHARE = 0.6

hud.PAD_COLOUR = {
    A = { 70, 110, 255 }, B = { 40, 190, 90 }, START = { 230, 60, 60 },
    C = { 255, 206, 30 }, Z = { 150, 150, 160 }, L = { 150, 150, 160 },
    R = { 150, 150, 160 }, STICK = { 120, 124, 136 }, DPAD = { 120, 124, 136 },
}

hud.CHIP = {
    shadow = { colour = "shade", alpha = 120 },
    keyTop = { colour = "ink", alpha = 90 },
    keyLip = { colour = "shade", alpha = 200 },
    padBar = 3,
    inkLift = 0.55,
    button = hud.PAD_COLOUR,
}

hud.TYPE = {
    display  = { face = "title", scale = 1.20 },
    title    = { face = "title", scale = 0.70 },
    heading  = { face = "title", scale = 0.50 },
    body     = { face = "title", scale = 0.38 },
    caption  = { face = "title", scale = 0.28 },
    row      = { face = "board", scale = 0.85 },
    rowSmall = { face = "board", scale = 0.70 },
}

hud.TYPE_SCALE = { "display", "title", "heading", "body", "row" }

hud.TYPE_FLOOR = { title = "body", board = "row" }

hud.TEAM_GLYPH = { red = "circle", blue = "square" }

hud.S = { s1 = 4, s2 = 8, s3 = 12, s4 = 16, s6 = 24, s8 = 32, s12 = 48 }
hud.MARGIN = 24
hud.ROW = 22

hud.MOTION = { instant = 3, fast = 6, base = 9, slow = 15, hold = 90, feed = 105 }

hud.MOTION.banner = { enter = 8, hold = 60, exit = 6 }
hud.MOTION.band = { enter = 15, hold = 45, exit = 6 }
hud.MOTION.cut, hud.MOTION.stale, hud.MOTION.merge = 4, 90, 90

hud.MOTION.state = { enter = 6, exit = 4, minHold = 60 }

hud.MOTION.reveal = { row = 6, stagger = 4, start = 15 }

hud.MOTION.pop, hud.MOTION.swap = 6, 10
hud.MOTION.roll = { least = 6, per = 2, most = 20 }

hud.FEED_LINES = 4
hud.CALLOUT_FRAMES = 45

hud.GLYPH_SETTLE = 0
hud.GLYPH_FADE = 6

local function clamp01(t)
    if t ~= t or t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t
end
hud.clamp01 = clamp01

hud.ease = {
    linear = function(t) return clamp01(t) end,
    out_cubic = function(t)
        local u = 1 - clamp01(t)
        return 1 - u * u * u
    end,
    out_quint = function(t)
        local u = 1 - clamp01(t)
        return 1 - u * u * u * u * u
    end,
    in_cubic = function(t)
        local v = clamp01(t)
        return v * v * v
    end,
    out_back = function(t)
        local v = clamp01(t)
        local c1 = 1.4
        local c3 = c1 + 1
        local u = v - 1
        return 1 + c3 * u * u * u + c1 * u * u
    end,

    in_out_sine = function(t)
        return 0.5 - 0.5 * math.cos(math.pi * clamp01(t))
    end,
}

function hud.pulse(frame, period)
    period = period or 30
    return 0.5 + 0.5 * math.sin((frame or 0) * 2 * math.pi / period)
end

function hud.progress(age, delay, dur)
    if dur == nil or dur <= 0 then return 1 end
    return clamp01(((age or 0) - (delay or 0)) / dur)
end

function hud.envelope(age, inDur, hold, outDur)
    age = age or 0
    if age < 0 then return 0 end
    local up = hud.ease.out_cubic(hud.progress(age, 0, inDur or hud.MOTION.base))
    if hold == nil then return up end
    local outStart = (inDur or 0) + hold
    if age < outStart then return up end
    return up * (1 - hud.ease.in_cubic(hud.progress(age, outStart, outDur or hud.MOTION.base)))
end

function hud.now()
    if get_global_timer == nil then return 0 end
    return get_global_timer() or 0
end

function hud.card_up()
    local at = hud.state ~= nil and hud.state.introAt or nil
    if type(at) ~= "number" then return false end
    local now = hud.now()
    return now - at <= 1 and now >= at
end

hud.state = hud.state or {
    feed = {},
    callout = nil,
    objective = nil,
    glyph = { set = "none", prev = nil, changedAt = -1000, pending = nil, pendingAt = 0 },
    tracked = {},
}

function hud.colour(c)
    if c == "gold" or c == "accent" or c == hud.C.gold or c == hud.C.accent then
        local util = OF.util
        if util ~= nil and type(util.gold) == "function" then
            local g = util.gold()
            if type(g) == "table" and g.r ~= nil then return g.r, g.g, g.b end
        end
        return hud.C.gold[1], hud.C.gold[2], hud.C.gold[3]
    end

    if c == "dim" then c = "mute" end
    if type(c) == "string" then c = hud.C[c] or hud.C.ink end
    if type(c) ~= "table" then c = hud.C.ink end
    return c[1] or 255, c[2] or 255, c[3] or 255
end

function hud.lighten(c, amount)
    local r, g, b = hud.colour(c)
    local k = clamp01(amount or 0)
    return { r + (255 - r) * k, g + (255 - g) * k, b + (255 - b) * k }
end

function hud.darken(c, amount)
    local r, g, b = hud.colour(c)
    local k = 1 - clamp01(amount or 0)
    return { r * k, g * k, b * k }
end

local function byte(v)
    v = math.floor((v or 0) + 0.5)
    if v < 0 then return 0 end
    if v > 255 then return 255 end
    return v
end

function hud.screen()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    return djui_hud_get_screen_width(), djui_hud_get_screen_height()
end

function hud.unrotate()
    djui_hud_set_rotation(0, 0, 0)
end

function hud.blocked()
    local util = OF.util
    if util ~= nil and type(util.menu_has_screen) == "function" then
        return util.menu_has_screen() == true
    end
    return false
end

function hud.rect(x, y, w, h, c, alpha, from)
    if w <= 0 or h <= 0 then return end
    local r, g, b = hud.colour(c)
    OF.util.rect(x, y, w, h, r, g, b, byte(alpha or 255), from)
end

function hud.diamond(cx, cy, size, c, alpha)
    local half = size / 2
    djui_hud_set_rotation(0x2000, 0.5, 0.5)
    hud.rect(cx - half, cy - half, size, size, c, alpha)
    hud.unrotate()
end

function hud.line(x1, y1, x2, y2, width, c, alpha)
    local r, g, b = hud.colour(c)
    djui_hud_set_color(byte(r), byte(g), byte(b), byte(alpha or 255))
    djui_hud_render_line(x1, y1, x2, y2, width or 2)
    hud.unrotate()
end

function hud.chevron(cx, cy, angle, size, width, c, alpha)
    local tipX = cx + math.cos(angle) * size
    local tipY = cy + math.sin(angle) * size
    local back = size * 0.9
    for _, turn in ipairs({ 2.5, -2.5 }) do
        hud.line(tipX, tipY, tipX + math.cos(angle + turn) * back,
            tipY + math.sin(angle + turn) * back, width or 3, c, alpha)
    end
end

hud.ARROW_WEIGHT = 2
local ARROW_TURN = {
    up = function(x, y) return x, y end,
    down = function(x, y, _, h) return x, h - 1 - y end,
    left = function(x, y) return y, x end,
    right = function(x, y, _, h) return h - 1 - y, x end,
}
local function build_arrow_runs(dir, size, style)
    size = math.max(4, math.floor((size or 8) + 0.5))
    style = style or "arrow"
    local t = hud.ARROW_WEIGHT
    local cells, w, h = {}, 0, 0
    local function put(from, y, len)
        for x = from, from + len - 1 do cells[#cells + 1] = { x, y } end
    end
    local n = math.max(2, math.floor(size / 2))
    if style == "chevron" then
        w, h = 2 * n, n
        for k = 0, n - 1 do
            if k * 2 < t then
                put(n - 1 - k, k, 2 * k + t)
            else
                put(n - 1 - k, k, t)
                put(n - 1 + k, k, t)
            end
        end
    else
        w, h = 2 * n, n
        for k = 0, n - 1 do put(n - 1 - k, k, 2 * k + t) end
        if style ~= "head" then
            h = math.max(size, n + 2)
            for y = n, h - 1 do put(n - t / 2, y, t) end
        end
    end
    local turn = ARROW_TURN[dir] or ARROW_TURN.up
    local bw, bh = w, h
    if dir == "left" or dir == "right" then bw, bh = h, w end
    local rows = {}
    for _, c in ipairs(cells) do
        local x, y = turn(c[1], c[2], w, h)
        rows[y] = rows[y] or {}
        rows[y][x] = true
    end
    local runs = {}
    for y = 0, bh - 1 do
        local x = 0
        while x < bw do
            if rows[y] ~= nil and rows[y][x] then
                local from = x
                while x < bw and rows[y][x] do x = x + 1 end
                runs[#runs + 1] = { from, y, x - from }
            else
                x = x + 1
            end
        end
    end
    return runs, bw, bh
end

do
    local store, storeWeight = {}, nil
    function hud.arrow_runs(dir, size, style)
        size = math.max(4, math.floor((size or 8) + 0.5))
        style = style or "arrow"
        if storeWeight ~= hud.ARROW_WEIGHT then store, storeWeight = {}, hud.ARROW_WEIGHT end
        local byStyle = store[style]
        if byStyle == nil then byStyle = {}; store[style] = byStyle end
        local byDir = byStyle[dir or "up"]
        if byDir == nil then byDir = {}; byStyle[dir or "up"] = byDir end
        local hit = byDir[size]
        if hit == nil then
            local runs, bw, bh = build_arrow_runs(dir, size, style)
            hit = { runs, bw, bh }
            byDir[size] = hit
        end
        return hit[1], hit[2], hit[3]
    end
end

function hud.arrow_glyph(dir, cx, cy, size, c, alpha, style)
    alpha = alpha or 255
    if style == "dpad" then
        local x, y = math.floor(cx - size / 2 + 0.5), math.floor(cy - size / 2 + 0.5)
        hud.plate(x, y, size, size, { alpha = alpha / 255, lit = true })
        local mx, my = x + size / 2, y + size / 2
        local arm = 2 * math.floor(size * 0.16 + 0.5)
        local reach = math.floor(size * 0.40 + 0.5)
        hud.rect(mx - reach, my - arm / 2, reach * 2, arm, hud.C.mute, alpha * 0.85)
        hud.rect(mx - arm / 2, my - reach, arm, reach * 2, hud.C.mute, alpha * 0.85)
        local lx, ly, lw, lh
        if dir == "left" then lx, ly, lw, lh = mx - reach, my - arm / 2, reach - arm / 2, arm
        elseif dir == "right" then lx, ly, lw, lh = mx + arm / 2, my - arm / 2, reach - arm / 2, arm
        elseif dir == "up" then lx, ly, lw, lh = mx - arm / 2, my - reach, arm, reach - arm / 2
        else lx, ly, lw, lh = mx - arm / 2, my + arm / 2, arm, reach - arm / 2 end
        hud.rect(lx, ly, lw, lh, c or hud.C.ink, alpha)
        return size
    end
    local runs, w, h = hud.arrow_runs(dir, size, style)
    local x0 = math.floor(cx - w / 2 + 0.5)
    local y0 = math.floor(cy - h / 2 + 0.5)
    for _, run in ipairs(runs) do
        hud.rect(x0 + run[1], y0 + run[2], run[3], 1, c, alpha)
    end
    return w
end

function hud.arc(cx, cy, radius, fraction, width, c, alpha, segments)
    segments = segments or 32
    local count = math.floor(segments * clamp01(fraction) + 0.5)
    if count <= 0 then return 0 end
    local r, g, b = hud.colour(c)
    djui_hud_set_color(byte(r), byte(g), byte(b), byte(alpha or 255))
    local step = 2 * math.pi / segments
    local px, py = cx, cy - radius
    for i = 1, count do
        local a = -math.pi / 2 + i * step
        local nx, ny = cx + math.cos(a) * radius, cy + math.sin(a) * radius
        djui_hud_render_line(px, py, nx, ny, width or 3)
        px, py = nx, ny
    end
    hud.unrotate()
    return count
end

function hud.plate(x, y, w, h, opts)
    opts = opts or {}
    local k = clamp01(opts.alpha == nil and 1 or opts.alpha)
    if k <= 0 or w <= 0 or h <= 0 then return end
    local body = opts.lit and hud.C.plateHi or hud.C.plate
    if opts.tint ~= nil then
        local tr, tg, tb = hud.colour(opts.tint)
        body = { body[1] * 0.7 + tr * 0.3 * 0.6, body[2] * 0.7 + tg * 0.3 * 0.6,
                 body[3] * 0.7 + tb * 0.3 * 0.6 }
    end

    hud.rect(x - 1, y + 1, w + 2, h + 3, hud.C.shade, 50 * k)
    hud.rect(x, y + 2, w, h, hud.C.shade, 70 * k)

    local cut = math.min(2, math.floor(math.min(w, h) / 4))
    hud.rect(x + cut, y, w - cut * 2, h, body, 205 * k)
    hud.rect(x, y + cut, cut, h - cut * 2, body, 205 * k)
    hud.rect(x + w - cut, y + cut, cut, h - cut * 2, body, 205 * k)

    hud.rect(x + cut, y, w - cut * 2, 1, hud.C.edge, 34 * k)
    if opts.strip ~= nil then
        local sx = opts.right and (x + w - 3) or x
        hud.rect(sx, y + cut, 3, h - cut * 2, opts.strip, 255 * k)
    end
end

function hud.in_round()
    local util = OF.util
    if util == nil or type(util.round_faces_on) ~= "function" then return false end
    return util.round_faces_on() == true
end

local function face_for(token, text, mult)

    if (token == "caption" or token == "rowSmall") and hud.in_round ~= nil and hud.in_round() then
        hud.state.floored = (hud.state.floored or 0) + 1
        token = token == "caption" and hud.TYPE_FLOOR.title or hud.TYPE_FLOOR.board
    end
    local t = type(token) == "table" and token or hud.TYPE[token or "body"] or hud.TYPE.body
    local scale = (t.scale or 0.38) * (mult or 1)
    if t.face == "board" then return _G["FONT_ALIASED"], scale, "board" end
    local util = OF.util
    local face = util ~= nil and util.hud_face ~= nil and util.hud_face(text) or nil
    if face ~= nil then return face, scale, "title" end
    return _G["FONT_ALIASED"], scale * 2, "board"
end
hud.face_for = face_for

local function ink_list(text)
    local out = {}
    for v in string.gmatch(text, "[^,]+") do out[#out + 1] = tonumber(v) end
    return out
end
hud.INK = {
    title = {
        top = 12, base = 53,
        l = ink_list("1,2,1,1,1,1,1,1,14,1,1,1,2,4,1,1,2,1,2,2,1,1,2,2,2,1,1,1,2,14,2,2,2,1,1,2,"
            .. "2,1,1,2,2,2,2,2,1,1,1,2,1,2,1,1,1,1,1,2,2,1,2,1,14,1,2,2,1,1,1,1,1,1,1,1,1,1,1,"
            .. "2,2,1,1,1,2,2,2,2,1,1,1,1,1,2,2,1,15,2"),
        r = ink_list("25,30,45,44,47,48,19,28,42,33,39,25,34,28,35,40,33,41,44,38,43,39,42,42,40,"
            .. "24,25,36,36,49,48,45,44,41,44,42,42,46,41,44,30,46,47,45,45,41,42,43,43,43,51,41,"
            .. "41,44,46,48,49,44,28,44,40,36,58,30,39,34,35,34,37,35,32,33,22,37,36,23,39,33,35,"
            .. "34,34,37,41,35,36,36,38,40,32,34,31,18,44,54"),
    },
    board = {
        top = 6, base = 26,
        l = ink_list("1,0,0,0,0,0,1,0,2,0,2,2,2,2,2,0,2,0,0,0,0,0,0,0,1,2,2,0,2,0,2,0,0,0,0,0,0,"
            .. "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"
            .. "0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0"),
        r = ink_list("8,10,12,10,12,14,6,6,8,10,12,6,8,6,10,12,10,12,12,12,12,12,12,12,12,6,6,8,8,"
            .. "8,12,16,10,10,10,10,10,10,10,10,8,10,10,8,14,14,10,10,10,10,10,10,10,10,14,12,10,"
            .. "10,8,10,8,10,10,5,10,8,8,10,8,10,10,8,5,8,8,5,12,8,8,8,10,8,8,8,8,8,12,10,8,8,8,"
            .. "4,8,14"),
    },
}

local function last_char_start(text)
    local i = #text
    while i > 1 do
        local b = string.byte(text, i)
        if b < 0x80 or b > 0xBF then break end
        i = i - 1
    end
    return i
end

local function ink_box_measured(plain, scale, m)
    local util = OF.util
    local w, h = util.text_size(plain, scale)
    local first = string.find(plain, "[^ ]")
    if first == nil then return 0, 0, m.top * scale, m.base * scale, w, h end
    local trimmed = string.gsub(plain, " +$", "")
    local last = last_char_start(trimmed)
    local lead = first > 1 and util.text_size(string.sub(plain, 1, first - 1), scale) or 0
    local fb = string.byte(plain, first)
    local l = lead
    if fb >= 33 and fb <= 126 then l = lead + (m.l[fb - 32] or 0) * scale end
    local lb = string.byte(trimmed, last)
    local before = last > 1 and util.text_size(string.sub(trimmed, 1, last - 1), scale) or 0
    local r
    if lb >= 33 and lb <= 126 and #trimmed - last == 0 then
        r = before + (m.r[lb - 32] or 0) * scale
    else
        r = util.text_size(trimmed, scale)
    end
    if r < l then r = l end
    return l, r, m.top * scale, m.base * scale, w, h
end

local inkStore, inkStoreFor, inkStoreSize, inkStoreSize2 = {}, nil, nil, 0
local function ink_facts(plain, face)
    local util = OF.util
    local measure, size = djui_hud_measure_text, util.text_size
    if inkStoreFor ~= measure or inkStoreSize ~= size or inkStoreSize2 >= 1024 then
        inkStore, inkStoreFor, inkStoreSize, inkStoreSize2 = {}, measure, size, 0
    end
    local byFace = inkStore[face]
    if byFace == nil then byFace = {}; inkStore[face] = byFace end
    local f = byFace[plain]
    if f ~= nil then return f end
    local w, h = size(plain, 1)
    f = { w = w, h = h }
    local first = string.find(plain, "[^ ]")
    if first ~= nil then
        local trimmed = string.gsub(plain, " +$", "")
        local last = last_char_start(trimmed)
        f.first, f.fb = first, string.byte(plain, first)
        f.lead = first > 1 and size(string.sub(plain, 1, first - 1), 1) or nil
        f.lb = string.byte(trimmed, last)
        f.ends = #trimmed - last == 0
        f.before = last > 1 and size(string.sub(trimmed, 1, last - 1), 1) or nil
        f.trimmed = size(trimmed, 1)
    end
    byFace[plain] = f
    inkStoreSize2 = inkStoreSize2 + 1
    return f
end

local function ink_box(plain, scale, key, face)
    local m = hud.INK[key] or hud.INK.board
    if face == nil then return ink_box_measured(plain, scale, m) end
    local f = ink_facts(plain, face)
    local w, h = f.w * scale, f.h * scale
    if f.first == nil then return 0, 0, m.top * scale, m.base * scale, w, h end
    local lead = f.lead ~= nil and f.lead * scale or 0
    local fb = f.fb
    local l = lead
    if fb >= 33 and fb <= 126 then l = lead + (m.l[fb - 32] or 0) * scale end
    local lb = f.lb
    local before = f.before ~= nil and f.before * scale or 0
    local r
    if lb >= 33 and lb <= 126 and f.ends then
        r = before + (m.r[lb - 32] or 0) * scale
    else
        r = f.trimmed * scale
    end
    if r < l then r = l end
    return l, r, m.top * scale, m.base * scale, w, h
end

local function plain_of(text)
    text = tostring(text or "")
    local util = OF.util
    if util ~= nil and type(util.plain) == "function" then return util.plain(text) end
    return text
end

function hud.measure(text, token, mult)
    text = plain_of(text)
    local face, scale = face_for(token, text, mult)
    return OF.util.in_font_call(face, OF.util.text_size, text, scale)
end

function hud.ink(text, token, mult)
    text = plain_of(text)
    local face, scale, key = face_for(token, text, mult)
    return OF.util.in_font_call(face, ink_box, text, scale, key, face)
end

function hud.ink_at(text, face, scale)
    local key = nil
    if face ~= nil and face == _G["FONT_MENU"] then key = "title"
    elseif face ~= nil and face == _G["FONT_ALIASED"] then key = "board" end
    if key == nil or type(scale) ~= "number" then return nil end
    text = plain_of(text)
    return OF.util.in_font_call(face, ink_box, text, scale, key, face)
end

function hud.ink_width(text, token, mult)
    local l, r = hud.ink(text, token, mult)
    return (r or 0) - (l or 0)
end

function hud.cap(token, mult, text)
    local _, scale, key = face_for(token, text or "0", mult)
    local m = hud.INK[key] or hud.INK.board
    return m.top * scale, m.base * scale, (m.base - m.top) * scale
end

local function aligned_left(x, l, rr, align)
    if align == "center" then return x - (l + rr) / 2 end
    if align == "right" then return x - rr end
    return x - l
end

local function text_body(text, x, y, token, align, mult, from, face, scale, key, r, g, b, alpha)
    local l, rr, _, _, w, h = ink_box(text, scale, key, face)
    local left = aligned_left(x, l, rr, align)
    local prev = nil
    if from ~= nil then
        local _, prevScale = face_for(token, text, from.mult or mult)
        local pl, pr = ink_box(text, prevScale, key, face)
        prev = { x = aligned_left(x, pl, pr, align), y = from.y or y, scale = prevScale }
    end
    OF.util.text(text, left, y, scale, r, g, b, byte(alpha or 255), prev)
    return w, h
end

function hud.text(text, x, y, token, c, alpha, align, mult, from)

    if type(text) == "string" and string.find(text, "\\" .. "#", 1, true) ~= nil
        and plain_of(text) ~= text then
        return hud.name(text, x, y, token, c, alpha, align, nil, { mult = mult })
    end
    text = plain_of(text)
    if text == "" then return 0, 0 end
    local face, scale, key = face_for(token, text, mult)
    local r, g, b = hud.colour(c or "ink")
    return OF.util.in_font_call(face, text_body, text, x, y, token, align, mult, from,
        face, scale, key, r, g, b, alpha)
end

function hud.text_mid(text, x, cy, token, c, alpha, align, mult, fromMult)
    local top, base = hud.cap(token, mult, plain_of(text))
    local from = nil
    if fromMult ~= nil then
        local pt, pb = hud.cap(token, fromMult, plain_of(text))
        from = { mult = fromMult, y = cy - (pt + pb) / 2 }
    end
    return hud.text(text, x, cy - (top + base) / 2, token, c, alpha, align, mult, from)
end

function hud.text_base(text, x, by, token, c, alpha, align, mult)
    local _, base = hud.cap(token, mult, plain_of(text))
    return hud.text(text, x, by - base, token, c, alpha, align, mult)
end

function hud.text_centred(text, cx, cy, token, c, alpha, mult, fromMult)
    return hud.text_mid(text, cx, cy, token, c, alpha, "center", mult, fromMult)
end

function hud.text_in(text, bx, by, bw, bh, token, c, alpha, mult)
    return hud.text_mid(text, bx + bw / 2, by + bh / 2, token, c, alpha, "center", mult)
end

function hud.fit(text, token, room)
    text = plain_of(text)
    local util = OF.util
    if util == nil or type(util.fit_name) ~= "function" then return text end
    local face, scale = face_for(token, text)
    return util.in_font(face, function()
        return util.fit_name(text, scale, room)
    end)
end

function hud.sentence(text)
    text = tostring(text or "")
    return (string.gsub(text, "^(%s*)(%l)", function(space, first)
        return space .. string.upper(first)
    end))
end

function hud.wrap(text, token, room, most)
    text = plain_of(text)
    local lines = {}
    if text == "" then return lines end
    most = most or 99
    local current = ""
    for word in string.gmatch(text, "%S+") do
        local try = current == "" and word or (current .. " " .. word)
        if current ~= "" and #lines < most - 1 and hud.measure(try, token) > room then
            lines[#lines + 1] = current
            current = word
        else
            current = try
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return lines
end

function hud.digits(text, x, y, token, c, alpha, align, mult)
    text = plain_of(text)
    local face, scale, key = face_for(token, "0", mult)
    local m = hud.INK[key] or hud.INK.board
    local r, g, b = hud.colour(c or "ink")
    return OF.util.in_font(face, function()
        local cell = OF.util.text_size("0", scale)
        local zero = ((m.r[16] or 1) - (m.l[16] or 0)) * scale
        local ratio = zero > 0 and cell / zero or 1
        local cells, total = {}, 0
        for i = 1, #text do
            local ch = string.sub(text, i, i)
            local bt = string.byte(ch)
            local il, ir = 0, OF.util.text_size(ch, scale) / scale
            if bt >= 33 and bt <= 126 then il, ir = m.l[bt - 32] or 0, m.r[bt - 32] or 0 end
            local inkW = (ir - il) * scale
            local w
            if string.find(ch, "%d") then w = cell
            elseif ch == " " then w = OF.util.text_size(" ", scale)
            else w = inkW * ratio end
            cells[i] = { ch = ch, w = w, mid = (il + ir) / 2 * scale }
            total = total + w
        end
        local left = x
        if align == "center" then left = x - total / 2
        elseif align == "right" then left = x - total end
        for i = 1, #cells do
            local cl = cells[i]
            if cl.ch ~= " " then
                OF.util.text(cl.ch, left + cl.w / 2 - cl.mid, y, scale, r, g, b, byte(alpha or 255))
            end
            left = left + cl.w
        end
        return total
    end)
end

function hud.digits_mid(text, x, cy, token, c, alpha, align, mult)
    local top, base = hud.cap(token, mult, "0")
    return hud.digits(text, x, cy - (top + base) / 2, token, c, alpha, align, mult)
end

function hud.digits_width(text, token, mult)
    text = plain_of(text)
    local face, scale, key = face_for(token, "0", mult)
    local m = hud.INK[key] or hud.INK.board
    return OF.util.in_font(face, function()
        local cell = OF.util.text_size("0", scale)
        local zero = ((m.r[16] or 1) - (m.l[16] or 0)) * scale
        local ratio = zero > 0 and cell / zero or 1
        local total = 0
        for i = 1, #text do
            local ch = string.sub(text, i, i)
            local bt = string.byte(ch)
            if string.find(ch, "%d") then total = total + cell
            elseif ch == " " then total = total + OF.util.text_size(" ", scale)
            elseif bt >= 33 and bt <= 126 then
                total = total + ((m.r[bt - 32] or 0) - (m.l[bt - 32] or 0)) * scale * ratio
            else total = total + OF.util.text_size(ch, scale) end
        end
        return total
    end)
end

hud.NAME_FLOOR = 120

function hud.readable(r, g, b)
    local lum = 0.299 * r + 0.587 * g + 0.114 * b
    if lum >= hud.NAME_FLOOR then return r, g, b end
    local k = (hud.NAME_FLOOR - lum) / math.max(1, 255 - lum)
    return r + (255 - r) * k, g + (255 - g) * k, b + (255 - b) * k
end

function hud.name_runs(text, tone)
    text = tostring(text or "")

    local close = "\\" .. "#FFFFFF" .. "\\"
    if string.find(text, close, 1, true) ~= nil then
        text = string.gsub(text, close, "\\" .. "#" .. "\\")
    end
    local tr, tg, tb = hud.colour(tone or "ink")
    local util = OF.util
    local runs
    if util ~= nil and type(util.colour_runs) == "function" then
        runs = util.colour_runs(text, { r = tr, g = tg, b = tb })
    else
        runs = { { text = text, r = tr, g = tg, b = tb } }
    end
    local out = {}
    for _, run in ipairs(runs) do
        local plain = plain_of(run.text)
        if plain ~= "" then
            local r, g, b = run.r, run.g, run.b
            if r ~= tr or g ~= tg or b ~= tb then r, g, b = hud.readable(r, g, b) end
            out[#out + 1] = { text = plain, r = r, g = g, b = b }
        end
    end
    return out
end

hud.MARQUEE = { speed = 1, pause = 45 }

function hud.marquee_offset(travel, frame)
    if travel <= 0 then return 0 end
    local pause, speed = hud.MARQUEE.pause, hud.MARQUEE.speed
    local moving = travel / speed
    local phase = (frame or 0) % (pause + moving + pause)
    return math.max(0, math.min(travel, (phase - pause) * speed))
end

function hud.marquee_frame(key, text, now)
    now = now or hud.now()
    hud.state.marquee = hud.state.marquee or {}
    local held = hud.state.marquee[key]
    if held == nil or held.text ~= text then
        held = { text = text, at = now }
        hud.state.marquee[key] = held
    end
    held.seen = now
    return now - held.at
end

function hud.name(text, x, y, token, tone, alpha, align, room, opts)
    opts = opts or {}
    local runs = hud.name_runs(text, tone)
    if #runs == 0 then return 0, 0 end
    local pieces = {}
    for i, run in ipairs(runs) do pieces[i] = run.text end
    local plain = table.concat(pieces)
    local face, scale, key = face_for(token, plain, opts.mult)
    local a = byte(alpha or 255)
    local util = OF.util
    return util.in_font(face, function()
        local l, rr, _, _, w, h = ink_box(plain, scale, key, face)
        if room == nil or w <= room then
            local left = x - l
            if align == "center" then left = x - (l + rr) / 2
            elseif align == "right" then left = x - rr end
            for _, run in ipairs(runs) do
                util.text(run.text, left, y, scale, run.r, run.g, run.b, a)
                left = left + util.text_size(run.text, scale)
            end
            return w, h
        end

        local x0 = x
        if align == "center" then x0 = x - room / 2 elseif align == "right" then x0 = x - room end
        local frame = hud.marquee_frame(opts.key or plain, plain)

        local fade = util.text_size("m", scale)
        if fade == nil or fade <= 0 then fade = 1 end
        local travel = w - room + fade
        local offset = hud.marquee_offset(travel, frame)
        local before = hud.marquee_offset(travel, frame - 1)
        local pen = 0
        for _, run in ipairs(runs) do
            for ch in string.gmatch(run.text, "[%z\1-\127\194-\244][\128-\191]*") do
                local adv = util.text_size(ch, scale)
                local cx = x0 + pen - offset

                local hidden = math.max(0, x0 - cx)
                local kLeft = adv > 0 and (1 - hidden / adv) or 0
                local kRight = math.max(0, math.min(1, ((x0 + room) - (cx + adv)) / fade))
                local k = math.min(kLeft, kRight)
                if ch ~= " " and k > 0 then
                    util.text(ch, cx, y, scale, run.r, run.g, run.b, a * k,
                        { x = x0 + pen - before, y = y, scale = scale })
                end
                pen = pen + adv
            end
        end
        return room, h
    end)
end
hud.label = hud.name

function hud.name_mid(text, x, cy, token, tone, alpha, align, room, opts)
    local top, base = hud.cap(token, opts and opts.mult, plain_of(text))
    return hud.name(text, x, cy - (top + base) / 2, token, tone, alpha, align, room, opts)
end

function hud.clock(seconds, tenths)
    seconds = math.max(0, seconds or 0)
    local whole = math.floor(seconds)
    local h = math.floor(whole / 3600)
    local m = math.floor((whole % 3600) / 60)
    local s = whole % 60
    local out
    if h > 0 then out = string.format("%.0f:%02.0f:%02.0f", h, m, s)
    else out = string.format("%.0f:%02.0f", m, s) end
    if tenths then out = out .. string.format(".%.0f", math.floor((seconds - whole) * 10)) end
    return out
end

function hud.glyph_set(now)
    now = now or hud.now()
    local st = hud.state.glyph
    local input = OF.input
    local want = nil
    if input ~= nil and type(input.chip_set) == "function" then
        want = input.chip_set()
    elseif input ~= nil and type(input.device) == "function" then
        local device = input.device()
        if device == "mouse" then want = "kbm" elseif device == "pad" then want = "pad" end
    end
    if (want == "kbm" or want == "pad") and want ~= st.set then
        st.prev, st.set, st.changedAt, st.pending = st.set, want, now, nil
    end
    return st.set, clamp01((now - st.changedAt) / hud.GLYPH_FADE), st.prev
end

hud.ACTIONS = {
    move    = { pad = "STICK", key = "WASD" },
    jump    = { pad = "A", key = "L" },
    attack  = { pad = "B", key = "," },
    crouch  = { pad = "Z", key = "K" },
    aim     = { pad = "L", mouse = "back", key = "LShift" },
    fire    = { pad = "L+B", key = "LShift+," },
    grenade = { pad = "Y", key = "M" },

    spacejump = { pad = "A", key = "Space" },
    pause   = { pad = "START", mouse = "middle", key = "Space" },
    flash   = { pad = "X", key = "I" },
    camera  = { pad = "C", key = "Arrows" },

    list    = { pad = "Select", key = "Tab" },
    watch   = { pad = "DPAD", padText = "<", key = "Del" },
    leave   = { pad = "DPAD", padText = ">", key = "PgDn" },

    labNext = { pad = "L+C", padText = "L+C>", key = "LShift+Right" },
    labBack = { pad = "L+C", padText = "L+C<", key = "LShift+Left" },
    labDo   = { pad = "L+C", padText = "L+C^", key = "LShift+Up" },
    labDev  = { pad = "L+C", padText = "L+Cv", key = "LShift+Down" },
}

hud.KEY_WORDS = { LShift = "Shift", RShift = "Shift", LCtrl = "Ctrl", RCtrl = "Ctrl",
    Arrows = "Arrows", Space = "Space", PgDn = "PgDn", Del = "Del", Back = "Back", Select = "Select" }
local DIRECTION = { Left = "left", Right = "right", Up = "up", Down = "down",
    ["<"] = "left", [">"] = "right", ["^"] = "up", ["v"] = "down" }
hud.DIRECTION = DIRECTION

local function build_glyph_parts(words)
    local parts = {}
    words = tostring(words or "")

    local pieces = {}
    if words == "+" or words == "," then pieces = { words }
    else
        for piece in string.gmatch(words, "[^+]+") do pieces[#pieces + 1] = piece end
        if #pieces == 0 then pieces = { words } end
    end
    for _, piece in ipairs(pieces) do
        local dir = DIRECTION[piece]
        if dir ~= nil then
            parts[#parts + 1] = { arrow = dir }
        else
            local word, tail = string.match(piece, "^(.-)([<>%^v])$")
            if word ~= nil and word ~= "" and #piece <= 3 then
                parts[#parts + 1] = { word = word, arrow = DIRECTION[tail] }
            else
                parts[#parts + 1] = { word = hud.KEY_WORDS[piece] or piece }
            end
        end
    end
    return parts
end

local glyph_parts
do
    local store, count = {}, 0
    glyph_parts = function(words)
        local key = tostring(words or "")
        local hit = store[key]
        if hit ~= nil then return hit end
        if count >= 256 then store, count = {}, 0 end
        hit = build_glyph_parts(key)
        store[key] = hit
        count = count + 1
        return hit
    end
end
hud.glyph_parts = glyph_parts

hud.BUTTON_MOVE = { A = "Jump", B = "Punch", Z = "Crouch" }

local function move_word(button)
    local word = hud.BUTTON_MOVE[button]
    if word == nil then return nil end
    if OF.lang ~= nil and type(OF.lang.t) == "function" then return OF.lang.t(word) end
    return word
end

function hud.move_words(entry)
    if type(entry) ~= "table" or type(entry.pad) ~= "string" then return nil end
    if entry.pad == entry.key then return nil end
    local keys = {}
    for piece in string.gmatch(tostring(entry.key or ""), "[^+]+") do keys[#keys + 1] = piece end
    local out, moved, i = {}, false, 0
    for button in string.gmatch(entry.pad, "[^+]+") do
        i = i + 1
        local word = move_word(button)
        if word ~= nil then moved = true else word = keys[i] or button end
        out[#out + 1] = word
    end
    if not moved then return nil end
    return table.concat(out, "+")
end

function hud.say_buttons(text)
    local input = OF.input
    if input == nil or type(input.button_text) ~= "function" then return text end
    return input.button_text(text)
end

function hud.chip_says(action, label, set)
    if set ~= "kbm" or type(label) ~= "string" then return false end
    local kind, words = hud.glyph_words(action, set)
    return kind == "move" and type(words) == "string"
        and string.lower(words) == string.lower(OF.util.plain(label))
end

local function glyph_words(action, set)
    local entry = type(action) == "table" and action
        or hud.ACTIONS[action] or { pad = tostring(action), key = tostring(action) }
    if set == "kbm" then
        if entry.mouse ~= nil then return "mouse", entry.mouse end

        if type(action) == "string" and hud.ACTIONS[action] == nil then
            local said = hud.prompt_key(action, "kbm")
            if hud.BUTTON_MOVE[action] ~= nil then
                return "move", said, { pad = action, key = said }
            end
            return "key", said
        end
        local moved = hud.move_words(entry)
        if moved ~= nil then return "move", moved, entry end
        return "key", entry.key or entry.pad
    end

    if set == "none" and not (type(action) == "string" and string.sub(action, 1, 4) == "menu") then
        local both = entry
        if type(action) == "string" and hud.ACTIONS[action] == nil and hud.BUTTON_MOVE[action] ~= nil then
            both = { pad = action }
        end
        if hud.move_words(both) ~= nil then
            local words = {}
            for _, item in ipairs(hud.move_parts(both, "none")) do words[#words + 1] = item.part.word or "" end
            return "move", table.concat(words, "+"), both
        end
    end
    return "pad", entry.padText or entry.pad, entry.pad
end
hud.glyph_words = glyph_words

local function chip_pad(size) return math.max(6, math.floor(size * 0.36)) end
local function arrow_size(size) return size * 0.42 end
local JOINT = 12

local function part_width(part, size)
    local pad = chip_pad(size)
    local w = 0
    if part.word ~= nil then w = w + hud.ink_width(part.word, "caption") end
    if part.arrow ~= nil then
        if w > 0 then w = w + 3 end
        w = w + arrow_size(size)
    end
    return math.max(size, w + pad * 2)
end

function hud.move_parts(entry, set)
    local out = {}
    if type(entry) ~= "table" or type(entry.pad) ~= "string" then return out end
    local keys = {}
    for piece in string.gmatch(tostring(entry.key or ""), "[^+]+") do keys[#keys + 1] = piece end
    local i = 0
    for button in string.gmatch(entry.pad, "[^+]+") do
        i = i + 1
        local word = move_word(button)
        if word ~= nil then
            if set == "none" then word = button .. " " .. word end
            out[#out + 1] = { part = { word = word }, kind = "pad",
                colour = hud.CHIP.button[button] or hud.CHIP.button.Z }
        elseif set == "none" then
            for _, part in ipairs(glyph_parts(button)) do
                out[#out + 1] = { part = part, kind = "pad",
                    colour = hud.CHIP.button[part.word or "Z"] or hud.CHIP.button.Z }
            end
        else
            for _, part in ipairs(glyph_parts(keys[i] or button)) do
                out[#out + 1] = { part = part, kind = "key", colour = hud.CHIP.button.Z }
            end
        end
    end
    return out
end

local function draw_chip(part, x, y, size, alpha, kind, colour)
    local S = hud.CHIP
    local w = part_width(part, size)
    local k = alpha / 255
    hud.rect(x, y + 2, w, size, hud.C[S.shadow.colour], S.shadow.alpha * k)
    hud.plate(x, y, w, size, { alpha = k, lit = true })
    local ink = hud.C.ink
    if kind == "key" then
        hud.rect(x + 2, y, w - 4, 1, hud.C[S.keyTop.colour], S.keyTop.alpha * k)
        hud.rect(x + 2, y + size - 2, w - 4, 2, hud.C[S.keyLip.colour], S.keyLip.alpha * k)
    else
        hud.rect(x + 2, y + size - S.padBar, w - 4, S.padBar, colour, 255 * k)
        ink = hud.lighten(colour, S.inkLift)
    end
    local cy = y + (kind == "key" and size - 2 or size - S.padBar) / 2
    local ww = part.word ~= nil and hud.ink_width(part.word, "caption") or 0
    local aw = part.arrow ~= nil and arrow_size(size) or 0
    local gap = (ww > 0 and aw > 0) and 3 or 0
    local left = x + w / 2 - (ww + gap + aw) / 2
    if part.word ~= nil then
        hud.text_mid(part.word, left, cy, "caption", ink, alpha, "left")
    end
    if part.arrow ~= nil then
        hud.arrow_glyph(part.arrow, left + ww + gap + aw / 2, cy, aw, ink, alpha)
    end
    return w
end

function hud.mouse_glyph(x, y, size, which, alpha)
    which = tostring(which or "")
    alpha = alpha or 255
    local w = math.max(9, math.floor(size * 0.72 + 0.5))
    if w % 2 == 0 then w = w + 1 end
    local h = math.max(12, math.floor(size + 0.5))
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    local ink, lit = hud.C.ink, "gold"
    local mid = x + (w - 1) / 2
    local split = y + math.floor(h * 0.45)
    local function has(word) return string.find(which, word, 1, true) ~= nil end
    hud.plate(x, y, w, h, { alpha = alpha / 255, lit = true })

    hud.rect(x + 2, y, w - 4, 1, ink, alpha)
    hud.rect(x + 2, y + h - 1, w - 4, 1, ink, alpha)
    hud.rect(x, y + 2, 1, h - 4, ink, alpha)
    hud.rect(x + w - 1, y + 2, 1, h - 4, ink, alpha)
    hud.rect(x + 1, y + 1, 1, 1, ink, alpha)
    hud.rect(x + w - 2, y + 1, 1, 1, ink, alpha)
    hud.rect(x + 1, y + h - 2, 1, 1, ink, alpha)
    hud.rect(x + w - 2, y + h - 2, 1, 1, ink, alpha)

    hud.rect(x + 1, split, w - 2, 1, ink, alpha)

    local wheelTop = y + 3
    local wheelH = math.max(3, split - y - 6)
    local wheelOn = has("middle") or has("scroll")

    local boxTop, boxBottom = wheelTop - 1, wheelTop + wheelH - 1

    local half = math.max(1, math.floor(w * 0.1))
    local wheelW = half * 2 + 1
    local left, right = x + 1, x + w - 2
    if has("left") then
        hud.rect(left, y + 2, (mid - half - 1) - left + 1, split - y - 2, lit, alpha)
        hud.rect(left + 1, y + 1, (mid - half - 1) - (left + 1) + 1, 1, lit, alpha)
        if boxTop - (y + 1) > 0 then hud.rect(mid - half, y + 1, half, boxTop - (y + 1), lit, alpha) end
        if split - (boxBottom + 1) > 0 then hud.rect(mid - half, boxBottom + 1, half, split - (boxBottom + 1), lit, alpha) end
    end
    if has("right") then
        hud.rect(mid + half + 1, y + 2, right - (mid + half + 1) + 1, split - y - 2, lit, alpha)
        hud.rect(mid + half + 1, y + 1, (right - 1) - (mid + half + 1) + 1, 1, lit, alpha)
        if boxTop - (y + 1) > 0 then hud.rect(mid + 1, y + 1, half, boxTop - (y + 1), lit, alpha) end
        if split - (boxBottom + 1) > 0 then hud.rect(mid + 1, boxBottom + 1, half, split - (boxBottom + 1), lit, alpha) end
    end
    hud.rect(mid, y + 1, 1, boxTop - (y + 1), ink, alpha)
    hud.rect(mid, boxBottom + 1, 1, split - (boxBottom + 1), ink, alpha)
    hud.rect(mid - half, boxTop, wheelW, boxBottom - boxTop + 1, wheelOn and lit or ink, alpha)
    if has("scroll") then

        hud.rect(mid, y - 3, 1, 2, lit, alpha)
        hud.rect(mid, split + 2, 1, 2, lit, alpha)
    end
    if has("back") then hud.rect(x - 2, y + math.floor(h * 0.55), 2, math.floor(h * 0.22), lit, alpha) end
    return w
end

local function pad_colour(part)
    local word = part.word or (part.arrow ~= nil and "C") or "Z"
    if part.arrow ~= nil and part.word == nil then word = "STICK" end
    return hud.CHIP.button[word] or hud.CHIP.button.Z
end

function hud.glyph(action, x, y, size, alpha, set)
    set = set or hud.glyph_set()
    alpha = alpha or 255
    size = size or 22
    local kind, words, entry = glyph_words(action, set)
    if kind == "mouse" then return hud.mouse_glyph(x, y, size, words, alpha) end
    if kind == "move" then
        local left = x
        for i, item in ipairs(hud.move_parts(entry, set)) do
            if i > 1 then
                hud.text_mid("+", left + JOINT / 2, y + size / 2, "caption", "mute", alpha, "center")
                left = left + JOINT
            end
            left = left + draw_chip(item.part, left, y, size, alpha, item.kind, item.colour)
        end
        return left - x
    end
    local parts = glyph_parts(words)
    local left = x
    for i, part in ipairs(parts) do
        if i > 1 then
            hud.text_mid("+", left + JOINT / 2, y + size / 2, "caption", "mute", alpha, "center")
            left = left + JOINT
        end
        left = left + draw_chip(part, left, y, size, alpha, kind, pad_colour(part))
    end
    return left - x
end

function hud.glyph_width(action, size, set)
    set = set or hud.glyph_set()
    size = size or 22
    local kind, words, entry = glyph_words(action, set)
    if kind == "mouse" then
        local w = math.max(9, math.floor(size * 0.72 + 0.5))
        return w % 2 == 0 and w + 1 or w
    end
    if kind == "move" then
        local total = 0
        for i, item in ipairs(hud.move_parts(entry, set)) do
            if i > 1 then total = total + JOINT end
            total = total + part_width(item.part, size)
        end
        return total
    end
    local total = 0
    for i, part in ipairs(glyph_parts(words)) do
        if i > 1 then total = total + JOINT end
        total = total + part_width(part, size)
    end
    return total
end

function hud.hint_row(list, x, y, alpha, set)
    local size = hud.HINT_SIZE
    set = set or hud.glyph_set()
    local hx = x
    for index, item in ipairs(list) do
        if index > 1 then hx = hx + hud.S.s6 end
        hx = hx + hud.glyph(item[1], hx, y, size, alpha, set)
        if not hud.chip_says(item[1], item[2], set) then
            hx = hx + hud.S.s2
            hud.text_mid(item[2], hx, y + size / 2, "caption", "ink2", alpha, "left")
            hx = hx + hud.ink_width(item[2], "caption")
        end
    end
    return hx - x
end

function hud.hint_row_width(list, set)
    local w = 0
    for index, item in ipairs(list) do
        if index > 1 then w = w + hud.S.s6 end
        w = w + hud.glyph_width(item[1], hud.HINT_SIZE, set)
        if not hud.chip_says(item[1], item[2], set) then
            w = w + hud.S.s2 + hud.ink_width(item[2], "caption")
        end
    end
    return w
end

function hud.header(title, sub, hints, claim, tone, subTone)
    if title == nil or title == "" or hud.blocked() then return nil end
    local sw = hud.screen()
    local _, _, titleH = hud.cap("heading", 1, plain_of(title))
    local subH = 0
    if sub ~= nil and sub ~= "" then
        local _, _, h = hud.cap("body", 1, plain_of(sub))
        subH = h
    end
    local room = sw - hud.MARGIN * 2 - hud.S.s4 * 2
    local inkW = hud.ink_width(title, "heading")
    if subH > 0 then inkW = math.max(inkW, hud.ink_width(sub, "body")) end
    local pw = math.min(inkW, room) + hud.S.s4 * 2
    local ph = titleH + hud.S.s2 * 2 + (subH > 0 and (subH + hud.S.s2) or 0)
    local hintW = (hints ~= nil and #hints > 0) and hud.hint_row_width(hints) or 0
    local tall = ph + (hintW > 0 and (hud.S.s2 + hud.HINT_SIZE) or 0)
    local top = claim ~= nil and claim(tall, math.max(pw, hintW)) or hud.MARGIN
    hud.plate(sw / 2 - pw / 2, top, pw, ph, { strip = tone or "gold" })
    hud.text_mid(title, sw / 2, top + hud.S.s2 + titleH / 2, "heading", tone or "gold", 255, "center")
    if subH > 0 then
        hud.text_mid(sub, sw / 2, top + hud.S.s2 * 2 + titleH + subH / 2, "body",
            subTone or "warn", 255, "center")
    end
    if hintW > 0 then
        hud.hint_row(hints, sw / 2 - hintW / 2, top + ph + hud.S.s2, 255)
    end
    return top + tall
end

function hud.corner_hint_y()
    local _, sh = hud.screen()
    local size = hud.HINT_SIZE
    local y = sh - hud.MARGIN - size
    if OF.util.asks(OF.markers, "radar_shown") and OF.markers.radar_shown() then
        y = math.min(y, sh - 16 - 150 - hud.S.s2 - size)
    end
    return y
end

hud.HINT_SIZE = 22
function hud.hints(list, opts)
    if type(list) ~= "table" or #list == 0 or hud.blocked() then return 0 end
    opts = opts or {}
    local sw, sh = hud.screen()
    local size = hud.HINT_SIZE
    local set, fade, prev = hud.glyph_set()
    local function row(useSet, alpha, y)
        local x = sw - hud.MARGIN
        for i = #list, 1, -1 do
            local item = list[i]

            if not hud.chip_says(item[1], item[2], useSet) then
                local lw = hud.ink_width(item[2], "caption")
                x = x - lw
                hud.text_mid(item[2], x, y + size / 2, "caption", "ink2", alpha, "left")
                x = x - hud.S.s2
            end
            local gw = hud.glyph_width(item[1], size, useSet)
            hud.glyph(item[1], x - gw, y, size, alpha, useSet)
            x = x - gw - hud.S.s6
        end
        return sw - hud.MARGIN - x
    end
    local y = opts.y or (sh - hud.MARGIN - size)
    local width = row(set, 255 * fade, y)
    if fade < 1 and prev ~= nil and prev ~= set then row(prev, 255 * (1 - fade), y) end
    return width
end

hud.SOUND = {
    tick      = "SOUND_GENERAL_COIN",
    go        = "SOUND_MENU_STAR_SOUND_LETS_A_GO",
    score     = "SOUND_MENU_COLLECT_RED_COIN",
    objective = "SOUND_GENERAL2_RIGHT_ANSWER",
    kill      = "SOUND_OBJ_DEFAULT_DEATH",
    body      = "SOUND_MENU_CAMERA_BUZZ",
    flag      = "SOUND_MENU_COLLECT_SECRET",
    dropped   = "SOUND_MENU_CAMERA_ZOOM_OUT",
    captured  = "SOUND_MENU_STAR_SOUND",
    pass      = "SOUND_GENERAL_BOING1",
    boom      = "SOUND_GENERAL2_BOBOMB_EXPLOSION",
    warn      = "SOUND_GENERAL2_SWITCH_TICK_FAST",
    alarm     = "SOUND_GENERAL_ENEMY_ALERT1",
    overtime  = "SOUND_GENERAL_BIG_CLOCK",
    win       = "SOUND_GENERAL2_STAR_APPEARS",

    loss      = "SOUND_MENU_HAND_DISAPPEAR",
    draw      = "SOUND_MENU_CAMERA_ZOOM_OUT",
    mvp       = "SOUND_GENERAL2_1UP_APPEAR",
    move      = "SOUND_MENU_CHANGE_SELECT",
    vote      = "SOUND_MENU_CLICK_FILE_SELECT",
    roulette  = "SOUND_MENU_MESSAGE_APPEAR",
    reveal    = "SOUND_MENU_STAR_SOUND",
    ready     = "SOUND_GENERAL_COIN",
    allready  = "SOUND_GENERAL2_RIGHT_ANSWER",
    split     = "SOUND_MENU_MESSAGE_NEXT_PAGE",
    gold      = "SOUND_MENU_COLLECT_RED_COIN",
    pb        = "SOUND_GENERAL2_STAR_APPEARS",

    them      = "SOUND_MENU_CAMERA_ZOOM_OUT",
    lead      = "SOUND_GENERAL2_RIGHT_ANSWER",
    matchpoint = "SOUND_GENERAL_SHORT_STAR",
    sideswitch = "SOUND_MENU_CAMERA_TURN",
    out       = "SOUND_MENU_CAMERA_BUZZ",
    last      = "SOUND_MENU_CAMERA_ZOOM_IN",
    role      = "SOUND_MENU_HAND_APPEAR",
    stinger   = "SOUND_MENU_STAR_SOUND",
    medal     = "SOUND_GENERAL_COLLECT_1UP",
    notice    = "SOUND_MENU_MESSAGE_APPEAR",
}

function hud.sound_of(event)
    local name = hud.SOUND[event]
    if name == nil then return nil end
    return _G[name]
end

hud.SOUND_RATE = { same = 3, tier = 10, low = { below = 50, gap = 15 } }

function hud.cue_allowed(sound, tier, now)
    if tier == nil then return true end
    now = now or hud.now()
    local log = hud.state.cueLog
    if log == nil then
        log = { bySound = {}, tier = nil, tierAt = -1000, lowAt = -1000 }
        hud.state.cueLog = log
    end
    local R = hud.SOUND_RATE
    local last = log.bySound[sound]
    if last ~= nil and now - last >= 0 and now - last < R.same then return false end
    if log.tier ~= nil and tier < log.tier and now - log.tierAt >= 0 and now - log.tierAt < R.tier then
        return false
    end
    if tier < R.low.below and now - log.lowAt >= 0 and now - log.lowAt < R.low.gap then return false end
    log.bySound[sound] = now
    if log.tier == nil or tier >= log.tier or now - log.tierAt >= R.tier then
        log.tier, log.tierAt = tier, now
    end
    if tier < R.low.below then log.lowAt = now end
    return true
end

function hud.cue(event, tier, now)
    local sound = hud.sound_of(event)
    local sounds = OF.sounds
    if sound == nil or sounds == nil or type(sounds.play) ~= "function" then return false end
    if not hud.cue_allowed(sound, tier, now) then return false end
    sounds.play(sound)
    return true
end

function hud.cue_once(key, event)
    hud.state.cued = hud.state.cued or {}
    if hud.state.cued[key] then return false end
    hud.state.cued[key] = true
    return hud.cue(event)
end

local CHIP_W, CHIP_H = 120, 40
local SIDE_W = 116
local SIDE_GAP = 4

local SIDE_INSET = 14
hud.CHIP_W, hud.CHIP_H, hud.SIDE_W, hud.SIDE_GAP, hud.SIDE_INSET = CHIP_W, CHIP_H, SIDE_W,
    SIDE_GAP, SIDE_INSET

function hud.side_shape(side)
    if type(side) ~= "table" then return nil end
    if side.key ~= nil and hud.TEAM_GLYPH[side.key] ~= nil then return hud.TEAM_GLYPH[side.key] end
    if side.shape == "diamond" or side.shape == nil then return hud.TEAM_GLYPH.red end
    return side.shape
end

local function pips(cx, y, score, target, colour, shape)
    if target == nil or target <= 0 then return end

    if target > 12 then
        local w = SIDE_W - SIDE_INSET * 2
        hud.rect(cx - w / 2, y - 2, w, 4, hud.C.plate, 200)
        hud.rect(cx - w / 2, y - 2, w * clamp01(score / target), 4, colour, 255)
        return
    end
    local gap = 10
    local left = cx - (target - 1) * gap / 2
    for i = 1, target do
        local px = left + (i - 1) * gap
        local on = i <= score
        local tone = on and colour or hud.C.mute
        local a = on and 255 or 110
        if shape == "square" then hud.rect(px - 3, y - 3, 6, 6, tone, a)
        else hud.draw_glyph("circle", px, y, 6, tone, a) end
    end
end

local function side_baseline(y)
    local top, base = hud.cap("heading", 1, "0")
    return y + CHIP_H / 2 + (base - top) / 2
end
hud.side_baseline = side_baseline

local function side_plate(x, y, side, flashAge, mirrored, match, sideW)
    sideW = sideW or SIDE_W
    local colour = side.colour or hud.C.ink
    local lit = flashAge ~= nil and flashAge < hud.MOTION.slow
    hud.plate(x, y, sideW, CHIP_H, { strip = colour, right = mirrored, lit = lit,
        tint = colour })
    local pop = 1
    if flashAge ~= nil and flashAge < hud.MOTION.base then
        pop = 1.35 - 0.35 * hud.ease.out_back(flashAge / hud.MOTION.base)
    end
    local base = side_baseline(y)
    local outer = mirrored and (x + sideW - SIDE_INSET) or (x + SIDE_INSET)
    local inner = mirrored and (x + SIDE_INSET) or (x + sideW - SIDE_INSET)
    local _, digitBase = hud.cap("heading", pop, "0")
    hud.digits(tostring(side.score or 0), inner, base - digitBase, "heading",
        lit and hud.lighten(colour, 0.5) or hud.C.ink, 255, mirrored and "left" or "right", pop)
    if side.label ~= nil then
        hud.text_base(side.label, outer, base, "caption", colour, 230,
            mirrored and "right" or "left")
    end
    if side.pips ~= nil then

        local p = side.pips
        pips(x + sideW / 2, y + CHIP_H + 8, p.alive or p[1] or 0, p.total or p[2] or 0, colour,
            hud.side_shape(side))
    else
        pips(x + sideW / 2, y + CHIP_H + 8, side.score or 0, side.target, colour, hud.side_shape(side))
    end

    if type(side.icon) == "table" and type(hud.icon) == "function" then
        local ic = side.icon
        local lw = side.label ~= nil and hud.ink_width(side.label, "caption") or 0
        local dw = hud.measure(tostring(side.score or 0), "heading", pop)
        local wordEdge = mirrored and (outer - lw) or (outer + lw)
        local scoreEdge = mirrored and (inner + dw) or (inner - dw)

        local size = OF.util.clamp(math.abs(scoreEdge - wordEdge) - 6, 10, 18)
        local ix = (wordEdge + scoreEdge) / 2
        local least = size / 2 + 3
        if mirrored then ix = math.min(ix, wordEdge - least) else ix = math.max(ix, wordEdge + least) end
        local icons = hud.state.sideIcons or {}
        hud.state.sideIcons = icons
        local one = icons[mirrored and 2 or 1] or {}
        icons[mirrored and 2 or 1] = one
        one.cx, one.size, one.word, one.score = ix, size, wordEdge, scoreEdge
        hud.icon(ic.icon or ic.name or "flag", ix, y + CHIP_H / 2, size, ic.tone or colour,
            ic.dim and 120 or 255, ic)
    end

    if side.match or match then
        local breath = 0.5 + 0.5 * math.sin((hud.now() or 0) * 2 * math.pi / 60)
        local a = 90 + 120 * breath
        hud.rect(x - 2, y - 2, sideW + 4, 2, colour, a)
        hud.rect(x - 2, y + CHIP_H, sideW + 4, 2, colour, a)
        hud.rect(x - 2, y, 2, CHIP_H, colour, a)
        hud.rect(x + sideW, y, 2, CHIP_H, colour, a)
    end
end

hud.SIDE_ROOM = 10
function hud.side_width(st)
    if type(st) ~= "table" or type(st.left) ~= "table" or type(st.right) ~= "table" then
        return SIDE_W
    end
    local need = 0
    for _, side in ipairs({ st.left, st.right }) do
        local lw = side.label ~= nil and hud.ink_width(side.label, "caption") or 0
        local dw = hud.measure(tostring(side.score or 0), "heading")
        local iw = type(side.icon) == "table" and 24 or 0
        need = math.max(need, SIDE_INSET * 2 + lw + hud.SIDE_ROOM + iw + dw)
    end
    return math.max(SIDE_W, math.ceil(need))
end

function hud.cluster_layout(st)
    local sw = hud.screen()
    local cx = sw / 2
    local chipW = CHIP_W
    if st ~= nil and st.overtime then chipW = math.max(CHIP_W, hud.ink_width("OVERTIME", "body") + 32) end
    if st ~= nil and st.clockText ~= nil then
        chipW = math.max(CHIP_W, hud.clock_text_width(st.clockText) + 32)
    end
    local chipX = cx - chipW / 2
    local ffaW = SIDE_W + 24
    local sideW = hud.side_width(st)
    return {
        cx = cx, chipX = chipX, chipW = chipW,
        leftX = chipX - SIDE_GAP - sideW, rightX = chipX + chipW + SIDE_GAP, sideW = sideW,
        ffaLeftX = chipX - SIDE_GAP - ffaW, ffaRightX = chipX + chipW + SIDE_GAP, ffaW = ffaW,
    }
end

hud.ROUND_TOP_H = 136
function hud.round_zones()
    local sw, sh = hud.screen()
    local L = hud.cluster_layout()
    local left = math.min(L.leftX, L.ffaLeftX) - hud.S.s4
    local right = math.max(L.rightX + L.sideW, L.ffaRightX + L.ffaW) + hud.S.s4
    local legendW = 460
    return {
        { x = left, y = 0, w = right - left, h = hud.MARGIN + hud.ROUND_TOP_H, name = "top" },
        { x = sw - hud.MARGIN - legendW, y = sh - hud.MARGIN - hud.HINT_SIZE - 16,
          w = legendW + hud.MARGIN, h = hud.HINT_SIZE + 16 + hud.MARGIN, name = "legend" },
    }
end

hud.BIG_COUNT = { share = 0.8, alpha = 200, enter = 4, hold = 10, exit = 6 }
function hud.big_count(n, into)
    local B = hud.BIG_COUNT
    local f = clamp01(into or 0) * 30
    local enter = B.enter
    local exit = B.exit
    if f >= enter + B.hold + exit then return false end
    local a = B.alpha * hud.envelope(f, enter, B.hold, exit)
    if a <= 0 then return false end
    local land = hud.ease.out_back(f / math.max(1, enter))
    local mult = B.share * (1 + 0.25 * (1 - land))
    local cx, cy = hud.countdown_centre()
    hud.text_centred(tostring(n), cx, cy, "display", "warn", a, mult)
    hud.state.bigCount = { n = n, alpha = a }
    return true
end

function hud.clock_text_width(text)
    if string.find(text, "%a") then return hud.ink_width(text, "body") end
    return hud.digits_width(text, "heading")
end

function hud.top_cluster(st, now)
    if st == nil or hud.blocked() then return 0 end
    now = now or hud.now()
    local L = hud.cluster_layout(st)
    local cx = L.cx
    local y = st.top or hud.MARGIN
    local bottom = y + CHIP_H
    local chipW, chipX = L.chipW, L.chipX
    local mid = y + CHIP_H / 2

    if st.clockText ~= nil then

        hud.plate(chipX, y, chipW, CHIP_H, { tint = st.clockTint })
        if string.find(st.clockText, "%a") then
            hud.text_mid(st.clockText, cx, mid, "body", st.clockTone or hud.C.ink, 255, "center")
        else
            hud.digits_mid(st.clockText, cx, mid, "heading", st.clockTone or hud.C.ink, 255, "center")
        end
    elseif st.overtime then
        local breath = hud.pulse(now, 30)
        hud.plate(chipX, y, chipW, CHIP_H, { tint = hud.C.warn, lit = breath > 0.5 })
        hud.text_mid("OVERTIME", cx, mid, "body", hud.lighten(hud.C.warn, 0.3 * breath), 255,
            "center")
    elseif st.timer ~= nil then
        local secs = math.max(0, st.timer)
        local late = secs <= 10 and not st.countUp
        hud.plate(chipX, y, chipW, CHIP_H, { tint = late and hud.C.warn or nil })

        local mult = 1
        if late and secs > 0 then
            local into = 1 - (secs - math.floor(secs))
            mult = 1.18 - 0.18 * hud.ease.out_cubic(into / 0.25)
        end
        hud.digits_mid(hud.clock(math.ceil(secs)), cx, mid, "heading",
            late and hud.C.warn or hud.C.ink, 255, "center", mult)

        if late and secs > 0 and secs <= 5 and not st.noBigCount then
            hud.big_count(math.ceil(secs), 1 - (secs - math.floor(secs)))
        end
    else
        hud.plate(chipX, y, chipW, CHIP_H)
    end

    if st.left ~= nil and st.right ~= nil then

        local m = st.match
        side_plate(L.leftX, y, st.left, st.leftFlash, false,
            m ~= nil and (m == "left" or m == st.left.key), L.sideW)
        side_plate(L.rightX, y, st.right, st.rightFlash, true,
            m ~= nil and (m == "right" or m == st.right.key), L.sideW)
        if (st.left.target or 0) > 0 or (st.right.target or 0) > 0 then bottom = bottom + 14 end
    elseif st.you ~= nil then
        local ffaW = L.ffaW
        local labelBase = y + 15
        local scoreBase = y + CHIP_H - 7
        local function ffa(x, entry, colour, mirrored)
            hud.plate(x, y, ffaW, CHIP_H, { strip = colour, right = mirrored })
            local outer = mirrored and (x + ffaW - SIDE_INSET) or (x + SIDE_INSET)
            local align = mirrored and "right" or "left"
            local lives = (entry.livesMax or 0) > 0 and (entry.livesMax * 9 + 6) or 0
            local _, cb = hud.cap("caption")
            hud.name(entry.label or "", outer, labelBase - cb, "caption", colour, 230, align,
                ffaW - SIDE_INSET * 2, { key = mirrored and "ffa-right" or "ffa-left" })
            hud.digits(tostring(entry.score or 0), outer, scoreBase - select(2, hud.cap("body", 1, "0")),
                "body", hud.C.ink, 255, align)

            if lives > 0 then
                local lx = mirrored and (x + SIDE_INSET) or (x + ffaW - SIDE_INSET - entry.livesMax * 9)
                hud.stocks(lx, scoreBase - 8, entry.lives or 0, entry.livesMax, colour)
            end
        end

        local d = 0
        if st.leadSwap ~= nil and st.leadSwap >= 0 and st.leadSwap < hud.MOTION.swap
            and st.leader ~= nil then
            d = (L.ffaRightX - L.ffaLeftX) * (1 - hud.ease.in_out_sine(st.leadSwap / hud.MOTION.swap))
        end
        hud.state.leadSwapShift = d
        ffa(L.ffaLeftX + d, st.you, "gold", false)
        if st.leader ~= nil then ffa(L.ffaRightX - d, st.leader, hud.C.ink2, true) end

        if (st.target or 0) > 0 then
            local barW = chipW + 2 * (ffaW + SIDE_GAP)
            local bx = cx - barW / 2
            local by = y + CHIP_H + 4
            hud.rect(bx, by, barW, 3, hud.C.plate, 180)
            local lead = st.leader ~= nil and st.leader.score or 0
            hud.rect(bx, by, barW * clamp01(lead / st.target), 3, hud.C.ink2, 200)
            hud.rect(bx, by, barW * clamp01((st.you.score or 0) / st.target), 3, "gold", 255)
            bottom = bottom + 8
        end
    end

    local left, right = chipX, chipX + chipW
    if st.left ~= nil and st.right ~= nil then
        left, right = L.leftX, L.rightX + L.sideW
    elseif st.you ~= nil then
        left, right = L.ffaLeftX, L.ffaRightX + L.ffaW
    end
    local drawn = hud.state.clusterDrawn or {}
    hud.state.clusterDrawn = drawn
    drawn.x, drawn.y, drawn.w, drawn.h, drawn.at = left, y, right - left, bottom - y, now
    return bottom
end

hud.CLUSTER_MARGIN = 12
function hud.cluster_clear(x, halfW)
    local now = hud.now()
    local function fresh(t) return t ~= nil and type(t.at) == "number" and now - t.at <= 1 and now >= t.at end
    local reach = hud.MARKER.cap + (halfW or 0)
    local bottom = nil
    local c, slot = hud.state.clusterDrawn, hud.state.lineSlot
    if fresh(c) and x >= c.x - reach and x <= c.x + c.w + reach then bottom = c.y + c.h end

    if fresh(slot) and slot.w ~= nil and slot.w > 0 and x >= slot.x - reach
        and x <= slot.x + slot.w + reach then
        bottom = math.max(bottom or 0, slot.y + slot.h)
    end
    if bottom == nil then return nil end
    return bottom + hud.MARKER.cap + hud.CLUSTER_MARGIN
end

function hud.feed_push(e, now)
    if type(e) ~= "table" then return false end

    if type(e.left) == "string" then e.left = hud.say_buttons(e.left) end

    e.born = now or hud.now()

    if e.right == nil then
        for _, old in ipairs(hud.state.feed) do
            if old.right == nil and old.left == e.left and old.icon == e.icon
                and e.born - (old.born or 0) >= 0 and e.born - (old.firstBorn or old.born or 0) <= hud.FEED_MERGE then
                old.count = (old.count or 1) + 1
                old.firstBorn = old.firstBorn or old.born
                old.born = e.born
                return true
            end
        end
    end
    table.insert(hud.state.feed, 1, e)
    while #hud.state.feed > hud.FEED_LINES + 2 do table.remove(hud.state.feed) end
    return true
end

local function feed_icon(kind, x, y, size, alpha)
    local cy = y + size / 2
    local cx = x + size / 2
    if kind == "kill" then
        hud.arrow_glyph("right", cx, cy, size * 0.64, hud.C.ink2, alpha, "chevron")
    elseif kind == "flag" or kind == "capture" then
        local tone = kind == "capture" and hud.C.good or hud.C.warn
        hud.rect(cx - size * 0.3, y + 3, 2, size - 6, hud.C.ink2, alpha)
        hud.rect(cx - size * 0.3 + 2, y + 3, size * 0.5, size * 0.32, tone, alpha)
    elseif kind == "bomb" or kind == "pass" then
        hud.diamond(cx, cy + 1, size * 0.5, hud.C.warn, alpha)
        hud.line(cx + 2, cy - size * 0.3, cx + 5, cy - size * 0.45, 2, hud.C.ink, alpha)
    else
        hud.rect(cx - 1, y + 4, 2, size - 8, hud.C.good, alpha)
        hud.rect(cx - size / 2 + 4, cy - 1, size - 8, 2, hud.C.good, alpha)
    end
    return size
end

hud.FEED_NAME_ROOM = 150

hud.FEED_MERGE = 120

hud.FEED_SHARE = 0.36

function hud.feed_draw(now, top)
    if hud.blocked() then return 0 end
    now = now or hud.now()
    local sw = hud.screen()
    local y = top or hud.MARGIN
    local rowH = 30
    local plateH = rowH - 4
    local pad = 10
    local gap = 6
    local life = hud.MOTION.fast + hud.MOTION.feed + hud.MOTION.base
    local kept, drawn = {}, 0
    for i, e in ipairs(hud.state.feed) do
        local age = now - (e.born or now)
        if age < life and drawn < hud.FEED_LINES then
            table.insert(kept, e)
            drawn = drawn + 1
            local k = hud.envelope(age, hud.MOTION.fast, hud.MOTION.feed, hud.MOTION.base)
            local slide = (1 - hud.ease.out_cubic(age / hud.MOTION.fast)) * 60

            local face = "row"
            local room = e.right ~= nil and hud.FEED_NAME_ROOM or math.floor(sw * hud.FEED_SHARE)
            local leftText = e.left
            if leftText ~= nil and (e.count or 1) > 1 then leftText = leftText .. " x" .. e.count end
            local lw = leftText ~= nil and math.min(room, hud.ink_width(leftText, face)) or 0
            local rw = e.right ~= nil and math.min(room, hud.ink_width(e.right, face)) or 0
            local iconW = 18
            local w = pad + iconW + (lw > 0 and gap or 0) + lw + (rw > 0 and gap or 0) + rw + pad
            local x = sw - hud.MARGIN - w + slide
            local strip = e.mine and "gold" or (e.right == nil and e.leftColour or nil)
            hud.plate(x, y, w, plateH, { alpha = k, lit = e.mine, strip = strip })
            local mid = y + plateH / 2
            local tx = x + pad
            feed_icon(e.icon, tx, mid - iconW / 2, iconW, 255 * k)
            tx = tx + iconW + gap
            if leftText ~= nil then
                local leftTone = e.right ~= nil and (e.leftColour or "ink") or "ink"
                hud.name_mid(leftText, tx, mid, face, leftTone, 255 * k, "left",
                    room, { key = "feed-l" .. tostring(e.born) .. i })
                tx = tx + lw + gap
            end
            if e.right ~= nil then
                hud.name_mid(e.right, tx, mid, face, e.rightColour or "ink", 255 * k, "left",
                    room, { key = "feed-r" .. tostring(e.born) .. i })
            end
            y = y + rowH
        elseif age < life then
            table.insert(kept, e)
        end
    end
    hud.state.feed = kept
    return drawn
end

function hud.callout_draw(now)
    local c = hud.state.callout
    if c == nil or hud.blocked() then return false end
    now = now or hud.now()
    local age = now - c.born
    if age > hud.CALLOUT_FRAMES + hud.MOTION.base then
        hud.state.callout = nil
        return false
    end
    local sw, sh = hud.screen()
    local k = hud.envelope(age, hud.MOTION.fast, hud.CALLOUT_FRAMES, hud.MOTION.base)
    local mult = 0.7 + 0.3 * hud.ease.out_back(age / hud.MOTION.fast)
    hud.text_centred(c.text, sw / 2, sh * 0.70, "title", c.tone, 255 * k, mult)
    return true
end

function hud.band_rhythm(titleToken, titleMult, subToken, hasSub, pad, gap)
    local _, _, th = hud.cap(titleToken, titleMult, "A")
    local _, _, sh = hud.cap(subToken, 1, "A")
    local h = pad + th + (hasSub and (gap + sh) or 0) + pad
    local titleBase = pad + th
    local subBase = titleBase + gap + sh
    return h, titleBase, subBase
end

function hud.countdown_centre()
    local sw, sh = hud.screen()
    return sw / 2, sh * 0.42
end
hud.COUNT_RING = 78
hud.COUNT_FLOOR = 90

function hud.countdown(n, frac)
    if hud.blocked() then return false end
    local cx, cy = hud.countdown_centre()
    return hud.countdown_at(cx, cy, n, frac, hud.COUNT_RING, 1)
end

function hud.countdown_at(cx, cy, n, frac, radius, size)
    frac = clamp01(frac or 0)
    size = size or 1
    local land = hud.ease.out_back(frac / 0.2)
    local mult = (1.6 - 0.6 * land) * size

    local fromMult = nil
    if frac > 0 then
        fromMult = (1.6 - 0.6 * hud.ease.out_back(math.max(0, frac - 1 / 30) / 0.2)) * size
    end

    local alpha = hud.COUNT_FLOOR
        + (255 - hud.COUNT_FLOOR) * (1 - hud.ease.in_cubic(hud.progress(frac, 0.73, 0.27)))

    local tick = math.max(4, 7 * math.min(1, radius / 78))
    for i = 0, 11 do
        local a = -math.pi / 2 + i * math.pi / 6
        local lit = (i / 12) >= frac
        hud.diamond(cx + math.cos(a) * radius, cy + math.sin(a) * radius,
            lit and tick or tick * 0.7, lit and "gold" or hud.C.mute, alpha * (lit and 1 or 0.5))
    end
    hud.text_centred(tostring(n), cx, cy, "display", "ink", alpha, mult, fromMult)
    return true
end

function hud.go(age)
    if age == nil or age < 0 or age > 24 or hud.blocked() then return false end
    local cx, cy = hud.countdown_centre()
    local mult = 1.3 - 0.3 * hud.ease.out_quint(age / hud.MOTION.fast)
    local fromMult = age > 0 and (1.3 - 0.3 * hud.ease.out_quint((age - 1) / hud.MOTION.fast)) or nil
    local alpha = 255 * (1 - hud.ease.in_cubic(hud.progress(age, 14, 10)))
    hud.text_centred("GO!", cx, cy, "display", "good", alpha, mult, fromMult)
    return true
end

hud.RESULT = {
    win  = { word = "VICTORY", tone = "gold" },
    loss = { word = "DEFEAT",  tone = "bad" },
    draw = { word = "DRAW",    tone = "info" },
}
hud.RESULT_Y = 0.40

function hud.result_band(sub)
    local _, sh = hud.screen()
    local hasSub = sub ~= nil and sub ~= ""
    local h, titleBase, subBase = hud.band_rhythm("display", 1, "body", hasSub, 22, 16)
    local cy = sh * hud.RESULT_Y
    return cy - h / 2, h, titleBase, subBase
end

function hud.result(kind, sub, age, word)
    if hud.blocked() then return false end
    local look = hud.RESULT[kind] or hud.RESULT.draw
    word = word or look.word
    age = age or 0

    hud.state.result = { kind = kind, word = word, sub = sub }
    local sw = hud.screen()
    local top, bandH, titleBase, subBase = hud.result_band(sub)
    local open = hud.ease.out_cubic(age / hud.MOTION.slow)

    local openH = bandH * open
    local drawTop = top + (bandH - openH) / 2
    hud.rect(0, drawTop, sw, openH, hud.darken(look.tone, 0.78), 220)
    hud.rect(0, drawTop, sw, 2, look.tone, 255)
    hud.rect(0, drawTop + openH - 2, sw, 2, look.tone, 255)

    local settle = hud.ease.out_quint(hud.progress(age, 2, hud.MOTION.slow))
    local track = 26 - 20 * settle
    local alpha = 255 * hud.ease.out_cubic(hud.progress(age, 2, hud.MOTION.base))
    local util = OF.util
    local ascii = util == nil or type(util.hud_face) ~= "function" or util.hud_face(word) ~= nil
    if ascii and #word <= 14 then
        local widths, total = {}, 0
        for i = 1, #word do
            widths[i] = hud.ink_width(string.sub(word, i, i), "display")
            if string.sub(word, i, i) == " " then widths[i] = hud.measure(" ", "display") end
            total = total + widths[i] + (i < #word and track or 0)
        end
        local x = sw / 2 - total / 2
        for i = 1, #word do
            hud.text_base(string.sub(word, i, i), x, top + titleBase, "display", look.tone, alpha, "left")
            x = x + widths[i] + track
        end
    else
        hud.name(word, sw / 2, top + titleBase - select(2, hud.cap("display", 1, "A")), "display",
            look.tone, alpha, "center", sw - hud.MARGIN * 4, { key = "result-word" })
    end
    if sub ~= nil and sub ~= "" then
        local sk = hud.ease.out_cubic(hud.progress(age, hud.MOTION.base, hud.MOTION.base))
        local _, sb = hud.cap("body", 1, plain_of(sub))
        hud.name(sub, sw / 2, top + subBase - sb, "body", "ink2", 255 * sk, "center",
            sw - hud.MARGIN * 4, { key = "result-sub" })
    end
    return true
end

hud.MVP_W, hud.MVP_H = 400, 96

function hud.mvp_layout()
    local sw, sh = hud.screen()
    local w, h = hud.MVP_W, hud.MVP_H
    local x = sw / 2 - w / 2
    local _, _, capCaption = hud.cap("caption", 1, "A")
    local _, _, capTitle = hud.cap("title", 1, "A")
    local _, _, capBody = hud.cap("body", 1, "A")
    local gapA, gapB = 9, 11
    local block = capCaption + gapA + capTitle + gapB + capBody
    local pad = (h - block) / 2
    local badge = h - 28
    return {
        x = x, w = w, h = h, yAt = sh * 0.62, badge = badge, badgeX = x + 18,
        textX = x + 18 + badge + 18,
        labelBase = pad + capCaption,
        nameBase = pad + capCaption + gapA + capTitle,
        statBase = pad + block,
    }
end

function hud.mvp(card, age, opts)
    if card == nil or hud.blocked() then return false end
    age = age or 0
    local L = hud.mvp_layout()
    local k = hud.ease.out_cubic(age / hud.MOTION.slow)

    local yAt = L.yAt
    if opts ~= nil and opts.y ~= nil then
        local _, sh = hud.screen()
        yAt = sh * opts.y
    end
    local y = yAt + (1 - k) * 24
    local x, w, h = L.x, L.w, L.h
    hud.plate(x, y, w, h, { alpha = k, lit = true, strip = "gold" })

    local bs = L.badge
    local bx, by = L.badgeX, y + (h - bs) / 2
    local ar, ag, ab = hud.colour("gold")
    local deep = { ar * 0.82, ag * 0.82, ab * 0.82 }
    hud.rect(bx + 2, by, bs - 4, bs, deep, 255 * k)
    hud.rect(bx, by + 2, 2, bs - 4, deep, 255 * k)
    hud.rect(bx + bs - 2, by + 2, 2, bs - 4, deep, 255 * k)
    hud.rect(bx + 2, by, bs - 4, 2, hud.lighten("gold", 0.45), 255 * k)
    hud.rect(bx + 2, by + bs - 3, bs - 4, 3, hud.darken("gold", 0.45), 255 * k)
    hud.text_in("MVP", bx, by, bs, bs - 1, "body", "ink", 255 * k)
    local room = x + w - 18 - L.textX
    hud.text_base(card.label or "Most valuable player", L.textX, y + L.labelBase, "caption", "gold",
        230 * k)
    local _, nb = hud.cap("title", 1, plain_of(card.name or ""))
    hud.name(card.name or "", L.textX, y + L.nameBase - nb, "title", "ink", 255 * k, "left", room,
        { key = "mvp" })
    if card.stat ~= nil then
        hud.text_base(card.stat, L.textX, y + L.statBase, "body", "ink2", 255 * k)
    end
    return true
end

local markScreen = { x = 0, y = 0, z = 0 }
local markWorld = { x = 0, y = 0, z = 0 }

local lastMark = { x = nil, y = nil, size = nil, state = nil }

function hud.last_marker()
    return lastMark.x, lastMark.y, lastMark.size
end

local function project(x, y, z)
    markWorld.x, markWorld.y, markWorld.z = x, y, z
    local util = OF.util
    if util == nil or util.world_screen == nil then return nil end
    if not util.world_screen(markWorld, markScreen) then return nil end
    return markScreen.x, markScreen.y
end

function hud.camera_direction(pos)
    local lk = gLakituState
    if lk == nil or lk.pos == nil or lk.focus == nil or pos == nil then return nil end
    local fx, fy, fz = lk.focus.x - lk.pos.x, lk.focus.y - lk.pos.y, lk.focus.z - lk.pos.z
    local len = math.sqrt(fx * fx + fy * fy + fz * fz)
    if len < 0.001 then return nil end
    fx, fy, fz = fx / len, fy / len, fz / len

    local rx, rz = -fz, fx
    local rl = math.sqrt(rx * rx + rz * rz)
    if rl < 0.001 then rx, rz, rl = 1, 0, 1 end
    rx, rz = rx / rl, rz / rl
    local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy
    local dx, dy, dz = pos.x - lk.pos.x, (pos.y or 0) - lk.pos.y, pos.z - lk.pos.z
    local side = dx * rx + dz * rz
    local up = dx * ux + dy * uy + dz * uz
    local ahead = dx * fx + dy * fy + dz * fz
    local util = OF.util
    if util ~= nil and type(util.mirror_x) == "function" then
        local a, b = util.mirror_x(100), util.mirror_x(200)
        if type(a) == "number" and type(b) == "number" and b < a then side = -side end
    end
    local down = -up
    if ahead < 0 then down = down - ahead end
    return side, down, ahead
end

hud.MARKER = {
    share = 0.026, least = 14, most = 30, cap = 22, rim = 4,
    ax = 0.86, ay = 0.80, wide = 16 / 9,
    enter = 0.92, leave = 1.0, slide = 0.35,
    chars = 12,
}
hud.MARKER_SCALE = { near = 15, far = 60, min = 0.8, max = 1.0 }

function hud.marker_size()
    local _, sh = hud.screen()
    local M = hud.MARKER
    local base = math.max(M.least, math.min(M.most, (sh or 720) * M.share))
    return math.min(base, M.cap - M.rim)
end

function hud.marker_scale(dist)
    local s = hud.MARKER_SCALE
    if dist == nil then return s.max end
    local t = clamp01((dist - s.near) / (s.far - s.near))
    t = t * t * (3 - 2 * t)
    return s.max - (s.max - s.min) * t
end

function hud.marker_ellipse()
    local sw, sh = hud.screen()
    local M = hud.MARKER
    local halfW = math.min(sw / 2, sh * M.wide / 2)
    return sw / 2, sh / 2, halfW * M.ax, sh / 2 * M.ay
end

function hud.marker_label(label)
    if type(label) ~= "string" or label == "" then return nil end
    local most = hud.MARKER.chars
    local function cut_at(n)
        if utf8 ~= nil and utf8.offset ~= nil then
            local at = utf8.offset(label, n + 1)
            if at ~= nil then return label:sub(1, at - 1) end
        end
        return label:sub(1, n)
    end
    local n = (utf8 ~= nil and utf8.len ~= nil and utf8.len(label)) or #label
    if n <= most then return label end
    local head = cut_at(most)

    local after = cut_at(most + 1):sub(#head + 1)
    if after == " " then return (head:gsub("%s+$", "")) end
    local lastSpace = head:match("^.*()%s")
    if lastSpace ~= nil and lastSpace > 1 then
        return (head:sub(1, lastSpace - 1):gsub("[%s%-]+$", ""))
    end
    return head
end

hud.state.marks = hud.state.marks or {}

local function wrap_angle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end

function hud.marker_locate(pos, opts)
    if pos == nil then return nil end
    opts = opts or {}
    local cx, cy, ax, ay = hud.marker_ellipse()
    local sx, sy = project(pos.x, (pos.y or 0) + (opts.lift or 0), pos.z)
    local norm = nil
    if sx ~= nil then
        local ex, ey = (sx - cx) / ax, (sy - cy) / ay
        norm = math.sqrt(ex * ex + ey * ey)
    end
    local st = nil
    local now = hud.now()
    if opts.id ~= nil then
        st = hud.state.marks[opts.id]
        if st == nil or now - (st.at or -100) > 2 then
            st = { on = nil, phi = nil }
            hud.state.marks[opts.id] = st
        end
        st.at = now
    end
    local M = hud.MARKER
    local inside
    if norm == nil then
        inside = false
    elseif st == nil or st.on == nil then
        inside = norm <= 1
    elseif st.on then
        inside = norm <= M.leave
    else
        inside = norm <= M.enter
    end
    if inside and sx ~= nil then
        if st ~= nil then st.on, st.phi = true, nil end
        return "on", sx, sy, nil, norm
    end
    local dx, dy
    if sx ~= nil then
        dx, dy = sx - cx, sy - cy
    else
        local side, down = hud.camera_direction(pos)
        dx, dy = side or 0, down or 1
    end
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then dy = 1 end
    local phi = math.atan(dy / ay, dx / ax)
    if st ~= nil then
        if st.phi ~= nil then phi = st.phi + wrap_angle(phi - st.phi) * M.slide end
        st.on, st.phi = false, phi
    end
    local px, py = cx + math.cos(phi) * ax, cy + math.sin(phi) * ay
    local angle = math.atan(py - cy, px - cx)

    local markers = OF.markers
    if markers ~= nil and type(markers.keep_clear) == "function" then
        local sw, sh = hud.screen()
        px, py = markers.keep_clear(px, py, sw, sh)
    end
    return "edge", px, py, angle, norm
end

function hud.marker(pos, glyph, tone, label, opts)
    lastMark.x, lastMark.y, lastMark.size, lastMark.state = nil, nil, nil, nil
    if pos == nil or hud.blocked() then return nil end
    opts = opts or {}

    local state, px, py, angle
    if type(opts.placed) == "table" then
        state, px, py, angle = opts.placed[1], opts.placed[2], opts.placed[3], opts.placed[4]
    else
        state, px, py, angle = hud.marker_locate(pos, opts)
    end
    if state == nil or px == nil then return nil end
    if state == "edge" and angle == nil then angle = 0 end
    local sw, sh = hud.screen()
    local cy = sh / 2
    local alpha = opts.alpha or 255
    if opts.pulse then alpha = alpha * (160 + 95 * hud.pulse(hud.now(), opts.pulsePeriod or 20)) / 255 end
    if alpha <= 1 then return nil end

    local dist = nil
    local m = gMarioStates ~= nil and gMarioStates[0] or nil
    if m ~= nil and m.pos ~= nil then
        local dx, dy, dz = pos.x - m.pos.x, (pos.y or 0) - m.pos.y, pos.z - m.pos.z
        dist = math.sqrt(dx * dx + dy * dy + dz * dz) / 100
    end
    local k = hud.marker_scale(dist) * (opts.scale or 1)
    local base = hud.marker_size()
    if type(opts.size) == "number" then base = math.min(opts.size, base) end
    local size = base * k

    local wordMult = 1

    if type(opts.avoid) == "table" then
        local lift = size + 26
        for _ = 1, 8 do
            local clear = true
            for _, at in ipairs(opts.avoid) do
                if math.abs(at.x - px) < 44 and math.abs(at.y - py) < lift - 1 then clear = false end
            end
            if clear then break end
            py = py - lift
        end
        table.insert(opts.avoid, { x = px, y = py })
    end
    lastMark.x, lastMark.y, lastMark.size, lastMark.state = px, py, size, state

    local word = hud.marker_label(label)
    if type(opts.icon) == "table" then

        local ic = opts.icon
        hud.icon(ic.name or ic.icon or "letter", px, py, size * 1.3, tone, alpha, ic)
        if ic.ring ~= nil and ic.ring > 0 then
            hud.arc(px, py, size * 0.85, ic.ring, 2, ic.ringTone or tone, alpha, 24)
        end
        word = nil
    else

        hud.diamond(px, py, size + hud.MARKER.rim, hud.C.shade, alpha * 0.7)
        hud.diamond(px, py, size, tone, alpha)
        hud.diamond(px, py - size * 0.14, size * 0.42, hud.lighten(tone, 0.45), alpha * 0.55)
    end

    local half = size * 0.71
    local _, capBase, capH = hud.cap("body", wordMult, "A")

    if word ~= nil and OF.util.asks(OF.util, "on_a_board") then
        local ww = math.min(200, hud.measure(word, "body", wordMult) or 0)
        local wy = py - half - 6 - capH
        if state ~= "on" and py <= cy then wy = py + half + 6 end
        local x0, x1, y1 = px - ww / 2, px + ww / 2, wy + capH
        if OF.util.on_a_board(x0, wy, x1, y1) then word = nil end

        local under = hud.cluster_clear(px, ww / 2)
        if under ~= nil and wy < under - hud.MARKER.cap then word = nil end
    end
    if state == "on" then
        if word ~= nil then
            hud.name(word, px, py - half - 5 - capBase,
                "body", tone, alpha, "center", 200, { mult = wordMult, key = "mark-" .. word })
        end
        return "on"
    end
    hud.chevron(px + math.cos(angle) * (half + 4), py + math.sin(angle) * (half + 4),
        angle, 8 * math.max(0.8, k), 3, tone, alpha)

    if word ~= nil then
        local by
        if py > cy then by = py - half - 6 else by = py + half + 6 + capH end
        hud.name(word, px, by - capBase, "body", tone, alpha, "center",
            200, { mult = wordMult, key = "edge-" .. word })
    end
    return "edge"
end

hud.GLYPH = { "circle", "square", "down", "ring", "star", "diamond", "cross" }

local function glyph_shape(name, cx, cy, s, c, alpha)
    local h = s / 2
    if name == "square" then
        hud.rect(cx - h, cy - h, s, s, c, alpha)
    elseif name == "diamond" then
        hud.diamond(cx, cy, s * 0.8, c, alpha)
    elseif name == "circle" or name == "ring" then
        hud.rect(cx - s * 0.4, cy - s * 0.4, s * 0.8, s * 0.8, c, alpha)
        hud.diamond(cx, cy, s * 0.72, c, alpha)
    elseif name == "star" then
        hud.diamond(cx, cy, s * 0.72, c, alpha)
        hud.rect(cx - s * 0.3, cy - s * 0.3, s * 0.6, s * 0.6, c, alpha)
        hud.rect(cx - s * 0.06, cy - h, s * 0.12, s, c, alpha)
        hud.rect(cx - h, cy - s * 0.06, s, s * 0.12, c, alpha)
    elseif name == "down" then

        local rows = math.max(3, math.floor(s * 0.8))
        for i = 0, rows - 1 do
            local w = s * (1 - i / rows)
            hud.rect(cx - w / 2, cy - rows / 2 + i, w, 1, c, alpha)
        end
    elseif name == "cross" then
        hud.line(cx - h, cy - h, cx + h, cy + h, math.max(2, s * 0.22), c, alpha)
        hud.line(cx - h, cy + h, cx + h, cy - h, math.max(2, s * 0.22), c, alpha)
    end
end

function hud.draw_glyph(name, cx, cy, size, tone, alpha)
    alpha = alpha or 255
    size = size or 10
    local known = false
    for _, g in ipairs(hud.GLYPH) do if g == name then known = true end end
    if not known then return false end
    glyph_shape(name, cx, cy, size + 2, hud.C.outline, alpha)
    glyph_shape(name, cx, cy, size, tone, alpha)
    if name == "ring" then
        glyph_shape("circle", cx, cy, size * 0.45, hud.C.outline, alpha)
    end
    return true
end

hud.PROMPT = { y = 0.64, chip = 24, gap = 10, pad = 10, bar = 4 }

hud.state.prompt = hud.state.prompt or nil

function hud.prompt(action, label, progress, opts)
    if action == nil then return nil end
    opts = opts or {}
    local now = hud.now()
    local st = hud.state.prompt
    local same = st ~= nil and st.action == action and st.label == label
        and now - (st.at or -100) <= 2
    hud.state.prompt = {
        action = action, label = label, tone = opts.tone or "target",
        progress = type(progress) == "number" and clamp01(progress) or nil,
        at = now, born = same and st.born or now, alpha = same and st.alpha or 0,
    }
    return hud.state.prompt
end

function hud.prompt_key(action, set)
    local input = OF.input
    if input ~= nil and type(input.prompt_label) == "function" then
        return input.prompt_label(action, set)
    end
    local entry = hud.ACTIONS[action]
    if entry == nil then return tostring(action) end
    if set == "kbm" then return hud.move_words(entry) or entry.key or entry.pad end
    return entry.padText or entry.pad
end

function hud.draw_prompt()
    local st = hud.state.prompt
    if st == nil then return false end
    local now = hud.now()
    local idle = now - (st.at or now)
    local M = hud.MOTION
    if idle > 1 then
        st.alpha = (st.alpha or 0) - 1 / M.base
    else
        st.alpha = math.min(1, (st.alpha or 0) + 1 / M.fast)
    end
    if st.alpha <= 0 then hud.state.prompt = nil return false end
    if hud.blocked() then return false end
    local sw, sh = hud.screen()
    local P = hud.PROMPT
    local a = 255 * hud.ease.out_cubic(st.alpha)
    local label = type(st.label) == "string" and st.label or ""
    local chipW = hud.glyph_width(st.action, P.chip)
    local textW = hud.measure(label, "body")
    local w = chipW + (label ~= "" and (P.gap + textW) or 0) + P.pad * 2
    local h = P.chip + P.pad * 2 + (st.progress ~= nil and (P.bar + 6) or 0)
    local x, y = math.floor(sw / 2 - w / 2), math.floor(sh * P.y)
    hud.plate(x, y, w, h, { alpha = st.alpha })
    hud.glyph(st.action, x + P.pad, y + P.pad, P.chip, a)
    if label ~= "" then
        hud.text_mid(label, x + P.pad + chipW + P.gap, y + P.pad + P.chip / 2, "body", "ink", a, "left")
    end
    if st.progress ~= nil then
        local bx, by, bw = x + P.pad, y + P.pad + P.chip + 6, w - P.pad * 2
        hud.rect(bx, by, bw, P.bar, hud.C.shade, a * 0.8)
        hud.rect(bx, by, bw * st.progress, P.bar, st.tone, a)
    end
    return true
end

function hud.render_prompt()
    if hud.state.prompt == nil then return end
    if OF.util.asks(OF.util, "menu_has_screen") and OF.util.menu_has_screen() then return end
    djui_hud_set_resolution(RESOLUTION_DJUI)
    hud.draw_prompt()
end

hud.METER = { h = 6, pad = 4 }

function hud.meter(x, y, w, fraction, tone, opts)
    opts = opts or {}
    local M = hud.METER
    local h = opts.h or M.h
    local a = opts.alpha or 255
    local k = clamp01(fraction or 0)
    local pad = M.pad
    local top = y
    if opts.label ~= nil or opts.figure ~= nil then
        local _, capBase, capH = hud.cap("caption", 1, "A")
        if opts.label ~= nil then
            hud.text_base(opts.label, x, y + capH, "caption", "ink", a, "left")
        end
        if opts.figure ~= nil then
            hud.text_base(opts.figure, x + w, y + capH, "caption", "ink2", a, "right")
        end
        top = y + capH + 4
        local _ = capBase
    end
    hud.plate(x - pad, top - pad, w + pad * 2, h + pad * 2, { alpha = a / 255 })
    hud.rect(x, top, w, h, hud.C.shade, a * 0.85)
    if k > 0 then
        hud.rect(x, top, w * k, h, tone or "target", a)
        hud.rect(x, top, w * k, 1, hud.lighten(tone or "target", 0.5), a * 0.8)
    end
    return x - pad, y - pad, w + pad * 2, (top - y) + h + pad * 2
end

function hud.outlined(text, x, y, token, c, alpha, align, mult)

    local shape = plain_of(text)
    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
        hud.text(shape, x + o[1], y + o[2], token, hud.C.outline, alpha, align, mult)
    end
    return hud.text(text, x, y, token, c, alpha, align, mult)
end

local function card_frame(w, h, age, tone, minX, below)
    local sw, sh = hud.screen()
    local k = hud.ease.out_cubic((age or 0) / hud.MOTION.base)
    w = math.min(w, sw - hud.MARGIN * 2)
    h = math.min(h, sh - hud.MARGIN * 2)
    local x = sw / 2 - w / 2

    if minX ~= nil and x < minX then x = math.min(minX, sw - hud.MARGIN - w) end

    local lift = 0
    if type(below) == "number" and below > 0 then
        lift = math.min(below / 2, math.max(0, sh / 2 - h / 2 - hud.MARGIN))
    end
    local y = sh / 2 - h / 2 - lift + (1 - k) * 16

    hud.rect(0, 0, sw, sh, hud.C.shade, 110 * k)
    hud.plate(x, y, w, h, { alpha = k })
    if tone ~= nil then hud.rect(x + 2, y, w - 4, 3, tone, 255 * k) end
    return x, y, k, w, h
end
hud.card_frame = card_frame

hud.CARD_PAD = 24
hud.CARD_HEAD = 38
hud.CARD_CAPTION_SHARE = 0.55
local function card_header(x, y, w, title, right, a, titleTone, room)
    local base = y + hud.CARD_HEAD
    local _, tb = hud.cap("heading", 1, tostring(title or ""))

    local rw = 0
    if right ~= nil and right ~= "" then
        local most = (w - hud.CARD_PAD * 2) * hud.CARD_CAPTION_SHARE
        rw = math.min(hud.ink_width(plain_of(right), "caption"), most)
        local _, cb = hud.cap("caption", 1, plain_of(right))
        hud.name(right, x + w - hud.CARD_PAD, base - cb, "caption", "mute", a, "right", most,
            { key = "card-caption" })
    end
    local titleRoom = w - hud.CARD_PAD * 2 - rw - (rw > 0 and hud.S.s4 or 0)
    hud.name(title or "", x + hud.CARD_PAD, base - tb, "heading", titleTone or "ink", a, "left",
        math.min(room or titleRoom, titleRoom), { key = "card-title" })
    return base
end
hud.card_header = card_header

function hud.intro_card(card, age)
    if card == nil or hud.blocked() then return false end

    local w = 620
    local room = w - 64
    local headRoom = card.count ~= nil and (room - hud.INTRO_RING * 2 - 16) or room
    local _, _, capC = hud.cap("caption", 1, "A")
    local _, _, capT = hud.cap("title", 1, "A")
    local _, _, capB = hud.cap("body", 1, "A")
    local lineStep = capB + 9
    local objective = hud.wrap(hud.sentence(hud.say_buttons(card.objective)), "body", headRoom, 3)
    local rules = {}
    for i, line in ipairs(card.rules or {}) do
        if i > 3 then break end
        rules[i] = hud.wrap(hud.sentence(hud.say_buttons(line)), "body", room - 18, 2)
    end
    local rulesH = 0
    for _, lines in ipairs(rules) do rulesH = rulesH + #lines * lineStep + 3 end
    local hintsH = card.hints ~= nil and (hud.HINT_SIZE + 20) or 0
    local h = 26 + capC + 10 + capT + 16 + math.max(1, #objective) * lineStep
        + (rulesH > 0 and (12 + rulesH) or 0) + hintsH + 28
    if card.count ~= nil then h = math.max(h, 32 + hud.INTRO_RING * 2 + 32) end

    local x, y, k
    x, y, k, w, h = card_frame(w, h, age, card.tone or "gold", nil, card.below)
    local a = 255 * k
    local tx = x + 32
    local roundBase = y + 26 + capC
    local nameBase = roundBase + 10 + capT
    local _, cb = hud.cap("caption", 1, "A")
    hud.name(card.round or "NEXT ROUND", tx, roundBase - cb, "caption", "mute", a, "left", headRoom,
        { key = "intro-round" })
    local _, nb = hud.cap("title", 1, tostring(card.name or ""))
    hud.name(card.name or "", tx, nameBase - nb, "title", "ink", a, "left", headRoom, { key = "intro-name" })

    local ok = hud.ease.out_cubic(hud.progress(age or 0, 4, hud.MOTION.base))
    local base = nameBase + 16 + capB
    local _, bb = hud.cap("body", 1, "A")
    for _, line in ipairs(objective) do
        hud.text(line, tx, base - bb, "body", card.tone or "gold", a * ok)
        base = base + lineStep
    end
    base = base - lineStep + 12 + capB
    for i, lines in ipairs(rules) do
        local rk = hud.ease.out_cubic(hud.progress(age or 0, 6 + i * 3, hud.MOTION.base))
        hud.diamond(tx + 4, base - capB / 2, 6, card.tone or "gold", a * rk)
        for _, line in ipairs(lines) do
            hud.text(line, tx + 18, base - bb, "body", "ink2", a * rk)
            base = base + lineStep
        end
        base = base + 3
    end

    if card.hints ~= nil then
        hud.hint_row(card.hints, tx, y + h - 28 - hud.HINT_SIZE, a)
    end
    if card.left ~= nil then
        hud.rect(x + 2, y + h - 6, (w - 4) * clamp01(card.left), 3, card.tone or "gold", 200 * k)
    end

    if card.count ~= nil then
        local r = hud.INTRO_RING
        hud.countdown_at(x + w - 32 - r, y + 32 + r, card.count.n, card.count.frac, r, 0.6)
    end
    hud.state.introAt = hud.now()
    hud.state.intro = { x = x, y = y, w = w, h = h, ring = card.count ~= nil and
        { x = x + w - 32 - hud.INTRO_RING, y = y + 32 + hud.INTRO_RING, r = hud.INTRO_RING } or nil }
    return true
end
hud.INTRO_RING = 40

hud.BOARD_W = 520

hud.PODIUM = { "gold", "silver", "bronze" }
function hud.scoreboard_layout(x, w)
    return {
        place = x + 36, name = x + 52, score = x + w - 24, stat = x + w - 110,
        nameRoom = w - 52 - 130,
    }
end

function hud.scoreboard(rows, opts, age)
    if rows == nil or hud.blocked() then return false end
    opts = opts or {}
    local count = math.min(#rows, 16)
    local x, y, k, w = card_frame(hud.BOARD_W, 84 + count * hud.ROW + 12, age, opts.tone or "gold",
        opts.minX)
    local a = 255 * k
    local L = hud.scoreboard_layout(x, w)
    card_header(x, y, w, opts.title or "", opts.sub or "SCOREBOARD", a)
    local cols = opts.columns or { "SCORE" }
    local colX = { L.score, L.stat }
    local headBase = y + 64
    for i, label in ipairs(cols) do
        if colX[i] ~= nil then hud.text_base(label, colX[i], headBase, "caption", "mute", a, "right") end
    end
    hud.text_base("#", L.place, headBase, "caption", "mute", a, "right")
    hud.text_base("PLAYER", L.name, headBase, "caption", "mute", a)
    local ry = y + 74

    local up = opts.reveal == "up"
    if up then hud.reveal_cues(opts.key or opts.title or "board", count, age or 0) end
    hud.state.revealOrder = up and {} or nil
    for i = 1, count do
        local row = rows[i]
        local rk
        local pop = 1
        if up then
            local at = hud.reveal_delay(i, count)
            rk = hud.ease.out_cubic(hud.progress(age or 0, at, hud.MOTION.reveal.row)) * k
            hud.state.revealOrder[i] = at
            if i == 1 then
                pop = hud.punch((age or 0) - at - hud.MOTION.reveal.row, 1.15, 2, 2, 4)
                local edgeAge = (age or 0) - at - hud.MOTION.reveal.row
                if edgeAge >= 0 and edgeAge < 2 then
                    hud.rect(x + 8, ry - 3, w - 16, 2, "ink", 255)
                    hud.rect(x + 8, ry + hud.ROW - 3, w - 16, 2, "ink", 255)
                end
            end
        else
            rk = hud.ease.out_cubic(hud.progress(age or 0, i, hud.MOTION.base)) * k
        end
        local strip = row.you and "gold" or (row.team == "red" and hud.C.red)
            or (row.team == "blue" and hud.C.blue) or nil
        local lit = row.you == true
        local rowH = hud.ROW - 2
        if lit or strip ~= nil or i % 2 == 0 then
            hud.plate(x + 10, ry - 1, w - 20, rowH,
                { alpha = rk * (lit and 1 or 0.55), lit = lit, strip = strip })
        end
        local mid = ry - 1 + rowH / 2
        local tone = row.out and "mute" or (row.you and "gold" or "ink")
        local slide = (1 - rk) * 12
        local placeTone = tone
        if opts.podium and not row.out then placeTone = hud.PODIUM[i] or tone end
        hud.digits_mid(tostring(i), L.place + slide, mid, "rowSmall", placeTone, 255 * rk, "right")
        hud.name_mid(row.name or "", L.name + slide, mid, "rowSmall", tone, 255 * rk, "left",
            L.nameRoom, { key = "board" .. i, mult = pop ~= 1 and pop or nil })

        local score = tostring(row.score or 0)
        if string.find(score, "%a") then
            hud.text_mid(score, colX[1], mid, "rowSmall", tone, 255 * rk, "right")
        else
            hud.digits_mid(score, colX[1], mid, "rowSmall", tone, 255 * rk, "right")
        end
        if row.stat ~= nil and cols[2] ~= nil then
            hud.text_mid(tostring(row.stat), colX[2], mid, "rowSmall", "ink2", 230 * rk, "right")
        end
        ry = ry + hud.ROW
    end
    return true
end

local function card_art(x, y, w, h, card, alpha)
    local tone = card.tone or hud.C.info
    hud.rect(x, y, w, h, hud.darken(tone, 0.55), alpha)
    local util = OF.util
    if card.level ~= nil and util ~= nil and type(util.painting_for_place) == "function" then
        local scale = h / 64
        if util.painting_for_place(card.level, card.area or 1, x + (w - 64 * scale) / 2, y,
            scale, alpha) then
            hud.rect(x, y, w, 2, hud.lighten(tone, 0.4), alpha)
            return true
        end
    end
    for i = 0, 2 do
        hud.rect(x, y + h * (0.45 + i * 0.18), w, h * 0.18, hud.darken(tone, 0.35 + i * 0.15),
            alpha * (0.5 + i * 0.15))
    end
    hud.rect(x, y, w, 2, hud.lighten(tone, 0.4), alpha)
    hud.text_centred(string.sub(plain_of(card.name or "?"), 1, 1), x + w * 0.5, y + h * 0.5,
        "display", hud.lighten(tone, 0.3), alpha * 0.45, math.min(1, h / 110))
    return false
end
hud.card_art = card_art

local function corner_tag(word, x, y, alpha, tone)
    local tw = hud.ink_width(word, "caption")
    local _, _, capH = hud.cap("caption", 1, "A")
    local pw, ph = tw + hud.S.s4, capH + hud.S.s2 + 2
    hud.plate(x - pw, y, pw, ph, { alpha = alpha / 255, tint = tone or "gold" })
    hud.text_in(word, x - pw, y, pw, ph, "caption", tone or "gold", alpha)
end

hud.TEAM_COL_W = 260
hud.TEAM_GAP = 16
hud.TEAM_BAND = 40
hud.TEAM_LAND = { 15, 39 }
function hud.team_board(sides, opts, age)
    if type(sides) ~= "table" or #sides == 0 or hud.blocked() then return nil end
    opts = opts or {}
    age = age or 0
    local n = #sides
    local most = 0
    for _, side in ipairs(sides) do most = math.max(most, math.min(#(side.rows or {}), 16)) end
    local w = math.max(hud.BOARD_W, hud.CARD_PAD * 2 + n * hud.TEAM_COL_W + (n - 1) * hud.TEAM_GAP)
    local h = 64 + hud.TEAM_BAND + 10 + most * hud.ROW + 16
    local x, y, k
    x, y, k, w, h = card_frame(w, h, age, opts.tone or "gold", opts.minX)
    local a = 255 * k
    card_header(x, y, w, opts.title or "", opts.sub or "", a)
    local colW = (w - hud.CARD_PAD * 2 - (n - 1) * hud.TEAM_GAP) / n
    local bandY = y + 56
    local xs = {}
    local anyWinner = false
    for _, side in ipairs(sides) do if side.winner then anyWinner = true end end
    for i, side in ipairs(sides) do
        local cx = x + hud.CARD_PAD + (i - 1) * (colW + hud.TEAM_GAP)
        xs[i] = cx
        local colour = side.colour or hud.C.ink

        local landAt = (anyWinner and side.winner) and hud.TEAM_LAND[2] or hud.TEAM_LAND[1]
        local ck = hud.ease.out_cubic(hud.progress(age, landAt, hud.MOTION.reveal.row)) * k
        if ck > 0 then
            if side.winner and age >= landAt then
                hud.cue_once((opts.key or "team") .. ":win", "stinger")
            end
            local pop = side.winner and hud.punch(age - landAt - hud.MOTION.reveal.row, 1.12, 2, 2, 4) or 1
            local slide = (1 - ck) * 14
            hud.plate(cx, bandY + slide, colW, hud.TEAM_BAND,
                { alpha = ck, strip = colour, tint = colour, lit = side.winner == true })
            local mid = bandY + slide + hud.TEAM_BAND / 2
            local scoreText = tostring(side.score or "")
            local scoreW = scoreText ~= "" and (hud.measure(scoreText, "heading", pop) + hud.S.s3) or 0

            local tagW = 0
            if side.winner then
                local _, _, capH = hud.cap("caption", 1, "A")
                tagW = hud.ink_width("WINNER", "caption") + hud.S.s4
                corner_tag("WINNER", cx + colW - hud.S.s3 - scoreW, mid - (capH + hud.S.s2 + 2) / 2,
                    255 * ck, colour)
                tagW = tagW + hud.S.s2
            end
            hud.name_mid(side.label or "", cx + hud.S.s3, mid, "body", colour, 255 * ck, "left",
                colW - hud.S.s3 * 2 - scoreW - tagW, { key = "team-band" .. i })
            if scoreText ~= "" then
                hud.digits_mid(scoreText, cx + colW - hud.S.s3, mid, "heading",
                    side.winner and hud.lighten(colour, 0.5) or hud.C.ink, 255 * ck, "right", pop)
            end
            local rows = side.rows or {}
            local count = math.min(#rows, 16)
            local ry = bandY + hud.TEAM_BAND + 10
            for j = 1, count do
                local row = rows[j]
                local at = landAt + hud.reveal_delay(j, count) - hud.MOTION.reveal.start
                local rk = hud.ease.out_cubic(hud.progress(age, at, hud.MOTION.reveal.row)) * ck
                if rk > 0 then
                    local lit = row.you == true
                    local rowH = hud.ROW - 2
                    if lit or j % 2 == 0 then
                        hud.plate(cx, ry - 1, colW, rowH,
                            { alpha = rk * (lit and 1 or 0.55), lit = lit, strip = lit and "gold" or nil })
                    end
                    local rmid = ry - 1 + rowH / 2
                    local tone = row.out and "mute" or (lit and "gold" or "ink")
                    local rslide = (1 - rk) * 12
                    local figure = tostring(row.score or "")

                    local numeric = figure ~= "" and not string.find(figure, "%a")
                    local fw = 0
                    if figure ~= "" then
                        fw = (numeric and hud.digits_width(figure, "rowSmall")
                            or hud.measure(figure, "rowSmall")) + hud.S.s3
                    end
                    hud.name_mid(row.name or "", cx + hud.S.s3 + rslide, rmid, "rowSmall", tone, 255 * rk,
                        "left", colW - hud.S.s3 * 2 - fw, { key = "team" .. i .. ":" .. j })
                    if figure ~= "" then
                        if not numeric then
                            hud.text_mid(figure, cx + colW - hud.S.s3, rmid, "rowSmall", tone, 255 * rk, "right")
                        else
                            hud.digits_mid(figure, cx + colW - hud.S.s3, rmid, "rowSmall", tone, 255 * rk, "right")
                        end
                    end
                end
                ry = ry + hud.ROW
            end
        end
    end
    hud.state.teamBoard = { x = x, y = y, w = w, h = h, xs = xs, colW = colW }
    return x, y, w, h, xs
end

function hud.map_cards(cards, opts, age)
    if cards == nil or hud.blocked() then return nil end
    opts = opts or {}
    local count = math.min(#cards, 4)
    local cw, ch, gap = 210, 250, 18
    local w = count * cw + (count - 1) * gap + hud.CARD_PAD * 2
    local h = ch + 120
    local x, y, k = card_frame(w, h, age, "gold")
    local a = 255 * k
    local phase = opts.phase or "vote"
    local pk = hud.ease.out_cubic((opts.phaseAge or 0) / hud.MOTION.slow)
    local title = opts.title or "VOTE FOR THE NEXT MAP"
    if phase == "tie" then title = "A TIE - DRAWING ONE"
    elseif phase == "reveal" then title = "NEXT MAP" end
    local clockW = 80
    local base = card_header(x, y, w, title, nil, a, phase == "vote" and "ink" or "gold",
        w - hud.CARD_PAD * 2 - clockW - hud.S.s4)
    if phase == "vote" and opts.secs ~= nil then
        local late = opts.secs <= 5
        local _, _, capH = hud.cap("heading", 1, "0")
        local chipH = 30

        local chipY = base - capH / 2 - chipH / 2
        hud.plate(x + w - hud.CARD_PAD - clockW, chipY, clockW, chipH,
            { alpha = k, tint = late and hud.C.warn or nil })
        hud.digits_mid(hud.clock(opts.secs), x + w - hud.CARD_PAD - clockW / 2, chipY + chipH / 2,
            "body", late and "warn" or "ink", a, "center")
    end
    local rects = {}
    local _, _, capB = hud.cap("body", 1, "A")
    local _, _, capC = hud.cap("caption", 1, "A")
    for i = 1, count do
        local card = cards[i]
        local winner = opts.winner == i
        local lit = (phase == "vote" and opts.selected == i) or (phase == "tie" and opts.highlight == i)
            or (phase == "reveal" and winner)
        local ck = hud.ease.out_cubic(hud.progress(age or 0, i * 2, hud.MOTION.base)) * k
        local cx = x + hud.CARD_PAD + (i - 1) * (cw + gap)
        local cy = y + 64 - (lit and 8 or 0) + (1 - ck) * 20
        local scale = 1
        if phase == "reveal" then
            if winner then
                local centre = x + w / 2 - cw / 2
                cx = cx + (centre - cx) * pk
                scale = 1 + 0.12 * pk
                cy = cy - 10 * pk
            else
                ck = ck * (1 - pk)
            end
        elseif phase == "tie" and not card.tied then
            ck = ck * 0.35
        end
        local sw2, sh2 = cw * scale, ch * scale
        cx = cx - (sw2 - cw) / 2
        rects[i] = { x = cx, y = cy, w = sw2, h = sh2 }
        if ck > 0.01 then
            if lit then
                local glow = hud.pulse(hud.now(), phase == "tie" and 8 or 40)
                hud.rect(cx - 3, cy - 3, sw2 + 6, sh2 + 6, "gold", (140 + 80 * glow) * ck)
            end
            hud.plate(cx, cy, sw2, sh2, { alpha = ck, lit = lit })
            local artH = 112 * scale
            card_art(cx + 2, cy + 2, sw2 - 4, artH, card, 255 * ck)
            local inner = sw2 - 24
            local nameBase = cy + 2 + artH + 14 + capB
            local _, nb = hud.cap("body", 1, plain_of(card.name or ""))
            hud.name(card.name or "", cx + 12, nameBase - nb, "body", "ink", 255 * ck, "left", inner,
                { key = "vote-name" .. i })
            local _, tb = hud.cap("caption", 1, plain_of(card.tags or ""))
            hud.name(card.tags or "", cx + 12, nameBase + 10 + capC - tb, "caption", "mute", 255 * ck,
                "left", inner, { key = "vote-tags" .. i })

            local voters = card.voters or {}
            local footMid = cy + sh2 - 22
            local px = cx + 16
            for v, tone in ipairs(voters) do
                local col = (v - 1) % 8
                local row = math.floor((v - 1) / 8)
                hud.diamond(px + col * 14, footMid - row * 12, 8, tone, 255 * ck)
            end
            local n = #voters
            hud.text_mid(string.format("%.0f vote%s", n, n == 1 and "" or "s"), cx + sw2 - 12,
                footMid, "caption", "ink2", 255 * ck, "right")
            if opts.mine == i and phase ~= "reveal" then
                corner_tag("YOUR PICK", cx + sw2 - 8, cy + 8, 255 * ck, "gold")
            end
        end
    end
    return rects
end

hud.GRID = { cw = 176, ch = 150, art = 92, gap = 14, cols = 5 }

function hud.map_grid_layout(count)
    local sw, sh = hud.screen()
    local g = hud.GRID
    local cols = math.max(1, math.min(g.cols, count,
        math.floor((sw - hud.MARGIN * 2 - hud.CARD_PAD * 2 + g.gap) / (g.cw + g.gap))))
    local rowsFit = math.max(1, math.floor((sh - hud.MARGIN * 2 - 96 + g.gap) / (g.ch + g.gap)))
    local rows = math.max(1, math.min(rowsFit, math.ceil(count / cols)))
    local w = cols * g.cw + (cols - 1) * g.gap + hud.CARD_PAD * 2
    local h = 72 + rows * (g.ch + g.gap) - g.gap + 30
    return { cols = cols, rows = rows, w = w, h = h, totalRows = math.ceil(count / cols) }
end

function hud.map_grid(cards, opts, age)
    if cards == nil or #cards == 0 or hud.blocked() then return nil, 0 end
    opts = opts or {}
    local g = hud.GRID
    local L = hud.map_grid_layout(#cards)
    local x, y, k, w, h = card_frame(L.w, L.h, age, "gold")
    local a = 255 * k
    local sel = math.max(1, math.min(#cards, opts.selected or 1))
    local selRow = math.floor((sel - 1) / L.cols)
    local first = opts.first or 0
    if selRow < first then first = selRow end
    if selRow >= first + L.rows then first = selRow - L.rows + 1 end
    first = math.max(0, math.min(first, L.totalRows - L.rows))
    card_header(x, y, w, opts.title or "PICK THE MAP",
        string.format("%.0f MAPS", #cards), a)
    local rects = {}
    local _, _, capB = hud.cap("rowSmall", 1, "A")
    local _, _, capC = hud.cap("caption", 1, "A")
    for r = 0, L.rows - 1 do
        for c = 0, L.cols - 1 do
            local i = (first + r) * L.cols + c + 1
            local card = cards[i]
            if card ~= nil then
                local lit = i == sel
                local ck = hud.ease.out_cubic(hud.progress(age or 0, r * L.cols + c, hud.MOTION.base)) * k
                local cx = x + hud.CARD_PAD + c * (g.cw + g.gap)
                local cy = y + 60 + r * (g.ch + g.gap) - (lit and 4 or 0)
                rects[i] = { x = cx, y = cy, w = g.cw, h = g.ch }
                if lit then
                    local glow = hud.pulse(hud.now(), 40)
                    hud.rect(cx - 3, cy - 3, g.cw + 6, g.ch + 6, "gold", (140 + 80 * glow) * ck)
                end
                hud.plate(cx, cy, g.cw, g.ch, { alpha = ck, lit = lit })
                card_art(cx + 2, cy + 2, g.cw - 4, g.art, card, 255 * ck)
                local nameBase = cy + 2 + g.art + 10 + capB
                local _, nb = hud.cap("rowSmall", 1, plain_of(card.name or ""))
                hud.name(card.name or "", cx + 10, nameBase - nb, "rowSmall", lit and "ink" or "ink2",
                    255 * ck, "left", g.cw - 20, { key = "grid" .. i })
                if card.tags ~= nil then
                    local _, tb = hud.cap("caption", 1, plain_of(card.tags))
                    hud.name(card.tags, cx + 10, nameBase + 8 + capC - tb, "caption", "mute",
                        255 * ck, "left", g.cw - 20, { key = "grid-tags" .. i })
                end
                if opts.mine == i then corner_tag(opts.mineWord or "PICKED", cx + g.cw - 6, cy + 6, 255 * ck, "gold") end
            end
        end
    end

    if L.totalRows > L.rows then
        local barX = x + w - 10
        local barY = y + 60
        local barH = L.rows * (g.ch + g.gap) - g.gap
        hud.rect(barX, barY, 3, barH, hud.C.plate, 200 * k)
        hud.rect(barX, barY + barH * first / L.totalRows, 3, barH * L.rows / L.totalRows, "gold", 255 * k)
    end
    if opts.sub ~= nil then
        hud.text_base(opts.sub, x + hud.CARD_PAD, y + h - 12, "caption", "mute", a)
    end
    return rects, first
end

function hud.roulette(tied, winner, age, frames)
    if type(tied) ~= "table" or #tied == 0 then return winner end
    if (age or 0) >= (frames or 60) * 0.66 then return winner end
    local step = math.floor((-5 + math.sqrt(25 + 8 * math.max(0, age or 0))) / 2)
    return tied[(step % #tied) + 1]
end

function hud.stocks(x, y, lives, most, tone)
    for i = 1, most or 0 do
        local px = x + (i - 1) * 9
        if i <= (lives or 0) then
            hud.diamond(px + 3, y + 3, 6, tone or "good", 255)
        else
            hud.diamond(px + 3, y + 3, 6, hud.C.mute, 90)
        end
    end
    return (most or 0) * 9
end

function hud.ordinal(n)
    n = math.floor(n or 0)
    local tens = n % 100
    local suffix = "TH"
    if tens < 11 or tens > 13 then
        local last = n % 10
        if last == 1 then suffix = "ST" elseif last == 2 then suffix = "ND"
        elseif last == 3 then suffix = "RD" end
    end
    return tostring(n) .. suffix
end

function hud.role_badge(word, tone)
    if word == nil or hud.blocked() then return 0 end
    local tw = hud.ink_width(word, "body")
    local _, _, capH = hud.cap("body", 1, "A")
    local pw, ph = tw + hud.S.s3 * 2 + 3, capH + hud.S.s2 * 2
    hud.plate(hud.MARGIN, hud.MARGIN, pw, ph, { strip = tone })
    hud.text_in(word, hud.MARGIN + 3, hud.MARGIN, pw - 3, ph, "body", tone, 255)
    return pw
end

function hud.split_tone(delta, segment, bestSegment)
    if segment ~= nil and bestSegment ~= nil and segment < bestSegment then return "best" end
    if delta == nil then return "ink2" end
    if delta < 0 then return "good" end
    return "bad"
end

function hud.wheel_chrome(spec)
    local fade = clamp01(spec.fade or 1)
    local open = hud.ease.out_cubic(spec.open == nil and 1 or spec.open)
    local rx = (spec.rx or 200) * (0.72 + 0.28 * open)
    local ry = (spec.ry or spec.rx or 200) * (0.72 + 0.28 * open)
    local cx, cy, count = spec.cx, spec.cy, math.max(1, spec.count or 8)
    local accent = spec.accent or "gold"
    if spec.wash ~= false then
        local sw, sh = hud.screen()
        hud.rect(0, 0, sw, sh, hud.C.shade, 120 * fade)
    end
    local function at(i)
        local angle = (i - 1) * 2 * math.pi / count
        return cx + math.sin(angle) * rx, cy - math.cos(angle) * ry, angle
    end

    local segments = math.max(24, count * 6)
    local px, py = cx, cy - ry
    local r, g, b = hud.colour(hud.C.ink2)
    local ar, ag, ab = hud.colour(accent)
    for k = 1, segments do
        local a = k * 2 * math.pi / segments
        local nx, ny = cx + math.sin(a) * rx, cy - math.cos(a) * ry
        local lit = false
        if spec.selected ~= nil then
            local mid = (spec.selected - 1) * 2 * math.pi / count
            local d = math.abs(((a - math.pi / segments - mid) + math.pi) % (2 * math.pi) - math.pi)
            lit = d <= math.pi / count
        end
        if lit then
            djui_hud_set_color(ar, ag, ab, byte(230 * fade))
            djui_hud_render_line(px, py, nx, ny, 4)
        else
            djui_hud_set_color(r, g, b, byte(55 * fade))
            djui_hud_render_line(px, py, nx, ny, 2)
        end
        px, py = nx, ny
    end
    hud.unrotate()

    if spec.selected ~= nil then
        local sx, sy, angle = at(spec.selected)
        local dx, dy = math.sin(angle), -math.cos(angle)
        local inner = spec.hubRadius or 40
        local reach = math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2) * 0.62
        hud.line(cx + dx * inner, cy + dy * inner, cx + dx * reach, cy + dy * reach, 3, accent, 220 * fade)
        hud.diamond(cx + dx * reach, cy + dy * reach, 10, accent, 255 * fade)
    end
    return at
end

function hud.wheel_slot(x, y, w, h, lit, fade, accent, dim)
    lit = clamp01(lit or 0)
    fade = clamp01(fade or 1)
    local grow = 1 + 0.08 * hud.ease.out_back(lit)
    local pw, ph = w * grow, h * grow
    local px, py = x - pw / 2, y - ph / 2
    if lit > 0 then
        hud.rect(px - 2, py - 2, pw + 4, ph + 4, accent or "gold", 150 * lit * fade)
    end
    hud.plate(px, py, pw, ph, { alpha = fade * (dim and 0.45 or 1), lit = lit > 0.5 })
    if lit > 0 then hud.rect(px + 2, py, pw - 4, 3, accent or "gold", 255 * lit * fade) end
    return px, py, pw, ph
end

function hud.wheel_hub(cx, cy, w, h, fade, aimed, accent)
    fade = clamp01(fade or 1)
    local x, y = cx - w / 2, cy - h / 2
    hud.plate(x, y, w, h, { alpha = fade, lit = true })
    hud.rect(x + 2, y, w - 4, 3, aimed and (accent or "gold") or hud.C.mute, 255 * fade)
    return x, y, w, h
end

function hud.punch(age, peak, up, hold, settle)
    if age == nil or age < 0 then return 1 end
    up, hold, settle = up or 2, hold or 2, settle or 4
    local rise = (peak or 1.15) - 1
    if rise == 0 then return 1 end
    if age < up then return 1 + rise * hud.ease.out_cubic(age / math.max(1, up)) end
    if age < up + hold then return 1 + rise end
    local t = (age - up - hold) / math.max(1, settle)
    if t >= 1 then return 1 end
    return 1 + rise * (1 - hud.ease.out_cubic(t))
end

function hud.pop(key, value, now, peak)
    now = now or hud.now()
    hud.state.pops = hud.state.pops or {}
    local p = hud.state.pops[key]
    if p == nil then
        hud.state.pops[key] = { value = value, at = nil }
        return 1, nil
    end
    if p.value ~= value then p.value, p.at = value, now end
    if p.at == nil then return 1, nil end
    local age = now - p.at
    local dur = hud.MOTION.pop
    if age < 0 or age >= dur then return 1, age end
    local rise = (peak or 1.3) - 1

    local t = age / dur
    if t < 0.33 then return 1 + rise * hud.ease.out_cubic(t / 0.33), age end
    return 1 + rise * (1 - hud.ease.out_back((t - 0.33) / 0.67)), age
end

function hud.roll(key, value, now)
    if type(value) ~= "number" then return value, 1 end
    now = now or hud.now()
    hud.state.rolls = hud.state.rolls or {}
    local r = hud.state.rolls[key]
    if r == nil then
        hud.state.rolls[key] = { from = value, to = value, at = now, dur = 0 }
        return value, 1
    end
    if r.to ~= value then
        local shown = hud.roll_value(r, now)
        local R = hud.MOTION.roll
        local dur = math.min(R.most, R.least + R.per * math.abs(value - shown))
        r.from, r.to, r.at, r.dur = shown, value, now, dur
    end
    local shown = hud.roll_value(r, now)
    local pop = 1
    if r.dur > 0 then pop = hud.punch(now - r.at - r.dur, 1.2, 2, 2, 4) end
    return shown, pop
end

function hud.roll_value(r, now)
    if r.dur <= 0 or now - r.at >= r.dur then return r.to end
    local k = hud.ease.out_cubic((now - r.at) / r.dur)
    local v = r.from + (r.to - r.from) * k
    if math.floor(r.to) == r.to and math.floor(r.from) == r.from then
        if r.to >= r.from then v = math.floor(v) else v = math.ceil(v) end
    end
    return v
end

hud.ICONS = { "star", "coin", "key", "grand", "tag", "flag", "bomb", "pip", "letter", "heart", "balloon" }

function hud.icon_texture(name)
    local globals = _G["gTextures"]
    if globals == nil then return nil end
    local ok, info = pcall(function() return globals[name] end)
    if ok then return info end
    return nil
end

hud.ICON_ART = {
    bomb = { rom = { "bobomb_seg8_texture_0801DA60", "bobomb_seg8_texture_0801EA60" }, own = "of_hud_bomb",
             fuse = "of_hud_fuse", fuseBox = { 0.5, -0.24, 0.42 },
             spark = "of_hud_spark", sparkAt = { rom = { 0.605, -0.114, 0.4 }, own = { 0.73, 0.1, 0.5 } } },
    key = { rom = { "bowser_key_left_texture", "bowser_key_right_texture" }, own = "of_hud_key",
            ownEmpty = "of_hud_key_empty", scale = 1.15 },
    grand = { own = "of_hud_star", ownEmpty = "of_hud_star_empty", glow = "of_hud_glow" },
    star = { ownEmpty = "of_hud_star_empty" },
    tag = { own = "of_hud_tag", ownEmpty = "of_hud_tag_empty", tint = true },

    heart = { own = "of_hud_heart", ownEmpty = "of_hud_heart_empty", tint = true },
    balloon = { own = "of_hud_balloon", ownEmpty = "of_hud_balloon_empty", tint = true },
}

hud.ICON_PICTURES = {
    "of_hud_bomb", "of_hud_bomb_s",
    "of_hud_fuse", "of_hud_fuse_s",
    "of_hud_spark", "of_hud_spark_s",
    "of_hud_key", "of_hud_key_s",
    "of_hud_key_empty", "of_hud_key_empty_s",
    "of_hud_star", "of_hud_star_s",
    "of_hud_star_empty", "of_hud_star_empty_s",
    "of_hud_glow", "of_hud_glow_s",
    "of_hud_tag", "of_hud_tag_s",
    "of_hud_tag_empty", "of_hud_tag_empty_s",
    "of_hud_heart", "of_hud_heart_s",
    "of_hud_heart_empty", "of_hud_heart_empty_s",
    "of_hud_balloon", "of_hud_balloon_s",
    "of_hud_balloon_empty", "of_hud_balloon_empty_s",
}

hud.ICON_SMALL = 28

hud.artCache = {}
function hud.art(name)
    if name == nil then return nil end
    local artInfo = hud.artCache
    local info = artInfo[name]
    if info == nil then
        info = false
        if type(get_texture_info) == "function" then
            local ok, got = pcall(get_texture_info, name)
            if ok and type(got) == "table" then info = got end
        end
        artInfo[name] = info
    end
    return info or nil
end

function hud.own_art(base, size)
    if base == nil then return nil end
    if (size or 64) < hud.ICON_SMALL then return hud.art(base .. "_s") or hud.art(base) end
    return hud.art(base) or hud.art(base .. "_s")
end

local function draw_art(info, x, y, w, h, r, g, b, a)
    local restore = djui_hud_get_filter ~= nil and djui_hud_get_filter() or nil
    if djui_hud_set_filter ~= nil and FILTER_LINEAR ~= nil then djui_hud_set_filter(FILTER_LINEAR) end
    djui_hud_set_color(byte(r), byte(g), byte(b), byte(a))
    djui_hud_render_texture(info, x, y, w / (info.width or 64), h / (info.height or 64))
    if djui_hud_set_filter ~= nil and restore ~= nil then djui_hud_set_filter(restore) end
end

local function draw_halves(names, cx, cy, size, r, g, b, a)
    local left, right = hud.art(names[1]), hud.art(names[2])
    if left == nil or right == nil then return false end
    local h = size
    local w = size * ((left.width or 32) / (left.height or 64))
    draw_art(left, cx - w, cy - h / 2, w, h, r, g, b, a)
    draw_art(right, cx, cy - h / 2, w, h, r, g, b, a)
    return true
end

local function draw_icon_art(name, cx, cy, size, tone, alpha, empty)
    local art = hud.ICON_ART[name]
    if art == nil then return nil end
    size = size * (art.scale or 1)
    local h = size / 2
    if name == "grand" and not empty then
        local glow = hud.own_art(art.glow, size * 1.8)
        if glow ~= nil then
            local gr, gg, gb = hud.colour("gold")
            draw_art(glow, cx - size * 0.9, cy - size * 0.9, size * 1.8, size * 1.8, gr, gg, gb, alpha * 0.9)
        end
        local star = hud.icon_texture("star")
        if star ~= nil then
            local w = star.width or 16
            djui_hud_set_color(255, 255, 255, byte(alpha))
            djui_hud_render_texture(star, cx - h, cy - h, size / w, size / w)
            return "rom"
        end
    end
    if art.rom ~= nil and not empty then
        if draw_halves(art.rom, cx, cy, size, 255, 255, 255, alpha) then
            local fuse = art.fuse ~= nil and hud.own_art(art.fuse, size * art.fuseBox[3]) or nil
            if fuse ~= nil then
                local f = art.fuseBox
                draw_art(fuse, cx - h + (f[1] - f[3] / 2) * size, cy - h + f[2] * size, f[3] * size, f[3] * size,
                    255, 255, 255, alpha)
            end
            return "rom"
        end
    elseif art.rom ~= nil and empty and art.ownEmpty == nil then
        local r, g, b = hud.colour(hud.C.mute)
        if draw_halves(art.rom, cx, cy, size, r, g, b, alpha * 0.6) then return "rom" end
    end
    local own = hud.own_art(empty and art.ownEmpty or art.own, size)
    if own == nil then return nil end
    local r, g, b = 255, 255, 255
    if art.tint then r, g, b = hud.colour(empty and hud.C.mute or tone) end
    draw_art(own, cx - h, cy - h, size, size, r, g, b, alpha * (empty and 0.9 or 1))
    return "own"
end

local function bomb_spark(source, cx, cy, size, tone, alpha)
    local art = hud.ICON_ART.bomb
    local at = art.sparkAt[source] or art.sparkAt.own
    local s = size * at[3]
    local spark = hud.own_art(art.spark, s)
    if spark == nil then return end
    if tone == nil or tone == "ink" or tone == hud.C.ink then tone = "warn" end
    local r, g, b = hud.colour(tone)
    draw_art(spark, cx - size / 2 + at[1] * size - s / 2, cy - size / 2 + at[2] * size - s / 2, s, s, r, g, b, alpha)
end

function hud.icon(name, cx, cy, size, tone, alpha, opts)
    opts = opts or {}
    alpha = alpha or 255
    size = size or 18
    tone = tone or "ink"
    local h = size / 2
    if name == "key" or name == "grand" or name == "tag" or name == "bomb" or name == "heart" or name == "balloon"
        or (name == "star" and opts.empty) then
        local source = draw_icon_art(name, cx, cy, size, tone, alpha, opts.empty)
        if source ~= nil then
            if name == "bomb" then bomb_spark(source, cx, cy, size, tone, alpha) end
            hud.state.iconArt = hud.state.iconArt or {}
            hud.state.iconArt[name] = source
            return true
        end
        hud.state.iconArt = hud.state.iconArt or {}
        hud.state.iconArt[name] = "shape"
    end
    if opts.empty then
        alpha = alpha * 0.45
        tone = hud.C.mute
    end
    if name == "grand" then name = "star" end
    if name == "tag" then name = "pip" end
    if name == "star" or name == "coin" then
        local info = hud.icon_texture(name)
        if info ~= nil then
            local w = info.width or 16
            local r, g, b = hud.colour(opts.empty and hud.C.mute or "ink")
            djui_hud_set_color(byte(r), byte(g), byte(b), byte(alpha))
            djui_hud_render_texture(info, cx - h, cy - h, size / w, size / w)
            return true
        end
        if name == "star" then return hud.draw_glyph("star", cx, cy, size, tone or "target", alpha) end
        hud.draw_glyph("circle", cx, cy, size * 0.9, tone or "target", alpha)
        hud.rect(cx - size * 0.08, cy - size * 0.28, size * 0.16, size * 0.56, hud.C.outline, alpha * 0.6)
        return true
    elseif name == "key" then

        hud.draw_glyph("ring", cx - size * 0.22, cy - size * 0.18, size * 0.5, tone, alpha)
        hud.line(cx - size * 0.05, cy, cx + h, cy + h * 0.9, math.max(2, size * 0.14), tone, alpha)
        hud.rect(cx + size * 0.2, cy + size * 0.22, size * 0.12, size * 0.2, tone, alpha)
        hud.rect(cx + size * 0.34, cy + size * 0.32, size * 0.12, size * 0.16, tone, alpha)
        return true
    elseif name == "flag" then
        hud.rect(cx - h * 0.7, cy - h, math.max(2, size * 0.1), size, hud.C.ink2, alpha)
        hud.rect(cx - h * 0.7 + 2, cy - h, size * 0.62, size * 0.42, tone, alpha)
        return true
    elseif name == "bomb" then
        hud.draw_glyph("circle", cx, cy + size * 0.06, size * 0.82, tone, alpha)
        hud.line(cx + size * 0.12, cy - size * 0.3, cx + size * 0.3, cy - h, 2, hud.C.warn, alpha)
        return true
    elseif name == "pip" then
        return hud.draw_glyph("circle", cx, cy, size * 0.5, tone, alpha)
    elseif name == "heart" or name == "balloon" then

        hud.draw_glyph("circle", cx - size * 0.18, cy - size * 0.1, size * 0.5, tone, alpha)
        hud.draw_glyph("circle", cx + size * 0.18, cy - size * 0.1, size * 0.5, tone, alpha)
        hud.diamond(cx, cy + size * 0.12, size * 0.62, tone, alpha)
        return true
    elseif name == "letter" then

        local fill = opts.fill or hud.C.out
        hud.draw_glyph("circle", cx, cy, size, fill, alpha)
        if opts.text ~= nil then
            hud.text_centred(opts.text, cx, cy, "body", "ink", alpha)
        end
        return true
    end
    return hud.draw_glyph(name, cx, cy, size, tone, alpha)
end

hud.ICON_ROW = { size = 26, gap = 8, countGap = 4, ref = 1080 / 2 }

function hud.icon_size()

    local _, _, capH = hud.cap("heading", 1, "A")
    return math.max(14, math.floor(capH * 1.25 + 0.5))
end

local function item_text(item)
    if item.count ~= nil then return tostring(item.count) end
    if item.icon == "letter" then return nil end
    return item.text
end

local function count_width(t, opts)
    if opts.digits then return hud.digits_width(t, opts.digits) end
    return hud.ink_width(t, "body")
end

hud.ICON_ROW_DIVIDER = { w = 1, gap = 10, share = 0.62, alpha = 0.22 }

function hud.icon_row_width(items, opts)
    opts = opts or {}
    local size = opts.size or hud.icon_size()
    local I = hud.ICON_ROW
    local D = hud.ICON_ROW_DIVIDER
    local w = 0
    for i, item in ipairs(items or {}) do
        if item.divider then
            w = w + D.w + 2 * D.gap
        else
            w = w + size
            local t = item_text(item)
            if t ~= nil and t ~= "" then w = w + I.countGap + count_width(t, opts) end
            local nxt = items[i + 1]
            if nxt ~= nil and not nxt.divider then w = w + (item.gap or I.gap) end
        end
    end
    return w, size
end

function hud.icon_row(items, cx, y, opts)
    if type(items) ~= "table" or #items == 0 or hud.blocked() then return 0, 0 end
    opts = opts or {}
    local now = opts.now or hud.now()
    local alpha = opts.alpha or 255
    local w, size = hud.icon_row_width(items, opts)
    local x = cx - w / 2
    local I = hud.ICON_ROW
    local D = hud.ICON_ROW_DIVIDER
    local key = opts.key or "row"
    hud.state.iconPops = 0
    for i, item in ipairs(items) do
        if item.divider then
            x = x + D.gap
            local dh = size * D.share
            hud.rect(math.floor(x + 0.5), y - dh / 2, D.w, dh, hud.C.ink, alpha * D.alpha)
            x = x + D.w + D.gap
        else
            local t = item_text(item)
            local sig = tostring(item.count) .. "|" .. tostring(item.fill) .. "|" .. tostring(item.empty)
                .. "|" .. tostring(item.ring and math.floor(item.ring * 4) or "")
                .. "|" .. tostring(item.text)
            local mult, popAge = hud.pop(key .. ":" .. i, sig, now)
            if popAge ~= nil and popAge == 0 then hud.state.iconPops = hud.state.iconPops + 1 end
            local a = alpha * (item.dim and 0.55 or 1)
            if item.blink then
                a = a * (0.45 + 0.55 * hud.pulse(now, 60))
            end
            local icx = x + size / 2
            local s = size * mult
            local fill = item.fill
            if type(fill) == "string" and hud.C[fill] == nil then fill = nil end
            hud.icon(item.icon or "pip", icx, y, item.icon == "letter" and s or s * 0.86,
                item.tone or fill or "ink", a, { text = item.letter or (item.icon == "letter" and item.text or nil),
                    fill = fill, empty = item.empty })
            if item.ring ~= nil and item.ring > 0 then
                hud.arc(icx, y, size * 0.62, item.ring, 2, item.ringTone or "ink", a, 24)
            end
            x = x + size
            if t ~= nil and t ~= "" then
                x = x + I.countGap
                local tw = count_width(t, opts)
                if opts.digits then
                    hud.digits_mid(t, x, y, opts.digits, item.countTone or "ink", a, "left", mult)
                else
                    hud.text_mid(t, x, y, "body", item.countTone or "ink", a, "left", mult)
                end
                x = x + tw
            end
            local nxt = items[i + 1]
            if nxt ~= nil and not nxt.divider then x = x + (item.gap or I.gap) end
        end
    end
    return w, size
end

hud.STATE_LINE = { padX = 12, padY = 6, strip = 3, most = 32, meterH = 2 }

function hud.state_line(id, text, opts)
    if id == nil then return false end
    local D = hud.state.lineDecl
    local at = hud.now()
    if D == nil or D.drawn or D.at ~= at then
        D = { drawn = false, at = at }
        hud.state.lineDecl = D
    end
    if #D >= hud.STATE_LINE.most then return false end
    opts = opts or {}
    D[#D + 1] = { id = id, text = text, prio = opts.prio or 50, tone = opts.tone,
        figure = opts.figure, urgent = opts.urgent == true, colour = opts.colour == true,
        icons = opts.icons, iconOpts = opts.iconOpts,
        meter = type(opts.meter) == "number" and clamp01(opts.meter) or nil }
    return true
end

local function line_take(entry, now)
    return { id = entry.id, text = entry.text, prio = entry.prio, tone = entry.tone,
        figure = entry.figure, urgent = entry.urgent, colour = entry.colour, icons = entry.icons,
        iconOpts = entry.iconOpts, meter = entry.meter, since = now }
end

function hud.state_line_resolve(now)
    now = now or hud.now()
    local D = hud.state.lineDecl or { drawn = true }

    local list = (D.drawn or (D.at ~= nil and D.at ~= hud.now())) and {} or D
    D.drawn = true

    local seen = hud.state.lineSeen or {}
    local nextSeen = {}
    local best, cur = nil, nil
    local S = hud.state.line
    for _, e in ipairs(list) do
        nextSeen[e.id] = seen[e.id] or now
        if S ~= nil and e.id == S.id then cur = e end
        if best == nil or e.prio > best.prio
            or (e.prio == best.prio and nextSeen[e.id] > nextSeen[best.id]) then
            best = e
        end
    end
    hud.state.lineSeen = nextSeen
    local M = hud.MOTION.state
    if S == nil then
        if best ~= nil then hud.state.line = line_take(best, now) end
    elseif cur == nil then

        hud.state.lineGhost = { entry = S, at = now }
        hud.state.line = best ~= nil and line_take(best, now) or nil
    elseif best ~= nil and best.id ~= S.id
        and (best.prio > cur.prio
            or (best.prio == cur.prio and now - S.since >= M.minHold)) then
        hud.state.lineGhost = { entry = S, at = now }
        hud.state.line = line_take(best, now)
    else

        S.text, S.prio, S.tone, S.figure = cur.text, cur.prio, cur.tone, cur.figure
        S.urgent, S.colour, S.icons, S.meter = cur.urgent, cur.colour, cur.icons, cur.meter
        S.iconOpts = cur.iconOpts
    end
    return hud.state.line
end

local function line_words(e, now, rolled)
    local fig = e.figure
    if fig ~= nil and rolled then fig = hud.roll("state:" .. e.id, fig, now) end
    if e.text == nil or e.text == "" then return fig ~= nil and tostring(fig) or "" end
    if fig == nil then return e.text end
    return e.text .. " " .. tostring(fig)
end

local function line_width(e, now)
    local L = hud.STATE_LINE
    local inner
    if e.icons ~= nil then
        inner = hud.icon_row_width(e.icons, e.iconOpts)
    else
        inner = hud.ink_width(line_words(e, now, false), "heading")
    end
    return L.strip + L.padX * 2 + inner
end

function hud.state_line_height()
    local L = hud.STATE_LINE
    local _, _, capH = hud.cap("heading", 1, "A")
    return math.floor(capH + L.padY * 2 + 0.5)
end

function hud.state_line_draw(y, now)
    now = now or hud.now()
    local S = hud.state_line_resolve(now)
    hud.state.lineFrame = { plates = 0, id = S and S.id or nil }

    local slot = hud.state.lineSlot or {}
    hud.state.lineSlot = slot
    slot.y, slot.h, slot.at, slot.x, slot.w = y, hud.state_line_height(), now, nil, 0
    if hud.blocked() then return y end
    local G = hud.state.lineGhost
    local M = hud.MOTION.state
    local outDur = M.exit
    local inDur = M.enter
    if G ~= nil and now - G.at >= outDur then
        G = nil
        hud.state.lineGhost = nil
    end
    if S == nil and G == nil then return y end
    local sw = hud.screen()
    local h = hud.state_line_height()
    if (S ~= nil and S.icons ~= nil) or (G ~= nil and G.entry.icons ~= nil) then
        h = math.max(h, hud.icon_size() + 8)
    end
    hud.state.lineSlot.h = h
    local L = hud.STATE_LINE

    local inK = S ~= nil and hud.ease.out_cubic(hud.progress(now - S.since, 0, inDur)) or 0
    local outK = G ~= nil and (1 - hud.ease.in_cubic(hud.progress(now - G.at, 0, outDur))) or 0
    local w
    if S ~= nil and G ~= nil then
        w = line_width(G.entry, now) + (line_width(S, now) - line_width(G.entry, now)) * inK
    elseif S ~= nil then
        w = line_width(S, now)
    else
        w = line_width(G.entry, now)
    end
    local plateK = S ~= nil and math.max(inK, G ~= nil and 1 or 0) or outK
    if S ~= nil and G == nil then plateK = inK end
    local tone = (S ~= nil and S.tone) or (G ~= nil and G.entry.tone) or "accent"
    local x = sw / 2 - w / 2
    local breath = 1
    if S ~= nil and S.urgent then breath = 0.75 + 0.25 * hud.pulse(now, 45) end
    hud.plate(x, y, w, h, { alpha = plateK * breath, strip = tone })
    hud.state.lineFrame.plates = 1
    hud.state.lineSlot.x, hud.state.lineSlot.w = x, w
    local mid = y + h / 2
    local function words(e, k, drop)
        if k <= 0 then return end
        local a = 255 * k * (e.urgent and breath or 1)
        local ink = e.colour and (e.tone or "ink") or "ink"
        if e.icons ~= nil then
            local rowOpts = e.iconOpts or {}
            hud.icon_row(e.icons, sw / 2 + L.strip / 2, mid + drop, { key = "state:" .. e.id,
                alpha = a, now = now, digits = rowOpts.digits, size = rowOpts.size })
        else
            local text = line_words(e, now, true)
            local _, pop = 1, 1
            if e.figure ~= nil then _, pop = hud.roll("state:" .. e.id, e.figure, now) end
            hud.text_mid(text, sw / 2 + L.strip / 2, mid + drop, "heading", ink, a, "center",
                pop ~= 1 and (1 + (pop - 1) * 0.5) or nil)
        end

        if e.meter ~= nil then
            local mx, mw = x + L.strip + L.padX, w - L.strip - L.padX * 2
            local my = y + h - L.meterH - 2
            if mw > 0 then
                hud.rect(mx, my, mw, L.meterH, hud.C.shade, a * 0.85)
                if e.meter > 0 then hud.rect(mx, my, mw * e.meter, L.meterH, e.tone or "accent", a) end
            end
        end
    end
    if G ~= nil then words(G.entry, outK, 0) end
    if S ~= nil then words(S, inK, (1 - inK) * 4) end

    if hud.state.line ~= nil then hud.state.line.drawnAt = S ~= nil and now or nil end
    return y + h
end

hud.BANNER = {
    out        = { look = "plate", prio = 70, tone = "bad", sound = "out", you = true, word = "OUT" },
    eliminated = { look = "plate", prio = 30, tone = "warn", wordTone = "ink", sound = "last" },
    sideswitch = { look = "band", prio = 80, tone = "info", sound = "sideswitch", word = "SIDE SWITCH" },
    point      = { look = "plate", prio = 50, tone = "good", sound = "score", them = "them", word = "POINT" },
    lead       = { look = "plate", prio = 55, tone = "accent", sound = "lead", them = "them" },
    matchpoint = { look = "band", prio = 80, tone = "accent", sound = "matchpoint", word = "MATCH POINT" },
    overtime   = { look = "band", prio = 80, tone = "warn", sound = "overtime", word = "OVERTIME" },
    finish     = { look = "band", prio = 100, tone = "ink", sound = nil, word = "FINISH!", punch = true,
                   enter = 8, hold = 26 },
    win        = { look = "band", prio = 100, tone = "target", sound = "win", word = "VICTORY" },
    lose       = { look = "band", prio = 100, tone = "bad", sound = "loss", word = "DEFEAT" },
    draw       = { look = "band", prio = 100, tone = "info", sound = "draw", word = "DRAW" },
    roundend   = { look = "band", prio = 100, tone = "ink2", sound = "notice", word = "ROUND OVER" },
    roundstate = { look = "band", prio = 80, tone = "warn", sound = "notice" },
    objective  = { look = "plate", prio = 50, tone = "target", sound = "notice", us = "objective",
                   them = "alarm" },
    role       = { look = "plate", prio = 70, tone = "target", sound = "role", you = true },
    call       = { look = "call", prio = 75, tone = "ink", sound = nil, enter = 4, exit = 4, hold = 60 },
    medal      = { look = "medal", prio = 40, tone = "good", sound = "medal" },
}

hud.BANNER.loss = hud.BANNER.lose

hud.BANNER_CEREMONY = { finish = true, win = true, lose = true, loss = true, draw = true, roundend = true }
hud.BANNER_Y = { plate = 0.30, band = 0.40, call = 0.30 }

local function banners()
    local B = hud.state.banners
    if B == nil then
        B = { cur = nil, wait = nil, shown = 0 }
        hud.state.banners = B
    end
    return B
end

function hud.banner_timing(kind, hold)
    local K = hud.BANNER[kind] or hud.BANNER.objective
    local T = K.look == "band" and hud.MOTION.band or hud.MOTION.banner
    local enter = K.enter or T.enter
    local exit = K.exit or T.exit
    return enter, hold or K.hold or T.hold, exit
end

local function banner_sound(b)
    local K = hud.BANNER[b.kind]
    if b.side == "them" and K.them ~= nil then return K.them end
    if b.side == "us" and K.us ~= nil then return K.us end
    return K.sound
end

local function banner_tones(b)
    local K = hud.BANNER[b.kind]
    local tone = b.tone
    if tone == nil then
        if b.kind == "objective" then
            tone = (b.side == "us" and "good") or (b.side == "them" and "bad") or "target"
        elseif b.kind == "point" or b.kind == "lead" then
            tone = (b.side == "them" and "bad") or K.tone
        else
            tone = K.tone
        end
    end
    local wordTone = b.wordTone or K.wordTone
    if wordTone == nil then
        if b.side == "them" then wordTone = "ink2"
        elseif K.look == "plate" and b.kind ~= "objective" then wordTone = tone
        else wordTone = (K.look == "band") and tone or "ink" end
    end
    return tone, wordTone
end

local function banner_start(B, b, now)
    b.born = now
    b.holdFrom = nil
    b.exitAt, b.exitDur = nil, nil
    B.cur = b
    B.shown = (B.shown or 0) + 1
    local event = banner_sound(b)
    b.sounded = false
    if event ~= nil and not b.quiet then b.sounded = hud.cue(event, b.prio, now) end
    if hud.BANNER[b.kind].you and OF.util.asks(OF.notify, "buzz") then
        pcall(OF.notify.buzz)
    end
end

function hud.banner_phase(b, now)
    if b == nil or b.born == nil then return "done" end
    local enter, hold, exit = hud.banner_timing(b.kind, b.hold)
    local age = now - b.born
    if b.exitAt ~= nil then
        if now >= b.exitAt + b.exitDur then return "done" end
        if now >= b.exitAt then return "exit" end
    end
    if age < enter then return "enter" end
    local holdEnd = (b.holdFrom or (b.born + enter)) + hold
    if now < holdEnd then return "hold" end
    if b.kind == "finish" and b.handedOver then return "hold" end
    if now < holdEnd + exit then return "exit" end
    return "done"
end

function hud.banner_tick(now)
    now = now or hud.now()
    local B = banners()
    if B.cur ~= nil and hud.banner_phase(B.cur, now) == "done" then B.cur = nil end
    if B.cur == nil and B.wait ~= nil then
        local w = B.wait
        B.wait = nil
        if now - w.asked <= hud.MOTION.stale then
            banner_start(B, w, now)
        else
            B.dropped = (B.dropped or 0) + 1
        end
    end
    local c = B.cur
    hud.state.banner = c ~= nil and { kind = c.kind, text = c.text, sub = c.sub, born = c.born,
        phase = hud.banner_phase(c, now), count = c.count } or nil
    return c
end

function hud.banner(kind, text, sub, opts)
    if type(sub) == "table" and opts == nil then
        opts = sub
        sub = opts.sub
    end
    opts = opts or {}
    local K = hud.BANNER[kind]
    if K == nil then return false end
    if kind == "loss" then kind = "lose" end
    text = text or K.word or ""
    if K.look ~= "medal" and K.look ~= "call" then text = string.upper(text) end
    if K.look == "medal" then
        hud.callout(text, opts.tone or K.tone, opts.now, opts.quiet == true)
        return "medal"
    end
    local now = opts.now or hud.now()
    local B = banners()
    hud.banner_tick(now)
    local b = { kind = kind, text = text, sub = sub, side = opts.side, tone = opts.tone,
        wordTone = opts.wordTone, prio = opts.prio or K.prio, hold = opts.hold, asked = now,
        count = 1, quiet = opts.quiet == true }
    local cur = B.cur

    local function same(o)
        return o ~= nil and o.kind == b.kind and o.text == b.text and now - o.asked <= hud.MOTION.merge
    end
    if same(cur) and cur.exitAt == nil then
        cur.count = cur.count + 1
        cur.mergedAt, cur.asked = now, now
        local enter = hud.banner_timing(cur.kind, cur.hold)
        cur.holdFrom = math.max(now, cur.born + enter)
        return "merged"
    end
    if same(B.wait) then
        B.wait.count = B.wait.count + 1
        B.wait.asked = now
        return "merged"
    end
    if cur == nil then
        banner_start(B, b, now)
        return "shown"
    end

    if cur.kind == "finish" and hud.BANNER_CEREMONY[kind] and kind ~= "finish" then
        cur.handedOver = true
        cur.from = { text = cur.text, tone = select(1, banner_tones(cur)), at = now }
        cur.kind, cur.text, cur.sub, cur.tone, cur.side = b.kind, b.text, b.sub, b.tone, b.side
        cur.wordTone, cur.hold, cur.handoverAt = b.wordTone, b.hold, now
        cur.holdFrom = now
        local event = banner_sound(cur)
        if event ~= nil and not b.quiet then hud.cue(event, cur.prio, now) end
        return "handover"
    end
    if b.prio > cur.prio then

        if cur.exitAt == nil or cur.exitAt + cur.exitDur > now + hud.MOTION.cut then
            cur.exitAt, cur.exitDur = now, hud.MOTION.cut
        end
        if B.wait == nil or b.prio >= B.wait.prio then B.wait = b end
        return "interrupt"
    end

    if B.wait == nil or b.prio >= B.wait.prio then
        B.wait = b
        return "queued"
    end
    return false
end

function hud.banner_clear()
    hud.state.banners = nil
    hud.state.banner = nil
end

function hud.band(word, sub, tone, age, close, opts)
    opts = opts or {}
    local sw, sh = hud.screen()
    local top, bandH, titleBase, subBase = hud.result_band(sub)
    if opts.y ~= nil then top = sh * opts.y - bandH / 2 end
    local enter = opts.enter or hud.MOTION.slow
    local open = hud.ease.out_cubic(age / math.max(1, enter)) * (1 - (close or 0))

    local openH = bandH * open
    if openH <= 0 then return false end
    local body = opts.bodyTone or hud.darken(tone, 0.78)
    local drawTop = top + (bandH - openH) / 2
    hud.rect(0, drawTop, sw, openH, body, 220)
    hud.rect(0, drawTop, sw, 2, tone, 255)
    hud.rect(0, drawTop + openH - 2, sw, 2, tone, 255)

    do
        local mult = opts.mult or 1
        local _, _, capM = hud.cap("display", mult, "A")
        local _, _, cap1 = hud.cap("display", 1, "A")
        titleBase = titleBase + (capM - cap1) / 2
        subBase = subBase + (capM - cap1) / 2
        hud.state.bandDrawn = { x = 0, y = drawTop, w = sw, h = openH, top = top, bandH = bandH,
            capTop = top + titleBase - capM, base = top + titleBase,
            last = (sub ~= nil and sub ~= "") and (top + subBase) or (top + titleBase) }
    end
    local fade = 1 - (close or 0)
    local function say(text, textTone, wordAge, k)
        if text == nil or text == "" or k <= 0 then return end
        local settle = hud.ease.out_quint(hud.progress(wordAge, 2, enter))
        local track = 6 + 20 * (1 - settle)

        local rise = opts.instant and 1 or hud.ease.out_cubic(hud.progress(wordAge, 2, hud.MOTION.base))
        local alpha = 255 * rise * fade * k
        local mult = opts.mult or 1
        local util = OF.util
        local ascii = util == nil or type(util.hud_face) ~= "function" or util.hud_face(text) ~= nil

        if ascii and #text <= 16 and plain_of(text) == text then
            local widths, total = {}, 0
            for i = 1, #text do
                local ch = string.sub(text, i, i)
                widths[i] = ch == " " and hud.measure(" ", "display", mult)
                    or hud.ink_width(ch, "display", mult)
                total = total + widths[i] + (i < #text and track or 0)
            end
            local x = sw / 2 - total / 2
            for i = 1, #text do
                hud.text_base(string.sub(text, i, i), x, top + titleBase, "display", textTone, alpha,
                    "left", mult)
                x = x + widths[i] + track
            end
        else
            hud.name(text, sw / 2, top + titleBase - select(2, hud.cap("display", 1, "A")), "display",
                textTone, alpha, "center", sw - hud.MARGIN * 4, { key = "band-word" })
        end
    end
    local wordAge = opts.wordAge or age
    if opts.fromWord ~= nil then

        local k = hud.progress(wordAge, 0, 6)
        say(opts.fromWord, opts.fromTone or tone, enter + 30, 1 - k)
        say(word, opts.wordTone or tone, wordAge, k)
    else
        say(word, opts.wordTone or tone, wordAge, 1)
    end
    if sub ~= nil and sub ~= "" then
        local sk = hud.ease.out_cubic(hud.progress(wordAge, hud.MOTION.base, hud.MOTION.base)) * fade
        local _, sb = hud.cap("body", 1, plain_of(sub))
        hud.name(sub, sw / 2, top + subBase - sb, "body", "ink2", 255 * sk, "center",
            sw - hud.MARGIN * 4, { key = "band-sub" })
    end
    return true
end

function hud.band_area()
    local st = hud.state.banners
    local b = st ~= nil and st.cur or nil
    if b == nil or b.born == nil then return nil end
    local K = hud.BANNER[b.kind]
    if K == nil or K.look ~= "band" then return nil end
    if hud.banner_phase(b, hud.now()) == "done" then return nil end
    local _, sh = hud.screen()
    local _, bandH = hud.result_band(b.sub)
    local top = sh * hud.BANNER_Y.band - bandH / 2
    return top, top + bandH
end

hud.PLATE_GAP = 8

hud.PLATE_MOST = 420
function hud.plate_banner_top(now)
    local slot = hud.state.lineSlot
    if slot == nil or type(slot.at) ~= "number" then return nil end
    now = now or hud.now()
    if now - slot.at > 1 or now < slot.at then return nil end
    return slot.y + slot.h + hud.PLATE_GAP
end

local function banner_sub(b)
    if (b.count or 1) <= 1 then return b.sub end
    local x = "x" .. tostring(b.count)
    if b.sub == nil or b.sub == "" then return x end
    return b.sub .. " - " .. x
end

function hud.banner_draw(now)
    now = now or hud.now()
    local b = hud.banner_tick(now)
    if b == nil or hud.blocked() then return false end
    local K = hud.BANNER[b.kind]
    local enter, hold, exit = hud.banner_timing(b.kind, b.hold)
    local phase = hud.banner_phase(b, now)
    local age = now - b.born

    local outK = 0
    if phase == "exit" then
        local at = b.exitAt or ((b.holdFrom or (b.born + enter)) + hold)
        local dur = b.exitDur or exit
        outK = hud.ease.in_cubic(hud.progress(now - at, 0, dur))
    end
    local tone, wordTone = banner_tones(b)
    local sub = banner_sub(b)
    local sw, sh = hud.screen()
    if K.look == "band" then
        local mult = 1
        if K.punch then mult = hud.punch(age, 1.4, 2, 2, 4) end
        local opts = { wordTone = wordTone, y = hud.BANNER_Y.band, enter = enter, mult = mult,
            instant = K.punch == true }
        local bandAge = age
        if b.handoverAt ~= nil then

            local k = hud.progress(now - b.handoverAt, 0, 6)
            local fr, fg, fb = hud.colour(b.from.tone)
            local tr, tg, tb = hud.colour(tone)
            local mix = { fr + (tr - fr) * k, fg + (tg - fg) * k, fb + (tb - fb) * k }
            opts.bodyTone = hud.darken(mix, 0.78)
            opts.wordAge = now - b.handoverAt
            opts.fromWord, opts.fromTone = b.from.text, b.from.tone
            bandAge = math.max(enter, age)
            hud.band(b.text, sub, mix, bandAge, outK, opts)
            return true
        end
        hud.band(b.text, sub, tone, bandAge, outK, opts)
        if K.punch and age < 3 then hud.flash(now, 0.2, 3) end
        return true
    end

    local inK = hud.ease.out_cubic(hud.progress(age, 0, math.max(1, enter)))
    local token = K.look == "call" and "display" or "title"
    local hasSub = sub ~= nil and sub ~= "" and K.look ~= "call"
    local h, titleBase, subBase = hud.band_rhythm(token, 1, "body", hasSub, 12, 8)
    local ww = hud.ink_width(b.text, token)
    local subW = hasSub and hud.ink_width(sub, "body") or 0
    local w = math.max(ww, subW) + 48 + 3

    w = math.min(w, math.max(ww + 48 + 3, math.min(sw - hud.MARGIN * 2, hud.PLATE_MOST)))
    local subRoom = w - 48 - 3
    local drop = (1 - inK) * 24 - outK * 8
    local x = sw / 2 - w / 2
    local y = sh * (hud.BANNER_Y[K.look] or 0.30) - h / 2 - drop

    local under = K.look == "plate" and hud.plate_banner_top(now) or nil
    if under ~= nil then y = under - drop end
    local alpha = inK * (1 - outK)
    hud.plate(x, y, w, h, { alpha = alpha, strip = tone, lit = b.side ~= "them" })
    local land = 1
    if b.side ~= "them" then land = 1.15 - 0.15 * hud.ease.out_back(hud.progress(age, 0, math.max(1, enter))) end
    hud.text_base(b.text, sw / 2 + 1.5, y + titleBase, token, wordTone, 255 * alpha, "center", land)
    if hasSub then
        local sk = hud.ease.out_cubic(hud.progress(age, 3, math.max(1, enter))) * (1 - outK)
        local subMult = 1
        if b.mergedAt ~= nil then
            local ma = now - b.mergedAt
            subMult = hud.punch(ma, 1.3, 2, 0, 4)
        end
        if subW > subRoom then
            local _, sb = hud.cap("body", 1, plain_of(sub))
            hud.name(sub, sw / 2 + 1.5, y + subBase - sb, "body", "ink2", 255 * sk, "center", subRoom,
                { key = "banner-sub" })
        else
            hud.text_base(sub, sw / 2 + 1.5, y + subBase, "body", "ink2", 255 * sk, "center", subMult)
        end
    end
    return true
end

function hud.callout(text, tone, now, quiet)
    if text == nil then return false end
    now = now or hud.now()
    hud.state.callout = { text = text, tone = tone or "good", born = now }
    if not quiet then hud.cue("medal", hud.BANNER.medal.prio, now) end
    return true
end

hud.FLASH = { most = 3, window = 30, alpha = 0.25 }

function hud.flash(now, share, frames)
    now = now or hud.now()
    local F = hud.state.flashes or {}
    hud.state.flashes = F
    local cur = F.cur
    if cur ~= nil and now >= cur.at and now < cur.at + cur.frames then return true end
    local recent = {}
    for _, at in ipairs(F.starts or {}) do
        if now - at >= 0 and now - at < hud.FLASH.window then recent[#recent + 1] = at end
    end
    F.starts = recent
    if #recent >= hud.FLASH.most then return false end
    recent[#recent + 1] = now
    F.cur = { at = now, frames = frames or 3, share = math.min(hud.FLASH.alpha, share or 0.2) }
    return true
end

function hud.flash_draw(now)
    now = now or hud.now()
    local F = hud.state.flashes
    if F == nil or F.cur == nil then return false end
    local c = F.cur
    local age = now - c.at
    if age < 0 or age >= c.frames then return false end
    local sw, sh = hud.screen()
    local a = 255 * c.share * (1 - age / c.frames)
    hud.rect(0, 0, sw, sh, "ink", a)
    return true
end

function hud.reveal_delay(i, count)
    local R = hud.MOTION.reveal
    count = math.max(1, count or 1)
    local stagger = math.min(R.stagger, 40 / count)
    return R.start + (count - i) * stagger
end

function hud.reveal_cues(key, count, age)
    hud.state.reveals = hud.state.reveals or {}
    local last = hud.state.reveals[key]
    if last == nil or age < last then last = -1 end
    for i = 1, math.min(count, 3) do
        local at = hud.reveal_delay(i, count)
        if at > last and at <= age then
            if i == 1 then hud.cue("stinger") else hud.cue("move") end
        end
    end
    hud.state.reveals[key] = age
end
