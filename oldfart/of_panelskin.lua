OF = OF or {}
OF.panelskin = OF.panelskin or {}
OF.settings = OF.settings or {}

local skin = OF.panelskin

skin.SETTING_KEY = "menu_style"
skin.STYLES = { classic = true, premium = true }

skin.DEFAULT = "premium"
do
    local stored = mod_storage_load ~= nil and mod_storage_load(skin.SETTING_KEY) or nil
    if stored ~= nil and skin.STYLES[stored] then OF.settings.menuStyle = stored end
end

function skin.style()
    local settings = OF.settings
    local chosen = settings ~= nil and settings.menuStyle or nil
    if chosen ~= nil and skin.STYLES[chosen] then return chosen end
    return skin.DEFAULT
end

function skin.on()
    if skin.style() ~= "premium" then return false end
    local H = OF.hud
    return H ~= nil and type(H.plate) == "function" and type(H.menu_glow) == "function"
end

function skin.set(style)
    if not skin.STYLES[style] then return skin.style() end
    if OF.settings == nil then return skin.style() end
    OF.settings.menuStyle = style
    if OF.util ~= nil and type(OF.util.store) == "function" then
        OF.util.store(skin.SETTING_KEY, style)
    end
    return style
end

local function fade()
    local panel = OF.panel
    if panel ~= nil and type(panel.fade_now) == "function" then return panel.fade_now() or 1 end
    return 1
end
skin.fade = fade

local function now()
    if get_global_timer == nil then return 0 end
    return get_global_timer() or 0
end

function skin.frame(x, y, width, height, titleHeight, hr, hg, hb)
    local H = OF.hud
    local k = fade()
    local accent = { hr, hg, hb }
    for i = 3, 1, -1 do
        H.rect(x - 4 - i * 4, y - 2 - i * 3 + 8, width + 8 + i * 8, height + 4 + i * 6,
            H.C.shade, (14 + (3 - i) * 8) * k)
    end
    H.rect(x, y, width, 2, accent, 255 * k)
    H.rect(x, y + titleHeight - 1, width, 1, accent, 110 * k)
end

function skin.logo_glow(x, y, side)
    OF.hud.menu_logo_glow(x, y, side, now(), fade())
end

function skin.logo_shine(x, y, side)
    OF.hud.menu_logo_shine(x, y, side, now(), fade())
end

skin.tabMove = nil

local function eased_between(move, t)
    local H = OF.hud
    local p = H.ease.out_cubic(H.progress(t - move.at, 0, H.MOTION.fast))
    return p, move.fromX + (move.toX - move.fromX) * p, move.fromW + (move.toW - move.fromW) * p
end

function skin.tab_underline(lineX, lineWidth, lineY, hr, hg, hb)
    local H = OF.hud
    local t = now()
    local move = skin.tabMove
    if move == nil then
        move = { fromX = lineX, fromW = lineWidth, toX = lineX, toW = lineWidth, at = -1000 }
        skin.tabMove = move
    elseif move.toX ~= lineX or move.toW ~= lineWidth then
        local _, cx, cw = eased_between(move, t)
        move.fromX, move.fromW, move.toX, move.toW, move.at = cx, cw, lineX, lineWidth, t
    end
    local p, ux, uw = eased_between(move, t)
    local stretch = math.sin(p * math.pi)
    local k = fade()
    ux, uw = ux - stretch * 12, uw + stretch * 24
    H.rect(ux + 2, lineY - 2, uw - 4, 2, { hr, hg, hb }, (60 + 120 * stretch) * k)
    return ux, uw
end

function skin.selection(x, width, top, height, hr, hg, hb)
    local H = OF.hud
    local accent = { hr, hg, hb }
    H.plate(x + 2, top, width - 4, height, { lit = true, tint = accent, alpha = fade() })
end

skin.TAG_ROOM = 130

function skin.two_tick(right, cy, armedLeft, lit)
    local H = OF.hud
    local a = 255 * fade()

    if armedLeft ~= nil then
        H.menu_arm_ring(right - 11, cy, 10, armedLeft, a, "warn")
        H.menu_text_mid("PRESS AGAIN", right - 28, cy, "caption", "warn", a, "right")
    else
        local tw = H.menu_tag("2x", right, cy, lit and "warn" or "mute", a)
        H.menu_text_mid("PRESS TWICE", right - tw - H.S.s2, cy, "caption", lit and "ink2" or "mute", a, "right")
    end
end

local BOX_STATE = { X = "on", x = "on", [" "] = "off", ["-"] = "some" }
function skin.split_boxes(text)
    local states = {}
    if type(text) ~= "string" then return states, text end
    local at = 1
    while true do
        local box = string.match(text, "^%[([xX%s%-])%]%s", at)
        if box == nil then break end
        states[#states + 1] = BOX_STATE[box] or "off"
        at = at + 4
    end
    return states, string.sub(text, at)
end

function skin.boxes(text, left, rowY, rowHeight, states, dim, mineInk)
    local panel = OF.panel
    local hud = OF.hud
    local size = math.floor(OF.util.line_height(panel.drawScale or 1) * 0.62 + 0.5)
    local top = rowY + math.floor((rowHeight - size) / 2 + 0.5)
    local a = 255 * fade() * (dim and 0.4 or 1)
    for i, state in ipairs(states) do
        local from = panel.box_span(text, i)
        local accent = skin.accent_now()
        if mineInk and i == 2 and type(panel.mine_ink) == "function" then
            local r, g, b = panel.mine_ink()
            accent = { r, g, b }
        end
        if from ~= nil then hud.menu_checkbox(left + from + 1, top, size, state, a, accent) end
    end
end

function skin.locked(right, cy)
    local H = OF.hud
    local a = 255 * fade()
    H.menu_lock(right - 8, cy - 3, a)
    local w = H.menu_text_mid("LOCKED", right - 24, cy, "caption", "mute", a, "right") or 0
    return 24 + w + H.S.s3
end

function skin.caption_row(text, x, cy, room, alpha, index)
    local H = OF.hud
    text = OF.util.plain(tostring(text or ""))
    local shown, dx = H.menu_marquee(text, "caption", room, now())
    local face, scale = H.face_for("caption", shown)
    local top, base = H.cap("caption", 1, shown)
    local r, g, b = H.colour("mute")
    OF.util.in_font(face, function()
        djui_hud_set_color(r, g, b, math.floor((alpha or 255) * fade()))
        djui_hud_print_text(shown, x + (dx or 0), cy - (top + base) / 2, scale)
    end)
end

function skin.thumb(barX, thumbY, thumbHeight, hr, hg, hb, bright)
    local H = OF.hud
    local k = fade()
    H.rect(barX - 2, thumbY, 6, thumbHeight, { hr, hg, hb }, bright * 0.45 * k)
    H.rect(barX - 2, thumbY, 6, 1, H.C.ink, bright * 0.4 * k)
end

local function H() return OF.hud end

function skin.backdrop(vignetteOnly)
    local hud = H()
    local sw, sh = hud.screen()
    local k = fade()
    if not vignetteOnly then hud.rect(0, 0, sw, sh, hud.C.shade, 70 * k) end
    local band = math.floor(math.min(sw, sh) * 0.06)
    for i = 1, 4 do
        local d = band * (i - 1)
        local a = (34 - i * 7) * k
        hud.rect(0, d, sw, band, hud.C.shade, a)
        hud.rect(0, sh - d - band, sw, band, hud.C.shade, a)
        hud.rect(d, 0, band, sh, hud.C.shade, a)
        hud.rect(sw - d - band, 0, band, sh, hud.C.shade, a)
    end
end

skin.pageSeen, skin.pageAt, skin.pageDepth = nil, -1000, 0

function skin.page_veil(page, depth, x, top, width, height)
    local hud = H()
    local t = now()
    if page ~= skin.pageSeen then
        if skin.pageSeen ~= nil then
            skin.pageAt = t
            skin.pageDir = (depth or 0) >= (skin.pageDepth or 0) and 1 or -1
        end
        skin.pageSeen, skin.pageDepth = page, depth or 0
    end
    local p = hud.ease.out_cubic(hud.progress(t - skin.pageAt, 0, hud.MOTION.base))
    if p >= 1 then return false end
    local k = fade()
    hud.rect(x + 2, top, width - 4, height, hud.C.shade, 130 * (1 - p) * k)
    return true
end

skin.glintKey, skin.glintAt = nil, -1000

function skin.glint(key, x, width, top, height)
    local hud = H()
    local t = now()
    if key ~= skin.glintKey then skin.glintKey, skin.glintAt = key, t end
    local p = hud.progress(t - skin.glintAt, 0, hud.MOTION.slow)
    if p >= 1 then return false end
    local e = hud.ease.out_cubic(p)
    local k = fade() * (1 - p)
    local cx = x + (width + 80) * e - 40
    for i = 3, 1, -1 do
        local w = 6 + i * 8
        hud.rect(math.max(x + 5, cx - w / 2), top + 1, math.max(0, math.min(w, x + width - 2 - (cx - w / 2))),
            height - 2, hud.C.ink, (12 + (3 - i) * 10) * k)
    end
    return true
end

skin.seenValue, skin.flashAt = {}, {}

function skin.value_flash(key, value, x, y, w, h, hr, hg, hb)
    if key == nil then return false end
    local hud = H()
    local t = now()
    local was = skin.seenValue[key]
    if was ~= nil and was ~= value then skin.flashAt[key] = t end
    skin.seenValue[key] = value
    local at = skin.flashAt[key]
    if at == nil then return false end
    local p = hud.progress(t - at, 0, hud.MOTION.slow)
    if p >= 1 then skin.flashAt[key] = nil return false end
    local a = (1 - hud.ease.out_cubic(p)) * fade()
    hud.plate(x - 4, y + 2, w + 8, h - 4, { alpha = a, tint = { hr, hg, hb }, lit = true })
    hud.rect(x - 4, y + h - 3, (w + 8) * (1 - p), 2, { hr, hg, hb }, 230 * a)
    return true
end

skin.LIT_PULSE = 0.72

function skin.pulse_pair(r, g, b, lit, hr, hg, hb, frame)
    local panel = OF.panel
    local frames = panel ~= nil and panel.PULSE_FRAMES or 60
    local phase = ((tonumber(frame) or now()) % frames) / frames
    local s = 0.5 - 0.5 * math.cos(phase * 2 * math.pi)
    local tr, tg, tb
    if lit then
        r, g, b = 255, 255, 255
        tr = hr + (255 - hr) * skin.LIT_PULSE
        tg = hg + (255 - hg) * skin.LIT_PULSE
        tb = hb + (255 - hb) * skin.LIT_PULSE
    else
        tr = hr + (255 - hr) * 0.35
        tg = hg + (255 - hg) * 0.35
        tb = hb + (255 - hb) * 0.35
    end
    return math.floor(r + (tr - r) * s + 0.5), math.floor(g + (tg - g) * s + 0.5),
        math.floor(b + (tb - b) * s + 0.5)
end

function skin.mark_match(name, word, nameX, rowY, rowHeight, scale, hr, hg, hb)
    if type(name) ~= "string" or type(word) ~= "string" or word == "" then return false end
    local from, to = string.find(string.lower(name), string.lower(word), 1, true)
    if from == nil then return false end
    local util = OF.util
    local left = nameX + util.width(string.sub(name, 1, from - 1), scale)
    local w = util.width(string.sub(name, from, to), scale)
    local hud = H()
    local k = fade()
    hud.rect(left - 2, rowY + 5, w + 4, rowHeight - 10, { hr, hg, hb }, 70 * k)
    hud.rect(left - 1, rowY + rowHeight - 6, w + 2, 2, { hr, hg, hb }, 255 * k)
    return true
end

function skin.player_ink(localIndex)
    local util = OF.util
    if localIndex == nil or util == nil or type(util.player_color) ~= "function" then return nil end
    local r, g, b = util.player_color(localIndex)
    local hud = H()
    if type(hud.readable) == "function" then r, g, b = hud.readable(r, g, b) end
    return math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)
end

function skin.player_status(localIndex)
    local tags, spectate, idle = OF.tags, OF.spectate, OF.idle
    local asks = OF.util.asks
    if asks(tags, "in_a_round") and tags.in_a_round(localIndex) then return "round", "good" end
    if asks(spectate, "is_spectating") and spectate.is_spectating(localIndex) then return "watching", "info" end
    if asks(idle, "in_menu") and idle.in_menu(localIndex) then return "menu", "gold" end
    if asks(idle, "is_idle") and idle.is_idle(localIndex) then return "away", "mute" end
    return "here", "ink2"
end

function skin.status_dot(cx, cy, localIndex)
    local hud = H()
    local word, tone = skin.player_status(localIndex)
    local k = fade()
    if word == "round" then hud.menu_glow(cx, cy, 7, tone, 90 * k, 2) end
    hud.menu_glow(cx, cy, 3.5, tone, 255 * k, 1)
    return word
end

function skin.rank_badge(faceName, nameX, rowY, rowHeight, scale, rank)
    if type(faceName) ~= "string" or rank == nil then return false end

    local box1 = string.match(faceName, "^(%[[ xX%-]%]%s*)") or ""
    local rest = string.sub(faceName, #box1 + 1)
    local tag = string.match(rest, "^(%[[^%]]+%])")
    if tag == nil then return false end
    local util = OF.util
    local left = nameX + util.width(box1, scale)
    local w = util.width(tag, scale)
    local hud = H()
    local k = fade()

    local top, h = rowY + 5, rowHeight - 10
    hud.plate(left - 4, top, w + 8, h, { alpha = k, lit = true })
    hud.rect(left - 2, top + h - 2, w + 4, 2, rank, 255 * k)
    return true
end

function skin.equaliser(right, cy, hr, hg, hb)
    local hud = H()
    local t = now()
    local k = fade()
    for i = 0, 2 do
        local h = 4 + 8 * (0.5 + 0.5 * math.sin(t * (0.21 + i * 0.07) + i * 1.7))
        hud.rect(right - 16 + i * 5, cy + 6 - h, 3, h, { hr, hg, hb }, 230 * k)
    end
    return 16
end

function skin.sounding(row)
    local music = OF.music
    return row ~= nil and row.track ~= nil and OF.util.asks(music, "sounding")
        and music.sounding() == row.track
end

skin.TAB_ICON = 14

skin.SYMMETRIC_ICONS = { "players", "travel", "race", "control", "me" }
skin.TAB_ICON_GRID = 14
skin.TAB_ICONS = {
    players = {
        "..............",
        ".....####.....",
        "....######....",
        "....######....",
        "....######....",
        ".....####.....",
        "..............",
        "...########...",
        "..##########..",
        ".############.",
        ".############.",
        ".############.",
        ".############.",
        "..............",
    },
    travel = {
        "..............",
        ".....####.....",
        "...########...",
        "..##..##..##..",
        ".##...##...##.",
        ".##...##...##.",
        ".############.",
        ".############.",
        ".##...##...##.",
        ".##...##...##.",
        "..##..##..##..",
        "...########...",
        ".....####.....",
        "..............",
    },
    race = {
        "..............",
        ".##...##...##.",
        ".##...##...##.",
        ".###..##..###.",
        ".###.####.###.",
        ".############.",
        ".############.",
        ".############.",
        ".############.",
        ".############.",
        "..............",
        ".############.",
        ".############.",
        "..............",
    },
    room = {
        "..............",
        ".........##...",
        ".........##...",
        ".......######.",
        ".......######.",
        ".........##...",
        ".........##...",
        "......##......",
        ".....##.......",
        "....##........",
        "...##.........",
        "..##..........",
        ".##...........",
        "..............",
    },
    control = {
        "..............",
        ".############.",
        ".############.",
        ".############.",
        ".############.",
        ".############.",
        ".############.",
        "..##########..",
        "..##########..",
        "...########...",
        "....######....",
        ".....####.....",
        "......##......",
        "..............",
    },
    me = {
        "..............",
        "......##......",
        "..##..##..##..",
        "..##########..",
        "...########...",
        "...##....##...",
        ".####....####.",
        ".####....####.",
        "...##....##...",
        "...########...",
        "..##########..",
        "..##..##..##..",
        "......##......",
        "..............",
    },
}

local iconRunsKept = {}
function skin.icon_runs(key)
    local rows = skin.TAB_ICONS[key]
    if rows == nil then return nil end
    local kept = iconRunsKept[key]
    if kept ~= nil and kept.rows == rows then return kept.runs end
    local runs = skin.cut_icon_runs(rows)
    iconRunsKept[key] = { rows = rows, runs = runs }
    return runs
end

function skin.cut_icon_runs(rows)
    local runs = {}
    for r, line in ipairs(rows) do
        local col = 1
        while col <= #line do
            if string.sub(line, col, col) == "#" then
                local from = col
                while col <= #line and string.sub(line, col, col) == "#" do col = col + 1 end
                runs[#runs + 1] = { from - 1, r - 1, col - from }
            else
                col = col + 1
            end
        end
    end
    return runs
end

function skin.tab_icon(key, x, y, size, c, alpha)
    local hud = H()
    local runs = skin.icon_runs(key)
    if runs == nil then return false end
    local grid = skin.TAB_ICON_GRID
    local u = math.max(1, math.floor(size / grid))
    local ox = math.floor(x + (size - grid * u) / 2 + 0.5)
    local oy = math.floor(y + (size - grid * u) / 2 + 0.5)
    for _, run in ipairs(runs) do
        hud.rect(ox + run[1] * u, oy + run[2] * u, run[3] * u, u, c, alpha or 255)
    end
    return true
end

local MOUSE_WORDS = {
    ["Click"] = "left", ["Drag"] = "left", ["Click left [x]"] = "left",
    ["Right-click"] = "right", ["Wheel"] = "scroll", ["Wheel on the bar"] = "scroll",
}
local PAD_DIRECTIONS = { ["^v"] = { "Up", "Down" }, ["<>"] = { "Left", "Right" } }

local function pad_pieces(word, out)
    local dirs = PAD_DIRECTIONS[word]
    if dirs ~= nil then
        out[#out + 1] = { glyph = { pad = dirs[1] }, set = "pad" }
        out[#out + 1] = { glyph = { pad = dirs[2] }, set = "pad" }
        return true
    end

    local chord, rest = string.match(word, "^(%a+)%+(.+)$")
    if chord ~= nil then
        out[#out + 1] = { glyph = { pad = chord }, set = "pad" }
        out[#out + 1] = { sep = "+" }
        return pad_pieces(rest, out)
    end
    local a, b = string.match(word, "^(%a+)/(%a+)$")
    if a ~= nil then
        out[#out + 1] = { glyph = { pad = a }, set = "pad" }
        out[#out + 1] = { sep = "/" }
        out[#out + 1] = { glyph = { pad = b }, set = "pad" }
        return true
    end
    if string.match(word, "^%a+$") and #word <= 5 then
        out[#out + 1] = { glyph = { pad = word }, set = "pad" }
        return true
    end
    return false
end

local keyPiecesKept, keyPiecesCount = {}, 0
function skin.key_pieces(key)
    key = tostring(key or "")
    local kept = keyPiecesKept[key]
    if kept ~= nil then return kept end
    if keyPiecesCount >= 256 then keyPiecesKept, keyPiecesCount = {}, 0 end
    kept = skin.parse_key_pieces(key)
    keyPiecesKept[key] = kept
    keyPiecesCount = keyPiecesCount + 1
    return kept
end

function skin.parse_key_pieces(key)
    local out = {}

    local padWord, mouseWord = string.match(key, "^(.-)   (.+)$")
    local words = padWord ~= nil and { padWord, mouseWord } or { key }
    for i, word in ipairs(words) do
        if i > 1 then out[#out + 1] = { sep = "/" } end
        local mouse = MOUSE_WORDS[word]
        if mouse ~= nil then
            out[#out + 1] = { glyph = { mouse = mouse, pad = word, key = word }, set = "kbm" }
        elseif not pad_pieces(word, out) then
            out[#out + 1] = { word = word }
        end
    end
    return out
end

skin.CHIP = 18

function skin.key_width(key, scale)
    local H = OF.hud
    local w = 0
    for _, piece in ipairs(skin.key_pieces(key)) do
        if piece.glyph ~= nil then w = w + H.glyph_width(piece.glyph, skin.CHIP, piece.set)
        elseif piece.sep ~= nil then w = w + H.measure(piece.sep, "caption") + 6
        else w = w + H.glyph_width({ pad = piece.word, key = piece.word }, skin.CHIP, "kbm") end
        w = w + 2
    end
    return math.max(0, w - 2)
end

function skin.key(key, x, textY, textHeight, scale)
    local H = OF.hud
    local cy = textY + textHeight / 2
    local left = x
    for _, piece in ipairs(skin.key_pieces(key)) do
        if piece.glyph ~= nil then
            local gw = H.glyph(piece.glyph, left, cy - skin.CHIP / 2, skin.CHIP, 255 * fade(), piece.set)
            left = left + gw
        elseif piece.sep ~= nil then
            local sw = H.measure(piece.sep, "caption") + 6
            H.menu_text_mid(piece.sep, left + sw / 2, cy, "caption", "mute", 255 * fade(), "center")
            left = left + sw
        else
            left = left + H.glyph({ pad = piece.word, key = piece.word }, left, cy - skin.CHIP / 2,
                skin.CHIP, 255 * fade(), "kbm")
        end
        left = left + 2
    end
    return left - 2 - x
end

function skin.legend_width(hints, scale, gap)
    local w = 0
    for i, hint in ipairs(hints) do
        w = w + skin.key_width(hint.key, scale) + 4
            + OF.util.width(OF.lang.t(hint.label), scale)
        if i < #hints then w = w + gap end
    end
    return w
end

skin.ROW_SCALE = 0.85
skin.ROW_GAP = 6
skin.DETAIL = 300
skin.DETAIL_MIN = 220

skin.SIZE_KEY = "menu_size"
skin.SIZES = { 75, 85, 100, 115, 130, 0 }
skin.SIZE_DEFAULT = 100
skin.sizeNow = skin.SIZE_DEFAULT
do
    local stored = mod_storage_load_integer ~= nil and mod_storage_load_integer(skin.SIZE_KEY, skin.SIZE_DEFAULT)
        or skin.SIZE_DEFAULT
    for _, v in ipairs(skin.SIZES) do
        if v == stored then skin.sizeNow = stored end
    end
end
function skin.size() return skin.sizeNow end
function skin.size_step()
    for i, v in ipairs(skin.SIZES) do
        if v == skin.sizeNow then return i - 1 end
    end
    return 2
end
function skin.set_size_step(step)
    local v = skin.SIZES[math.floor(tonumber(step) or 0) + 1]
    if v == nil then return false, "No such size." end
    skin.sizeNow = v
    if OF.util ~= nil and type(OF.util.store_integer) == "function" then
        OF.util.store_integer(skin.SIZE_KEY, v)
    end
    return true
end
function skin.size_word(v)
    v = v or skin.sizeNow
    if v == 0 then return OF.lang.t("The whole screen") end
    return tostring(v) .. "%"
end

function skin.layout(classicWidth, sidePad, strip)
    local hud = H()
    local M = hud.MENU
    local sw, sh = hud.screen()
    local room = math.max(0, (classicWidth or 0) - sidePad * 2)
    local paneW = math.ceil(room * skin.ROW_SCALE) + sidePad * 2 + strip
    local detailW = skin.DETAIL
    local base = math.max(M.width, M.pad * 2 + paneW + M.gap + detailW)
    local most = sw - hud.MARGIN * 2
    local tallest = sh - hud.MARGIN * 2
    local size = skin.sizeNow or skin.SIZE_DEFAULT
    local w, h
    if size == 0 then
        w, h = most, tallest
    else
        w, h = base * size / 100, M.height * size / 100
    end
    local least = M.pad * 2 + paneW + M.gap + skin.DETAIL_MIN
    w = math.floor(math.min(most, math.max(w, least)))
    detailW = math.max(skin.DETAIL_MIN, math.min(skin.DETAIL * 1.5, w - M.pad * 2 - paneW - M.gap))
    paneW = w - M.pad * 2 - M.gap - detailW
    local shortest = M.header + M.tabs + M.crumb + M.footer + 8 + 4 * 34
    h = math.floor(math.min(tallest, math.max(h, math.min(shortest, tallest))))
    local px, py = 50, 50
    local panel = OF.panel
    if panel ~= nil and type(panel.place) == "table" then
        px, py = panel.place.x or 50, panel.place.y or 50
    end
    local x = math.floor(hud.MARGIN + (sw - hud.MARGIN * 2 - w) * px / 100)
    local y = math.floor(hud.MARGIN + (sh - hud.MARGIN * 2 - h) * py / 100)
    local L = { x = x, y = y, w = w, h = h }
    L.tabsY = y + M.header
    L.crumbY = L.tabsY + M.tabs
    L.lx, L.ly = x + M.pad, L.crumbY + M.crumb
    L.lw = paneW
    L.lh = h - M.header - M.tabs - M.crumb - M.footer - 8
    L.px = L.lx + L.lw + M.gap
    L.pw = x + w - M.pad - L.px
    L.footerY = y + h - M.footer
    L.tabBar = { x = x, y = L.tabsY, w = w, h = M.tabs }
    L.screen = { w = sw, h = sh }
    skin.last = L
    return L
end

function skin.metrics(classic)
    local rowText = OF.util.line_height(skin.ROW_SCALE)
    local M = H().MENU
    local m = {}
    for key, value in pairs(classic) do m[key] = value end
    m.rowText = rowText
    m.rowHeight = rowText + skin.ROW_GAP
    m.titleHeight, m.tabHeight, m.footerHeight = M.header, M.tabs, M.footer
    return m
end

function skin.rows_in(L, m)
    return math.max(1, math.floor(L.lh / m.rowHeight))
end

skin.tabFrom, skin.tabAt, skin.tabWas = nil, -1000, nil

local function inside(r, x, y)
    return r ~= nil and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function skin.accent_now()
    local hr, hg, hb = 255, 210, 80
    if OF.theme ~= nil and type(OF.theme.highlight) == "function" then hr, hg, hb = OF.theme.highlight() end

    return H().accent_lift({ hr, hg, hb })
end

function skin.chrome(L, st)
    local hud = H()
    local panel = OF.panel
    local M = hud.MENU
    local k = fade()
    local accent = skin.accent_now()
    local now = st.now or 0
    hud.menu_window(L.x, L.y, L.w, L.h, k, accent, (panel.opacity or 100) / 100)

    local tier = OF.perms.my_tier()
    local badge = string.upper(tostring(OF.perms.tier_name(tier) or ""))
    local br, bg, bb = 255, 210, 80
    if OF.util.asks(OF.perms, "tier_color") then br, bg, bb = OF.perms.tier_color(tier) end
    if type(hud.readable) == "function" then br, bg, bb = hud.readable(br, bg, bb) end
    hud.menu_header(L.x, L.y, L.w, { version = OF.VERSION or "", badge = badge,
        badgeTone = { br, bg, bb }, now = now }, k)

    if skin.tabWas ~= panel.tab then
        if skin.tabWas ~= nil then skin.tabFrom, skin.tabAt = skin.tabWas, now end
        skin.tabWas = panel.tab
    end
    local names, closed = {}, {}
    local roundOnly = panel.round_tab_only()
    for i, tab in ipairs(panel.TABS) do
        names[i] = OF.lang.t(tab.name)
        closed[i] = roundOnly and tab.key ~= panel.ROUND_TAB
    end
    local hover = nil
    for i, cell in ipairs(skin.tabCells or {}) do
        if inside(cell, st.mouseX, st.mouseY) then hover = i end
    end
    local cells, chips = hud.menu_tabs(L.x, L.tabsY, L.w, names, {
        current = panel.tab, from = skin.tabFrom or panel.tab, at = skin.tabAt, now = now,
        hover = hover, accent = accent, closed = closed,

        icon = function(i, x, cy, size, a)
            skin.tab_icon(panel.TABS[i].key, x, cy - size / 2, size, accent, a)
        end,
    }, k, hud.glyph_set(now))
    skin.tabCells = cells
    if st.clicked then
        for i, cell in ipairs(cells or {}) do
            if inside(cell, st.mouseX, st.mouseY) then
                if i ~= panel.tab then panel.show_tab(i) else panel.tab_home(i) end
                OF.sounds.ui("tab", OF.sounds.TAB)
                return true
            end
        end
        for _, chip in ipairs(chips or {}) do
            if inside(chip, st.mouseX, st.mouseY) then
                panel.next_tab(chip.word == "tabPrev" and -1 or 1)
                return true
            end
        end
    end
    if (st.wheel or 0) ~= 0 then
        panel.next_tab(st.wheel > 0 and -1 or 1)
        return true
    end

    local crumbs = panel.crumbs
    if type(crumbs) ~= "table" or #crumbs == 0 then crumbs = panel.trail(panel.page) end
    local keys = panel.trail_keys(panel.page)
    if #keys ~= #crumbs then keys = {} end
    local shownCrumbs, shownKeys = {}, {}
    for i = math.max(1, #crumbs - 3), #crumbs do
        shownCrumbs[#shownCrumbs + 1] = tostring(crumbs[i])
        shownKeys[#shownKeys + 1] = keys[i] or false
    end
    local place, total = 0, 0
    for i, r in ipairs(panel.rows or {}) do
        if panel.is_stop(r) then
            total = total + 1
            if i == panel.cursor then place = total end
        end
    end
    local rects = hud.menu_breadcrumb(L.x, L.crumbY, L.w, shownCrumbs, place, total, k)
    local selected = panel.selection_count()
    if selected > 0 then
        local word = string.upper(OF.lang.fill("@ selected", selected))
        local counterW = hud.measure(string.format("%.0f / %.0f", place, total), "caption")
        hud.menu_text_mid(word, L.x + L.w - M.pad - counterW - hud.S.s4, L.crumbY + M.crumb / 2,
            "caption", "gold", 255 * k, "right")
    end
    local hits = { top = L.crumbY + 4, bottom = L.crumbY + M.crumb - 4, list = {} }
    for i, r in ipairs(rects or {}) do
        if i < #rects and shownKeys[i] then
            hits.list[#hits.list + 1] = { left = r.x, right = r.x + r.w, key = shownKeys[i] }
        end
    end
    panel.crumbHits = hits
    return false
end

function skin.detail_row(r, level, rows, index)
    if r == nil then return nil end
    local panel = OF.panel
    local name = OF.util.plain(tostring(r.confirming or r.text or ""))
    name = string.gsub(name, "^%s*%[.%]%s*%[.%]%s*", "")
    name = string.gsub(name, "^%s*%[.%]%s*", "")

    if r.heading then name = string.gsub(name, "^%s*[%+%-]%s+", "") end
    local help = r.help ~= nil and OF.util.say_buttons(OF.lang.t(r.help), true) or nil

    if r.grid ~= nil and OF.util.asks(panel, "grid_col") then
        local col = panel.grid_col(r)
        local cell = col ~= nil and r.grid.cells[col] or nil
        if cell ~= nil then
            name = OF.util.plain(tostring(cell.name or ""))
            help = cell.help ~= nil and OF.util.say_buttons(OF.lang.t(cell.help), true) or help
        end
    end

    if type(help) == "string" then help = string.upper(string.sub(help, 1, 1)) .. string.sub(help, 2) end
    local row = { name = name, help = help, now = level }
    if r.heading then

        local folded = string.match(OF.util.plain(tostring(r.text or "")), "^%s*%+") ~= nil
        if folded then
            row.kindWord = "A SECTION, FOLDED"
            row.help = (help ~= nil and (help .. ". ") or "") .. OF.util.say_buttons("Press A to open it.", true)
        else
            local count = 0
            for i = (index or 0) + 1, #(rows or {}) do
                if rows[i].heading then break end
                count = count + 1
            end
            row.kindWord = count == 1 and "A SECTION, 1 ROW" or string.format("A SECTION, %.0f ROWS", count)
            row.help = (help ~= nil and (help .. ". ") or "") .. OF.util.say_buttons("Press A to fold it away.", true)
        end
    elseif r.danger then
        row.kind = "double"
    elseif r.slider ~= nil and (r.slider.steps or 0) > 0 then
        row.kind = "slider"
    elseif panel.row_ticks(r) then
        row.kind = "toggle"
    elseif string.find(name, "%.%.%.$") then
        row.kind = "page"
    elseif r.action ~= nil then
        row.kindWord = "PRESS TO USE"
    end
    if r.action == nil and not r.heading and (r.needs ~= nil or r.hostOnly) then
        if r.hostOnly then
            row.disabled = "Only the host can use this one."
        else
            row.disabled = OF.lang.fill("Your rank needs to be @ or higher for this.",
                tostring(OF.perms.tier_name(r.needs) or r.needs))
        end
    end
    if r.localIndex ~= nil then
        local pr, pg, pb = skin.player_ink(r.localIndex)
        if pr ~= nil then row.colour = { pr, pg, pb } end
    end
    return row
end

function skin.feed_push(text)
    local hud = H()
    local np = gNetworkPlayers ~= nil and gNetworkPlayers[0] or nil
    local colour = nil
    if np ~= nil then
        local r, g, b = skin.player_ink(0)
        if r ~= nil then colour = { r, g, b } end
    end

    local line = tostring(text or "")
    local kind = "done"
    local page, rest = string.match(line, "^(.-:%s)(.*)$")
    if rest == nil then page, rest = "", line end
    local box = string.match(rest, "^%[(.)%]")
    if box ~= nil then
        kind = (box == "X" or box == "x") and "off" or "on"
        while string.match(rest, "^%[.%]%s*") do rest = string.gsub(rest, "^%[.%]%s*", "", 1) end
        line = page .. rest .. (kind == "on" and " - on" or " - off")
    end

    if OF.notify == nil or type(OF.notify.line_mine) ~= "function" then return false end
    return OF.notify.line_mine(line, kind, colour)
end

function skin.detail(L, r, level, now)
    local hud = H()
    local k = fade()
    local panel = OF.panel
    local doneAt = hud.menu_detail(L.px, L.ly, L.pw, L.lh,
        skin.detail_row(r, level, panel.rows, panel.cursor), k)
    local lineH = hud.MENU.feedLineH + hud.MENU.feedGap
    local feedRoom = math.floor((L.ly + L.lh - 8 - (doneAt + hud.S.s4) - 18) / lineH)
    local lines = math.max(1, math.min(hud.MENU.feedLines, feedRoom))
    local fy = L.ly + L.lh - 8 - lines * lineH - 18
    local w = L.pw - hud.S.s3 * 2
    local entries = (OF.notify ~= nil and type(OF.notify.feed_entries) == "function")
        and OF.notify.feed_entries(hud.menu_feed_room(w)) or {}
    hud.menu_feed(L.px + hud.S.s3, math.max(fy, doneAt + hud.S.s2), w, entries,
        now or 0, k, lines)
end

skin.FOOT_MOST = 5

function skin.footer_keys(hints, kbm)
    local mine = {}
    for _, hint in ipairs(hints or {}) do
        if #mine >= skin.FOOT_MOST then break end
        local key = tostring(hint.key or "")
        local padWord, mouseWord = string.match(key, "^(.-)   (.+)$")
        if padWord ~= nil then key = kbm and mouseWord or padWord end
        mine[#mine + 1] = { key = key, label = hint.label, nav = hint.nav }
    end
    return mine
end

function skin.footer(L, hints, contextual, scale)
    local hud = H()
    local M = hud.MENU
    local k = fade()
    hud.rect(L.x + M.pad, L.footerY, L.w - M.pad * 2, 1, hud.C.edge, 22 * k)
    local GAP = hud.S.s6
    local function width_of(list)
        local w = 0
        for i, hint in ipairs(list) do
            w = w + skin.key_width(hint.key, scale) + 6
                + hud.measure(string.upper(OF.lang.t(hint.label)), "caption")
            if i < #list then w = w + GAP end
        end
        return w
    end
    hints = skin.footer_keys(hints, hud.glyph_set() == "kbm")
    contextual = math.min(contextual, #hints)
    local room = L.w - M.pad * 2
    while #hints > 1 and width_of(hints) > room do table.remove(hints) end
    local cy = L.footerY + M.footer / 2
    local textH = OF.util.line_height(scale)
    local x = L.x + L.w / 2 - width_of(hints) / 2
    for index, hint in ipairs(hints) do
        local lit = index <= contextual
        local kw = skin.key(hint.key, x, cy - textH / 2, textH, scale)
        x = x + kw + 6
        local label = string.upper(OF.lang.t(hint.label))
        local lw = hud.menu_text_mid(label, x, cy, "caption", lit and "ink" or "ink2", 255 * k)
        x = x + (lw or 0) + GAP
    end
    return #hints
end
